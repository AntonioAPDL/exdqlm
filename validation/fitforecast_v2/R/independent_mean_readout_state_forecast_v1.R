if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

imrs_v1_schema <- "independent_mean_readout_state_forecast_v1"
imrs_v1_stage <- "qdesn_500obs_independent_mean_readout_state_forecast_v1"
imrs_v1_workers <- 8L
imrs_v1_threads_per_worker <- 1L
imrs_v1_estimator <-
  "mean_readout_state_quantile_draw_metric_equal_tailed_95cri_v1"
imrs_v1_recursion_mode <- "posterior_predictive_mean_readout_state"
imrs_v1_native_mode <- "posterior_predictive"
imrs_v1_tolerance <- 1e-6
imrs_v1_historical_compatibility_schema <-
  "historical_native_authority_compatibility_v1"

imrs_v1_vb_sources <- sprintf(
  "imi_v1_source_%03d",
  c(7:12, 19:24, 31:36)
)

imrs_v1_mcmc_sources <- sprintf(
  "imi_v1_source_%03d",
  c(75, 44, 85, 76, 86, 74, 77, 55, 79, 88, 56, 87, 59,
    89, 78, 57, 80, 60, 67, 90, 82, 68, 83, 81, 84)
)

imrs_v1_idolp_source <- "idolp_v2_winner_three_chain_pool"

imrs_v1_vb_source_map <- function() {
  data.frame(
    source_id = sprintf("imi_v1_source_%03d", c(
      7:9, 10:12, 19:21, 22:24, 31:33, 34:36
    )),
    likelihood_family = rep(c("al", "exal"), each = 3L, times = 3L),
    family = rep(c("normal", "laplace", "gausmix"), each = 6L),
    tau = rep(c(0.05, 0.25, 0.50), times = 6L),
    stringsAsFactors = FALSE
  )
}

