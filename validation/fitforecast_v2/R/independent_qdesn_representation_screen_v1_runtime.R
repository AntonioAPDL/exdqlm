iqrs_v1_write_status <- function(cfg, status, started, extra = list()) {
  payload <- c(list(
    schema_version = iqrs_v1_schema, job_id = cfg$job_id,
    stage = cfg$stage, status = status,
    config_path = cfg$config_path %||% NA_character_,
    pid = Sys.getpid(), host = unname(Sys.info()[["nodename"]]),
    started_at = format(started, "%Y-%m-%dT%H:%M:%S%z")
  ), extra)
  iqfr_v2_write_json(payload, as.character(cfg$status_path))
}

iqrs_v1_normal_fit <- function(X, y, prior_family, scale, budget) {
  if (identical(prior_family, "scaled_ridge")) {
    normal_desn_fit(
      X, y, beta_prior_type = "scaled_ridge",
      prior = list(beta_ridge_tau2 = as.numeric(scale), intercept_var = 1e6),
      omega_prior = list(a = 2, b = 1)
    )
  } else {
    normal_desn_fit(
      X, y, beta_prior_type = "rhs_ns",
      rhs = list(tau0 = as.numeric(scale), s2 = 1,
                 shrink_intercept = FALSE, n_inner = 2L),
      omega_prior = list(a = 2, b = 1),
      control = list(
        max_iter = iqfr_v2_integer(budget$max_iter, 200L),
        min_iter = iqfr_v2_integer(budget$min_iter, 10L),
        tol = iqfr_v2_number(budget$tol, 1e-5), verbose = FALSE,
        covariance = "woodbury_diagonal"
      )
    )
  }
}

iqrs_v1_lead_mae <- function(error, lead, lo, hi) {
  keep <- lead >= lo & lead <= hi
  if (!any(keep)) return(NA_real_)
  mean(abs(error[keep]))
}

