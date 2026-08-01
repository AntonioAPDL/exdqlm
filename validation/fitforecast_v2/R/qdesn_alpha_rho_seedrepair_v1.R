`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_arsr1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_arsr1_topology_audit <- function(profiles, seed_override = NULL) {
  if (!exists(".qdesn_arv1_build_d1_reservoir", mode = "function")) {
    stop("Source qdesn_alpha_rho_topology_v1.R before running the seed-repair topology audit.", call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required for the seed-repair topology audit.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    seed_used <- if (is.null(seed_override)) as.integer(p$seed[[1L]]) else as.integer(seed_override)[1L]
    reservoir <- .qdesn_arv1_build_d1_reservoir(
      n = as.integer(p$n_each[[1L]]),
      m = as.integer(p$m[[1L]]),
      alpha = as.numeric(p$alpha[[1L]]),
      rho = as.numeric(p$rho[[1L]]),
      pi_w = as.numeric(p$pi_w[[1L]]),
      pi_in = as.numeric(p$pi_in[[1L]]),
      seed = seed_used
    )
    W <- reservoir$W
    Win <- reservoir$Win
    data.frame(
      screening_profile_id = as.character(p$screening_profile_id[[1L]]),
      candidate_id = as.character(p$candidate_id[[1L]] %||% NA_character_),
      target_cell_id = as.character(p$target_cell_id[[1L]] %||% NA_character_),
      comparison_role = as.character(p$comparison_role[[1L]] %||% "candidate"),
      search_dimension = as.character(p$search_dimension[[1L]] %||% NA_character_),
      seed_declared = as.integer(p$seed[[1L]]),
      seed_used = seed_used,
      recurrent_nnz = sum(W != 0),
      input_nnz = sum(Win != 0),
      recurrent_mask_sha256 = digest::digest(W != 0, algo = "sha256"),
      input_mask_sha256 = digest::digest(Win != 0, algo = "sha256"),
      recurrent_value_sha256 = digest::digest(W, algo = "sha256"),
      input_value_sha256 = digest::digest(Win, algo = "sha256"),
      recurrent_active = sum(W != 0) > 0,
      input_active = sum(Win != 0) > 0,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

qdesn_arsr1_candidate_validity <- function(selected, profiles, actual_seed = 123L) {
  selected_ids <- unique(as.character(selected$candidate_id))
  first_profiles <- profiles[
    profiles$candidate_id %in% selected_ids & as.integer(profiles$reservoir_replicate) == 1L,
    , drop = FALSE
  ]
  first_profiles <- first_profiles[match(selected_ids, first_profiles$candidate_id), , drop = FALSE]
  if (nrow(first_profiles) != length(selected_ids) || anyNA(first_profiles$candidate_id)) {
    stop("Could not resolve one first-replicate profile per selected candidate.", call. = FALSE)
  }
  topology <- qdesn_arsr1_topology_audit(first_profiles, seed_override = actual_seed)
  alpha_rho <- as.character(topology$search_dimension) == "alpha_rho"
  topology$mechanically_valid <- topology$input_active & (!alpha_rho | topology$recurrent_active)
  topology$exclusion_reason <- ifelse(
    topology$mechanically_valid,
    "retained_for_corrected_second_seed",
    ifelse(
      !topology$input_active & !topology$recurrent_active,
      "actual_seed123_has_zero_input_and_recurrence",
      ifelse(!topology$input_active, "actual_seed123_has_zero_input", "actual_seed123_has_zero_recurrence")
    )
  )
  topology
}

.qdesn_arsr1_parent_profile <- function(template, parent, second_seed) {
  out <- template
  cell <- as.character(parent$target_cell_id[[1L]])
  out$screening_profile_id <- sprintf("arsr1_parent_%s_seed2", qdesn_arsr1_safe_token(cell))
  out$screening_stage <- "mcmc_alpha_rho_seedrepair_v1"
  out$screening_wave <- "alpha_rho_seedrepair_v1_2026_08_01"
  out$profile_role <- "parent_exact"
  for (nm in c(
    "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w", "pi_in",
    "washout", "add_bias", "readout_y_lags", "reservoir_lags", "rhs_tau0",
    "dimension_p_estimate", "p_over_n_tt500"
  )) {
    out[[nm]] <- parent[[nm]][[1L]]
  }
  out$seed <- as.integer(second_seed)
  out$x_feature_count <- 5L
  out$target_cells <- paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]), parent$likelihood_target[[1L]], sep = ":")
  out$target_cell_id <- cell
  out$target_role <- as.character(parent$target_role[[1L]])
  out$likelihood_target <- as.character(parent$likelihood_target[[1L]])
  out$target_family <- as.character(parent$family[[1L]])
  out$target_tau <- as.numeric(parent$tau[[1L]])
  out$parent_profile_id <- as.character(parent$parent_profile_id[[1L]])
  out$candidate_id <- sprintf("arsr1_%s_parent_exact", qdesn_arsr1_safe_token(cell))
  out$search_id <- "parent_exact"
  out$search_dimension <- "parent_exact"
  out$search_priority <- "paired_control"
  out$point_index <- 0L
  out$topology_mode <- "parent"
  out$reservoir_replicate <- 2L
  out$launch_phase <- "seed_contract_repair"
  out$parent_alpha <- as.numeric(parent$alpha[[1L]])
  out$parent_rho <- as.numeric(parent$rho[[1L]])
  out$parent_pi_w <- as.numeric(parent$pi_w[[1L]])
  out$parent_pi_in <- as.numeric(parent$pi_in[[1L]])
  out$repaired_pi_w <- as.numeric(parent$pi_w[[1L]])
  out$repaired_pi_in <- as.numeric(parent$pi_in[[1L]])
  out$expected_recurrent_edges <- as.integer(parent$n_each[[1L]])^2 * as.numeric(parent$pi_w[[1L]])
  out$expected_input_edges <- as.integer(parent$n_each[[1L]]) * (as.integer(parent$m[[1L]]) + 1L) * as.numeric(parent$pi_in[[1L]])
  out$source_screening_profile_id <- as.character(parent$parent_profile_id[[1L]])
  out$candidate_source <- "exact_parent_control_for_seed_contract_repair"
  out$selection_reason <- "Exact parent rerun on the same corrected second reservoir and sampler seed as its candidates."
  out$comparison_role <- "parent_exact"
  out$source_candidate_profile_id <- NA_character_
  out$seed_contract_version <- "screening_profile_desn_seed_v1"
  out
}

qdesn_arsr1_build_repair_plan <- function(profiles, parents, selected, actual_seed = 123L) {
  validity <- qdesn_arsr1_candidate_validity(selected, profiles, actual_seed = actual_seed)
  retained_ids <- as.character(validity$candidate_id[validity$mechanically_valid])
  candidate_profiles <- profiles[
    profiles$candidate_id %in% retained_ids & as.integer(profiles$reservoir_replicate) == 2L,
    , drop = FALSE
  ]
  candidate_profiles <- candidate_profiles[match(retained_ids, candidate_profiles$candidate_id), , drop = FALSE]
  if (nrow(candidate_profiles) != length(retained_ids) || anyNA(candidate_profiles$candidate_id)) {
    stop("Could not resolve one intended second-reservoir profile per retained candidate.", call. = FALSE)
  }
  candidate_profiles$source_candidate_profile_id <- as.character(candidate_profiles$screening_profile_id)
  candidate_profiles$screening_profile_id <- paste0(
    "arsr1_candidate_", qdesn_arsr1_safe_token(candidate_profiles$candidate_id), "_seed2"
  )
  candidate_profiles$screening_stage <- "mcmc_alpha_rho_seedrepair_v1"
  candidate_profiles$screening_wave <- "alpha_rho_seedrepair_v1_2026_08_01"
  candidate_profiles$launch_phase <- "seed_contract_repair"
  candidate_profiles$comparison_role <- "candidate"
  candidate_profiles$seed_contract_version <- "screening_profile_desn_seed_v1"

  parent_rows <- lapply(unique(as.character(candidate_profiles$target_cell_id)), function(cell) {
    template <- candidate_profiles[candidate_profiles$target_cell_id == cell, , drop = FALSE][1L, , drop = FALSE]
    parent <- parents[parents$target_cell_id == cell, , drop = FALSE]
    if (nrow(parent) != 1L) stop(sprintf("Could not resolve exact parent for %s.", cell), call. = FALSE)
    cell_seeds <- unique(as.integer(candidate_profiles$seed[candidate_profiles$target_cell_id == cell]))
    if (length(cell_seeds) != 1L) stop(sprintf("Second reservoir seed is inconsistent for %s.", cell), call. = FALSE)
    .qdesn_arsr1_parent_profile(template, parent, cell_seeds[[1L]])
  })
  parent_profiles <- do.call(rbind, parent_rows)
  repair_profiles <- rbind(candidate_profiles, parent_profiles)
  rownames(repair_profiles) <- NULL
  if (nrow(repair_profiles) != 16L || sum(repair_profiles$comparison_role == "candidate") != 11L ||
      sum(repair_profiles$comparison_role == "parent_exact") != 5L) {
    stop(sprintf(
      "Seed-repair profile count mismatch: total=%d candidates=%d parents=%d.",
      nrow(repair_profiles), sum(repair_profiles$comparison_role == "candidate"),
      sum(repair_profiles$comparison_role == "parent_exact")
    ), call. = FALSE)
  }
  assignments <- data.frame(
    assignment_id = sprintf("arsr1_%03d", seq_len(nrow(repair_profiles))),
    family = as.character(repair_profiles$target_family),
    tau = as.numeric(repair_profiles$target_tau),
    likelihood_target = as.character(repair_profiles$likelihood_target),
    target_cell_id = as.character(repair_profiles$target_cell_id),
    target_role = as.character(repair_profiles$target_role),
    screening_profile_id = as.character(repair_profiles$screening_profile_id),
    parent_profile_id = as.character(repair_profiles$parent_profile_id),
    candidate_id = as.character(repair_profiles$candidate_id),
    comparison_role = as.character(repair_profiles$comparison_role),
    reservoir_replicate = 2L,
    seed = as.integer(repair_profiles$seed),
    launch_phase = "seed_contract_repair",
    stringsAsFactors = FALSE
  )
  list(
    profiles = repair_profiles,
    assignments = assignments,
    validity = validity,
    excluded = validity[!validity$mechanically_valid, , drop = FALSE]
  )
}

qdesn_arsr1_assign_sampler_seeds <- function(grid) {
  out <- as.data.frame(grid, stringsAsFactors = FALSE)
  cells <- sort(unique(as.character(out$target_cell_id)))
  sources <- sort(unique(as.character(out$source_scenario)))
  cell_index <- match(as.character(out$target_cell_id), cells)
  source_index <- match(as.character(out$source_scenario), sources)
  pair_offset <- 100L * cell_index + source_index
  out$mcmc_seed <- as.integer(810000L + pair_offset)
  out$mcmc_rng_seed <- as.integer(820000L + pair_offset)
  out$vb_warm_start_seed <- as.integer(830000L + pair_offset)
  out$synthesis_seed <- as.integer(840000L + pair_offset)
  out$sampler_pair_id <- paste(out$target_cell_id, out$source_scenario, sep = "::")
  out
}

qdesn_arsr1_seed_contract_audit <- function(grid, profiles, stop_on_fail = TRUE) {
  profile_seed <- stats::setNames(as.integer(profiles$seed), as.character(profiles$screening_profile_id))
  expected <- unname(profile_seed[as.character(grid$screening_profile_id)])
  out <- data.frame(
    root_id = as.character(grid$root_id),
    screening_profile_id = as.character(grid$screening_profile_id),
    target_cell_id = as.character(grid$target_cell_id),
    source_scenario = as.character(grid$source_scenario),
    comparison_role = as.character(grid$comparison_role),
    run_seed = as.integer(grid$seed),
    expected_desn_seed = as.integer(expected),
    observed_desn_seed = as.integer(grid$desn_seed),
    mcmc_seed = as.integer(grid$mcmc_seed),
    mcmc_rng_seed = as.integer(grid$mcmc_rng_seed),
    vb_warm_start_seed = as.integer(grid$vb_warm_start_seed),
    synthesis_seed = as.integer(grid$synthesis_seed),
    sampler_pair_id = as.character(grid$sampler_pair_id),
    stringsAsFactors = FALSE
  )
  out$profile_resolved <- is.finite(out$expected_desn_seed)
  out$desn_seed_match <- out$profile_resolved & out$observed_desn_seed == out$expected_desn_seed
  seed_cols <- c("mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed")
  out$sampler_seeds_finite <- apply(out[, seed_cols, drop = FALSE], 1L, function(x) all(is.finite(as.numeric(x))))
  pair_consistent <- vapply(split(seq_len(nrow(out)), out$sampler_pair_id), function(idx) {
    all(vapply(seed_cols, function(nm) length(unique(out[[nm]][idx])) == 1L, logical(1L)))
  }, logical(1L))
  out$sampler_pair_consistent <- unname(pair_consistent[out$sampler_pair_id])
  out$status <- ifelse(
    out$profile_resolved & out$desn_seed_match & out$sampler_seeds_finite & out$sampler_pair_consistent,
    "PASS", "FAIL"
  )
  if (isTRUE(stop_on_fail) && any(out$status != "PASS")) {
    stop(sprintf("Seed contract failed for %d repair-grid row(s).", sum(out$status != "PASS")), call. = FALSE)
  }
  out
}

qdesn_arsr1_validate_replicate_separation <- function(profiles, stop_on_fail = TRUE) {
  candidate_profiles <- profiles[as.character(profiles$comparison_role %||% "candidate") == "candidate", , drop = FALSE]
  groups <- split(seq_len(nrow(candidate_profiles)), as.character(candidate_profiles$candidate_id))
  rows <- lapply(groups, function(idx) {
    x <- candidate_profiles[idx, , drop = FALSE]
    data.frame(
      candidate_id = as.character(x$candidate_id[[1L]]),
      target_cell_id = as.character(x$target_cell_id[[1L]]),
      n_profiles = nrow(x),
      n_distinct_seeds = length(unique(as.integer(x$seed))),
      seeds = paste(sort(unique(as.integer(x$seed))), collapse = ";"),
      status = if (nrow(x) >= 2L && length(unique(as.integer(x$seed))) >= 2L) "PASS" else "FAIL",
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (isTRUE(stop_on_fail) && any(out$status != "PASS")) {
    stop("Candidate reservoir replicates are not seed-separated.", call. = FALSE)
  }
  out
}
