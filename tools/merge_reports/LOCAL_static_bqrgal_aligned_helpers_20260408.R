#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

safe_chr_static_bqrgal <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  y <- as.character(x)[1]
  if (!nzchar(trimws(y)) || identical(toupper(trimws(y)), "NA")) default else y
}

safe_num_static_bqrgal <- function(x, default = NA_real_) {
  y <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(y)) y else default
}

safe_int_static_bqrgal <- function(x, default = NA_integer_) {
  y <- suppressWarnings(as.integer(x)[1])
  if (is.finite(y)) y else default
}

as_flag_static_bqrgal <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  tolower(as.character(x)[1]) %in% c("1", "true", "t", "yes", "y")
}

ensure_dir_static_bqrgal <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

tau_label_static_bqrgal <- function(x) {
  gsub("\\.", "p", formatC(as.numeric(x)[1], format = "f", digits = 2))
}

static_bqrgal_aligned_tag_20260408 <- function() {
  "static_bqrgal_aligned_20260408"
}

static_bqrgal_aligned_paths_20260408 <- function() {
  repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  out_dir <- file.path(repo_root, "tools", "merge_reports")
  tag <- static_bqrgal_aligned_tag_20260408()
  run_root <- file.path(out_dir, tag)
  result_root <- file.path(repo_root, "results", tag)
  list(
    repo_root = repo_root,
    out_dir = out_dir,
    tag = tag,
    run_root = run_root,
    result_root = result_root,
    config_dir = file.path(run_root, "configs"),
    rows_dir = file.path(run_root, "rows"),
    health_dir = file.path(run_root, "health"),
    metrics_dir = file.path(run_root, "metrics"),
    logs_dir = file.path(run_root, "logs"),
    data_dir = file.path(result_root, "data"),
    fits_dir = file.path(result_root, "fits"),
    lib_dir = file.path(run_root, "r_libs"),
    manifest = file.path(out_dir, "LOCAL_static_bqrgal_aligned_manifest_20260408.csv"),
    schedule = file.path(out_dir, "LOCAL_static_bqrgal_aligned_schedule_20260408.csv"),
    stage_counts = file.path(out_dir, "LOCAL_static_bqrgal_aligned_stage_counts_20260408.csv"),
    manifest_status = file.path(out_dir, "LOCAL_static_bqrgal_aligned_manifest_status_20260408.csv"),
    metrics_long = file.path(out_dir, "LOCAL_static_bqrgal_aligned_metrics_long_20260408.csv"),
    summary_by_scenario = file.path(out_dir, "LOCAL_static_bqrgal_aligned_summary_by_scenario_20260408.csv"),
    summary_by_model = file.path(out_dir, "LOCAL_static_bqrgal_aligned_summary_by_model_20260408.csv"),
    health_summary = file.path(out_dir, "LOCAL_static_bqrgal_aligned_health_summary_20260408.csv"),
    model_pair = file.path(out_dir, "LOCAL_static_bqrgal_aligned_model_pair_summary_20260408.csv"),
    cie_table = file.path(out_dir, "LOCAL_static_bqrgal_aligned_cie_table_20260408.csv"),
    rmse_table = file.path(out_dir, "LOCAL_static_bqrgal_aligned_rmse_table_20260408.csv"),
    coverage_table = file.path(out_dir, "LOCAL_static_bqrgal_aligned_coverage_table_20260408.csv"),
    interval_score_table = file.path(out_dir, "LOCAL_static_bqrgal_aligned_interval_score_table_20260408.csv"),
    audit = file.path(out_dir, "LOCAL_static_bqrgal_aligned_audit_20260408.csv"),
    data_core = file.path(result_root, "data", "train_test_data_paper_matched_core_n100.rds"),
    data_extension = file.path(result_root, "data", "train_test_data_extension_n1000.rds"),
    bqrgal_pkg_src = "/home/jaguir26/local/src/bqrgal-examples/bqrgal",
    bqrgal_run_wrapper = "/home/jaguir26/local/src/bqrgal-examples/data-examples/run_gal_mcmc.R"
  )
}