iqrs_v1_normal_job <- function(config_path) {
  started <- Sys.time()
  config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
  cfg <- iqfr_v2_read_json(config_path)
  cfg$config_path <- config_path
  iqrs_v1_write_status(cfg, "RUNNING", started)
  tryCatch({
    source_path <- as.character(iqfr_v2_scalar(cfg$source$frozen_path))
    source_hash <- as.character(iqfr_v2_scalar(cfg$source$frozen_sha256))
    if (!identical(iqfr_v2_sha256(source_path), source_hash)) {
      stop("Frozen source hash mismatch.", call. = FALSE)
    }
    x <- iqfr_v2_source_rows(source_path)
    candidate <- cfg$candidate
    folds <- as.data.frame(cfg$folds, stringsAsFactors = FALSE)
    scales <- as.numeric(cfg$scale_grid)
    prior_family <- if (identical(cfg$stage, "ridge_screen")) {
      "scaled_ridge"
    } else "rhs_ns"
    rows <- list()
    k <- 0L
    for (fold_index in seq_len(nrow(folds))) {
      fold <- folds[fold_index, , drop = FALSE]
      fit_end <- as.integer(fold$fit_end)
      origin_start <- as.integer(fold$origin_start)
      origin_end <- as.integer(fold$origin_end)
      origin_stride <- as.integer(fold$origin_stride)
      rollout_end <- origin_end + 30L
      fit_rows <- x$t >= 8501L & x$t <= fit_end
      rollout_rows <- x$t <= rollout_end
      preprocess <- iqfr_v2_training_preprocess(
        x$y[fit_rows], iqfr_v2_scalar(candidate$center_scale)
      )
      design <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
        y = x$y[rollout_rows], candidate = candidate,
        preprocess = preprocess, p0 = 0.5, fit_readout = FALSE
      ))
      expected_rollout_rows <- rollout_end - 8500L
      iqfr_v2_assert_design(design, candidate, expected_rollout_rows)
      fit_n <- fit_end - 8500L
      X_fit <- design$X[seq_len(fit_n), , drop = FALSE]
      y_fit <- design$y_fit[seq_len(fit_n)]
      if (!identical(as.numeric(y_fit), as.numeric(x$y[fit_rows]))) {
        stop("Normal fold alignment failed.", call. = FALSE)
      }
      origins_source <- seq.int(origin_start, origin_end, by = origin_stride)
      origins_local <- origins_source - 8110L
      for (scale in scales) {
        readout <- iqrs_v1_normal_fit(
          X_fit, y_fit, prior_family, scale, cfg$budget
        )
        fitted <- design
        fitted$fit <- readout
        fitted$mu_hat <- as.numeric(fitted$X %*% readout$beta$mean)
        fitted$meta$inference_method <- if (prior_family == "scaled_ridge") {
          "normal_exact"
        } else "normal_vb"
        fitted$meta$likelihood_family <- "normal"
        fitted$meta$target <- "conditional_mean"
        class(fitted) <- c("qdesn_normal_fit", "list")
        fc <- iqfr_v2_normal_forecast(
          fitted, y_all = x$y[rollout_rows], origins = origins_local, H = 30L
        )
        fc$source_target <- fc$target + 8110L
        target_row <- match(fc$source_target, x$t)
        if (anyNA(target_row)) stop("Normal forecast alignment failed.",
                                    call. = FALSE)
        forecast_error <- fc$prediction - x$mu[target_row]
        observed_error <- fc$prediction - x$y[target_row]
        fit_prediction <- as.numeric(X_fit %*% readout$beta$mean)
        fit_error <- fit_prediction - x$mu[fit_rows]
        trace <- readout$trace %||% data.frame()
        covariance <- readout$qbeta$covariance_approximation %||%
          readout$target_label %||% "exact"
        k <- k + 1L
        rows[[k]] <- data.frame(
          schema_version = iqrs_v1_schema, stage = cfg$stage,
          job_id = cfg$job_id,
          family = as.character(iqfr_v2_scalar(candidate$family)),
          structure_id = as.character(iqfr_v2_scalar(candidate$structure_id)),
          structure_signature = as.character(
            iqfr_v2_scalar(candidate$structure_signature)
          ),
          generation = as.character(iqfr_v2_scalar(candidate$generation)),
          fold_id = as.character(fold$fold_id),
          fit_end = fit_end, origin_start = origin_start,
          origin_end = origin_end, origin_stride = origin_stride,
          prior_family = prior_family, prior_scale = scale,
          D = iqfr_v2_integer(candidate$D),
          n = as.character(iqfr_v2_scalar(candidate$n)),
          n_tilde = as.character(iqfr_v2_scalar(candidate$n_tilde)),
          total_states = iqfr_v2_integer(candidate$total_states),
          readout_dimension = iqfr_v2_integer(candidate$readout_dimension),
          m = iqfr_v2_integer(candidate$m),
          alpha = iqfr_v2_number(candidate$alpha),
          rho = iqfr_v2_number(candidate$rho),
          center_scale = preprocess$method,
          input_bound = as.character(iqfr_v2_scalar(candidate$input_bound)),
          input_gain = iqfr_v2_number(candidate$input_gain),
          recurrent_indegree = iqfr_v2_integer(candidate$recurrent_indegree),
          input_fanin_fraction = iqfr_v2_number(
            candidate$input_fanin_fraction
          ),
          input_fanin = iqfr_v2_integer(candidate$input_fanin),
          interlayer_fanin = iqfr_v2_integer(candidate$interlayer_fanin),
          matrix_seed = iqfr_v2_integer(candidate$matrix_seed),
          exact_identity_projection = all(design$reservoir$Q_is_identity),
          fit_oracle_location_rmse = sqrt(mean(fit_error^2)),
          fit_oracle_location_mae = mean(abs(fit_error)),
          forecast_oracle_location_mae = mean(abs(forecast_error)),
          forecast_oracle_location_rmse = sqrt(mean(forecast_error^2)),
          forecast_observed_mae = mean(abs(observed_error)),
          lead_1_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 1L, 1L),
          leads_2_5_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 2L, 5L),
          leads_6_15_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 6L, 15L),
          leads_16_30_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 16L, 30L),
          state_saturation_fraction = mean(abs(design$X[, -1L]) >= 0.99),
          zero_variance_readout_columns = sum(
            apply(X_fit[, -1L, drop = FALSE], 2L, stats::sd) <= 1e-12
          ),
          normal_iterations = nrow(trace),
          normal_converged = if (prior_family == "scaled_ridge") TRUE else
            isTRUE(readout$converged),
          covariance_approximation = as.character(covariance),
          forecast_origins = length(origins_local),
          forecast_pairs = nrow(fc), stringsAsFactors = FALSE
        )
        numeric <- unlist(rows[[k]][vapply(rows[[k]], is.numeric,
                                           logical(1L))], use.names = FALSE)
        if (any(!is.finite(numeric)) ||
            !isTRUE(rows[[k]]$exact_identity_projection[[1L]])) {
          stop("Normal-screen finite/identity contract failed.", call. = FALSE)
        }
      }
      rm(design, fitted, readout, fc)
      gc(verbose = FALSE)
    }
    result <- do.call(rbind, rows)
    result$runtime_seconds_job <- as.numeric(difftime(
      Sys.time(), started, units = "secs"
    ))
    iqfr_v2_write_csv(result, as.character(cfg$result_path))
    finished <- Sys.time()
    iqrs_v1_write_status(cfg, "SUCCESS", started, list(
      finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      rows = nrow(result), result_path = cfg$result_path,
      result_sha256 = iqfr_v2_sha256(cfg$result_path),
      fitted_model_binaries = 0L
    ))
    invisible(result)
  }, error = function(e) {
    finished <- Sys.time()
    iqrs_v1_write_status(cfg, "FAILED", started, list(
      finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      error_class = class(e)[[1L]], error_message = conditionMessage(e)
    ))
    stop(e)
  })
}

