`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_arv2_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_arv2_alpha_levels <- function(parent_alpha) {
  levels <- c(0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03, 0.10, 0.30, 0.70, 0.95)
  parent_alpha <- as.numeric(parent_alpha)
  duplicate_parent <- which(abs(log(levels / parent_alpha)) < 1e-12)
  if (length(duplicate_parent)) {
    upper <- levels[levels > parent_alpha][1L]
    lower <- tail(levels[levels < parent_alpha], 1L)
    replacement <- if (is.finite(upper)) sqrt(parent_alpha * upper) else sqrt(lower * parent_alpha)
    levels[duplicate_parent[[1L]]] <- replacement
  }
  sort(unique(levels))
}

qdesn_arv2_alpha_rho_levels <- function(safeguard = FALSE) {
  points <- data.frame(
    alpha = c(
      0.0001, 0.0001, 0.001, 0.003, 0.01, 0.01,
      0.03, 0.03, 0.10, 0.10, 0.25, 0.80
    ),
    rho = c(
      0.05, 0.997, 0.30, 0.97, 0.15, 0.85,
      0.05, 0.93, 0.15, 0.97, 0.50, 0.85
    ),
    stringsAsFactors = FALSE
  )
  if (isTRUE(safeguard)) points[c(1L, 4L, 7L, 8L, 11L, 12L), , drop = FALSE] else points
}

qdesn_arv2_search_map <- function() {
  data.frame(
    target_cell_id = c(
      "al_gausmix_t0p05", "al_gausmix_t0p05",
      "al_normal_t0p05", "al_normal_t0p05",
      "exal_laplace_t0p05",
      "exal_gausmix_t0p25", "exal_gausmix_t0p25",
      "exal_laplace_t0p25", "exal_laplace_t0p25"
    ),
    search_id = c(
      "input_alpha", "full_alpha_rho",
      "input_alpha", "full_alpha_rho_safeguard",
      "parent_alpha",
      "input_alpha", "full_alpha_rho",
      "parent_alpha", "input_alpha"
    ),
    topology_mode = c(
      "repair_win", "repair_w_win",
      "repair_win", "repair_w_win",
      "parent",
      "repair_win", "repair_w_win",
      "parent", "repair_win"
    ),
    search_dimension = c(
      "alpha_only", "alpha_rho",
      "alpha_only", "alpha_rho",
      "alpha_only",
      "alpha_only", "alpha_rho",
      "alpha_only", "alpha_only"
    ),
    search_budget = c(10L, 12L, 10L, 6L, 10L, 10L, 12L, 10L, 10L),
    priority = c(
      "primary", "secondary",
      "primary", "safeguard",
      "primary",
      "secondary", "primary",
      "control", "primary"
    ),
    rationale = c(
      "Input repair helped and the recurrent radius is inert on the sparse parent draw.",
      "Full topology was mildly worse at the parent point but remains a bounded interaction check.",
      "Input repair improved fit; alpha is the active dynamic control when W is zero.",
      "Full topology was weak, so only a six-point safeguard surface is justified.",
      "The parent is input-active but rho is not identifiable under both reservoir seeds; tune alpha only.",
      "Input repair helped, while W remains inactive and makes rho redundant.",
      "Full topology gave the strongest median signal and warrants alpha/rho tuning.",
      "The parent is the stable control; only alpha is active because W is zero.",
      "Input repair was nearly neutral and receives an alpha-only check."
    ),
    stringsAsFactors = FALSE
  )
}

.qdesn_arv2_topology_values <- function(parent, topology_mode) {
  n_each <- as.integer(parent$n_each[[1L]])
  m <- as.integer(parent$m[[1L]])
  repaired_pi_w <- min(1, 4 / n_each)
  repaired_pi_in <- max(as.numeric(parent$pi_in[[1L]]), min(1, 2 / (m + 1L)))
  list(
    pi_w = if (topology_mode %in% c("repair_w", "repair_w_win")) repaired_pi_w else as.numeric(parent$pi_w[[1L]]),
    pi_in = if (topology_mode %in% c("repair_win", "repair_w_win")) repaired_pi_in else as.numeric(parent$pi_in[[1L]]),
    repaired_pi_w = repaired_pi_w,
    repaired_pi_in = repaired_pi_in
  )
}

qdesn_arv2_build_plan <- function(repo_root = ".") {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  if (!exists("qdesn_arv1_resolve_parent_profiles", mode = "function")) {
    source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"))
  }
  parents <- qdesn_arv1_resolve_parent_profiles(repo_root)
  search_map <- qdesn_arv2_search_map()
  profiles <- list()
  assignments <- list()
  designs <- list()
  profile_counter <- 0L
  design_counter <- 0L

  for (search_i in seq_len(nrow(search_map))) {
    search <- search_map[search_i, , drop = FALSE]
    parent <- parents[parents$target_cell_id == search$target_cell_id[[1L]], , drop = FALSE]
    if (nrow(parent) != 1L) stop(sprintf("Could not resolve target %s.", search$target_cell_id[[1L]]), call. = FALSE)
    topology <- .qdesn_arv2_topology_values(parent, search$topology_mode[[1L]])
    points <- if (search$search_dimension[[1L]] == "alpha_only") {
      data.frame(
        alpha = qdesn_arv2_alpha_levels(parent$alpha[[1L]]),
        rho = rep(as.numeric(parent$rho[[1L]]), search$search_budget[[1L]]),
        stringsAsFactors = FALSE
      )
    } else {
      qdesn_arv2_alpha_rho_levels(search$priority[[1L]] == "safeguard")
    }
    if (nrow(points) != search$search_budget[[1L]]) {
      stop(sprintf("Search %s has %d points; expected %d.", search$search_id[[1L]], nrow(points), search$search_budget[[1L]]), call. = FALSE)
    }

    for (point_i in seq_len(nrow(points))) {
      design_counter <- design_counter + 1L
      candidate_id <- sprintf(
        "arv2_%s_%s_p%02d",
        qdesn_arv2_safe_token(search$target_cell_id[[1L]]),
        qdesn_arv2_safe_token(search$search_id[[1L]]),
        point_i
      )
      designs[[design_counter]] <- data.frame(
        candidate_id = candidate_id,
        target_cell_id = search$target_cell_id[[1L]],
        search_id = search$search_id[[1L]],
        topology_mode = search$topology_mode[[1L]],
        search_dimension = search$search_dimension[[1L]],
        search_priority = search$priority[[1L]],
        point_index = as.integer(point_i),
        alpha = as.numeric(points$alpha[[point_i]]),
        rho = as.numeric(points$rho[[point_i]]),
        pi_w = topology$pi_w,
        pi_in = topology$pi_in,
        rationale = search$rationale[[1L]],
        stringsAsFactors = FALSE
      )
      seeds <- c(as.integer(parent$seed[[1L]]), as.integer(parent$seed[[1L]]) + 900001L)
      for (reservoir_replicate in seq_along(seeds)) {
        profile_counter <- profile_counter + 1L
        profile_id <- sprintf("%s_r%02d", candidate_id, reservoir_replicate)
        launch_phase <- if (reservoir_replicate == 1L) "coarse" else "refinement_universe"
        profiles[[profile_counter]] <- data.frame(
          screening_profile_id = profile_id,
          screening_stage = "mcmc_alpha_rho_cellwise_v2",
          screening_wave = "alpha_rho_cellwise_v2_2026_08_01",
          profile_role = search$search_id[[1L]],
          enabled = TRUE,
          D = as.integer(parent$D[[1L]]),
          n_each = as.integer(parent$n_each[[1L]]),
          n_tilde_each = as.integer(parent$n_tilde_each[[1L]]),
          m = as.integer(parent$m[[1L]]),
          alpha = as.numeric(points$alpha[[point_i]]),
          rho = as.numeric(points$rho[[point_i]]),
          pi_w = topology$pi_w,
          pi_in = topology$pi_in,
          washout = as.integer(parent$washout[[1L]]),
          add_bias = as.logical(parent$add_bias[[1L]]),
          seed = seeds[[reservoir_replicate]],
          readout_y_lags = as.integer(parent$readout_y_lags[[1L]]),
          reservoir_lags = as.integer(parent$reservoir_lags[[1L]]),
          rhs_tau0 = as.numeric(parent$rhs_tau0[[1L]]),
          dimension_p_estimate = as.integer(parent$dimension_p_estimate[[1L]]),
          p_over_n_tt500 = as.numeric(parent$p_over_n_tt500[[1L]]),
          x_feature_count = 5L,
          target_cells = paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]), parent$likelihood_target[[1L]], sep = ":"),
          target_cell_id = parent$target_cell_id[[1L]],
          target_role = parent$target_role[[1L]],
          likelihood_target = parent$likelihood_target[[1L]],
          target_family = parent$family[[1L]],
          target_tau = as.numeric(parent$tau[[1L]]),
          parent_profile_id = parent$parent_profile_id[[1L]],
          candidate_id = candidate_id,
          search_id = search$search_id[[1L]],
          search_dimension = search$search_dimension[[1L]],
          search_priority = search$priority[[1L]],
          point_index = as.integer(point_i),
          topology_mode = search$topology_mode[[1L]],
          reservoir_replicate = as.integer(reservoir_replicate),
          launch_phase = launch_phase,
          parent_alpha = as.numeric(parent$alpha[[1L]]),
          parent_rho = as.numeric(parent$rho[[1L]]),
          parent_pi_w = as.numeric(parent$pi_w[[1L]]),
          parent_pi_in = as.numeric(parent$pi_in[[1L]]),
          repaired_pi_w = topology$repaired_pi_w,
          repaired_pi_in = topology$repaired_pi_in,
          expected_recurrent_edges = as.integer(parent$n_each[[1L]])^2 * topology$pi_w,
          expected_input_edges = as.integer(parent$n_each[[1L]]) * (as.integer(parent$m[[1L]]) + 1L) * topology$pi_in,
          source_screening_profile_id = parent$parent_profile_id[[1L]],
          candidate_source = "topology_informed_cellwise_alpha_rho_v2",
          selection_reason = search$rationale[[1L]],
          stringsAsFactors = FALSE
        )
        assignments[[profile_counter]] <- data.frame(
          assignment_id = sprintf("arv2_%04d", profile_counter),
          family = parent$family[[1L]],
          tau = as.numeric(parent$tau[[1L]]),
          likelihood_target = parent$likelihood_target[[1L]],
          target_cell_id = parent$target_cell_id[[1L]],
          target_role = parent$target_role[[1L]],
          screening_profile_id = profile_id,
          parent_profile_id = parent$parent_profile_id[[1L]],
          candidate_id = candidate_id,
          search_id = search$search_id[[1L]],
          search_dimension = search$search_dimension[[1L]],
          search_priority = search$priority[[1L]],
          topology_mode = search$topology_mode[[1L]],
          point_index = as.integer(point_i),
          reservoir_replicate = as.integer(reservoir_replicate),
          launch_phase = launch_phase,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  profiles <- do.call(rbind, profiles)
  assignments <- do.call(rbind, assignments)
  designs <- do.call(rbind, designs)
  rownames(profiles) <- rownames(assignments) <- rownames(designs) <- NULL
  if (nrow(designs) != 90L || nrow(profiles) != 180L || nrow(assignments) != 180L) {
    stop(sprintf("Frozen v2 counts are wrong: designs=%d profiles=%d assignments=%d.", nrow(designs), nrow(profiles), nrow(assignments)), call. = FALSE)
  }
  list(parents = parents, search_map = search_map, designs = designs, profiles = profiles, assignments = assignments)
}

qdesn_arv2_topology_audit <- function(profiles) {
  if (!exists(".qdesn_arv1_build_d1_reservoir", mode = "function")) {
    stop("Source qdesn_alpha_rho_topology_v1.R before running the v2 topology audit.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    reservoir <- .qdesn_arv1_build_d1_reservoir(
      p$n_each, p$m, p$alpha, p$rho, p$pi_w, p$pi_in, p$seed
    )
    W <- reservoir$W
    Win <- reservoir$Win
    w_radius <- max(Mod(eigen(W, only.values = TRUE)$values))
    data.frame(
      screening_profile_id = p$screening_profile_id[[1L]],
      candidate_id = p$candidate_id[[1L]],
      target_cell_id = p$target_cell_id[[1L]],
      search_id = p$search_id[[1L]],
      search_dimension = p$search_dimension[[1L]],
      topology_mode = p$topology_mode[[1L]],
      reservoir_replicate = as.integer(p$reservoir_replicate[[1L]]),
      alpha = as.numeric(p$alpha[[1L]]),
      rho = as.numeric(p$rho[[1L]]),
      recurrent_nnz = sum(W != 0),
      input_nnz = sum(Win != 0),
      recurrent_spectral_radius = w_radius,
      rho_identifiable = is.finite(w_radius) && w_radius > 0,
      input_active = sum(Win != 0) > 0,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  alpha_only <- out$search_dimension == "alpha_only"
  alpha_groups <- split(
    seq_len(nrow(out))[alpha_only],
    paste(out$target_cell_id[alpha_only], out$search_id[alpha_only], out$reservoir_replicate[alpha_only], sep = "\r")
  )
  if (!all(vapply(alpha_groups, function(idx) length(unique(out$rho[idx])) == 1L, logical(1L)))) {
    stop("An alpha-only v2 search varies rho.", call. = FALSE)
  }
  if (any(!out$rho_identifiable[!alpha_only])) {
    stop("An alpha/rho v2 search has an inert recurrent radius.", call. = FALSE)
  }
  if (any(!out$input_active)) stop("Every v2 search profile must receive an active input signal.", call. = FALSE)
  out
}

qdesn_arv2_select_objective_candidates <- function(summary, max_per_cell = 4L) {
  required <- c(
    "target_cell_id", "candidate_id", "median_fit_ratio",
    "median_forecast_mae_ratio", "median_forecast_check_ratio",
    "worst_median_ratio", "worst_q90_ratio", "n_complete_pairs"
  )
  missing <- setdiff(required, names(summary))
  if (length(missing)) stop(sprintf("Candidate summary is missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  eligible <- summary[
    summary$n_complete_pairs >= 3L &
      summary$worst_median_ratio <= 1.05 &
      summary$worst_q90_ratio <= 1.25 &
      pmin(
        summary$median_fit_ratio,
        summary$median_forecast_mae_ratio,
        summary$median_forecast_check_ratio,
        na.rm = TRUE
      ) <= 0.98,
    , drop = FALSE
  ]
  if (!nrow(eligible)) return(eligible)
  metrics <- c(
    fit = "median_fit_ratio",
    forecast_mae = "median_forecast_mae_ratio",
    forecast_check = "median_forecast_check_ratio",
    balanced = "worst_median_ratio"
  )
  selected <- list()
  for (cell in unique(eligible$target_cell_id)) {
    x <- eligible[eligible$target_cell_id == cell, , drop = FALSE]
    picks <- lapply(names(metrics), function(objective) {
      metric <- metrics[[objective]]
      order_cols <- order(x[[metric]], x$worst_median_ratio, x$worst_q90_ratio, x$candidate_id)
      row <- x[order_cols[[1L]], , drop = FALSE]
      row$selection_objective <- objective
      row
    })
    picks <- do.call(rbind, picks)
    objective_map <- split(picks$selection_objective, picks$candidate_id)
    picks <- picks[!duplicated(picks$candidate_id), , drop = FALSE]
    picks$selection_objective <- vapply(picks$candidate_id, function(id) {
      paste(objective_map[[id]], collapse = "+")
    }, character(1L))
    picks <- picks[order(picks$worst_median_ratio, picks$worst_q90_ratio, picks$candidate_id), , drop = FALSE]
    selected[[length(selected) + 1L]] <- utils::head(picks, as.integer(max_per_cell))
  }
  out <- do.call(rbind, selected)
  rownames(out) <- NULL
  out
}
