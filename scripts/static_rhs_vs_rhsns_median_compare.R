#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args <- function(args) {
  out <- list()
  for (a in args) {
    if (grepl("^--[^=]+=.*$", a)) {
      key <- sub("^--([^=]+)=.*$", "\\1", a)
      val <- sub("^--[^=]+=(.*)$", "\\1", a)
      out[[key]] <- val
    } else if (grepl("^--", a)) {
      key <- sub("^--", "", a)
      out[[key]] <- "TRUE"
    }
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  tolower(as.character(x)[1]) %in% c("1", "true", "yes", "y", "t")
}

safe_num1 <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_int1 <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

safe_cor <- function(x, y) {
  out <- suppressWarnings(stats::cor(x, y))
  if (is.finite(out)) as.numeric(out) else NA_real_
}

safe_ess <- function(x) {
  x <- as.numeric(x)
  if (!length(x) || any(!is.finite(x))) return(NA_real_)
  out <- tryCatch(coda::effectiveSize(coda::as.mcmc(x)), error = function(e) NA_real_)
  out <- as.numeric(out)[1]
  if (is.finite(out)) out else NA_real_
}

safe_acf1 <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 10L || any(!is.finite(x))) return(NA_real_)
  ac <- tryCatch(stats::acf(x, lag.max = 1L, plot = FALSE)$acf, error = function(e) NULL)
  if (is.null(ac) || length(ac) < 2L) return(NA_real_)
  as.numeric(ac[2L])
}

safe_geweke <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 20L || any(!is.finite(x))) return(NA_real_)
  z <- tryCatch(coda::geweke.diag(coda::as.mcmc(x))$z, error = function(e) NA_real_)
  z <- as.numeric(z)[1]
  if (is.finite(z)) abs(z) else NA_real_
}

safe_half_drift <- function(x) {
  x <- as.numeric(x)
  n <- length(x)
  if (n < 20L || any(!is.finite(x))) return(NA_real_)
  i <- floor(n / 2L)
  if (i < 5L || (n - i) < 5L) return(NA_real_)
  s <- stats::sd(x)
  if (!is.finite(s) || s <= 0) return(NA_real_)
  abs(mean(x[(i + 1L):n]) - mean(x[1L:i])) / s
}

unwrap_bundle <- function(obj, max_depth = 32L) {
  depth <- 0L
  fit <- obj
  normalized <- NULL
  meta <- NULL
  is_bundle <- function(x) {
    is.list(x) && all(c("fit", "normalized", "meta") %in% names(x))
  }
  while (is_bundle(fit) && depth < max_depth) {
    if (is.null(normalized) && !is.null(fit$normalized)) normalized <- fit$normalized
    if (is.null(meta) && !is.null(fit$meta)) meta <- fit$meta
    fit <- fit$fit
    depth <- depth + 1L
  }
  list(fit = fit, normalized = normalized, meta = meta, depth = depth)
}

resolve_default_run_root <- function(repo_root) {
  candidates <- c(
    file.path(
      repo_root,
      "results/function_testing_20260309_static_shrinkage_family_qspec/gausmix/tau_0p50",
      "fit_input_subsample_tt100_x01_sorted/validation_shrink_rhs_tt100"
    ),
    file.path(
      repo_root,
      "results/function_testing_20260309_static_shrinkage_family_qspec/normal/tau_0p50",
      "fit_input_subsample_tt100_x01_sorted/validation_shrink_rhs_tt100"
    ),
    file.path(
      repo_root,
      "results/function_testing_20260309_static_shrinkage_family_qspec/laplace/tau_0p50",
      "fit_input_subsample_tt100_x01_sorted/validation_shrink_rhs_tt100"
    )
  )
  keep <- candidates[file.exists(candidates)]
  if (length(keep)) return(normalizePath(keep[1], winslash = "/", mustWork = TRUE))

  dynamic <- Sys.glob(file.path(
    repo_root,
    "results/function_testing_20260309_static_shrinkage_family_qspec/*/tau_0p50",
    "fit_input_subsample_tt100_x01_sorted/validation_shrink_rhs_tt100"
  ))
  if (length(dynamic)) {
    return(normalizePath(dynamic[1], winslash = "/", mustWork = TRUE))
  }
  stop("Could not find a default median rhs run_root. Pass --run_root_rhs=... explicitly.")
}