static_bqrgal_phase_order_20260408 <- c(
  phase1_paper_matched_core = 1L,
  phase2_extension_n1000 = 2L
)

static_bqrgal_grid_20260408 <- function() {
  families <- c("normal", "laplace", "gausmix")
  taus <- c(0.05, 0.25, 0.50)
  phase_grid <- data.frame(
    phase = c("phase1_paper_matched_core", "phase2_extension_n1000"),
    lane_label = c("paper_matched_core", "extension_n1000"),
    n_train = c(100L, 1000L),
    data_seed = c(42L, 1042L),
    stringsAsFactors = FALSE
  )
  rep_grid <- expand.grid(
    family = families,
    tau = taus,
    rep_id = seq_len(100L),
    model = c("exal", "al"),
    stringsAsFactors = FALSE
  )
  out <- merge(phase_grid, rep_grid, by = NULL, sort = FALSE)
  out$phase_order <- unname(static_bqrgal_phase_order_20260408[out$phase])
  out$tau_label <- vapply(out$tau, tau_label_static_bqrgal, character(1))
  out$n_test <- 100L
  out$train_reps <- 100L
  out$test_reps <- 100L
  out$model_order <- ifelse(out$model == "exal", 1L, 2L)
  fam_order <- setNames(seq_along(families), families)
  tau_order <- setNames(seq_along(taus), tau_label_static_bqrgal(taus))
  out$fit_seed <- with(
    out,
    2026040800L +
      phase_order * 1000000L +
      unname(fam_order[family]) * 100000L +
      unname(tau_order[tau_label]) * 10000L +
      rep_id * 10L +
      ifelse(model == "exal", 1L, 2L)
  )
  out$row_id <- seq_len(nrow(out))
  out[order(
    out$phase_order,
    out$family,
    out$tau,
    out$rep_id,
    out$model_order
  ), , drop = FALSE]
}

static_bqrgal_true_params_20260408 <- function(n_train, n_test, train_reps, test_reps, p0_vals, seed) {
  list(
    nn = as.integer(n_train),
    NN = as.integer(n_test),
    train_kk = as.integer(train_reps),
    test_kk = as.integer(test_reps),
    cov_mat = 0.5 ^ as.matrix(stats::dist(seq_len(8L))),
    bb = c(3, 1.5, 0, 0, 2, 0, 0, 0),
    true_ind = c(1, 1, 0, 0, 1, 0, 0, 0),
    p0_vals = as.numeric(p0_vals),
    seed = as.integer(seed)
  )
}

simGausQr_static_bqrgal_20260408 <- function(n, p0, mu, sigma) {
  mu0 <- -sigma * stats::qnorm(p0)
  mu + stats::rnorm(n, mu0, sigma)
}

simLaplaceQr_static_bqrgal_20260408 <- function(n, p0, mu, sigma) {
  if (p0 <= 0.5) {
    mu0 <- -sigma * log(2 * p0)
  } else {
    mu0 <- sigma * log(2 * (1 - p0))
  }
  mu + nimble::rdexp(n, mu0, sigma)
}

simGausMixQr_static_bqrgal_20260408 <- function(n, p0, mu, sigma) {
  findGausMixMu <- function(x0, p0_inner, sigma_inner) {
    0.1 * stats::pnorm(0, x0, sigma_inner[1]) +
      0.9 * stats::pnorm(0, x0 + 1, sigma_inner[2]) - p0_inner
  }
  sol <- stats::uniroot(findGausMixMu, c(-100, 100), p0_inner = p0, sigma_inner = sigma)
  lab <- sample(1:2, n, replace = TRUE, prob = c(0.1, 0.9))
  mu0 <- c(sol$root, sol$root + 1)
  loc_vec <- mu0[lab]
  scal_vec <- sigma[lab]
  mu + stats::rnorm(n, loc_vec, scal_vec)
}

