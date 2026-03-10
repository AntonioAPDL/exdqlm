#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(Matrix)
  library(matrixStats)
  library(parallel)
})

devtools::load_all(".", quiet = TRUE)

log_msg <- function(...) {
  cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", ..., "\n")
  flush.console()
}

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

  if (length(m0) != 6L || !all(dim(C0) == c(6L, 6L))) {
    stop("Unexpected DGP model dimension; expected m0 length 6 and C0 6x6.")
  }

  as.exdqlm(list(FF = FF, GG = GG, m0 = m0, C0 = C0))
}

sanitize_exps0 <- function(x, fallback) {
  z <- as.numeric(x)
  if (length(z) != length(fallback)) z <- rep(stats::median(fallback), length(fallback))
  z[!is.finite(z)] <- stats::median(fallback)
  z
}

ensure_dirs <- function(root) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  dirs <- c(
    "fits/vb", "fits/mcmc", "derived",
    "plots/fit_within_inference", "plots/fit_between_inference", "plots/traces",
    "tables", "logs"
  )
  for (d in dirs) dir.create(file.path(root, d), recursive = TRUE, showWarnings = FALSE)
}

# ---- Configuration ---------------------------------------------------------
Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

out_root <- "results/function_testing_20260304_vb_quantiles"
sim_path <- "results/sim_suite_dlm/series/dlm_constV_smallW/sim_output.rds"
if (!file.exists(sim_path)) stop("Simulation file not found: ", sim_path)

sim <- readRDS(sim_path)
TT_full <- length(sim$y)
TT_req <- safe_int(Sys.getenv("EXDQLM_FULL_TT", as.character(TT_full)), TT_full)
TT <- min(TT_full, max(200L, TT_req))

y <- as.numeric(sim$y[seq_len(TT)])
mu_true <- if (!is.null(sim$extras$mu)) as.numeric(sim$extras$mu[seq_len(TT)]) else rep(NA_real_, TT)

p_vec <- c(0.05, 0.50, 0.95)
df_base <- safe_num(Sys.getenv("EXDQLM_DF_BASE", "0.98"), 0.98)
df_vec <- rep(df_base, 3)
df_candidate_vals <- sort(unique(c(df_base, 0.995, 0.999)))
df_candidate_list <- lapply(df_candidate_vals, function(v) rep(v, 3))
dim_df <- c(2, 2, 2)

vb_tol <- safe_num(Sys.getenv("EXDQLM_VB_TOL", "0.03"), 0.03)
vb_n_samp <- safe_int(Sys.getenv("EXDQLM_VB_NSAMP", "300"), 300L)
vb_max_iter <- safe_int(Sys.getenv("EXDQLM_VB_MAX_ITER", "100"), 100L)
vb_tol_sigma <- safe_num(Sys.getenv("EXDQLM_VB_TOL_SIGMA", "0.01"), 0.01)
vb_tol_gamma <- safe_num(Sys.getenv("EXDQLM_VB_TOL_GAMMA", "0.005"), 0.005)
vb_tol_elbo <- safe_num(Sys.getenv("EXDQLM_VB_TOL_ELBO", "1e-4"), 1e-4)
vb_min_iter <- safe_int(Sys.getenv("EXDQLM_VB_MIN_ITER", "20"), 20L)
vb_patience <- safe_int(Sys.getenv("EXDQLM_VB_PATIENCE", "5"), 5L)
vb_allow_elbo_drop <- safe_num(Sys.getenv("EXDQLM_VB_ALLOW_ELBO_DROP", as.character(vb_tol_elbo)), vb_tol_elbo)

