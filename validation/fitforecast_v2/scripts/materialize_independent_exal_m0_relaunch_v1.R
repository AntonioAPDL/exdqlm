#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required.")
})

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_exal_m0_relaunch_v1.R"
))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("The independent M0 relaunch requires exdqlm 1.0.0.", call. = FALSE)
}

authority_path <- qdesn_m0v1_authority_path(repo_root)
if (!identical(qdesn_m0v1_sha256(authority_path), qdesn_m0v1_authority_sha256)) {
  stop("The authoritative v3 interface hash does not match the frozen contract.",
       call. = FALSE)
}
authority <- qdesn_m0v1_read_csv(authority_path)
occurrences <- qdesn_m0v1_source_occurrences(authority)
if (nrow(occurrences) != 27L || length(unique(occurrences$candidate_id)) != 15L) {
  stop("Expected 27 metric occurrences supplied by 15 exact exQ-DESN designs.",
       call. = FALSE)
}

stub <- qdesn_m0v1_config_stub(repo_root)
request_dir <- paste0(stub, "_frozen_requests")
input_dir <- paste0(stub, "_frozen_inputs")
config_dir <- paste0(stub, "_resolved_configs")
dir.create(request_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)

candidate_order <- unique(occurrences$candidate_id)
anchor_rows <- vector("list", length(candidate_order))
source_requests <- vector("list", length(candidate_order))

