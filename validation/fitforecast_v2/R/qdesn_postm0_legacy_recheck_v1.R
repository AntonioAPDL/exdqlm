source(file.path(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                winslash = "/", mustWork = TRUE),
  "validation", "fitforecast_v2", "R",
  "qdesn_lower_tail_cellwise_mcmc_v1.R"
))

qdesn_plrv1_stage <-
  "qdesn_dynamic_fitforecast_v2_500obs_postm0_legacy_recheck_v1"
qdesn_plrv1_branch <-
  "validation/qdesn-postm0-legacy-recheck-v1-1.0.0"
qdesn_plrv1_base_commit <-
  "f7d57b17997bea461faf6f5bfc6213c33fa2fd1e"
qdesn_plrv1_method_id <- "M0_v_collapsed_support_logit"
qdesn_plrv1_history_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2_history_signature_ledger.csv"
)
qdesn_plrv1_vb_history_path <- file.path(
  "validation", "fitforecast_v2", "docs",
  "qdesn_tt500_vb_historical_winner_handoff_ledger_20260709.csv"
)
qdesn_plrv1_mcmc_history_path <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_500obs_mcmc_nested_cellwise_v1_closeout_20260730",
  "cellwise_candidate_ranking.csv"
)
qdesn_plrv1_target_ids <- c(
  "exal_laplace_t0p05", "exal_gausmix_t0p25", "exal_gausmix_t0p05",
  "exal_normal_t0p05", "exal_normal_t0p25"
)