mcmc_burn <- safe_int(Sys.getenv("EXDQLM_MCMC_BURN", "100"), 100L)
mcmc_n <- safe_int(Sys.getenv("EXDQLM_MCMC_N", "1000"), 1000L)
mcmc_mh_adapt_interval <- safe_int(Sys.getenv("EXDQLM_MCMC_MH_ADAPT_INTERVAL", "50"), 50L)
mcmc_mh_target_lo <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_TARGET_LO", "0.20"), 0.20)
mcmc_mh_target_hi <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_TARGET_HI", "0.45"), 0.45)
mcmc_mh_scale_min <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_SCALE_MIN", "0.10"), 0.10)
mcmc_mh_scale_max <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_SCALE_MAX", "10.0"), 10.0)
mcmc_mh_max_scale_step <- safe_num(Sys.getenv("EXDQLM_MCMC_MH_MAX_SCALE_STEP", "0.35"), 0.35)
mcmc_mh_min_burn_adapt <- safe_int(Sys.getenv("EXDQLM_MCMC_MH_MIN_BURN_ADAPT", "50"), 50L)

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L

cores_vb <- safe_int(Sys.getenv("EXDQLM_CORES_VB", "4"), 4L)
cores_mcmc <- safe_int(Sys.getenv("EXDQLM_CORES_MCMC", "2"), 2L)
cores_vb <- max(1L, min(cores_vb, n_core_phys))
cores_mcmc <- max(1L, min(cores_mcmc, n_core_phys))

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

if (dir.exists(out_root)) {
  unlink(out_root, recursive = TRUE, force = TRUE)
}
ensure_dirs(out_root)

cfg <- list(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  sim_path = sim_path,
  TT_used = TT,
  taus = p_vec,
  df = df_vec,
  df_candidates = df_candidate_vals,
  dim_df = dim_df,
  vb = list(tol = vb_tol, n_samp = vb_n_samp, max_iter = vb_max_iter, cores = cores_vb),
  vb_joint = list(
    tol_sigma = vb_tol_sigma,
    tol_gamma = vb_tol_gamma,
    tol_elbo = vb_tol_elbo,
    min_iter = vb_min_iter,
    patience = vb_patience,
    allow_elbo_drop = vb_allow_elbo_drop
  ),
  mcmc = list(
    burn = mcmc_burn,
    n_mcmc = mcmc_n,
    cores = cores_mcmc,
    mh = list(
      adapt_interval = mcmc_mh_adapt_interval,
      target = c(mcmc_mh_target_lo, mcmc_mh_target_hi),
      scale_bounds = c(mcmc_mh_scale_min, mcmc_mh_scale_max),
      max_scale_step = mcmc_mh_max_scale_step,
      min_burn_adapt = mcmc_mh_min_burn_adapt
    )
  )
)
saveRDS(cfg, file.path(out_root, "run_config.rds"))
utils::write.table(
  data.frame(
    key = c(
      "TT_used", "vb_tol", "vb_n_samp", "vb_max_iter",
      "vb_tol_sigma", "vb_tol_gamma", "vb_tol_elbo", "vb_min_iter", "vb_patience",
      "vb_allow_elbo_drop",
      "mcmc_burn", "mcmc_n", "mcmc_mh_adapt_interval",
      "mcmc_mh_target_lo", "mcmc_mh_target_hi", "mcmc_mh_scale_min", "mcmc_mh_scale_max",
      "mcmc_mh_max_scale_step", "mcmc_mh_min_burn_adapt",
      "cores_vb", "cores_mcmc"
    ),
    value = c(
      TT, vb_tol, vb_n_samp, vb_max_iter,
      vb_tol_sigma, vb_tol_gamma, vb_tol_elbo, vb_min_iter, vb_patience,
      vb_allow_elbo_drop,
      mcmc_burn, mcmc_n, mcmc_mh_adapt_interval,
      mcmc_mh_target_lo, mcmc_mh_target_hi, mcmc_mh_scale_min, mcmc_mh_scale_max,
      mcmc_mh_max_scale_step, mcmc_mh_min_burn_adapt,
      cores_vb, cores_mcmc
    )
  ),
  file = file.path(out_root, "run_config.txt"), sep = "\t", row.names = FALSE, quote = FALSE
)

model <- build_dgp_matched_model(sim$info$params, TT = TT)

