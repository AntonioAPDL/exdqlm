qdesn_arfc1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_arfc1_build_plan <- function(cellwise_profiles, parent_profiles, handoff) {
  required_handoff <- c(
    "target_cell_id", "candidate_id", "likelihood_target", "target_family",
    "target_tau", "handoff_status", "confirmation_budget_n_burn",
    "confirmation_budget_n_mcmc"
  )
  missing_handoff <- setdiff(required_handoff, names(handoff))
  if (length(missing_handoff)) {
    stop(sprintf(
      "Confirmation handoff is missing: %s.",
      paste(missing_handoff, collapse = ", ")
    ), call. = FALSE)
  }
  if (nrow(handoff) != 2L ||
      anyDuplicated(handoff$target_cell_id) ||
      any(handoff$handoff_status != "PREPARED_NOT_LAUNCHED") ||
      any(as.integer(handoff$confirmation_budget_n_burn) != 5000L) ||
      any(as.integer(handoff$confirmation_budget_n_mcmc) != 20000L)) {
    stop("Expected exactly two unlaunched 5,000/20,000 confirmation handoffs.", call. = FALSE)
  }

  candidate_rows <- cellwise_profiles[
    cellwise_profiles$candidate_id %in% handoff$candidate_id &
      as.integer(cellwise_profiles$reservoir_replicate) %in% 1:2,
    ,
    drop = FALSE
  ]
  if (nrow(candidate_rows) != 4L ||
      any(table(candidate_rows$candidate_id) != 2L) ||
      any(vapply(
        split(candidate_rows$reservoir_replicate, candidate_rows$candidate_id),
        function(x) !setequal(as.integer(x), 1:2),
        logical(1L)
      ))) {
    stop("Could not recover two reservoir profiles for each confirmation candidate.", call. = FALSE)
  }

  candidate_rows$source_screening_profile_id <- candidate_rows$screening_profile_id
  candidate_rows$comparison_role <- "candidate"
  candidate_rows$screening_stage <- "mcmc_alpha_rho_confirmation_v1"
  candidate_rows$screening_wave <- "alpha_rho_confirmation_v1_2026_08_03"
  candidate_rows$profile_role <- "candidate_confirmation"
  candidate_rows$launch_phase <- "frozen_article_source_confirmation"
  candidate_rows$screening_profile_id <- vapply(seq_len(nrow(candidate_rows)), function(i) {
    sprintf(
      "arfc1_candidate_%s_r%02d",
      qdesn_arfc1_safe_token(candidate_rows$target_cell_id[[i]]),
      as.integer(candidate_rows$reservoir_replicate[[i]])
    )
  }, character(1L))
  candidate_rows$confirmation_pair_id <- paste(
    candidate_rows$target_cell_id,
    sprintf("r%02d", as.integer(candidate_rows$reservoir_replicate)),
    sep = "::"
  )

  design_fields <- c(
    "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w", "pi_in",
    "washout", "add_bias", "readout_y_lags", "reservoir_lags", "rhs_tau0",
    "dimension_p_estimate", "p_over_n_tt500"
  )
  parent_rows <- lapply(seq_len(nrow(candidate_rows)), function(i) {
    candidate <- candidate_rows[i, , drop = FALSE]
    parent <- parent_profiles[
      parent_profiles$target_cell_id == candidate$target_cell_id[[1L]],
      ,
      drop = FALSE
    ]
    if (nrow(parent) != 1L) {
      stop(sprintf(
        "Could not resolve one parent for %s.",
        candidate$target_cell_id[[1L]]
      ), call. = FALSE)
    }
    out <- candidate
    for (field in design_fields) out[[field]] <- parent[[field]][[1L]]
    out$screening_profile_id <- sprintf(
      "arfc1_parent_%s_r%02d",
      qdesn_arfc1_safe_token(candidate$target_cell_id[[1L]]),
      as.integer(candidate$reservoir_replicate[[1L]])
    )
    out$profile_role <- "parent_confirmation"
    out$comparison_role <- "parent_exact"
    out$candidate_id <- paste0(
      "arfc1_", qdesn_arfc1_safe_token(candidate$target_cell_id[[1L]]),
      "_parent_exact"
    )
    out$search_id <- "parent_exact"
    out$search_dimension <- "parent_exact"
    out$search_priority <- "paired_control"
    out$point_index <- 0L
    out$topology_mode <- "parent"
    out$parent_alpha <- parent$alpha[[1L]]
    out$parent_rho <- parent$rho[[1L]]
    out$parent_pi_w <- parent$pi_w[[1L]]
    out$parent_pi_in <- parent$pi_in[[1L]]
    out$repaired_pi_w <- parent$pi_w[[1L]]
    out$repaired_pi_in <- parent$pi_in[[1L]]
    out$seed <- candidate$seed[[1L]]
    out$source_screening_profile_id <- parent$parent_profile_id[[1L]]
    out$candidate_source <- "exact_parent_control"
    out$selection_reason <- paste(
      "Exact parent on the same frozen article source, reservoir realization,",
      "and sampler seeds as its candidate."
    )
    out$confirmation_pair_id <- candidate$confirmation_pair_id[[1L]]
    out
  })
  parent_rows <- do.call(rbind, parent_rows)
  profiles <- rbind(candidate_rows, parent_rows)
  profiles <- profiles[order(
    profiles$target_cell_id,
    profiles$reservoir_replicate,
    profiles$comparison_role
  ), , drop = FALSE]
  rownames(profiles) <- NULL

  if (nrow(profiles) != 8L ||
      anyDuplicated(profiles$screening_profile_id) ||
      any(table(profiles$confirmation_pair_id) != 2L)) {
    stop("The confirmation profile plan is not eight unique paired profiles.", call. = FALSE)
  }
  paired_seed_ok <- vapply(
    split(profiles, profiles$confirmation_pair_id),
    function(x) length(unique(as.integer(x$seed))) == 1L,
    logical(1L)
  )
  if (!all(paired_seed_ok)) {
    stop("Candidate and parent do not share the declared reservoir seed.", call. = FALSE)
  }

  assignments <- data.frame(
    assignment_key = paste(
      profiles$screening_profile_id,
      profiles$target_family,
      sprintf("%.8f", as.numeric(profiles$target_tau)),
      sep = "|"
    ),
    assignment_id = sprintf("arfc1_%03d", seq_len(nrow(profiles))),
    family = as.character(profiles$target_family),
    tau = as.numeric(profiles$target_tau),
    likelihood_target = as.character(profiles$likelihood_target),
    target_cell_id = as.character(profiles$target_cell_id),
    target_role = as.character(profiles$target_role),
    cell_status = "full_budget_confirmation",
    priority_rank = match(
      profiles$target_cell_id,
      unique(profiles$target_cell_id)
    ),
    target_profile_rank = seq_len(nrow(profiles)),
    screening_profile_id = as.character(profiles$screening_profile_id),
    parent_profile_id = as.character(profiles$parent_profile_id),
    candidate_id = as.character(profiles$candidate_id),
    comparison_role = as.character(profiles$comparison_role),
    reservoir_replicate = as.integer(profiles$reservoir_replicate),
    confirmation_pair_id = as.character(profiles$confirmation_pair_id),
    launch_status = "prepared_not_launched",
    stringsAsFactors = FALSE
  )
  cell_plan <- unique(assignments[, c(
    "family", "tau", "likelihood_target", "target_cell_id", "target_role"
  )])
  cell_plan$cell_status <- "full_budget_confirmation"
  cell_plan$primary_objective <- ifelse(
    cell_plan$target_cell_id == "exal_gausmix_t0p25",
    "forecast_transport",
    "fit_recovery"
  )
  list(profiles = profiles, assignments = assignments, cell_plan = cell_plan)
}