rhs_to_rhsns_controls <- function(ctrl_rhs) {
  ctrl <- ctrl_rhs %||% list()
  nu <- safe_num1(ctrl$nu %||% 4, 4)
  s2 <- safe_num1(ctrl$s2 %||% 1, 1)
  if (!is.finite(ctrl$a_zeta %||% NA_real_)) ctrl$a_zeta <- nu / 2
  if (!is.finite(ctrl$b_zeta %||% NA_real_)) ctrl$b_zeta <- nu * s2 / 2
  ctrl
}

selection_metrics <- function(beta_hat, truth_df, threshold = 0.10) {
  slopes <- !truth_df$term %in% "(Intercept)"
  pred <- abs(beta_hat) > threshold
  truth <- as.logical(truth_df$is_signal)
  pred <- pred[slopes]
  truth <- truth[slopes]
  tp <- sum(pred & truth)
  fp <- sum(pred & !truth)
  fn <- sum(!pred & truth)
  prec <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
  rec <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
  f1 <- if (is.finite(prec) && is.finite(rec) && (prec + rec) > 0) {
    2 * prec * rec / (prec + rec)
  } else {
    NA_real_
  }
  list(precision = prec, recall = rec, f1 = f1, tp = tp, fp = fp, fn = fn)
}

topk_recall <- function(beta_hat, truth_df) {
  slopes <- which(!truth_df$term %in% "(Intercept)")
  truth <- as.logical(truth_df$is_signal[slopes])
  k <- sum(truth)
  if (k <= 0) return(NA_real_)
  ord <- order(abs(beta_hat[slopes]), decreasing = TRUE)
  sel <- rep(FALSE, length(slopes))
  sel[ord[seq_len(min(k, length(ord)))]] <- TRUE
  sum(sel & truth) / k
}

extract_beta_mean <- function(fit) {
  cls <- class(fit)
  if ("exal_static_mcmc" %in% cls || "exal_mcmc" %in% cls) {
    b <- as.matrix(fit$samp.beta)
    return(as.numeric(colMeans(b)))
  }
  if ("exal_vb" %in% cls || "exal_ldvb" %in% cls) {
    return(as.numeric(fit$qbeta$m))
  }
  stop("Unsupported fit class: ", paste(cls, collapse = ","))
}

extract_runtime <- function(fit, meta) {
  rt <- safe_num1(meta$runtime_sec %||% NA_real_, NA_real_)
  if (is.finite(rt)) return(rt)
  safe_num1(fit$run.time %||% NA_real_, NA_real_)
}

extract_rhs_collapse <- function(fit) {
  probes <- c(
    fit$beta_prior$summary$collapse_flag %||% NA,
    fit$rhs.diagnostics$summary$collapse_flag %||% NA,
    fit$diagnostics$rhs$summary$collapse_flag %||% NA,
    fit$diagnostics$rhs$collapse_flag %||% NA
  )
  any(isTRUE(as.logical(probes)))
}