log_msg("Starting full validation run")
log_msg(sprintf("TT=%d | VB(max_iter=%d, n_samp=%d, tol=%.3g, cores=%d) | MCMC(burn=%d, n=%d, cores=%d)",
                TT, vb_max_iter, vb_n_samp, vb_tol, cores_vb, mcmc_burn, mcmc_n, cores_mcmc))
log_msg(sprintf("VB joint stop: tol_sigma=%.3g tol_gamma=%.3g tol_elbo=%.3g min_iter=%d patience=%d",
                vb_tol_sigma, vb_tol_gamma, vb_tol_elbo, vb_min_iter, vb_patience))
log_msg(sprintf("VB ELBO drop allowance: %.3g", vb_allow_elbo_drop))
log_msg(sprintf("MCMC MH: adapt_int=%d target=[%.2f, %.2f] scale=[%.2f, %.2f] max_step=%.2f min_burn=%d",
                mcmc_mh_adapt_interval, mcmc_mh_target_lo, mcmc_mh_target_hi,
                mcmc_mh_scale_min, mcmc_mh_scale_max, mcmc_mh_max_scale_step, mcmc_mh_min_burn_adapt))
log_msg(sprintf("DF base=%.4f | DF candidates=%s", df_base, paste(df_candidate_vals, collapse = ", ")))

# ---- Fit helpers -----------------------------------------------------------
exps0_candidates <- list(
  if (all(is.finite(mu_true))) mu_true else rep(stats::median(y), TT),
  stats::filter(y, rep(1 / 9, 9), sides = 1),
  rep(stats::median(y), TT)
)

fit_vb_safe <- function(tau, dqlm_flag, seed) {
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
        return(list(fit = fit_try, init_id = j, df_used = as.numeric(df_try[1])))
      }
      errs <- c(errs, sprintf("df=%.4f init=%d :: %s", df_try[1], j, conditionMessage(fit_try)))
    }
  }
  stop(paste(unique(errs), collapse = " | "))
}

