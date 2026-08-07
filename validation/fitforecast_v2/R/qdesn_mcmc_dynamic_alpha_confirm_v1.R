`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_dacf1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_dacf1_tau_key <- function(x) sprintf("%.8f", as.numeric(x))

qdesn_dacf1_expected_shortlist <- function() {
  data.frame(
    confirmation_design_id = c(
      "dacf1_al_a0p60_seed900124",
      "dacf1_al_a0p50_seed900132",
      "dacf1_al_a0p55_seed900132",
      "dacf1_exal_a0p80_seed900132",
      "dacf1_exal_a0p70_seed900126",
      "dacf1_exal_a0p85_seed900126"
    ),
    source_screening_profile_id = c(
      "dsr1_al_normal_t0p25_alpha_a0p6_r01",
      "dsr1_al_normal_t0p25_alpha_a0p5_r03",
      "dsr1_al_normal_t0p25_alpha_a0p55_r03",
      "dsr1_exal_normal_t0p25_alpha_a0p8_r03",
      "dsr1_exal_normal_t0p25_alpha_a0p7_r02",
      "dsr1_exal_normal_t0p25_alpha_a0p85_r02"
    ),
    target_cell_id = c(
      rep("al_normal_t0p25", 3L),
      rep("exal_normal_t0p25", 3L)
    ),
    likelihood_target = c(rep("al", 3L), rep("exal", 3L)),
    alpha = c(0.60, 0.50, 0.55, 0.80, 0.70, 0.85),
    desn_seed = c(900124L, 900132L, 900132L, 900132L, 900126L, 900126L),
    stringsAsFactors = FALSE
  )
}

qdesn_dacf1_validate_shortlist <- function(shortlist) {
  required <- c(
    "confirmation_design_id", "source_screening_profile_id", "target_cell_id",
    "likelihood_target", "alpha", "desn_seed", "selection_tier",
    "selection_role", "selection_reason"
  )
  missing <- setdiff(required, names(shortlist))
  if (length(missing)) {
    stop(sprintf("Confirmation shortlist is missing: %s.", paste(missing, collapse = ", ")), call. = FALSE)
  }
  expected <- qdesn_dacf1_expected_shortlist()
  key <- match(expected$confirmation_design_id, shortlist$confirmation_design_id)
  if (nrow(shortlist) != 6L || anyNA(key) || anyDuplicated(shortlist$confirmation_design_id) ||
      anyDuplicated(shortlist$source_screening_profile_id)) {
    stop("The confirmation shortlist is not the six exact frozen designs.", call. = FALSE)
  }
  observed <- shortlist[key, names(expected), drop = FALSE]
  exact <-
    observed$source_screening_profile_id == expected$source_screening_profile_id &
    observed$target_cell_id == expected$target_cell_id &
    observed$likelihood_target == expected$likelihood_target &
    abs(as.numeric(observed$alpha) - expected$alpha) <= 1e-12 &
    as.integer(observed$desn_seed) == expected$desn_seed
  if (!all(exact)) stop("One or more shortlist designs differ from the audited discovery evidence.", call. = FALSE)
  invisible(TRUE)
}

.qdesn_dacf1_expand_sampler_replicates <- function(rows, sampler_replicates) {
  out <- lapply(seq_len(nrow(rows)), function(i) {
    do.call(rbind, lapply(seq_len(sampler_replicates), function(rep_id) {
      row <- rows[i, , drop = FALSE]
      row$sampler_replicate <- as.integer(rep_id)
      row$screening_profile_id <- sprintf(
        "%s_s%02d", as.character(row$confirmation_design_id), as.integer(rep_id)
      )
      row
    }))
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

qdesn_dacf1_build_plan <- function(discovery_profiles, shortlist, sampler_replicates = 3L) {
  qdesn_dacf1_validate_shortlist(shortlist)
  sampler_replicates <- as.integer(sampler_replicates)
  if (sampler_replicates != 3L) stop("The confirmation contract requires three sampler replicates.", call. = FALSE)

  candidate_index <- match(
    shortlist$source_screening_profile_id,
    discovery_profiles$screening_profile_id
  )
  if (anyNA(candidate_index)) stop("A shortlisted discovery profile is unavailable.", call. = FALSE)
  candidates <- discovery_profiles[candidate_index, , drop = FALSE]
  expected <- qdesn_dacf1_expected_shortlist()
  expected <- expected[match(shortlist$confirmation_design_id, expected$confirmation_design_id), , drop = FALSE]
  candidate_exact <-
    candidates$target_cell_id == expected$target_cell_id &
    candidates$likelihood_target == expected$likelihood_target &
    abs(as.numeric(candidates$alpha) - expected$alpha) <= 1e-12 &
    as.integer(candidates$seed) == expected$desn_seed &
    candidates$comparison_role == "candidate"
  if (!all(candidate_exact)) stop("Shortlist-to-discovery profile verification failed.", call. = FALSE)

  candidates$source_screening_profile_id <- as.character(candidates$screening_profile_id)
  candidates$confirmation_design_id <- as.character(shortlist$confirmation_design_id)
  candidates$selection_tier <- as.character(shortlist$selection_tier)
  candidates$selection_role <- as.character(shortlist$selection_role)
  candidates$selection_reason <- as.character(shortlist$selection_reason)
  candidates$comparison_role <- "candidate"
  candidates$profile_role <- "candidate_full_budget_confirmation"
  candidates$design_role <- "candidate_full_budget_confirmation"
  candidates$screening_stage <- "mcmc_dynamic_alpha_confirm_v1"
  candidates$screening_wave <- "dynamic_alpha_confirm_2026_08_07"
  candidates$launch_phase <- "frozen_article_source_full_budget_confirmation"
  candidates$control_key <- paste(
    candidates$target_cell_id, as.integer(candidates$seed), sep = "::"
  )

  controls_needed <- unique(candidates[, c(
    "target_cell_id", "likelihood_target", "seed", "control_key"
  ), drop = FALSE])
  controls <- lapply(seq_len(nrow(controls_needed)), function(i) {
    key <- controls_needed[i, , drop = FALSE]
    hits <- discovery_profiles[
      discovery_profiles$target_cell_id == key$target_cell_id[[1L]] &
        discovery_profiles$comparison_role == "dynamic_parent" &
        as.integer(discovery_profiles$seed) == as.integer(key$seed[[1L]]),
      , drop = FALSE
    ]
    if (nrow(hits) != 1L) {
      stop(sprintf("Could not recover one dynamic parent for %s.", key$control_key[[1L]]), call. = FALSE)
    }
    hits$source_screening_profile_id <- as.character(hits$screening_profile_id)
    hits$confirmation_design_id <- paste0(
      "dacf1_parent_", qdesn_dacf1_safe_token(key$target_cell_id[[1L]]),
      "_seed", as.integer(key$seed[[1L]])
    )
    hits$selection_tier <- "control"
    hits$selection_role <- "same_reservoir_parent_control"
    hits$selection_reason <- paste(
      "Exact parent alpha on the same frozen article source, DESN realization,",
      "and sampler seeds as each linked candidate."
    )
    hits$comparison_role <- "parent_exact_same_reservoir"
    hits$profile_role <- "parent_full_budget_confirmation"
    hits$design_role <- "parent_full_budget_confirmation"
    hits$screening_stage <- "mcmc_dynamic_alpha_confirm_v1"
    hits$screening_wave <- "dynamic_alpha_confirm_2026_08_07"
    hits$launch_phase <- "frozen_article_source_full_budget_confirmation"
    hits$control_key <- key$control_key[[1L]]
    hits
  })
  controls <- do.call(rbind, controls)
  rownames(controls) <- NULL
  if (nrow(controls) != 4L) stop("Expected four unique same-reservoir parent controls.", call. = FALSE)

  base_designs <- rbind(candidates, controls)
  topology_input <- base_designs
  topology_input$comparison_role[topology_input$comparison_role == "parent_exact_same_reservoir"] <-
    "dynamic_parent"
  profiles <- .qdesn_dacf1_expand_sampler_replicates(base_designs, sampler_replicates)
  profiles$candidate_id <- as.character(profiles$confirmation_design_id)
  profiles$arm_code <- as.character(profiles$confirmation_design_id)
  profiles$point_index <- seq_len(nrow(profiles))
  profiles$topology_search_mode <- "frozen_dynamic_alpha_confirmation"
  profiles$topology_mode <- "exact_discovery_topology_and_probabilities"

  profile_key <- paste(profiles$control_key, profiles$sampler_replicate, sep = "::s")
  key_levels <- sort(unique(profile_key))
  seed_index <- match(profile_key, key_levels)
  profiles$mcmc_seed <- as.integer(951000L + seed_index)
  profiles$mcmc_rng_seed <- as.integer(952000L + seed_index)
  profiles$vb_warm_start_seed <- as.integer(953000L + seed_index)
  profiles$synthesis_seed <- as.integer(954000L + seed_index)
  profiles$sampler_pair_id <- profile_key

  assignments <- data.frame(
    assignment_id = sprintf("dacf1_%03d", seq_len(nrow(profiles))),
    family = as.character(profiles$target_family),
    tau = as.numeric(profiles$target_tau),
    likelihood_target = as.character(profiles$likelihood_target),
    target_cell_id = as.character(profiles$target_cell_id),
    target_metrics = as.character(profiles$target_metrics),
    screening_profile_id = as.character(profiles$screening_profile_id),
    source_screening_profile_id = as.character(profiles$source_screening_profile_id),
    confirmation_design_id = as.character(profiles$confirmation_design_id),
    comparison_role = as.character(profiles$comparison_role),
    control_key = as.character(profiles$control_key),
    reservoir_replicate = as.integer(profiles$reservoir_replicate),
    paired_reservoir_seed = as.integer(profiles$seed),
    sampler_replicate = as.integer(profiles$sampler_replicate),
    sampler_pair_id = as.character(profiles$sampler_pair_id),
    launch_status = "prepared_not_launched",
    stringsAsFactors = FALSE
  )

  candidate_profiles <- profiles[profiles$comparison_role == "candidate", , drop = FALSE]
  parent_profiles <- profiles[
    profiles$comparison_role == "parent_exact_same_reservoir", , drop = FALSE
  ]
  parent_lookup_key <- paste(
    parent_profiles$control_key, parent_profiles$sampler_replicate, sep = "::s"
  )
  candidate_lookup_key <- paste(
    candidate_profiles$control_key, candidate_profiles$sampler_replicate, sep = "::s"
  )
  parent_index <- match(candidate_lookup_key, parent_lookup_key)
  if (anyNA(parent_index)) stop("A candidate is missing its exact paired parent control.", call. = FALSE)
  pair_map <- data.frame(
    confirmation_pair_id = paste(
      candidate_profiles$confirmation_design_id,
      sprintf("s%02d", candidate_profiles$sampler_replicate), sep = "::"
    ),
    target_cell_id = as.character(candidate_profiles$target_cell_id),
    likelihood_target = as.character(candidate_profiles$likelihood_target),
    confirmation_design_id = as.character(candidate_profiles$confirmation_design_id),
    control_key = as.character(candidate_profiles$control_key),
    desn_seed = as.integer(candidate_profiles$seed),
    sampler_replicate = as.integer(candidate_profiles$sampler_replicate),
    candidate_profile_id = as.character(candidate_profiles$screening_profile_id),
    parent_profile_id = as.character(parent_profiles$screening_profile_id[parent_index]),
    sampler_pair_id = as.character(candidate_profiles$sampler_pair_id),
    stringsAsFactors = FALSE
  )

  if (nrow(profiles) != 30L ||
      sum(profiles$comparison_role == "candidate") != 18L ||
      sum(profiles$comparison_role == "parent_exact_same_reservoir") != 12L ||
      nrow(pair_map) != 18L || anyDuplicated(profiles$screening_profile_id) ||
      anyDuplicated(pair_map$confirmation_pair_id)) {
    stop("The 30-fit confirmation profile contract failed.", call. = FALSE)
  }
  list(
    profiles = profiles,
    assignments = assignments,
    pair_map = pair_map,
    base_designs = base_designs,
    topology_input = topology_input
  )
}

qdesn_dacf1_assign_execution_seeds <- function(grid, profiles) {
  out <- as.data.frame(grid, stringsAsFactors = FALSE)
  fields <- c(
    desn_seed = "seed", mcmc_seed = "mcmc_seed",
    mcmc_rng_seed = "mcmc_rng_seed",
    vb_warm_start_seed = "vb_warm_start_seed",
    synthesis_seed = "synthesis_seed", sampler_pair_id = "sampler_pair_id"
  )
  index <- match(out$screening_profile_id, profiles$screening_profile_id)
  if (anyNA(index)) stop("Execution grid contains an unknown confirmation profile.", call. = FALSE)
  for (target in names(fields)) out[[target]] <- profiles[[fields[[target]]]][index]
  out
}

qdesn_dacf1_seed_contract_audit <- function(grid, profiles, stop_on_fail = TRUE) {
  index <- match(grid$screening_profile_id, profiles$screening_profile_id)
  out <- data.frame(
    root_id = as.character(grid$root_id),
    screening_profile_id = as.character(grid$screening_profile_id),
    target_cell_id = as.character(profiles$target_cell_id[index]),
    comparison_role = as.character(profiles$comparison_role[index]),
    control_key = as.character(profiles$control_key[index]),
    sampler_replicate = as.integer(profiles$sampler_replicate[index]),
    expected_desn_seed = as.integer(profiles$seed[index]),
    observed_desn_seed = as.integer(grid$desn_seed),
    mcmc_seed = as.integer(grid$mcmc_seed),
    mcmc_rng_seed = as.integer(grid$mcmc_rng_seed),
    vb_warm_start_seed = as.integer(grid$vb_warm_start_seed),
    synthesis_seed = as.integer(grid$synthesis_seed),
    sampler_pair_id = as.character(grid$sampler_pair_id),
    stringsAsFactors = FALSE
  )
  seed_fields <- c("mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed")
  group_ok <- vapply(split(seq_len(nrow(out)), out$sampler_pair_id), function(rows) {
    roles <- out$comparison_role[rows]
    sum(roles == "parent_exact_same_reservoir") == 1L &&
      sum(roles == "candidate") >= 1L &&
      length(unique(out$observed_desn_seed[rows])) == 1L &&
      all(vapply(seed_fields, function(field) length(unique(out[[field]][rows])) == 1L, logical(1L)))
  }, logical(1L))
  out$desn_seed_match <- out$expected_desn_seed == out$observed_desn_seed
  out$paired_execution_seeds_match <- unname(group_ok[out$sampler_pair_id])
  out$status <- ifelse(out$desn_seed_match & out$paired_execution_seeds_match, "PASS", "FAIL")
  if (isTRUE(stop_on_fail) && any(out$status != "PASS")) {
    stop("The confirmation execution-seed contract failed.", call. = FALSE)
  }
  out
}

qdesn_dacf1_pair_metrics <- function(metrics, pair_map) {
  required <- c(
    "screening_profile_id", "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000"
  )
  missing <- setdiff(required, names(metrics))
  if (length(missing)) stop(sprintf("Pair metrics are missing: %s.", paste(missing, collapse = ", ")), call. = FALSE)
  candidate_index <- match(pair_map$candidate_profile_id, metrics$screening_profile_id)
  parent_index <- match(pair_map$parent_profile_id, metrics$screening_profile_id)
  out <- pair_map
  for (metric in c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")) {
    candidate_value <- as.numeric(metrics[[metric]][candidate_index])
    parent_value <- as.numeric(metrics[[metric]][parent_index])
    out[[paste0("candidate_", metric)]] <- candidate_value
    out[[paste0("parent_", metric)]] <- parent_value
    out[[paste0(metric, "_ratio")]] <- candidate_value / parent_value
  }
  out$pair_complete <- stats::complete.cases(out[, grep("_ratio$", names(out)), drop = FALSE])
  out
}

qdesn_dacf1_metric_promotion <- function(metrics, article_context, tolerance = 1e-10) {
  metric_names <- c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000"
  )
  required_metrics <- c(
    "spec_id", "screening_profile_id", "likelihood_family",
    "source_registry_hash_match", "seed_contract_match",
    "budget_contract_match", "expected_spec_match", metric_names
  )
  required_context <- c("model_variant", metric_names)
  missing_metrics <- setdiff(required_metrics, names(metrics))
  missing_context <- setdiff(required_context, names(article_context))
  if (length(missing_metrics) || length(missing_context)) {
    stop(sprintf(
      "Metric-promotion inputs are missing: %s.",
      paste(c(missing_metrics, missing_context), collapse = ", ")
    ), call. = FALSE)
  }
  tolerance <- as.numeric(tolerance)[1L]
  if (!is.finite(tolerance) || tolerance < 0) {
    stop("Promotion tolerance must be finite and nonnegative.", call. = FALSE)
  }

  rows <- list()
  for (variant in c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")) {
    likelihood <- if (identical(variant, "qdesn_al_rhs_ns")) "al" else "exal"
    current <- article_context[article_context$model_variant == variant, , drop = FALSE]
    candidates <- metrics[metrics$likelihood_family == likelihood, , drop = FALSE]
    if (nrow(current) != 1L) {
      stop(sprintf("Expected one current article row for %s.", variant), call. = FALSE)
    }
    if (!nrow(candidates)) next
    for (metric in metric_names) {
      current_value <- as.numeric(current[[metric]][[1L]])
      for (i in seq_len(nrow(candidates))) {
        candidate_value <- as.numeric(candidates[[metric]][[i]])
        contract_eligible <- isTRUE(as.logical(candidates$source_registry_hash_match[[i]])) &&
          isTRUE(as.logical(candidates$seed_contract_match[[i]])) &&
          isTRUE(as.logical(candidates$budget_contract_match[[i]])) &&
          isTRUE(as.logical(candidates$expected_spec_match[[i]])) &&
          is.finite(candidate_value) && is.finite(current_value)
        rows[[length(rows) + 1L]] <- data.frame(
          model_variant = variant,
          metric = metric,
          spec_id = as.character(candidates$spec_id[[i]]),
          screening_profile_id = as.character(candidates$screening_profile_id[[i]]),
          candidate_value = candidate_value,
          current_value = current_value,
          ratio_to_current = candidate_value / current_value,
          contract_eligible = contract_eligible,
          metric_improves_current = contract_eligible &&
            candidate_value < current_value - tolerance,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  candidates <- if (length(rows)) do.call(rbind, rows) else data.frame()
  if (!nrow(candidates)) return(list(candidates = candidates, winners = candidates))
  candidates <- candidates[order(
    candidates$model_variant, candidates$metric,
    !candidates$contract_eligible, candidates$candidate_value,
    candidates$screening_profile_id
  ), , drop = FALSE]
  eligible <- candidates[
    candidates$contract_eligible & candidates$metric_improves_current,
    , drop = FALSE
  ]
  winners <- if (nrow(eligible)) {
    keys <- paste(eligible$model_variant, eligible$metric, sep = "\r")
    eligible[!duplicated(keys), , drop = FALSE]
  } else eligible
  rownames(candidates) <- NULL
  rownames(winners) <- NULL
  list(candidates = candidates, winners = winners)
}