iqrs_v1_stage_health <- function(plan_path) {
  iqfr_v2_stage_health(plan_path)
}

iqrs_v1_pending_configs <- function(plan_path) {
  iqfr_v2_pending_configs(plan_path)
}

iqrs_v1_result_key_columns <- function(stage) {
  switch(
    as.character(stage),
    ridge_screen =,
    rhs_screen = c("job_id", "fold_id", "prior_scale"),
    quantile_vb = c("job_id", "fold_id", "likelihood_family", "tau"),
    quantile_refinement = c(
      "job_id", "fold_id", "likelihood_family", "tau"
    ),
    mcmc_pilot =,
    replication =,
    confirmation = c("job_id", "estimator"),
    stop("Unsupported result-key stage: ", stage, call. = FALSE)
  )
}

iqrs_v1_collect_results <- function(plan_path, require_complete = TRUE) {
  plan <- utils::read.csv(plan_path, check.names = FALSE,
                          stringsAsFactors = FALSE)
  health <- iqrs_v1_stage_health(plan_path)
  if (isTRUE(require_complete) && !isTRUE(health$complete[[1L]])) {
    stop("Stage is not completely successful: ", basename(plan_path),
         call. = FALSE)
  }
  paths <- plan$result_path[file.exists(plan$result_path)]
  if (!length(paths)) return(data.frame())
  out <- do.call(rbind, lapply(paths, utils::read.csv,
                              check.names = FALSE, stringsAsFactors = FALSE))
  plan_stage <- unique(as.character(plan$stage))
  if (length(plan_stage) != 1L) {
    stop("A result plan must contain exactly one stage.", call. = FALSE)
  }
  key_columns <- iqrs_v1_result_key_columns(plan_stage)
  if (!all(key_columns %in% names(out))) {
    stop("Result ledger is missing its stage-specific key columns: ",
         paste(setdiff(key_columns, names(out)), collapse = ", "),
         call. = FALSE)
  }
  keys <- do.call(paste, c(out[key_columns], sep = "|"))
  if (anyDuplicated(keys)) {
    stop("Duplicate stage-specific result rows.", call. = FALSE)
  }
  rownames(out) <- NULL
  out
}

iqrs_v1_pareto_flag <- function(x, fields) {
  values <- as.matrix(x[fields])
  vapply(seq_len(nrow(values)), function(i) {
    delta <- sweep(values, 2L, values[i, ], FUN = "-")
    dominated <- rowSums(delta <= 0) == ncol(values) &
      rowSums(delta < 0) > 0
    !any(dominated)
  }, logical(1L))
}