fit_mcmc_safe <- function(tau, dqlm_flag, seed) {
  errs <- character(0)
  attempts <- if (isTRUE(dqlm_flag)) {
    list(
      list(init.from.vb = TRUE, vb.method = "ldvb", mh.proposal = "rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001))),
      list(init.from.vb = TRUE, vb.method = "isvb", mh.proposal = "rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001))),
      list(init.from.vb = FALSE, vb.method = "isvb", mh.proposal = "rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001)))
    )
  } else {
    list(
      list(init.from.vb = TRUE, vb.method = "ldvb", mh.proposal = "laplace_rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001))),
      list(init.from.vb = TRUE, vb.method = "ldvb", mh.proposal = "rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001))),
      list(init.from.vb = TRUE, vb.method = "isvb", mh.proposal = "rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001))),
      list(init.from.vb = FALSE, vb.method = "isvb", mh.proposal = "rw", joint.sample = FALSE, Sig.mh = diag(c(0.001, 0.001)))
    )
  }

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
          dqlm.ind = dqlm_flag,
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
          Sig.mh = a$Sig.mh,
          verbose = FALSE
        ),
        error = function(e) e
      )

      if (!inherits(fit_try, "error")) {
        return(list(
          fit = fit_try,
          attempt_id = j,
          init.from.vb = a$init.from.vb,
          vb_method = a$vb.method,
          mh_proposal = a$mh.proposal,
          df_used = as.numeric(df_try[1])
        ))
      }
      errs <- c(errs, sprintf("df=%.4f attempt=%d :: %s", df_try[1], j, conditionMessage(fit_try)))
    }
  }
  stop(paste(unique(errs), collapse = " | "))
}

fit_one_task <- function(task_row) {
  inference <- as.character(task_row$inference)
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)
  dqlm_flag <- identical(model_name, "dqlm")
  tlabel <- tau_lab(tau)

  started <- Sys.time()
  log_msg(sprintf("FIT start | %s | %s | tau=%.2f", inference, model_name, tau))

  fit_out <- if (inference == "vb") {
    fit_vb_safe(tau, dqlm_flag = dqlm_flag, seed = seed)
  } else {
    fit_mcmc_safe(tau, dqlm_flag = dqlm_flag, seed = seed)
  }

  fit_obj <- fit_out$fit
  finished <- Sys.time()
  runtime_sec <- as.numeric(difftime(finished, started, units = "secs"))

  out_file <- file.path(out_root, "fits", inference,
                        sprintf("%s_%s_tau_%s_fit.rds", inference, model_name, tlabel))

  saveRDS(
    list(
      fit = fit_obj,
      meta = c(
        as.list(task_row),
        list(started = started, finished = finished, runtime_sec = runtime_sec),
        as.list(fit_out[setdiff(names(fit_out), "fit")])
      )
    ),
    out_file,
    compress = "xz"
  )

  sigma_mean <- mean(as.numeric(fit_obj$samp.sigma))
  gamma_mean <- if (!is.null(fit_obj$samp.gamma)) mean(as.numeric(fit_obj$samp.gamma)) else NA_real_
  iter_like <- if (!is.null(fit_obj$iter)) as.integer(fit_obj$iter) else NA_integer_
  converged <- if (!is.null(fit_obj$converged)) isTRUE(fit_obj$converged) else NA
  stop_reason <- if (!is.null(fit_obj$diagnostics$convergence$stop_reason)) {
    as.character(fit_obj$diagnostics$convergence$stop_reason)[1]
  } else NA_character_
  accept_burn <- if (!is.null(fit_obj$accept.rate.burn)) as.numeric(fit_obj$accept.rate.burn) else NA_real_
  accept_keep <- if (!is.null(fit_obj$accept.rate.keep)) as.numeric(fit_obj$accept.rate.keep) else NA_real_

  log_msg(sprintf("FIT done  | %s | %s | tau=%.2f | runtime=%.1fs", inference, model_name, tau, runtime_sec))

  data.frame(
    inference = inference,
    model = model_name,
    tau = tau,
    seed = seed,
    df_used = if (!is.null(fit_out$df_used)) as.numeric(fit_out$df_used) else NA_real_,
    runtime_sec = runtime_sec,
    iter_like = iter_like,
    converged = converged,
    stop_reason = stop_reason,
    accept_rate_burn = accept_burn,
    accept_rate_keep = accept_keep,
    sigma_mean = sigma_mean,
    gamma_mean = gamma_mean,
    fit_file = out_file,
    stringsAsFactors = FALSE
  )
}

run_task_block <- function(tasks_df, mc_cores, label) {
  task_list <- split(tasks_df, seq_len(nrow(tasks_df)))
  log_msg(sprintf("Running %s tasks: %d (mc.cores=%d)", label, length(task_list), mc_cores))

  safe_run <- function(task_row) {
    tryCatch(
      list(ok = TRUE, res = fit_one_task(task_row), task = task_row, err = NA_character_),
      error = function(e) list(ok = FALSE, res = NULL, task = task_row, err = conditionMessage(e))
    )
  }

  if (.Platform$OS.type == "unix" && mc_cores > 1L) {
    out <- parallel::mclapply(task_list, safe_run, mc.cores = mc_cores, mc.preschedule = FALSE)
  } else {
    out <- lapply(task_list, safe_run)
  }

  fail_idx <- which(!vapply(out, function(x) isTRUE(x$ok), logical(1)))
  if (length(fail_idx) > 0L) {
    log_msg(sprintf("%s parallel failures: %d. Retrying sequentially.", label, length(fail_idx)))
    for (ii in fail_idx) {
      task_row <- out[[ii]]$task
      log_msg(sprintf(
        "Retry start | %s | %s | tau=%.2f",
        as.character(task_row$inference), as.character(task_row$model), as.numeric(task_row$tau)
      ))
      out[[ii]] <- safe_run(task_row)
    }
  }

  still_fail <- which(!vapply(out, function(x) isTRUE(x$ok), logical(1)))
  if (length(still_fail) > 0L) {
    msgs <- vapply(still_fail, function(ii) {
      tr <- out[[ii]]$task
      sprintf("%s|%s|tau=%.2f -> %s",
              as.character(tr$inference), as.character(tr$model), as.numeric(tr$tau), out[[ii]]$err)
    }, character(1))
    stop(sprintf("%s task block failed after retries: %s", label, paste(msgs, collapse = " || ")))
  }

  do.call(rbind, lapply(out, function(x) x$res))
}

# ---- Run fits --------------------------------------------------------------
fit_grid <- expand.grid(
  inference = c("vb", "mcmc"),
  model = c("exdqlm", "dqlm"),
  tau = p_vec,
  stringsAsFactors = FALSE
)
fit_grid$seed <- 20260305L + seq_len(nrow(fit_grid)) * 1000L

vb_grid <- subset(fit_grid, inference == "vb")
mcmc_grid <- subset(fit_grid, inference == "mcmc")

fit_summary_vb <- run_task_block(vb_grid, mc_cores = cores_vb, label = "VB")
fit_summary_mcmc <- run_task_block(mcmc_grid, mc_cores = cores_mcmc, label = "MCMC")
fit_summary <- rbind(fit_summary_vb, fit_summary_mcmc)
utils::write.csv(fit_summary, file.path(out_root, "tables", "fit_summary.csv"), row.names = FALSE)

# ---- Derived fit summaries (map + CrI) ------------------------------------
get_fit_file <- function(inference, model_name, tau) {
  file.path(out_root, "fits", inference,
            sprintf("%s_%s_tau_%s_fit.rds", inference, model_name, tau_lab(tau)))
}

derive_map_ci <- function(fit_obj, ci_level = 0.95) {
  TT_loc <- ncol(fit_obj$model$FF)
  theta_arr <- fit_obj$samp.theta
  # Some saved MCMC fits carry a legacy 'mcmc' class on a 3D array.
  # Strip it so 3D indexing does not dispatch coda coercions.
  if (inherits(theta_arr, "mcmc")) {
    class(theta_arr) <- setdiff(class(theta_arr), "mcmc")
  }
  if (!is.array(theta_arr)) {
    stop("samp.theta is not an array after coercion.")
  }
  ns <- dim(theta_arr)[3]
  q_draws <- vapply(seq_len(ns), function(i) {
    colSums(fit_obj$model$FF * theta_arr[, , i])
  }, numeric(TT_loc))

  alpha <- (1 - ci_level) / 2
  list(
    map = rowMeans(q_draws),
    lb = matrixStats::rowQuantiles(q_draws, probs = alpha),
    ub = matrixStats::rowQuantiles(q_draws, probs = 1 - alpha),
    n_draws = ns
  )
}

metrics_rows <- list()

for (inf in c("vb", "mcmc")) {
  for (mdl in c("exdqlm", "dqlm")) {
    for (tau in p_vec) {
      tlabel <- tau_lab(tau)
      fit_file <- get_fit_file(inf, mdl, tau)
      fit_wrap <- .exdqlm_unwrap_fit_bundle(readRDS(fit_file))
      fit_obj <- fit_wrap$fit

      summ <- derive_map_ci(fit_obj)

      tq_idx <- which.min(abs(sim$p - tau))
      true_q <- as.numeric(sim$q[seq_len(TT), tq_idx])

      rmse <- sqrt(mean((summ$map - true_q)^2))
      coverage <- mean(true_q >= summ$lb & true_q <= summ$ub)
      mean_ci_width <- mean(summ$ub - summ$lb)

      derived_file <- file.path(out_root, "derived",
                                sprintf("%s_%s_tau_%s_summary.rds", inf, mdl, tlabel))
      saveRDS(
        list(
          inference = inf,
          model = mdl,
          tau = tau,
          summary = summ,
          true_q = true_q,
          metrics = list(rmse = rmse, coverage = coverage, mean_ci_width = mean_ci_width)
        ),
        derived_file,
        compress = "xz"
      )

      metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
        inference = inf,
        model = mdl,
        tau = tau,
        rmse = rmse,
        coverage = coverage,
        mean_ci_width = mean_ci_width,
        n_draws = summ$n_draws,
        stringsAsFactors = FALSE
      )

      rm(fit_wrap, fit_obj, summ)
      invisible(gc())
    }
  }
}

