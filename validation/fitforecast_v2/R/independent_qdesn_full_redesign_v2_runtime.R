`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

iqfr_v2_scalar <- function(x, default = NULL) {
  if (is.null(x) || !length(x)) return(default)
  if (is.list(x) && length(x) == 1L) x <- x[[1L]]
  if (!length(x)) default else x[[1L]]
}

iqfr_v2_number <- function(x, default = NA_real_) {
  out <- suppressWarnings(as.numeric(iqfr_v2_scalar(x, default)))
  if (!length(out)) default else out[[1L]]
}

iqfr_v2_integer <- function(x, default = NA_integer_) {
  out <- suppressWarnings(as.integer(iqfr_v2_scalar(x, default)))
  if (!length(out)) default else out[[1L]]
}

iqfr_v2_read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}

iqfr_v2_source_rows <- function(source_path) {
  x <- utils::read.csv(source_path, check.names = FALSE)
  required <- c("t", "y", "mu", "q_target", "eps")
  if (!all(required %in% names(x)) || nrow(x) != 1890L ||
      !identical(as.integer(x$t), 8111:10000)) {
    stop("Frozen source does not satisfy the 8111:10000 contract: ",
         source_path, call. = FALSE)
  }
  x
}

iqfr_v2_training_preprocess <- function(y, method) {
  method <- match.arg(as.character(method), c("mean_sd", "median_mad"))
  if (identical(method, "median_mad")) {
    center <- stats::median(y)
    scale <- stats::mad(y, center = center, constant = 1.4826)
    if (!is.finite(scale) || scale <= 1e-12) scale <- stats::sd(y)
  } else {
    center <- mean(y)
    scale <- stats::sd(y)
  }
  if (!is.finite(center)) stop("Nonfinite training input center.", call. = FALSE)
  if (!is.finite(scale) || scale <= 1e-12) scale <- 1
  list(center = center, scale = scale, method = method)
}

iqfr_v2_candidate_values <- function(candidate) {
  D <- iqfr_v2_integer(candidate$D)
  n <- iqfr_v2_unpack_integer(candidate$n)
  n_tilde <- iqfr_v2_unpack_integer(candidate$n_tilde)
  if (length(n) != D || (D > 1L && length(n_tilde) != D - 1L) ||
      (D == 1L && length(n_tilde))) {
    stop("Candidate layer dimensions are malformed.", call. = FALSE)
  }
  if (D > 1L && !identical(n_tilde, n[seq_len(D - 1L)])) {
    stop("Candidate violates exact identity projection.", call. = FALSE)
  }
  bound_token <- as.character(iqfr_v2_scalar(candidate$input_bound))
  bound <- if (identical(bound_token, "tanh_z_over_3")) "tanh" else bound_token
  divisor <- if (identical(bound_token, "tanh_z_over_3")) 3 else 1
  list(
    D = D, n = n, n_tilde = n_tilde,
    m = iqfr_v2_integer(candidate$m),
    alpha = iqfr_v2_number(candidate$alpha),
    rho = iqfr_v2_number(candidate$rho),
    tau0 = iqfr_v2_number(candidate$rhs_tau0),
    center_scale = as.character(iqfr_v2_scalar(candidate$center_scale)),
    input_bound = bound, input_bound_divisor = divisor,
    input_gain = iqfr_v2_number(candidate$input_gain),
    recurrent_indegree = iqfr_v2_integer(candidate$recurrent_indegree),
    input_fanin = iqfr_v2_integer(candidate$input_fanin),
    interlayer_fanin = iqfr_v2_integer(candidate$interlayer_fanin),
    matrix_seed = iqfr_v2_integer(candidate$matrix_seed)
  )
}

iqfr_v2_design_args <- function(y, candidate, preprocess, p0 = 0.5,
                                fit_readout = FALSE, normal_args = list()) {
  z <- iqfr_v2_candidate_values(candidate)
  list(
    y = as.numeric(y), p0 = as.numeric(p0), D = z$D, n = z$n,
    n_tilde = z$n_tilde, m = z$m, input_mode = "raw_y_lags",
    standardize_inputs = TRUE, input_center_scale = z$center_scale,
    input_bound = z$input_bound,
    input_bound_divisor = z$input_bound_divisor,
    lag_center_override = preprocess$center,
    lag_scale_override = preprocess$scale,
    win_scale_global = z$input_gain, win_scale_bias = 1,
    alpha = z$alpha, rho = rep(z$rho, z$D),
    act_f = "tanh", act_k = "identity", pi_w = 0.1, pi_in = 0.1,
    topology = list(
      mode = "exact_fanin",
      recurrent_indegree = rep(z$recurrent_indegree, z$D),
      input_fanin = rep(z$input_fanin, z$D),
      interlayer_fanin = rep(z$interlayer_fanin, z$D),
      row_normalize_inputs = TRUE
    ),
    w_dist = function(n) stats::runif(n, -1, 1),
    in_dist = function(n) stats::runif(n, -1, 1),
    washout = 390L, add_bias = TRUE, state_noise_sd = 0,
    seed = z$matrix_seed, normal_args = normal_args,
    fit_readout = fit_readout
  )
}

iqfr_v2_assert_design <- function(object, candidate, expected_rows) {
  z <- iqfr_v2_candidate_values(candidate)
  failures <- character()
  if (!identical(as.integer(object$meta$D), z$D)) failures <- c(failures, "D")
  if (nrow(object$X) != expected_rows) failures <- c(failures, "rows")
  if (ncol(object$X) != 1L + sum(z$n)) failures <- c(failures, "readout_width")
  if (!isTRUE(object$meta$add_bias)) failures <- c(failures, "intercept")
  if (any(!is.finite(object$X))) failures <- c(failures, "finite_design")
  if (!identical(object$reservoir$topology$mode, "exact_fanin")) {
    failures <- c(failures, "topology")
  }
  if (z$D > 1L && !all(object$reservoir$Q_is_identity)) {
    failures <- c(failures, "identity_projection")
  }
  for (d in seq_len(z$D)) {
    expected_recurrent <- min(z$recurrent_indegree, z$n[[d]])
    if (any(rowSums(object$reservoir$W[[d]] != 0) != expected_recurrent)) {
      failures <- c(failures, paste0("recurrent_fanin_L", d))
    }
    expected_input <- if (d == 1L) {
      min(z$input_fanin, z$m + 1L)
    } else {
      min(z$interlayer_fanin, z$n[[d - 1L]])
    }
    if (any(rowSums(object$reservoir$Win[[d]] != 0) != expected_input)) {
      failures <- c(failures, paste0("input_fanin_L", d))
    }
  }
  if (length(failures)) {
    stop("Q-DESN architecture contract failed: ",
         paste(unique(failures), collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

iqfr_v2_attach_normal_readout <- function(design, training_fit) {
  design$fit <- training_fit$fit
  design$mu_hat <- as.numeric(design$X %*% design$fit$beta$mean)
  design$meta$inference_method <- "normal_vb"
  design$meta$likelihood_family <- "normal"
  design$meta$target <- "conditional_mean"
  class(design) <- c("qdesn_normal_fit", "list")
  design
}

iqfr_v2_normal_forecast <- function(object, y_all, origins, H) {
  beta <- matrix(object$fit$beta$mean, nrow = 1L)
  draws <- list(beta = beta, omega2 = 0, nd = 1L)
  rows <- vector("list", length(origins))
  for (i in seq_along(origins)) {
    origin <- as.integer(origins[[i]])
    origin_state <- lapply(object$states$H_all, function(Hd) Hd[origin, ])
    fc <- forecast_paths.qdesn_normal_fit(
      object = object, H = H, nd = 1L,
      y_hist = y_all[seq_len(origin)], origin_state = origin_state,
      draws = draws, seed = 1L
    )
    rows[[i]] <- data.frame(
      origin = origin, lead = seq_len(H), target = origin + seq_len(H),
      prediction = as.numeric(fc$mu_draws[, 1L]),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

iqfr_v2_normal_job <- function(config_path) {
  started <- Sys.time()
  config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
  cfg <- iqfr_v2_read_json(config_path)
  status_path <- as.character(cfg$status_path)
  result_path <- as.character(cfg$result_path)
  base_status <- list(
    schema_version = iqfr_v2_schema, job_id = cfg$job_id,
    stage = cfg$stage, config_path = config_path,
    config_sha256 = iqfr_v2_sha256(config_path),
    pid = Sys.getpid(), host = Sys.info()[["nodename"]],
    started_at = format(started, "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(c(base_status, list(status = "RUNNING")), status_path)

  tryCatch({
    source_row <- cfg$source
    source_path <- as.character(iqfr_v2_scalar(source_row$frozen_path))
    expected_source_hash <- as.character(iqfr_v2_scalar(source_row$frozen_sha256))
    if (!identical(iqfr_v2_sha256(source_path), expected_source_hash)) {
      stop("Frozen source hash mismatch.", call. = FALSE)
    }
    x <- iqfr_v2_source_rows(source_path)
    candidate <- cfg$candidate
    fit_rows <- x$t >= 8501L & x$t <= 8800L
    train_rows <- x$t <= 8800L
    rollout_rows <- x$t <= 9000L
    preprocess <- iqfr_v2_training_preprocess(
      x$y[fit_rows], iqfr_v2_scalar(candidate$center_scale)
    )
    budget <- cfg$budget
    normal_args <- list(
      beta_prior_type = "rhs_ns",
      rhs = list(
        tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = 1,
        shrink_intercept = FALSE, n_inner = 2L
      ),
      omega_prior = list(a = 2, b = 1),
      control = list(
        max_iter = iqfr_v2_integer(budget$max_iter),
        min_iter = iqfr_v2_integer(budget$min_iter),
        tol = iqfr_v2_number(budget$tol), verbose = FALSE,
        covariance = "woodbury_diagonal"
      )
    )
    fit <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
      y = x$y[train_rows], candidate = candidate, preprocess = preprocess,
      p0 = 0.5, fit_readout = TRUE, normal_args = normal_args
    ))
    iqfr_v2_assert_design(fit, candidate, expected_rows = 300L)

    rollout <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
      y = x$y[rollout_rows], candidate = candidate, preprocess = preprocess,
      p0 = 0.5, fit_readout = FALSE
    ))
    iqfr_v2_assert_design(rollout, candidate, expected_rows = 500L)
    rollout <- iqfr_v2_attach_normal_readout(rollout, fit)

    origins_source <- seq.int(8800L, 8970L, by = 5L)
    origins_local <- origins_source - 8110L
    fc <- iqfr_v2_normal_forecast(
      rollout, y_all = x$y[rollout_rows], origins = origins_local, H = 30L
    )
    fc$source_origin <- fc$origin + 8110L
    fc$source_target <- fc$target + 8110L
    target_row <- match(fc$source_target, x$t)
    if (anyNA(target_row)) stop("Forecast target alignment failed.", call. = FALSE)
    oracle <- x$mu[target_row]
    observed <- x$y[target_row]

    fit_prediction <- as.numeric(fit$X %*% fit$fit$beta$mean)
    fit_oracle <- x$mu[fit_rows]
    state_values <- unlist(lapply(rollout$states$H_all, function(Hd) {
      as.numeric(Hd[391:690, , drop = FALSE])
    }), use.names = FALSE)
    trace <- fit$fit$trace %||% data.frame()
    result <- data.frame(
      schema_version = iqfr_v2_schema, stage = cfg$stage,
      job_id = cfg$job_id,
      family = as.character(iqfr_v2_scalar(candidate$family)),
      candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
      candidate_signature = as.character(iqfr_v2_scalar(candidate$candidate_signature)),
      source_sha256 = expected_source_hash,
      matrix_seed = iqfr_v2_integer(candidate$matrix_seed),
      D = iqfr_v2_integer(candidate$D), n = as.character(iqfr_v2_scalar(candidate$n)),
      n_tilde = as.character(iqfr_v2_scalar(candidate$n_tilde)),
      total_states = iqfr_v2_integer(candidate$total_states),
      readout_dimension = iqfr_v2_integer(candidate$readout_dimension),
      m = iqfr_v2_integer(candidate$m), alpha = iqfr_v2_number(candidate$alpha),
      rho = iqfr_v2_number(candidate$rho), rhs_tau0 = iqfr_v2_number(candidate$rhs_tau0),
      tau0_mode = as.character(iqfr_v2_scalar(candidate$tau0_mode)),
      center_scale = preprocess$method,
      input_bound = as.character(iqfr_v2_scalar(candidate$input_bound)),
      input_gain = iqfr_v2_number(candidate$input_gain),
      recurrent_indegree = iqfr_v2_integer(candidate$recurrent_indegree),
      input_fanin = iqfr_v2_integer(candidate$input_fanin),
      interlayer_fanin = iqfr_v2_integer(candidate$interlayer_fanin),
      fit_oracle_location_rmse = sqrt(mean((fit_prediction - fit_oracle)^2)),
      fit_oracle_location_mae = mean(abs(fit_prediction - fit_oracle)),
      forecast_oracle_location_mae = mean(abs(fc$prediction - oracle)),
      forecast_oracle_location_rmse = sqrt(mean((fc$prediction - oracle)^2)),
      forecast_observed_mae = mean(abs(fc$prediction - observed)),
      state_saturation_fraction = mean(abs(state_values) >= 0.99),
      zero_variance_readout_columns = sum(apply(fit$X[, -1L, drop = FALSE], 2L, stats::sd) <= 1e-12),
      normal_iterations = nrow(trace),
      normal_converged = isTRUE(fit$fit$converged),
      covariance_approximation = as.character(fit$fit$qbeta$covariance_approximation),
      forecast_origins = length(origins_local), forecast_pairs = nrow(fc),
      runtime_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
      finite_contract = TRUE, stringsAsFactors = FALSE
    )
    numeric_values <- unlist(result[vapply(result, is.numeric, logical(1L))],
                             use.names = FALSE)
    if (any(!is.finite(numeric_values)) ||
        result$zero_variance_readout_columns[[1L]] > 0L) {
      stop("Normal-screen result violates finite/nondegenerate contract.",
           call. = FALSE)
    }
    iqfr_v2_write_csv(result, result_path)
    finished <- Sys.time()
    iqfr_v2_write_json(c(base_status, list(
      status = "SUCCESS", finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      result_path = result_path, result_sha256 = iqfr_v2_sha256(result_path)
    )), status_path)
    invisible(result)
  }, error = function(e) {
    finished <- Sys.time()
    iqfr_v2_write_json(c(base_status, list(
      status = "FAILED", finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      error_class = class(e)[[1L]], error_message = conditionMessage(e)
    )), status_path)
    stop(e)
  })
}

iqfr_v2_stage_health <- function(plan_path) {
  plan <- utils::read.csv(plan_path, check.names = FALSE,
                          stringsAsFactors = FALSE)
  statuses <- vapply(plan$status_path, function(path) {
    if (!file.exists(path)) return("PENDING")
    tryCatch(as.character(iqfr_v2_read_json(path)$status),
             error = function(e) "INVALID_STATUS")
  }, character(1L))
  data.frame(
    stage = unique(plan$stage), planned = nrow(plan),
    success = sum(statuses == "SUCCESS"),
    running = sum(statuses == "RUNNING"),
    failed = sum(statuses == "FAILED"),
    pending = sum(statuses == "PENDING"),
    invalid = sum(statuses == "INVALID_STATUS"),
    complete = all(statuses == "SUCCESS"), stringsAsFactors = FALSE
  )
}

iqfr_v2_collect_results <- function(plan_path, require_complete = TRUE) {
  plan <- utils::read.csv(plan_path, check.names = FALSE,
                          stringsAsFactors = FALSE)
  health <- iqfr_v2_stage_health(plan_path)
  if (isTRUE(require_complete) && !isTRUE(health$complete[[1L]])) {
    stop("Stage is not completely successful: ", basename(plan_path),
         call. = FALSE)
  }
  paths <- plan$result_path[file.exists(plan$result_path)]
  if (!length(paths)) return(data.frame())
  out <- do.call(rbind, lapply(paths, utils::read.csv,
                              check.names = FALSE, stringsAsFactors = FALSE))
  stage <- unique(as.character(out$stage))
  key_columns <- if (identical(stage, "quantile_vb")) {
    c("job_id", "likelihood_family", "tau")
  } else if (stage %in% c("mcmc_pilot", "mcmc_confirmation")) {
    c("job_id", "estimator")
  } else {
    "job_id"
  }
  if (!all(key_columns %in% names(out))) {
    stop("Result ledger is missing its stage-specific key columns.",
         call. = FALSE)
  }
  keys <- do.call(paste, c(out[key_columns], sep = "|"))
  if (anyDuplicated(keys)) {
    stop("Duplicate stage-specific result rows.", call. = FALSE)
  }
  rownames(out) <- NULL
  out
}

iqfr_v2_rank_normal <- function(results) {
  required <- c("family", "candidate_id", "forecast_oracle_location_mae",
                "fit_oracle_location_rmse", "forecast_oracle_location_rmse",
                "state_saturation_fraction", "readout_dimension")
  if (!all(required %in% names(results)) || any(!is.finite(
      as.matrix(results[c("forecast_oracle_location_mae",
                          "fit_oracle_location_rmse",
                          "forecast_oracle_location_rmse")])))) {
    stop("Normal ranking input is incomplete or nonfinite.", call. = FALSE)
  }
  rows <- lapply(split(results, results$family), function(x) {
    r1 <- rank(x$forecast_oracle_location_mae, ties.method = "min")
    r2 <- rank(x$fit_oracle_location_rmse, ties.method = "min")
    r3 <- rank(x$forecast_oracle_location_rmse, ties.method = "min")
    r4 <- rank(x$state_saturation_fraction, ties.method = "min")
    x$selection_score <- r1 + 0.25 * r2 + 0.10 * r3 + 0.05 * r4
    x$family_rank <- rank(x$selection_score, ties.method = "first")
    x[order(x$selection_score, x$forecast_oracle_location_mae,
            x$readout_dimension), , drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqfr_v2_select_diverse_normal <- function(ranked, candidates, k = 50L) {
  k <- as.integer(k)
  rows <- lapply(iqfr_v2_families, function(family) {
    r <- ranked[ranked$family == family, , drop = FALSE]
    cands <- candidates[candidates$family == family, , drop = FALSE]
    r <- merge(r, cands, by = c("family", "candidate_id"),
               suffixes = c(".result", ""), sort = FALSE)
    r <- r[order(r$selection_score, r$forecast_oracle_location_mae),
           , drop = FALSE]
    r$diversity_key <- paste(
      r$D, r$layer_shape, r$center_scale, r$input_bound,
      cut(r$alpha, c(-Inf, 0.25, 0.5, 0.75, Inf), labels = FALSE),
      cut(r$rho, c(-Inf, 0.5, 0.75, 0.9, Inf), labels = FALSE), sep = "|"
    )
    selected <- integer()
    for (cap in c(1L, 2L, 4L, k)) {
      counts <- table(r$diversity_key[selected])
      for (i in seq_len(nrow(r))) {
        if (i %in% selected) next
        key <- r$diversity_key[[i]]
        used <- if (key %in% names(counts)) as.integer(counts[[key]]) else 0L
        if (used < cap) {
          selected <- c(selected, i)
          counts <- table(r$diversity_key[selected])
        }
        if (length(selected) >= k) break
      }
      if (length(selected) >= k) break
    }
    selected <- selected[seq_len(min(k, length(selected)))]
    out <- r[selected, names(cands), drop = FALSE]
    out$normal_selection_rank <- seq_len(nrow(out))
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (any(table(out$family) != k)) {
    stop("Diverse Normal selection did not retain exactly k per family.",
         call. = FALSE)
  }
  out
}

iqfr_v2_quantile_init_from_fit <- function(object, tau, likelihood_family) {
  fit <- object$fit
  qsig <- fit$qsiggam %||% list()
  gamma <- if (identical(likelihood_family, "al")) 0 else {
    bounds <- c(L.fn(tau), U.fn(tau))
    min(bounds[[2L]] - 1e-8, max(bounds[[1L]] + 1e-8,
                                as.numeric(qsig$gamma_mean)))
  }
  list(
    beta_m = as.numeric(fit$qbeta$m), beta_V = as.matrix(fit$qbeta$V),
    v_m = as.numeric(fit$qv$m %||% fit$qv$E_v),
    v_inv = as.numeric(fit$qv$m_inv %||% fit$qv$E_inv_v),
    s_m = as.numeric(fit$qs$m %||% fit$qs$E_s),
    s_m2 = as.numeric(fit$qs$m2 %||% fit$qs$E_s2),
    gamma = gamma, sigma = as.numeric(qsig$sigma_mean),
    siggam_Sigma = as.matrix(qsig$Sigma),
    beta_state = fit$beta_prior$state %||% NULL
  )
}

iqfr_v2_quantile_point_draws <- function(object) {
  fit <- object$fit
  qsig <- fit$qsiggam %||% list()
  list(
    beta = matrix(as.numeric(fit$qbeta$m), nrow = 1L),
    sigma = as.numeric(qsig$sigma_mean),
    gamma = as.numeric(qsig$gamma_mean),
    source_draw_index = 1L
  )
}

iqfr_v2_attach_quantile_readout <- function(design, fit_object) {
  design$fit <- fit_object$fit
  design$mu_hat <- as.numeric(design$X %*% design$fit$qbeta$m)
  design$meta$inference_method <- "vb"
  class(design) <- c("qdesn_fit", "list")
  design
}

iqfr_v2_check_loss <- function(y, q, tau) {
  u <- as.numeric(y) - as.numeric(q)
  u * (as.numeric(tau) - as.numeric(u < 0))
}

iqfr_v2_flatten_lattice <- function(lattice, origins) {
  blocks <- lapply(seq_along(origins), function(i) {
    q <- as.matrix(lattice$mu_by_origin[[i]])
    data.frame(
      origin = as.integer(origins[[i]]), lead = seq_len(nrow(q)),
      target = as.integer(origins[[i]]) + seq_len(nrow(q)),
      prediction = rowMeans(q), stringsAsFactors = FALSE
    )
  })
  do.call(rbind, blocks)
}

iqfr_v2_quantile_vb_job <- function(config_path) {
  started <- Sys.time()
  config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
  cfg <- iqfr_v2_read_json(config_path)
  status_path <- as.character(cfg$status_path)
  result_path <- as.character(cfg$result_path)
  base_status <- list(
    schema_version = iqfr_v2_schema, job_id = cfg$job_id,
    stage = cfg$stage, config_path = config_path,
    config_sha256 = iqfr_v2_sha256(config_path), pid = Sys.getpid(),
    host = Sys.info()[["nodename"]],
    started_at = format(started, "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(c(base_status, list(status = "RUNNING")), status_path)
  tryCatch({
    candidate <- cfg$candidate
    sources <- as.data.frame(cfg$sources, stringsAsFactors = FALSE)
    sources$tau <- as.numeric(sources$tau)
    if (!identical(sort(sources$tau), iqfr_v2_quantiles)) {
      stop("Quantile VB job does not contain the complete quantile source set.",
           call. = FALSE)
    }
    source_paths <- as.character(sources$frozen_path)
    observed_hashes <- vapply(source_paths, iqfr_v2_sha256, character(1L))
    if (any(observed_hashes != as.character(sources$frozen_sha256))) {
      stop("Quantile VB frozen source hash mismatch.", call. = FALSE)
    }
    data_by_tau <- setNames(lapply(source_paths, iqfr_v2_source_rows),
                            sprintf("%.2f", sources$tau))
    x0 <- data_by_tau[["0.50"]]
    if (!all(vapply(data_by_tau, function(z) identical(z$mu, x0$mu),
                    logical(1L)))) {
      stop("Oracle-location paths differ within a family.", call. = FALSE)
    }
    fit_rows <- x0$t >= 8501L & x0$t <= 8800L
    train_rows <- x0$t <= 8800L
    rollout_rows <- x0$t <= 9000L
    preprocess <- iqfr_v2_training_preprocess(
      x0$y[fit_rows], iqfr_v2_scalar(candidate$center_scale)
    )
    normal_args <- list(
      beta_prior_type = "rhs_ns",
      rhs = list(tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = 1,
                 shrink_intercept = FALSE, n_inner = 2L),
      control = list(
        max_iter = 250L, min_iter = 10L, tol = 1e-6,
        covariance = "woodbury_diagonal", verbose = FALSE
      )
    )
    normal_fit <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
      y = x0$y[train_rows], candidate = candidate, preprocess = preprocess,
      p0 = 0.5, fit_readout = TRUE, normal_args = normal_args
    ))
    iqfr_v2_assert_design(normal_fit, candidate, 300L)

    results <- list()
    k <- 0L
    for (likelihood_family in c("al", "exal")) {
      previous_fit <- NULL
      for (tau in c(0.50, 0.25, 0.05)) {
        x <- data_by_tau[[sprintf("%.2f", tau)]]
        init <- if (is.null(previous_fit)) {
          qdesn_normal_to_vb_init(
            normal_fit, likelihood_family = likelihood_family,
            beta_prior_type = "rhs_ns", p0 = tau
          )
        } else {
          iqfr_v2_quantile_init_from_fit(previous_fit, tau, likelihood_family)
        }
        vb_args <- list(
          likelihood_family = likelihood_family,
          al_fixed_gamma = if (likelihood_family == "al") 0 else NULL,
          beta_prior_type = "rhs_ns",
          beta_rhs = list(
            tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = 1,
            shrink_intercept = FALSE, n_inner = 2L
          ),
          max_iter = iqfr_v2_integer(cfg$budget$max_iter, 1000L),
          min_iter_elbo = 10L, tol = iqfr_v2_number(cfg$budget$tol, 1e-4),
          tol_par = iqfr_v2_number(cfg$budget$tol, 1e-4),
          n_samp_xi = iqfr_v2_integer(cfg$budget$n_samp_xi, 500L),
          verbose = FALSE, init = init,
          sigmagam = exal_make_vb_sigmagam_control(),
          beta_covariance = list(
            approximation = "diagonal", label_uncertainty = TRUE
          )
        )
        fit_args <- iqfr_v2_design_args(
          y = x$y[train_rows], candidate = candidate,
          preprocess = preprocess, p0 = tau, fit_readout = TRUE
        )
        fit_args$normal_args <- NULL
        fit_args$vb_args <- vb_args
        fit <- do.call(qdesn_fit_vb, fit_args)
        iqfr_v2_assert_design(fit, candidate, 300L)

        rollout_args <- iqfr_v2_design_args(
          y = x$y[rollout_rows], candidate = candidate,
          preprocess = preprocess, p0 = tau, fit_readout = FALSE
        )
        rollout_args$normal_args <- NULL
        rollout_args$vb_args <- list()
        rollout <- do.call(qdesn_fit_vb, rollout_args)
        iqfr_v2_assert_design(rollout, candidate, 500L)
        rollout <- iqfr_v2_attach_quantile_readout(rollout, fit)
        origins_source <- seq.int(8800L, 8970L, by = 5L)
        origins_local <- origins_source - 8110L
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
        qtrue <- x$q_target[target_row]
        observed <- x$y[target_row]
        fit_q <- as.numeric(fit$X %*% fit$fit$qbeta$m)
        fit_qtrue <- x$q_target[fit_rows]
        elbo <- fit$fit$misc$elbo_trace %||% numeric()
        k <- k + 1L
        results[[k]] <- data.frame(
          schema_version = iqfr_v2_schema, stage = cfg$stage,
          job_id = cfg$job_id,
          family = as.character(iqfr_v2_scalar(candidate$family)),
          candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
          candidate_signature = as.character(iqfr_v2_scalar(candidate$candidate_signature)),
          likelihood_family = likelihood_family,
          model_variant = if (likelihood_family == "al") {
            "qdesn_al_rhs"
          } else "qdesn_exal_rhs",
          tau = tau, rhs_tau0 = iqfr_v2_number(candidate$rhs_tau0),
          fit_qtrue_rmse = sqrt(mean((fit_q - fit_qtrue)^2)),
          fit_qtrue_mae = mean(abs(fit_q - fit_qtrue)),
          fit_check_loss = mean(iqfr_v2_check_loss(x$y[fit_rows], fit_q, tau)),
          forecast_qtrue_mae = mean(abs(fc$prediction - qtrue)),
          forecast_qtrue_rmse = sqrt(mean((fc$prediction - qtrue)^2)),
          forecast_check_loss = mean(iqfr_v2_check_loss(observed, fc$prediction, tau)),
          vb_iterations = length(elbo),
          vb_covariance_approximation = as.character(
            fit$fit$qbeta$covariance_approximation %||% "unknown"
          ),
          sigmagam_factorization = as.character(
            fit$fit$misc$sigmagam$factorization %||%
              fit$fit$misc$vb_control$sigmagam$factorization %||% "structured"
          ),
          nested_init_source = if (is.null(previous_fit)) {
            "normal_rhs_vb"
          } else sprintf("%s_tau_%.2f", likelihood_family,
                         previous_fit$meta$p0),
          forecast_origins = length(origins_local), forecast_pairs = nrow(fc),
          finite_contract = TRUE, stringsAsFactors = FALSE
        )
        numeric_values <- unlist(results[[k]][vapply(results[[k]], is.numeric,
                                                     logical(1L))])
        if (any(!is.finite(numeric_values))) {
          stop("Quantile VB result contains nonfinite metrics.", call. = FALSE)
        }
        previous_fit <- fit
        rm(rollout, lattice, fc)
        gc(verbose = FALSE)
      }
    }
    result <- do.call(rbind, results)
    result$runtime_seconds_job <- as.numeric(difftime(Sys.time(), started,
                                                       units = "secs"))
    iqfr_v2_write_csv(result, result_path)
    finished <- Sys.time()
    iqfr_v2_write_json(c(base_status, list(
      status = "SUCCESS", finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      rows = nrow(result), result_path = result_path,
      result_sha256 = iqfr_v2_sha256(result_path)
    )), status_path)
    invisible(result)
  }, error = function(e) {
    finished <- Sys.time()
    iqfr_v2_write_json(c(base_status, list(
      status = "FAILED", finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      error_class = class(e)[[1L]], error_message = conditionMessage(e)
    )), status_path)
    stop(e)
  })
}

iqfr_v2_rank_quantile <- function(results) {
  groups <- interaction(results$family, results$tau,
                        results$likelihood_family, drop = TRUE)
  rows <- lapply(split(results, groups), function(x) {
    x$selection_score <- rank(x$forecast_qtrue_mae, ties.method = "min") +
      0.20 * rank(x$forecast_check_loss, ties.method = "min") +
      0.10 * rank(x$fit_qtrue_rmse, ties.method = "min")
    x$cell_rank <- rank(x$selection_score, ties.method = "first")
    x[order(x$selection_score, x$forecast_qtrue_mae), , drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqfr_v2_attach_mcmc_readout <- function(design, fit_object) {
  design$fit <- fit_object$fit
  design$mu_hat <- as.numeric(design$X %*% design$fit$summary$beta_mean)
  design$meta$inference_method <- "mcmc"
  class(design) <- c("qdesn_fit", "list")
  design
}

iqfr_v2_metric_summary <- function(x, prefix) {
  x <- as.numeric(x)
  if (!length(x) || any(!is.finite(x))) {
    stop("Metric draw vector is empty or nonfinite: ", prefix, call. = FALSE)
  }
  q <- stats::quantile(x, c(0.025, 0.975), names = FALSE, type = 8)
  out <- c(mean(x), q[[1L]], q[[2L]])
  names(out) <- paste0(prefix, c("_mean", "_lower", "_upper"))
  out
}

iqfr_v2_draw_metric_accumulator <- function(lattice, origins_local, x, tau) {
  nd <- ncol(lattice$mu_by_origin[[1L]])
  abs_sum <- sq_sum <- check_sum <- numeric(nd)
  point_rows <- vector("list", length(origins_local))
  count <- 0L
  for (i in seq_along(origins_local)) {
    q <- as.matrix(lattice$mu_by_origin[[i]])
    source_targets <- origins_local[[i]] + seq_len(nrow(q)) + 8110L
    idx <- match(source_targets, x$t)
    if (anyNA(idx)) stop("MCMC forecast target alignment failed.", call. = FALSE)
    truth <- x$q_target[idx]
    observed <- x$y[idx]
    abs_sum <- abs_sum + colSums(abs(sweep(q, 1L, truth, `-`)))
    sq_sum <- sq_sum + colSums(sweep(q, 1L, truth, `-`)^2)
    check_sum <- check_sum + colSums(vapply(
      seq_len(nd), function(j) iqfr_v2_check_loss(observed, q[, j], tau),
      numeric(nrow(q))
    ))
    count <- count + nrow(q)
    point_rows[[i]] <- data.frame(
      source_origin = origins_local[[i]] + 8110L,
      lead = seq_len(nrow(q)), source_target = source_targets,
      qtrue = truth, observed = observed,
      posterior_mean_quantile = rowMeans(q),
      posterior_sd_quantile = apply(q, 1L, stats::sd),
      stringsAsFactors = FALSE
    )
  }
  list(
    forecast_qtrue_mae = abs_sum / count,
    forecast_qtrue_rmse = sqrt(sq_sum / count),
    forecast_check_loss = check_sum / count,
    point = do.call(rbind, point_rows), pairs = count
  )
}

iqfr_v2_write_csv_gz <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = paste0(".", basename(path), "."),
                  tmpdir = dirname(path), fileext = ".gz")
  con <- gzfile(tmp, open = "wt")
  ok <- FALSE
  con_open <- TRUE
  on.exit({
    if (con_open) close(con)
    if (!ok) unlink(tmp, force = TRUE)
  }, add = TRUE)
  utils::write.csv(x, con, row.names = FALSE, na = "")
  close(con)
  con_open <- FALSE
  if (!file.rename(tmp, path)) stop("Could not atomically write ", path,
                                    call. = FALSE)
  ok <- TRUE
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

iqfr_v2_safe_ess <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 4L) return(NA_real_)
  if (requireNamespace("coda", quietly = TRUE)) {
    out <- tryCatch(
      coda::effectiveSize(coda::as.mcmc(x)),
      error = function(e) NA_real_
    )
    return(as.numeric(out)[[1L]])
  }
  ac <- tryCatch(
    as.numeric(stats::acf(x, lag.max = min(1000L, length(x) - 1L),
                          plot = FALSE)$acf)[-1L],
    error = function(e) numeric()
  )
  if (!length(ac)) return(NA_real_)
  first_nonpositive <- which(ac <= 0)[1L]
  if (is.na(first_nonpositive)) first_nonpositive <- length(ac) + 1L
  denom <- 1 + 2 * sum(ac[seq_len(max(0L, first_nonpositive - 1L))])
  min(length(x), length(x) / max(denom, 1))
}

iqfr_v2_safe_acf1 <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 3L) return(NA_real_)
  as.numeric(stats::acf(x, lag.max = 1L, plot = FALSE)$acf[[2L]])
}

iqfr_v2_mcmc_job <- function(config_path) {
  started <- Sys.time()
  config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
  cfg <- iqfr_v2_read_json(config_path)
  status_path <- as.character(cfg$status_path)
  result_path <- as.character(cfg$result_path)
  base_status <- list(
    schema_version = iqfr_v2_schema, job_id = cfg$job_id,
    stage = cfg$stage, config_path = config_path,
    config_sha256 = iqfr_v2_sha256(config_path), pid = Sys.getpid(),
    host = Sys.info()[["nodename"]],
    started_at = format(started, "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(c(base_status, list(status = "RUNNING")), status_path)
  tryCatch({
    candidate <- cfg$candidate
    source_path <- as.character(iqfr_v2_scalar(cfg$source$frozen_path))
    expected_hash <- as.character(iqfr_v2_scalar(cfg$source$frozen_sha256))
    if (!identical(iqfr_v2_sha256(source_path), expected_hash)) {
      stop("MCMC source hash mismatch.", call. = FALSE)
    }
    x <- iqfr_v2_source_rows(source_path)
    tau <- iqfr_v2_number(cfg$tau)
    likelihood <- as.character(cfg$likelihood_family)
    is_confirmation <- identical(as.character(cfg$stage), "mcmc_confirmation")
    train_end <- if (is_confirmation) 9000L else 8800L
    rollout_end <- if (is_confirmation) 10000L else 9000L
    fit_rows <- x$t >= 8501L & x$t <= train_end
    train_rows <- x$t <= train_end
    rollout_rows <- x$t <= rollout_end
    preprocess <- iqfr_v2_training_preprocess(
      x$y[fit_rows], iqfr_v2_scalar(candidate$center_scale)
    )
    budget <- cfg$budget
    seed <- iqfr_v2_integer(cfg$seed)
    mcmc_args <- list(
      likelihood_family = likelihood,
      al_fixed_gamma = if (likelihood == "al") 0 else NULL,
      beta_prior_type = "rhs_ns",
      beta_rhs = list(
        tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = 1,
        shrink_intercept = FALSE, n_inner = 2L
      ),
      n_burn = iqfr_v2_integer(budget$burn),
      n_mcmc = iqfr_v2_integer(budget$sample), thin = 1L,
      verbose = FALSE, progress_every = 250L,
      init_from_vb = TRUE,
      vb_warm_start_seed = iqfr_v2_seed(seed, "vb_warm"),
      vb_warm_start_control = list(
        max_iter = 100L, min_iter_elbo = 10L, tol = 1e-3,
        tol_par = 1e-3, n_samp_xi = 200L,
        beta_covariance = list(
          approximation = "diagonal", label_uncertainty = TRUE
        ),
        sigmagam = exal_make_vb_sigmagam_control()
      ),
      sigmagam = exal_make_mcmc_sigmagam_control(),
      slice = if (likelihood == "exal") {
        list(core_update_mode = "m0_v_collapsed_support_logit")
      } else list(core_update_mode = "sigma_then_gamma"),
      store_latent_draws = FALSE, store_rhs_draws = FALSE,
      mcmc_control = list(rng_seed = seed)
    )
    fit_args <- iqfr_v2_design_args(
      y = x$y[train_rows], candidate = candidate,
      preprocess = preprocess, p0 = tau, fit_readout = TRUE
    )
    fit_args$normal_args <- NULL
    fit_args$mcmc_args <- mcmc_args
    fit <- do.call(qdesn_fit_mcmc, fit_args)
    expected_fit_rows <- train_end - 8500L
    iqfr_v2_assert_design(fit, candidate, expected_fit_rows)

    rollout_args <- iqfr_v2_design_args(
      y = x$y[rollout_rows], candidate = candidate,
      preprocess = preprocess, p0 = tau, fit_readout = FALSE
    )
    rollout_args$normal_args <- NULL
    rollout_args$vb_args <- list()
    rollout <- do.call(qdesn_fit_vb, rollout_args)
    iqfr_v2_assert_design(rollout, candidate, rollout_end - 8500L)
    rollout <- iqfr_v2_attach_mcmc_readout(rollout, fit)

    nd <- iqfr_v2_integer(budget$draws)
    draws <- exal_posterior_draws(fit$fit, nd = nd,
                                  seed = iqfr_v2_seed(seed, "posterior_draws"))
    fit_q <- fit$X %*% t(draws$beta)
    fit_truth <- x$q_target[fit_rows]
    fit_observed <- x$y[fit_rows]
    fit_rmse <- sqrt(colMeans(sweep(fit_q, 1L, fit_truth, `-`)^2))
    fit_mae <- colMeans(abs(sweep(fit_q, 1L, fit_truth, `-`)))
    fit_check <- vapply(seq_len(ncol(fit_q)), function(j) {
      mean(iqfr_v2_check_loss(fit_observed, fit_q[, j], tau))
    }, numeric(1L))

    origins_source <- if (is_confirmation) 9000:9970 else
      seq.int(8800L, 8970L, by = 5L)
    origins_local <- origins_source - 8110L
    estimators <- c("posterior_predictive",
                    "posterior_predictive_mean_readout_state")
    rows <- vector("list", length(estimators))
    granular <- vector("list", length(estimators))
    metric_draws <- vector("list", length(estimators))
    for (j in seq_along(estimators)) {
      estimator <- estimators[[j]]
      lattice <- forecast_lattice.qdesn_fit(
        rollout, y_all = x$y[rollout_rows], origins = origins_local,
        H = 30L, nd = nd, draws = draws, keep_origin_draws = TRUE,
        build_mix = FALSE, seed = iqfr_v2_seed(seed, estimator),
        recursion_mode = estimator
      )
      metrics <- iqfr_v2_draw_metric_accumulator(
        lattice, origins_local, x, tau
      )
      summary <- c(
        iqfr_v2_metric_summary(fit_rmse, "fit_qtrue_rmse"),
        iqfr_v2_metric_summary(fit_mae, "fit_qtrue_mae"),
        iqfr_v2_metric_summary(fit_check, "fit_check_loss"),
        iqfr_v2_metric_summary(metrics$forecast_qtrue_mae,
                               "forecast_qtrue_mae"),
        iqfr_v2_metric_summary(metrics$forecast_qtrue_rmse,
                               "forecast_qtrue_rmse"),
        iqfr_v2_metric_summary(metrics$forecast_check_loss,
                               "forecast_check_loss")
      )
      rows[[j]] <- cbind(data.frame(
        schema_version = iqfr_v2_schema, stage = cfg$stage,
        job_id = cfg$job_id,
        family = as.character(iqfr_v2_scalar(candidate$family)),
        candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
        candidate_signature = as.character(iqfr_v2_scalar(candidate$candidate_signature)),
        likelihood_family = likelihood,
        model_variant = if (likelihood == "al") {
          "qdesn_al_rhs"
        } else "qdesn_exal_rhs",
        tau = tau, chain_id = iqfr_v2_integer(cfg$chain_id, 1L),
        estimator = if (estimator == "posterior_predictive") {
          "path_recursive"
        } else "mean_readout_state_recursive",
        rhs_tau0 = iqfr_v2_number(candidate$rhs_tau0),
        mcmc_burn = iqfr_v2_integer(budget$burn),
        mcmc_sample = iqfr_v2_integer(budget$sample), posterior_draws = nd,
        forecast_origins = length(origins_local), forecast_pairs = metrics$pairs,
        core_update_mode = if (likelihood == "exal") {
          "m0_v_collapsed_support_logit"
        } else "sigma_then_gamma",
        mcmc_ess_gamma = iqfr_v2_safe_ess(fit$fit$samp.gamma),
        mcmc_ess_sigma = iqfr_v2_safe_ess(fit$fit$samp.sigma),
        mcmc_ess_beta_norm = iqfr_v2_safe_ess(sqrt(rowSums(
          as.matrix(fit$fit$samp.beta)^2
        ))),
        mcmc_acf1_gamma = iqfr_v2_safe_acf1(fit$fit$samp.gamma),
        mcmc_acf1_sigma = iqfr_v2_safe_acf1(fit$fit$samp.sigma),
        stringsAsFactors = FALSE
      ), as.data.frame(as.list(summary), check.names = FALSE))
      metric_draws[[j]] <- data.frame(
        job_id = cfg$job_id,
        candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
        family = as.character(iqfr_v2_scalar(candidate$family)),
        likelihood_family = likelihood, tau = tau,
        chain_id = iqfr_v2_integer(cfg$chain_id, 1L),
        estimator = rows[[j]]$estimator[[1L]],
        metric_draw_index = seq_len(nd),
        posterior_source_draw_index = as.integer(
          draws$source_draw_index %||% seq_len(nd)
        ),
        gamma = as.numeric(draws$gamma), sigma = as.numeric(draws$sigma),
        fit_qtrue_rmse = fit_rmse, fit_qtrue_mae = fit_mae,
        fit_check_loss = fit_check,
        forecast_qtrue_mae = metrics$forecast_qtrue_mae,
        forecast_qtrue_rmse = metrics$forecast_qtrue_rmse,
        forecast_check_loss = metrics$forecast_check_loss,
        stringsAsFactors = FALSE
      )
      granular[[j]] <- cbind(data.frame(
        job_id = cfg$job_id,
        candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
        family = as.character(iqfr_v2_scalar(candidate$family)),
        likelihood_family = likelihood, tau = tau,
        chain_id = iqfr_v2_integer(cfg$chain_id, 1L),
        estimator = rows[[j]]$estimator[[1L]], stringsAsFactors = FALSE
      ), metrics$point)
      rm(lattice, metrics)
      gc(verbose = FALSE)
    }
    result <- do.call(rbind, rows)
    granular_path <- sub("[.]csv$", "__origin_lead.csv.gz", result_path)
    iqfr_v2_write_csv_gz(do.call(rbind, granular), granular_path)
    metric_draw_path <- sub("[.]csv$", "__metric_draws.csv.gz", result_path)
    iqfr_v2_write_csv_gz(do.call(rbind, metric_draws), metric_draw_path)
    result$origin_lead_path <- granular_path
    result$origin_lead_sha256 <- iqfr_v2_sha256(granular_path)
    result$metric_draw_path <- metric_draw_path
    result$metric_draw_sha256 <- iqfr_v2_sha256(metric_draw_path)
    result$runtime_seconds_job <- as.numeric(difftime(Sys.time(), started,
                                                       units = "secs"))
    iqfr_v2_write_csv(result, result_path)
    finished <- Sys.time()
    iqfr_v2_write_json(c(base_status, list(
      status = "SUCCESS", finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      rows = nrow(result), result_path = result_path,
      result_sha256 = iqfr_v2_sha256(result_path),
      origin_lead_path = granular_path,
      origin_lead_sha256 = iqfr_v2_sha256(granular_path),
      metric_draw_path = metric_draw_path,
      metric_draw_sha256 = iqfr_v2_sha256(metric_draw_path),
      fitted_model_binaries = 0L
    )), status_path)
    invisible(result)
  }, error = function(e) {
    finished <- Sys.time()
    iqfr_v2_write_json(c(base_status, list(
      status = "FAILED", finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      error_class = class(e)[[1L]], error_message = conditionMessage(e)
    )), status_path)
    stop(e)
  })
}

iqfr_v2_select_cell_finalists <- function(results, n_per_cell,
                                           metric_suffix = "") {
  n_per_cell <- as.integer(n_per_cell)
  primary <- paste0("forecast_qtrue_mae", metric_suffix)
  secondary <- paste0("forecast_check_loss", metric_suffix)
  tertiary <- paste0("fit_qtrue_rmse", metric_suffix)
  required <- c("family", "tau", "likelihood_family", "candidate_id",
                primary, secondary, tertiary)
  if (!all(required %in% names(results))) {
    stop("Finalist input is missing ranking columns: ",
         paste(setdiff(required, names(results)), collapse = ", "),
         call. = FALSE)
  }
  groups <- interaction(results$family, results$tau,
                        results$likelihood_family, drop = TRUE)
  rows <- lapply(split(results, groups), function(x) {
    finite <- is.finite(x[[primary]]) & is.finite(x[[secondary]]) &
      is.finite(x[[tertiary]])
    x <- x[finite & !duplicated(x$candidate_id), , drop = FALSE]
    if (!nrow(x)) stop("A selection cell has no finite candidates.",
                       call. = FALSE)
    x$selection_score <- rank(x[[primary]], ties.method = "min") +
      0.20 * rank(x[[secondary]], ties.method = "min") +
      0.10 * rank(x[[tertiary]], ties.method = "min")
    x <- x[order(x$selection_score, x[[primary]], x[[secondary]],
                 x[[tertiary]]), , drop = FALSE]
    x <- x[seq_len(min(n_per_cell, nrow(x))), , drop = FALSE]
    x$finalist_rank <- seq_len(nrow(x))
    x
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  expected_cells <- length(iqfr_v2_families) * length(iqfr_v2_quantiles) * 2L
  if (length(unique(interaction(out$family, out$tau,
                                out$likelihood_family))) != expected_cells) {
    stop("Finalist selection does not cover all 18 Q-DESN cells.",
         call. = FALSE)
  }
  out
}

iqfr_v2_materialize_mcmc_jobs <- function(repo_root, run_root, protocol,
                                           selected, candidates, sources,
                                           stage) {
  stage <- match.arg(stage, c("mcmc_pilot", "mcmc_confirmation"))
  is_confirmation <- identical(stage, "mcmc_confirmation")
  budget <- if (is_confirmation) {
    protocol$inference$mcmc$confirmation
  } else {
    protocol$inference$mcmc$pilot
  }
  chain_ids <- if (is_confirmation) {
    seq_len(as.integer(budget$chains))
  } else 1L
  config_dir <- file.path(run_root, "configs", stage)
  dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(selected))) {
    selected_row <- selected[i, , drop = FALSE]
    candidate <- candidates[
      candidates$candidate_id == selected_row$candidate_id[[1L]],
      , drop = FALSE
    ]
    if (nrow(candidate) != 1L) {
      stop("Could not resolve exactly one candidate specification for ",
           selected_row$candidate_id[[1L]], call. = FALSE)
    }
    source <- sources[
      sources$family == selected_row$family[[1L]] &
        abs(sources$tau - as.numeric(selected_row$tau[[1L]])) < 1e-10,
      , drop = FALSE
    ]
    if (nrow(source) != 1L) {
      stop("Could not resolve exactly one frozen source for an MCMC cell.",
           call. = FALSE)
    }
    for (chain_id in chain_ids) {
      tau_token <- gsub("[.]", "p", sprintf("%.2f",
                                             selected_row$tau[[1L]]))
      job_id <- paste(
        stage, selected_row$family[[1L]],
        selected_row$likelihood_family[[1L]], tau_token,
        selected_row$candidate_id[[1L]], sprintf("chain%02d", chain_id),
        sep = "__"
      )
      config_path <- file.path(config_dir, paste0(job_id, ".json"))
      result_path <- file.path(run_root, "results", stage,
                               paste0(job_id, ".csv"))
      status_path <- file.path(run_root, "status", stage,
                               paste0(job_id, ".json"))
      config <- list(
        schema_version = iqfr_v2_schema,
        protocol_id = protocol$protocol$id, stage = stage,
        job_id = job_id, repo_root = repo_root, run_root = run_root,
        protocol_sha256 = iqfr_v2_sha256(file.path(
          repo_root, iqfr_v2_protocol_relpath
        )),
        source = as.list(source[1L, , drop = FALSE]),
        candidate = as.list(candidate[1L, , drop = FALSE]),
        likelihood_family = selected_row$likelihood_family[[1L]],
        tau = as.numeric(selected_row$tau[[1L]]),
        chain_id = as.integer(chain_id),
        selection_rank = as.integer(selected_row$finalist_rank[[1L]]),
        selection_source_stage = if (is_confirmation) {
          "mcmc_pilot"
        } else "quantile_vb",
        result_path = result_path, status_path = status_path,
        seed = iqfr_v2_seed(job_id, "independent_redesign_mcmc"),
        budget = budget
      )
      iqfr_v2_write_json(config, config_path)
      k <- k + 1L
      rows[[k]] <- data.frame(
        stage = stage, job_id = job_id,
        family = selected_row$family[[1L]],
        likelihood_family = selected_row$likelihood_family[[1L]],
        tau = as.numeric(selected_row$tau[[1L]]),
        candidate_id = selected_row$candidate_id[[1L]],
        finalist_rank = as.integer(selected_row$finalist_rank[[1L]]),
        chain_id = as.integer(chain_id),
        config_path = config_path,
        config_sha256 = iqfr_v2_sha256(config_path),
        result_path = result_path, status_path = status_path,
        stringsAsFactors = FALSE
      )
    }
  }
  plan <- do.call(rbind, rows)
  plan_path <- iqfr_v2_write_csv(
    plan, file.path(run_root, "plans", paste0(stage, ".csv"))
  )
  list(plan = plan, plan_path = plan_path, budget = budget)
}

iqfr_v2_pending_configs <- function(plan_path) {
  plan <- utils::read.csv(plan_path, check.names = FALSE,
                          stringsAsFactors = FALSE)
  keep <- vapply(seq_len(nrow(plan)), function(i) {
    path <- plan$status_path[[i]]
    if (!file.exists(path)) return(TRUE)
    status <- tryCatch(iqfr_v2_read_json(path), error = function(e) NULL)
    if (is.null(status)) return(TRUE)
    state <- as.character(status$status %||% "")
    if (identical(state, "SUCCESS")) return(FALSE)
    if (identical(state, "RUNNING")) {
      same_host <- identical(as.character(status$host %||% ""),
                             as.character(Sys.info()[["nodename"]]))
      pid <- suppressWarnings(as.integer(status$pid %||% NA_integer_))
      if (same_host && is.finite(pid) &&
          file.exists(file.path("/proc", as.character(pid)))) {
        return(FALSE)
      }
    }
    TRUE
  }, logical(1L))
  as.character(plan$config_path[keep])
}

iqfr_v2_read_metric_draws <- function(result_rows) {
  paths <- unique(as.character(result_rows$metric_draw_path))
  hashes <- setNames(as.character(result_rows$metric_draw_sha256),
                     as.character(result_rows$metric_draw_path))
  if (!length(paths) || any(!file.exists(paths))) {
    stop("Confirmation metric-draw artifacts are incomplete.", call. = FALSE)
  }
  observed <- vapply(paths, iqfr_v2_sha256, character(1L))
  if (any(observed != hashes[paths])) {
    stop("Confirmation metric-draw hash verification failed.", call. = FALSE)
  }
  out <- do.call(rbind, lapply(paths, utils::read.csv,
                              check.names = FALSE, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}

iqfr_v2_pool_confirmation_metrics <- function(draws) {
  metric_columns <- c(
    "fit_qtrue_rmse", "fit_qtrue_mae", "fit_check_loss",
    "forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss"
  )
  required <- c("family", "tau", "likelihood_family", "candidate_id",
                "chain_id", "estimator", metric_columns)
  if (!all(required %in% names(draws))) {
    stop("Pooled confirmation draws are missing required columns.",
         call. = FALSE)
  }
  key <- interaction(draws$family, draws$tau, draws$likelihood_family,
                     draws$candidate_id, draws$estimator, drop = TRUE)
  rows <- lapply(split(draws, key), function(x) {
    base <- x[1L, c("family", "tau", "likelihood_family", "candidate_id",
                    "estimator"), drop = FALSE]
    base$chains <- length(unique(x$chain_id))
    base$pooled_draws <- nrow(x)
    for (metric in metric_columns) {
      values <- as.numeric(x[[metric]])
      if (any(!is.finite(values))) {
        stop("Nonfinite pooled metric draws for ", metric, call. = FALSE)
      }
      interval <- stats::quantile(values, c(0.025, 0.975),
                                  names = FALSE, type = 8)
      base[[paste0(metric, "_mean")]] <- mean(values)
      base[[paste0(metric, "_lower")]] <- interval[[1L]]
      base[[paste0(metric, "_upper")]] <- interval[[2L]]
    }
    base
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqfr_v2_closeout <- function(repo_root, run_root) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  plan_path <- file.path(run_root, "plans", "mcmc_confirmation.csv")
  confirmation <- iqfr_v2_collect_results(plan_path, require_complete = TRUE)
  if (any(confirmation$forecast_origins != 971L) ||
      any(confirmation$forecast_pairs != 29130L)) {
    stop("Confirmation rows violate the final stride-one lattice.",
         call. = FALSE)
  }
  chain_path <- iqfr_v2_write_csv(
    confirmation,
    file.path(run_root, "summaries", "mcmc_confirmation_chain_results.csv")
  )
  draws <- iqfr_v2_read_metric_draws(confirmation)
  expected_draw_rows <- nrow(unique(confirmation[c("job_id")])) *
    as.integer(protocol$inference$mcmc$confirmation$draws) * 2L
  if (nrow(draws) != expected_draw_rows) {
    stop("Unexpected number of pooled confirmation metric draws.",
         call. = FALSE)
  }
  draw_path <- iqfr_v2_write_csv_gz(
    draws, file.path(run_root, "summaries",
                     "mcmc_confirmation_metric_draws.csv.gz")
  )
  pooled <- iqfr_v2_pool_confirmation_metrics(draws)
  if (any(pooled$chains !=
          as.integer(protocol$inference$mcmc$confirmation$chains))) {
    stop("A pooled candidate summary is missing confirmation chains.",
         call. = FALSE)
  }
  pooled_path <- iqfr_v2_write_csv(
    pooled, file.path(run_root, "summaries",
                      "mcmc_confirmation_candidate_metrics.csv")
  )
  primary <- pooled[pooled$estimator == "path_recursive", , drop = FALSE]
  cell <- interaction(primary$family, primary$tau,
                      primary$likelihood_family, drop = TRUE)
  winners <- do.call(rbind, lapply(split(primary, cell), function(x) {
    x <- x[order(x$forecast_qtrue_mae_mean,
                 x$forecast_check_loss_mean,
                 x$fit_qtrue_rmse_mean), , drop = FALSE]
    x[1L, , drop = FALSE]
  }))
  rownames(winners) <- NULL
  if (nrow(winners) != 18L) {
    stop("Closeout did not select exactly 18 case-specific winners.",
         call. = FALSE)
  }
  winner_keys <- paste(winners$family, winners$tau,
                       winners$likelihood_family, winners$candidate_id)
  pooled_keys <- paste(pooled$family, pooled$tau,
                       pooled$likelihood_family, pooled$candidate_id)
  selected_metrics <- pooled[pooled_keys %in% winner_keys, , drop = FALSE]
  if (nrow(selected_metrics) != 36L) {
    stop("Each winner must retain both paired forecast estimators.",
         call. = FALSE)
  }
  winner_path <- iqfr_v2_write_csv(
    winners, file.path(run_root, "summaries", "mcmc_cell_winners.csv")
  )
  selected_path <- iqfr_v2_write_csv(
    selected_metrics,
    file.path(run_root, "summaries", "mcmc_selected_winner_metrics.csv")
  )

  authority_paths <- c(
    qdesn_v11 = file.path(
      repo_root, "validation", "fitforecast_v2", "promotions",
      "qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827",
      "qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827_interface.csv"
    ),
    exdqlm_rolling_fix = file.path(
      repo_root, "validation", "fitforecast_v2", "promotions",
      "independent_exdqlm_mcmc_rolling_state_fix_v1_20260829",
      "candidate_point_exdqlm_mcmc_rows.csv"
    )
  )
  if (any(!file.exists(authority_paths))) {
    stop("A declared fixed-comparator authority is missing.", call. = FALSE)
  }
  authority_ledger <- data.frame(
    authority = names(authority_paths), path = unname(authority_paths),
    sha256 = vapply(authority_paths, iqfr_v2_sha256, character(1L)),
    role = c("current_qdesn_article_authority_reference",
             "corrected_exdqlm_fixed_comparator_reference"),
    direct_score_comparison = FALSE,
    reason = "historical stride differs; regenerate common-grid comparators before article replacement",
    stringsAsFactors = FALSE
  )
  authority_path <- iqfr_v2_write_csv(
    authority_ledger,
    file.path(run_root, "summaries", "fixed_comparator_authority_ledger.csv")
  )

  artifact_path <- file.path(run_root, "manifests", "artifact_manifest.csv")
  status <- list(
    schema_version = iqfr_v2_schema,
    status = "READY_FOR_SCIENTIFIC_REVIEW_NO_AUTOMATIC_ARTICLE_PROMOTION",
    completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    scientific_lane = protocol$protocol$scientific_lane,
    selected_cells = nrow(winners), paired_estimator_rows = nrow(selected_metrics),
    confirmation_jobs = nrow(unique(confirmation["job_id"])),
    confirmation_chains_per_candidate =
      as.integer(protocol$inference$mcmc$confirmation$chains),
    final_origins = 971L, final_pairs_per_row = 29130L,
    fitted_model_binaries = 0L, article_write_performed = FALSE,
    shared_validation_merge_performed = FALSE,
    historical_comparator_scores_directly_comparable = FALSE,
    next_required_action = paste(
      "Regenerate the frozen DQLM/exDQLM comparators on the same stride-one",
      "lattice, then perform scientific comparison and integration review."
    ),
    outputs = list(
      chain_results = chain_path, pooled_metric_draws = draw_path,
      pooled_candidate_metrics = pooled_path, cell_winners = winner_path,
      selected_winner_metrics = selected_path,
      fixed_comparator_authorities = authority_path,
      artifact_manifest = artifact_path
    )
  )
  status_path <- iqfr_v2_write_json(
    status, file.path(run_root, "manifests", "closeout.json")
  )
  files <- unique(c(
    list.files(file.path(run_root, "plans"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(run_root, "manifests"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(run_root, "summaries"), recursive = TRUE,
               full.names = TRUE),
    file.path(run_root, "source_manifest.csv")
  ))
  files <- files[file.exists(files) & !dir.exists(files)]
  files <- files[normalizePath(files, winslash = "/", mustWork = FALSE) !=
                   normalizePath(artifact_path, winslash = "/",
                                 mustWork = FALSE)]
  artifact <- data.frame(
    path = files, bytes = as.numeric(file.info(files)$size),
    sha256 = vapply(files, iqfr_v2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  artifact_path <- iqfr_v2_write_csv(artifact, artifact_path)
  list(status = status, status_path = status_path, winners = winners,
       selected_metrics = selected_metrics)
}