summarize_fit <- function(bundle_obj, algorithm, prior, sim_obj) {
  un <- unwrap_bundle(bundle_obj)
  fit <- un$fit
  meta <- un$meta %||% list()

  truth_df <- sim_obj$extras$coef_truth
  beta_truth <- as.numeric(truth_df$beta_truth)
  X <- as.matrix(sim_obj$extras$X)
  q_true <- if (is.matrix(sim_obj$q)) as.numeric(sim_obj$q[, 1]) else as.numeric(sim_obj$q)

  beta_hat <- extract_beta_mean(fit)
  if (length(beta_hat) != length(beta_truth)) {
    stop("beta dimension mismatch between fit and truth.")
  }

  q_hat <- as.numeric(drop(X %*% beta_hat))

  sig <- as.logical(truth_df$is_signal)
  zero <- as.logical(truth_df$is_zero)
  near_zero <- as.logical(truth_df$is_near_zero)

  sel_010 <- selection_metrics(beta_hat, truth_df, threshold = 0.10)
  sel_005 <- selection_metrics(beta_hat, truth_df, threshold = 0.05)

  ess_sigma <- acf1_sigma <- geweke_sigma <- half_drift_sigma <- NA_real_
  ess_gamma <- acf1_gamma <- geweke_gamma <- half_drift_gamma <- NA_real_
  accept_keep <- NA_real_

  if (identical(algorithm, "mcmc")) {
    sigma_chain <- as.numeric(fit$samp.sigma)
    gamma_chain <- as.numeric(fit$samp.gamma)
    ch_sig <- fit$diagnostics$chain_health$sigma %||% list()
    ch_gam <- fit$diagnostics$chain_health$gamma %||% list()

    ess_sigma <- safe_num1(ch_sig$ess %||% safe_ess(sigma_chain), NA_real_)
    acf1_sigma <- safe_num1(ch_sig$acf1 %||% safe_acf1(sigma_chain), NA_real_)
    geweke_sigma <- safe_num1(ch_sig$geweke_absz %||% safe_geweke(sigma_chain), NA_real_)
    half_drift_sigma <- safe_num1(ch_sig$half_drift %||% safe_half_drift(sigma_chain), NA_real_)

    ess_gamma <- safe_num1(ch_gam$ess %||% safe_ess(gamma_chain), NA_real_)
    acf1_gamma <- safe_num1(ch_gam$acf1 %||% safe_acf1(gamma_chain), NA_real_)
    geweke_gamma <- safe_num1(ch_gam$geweke_absz %||% safe_geweke(gamma_chain), NA_real_)
    half_drift_gamma <- safe_num1(ch_gam$half_drift %||% safe_half_drift(gamma_chain), NA_real_)

    accept_keep <- safe_num1(fit$accept.rate.keep %||% fit$mh.diagnostics$accept$keep %||% NA_real_, NA_real_)
  }

  data.frame(
    algorithm = algorithm,
    prior = prior,
    runtime_sec = extract_runtime(fit, meta),
    iter = safe_num1(fit$iter %||% NA_real_, NA_real_),
    n_burn = safe_num1(fit$n.burn %||% NA_real_, NA_real_),
    n_mcmc = safe_num1(fit$n.mcmc %||% NA_real_, NA_real_),
    rmse_quantile_map = sqrt(mean((q_hat - q_true)^2)),
    mae_quantile_map = mean(abs(q_hat - q_true)),
    beta_rmse_all = sqrt(mean((beta_hat - beta_truth)^2)),
    beta_rmse_signal = sqrt(mean((beta_hat[sig] - beta_truth[sig])^2)),
    beta_rmse_zero = sqrt(mean((beta_hat[zero] - beta_truth[zero])^2)),
    beta_rmse_near_zero = sqrt(mean((beta_hat[near_zero] - beta_truth[near_zero])^2)),
    beta_corr = safe_cor(beta_hat, beta_truth),
    topk_signal_recall = topk_recall(beta_hat, truth_df),
    signal_precision_t010 = sel_010$precision,
    signal_recall_t010 = sel_010$recall,
    signal_f1_t010 = sel_010$f1,
    signal_precision_t005 = sel_005$precision,
    signal_recall_t005 = sel_005$recall,
    signal_f1_t005 = sel_005$f1,
    rhs_collapse_flag = extract_rhs_collapse(fit),
    ess_sigma = ess_sigma,
    acf1_sigma = acf1_sigma,
    geweke_sigma = geweke_sigma,
    half_drift_sigma = half_drift_sigma,
    ess_gamma = ess_gamma,
    acf1_gamma = acf1_gamma,
    geweke_gamma = geweke_gamma,
    half_drift_gamma = half_drift_gamma,
    accept_keep = accept_keep,
    stringsAsFactors = FALSE
  )
}

