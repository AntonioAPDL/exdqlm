#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(Matrix)
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
source("tools/merge_reports/20260305_dynamic_dgp_model_helpers.R")

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_bool <- function(x, default = FALSE) {
  z <- tolower(trimws(as.character(x)[1]))
  if (z %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (z %in% c("false", "f", "0", "no", "n")) return(FALSE)
  default
}

safe_num_vec <- function(x, default = NULL, length_out = NULL) {
  if (!nzchar(x)) return(default)
  vals <- suppressWarnings(as.numeric(strsplit(x, ",", fixed = TRUE)[[1]]))
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(default)
  if (!is.null(length_out) && length(vals) != length_out) return(default)
  vals
}

safe_chr_vec <- function(x, default = NULL) {
  if (!nzchar(x)) return(default)
  vals <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  vals <- vals[nzchar(vals)]
  if (!length(vals)) return(default)
  vals
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

sanitize_exps0 <- function(x, fallback) {
  z <- as.numeric(x)
  if (length(z) != length(fallback)) z <- rep(stats::median(fallback), length(fallback))
  z[!is.finite(z)] <- stats::median(fallback)
  z
}

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

sim_path <- Sys.getenv("EXDQLM_DYNAMIC_SIM_PATH", "results/sim_suite_dlm/series/dlm_constV_smallW/sim_output.rds")
if (!file.exists(sim_path)) stop("Simulation file not found: ", sim_path)
sim <- readRDS(sim_path)

TT_full <- length(sim$y)
TT <- min(TT_full, max(200L, safe_int(Sys.getenv("EXDQLM_PIPELINE_TT", "5000"), 5000L)))
y <- as.numeric(sim$y[seq_len(TT)])
mu_true <- if (!is.null(sim$extras$mu)) as.numeric(sim$extras$mu[seq_len(TT)]) else rep(NA_real_, TT)

sim_taus <- if (!is.null(sim$p)) as.numeric(sim$p) else numeric(0)
sim_taus <- sim_taus[is.finite(sim_taus)]
p_vec_env <- safe_num_vec(Sys.getenv("EXDQLM_DYNAMIC_PIPELINE_TAUS", ""), default = NULL)
p_tau_single <- safe_num_vec(Sys.getenv("EXDQLM_DYNAMIC_PIPELINE_TAU", ""), default = NULL, length_out = 1L)
if (!is.null(p_vec_env)) {
  p_vec <- p_vec_env
} else if (!is.null(p_tau_single)) {
  p_vec <- p_tau_single
} else if (length(sim_taus)) {
  p_vec <- sim_taus
} else {
  p_vec <- c(0.05, 0.25, 0.95)
}
p_vec <- unique(as.numeric(p_vec))
p_vec <- p_vec[is.finite(p_vec) & p_vec > 0 & p_vec < 1]
if (!length(p_vec)) stop("No valid taus resolved for dynamic pipeline.")
if (!is.null(sim$q)) {
  q_mat_check <- as.matrix(sim$q)
  if (nrow(q_mat_check) >= TT && ncol(q_mat_check) == 1L && length(p_vec) != 1L) {
    stop("Quantile-specific dynamic simulation has one truth column but pipeline resolved ", length(p_vec), " taus. Set EXDQLM_DYNAMIC_PIPELINE_TAU(S) consistently or use sim$p length 1.")
  }
}
df_base <- safe_num(Sys.getenv("EXDQLM_DF_BASE", "0.98"), 0.98)
df_candidate_vals <- sort(unique(c(df_base, 0.995, 0.999)))
df_candidate_list <- lapply(df_candidate_vals, function(v) rep(v, 3))
dim_df <- c(2, 2, 2)

vb_tol <- safe_num(Sys.getenv("EXDQLM_VB_TOL", "0.03"), 0.03)
vb_n_samp <- safe_int(Sys.getenv("EXDQLM_VB_NSAMP", "1000"), 1000L)
vb_max_iter <- safe_int(Sys.getenv("EXDQLM_VB_MAX_ITER", "300"), 300L)
vb_tol_sigma <- safe_num(Sys.getenv("EXDQLM_VB_TOL_SIGMA", "0.02"), 0.02)
vb_tol_gamma <- safe_num(Sys.getenv("EXDQLM_VB_TOL_GAMMA", "0.01"), 0.01)
vb_tol_elbo <- safe_num(Sys.getenv("EXDQLM_VB_TOL_ELBO", "5"), 5)
vb_min_iter <- safe_int(Sys.getenv("EXDQLM_VB_MIN_ITER", "30"), 30L)
vb_patience <- safe_int(Sys.getenv("EXDQLM_VB_PATIENCE", "5"), 5L)
vb_allow_elbo_drop <- safe_num(Sys.getenv("EXDQLM_VB_ALLOW_ELBO_DROP", "5"), 5)
vb_ld_optimizer_method <- tolower(Sys.getenv("EXDQLM_DYNAMIC_LD_OPTIMIZER_METHOD", "lbfgsb"))
if (!(vb_ld_optimizer_method %in% c("lbfgsb", "bfgs"))) vb_ld_optimizer_method <- "lbfgsb"
vb_ld_direct_commit <- safe_bool(Sys.getenv("EXDQLM_DYNAMIC_LD_DIRECT_COMMIT", if (vb_ld_optimizer_method == "lbfgsb") "true" else "false"), vb_ld_optimizer_method == "lbfgsb")
vb_ld_damping <- safe_num(Sys.getenv("EXDQLM_DYNAMIC_LD_DAMPING", if (vb_ld_direct_commit) "1" else "0.45"), if (vb_ld_direct_commit) 1 else 0.45)
vb_ld_eig_floor <- safe_num(Sys.getenv("EXDQLM_DYNAMIC_LD_EIG_FLOOR", "1e-6"), 1e-6)
vb_ld_eig_cap <- safe_num(Sys.getenv("EXDQLM_DYNAMIC_LD_EIG_CAP", if (vb_ld_direct_commit) "1" else "25"), if (vb_ld_direct_commit) 1 else 25)
vb_ld_eta_lo <- safe_num(Sys.getenv("EXDQLM_DYNAMIC_LD_ETA_LO", "-12"), -12)
vb_ld_eta_hi <- safe_num(Sys.getenv("EXDQLM_DYNAMIC_LD_ETA_HI", "12"), 12)
vb_ld_sigma_bounds <- safe_num_vec(Sys.getenv("EXDQLM_DYNAMIC_LD_SIGMA_BOUNDS", ""), default = NULL, length_out = 2L)
vb_ld_sigma_init_mode <- tolower(Sys.getenv("EXDQLM_DYNAMIC_LD_SIGMA_INIT_MODE", "data_scale"))
if (!(vb_ld_sigma_init_mode %in% c("data_scale", "fixed1"))) vb_ld_sigma_init_mode <- "data_scale"
vb_ld_init_cov_diag <- safe_num_vec(Sys.getenv("EXDQLM_DYNAMIC_LD_INIT_COV_DIAG", "1e-2,1e-2"), default = c(1e-2, 1e-2), length_out = 2L)
vb_ld_store_trace <- safe_bool(Sys.getenv("EXDQLM_DYNAMIC_LD_STORE_TRACE", "true"), TRUE)

mcmc_burn <- safe_int(Sys.getenv("EXDQLM_MCMC_BURN", "2000"), 2000L)
mcmc_n <- safe_int(Sys.getenv("EXDQLM_MCMC_N", "1000"), 1000L)
mcmc_mh_adapt_interval <- safe_int(Sys.getenv("EXDQLM_MCMC_MH_ADAPT_INTERVAL", "25"), 25L)
mcmc_mh_target_lo <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_TARGET_LO", "0.25"), 0.25)
mcmc_mh_target_hi <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_TARGET_HI", "0.55"), 0.55)
mcmc_mh_scale_min <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_SCALE_MIN", "0.02"), 0.02)
mcmc_mh_scale_max <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_SCALE_MAX", "2.5"), 2.5)
mcmc_mh_max_scale_step <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_MAX_SCALE_STEP", "0.5"), 0.5)
mcmc_mh_min_burn_adapt <- safe_int(Sys.getenv("EXDQLM_MCMC_MH_MIN_BURN_ADAPT", "25"), 25L)
mcmc_primary_proposal <- tolower(Sys.getenv("EXDQLM_MCMC_PRIMARY_PROPOSAL", "laplace_rw"))
if (!(mcmc_primary_proposal %in% c("laplace_rw", "rw"))) mcmc_primary_proposal <- "laplace_rw"
mcmc_primary_joint_sample <- identical(tolower(Sys.getenv("EXDQLM_MCMC_PRIMARY_JOINT_SAMPLE", "false")), "true")

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores_pipeline <- safe_int(Sys.getenv("EXDQLM_PIPELINE_CORES", "6"), 6L)
cores_pipeline <- max(1L, min(cores_pipeline, n_core_phys))
model_filter <- safe_chr_vec(Sys.getenv("EXDQLM_DYNAMIC_PIPELINE_MODELS", ""), default = c("exdqlm", "dqlm"))
model_filter <- unique(tolower(model_filter))
model_filter <- model_filter[model_filter %in% c("exdqlm", "dqlm")]
if (!length(model_filter)) stop("No valid EXDQLM_DYNAMIC_PIPELINE_MODELS resolved.")

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
default_run_name <- sprintf(
  "rerun_vb_then_mcmc_tt%d_vbns%d_burn%d_n%d_%s",
  TT, vb_n_samp, mcmc_burn, mcmc_n, stamp
)
run_label <- Sys.getenv("EXDQLM_DYNAMIC_PIPELINE_LABEL", "")
if (nzchar(run_label)) {
  run_label <- gsub("[^A-Za-z0-9._-]+", "_", run_label)
  default_run_name <- paste(default_run_name, run_label, sep = "_")
}
out_root <- Sys.getenv(
  "EXDQLM_DYNAMIC_OUT_ROOT",
  file.path("results/function_testing_20260304_vb_quantiles", default_run_name)
)

for (d in c("fits/vb", "fits/mcmc", "logs", "tables")) {
  dir.create(file.path(out_root, d), recursive = TRUE, showWarnings = FALSE)
}

master_log <- file.path(out_root, "logs", "master.log")
status_dir <- file.path(out_root, "logs")

log_master <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = master_log, append = TRUE)
  flush.console()
}