qdesn_plrv1_tracked_paths <- function(repo_root) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  stub <- file.path(repo_root, "config", "validation", qdesn_plrv1_stage)
  paths <- c(
    paste0(stub, c(
      "_sources.yaml", "_target_cells.csv", "_parent_controls.csv",
      "_candidate_profiles.csv", "_historical_evidence_rows.csv",
      "_historical_signature_evidence.csv", "_postm0_signature_coverage.csv",
      "_candidate_selection_audit.csv", "_source_seed_contract.csv"
    )),
    list.files(
      paste0(stub, "_frozen_parent_requests"), pattern = "[.]json$",
      full.names = TRUE
    ),
    list.files(
      paste0(stub, "_frozen_parent_metrics"), pattern = "[.]csv$",
      full.names = TRUE
    ),
    file.path(repo_root, "validation", "fitforecast_v2", "R", c(
      "independent_exal_m0_structural_screen_v2.R",
      "qdesn_lower_tail_cellwise_mcmc_v1.R",
      "qdesn_postm0_legacy_recheck_v1.R"
    )),
    file.path(repo_root, "validation", "fitforecast_v2", "scripts", c(
      "materialize_qdesn_postm0_legacy_recheck_v1.R",
      "run_qdesn_postm0_legacy_recheck_v1_chain.R",
      "healthcheck_qdesn_postm0_legacy_recheck_v1.R",
      "verify_qdesn_postm0_legacy_recheck_v1.R",
      "advance_qdesn_postm0_legacy_recheck_v1.R",
      "recover_qdesn_postm0_legacy_recheck_v1_replication_closeout.R",
      "materialize_qdesn_postm0_legacy_recheck_v1_confirmation.R",
      "verify_qdesn_postm0_legacy_recheck_v1_confirmation.R",
      "closeout_qdesn_postm0_legacy_recheck_v1_confirmation.R",
      "run_qdesn_postm0_legacy_recheck_v1_pipeline.sh",
      "run_qdesn_postm0_legacy_recheck_v1_stage.sh",
      "run_qdesn_postm0_legacy_recheck_v1_confirmation.sh",
      "launch_qdesn_postm0_legacy_recheck_v1.sh",
      "launch_qdesn_postm0_legacy_recheck_v1_stage.sh",
      "launch_qdesn_postm0_legacy_recheck_v1_confirmation.sh"
    )),
    file.path(repo_root, "validation", "fitforecast_v2", "tests", "testthat", c(
      "test-independent-exal-m0-structural-screen-v2.R",
      "test-qdesn-postm0-legacy-recheck-v1.R"
    )),
    file.path(
      repo_root, "validation", "fitforecast_v2", "docs",
      c("QDESN_POSTM0_LEGACY_RECHECK_V1_PROTOCOL_2026-08-14.md",
        "QDESN_POSTM0_FORECAST_FIRST_CONFIRMATION_V1_2026-08-18.md")
    )
  )
  paths <- unique(paths)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) {
    stop(sprintf(
      "Tracked implementation paths missing: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  normalizePath(paths, winslash = "/", mustWork = TRUE)
}

qdesn_plrv1_tracked_manifest <- function(repo_root) {
  paths <- qdesn_plrv1_tracked_paths(repo_root)
  data.frame(
    relative_path = vapply(
      paths, qdesn_ssv2_rel, character(1L), repo_root = repo_root
    ),
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, qdesn_ssv2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
}

# Reuse the proven Tier-A execution core under a campaign-specific stage.
qdesn_ltcv1_stage <- qdesn_plrv1_stage
qdesn_ltcv1_branch <- qdesn_plrv1_branch
qdesn_ltcv1_base_commit <- qdesn_plrv1_base_commit

.qdesn_plrv1_bool <- function(x) {
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}

.qdesn_plrv1_expand <- function(value, D, mode = c("numeric", "integer")) {
  mode <- match.arg(mode)
  value <- qdesn_ssv2_vec(as.character(value), mode)
  if (length(value) == 1L) value <- rep(value, D)
  if (length(value) != D) {
    stop(sprintf("Expected %d layer values, found %d.", D, length(value)),
         call. = FALSE)
  }
  value
}

.qdesn_plrv1_profile <- function(D, n, m, alpha, rho, pi_w, pi_in,
                                  rhs_tau0, readout_y_lags,
                                  reservoir_lags, washout = 300L) {
  D <- as.integer(D)
  n <- .qdesn_plrv1_expand(n, D, "integer")
  alpha <- .qdesn_plrv1_expand(alpha, D)
  rho <- .qdesn_plrv1_expand(rho, D)
  pi_w <- .qdesn_plrv1_expand(pi_w, D)
  pi_in <- .qdesn_plrv1_expand(pi_in, D)
  out <- .qdesn_ssv2_profile_row(
    D = D, n = n, m = as.integer(m), alpha = alpha, rho = rho,
    degree = max(1L, as.integer(round(mean(pi_w * n)))),
    tau0 = as.numeric(rhs_tau0),
    readout_y_lags = as.integer(readout_y_lags),
    reservoir_lags = as.integer(reservoir_lags),
    washout = as.integer(washout), layer_shape = "historical_exact",
    alpha_pattern = "historical_exact", rho_pattern = "historical_exact",
    design_role = "historical_exact", selection_arm = "legacy_recheck"
  )
  out$pi_w <- qdesn_ssv2_pack(pi_w)
  out$pi_in <- qdesn_ssv2_pack(pi_in)
  out$profile_signature <- qdesn_ssv2_profile_signature(out)
  qdesn_ssv2_ensure_effective_dimension(out)
}

qdesn_plrv1_targets <- function(repo_root, freeze_requests = FALSE) {
  campaign_stage <- qdesn_ltcv1_stage
  qdesn_ltcv1_stage <<-
    "qdesn_dynamic_fitforecast_v2_500obs_lower_tail_cellwise_mcmc_v1"
  on.exit(qdesn_ltcv1_stage <<- campaign_stage, add = TRUE)
  out <- qdesn_ltcv1_targets(repo_root, freeze_requests = FALSE)
  out <- out[out$target_cell_id %in% qdesn_plrv1_target_ids, , drop = FALSE]
  out <- out[match(qdesn_plrv1_target_ids, out$target_cell_id), , drop = FALSE]
  out$parent_metric_source_path <- rep(NA_character_, nrow(out))
  out$parent_metric_sha256 <- rep(NA_character_, nrow(out))
  for (i in seq_len(nrow(out))) {
    suffix <- substr(digest::digest(
      out$parent_candidate_id[[i]], algo = "sha256", serialize = FALSE
    ), 1L, 12L)
    frozen_rel <- file.path(
      "config", "validation", paste0(qdesn_plrv1_stage,
                                        "_frozen_parent_requests"),
      paste0(qdesn_ssv2_safe(out$target_cell_id[[i]]), "__", suffix, ".json")
    )
    frozen_abs <- qdesn_ssv2_path(repo_root, frozen_rel)
    metric_frozen_rel <- file.path(
      "config", "validation", paste0(qdesn_plrv1_stage,
                                        "_frozen_parent_metrics"),
      paste0(qdesn_ssv2_safe(out$target_cell_id[[i]]), "__", suffix, ".csv")
    )
    metric_frozen_abs <- qdesn_ssv2_path(repo_root, metric_frozen_rel)
    metric_source_abs <- if (file.exists(metric_frozen_abs) &&
                             !isTRUE(freeze_requests)) {
      frozen_metric <- qdesn_ssv2_read_csv(metric_frozen_abs)
      as.character(frozen_metric$source_metric_path[[1L]])
    } else {
      normalizePath(out$parent_metric_path[[i]], winslash = "/",
                    mustWork = TRUE)
    }
    if (isTRUE(freeze_requests)) {
      request <- qdesn_ssv2_read_json(qdesn_ssv2_path(
        repo_root, out$parent_request_path[[i]], must_work = TRUE
      ))
      qdesn_ssv2_write_json(request, frozen_abs)
      metric_evidence <- data.frame(
        target_cell_id = out$target_cell_id[[i]],
        family = out$family[[i]], tau = out$tau[[i]],
        likelihood_target = out$likelihood_target[[i]],
        parent_candidate_id = out$parent_candidate_id[[i]],
        objective_metric = out$objective_metric[[i]],
        current_fit_qtrue_rmse = out$current_fit_qtrue_rmse[[i]],
        current_forecast_qtrue_mae_H1000 =
          out$current_forecast_qtrue_mae_H1000[[i]],
        current_forecast_check_loss_H1000 =
          out$current_forecast_check_loss_H1000[[i]],
        comparator_fit_qtrue_rmse = out$comparator_fit_qtrue_rmse[[i]],
        comparator_forecast_qtrue_mae_H1000 =
          out$comparator_forecast_qtrue_mae_H1000[[i]],
        comparator_forecast_check_loss_H1000 =
          out$comparator_forecast_check_loss_H1000[[i]],
        source_metric_path = metric_source_abs,
        source_metric_sha256 = qdesn_ssv2_sha256(metric_source_abs),
        stringsAsFactors = FALSE
      )
      qdesn_ssv2_write_csv(metric_evidence, metric_frozen_abs)
    }
    if (file.exists(frozen_abs)) {
      out$parent_request_path[[i]] <- frozen_rel
      out$parent_request_source_path[[i]] <- frozen_abs
      out$parent_request_sha256[[i]] <- qdesn_ssv2_sha256(frozen_abs)
    }
    if (file.exists(metric_frozen_abs)) {
      out$parent_metric_source_path[[i]] <- metric_source_abs
      out$parent_metric_path[[i]] <- metric_frozen_rel
      out$parent_metric_sha256[[i]] <- qdesn_ssv2_sha256(metric_frozen_abs)
    }
  }
  out$tier <- "A"
  out$candidates_per_cell <- 8L
  out$discovery_sources <- 2L
  out$replication_survivors <- 3L
  out$sealed_finalists <- 2L
  if (nrow(out) != 5L || any(out$likelihood_target != "exal") ||
      anyDuplicated(out$target_cell_id)) {
    stop("The five-cell post-M0 target contract has drifted.", call. = FALSE)
  }
  out
}

.qdesn_plrv1_evidence_class <- function(path) {
  base <- tolower(basename(path))
  if (grepl("vb", base, fixed = TRUE) || grepl("^qvbm", base)) {
    "pre_m0_vb"
  } else if (grepl("mcmc", base, fixed = TRUE) ||
             grepl("trainonly_(mechanism|followup|rebaseline)", base)) {
    "pre_m0_mcmc_sampler_confounded"
  } else {
    "pre_m0_untyped"
  }
}

qdesn_plrv1_history_audit <- function(repo_root) {
  history_path <- qdesn_ssv2_path(
    repo_root, qdesn_plrv1_history_path, must_work = TRUE
  )
  rows <- qdesn_ssv2_read_csv(history_path)
  rows$evidence_class <- vapply(
    rows$source_file, .qdesn_plrv1_evidence_class, character(1L)
  )
  rows$eligible_as_negative_m0_evidence <- FALSE
  rows$interpretation <- ifelse(
    rows$evidence_class == "pre_m0_vb",
    "valid_VB_candidate_prior_only_not_negative_M0_MCMC_evidence",
    ifelse(
      rows$evidence_class == "pre_m0_mcmc_sampler_confounded",
      "sampler_confounded_exact_design_eligible_for_M0_recheck",
      "untyped_history_not_used_for_candidate_selection"
    )
  )
  key <- split(seq_len(nrow(rows)), rows$profile_signature)
  signatures <- do.call(rbind, lapply(names(key), function(signature) {
    i <- key[[signature]]
    classes <- sort(unique(rows$evidence_class[i]))
    data.frame(
      profile_signature = signature,
      historical_occurrences = length(i),
      historical_files = length(unique(rows$source_file[i])),
      evidence_classes = paste(classes, collapse = ";"),
      pre_m0_vb_seen = "pre_m0_vb" %in% classes,
      pre_m0_mcmc_seen = "pre_m0_mcmc_sampler_confounded" %in% classes,
      stringsAsFactors = FALSE
    )
  }))
  rownames(signatures) <- NULL
  if (nrow(rows) != 9268L || nrow(signatures) != 2398L) {
    stop(sprintf(
      "Frozen history changed: expected 9268 rows/2398 signatures, found %d/%d.",
      nrow(rows), nrow(signatures)
    ), call. = FALSE)
  }
  list(rows = rows, signatures = signatures, source_sha256 =
         qdesn_ssv2_sha256(history_path))
}

qdesn_plrv1_postm0_signatures <- function(repo_root) {
  profile_files <- file.path(repo_root, "config", "validation", c(
    "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2_wave1_profiles.csv",
    "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2_parent_controls.csv",
    "qdesn_dynamic_fitforecast_v2_500obs_lower_tail_cellwise_mcmc_v1_candidate_profiles.csv",
    "qdesn_dynamic_fitforecast_v2_500obs_lower_tail_cellwise_mcmc_v1_parent_controls.csv",
    "qdesn_dynamic_fitforecast_v2_500obs_tierb_cellwise_mcmc_v1_candidate_profiles.csv",
    "qdesn_dynamic_fitforecast_v2_500obs_tierb_cellwise_mcmc_v1_parent_controls.csv"
  ))
  rows <- lapply(profile_files[file.exists(profile_files)], function(path) {
    x <- qdesn_ssv2_read_csv(path)
    data.frame(
      profile_signature = as.character(x$profile_signature),
      postm0_source = qdesn_ssv2_rel(path, repo_root),
      postm0_evidence_class = "exact_M0_profile_campaign",
      stringsAsFactors = FALSE
    )
  })
  anchor_path <- file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1_anchor_registry.csv"
  )
  anchors <- qdesn_ssv2_read_csv(anchor_path)
  anchor_rows <- lapply(seq_len(nrow(anchors)), function(i) {
    request_path <- qdesn_ssv2_path(
      repo_root, anchors$frozen_request_path[[i]], must_work = TRUE
    )
    profile <- .qdesn_ssv2_parent_profile(qdesn_ssv2_read_json(request_path))
    data.frame(
      profile_signature = qdesn_ssv2_profile_signature(profile),
      postm0_source = qdesn_ssv2_rel(anchor_path, repo_root),
      postm0_evidence_class = "exact_M0_same_design_relaunch",
      stringsAsFactors = FALSE
    )
  })
  out <- unique(do.call(rbind, c(rows, anchor_rows)))
  out$postm0_exact_mcmc_tested <- TRUE
  out
}

.qdesn_plrv1_quality_diverse <- function(pool, n_select, quality_field) {
  pool <- pool[!duplicated(pool$profile_signature), , drop = FALSE]
  pool <- pool[is.finite(pool[[quality_field]]), , drop = FALSE]
  if (!nrow(pool) || n_select < 1L) return(pool[FALSE, , drop = FALSE])
  pool <- pool[order(pool[[quality_field]], pool$profile_signature), , drop = FALSE]
  n_select <- min(as.integer(n_select), nrow(pool))
  chosen <- 1L
  while (length(chosen) < n_select) {
    remaining <- setdiff(seq_len(nrow(pool)), chosen)
    features <- as.matrix(.qdesn_ssv2_features(pool))
    dmin <- vapply(remaining, function(i) {
      min(rowSums((features[chosen, , drop = FALSE] -
                     matrix(features[i, ], nrow = length(chosen),
                            ncol = ncol(features), byrow = TRUE))^2))
    }, numeric(1L))
    quality <- rank(pool[[quality_field]][remaining], ties.method = "first")
    quality <- 1 - (quality - 1) / max(1, length(remaining) - 1)
    score <- dmin + .25 * quality
    chosen <- c(chosen, remaining[which.max(score)])
  }
  pool[chosen, , drop = FALSE]
}

.qdesn_plrv1_vb_pool <- function(repo_root) {
  path <- qdesn_ssv2_path(repo_root, qdesn_plrv1_vb_history_path,
                          must_work = TRUE)
  x <- qdesn_ssv2_read_csv(path)
  x <- x[.qdesn_plrv1_bool(x$all_primary_win) &
           .qdesn_plrv1_bool(x$profile_resolved), , drop = FALSE]
  rows <- lapply(seq_len(nrow(x)), function(i) {
    profile <- tryCatch(.qdesn_plrv1_profile(
      x$profile_D[[i]], x$profile_n_each[[i]], x$profile_m[[i]],
      x$profile_alpha[[i]], x$profile_rho[[i]], x$profile_pi_w[[i]],
      x$profile_pi_in[[i]], x$rhs_tau0[[i]],
      x$profile_readout_y_lags[[i]], x$profile_reservoir_lags[[i]],
      x$washout[[i]]
    ), error = function(e) NULL)
    if (is.null(profile)) return(NULL)
    profile$family <- as.character(x$family[[i]])
    profile$tau <- as.numeric(x$tau[[i]])
    profile$legacy_quality_score <- as.numeric(x$max_primary_ratio[[i]])
    profile$historical_evidence_class <- "pre_m0_vb_all_primary_win"
    profile$historical_source_file <- qdesn_ssv2_rel(path, repo_root)
    profile$historical_source_id <- as.character(
      x$resolved_screening_profile_id[[i]]
    )
    profile
  })
  do.call(rbind, rows[!vapply(rows, is.null, logical(1L))])
}

.qdesn_plrv1_mcmc_pool <- function(repo_root) {
  path <- qdesn_ssv2_path(repo_root, qdesn_plrv1_mcmc_history_path,
                          must_work = TRUE)
  x <- qdesn_ssv2_read_csv(path)
  x <- x[x$model_variant == "qdesn_exal_rhs_ns", , drop = FALSE]
  rows <- lapply(seq_len(nrow(x)), function(i) {
    profile <- tryCatch(.qdesn_plrv1_profile(
      x$D[[i]], x$n_each[[i]], x$m[[i]], x$alpha[[i]], x$rho[[i]],
      x$pi_w[[i]], x$pi_in[[i]], x$rhs_tau0[[i]],
      x$readout_y_lags[[i]], x$reservoir_lags[[i]], 300L
    ), error = function(e) NULL)
    if (is.null(profile)) return(NULL)
    profile$family <- as.character(x$family[[i]])
    profile$tau <- as.numeric(x$tau[[i]])
    profile$legacy_quality_score <- as.numeric(x$primary_ratio[[i]])
    profile$historical_evidence_class <-
      "pre_m0_mcmc_sampler_confounded_ranked"
    profile$historical_source_file <- qdesn_ssv2_rel(path, repo_root)
    profile$historical_source_id <- paste(
      x$design_role[[i]], x$rank_within_cell[[i]], sep = "__rank_"
    )
    profile
  })
  do.call(rbind, rows[!vapply(rows, is.null, logical(1L))])
}

qdesn_plrv1_candidate_profiles <- function(repo_root, parents, targets,
                                            postm0) {
  vb <- .qdesn_plrv1_vb_pool(repo_root)
  mcmc <- .qdesn_plrv1_mcmc_pool(repo_root)
  tested <- unique(postm0$profile_signature)
  rows <- list()
  audit <- list()
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, , drop = FALSE]
    cell <- target$target_cell_id[[1L]]
    vb_cell <- vb[
      vb$family == target$family[[1L]] &
        abs(vb$tau - target$tau[[1L]]) < 1e-10 &
        !vb$profile_signature %in% tested,
      , drop = FALSE
    ]
    vb_selected <- .qdesn_plrv1_quality_diverse(
      vb_cell, 5L, "legacy_quality_score"
    )
    need <- 8L - nrow(vb_selected)
    mcmc_cell <- mcmc[
      mcmc$family == target$family[[1L]] &
        abs(mcmc$tau - target$tau[[1L]]) < 1e-10 &
        !mcmc$profile_signature %in% c(
          tested, vb_selected$profile_signature
        ),
      , drop = FALSE
    ]
    mcmc_selected <- .qdesn_plrv1_quality_diverse(
      mcmc_cell, need, "legacy_quality_score"
    )
    selected <- rbind(vb_selected, mcmc_selected)
    if (nrow(selected) != 8L || anyDuplicated(selected$profile_signature)) {
      stop(sprintf("Could not select eight untested designs for %s.", cell),
           call. = FALSE)
    }
    selected$target_cell_id <- cell
    selected$family <- target$family[[1L]]
    selected$tau <- target$tau[[1L]]
    selected$priority <- "postm0_legacy_recheck"
    selected$objective_metric <- target$objective_metric[[1L]]
    selected$current_value <- target$objective_current_value[[1L]]
    selected$comparator_value <- target$objective_comparator_value[[1L]]
    selected$parent_anchor_id <- target$parent_candidate_id[[1L]]
    selected$likelihood_target <- "exal"
    selected$target_metrics <- target$target_metrics[[1L]]
    selected$selection_arm <- ifelse(
      selected$historical_evidence_class == "pre_m0_vb_all_primary_win",
      "historical_vb_quality_diversity", "historical_mcmc_quality_diversity"
    )
    selected$design_role <- ifelse(
      selected$historical_evidence_class == "pre_m0_vb_all_primary_win",
      "exact_pre_m0_vb_all_criterion_winner_rechecked_under_M0",
      "exact_pre_m0_mcmc_design_rechecked_under_M0"
    )
    hashes <- vapply(
      selected$profile_signature, digest::digest, character(1L),
      algo = "sha256", serialize = FALSE
    )
    selected$candidate_id <- sprintf(
      "plrv1_%s_%02d_%s", cell, seq_len(nrow(selected)),
      substr(hashes, 1L, 10L)
    )
    selected$screening_profile_id <- selected$candidate_id
    selected$selection_rank <- seq_len(nrow(selected))
    selected$postm0_exact_mcmc_tested_before_campaign <- FALSE
    rows[[i]] <- selected
    audit[[i]] <- data.frame(
      target_cell_id = cell,
      available_pre_m0_vb_all_primary_unique =
        length(unique(vb_cell$profile_signature)),
      selected_pre_m0_vb = nrow(vb_selected),
      available_pre_m0_mcmc_unique =
        length(unique(mcmc_cell$profile_signature)),
      selected_pre_m0_mcmc = nrow(mcmc_selected),
      exact_postm0_signatures_excluded = length(tested),
      candidates_selected = nrow(selected),
      stringsAsFactors = FALSE
    )
  }
  profiles <- do.call(rbind, rows)
  rownames(profiles) <- NULL
  core <- .qdesn_ltcv1_profile_schema(profiles)
  extras <- profiles[, setdiff(names(profiles), names(core)), drop = FALSE]
  profiles <- cbind(core, extras)
  if (nrow(profiles) != 40L ||
      any(table(profiles$target_cell_id) != 8L) ||
      any(profiles$profile_signature %in% tested) ||
      any(profiles$effective_readout_dimension > 900L)) {
    stop("The post-M0 40-profile selection contract failed.", call. = FALSE)
  }
  list(profiles = profiles, audit = do.call(rbind, audit))
}