for (i in seq_along(candidate_order)) {
  candidate_id <- candidate_order[[i]]
  rows <- occurrences[occurrences$candidate_id == candidate_id, , drop = FALSE]
  request_paths <- unique(vapply(
    rows$source_path, qdesn_m0v1_request_path_from_metric, character(1L)
  ))
  if (length(request_paths) != 1L) {
    stop(sprintf("Candidate %s resolves to %d fit requests.",
                 candidate_id, length(request_paths)), call. = FALSE)
  }
  request_path <- request_paths[[1L]]
  request <- qdesn_m0v1_read_json(request_path)
  if (!identical(as.character(request$spec_id), candidate_id)) {
    stop(sprintf("Candidate/request identity mismatch for %s.", candidate_id),
         call. = FALSE)
  }
  if (!identical(tolower(as.character(request$config$inference$method)), "mcmc") ||
      !identical(tolower(as.character(request$config$inference$likelihood_family)), "exal") ||
      !identical(tolower(as.character(request$root_spec$beta_prior_type)), "rhs_ns")) {
    stop(sprintf("Candidate %s is not an exAL RHS MCMC fit.", candidate_id),
         call. = FALSE)
  }
  registry_hash <- as.character(
    request$study_contract$source_registry_hash_value %||%
      request$study_contract$source_registry_hash %||% NA_character_
  )
  if (!identical(registry_hash, qdesn_m0v1_registry_hash)) {
    stop(sprintf("Candidate %s has the wrong source registry hash.", candidate_id),
         call. = FALSE)
  }
  observed_path <- normalizePath(
    as.character(request$observed_path), winslash = "/", mustWork = TRUE
  )
  observed_hash <- qdesn_m0v1_sha256(observed_path)
  source_series_path <- normalizePath(
    as.character(request$root_spec$source_series_wide_path),
    winslash = "/", mustWork = TRUE
  )
  source_series_hash <- as.character(request$root_spec$source_series_wide_sha256)
  if (!identical(qdesn_m0v1_sha256(source_series_path), source_series_hash)) {
    stop(sprintf("Canonical source-series hash mismatch for %s.", candidate_id),
         call. = FALSE)
  }
  if (!identical(as.integer(request$root_spec$train_start_source_index), 8501L) ||
      !identical(as.integer(request$root_spec$train_end_source_index), 9000L) ||
      !identical(as.integer(request$root_spec$forecast_start_source_index), 9001L) ||
      !identical(as.integer(request$root_spec$forecast_end_source_index), 10000L) ||
      !identical(as.integer(request$config$forecast$horizon), 30L) ||
      !identical(as.integer(request$config$forecast$origin_stride), 30L)) {
    stop(sprintf("Window or rolling-origin contract mismatch for %s.", candidate_id),
         call. = FALSE)
  }
  if (!identical(as.integer(request$config$inference$mcmc$n_burn), 5000L) ||
      !identical(as.integer(request$config$inference$mcmc$n_mcmc), 20000L) ||
      !identical(as.integer(request$config$inference$mcmc$thin), 1L)) {
    stop(sprintf("Historical full-budget contract mismatch for %s.", candidate_id),
         call. = FALSE)
  }

  id_tail <- sub("^.*__", "", candidate_id)
  tau_slug <- sub("[.]", "p", sprintf("%.2f", rows$tau[[1L]]))
  anchor_id <- sprintf(
    "a%02d_%s_t%s_%s", i, rows$family[[1L]], tau_slug, id_tail
  )
  frozen_request_path <- file.path(request_dir, paste0(anchor_id, ".json"))
  frozen_input_path <- file.path(input_dir, paste0(anchor_id, ".csv"))
  if (!file.copy(request_path, frozen_request_path, overwrite = TRUE)) {
    stop(sprintf("Could not freeze request %s.", request_path), call. = FALSE)
  }
  if (!file.copy(observed_path, frozen_input_path, overwrite = TRUE)) {
    stop(sprintf("Could not freeze observed input %s.", observed_path), call. = FALSE)
  }
  frozen_request_path <- normalizePath(frozen_request_path, winslash = "/", mustWork = TRUE)
  frozen_input_path <- normalizePath(frozen_input_path, winslash = "/", mustWork = TRUE)
  if (!identical(qdesn_m0v1_sha256(frozen_request_path),
                 qdesn_m0v1_sha256(request_path)) ||
      !identical(qdesn_m0v1_sha256(frozen_input_path), observed_hash)) {
    stop(sprintf("Byte-for-byte freeze failed for %s.", candidate_id), call. = FALSE)
  }

  role_order <- c(
    fit_qtrue_rmse = 1L,
    forecast_qtrue_mae_H1000 = 2L,
    forecast_check_loss_H1000 = 3L
  )
  roles <- sort(unique(as.character(rows$metric_role)),
                index.return = FALSE)
  roles <- names(sort(role_order[roles]))
  source_requests[[i]] <- request
  anchor_rows[[i]] <- data.frame(
    anchor_id = anchor_id,
    candidate_id = candidate_id,
    family = as.character(rows$family[[1L]]),
    tau = as.numeric(rows$tau[[1L]]),
    metric_roles = paste(roles, collapse = "|"),
    source_metric_paths = paste(unique(rows$source_path), collapse = "|"),
    source_request_path = request_path,
    source_request_sha256 = qdesn_m0v1_sha256(request_path),
    frozen_request_path = qdesn_m0v1_rel(frozen_request_path, repo_root),
    frozen_request_sha256 = qdesn_m0v1_sha256(frozen_request_path),
    original_observed_path = observed_path,
    frozen_observed_path = qdesn_m0v1_rel(frozen_input_path, repo_root),
    observed_sha256 = observed_hash,
    canonical_source_series_path = source_series_path,
    canonical_source_series_sha256 = source_series_hash,
    source_registry_hash_value = registry_hash,
    source_root_id = as.character(request$root_spec$root_id),
    source_screening_profile_id = as.character(request$root_spec$screening_profile_id),
    desn_seed = as.integer(request$config$desn$seed),
    D = as.integer(request$config$desn$D),
    n_each = paste(as.integer(request$config$desn$n), collapse = ";"),
    m = as.integer(request$config$desn$m),
    alpha = as.numeric(request$config$desn$alpha),
    rho = as.numeric(request$config$desn$rho),
    pi_w = as.numeric(request$config$desn$pi_w),
    pi_in = as.numeric(request$config$desn$pi_in),
    rhs_tau0 = as.numeric(request$config$inference$mcmc$priors$beta$rhs_ns$tau0),
    historical_core_update_mode = as.character(
      request$config$inference$mcmc$slice$core_update_mode
    ),
    target_core_update_mode = qdesn_m0v1_method_id,
    stringsAsFactors = FALSE
  )
}

anchors <- do.call(rbind, anchor_rows)
if (nrow(anchors) != 15L || anyDuplicated(anchors$anchor_id) ||
    anyDuplicated(anchors$candidate_id)) {
  stop("The 15-anchor registry is not unique.", call. = FALSE)
}

metric_contract <- merge(
  occurrences,
  anchors[, c("anchor_id", "candidate_id"), drop = FALSE],
  by = "candidate_id", all.x = TRUE, sort = FALSE
)
metric_contract <- metric_contract[, c(
  "family", "tau", "metric_role", "anchor_id", "candidate_id",
  "current_value", "current_status", "current_signoff_grade", "source_path"
), drop = FALSE]

