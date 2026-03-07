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

build_dgp_matched_model <- function(params, TT) {
  period <- as.numeric(params$period)[1]
  if (!is.finite(period) || period <= 2) stop("Invalid DGP period.")

  lam1 <- 2 * pi / period
  lam2 <- 2 * lam1
  rot <- function(lam) {
    matrix(c(cos(lam), sin(lam), -sin(lam), cos(lam)), nrow = 2, byrow = TRUE)
  }

  GG_one <- as.matrix(Matrix::bdiag(diag(2), rot(lam1), rot(lam2)))
  GG <- array(0, dim = c(6, 6, TT))
  for (t in seq_len(TT)) GG[, , t] <- GG_one

  FF <- matrix(rep(c(1, 0, 1, 0, 1, 0), TT), nrow = 6, ncol = TT)
  m0 <- as.numeric(params$m0)
  C0 <- as.matrix(params$C0)
  as.exdqlm(list(FF = FF, GG = GG, m0 = m0, C0 = C0))
}

out_root <- "results/function_testing_20260304_vb_quantiles/gate_exdqlm_mcmc_20260305"
sim_path <- "results/sim_suite_dlm/series/dlm_constV_smallW/sim_output.rds"
if (!file.exists(sim_path)) stop("Simulation file not found: ", sim_path)
sim <- readRDS(sim_path)

TT_full <- length(sim$y)
TT_req <- safe_int(Sys.getenv("EXDQLM_GATE_TT", as.character(TT_full)), TT_full)
TT <- min(TT_full, max(200L, TT_req))
y <- as.numeric(sim$y[seq_len(TT)])

p_vec <- c(0.05, 0.50, 0.95)
df_base <- safe_num(Sys.getenv("EXDQLM_DF_BASE", "0.98"), 0.98)
df_candidate_vals <- sort(unique(c(df_base, 0.995, 0.999)))
df_candidate_list <- lapply(df_candidate_vals, function(v) rep(v, 3))
dim_df <- c(2, 2, 2)

vb_tol <- safe_num(Sys.getenv("EXDQLM_VB_TOL", "0.03"), 0.03)
vb_n_samp <- safe_int(Sys.getenv("EXDQLM_VB_NSAMP", "300"), 300L)
vb_max_iter <- safe_int(Sys.getenv("EXDQLM_VB_MAX_ITER", "300"), 300L)
vb_tol_sigma <- safe_num(Sys.getenv("EXDQLM_VB_TOL_SIGMA", "0.02"), 0.02)
vb_tol_gamma <- safe_num(Sys.getenv("EXDQLM_VB_TOL_GAMMA", "0.01"), 0.01)
vb_tol_elbo <- safe_num(Sys.getenv("EXDQLM_VB_TOL_ELBO", "5"), 5)
vb_min_iter <- safe_int(Sys.getenv("EXDQLM_VB_MIN_ITER", "30"), 30L)
vb_patience <- safe_int(Sys.getenv("EXDQLM_VB_PATIENCE", "5"), 5L)
vb_allow_elbo_drop <- safe_num(Sys.getenv("EXDQLM_VB_ALLOW_ELBO_DROP", "5"), 5)

mcmc_burn <- safe_int(Sys.getenv("EXDQLM_MCMC_BURN", "500"), 500L)
mcmc_n <- safe_int(Sys.getenv("EXDQLM_MCMC_N", "1500"), 1500L)
mcmc_mh_adapt_interval <- safe_int(Sys.getenv("EXDQLM_MCMC_MH_ADAPT_INTERVAL", "25"), 25L)
mcmc_mh_target_lo <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_TARGET_LO", "0.20"), 0.20)
mcmc_mh_target_hi <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_TARGET_HI", "0.45"), 0.45)
mcmc_mh_scale_min <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_SCALE_MIN", "0.02"), 0.02)
mcmc_mh_scale_max <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_SCALE_MAX", "2.5"), 2.5)
mcmc_mh_max_scale_step <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_MAX_SCALE_STEP", "0.50"), 0.50)
mcmc_mh_min_burn_adapt <- safe_int(Sys.getenv("EXDQLM_MCMC_MH_MIN_BURN_ADAPT", "25"), 25L)

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores_mcmc <- safe_int(Sys.getenv("EXDQLM_CORES_MCMC", "3"), 3L)
cores_mcmc <- max(1L, min(cores_mcmc, n_core_phys))

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
for (d in c("fits", "tables", "plots", "logs")) {
  dir.create(file.path(out_root, d), recursive = TRUE, showWarnings = FALSE)
}

log_file <- file.path(out_root, "logs", "gate_run.log")
if (file.exists(log_file)) file.remove(log_file)

log_msg <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
  flush.console()
}

model <- build_dgp_matched_model(sim$info$params, TT = TT)

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
  exdqlm.vb.allow_elbo_drop = vb_allow_elbo_drop
)
on.exit(options(old_opts), add = TRUE)

get_adapt_tbl <- function(mh_diag) {
  if (is.null(mh_diag)) return(NULL)
  if (!is.null(mh_diag$adaptation)) return(mh_diag$adaptation)
  if (!is.null(mh_diag$adapt_trace)) return(mh_diag$adapt_trace)
  NULL
}