metrics_df <- do.call(rbind, metrics_rows)
utils::write.csv(metrics_df, file.path(out_root, "tables", "metrics_summary.csv"), row.names = FALSE)

load_derived <- function(inference, model_name, tau) {
  readRDS(file.path(out_root, "derived", sprintf("%s_%s_tau_%s_summary.rds", inference, model_name, tau_lab(tau))))
}

# ---- Plot helpers ----------------------------------------------------------
plot_fit_compare <- function(file_path, idx_use, obj_a, obj_b, label_a, label_b, col_a, col_b, title_txt) {
  y_use <- y[idx_use]
  t_use <- idx_use
  true_q_use <- obj_a$true_q[idx_use]

  map_a <- obj_a$summary$map[idx_use]
  lb_a <- obj_a$summary$lb[idx_use]
  ub_a <- obj_a$summary$ub[idx_use]

  map_b <- obj_b$summary$map[idx_use]
  lb_b <- obj_b$summary$lb[idx_use]
  ub_b <- obj_b$summary$ub[idx_use]

  grDevices::png(file_path, width = 1900, height = 980, res = 150)
  y_lim <- range(c(y_use, true_q_use, lb_a, ub_a, lb_b, ub_b), finite = TRUE)

  graphics::plot(t_use, y_use, type = "l", col = "grey45", lwd = 1.0,
                 xlab = "time index", ylab = "value",
                 main = title_txt, ylim = y_lim)
  xx <- c(t_use, rev(t_use))
  graphics::polygon(xx, c(lb_a, rev(ub_a)), border = NA,
                    col = grDevices::adjustcolor(col_a, alpha.f = 0.16))
  graphics::polygon(xx, c(lb_b, rev(ub_b)), border = NA,
                    col = grDevices::adjustcolor(col_b, alpha.f = 0.16))

  graphics::lines(t_use, true_q_use, lwd = 2.0, lty = 2, col = "#202020")
  graphics::lines(t_use, map_a, lwd = 1.8, col = col_a)
  graphics::lines(t_use, map_b, lwd = 1.8, col = col_b)
  if (all(is.finite(mu_true))) graphics::lines(t_use, mu_true[idx_use], lwd = 1.1, lty = 3, col = "#2CA02C")

  graphics::legend(
    "topleft",
    legend = c("y", "true quantile", label_a, label_b,
               paste0(label_a, " 95% CrI"), paste0(label_b, " 95% CrI"), "true mean (mu_t)"),
    col = c("grey45", "#202020", col_a, col_b,
            grDevices::adjustcolor(col_a, alpha.f = 0.35),
            grDevices::adjustcolor(col_b, alpha.f = 0.35), "#2CA02C"),
    lty = c(1, 2, 1, 1, 1, 1, 3),
    lwd = c(1.0, 2.0, 1.8, 1.8, 8, 8, 1.1),
    bty = "n", cex = 0.9
  )
  grDevices::dev.off()
}

