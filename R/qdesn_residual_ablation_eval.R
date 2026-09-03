# Candidate evaluation, ranking, and final summaries for the focused
# residual Q-DESN ablation.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

.qdesn_evaluate_candidate_seed <- function(
    y_observed,
    y_future,
    candidate,
    reservoir_seed,
    stage,
    p_vec,
    nd,
    tau0,
    skip_scale,
    fixed,
    vb_control,
    standardize_readout,
    cache_dir,
    resume = TRUE,
    architectures = c("plain", "interlayer_residual"),
    compute_forgetting = FALSE) {
  cand <- .qdesn_candidate_list(candidate)
  H <- length(y_future)
  if (H != 100L) stop("The focused ablation requires a 100-step target window.", call. = FALSE)
  architectures <- unique(vapply(architectures, .qdesn_architecture_design_name, character(1L)))

  response_center <- 0
  response_scale <- 1
  if (isTRUE(fixed$standardize_response %||% TRUE)) {
    fit_start <- as.integer(fixed$washout)[1L] + 1L
    if (fit_start > length(y_observed)) {
      stop("Response scaling has no post-washout fitting observations.", call. = FALSE)
    }
    response_fit <- y_observed[seq.int(fit_start, length(y_observed))]
    response_center <- mean(response_fit)
    response_scale <- stats::sd(response_fit)
    if (!is.finite(response_scale) || response_scale < 1e-12) response_scale <- 1
  }
  y_observed_model <- (as.numeric(y_observed) - response_center) / response_scale
  phase_id <- sprintf("origin-%d", length(y_observed))

  design_path <- file.path(
    cache_dir,
    phase_id,
    "design",
    sprintf("%s__seed-%d.rds", cand$candidate_id, reservoir_seed)
  )
  paired <- .qdesn_ablation_design_pair(
    y_observed = y_observed_model,
    candidate = candidate,
    reservoir_seed = reservoir_seed,
    skip_scale = skip_scale,
    fixed = fixed,
    cache_path = design_path,
    resume = resume
  )

  forget <- list()
  if (isTRUE(compute_forgetting)) {
    for (architecture in architectures) {
      design <- paired[[architecture]]
      forget[[architecture]] <- tryCatch(
        qdesn_architecture_forgetting_diagnostic(design, y_observed_model),
        error = function(e) data.frame(
          connection_type = architecture,
          layer = NA_integer_,
          final_l2_distance = NA_real_,
          aggregate_final_l2_distance = Inf,
          stringsAsFactors = FALSE
        )
      )
    }
  }

  summary_rows <- list()
  pointwise_rows <- list()
  qhat_by_arch <- setNames(vector("list", length(architectures)), architectures)

  for (architecture in architectures) {
    design <- paired[[architecture]]
    qhat_mat <- matrix(NA_real_, nrow = H, ncol = length(p_vec),
                       dimnames = list(NULL, sprintf("p%.2f", p_vec)))

    for (ip in seq_along(p_vec)) {
      p0 <- p_vec[ip]
      fit_cache_path <- file.path(
        cache_dir,
        phase_id,
        "fits",
        sprintf("%s__seed-%d__%s__p-%0.2f.rds",
                cand$candidate_id, reservoir_seed, architecture, p0)
      )
      forecast_cache_path <- file.path(
        cache_dir,
        stage,
        "forecasts",
        sprintf("%s__seed-%d__%s__p-%0.2f__nd-%d.rds",
                cand$candidate_id, reservoir_seed, architecture, p0, nd)
      )
      cell <- .qdesn_ablation_fit_forecast_cell(
        design = design,
        y_observed = y_observed_model,
        p0 = p0,
        tau0 = tau0,
        H = H,
        nd = nd,
        stage = stage,
        candidate_id = cand$candidate_id,
        reservoir_seed = reservoir_seed,
        architecture = architecture,
        vb_control = vb_control,
        standardize_readout = standardize_readout,
        fit_cache_path = fit_cache_path,
        forecast_cache_path = forecast_cache_path,
        resume = resume
      )

      qhat_raw <- as.numeric(cell$qhat) * response_scale + response_center
      qhat_mat[, ip] <- qhat_raw
      losses <- .qdesn_pinball(y_future, qhat_raw, p0)
      hits <- as.numeric(y_future <= qhat_raw)
      forgetting_value <- if (isTRUE(compute_forgetting)) {
        max(forget[[architecture]]$aggregate_final_l2_distance, na.rm = TRUE)
      } else {
        NA_real_
      }

      summary_rows[[length(summary_rows) + 1L]] <- data.frame(
        stage = stage,
        candidate_id = cand$candidate_id,
        architecture = architecture,
        reservoir_seed = as.integer(reservoir_seed),
        D = cand$D,
        n = cand$n,
        m = cand$m,
        alpha = cand$alpha,
        rho = cand$rho,
        p0 = p0,
        mean_pinball = if (all(is.finite(losses))) mean(losses) else Inf,
        hit_rate = if (all(is.finite(hits))) mean(hits) else NA_real_,
        crossing_rate = NA_real_,
        runtime_sec = cell$runtime_sec,
        fit_runtime_sec = cell$fit_runtime_sec,
        forecast_runtime_sec = cell$forecast_runtime_sec,
        state_roll_runtime_sec = as.numeric(design$meta$state_roll_runtime_sec %||% NA_real_),
        total_runtime_sec = cell$runtime_sec +
          as.numeric(design$meta$state_roll_runtime_sec %||% 0) / length(p_vec),
        vb_converged = cell$vb_converged,
        vb_iterations = cell$vb_iterations,
        max_abs_state = cell$max_abs_state,
        max_abs_preactivation = cell$max_abs_preactivation,
        tanh_saturation_rate = cell$tanh_saturation_rate,
        state_finite = cell$state_finite,
        forgetting_final_l2 = forgetting_value,
        ok = cell$ok && all(is.finite(cell$qhat)),
        error = cell$error,
        n_paths = cell$n_paths,
        rhs_tau0 = tau0,
        response_center = response_center,
        response_scale = response_scale,
        response_standardized = isTRUE(fixed$standardize_response %||% TRUE),
        fit_seed = cell$fit_seed,
        posterior_seed = cell$posterior_seed,
        noise_seed = cell$noise_seed,
        base_reservoir_sha256 = paired$pairing$base_reservoir_sha256,
        legacy_parity_max_abs_error = paired$plain$meta$legacy_parity_max_abs_error %||% NA_real_,
        stringsAsFactors = FALSE
      )

      pointwise_rows[[length(pointwise_rows) + 1L]] <- data.frame(
        stage = stage,
        candidate_id = cand$candidate_id,
        architecture = architecture,
        reservoir_seed = as.integer(reservoir_seed),
        p0 = p0,
        horizon = seq_len(H),
        horizon_block = as.character(.qdesn_horizon_block(seq_len(H))),
        y = as.numeric(y_future),
        qhat = as.numeric(qhat_raw),
        pinball = as.numeric(losses),
        hit = hits,
        stringsAsFactors = FALSE
      )
    }

    qhat_by_arch[[architecture]] <- qhat_mat
    if (ncol(qhat_mat) >= 2L && all(is.finite(qhat_mat))) {
      crossing <- rowSums(qhat_mat[, -ncol(qhat_mat), drop = FALSE] >
                            qhat_mat[, -1L, drop = FALSE]) > 0L
      crossing_rate <- mean(crossing)
    } else {
      crossing_rate <- NA_real_
    }
    idx <- vapply(summary_rows, function(x) {
      identical(x$architecture[[1L]], architecture)
    }, logical(1L))
    for (ii in which(idx)) summary_rows[[ii]]$crossing_rate <- crossing_rate
  }

  list(
    summary = do.call(rbind, summary_rows),
    pointwise = do.call(rbind, pointwise_rows),
    pairing = paired$pairing,
    qhat = qhat_by_arch,
    forgetting = forget
  )
}