iqrs_v1_aggregate_normal <- function(results) {
  required <- c("family", "structure_id", "prior_scale", "fold_id",
                "fit_oracle_location_rmse", "forecast_oracle_location_mae")
  if (!all(required %in% names(results))) {
    stop("Normal results lack robust-ranking columns.", call. = FALSE)
  }
  key <- interaction(results$family, results$structure_id,
                     results$prior_scale, drop = TRUE)
  rows <- lapply(split(results, key), function(x) {
    if (length(unique(x$fold_id)) != 2L) {
      stop("Normal candidate lacks both blocked folds.", call. = FALSE)
    }
    first <- x[1L, setdiff(names(x), c(
      "fold_id", "fit_end", "origin_start", "origin_end", "origin_stride",
      "fit_oracle_location_rmse", "fit_oracle_location_mae",
      "forecast_oracle_location_mae", "forecast_oracle_location_rmse",
      "forecast_observed_mae", "lead_1_mae", "leads_2_5_mae",
      "leads_6_15_mae", "leads_16_30_mae", "normal_iterations",
      "normal_converged", "forecast_origins", "forecast_pairs",
      "runtime_seconds_job"
    )), drop = FALSE]
    cbind(first, data.frame(
      folds = 2L,
      median_fit_rmse = stats::median(x$fit_oracle_location_rmse),
      worst_fit_rmse = max(x$fit_oracle_location_rmse),
      median_forecast_mae = stats::median(x$forecast_oracle_location_mae),
      worst_forecast_mae = max(x$forecast_oracle_location_mae),
      median_forecast_rmse = stats::median(x$forecast_oracle_location_rmse),
      median_lead_1_mae = stats::median(x$lead_1_mae),
      median_leads_2_5_mae = stats::median(x$leads_2_5_mae),
      median_leads_6_15_mae = stats::median(x$leads_6_15_mae),
      median_leads_16_30_mae = stats::median(x$leads_16_30_mae),
      all_converged = all(x$normal_converged), stringsAsFactors = FALSE
    ))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  by_family <- split(out, out$family)
  out <- do.call(rbind, lapply(by_family, function(x) {
    x$robust_score <- rank(x$median_forecast_mae, ties.method = "average") +
      0.50 * rank(x$worst_forecast_mae, ties.method = "average") +
      0.20 * rank(x$median_fit_rmse, ties.method = "average") +
      0.10 * rank(x$median_leads_16_30_mae, ties.method = "average")
    x$pareto <- iqrs_v1_pareto_flag(
      x, c("median_forecast_mae", "worst_forecast_mae", "median_fit_rmse")
    )
    x
  }))
  rownames(out) <- NULL
  out
}

iqrs_v1_best_scale_per_structure <- function(ranked) {
  key <- interaction(ranked$family, ranked$structure_id, drop = TRUE)
  rows <- lapply(split(ranked, key), function(x) {
    x <- x[order(x$robust_score, x$median_forecast_mae,
                 x$median_fit_rmse, x$prior_scale), , drop = FALSE]
    x[1L, , drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqrs_v1_select_diverse <- function(ranked, n_per_family) {
  best <- iqrs_v1_best_scale_per_structure(ranked)
  rows <- lapply(iqrs_v1_families, function(family) {
    x <- best[best$family == family, , drop = FALSE]
    x$capacity_stratum <- cut(
      x$total_states, breaks = c(-Inf, 250, 600, 1200, 1800),
      labels = c("small", "medium", "large", "very_large")
    )
    x$lag_stratum <- cut(x$m, breaks = c(-Inf, 60, 150, 300),
                         labels = c("short", "medium", "long"))
    x$memory_stratum <- ifelse(x$alpha >= 0.4 & x$rho >= 0.9,
                               "high_memory", "general")
    x <- x[order(!x$pareto, x$robust_score, x$median_forecast_mae,
                 x$structure_id), , drop = FALSE]
    seeds <- integer()
    strata <- c(
      paste0("D", 1:4), paste0("C", levels(x$capacity_stratum)),
      paste0("L", levels(x$lag_stratum)), "Mhigh_memory", "Mgeneral"
    )
    for (stratum in strata) {
      eligible <- if (substr(stratum, 1L, 1L) == "D") {
        which(x$D == as.integer(sub("D", "", stratum)))
      } else if (substr(stratum, 1L, 1L) == "C") {
        which(as.character(x$capacity_stratum) == sub("C", "", stratum))
      } else if (substr(stratum, 1L, 1L) == "L") {
        which(as.character(x$lag_stratum) == sub("L", "", stratum))
      } else which(x$memory_stratum == sub("M", "", stratum))
      eligible <- setdiff(eligible, seeds)
      if (length(eligible)) seeds <- c(seeds, eligible[[1L]])
    }
    order_all <- unique(c(seeds, seq_len(nrow(x))))
    if (length(order_all) < n_per_family) {
      stop("Insufficient diverse candidates for ", family, call. = FALSE)
    }
    out <- x[order_all[seq_len(n_per_family)], , drop = FALSE]
    out$selection_rank <- seq_len(nrow(out))
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqrs_v1_finalize_rhs_candidates <- function(selected, structures) {
  rows <- vector("list", nrow(selected))
  for (i in seq_len(nrow(selected))) {
    structure <- structures[
      structures$structure_id == selected$structure_id[[i]], , drop = FALSE
    ]
    if (nrow(structure) != 1L) stop("Structure lookup failed.", call. = FALSE)
    tau0 <- as.numeric(selected$prior_scale[[i]])
    structure$rhs_tau0 <- tau0
    structure$tau0_base <- tau0
    structure$tau0_mode <- "absolute"
    structure$tau_arm <- iqfr_v2_tau_arm_label(tau0)
    structure$tau_arm_index <- NA_integer_
    structure$candidate_signature <- paste(
      iqrs_v1_schema, structure$structure_signature,
      format(tau0, digits = 14, scientific = TRUE), sep = "|"
    )
    hash <- digest::digest(structure$candidate_signature, algo = "sha256",
                           serialize = FALSE)
    structure$candidate_id <- sprintf("iqrs1_%s_%s", structure$family,
                                      substr(hash, 1L, 12L))
    structure$normal_selection_rank <- selected$selection_rank[[i]]
    structure$normal_robust_score <- selected$robust_score[[i]]
    rows[[i]] <- structure
  }
  out <- iqrs_v1_bind_rows(rows)
  if (anyDuplicated(out$candidate_id) || anyDuplicated(out$candidate_signature)) {
    stop("Final RHS candidate identity collision.", call. = FALSE)
  }
  out
}

iqrs_v1_materialize_quantile_plan <- function(repo_root, run_root, protocol,
                                               candidates, sources) {
  rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    family_sources <- sources[sources$family == candidate$family[[1L]],
                              , drop = FALSE]
    family_sources <- family_sources[order(family_sources$tau), , drop = FALSE]
    if (nrow(family_sources) != 3L) stop("Incomplete quantile source set.")
    job_id <- paste("quantile_vb", candidate$candidate_id[[1L]], sep = "__")
    row <- iqrs_v1_make_job_config(
      repo_root, run_root, protocol, "quantile_vb", job_id,
      payload = list(
        candidate = as.list(candidate), sources = family_sources,
        folds = protocol$selection$blocked_folds,
        budget = protocol$inference$quantile_vb,
        seed = iqfr_v2_seed(protocol$protocol$id, "quantile_vb", job_id)
      ),
      plan_fields = list(family = candidate$family[[1L]],
                         candidate_id = candidate$candidate_id[[1L]])
    )
    rows[[i]] <- as.data.frame(row, stringsAsFactors = FALSE)
  }
  plan <- iqrs_v1_bind_rows(rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans", "quantile_vb.csv"))
  plan
}

iqrs_v1_quantile_vb_job <- function(config_path) {
  started <- Sys.time()
  config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
  cfg <- iqfr_v2_read_json(config_path)
  cfg$config_path <- config_path
  iqrs_v1_write_status(cfg, "RUNNING", started)
  tryCatch({
    candidate <- cfg$candidate
    sources <- as.data.frame(cfg$sources, stringsAsFactors = FALSE)
    sources$tau <- as.numeric(sources$tau)
    if (!identical(sort(sources$tau), iqrs_v1_quantiles)) {
      stop("Quantile VB source set is incomplete.", call. = FALSE)
    }
    if (any(vapply(sources$frozen_path, iqfr_v2_sha256, character(1L)) !=
            sources$frozen_sha256)) {
      stop("Quantile VB source hash mismatch.", call. = FALSE)
    }
    data_by_tau <- setNames(lapply(sources$frozen_path, iqfr_v2_source_rows),
                            sprintf("%.2f", sources$tau))
    x0 <- data_by_tau[["0.50"]]
    folds <- as.data.frame(cfg$folds, stringsAsFactors = FALSE)
    rows <- list()
    k <- 0L
    for (fold_index in seq_len(nrow(folds))) {
      fold <- folds[fold_index, , drop = FALSE]
      fit_end <- as.integer(fold$fit_end)
      origin_start <- as.integer(fold$origin_start)
      origin_end <- as.integer(fold$origin_end)
      rollout_end <- origin_end + 30L
      fit_rows0 <- x0$t >= 8501L & x0$t <= fit_end
      train_rows0 <- x0$t <= fit_end
      preprocess <- iqfr_v2_training_preprocess(
        x0$y[fit_rows0], iqfr_v2_scalar(candidate$center_scale)
      )
      normal_args <- list(
        beta_prior_type = "rhs_ns",
        rhs = list(tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = 1,
                   shrink_intercept = FALSE, n_inner = 2L),
        control = list(max_iter = 200L, min_iter = 10L, tol = 1e-5,
                       covariance = "woodbury_diagonal", verbose = FALSE)
      )
      normal_fit <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
        y = x0$y[train_rows0], candidate = candidate,
        preprocess = preprocess, p0 = 0.5, fit_readout = TRUE,
        normal_args = normal_args
      ))
      iqfr_v2_assert_design(normal_fit, candidate, fit_end - 8500L)
      origins_source <- seq.int(origin_start, origin_end,
                                by = as.integer(fold$origin_stride))
      origins_local <- origins_source - 8110L
      for (likelihood in c("al", "exal")) {
        previous_fit <- NULL
        for (tau in c(0.50, 0.25, 0.05)) {
          x <- data_by_tau[[sprintf("%.2f", tau)]]
          fit_rows <- x$t >= 8501L & x$t <= fit_end
          train_rows <- x$t <= fit_end
          rollout_rows <- x$t <= rollout_end
          init <- if (is.null(previous_fit)) {
            qdesn_normal_to_vb_init(
              normal_fit, likelihood_family = likelihood,
              beta_prior_type = "rhs_ns", p0 = tau
            )
          } else iqfr_v2_quantile_init_from_fit(previous_fit, tau, likelihood)
          vb_args <- list(
            likelihood_family = likelihood,
            al_fixed_gamma = if (likelihood == "al") 0 else NULL,
            beta_prior_type = "rhs_ns",
            beta_rhs = list(
              tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = 1,
              shrink_intercept = FALSE, n_inner = 2L
            ),
            max_iter = iqfr_v2_integer(cfg$budget$max_iter, 750L),
            min_iter_elbo = 10L,
            tol = iqfr_v2_number(cfg$budget$tol, 1e-4),
            tol_par = iqfr_v2_number(cfg$budget$tol, 1e-4),
            n_samp_xi = iqfr_v2_integer(cfg$budget$n_samp_xi, 400L),
            verbose = FALSE, init = init,
            sigmagam = exal_make_vb_sigmagam_control(),
            beta_covariance = list(approximation = "diagonal",
                                   label_uncertainty = TRUE)
          )
          fit_args <- iqfr_v2_design_args(
            y = x$y[train_rows], candidate = candidate,
            preprocess = preprocess, p0 = tau, fit_readout = TRUE
          )
          fit_args$normal_args <- NULL
          fit_args$vb_args <- vb_args
          fit <- do.call(qdesn_fit_vb, fit_args)
          iqfr_v2_assert_design(fit, candidate, fit_end - 8500L)
          rollout_args <- iqfr_v2_design_args(
            y = x$y[rollout_rows], candidate = candidate,
            preprocess = preprocess, p0 = tau, fit_readout = FALSE
          )
          rollout_args$normal_args <- NULL
          rollout_args$vb_args <- list()
          rollout <- do.call(qdesn_fit_vb, rollout_args)
          iqfr_v2_assert_design(rollout, candidate, rollout_end - 8500L)
          rollout <- iqfr_v2_attach_quantile_readout(rollout, fit)
          lattice <- forecast_lattice.qdesn_fit(
            rollout, y_all = x$y[rollout_rows], origins = origins_local,
            H = 30L, nd = 1L, draws = iqfr_v2_quantile_point_draws(fit),
            keep_origin_draws = TRUE, build_mix = FALSE, seed = 1L,
            recursion_mode = "conditional_mean_plugin"
          )
          fc <- iqfr_v2_flatten_lattice(lattice, origins_local)
          fc$source_target <- fc$target + 8110L
          target_row <- match(fc$source_target, x$t)
          if (anyNA(target_row)) stop("Quantile forecast alignment failed.",
                                      call. = FALSE)
          fit_q <- as.numeric(fit$X %*% fit$fit$qbeta$m)
          forecast_error <- fc$prediction - x$q_target[target_row]
          elbo <- fit$fit$misc$elbo_trace %||% numeric()
          k <- k + 1L
          rows[[k]] <- data.frame(
            schema_version = iqrs_v1_schema, stage = cfg$stage,
            job_id = cfg$job_id,
            family = as.character(iqfr_v2_scalar(candidate$family)),
            candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
            candidate_signature = as.character(
              iqfr_v2_scalar(candidate$candidate_signature)
            ),
            structure_id = as.character(iqfr_v2_scalar(candidate$structure_id)),
            structure_signature = as.character(
              iqfr_v2_scalar(candidate$structure_signature)
            ),
            fold_id = as.character(fold$fold_id), likelihood_family = likelihood,
            model_variant = if (likelihood == "al") "qdesn_al_rhs" else
              "qdesn_exal_rhs",
            tau = tau, rhs_tau0 = iqfr_v2_number(candidate$rhs_tau0),
            fit_qtrue_rmse = sqrt(mean((fit_q - x$q_target[fit_rows])^2)),
            fit_qtrue_mae = mean(abs(fit_q - x$q_target[fit_rows])),
            fit_check_loss = mean(iqfr_v2_check_loss(
              x$y[fit_rows], fit_q, tau
            )),
            forecast_qtrue_mae = mean(abs(forecast_error)),
            forecast_qtrue_rmse = sqrt(mean(forecast_error^2)),
            forecast_check_loss = mean(iqfr_v2_check_loss(
              x$y[target_row], fc$prediction, tau
            )),
            lead_1_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 1L, 1L),
            leads_2_5_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 2L, 5L),
            leads_6_15_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 6L, 15L),
            leads_16_30_mae = iqrs_v1_lead_mae(forecast_error, fc$lead, 16L, 30L),
            vb_iterations = length(elbo),
            sigmagam_factorization = as.character(
              fit$fit$misc$sigmagam$factorization %||% "structured"
            ),
            exact_identity_projection = all(fit$reservoir$Q_is_identity),
            forecast_origins = length(origins_local),
            forecast_pairs = nrow(fc), stringsAsFactors = FALSE
          )
          numeric <- unlist(rows[[k]][vapply(rows[[k]], is.numeric,
                                             logical(1L))], use.names = FALSE)
          if (any(!is.finite(numeric)) ||
              !isTRUE(rows[[k]]$exact_identity_projection[[1L]])) {
            stop("Quantile VB finite/identity contract failed.", call. = FALSE)
          }
          previous_fit <- fit
          rm(rollout, lattice, fc)
          gc(verbose = FALSE)
        }
      }
      rm(normal_fit)
      gc(verbose = FALSE)
    }
    result <- do.call(rbind, rows)
    result$runtime_seconds_job <- as.numeric(difftime(
      Sys.time(), started, units = "secs"
    ))
    iqfr_v2_write_csv(result, as.character(cfg$result_path))
    finished <- Sys.time()
    iqrs_v1_write_status(cfg, "SUCCESS", started, list(
      finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      rows = nrow(result), result_path = cfg$result_path,
      result_sha256 = iqfr_v2_sha256(cfg$result_path),
      fitted_model_binaries = 0L
    ))
    invisible(result)
  }, error = function(e) {
    finished <- Sys.time()
    iqrs_v1_write_status(cfg, "FAILED", started, list(
      finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      error_class = class(e)[[1L]], error_message = conditionMessage(e)
    ))
    stop(e)
  })
}

iqrs_v1_rank_quantile <- function(results) {
  key <- interaction(results$family, results$tau,
                     results$likelihood_family, results$candidate_id,
                     drop = TRUE)
  rows <- lapply(split(results, key), function(x) {
    if (length(unique(x$fold_id)) != 2L) {
      stop("Quantile candidate lacks both blocked folds.", call. = FALSE)
    }
    first <- x[1L, c("family", "tau", "likelihood_family", "model_variant",
                     "candidate_id", "candidate_signature", "structure_id",
                     "structure_signature", "rhs_tau0"), drop = FALSE]
    cbind(first, data.frame(
      median_fit_rmse = stats::median(x$fit_qtrue_rmse),
      worst_fit_rmse = max(x$fit_qtrue_rmse),
      median_forecast_mae = stats::median(x$forecast_qtrue_mae),
      worst_forecast_mae = max(x$forecast_qtrue_mae),
      median_forecast_rmse = stats::median(x$forecast_qtrue_rmse),
      median_forecast_check_loss = stats::median(x$forecast_check_loss),
      median_leads_16_30_mae = stats::median(x$leads_16_30_mae),
      stringsAsFactors = FALSE
    ))
  })
  out <- do.call(rbind, rows)
  cell <- interaction(out$family, out$tau, out$likelihood_family, drop = TRUE)
  ranked <- lapply(split(out, cell), function(x) {
    x$selection_score <- rank(x$median_forecast_mae, ties.method = "average") +
      0.50 * rank(x$worst_forecast_mae, ties.method = "average") +
      0.20 * rank(x$median_fit_rmse, ties.method = "average") +
      0.10 * rank(x$median_forecast_check_loss, ties.method = "average")
    x <- x[order(x$selection_score, x$median_forecast_mae,
                 x$worst_forecast_mae, x$candidate_id), , drop = FALSE]
    x$selection_rank <- seq_len(nrow(x))
    x
  })
  out <- do.call(rbind, ranked)
  rownames(out) <- NULL
  out
}

iqrs_v1_make_mcmc_configs <- function(repo_root, run_root, protocol, selected,
                                       candidates, sources, plan_stage,
                                       chain_ids, budget, confirmation = FALSE) {
  rows <- list()
  k <- 0L
  estimators <- if (confirmation) {
    c("posterior_predictive", "posterior_predictive_mean_readout_state")
  } else "posterior_predictive_mean_readout_state"
  contract <- if (confirmation) list(
    source_offset = 8110L, train_end = 9000L, rollout_end = 10000L,
    origin_start = 9000L, origin_end = 9970L, origin_stride = 1L,
    horizon = 30L, estimators = estimators, export_origin_lead = TRUE
  ) else list(
    source_offset = 8110L, train_end = 8800L, rollout_end = 9000L,
    origin_start = 8800L, origin_end = 8970L, origin_stride = 1L,
    horizon = 30L, estimators = estimators, export_origin_lead = FALSE
  )
  worker_stage <- if (confirmation) "mcmc_confirmation" else "mcmc_pilot"
  for (i in seq_len(nrow(selected))) {
    key <- selected[i, , drop = FALSE]
    candidate <- candidates[candidates$candidate_id == key$candidate_id[[1L]],
                            , drop = FALSE]
    source <- sources[sources$family == key$family[[1L]] &
                        abs(sources$tau - as.numeric(key$tau[[1L]])) < 1e-12,
                      , drop = FALSE]
    if (nrow(candidate) != 1L || nrow(source) != 1L) {
      stop("MCMC config identity lookup failed.", call. = FALSE)
    }
    for (chain_id in as.integer(chain_ids)) {
      job_id <- paste(
        plan_stage, key$family[[1L]], key$likelihood_family[[1L]],
        iqrs_v1_tau_token(key$tau[[1L]]), candidate$candidate_id[[1L]],
        sprintf("c%02d", chain_id), sep = "__"
      )
      config_path <- file.path(run_root, "configs", plan_stage,
                               paste0(job_id, ".json"))
      result_path <- file.path(run_root, "results", plan_stage,
                               paste0(job_id, ".csv"))
      status_path <- file.path(run_root, "status", plan_stage,
                               paste0(job_id, ".json"))
      config <- list(
        schema_version = iqrs_v1_schema, protocol_id = protocol$protocol$id,
        protocol_path = file.path(repo_root, iqrs_v1_protocol_relpath),
        protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                    iqrs_v1_protocol_relpath)),
        stage = worker_stage, plan_stage = plan_stage, job_id = job_id,
        repo_root = repo_root, run_root = run_root,
        source = as.list(source), candidate = as.list(candidate),
        likelihood_family = key$likelihood_family[[1L]],
        tau = as.numeric(key$tau[[1L]]), chain_id = chain_id,
        selection_rank = as.integer(key$selection_rank[[1L]] %||% 1L),
        budget = budget, forecast_contract = contract,
        seed = iqfr_v2_seed(protocol$protocol$id, plan_stage,
                            key$family[[1L]], key$likelihood_family[[1L]],
                            key$tau[[1L]], candidate$candidate_id[[1L]], chain_id),
        result_path = result_path, status_path = status_path
      )
      iqfr_v2_write_json(config, config_path)
      k <- k + 1L
      rows[[k]] <- data.frame(
        stage = plan_stage, job_id = job_id, family = key$family[[1L]],
        tau = as.numeric(key$tau[[1L]]),
        likelihood_family = key$likelihood_family[[1L]],
        candidate_id = candidate$candidate_id[[1L]], chain_id = chain_id,
        config_path = config_path, config_sha256 = iqfr_v2_sha256(config_path),
        result_path = result_path, status_path = status_path,
        stringsAsFactors = FALSE
      )
    }
  }
  plan <- do.call(rbind, rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans",
                                    paste0(plan_stage, ".csv")))
  plan
}

iqrs_v1_rank_mcmc <- function(results) {
  results <- results[results$estimator == "mean_readout_state_recursive",
                     , drop = FALSE]
  cell <- interaction(results$family, results$tau,
                      results$likelihood_family, drop = TRUE)
  rows <- lapply(split(results, cell), function(x) {
    candidate <- split(x, x$candidate_id)
    pooled <- lapply(candidate, function(z) {
      first <- z[1L, c("family", "tau", "likelihood_family", "model_variant",
                       "candidate_id", "structure_id", "rhs_tau0"),
                 drop = FALSE]
      cbind(first, data.frame(
        chains = length(unique(z$chain_id)),
        forecast_qtrue_mae_mean = mean(z$forecast_qtrue_mae_mean),
        forecast_qtrue_rmse_mean = mean(z$forecast_qtrue_rmse_mean),
        forecast_check_loss_mean = mean(z$forecast_check_loss_mean),
        fit_qtrue_rmse_mean = mean(z$fit_qtrue_rmse_mean),
        stringsAsFactors = FALSE
      ))
    })
    z <- do.call(rbind, pooled)
    z <- z[order(z$forecast_qtrue_mae_mean, z$forecast_check_loss_mean,
                 z$fit_qtrue_rmse_mean, z$candidate_id), , drop = FALSE]
    z$selection_rank <- seq_len(nrow(z))
    z
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqrs_v1_verify <- function(repo_root, run_root, require_complete = FALSE) {
  protocol <- iqrs_v1_read_protocol(repo_root)
  checks <- iqrs_v1_protocol_checks(protocol)
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  source_pass <- all(vapply(sources$frozen_path, iqfr_v2_sha256,
                            character(1L)) == sources$frozen_sha256)
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  health <- if (length(plans)) do.call(rbind, lapply(plans,
                                                     iqrs_v1_stage_health)) else
    data.frame()
  expected <- unlist(protocol$execution$expected_jobs)
  expected <- expected[names(expected) != "total"]
  materialized_counts_pass <- all(vapply(seq_len(nrow(health)), function(i) {
    stage <- as.character(health$stage[[i]])
    stage %in% names(expected) && health$planned[[i]] == as.integer(expected[[stage]])
  }, logical(1L)))
  complete_pass <- !require_complete ||
    (nrow(health) == length(expected) && all(health$complete) &&
       !any(health$failed > 0L | health$invalid > 0L))
  report <- list(
    protocol_checks = checks, source_hashes_pass = source_pass,
    stage_health = health, materialized_counts_pass = materialized_counts_pass,
    complete_required = require_complete,
    verification_pass = all(checks$pass) && source_pass &&
      materialized_counts_pass && complete_pass
  )
  iqfr_v2_write_json(report,
                     file.path(run_root, "manifests", "live_verification.json"))
  report
}