write_md_summary <- function(path, metrics) {
  by_alg <- split(metrics, metrics$algorithm)
  lines <- c(
    "# RHS vs RHS_NS (Median Static Case)",
    "",
    sprintf("Generated: %s", as.character(Sys.time())),
    ""
  )
  for (alg in names(by_alg)) {
    df <- by_alg[[alg]]
    df <- df[order(df$prior), , drop = FALSE]
    lines <- c(lines, sprintf("## %s", toupper(alg)), "")
    lines <- c(lines, "| prior | rmse_q | beta_rmse_signal | topk_recall | f1@0.10 | runtime_sec | rhs_collapse |")
    lines <- c(lines, "|---|---:|---:|---:|---:|---:|---|")
    for (i in seq_len(nrow(df))) {
      r <- df[i, , drop = FALSE]
      lines <- c(lines, sprintf(
        "| %s | %.4f | %.4f | %.3f | %.3f | %.2f | %s |",
        r$prior, r$rmse_quantile_map, r$beta_rmse_signal, r$topk_signal_recall,
        r$signal_f1_t010, r$runtime_sec, ifelse(isTRUE(r$rhs_collapse_flag), "TRUE", "FALSE")
      ))
    }
    lines <- c(lines, "")
  }
  writeLines(lines, con = path)
}