qdesn_arfc1_assign_execution_seeds <- function(grid, profiles) {
  out <- as.data.frame(grid, stringsAsFactors = FALSE)
  profile_seeds <- stats::setNames(
    as.integer(profiles$seed),
    as.character(profiles$screening_profile_id)
  )
  out$desn_seed <- unname(profile_seeds[as.character(out$screening_profile_id)])
  pair_levels <- sort(unique(as.character(out$confirmation_pair_id)))
  pair_index <- match(as.character(out$confirmation_pair_id), pair_levels)
  out$mcmc_seed <- as.integer(910000L + pair_index)
  out$mcmc_rng_seed <- as.integer(920000L + pair_index)
  out$vb_warm_start_seed <- as.integer(930000L + pair_index)
  out$synthesis_seed <- as.integer(940000L + pair_index)
  out$sampler_pair_id <- as.character(out$confirmation_pair_id)
  out
}

qdesn_arfc1_seed_contract_audit <- function(grid, profiles, stop_on_fail = TRUE) {
  profile_seeds <- stats::setNames(
    as.integer(profiles$seed),
    as.character(profiles$screening_profile_id)
  )
  expected_desn_seed <- unname(profile_seeds[as.character(grid$screening_profile_id)])
  out <- data.frame(
    root_id = as.character(grid$root_id),
    screening_profile_id = as.character(grid$screening_profile_id),
    target_cell_id = as.character(grid$target_cell_id),
    comparison_role = as.character(grid$comparison_role),
    reservoir_replicate = as.integer(grid$reservoir_replicate),
    confirmation_pair_id = as.character(grid$confirmation_pair_id),
    expected_desn_seed = as.integer(expected_desn_seed),
    observed_desn_seed = as.integer(grid$desn_seed),
    mcmc_seed = as.integer(grid$mcmc_seed),
    mcmc_rng_seed = as.integer(grid$mcmc_rng_seed),
    vb_warm_start_seed = as.integer(grid$vb_warm_start_seed),
    synthesis_seed = as.integer(grid$synthesis_seed),
    stringsAsFactors = FALSE
  )
  out$desn_seed_match <- out$expected_desn_seed == out$observed_desn_seed
  seed_fields <- c(
    "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed"
  )
  pair_ok <- vapply(split(seq_len(nrow(out)), out$confirmation_pair_id), function(index) {
    length(index) == 2L &&
      setequal(out$comparison_role[index], c("candidate", "parent_exact")) &&
      length(unique(out$observed_desn_seed[index])) == 1L &&
      all(vapply(seed_fields, function(field) {
        length(unique(out[[field]][index])) == 1L
      }, logical(1L)))
  }, logical(1L))
  out$paired_execution_seeds_match <- unname(pair_ok[out$confirmation_pair_id])
  out$status <- ifelse(
    out$desn_seed_match & out$paired_execution_seeds_match,
    "PASS",
    "FAIL"
  )
  if (isTRUE(stop_on_fail) && any(out$status != "PASS")) {
    stop("The frozen confirmation seed contract failed.", call. = FALSE)
  }
  out
}

