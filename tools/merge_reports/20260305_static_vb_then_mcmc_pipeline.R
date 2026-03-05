#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(parallel)
})

devtools::load_all(".", quiet = TRUE)

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

sim_path <- Sys.getenv(
  "EXDQLM_STATIC_SIM_PATH",
  "results/sim_suite_static/series/static_exal_mildskew/sim_output.rds"
)
if (!file.exists(sim_path)) stop("Static simulation file not found: ", sim_path)

sim <- readRDS(sim_path)
if (is.null(sim$extras$X)) stop("Static sim object must contain extras$X")

TT_full <- length(sim$y)
TT <- min(TT_full, max(100L, safe_int(Sys.getenv("EXDQLM_STATIC_PIPELINE_TT", "5000"), 5000L)))
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])

p_vec <- c(0.05, 0.50, 0.95)

vb_max_iter <- safe_int(Sys.getenv("EXDQLM_STATIC_VB_MAX_ITER", "300"), 300L)
vb_tol <- safe_num(Sys.getenv("EXDQLM_STATIC_VB_TOL", "0.03"), 0.03)
vb_n_samp_xi <- safe_int(Sys.getenv("EXDQLM_STATIC_VB_NSAMP", "1000"), 1000L)

mcmc_burn <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_BURN", "2000"), 2000L)
mcmc_n <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_N", "1000"), 1000L)
mcmc_thin <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_THIN", "1"), 1L)

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores_pipeline <- safe_int(Sys.getenv("EXDQLM_STATIC_PIPELINE_CORES", "6"), 6L)
cores_pipeline <- max(1L, min(cores_pipeline, n_core_phys))

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
out_root <- file.path(
  "results/sim_suite_static",
  sprintf(
    "static_vb_then_mcmc_tt%d_vbns%d_burn%d_n%d_%s",
    TT, vb_n_samp_xi, mcmc_burn, mcmc_n, stamp
  )
)

for (d in c("fits/vb", "fits/mcmc", "logs", "tables", "plots")) {
  dir.create(file.path(out_root, d), recursive = TRUE, showWarnings = FALSE)
}

master_log <- file.path(out_root, "logs", "master.log")
status_dir <- file.path(out_root, "logs")

task_key <- function(model_name, tau) sprintf("%s_tau_%s", model_name, tau_lab(tau))
task_log_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".log"))
task_status_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".status.tsv"))

log_master <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = master_log, append = TRUE)
  flush.console()
}

log_task <- function(model_name, tau, ...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n", file = task_log_file(model_name, tau), append = TRUE)
}

write_status <- function(model_name, tau, stage, note = "") {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stage, note, sep = "\t")
  cat(line, "\n", file = task_status_file(model_name, tau), append = TRUE)
}

cfg <- list(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  sim_path = sim_path,
  out_root = out_root,
  TT = TT,
  taus = p_vec,
  X_dim = dim(X),
  y_summary = list(mean = mean(y), sd = stats::sd(y)),
  cores_pipeline = cores_pipeline,
  vb = list(max_iter = vb_max_iter, tol = vb_tol, n_samp_xi = vb_n_samp_xi),
  mcmc = list(burn = mcmc_burn, n = mcmc_n, thin = mcmc_thin)
)
saveRDS(cfg, file.path(out_root, "tables", "run_config.rds"))

