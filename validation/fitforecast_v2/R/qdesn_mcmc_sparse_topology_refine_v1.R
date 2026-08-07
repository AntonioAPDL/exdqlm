`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_strv1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_strv1_target_cells <- function() {
  c("al_normal_t0p25", "exal_normal_t0p25")
}

qdesn_strv1_interaction_design <- function(likelihood_target) {
  points <- switch(
    as.character(likelihood_target),
    al = data.frame(
      alpha = c(0.05, 0.10, 0.20, 0.40, 0.60, 0.80),
      rho = c(0.35, 0.70, 0.90, 0.35, 0.70, 0.90)
    ),
    exal = data.frame(
      alpha = c(0.55, 0.65, 0.70, 0.75, 0.80, 0.85),
      rho = c(0.35, 0.70, 0.90, 0.35, 0.70, 0.90)
    ),
    stop(sprintf("No sparse-topology design for '%s'.", likelihood_target),
         call. = FALSE)
  )
  points$point_index <- seq_len(nrow(points))
  points$point_id <- sprintf("p%02d", points$point_index)
  points
}

qdesn_strv1_topology_classes <- function() {
  data.frame(
    topology_class = c("w01", "w02", "w03"),
    recurrent_edges_target = 1:3,
    pi_w = (1:3) / 36,
    pi_in = 1 / 12,
    stringsAsFactors = FALSE
  )
}

.qdesn_strv1_load_dependencies <- function(repo_root = NULL) {
  if (is.null(repo_root)) {
    repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                               winslash = "/", mustWork = TRUE)
  }
  if (!exists(".qdesn_arv1_build_d1_reservoir", mode = "function")) {
    source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                     "qdesn_alpha_rho_topology_v1.R"))
  }
  if (!exists("qdesn_hacv1_authority", mode = "function")) {
    source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                     "qdesn_mcmc_highalpha_cellwise_v1.R"))
  }
  invisible(repo_root)
}

qdesn_strv1_authority <- function(interface_path, repo_root = NULL) {
  .qdesn_strv1_load_dependencies(repo_root)
  authority <- qdesn_hacv1_authority(interface_path)
  targets <- qdesn_strv1_target_cells()
  authority$targets <- authority$targets[
    authority$targets$target_cell_id %in% targets, , drop = FALSE
  ]
  authority$parents <- authority$parents[
    authority$parents$target_cell_id %in% targets, , drop = FALSE
  ]
  authority$metric_sources <- authority$metric_sources[
    authority$metric_sources$target_cell_id %in% targets, , drop = FALSE
  ]
  authority$parents <- authority$parents[
    match(targets, authority$parents$target_cell_id), , drop = FALSE
  ]
  structural <- c("D", "n_each", "m", "rho", "pi_w", "pi_in", "rhs_tau0",
                  "readout_y_lags", "reservoir_lags")
  if (nrow(authority$parents) != 2L || anyNA(authority$parents$target_cell_id) ||
      any(vapply(structural, function(nm) {
        length(unique(authority$parents[[nm]])) != 1L
      }, logical(1L))) ||
      !all(authority$parents$target_metrics == "forecast_qtrue_mae_H1000")) {
    stop("The v2 authority does not contain the two expected coherent target parents.",
         call. = FALSE)
  }
  authority
}

.qdesn_strv1_topology_signature <- function(n, m, alpha, rho, pi_w, pi_in, seed) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required.", call. = FALSE)
  }
  reservoir <- .qdesn_arv1_build_d1_reservoir(
    n = n, m = m, alpha = alpha, rho = rho,
    pi_w = pi_w, pi_in = pi_in, seed = seed
  )
  W <- reservoir$W
  Win <- reservoir$Win
  dynamic_cols <- if (ncol(Win) > 1L) 2:ncol(Win) else integer()
  data.frame(
    seed = as.integer(seed), alpha = as.numeric(alpha), rho = as.numeric(rho),
    recurrent_nnz = sum(W != 0), input_nnz = sum(Win != 0),
    dynamic_input_nnz = if (length(dynamic_cols)) {
      sum(Win[, dynamic_cols, drop = FALSE] != 0)
    } else 0L,
    recurrent_mask_sha256 = digest::digest(W != 0, algo = "sha256"),
    input_mask_sha256 = digest::digest(Win != 0, algo = "sha256"),
    stringsAsFactors = FALSE
  )
}

qdesn_strv1_select_topology_seeds <- function(n = 6L, m = 1L,
                                               start_seed = 910001L,
                                               seeds_per_class = 2L,
                                               max_search = 100000L) {
  classes <- qdesn_strv1_topology_classes()
  all_points <- unique(rbind(
    data.frame(alpha = 0.00075, rho = 0.35),
    qdesn_strv1_interaction_design("al")[, c("alpha", "rho")],
    qdesn_strv1_interaction_design("exal")[, c("alpha", "rho")]
  ))
  selected <- list()
  audit <- list()
  for (class_i in seq_len(nrow(classes))) {
    class <- classes[class_i, , drop = FALSE]
    found <- 0L
    for (offset in 0:(as.integer(max_search) - 1L)) {
      seed <- as.integer(start_seed + (class_i - 1L) * max_search + offset)
      signatures <- do.call(rbind, lapply(seq_len(nrow(all_points)), function(i) {
        .qdesn_strv1_topology_signature(
          n, m, all_points$alpha[[i]], all_points$rho[[i]],
          class$pi_w[[1L]], class$pi_in[[1L]], seed
        )
      }))
      valid <- all(signatures$recurrent_nnz == class$recurrent_edges_target[[1L]]) &&
        all(signatures$dynamic_input_nnz >= 1L) &&
        length(unique(signatures$recurrent_mask_sha256)) == 1L &&
        length(unique(signatures$input_mask_sha256)) == 1L
      audit[[length(audit) + 1L]] <- data.frame(
        topology_class = class$topology_class[[1L]], seed = seed,
        recurrent_edges_target = class$recurrent_edges_target[[1L]],
        recurrent_nnz_min = min(signatures$recurrent_nnz),
        recurrent_nnz_max = max(signatures$recurrent_nnz),
        dynamic_input_nnz_min = min(signatures$dynamic_input_nnz),
        masks_invariant = length(unique(signatures$recurrent_mask_sha256)) == 1L &&
          length(unique(signatures$input_mask_sha256)) == 1L,
        selection_valid = valid, stringsAsFactors = FALSE
      )
      if (valid) {
        found <- found + 1L
        selected[[length(selected) + 1L]] <- data.frame(
          topology_class = class$topology_class[[1L]],
          recurrent_edges_target = class$recurrent_edges_target[[1L]],
          pi_w = class$pi_w[[1L]], pi_in = class$pi_in[[1L]],
          seed_rank = found, seed = seed,
          recurrent_mask_sha256 = signatures$recurrent_mask_sha256[[1L]],
          input_mask_sha256 = signatures$input_mask_sha256[[1L]],
          dynamic_input_nnz = signatures$dynamic_input_nnz[[1L]],
          selection_rule = paste(
            "first_two_outcome_blind_seeds_per_exact_edge_class_with_dynamic_input",
            "and_alpha_rho_invariant_masks", sep = "_"
          ), stringsAsFactors = FALSE
        )
        if (found == seeds_per_class) break
      }
    }
    if (found != seeds_per_class) {
      stop(sprintf("Found %d/%d valid seeds for %s.", found, seeds_per_class,
                   class$topology_class[[1L]]), call. = FALSE)
    }
  }
  list(selected = do.call(rbind, selected), search_audit = do.call(rbind, audit),
       evaluated_points = all_points)
}

.qdesn_strv1_profile <- function(parent, topology, alpha, rho,
                                  comparison_role, point_id) {
  likelihood <- as.character(parent$likelihood_target[[1L]])
  cell <- as.character(parent$target_cell_id[[1L]])
  design_id <- sprintf(
    "strv1_%s_%s_seed%d_%s", likelihood, topology$topology_class[[1L]],
    topology$seed[[1L]], point_id
  )
  data.frame(
    screening_profile_id = design_id,
    screening_stage = "mcmc_sparse_topology_refine_v1",
    screening_wave = "sparse_topology_refine_2026_08_07",
    profile_role = comparison_role,
    enabled = TRUE,
    D = 1L, n_each = 6L,
    n_tilde_each = as.integer(parent$n_tilde_each[[1L]]), m = 1L,
    alpha = as.numeric(alpha), rho = as.numeric(rho),
    pi_w = as.numeric(topology$pi_w[[1L]]),
    pi_in = as.numeric(topology$pi_in[[1L]]),
    washout = as.integer(parent$washout[[1L]]),
    add_bias = as.logical(parent$add_bias[[1L]]),
    seed = as.integer(topology$seed[[1L]]),
    readout_y_lags = as.integer(parent$readout_y_lags[[1L]]),
    reservoir_lags = as.integer(parent$reservoir_lags[[1L]]),
    rhs_tau0 = as.numeric(parent$rhs_tau0[[1L]]),
    dimension_p_estimate = as.integer(parent$dimension_p_estimate[[1L]]),
    p_over_n_tt500 = as.numeric(parent$p_over_n_tt500[[1L]]),
    x_feature_count = 5L,
    target_cells = paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]),
                         likelihood, sep = ":"),
    target_cell_id = cell,
    launch_phase = "full_budget_mechanism_refinement",
    likelihood_target = likelihood,
    target_family = as.character(parent$family[[1L]]),
    target_tau = as.numeric(parent$tau[[1L]]),
    target_metrics = as.character(parent$target_metrics[[1L]]),
    parent_profile_id = as.character(parent$parent_profile_id[[1L]]),
    source_screening_profile_id = as.character(parent$parent_profile_id[[1L]]),
    parent_candidate_id = as.character(parent$parent_candidate_id[[1L]]),
    parent_fit_request_path = as.character(parent$parent_fit_request_path[[1L]]),
    candidate_id = design_id, arm_code = point_id,
    confirmation_design_id = design_id,
    selection_tier = if (comparison_role == "candidate") "candidate" else "control",
    selection_role = if (comparison_role == "candidate") {
      "sparse_alpha_rho_interaction"
    } else "exact_same_topology_parent",
    design_role = comparison_role,
    topology_search_mode = "outcome_blind_exact_sparse_edge_class",
    topology_mode = "active_recurrent_and_dynamic_input",
    point_index = if (comparison_role == "candidate") {
      as.integer(sub("p", "", point_id))
    } else 0L,
    reservoir_replicate = as.integer(topology$seed_rank[[1L]]),
    paired_reservoir_seed = as.integer(topology$seed[[1L]]),
    comparison_role = comparison_role,
    seed_selection_rule = as.character(topology$selection_rule[[1L]]),
    topology_contract_version = "exact_recurrent_edges_dynamic_input_v1",
    topology_class = as.character(topology$topology_class[[1L]]),
    recurrent_edges_target = as.integer(topology$recurrent_edges_target[[1L]]),
    candidate_source = "v2_authority_sparse_recurrent_mechanism_refinement",
    selection_reason = paste(
      "Hold D=1,n=6,m=1,tau0=3e-4 and readout fixed; activate rho through",
      "one-to-three exact recurrent edges and evaluate purposeful alpha/rho interactions."
    ), stringsAsFactors = FALSE
  )
}

.qdesn_strv1_expand_sampler_replicates <- function(base, n_replicates = 2L) {
  rows <- lapply(seq_len(nrow(base)), function(i) {
    do.call(rbind, lapply(seq_len(n_replicates), function(rep_id) {
      row <- base[i, , drop = FALSE]
      row$base_design_id <- row$screening_profile_id
      row$sampler_replicate <- rep_id
      row$screening_profile_id <- sprintf("%s_s%02d", row$base_design_id, rep_id)
      row
    }))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

qdesn_strv1_build_plan <- function(interface_path, repo_root = NULL) {
  authority <- qdesn_strv1_authority(interface_path, repo_root)
  topology <- qdesn_strv1_select_topology_seeds()
  base <- list()
  for (parent_i in seq_len(nrow(authority$parents))) {
    parent <- authority$parents[parent_i, , drop = FALSE]
    design <- qdesn_strv1_interaction_design(parent$likelihood_target[[1L]])
    for (topology_i in seq_len(nrow(topology$selected))) {
      tp <- topology$selected[topology_i, , drop = FALSE]
      base[[length(base) + 1L]] <- .qdesn_strv1_profile(
        parent, tp, 0.00075, 0.35, "matched_sparse_parent", "parent"
      )
      for (point_i in seq_len(nrow(design))) {
        base[[length(base) + 1L]] <- .qdesn_strv1_profile(
          parent, tp, design$alpha[[point_i]], design$rho[[point_i]],
          "candidate", design$point_id[[point_i]]
        )
      }
    }
  }
  base <- do.call(rbind, base)
  profiles <- .qdesn_strv1_expand_sampler_replicates(base, 2L)
  profiles$control_key <- paste(profiles$target_cell_id,
                                profiles$topology_class, profiles$seed, sep = "::")
  profiles$sampler_pair_id <- paste(profiles$control_key,
                                    sprintf("s%02d", profiles$sampler_replicate), sep = "::")
  pair_levels <- sort(unique(profiles$sampler_pair_id))
  pair_index <- match(profiles$sampler_pair_id, pair_levels)
  profiles$mcmc_seed <- as.integer(961000L + pair_index)
  profiles$mcmc_rng_seed <- as.integer(962000L + pair_index)
  profiles$vb_warm_start_seed <- as.integer(963000L + pair_index)
  profiles$synthesis_seed <- as.integer(964000L + pair_index)

  parents <- profiles[profiles$comparison_role == "matched_sparse_parent", , drop = FALSE]
  candidates <- profiles[profiles$comparison_role == "candidate", , drop = FALSE]
  parent_index <- match(candidates$sampler_pair_id, parents$sampler_pair_id)
  if (anyNA(parent_index)) stop("A candidate is missing its matched sparse parent.", call. = FALSE)
  pair_map <- data.frame(
    pair_id = paste(candidates$screening_profile_id,
                    parents$screening_profile_id[parent_index], sep = "::vs::"),
    target_cell_id = candidates$target_cell_id,
    likelihood_target = candidates$likelihood_target,
    confirmation_design_id = candidates$base_design_id,
    topology_class = candidates$topology_class,
    desn_seed = candidates$seed,
    sampler_replicate = candidates$sampler_replicate,
    sampler_pair_id = candidates$sampler_pair_id,
    candidate_profile_id = candidates$screening_profile_id,
    parent_profile_id = parents$screening_profile_id[parent_index],
    stringsAsFactors = FALSE
  )
  assignments <- data.frame(
    assignment_id = sprintf("strv1_%03d", seq_len(nrow(profiles))),
    family = profiles$target_family, tau = profiles$target_tau,
    likelihood_target = profiles$likelihood_target,
    target_cell_id = profiles$target_cell_id,
    target_metrics = profiles$target_metrics,
    screening_profile_id = profiles$screening_profile_id,
    comparison_role = profiles$comparison_role,
    topology_class = profiles$topology_class,
    paired_reservoir_seed = profiles$seed,
    sampler_replicate = profiles$sampler_replicate,
    sampler_pair_id = profiles$sampler_pair_id,
    launch_status = "prepared_not_launched", stringsAsFactors = FALSE
  )
  if (nrow(base) != 84L || nrow(profiles) != 168L ||
      sum(profiles$comparison_role == "candidate") != 144L ||
      sum(profiles$comparison_role == "matched_sparse_parent") != 24L ||
      nrow(pair_map) != 144L || anyDuplicated(profiles$screening_profile_id) ||
      anyDuplicated(pair_map$pair_id)) {
    stop("Sparse-topology 168-spec profile contract failed.", call. = FALSE)
  }
  list(authority = authority, topology = topology, base_designs = base,
       profiles = profiles, assignments = assignments, pair_map = pair_map)
}

qdesn_strv1_topology_audit <- function(profiles) {
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    stats <- .qdesn_strv1_topology_signature(
      p$n_each[[1L]], p$m[[1L]], p$alpha[[1L]], p$rho[[1L]],
      p$pi_w[[1L]], p$pi_in[[1L]], p$seed[[1L]]
    )
    cbind(p[, c("screening_profile_id", "target_cell_id", "likelihood_target",
                "comparison_role", "topology_class", "recurrent_edges_target",
                "sampler_replicate", "seed", "alpha", "rho", "pi_w", "pi_in")],
          stats[, c("recurrent_nnz", "input_nnz", "dynamic_input_nnz",
                    "recurrent_mask_sha256", "input_mask_sha256")])
  })
  out <- do.call(rbind, rows)
  out$topology_valid <- out$recurrent_nnz == out$recurrent_edges_target &
    out$dynamic_input_nnz >= 1L
  invariant <- vapply(split(seq_len(nrow(out)), paste(
    out$likelihood_target, out$topology_class, out$seed, sep = "::"
  )), function(index) {
    length(unique(out$recurrent_mask_sha256[index])) == 1L &&
      length(unique(out$input_mask_sha256[index])) == 1L
  }, logical(1L))
  if (any(!out$topology_valid) || any(!invariant)) {
    stop("Sparse topology changed across alpha/rho points or violated edge counts.",
         call. = FALSE)
  }
  out
}

qdesn_strv1_assign_execution_seeds <- function(grid, profiles) {
  out <- as.data.frame(grid, stringsAsFactors = FALSE)
  index <- match(out$screening_profile_id, profiles$screening_profile_id)
  if (anyNA(index)) stop("Execution grid contains an unknown sparse profile.", call. = FALSE)
  fields <- c(desn_seed = "seed", mcmc_seed = "mcmc_seed",
              mcmc_rng_seed = "mcmc_rng_seed",
              vb_warm_start_seed = "vb_warm_start_seed",
              synthesis_seed = "synthesis_seed", sampler_pair_id = "sampler_pair_id")
  for (target in names(fields)) out[[target]] <- profiles[[fields[[target]]]][index]
  out
}

qdesn_strv1_seed_contract_audit <- function(grid, profiles, stop_on_fail = TRUE) {
  index <- match(grid$screening_profile_id, profiles$screening_profile_id)
  fields <- c("desn_seed", "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed",
              "synthesis_seed")
  expected <- data.frame(
    desn_seed = profiles$seed[index], mcmc_seed = profiles$mcmc_seed[index],
    mcmc_rng_seed = profiles$mcmc_rng_seed[index],
    vb_warm_start_seed = profiles$vb_warm_start_seed[index],
    synthesis_seed = profiles$synthesis_seed[index]
  )
  match_rows <- vapply(fields, function(field) {
    as.integer(grid[[field]]) == as.integer(expected[[field]])
  }, logical(nrow(grid)))
  audit <- data.frame(
    root_id = grid$root_id, screening_profile_id = grid$screening_profile_id,
    sampler_pair_id = grid$sampler_pair_id,
    comparison_role = grid$comparison_role,
    seed_contract_match = rowSums(match_rows) == length(fields),
    stringsAsFactors = FALSE
  )
  pair_ok <- vapply(split(seq_len(nrow(grid)), grid$sampler_pair_id), function(index) {
    all(vapply(fields[-1L], function(field) {
      length(unique(grid[[field]][index])) == 1L
    }, logical(1L)))
  }, logical(1L))
  audit$pair_seed_consistent <- unname(pair_ok[audit$sampler_pair_id])
  audit$status <- ifelse(audit$seed_contract_match & audit$pair_seed_consistent,
                         "PASS", "FAIL")
  if (stop_on_fail && any(audit$status != "PASS")) {
    stop("Sparse-topology seed contract failed.", call. = FALSE)
  }
  audit
}