main <- function() {
  if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload package is required.")
  if (!requireNamespace("coda", quietly = TRUE)) stop("coda package is required.")

  args <- parse_args(commandArgs(trailingOnly = TRUE))
  repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)

  run_root_rhs <- args$run_root_rhs %||% resolve_default_run_root(repo_root)
  run_root_rhs <- normalizePath(run_root_rhs, winslash = "/", mustWork = TRUE)
  cfg_path <- args$run_config_path %||% file.path(run_root_rhs, "tables", "run_config.rds")
  if (!file.exists(cfg_path)) stop("Missing run_config.rds: ", cfg_path)
  cfg <- readRDS(cfg_path)

  sim_path <- args$sim_path %||% cfg$sim_path %||% file.path(dirname(run_root_rhs), "sim_output.rds")
  if (!file.exists(sim_path)) stop("Missing sim_output.rds: ", sim_path)
  sim_obj <- readRDS(sim_path)
  y <- as.numeric(sim_obj$y)
  X <- as.matrix(sim_obj$extras$X)
  storage.mode(X) <- "double"
  p0 <- safe_num1(args$p0 %||% sim_obj$p %||% cfg$taus, NA_real_)
  if (!is.finite(p0) || p0 <= 0 || p0 >= 1) stop("Invalid p0.")

  vb_cfg <- cfg$vb %||% list()
  mcmc_cfg <- cfg$mcmc %||% list()
  rhs_controls <- mcmc_cfg$beta_prior_controls %||% vb_cfg$beta_prior_controls %||% list(
    tau0 = 1, nu = 4, s2 = 1, shrink_intercept = FALSE
  )
  rhsns_controls <- rhs_to_rhsns_controls(rhs_controls)

  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  out_root <- args$out_root %||% file.path(dirname(run_root_rhs), paste0("validation_shrink_rhs_vs_rhsns_", stamp))
  dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out_root, "fits", "vb"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out_root, "fits", "mcmc"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)

  pkgload::load_all(repo_root, quiet = TRUE)

  vb_max_iter <- safe_int1(args$vb_max_iter %||% vb_cfg$max_iter, 300L)
  vb_tol <- safe_num1(args$vb_tol %||% vb_cfg$tol, 0.03)
  vb_n_samp_xi <- safe_int1(args$vb_n_samp_xi %||% vb_cfg$n_samp_xi, 1000L)
  vb_ld <- vb_cfg$ld %||% NULL

  n_burn <- safe_int1(args$n_burn %||% mcmc_cfg$burn, 2000L)
  n_mcmc <- safe_int1(args$n_mcmc %||% mcmc_cfg$n, 1000L)
  thin <- safe_int1(args$thin %||% mcmc_cfg$thin, 1L)
  mh <- mcmc_cfg$mh %||% list()

  mh_proposal <- as.character(args$mh_proposal %||% mh$proposal %||% "laplace_rw")
  mh_adapt <- as_flag(args$mh_adapt %||% mh$adapt, TRUE)
  mh_adapt_interval <- safe_int1(args$mh_adapt_interval %||% mh$adapt_interval, 50L)
  mh_target_accept <- as.numeric(strsplit(args$mh_target_accept %||% paste(mh$target_accept %||% c(0.20, 0.45), collapse = ","), ",", fixed = TRUE)[[1]])
  if (length(mh_target_accept) != 2L || any(!is.finite(mh_target_accept))) mh_target_accept <- c(0.20, 0.45)
  mh_scale_bounds <- as.numeric(strsplit(args$mh_scale_bounds %||% paste(mh$scale_bounds %||% c(0.1, 10), collapse = ","), ",", fixed = TRUE)[[1]])
  if (length(mh_scale_bounds) != 2L || any(!is.finite(mh_scale_bounds))) mh_scale_bounds <- c(0.1, 10)
  mh_max_scale_step <- safe_num1(args$mh_max_scale_step %||% mh$max_scale_step, 0.35)
  mh_min_burn_adapt <- safe_int1(args$mh_min_burn_adapt %||% mh$min_burn_adapt, 50L)
  slice_width <- safe_num1(args$slice_width %||% rhs_controls$slice_width %||% 0.12, 0.12)
  slice_max_steps <- safe_int1(args$slice_max_steps %||% rhs_controls$slice_max_steps %||% 80L, 80L)
  gamma_substeps <- safe_int1(args$gamma_substeps %||% 1L, 1L)
  p_global_eta_jump <- safe_num1(args$p_global_eta_jump %||% 0, 0)
  global_eta_jump_scale <- safe_num1(args$global_eta_jump_scale %||% 1, 1)
  trace_every <- safe_int1(args$trace_every %||% 25L, 25L)

  seed_rhs_vb <- safe_int1(args$seed_rhs_vb %||% 2026032701L, 2026032701L)
  seed_rhs_mcmc <- safe_int1(args$seed_rhs_mcmc %||% 2026032702L, 2026032702L)
  seed_rhsns_vb <- safe_int1(args$seed_rhsns_vb %||% 2026032703L, 2026032703L)
  seed_rhsns_mcmc <- safe_int1(args$seed_rhsns_mcmc %||% 2026032704L, 2026032704L)

  run_fit <- function(algorithm, prior, controls, seed) {
    message(sprintf("[compare] running %s %s ...", algorithm, prior))
    set.seed(seed)
    t0 <- proc.time()[["elapsed"]]
    fit <- if (identical(algorithm, "vb")) {
      exal_static_LDVB(
        y = y,
        X = X,
        p0 = p0,
        beta_prior = prior,
        beta_prior_controls = controls,
        max_iter = vb_max_iter,
        tol = vb_tol,
        n_samp_xi = vb_n_samp_xi,
        ld_controls = vb_ld,
        dqlm.ind = FALSE,
        verbose = FALSE
      )
    } else {
      exal_static_mcmc(
        y = y,
        X = X,
        p0 = p0,
        beta_prior = prior,
        beta_prior_controls = controls,
        dqlm.ind = FALSE,
        n.burn = n_burn,
        n.mcmc = n_mcmc,
        thin = thin,
        init.from.vb = TRUE,
        mh.proposal = mh_proposal,
        mh.adapt = mh_adapt,
        mh.adapt.interval = mh_adapt_interval,
        mh.target.accept = mh_target_accept,
        mh.scale.bounds = mh_scale_bounds,
        mh.max_scale.step = mh_max_scale_step,
        mh.min_burn_adapt = mh_min_burn_adapt,
        slice.width = slice_width,
        slice.max.steps = slice_max_steps,
        gamma.substeps = gamma_substeps,
        p.global.eta.jump = p_global_eta_jump,
        global.eta.jump.scale = global_eta_jump_scale,
        trace.diagnostics = TRUE,
        trace.every = trace_every,
        verbose = FALSE
      )
    }
    elapsed <- proc.time()[["elapsed"]] - t0
    list(
      fit = fit,
      normalized = NULL,
      meta = list(
        model = "exal",
        tau = p0,
        seed = as.integer(seed),
        runtime_sec = as.numeric(elapsed),
        compare_tag = "rhs_vs_rhsns_median"
      )
    )
  }

  vb_rhs <- run_fit("vb", "rhs", rhs_controls, seed_rhs_vb)
  vb_rhsns <- run_fit("vb", "rhs_ns", rhsns_controls, seed_rhsns_vb)
  mcmc_rhs <- run_fit("mcmc", "rhs", rhs_controls, seed_rhs_mcmc)
  mcmc_rhsns <- run_fit("mcmc", "rhs_ns", rhsns_controls, seed_rhsns_mcmc)

  saveRDS(vb_rhs, file.path(out_root, "fits", "vb", sprintf("vb_exal_tau_%s_rhs_fit.rds", gsub("\\.", "p", sprintf("%.2f", p0)))))
  saveRDS(vb_rhsns, file.path(out_root, "fits", "vb", sprintf("vb_exal_tau_%s_rhs_ns_fit.rds", gsub("\\.", "p", sprintf("%.2f", p0)))))
  saveRDS(mcmc_rhs, file.path(out_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_rhs_fit.rds", gsub("\\.", "p", sprintf("%.2f", p0)))))
  saveRDS(mcmc_rhsns, file.path(out_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_rhs_ns_fit.rds", gsub("\\.", "p", sprintf("%.2f", p0)))))

  metrics <- rbind(
    summarize_fit(vb_rhs, algorithm = "vb", prior = "rhs", sim_obj = sim_obj),
    summarize_fit(vb_rhsns, algorithm = "vb", prior = "rhs_ns", sim_obj = sim_obj),
    summarize_fit(mcmc_rhs, algorithm = "mcmc", prior = "rhs", sim_obj = sim_obj),
    summarize_fit(mcmc_rhsns, algorithm = "mcmc", prior = "rhs_ns", sim_obj = sim_obj)
  )

  write.csv(metrics, file.path(out_root, "tables", "rhs_vs_rhsns_metrics.csv"), row.names = FALSE)

  truth_df <- sim_obj$extras$coef_truth
  make_coef_tbl <- function(bundle_obj, algorithm, prior) {
    fit <- unwrap_bundle(bundle_obj)$fit
    beta_hat <- extract_beta_mean(fit)
    data.frame(
      algorithm = algorithm,
      prior = prior,
      term = truth_df$term,
      beta_truth = as.numeric(truth_df$beta_truth),
      beta_hat = beta_hat,
      abs_error = abs(beta_hat - as.numeric(truth_df$beta_truth)),
      is_signal = as.logical(truth_df$is_signal),
      is_zero = as.logical(truth_df$is_zero),
      stringsAsFactors = FALSE
    )
  }
  coef_tbl <- rbind(
    make_coef_tbl(vb_rhs, "vb", "rhs"),
    make_coef_tbl(vb_rhsns, "vb", "rhs_ns"),
    make_coef_tbl(mcmc_rhs, "mcmc", "rhs"),
    make_coef_tbl(mcmc_rhsns, "mcmc", "rhs_ns")
  )
  write.csv(coef_tbl, file.path(out_root, "tables", "rhs_vs_rhsns_coef_recovery.csv"), row.names = FALSE)
  write_md_summary(file.path(out_root, "tables", "rhs_vs_rhsns_summary.md"), metrics)

  cmp <- metrics[, c(
    "algorithm", "prior", "rmse_quantile_map", "beta_rmse_signal",
    "topk_signal_recall", "signal_f1_t010", "runtime_sec", "rhs_collapse_flag"
  )]
  rownames(cmp) <- NULL
  print(cmp)

  message("[compare] done.")
  message("[compare] out_root: ", out_root)
  message("[compare] metrics: ", file.path(out_root, "tables", "rhs_vs_rhsns_metrics.csv"))
  message("[compare] summary: ", file.path(out_root, "tables", "rhs_vs_rhsns_summary.md"))
}

main()