task_key <- function(model_name, tau) sprintf("%s_tau_%s", model_name, tau_lab(tau))
task_log_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".log"))
task_status_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".status.tsv"))

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
  df_candidates = df_candidate_vals,
  cores_pipeline = cores_pipeline,
  vb = list(
    tol = vb_tol,
    n_samp = vb_n_samp,
    max_iter = vb_max_iter,
    tol_sigma = vb_tol_sigma,
    tol_gamma = vb_tol_gamma,
    tol_elbo = vb_tol_elbo,
    min_iter = vb_min_iter,
    patience = vb_patience,
    allow_elbo_drop = vb_allow_elbo_drop,
    ld = list(
      optimizer_method = vb_ld_optimizer_method,
      direct_commit = vb_ld_direct_commit,
      damping = vb_ld_damping,
      eig_floor = vb_ld_eig_floor,
      eig_cap = vb_ld_eig_cap,
      eta_bounds = c(vb_ld_eta_lo, vb_ld_eta_hi),
      sigma_bounds = vb_ld_sigma_bounds,
      sigma_init_mode = vb_ld_sigma_init_mode,
      init_cov_diag = vb_ld_init_cov_diag,
      store_trace = vb_ld_store_trace
    )
  ),
  mcmc = list(
    burn = mcmc_burn,
    n = mcmc_n,
    mh = list(
      adapt_interval = mcmc_mh_adapt_interval,
      target_accept = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
      scale_bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
      max_scale_step = mcmc_mh_max_scale_step,
      min_burn_adapt = mcmc_mh_min_burn_adapt,
      primary_proposal = mcmc_primary_proposal,
      primary_joint_sample = mcmc_primary_joint_sample
    )
  )
)
saveRDS(cfg, file.path(out_root, "tables", "run_config.rds"))