budget_contract <- data.frame(
  budget = c("smoke", "canary", "full"),
  n_burn = c(25L, 1000L, 5000L),
  n_mcmc = c(50L, 3000L, 20000L),
  thin = c(1L, 1L, 1L),
  posterior_metric_draws = c(20L, 100L, 200L),
  chains_per_anchor = c(2L, 3L, 3L),
  purpose = c(
    "finite-output and artifact-contract gate",
    "extended three-chain sampler-behavior gate",
    "article-comparable full-budget confirmation"
  ),
  stringsAsFactors = FALSE
)

canary_candidate_ids <- c(
  "qdesn__gausmix__0p05__tt500__rhs_ns__mcmc__exal__45c25fd0ade821",
  "qdesn__normal__0p25__tt500__rhs_ns__mcmc__exal__8994081347781b",
  "qdesn__laplace__0p05__tt500__rhs_ns__mcmc__exal__fb19f023510b7a"
)
canary_anchors <- anchors$anchor_id[match(canary_candidate_ids, anchors$candidate_id)]
if (length(canary_anchors) != 3L || anyNA(canary_anchors)) {
  stop("Could not recover the three predeclared gate anchors.", call. = FALSE)
}

make_cfg <- function(anchor_index, chain_id, budget_row) {
  request <- source_requests[[anchor_index]]
  cfg <- request$config
  root_spec <- request$root_spec
  budget <- as.character(budget_row$budget)
  budget_offset <- switch(budget, smoke = 100000L, canary = 200000L, full = 0L)
  if (identical(chain_id, 1L) && identical(budget, "full")) {
    mcmc_seed <- as.integer(root_spec$mcmc_seed)
    rng_seed <- as.integer(root_spec$mcmc_rng_seed)
    vb_seed <- as.integer(root_spec$vb_warm_start_seed)
    synthesis_seed <- as.integer(root_spec$synthesis_seed)
  } else {
    mcmc_seed <- 981000L + budget_offset + anchor_index * 10L + chain_id
    rng_seed <- 982000L + budget_offset + anchor_index * 10L + chain_id
    vb_seed <- 983000L + budget_offset + anchor_index * 10L + chain_id
    synthesis_seed <- 984000L + budget_offset + anchor_index * 10L + chain_id
  }
  cfg$inference$mcmc$n_burn <- as.integer(budget_row$n_burn)
  cfg$inference$mcmc$n_mcmc <- as.integer(budget_row$n_mcmc)
  cfg$inference$mcmc$thin <- as.integer(budget_row$thin)
  cfg$inference$mcmc$progress_every <- 50L
  cfg$inference$mcmc$slice$core_update_mode <- qdesn_m0v1_method_id
  cfg$inference$mcmc$slice$width_gamma <- 4
  cfg$inference$mcmc$slice$core_extra_passes <- 0L
  cfg$inference$mcmc$control$seed <- as.integer(mcmc_seed)
  cfg$inference$mcmc$control$rng_seed <- as.integer(rng_seed)
  cfg$inference$mcmc$vb_warm_start_seed <- as.integer(vb_seed)
  cfg$synthesis$seed <- as.integer(synthesis_seed)
  cfg$sampling$nd_draws <- as.integer(budget_row$posterior_metric_draws)
  cfg$synthesis$n_samp <- as.integer(budget_row$posterior_metric_draws)
  cfg$metrics$posterior_metric_draws <- as.integer(budget_row$posterior_metric_draws)
  cfg$outputs$save <- TRUE
  cfg$outputs$keep_draws <- FALSE
  cfg$outputs$keep_mcmc_vb_init <- FALSE
  cfg$outputs$save_forecast_objects <- FALSE
  cfg$outputs$save_compact_fit_paths <- TRUE
  cfg$outputs$save_metric_summaries <- TRUE
  cfg$outputs$retain_full_rds_on_failure <- FALSE
  cfg$outputs$retention_profile <- "storage_light_m0_relaunch_v1"
  cfg$cpp$postpred_threads <- 1L
  cfg$validation$stream_child_stdout <- TRUE
  cfg$validation$timeout_seconds <- 604800L
  cfg$validation$timeout_kill_after_seconds <- 60L
  cfg$validation$m0_relaunch_contract <- list(
    method_id = qdesn_m0v1_method_id,
    exact_target = TRUE,
    augmentation = "v",
    gamma_coordinate = "native_support_logit",
    scale_update = "sigma_collapsed_then_exact_gig_redraw",
    gamma_slice_width = 4,
    gamma_refreshes_per_iteration = 1L,
    article_reference_commit = qdesn_m0v1_reference_commit,
    validation_base_commit = qdesn_m0v1_base_commit,
    only_sampler_changed = TRUE
  )
  anchor_id <- anchors$anchor_id[[anchor_index]]
  spec_id <- sprintf("independent_exal_m0_v1__%s__%s__c%02d",
                     anchor_id, budget, chain_id)
  cfg$validation_spec_id <- spec_id
  cfg$validation_stage <- "all"

  root_spec$root_id <- sprintf("%s__m0_v1__%s__c%02d",
                               root_spec$root_id, budget, chain_id)
  root_spec$screening_profile_id <- spec_id
  root_spec$reservoir_profile <- spec_id
  root_spec$screening_stage <- qdesn_m0v1_stage
  root_spec$screening_wave <- "independent_exal_m0_relaunch_2026_08_09"
  root_spec$profile_role <- "exact_historical_metric_source_m0_relaunch"
  root_spec$mcmc_seed <- as.integer(mcmc_seed)
  root_spec$mcmc_rng_seed <- as.integer(rng_seed)
  root_spec$vb_warm_start_seed <- as.integer(vb_seed)
  root_spec$synthesis_seed <- as.integer(synthesis_seed)
  list(cfg = cfg, root_spec = root_spec, spec_id = spec_id,
       mcmc_seed = mcmc_seed, rng_seed = rng_seed,
       vb_seed = vb_seed, synthesis_seed = synthesis_seed)
}

