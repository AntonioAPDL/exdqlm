#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(parallel)
})

load_exdqlm <- function(repo_root = ".") {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }
  stop("Neither devtools nor pkgload is installed; cannot load local exdqlm package.")
}

load_exdqlm(".")

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

safe_chr_vec <- function(x, default = NULL) {
  if (!nzchar(x)) return(default)
  vals <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  vals <- vals[nzchar(vals)]
  if (!length(vals)) return(default)
  vals
}

cfg_path <- Sys.getenv(
  "EXDQLM_STATIC_RUN_CONFIG",
  "results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_194203/tables/run_config.rds"
)
if (!file.exists(cfg_path)) stop("Missing config: ", cfg_path)
cfg <- readRDS(cfg_path)
run_root <- as.character(cfg$out_root)
if (!dir.exists(run_root)) stop("run_root not found: ", run_root)

sim <- readRDS(cfg$sim_path)
TT <- as.integer(cfg$TT)
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])

p_vec <- as.numeric(cfg$taus)
mcmc_burn <- safe_int(cfg$mcmc$burn, 2000L)
mcmc_n <- safe_int(cfg$mcmc$n, 1000L)
mcmc_thin <- safe_int(cfg$mcmc$thin, 1L)
mcmc_mh_proposal <- tolower(Sys.getenv(
  "EXDQLM_STATIC_MCMC_MH_PROPOSAL",
  if (!is.null(cfg$mcmc$mh$proposal)) as.character(cfg$mcmc$mh$proposal)[1] else "laplace_rw"
))
if (!(mcmc_mh_proposal %in% c("laplace_local", "laplace_rw", "rw"))) mcmc_mh_proposal <- "laplace_rw"
mcmc_mh_adapt <- identical(tolower(Sys.getenv(
  "EXDQLM_STATIC_MCMC_MH_ADAPT",
  if (!is.null(cfg$mcmc$mh$adapt)) as.character(cfg$mcmc$mh$adapt)[1] else "true"
)), "true")
mcmc_mh_adapt_interval <- safe_int(
  Sys.getenv("EXDQLM_STATIC_MCMC_MH_ADAPT_INTERVAL", as.character(cfg$mcmc$mh$adapt_interval)),
  safe_int(cfg$mcmc$mh$adapt_interval, 50L)
)
mcmc_mh_target <- if (!is.null(cfg$mcmc$mh$target_accept)) as.numeric(cfg$mcmc$mh$target_accept) else c(0.20, 0.45)
if (length(mcmc_mh_target) != 2L || any(!is.finite(mcmc_mh_target))) mcmc_mh_target <- c(0.20, 0.45)
mcmc_mh_scale_bounds <- if (!is.null(cfg$mcmc$mh$scale_bounds)) as.numeric(cfg$mcmc$mh$scale_bounds) else c(0.1, 10)
if (length(mcmc_mh_scale_bounds) != 2L || any(!is.finite(mcmc_mh_scale_bounds))) mcmc_mh_scale_bounds <- c(0.1, 10)
mcmc_mh_max_scale_step <- safe_num(
  Sys.getenv("EXDQLM_STATIC_MCMC_MH_MAX_SCALE_STEP", as.character(cfg$mcmc$mh$max_scale_step)),
  safe_num(cfg$mcmc$mh$max_scale_step, 0.35)
)
mcmc_mh_min_burn_adapt <- safe_int(
  Sys.getenv("EXDQLM_STATIC_MCMC_MH_MIN_BURN_ADAPT", as.character(cfg$mcmc$mh$min_burn_adapt)),
  safe_int(cfg$mcmc$mh$min_burn_adapt, 50L)
)

cores <- safe_int(Sys.getenv("EXDQLM_STATIC_RESUME_CORES", as.character(cfg$cores_pipeline)), safe_int(cfg$cores_pipeline, 2L))
cores <- max(1L, min(cores, safe_int(parallel::detectCores(logical = FALSE), 2L)))
dry_run <- identical(tolower(Sys.getenv("EXDQLM_STATIC_RESUME_DRYRUN", "0")), "1")

status_dir <- file.path(run_root, "logs")
master_log <- file.path(status_dir, "resume_static_master.log")

task_key <- function(model_name, tau) sprintf("%s_tau_%s", model_name, tau_lab(tau))
task_log_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".log"))
task_status_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".status.tsv"))

log_master <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = master_log, append = TRUE)
}

log_task <- function(model_name, tau, ...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n", file = task_log_file(model_name, tau), append = TRUE)
}

write_status <- function(model_name, tau, stage, note = "") {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stage, note, sep = "\t")
  cat(line, "\n", file = task_status_file(model_name, tau), append = TRUE)
}

seed_from_status <- function(model_name, tau, fallback) {
  sf <- task_status_file(model_name, tau)
  if (!file.exists(sf)) return(as.integer(fallback))
  lines <- readLines(sf, warn = FALSE)
  m <- regmatches(lines, regexec("seed=([0-9]+)", lines))
  vals <- unlist(lapply(m, function(x) if (length(x) >= 2) x[2] else NA_character_))
  vals <- vals[!is.na(vals)]
  if (length(vals) >= 1) return(as.integer(vals[1]))
  as.integer(fallback)
}

model_filter <- safe_chr_vec(Sys.getenv("EXDQLM_STATIC_RESUME_MODELS", ""), default = c("exal", "al"))
model_filter <- unique(tolower(model_filter))
model_filter <- model_filter[model_filter %in% c("exal", "al")]
if (!length(model_filter)) stop("No valid EXDQLM_STATIC_RESUME_MODELS resolved.")