build_static_bqrgal_dataset_20260408 <- function(n_train, n_test = 100L, train_reps = 100L, test_reps = 100L, p0_vals = c(0.05, 0.25, 0.5), seed = 42L) {
  set.seed(seed)
  params <- static_bqrgal_true_params_20260408(n_train, n_test, train_reps, test_reps, p0_vals, seed)

  train_covar_list <- vector("list", length = length(p0_vals))
  for (l in seq_along(p0_vals)) {
    XX_train_list <- vector("list", length = train_reps)
    for (j in seq_len(train_reps)) {
      XX_train_list[[j]] <- mvtnorm::rmvnorm(n_train, sigma = params$cov_mat)
    }
    train_covar_list[[l]] <- XX_train_list
  }

  test_covar_list <- vector("list", length = length(p0_vals))
  for (l in seq_along(p0_vals)) {
    XX_test_list <- vector("list", length = test_reps)
    for (j in seq_len(test_reps)) {
      XX_test_list[[j]] <- mvtnorm::rmvnorm(n_test, sigma = params$cov_mat)
    }
    test_covar_list[[l]] <- XX_test_list
  }

  make_family_data <- function(sim_fun, extra_arg) {
    train_out <- vector("list", length = length(p0_vals))
    test_out <- vector("list", length = length(p0_vals))
    for (l in seq_along(p0_vals)) {
      p0 <- p0_vals[l]
      yy_train_list <- vector("list", length = train_reps)
      yy_test_list <- vector("list", length = test_reps)
      for (j in seq_len(train_reps)) {
        XX <- train_covar_list[[l]][[j]]
        mu <- drop(XX %*% params$bb)
        yy_train_list[[j]] <- sim_fun(n_train, p0, mu, extra_arg)
      }
      for (j in seq_len(test_reps)) {
        XX_test <- test_covar_list[[l]][[j]]
        mu_test <- drop(XX_test %*% params$bb)
        yy_test_list[[j]] <- sim_fun(n_test, p0, mu_test, extra_arg)
      }
      train_out[[l]] <- yy_train_list
      test_out[[l]] <- yy_test_list
    }
    list(train = train_out, test = test_out)
  }

  normal_data <- make_family_data(simGausQr_static_bqrgal_20260408, 3)
  laplace_data <- make_family_data(simLaplaceQr_static_bqrgal_20260408, 3)
  gausmix_data <- make_family_data(simGausMixQr_static_bqrgal_20260408, c(sqrt(1), sqrt(5)))

  list(
    true_params = params,
    train_covar_list = train_covar_list,
    test_covar_list = test_covar_list,
    train_data = list(
      normal = normal_data$train,
      laplace = laplace_data$train,
      gausmix = gausmix_data$train
    ),
    test_data = list(
      normal = normal_data$test,
      laplace = laplace_data$test,
      gausmix = gausmix_data$test
    )
  )
}

bootstrap_static_bqrgal_lib_20260408 <- function(paths) {
  ensure_dir_static_bqrgal(paths$lib_dir)
  if (!file.exists(paths$bqrgal_pkg_src)) {
    stop(sprintf("bqrgal package source not found: %s", paths$bqrgal_pkg_src))
  }
  if (!file.exists(paths$bqrgal_run_wrapper)) {
    stop(sprintf("bqrgal wrapper script not found: %s", paths$bqrgal_run_wrapper))
  }
  old_libs <- .libPaths()
  on.exit(.libPaths(old_libs), add = TRUE)
  .libPaths(c(paths$lib_dir, old_libs))

  required_pkgs <- c("Rcpp", "RcppArmadillo", "RcppDist", "mvtnorm", "GIGrvg", "truncnorm")
  missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]
  if (length(missing_pkgs)) {
    utils::install.packages(missing_pkgs, lib = paths$lib_dir, repos = "https://cloud.r-project.org")
  }

  if (!requireNamespace("bqrgal", quietly = TRUE)) {
    cmd <- file.path(R.home("bin"), "R")
    args <- c("CMD", "INSTALL", "--preclean", "-l", shQuote(paths$lib_dir), shQuote(paths$bqrgal_pkg_src))
    rc <- system2(cmd, args = args)
    if (!identical(rc, 0L)) {
      stop(sprintf("failed to install local bqrgal package from %s", paths$bqrgal_pkg_src))
    }
  }

  if (!requireNamespace("bqrgal", quietly = TRUE)) {
    stop("bqrgal is still unavailable after bootstrap")
  }

  invisible(paths$lib_dir)
}