run_one_pipeline <- function(task_row) {
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)
  dqlm.ind <- identical(model_name, "al")

  write_status(model_name, tau, "START", sprintf("seed=%d", seed))
  log_task(model_name, tau, sprintf("start pipeline model=%s tau=%.2f", model_name, tau))

  set.seed(seed)
  vb_t0 <- Sys.time()
  write_status(model_name, tau, "VB_START")

  vb_fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = tau,
    max_iter = vb_max_iter,
    tol = vb_tol,
    dqlm.ind = dqlm.ind,
    n_samp_xi = vb_n_samp_xi,
    verbose = FALSE
  )
  vb_runtime <- as.numeric(difftime(Sys.time(), vb_t0, units = "secs"))
  vb_norm <- .static_normalize_vb_fit(
    vb_fit,
    model_name = model_name,
    tau = tau,
    run_settings = list(max_iter = vb_max_iter, tol = vb_tol, n_samp_xi = vb_n_samp_xi)
  )

  vb_file <- file.path(out_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))
  saveRDS(
    list(
      fit = vb_fit,
      normalized = vb_norm,
      meta = list(model = model_name, tau = tau, seed = seed, runtime_sec = vb_runtime)
    ),
    vb_file,
    compress = "xz"
  )

  write_status(
    model_name,
    tau,
    "VB_DONE",
    sprintf("runtime_sec=%.1f iter=%s stop=%s", vb_runtime, vb_norm$iter, vb_norm$stop_reason)
  )
  log_task(model_name, tau, sprintf("vb done runtime=%.1fs", vb_runtime))

  init_list <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = dqlm.ind)

  m_t0 <- Sys.time()
  write_status(model_name, tau, "MCMC_START")
  set.seed(seed + 1234L)

  m_fit <- exal_static_mcmc(
    y = y,
    X = X,
    p0 = tau,
    dqlm.ind = dqlm.ind,
    init = init_list,
    init.from.vb = FALSE,
    n.burn = mcmc_burn,
    n.mcmc = mcmc_n,
    thin = mcmc_thin,
    verbose = FALSE
  )

  m_runtime <- as.numeric(difftime(Sys.time(), m_t0, units = "secs"))
  m_norm <- .static_normalize_mcmc_fit(
    m_fit,
    model_name = model_name,
    tau = tau,
    run_settings = list(n_burn = mcmc_burn, n_mcmc = mcmc_n, thin = mcmc_thin)
  )

  m_file <- file.path(out_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))
  saveRDS(
    list(
      fit = m_fit,
      normalized = m_norm,
      meta = list(model = model_name, tau = tau, seed = seed, runtime_sec = m_runtime)
    ),
    m_file,
    compress = "xz"
  )

  write_status(
    model_name,
    tau,
    "MCMC_DONE",
    sprintf("runtime_sec=%.1f ess_sigma=%.2f ess_gamma=%.2f", m_runtime, m_norm$diagnostics$ess$sigma, m_norm$diagnostics$ess$gamma)
  )
  log_task(model_name, tau, sprintf("mcmc done runtime=%.1fs", m_runtime))

  data.frame(
    model = model_name,
    tau = tau,
    status = "done",
    vb_runtime_sec = vb_runtime,
    vb_iter = vb_norm$iter,
    vb_converged = vb_norm$converged,
    vb_stop_reason = vb_norm$stop_reason,
    vb_sigma = vb_norm$sigma_est,
    vb_gamma = vb_norm$gamma_est,
    mcmc_runtime_sec = m_runtime,
    mcmc_sigma_mean = m_norm$sigma_est,
    mcmc_gamma_mean = m_norm$gamma_est,
    ess_sigma = m_norm$diagnostics$ess$sigma,
    ess_gamma = m_norm$diagnostics$ess$gamma,
    accept_rate = m_norm$diagnostics$acceptance$total,
    vb_file = vb_file,
    mcmc_file = m_file,
    stringsAsFactors = FALSE
  )
}

tasks <- expand.grid(
  model = c("exal", "al"),
  tau = p_vec,
  stringsAsFactors = FALSE
)
tasks$seed <- 202603050L + seq_len(nrow(tasks)) * 1000L

log_master(sprintf("starting static VB->MCMC pipeline run in %s", out_root))
log_master(sprintf("TT=%d VB(max_iter=%d,tol=%.4f,n_samp_xi=%d) MCMC(burn=%d,n=%d,thin=%d) cores=%d",
                   TT, vb_max_iter, vb_tol, vb_n_samp_xi, mcmc_burn, mcmc_n, mcmc_thin, cores_pipeline))
log_master(sprintf("models=%s taus=%s", paste(unique(tasks$model), collapse = ","), paste(sprintf("%.2f", p_vec), collapse = ",")))

safe_task <- function(task_row) {
  tryCatch(
    run_one_pipeline(task_row),
    error = function(e) {
      model_name <- as.character(task_row$model)
      tau <- as.numeric(task_row$tau)
      write_status(model_name, tau, "FAILED", conditionMessage(e))
      log_task(model_name, tau, paste("failed:", conditionMessage(e)))
      data.frame(
        model = model_name,
        tau = tau,
        status = "failed",
        vb_runtime_sec = NA_real_,
        vb_iter = NA_integer_,
        vb_converged = NA,
        vb_stop_reason = NA_character_,
        vb_sigma = NA_real_,
        vb_gamma = NA_real_,
        mcmc_runtime_sec = NA_real_,
        mcmc_sigma_mean = NA_real_,
        mcmc_gamma_mean = NA_real_,
        ess_sigma = NA_real_,
        ess_gamma = NA_real_,
        accept_rate = NA_real_,
        vb_file = NA_character_,
        mcmc_file = NA_character_,
        error = conditionMessage(e),
        stringsAsFactors = FALSE
      )
    }
  )
}

task_list <- split(tasks, seq_len(nrow(tasks)))
if (.Platform$OS.type == "unix" && cores_pipeline > 1L) {
  out <- parallel::mclapply(task_list, safe_task, mc.cores = cores_pipeline, mc.preschedule = FALSE)
} else {
  out <- lapply(task_list, safe_task)
}

summary_df <- do.call(rbind, out)
utils::write.csv(summary_df, file.path(out_root, "tables", "pipeline_task_summary.csv"), row.names = FALSE)

log_master("pipeline run completed")
log_master(sprintf("summary table: %s", file.path(out_root, "tables", "pipeline_task_summary.csv")))
