iqcb_v4_schema <- "independent_qdesn_corrected_broad_v4_v1"
iqcb_v4_expected_branch <-
  "validation/independent-qdesn-corrected-broad-v4-20261001"
iqcb_v4_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_corrected_broad_v4",
  "protocol_defaults.yaml"
)

iqcb_v4_read_protocol <- function(repo_root = iqfr_v2_repo_root()) {
  path <- file.path(repo_root, iqcb_v4_protocol_relpath)
  if (!file.exists(path)) stop("Missing corrected-broad v4 protocol: ", path,
                               call. = FALSE)
  yaml::read_yaml(path)
}

iqcb_v4_protocol_checks <- function(protocol = iqcb_v4_read_protocol()) {
  checks <- c(
    protocol_id = identical(
      protocol$protocol$id, "independent_qdesn_corrected_broad_v4"
    ),
    lane = identical(
      protocol$protocol$scientific_lane,
      "independent_single_quantile_qdesn_dqlm_validation"
    ),
    lane_boundaries = !isTRUE(protocol$protocol$article_write_permitted) &&
      !isTRUE(protocol$protocol$shared_validation_merge_permitted) &&
      !isTRUE(protocol$protocol$overleaf_write_permitted),
    complete_surface = identical(as.character(protocol$scope$families),
                                  c("normal", "laplace", "gausmix")) &&
      identical(as.numeric(protocol$scope$quantiles), c(0.05, 0.25, 0.50)) &&
      identical(as.character(protocol$scope$likelihoods), c("al", "exal")),
    internal_split = identical(as.integer(protocol$scope$fit_window$start), 8501L) &&
      identical(as.integer(protocol$scope$fit_window$end), 8750L) &&
      identical(as.integer(protocol$scope$development_window$end), 9000L),
    matched_comparators = identical(
      as.character(protocol$scope$development_comparators),
      c("dqlm_al_vb", "exdqlm_exal_vb",
        "training_empirical_quantile_constant")
    ) && identical(
      as.integer(protocol$scope$expected_development_comparator_jobs), 18L
    ),
    causal_h30 = identical(as.integer(protocol$forecast$horizon), 30L) &&
      isTRUE(protocol$forecast$teacher_forced_between_origins) &&
      isTRUE(protocol$forecast$recursive_within_origin) &&
      !isTRUE(protocol$forecast$future_observations_within_origin) &&
      !isTRUE(protocol$forecast$refit_per_origin),
    search_size = identical(as.integer(protocol$search$structures_per_cell), 8L) &&
      identical(as.integer(protocol$search$tau_arms_per_structure), 2L) &&
      identical(as.integer(protocol$search$expected_cells), 18L) &&
      identical(as.integer(protocol$search$expected_broad_jobs), 288L),
    identity_readout = identical(protocol$search$projection, "identity") &&
      isTRUE(protocol$search$dimensionality_reduction_forbidden) &&
      identical(as.integer(protocol$search$mx), 0L) &&
      !isTRUE(protocol$search$direct_response_lags_in_readout) &&
      !isTRUE(protocol$search$direct_exogenous_lags_in_readout) &&
      !isTRUE(protocol$search$reservoir_lags_in_readout),
    tau_bridge = identical(
      as.numeric(protocol$shrinkage$broad_tau_multipliers), c(1, 3.5)
    ) && identical(as.numeric(protocol$shrinkage$slab_s2), 1) &&
      identical(protocol$shrinkage$parameterization_scale,
                "standardized_response"),
    adaptive_ceiling = identical(as.integer(protocol$adaptive$maximum_jobs), 96L),
    m0_exal = identical(protocol$inference$mcmc$exal_method_id,
                        "m0_v_collapsed_support_logit"),
    gated_compute = !isTRUE(protocol$execution$automatic_adaptive_launch) &&
      !isTRUE(protocol$execution$automatic_mcmc_launch),
    comparator_gate = identical(
      protocol$gates$broad_requires_comparator_decision,
      "PASS_MATCHED_COMPARATORS_COMPLETE"
    ),
    storage_light = isTRUE(protocol$execution$storage_light) &&
      identical(protocol$execution$fitted_model_binary_retention, "none")
  )
  data.frame(check = names(checks), pass = unname(checks),
             stringsAsFactors = FALSE)
}

iqcb_v4_assert_protocol <- function(protocol = iqcb_v4_read_protocol()) {
  checks <- iqcb_v4_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("Corrected-broad v4 protocol checks failed: ",
         paste(checks$check[!checks$pass], collapse = ", "), call. = FALSE)
  }
  invisible(checks)
}