tasks <- expand.grid(model = model_filter, tau = p_vec, stringsAsFactors = FALSE)
tasks$seed <- vapply(seq_len(nrow(tasks)), function(i) {
  seed_from_status(tasks$model[i], tasks$tau[i], 202603050L + i * 1000L)
}, integer(1))

log_master(sprintf("static resume start | run_root=%s | dry_run=%s | cores=%d", run_root, dry_run, cores))

safe_task <- function(task_row) {
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)
  dqlm.ind <- identical(model_name, "al")

  vb_file <- file.path(run_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))
  m_file <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))

  if (file.exists(m_file)) {
    log_task(model_name, tau, "resume skip: mcmc fit already exists")
    return(data.frame(model = model_name, tau = tau, status = "skipped_existing", mcmc_file = m_file, stringsAsFactors = FALSE))
  }
  if (!file.exists(vb_file)) {
    msg <- sprintf("missing VB fit file: %s", vb_file)
    write_status(model_name, tau, "FAILED", msg)
    return(data.frame(model = model_name, tau = tau, status = "failed", error = msg, stringsAsFactors = FALSE))
  }

  if (dry_run) {
    log_task(model_name, tau, "dry-run pending task")
    return(data.frame(model = model_name, tau = tau, status = "pending", vb_file = vb_file, stringsAsFactors = FALSE))
  }

  write_status(model_name, tau, "RESUME_MCMC_START", sprintf("seed=%d", seed))
  log_task(model_name, tau, sprintf("resume mcmc start seed=%d", seed))

  vb_obj <- readRDS(vb_file)
  vb_fit <- vb_obj$fit
  init_list <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = dqlm.ind)

  set.seed(seed + 700000L)
  t0 <- Sys.time()
  m_fit <- tryCatch(
    exal_static_mcmc(
      y = y,
      X = X,
      p0 = tau,
      dqlm.ind = dqlm.ind,
      init = init_list,
      init.from.vb = FALSE,
      n.burn = mcmc_burn,
      n.mcmc = mcmc_n,
      thin = mcmc_thin,
      mh.proposal = mcmc_mh_proposal,
      mh.adapt = mcmc_mh_adapt,
      mh.adapt.interval = mcmc_mh_adapt_interval,
      mh.target.accept = mcmc_mh_target,
      mh.scale.bounds = mcmc_mh_scale_bounds,
      mh.max_scale.step = mcmc_mh_max_scale_step,
      mh.min_burn_adapt = mcmc_mh_min_burn_adapt,
      verbose = FALSE
    ),
    error = function(e) e
  )

  if (inherits(m_fit, "error")) {
    write_status(model_name, tau, "FAILED", conditionMessage(m_fit))
    log_task(model_name, tau, paste("resume failed:", conditionMessage(m_fit)))
    return(data.frame(model = model_name, tau = tau, status = "failed", error = conditionMessage(m_fit), stringsAsFactors = FALSE))
  }

  runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  norm <- .static_normalize_mcmc_fit(
    m_fit,
    model_name = model_name,
    tau = tau,
    run_settings = list(
      n_burn = mcmc_burn,
      n_mcmc = mcmc_n,
      thin = mcmc_thin,
      resumed = TRUE,
      mh = list(
        proposal = mcmc_mh_proposal,
        adapt = mcmc_mh_adapt,
        adapt_interval = mcmc_mh_adapt_interval,
        target_accept = mcmc_mh_target,
        scale_bounds = mcmc_mh_scale_bounds,
        max_scale_step = mcmc_mh_max_scale_step,
        min_burn_adapt = mcmc_mh_min_burn_adapt
      )
    )
  )

  saveRDS(
    list(
      fit = m_fit,
      normalized = norm,
      meta = list(model = model_name, tau = tau, seed = seed, runtime_sec = runtime, resumed = TRUE)
    ),
    m_file,
    compress = "xz"
  )

  write_status(
    model_name,
    tau,
    "MCMC_DONE",
    sprintf("runtime_sec=%.1f ess_sigma=%.2f ess_gamma=%.2f", runtime, norm$diagnostics$ess$sigma, norm$diagnostics$ess$gamma)
  )
  log_task(model_name, tau, sprintf("resume mcmc done runtime=%.1fs", runtime))

  data.frame(
    model = model_name,
    tau = tau,
    status = "done",
    runtime_sec = runtime,
    ess_sigma = norm$diagnostics$ess$sigma,
    ess_gamma = norm$diagnostics$ess$gamma,
    mcmc_file = m_file,
    stringsAsFactors = FALSE
  )
}

task_list <- split(tasks, seq_len(nrow(tasks)))
out <- if (.Platform$OS.type == "unix" && cores > 1L) {
  parallel::mclapply(task_list, safe_task, mc.cores = cores, mc.preschedule = FALSE)
} else {
  lapply(task_list, safe_task)
}
bind_rows_fill <- function(lst) {
  cols <- unique(unlist(lapply(lst, names)))
  aligned <- lapply(lst, function(df) {
    miss <- setdiff(cols, names(df))
    if (length(miss)) for (m in miss) df[[m]] <- NA
    df[, cols, drop = FALSE]
  })
  do.call(rbind, aligned)
}
resume_df <- bind_rows_fill(out)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
resume_csv <- file.path(run_root, "tables", sprintf("pipeline_task_summary_resume_static_%s.csv", stamp))
utils::write.csv(resume_df, resume_csv, row.names = FALSE)

log_master(sprintf("static resume complete | summary=%s", resume_csv))
cat(sprintf("Static resume complete. Summary: %s\n", resume_csv))