model <- build_dynamic_dgp_matched_model(sim$info$params, TT = TT)

old_opts <- options(
  exdqlm.use_cpp_kf = FALSE,
  exdqlm.compute_elbo = TRUE,
  exdqlm.use_cpp_samplers = FALSE,
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.use_cpp_mcmc = TRUE,
  exdqlm.cpp_mcmc_mode = "fast",
  exdqlm.max_iter = vb_max_iter,
  exdqlm.tol_sigma = vb_tol_sigma,
  exdqlm.tol_gamma = vb_tol_gamma,
  exdqlm.tol_elbo = vb_tol_elbo,
  exdqlm.vb.min_iter = vb_min_iter,
  exdqlm.vb.patience = vb_patience,
  exdqlm.vb.allow_elbo_drop = vb_allow_elbo_drop,
  exdqlm.dynamic.ldvb.optimizer_method = vb_ld_optimizer_method,
  exdqlm.dynamic.ldvb.direct_commit = vb_ld_direct_commit,
  exdqlm.dynamic.ldvb.damping = vb_ld_damping,
  exdqlm.dynamic.ldvb.eig_floor = vb_ld_eig_floor,
  exdqlm.dynamic.ldvb.eig_cap = vb_ld_eig_cap,
  exdqlm.dynamic.ldvb.eta_lo = vb_ld_eta_lo,
  exdqlm.dynamic.ldvb.eta_hi = vb_ld_eta_hi,
  exdqlm.dynamic.ldvb.sigma_bounds = vb_ld_sigma_bounds,
  exdqlm.dynamic.ldvb.sigma_init_mode = vb_ld_sigma_init_mode,
  exdqlm.dynamic.ldvb.init_cov_diag = vb_ld_init_cov_diag,
  exdqlm.dynamic.ldvb.store_trace = vb_ld_store_trace
)
on.exit(options(old_opts), add = TRUE)