plot_trace_two <- function(file_path, x_a, y_a, x_b, y_b, label_a, label_b, col_a, col_b, title_txt, ylab_txt) {
  y_lim <- range(c(y_a, y_b), finite = TRUE)
  if (!all(is.finite(y_lim)) || diff(y_lim) <= 0) y_lim <- y_lim + c(-1e-6, 1e-6)

  grDevices::png(file_path, width = 1700, height = 900, res = 140)
  graphics::plot(x_a, y_a, type = "l", lwd = 1.7, col = col_a,
                 xlab = "iteration", ylab = ylab_txt,
                 main = title_txt, ylim = y_lim)
  graphics::lines(x_b, y_b, lwd = 1.7, col = col_b)
  graphics::legend("topright", legend = c(label_a, label_b),
                   col = c(col_a, col_b), lwd = 2, bty = "n")
  grDevices::dev.off()
}

plot_trace_single <- function(file_path, x, y, col, title_txt, ylab_txt) {
  y_lim <- range(y, finite = TRUE)
  if (!all(is.finite(y_lim)) || diff(y_lim) <= 0) y_lim <- y_lim + c(-1e-6, 1e-6)

  grDevices::png(file_path, width = 1700, height = 900, res = 140)
  graphics::plot(x, y, type = "l", lwd = 1.7, col = col,
                 xlab = "iteration", ylab = ylab_txt,
                 main = title_txt, ylim = y_lim)
  grDevices::dev.off()
}