plan_rows <- list()
k <- 0L
for (b in seq_len(nrow(budget_contract))) {
  budget_row <- budget_contract[b, , drop = FALSE]
  budget <- budget_row$budget[[1L]]
  anchor_indices <- if (budget %in% c("smoke", "canary")) {
    match(canary_anchors, anchors$anchor_id)
  } else seq_len(nrow(anchors))
  n_chains <- as.integer(budget_row$chains_per_anchor[[1L]])
  for (anchor_index in anchor_indices) {
    for (chain_id in seq_len(n_chains)) {
      resolved <- make_cfg(anchor_index, chain_id, budget_row)
      job_id <- sprintf("%s__%s__c%02d", budget,
                        anchors$anchor_id[[anchor_index]], chain_id)
      config_path <- file.path(config_dir, budget, paste0(job_id, ".json"))
      qdesn_m0v1_write_json(list(
        schema_version = "independent_exal_m0_relaunch_v1",
        job_id = job_id,
        budget = budget,
        anchor_id = anchors$anchor_id[[anchor_index]],
        chain_id = as.integer(chain_id),
        spec_id = resolved$spec_id,
        candidate_id = anchors$candidate_id[[anchor_index]],
        family = anchors$family[[anchor_index]],
        tau = anchors$tau[[anchor_index]],
        observed_path = anchors$frozen_observed_path[[anchor_index]],
        observed_sha256 = anchors$observed_sha256[[anchor_index]],
        source_request_path = anchors$frozen_request_path[[anchor_index]],
        source_request_sha256 = anchors$frozen_request_sha256[[anchor_index]],
        source_registry_hash_value = qdesn_m0v1_registry_hash,
        root_spec = resolved$root_spec,
        config = resolved$cfg,
        study_contract = list(
          id = qdesn_m0v1_stage,
          authoritative_interface_path = qdesn_m0v1_rel(authority_path, repo_root),
          authoritative_interface_sha256 = qdesn_m0v1_authority_sha256,
          source_registry_identity_field = "source_registry_hash_value",
          source_registry_hash_value = qdesn_m0v1_registry_hash,
          current_protocol = list(
            TT_warmup = 2000L, TT_main = 10000L, TT_total = 12000L,
            train_start_source_index = 8501L,
            train_end_source_index = 9000L,
            forecast_origin_source_index = 9000L,
            forecast_start_source_index = 9001L,
            forecast_end_source_index = 10000L,
            max_lead_configured = 30L, origin_stride = 30L,
            refit_per_origin = FALSE, observed_lag_state_update = TRUE
          ),
          storage_policy = list(
            successful_model_binaries_retained = FALSE,
            failure_model_binaries_retained = FALSE,
            compact_paths_retained = TRUE,
            status_logs_manifests_retained = TRUE
          ),
          m0_reference = list(
            method_id = "M0_v_collapsed_support_logit",
            repository = "https://github.com/AntonioAPDL/Article-Q-DESN---Version-2.git",
            commit = qdesn_m0v1_reference_commit,
            method_registry_sha256 = "6d57a7017bfe6ca58e0a10fd47245fac766371cd32cbe2b09162a77a0506822d",
            default_policy_sha256 = "28343f6974dd3cbaac0ab04430cb9f6f0ae0cadc445e6d00395e121c80075d34",
            implementation_sha256 = "ccdef9dfd5577afbc86a134259e8b1960743c085feb5b8145078709df7929d7f",
            dispatch_sha256 = "91d1c3e83ec92db51199d98cff9e9bc3ce2be7df76f268c29e09efa90d21e8dd",
            implementation_note_sha256 = "502d850f8069aab560ce14a73c8040b67e764a66729209a9e4aaa97a6b47953f"
          )
        )
      ), config_path)
      k <- k + 1L
      plan_rows[[k]] <- data.frame(
        job_id = job_id,
        budget = budget,
        anchor_id = anchors$anchor_id[[anchor_index]],
        chain_id = as.integer(chain_id),
        candidate_id = anchors$candidate_id[[anchor_index]],
        family = anchors$family[[anchor_index]],
        tau = anchors$tau[[anchor_index]],
        metric_roles = anchors$metric_roles[[anchor_index]],
        spec_id = resolved$spec_id,
        config_path = qdesn_m0v1_rel(config_path, repo_root),
        config_sha256 = qdesn_m0v1_sha256(config_path),
        observed_path = anchors$frozen_observed_path[[anchor_index]],
        observed_sha256 = anchors$observed_sha256[[anchor_index]],
        source_request_path = anchors$frozen_request_path[[anchor_index]],
        source_request_sha256 = anchors$frozen_request_sha256[[anchor_index]],
        desn_seed = anchors$desn_seed[[anchor_index]],
        mcmc_seed = resolved$mcmc_seed,
        mcmc_rng_seed = resolved$rng_seed,
        vb_warm_start_seed = resolved$vb_seed,
        synthesis_seed = resolved$synthesis_seed,
        n_burn = as.integer(budget_row$n_burn[[1L]]),
        n_mcmc = as.integer(budget_row$n_mcmc[[1L]]),
        thin = as.integer(budget_row$thin[[1L]]),
        core_update_mode = qdesn_m0v1_method_id,
        gamma_slice_width = 4,
        core_extra_passes = 0L,
        launch_status = "prepared_not_launched",
        stringsAsFactors = FALSE
      )
    }
  }
}
plan <- do.call(rbind, plan_rows)
if (nrow(plan) != 60L ||
    sum(plan$budget == "smoke") != 6L ||
    sum(plan$budget == "canary") != 9L ||
    sum(plan$budget == "full") != 45L ||
    anyDuplicated(plan$job_id) || anyDuplicated(plan$spec_id)) {
  stop("The 6/9/45 staged chain plan contract failed.", call. = FALSE)
}