get_scale_final <- function(mh_diag) {
  if (is.null(mh_diag)) return(NA_real_)
  if (!is.null(mh_diag$scale_final)) return(as.numeric(mh_diag$scale_final)[1])
  if (!is.null(mh_diag$final_scale)) return(as.numeric(mh_diag$final_scale)[1])
  NA_real_
}

fit_mcmc_exdqlm_safe <- function(tau, seed) {
  errs <- character(0)
  attempts <- list(
    list(init.from.vb = TRUE, vb.method = "ldvb", mh.proposal = "laplace_rw", joint.sample = TRUE),
    list(init.from.vb = TRUE, vb.method = "ldvb", mh.proposal = "laplace_rw", joint.sample = FALSE),
    list(init.from.vb = TRUE, vb.method = "ldvb", mh.proposal = "rw", joint.sample = FALSE),
    list(init.from.vb = TRUE, vb.method = "isvb", mh.proposal = "rw", joint.sample = FALSE),
    list(init.from.vb = FALSE, vb.method = "isvb", mh.proposal = "rw", joint.sample = FALSE)
  )

  for (df_try in df_candidate_list) {
    for (j in seq_along(attempts)) {
      a <- attempts[[j]]
      set.seed(seed + 1000L * j + as.integer(round(1000 * df_try[1])))
      fit_try <- tryCatch(
        exdqlmMCMC(
          y = y,
          p0 = tau,
          model = model,
          df = df_try,
          dim.df = dim_df,
          dqlm.ind = FALSE,
          fix.sigma = FALSE,
          n.burn = mcmc_burn,
          n.mcmc = mcmc_n,
          init.from.isvb = identical(a$vb.method, "isvb"),
          init.from.vb = a$init.from.vb,
          vb_init_controls = list(
            method = a$vb.method,
            tol = vb_tol,
            n.samp = max(200L, vb_n_samp),
            max_iter = vb_max_iter,
            verbose = FALSE
          ),
          mh.proposal = a$mh.proposal,
          mh.adapt = TRUE,
          mh.adapt.interval = mcmc_mh_adapt_interval,
          mh.target.accept = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
          mh.scale.bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
          mh.max_scale.step = mcmc_mh_max_scale_step,
          mh.min_burn_adapt = mcmc_mh_min_burn_adapt,
          joint.sample = a$joint.sample,
          Sig.mh = diag(c(0.001, 0.001)),
          verbose = FALSE
        ),
        error = function(e) e
      )
      if (!inherits(fit_try, "error")) {
        return(list(
          fit = fit_try,
          df_used = as.numeric(df_try[1]),
          attempt_id = j,
          init.from.vb = a$init.from.vb,
          vb_method = a$vb.method,
          mh_proposal = a$mh.proposal,
          joint_sample = isTRUE(a$joint.sample)
        ))
      }
      errs <- c(errs, sprintf("df=%.4f attempt=%d :: %s", df_try[1], j, conditionMessage(fit_try)))
    }
  }
  stop(paste(unique(errs), collapse = " | "))
}

fit_one <- function(tau, seed) {
  started <- Sys.time()
  log_msg(sprintf("FIT start | exdqlm mcmc | tau=%.2f", tau))
  out <- fit_mcmc_exdqlm_safe(tau, seed)
  fit <- out$fit
  runtime_sec <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  tlabel <- tau_lab(tau)
  file_out <- file.path(out_root, "fits", sprintf("mcmc_exdqlm_tau_%s_fit.rds", tlabel))
  saveRDS(
    list(
      fit = fit,
      meta = list(
        tau = tau,
        seed = seed,
        runtime_sec = runtime_sec,
        df_used = out$df_used,
        attempt_id = out$attempt_id,
        init.from.vb = out$init.from.vb,
        vb_method = out$vb_method,
        mh_proposal = out$mh_proposal,
        joint_sample = out$joint_sample
      )
    ),
    file_out,
    compress = "xz"
  )
  log_msg(sprintf("FIT done  | exdqlm mcmc | tau=%.2f | runtime=%.1fs", tau, runtime_sec))
  list(file = file_out, tau = tau)
}

log_msg("Starting exDQLM-only MCMC gate pass")
log_msg(sprintf(
  "TT=%d burn=%d n=%d cores=%d MH(adapt=%d target=[%.2f,%.2f] scale=[%.2f,%.2f] step=%.2f min_burn=%d)",
  TT, mcmc_burn, mcmc_n, cores_mcmc,
  mcmc_mh_adapt_interval, mcmc_mh_target_lo, mcmc_mh_target_hi,
  mcmc_mh_scale_min, mcmc_mh_scale_max, mcmc_mh_max_scale_step, mcmc_mh_min_burn_adapt
))

task_taus <- p_vec
task_seeds <- 20260305L + seq_along(task_taus) * 1000L

safe_run <- function(k) {
  tryCatch(
    list(ok = TRUE, res = fit_one(task_taus[k], task_seeds[k]), err = NA_character_),
    error = function(e) list(ok = FALSE, res = NULL, err = conditionMessage(e))
  )
}