# ---- Fit comparison plots --------------------------------------------------
last_n <- min(200L, TT)
idx_full <- seq_len(TT)
idx_tail <- seq.int(TT - last_n + 1L, TT)

for (tau in p_vec) {
  tlabel <- tau_lab(tau)

  for (inf in c("vb", "mcmc")) {
    obj_ex <- load_derived(inf, "exdqlm", tau)
    obj_dq <- load_derived(inf, "dqlm", tau)

    file_full <- file.path(out_root, "plots", "fit_within_inference",
                           sprintf("%s_tau_%s_dqlm_vs_exdqlm_full.png", inf, tlabel))
    file_tail <- file.path(out_root, "plots", "fit_within_inference",
                           sprintf("%s_tau_%s_dqlm_vs_exdqlm_last200.png", inf, tlabel))

    plot_fit_compare(
      file_full, idx_full,
      obj_a = obj_ex, obj_b = obj_dq,
      label_a = paste0(toupper(inf), " exDQLM"),
      label_b = paste0(toupper(inf), " DQLM"),
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("%s fit compare (tau=%.2f): exDQLM vs DQLM [full]", toupper(inf), tau)
    )

    plot_fit_compare(
      file_tail, idx_tail,
      obj_a = obj_ex, obj_b = obj_dq,
      label_a = paste0(toupper(inf), " exDQLM"),
      label_b = paste0(toupper(inf), " DQLM"),
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("%s fit compare (tau=%.2f): exDQLM vs DQLM [last %d]", toupper(inf), tau, last_n)
    )
  }

  for (mdl in c("exdqlm", "dqlm")) {
    obj_vb <- load_derived("vb", mdl, tau)
    obj_mc <- load_derived("mcmc", mdl, tau)

    file_full <- file.path(out_root, "plots", "fit_between_inference",
                           sprintf("%s_tau_%s_vb_vs_mcmc_full.png", mdl, tlabel))
    file_tail <- file.path(out_root, "plots", "fit_between_inference",
                           sprintf("%s_tau_%s_vb_vs_mcmc_last200.png", mdl, tlabel))

    plot_fit_compare(
      file_full, idx_full,
      obj_a = obj_vb, obj_b = obj_mc,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = "#8E44AD", col_b = "#16A085",
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [full]", toupper(mdl), tau)
    )

    plot_fit_compare(
      file_tail, idx_tail,
      obj_a = obj_vb, obj_b = obj_mc,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = "#8E44AD", col_b = "#16A085",
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [last %d]", toupper(mdl), tau, last_n)
    )
  }
}

