#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(parallel)
})

devtools::load_all(".", quiet = TRUE)

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

safe_bool <- function(x, default = FALSE) {
  x <- tolower(trimws(as.character(x)[1]))
  if (!nzchar(x) || is.na(x)) return(default)
  if (x %in% c("1", "true", "t", "yes", "y")) return(TRUE)
  if (x %in% c("0", "false", "f", "no", "n")) return(FALSE)
  default
}

safe_num_vec <- function(x, default = NULL, length_out = NA_integer_) {
  if (!nzchar(x)) return(default)
  parts <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  vals <- suppressWarnings(as.numeric(parts))
  if (any(!is.finite(vals))) return(default)
  if (is.finite(length_out) && length(vals) != length_out) return(default)
  vals
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

sim_path <- Sys.getenv(
  "EXDQLM_STATIC_SIM_PATH",
  "results/sim_suite_static/series/static_exal_rich1d_mcq/sim_output.rds"
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
vb_tol_sigma <- safe_num(Sys.getenv("EXDQLM_STATIC_VB_TOL_SIGMA", format(vb_tol, scientific = FALSE)), vb_tol)
vb_tol_gamma <- safe_num(Sys.getenv("EXDQLM_STATIC_VB_TOL_GAMMA", format(vb_tol, scientific = FALSE)), vb_tol)
vb_tol_elbo_default <- max(1e-5, vb_tol / 10)
vb_tol_elbo <- safe_num(
  Sys.getenv("EXDQLM_STATIC_VB_TOL_ELBO", format(vb_tol_elbo_default, scientific = FALSE)),
  vb_tol_elbo_default
)
vb_min_iter <- safe_int(Sys.getenv("EXDQLM_STATIC_VB_MIN_ITER", "10"), 10L)
if (vb_min_iter < 1L) vb_min_iter <- 10L
vb_patience <- safe_int(Sys.getenv("EXDQLM_STATIC_VB_PATIENCE", "3"), 3L)
if (vb_patience < 1L) vb_patience <- 3L
vb_allow_elbo_drop <- safe_num(
  Sys.getenv("EXDQLM_STATIC_VB_ALLOW_ELBO_DROP", format(vb_tol_elbo, scientific = FALSE)),
  vb_tol_elbo
)
vb_n_samp_xi <- safe_int(Sys.getenv("EXDQLM_STATIC_VB_NSAMP", "1000"), 1000L)
vb_ld_xi_method <- tolower(Sys.getenv("EXDQLM_STATIC_LD_XI_METHOD", "delta"))
if (!(vb_ld_xi_method %in% c("delta", "mc"))) vb_ld_xi_method <- "delta"
vb_ld_optimizer_method <- tolower(Sys.getenv("EXDQLM_STATIC_LD_OPTIMIZER_METHOD", "lbfgsb"))
if (!(vb_ld_optimizer_method %in% c("lbfgsb", "bfgs"))) vb_ld_optimizer_method <- "lbfgsb"
vb_ld_direct_commit <- safe_bool(Sys.getenv("EXDQLM_STATIC_LD_DIRECT_COMMIT", "true"), TRUE)
vb_ld_damping <- safe_num(
  Sys.getenv("EXDQLM_STATIC_LD_DAMPING", if (vb_ld_direct_commit) "1" else "0.45"),
  if (vb_ld_direct_commit) 1 else 0.45
)
vb_ld_xi_damping <- safe_num(
  Sys.getenv("EXDQLM_STATIC_LD_XI_DAMPING", if (vb_ld_xi_method == "delta") "1" else "0.65"),
  if (vb_ld_xi_method == "delta") 1 else 0.65
)
vb_ld_xi_mode <- tolower(Sys.getenv("EXDQLM_STATIC_LD_XI_MODE", "single"))
if (!(vb_ld_xi_mode %in% c("single", "replicated"))) vb_ld_xi_mode <- "single"
vb_ld_xi_replicates <- safe_int(Sys.getenv("EXDQLM_STATIC_LD_XI_REPLICATES", "1"), 1L)
if (vb_ld_xi_mode == "single") vb_ld_xi_replicates <- 1L
if (vb_ld_xi_method == "delta") vb_ld_xi_replicates <- 0L
vb_ld_reuse_draws <- safe_bool(Sys.getenv("EXDQLM_STATIC_LD_REUSE_DRAWS", "true"), TRUE)
vb_ld_antithetic <- safe_bool(Sys.getenv("EXDQLM_STATIC_LD_ANTITHETIC", "true"), TRUE)
vb_ld_reuse_seed <- safe_int(Sys.getenv("EXDQLM_STATIC_LD_REUSE_SEED", "20260305"), 20260305L)
vb_ld_step_cap_eta <- safe_num(
  Sys.getenv("EXDQLM_STATIC_LD_STEP_CAP_ETA", if (vb_ld_direct_commit) "Inf" else "2.0"),
  if (vb_ld_direct_commit) Inf else 2.0
)
vb_ld_step_cap_ell <- safe_num(
  Sys.getenv("EXDQLM_STATIC_LD_STEP_CAP_ELL", if (vb_ld_direct_commit) "Inf" else "0.75"),
  if (vb_ld_direct_commit) Inf else 0.75
)
vb_ld_eig_floor <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_EIG_FLOOR", "1e-6"), 1e-6)
vb_ld_eig_cap <- safe_num(
  Sys.getenv(
    "EXDQLM_STATIC_LD_EIG_CAP",
    if (vb_ld_direct_commit && vb_ld_xi_method == "delta") "1" else "25"
  ),
  if (vb_ld_direct_commit && vb_ld_xi_method == "delta") 1 else 25
)
vb_ld_optimizer_maxit <- safe_int(
  Sys.getenv("EXDQLM_STATIC_LD_OPTIMIZER_MAXIT", if (vb_ld_optimizer_method == "lbfgsb") "2000" else "200"),
  if (vb_ld_optimizer_method == "lbfgsb") 2000L else 200L
)
vb_ld_eta_lo <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_ETA_LO", "-12"), -12)
vb_ld_eta_hi <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_ETA_HI", "12"), 12)
vb_ld_sigma_bounds <- safe_num_vec(Sys.getenv("EXDQLM_STATIC_LD_SIGMA_BOUNDS", ""), default = NULL, length_out = 2L)
vb_ld_sigma_init_mode <- tolower(Sys.getenv("EXDQLM_STATIC_LD_SIGMA_INIT_MODE", "data_scale"))
if (!(vb_ld_sigma_init_mode %in% c("data_scale", "fixed1"))) vb_ld_sigma_init_mode <- "data_scale"
vb_ld_sigma_floor_abs <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_SIGMA_FLOOR_ABS", "1e-6"), 1e-6)
vb_ld_sigma_min_mult <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_SIGMA_MIN_MULT", "1e-3"), 1e-3)
vb_ld_sigma_max_mult <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_SIGMA_MAX_MULT", "1e3"), 1e3)
vb_ld_sigma_bound_ratio_min <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_SIGMA_BOUND_RATIO_MIN", "10"), 10)
vb_ld_gamma_init_pad_frac <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_GAMMA_INIT_PAD_FRAC", "0.05"), 0.05)
vb_ld_logit_eps <- safe_num(Sys.getenv("EXDQLM_STATIC_LD_LOGIT_EPS", "1e-8"), 1e-8)
vb_ld_init_cov_diag <- safe_num_vec(
  Sys.getenv("EXDQLM_STATIC_LD_INIT_COV_DIAG", "1e-2,1e-2"),
  default = c(1e-2, 1e-2),
  length_out = 2L
)
vb_ld_profile_name <- Sys.getenv("EXDQLM_STATIC_LD_PROFILE_NAME", "manual")

mcmc_burn <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_BURN", "2000"), 2000L)
mcmc_n <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_N", "1000"), 1000L)
mcmc_thin <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_THIN", "1"), 1L)
mcmc_mh_proposal <- tolower(Sys.getenv("EXDQLM_STATIC_MCMC_MH_PROPOSAL", "laplace_rw"))
if (!(mcmc_mh_proposal %in% c("laplace_local", "laplace_rw", "rw"))) mcmc_mh_proposal <- "laplace_rw"
mcmc_mh_adapt <- identical(tolower(Sys.getenv("EXDQLM_STATIC_MCMC_MH_ADAPT", "true")), "true")
mcmc_mh_adapt_interval <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_MH_ADAPT_INTERVAL", "50"), 50L)
mcmc_mh_target_lo <- safe_num(Sys.getenv("EXDQLM_STATIC_MCMC_MH_TARGET_LO", "0.20"), 0.20)
mcmc_mh_target_hi <- safe_num(Sys.getenv("EXDQLM_STATIC_MCMC_MH_TARGET_HI", "0.45"), 0.45)
mcmc_mh_scale_min <- safe_num(Sys.getenv("EXDQLM_STATIC_MCMC_MH_SCALE_MIN", "0.1"), 0.1)
mcmc_mh_scale_max <- safe_num(Sys.getenv("EXDQLM_STATIC_MCMC_MH_SCALE_MAX", "10"), 10)
mcmc_mh_max_scale_step <- safe_num(Sys.getenv("EXDQLM_STATIC_MCMC_MH_MAX_SCALE_STEP", "0.35"), 0.35)
mcmc_mh_min_burn_adapt <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_MH_MIN_BURN_ADAPT", "50"), 50L)

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores_pipeline <- safe_int(Sys.getenv("EXDQLM_STATIC_PIPELINE_CORES", "6"), 6L)
cores_pipeline <- max(1L, min(cores_pipeline, n_core_phys))
overwrite_existing <- identical(tolower(Sys.getenv("EXDQLM_STATIC_PIPELINE_OVERWRITE", "false")), "true")

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
default_run_name <- sprintf(
  "static_vb_then_mcmc_tt%d_vbns%d_burn%d_n%d_%s",
  TT, vb_n_samp_xi, mcmc_burn, mcmc_n, stamp
)
run_label <- Sys.getenv("EXDQLM_STATIC_PIPELINE_LABEL", "")
if (nzchar(run_label)) {
  run_label <- gsub("[^A-Za-z0-9._-]+", "_", run_label)
  default_run_name <- paste(default_run_name, run_label, sep = "_")
}
out_root <- Sys.getenv(
  "EXDQLM_STATIC_OUT_ROOT",
  file.path("results/sim_suite_static", default_run_name)
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
  vb = list(
    max_iter = vb_max_iter,
    tol = vb_tol,
    conv = list(
      tol_sigma = vb_tol_sigma,
      tol_gamma = vb_tol_gamma,
      tol_elbo = vb_tol_elbo,
      min_iter = vb_min_iter,
      patience = vb_patience,
      allow_elbo_drop = vb_allow_elbo_drop
    ),
    n_samp_xi = vb_n_samp_xi,
    ld = list(
      xi_method = vb_ld_xi_method,
      optimizer_method = vb_ld_optimizer_method,
      direct_commit = vb_ld_direct_commit,
      damping = vb_ld_damping,
      xi_damping = vb_ld_xi_damping,
      xi_mode = vb_ld_xi_mode,
      xi_replicates = vb_ld_xi_replicates,
      reuse_draws = vb_ld_reuse_draws,
      antithetic = vb_ld_antithetic,
      reuse_seed = vb_ld_reuse_seed,
      step_cap_eta = vb_ld_step_cap_eta,
      step_cap_ell = vb_ld_step_cap_ell,
      eig_floor = vb_ld_eig_floor,
      eig_cap = vb_ld_eig_cap,
      eta_lo = vb_ld_eta_lo,
      eta_hi = vb_ld_eta_hi,
      sigma_bounds = vb_ld_sigma_bounds,
      sigma_init_mode = vb_ld_sigma_init_mode,
      sigma_floor_abs = vb_ld_sigma_floor_abs,
      sigma_min_mult = vb_ld_sigma_min_mult,
      sigma_max_mult = vb_ld_sigma_max_mult,
      sigma_bound_ratio_min = vb_ld_sigma_bound_ratio_min,
      gamma_init_pad_frac = vb_ld_gamma_init_pad_frac,
      logit_eps = vb_ld_logit_eps,
      init_cov_diag = vb_ld_init_cov_diag,
      optimizer_maxit = vb_ld_optimizer_maxit,
      profile_name = vb_ld_profile_name
    )
  ),
  mcmc = list(
    burn = mcmc_burn,
    n = mcmc_n,
    thin = mcmc_thin,
    mh = list(
      proposal = mcmc_mh_proposal,
      adapt = mcmc_mh_adapt,
      adapt_interval = mcmc_mh_adapt_interval,
      target_accept = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
      scale_bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
      max_scale_step = mcmc_mh_max_scale_step,
      min_burn_adapt = mcmc_mh_min_burn_adapt
    )
  )
)
saveRDS(cfg, file.path(out_root, "tables", "run_config.rds"))

old_vb_opts <- options(
  exdqlm.tol_sigma = vb_tol_sigma,
  exdqlm.tol_gamma = vb_tol_gamma,
  exdqlm.tol_elbo = vb_tol_elbo,
  exdqlm.vb.min_iter = vb_min_iter,
  exdqlm.vb.patience = vb_patience,
  exdqlm.vb.allow_elbo_drop = vb_allow_elbo_drop
)
on.exit(options(old_vb_opts), add = TRUE)

empty_summary_row <- function(model_name, tau, status = "pending", error = NA_character_) {
  data.frame(
    model = as.character(model_name),
    tau = as.numeric(tau),
    status = as.character(status),
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
    accept_rate_burn = NA_real_,
    accept_rate_keep = NA_real_,
    mcmc_mh_proposal = NA_character_,
    mcmc_gamma_kernel_exact = NA,
    mcmc_signoff_ready = NA,
    mcmc_mh_adapt = NA,
    mcmc_mh_scale_initial = NA_real_,
    mcmc_mh_scale_final = NA_real_,
    vb_file = NA_character_,
    mcmc_file = NA_character_,
    error = as.character(error)[1],
    stringsAsFactors = FALSE
  )
}

normalize_vb_wrap <- function(vb_obj, model_name, tau) {
  vb_fit <- vb_obj$fit
  vb_norm <- vb_obj$normalized
  if (is.null(vb_norm) || is.null(vb_norm$diagnostics$ld_block$mode_quality)) {
    vb_norm <- .static_normalize_vb_fit(vb_fit, model_name = model_name, tau = tau)
  }
  list(
    fit = vb_fit,
    normalized = vb_norm,
    runtime_sec = if (!is.null(vb_obj$meta$runtime_sec)) as.numeric(vb_obj$meta$runtime_sec)[1] else NA_real_
  )
}

normalize_mcmc_wrap <- function(m_obj, model_name, tau) {
  m_fit <- m_obj$fit
  m_norm <- m_obj$normalized
  if (is.null(m_norm) || is.null(m_norm$diagnostics$mh$kernel_exact)) {
    m_norm <- .static_normalize_mcmc_fit(m_fit, model_name = model_name, tau = tau)
  }
  list(
    fit = m_fit,
    normalized = m_norm,
    runtime_sec = if (!is.null(m_obj$meta$runtime_sec)) as.numeric(m_obj$meta$runtime_sec)[1] else NA_real_
  )
}

populate_vb_summary <- function(row, vb_norm, vb_runtime, vb_file) {
  row$vb_runtime_sec <- as.numeric(vb_runtime)[1]
  row$vb_iter <- if (!is.null(vb_norm$iter)) as.integer(vb_norm$iter)[1] else NA_integer_
  row$vb_converged <- if (!is.null(vb_norm$converged)) isTRUE(vb_norm$converged) else NA
  row$vb_stop_reason <- if (!is.null(vb_norm$stop_reason)) as.character(vb_norm$stop_reason)[1] else NA_character_
  row$vb_sigma <- as.numeric(vb_norm$sigma_est)[1]
  row$vb_gamma <- as.numeric(vb_norm$gamma_est)[1]
  row$vb_file <- as.character(vb_file)[1]
  row
}

populate_mcmc_summary <- function(row, m_norm, m_runtime, m_file) {
  row$mcmc_runtime_sec <- as.numeric(m_runtime)[1]
  row$mcmc_sigma_mean <- as.numeric(m_norm$sigma_est)[1]
  row$mcmc_gamma_mean <- as.numeric(m_norm$gamma_est)[1]
  row$ess_sigma <- as.numeric(m_norm$diagnostics$ess$sigma)[1]
  row$ess_gamma <- as.numeric(m_norm$diagnostics$ess$gamma)[1]
  row$accept_rate <- as.numeric(m_norm$diagnostics$acceptance$total)[1]
  row$accept_rate_burn <- as.numeric(m_norm$diagnostics$acceptance$burn)[1]
  row$accept_rate_keep <- as.numeric(m_norm$diagnostics$acceptance$keep)[1]
  row$mcmc_mh_proposal <- as.character(m_norm$diagnostics$mh$proposal)[1]
  row$mcmc_gamma_kernel_exact <- isTRUE(m_norm$diagnostics$mh$kernel_exact)
  row$mcmc_signoff_ready <- isTRUE(m_norm$diagnostics$mh$signoff_ready)
  row$mcmc_mh_adapt <- if (!is.null(m_norm$diagnostics$mh$adapt)) isTRUE(m_norm$diagnostics$mh$adapt) else NA
  row$mcmc_mh_scale_initial <- as.numeric(m_norm$diagnostics$mh$scale_initial)[1]
  row$mcmc_mh_scale_final <- as.numeric(m_norm$diagnostics$mh$scale_final)[1]
  row$mcmc_file <- as.character(m_file)[1]
  row
}

summary_from_existing_fits <- function(model_name, tau, vb_file, m_file, status = "skipped_existing") {
  row <- empty_summary_row(model_name, tau, status = status)
  if (file.exists(vb_file)) {
    vb_dat <- normalize_vb_wrap(readRDS(vb_file), model_name, tau)
    row <- populate_vb_summary(row, vb_dat$normalized, vb_dat$runtime_sec, vb_file)
  }
  if (file.exists(m_file)) {
    m_dat <- normalize_mcmc_wrap(readRDS(m_file), model_name, tau)
    row <- populate_mcmc_summary(row, m_dat$normalized, m_dat$runtime_sec, m_file)
  }
  row
}

run_one_pipeline <- function(task_row) {
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)
  dqlm.ind <- identical(model_name, "al")
  row <- empty_summary_row(model_name, tau)
  ld_ctrl <- if (!dqlm.ind) {
    list(
      xi_method = vb_ld_xi_method,
      optimizer_method = vb_ld_optimizer_method,
      direct_commit = vb_ld_direct_commit,
      damping = vb_ld_damping,
      xi_damping = vb_ld_xi_damping,
      xi_mode = vb_ld_xi_mode,
      xi_replicates = vb_ld_xi_replicates,
      reuse_draws = vb_ld_reuse_draws,
      antithetic = vb_ld_antithetic,
      reuse_seed = vb_ld_reuse_seed,
      step_cap_eta = vb_ld_step_cap_eta,
      step_cap_ell = vb_ld_step_cap_ell,
      eig_floor = vb_ld_eig_floor,
      eig_cap = vb_ld_eig_cap,
      eta_lo = vb_ld_eta_lo,
      eta_hi = vb_ld_eta_hi,
      sigma_bounds = vb_ld_sigma_bounds,
      sigma_init_mode = vb_ld_sigma_init_mode,
      sigma_floor_abs = vb_ld_sigma_floor_abs,
      sigma_min_mult = vb_ld_sigma_min_mult,
      sigma_max_mult = vb_ld_sigma_max_mult,
      sigma_bound_ratio_min = vb_ld_sigma_bound_ratio_min,
      gamma_init_pad_frac = vb_ld_gamma_init_pad_frac,
      logit_eps = vb_ld_logit_eps,
      init_cov_diag = vb_ld_init_cov_diag,
      optimizer_maxit = vb_ld_optimizer_maxit,
      profile_name = vb_ld_profile_name
    )
  } else {
    NULL
  }

  write_status(model_name, tau, "START", sprintf("seed=%d", seed))
  log_task(model_name, tau, sprintf("start pipeline model=%s tau=%.2f", model_name, tau))

  vb_file <- file.path(out_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))
  m_file <- file.path(out_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))

  if (!overwrite_existing && file.exists(m_file)) {
    write_status(model_name, tau, "SKIP_EXISTING", "mcmc fit already exists")
    log_task(model_name, tau, "skip existing: mcmc fit already exists")
    return(summary_from_existing_fits(model_name, tau, vb_file, m_file, status = "skipped_existing"))
  }

  set.seed(seed)
  if (!overwrite_existing && file.exists(vb_file)) {
    vb_dat <- normalize_vb_wrap(readRDS(vb_file), model_name, tau)
    vb_fit <- vb_dat$fit
    vb_norm <- vb_dat$normalized
    vb_runtime <- vb_dat$runtime_sec
    row <- populate_vb_summary(row, vb_norm, vb_runtime, vb_file)
    write_status(model_name, tau, "VB_EXISTING", sprintf("iter=%s stop=%s", row$vb_iter, row$vb_stop_reason))
    log_task(model_name, tau, "reuse existing vb fit")
  } else {
    vb_t0 <- Sys.time()
    write_status(model_name, tau, "VB_START")

    vb_fit <- tryCatch(
      exal_static_LDVB(
        y = y,
        X = X,
        p0 = tau,
        max_iter = vb_max_iter,
        tol = vb_tol,
        dqlm.ind = dqlm.ind,
        n_samp_xi = vb_n_samp_xi,
        ld_controls = ld_ctrl,
        verbose = FALSE
      ),
      error = function(e) e
    )
    if (inherits(vb_fit, "error")) {
      row$status <- "failed"
      row$error <- conditionMessage(vb_fit)
      write_status(model_name, tau, "FAILED", row$error)
      log_task(model_name, tau, paste("vb failed:", row$error))
      return(row)
    }
    vb_runtime <- as.numeric(difftime(Sys.time(), vb_t0, units = "secs"))
    vb_norm <- .static_normalize_vb_fit(
      vb_fit,
      model_name = model_name,
      tau = tau,
      run_settings = list(max_iter = vb_max_iter, tol = vb_tol, n_samp_xi = vb_n_samp_xi, ld = ld_ctrl)
    )
    row <- populate_vb_summary(row, vb_norm, vb_runtime, vb_file)

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
  }

  init_list <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = dqlm.ind)

  m_t0 <- Sys.time()
  write_status(model_name, tau, "MCMC_START")
  set.seed(seed + 1234L)

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
      mh.target.accept = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
      mh.scale.bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
      mh.max_scale.step = mcmc_mh_max_scale_step,
      mh.min_burn_adapt = mcmc_mh_min_burn_adapt,
      verbose = FALSE
    ),
    error = function(e) e
  )
  if (inherits(m_fit, "error")) {
    row$status <- "failed"
    row$error <- conditionMessage(m_fit)
    write_status(model_name, tau, "FAILED", row$error)
    log_task(model_name, tau, paste("mcmc failed:", row$error))
    return(row)
  }

  m_runtime <- as.numeric(difftime(Sys.time(), m_t0, units = "secs"))
  m_norm <- .static_normalize_mcmc_fit(
    m_fit,
    model_name = model_name,
    tau = tau,
    run_settings = list(
      n_burn = mcmc_burn,
      n_mcmc = mcmc_n,
      thin = mcmc_thin,
      mh = list(
        proposal = mcmc_mh_proposal,
        adapt = mcmc_mh_adapt,
        adapt_interval = mcmc_mh_adapt_interval,
        target_accept = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
        scale_bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max)
      )
    )
  )

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
    sprintf(
      "runtime_sec=%.1f ess_sigma=%.2f ess_gamma=%.2f kernel=%s",
      m_runtime, m_norm$diagnostics$ess$sigma, m_norm$diagnostics$ess$gamma, m_norm$diagnostics$mh$proposal
    )
  )
  log_task(model_name, tau, sprintf("mcmc done runtime=%.1fs", m_runtime))

  row <- populate_mcmc_summary(row, m_norm, m_runtime, m_file)
  row$status <- "done"
  row
}