exps0_candidates <- list(
  if (all(is.finite(mu_true))) mu_true else rep(stats::median(y), TT),
  stats::filter(y, rep(1 / 9, 9), sides = 1),
  rep(stats::median(y), TT)
)

fit_vb_safe <- function(model_name, tau, seed) {
  dqlm_flag <- identical(model_name, "dqlm")
  errs <- character(0)
  for (df_try in df_candidate_list) {
    for (j in seq_along(exps0_candidates)) {
      exps0_try <- sanitize_exps0(exps0_candidates[[j]], y)
      set.seed(seed + 100L * j + as.integer(round(1000 * df_try[1])))
      fit_try <- tryCatch(
        exdqlmLDVB(
          y = y,
          p0 = tau,
          model = model,
          df = df_try,
          dim.df = dim_df,
          dqlm.ind = dqlm_flag,
          exps0 = exps0_try,
          fix.sigma = FALSE,
          tol = vb_tol,
          n.samp = vb_n_samp,
          verbose = FALSE
        ),
        error = function(e) e
      )
      if (!inherits(fit_try, "error")) {
        return(list(fit = fit_try, df_used = as.numeric(df_try[1]), init_id = j))
      }
      errs <- c(errs, sprintf("df=%.4f init=%d :: %s", df_try[1], j, conditionMessage(fit_try)))
    }
  }
  stop(paste(unique(errs), collapse = " | "))
}