# ---- Trace plots -----------------------------------------------------------
# VB ELBO: exDQLM vs DQLM per tau
for (tau in p_vec) {
  tlabel <- tau_lab(tau)
  ex_fit <- readRDS(get_fit_file("vb", "exdqlm", tau))$fit
  dq_fit <- readRDS(get_fit_file("vb", "dqlm", tau))$fit
  elbo_ex <- as.numeric(ex_fit$diagnostics$elbo)
  elbo_dq <- as.numeric(dq_fit$diagnostics$elbo)

  out_file <- file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_elbo_trace.png", tlabel))
  grDevices::png(out_file, width = 1900, height = 900, res = 140)
  old_par <- graphics::par(no.readonly = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.2))

  y_lim <- range(c(elbo_ex, elbo_dq), finite = TRUE)
  graphics::plot(seq_along(elbo_ex), elbo_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                 xlab = "iteration", ylab = "ELBO",
                 main = sprintf("VB raw ELBO (tau=%.2f)", tau), ylim = y_lim)
  graphics::lines(seq_along(elbo_dq), elbo_dq, lwd = 1.8, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")

  d_ex <- elbo_ex - elbo_ex[1]
  d_dq <- elbo_dq - elbo_dq[1]
  yd <- range(c(d_ex, d_dq), finite = TRUE)
  graphics::plot(seq_along(d_ex), d_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                 xlab = "iteration", ylab = "ELBO - ELBO[1]",
                 main = "VB centered ELBO change", ylim = yd)
  graphics::lines(seq_along(d_dq), d_dq, lwd = 1.8, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")

  graphics::par(old_par)
  grDevices::dev.off()

  rm(ex_fit, dq_fit)
  invisible(gc())
}

# Sigma traces: VB and MCMC compare exDQLM vs DQLM per tau
for (tau in p_vec) {
  tlabel <- tau_lab(tau)

  vb_ex <- readRDS(get_fit_file("vb", "exdqlm", tau))$fit
  vb_dq <- readRDS(get_fit_file("vb", "dqlm", tau))$fit
  plot_trace_two(
    file_path = file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_sigma_trace.png", tlabel)),
    x_a = seq_along(vb_ex$seq.sigma) - 1L,
    y_a = as.numeric(vb_ex$seq.sigma),
    x_b = seq_along(vb_dq$seq.sigma) - 1L,
    y_b = as.numeric(vb_dq$seq.sigma),
    label_a = "VB exDQLM",
    label_b = "VB DQLM",
    col_a = "#C73E1D",
    col_b = "#1F78B4",
    title_txt = sprintf("VB sigma trace (tau=%.2f)", tau),
    ylab_txt = "E[sigma]"
  )

  if (!is.null(vb_ex$seq.gamma)) {
    plot_trace_single(
      file_path = file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_gamma_trace_exdqlm.png", tlabel)),
      x = seq_along(vb_ex$seq.gamma) - 1L,
      y = as.numeric(vb_ex$seq.gamma),
      col = "#C73E1D",
      title_txt = sprintf("VB gamma trace exDQLM (tau=%.2f)", tau),
      ylab_txt = "E[gamma]"
    )
  }

  mc_ex <- readRDS(get_fit_file("mcmc", "exdqlm", tau))$fit
  mc_dq <- readRDS(get_fit_file("mcmc", "dqlm", tau))$fit

  sig_ex <- as.numeric(mc_ex$samp.sigma)
  sig_dq <- as.numeric(mc_dq$samp.sigma)
  plot_trace_two(
    file_path = file.path(out_root, "plots", "traces", sprintf("mcmc_tau_%s_sigma_trace.png", tlabel)),
    x_a = seq_along(sig_ex),
    y_a = sig_ex,
    x_b = seq_along(sig_dq),
    y_b = sig_dq,
    label_a = "MCMC exDQLM",
    label_b = "MCMC DQLM",
    col_a = "#C73E1D",
    col_b = "#1F78B4",
    title_txt = sprintf("MCMC sigma trace (tau=%.2f)", tau),
    ylab_txt = "sigma sample"
  )

  if (!is.null(mc_ex$samp.gamma)) {
    gam_ex <- as.numeric(mc_ex$samp.gamma)
    plot_trace_single(
      file_path = file.path(out_root, "plots", "traces", sprintf("mcmc_tau_%s_gamma_trace_exdqlm.png", tlabel)),
      x = seq_along(gam_ex),
      y = gam_ex,
      col = "#C73E1D",
      title_txt = sprintf("MCMC gamma trace exDQLM (tau=%.2f)", tau),
      ylab_txt = "gamma sample"
    )
  }

  rm(vb_ex, vb_dq, mc_ex, mc_dq)
  invisible(gc())
}

log_msg("Finished full validation run")