anchors_path <- qdesn_m0v1_write_csv(anchors, paste0(stub, "_anchor_registry.csv"))
metric_path <- qdesn_m0v1_write_csv(metric_contract, paste0(stub, "_metric_contract.csv"))
budget_path <- qdesn_m0v1_write_csv(budget_contract, paste0(stub, "_budget_contract.csv"))
plan_path <- qdesn_m0v1_write_csv(plan, paste0(stub, "_chain_plan.csv"))
for (budget in c("smoke", "canary", "full")) {
  qdesn_m0v1_write_csv(
    plan[plan$budget == budget, , drop = FALSE],
    paste0(stub, "_", budget, "_chain_plan.csv")
  )
}

reference_manifest <- data.frame(
  role = c(
    "authoritative_v3_interface", "local_m0_implementation",
    "local_sampler_routing", "local_sampler_tests",
    "article_phase170_method_registry", "article_phase170_default_policy",
    "article_phase170_m0_implementation", "article_phase170_dispatch",
    "article_phase170_note"
  ),
  path = c(
    qdesn_m0v1_rel(authority_path, repo_root),
    "R/exal_mcmc_collapsed_scale_shape.R", "R/exal_mcmc_fit.R",
    "tests/testthat/test-exal-mcmc-collapsed-scale-shape.R",
    "Article-Q-DESN---Version-2:application/config/joint_exqdesn_inference_method_registry_v1.csv",
    "Article-Q-DESN---Version-2:application/config/joint_exqdesn_inference_default_policy_v1.csv",
    "Article-Q-DESN---Version-2:application/R/joint_qvp_qdesn.R",
    "Article-Q-DESN---Version-2:application/R/joint_exqdesn_inference_dispatch.R",
    "Article-Q-DESN---Version-2:docs/implementation_notes/joint_exqdesn_phase170_exact_mcmc_default_promotion_20260808.md"
  ),
  sha256 = c(
    qdesn_m0v1_authority_sha256,
    qdesn_m0v1_sha256(file.path(repo_root, "R", "exal_mcmc_collapsed_scale_shape.R")),
    qdesn_m0v1_sha256(file.path(repo_root, "R", "exal_mcmc_fit.R")),
    qdesn_m0v1_sha256(file.path(repo_root, "tests", "testthat", "test-exal-mcmc-collapsed-scale-shape.R")),
    "6d57a7017bfe6ca58e0a10fd47245fac766371cd32cbe2b09162a77a0506822d",
    "28343f6974dd3cbaac0ab04430cb9f6f0ae0cadc445e6d00395e121c80075d34",
    "ccdef9dfd5577afbc86a134259e8b1960743c085feb5b8145078709df7929d7f",
    "91d1c3e83ec92db51199d98cff9e9bc3ce2be7df76f268c29e09efa90d21e8dd",
    "502d850f8069aab560ce14a73c8040b67e764a66729209a9e4aaa97a6b47953f"
  ),
  source_commit = c(
    qdesn_m0v1_base_commit,
    rep("launch_commit_recorded_in_run_provenance", 3L),
    rep(qdesn_m0v1_reference_commit, 5L)
  ),
  stringsAsFactors = FALSE
)
reference_path <- qdesn_m0v1_write_csv(
  reference_manifest, paste0(stub, "_reference_manifest.csv")
)