activate_static_bqrgal_lib_20260408 <- function(paths) {
  .libPaths(c(paths$lib_dir, .libPaths()))
  suppressPackageStartupMessages(library(bqrgal))
  source(paths$bqrgal_run_wrapper, local = .GlobalEnv)
  invisible(TRUE)
}

interval_score_static_bqrgal_20260408 <- function(observed, lower, upper, level = 95) {
  alpha <- 1 - level / 100
  width <- upper - lower
  lower_penalty <- (2 / alpha) * (lower - observed) * (observed < lower)
  upper_penalty <- (2 / alpha) * (observed - upper) * (observed > upper)
  width + lower_penalty + upper_penalty
}

compact_bqrgal_fit_20260408 <- function(fit, model) {
  keep_names <- c("be0", "be", "sigma")
  if (identical(model, "exal")) keep_names <- c(keep_names, "ga")
  compact <- fit
  compact$post_sams <- fit$post_sams[intersect(names(fit$post_sams), keep_names)]
  compact$response <- NULL
  compact$covariates <- NULL
  compact$starting <- NULL
  compact$compact_fit <- TRUE
  compact
}

compute_bqrgal_metrics_20260408 <- function(fit, model, XX_train, yy_train, XX_test, yy_test, beta_truth, true_ind) {
  be_sams <- as.matrix(fit$post_sams$be)
  sd_xx <- apply(XX_train, 2, stats::sd)
  sd_yy <- stats::sd(yy_train)

  be_star_sams <- sweep(be_sams, 1L, sd_xx / sd_yy, "*")
  be_ind <- abs(be_star_sams) > 0.1
  cie <- mean(apply(be_ind, 2L, function(x) sum(x == true_ind) / length(true_ind)))

  be_err <- sweep(be_sams, 1L, beta_truth, "-")
  rmse_per_beta <- sqrt(rowMeans(be_err ^ 2))
  beta_qq <- t(apply(be_sams, 1L, stats::quantile, probs = c(0.025, 0.975)))
  beta_cover <- beta_truth >= beta_qq[, 1] & beta_truth <= beta_qq[, 2]

  pred_out <- predict(fit, XX_test, probs = c(0.025, 0.975), err_dens = FALSE, predict_sam = FALSE)
  yy_qq <- pred_out$yy_qq
  pred_is <- interval_score_static_bqrgal_20260408(yy_test, yy_qq[1, ], yy_qq[2, ], level = 95)

  out <- data.frame(
    cie = cie,
    beta_rmse_mean = mean(rmse_per_beta),
    beta_coverage_mean = mean(beta_cover),
    pred_interval_score_mean = mean(pred_is),
    pred_interval_score_median = stats::median(pred_is),
    n_keep = ncol(be_sams),
    stringsAsFactors = FALSE
  )

  for (j in seq_along(beta_truth)) {
    out[[sprintf("beta_rmse_b%02d", j)]] <- rmse_per_beta[j]
    out[[sprintf("beta_cover_b%02d", j)]] <- as.numeric(beta_cover[j])
  }

  out
}