qdesn_plrv1_make_job <- function(repo_root, profile, target, source, stage,
                                  source_registry_path, chain_id = 1L,
                                  reservoir_seed_id = "r01") {
  job <- qdesn_ltcv1_make_job(
    repo_root, profile, target, source, stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job$schema_version <- "qdesn_postm0_legacy_recheck_v1_job_v1"
  job$spec_id <- paste0("postm0_legacy_recheck_v1__", job$job_id)
  job$config$validation_spec_id <- job$spec_id
  job$config$outputs$retention_profile <-
    "storage_light_postm0_legacy_recheck_v1"
  job$root_spec$screening_stage <- qdesn_plrv1_stage
  job$study_contract$validation_stage <- qdesn_plrv1_stage
  job$study_contract$historical_evidence_class <- if (
    "historical_evidence_class" %in% names(profile) &&
      !is.na(profile$historical_evidence_class[[1L]])
  ) {
    as.character(profile$historical_evidence_class[[1L]])
  } else if (grepl("_parent$", profile$candidate_id[[1L]])) {
    "postm0_exact_v6_parent_control"
  } else {
    "postm0_selected_candidate_rehydrated_from_job"
  }
  job$study_contract$pre_m0_negative_evidence_veto <- FALSE
  job$study_contract$exact_M0_required <- TRUE
  job$study_contract$article_state <- "v6_frozen_unchanged"
  job
}

qdesn_plrv1_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_ltcv1_job_root(repo_root, run_tag, job_id)
}