if (.Platform$OS.type == "unix" && cores_mcmc > 1L) {
  runs <- parallel::mclapply(seq_along(task_taus), safe_run, mc.cores = cores_mcmc, mc.preschedule = FALSE)
} else {
  runs <- lapply(seq_along(task_taus), safe_run)
}

bad <- which(!vapply(runs, function(x) isTRUE(x$ok), logical(1)))
if (length(bad) > 0L) {
  msgs <- vapply(bad, function(i) sprintf("tau=%.2f -> %s", task_taus[i], runs[[i]]$err), character(1))
  stop("Gate pass failed: ", paste(msgs, collapse = " || "))
}

rows <- list()
for (tau in p_vec) {
  tlabel <- tau_lab(tau)
  wrap <- readRDS(file.path(out_root, "fits", sprintf("mcmc_exdqlm_tau_%s_fit.rds", tlabel)))
  fit <- wrap$fit
  meta <- wrap$meta
  mh_diag <- fit$mh.diagnostics
  adapt_tbl <- get_adapt_tbl(mh_diag)
  rows[[length(rows) + 1L]] <- data.frame(
    tau = tau,
    runtime_sec = as.numeric(meta$runtime_sec),
    df_used = as.numeric(meta$df_used),
    attempt_id = as.integer(meta$attempt_id),
    vb_method = as.character(meta$vb_method),
    mh_proposal = as.character(meta$mh_proposal),
    joint_sample = isTRUE(meta$joint_sample),
    accept_rate = as.numeric(fit$accept.rate),
    accept_rate_burn = as.numeric(fit$accept.rate.burn),
    accept_rate_keep = as.numeric(fit$accept.rate.keep),
    ess_sigma = if (!is.null(fit$diagnostics$ess$sigma)) as.numeric(fit$diagnostics$ess$sigma)[1] else NA_real_,
    ess_gamma = if (!is.null(fit$diagnostics$ess$gamma)) as.numeric(fit$diagnostics$ess$gamma)[1] else NA_real_,
    mh_scale_final = get_scale_final(mh_diag),
    mh_adapt_steps = if (!is.null(adapt_tbl)) nrow(adapt_tbl) else NA_integer_,
    gate_ess_gamma_ge_20 = if (!is.null(fit$diagnostics$ess$gamma)) as.numeric(fit$diagnostics$ess$gamma)[1] >= 20 else NA,
    gate_ess_gamma_ge_50 = if (!is.null(fit$diagnostics$ess$gamma)) as.numeric(fit$diagnostics$ess$gamma)[1] >= 50 else NA,
    stringsAsFactors = FALSE
  )

  grDevices::png(file.path(out_root, "plots", sprintf("mcmc_exdqlm_tau_%s_sigma_trace.png", tlabel)),
                 width = 1700, height = 900, res = 140)
  graphics::plot(seq_along(fit$samp.sigma), as.numeric(fit$samp.sigma), type = "l", lwd = 1.7,
                 col = "#1F78B4", xlab = "iteration", ylab = "sigma sample",
                 main = sprintf("Gate pass MCMC sigma trace exDQLM (tau=%.2f)", tau))
  grDevices::dev.off()

  if (!is.null(fit$samp.gamma)) {
    grDevices::png(file.path(out_root, "plots", sprintf("mcmc_exdqlm_tau_%s_gamma_trace.png", tlabel)),
                   width = 1700, height = 900, res = 140)
    graphics::plot(seq_along(fit$samp.gamma), as.numeric(fit$samp.gamma), type = "l", lwd = 1.7,
                   col = "#C73E1D", xlab = "iteration", ylab = "gamma sample",
                   main = sprintf("Gate pass MCMC gamma trace exDQLM (tau=%.2f)", tau))
    grDevices::dev.off()
  }
}

diag_df <- do.call(rbind, rows)
utils::write.csv(diag_df, file.path(out_root, "tables", "mcmc_exdqlm_gate_summary.csv"), row.names = FALSE)
saveRDS(
  list(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    TT = TT,
    taus = p_vec,
    settings = list(
      vb = list(
        tol = vb_tol,
        n_samp = vb_n_samp,
        max_iter = vb_max_iter,
        tol_sigma = vb_tol_sigma,
        tol_gamma = vb_tol_gamma,
        tol_elbo = vb_tol_elbo,
        min_iter = vb_min_iter,
        patience = vb_patience,
        allow_elbo_drop = vb_allow_elbo_drop
      ),
      mcmc = list(
        burn = mcmc_burn,
        n = mcmc_n,
        cores = cores_mcmc,
        mh = list(
          adapt_interval = mcmc_mh_adapt_interval,
          target = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
          scale_bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
          max_scale_step = mcmc_mh_max_scale_step,
          min_burn_adapt = mcmc_mh_min_burn_adapt
        )
      )
    ),
    diagnostics = diag_df
  ),
  file.path(out_root, "tables", "gate_run_config_and_summary.rds")
)

log_msg("Completed exDQLM-only MCMC gate pass")