imrs_v1_role_map <- function() {
  rows <- list()
  add <- function(inference, likelihood, family, tau, metric_role, source_id,
                  pooling_policy) {
    rows[[length(rows) + 1L]] <<- data.frame(
      inference = inference,
      likelihood_family = likelihood,
      family = family,
      tau = tau,
      metric_role = metric_role,
      source_id = source_id,
      pooling_policy = pooling_policy,
      stringsAsFactors = FALSE
    )
  }

  vb_grid <- imrs_v1_vb_source_map()
  for (i in seq_len(nrow(vb_grid))) {
    for (metric in c("forecast_mae", "forecast_check_loss")) {
      add(
        "vb", vb_grid$likelihood_family[[i]], vb_grid$family[[i]],
        vb_grid$tau[[i]], metric, vb_grid$source_id[[i]], "single_basis"
      )
    }
  }

  mcmc <- data.frame(
    family = rep(c("normal", "laplace", "gausmix"), each = 3L),
    tau = rep(c(0.05, 0.25, 0.50), times = 3L),
    al_mae = c(imrs_v1_idolp_source, "imi_v1_source_044", "imi_v1_source_074",
               "imi_v1_source_055", "imi_v1_source_056", "imi_v1_source_078",
               "imi_v1_source_067", "imi_v1_source_068", "imi_v1_source_081"),
    al_check = c(imrs_v1_idolp_source, "imi_v1_source_085", "imi_v1_source_074",
                 "imi_v1_source_055", "imi_v1_source_087", "imi_v1_source_057",
                 "imi_v1_source_090", "imi_v1_source_068", "imi_v1_source_081"),
    exal_mae = c("imi_v1_source_075", "imi_v1_source_076", "imi_v1_source_077",
                 "imi_v1_source_079", "imi_v1_source_059", "imi_v1_source_080",
                 "imi_v1_source_082", "imi_v1_source_083", "imi_v1_source_084"),
    exal_check = c("imi_v1_source_075", "imi_v1_source_086", "imi_v1_source_077",
                   "imi_v1_source_088", "imi_v1_source_089", "imi_v1_source_060",
                   "imi_v1_source_082", "imi_v1_source_083", "imi_v1_source_084"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(mcmc))) {
    for (likelihood in c("al", "exal")) {
      for (metric in c("mae", "check")) {
        source_id <- mcmc[[paste0(likelihood, "_", metric)]][[i]]
        add(
          "mcmc", likelihood, mcmc$family[[i]], mcmc$tau[[i]],
          if (metric == "mae") "forecast_mae" else "forecast_check_loss",
          source_id,
          if (identical(source_id, imrs_v1_idolp_source)) {
            "basis_specific_then_score_pool"
          } else {
            "compatible_basis_chain_pool"
          }
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

imrs_v1_sha256 <- function(path) {
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

imrs_v1_object_sha256 <- function(object) {
  digest::digest(object, algo = "sha256", serialize = TRUE)
}

imrs_v1_atomic_save_rds <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp.", Sys.getpid())
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  saveRDS(object, tmp, version = 3, compress = "gzip")
  if (!file.rename(tmp, path)) stop("Could not atomically publish RDS: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

imrs_v1_atomic_write_json <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp.", Sys.getpid())
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  jsonlite::write_json(
    object, tmp, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA
  )
  if (!file.rename(tmp, path)) stop("Could not atomically publish JSON: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

imrs_v1_atomic_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp.", Sys.getpid())
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, path)) stop("Could not atomically publish CSV: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

imrs_v1_read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = FALSE)
}

imrs_v1_set_one_thread <- function() {
  Sys.setenv(
    OMP_NUM_THREADS = "1",
    OMP_THREAD_LIMIT = "1",
    OPENBLAS_NUM_THREADS = "1",
    MKL_NUM_THREADS = "1",
    BLIS_NUM_THREADS = "1",
    VECLIB_MAXIMUM_THREADS = "1",
    NUMEXPR_NUM_THREADS = "1",
    RCPP_PARALLEL_NUM_THREADS = "1"
  )
  invisible(TRUE)
}

imrs_v1_stability_distance <- function(left, right, label = "quantity") {
  left <- as.numeric(left)
  right <- as.numeric(right)
  if (length(left) != length(right) || !identical(is.na(left), is.na(right)) ||
      any(is.infinite(left)) || any(is.infinite(right))) {
    stop(label, " stability vectors have incompatible non-finite structure.",
         call. = FALSE)
  }
  keep <- is.finite(left) & is.finite(right)
  if (!any(keep)) {
    stop(label, " stability vectors contain no comparable finite values.",
         call. = FALSE)
  }
  delta <- left[keep] - right[keep]
  c(
    max_abs_difference = max(abs(delta)),
    rms_difference = sqrt(mean(delta^2)),
    compared_values = sum(keep),
    structural_missing_values = sum(!keep)
  )
}

imrs_v1_validate_role_map <- function(role_map = imrs_v1_role_map()) {
  checks <- c(
    role_rows = nrow(role_map) == 72L,
    vb_cells = nrow(unique(role_map[role_map$inference == "vb",
      c("likelihood_family", "family", "tau")])) == 18L,
    mcmc_cells = nrow(unique(role_map[role_map$inference == "mcmc",
      c("likelihood_family", "family", "tau")])) == 18L,
    vb_sources = length(unique(role_map$source_id[role_map$inference == "vb"])) == 18L,
    mcmc_sources = length(unique(role_map$source_id[role_map$inference == "mcmc"])) == 26L,
    all_sources = length(unique(role_map$source_id)) == 44L
  )
  if (!all(checks)) {
    stop("Mean-readout-state role map failed: ",
         paste(names(checks)[!checks], collapse = ", "), call. = FALSE)
  }
  invisible(checks)
}

imrs_v1_extract_pipeline_capsule <- function(run, job) {
  fits <- (run$summary$forecast_objects %||% list())$fits_fc %||% list()
  if (length(fits) != 1L) {
    stop("Expected exactly one quantile fit in the pipeline result.", call. = FALSE)
  }
  capsule <- fits[[1L]]$mean_readout_state_capsule %||% NULL
  if (is.null(capsule) ||
      !identical(capsule$schema_version, "qdesn_mean_readout_state_fit_capsule_v1")) {
    stop("Pipeline did not return the requested mean-readout-state capsule.",
         call. = FALSE)
  }
  observed_basis_hash <- exdqlm:::.qdesn_mean_readout_state_basis_hash(
    capsule$qdesn_object
  )
  if (!identical(observed_basis_hash, capsule$feature_basis_hash)) {
    stop("Pipeline capsule feature-basis hash mismatch.", call. = FALSE)
  }
  draws <- capsule$posterior_draws
  if (!is.matrix(draws$beta) || nrow(draws$beta) < 2L ||
      length(draws$sigma) != nrow(draws$beta) ||
      length(draws$gamma) != nrow(draws$beta)) {
    stop("Pipeline capsule has incomplete posterior draws.", call. = FALSE)
  }
  if (length(capsule$analysis_source_index) != length(capsule$y_all) ||
      any(!is.finite(capsule$analysis_source_index))) {
    stop("Pipeline capsule has an invalid local-to-source index map.",
         call. = FALSE)
  }
  list(
    basis = list(
      schema_version = "qdesn_mean_readout_state_basis_capsule_v1",
      source_id = job$source_id,
      chain_id = as.integer(job$chain_id),
      feature_basis_hash = observed_basis_hash,
      qdesn_object = capsule$qdesn_object,
      y_all = capsule$y_all,
      analysis_source_index = as.integer(capsule$analysis_source_index),
      xreg_all = capsule$xreg_all,
      y_obs_last = capsule$y_obs_last,
      origins = capsule$origins,
      horizon = capsule$horizon,
      lead_weights = capsule$lead_weights,
      lead_export_scale = capsule$lead_export_scale,
      source_series_path = job$source_series_path,
      source_series_sha256 = job$source_series_sha256,
      root_spec = job$root_spec
    ),
    posterior = list(
      schema_version = "qdesn_mean_readout_state_posterior_capsule_v1",
      source_id = job$source_id,
      chain_id = as.integer(job$chain_id),
      feature_basis_hash = observed_basis_hash,
      beta = as.matrix(draws$beta),
      sigma = as.numeric(draws$sigma),
      gamma = as.numeric(draws$gamma),
      source_draw_index = as.integer(
        draws$source_draw_index %||% seq_len(nrow(draws$beta))
      ),
      inference = as.character(job$inference),
      likelihood_family = as.character(job$likelihood_family),
      tau = as.numeric(job$tau)
    )
  )
}

imrs_v1_generate_chain_noise <- function(draws, origins, horizon, seed) {
  set.seed(as.integer(seed))
  nd <- nrow(draws$beta)
  lapply(seq_along(origins), function(i) {
    s <- matrix(NA_real_, nrow = horizon, ncol = nd)
    v <- matrix(NA_real_, nrow = horizon, ncol = nd)
    z <- matrix(NA_real_, nrow = horizon, ncol = nd)
    for (j in seq_len(nd)) {
      s[, j] <- abs(stats::rnorm(horizon))
      v[, j] <- stats::rexp(horizon, rate = 1 / draws$sigma[[j]])
      z[, j] <- stats::rnorm(horizon)
    }
    list(s = s, v = v, z = z)
  })
}

imrs_v1_generate_pipeline_noise <- function(
    draws, draw_indices, origins, horizon, y_obs_last, seed,
    tail_seed_offset = 31L) {
  origins <- as.integer(origins)
  horizon <- as.integer(horizon)
  y_obs_last <- as.integer(y_obs_last)
  draw_indices <- as.integer(draw_indices)
  n_source_draws <- nrow(draws$beta)
  if (!length(origins) || horizon < 1L || !is.finite(y_obs_last)) {
    stop("Invalid pipeline-noise forecast geometry.", call. = FALSE)
  }
  if (!length(draw_indices) || anyNA(draw_indices) ||
      any(draw_indices < 1L | draw_indices > n_source_draws) ||
      anyDuplicated(draw_indices)) {
    stop("Invalid source draw indices for paired pipeline noise.", call. = FALSE)
  }

  complete <- origins + horizon <= y_obs_last
  out <- vector("list", length(origins))
  generate_segment <- function(idx, segment_seed) {
    if (!length(idx)) return(invisible(NULL))
    source_noise <- imrs_v1_generate_chain_noise(
      draws = draws,
      origins = origins[idx],
      horizon = horizon,
      seed = segment_seed
    )
    out[idx] <<- lapply(source_noise, function(x) {
      lapply(x, function(z) z[, draw_indices, drop = FALSE])
    })
    invisible(NULL)
  }
  generate_segment(which(complete), as.integer(seed))
  generate_segment(which(!complete), as.integer(seed) + as.integer(tail_seed_offset))
  if (any(vapply(out, is.null, logical(1L)))) {
    stop("Pipeline-noise segmentation left an origin unresolved.", call. = FALSE)
  }
  attr(out, "pairing_contract") <- list(
    full_seed = as.integer(seed),
    tail_seed = as.integer(seed) + as.integer(tail_seed_offset),
    tail_seed_offset = as.integer(tail_seed_offset),
    complete_origin_count = sum(complete),
    tail_origin_count = sum(!complete),
    source_draw_count = n_source_draws,
    selected_draw_count = length(draw_indices)
  )
  out
}

imrs_v1_combine_noise <- function(noise_sets) {
  n_origins <- unique(vapply(noise_sets, length, integer(1L)))
  if (length(n_origins) != 1L) stop("Noise sets have incompatible origin counts.")
  lapply(seq_len(n_origins), function(i) {
    list(
      s = do.call(cbind, lapply(noise_sets, function(x) x[[i]]$s)),
      v = do.call(cbind, lapply(noise_sets, function(x) x[[i]]$v)),
      z = do.call(cbind, lapply(noise_sets, function(x) x[[i]]$z))
    )
  })
}

imrs_v1_balance_posteriors <- function(posteriors) {
  hashes <- unique(vapply(posteriors, `[[`, character(1L), "feature_basis_hash"))
  if (length(hashes) != 1L) {
    stop("Refusing to pool posterior draws across incompatible feature bases.",
         call. = FALSE)
  }
  n_keep <- min(vapply(posteriors, function(x) nrow(x$beta), integer(1L)))
  if (n_keep < 2L) stop("At least two posterior draws per chain are required.")
  idx <- lapply(posteriors, function(x) {
    unique(as.integer(round(seq(1, nrow(x$beta), length.out = n_keep))))
  })
  list(
    draws = list(
      beta = do.call(rbind, Map(function(x, i) x$beta[i, , drop = FALSE],
                                posteriors, idx)),
      sigma = unlist(Map(function(x, i) x$sigma[i], posteriors, idx),
                       use.names = FALSE),
      gamma = unlist(Map(function(x, i) x$gamma[i], posteriors, idx),
                       use.names = FALSE),
      source_draw_index = unlist(Map(
        function(x, i) x$source_draw_index[i], posteriors, idx
      ), use.names = FALSE)
    ),
    chain_id = unlist(Map(
      function(x, i) rep(as.integer(x$chain_id), length(i)), posteriors, idx
    ), use.names = FALSE),
    within_chain_draw_id = unlist(lapply(idx, seq_along), use.names = FALSE),
    indices = idx,
    draws_per_chain = n_keep,
    feature_basis_hash = hashes[[1L]]
  )
}

imrs_v1_validate_native_posterior_alignment <- function(
    native_draws, posterior, selected_positions) {
  selected_positions <- as.integer(selected_positions)
  n_posterior <- if (is.matrix(posterior$beta)) nrow(posterior$beta) else 0L
  native_positions <- as.integer(native_draws$source_draw_index %||% integer())
  original_indices <- as.integer(
    posterior$source_draw_index %||% seq_len(n_posterior)
  )
  checks <- c(
    posterior_rows = n_posterior > 1L,
    native_rows = nrow(native_draws) == n_posterior,
    native_position_schema = length(native_positions) == n_posterior &&
      identical(native_positions, seq_len(n_posterior)),
    original_index_schema = length(original_indices) == n_posterior &&
      !anyNA(original_indices) && !anyDuplicated(original_indices),
    selected_position_schema = length(selected_positions) > 1L &&
      !anyNA(selected_positions) && !anyDuplicated(selected_positions) &&
      all(selected_positions >= 1L & selected_positions <= n_posterior)
  )
  if (!all(checks)) {
    stop(
      "Native metric rows and posterior capsule violate positional alignment: ",
      paste(names(checks)[!checks], collapse = ", "), call. = FALSE
    )
  }
  data.frame(
    selected_position = selected_positions,
    native_position = native_positions[selected_positions],
    posterior_original_draw_index = original_indices[selected_positions],
    stringsAsFactors = FALSE
  )
}

imrs_v1_apply_scale <- function(x, scale_spec) {
  x * as.numeric(scale_spec$scale %||% 1) +
    as.numeric(scale_spec$center %||% 0)
}

imrs_v1_score_lattice <- function(lattice, basis, chain_id,
                                  within_chain_draw_id) {
  source <- utils::read.csv(
    basis$source_series_path, stringsAsFactors = FALSE, check.names = FALSE
  )
  source_index <- if ("source_index" %in% names(source)) {
    as.integer(source$source_index)
  } else if ("t" %in% names(source)) {
    as.integer(source$t)
  } else {
    seq_len(nrow(source))
  }
  analysis_source_index <- as.integer(
    basis$analysis_source_index %||% seq_len(length(basis$y_all))
  )
  if (length(analysis_source_index) != length(basis$y_all) ||
      anyNA(match(analysis_source_index, source_index))) {
    stop("Forecast capsule has an invalid local-to-source index map.",
         call. = FALSE)
  }
  q_true <- if ("q_target" %in% names(source)) {
    as.numeric(source$q_target)
  } else if ("q_true" %in% names(source)) {
    as.numeric(source$q_true)
  } else {
    as.numeric(source$mu)
  }
  y <- as.numeric(source$y)
  nd <- ncol(lattice$mu_by_origin[[1L]])
  if (length(chain_id) != nd || length(within_chain_draw_id) != nd) {
    stop("Draw identity does not match lattice width.", call. = FALSE)
  }
  rows <- vector("list", length(lattice$origins))
  for (i in seq_along(lattice$origins)) {
    origin <- as.integer(lattice$origins[[i]])
    mu <- as.matrix(lattice$mu_by_origin[[i]])
    h_keep <- min(nrow(mu), length(basis$y_all) - origin)
    if (h_keep < 1L) next
    rows[[i]] <- data.frame(
      origin_local = origin,
      origin_source_index = analysis_source_index[[origin]],
      lead = seq_len(h_keep),
      target_local = origin + seq_len(h_keep),
      target_source_index = analysis_source_index[origin + seq_len(h_keep)],
      stringsAsFactors = FALSE
    )
  }
  grid <- do.call(rbind, rows)
  rownames(grid) <- NULL
  if (nrow(grid) != 1000L || length(unique(grid$target_source_index)) != 1000L) {
    stop("Forecast score grid is not the required 1,000-target contract.",
         call. = FALSE)
  }
  qmat <- matrix(NA_real_, nrow = nrow(grid), ncol = nd)
  offset <- 0L
  for (i in seq_along(lattice$origins)) {
    mu <- as.matrix(lattice$mu_by_origin[[i]])
    h_keep <- min(
      nrow(mu), length(basis$y_all) - lattice$origins[[i]]
    )
    if (h_keep < 1L) next
    idx <- offset + seq_len(h_keep)
    qmat[idx, ] <- imrs_v1_apply_scale(
      mu[seq_len(h_keep), , drop = FALSE], basis$lead_export_scale
    )
    offset <- offset + h_keep
  }
  if (any(!is.finite(qmat))) stop("Forecast quantile draws contain non-finite values.")
  source_rows <- match(grid$target_source_index, source_index)
  truth <- q_true[source_rows]
  obs <- y[source_rows]
  tau <- as.numeric(basis$root_spec$tau)
  err <- sweep(qmat, 1L, truth, "-")
  check_u <- sweep(qmat, 1L, obs, function(q, yy) yy - q)
  check <- check_u * (tau - (check_u < 0))
  point <- matrixStats::rowMedians(qmat)
  point_u <- obs - point
  point_metrics <- data.frame(
    forecast_mae = mean(abs(point - truth)),
    forecast_rmse = sqrt(mean((point - truth)^2)),
    forecast_check_loss = mean(point_u * (tau - (point_u < 0))),
    stringsAsFactors = FALSE
  )
  draw_metrics <- data.frame(
    draw_id = seq_len(nd),
    chain_id = as.integer(chain_id),
    within_chain_draw_id = as.integer(within_chain_draw_id),
    forecast_mae = colMeans(abs(err)),
    forecast_rmse = sqrt(colMeans(err^2)),
    forecast_check_loss = colMeans(check),
    stringsAsFactors = FALSE
  )
  summarize_group <- function(group) {
    ids <- split(seq_len(nrow(grid)), group)
    do.call(rbind, lapply(names(ids), function(label) {
      ii <- ids[[label]]
      data.frame(
        group = label,
        n_targets = length(ii),
        point_mae = mean(abs(point[ii] - truth[ii])),
        point_rmse = sqrt(mean((point[ii] - truth[ii])^2)),
        point_check_loss = mean(point_u[ii] * (tau - (point_u[ii] < 0))),
        draw_mae_mean = mean(colMeans(abs(err[ii, , drop = FALSE]))),
        draw_check_mean = mean(colMeans(check[ii, , drop = FALSE])),
        stringsAsFactors = FALSE
      )
    }))
  }
  list(
    grid = grid,
    point_path = data.frame(
      grid,
      q_point = point,
      q_true = truth,
      y = obs,
      stringsAsFactors = FALSE
    ),
    point_metrics = point_metrics,
    draw_metrics = draw_metrics,
    lead_profile = summarize_group(grid$lead),
    origin_profile = summarize_group(grid$origin_source_index)
  )
}

imrs_v1_interval_summary <- function(draw_metrics, estimator_id) {
  metrics <- c("forecast_mae", "forecast_check_loss")
  do.call(rbind, lapply(metrics, function(metric) {
    x <- as.numeric(draw_metrics[[metric]])
    q <- stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE,
                         type = 8, na.rm = TRUE)
    data.frame(
      metric = metric,
      posterior_mean = mean(x),
      posterior_sd = stats::sd(x),
      cri_lower = q[[1L]],
      posterior_median = q[[2L]],
      cri_upper = q[[3L]],
      interval_width = q[[3L]] - q[[1L]],
      n_draws = length(x),
      n_chains = length(unique(draw_metrics$chain_id)),
      estimator_id = estimator_id,
      stringsAsFactors = FALSE
    )
  }))
}

imrs_v1_native_artifact_parity <- function(draw_metrics, interval_summary,
                                           tolerance = imrs_v1_tolerance) {
  observed <- imrs_v1_interval_summary(
    draw_metrics, "native_posterior_predictive"
  )
  fields <- c(
    "posterior_mean", "posterior_sd", "cri_lower", "posterior_median",
    "cri_upper"
  )
  rows <- lapply(observed$metric, function(metric) {
    left <- observed[observed$metric == metric, , drop = FALSE]
    right <- interval_summary[interval_summary$metric == metric, , drop = FALSE]
    if (nrow(right) != 1L || any(!fields %in% names(right))) {
      return(data.frame(
        metric = metric, max_abs_difference = Inf, tolerance = tolerance,
        pass = FALSE, stringsAsFactors = FALSE
      ))
    }
    delta <- abs(
      as.numeric(unlist(left[1L, fields, drop = FALSE], use.names = FALSE)) -
        as.numeric(unlist(right[1L, fields, drop = FALSE], use.names = FALSE))
    )
    data.frame(
      metric = metric,
      max_abs_difference = max(delta),
      tolerance = tolerance,
      pass = all(is.finite(delta)) && max(delta) <= tolerance,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

imrs_v1_historical_compatibility_policy <- function(policy) {
  required <- c(
    "schema_version", "source_package_version", "fit_jobs",
    "metrics_per_fit", "familywise_alpha", "exact_summary_tolerance",
    "mean_relative_tolerance", "interval_endpoint_width_tolerance",
    "interval_overlap_min", "absolute_floor"
  )
  if (!is.list(policy) || any(!required %in% names(policy))) {
    stop("Historical-authority compatibility policy is incomplete.",
         call. = FALSE)
  }
  out <- list(
    schema_version = as.character(policy$schema_version)[[1L]],
    source_package_version = as.character(policy$source_package_version)[[1L]],
    fit_jobs = as.integer(policy$fit_jobs)[[1L]],
    metrics_per_fit = as.integer(policy$metrics_per_fit)[[1L]],
    familywise_alpha = as.numeric(policy$familywise_alpha)[[1L]],
    exact_summary_tolerance =
      as.numeric(policy$exact_summary_tolerance)[[1L]],
    mean_relative_tolerance =
      as.numeric(policy$mean_relative_tolerance)[[1L]],
    interval_endpoint_width_tolerance =
      as.numeric(policy$interval_endpoint_width_tolerance)[[1L]],
    interval_overlap_min = as.numeric(policy$interval_overlap_min)[[1L]],
    absolute_floor = as.numeric(policy$absolute_floor)[[1L]]
  )
  if (!identical(out$schema_version, imrs_v1_historical_compatibility_schema) ||
      out$fit_jobs < 1L || out$metrics_per_fit < 1L ||
      !is.finite(out$familywise_alpha) || out$familywise_alpha <= 0 ||
      out$familywise_alpha >= 1 ||
      any(!is.finite(unlist(out[c(
        "exact_summary_tolerance", "mean_relative_tolerance",
        "interval_endpoint_width_tolerance", "interval_overlap_min",
        "absolute_floor"
      )]))) || out$exact_summary_tolerance < 0 ||
      out$mean_relative_tolerance < 0 ||
      out$interval_endpoint_width_tolerance < 0 ||
      out$interval_overlap_min < 0 || out$interval_overlap_min > 1 ||
      out$absolute_floor <= 0) {
    stop("Historical-authority compatibility policy is invalid.",
         call. = FALSE)
  }
  out$familywise_comparisons <- out$fit_jobs * out$metrics_per_fit
  out$per_comparison_alpha <-
    out$familywise_alpha / out$familywise_comparisons
  out$mean_z_critical <- stats::qnorm(1 - out$per_comparison_alpha / 2)
  out$ks_constant <- sqrt(-0.5 * log(out$per_comparison_alpha / 2))
  out
}

imrs_v1_effective_size <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 3L || any(!is.finite(x))) return(NA_real_)
  if (stats::sd(x) <= sqrt(.Machine$double.eps)) return(as.numeric(length(x)))
  value <- tryCatch(
    as.numeric(coda::effectiveSize(coda::mcmc(x))),
    error = function(...) NA_real_
  )
  if (length(value) != 1L || !is.finite(value) || value <= 0) return(NA_real_)
  min(as.numeric(length(x)), value)
}

imrs_v1_two_sample_ks <- function(x, y) {
  x <- sort(as.numeric(x))
  y <- sort(as.numeric(y))
  if (!length(x) || !length(y) || any(!is.finite(c(x, y)))) return(NA_real_)
  grid <- sort(unique(c(x, y)))
  max(abs(findInterval(grid, x) / length(x) -
            findInterval(grid, y) / length(y)))
}

imrs_v1_native_authority_compatibility <- function(
    observed_draws, authority_draws, policy) {
  policy <- imrs_v1_historical_compatibility_policy(policy)
  metrics <- c("forecast_mae", "forecast_check_loss")
  summary_fields <- c(
    "posterior_mean", "posterior_sd", "cri_lower", "posterior_median",
    "cri_upper"
  )
  schema_ok <- all(metrics %in% names(observed_draws)) &&
    all(metrics %in% names(authority_draws))
  row_count_pass <- nrow(observed_draws) == nrow(authority_draws) &&
    nrow(observed_draws) > 1L

  rows <- lapply(metrics, function(metric) {
    x <- if (schema_ok) as.numeric(observed_draws[[metric]]) else numeric()
    y <- if (schema_ok) as.numeric(authority_draws[[metric]]) else numeric()
    finite_contract <- schema_ok && length(x) > 1L && length(y) > 1L &&
      all(is.finite(x)) && all(is.finite(y))
    if (!finite_contract) {
      return(data.frame(
        policy_schema_version = policy$schema_version,
        metric = metric, observed_draws = length(x), authority_draws = length(y),
        row_count_pass = row_count_pass, finite_contract = FALSE,
        exact_draw_max_abs_difference = Inf,
        exact_summary_max_abs_difference = Inf,
        exact_summary_tolerance = policy$exact_summary_tolerance,
        exact_pass = FALSE,
        observed_mean = NA_real_, authority_mean = NA_real_,
        mean_difference = NA_real_, relative_mean_difference = Inf,
        observed_ess = NA_real_, authority_ess = NA_real_,
        combined_mcse = NA_real_, familywise_z_critical = policy$mean_z_critical,
        mean_tolerance = NA_real_, mean_pass = FALSE,
        ks_distance = Inf, familywise_ks_threshold = NA_real_, ks_pass = FALSE,
        observed_q025 = NA_real_, authority_q025 = NA_real_,
        observed_q50 = NA_real_, authority_q50 = NA_real_,
        observed_q975 = NA_real_, authority_q975 = NA_real_,
        max_interval_endpoint_difference = Inf,
        authority_interval_width = NA_real_, endpoint_width_ratio = Inf,
        endpoint_width_tolerance = policy$interval_endpoint_width_tolerance,
        endpoint_pass = FALSE, interval_overlap_fraction = 0,
        interval_overlap_min = policy$interval_overlap_min,
        overlap_pass = FALSE, core_distributional_pass = FALSE,
        endpoint_review_required = FALSE, compatibility_pass = FALSE,
        gate_mode = "failed_contract", pass = FALSE,
        stringsAsFactors = FALSE
      ))
    }

    observed_summary <- imrs_v1_interval_summary(
      observed_draws, "reconstructed_native_posterior_predictive"
    )
    authority_summary <- imrs_v1_interval_summary(
      authority_draws, "frozen_native_posterior_predictive"
    )
    left <- observed_summary[observed_summary$metric == metric, , drop = FALSE]
    right <- authority_summary[authority_summary$metric == metric, , drop = FALSE]
    summary_delta <- abs(
      as.numeric(unlist(left[1L, summary_fields, drop = FALSE], use.names = FALSE)) -
        as.numeric(unlist(right[1L, summary_fields, drop = FALSE], use.names = FALSE))
    )
    draw_delta <- if (row_count_pass) abs(x - y) else Inf
    exact_draw_max <- max(draw_delta)
    exact_max <- max(summary_delta)
    exact_pass <- row_count_pass && all(is.finite(c(draw_delta, summary_delta))) &&
      exact_draw_max <= policy$exact_summary_tolerance &&
      exact_max <= policy$exact_summary_tolerance

    observed_mean <- mean(x)
    authority_mean <- mean(y)
    mean_difference <- abs(observed_mean - authority_mean)
    relative_mean_difference <- mean_difference /
      max(abs(authority_mean), policy$absolute_floor)
    observed_ess <- imrs_v1_effective_size(x)
    authority_ess <- imrs_v1_effective_size(y)
    combined_mcse <- if (all(is.finite(c(observed_ess, authority_ess)))) {
      sqrt(stats::var(x) / observed_ess + stats::var(y) / authority_ess)
    } else NA_real_
    mean_tolerance <- max(
      policy$absolute_floor,
      policy$mean_relative_tolerance * abs(authority_mean),
      policy$mean_z_critical * combined_mcse,
      na.rm = TRUE
    )
    mean_pass <- is.finite(mean_tolerance) && mean_difference <= mean_tolerance

    ks_distance <- imrs_v1_two_sample_ks(x, y)
    effective_n <- c(observed_ess, authority_ess)
    ks_threshold <- if (all(is.finite(effective_n)) && all(effective_n > 0)) {
      min(1, policy$ks_constant * sqrt(sum(effective_n) / prod(effective_n)))
    } else NA_real_
    ks_pass <- is.finite(ks_distance) && is.finite(ks_threshold) &&
      ks_distance <= ks_threshold

    observed_q <- stats::quantile(
      x, c(0.025, 0.5, 0.975), names = FALSE, type = 8
    )
    authority_q <- stats::quantile(
      y, c(0.025, 0.5, 0.975), names = FALSE, type = 8
    )
    endpoint_difference <- max(abs(observed_q[c(1L, 3L)] -
      authority_q[c(1L, 3L)]))
    authority_width <- authority_q[[3L]] - authority_q[[1L]]
    observed_width <- observed_q[[3L]] - observed_q[[1L]]
    endpoint_ratio <- endpoint_difference /
      max(authority_width, policy$absolute_floor)
    endpoint_pass <- is.finite(endpoint_ratio) &&
      endpoint_ratio <= policy$interval_endpoint_width_tolerance
    overlap_width <- max(
      0, min(observed_q[[3L]], authority_q[[3L]]) -
        max(observed_q[[1L]], authority_q[[1L]])
    )
    narrower_width <- min(observed_width, authority_width)
    overlap_fraction <- if (narrower_width <= policy$absolute_floor) {
      as.numeric(endpoint_difference <= policy$absolute_floor)
    } else min(1, overlap_width / narrower_width)
    overlap_pass <- is.finite(overlap_fraction) &&
      overlap_fraction >= policy$interval_overlap_min
    core_distributional_pass <- row_count_pass && finite_contract && mean_pass &&
      ks_pass && overlap_pass
    endpoint_review_required <- core_distributional_pass && !endpoint_pass
    compatibility_pass <- core_distributional_pass && endpoint_pass
    final_pass <- exact_pass || compatibility_pass
    data.frame(
      policy_schema_version = policy$schema_version,
      metric = metric, observed_draws = length(x), authority_draws = length(y),
      row_count_pass = row_count_pass, finite_contract = finite_contract,
      exact_draw_max_abs_difference = exact_draw_max,
      exact_summary_max_abs_difference = exact_max,
      exact_summary_tolerance = policy$exact_summary_tolerance,
      exact_pass = exact_pass,
      observed_mean = observed_mean, authority_mean = authority_mean,
      mean_difference = mean_difference,
      relative_mean_difference = relative_mean_difference,
      observed_ess = observed_ess, authority_ess = authority_ess,
      combined_mcse = combined_mcse,
      familywise_z_critical = policy$mean_z_critical,
      mean_tolerance = mean_tolerance, mean_pass = mean_pass,
      ks_distance = ks_distance, familywise_ks_threshold = ks_threshold,
      ks_pass = ks_pass,
      observed_q025 = observed_q[[1L]], authority_q025 = authority_q[[1L]],
      observed_q50 = observed_q[[2L]], authority_q50 = authority_q[[2L]],
      observed_q975 = observed_q[[3L]], authority_q975 = authority_q[[3L]],
      max_interval_endpoint_difference = endpoint_difference,
      authority_interval_width = authority_width,
      endpoint_width_ratio = endpoint_ratio,
      endpoint_width_tolerance = policy$interval_endpoint_width_tolerance,
      endpoint_pass = endpoint_pass,
      interval_overlap_fraction = overlap_fraction,
      interval_overlap_min = policy$interval_overlap_min,
      overlap_pass = overlap_pass,
      core_distributional_pass = core_distributional_pass,
      endpoint_review_required = endpoint_review_required,
      compatibility_pass = compatibility_pass,
      gate_mode = if (exact_pass) "exact" else if (compatibility_pass) {
        "distributional"
      } else "failed_compatibility",
      pass = final_pass,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

imrs_v1_complete_compatibility_fields <- function(compatibility) {
  legacy_required <- c(
    "pass", "exact_pass", "row_count_pass", "finite_contract",
    "mean_pass", "ks_pass", "endpoint_pass", "overlap_pass"
  )
  if (!is.data.frame(compatibility) || !nrow(compatibility) ||
      any(!legacy_required %in% names(compatibility))) {
    stop("Fit compatibility evidence is incomplete.", call. = FALSE)
  }
  if (!"core_distributional_pass" %in% names(compatibility)) {
    compatibility$core_distributional_pass <- with(
      compatibility,
      row_count_pass & finite_contract & mean_pass & ks_pass & overlap_pass
    )
  }
  if (!"endpoint_review_required" %in% names(compatibility)) {
    compatibility$endpoint_review_required <- with(
      compatibility, core_distributional_pass & !endpoint_pass
    )
  }
  compatibility
}

imrs_v1_fit_compatibility_decision <- function(compatibility, inference) {
  compatibility <- imrs_v1_complete_compatibility_fields(compatibility)
  inference <- tolower(as.character(inference)[[1L]])
  strict_pass <- all(compatibility$pass)
  endpoint_only_review <- !strict_pass && identical(inference, "mcmc") &&
    all(
      compatibility$pass |
        (compatibility$core_distributional_pass &
           compatibility$endpoint_review_required)
    ) && any(compatibility$endpoint_review_required)
  list(
    accepted = strict_pass || endpoint_only_review,
    strict_pass = strict_pass,
    source_pool_required = endpoint_only_review,
    endpoint_review_metric_count =
      sum(compatibility$endpoint_review_required),
    gate_mode = if (strict_pass) {
      "strict_chain_compatibility"
    } else if (endpoint_only_review) {
      "mcmc_endpoint_review_pending_source_pool"
    } else {
      "failed_chain_compatibility"
    }
  )
}

imrs_v1_retryable_fit_compatibility_failure <- function(
    status, compatibility, inference) {
  expected_error <- paste(
    "Reconstructed native forecast is incompatible with its frozen authority."
  )
  if (!is.list(status) ||
      !identical(as.character(status$status %||% ""), "FAILED") ||
      !identical(as.character(status$error_message %||% ""), expected_error)) {
    return(FALSE)
  }
  decision <- tryCatch(
    imrs_v1_fit_compatibility_decision(compatibility, inference),
    error = function(...) NULL
  )
  !is.null(decision) && isTRUE(decision$accepted) &&
    isTRUE(decision$source_pool_required)
}

# Retained as a narrow compatibility wrapper for downstream callers. New
# campaign code must pass the complete, multiplicity-controlled policy.
imrs_v1_native_authority_parity <- function(observed_draws, authority_draws,
                                            tolerance = imrs_v1_tolerance) {
  policy <- list(
    schema_version = imrs_v1_historical_compatibility_schema,
    source_package_version = "legacy_test_fixture",
    fit_jobs = 1L, metrics_per_fit = 2L, familywise_alpha = 0.01,
    exact_summary_tolerance = tolerance, mean_relative_tolerance = 0,
    interval_endpoint_width_tolerance = 0,
    interval_overlap_min = 1, absolute_floor = tolerance
  )
  out <- imrs_v1_native_authority_compatibility(
    observed_draws, authority_draws, policy
  )
  out$pass <- out$exact_pass
  out
}

imrs_v1_score_native_paths <- function(path_blocks, tau) {
  required <- c(
    "forecast_origin_source_index", "forecast_lead", "target_source_index",
    "local_origin_t", "local_target_t", "qhat", "q_true", "y"
  )
  normalize <- function(x) {
    if (any(!required %in% names(x))) {
      stop("Native forecast path artifact has an incomplete schema.", call. = FALSE)
    }
    x <- x[order(x$target_source_index), required, drop = FALSE]
    rownames(x) <- NULL
    x
  }
  paths <- lapply(path_blocks, normalize)
  reference <- paths[[1L]]
  keys <- required[seq_len(5L)]
  for (i in seq_along(paths)) {
    if (!identical(paths[[i]][keys], reference[keys]) ||
        max(abs(paths[[i]]$q_true - reference$q_true)) > 1e-10 ||
        max(abs(paths[[i]]$y - reference$y)) > 1e-10) {
      stop("Native forecast paths do not share one scoring grid.", call. = FALSE)
    }
  }
  if (nrow(reference) != 1000L ||
      length(unique(reference$target_source_index)) != 1000L) {
    stop("Native forecast path is not the required 1,000-target contract.",
         call. = FALSE)
  }
  q_point <- rowMeans(do.call(cbind, lapply(paths, `[[`, "qhat")))
  truth <- as.numeric(reference$q_true)
  obs <- as.numeric(reference$y)
  u <- obs - q_point
  point_metrics <- data.frame(
    forecast_mae = mean(abs(q_point - truth)),
    forecast_rmse = sqrt(mean((q_point - truth)^2)),
    forecast_check_loss = mean(u * (tau - (u < 0))),
    stringsAsFactors = FALSE
  )
  grid <- data.frame(
    origin_local = as.integer(reference$local_origin_t),
    origin_source_index = as.integer(reference$forecast_origin_source_index),
    lead = as.integer(reference$forecast_lead),
    target_local = as.integer(reference$local_target_t),
    target_source_index = as.integer(reference$target_source_index),
    stringsAsFactors = FALSE
  )
  summarize_group <- function(group) {
    ids <- split(seq_len(nrow(grid)), group)
    do.call(rbind, lapply(names(ids), function(label) {
      ii <- ids[[label]]
      data.frame(
        group = label, n_targets = length(ii),
        point_mae = mean(abs(q_point[ii] - truth[ii])),
        point_rmse = sqrt(mean((q_point[ii] - truth[ii])^2)),
        point_check_loss = mean(u[ii] * (tau - (u[ii] < 0))),
        draw_mae_mean = NA_real_, draw_check_mean = NA_real_,
        stringsAsFactors = FALSE
      )
    }))
  }
  list(
    point_path = data.frame(
      grid, q_point = q_point, q_true = truth, y = obs,
      stringsAsFactors = FALSE
    ),
    point_metrics = point_metrics,
    lead_profile = summarize_group(grid$lead),
    origin_profile = summarize_group(grid$origin_source_index)
  )
}

imrs_v1_status_path <- function(state_root, stage, job_id) {
  file.path(state_root, "status", stage, paste0(job_id, ".json"))
}

imrs_v1_status_success <- function(state_root, stage, job_id,
                                   request_sha256 = NULL) {
  path <- imrs_v1_status_path(state_root, stage, job_id)
  if (!file.exists(path)) return(FALSE)
  x <- tryCatch(imrs_v1_read_json(path), error = function(...) NULL)
  if (is.null(x) || !identical(as.character(x$status), "SUCCESS")) return(FALSE)
  is.null(request_sha256) || identical(
    as.character(x$request_sha256), as.character(request_sha256)
  )
}

imrs_v1_write_status <- function(state_root, stage, job_id, payload) {
  payload$schema_version <- imrs_v1_schema
  payload$stage <- stage
  payload$job_id <- job_id
  imrs_v1_atomic_write_json(
    payload, imrs_v1_status_path(state_root, stage, job_id)
  )
}

imrs_v1_split_ids <- function(x) {
  out <- strsplit(as.character(x %||% ""), ";", fixed = TRUE)[[1L]]
  out[nzchar(out)]
}

imrs_v1_label_ids <- function(prefix, ids) {
  ids <- as.character(ids)
  if (!length(ids)) return(character())
  paste0(as.character(prefix)[[1L]], ids)
}

imrs_v1_flatten_dispersion <- function(lattice) {
  rows <- list()
  k <- 0L
  for (i in seq_along(lattice$origins)) {
    state <- as.matrix(lattice$state_dispersion_by_origin[[i]])
    readout <- as.numeric(lattice$readout_dispersion_by_origin[[i]])
    if (!nrow(state)) next
    for (h in seq_len(nrow(state))) {
      for (d in seq_len(ncol(state))) {
        k <- k + 1L
        rows[[k]] <- data.frame(
          origin_local = as.integer(lattice$origins[[i]]),
          lead = h,
          component = paste0("state_layer_", d),
          rms_dispersion = state[h, d],
          stringsAsFactors = FALSE
        )
      }
      k <- k + 1L
      rows[[k]] <- data.frame(
        origin_local = as.integer(lattice$origins[[i]]),
        lead = h,
        component = "complete_readout",
        rms_dispersion = readout[[h]],
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

imrs_v1_metric_parity <- function(observed, expected, tolerance = imrs_v1_tolerance) {
  metrics <- intersect(
    c("forecast_mae", "forecast_check_loss"),
    intersect(names(observed), names(expected))
  )
  if (!length(metrics) || nrow(observed) != nrow(expected)) {
    return(data.frame(
      metric = "row_contract", max_abs_difference = Inf,
      tolerance = tolerance, pass = FALSE, stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(metrics, function(metric) {
    delta <- abs(as.numeric(observed[[metric]]) - as.numeric(expected[[metric]]))
    data.frame(
      metric = metric,
      max_abs_difference = max(delta, na.rm = TRUE),
      tolerance = tolerance,
      pass = all(is.finite(delta)) && max(delta, na.rm = TRUE) <= tolerance,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