tasks <- expand.grid(
  model = c("exal", "al"),
  tau = p_vec,
  stringsAsFactors = FALSE
)
tasks$seed <- 202603050L + seq_len(nrow(tasks)) * 1000L

log_master(sprintf("starting static VB->MCMC pipeline run in %s", out_root))
log_master(sprintf(
  paste0(
    "TT=%d VB(max_iter=%d,tol=%.4f,tol_sigma=%.4g,tol_gamma=%.4g,tol_elbo=%.4g,min_iter=%d,patience=%d,",
    "allow_elbo_drop=%.4g,n_samp_xi=%d,xi=%s,opt=%s,direct=%s,",
    "ld_damp=%s,ld_xi_damp=%s,sigma_init=%s,eta=[%.1f,%.1f]) ",
    "MCMC(burn=%d,n=%d,thin=%d,mh=%s) cores=%d overwrite=%s"
  ),
  TT, vb_max_iter, vb_tol, vb_tol_sigma, vb_tol_gamma, vb_tol_elbo, vb_min_iter, vb_patience, vb_allow_elbo_drop,
  vb_n_samp_xi, vb_ld_xi_method, vb_ld_optimizer_method, vb_ld_direct_commit,
  format(vb_ld_damping, trim = TRUE), format(vb_ld_xi_damping, trim = TRUE), vb_ld_sigma_init_mode, vb_ld_eta_lo, vb_ld_eta_hi,
  mcmc_burn, mcmc_n, mcmc_thin, mcmc_mh_proposal, cores_pipeline, overwrite_existing
))
log_master(sprintf("models=%s taus=%s", paste(unique(tasks$model), collapse = ","), paste(sprintf("%.2f", p_vec), collapse = ",")))

safe_task <- function(task_row) {
  tryCatch(
    run_one_pipeline(task_row),
    error = function(e) {
      model_name <- as.character(task_row$model)
      tau <- as.numeric(task_row$tau)
      row <- empty_summary_row(model_name, tau, status = "failed", error = conditionMessage(e))
      write_status(model_name, tau, "FAILED", conditionMessage(e))
      log_task(model_name, tau, paste("failed:", conditionMessage(e)))
      row
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