qdesn_arfc1_pair_metrics <- function(metrics) {
  required <- c(
    "target_cell_id", "reservoir_replicate", "comparison_role",
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000"
  )
  missing <- setdiff(required, names(metrics))
  if (length(missing)) {
    stop(sprintf("Pair metrics are missing: %s.", paste(missing, collapse = ", ")), call. = FALSE)
  }
  groups <- split(
    seq_len(nrow(metrics)),
    paste(metrics$target_cell_id, metrics$reservoir_replicate, sep = "::")
  )
  rows <- lapply(groups, function(index) {
    x <- metrics[index, , drop = FALSE]
    candidate <- x[x$comparison_role == "candidate", , drop = FALSE]
    parent <- x[x$comparison_role == "parent_exact", , drop = FALSE]
    if (nrow(candidate) != 1L || nrow(parent) != 1L) {
      stop("Each confirmation pair must contain one candidate and one parent.", call. = FALSE)
    }
    data.frame(
      target_cell_id = candidate$target_cell_id[[1L]],
      family = candidate$family[[1L]],
      tau = as.numeric(candidate$tau[[1L]]),
      reservoir_replicate = as.integer(candidate$reservoir_replicate[[1L]]),
      candidate_profile_id = candidate$screening_profile_id[[1L]],
      parent_profile_id = parent$screening_profile_id[[1L]],
      candidate_fit = as.numeric(candidate$fit_qtrue_rmse[[1L]]),
      parent_fit = as.numeric(parent$fit_qtrue_rmse[[1L]]),
      fit_ratio = as.numeric(candidate$fit_qtrue_rmse[[1L]]) /
        as.numeric(parent$fit_qtrue_rmse[[1L]]),
      candidate_forecast_mae = as.numeric(candidate$forecast_qtrue_mae_H1000[[1L]]),
      parent_forecast_mae = as.numeric(parent$forecast_qtrue_mae_H1000[[1L]]),
      forecast_mae_ratio = as.numeric(candidate$forecast_qtrue_mae_H1000[[1L]]) /
        as.numeric(parent$forecast_qtrue_mae_H1000[[1L]]),
      candidate_forecast_check = as.numeric(candidate$forecast_check_loss_H1000[[1L]]),
      parent_forecast_check = as.numeric(parent$forecast_check_loss_H1000[[1L]]),
      forecast_check_ratio = as.numeric(candidate$forecast_check_loss_H1000[[1L]]) /
        as.numeric(parent$forecast_check_loss_H1000[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