.qdesn_validation_normalizers <- function(y_fit, y_validation, p_vec) {
  values <- vapply(p_vec, function(p0) {
    q0 <- as.numeric(stats::quantile(y_fit, probs = p0, names = FALSE, type = 8))
    score <- mean(.qdesn_pinball(y_validation, rep(q0, length(y_validation)), p0))
    max(score, sqrt(.Machine$double.eps))
  }, numeric(1L))
  data.frame(p0 = p_vec, normalizer = values, stringsAsFactors = FALSE)
}

.qdesn_bind_eval_results <- function(results) {
  list(
    summary = do.call(rbind, lapply(results, `[[`, "summary")),
    pointwise = do.call(rbind, lapply(results, `[[`, "pointwise"))
  )
}

.qdesn_rank_validation <- function(summary_table, candidates, normalizers) {
  x <- merge(summary_table, normalizers, by = "p0", all.x = TRUE, sort = FALSE)
  x$scaled_pinball <- x$mean_pinball / x$normalizer
  x$valid_cell <- x$ok & x$state_finite &
    !is.na(x$vb_converged) & x$vb_converged & is.finite(x$scaled_pinball)

  keys <- unique(x[, c("architecture", "candidate_id"), drop = FALSE])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    z <- x[x$architecture == keys$architecture[i] &
             x$candidate_id == keys$candidate_id[i], , drop = FALSE]
    per_p <- vapply(sort(unique(z$p0)), function(p0) {
      vals <- z$scaled_pinball[z$p0 == p0 & z$valid_cell]
      if (length(vals)) stats::median(vals) else Inf
    }, numeric(1L))
    cand <- candidates[candidates$candidate_id == keys$candidate_id[i], , drop = FALSE]
    all_cells_valid <- all(z$valid_cell)
    data.frame(
      architecture = keys$architecture[i],
      candidate_id = keys$candidate_id[i],
      D = cand$D[1L],
      n = cand$n[1L],
      m = cand$m[1L],
      alpha = cand$alpha[1L],
      rho = cand$rho[1L],
      aggregate_score = if (all_cells_valid) mean(per_p) else Inf,
      worst_quantile_score = if (all_cells_valid) max(per_p) else Inf,
      valid_cells = sum(z$valid_cell),
      expected_cells = nrow(z),
      median_saturation = stats::median(z$tanh_saturation_rate, na.rm = TRUE),
      total_runtime_sec = sum(z$total_runtime_sec, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$architecture, out$aggregate_score, out$D, out$n, out$m,
                   out$median_saturation, out$candidate_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.qdesn_select_winner <- function(ranking, architecture, tolerance = 0.01) {
  x <- ranking[ranking$architecture == architecture & is.finite(ranking$aggregate_score), , drop = FALSE]
  if (!nrow(x)) stop("No valid candidate for architecture ", architecture, ".", call. = FALSE)
  best <- min(x$aggregate_score)
  near <- x[x$aggregate_score <= best * (1 + tolerance), , drop = FALSE]
  near <- near[order(near$D, near$n, near$m, near$median_saturation, near$candidate_id), , drop = FALSE]
  near[1L, , drop = FALSE]
}

.qdesn_top_candidate_ids <- function(ranking, architecture, n_top = 2L) {
  x <- ranking[ranking$architecture == architecture & is.finite(ranking$aggregate_score), , drop = FALSE]
  head(x$candidate_id, n_top)
}


.qdesn_final_paired_differences <- function(summary_final, normalizers) {
  x <- merge(summary_final, normalizers, by = "p0", all.x = TRUE, sort = FALSE)
  x$scaled_pinball <- x$mean_pinball / x$normalizer
  agg <- stats::aggregate(
    scaled_pinball ~ model_id + reservoir_seed,
    data = x,
    FUN = mean
  )
  base <- agg[agg$model_id == "M0_plain_selected", c("reservoir_seed", "scaled_pinball")]
  names(base)[2L] <- "M0"
  res <- agg[agg$model_id == "M1_residual_same_hyperparameters", c("reservoir_seed", "scaled_pinball")]
  names(res)[2L] <- "M1"
  paired <- merge(base, res, by = "reservoir_seed", all = FALSE)
  paired$difference_M1_minus_M0 <- paired$M1 - paired$M0
  paired$relative_improvement_percent <- 100 * (paired$M0 - paired$M1) /
    pmax(paired$M0, sqrt(.Machine$double.eps))
  paired
}

.qdesn_final_aggregate <- function(summary_final) {
  keys <- unique(summary_final[, c("model_id", "architecture", "p0"), drop = FALSE])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    z <- summary_final[
      summary_final$model_id == keys$model_id[i] &
        summary_final$architecture == keys$architecture[i] &
        summary_final$p0 == keys$p0[i],
      , drop = FALSE
    ]
    data.frame(
      model_id = keys$model_id[i],
      architecture = keys$architecture[i],
      p0 = keys$p0[i],
      mean_pinball = mean(z$mean_pinball, na.rm = TRUE),
      median_pinball = stats::median(z$mean_pinball, na.rm = TRUE),
      iqr_pinball = stats::IQR(z$mean_pinball, na.rm = TRUE),
      mean_hit_rate = mean(z$hit_rate, na.rm = TRUE),
      median_crossing_rate = stats::median(z$crossing_rate, na.rm = TRUE),
      mean_runtime_sec = mean(z$runtime_sec, na.rm = TRUE),
      mean_state_roll_runtime_sec = mean(z$state_roll_runtime_sec, na.rm = TRUE),
      mean_total_runtime_sec = mean(z$total_runtime_sec, na.rm = TRUE),
      valid_seed_count = sum(z$ok & z$state_finite &
                               !is.na(z$vb_converged) & z$vb_converged),
      seed_count = nrow(z),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