collect_bqrgal_health_metrics_20260408 <- function(fit, case_id, variant, candidate_path, model, runtime_sec) {
  sigma <- as.numeric(fit$post_sams$sigma)
  gamma <- if (identical(model, "exal") && "ga" %in% names(fit$post_sams)) as.numeric(fit$post_sams$ga) else numeric(0)
  has_gamma <- length(gamma) > 0L && any(is.finite(gamma))
  n_keep <- length(sigma)

  ess_sigma <- if (length(sigma) >= 5L) tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(sigma))), error = function(e) NA_real_) else NA_real_
  ess_gamma <- if (has_gamma && length(gamma) >= 5L) tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(gamma))), error = function(e) NA_real_) else NA_real_
  acf1_sigma <- if (length(sigma) >= 10L) tryCatch(as.numeric(stats::acf(sigma, lag.max = 1L, plot = FALSE)$acf[2L]), error = function(e) NA_real_) else NA_real_
  acf1_gamma <- if (has_gamma && length(gamma) >= 10L) tryCatch(as.numeric(stats::acf(gamma, lag.max = 1L, plot = FALSE)$acf[2L]), error = function(e) NA_real_) else NA_real_
  geweke_sigma <- if (length(sigma) >= 20L) tryCatch(as.numeric(abs(coda::geweke.diag(coda::as.mcmc(sigma))$z[1])), error = function(e) NA_real_) else NA_real_
  geweke_gamma <- if (has_gamma && length(gamma) >= 20L) tryCatch(as.numeric(abs(coda::geweke.diag(coda::as.mcmc(gamma))$z[1])), error = function(e) NA_real_) else NA_real_

  half_drift <- function(x) {
    n <- length(x)
    if (n < 20L) return(NA_real_)
    i <- floor(n / 2)
    s <- stats::sd(x)
    if (!is.finite(s) || s <= 0) return(NA_real_)
    abs(mean(x[(i + 1L):n]) - mean(x[1L:i])) / s
  }

  half_drift_sigma <- if (length(sigma) >= 20L) half_drift(sigma) else NA_real_
  half_drift_gamma <- if (has_gamma && length(gamma) >= 20L) half_drift(gamma) else NA_real_

  data.frame(
    case_id = case_id,
    variant = variant,
    mh_kernel = if (identical(model, "exal")) "slice" else "none",
    kernel_exact = TRUE,
    rhs_collapse_flag = FALSE,
    rhs_collapse_sources = NA_character_,
    ess_sigma = ess_sigma,
    ess_gamma = ess_gamma,
    ess_sigma_per1k = if (is.finite(ess_sigma) && n_keep > 0L) ess_sigma / n_keep * 1000 else NA_real_,
    ess_gamma_per1k = if (is.finite(ess_gamma) && n_keep > 0L) ess_gamma / n_keep * 1000 else NA_real_,
    acf1_sigma = acf1_sigma,
    acf1_gamma = acf1_gamma,
    geweke_sigma = geweke_sigma,
    geweke_gamma = geweke_gamma,
    half_drift_sigma = half_drift_sigma,
    half_drift_gamma = half_drift_gamma,
    accept_keep = NA_real_,
    n_burn = safe_num_static_bqrgal(fit$mcmc_settings$n_burn, NA_real_),
    n_mcmc = n_keep,
    run_time_sec = runtime_sec,
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

row_config_path_static_bqrgal_20260408 <- function(paths, row_id) {
  file.path(paths$config_dir, sprintf("row_%04d_run_config.rds", as.integer(row_id)))
}

row_status_path_static_bqrgal_20260408 <- function(paths, row_id) {
  file.path(paths$rows_dir, sprintf("row_%04d.csv", as.integer(row_id)))
}

row_health_path_static_bqrgal_20260408 <- function(paths, row_id) {
  file.path(paths$health_dir, sprintf("health_%04d.csv", as.integer(row_id)))
}

row_metrics_path_static_bqrgal_20260408 <- function(paths, row_id) {
  file.path(paths$metrics_dir, sprintf("metrics_%04d.csv", as.integer(row_id)))
}

fit_path_static_bqrgal_20260408 <- function(paths, lane_label, family, tau_label, n_train, model, rep_id) {
  file.path(
    paths$fits_dir,
    lane_label,
    sprintf("n%d", as.integer(n_train)),
    family,
    sprintf("tau_%s", tau_label),
    model,
    sprintf("%s_%s_n%d_%s_rep%03d.rds", model, family, as.integer(n_train), tau_label, as.integer(rep_id))
  )
}

data_path_for_lane_static_bqrgal_20260408 <- function(paths, lane_label) {
  if (identical(lane_label, "paper_matched_core")) {
    paths$data_core
  } else if (identical(lane_label, "extension_n1000")) {
    paths$data_extension
  } else {
    stop(sprintf("unknown lane_label: %s", lane_label))
  }
}

format_med_sd_static_bqrgal_20260408 <- function(x_med, x_sd, digits = 3L) {
  ifelse(
    is.finite(x_med) & is.finite(x_sd),
    sprintf(paste0("%.", digits, "f (%.", digits, "f)"), x_med, x_sd),
    NA_character_
  )
}