fit_mcmc_with_vb <- function(model_name, tau, seed, vb_fit, df_used) {
  dqlm_flag <- identical(model_name, "dqlm")
  df_vec <- rep(df_used, 3)
  attempts <- if (dqlm_flag) {
    list(
      list(mh_proposal = "rw", joint_sample = FALSE),
      list(mh_proposal = "rw", joint_sample = TRUE)
    )
  } else {
    primary <- list(mh_proposal = mcmc_primary_proposal, joint_sample = mcmc_primary_joint_sample)
    fallback <- list(
      list(mh_proposal = "laplace_rw", joint_sample = FALSE),
      list(mh_proposal = "laplace_rw", joint_sample = TRUE),
      list(mh_proposal = "rw", joint_sample = FALSE),
      list(mh_proposal = "rw", joint_sample = TRUE)
    )
    uniq <- list()
    keys <- character(0)
    for (a in c(list(primary), fallback)) {
      key <- sprintf("%s_%s", a$mh_proposal, ifelse(isTRUE(a$joint_sample), "joint", "fixed"))
      if (!(key %in% keys)) {
        keys <- c(keys, key)
        uniq[[length(uniq) + 1L]] <- a
      }
    }
    uniq
  }

  errs <- character(0)
  for (k in seq_along(attempts)) {
    a <- attempts[[k]]
    set.seed(seed + 5000L * k)
    fit_try <- tryCatch(
      exdqlmMCMC(
        y = y,
        p0 = tau,
        model = model,
        df = df_vec,
        dim.df = dim_df,
        dqlm.ind = dqlm_flag,
        fix.sigma = FALSE,
        n.burn = mcmc_burn,
        n.mcmc = mcmc_n,
        init.from.vb = TRUE,
        vb_init_fit = vb_fit,
        vb_init_controls = list(
          method = "ldvb",
          tol = vb_tol,
          n.samp = vb_n_samp,
          max_iter = vb_max_iter,
          verbose = FALSE
        ),
        mh.proposal = a$mh_proposal,
        mh.adapt = TRUE,
        mh.adapt.interval = mcmc_mh_adapt_interval,
        mh.target.accept = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
        mh.scale.bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
        mh.max_scale.step = mcmc_mh_max_scale_step,
        mh.min_burn_adapt = mcmc_mh_min_burn_adapt,
        joint.sample = a$joint_sample,
        Sig.mh = diag(c(0.001, 0.001)),
        verbose = FALSE
      ),
      error = function(e) e
    )
    if (!inherits(fit_try, "error")) {
      return(list(
        fit = fit_try,
        attempt_id = k,
        mh_proposal = a$mh_proposal,
        joint_sample = a$joint_sample
      ))
    }
    errs <- c(errs, sprintf("attempt=%d :: %s", k, conditionMessage(fit_try)))
  }
  stop(paste(unique(errs), collapse = " | "))
}