generated <- c(
  anchors_path, metric_path, budget_path, plan_path,
  paste0(stub, "_smoke_chain_plan.csv"),
  paste0(stub, "_canary_chain_plan.csv"),
  paste0(stub, "_full_chain_plan.csv"), reference_path,
  list.files(request_dir, full.names = TRUE),
  list.files(input_dir, full.names = TRUE),
  list.files(config_dir, recursive = TRUE, full.names = TRUE)
)
generated <- sort(unique(normalizePath(generated, winslash = "/", mustWork = TRUE)))
file_manifest <- data.frame(
  path = vapply(generated, qdesn_m0v1_rel, character(1L), repo_root = repo_root),
  bytes = as.numeric(file.info(generated)$size),
  sha256 = vapply(generated, qdesn_m0v1_sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- qdesn_m0v1_write_csv(
  file_manifest, paste0(stub, "_file_manifest.csv")
)

qdesn_m0v1_write_json(list(
  schema_version = "independent_exal_m0_relaunch_v1",
  materialized_at = "2026-08-09",
  stage = qdesn_m0v1_stage,
  package_version = "1.0.0",
  branch = "validation/independent-exal-m0-relaunch-v1-1.0.0",
  exact_base_commit = qdesn_m0v1_base_commit,
  authoritative_interface_path = qdesn_m0v1_rel(authority_path, repo_root),
  authoritative_interface_sha256 = qdesn_m0v1_authority_sha256,
  source_registry_hash_value = qdesn_m0v1_registry_hash,
  method_id = "M0_v_collapsed_support_logit",
  package_method_id = qdesn_m0v1_method_id,
  anchors = nrow(anchors),
  metric_occurrences = nrow(metric_contract),
  planned_jobs = nrow(plan),
  jobs_by_stage = as.list(table(plan$budget)),
  parallel_workers = 20L,
  threads_per_worker = 1L,
  full_chains_per_anchor = 3L,
  article_update_automatic = FALSE,
  automatic_promotion = FALSE,
  diagnostic_status_filters_metrics = FALSE,
  file_manifest_path = qdesn_m0v1_rel(file_manifest_path, repo_root),
  file_manifest_sha256 = qdesn_m0v1_sha256(file_manifest_path)
), paste0(stub, "_materialization_manifest.json"))

cat(sprintf(
  "materialized: %d anchors; %d metric roles; %d smoke + %d canary + %d full chains\n",
  nrow(anchors), nrow(metric_contract), sum(plan$budget == "smoke"),
  sum(plan$budget == "canary"), sum(plan$budget == "full")
))