qdesn_plrv1_forecast_first_decision <- function(chain_metrics) {
  required <- c(
    "target_cell_id", "candidate_id", "chain_id", "metric", "value",
    "current_value", "status", "signoff_grade"
  )
  missing <- setdiff(required, names(chain_metrics))
  if (length(missing)) {
    stop(sprintf("Forecast-first chain metrics are missing: %s.",
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (nrow(chain_metrics) != 3L ||
      !identical(sort(as.integer(chain_metrics$chain_id)), 1:3) ||
      length(unique(chain_metrics$target_cell_id)) != 1L ||
      length(unique(chain_metrics$candidate_id)) != 1L ||
      length(unique(chain_metrics$current_value)) != 1L ||
      any(chain_metrics$metric != "forecast_qtrue_mae_H1000")) {
    stop("Forecast-first confirmation requires one frozen three-chain target.",
         call. = FALSE)
  }
  values <- as.numeric(chain_metrics$value)
  current <- as.numeric(chain_metrics$current_value[[1L]])
  execution_valid <- all(chain_metrics$status == "SUCCESS") &&
    all(is.finite(values)) && is.finite(current)
  mean_value <- if (all(is.finite(values))) mean(values) else NA_real_
  strict_gain <- isTRUE(execution_valid) && mean_value < current
  grades <- sort(unique(as.character(chain_metrics$signoff_grade)))
  data.frame(
    target_cell_id = chain_metrics$target_cell_id[[1L]],
    candidate_id = chain_metrics$candidate_id[[1L]],
    metric = "forecast_qtrue_mae_H1000",
    chains = 3L,
    current_value = current,
    mean_value = mean_value,
    median_value = stats::median(values),
    min_value = min(values),
    max_value = max(values),
    mean_ratio = mean_value / current,
    relative_gain = 1 - mean_value / current,
    chains_improved = sum(values < current),
    execution_valid = execution_valid,
    signoff_grades_observed = paste(grades, collapse = ";"),
    diagnostics_used_as_promotion_gate = FALSE,
    promotion_primary_metric = "forecast_qtrue_mae_H1000",
    promotion_rule = "strict_three_chain_mean_forecast_mae_below_v6",
    promote = strict_gain,
    decision = if (strict_gain) {
      "PROMOTE_STRICT_FORECAST_MAE_GAIN_DIAGNOSTICS_RECORDED"
    } else if (!execution_valid) {
      "INVALID_EXECUTION_NO_PROMOTION"
    } else {
      "NO_CANONICAL_FORECAST_GAIN_RETAIN_V6"
    },
    stringsAsFactors = FALSE
  )
}