run_one_pipeline <- function(task_row) {
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)
  tlabel <- tau_lab(tau)

  write_status(model_name, tau, "START", sprintf("seed=%d", seed))
  log_task(model_name, tau, sprintf("start pipeline model=%s tau=%.2f", model_name, tau))

  vb_t0 <- Sys.time()
  write_status(model_name, tau, "VB_START")
  vb_out <- fit_vb_safe(model_name, tau, seed)
  vb_runtime <- as.numeric(difftime(Sys.time(), vb_t0, units = "secs"))
  vb_file <- file.path(out_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model_name, tlabel))
  saveRDS(
    list(
      fit = vb_out$fit,
      meta = list(
        model = model_name,
        tau = tau,
        seed = seed,
        runtime_sec = vb_runtime,
        df_used = vb_out$df_used,
        init_id = vb_out$init_id
      )
    ),
    vb_file,
    compress = "xz"
  )
  write_status(model_name, tau, "VB_DONE", sprintf("runtime_sec=%.1f df=%.4f", vb_runtime, vb_out$df_used))
  log_task(model_name, tau, sprintf("vb done runtime=%.1fs df=%.4f", vb_runtime, vb_out$df_used))

  m_t0 <- Sys.time()
  write_status(model_name, tau, "MCMC_START")
  m_out <- fit_mcmc_with_vb(model_name, tau, seed + 1234L, vb_out$fit, vb_out$df_used)
  m_runtime <- as.numeric(difftime(Sys.time(), m_t0, units = "secs"))
  m_file <- file.path(out_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model_name, tlabel))
  saveRDS(
    list(
      fit = m_out$fit,
      meta = list(
        model = model_name,
        tau = tau,
        seed = seed,
        runtime_sec = m_runtime,
        df_used = vb_out$df_used,
        attempt_id = m_out$attempt_id,
        mh_proposal = m_out$mh_proposal,
        joint_sample = m_out$joint_sample
      )
    ),
    m_file,
    compress = "xz"
  )
  write_status(model_name, tau, "MCMC_DONE", sprintf("runtime_sec=%.1f attempt=%d", m_runtime, m_out$attempt_id))
  log_task(model_name, tau, sprintf(
    "mcmc done runtime=%.1fs attempt=%d mh=%s joint_sample=%s",
    m_runtime, m_out$attempt_id, m_out$mh_proposal, m_out$joint_sample
  ))

  ess_sigma <- if (!is.null(m_out$fit$diagnostics$ess$sigma)) as.numeric(m_out$fit$diagnostics$ess$sigma)[1] else NA_real_
  ess_gamma <- if (!is.null(m_out$fit$diagnostics$ess$gamma)) as.numeric(m_out$fit$diagnostics$ess$gamma)[1] else NA_real_

  data.frame(
    model = model_name,
    tau = tau,
    status = "done",
    vb_runtime_sec = vb_runtime,
    vb_iter = if (!is.null(vb_out$fit$iter)) as.integer(vb_out$fit$iter) else NA_integer_,
    vb_stop_reason = if (!is.null(vb_out$fit$diagnostics$convergence$stop_reason)) {
      as.character(vb_out$fit$diagnostics$convergence$stop_reason)[1]
    } else NA_character_,
    mcmc_runtime_sec = m_runtime,
    mcmc_attempt = as.integer(m_out$attempt_id),
    mcmc_mh_proposal = as.character(m_out$mh_proposal),
    mcmc_joint_sample = isTRUE(m_out$joint_sample),
    accept_rate_burn = if (!is.null(m_out$fit$accept.rate.burn)) as.numeric(m_out$fit$accept.rate.burn) else NA_real_,
    accept_rate_keep = if (!is.null(m_out$fit$accept.rate.keep)) as.numeric(m_out$fit$accept.rate.keep) else NA_real_,
    accept_rate = if (!is.null(m_out$fit$accept.rate)) as.numeric(m_out$fit$accept.rate) else NA_real_,
    ess_sigma = ess_sigma,
    ess_gamma = ess_gamma,
    vb_file = vb_file,
    mcmc_file = m_file,
    stringsAsFactors = FALSE
  )
}

tasks <- expand.grid(
  model = model_filter,
  tau = p_vec,
  stringsAsFactors = FALSE
)
tasks$seed <- 202603060L + seq_len(nrow(tasks)) * 1000L

log_master(sprintf("starting VB->MCMC pipeline run in %s", out_root))
log_master(sprintf(
  "TT=%d VB(n_samp=%d,max_iter=%d) MCMC(burn=%d,n=%d,primary=%s,joint=%s) cores=%d",
  TT, vb_n_samp, vb_max_iter, mcmc_burn, mcmc_n, mcmc_primary_proposal, mcmc_primary_joint_sample, cores_pipeline
))
log_master(sprintf("models=%s taus=%s",
                   paste(unique(tasks$model), collapse = ","),
                   paste(sprintf("%.2f", p_vec), collapse = ",")))

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
        vb_stop_reason = NA_character_,
        mcmc_runtime_sec = NA_real_,
        mcmc_attempt = NA_integer_,
        mcmc_mh_proposal = NA_character_,
        mcmc_joint_sample = NA,
        accept_rate = NA_real_,
        accept_rate_burn = NA_real_,
        accept_rate_keep = NA_real_,
        ess_sigma = NA_real_,
        ess_gamma = NA_real_,
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
