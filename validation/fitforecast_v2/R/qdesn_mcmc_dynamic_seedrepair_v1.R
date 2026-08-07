`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_dsr1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_dsr1_tau_key <- function(x) sprintf("%.8f", as.numeric(x))

qdesn_dsr1_target_cells <- function() {
  c("al_normal_t0p25", "exal_normal_t0p25")
}

qdesn_dsr1_alpha_levels <- function(target_cell_id) {
  switch(
    as.character(target_cell_id),
    al_normal_t0p25 = c(0.40, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 0.99),
    exal_normal_t0p25 = c(0.40, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90, 0.925, 0.95, 0.975, 0.99, 0.995),
    stop(sprintf("No dynamic seed-repair alpha design for %s.", target_cell_id), call. = FALSE)
  )
}

.qdesn_dsr1_repo_root <- function(repo_root = NULL) {
  if (!is.null(repo_root)) return(normalizePath(repo_root, winslash = "/", mustWork = TRUE))
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
}

.qdesn_dsr1_source_dependencies <- function(repo_root = NULL) {
  repo_root <- .qdesn_dsr1_repo_root(repo_root)
  if (!exists(".qdesn_arv1_build_d1_reservoir", mode = "function")) {
    source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"))
  }
  if (!exists("qdesn_hacv1_authority", mode = "function")) {
    source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_mcmc_highalpha_cellwise_v1.R"))
  }
  invisible(repo_root)
}

qdesn_dsr1_authority <- function(interface_path, repo_root = NULL) {
  .qdesn_dsr1_source_dependencies(repo_root)
  authority <- qdesn_hacv1_authority(interface_path)
  cells <- qdesn_dsr1_target_cells()
  authority$targets <- authority$targets[authority$targets$target_cell_id %in% cells, , drop = FALSE]
  authority$parents <- authority$parents[authority$parents$target_cell_id %in% cells, , drop = FALSE]
  authority$metric_sources <- authority$metric_sources[
    authority$metric_sources$target_cell_id %in% cells, , drop = FALSE
  ]
  authority$targets <- authority$targets[match(cells, authority$targets$target_cell_id), , drop = FALSE]
  authority$parents <- authority$parents[match(cells, authority$parents$target_cell_id), , drop = FALSE]
  if (nrow(authority$parents) != 2L || anyNA(authority$parents$target_cell_id)) {
    stop("Could not resolve both frozen Normal p=0.25 MCMC authorities.", call. = FALSE)
  }
  expected_targets <- "forecast_qtrue_mae_H1000"
  if (!all(authority$parents$target_metrics == expected_targets)) {
    stop("Both dynamic seed-repair cells must target forecast H=1000 MAE only.", call. = FALSE)
  }
  authority
}

.qdesn_dsr1_probe_input <- function(n = 700L) {
  t <- seq_len(as.integer(n))
  sin(t / 7) + 0.35 * cos(t / 19) + 0.002 * t
}

qdesn_dsr1_topology_stats <- function(parent, seed, alpha = NULL) {
  .qdesn_dsr1_source_dependencies()
  if (!requireNamespace("digest", quietly = TRUE)) stop("Package 'digest' is required.", call. = FALSE)
  alpha <- as.numeric(alpha %||% parent$alpha[[1L]])
  reservoir <- .qdesn_arv1_build_d1_reservoir(
    n = as.integer(parent$n_each[[1L]]),
    m = as.integer(parent$m[[1L]]),
    alpha = alpha,
    rho = as.numeric(parent$rho[[1L]]),
    pi_w = as.numeric(parent$pi_w[[1L]]),
    pi_in = as.numeric(parent$pi_in[[1L]]),
    seed = as.integer(seed)
  )
  W <- reservoir$W
  Win <- reservoir$Win
  dynamic_cols <- if (ncol(Win) > 1L) seq.int(2L, ncol(Win)) else integer()
  bias_input_nnz <- sum(Win[, 1L, drop = FALSE] != 0)
  dynamic_input_nnz <- if (length(dynamic_cols)) sum(Win[, dynamic_cols, drop = FALSE] != 0) else 0L

  probe <- .qdesn_dsr1_probe_input()
  H <- matrix(0, nrow = length(probe), ncol = nrow(W))
  h <- rep(0, nrow(W))
  for (i in seq_along(probe)) {
    u <- c(1, rep(probe[[i]], ncol(Win) - 1L))
    h <- (1 - alpha) * h + alpha * tanh(as.numeric(W %*% h + Win %*% u))
    H[i, ] <- h
  }
  probe_tail <- H[301:nrow(H), , drop = FALSE]
  list(
    recurrent_nnz = sum(W != 0),
    input_nnz = sum(Win != 0),
    bias_input_nnz = bias_input_nnz,
    dynamic_input_nnz = dynamic_input_nnz,
    recurrent_mask_sha256 = digest::digest(W != 0, algo = "sha256"),
    input_mask_sha256 = digest::digest(Win != 0, algo = "sha256"),
    dynamic_input_mask_sha256 = digest::digest(
      if (length(dynamic_cols)) Win[, dynamic_cols, drop = FALSE] != 0 else logical(),
      algo = "sha256"
    ),
    probe_state_sha256 = digest::digest(round(probe_tail, 12L), algo = "sha256"),
    probe_state_sd = stats::sd(as.numeric(probe_tail)),
    probe_state_range = diff(range(as.numeric(probe_tail)))
  )
}

qdesn_dsr1_select_dynamic_seeds <- function(parent, n_seeds = 3L, max_search = 100000L) {
  n_seeds <- as.integer(n_seeds)
  start <- as.integer(parent$seed[[1L]]) + 900001L
  selected <- list()
  audit <- list()
  for (offset in 0:(as.integer(max_search) - 1L)) {
    seed <- start + offset
    stats <- qdesn_dsr1_topology_stats(parent, seed)
    valid <- stats$dynamic_input_nnz > 0L
    audit[[length(audit) + 1L]] <- data.frame(
      seed = seed,
      recurrent_nnz = stats$recurrent_nnz,
      input_nnz = stats$input_nnz,
      bias_input_nnz = stats$bias_input_nnz,
      dynamic_input_nnz = stats$dynamic_input_nnz,
      selection_valid = valid,
      stringsAsFactors = FALSE
    )
    if (valid) {
      selected[[length(selected) + 1L]] <- data.frame(
        seed_rank = length(selected) + 1L,
        seed = seed,
        selection_rule = "first_three_seeds_at_parent_plus_900001_with_dynamic_input_nnz_gt_zero",
        recurrent_nnz = stats$recurrent_nnz,
        input_nnz = stats$input_nnz,
        bias_input_nnz = stats$bias_input_nnz,
        dynamic_input_nnz = stats$dynamic_input_nnz,
        stringsAsFactors = FALSE
      )
      if (length(selected) == n_seeds) break
    }
  }
  if (length(selected) != n_seeds) {
    stop(sprintf("Found only %d/%d dynamically active seeds.", length(selected), n_seeds), call. = FALSE)
  }
  list(selected = do.call(rbind, selected), search_audit = do.call(rbind, audit))
}

.qdesn_dsr1_alpha_code <- function(alpha) {
  paste0("a", gsub("[.]", "p", sub("0+$", "", sub("[.]0+$", "", sprintf("%.4f", alpha)))))
}

.qdesn_dsr1_profile <- function(parent, alpha, seed, seed_rank, comparison_role, point_index) {
  cell <- as.character(parent$target_cell_id[[1L]])
  arm_code <- switch(
    comparison_role,
    authority_parent = "authority_parent",
    dynamic_parent = "dynamic_parent",
    candidate = paste0("alpha_", .qdesn_dsr1_alpha_code(alpha))
  )
  candidate_id <- sprintf("dsr1_%s_%s", qdesn_dsr1_safe_token(cell), arm_code)
  profile_id <- if (comparison_role == "authority_parent") {
    candidate_id
  } else {
    sprintf("%s_r%02d", candidate_id, as.integer(seed_rank))
  }
  data.frame(
    screening_profile_id = profile_id,
    screening_stage = "mcmc_dynamic_seedrepair_v1",
    screening_wave = "dynamic_seedrepair_2026_08_07",
    profile_role = comparison_role,
    enabled = TRUE,
    D = as.integer(parent$D[[1L]]),
    n_each = as.integer(parent$n_each[[1L]]),
    n_tilde_each = as.integer(parent$n_tilde_each[[1L]]),
    m = as.integer(parent$m[[1L]]),
    alpha = as.numeric(alpha),
    rho = as.numeric(parent$rho[[1L]]),
    pi_w = as.numeric(parent$pi_w[[1L]]),
    pi_in = as.numeric(parent$pi_in[[1L]]),
    washout = as.integer(parent$washout[[1L]]),
    add_bias = as.logical(parent$add_bias[[1L]]),
    seed = as.integer(seed),
    readout_y_lags = as.integer(parent$readout_y_lags[[1L]]),
    reservoir_lags = as.integer(parent$reservoir_lags[[1L]]),
    rhs_tau0 = as.numeric(parent$rhs_tau0[[1L]]),
    dimension_p_estimate = as.integer(parent$dimension_p_estimate[[1L]]),
    p_over_n_tt500 = as.numeric(parent$p_over_n_tt500[[1L]]),
    x_feature_count = 5L,
    target_cells = paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]), parent$likelihood_target[[1L]], sep = ":"),
    target_cell_id = cell,
    launch_phase = "discovery",
    likelihood_target = as.character(parent$likelihood_target[[1L]]),
    target_family = as.character(parent$family[[1L]]),
    target_tau = as.numeric(parent$tau[[1L]]),
    target_metrics = as.character(parent$target_metrics[[1L]]),
    parent_profile_id = as.character(parent$parent_profile_id[[1L]]),
    parent_candidate_id = as.character(parent$parent_candidate_id[[1L]]),
    parent_fit_request_path = as.character(parent$parent_fit_request_path[[1L]]),
    candidate_id = candidate_id,
    arm_code = arm_code,
    design_role = comparison_role,
    topology_search_mode = "dynamic_seed_alpha_only",
    topology_mode = "exact_parent_probabilities_outcome_blind_dynamic_seed",
    point_index = as.integer(point_index),
    reservoir_replicate = as.integer(seed_rank),
    paired_reservoir_seed = as.integer(seed),
    comparison_role = comparison_role,
    seed_selection_rule = if (comparison_role == "authority_parent") {
      "frozen_authoritative_seed"
    } else {
      "first_three_outcome_blind_seeds_with_dynamic_input_nnz_gt_zero"
    },
    topology_contract_version = "dynamic_input_excludes_bias_v1",
    candidate_source = "frozen_authority_structure_dynamic_seed_alpha_repair",
    selection_reason = paste(
      "Hold D/n/m/rho/pi_w/pi_in/tau0/readout fixed;",
      "compare alpha on three outcome-blind seeds with a non-bias dynamic input edge."
    ),
    stringsAsFactors = FALSE
  )
}

qdesn_dsr1_build_plan <- function(interface_path, repo_root = NULL) {
  authority <- qdesn_dsr1_authority(interface_path, repo_root)
  parents <- authority$parents
  structural <- c("D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0", "seed")
  if (any(vapply(structural, function(nm) length(unique(parents[[nm]])) != 1L, logical(1L)))) {
    stop("The two target authorities do not share the expected structural parent contract.", call. = FALSE)
  }
  seed_contract <- qdesn_dsr1_select_dynamic_seeds(parents[1L, , drop = FALSE], n_seeds = 3L)
  profiles <- list()
  assignments <- list()
  designs <- list()
  profile_i <- 0L
  design_i <- 0L
  for (parent_i in seq_len(nrow(parents))) {
    parent <- parents[parent_i, , drop = FALSE]
    cell <- parent$target_cell_id[[1L]]
    alpha_levels <- qdesn_dsr1_alpha_levels(cell)
    design_i <- design_i + 1L
    designs[[design_i]] <- data.frame(
      target_cell_id = cell,
      likelihood_target = parent$likelihood_target[[1L]],
      family = parent$family[[1L]],
      tau = parent$tau[[1L]],
      alpha = alpha_levels,
      rho = parent$rho[[1L]],
      D = parent$D[[1L]],
      n_each = parent$n_each[[1L]],
      m = parent$m[[1L]],
      pi_w = parent$pi_w[[1L]],
      pi_in = parent$pi_in[[1L]],
      rhs_tau0 = parent$rhs_tau0[[1L]],
      stringsAsFactors = FALSE
    )

    cell_profiles <- list(.qdesn_dsr1_profile(
      parent, parent$alpha[[1L]], parent$seed[[1L]], 0L, "authority_parent", 0L
    ))
    for (seed_i in seq_len(nrow(seed_contract$selected))) {
      seed <- seed_contract$selected$seed[[seed_i]]
      cell_profiles[[length(cell_profiles) + 1L]] <- .qdesn_dsr1_profile(
        parent, parent$alpha[[1L]], seed, seed_i, "dynamic_parent", 0L
      )
      for (alpha_i in seq_along(alpha_levels)) {
        cell_profiles[[length(cell_profiles) + 1L]] <- .qdesn_dsr1_profile(
          parent, alpha_levels[[alpha_i]], seed, seed_i, "candidate", alpha_i
        )
      }
    }
    cell_profiles <- do.call(rbind, cell_profiles)
    for (i in seq_len(nrow(cell_profiles))) {
      profile_i <- profile_i + 1L
      profiles[[profile_i]] <- cell_profiles[i, , drop = FALSE]
      assignments[[profile_i]] <- data.frame(
        assignment_id = sprintf("dsr1_%04d", profile_i),
        family = cell_profiles$target_family[[i]],
        tau = cell_profiles$target_tau[[i]],
        likelihood_target = cell_profiles$likelihood_target[[i]],
        target_cell_id = cell_profiles$target_cell_id[[i]],
        target_metrics = cell_profiles$target_metrics[[i]],
        launch_phase = "discovery",
        screening_profile_id = cell_profiles$screening_profile_id[[i]],
        parent_profile_id = cell_profiles$parent_profile_id[[i]],
        candidate_id = cell_profiles$candidate_id[[i]],
        arm_code = cell_profiles$arm_code[[i]],
        comparison_role = cell_profiles$comparison_role[[i]],
        reservoir_replicate = cell_profiles$reservoir_replicate[[i]],
        paired_reservoir_seed = cell_profiles$paired_reservoir_seed[[i]],
        stringsAsFactors = FALSE
      )
    }
  }
  profiles <- do.call(rbind, profiles)
  assignments <- do.call(rbind, assignments)
  designs <- do.call(rbind, designs)
  rownames(profiles) <- rownames(assignments) <- rownames(designs) <- NULL
  if (nrow(profiles) != 80L || sum(profiles$comparison_role == "candidate") != 72L ||
      sum(profiles$comparison_role == "dynamic_parent") != 6L ||
      sum(profiles$comparison_role == "authority_parent") != 2L) {
    stop("Dynamic seed-repair profile count contract failed.", call. = FALSE)
  }
  list(
    authority = authority,
    parents = parents,
    metric_sources = authority$metric_sources,
    seed_contract = seed_contract$selected,
    seed_search_audit = seed_contract$search_audit,
    designs = designs,
    profiles = profiles,
    assignments = assignments
  )
}

qdesn_dsr1_topology_audit <- function(profiles) {
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    stats <- qdesn_dsr1_topology_stats(p, p$seed[[1L]], p$alpha[[1L]])
    data.frame(
      screening_profile_id = p$screening_profile_id[[1L]],
      candidate_id = p$candidate_id[[1L]],
      target_cell_id = p$target_cell_id[[1L]],
      comparison_role = p$comparison_role[[1L]],
      reservoir_replicate = p$reservoir_replicate[[1L]],
      seed = p$seed[[1L]],
      alpha = p$alpha[[1L]],
      rho = p$rho[[1L]],
      pi_w = p$pi_w[[1L]],
      pi_in = p$pi_in[[1L]],
      recurrent_nnz = stats$recurrent_nnz,
      input_nnz = stats$input_nnz,
      bias_input_nnz = stats$bias_input_nnz,
      dynamic_input_nnz = stats$dynamic_input_nnz,
      recurrent_mask_sha256 = stats$recurrent_mask_sha256,
      input_mask_sha256 = stats$input_mask_sha256,
      dynamic_input_mask_sha256 = stats$dynamic_input_mask_sha256,
      probe_state_sha256 = stats$probe_state_sha256,
      probe_state_sd = stats$probe_state_sd,
      probe_state_range = stats$probe_state_range,
      dynamic_axis_active = stats$dynamic_input_nnz > 0L,
      candidate_topology_valid = p$comparison_role[[1L]] == "authority_parent" || stats$dynamic_input_nnz > 0L,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  searched <- out[out$comparison_role != "authority_parent", , drop = FALSE]
  if (any(!searched$candidate_topology_valid)) {
    stop("At least one searched profile has no non-bias dynamic input edge.", call. = FALSE)
  }
  topology_key <- paste(searched$target_cell_id, searched$reservoir_replicate, sep = "\r")
  invariant <- vapply(split(seq_len(nrow(searched)), topology_key), function(idx) {
    length(unique(searched$recurrent_mask_sha256[idx])) == 1L &&
      length(unique(searched$input_mask_sha256[idx])) == 1L
  }, logical(1L))
  if (!all(invariant)) stop("Alpha changed a paired topology mask.", call. = FALSE)
  state_unique <- vapply(split(seq_len(nrow(searched)), topology_key), function(idx) {
    length(unique(searched$probe_state_sha256[idx])) == length(idx)
  }, logical(1L))
  if (!all(state_unique)) stop("At least one alpha point is state-inert on the deterministic probe.", call. = FALSE)
  out$topology_invariant_within_seed <- NA
  out$probe_state_unique_within_seed <- NA
  searched_rows <- which(out$comparison_role != "authority_parent")
  out$topology_invariant_within_seed[searched_rows] <- unname(invariant[topology_key])
  out$probe_state_unique_within_seed[searched_rows] <- unname(state_unique[topology_key])
  out
}

qdesn_dsr1_assign_sampler_seeds <- function(grid) {
  out <- as.data.frame(grid, stringsAsFactors = FALSE)
  cells <- sort(unique(as.character(out$target_cell_id)))
  sources <- sort(unique(as.character(out$source_scenario)))
  pair_offset <- 100L * match(as.character(out$target_cell_id), cells) +
    match(as.character(out$source_scenario), sources)
  out$mcmc_seed <- as.integer(910000L + pair_offset)
  out$mcmc_rng_seed <- as.integer(920000L + pair_offset)
  out$vb_warm_start_seed <- as.integer(930000L + pair_offset)
  out$synthesis_seed <- as.integer(940000L + pair_offset)
  out$sampler_pair_id <- paste(out$target_cell_id, out$source_scenario, sep = "::")
  out
}

qdesn_dsr1_seed_execution_audit <- function(grid, profiles, stop_on_fail = TRUE) {
  profile_seed <- stats::setNames(as.integer(profiles$seed), profiles$screening_profile_id)
  expected_desn <- unname(profile_seed[as.character(grid$screening_profile_id)])
  out <- data.frame(
    root_id = as.character(grid$root_id),
    screening_profile_id = as.character(grid$screening_profile_id),
    target_cell_id = as.character(grid$target_cell_id),
    source_scenario = as.character(grid$source_scenario),
    comparison_role = as.character(grid$comparison_role),
    expected_desn_seed = as.integer(expected_desn),
    observed_grid_desn_seed = as.integer(grid$desn_seed),
    mcmc_seed = as.integer(grid$mcmc_seed),
    mcmc_rng_seed = as.integer(grid$mcmc_rng_seed),
    vb_warm_start_seed = as.integer(grid$vb_warm_start_seed),
    synthesis_seed = as.integer(grid$synthesis_seed),
    sampler_pair_id = as.character(grid$sampler_pair_id),
    stringsAsFactors = FALSE
  )
  seed_cols <- c("mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed")
  pair_ok <- vapply(split(seq_len(nrow(out)), out$sampler_pair_id), function(idx) {
    all(vapply(seed_cols, function(nm) length(unique(out[[nm]][idx])) == 1L, logical(1L)))
  }, logical(1L))
  out$desn_seed_match <- out$expected_desn_seed == out$observed_grid_desn_seed
  out$sampler_pair_consistent <- unname(pair_ok[out$sampler_pair_id])
  out$status <- ifelse(out$desn_seed_match & out$sampler_pair_consistent, "PASS", "FAIL")
  if (isTRUE(stop_on_fail) && any(out$status != "PASS")) {
    stop(sprintf("Seed execution contract failed for %d row(s).", sum(out$status != "PASS")), call. = FALSE)
  }
  out
}