iqcb_v4_verified_csv <- function(path, expected_sha256, role) {
  if (!file.exists(path)) stop(role, " is missing: ", path, call. = FALSE)
  observed <- iqfr_v2_sha256(path)
  if (!identical(observed, as.character(expected_sha256))) {
    stop(role, " hash mismatch: ", path, call. = FALSE)
  }
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

iqcb_v4_design_fields <- c(
  "D", "n", "n_tilde", "m", "alpha", "rho", "center_scale",
  "input_bound", "input_gain", "recurrent_indegree", "input_fanin",
  "interlayer_fanin", "matrix_seed"
)

iqcb_v4_unpack_n <- function(x) {
  iqfr_v2_unpack_integer(as.character(iqfr_v2_scalar(x, "")))
}

iqcb_v4_canonical_signature <- function(row) {
  values <- vapply(iqcb_v4_design_fields, function(field) {
    value <- row[[field]]
    if (is.null(value) || !length(value) || is.na(value[[1L]])) "" else
      format(value[[1L]], scientific = FALSE, trim = TRUE, digits = 15)
  }, character(1L))
  paste(names(values), values, sep = "=", collapse = "|")
}

iqcb_v4_normalize_structure <- function(row, family, role, source_id,
                                        matrix_seed = 920001L) {
  row <- as.data.frame(row[1L, , drop = FALSE], stringsAsFactors = FALSE)
  n <- iqcb_v4_unpack_n(row$n)
  D <- as.integer(row$D[[1L]])
  if (length(n) != D || D < 1L) stop("Malformed candidate layer widths.",
                                     call. = FALSE)
  row$family <- family
  row$D <- D
  row$n <- paste(n, collapse = ";")
  row$n_tilde <- if (D == 1L) "" else paste(head(n, -1L), collapse = ";")
  row$total_states <- sum(n)
  row$readout_dimension <- 1L + sum(n)
  row$m <- as.integer(row$m[[1L]])
  row$alpha <- as.numeric(row$alpha[[1L]])
  row$rho <- as.numeric(row$rho[[1L]])
  row$center_scale <- as.character(row$center_scale[[1L]])
  row$input_bound <- as.character(row$input_bound[[1L]])
  row$input_gain <- as.numeric(row$input_gain[[1L]])
  row$recurrent_indegree <- as.integer(row$recurrent_indegree[[1L]])
  fraction <- suppressWarnings(as.numeric(row$input_fanin_fraction[[1L]]))
  if (!is.finite(fraction) || fraction <= 0) fraction <- 0.25
  row$input_fanin_fraction <- fraction
  input_fanin <- suppressWarnings(as.integer(row$input_fanin[[1L]]))
  if (!is.finite(input_fanin) || input_fanin < 1L) {
    input_fanin <- max(1L, as.integer(round((row$m + 1L) * fraction)))
  }
  row$input_fanin <- input_fanin
  row$interlayer_fanin <- as.integer(row$interlayer_fanin[[1L]])
  row$matrix_seed <- as.integer(matrix_seed)
  row$representation_role <- role
  row$source_candidate_id <- as.character(source_id %||% NA_character_)
  row$generation <- paste0("corrected_broad_v4_", role)
  row$canonical_structure_signature <- iqcb_v4_canonical_signature(row)
  row$structure_signature <- paste(
    iqcb_v4_schema, family, row$canonical_structure_signature, sep = "|"
  )
  row$structure_id <- paste0(
    "iqcb4_", family, "_",
    substr(digest::digest(row$structure_signature, algo = "sha256",
                          serialize = FALSE), 1L, 12L)
  )
  row
}

iqcb_v4_novel_structure <- function(template, family) {
  specs <- list(
    normal = list(D = 5L, n = c(300L, 150L, 300L, 150L, 300L), m = 180L,
                  alpha = 0.72, rho = 0.970, center_scale = "median_mad",
                  input_bound = "tanh_z_over_3", input_gain = 0.03,
                  recurrent_indegree = 20L, input_fanin_fraction = 0.25,
                  interlayer_fanin = 100L),
    laplace = list(D = 4L, n = c(400L, 200L, 400L, 200L), m = 240L,
                   alpha = 0.62, rho = 0.985, center_scale = "mean_sd",
                   input_bound = "none", input_gain = 0.10,
                   recurrent_indegree = 40L, input_fanin_fraction = 0.10,
                   interlayer_fanin = 100L),
    gausmix = list(D = 5L, n = c(200L, 100L, 200L, 100L, 200L), m = 120L,
                   alpha = 0.88, rho = 0.995, center_scale = "median_mad",
                   input_bound = "tanh_z_over_3", input_gain = 0.30,
                   recurrent_indegree = 20L, input_fanin_fraction = 0.50,
                   interlayer_fanin = 50L)
  )[[family]]
  if (is.null(specs)) stop("Unknown family for deterministic v4 design.",
                           call. = FALSE)
  row <- template[1L, , drop = FALSE]
  for (field in setdiff(names(specs), "n")) row[[field]] <- specs[[field]]
  row$n <- paste(specs$n, collapse = ";")
  row$n_tilde <- if (specs$D == 1L) "" else
    paste(head(specs$n, -1L), collapse = ";")
  row$input_fanin <- max(
    1L, as.integer(round((specs$m + 1L) * specs$input_fanin_fraction))
  )
  iqcb_v4_normalize_structure(
    row, family, "deterministic_unseen_design", "predeclared_v4_design"
  )
}

iqcb_v4_copy_sources <- function(v3_run_root, run_root) {
  manifest_path <- file.path(v3_run_root, "source_manifest.csv")
  manifest <- utils::read.csv(manifest_path, check.names = FALSE,
                              stringsAsFactors = FALSE)
  if (nrow(manifest) != 9L || anyDuplicated(paste(manifest$family,
                                                  manifest$tau))) {
    stop("The v3 source manifest is not the expected nine-cell authority.",
         call. = FALSE)
  }
  destination_root <- file.path(run_root, "sources")
  dir.create(destination_root, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(nrow(manifest))) {
    source <- as.character(manifest$frozen_path[[i]])
    expected <- as.character(manifest$frozen_sha256[[i]])
    if (!file.exists(source) || !identical(iqfr_v2_sha256(source), expected)) {
      stop("A v3 frozen source is missing or has drifted: ", source,
           call. = FALSE)
    }
    token <- gsub("[.]", "p", sprintf("%.2f", manifest$tau[[i]]))
    target <- file.path(destination_root, paste0(manifest$family[[i]],
                                                 "_tau_", token, ".csv"))
    if (!file.copy(source, target, overwrite = FALSE, copy.mode = TRUE)) {
      stop("Could not copy frozen source: ", source, call. = FALSE)
    }
    if (!identical(iqfr_v2_sha256(target), expected)) {
      stop("Frozen source changed while copying: ", target, call. = FALSE)
    }
    manifest$frozen_path[[i]] <- normalizePath(target, winslash = "/",
                                                mustWork = TRUE)
  }
  iqfr_v2_write_csv(manifest, file.path(run_root, "source_manifest.csv"))
  manifest
}

iqcb_v4_verify_predecessors <- function(repo_root, v3_run_root,
                                        predecessor_run_root, protocol) {
  v3_files <- c(
    decision = "summaries/forecast_canary_decision.json",
    ranking = "summaries/forecast_canary_cellwise_ranking.csv",
    candidates = "manifests/canary_candidates.csv",
    sources = "source_manifest.csv"
  )
  expected <- c(
    decision = "7a9297f0ae5d25eb2eef738474e6124c6842e2355a6e05ad59291b0ccac36a4e",
    ranking = "7dd3f16fd0acdfb40dec0a46798c59373849550c71c722d79913e9d2c6e83e21",
    candidates = "41a16c1e14bcb0d5ae752d047c99c350cd8743f2ed0f376941e32bef42e859f5",
    sources = "b857a9f414e543111e0c9f4e6ea770f30e92ac9fe092b6b907391dfd6174155d"
  )
  observed <- vapply(v3_files, function(relative) {
    path <- file.path(v3_run_root, relative)
    if (!file.exists(path)) return(NA_character_)
    iqfr_v2_sha256(path)
  }, character(1L))
  if (anyNA(observed) || !identical(unname(observed), unname(expected))) {
    stop("The completed v3 evidence authority is missing or has drifted.",
         call. = FALSE)
  }
  decision <- iqfr_v2_read_json(file.path(v3_run_root, v3_files[["decision"]]))
  if (!identical(as.character(decision$decision),
                 as.character(protocol$gates$required_v3_decision))) {
    stop("The v3 gate does not authorize broad-screen design.", call. = FALSE)
  }
  rhs_path <- file.path(predecessor_run_root, "summaries",
                        "rhs_combined_robust_ranking.csv")
  rhs_sha <- "4d886b6e349ea34a874d65b46bcd4732c354fdb134c27d1d76a5f89b1682067b"
  if (!file.exists(rhs_path) || !identical(iqfr_v2_sha256(rhs_path), rhs_sha)) {
    stop("The frozen RHS ranking authority is missing or has drifted.",
         call. = FALSE)
  }
  list(
    v3_files = normalizePath(file.path(v3_run_root, v3_files), winslash = "/",
                             mustWork = TRUE),
    v3_sha256 = observed,
    rhs_path = normalizePath(rhs_path, winslash = "/", mustWork = TRUE),
    rhs_sha256 = rhs_sha
  )
}

iqcb_v4_structure_bank <- function(repo_root, v3_run_root,
                                   predecessor_run_root,
                                   protocol = iqcb_v4_read_protocol(repo_root)) {
  tracked <- protocol$tracked_authorities
  ridge_path <- file.path(repo_root, tracked$ridge_shortlist$path)
  authority_path <- file.path(repo_root, tracked$current_authority$path)
  ridge <- iqcb_v4_verified_csv(ridge_path, tracked$ridge_shortlist$sha256,
                                "Ridge shortlist")
  authority <- iqcb_v4_verified_csv(authority_path,
                                    tracked$current_authority$sha256,
                                    "Current authority")
  rhs <- iqcb_v4_verified_csv(
    file.path(predecessor_run_root, "summaries",
              "rhs_combined_robust_ranking.csv"),
    "4d886b6e349ea34a874d65b46bcd4732c354fdb134c27d1d76a5f89b1682067b",
    "RHS ranking"
  )
  v3_ranking <- utils::read.csv(
    file.path(v3_run_root, "summaries", "forecast_canary_cellwise_ranking.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  v3_candidates <- utils::read.csv(
    file.path(v3_run_root, "manifests", "canary_candidates.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  historical <- iqcf_v3_authority_candidate_manifest(repo_root)$candidates

  rows <- list()
  audit_rows <- list()
  row_index <- 0L
  audit_index <- 0L
  for (family in as.character(protocol$scope$families)) {
    ridge_family <- ridge[ridge$family == family, , drop = FALSE]
    ridge_family <- ridge_family[order(ridge_family$selection_rank,
                                       ridge_family$robust_score,
                                       ridge_family$structure_id), , drop = FALSE]
    rhs_family <- rhs[rhs$family == family, , drop = FALSE]
    rhs_family <- rhs_family[order(rhs_family$robust_score,
                                   rhs_family$median_forecast_mae,
                                   rhs_family$structure_id), , drop = FALSE]
    rhs_family <- rhs_family[!duplicated(rhs_family$structure_id), , drop = FALSE]
    for (probability in as.numeric(protocol$scope$quantiles)) {
      for (likelihood in as.character(protocol$scope$likelihoods)) {
        selected <- list()
        signatures <- character()
        add <- function(row, role, source_id = NA_character_) {
          if (is.null(row) || !nrow(row)) return(invisible(FALSE))
          normalized <- iqcb_v4_normalize_structure(
            row[1L, , drop = FALSE], family, role, source_id,
            matrix_seed = as.integer(protocol$search$fixed_matrix_seed)
          )
          signature <- normalized$canonical_structure_signature[[1L]]
          audit_index <<- audit_index + 1L
          audit_rows[[audit_index]] <<- data.frame(
            family = family, probability = probability,
            likelihood_family = likelihood, proposed_role = role,
            source_candidate_id = as.character(source_id),
            canonical_structure_signature = signature,
            accepted = !(signature %in% signatures),
            reason = if (signature %in% signatures) "duplicate_structure" else
              "accepted", stringsAsFactors = FALSE
          )
          if (signature %in% signatures) return(invisible(FALSE))
          selected[[length(selected) + 1L]] <<- normalized
          signatures <<- c(signatures, signature)
          invisible(TRUE)
        }

        winner <- v3_ranking[
          v3_ranking$family == family &
            v3_ranking$likelihood_family == likelihood &
            v3_ranking$selection_rank == 1L, , drop = FALSE
        ]
        if (nrow(winner) == 1L) {
          match_row <- v3_candidates[
            v3_candidates$candidate_id == winner$candidate_id[[1L]], ,
            drop = FALSE
          ]
          add(match_row, "corrected_v3_cell_winner", winner$candidate_id[[1L]])
        }
        anchor_ids <- unique(authority$candidate_id[
          authority$family == family & authority$likelihood_family == likelihood &
            abs(authority$tau - probability) < 1e-12
        ])
        if (length(anchor_ids) == 1L) {
          anchor <- historical[historical$candidate_id == anchor_ids[[1L]], ,
                               drop = FALSE]
          add(anchor, "current_article_authority", anchor_ids[[1L]])
        }
        template <- if (nrow(ridge_family)) ridge_family[1L, , drop = FALSE] else
          rhs_family[1L, , drop = FALSE]
        novel <- iqcb_v4_novel_structure(template, family)
        add(novel, "deterministic_unseen_design", "predeclared_v4_design")
        add(ridge_family[1L, , drop = FALSE], "ridge_forecast_best",
            ridge_family$structure_id[[1L]])
        high_memory <- ridge_family[ridge_family$memory_stratum == "high_memory", ,
                                    drop = FALSE]
        if (nrow(high_memory)) add(high_memory[1L, , drop = FALSE],
                                   "ridge_high_memory",
                                   high_memory$structure_id[[1L]])
        long_lag <- ridge_family[ridge_family$lag_stratum == "long", , drop = FALSE]
        if (nrow(long_lag)) add(long_lag[1L, , drop = FALSE], "ridge_long_lag",
                               long_lag$structure_id[[1L]])
        add(rhs_family[1L, , drop = FALSE], "rhs_forecast_best",
            rhs_family$structure_id[[1L]])
        dynamic_rhs <- rhs_family[rhs_family$alpha >= 0.4 & rhs_family$rho >= 0.8,
                                  , drop = FALSE]
        if (nrow(dynamic_rhs)) add(dynamic_rhs[1L, , drop = FALSE],
                                   "rhs_high_memory",
                                   dynamic_rhs$structure_id[[1L]])
        if (!any(grepl("^rhs", vapply(selected, function(x) {
          as.character(x$representation_role[[1L]])
        }, character(1L))))) {
          for (rhs_index in seq_len(nrow(rhs_family))) {
            if (add(rhs_family[rhs_index, , drop = FALSE],
                    paste0("rhs_diverse_required_", rhs_index),
                    rhs_family$structure_id[[rhs_index]])) break
          }
        }
        fill <- iqcf_v3_bind_rows(list(ridge_family, rhs_family))
        if (nrow(fill)) {
          for (i in seq_len(nrow(fill))) {
            if (length(selected) >= as.integer(protocol$search$structures_per_cell))
              break
            prefix <- if (i <= nrow(ridge_family)) "ridge_diverse_fill" else
              "rhs_diverse_fill"
            add(fill[i, , drop = FALSE], paste0(prefix, "_", i),
                as.character(fill$structure_id[[i]]))
          }
        }
        expected <- as.integer(protocol$search$structures_per_cell)
        if (length(selected) != expected) {
          stop(sprintf("Only %d distinct structures were available for %s/%.2f/%s.",
                       length(selected), family, probability, likelihood),
               call. = FALSE)
        }
        for (rank in seq_along(selected)) {
          row_index <- row_index + 1L
          row <- selected[[rank]]
          row$probability <- probability
          row$likelihood_family <- likelihood
          row$structure_rank <- rank
          row$cell_id <- sprintf("%s__%s__p%03d", family, likelihood,
                                 as.integer(round(100 * probability)))
          row$broad_structure_id <- paste0(
            row$cell_id, "__s", sprintf("%02d", rank), "__", row$structure_id
          )
          rows[[row_index]] <- row
        }
      }
    }
  }
  bank <- iqcf_v3_bind_rows(rows)
  audit <- iqcf_v3_bind_rows(audit_rows)
  keep <- c(
    "cell_id", "family", "probability", "likelihood_family",
    "structure_rank", "representation_role", "broad_structure_id",
    "source_candidate_id", "structure_id", "structure_signature",
    "canonical_structure_signature", "generation", "D", "n", "n_tilde",
    "total_states", "readout_dimension", "m", "alpha", "rho",
    "center_scale", "input_bound", "input_gain", "recurrent_indegree",
    "input_fanin_fraction", "input_fanin", "interlayer_fanin", "matrix_seed"
  )
  bank <- bank[keep]
  expected_rows <- as.integer(protocol$search$expected_cells) *
    as.integer(protocol$search$structures_per_cell)
  cell_counts <- table(bank$cell_id)
  required_roles <- vapply(split(bank$representation_role, bank$cell_id),
                           function(x) {
    any(grepl("^ridge", x)) && any(grepl("^rhs", x)) &&
      "deterministic_unseen_design" %in% x &&
      "corrected_v3_cell_winner" %in% x
  }, logical(1L))
  checks <- c(
    rows = nrow(bank) == expected_rows,
    cells = length(cell_counts) == 18L,
    cell_counts = all(cell_counts == 8L),
    distinct_within_cell = !any(duplicated(
      bank[c("cell_id", "canonical_structure_signature")]
    )),
    fixed_seed = all(
      bank$matrix_seed == as.integer(protocol$search$fixed_matrix_seed)
    ),
    required_source_roles = all(required_roles)
  )
  if (any(!checks)) {
    stop("The v4 structure-bank diversity contract failed: ",
         paste(names(checks)[!checks], collapse = ", "), call. = FALSE)
  }
  list(bank = bank, audit = audit)
}

iqcb_v4_candidates <- function(structure_bank, source_manifest, protocol) {
  rows <- list()
  k <- 0L
  fit_start <- as.integer(protocol$scope$fit_window$start)
  fit_end <- as.integer(protocol$scope$fit_window$end)
  multipliers <- as.numeric(protocol$shrinkage$broad_tau_multipliers)
  labels <- as.character(protocol$shrinkage$broad_tau_labels)
  for (i in seq_len(nrow(structure_bank))) {
    structure <- structure_bank[i, , drop = FALSE]
    source_row <- source_manifest[
      source_manifest$family == structure$family[[1L]] &
        abs(source_manifest$tau - structure$probability[[1L]]) < 1e-12,
      , drop = FALSE
    ]
    if (nrow(source_row) != 1L) stop("Broad source lookup failed.", call. = FALSE)
    source <- iqfr_v2_source_rows(source_row$frozen_path[[1L]])
    y_fit <- source$y[source$t >= fit_start & source$t <= fit_end]
    response_scale <- stats::sd(y_fit)
    shrinkable <- as.integer(structure$readout_dimension[[1L]]) - 1L
    target_nonzero <- max(1L, min(shrinkable - 1L, as.integer(round(
      as.numeric(protocol$shrinkage$target_nonzero_fraction) * shrinkable
    ))))
    tau_reference_source <- iqcf_v3_tau0_reference(
      structure$readout_dimension[[1L]], length(y_fit), response_scale,
      target_nonzero
    )
    tau_reference <- tau_reference_source / response_scale
    for (arm in seq_along(multipliers)) {
      k <- k + 1L
      row <- structure
      row$tau_arm <- labels[[arm]]
      row$tau0_multiplier <- multipliers[[arm]]
      row$tau0_reference <- tau_reference
      row$tau0_reference_source_scale <- tau_reference_source
      row$rhs_tau0 <- tau_reference * multipliers[[arm]]
      row$rhs_tau0_source_scale <- tau_reference_source * multipliers[[arm]]
      row$target_nonzero <- target_nonzero
      row$effective_sample_size <- length(y_fit)
      row$sigma_reference_source_scale <- response_scale
      row$response_scale <- response_scale
      row$candidate_signature <- paste(
        iqcb_v4_schema, row$cell_id[[1L]],
        row$canonical_structure_signature[[1L]],
        format(row$tau0_multiplier[[1L]], scientific = TRUE, digits = 16),
        sep = "|"
      )
      row$candidate_id <- paste0(
        "iqcb4_", row$family[[1L]], "_", row$likelihood_family[[1L]], "_p",
        sprintf("%03d", as.integer(round(100 * row$probability[[1L]]))), "_",
        substr(digest::digest(row$candidate_signature[[1L]], algo = "sha256",
                              serialize = FALSE), 1L, 12L)
      )
      rows[[k]] <- row
    }
  }
  out <- iqcf_v3_bind_rows(rows)
  expected <- as.integer(protocol$search$expected_broad_jobs)
  if (nrow(out) != expected || anyDuplicated(out$candidate_id) ||
      anyDuplicated(out$candidate_signature) ||
      any(!is.finite(out$rhs_tau0)) || any(out$rhs_tau0 <= 0)) {
    stop("The v4 broad candidate contract failed.", call. = FALSE)
  }
  out
}

iqcb_v4_make_job_config <- function(repo_root, run_root, stage, candidate,
                                    source, protocol, smoke = FALSE,
                                    origin_stride = NULL) {
  job_id <- paste(stage, candidate$candidate_id[[1L]], sep = "__")
  config_path <- file.path(run_root, "configs", stage, paste0(job_id, ".json"))
  result_path <- file.path(run_root, "results", stage, paste0(job_id, ".csv"))
  status_path <- file.path(run_root, "status", stage, paste0(job_id, ".json"))
  prefix <- file.path(run_root, "results", stage, job_id)
  stride <- as.integer(origin_stride %||% protocol$forecast$broad_stride)
  config <- list(
    schema_version = iqcb_v4_schema,
    protocol_id = protocol$protocol$id,
    protocol_path = file.path(repo_root, iqcb_v4_protocol_relpath),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqcb_v4_protocol_relpath)),
    stage = stage, job_id = job_id, repo_root = repo_root,
    run_root = run_root, config_path = config_path,
    result_path = result_path, status_path = status_path,
    metric_draw_path = paste0(prefix, "__metric_draws.csv.gz"),
    origin_lead_path = paste0(prefix, "__origin_lead.csv.gz"),
    lead_profile_path = paste0(prefix, "__lead_profile.csv"),
    origin_profile_path = paste0(prefix, "__origin_profile.csv"),
    origin_block_path = paste0(prefix, "__origin_block_intervals.csv"),
    candidate = as.list(candidate), source = as.list(source),
    probability = as.numeric(candidate$probability[[1L]]),
    likelihood_family = candidate$likelihood_family[[1L]],
    rhs_s2 = as.numeric(protocol$shrinkage$slab_s2),
    fit_end = as.integer(protocol$scope$fit_window$end),
    rollout_end = as.integer(protocol$scope$development_window$end),
    origins = list(
      start = as.integer(protocol$forecast$origin_start),
      end = if (isTRUE(smoke)) as.integer(protocol$forecast$origin_start) + 20L else
        as.integer(protocol$forecast$origin_end),
      stride = if (isTRUE(smoke)) 10L else stride
    ),
    horizon = as.integer(protocol$forecast$horizon),
    outer_draws = if (isTRUE(smoke)) 8L else
      as.integer(protocol$forecast$outer_draws),
    inner_path_grid = if (isTRUE(smoke)) c(32L, 64L) else
      as.integer(protocol$forecast$inner_paths),
    include_mean_readout_state = isTRUE(smoke),
    seed = iqfr_v2_seed(protocol$protocol$id, stage, job_id),
    budget = protocol$inference$quantile_vb
  )
  iqfr_v2_write_json(config, config_path)
  data.frame(
    stage = stage, job_id = job_id, cell_id = candidate$cell_id[[1L]],
    family = candidate$family[[1L]], probability = candidate$probability[[1L]],
    likelihood_family = candidate$likelihood_family[[1L]],
    representation_role = candidate$representation_role[[1L]],
    candidate_id = candidate$candidate_id[[1L]],
    structure_id = candidate$structure_id[[1L]],
    tau_arm = candidate$tau_arm[[1L]],
    tau0_multiplier = candidate$tau0_multiplier[[1L]],
    rhs_tau0 = candidate$rhs_tau0[[1L]],
    rhs_tau0_source_scale = candidate$rhs_tau0_source_scale[[1L]],
    rhs_s2 = as.numeric(protocol$shrinkage$slab_s2),
    config_path = config_path, config_sha256 = iqfr_v2_sha256(config_path),
    result_path = result_path, status_path = status_path,
    stringsAsFactors = FALSE
  )
}

iqcb_v4_comparator_input_fields <- c(
  "series_wide_path", "true_quantile_grid_path", "sim_output_path", "meta_path"
)

iqcb_v4_comparator_source_equality <- function(registry, sources) {
  cells <- unique(registry[c("family", "tau")])
  rows <- lapply(seq_len(nrow(cells)), function(i) {
    family <- as.character(cells$family[[i]])
    probability <- as.numeric(cells$tau[[i]])
    source_row <- sources[
      sources$family == family & abs(sources$tau - probability) < 1e-12,
      , drop = FALSE
    ]
    configs <- registry[
      registry$family == family & abs(registry$tau - probability) < 1e-12,
      , drop = FALSE
    ]
    if (nrow(source_row) != 1L || nrow(configs) != 2L) {
      stop("Matched-comparator source lookup is ambiguous.", call. = FALSE)
    }
    config_objects <- lapply(configs$source_config_path, ffv2_read_json)
    series_paths <- unique(vapply(config_objects, function(x) {
      as.character(x$series_wide_path)
    }, character(1L)))
    truth_paths <- unique(vapply(config_objects, function(x) {
      as.character(x$true_quantile_grid_path)
    }, character(1L)))
    if (length(series_paths) != 1L || length(truth_paths) != 1L) {
      stop("DQLM and exDQLM controls do not share one source.", call. = FALSE)
    }
    frozen <- iqfr_v2_source_rows(source_row$frozen_path[[1L]])
    series <- utils::read.csv(series_paths[[1L]], check.names = FALSE,
                              stringsAsFactors = FALSE)
    series <- series[match(frozen$t, series$t), , drop = FALSE]
    truth <- utils::read.csv(truth_paths[[1L]], check.names = FALSE,
                             stringsAsFactors = FALSE)
    truth <- truth[abs(truth$tau - probability) < 1e-12, , drop = FALSE]
    truth <- truth[match(frozen$t, truth$t), , drop = FALSE]
    source_equal <- nrow(series) == nrow(frozen) && !anyNA(series$t) &&
      isTRUE(all.equal(
        as.matrix(series[c("y", "mu", "q_target", "eps")]),
        as.matrix(frozen[c("y", "mu", "q_target", "eps")]),
        tolerance = 0, check.attributes = FALSE
      ))
    truth_equal <- nrow(truth) == nrow(frozen) && !anyNA(truth$t) &&
      isTRUE(all.equal(as.numeric(truth$q_true), as.numeric(frozen$q_target),
                       tolerance = 0, check.attributes = FALSE))
    if (!source_equal || !truth_equal) {
      stop(sprintf("Matched-comparator DGP mismatch for %s/%.2f.",
                   family, probability), call. = FALSE)
    }
    data.frame(
      family = family, probability = probability,
      rows_compared = nrow(frozen), first_t = min(frozen$t),
      last_t = max(frozen$t), series_exact_equal = source_equal,
      oracle_exact_equal = truth_equal,
      frozen_source_path = source_row$frozen_path[[1L]],
      frozen_source_sha256 = iqfr_v2_sha256(source_row$frozen_path[[1L]]),
      comparator_series_path = series_paths[[1L]],
      comparator_series_sha256 = iqfr_v2_sha256(series_paths[[1L]]),
      comparator_truth_path = truth_paths[[1L]],
      comparator_truth_sha256 = iqfr_v2_sha256(truth_paths[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

iqcb_v4_remap_comparator_config <- function(source, repo_root, run_root,
                                             registry_row, frozen_source_path,
                                             protocol, row_id) {
  model_variant <- as.character(source$model_variant)
  family <- as.character(source$family)
  probability <- as.numeric(source$tau)
  job_id <- sprintf(
    "development_comparator__%s__%s__p%03d",
    model_variant, family, as.integer(round(100 * probability))
  )
  source_root <- normalizePath(source$run_root, winslash = "/", mustWork = TRUE)
  target_root <- file.path(run_root, "comparators", job_id)
  config <- source
  path_fields <- names(config)[grepl("_path$", names(config))]
  for (field in setdiff(path_fields, iqcb_v4_comparator_input_fields)) {
    value <- as.character(config[[field]] %||% "")[[1L]]
    if (nzchar(value) && startsWith(value, paste0(source_root, "/"))) {
      config[[field]] <- file.path(
        target_root, substring(value, nchar(source_root) + 2L)
      )
    }
  }
  config$row_id <- as.integer(row_id)
  config$row_key <- job_id
  config$run_tag <- paste0(basename(run_root), "__", job_id)
  config$run_root <- target_root
  config$repo_root <- repo_root
  config$harness_root <- file.path(repo_root, "validation", "fitforecast_v2")
  config$defaults_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "config",
    "exdqlm_dynamic_fitforecast_v2_defaults.yaml"
  )
  config$row_manifest_path <- file.path(
    run_root, "plans", "development_comparator.csv"
  )
  config$row_config_path <- file.path(
    run_root, "configs", "development_comparator", paste0(job_id, ".json")
  )
  config$status <- "pending"
  config$validation_stage <- "all"
  config$inference <- "vb"
  config$phase <- "development_comparator"
  config$smoke <- FALSE
  config$pilot <- FALSE
  config$fit_size <- 250L
  config$train_start_source_index <- as.integer(protocol$scope$fit_window$start)
  config$train_end_source_index <- as.integer(protocol$scope$fit_window$end)
  config$forecast_origin_source_index <- as.integer(protocol$forecast$origin_start)
  config$forecast_start_source_index <-
    as.integer(protocol$scope$development_window$start)
  config$forecast_end_source_index <- as.integer(protocol$scope$development_window$end)
  config$forecast_horizon_max <- as.integer(protocol$forecast$horizon)
  config$forecast_window_rows <-
    config$forecast_end_source_index - config$forecast_start_source_index + 1L
  config$forecast_protocol <- "rolling_origin_no_refit_state_update"
  config$state_update_method <-
    "deterministic_plugin_filter_train_median_latent_moments"
  config$refit_per_origin <- FALSE
  config$max_lead_configured <- as.integer(protocol$forecast$horizon)
  config$origin_stride <- as.integer(protocol$forecast$broad_stride)
  config$require_full_horizon <- TRUE
  config$package_runtime_mode <- "worktree_load_all"
  config$package_contract <- list(
    version = "1.1.1", authority = "dedicated_source_worktree",
    gamma_update = if (identical(model_variant, "exdqlm")) {
      "structured_ldvb_sigmagam"
    } else "gamma_fixed_al"
  )
  config$budget$stored_draws <- 200L
  config$budget$forecast_draws <- 200L
  config$budget$vb <- list(max_iter = 750L, tol = 1e-4, n_samp = 2000L)
  config$runtime$threads <- 1L
  config$runtime$verbose <- FALSE
  config$runtime$telemetry_sidecar <- FALSE
  config$handoff <- utils::modifyList(
    config$handoff %||% list(),
    list(fit = TRUE, vb_init = FALSE, reuse_vb_init = FALSE,
         prune_fit_on_success = TRUE)
  )
  config$retention <- utils::modifyList(
    config$retention %||% list(),
    list(mode = "compact_success_only", allow_success_binary_payloads = FALSE)
  )
  config$metric_intervals <- utils::modifyList(
    config$metric_intervals %||% list(),
    list(enabled = FALSE, required = FALSE, draws = 0L)
  )
  config$candidate_id <- job_id
  config$screen_stage <- iqcb_v4_schema
  config$candidate_notes <- paste(
    "Frozen DQLM/exDQLM scientific specification refit by VB on 8501:8750",
    "and evaluated on matched teacher-forced H30 origins in 8751:9000."
  )
  config$seed <- iqfr_v2_seed(protocol$protocol$id, "development_comparator",
                              model_variant, family, probability)
  config$chain_id <- 1L
  config$source_authority <- registry_row$source_authority[[1L]]
  config$source_job_id <- registry_row$source_job_id[[1L]]
  config$source_config_path <- frozen_source_path
  config$source_config_sha256 <- iqfr_v2_sha256(frozen_source_path)
  config
}

iqcb_v4_comparator_config_audit <- function(source, target) {
  invariant_fields <- c(
    "model_variant", "family", "tau", "dqlm_ind", "calibration_id",
    "latent_clock_mode", "latent_clock_start_source_index",
    "model_C0_scale", "trend_C0_scale", "seasonal_C0_scale", "df_value",
    "dim_df", "dynamic_model_period", "dynamic_model_harmonics", "models",
    "series_wide_path", "series_wide_sha256", "true_quantile_grid_path",
    "true_quantile_grid_sha256", "sim_output_path", "sim_output_sha256",
    "meta_path", "meta_sha256"
  )
  invariant <- vapply(invariant_fields, function(field) {
    identical(source[[field]], target[[field]])
  }, logical(1L))
  list(invariant = invariant, pass = all(invariant))
}

iqcb_v4_materialize_comparators <- function(repo_root, run_root, sources,
                                             protocol) {
  if (!exists("iqfc_v1_source_registry", mode = "function") ||
      !exists("ffv2_read_json", mode = "function")) {
    stop("Matched-comparator helpers were not loaded.", call. = FALSE)
  }
  registry <- iqfc_v1_source_registry(repo_root)
  registry <- registry[registry$chain_id == 1L, , drop = FALSE]
  expected <- as.integer(protocol$scope$expected_development_comparator_jobs)
  if (nrow(registry) != expected || anyDuplicated(
    registry[c("model_variant", "family", "tau")]
  )) stop("The matched-comparator registry is not the exact 18-cell surface.",
          call. = FALSE)
  equality <- iqcb_v4_comparator_source_equality(registry, sources)
  source_dir <- file.path(run_root, "manifests", "comparator_source_configs")
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- vector("list", nrow(registry))
  audits <- vector("list", nrow(registry))
  for (i in seq_len(nrow(registry))) {
    source_path <- registry$source_config_path[[i]]
    frozen_path <- file.path(
      source_dir,
      sprintf("%s__%s__p%03d.json", registry$model_variant[[i]],
              registry$family[[i]], as.integer(round(100 * registry$tau[[i]])))
    )
    if (!file.copy(source_path, frozen_path, overwrite = FALSE, copy.mode = TRUE) ||
        !identical(iqfr_v2_sha256(frozen_path),
                   registry$source_config_sha256[[i]])) {
      stop("Could not freeze a verified comparator source config.", call. = FALSE)
    }
    source <- ffv2_read_json(frozen_path)
    target <- iqcb_v4_remap_comparator_config(
      source, repo_root, run_root, registry[i, , drop = FALSE], frozen_path,
      protocol, i
    )
    audit <- iqcb_v4_comparator_config_audit(source, target)
    if (!audit$pass) {
      stop("Comparator scientific identity changed: ",
           paste(names(audit$invariant)[!audit$invariant], collapse = ", "),
           call. = FALSE)
    }
    iqfr_v2_write_json(target, target$row_config_path)
    rows[[i]] <- data.frame(
      stage = "development_comparator", job_id = target$row_key,
      model_variant = target$model_variant, family = target$family,
      probability = as.numeric(target$tau),
      likelihood_family = if (target$model_variant == "dqlm") "al" else "exal",
      source_authority = target$source_authority,
      source_job_id = target$source_job_id,
      source_config_path = normalizePath(frozen_path, winslash = "/",
                                         mustWork = TRUE),
      source_config_sha256 = iqfr_v2_sha256(frozen_path),
      config_path = normalizePath(target$row_config_path, winslash = "/",
                                  mustWork = TRUE),
      config_sha256 = iqfr_v2_sha256(target$row_config_path),
      result_path = target$row_metrics_path,
      status_path = target$row_status_path,
      status_format = "ffv2_csv", stringsAsFactors = FALSE
    )
    audits[[i]] <- data.frame(
      job_id = target$row_key,
      scientific_identity_preserved = all(audit$invariant),
      changed_evaluation_contract = TRUE,
      changed_inference_to_vb = TRUE,
      config_contract_pass = audit$pass, stringsAsFactors = FALSE
    )
  }
  plan <- do.call(rbind, rows)
  audit <- do.call(rbind, audits)
  registry_path <- iqfr_v2_write_csv(
    registry, file.path(run_root, "manifests", "comparator_source_registry.csv")
  )
  equality_path <- iqfr_v2_write_csv(
    equality, file.path(run_root, "manifests", "comparator_source_equality.csv")
  )
  audit_path <- iqfr_v2_write_csv(
    audit, file.path(run_root, "manifests", "comparator_config_audit.csv")
  )
  plan_path <- iqfr_v2_write_csv(
    plan, file.path(run_root, "plans", "development_comparator.csv")
  )
  list(plan = plan, registry_path = registry_path,
       equality_path = equality_path, audit_path = audit_path,
       plan_path = plan_path,
       frozen_configs = normalizePath(
         list.files(source_dir, full.names = TRUE), winslash = "/", mustWork = TRUE
       ))
}

iqcb_v4_assert_git <- function(repo_root, allow_dirty = FALSE) {
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                    stdout = TRUE)
  if (!identical(branch, iqcb_v4_expected_branch)) {
    stop("Materialization requires the dedicated corrected-broad v4 branch.",
         call. = FALSE)
  }
  status <- system2(
    "git", c("-C", repo_root, "status", "--porcelain", "--untracked-files=all"),
    stdout = TRUE
  )
  clean <- !length(status)
  if (!clean && !isTRUE(allow_dirty)) {
    stop("Production materialization requires a clean committed worktree.",
         call. = FALSE)
  }
  list(branch = branch, clean = clean, status = status,
       head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                      stdout = TRUE))
}

iqcb_v4_materialize <- function(repo_root, run_root, v3_run_root,
                                predecessor_run_root, allow_dirty = FALSE) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  run_root <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
  v3_run_root <- normalizePath(v3_run_root, winslash = "/", mustWork = TRUE)
  predecessor_run_root <- normalizePath(predecessor_run_root, winslash = "/",
                                        mustWork = TRUE)
  if (dir.exists(run_root) && length(list.files(run_root, all.files = TRUE,
                                                no.. = TRUE))) {
    stop("Refusing to overwrite a nonempty v4 run root.", call. = FALSE)
  }
  protocol <- iqcb_v4_read_protocol(repo_root)
  iqcb_v4_assert_protocol(protocol)
  git <- iqcb_v4_assert_git(repo_root, allow_dirty)
  source_version <- as.character(read.dcf(
    file.path(repo_root, "DESCRIPTION"), fields = "Version"
  )[[1L]])
  if (!identical(source_version, "1.1.1")) {
    stop("Corrected-broad workers require exdqlm 1.1.1 source.", call. = FALSE)
  }
  evidence <- iqcb_v4_verify_predecessors(
    repo_root, v3_run_root, predecessor_run_root, protocol
  )
  stages <- c("operator_smoke", "development_comparator", "broad_screen",
              "adaptive_refinement", "finalist_rescore")
  for (stage in stages) {
    for (prefix in c("configs", "results", "status", "logs")) {
      dir.create(file.path(run_root, prefix, stage), recursive = TRUE,
                 showWarnings = FALSE)
    }
  }
  for (directory in c("manifests", "plans", "sources", "summaries")) {
    dir.create(file.path(run_root, directory), recursive = TRUE,
               showWarnings = FALSE)
  }
  sources <- iqcb_v4_copy_sources(v3_run_root, run_root)
  structure <- iqcb_v4_structure_bank(
    repo_root, v3_run_root, predecessor_run_root, protocol
  )
  candidates <- iqcb_v4_candidates(structure$bank, sources, protocol)
  iqfr_v2_write_csv(structure$bank, file.path(run_root, "manifests",
                                              "broad_structure_bank.csv"))
  iqfr_v2_write_csv(structure$audit, file.path(run_root, "manifests",
                                               "structure_selection_audit.csv"))
  iqfr_v2_write_csv(candidates, file.path(run_root, "manifests",
                                          "broad_candidates.csv"))
  broad_rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - candidate$probability[[1L]]) < 1e-12,
                      , drop = FALSE]
    broad_rows[[i]] <- iqcb_v4_make_job_config(
      repo_root, run_root, "broad_screen", candidate, source, protocol
    )
  }
  broad_plan <- do.call(rbind, broad_rows)
  smoke_pool <- candidates[
    abs(candidates$probability - 0.25) < 1e-12 &
      candidates$tau0_multiplier == 1, , drop = FALSE
  ]
  smoke_candidates <- do.call(rbind, lapply(
    split(smoke_pool, smoke_pool$cell_id),
    function(cell) {
      cell <- cell[order(cell$total_states, cell$m, cell$D,
                         cell$candidate_id), , drop = FALSE]
      cell[1L, , drop = FALSE]
    }
  ))
  smoke_candidates <- smoke_candidates[
    order(smoke_candidates$family, smoke_candidates$likelihood_family),
    , drop = FALSE
  ]
  if (nrow(smoke_candidates) != 6L ||
      any(smoke_candidates$total_states > 100L)) {
    stop("Operator smoke did not resolve to six compact sentinels.",
         call. = FALSE)
  }
  smoke_rows <- vector("list", nrow(smoke_candidates))
  for (i in seq_len(nrow(smoke_candidates))) {
    candidate <- smoke_candidates[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - candidate$probability[[1L]]) < 1e-12,
                      , drop = FALSE]
    smoke_rows[[i]] <- iqcb_v4_make_job_config(
      repo_root, run_root, "operator_smoke", candidate, source, protocol,
      smoke = TRUE
    )
  }
  smoke_plan <- do.call(rbind, smoke_rows)
  iqfr_v2_write_csv(smoke_plan, file.path(run_root, "plans",
                                          "operator_smoke.csv"))
  iqfr_v2_write_csv(broad_plan, file.path(run_root, "plans",
                                          "broad_screen.csv"))
  comparators <- iqcb_v4_materialize_comparators(
    repo_root, run_root, sources, protocol
  )
  environment <- list(
    schema_version = iqcb_v4_schema, branch = git$branch, head = git$head,
    worktree_clean = git$clean, dirty_override_for_dry_run = isTRUE(allow_dirty),
    exdqlm_source_version = source_version,
    worker_runtime_contract = "pkgload_source_1.1.1",
    materializer_installed_version = as.character(utils::packageVersion("exdqlm")),
    R_version = R.version.string,
    OMP_NUM_THREADS = Sys.getenv("OMP_NUM_THREADS", unset = ""),
    OPENBLAS_NUM_THREADS = Sys.getenv("OPENBLAS_NUM_THREADS", unset = ""),
    MKL_NUM_THREADS = Sys.getenv("MKL_NUM_THREADS", unset = ""),
    v3_run_root = v3_run_root, predecessor_run_root = predecessor_run_root,
    predecessor_evidence = evidence,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(environment, file.path(run_root, "manifests",
                                            "environment.json"))
  writeLines(capture.output(sessionInfo()), file.path(run_root, "manifests",
                                                      "session_info.txt"))
  manifest_paths <- c(
    file.path(run_root, "source_manifest.csv"),
    file.path(run_root, "manifests", c(
      "broad_structure_bank.csv", "structure_selection_audit.csv",
      "broad_candidates.csv", "comparator_source_registry.csv",
      "comparator_source_equality.csv", "comparator_config_audit.csv",
      "environment.json", "session_info.txt"
    )),
    file.path(run_root, "plans", c(
      "operator_smoke.csv", "development_comparator.csv", "broad_screen.csv"
    )),
    comparators$frozen_configs
  )
  manifest <- data.frame(
    path = normalizePath(manifest_paths, winslash = "/", mustWork = TRUE),
    bytes = file.info(manifest_paths)$size,
    sha256 = vapply(manifest_paths, iqfr_v2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  iqfr_v2_write_csv(manifest, file.path(run_root, "manifests",
                                        "materialization_manifest.csv"))
  list(protocol = protocol, sources = sources, structure_bank = structure$bank,
       candidates = candidates, smoke_plan = smoke_plan,
       comparator_plan = comparators$plan, broad_plan = broad_plan,
       manifest = manifest)
}

iqcb_v4_status_payload <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(iqfr_v2_read_json(path), error = function(e) NULL)
}

iqcb_v4_status_valid <- function(config_path, status_path) {
  status <- iqcb_v4_status_payload(status_path)
  if (is.null(status) || !identical(toupper(as.character(status$status)),
                                     "SUCCESS") ||
      !identical(as.character(status$config_sha256),
                 iqfr_v2_sha256(config_path))) return(FALSE)
  paths <- unlist(status$artifact_paths, use.names = TRUE)
  hashes <- unlist(status$artifact_sha256, use.names = TRUE)
  length(paths) > 0L && setequal(names(paths), names(hashes)) &&
    all(file.exists(paths)) && all(vapply(names(paths), function(name) {
      identical(iqfr_v2_sha256(paths[[name]]), hashes[[name]])
    }, logical(1L)))
}

iqcb_v4_comparator_status <- function(config_path, status_path) {
  if (!file.exists(status_path)) return("PENDING")
  status <- tryCatch(
    utils::read.csv(status_path, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(status) || !nrow(status) || !"status" %in% names(status)) {
    return("UNKNOWN")
  }
  raw <- tolower(as.character(tail(status$status, 1L)))
  state <- switch(raw, done = "SUCCESS", fit_done = "RUNNING",
                  running = "RUNNING", failed_runtime = "FAILED", "UNKNOWN")
  if (identical(state, "SUCCESS") &&
      !iqcb_v4_comparator_success_valid(config_path)) return("STALE_SUCCESS")
  state
}

iqcb_v4_comparator_success_valid <- function(config_path) {
  if (!file.exists(config_path)) return(FALSE)
  config <- tryCatch(iqfr_v2_read_json(config_path), error = function(e) NULL)
  if (is.null(config)) return(FALSE)
  required <- c(
    config$row_status_path, config$row_metrics_path, config$row_health_path,
    config$fit_path_summary_path, config$forecast_path_summary_path,
    config$forecast_lead_metrics_path, config$artifact_manifest_path,
    config$inference_diagnostics_path
  )
  if (any(!file.exists(required))) return(FALSE)
  status <- tryCatch(utils::read.csv(config$row_status_path,
                                     check.names = FALSE),
                     error = function(e) NULL)
  metrics <- tryCatch(utils::read.csv(config$row_metrics_path,
                                      check.names = FALSE),
                      error = function(e) NULL)
  fit <- tryCatch(utils::read.csv(config$fit_path_summary_path,
                                  check.names = FALSE),
                  error = function(e) NULL)
  forecast <- tryCatch(utils::read.csv(config$forecast_path_summary_path,
                                       check.names = FALSE),
                       error = function(e) NULL)
  if (any(vapply(list(status, metrics, fit, forecast), is.null, logical(1L)))) {
    return(FALSE)
  }
  numeric_fields <- c("fit_q_rmse", "forecast_h1000_q_mae",
                      "forecast_h1000_q_rmse", "forecast_h1000_pinball_mean")
  all(numeric_fields %in% names(metrics)) &&
    identical(tolower(as.character(tail(status$status, 1L))), "done") &&
    nrow(fit) == 250L && nrow(forecast) == 1350L &&
    length(unique(forecast$forecast_origin_source_index)) == 45L &&
    max(forecast$forecast_lead) == 30L &&
    all(vapply(numeric_fields, function(field) {
      is.finite(as.numeric(metrics[[field]][[1L]]))
    }, logical(1L)))
}

iqcb_v4_health <- function(run_root) {
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  rows <- lapply(plans, function(path) {
    plan <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
    states <- vapply(seq_len(nrow(plan)), function(i) {
      if (identical(as.character(plan$stage[[i]]), "development_comparator")) {
        return(iqcb_v4_comparator_status(plan$config_path[[i]],
                                         plan$status_path[[i]]))
      }
      status <- iqcb_v4_status_payload(plan$status_path[[i]])
      if (is.null(status)) return("PENDING")
      state <- toupper(as.character(status$status %||% "UNKNOWN"))
      if (state == "SUCCESS" &&
          !iqcb_v4_status_valid(plan$config_path[[i]], plan$status_path[[i]])) {
        return("STALE_SUCCESS")
      }
      state
    }, character(1L))
    data.frame(
      stage = unique(plan$stage), planned = nrow(plan),
      success = sum(states == "SUCCESS"), failed = sum(states == "FAILED"),
      running = sum(states == "RUNNING"), pending = sum(states == "PENDING"),
      stale = sum(states == "STALE_SUCCESS"), unknown = sum(!states %in% c(
        "SUCCESS", "FAILED", "RUNNING", "PENDING", "STALE_SUCCESS"
      )), stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

iqcb_v4_audit_comparators <- function(run_root) {
  plan <- utils::read.csv(
    file.path(run_root, "plans", "development_comparator.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  health <- iqcb_v4_health(run_root)
  row <- health[health$stage == "development_comparator", , drop = FALSE]
  complete <- nrow(row) == 1L && row$success == nrow(plan) &&
    row$failed == 0L && row$running == 0L && row$pending == 0L &&
    row$stale == 0L && row$unknown == 0L
  if (!complete) stop("Matched development comparators are not complete.",
                      call. = FALSE)
  summaries <- lapply(seq_len(nrow(plan)), function(i) {
    config <- iqfr_v2_read_json(plan$config_path[[i]])
    metrics <- utils::read.csv(config$row_metrics_path, check.names = FALSE,
                               stringsAsFactors = FALSE)
    status <- utils::read.csv(config$row_status_path, check.names = FALSE,
                              stringsAsFactors = FALSE)
    forecast <- utils::read.csv(config$forecast_path_summary_path,
                                check.names = FALSE, stringsAsFactors = FALSE)
    data.frame(
      job_id = plan$job_id[[i]], model_variant = plan$model_variant[[i]],
      family = plan$family[[i]], probability = plan$probability[[i]],
      likelihood_family = plan$likelihood_family[[i]], inference = "vb",
      fit_qtrue_rmse = metrics$fit_q_rmse[[1L]],
      fit_qtrue_mae = metrics$fit_q_mae[[1L]],
      fit_check_loss = metrics$fit_pinball_mean[[1L]],
      forecast_qtrue_mae = metrics$forecast_h1000_q_mae[[1L]],
      forecast_qtrue_rmse = metrics$forecast_h1000_q_rmse[[1L]],
      forecast_check_loss = metrics$forecast_h1000_pinball_mean[[1L]],
      forecast_origins = length(unique(forecast$forecast_origin_source_index)),
      forecast_pairs = nrow(forecast),
      health_gate = metrics$health_gate[[1L]],
      runtime_seconds = as.numeric(tail(status$runtime_sec, 1L)),
      config_path = plan$config_path[[i]],
      config_sha256 = plan$config_sha256[[i]], stringsAsFactors = FALSE
    )
  })
  summary <- do.call(rbind, summaries)
  finite_fields <- c("fit_qtrue_rmse", "forecast_qtrue_mae",
                     "forecast_qtrue_rmse", "forecast_check_loss")
  finite <- all(vapply(finite_fields, function(field) {
    all(is.finite(summary[[field]]))
  }, logical(1L)))
  complete_surface <- nrow(summary) == 18L &&
    !anyDuplicated(summary[c("model_variant", "family", "probability")]) &&
    all(table(summary$model_variant) == 9L)
  binary_payloads <- list.files(
    file.path(run_root, "comparators"), recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData|ffv2handoff)$", ignore.case = TRUE
  )
  summary_path <- iqfr_v2_write_csv(
    summary, file.path(run_root, "summaries", "development_comparators.csv")
  )
  decision_value <- if (finite && complete_surface && !length(binary_payloads)) {
    "PASS_MATCHED_COMPARATORS_COMPLETE"
  } else "HOLD_MATCHED_COMPARATOR_CONTRACT_FAILURE"
  decision <- list(
    schema_version = iqcb_v4_schema, stage = "development_comparator",
    jobs = nrow(plan), cells = 18L, all_jobs_successful = TRUE,
    all_scores_finite = finite, complete_eighteen_cell_surface = complete_surface,
    forecast_origins_per_job = 45L, forecast_pairs_per_job = 1350L,
    fitted_model_binaries = length(binary_payloads),
    summary_path = summary_path, summary_sha256 = iqfr_v2_sha256(summary_path),
    decision = decision_value,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(
    decision,
    file.path(run_root, "summaries", "development_comparator_decision.json")
  )
  decision
}

iqcb_v4_read_results <- function(plan) {
  do.call(rbind, lapply(plan$result_path, function(path) {
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }))
}

iqcb_v4_audit_operator_smoke <- function(run_root) {
  plan <- utils::read.csv(file.path(run_root, "plans", "operator_smoke.csv"),
                          check.names = FALSE, stringsAsFactors = FALSE)
  health <- iqcb_v4_health(run_root)
  row <- health[health$stage == "operator_smoke", , drop = FALSE]
  complete <- nrow(row) == 1L && row$success == nrow(plan) &&
    row$failed == 0L && row$running == 0L && row$pending == 0L &&
    row$stale == 0L
  if (!complete) stop("The v4 operator smoke is not complete.", call. = FALSE)
  results <- iqcb_v4_read_results(plan)
  finite <- all(is.finite(results$forecast_qtrue_mae)) &&
    all(is.finite(results$forecast_check_loss))
  identity <- all(results$exact_identity_projection)
  complete_surface <- length(unique(results$job_id)) == 6L
  decision <- list(
    schema_version = iqcb_v4_schema, stage = "operator_smoke",
    jobs = nrow(plan), all_jobs_successful = TRUE,
    all_scores_finite = finite, exact_identity_projection = identity,
    complete_six_cell_surface = complete_surface,
    decision = if (finite && identity && complete_surface) {
      "PASS_UNLOCK_BROAD_SCREEN"
    } else "HOLD_OPERATOR_SMOKE_FAILURE",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(decision, file.path(run_root, "summaries",
                                         "operator_smoke_decision.json"))
  decision
}

iqcb_v4_amplitude_summary <- function(plan) {
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqfr_v2_read_json(plan$config_path[[i]])
    x <- utils::read.csv(gzfile(cfg$origin_lead_path), check.names = FALSE,
                         stringsAsFactors = FALSE)
    x <- x[x$estimator == "mean_conditional_location", , drop = FALSE]
    pred_sd <- stats::sd(x$point_prediction)
    oracle_sd <- stats::sd(x$q_target)
    data.frame(
      job_id = plan$job_id[[i]], prediction_sd = pred_sd,
      oracle_sd = oracle_sd,
      amplitude_ratio = pred_sd / max(oracle_sd, 1e-12),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

iqcb_v4_rank_results <- function(results, amplitude = NULL) {
  max_k <- aggregate(inner_paths ~ job_id, results, max)
  selected <- merge(results, max_k, by = c("job_id", "inner_paths"),
                    all = FALSE)
  oracle <- selected[selected$estimator == "mean_conditional_location", ,
                     drop = FALSE]
  predictive <- selected[
    selected$estimator == "posterior_predictive_quantile_pooled", , drop = FALSE
  ]
  baseline <- selected[
    selected$estimator == "training_empirical_quantile_baseline", , drop = FALSE
  ]
  keys <- c("job_id", "family", "likelihood_family", "probability",
            "representation_role", "candidate_id", "structure_id", "tau_arm",
            "rhs_tau0", "rhs_tau0_source_scale", "tau0_reference",
            "tau0_reference_source_scale", "tau0_multiplier")
  out <- merge(
    oracle[c(keys, "forecast_qtrue_mae", "forecast_qtrue_rmse",
             "fit_qtrue_rmse_mean", "fit_qtrue_mae_mean")],
    predictive[c(keys, "forecast_check_loss")], by = keys, all = FALSE
  )
  base <- baseline[c("job_id", "forecast_qtrue_mae")]
  names(base)[[2L]] <- "baseline_forecast_qtrue_mae"
  out <- merge(out, base, by = "job_id", all.x = TRUE, sort = FALSE)
  out$oracle_mae_ratio_to_baseline <- out$forecast_qtrue_mae /
    out$baseline_forecast_qtrue_mae
  if (!is.null(amplitude)) out <- merge(out, amplitude, by = "job_id", all.x = TRUE)
  cell <- interaction(out$family, out$likelihood_family, out$probability,
                      drop = TRUE)
  out$selection_rank <- ave(seq_len(nrow(out)), cell, FUN = function(ids) {
    order(order(out$forecast_qtrue_mae[ids], out$forecast_check_loss[ids],
                out$forecast_qtrue_rmse[ids], out$candidate_id[ids]))
  })
  out[order(out$family, out$likelihood_family, out$probability,
            out$selection_rank), , drop = FALSE]
}

iqcb_v4_audit_broad <- function(run_root) {
  smoke <- iqfr_v2_read_json(file.path(run_root, "summaries",
                                        "operator_smoke_decision.json"))
  if (!identical(as.character(smoke$decision), "PASS_UNLOCK_BROAD_SCREEN")) {
    stop("The v4 smoke gate is not open.", call. = FALSE)
  }
  protocol <- iqcb_v4_read_protocol()
  comparator <- iqfr_v2_read_json(file.path(
    run_root, "summaries", "development_comparator_decision.json"
  ))
  if (!identical(
    as.character(comparator$decision),
    as.character(protocol$gates$broad_requires_comparator_decision)
  )) stop("The matched-comparator gate is not open.", call. = FALSE)
  plan <- utils::read.csv(file.path(run_root, "plans", "broad_screen.csv"),
                          check.names = FALSE, stringsAsFactors = FALSE)
  health <- iqcb_v4_health(run_root)
  row <- health[health$stage == "broad_screen", , drop = FALSE]
  complete <- nrow(row) == 1L && row$success == nrow(plan) &&
    row$failed == 0L && row$running == 0L && row$pending == 0L &&
    row$stale == 0L
  if (!complete) stop("The v4 broad screen is not complete.", call. = FALSE)
  results <- iqcb_v4_read_results(plan)
  required_numeric <- c("forecast_qtrue_mae", "forecast_qtrue_rmse",
                        "forecast_check_loss", "fit_qtrue_rmse_mean")
  finite <- all(vapply(required_numeric, function(field) {
    all(is.finite(results[[field]]))
  }, logical(1L)))
  identity <- all(results$exact_identity_projection)
  amplitude <- iqcb_v4_amplitude_summary(plan)
  ranking <- iqcb_v4_rank_results(results, amplitude)
  counts <- table(interaction(ranking$family, ranking$likelihood_family,
                              ranking$probability, drop = TRUE))
  complete_surface <- length(counts) == 18L && all(counts == 16L)
  winners <- ranking[ranking$selection_rank == 1L, , drop = FALSE]
  dir.create(file.path(run_root, "summaries"), recursive = TRUE,
             showWarnings = FALSE)
  iqfr_v2_write_csv(ranking, file.path(run_root, "summaries",
                                       "broad_cellwise_ranking.csv"))
  iqfr_v2_write_csv(winners, file.path(run_root, "summaries",
                                       "broad_cellwise_winners.csv"))
  iqfr_v2_write_csv(amplitude, file.path(run_root, "summaries",
                                         "broad_path_amplitude_diagnostics.csv"))
  decision_value <- if (finite && identity && complete_surface) {
    "PASS_READY_FOR_ADAPTIVE_REFINEMENT"
  } else "HOLD_BROAD_CONTRACT_FAILURE"
  decision <- list(
    schema_version = iqcb_v4_schema, stage = "broad_screen",
    jobs = nrow(plan), cells = length(counts), candidates_per_cell = 16L,
    all_jobs_successful = TRUE, all_scores_finite = finite,
    exact_identity_projection = identity,
    complete_eighteen_cell_surface = complete_surface,
    cells_beating_constant_baseline = sum(
      winners$forecast_qtrue_mae < winners$baseline_forecast_qtrue_mae
    ),
    median_winner_amplitude_ratio = stats::median(winners$amplitude_ratio),
    decision = decision_value, automatic_adaptive_launch = FALSE,
    ranking_path = file.path(run_root, "summaries",
                             "broad_cellwise_ranking.csv"),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(decision, file.path(run_root, "summaries",
                                         "broad_decision.json"))
  decision
}

iqcb_v4_materialize_adaptive <- function(repo_root, run_root) {
  protocol <- iqcb_v4_read_protocol(repo_root)
  decision <- iqfr_v2_read_json(file.path(run_root, "summaries",
                                           "broad_decision.json"))
  if (!identical(as.character(decision$decision),
                 as.character(protocol$gates$adaptive_requires_broad_decision))) {
    stop("Broad evidence has not unlocked adaptive refinement.", call. = FALSE)
  }
  ranking <- utils::read.csv(file.path(run_root, "summaries",
                                       "broad_cellwise_ranking.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  candidates <- utils::read.csv(file.path(run_root, "manifests",
                                          "broad_candidates.csv"),
                                check.names = FALSE, stringsAsFactors = FALSE)
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  broad_signatures <- unique(candidates$candidate_signature)
  rows <- list()
  k <- 0L
  cells <- unique(ranking[c("family", "likelihood_family", "probability")])
  cells <- cells[order(match(cells$probability,
                             as.numeric(protocol$adaptive$priority_quantiles)),
                       cells$family, cells$likelihood_family), , drop = FALSE]
  for (i in seq_len(nrow(cells))) {
    cell <- ranking[
      ranking$family == cells$family[[i]] &
        ranking$likelihood_family == cells$likelihood_family[[i]] &
        abs(ranking$probability - cells$probability[[i]]) < 1e-12,
      , drop = FALSE
    ]
    best_by_structure <- cell[order(cell$selection_rank), , drop = FALSE]
    best_by_structure <- best_by_structure[
      !duplicated(best_by_structure$structure_id), , drop = FALSE
    ]
    best_by_structure <- head(best_by_structure,
                              as.integer(protocol$adaptive$structures_per_cell))
    multipliers <- if (cells$probability[[i]] < 0.5) {
      as.numeric(protocol$adaptive$lower_quantile_multipliers)
    } else as.numeric(protocol$adaptive$median_multipliers)
    for (j in seq_len(nrow(best_by_structure))) {
      parent <- candidates[candidates$candidate_id ==
                             best_by_structure$candidate_id[[j]], , drop = FALSE]
      if (nrow(parent) != 1L) stop("Adaptive parent lookup failed.", call. = FALSE)
      for (multiplier in multipliers) {
        row <- parent
        row$tau_arm <- paste0("adaptive_", gsub("[.]", "p", multiplier), "x")
        row$tau0_multiplier <- multiplier
        row$rhs_tau0 <- row$tau0_reference * multiplier
        row$rhs_tau0_source_scale <- row$tau0_reference_source_scale * multiplier
        row$candidate_signature <- paste(
          iqcb_v4_schema, row$cell_id[[1L]],
          row$canonical_structure_signature[[1L]],
          format(multiplier, scientific = TRUE, digits = 16), sep = "|"
        )
        if (row$candidate_signature[[1L]] %in% broad_signatures) next
        row$candidate_id <- paste0(
          "iqcb4a_", row$family[[1L]], "_", row$likelihood_family[[1L]], "_p",
          sprintf("%03d", as.integer(round(100 * row$probability[[1L]]))), "_",
          substr(digest::digest(row$candidate_signature[[1L]], algo = "sha256",
                                serialize = FALSE), 1L, 12L)
        )
        row$parent_broad_candidate_id <- parent$candidate_id[[1L]]
        k <- k + 1L
        rows[[k]] <- row
      }
    }
  }
  adaptive <- iqcf_v3_bind_rows(rows)
  ceiling <- as.integer(protocol$adaptive$maximum_jobs)
  if (nrow(adaptive) != ceiling || anyDuplicated(adaptive$candidate_id) ||
      any(adaptive$candidate_signature %in% broad_signatures)) {
    stop("Adaptive candidate ceiling/deduplication contract failed.",
         call. = FALSE)
  }
  plan_rows <- vector("list", nrow(adaptive))
  for (i in seq_len(nrow(adaptive))) {
    candidate <- adaptive[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - candidate$probability[[1L]]) < 1e-12,
                      , drop = FALSE]
    plan_rows[[i]] <- iqcb_v4_make_job_config(
      repo_root, run_root, "adaptive_refinement", candidate, source, protocol
    )
  }
  plan <- do.call(rbind, plan_rows)
  candidates_path <- file.path(run_root, "manifests", "adaptive_candidates.csv")
  plan_path <- file.path(run_root, "plans", "adaptive_refinement.csv")
  iqfr_v2_write_csv(adaptive, candidates_path)
  iqfr_v2_write_csv(plan, plan_path)
  manifest <- data.frame(
    path = normalizePath(c(candidates_path, plan_path), winslash = "/",
                         mustWork = TRUE),
    bytes = file.info(c(candidates_path, plan_path))$size,
    sha256 = vapply(c(candidates_path, plan_path), iqfr_v2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  iqfr_v2_write_csv(manifest, file.path(run_root, "manifests",
                                        "adaptive_materialization_manifest.csv"))
  list(candidates = adaptive, plan = plan, manifest = manifest)
}
