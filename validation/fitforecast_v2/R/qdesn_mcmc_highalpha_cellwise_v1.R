`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_hacv1_tau_key <- function(x) sprintf("%.8f", as.numeric(x))

qdesn_hacv1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_hacv1_alpha_levels <- function() {
  c(0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 0.99)
}

qdesn_hacv1_rho_levels <- function() {
  c(0.35, 0.45, 0.60, 0.75, 0.85, 0.93, 0.97, 0.99)
}

.qdesn_hacv1_scale_points <- function(x) {
  alpha_bounds <- range(qdesn_hacv1_alpha_levels())
  rho_bounds <- range(stats::qlogis(qdesn_hacv1_rho_levels()))
  data.frame(
    x = (as.numeric(x$alpha) - alpha_bounds[[1L]]) / diff(alpha_bounds),
    y = (stats::qlogis(as.numeric(x$rho)) - rho_bounds[[1L]]) / diff(rho_bounds)
  )
}

.qdesn_hacv1_maximin <- function(candidates, anchors, n_select) {
  candidates <- candidates[order(candidates$alpha, candidates$rho), , drop = FALSE]
  selected <- anchors
  out <- vector("list", n_select)
  for (i in seq_len(n_select)) {
    candidate_xy <- .qdesn_hacv1_scale_points(candidates)
    selected_xy <- .qdesn_hacv1_scale_points(selected)
    min_distance <- vapply(seq_len(nrow(candidate_xy)), function(j) {
      min((candidate_xy$x[[j]] - selected_xy$x)^2 +
        (candidate_xy$y[[j]] - selected_xy$y)^2)
    }, numeric(1L))
    pick <- which(min_distance == max(min_distance))[1L]
    out[[i]] <- candidates[pick, , drop = FALSE]
    selected <- rbind(selected, candidates[pick, , drop = FALSE])
    candidates <- candidates[-pick, , drop = FALSE]
  }
  do.call(rbind, out)
}

qdesn_hacv1_alpha_rho_design <- function() {
  forced <- data.frame(
    alpha = c(0.40, 0.40, 0.50, 0.60, 0.70, 0.70, 0.80,
      0.80, 0.90, 0.90, 0.95, 0.95, 0.99, 0.99),
    rho = c(0.35, 0.99, 0.60, 0.85, 0.45, 0.93, 0.75,
      0.85, 0.60, 0.97, 0.45, 0.85, 0.35, 0.99),
    stringsAsFactors = FALSE
  )
  full <- expand.grid(
    alpha = qdesn_hacv1_alpha_levels(),
    rho = qdesn_hacv1_rho_levels(),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  forced_key <- paste(forced$alpha, forced$rho, sep = "\r")
  full_key <- paste(full$alpha, full$rho, sep = "\r")
  candidates <- full[!full_key %in% forced_key, , drop = FALSE]
  fill <- .qdesn_hacv1_maximin(candidates, forced, 20L - nrow(forced))
  out <- rbind(forced, fill)
  out <- out[order(out$alpha, out$rho), , drop = FALSE]
  rownames(out) <- NULL
  out$point_index <- seq_len(nrow(out))
  out$point_id <- sprintf("ar%02d", out$point_index)
  out$design_role <- ifelse(
    out$alpha %in% c(0.70, 0.80, 0.95),
    "historical_bridge_on_fresh_corrected_protocol",
    "high_alpha_high_rho_novel_current_protocol"
  )
  if (nrow(out) != 20L || anyDuplicated(paste(out$alpha, out$rho, sep = "\r"))) {
    stop("High-alpha design must contain 20 unique alpha/rho points.", call. = FALSE)
  }
  out
}

qdesn_hacv1_wave1_cells <- function() {
  c(
    "al_normal_t0p05",
    "exal_gausmix_t0p25",
    "al_normal_t0p25",
    "exal_normal_t0p25"
  )
}

.qdesn_hacv1_metric_source_path <- function(row, metric) {
  field <- switch(
    metric,
    fit_qtrue_rmse = "fit_source_path",
    forecast_qtrue_mae_H1000 = "forecast_mae_source_path",
    forecast_check_loss_H1000 = "forecast_check_source_path",
    stop(sprintf("Unknown metric: %s", metric), call. = FALSE)
  )
  as.character(row[[field]][[1L]])
}

.qdesn_hacv1_fit_request <- function(metric_path) {
  request_path <- file.path(dirname(metric_path), "fit_request.json")
  if (basename(dirname(metric_path)) == "tables") {
    request_path <- file.path(dirname(dirname(metric_path)), "fit_request.json")
  }
  if (!file.exists(request_path)) {
    stop(sprintf("Missing authoritative fit request: %s", request_path), call. = FALSE)
  }
  list(path = normalizePath(request_path, winslash = "/", mustWork = TRUE),
    request = jsonlite::read_json(request_path, simplifyVector = FALSE))
}

.qdesn_hacv1_scalar <- function(x, default = NA_real_) {
  value <- unlist(x, recursive = TRUE, use.names = FALSE)
  if (!length(value)) return(default)
  value[[1L]]
}

qdesn_hacv1_authority <- function(interface_path) {
  interface_path <- normalizePath(interface_path, winslash = "/", mustWork = TRUE)
  interface <- utils::read.csv(interface_path, check.names = FALSE, stringsAsFactors = FALSE)
  required <- c(
    "inference", "model_variant", "family", "tau", "fit_qtrue_rmse",
    "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
    "fit_source_candidate_id", "fit_source_path", "forecast_mae_source_candidate_id",
    "forecast_mae_source_path", "forecast_check_source_candidate_id",
    "forecast_check_source_path", "source_registry_hash_value", "preprocessing_scope"
  )
  missing <- setdiff(required, names(interface))
  if (length(missing)) {
    stop(sprintf("Article interface is missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  q_rows <- interface[
    interface$inference == "mcmc" &
      interface$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns") &
      interface$tau %in% c(0.05, 0.25),
    , drop = FALSE
  ]
  q_rows$likelihood_target <- ifelse(q_rows$model_variant == "qdesn_al_rhs_ns", "al", "exal")
  q_rows$target_cell_id <- paste(
    q_rows$likelihood_target,
    q_rows$family,
    sub("[.]", "p", sprintf("t%.2f", q_rows$tau)),
    sep = "_"
  )
  structured <- interface[
    interface$inference == "mcmc" & interface$model_variant %in% c("dqlm", "exdqlm"),
    , drop = FALSE
  ]
  metric_names <- c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
  )
  comparator <- do.call(rbind, lapply(seq_len(nrow(q_rows)), function(i) {
    row <- q_rows[i, , drop = FALSE]
    cmp <- structured[structured$family == row$family & structured$tau == row$tau, , drop = FALSE]
    if (!nrow(cmp)) stop(sprintf("No structured comparator for %s.", row$target_cell_id), call. = FALSE)
    data.frame(
      target_cell_id = row$target_cell_id,
      best_structured_fit_qtrue_rmse = min(cmp$fit_qtrue_rmse, na.rm = TRUE),
      best_structured_forecast_qtrue_mae_H1000 = min(cmp$forecast_qtrue_mae_H1000, na.rm = TRUE),
      best_structured_forecast_check_loss_H1000 = min(cmp$forecast_check_loss_H1000, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
  q_rows <- merge(q_rows, comparator, by = "target_cell_id", all.x = TRUE, sort = FALSE)
  q_rows$fit_ratio <- q_rows$fit_qtrue_rmse / q_rows$best_structured_fit_qtrue_rmse
  q_rows$forecast_mae_ratio <- q_rows$forecast_qtrue_mae_H1000 /
    q_rows$best_structured_forecast_qtrue_mae_H1000
  q_rows$forecast_check_ratio <- q_rows$forecast_check_loss_H1000 /
    q_rows$best_structured_forecast_check_loss_H1000
  q_rows$target_metrics <- vapply(seq_len(nrow(q_rows)), function(i) {
    ratios <- c(
      fit_qtrue_rmse = q_rows$fit_ratio[[i]],
      forecast_qtrue_mae_H1000 = q_rows$forecast_mae_ratio[[i]],
      forecast_check_loss_H1000 = q_rows$forecast_check_ratio[[i]]
    )
    paste(names(ratios)[is.finite(ratios) & ratios > 1.02], collapse = ";")
  }, character(1L))
  q_rows <- q_rows[nzchar(q_rows$target_metrics), , drop = FALSE]
  q_rows$launch_wave <- ifelse(q_rows$target_cell_id %in% qdesn_hacv1_wave1_cells(), "wave1", "wave2_universe")
  q_rows$priority_score <- pmax(q_rows$fit_ratio, q_rows$forecast_mae_ratio, q_rows$forecast_check_ratio, na.rm = TRUE)
  q_rows <- q_rows[order(q_rows$launch_wave, -q_rows$priority_score, q_rows$target_cell_id), , drop = FALSE]
  rownames(q_rows) <- NULL
  if (nrow(q_rows) != 11L || sum(q_rows$launch_wave == "wave1") != 4L) {
    stop(sprintf("Expected 11 unresolved cells with four in Wave 1; found %d and %d.",
      nrow(q_rows), sum(q_rows$launch_wave == "wave1")), call. = FALSE)
  }
  if (length(unique(q_rows$source_registry_hash_value)) != 1L ||
      !identical(unique(q_rows$preprocessing_scope), "train_only")) {
    stop("Authority is not a single corrected train-only source-registry contract.", call. = FALSE)
  }

  profile_rows <- lapply(seq_len(nrow(q_rows)), function(i) {
    row <- q_rows[i, , drop = FALSE]
    fit <- .qdesn_hacv1_fit_request(as.character(row$fit_source_path[[1L]]))
    request <- fit$request
    desn <- request$config$desn
    root <- request$root_spec
    n_tilde <- unlist(desn$n_tilde, recursive = TRUE, use.names = FALSE)
    data.frame(
      target_cell_id = row$target_cell_id,
      launch_wave = row$launch_wave,
      likelihood_target = row$likelihood_target,
      family = row$family,
      tau = as.numeric(row$tau),
      target_metrics = row$target_metrics,
      priority_score = row$priority_score,
      current_fit_qtrue_rmse = row$fit_qtrue_rmse,
      current_forecast_qtrue_mae_H1000 = row$forecast_qtrue_mae_H1000,
      current_forecast_check_loss_H1000 = row$forecast_check_loss_H1000,
      fit_ratio = row$fit_ratio,
      forecast_mae_ratio = row$forecast_mae_ratio,
      forecast_check_ratio = row$forecast_check_ratio,
      parent_candidate_id = row$fit_source_candidate_id,
      parent_profile_id = as.character(root$screening_profile_id),
      parent_fit_request_path = fit$path,
      parent_fit_request_sha256 = unname(tools::sha256sum(fit$path)),
      D = as.integer(.qdesn_hacv1_scalar(desn$D)),
      n_each = as.integer(.qdesn_hacv1_scalar(desn$n)),
      n_tilde_each = if (length(n_tilde)) as.integer(n_tilde[[1L]]) else NA_integer_,
      m = as.integer(.qdesn_hacv1_scalar(desn$m)),
      alpha = as.numeric(.qdesn_hacv1_scalar(desn$alpha)),
      rho = as.numeric(.qdesn_hacv1_scalar(desn$rho)),
      pi_w = as.numeric(.qdesn_hacv1_scalar(desn$pi_w)),
      pi_in = as.numeric(.qdesn_hacv1_scalar(desn$pi_in)),
      washout = as.integer(.qdesn_hacv1_scalar(desn$washout)),
      add_bias = as.logical(.qdesn_hacv1_scalar(desn$add_bias, TRUE)),
      seed = as.integer(.qdesn_hacv1_scalar(desn$seed)),
      readout_y_lags = as.integer(.qdesn_hacv1_scalar(root$readout_y_lags, request$config$lags$m_y)),
      reservoir_lags = as.integer(.qdesn_hacv1_scalar(root$reservoir_lags, 0L)),
      rhs_tau0 = as.numeric(.qdesn_hacv1_scalar(root$rhs_tau0)),
      dimension_p_estimate = as.integer(.qdesn_hacv1_scalar(root$dimension_p_estimate)),
      p_over_n_tt500 = as.numeric(.qdesn_hacv1_scalar(root$p_over_n_tt500)),
      stringsAsFactors = FALSE
    )
  })
  profiles <- do.call(rbind, profile_rows)
  rownames(profiles) <- NULL

  metric_sources <- do.call(rbind, lapply(seq_len(nrow(q_rows)), function(i) {
    row <- q_rows[i, , drop = FALSE]
    do.call(rbind, lapply(metric_names, function(metric) {
      source_path <- .qdesn_hacv1_metric_source_path(row, metric)
      fit <- .qdesn_hacv1_fit_request(source_path)
      candidate_field <- switch(
        metric,
        fit_qtrue_rmse = "fit_source_candidate_id",
        forecast_qtrue_mae_H1000 = "forecast_mae_source_candidate_id",
        forecast_check_loss_H1000 = "forecast_check_source_candidate_id"
      )
      data.frame(
        target_cell_id = row$target_cell_id,
        metric = metric,
        metric_value = as.numeric(row[[metric]][[1L]]),
        source_candidate_id = as.character(row[[candidate_field]][[1L]]),
        source_metric_path = normalizePath(source_path, winslash = "/", mustWork = TRUE),
        source_fit_request_path = fit$path,
        source_fit_request_sha256 = unname(tools::sha256sum(fit$path)),
        source_profile_id = as.character(fit$request$root_spec$screening_profile_id),
        stringsAsFactors = FALSE
      )
    }))
  }))
  list(interface = interface, targets = q_rows, parents = profiles, metric_sources = metric_sources)
}

.qdesn_hacv1_topology_counts <- function(parent, seed, pi_w = NULL, pi_in = NULL) {
  reservoir <- .qdesn_arv1_build_d1_reservoir(
    n = as.integer(parent$n_each[[1L]]),
    m = as.integer(parent$m[[1L]]),
    alpha = as.numeric(parent$alpha[[1L]]),
    rho = as.numeric(parent$rho[[1L]]),
    pi_w = as.numeric(pi_w %||% parent$pi_w[[1L]]),
    pi_in = as.numeric(pi_in %||% parent$pi_in[[1L]]),
    seed = as.integer(seed)
  )
  c(recurrent_nnz = sum(reservoir$W != 0), input_nnz = sum(reservoir$Win != 0))
}

.qdesn_hacv1_second_seed <- function(parent, mode) {
  start <- as.integer(parent$seed[[1L]]) + 900001L
  repaired_pi_w <- min(1, 4 / as.integer(parent$n_each[[1L]]))
  repaired_pi_in <- max(as.numeric(parent$pi_in[[1L]]), min(1, 2 / (as.integer(parent$m[[1L]]) + 1L)))
  for (offset in 0:9999) {
    seed <- start + offset
    counts <- if (mode == "repair_alpha_rho") {
      .qdesn_hacv1_topology_counts(parent, seed, repaired_pi_w, repaired_pi_in)
    } else {
      .qdesn_hacv1_topology_counts(parent, seed)
    }
    valid <- switch(
      mode,
      repair_alpha_rho = all(counts > 0),
      exact_alpha_rho = all(counts > 0),
      exact_alpha_only = counts[["input_nnz"]] > 0,
      FALSE
    )
    if (valid) return(seed)
  }
  stop(sprintf("Could not find a valid paired reservoir seed for %s.", parent$target_cell_id), call. = FALSE)
}

qdesn_hacv1_build_plan <- function(interface_path) {
  authority <- qdesn_hacv1_authority(interface_path)
  parents <- authority$parents
  alpha_rho <- qdesn_hacv1_alpha_rho_design()
  alpha_only <- data.frame(
    alpha = qdesn_hacv1_alpha_levels(),
    rho = NA_real_,
    point_index = seq_along(qdesn_hacv1_alpha_levels()),
    point_id = sprintf("a%02d", seq_along(qdesn_hacv1_alpha_levels())),
    design_role = ifelse(
      qdesn_hacv1_alpha_levels() %in% c(0.70, 0.80, 0.95),
      "historical_bridge_on_fresh_corrected_protocol",
      "high_alpha_novel_current_protocol"
    ),
    stringsAsFactors = FALSE
  )
  profiles <- list()
  assignments <- list()
  topology_classes <- list()
  counter <- 0L

  for (target_i in seq_len(nrow(parents))) {
    parent <- parents[target_i, , drop = FALSE]
    if (as.integer(parent$D[[1L]]) != 1L) {
      stop("High-alpha cellwise v1 currently supports exact authoritative D=1 parents only.", call. = FALSE)
    }
    parent_counts <- .qdesn_hacv1_topology_counts(parent, parent$seed[[1L]])
    mode <- if (parent_counts[["input_nnz"]] == 0L) {
      "repair_alpha_rho"
    } else if (parent_counts[["recurrent_nnz"]] == 0L) {
      "exact_alpha_only"
    } else {
      "exact_alpha_rho"
    }
    repaired_pi_w <- min(1, 4 / as.integer(parent$n_each[[1L]]))
    repaired_pi_in <- max(as.numeric(parent$pi_in[[1L]]), min(1, 2 / (as.integer(parent$m[[1L]]) + 1L)))
    seeds <- c(as.integer(parent$seed[[1L]]), .qdesn_hacv1_second_seed(parent, mode))
    topology_classes[[target_i]] <- data.frame(
      target_cell_id = parent$target_cell_id,
      launch_wave = parent$launch_wave,
      topology_search_mode = mode,
      parent_recurrent_nnz = parent_counts[["recurrent_nnz"]],
      parent_input_nnz = parent_counts[["input_nnz"]],
      parent_pi_w = parent$pi_w,
      parent_pi_in = parent$pi_in,
      repaired_pi_w = repaired_pi_w,
      repaired_pi_in = repaired_pi_in,
      reservoir_seed_1 = seeds[[1L]],
      reservoir_seed_2 = seeds[[2L]],
      stringsAsFactors = FALSE
    )

    design <- if (mode == "exact_alpha_only") alpha_only else alpha_rho
    controls <- data.frame(
      point_id = "parent",
      point_index = 0L,
      alpha = parent$alpha,
      rho = parent$rho,
      design_role = "exact_authoritative_parent_control",
      arm_code = "parent_exact",
      topology_mode = "parent",
      stringsAsFactors = FALSE
    )
    if (mode == "repair_alpha_rho") {
      controls <- rbind(controls, data.frame(
        point_id = "connectivity",
        point_index = -1L,
        alpha = parent$alpha,
        rho = parent$rho,
        design_role = "connectivity_only_control",
        arm_code = "connectivity_control",
        topology_mode = "repair_w_win",
        stringsAsFactors = FALSE
      ))
    }
    design$arm_code <- paste0("high_", design$point_id)
    design$topology_mode <- if (mode == "repair_alpha_rho") "repair_w_win" else "parent"
    if (mode == "exact_alpha_only") design$rho <- parent$rho[[1L]]
    arms <- rbind(controls, design[, names(controls), drop = FALSE])

    for (arm_i in seq_len(nrow(arms))) {
      arm <- arms[arm_i, , drop = FALSE]
      for (reservoir_replicate in seq_along(seeds)) {
        counter <- counter + 1L
        use_repair <- arm$topology_mode[[1L]] == "repair_w_win"
        pi_w <- if (use_repair) repaired_pi_w else as.numeric(parent$pi_w[[1L]])
        pi_in <- if (use_repair) repaired_pi_in else as.numeric(parent$pi_in[[1L]])
        candidate_id <- sprintf(
          "hacv1_%s_%s",
          qdesn_hacv1_safe_token(parent$target_cell_id[[1L]]),
          qdesn_hacv1_safe_token(arm$arm_code[[1L]])
        )
        profile_id <- sprintf("%s_r%02d", candidate_id, reservoir_replicate)
        profiles[[counter]] <- data.frame(
          screening_profile_id = profile_id,
          screening_stage = "mcmc_highalpha_cellwise_v1",
          screening_wave = "highalpha_cellwise_2026_08_06",
          profile_role = arm$design_role[[1L]],
          enabled = TRUE,
          D = as.integer(parent$D[[1L]]),
          n_each = as.integer(parent$n_each[[1L]]),
          n_tilde_each = as.integer(parent$n_tilde_each[[1L]]),
          m = as.integer(parent$m[[1L]]),
          alpha = as.numeric(arm$alpha[[1L]]),
          rho = as.numeric(arm$rho[[1L]]),
          pi_w = pi_w,
          pi_in = pi_in,
          washout = as.integer(parent$washout[[1L]]),
          add_bias = as.logical(parent$add_bias[[1L]]),
          seed = as.integer(seeds[[reservoir_replicate]]),
          readout_y_lags = as.integer(parent$readout_y_lags[[1L]]),
          reservoir_lags = as.integer(parent$reservoir_lags[[1L]]),
          rhs_tau0 = as.numeric(parent$rhs_tau0[[1L]]),
          dimension_p_estimate = as.integer(parent$dimension_p_estimate[[1L]]),
          p_over_n_tt500 = as.numeric(parent$p_over_n_tt500[[1L]]),
          x_feature_count = 5L,
          target_cells = paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]), parent$likelihood_target[[1L]], sep = ":"),
          target_cell_id = parent$target_cell_id[[1L]],
          launch_wave = parent$launch_wave[[1L]],
          likelihood_target = parent$likelihood_target[[1L]],
          target_family = parent$family[[1L]],
          target_tau = as.numeric(parent$tau[[1L]]),
          target_metrics = parent$target_metrics[[1L]],
          parent_profile_id = parent$parent_profile_id[[1L]],
          parent_candidate_id = parent$parent_candidate_id[[1L]],
          parent_fit_request_path = parent$parent_fit_request_path[[1L]],
          candidate_id = candidate_id,
          arm_code = arm$arm_code[[1L]],
          design_role = arm$design_role[[1L]],
          topology_search_mode = mode,
          topology_mode = arm$topology_mode[[1L]],
          point_index = as.integer(arm$point_index[[1L]]),
          reservoir_replicate = as.integer(reservoir_replicate),
          paired_reservoir_seed = as.integer(seeds[[reservoir_replicate]]),
          parent_pi_w = as.numeric(parent$pi_w[[1L]]),
          parent_pi_in = as.numeric(parent$pi_in[[1L]]),
          repaired_pi_w = repaired_pi_w,
          repaired_pi_in = repaired_pi_in,
          candidate_source = "exact_current_authority_high_alpha_topology_aware",
          selection_reason = "Hold the case-specific authoritative D/n/m/tau0/readout fixed; vary alpha/rho only when realized topology makes the axis active.",
          stringsAsFactors = FALSE
        )
        assignments[[counter]] <- data.frame(
          assignment_id = sprintf("hacv1_%04d", counter),
          family = parent$family[[1L]],
          tau = as.numeric(parent$tau[[1L]]),
          likelihood_target = parent$likelihood_target[[1L]],
          target_cell_id = parent$target_cell_id[[1L]],
          target_metrics = parent$target_metrics[[1L]],
          launch_wave = parent$launch_wave[[1L]],
          screening_profile_id = profile_id,
          parent_profile_id = parent$parent_profile_id[[1L]],
          candidate_id = candidate_id,
          arm_code = arm$arm_code[[1L]],
          topology_search_mode = mode,
          topology_mode = arm$topology_mode[[1L]],
          reservoir_replicate = as.integer(reservoir_replicate),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  profiles <- do.call(rbind, profiles)
  assignments <- do.call(rbind, assignments)
  topology_classes <- do.call(rbind, topology_classes)
  rownames(profiles) <- rownames(assignments) <- rownames(topology_classes) <- NULL
  wave1_profiles <- profiles[profiles$launch_wave == "wave1", , drop = FALSE]
  if (nrow(wave1_profiles) != 124L) {
    stop(sprintf("Wave 1 must contain 124 profiles; found %d.", nrow(wave1_profiles)), call. = FALSE)
  }
  list(
    authority = authority,
    parents = parents,
    metric_sources = authority$metric_sources,
    topology_classes = topology_classes,
    alpha_rho_design = alpha_rho,
    alpha_only_design = alpha_only,
    profiles = profiles,
    assignments = assignments
  )
}

qdesn_hacv1_topology_audit <- function(profiles) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("Package 'digest' is required.", call. = FALSE)
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    reservoir <- .qdesn_arv1_build_d1_reservoir(
      n = as.integer(p$n_each[[1L]]),
      m = as.integer(p$m[[1L]]),
      alpha = as.numeric(p$alpha[[1L]]),
      rho = as.numeric(p$rho[[1L]]),
      pi_w = as.numeric(p$pi_w[[1L]]),
      pi_in = as.numeric(p$pi_in[[1L]]),
      seed = as.integer(p$seed[[1L]])
    )
    W <- reservoir$W
    Win <- reservoir$Win
    recurrent_nnz <- sum(W != 0)
    input_nnz <- sum(Win != 0)
    data.frame(
      screening_profile_id = p$screening_profile_id[[1L]],
      candidate_id = p$candidate_id[[1L]],
      target_cell_id = p$target_cell_id[[1L]],
      launch_wave = p$launch_wave[[1L]],
      arm_code = p$arm_code[[1L]],
      topology_search_mode = p$topology_search_mode[[1L]],
      topology_mode = p$topology_mode[[1L]],
      reservoir_replicate = as.integer(p$reservoir_replicate[[1L]]),
      seed = as.integer(p$seed[[1L]]),
      alpha = as.numeric(p$alpha[[1L]]),
      rho = as.numeric(p$rho[[1L]]),
      pi_w = as.numeric(p$pi_w[[1L]]),
      pi_in = as.numeric(p$pi_in[[1L]]),
      recurrent_nnz = recurrent_nnz,
      input_nnz = input_nnz,
      recurrent_mask_sha256 = digest::digest(W != 0, algo = "sha256"),
      input_mask_sha256 = digest::digest(Win != 0, algo = "sha256"),
      alpha_axis_active = input_nnz > 0,
      rho_axis_active = input_nnz > 0 && recurrent_nnz > 0,
      candidate_topology_valid = if (p$arm_code[[1L]] == "parent_exact") TRUE else if (
        p$topology_search_mode[[1L]] == "exact_alpha_only"
      ) input_nnz > 0 else input_nnz > 0 && recurrent_nnz > 0,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  searched <- out[!out$arm_code %in% c("parent_exact", "connectivity_control"), , drop = FALSE]
  if (any(!searched$candidate_topology_valid)) {
    stop("At least one searched profile is inert on its declared search axis.", call. = FALSE)
  }
  mask_key <- paste(searched$target_cell_id, searched$reservoir_replicate, searched$topology_mode, sep = "\r")
  invariant <- vapply(split(seq_len(nrow(searched)), mask_key), function(idx) {
    length(unique(searched$recurrent_mask_sha256[idx])) == 1L &&
      length(unique(searched$input_mask_sha256[idx])) == 1L
  }, logical(1L))
  if (!all(invariant)) stop("Alpha/rho points changed a fixed topology mask.", call. = FALSE)
  out
}
