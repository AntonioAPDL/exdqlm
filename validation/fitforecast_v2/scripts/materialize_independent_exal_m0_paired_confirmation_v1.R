#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("Missing package: %s", pkg), call. = FALSE)
    }
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

contract_path <- normalizePath(get_arg(
  "--contract",
  file.path(repo_root, "config", "validation",
            "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_paired_confirmation_v1.json")
), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "independent_exal_m0_paired_confirmation_v1_materialization")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

contract <- qdesn_ssv2_read_json(contract_path)
resolve_repo_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}
handoff_root <- resolve_repo_path(contract$sealed_handoff$root)
handoff_paths <- list(
  profiles = file.path(handoff_root, "canonical_confirmation_profiles.csv"),
  metric_selection = file.path(handoff_root, "paired_metric_selection_ledger.csv"),
  article_metric_baseline = file.path(handoff_root, "article_metric_baseline.csv"),
  target_contract = file.path(handoff_root, "corrected_target_contract.csv"),
  manifest = file.path(
    handoff_root,
    paste0(contract$sealed_handoff$promotion_id, "_manifest.json")
  )
)
expected_handoff_hashes <- c(
  profiles = contract$sealed_handoff$profiles_sha256,
  metric_selection = contract$sealed_handoff$metric_selection_sha256,
  article_metric_baseline = contract$sealed_handoff$article_metric_baseline_sha256,
  manifest = contract$sealed_handoff$manifest_sha256
)
observed_handoff_hashes <- vapply(
  handoff_paths[names(expected_handoff_hashes)], qdesn_ssv2_sha256, character(1L)
)
if (!identical(unname(observed_handoff_hashes), unname(expected_handoff_hashes))) {
  bad <- names(expected_handoff_hashes)[observed_handoff_hashes != expected_handoff_hashes]
  stop(sprintf("Sealed handoff hash mismatch: %s", paste(bad, collapse = ", ")),
       call. = FALSE)
}

handoff_manifest <- qdesn_ssv2_read_json(handoff_paths$manifest)
profiles <- qdesn_ssv2_read_csv(handoff_paths$profiles)
selection <- qdesn_ssv2_read_csv(handoff_paths$metric_selection)
article_baseline <- qdesn_ssv2_read_csv(handoff_paths$article_metric_baseline)
target_contract <- qdesn_ssv2_read_csv(handoff_paths$target_contract)
target_ids <- sort(as.character(contract$canonical_source$targets$target_cell_id))
eligible <- selection[
  selection$decision == "ELIGIBLE_FOR_CANONICAL_FULL_BUDGET_CONFIRMATION",
  , drop = FALSE
]
checks <- c(
  handoff_decision = identical(
    as.character(handoff_manifest$decision),
    "CALIBRATION_CLOSED_TWO_CANDIDATES_READY_FOR_FULL_CONFIRMATION"
  ),
  package_version = identical(as.character(contract$package_version), "1.0.0"),
  method = identical(as.character(contract$method_id), "M0_v_collapsed_support_logit"),
  registry = identical(as.character(contract$source_registry_hash_value),
                       qdesn_ssv2_registry_hash),
  profiles = nrow(profiles) == 2L &&
    identical(sort(profiles$target_cell_id), target_ids),
  eligible_metrics = nrow(eligible) == 3L &&
    identical(sort(unique(eligible$target_cell_id)), target_ids),
  baseline_metrics = nrow(article_baseline) == 6L &&
    identical(sort(unique(article_baseline$target_cell_id)), target_ids)
)
if (!all(checks)) {
  stop(sprintf("Confirmation handoff gate failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

targets <- profiles[, c(
  "target_cell_id", "family", "tau", "priority", "objective_metric",
  "current_value", "comparator_value", "parent_anchor_id"
), drop = FALSE]
targets$parent_request_path <- target_contract$parent_request_path[
  match(targets$target_cell_id, target_contract$target_cell_id)
]
targets$parent_request_sha256 <- target_contract$parent_request_sha256[
  match(targets$target_cell_id, target_contract$target_cell_id)
]
if (anyNA(targets$parent_request_path) || anyNA(targets$parent_request_sha256)) {
  stop("The selected target-to-parent request mapping is incomplete.", call. = FALSE)
}
targets$parent_request_path <- vapply(
  targets$parent_request_path, resolve_repo_path, character(1L)
)
if (!all(vapply(seq_len(nrow(targets)), function(i) {
  identical(qdesn_ssv2_sha256(targets$parent_request_path[[i]]),
            targets$parent_request_sha256[[i]])
}, logical(1L)))) {
  stop("A frozen parent fit request hash drifted.", call. = FALSE)
}

source_rows <- list()
for (i in seq_len(nrow(contract$canonical_source$targets))) {
  source_contract <- contract$canonical_source$targets[i, , drop = FALSE]
  target_id <- as.character(source_contract$target_cell_id[[1L]])
  family <- as.character(source_contract$family[[1L]])
  tau <- as.numeric(source_contract$tau[[1L]])
  tau_slug <- sub("[.]", "p", sprintf("%.2f", tau))
  source_dir <- file.path(
    resolve_repo_path(contract$canonical_source$root),
    contract$canonical_source$scenario, family, paste0("tau_", tau_slug)
  )
  series_path <- file.path(source_dir, "series_wide.csv")
  sim_path <- file.path(source_dir, "sim_output.rds")
  if (!file.exists(series_path) || !file.exists(sim_path)) {
    stop(sprintf("Canonical source is incomplete for %s.", target_id), call. = FALSE)
  }
  series <- qdesn_ssv2_read_csv(series_path)
  source_checks <- c(
    rows = nrow(series) == 10000L,
    schema = all(c("t", "y", "mu", "q_target", "eps") %in% names(series)),
    time = identical(as.integer(series$t), 1:10000),
    series_hash = identical(qdesn_ssv2_sha256(series_path),
                            as.character(source_contract$series_wide_sha256[[1L]])),
    sim_hash = identical(qdesn_ssv2_sha256(sim_path),
                         as.character(source_contract$sim_output_sha256[[1L]]))
  )
  if (!all(source_checks)) {
    stop(sprintf("Canonical source contract failed for %s: %s", target_id,
                 paste(names(source_checks)[!source_checks], collapse = ", ")),
         call. = FALSE)
  }
  target <- targets[targets$target_cell_id == target_id, , drop = FALSE]
  request <- qdesn_ssv2_read_json(target$parent_request_path[[1L]])
  historical_path <- normalizePath(request$root_spec$source_series_wide_path,
                                   winslash = "/", mustWork = TRUE)
  historical <- qdesn_ssv2_read_csv(historical_path)
  historical_start <- as.integer(request$root_spec$raw_start_source_index)
  shared_columns <- intersect(names(historical), names(series))
  canonical_window <- series[historical_start:10000, shared_columns, drop = FALSE]
  historical_window <- historical[, shared_columns, drop = FALSE]
  if (!isTRUE(all.equal(canonical_window, historical_window, tolerance = 0,
                        check.attributes = FALSE))) {
    stop(sprintf("Canonical source does not reproduce the frozen article window for %s.",
                 target_id), call. = FALSE)
  }
  source_rows[[i]] <- data.frame(
    source_id = "canonical_article", source_role = "canonical_confirmation",
    target_cell_id = target_id, scenario = contract$canonical_source$scenario,
    family = family, tau = tau,
    series_wide_path = normalizePath(series_path, winslash = "/", mustWork = TRUE),
    series_wide_sha256 = qdesn_ssv2_sha256(series_path),
    sim_output_path = normalizePath(sim_path, winslash = "/", mustWork = TRUE),
    sim_output_sha256 = qdesn_ssv2_sha256(sim_path),
    historical_window_path = historical_path,
    historical_window_sha256 = qdesn_ssv2_sha256(historical_path),
    historical_request_path = target$parent_request_path[[1L]],
    historical_request_sha256 = target$parent_request_sha256[[1L]],
    canonical_registry_hash_value = qdesn_ssv2_registry_hash,
    stringsAsFactors = FALSE
  )
}
source_registry <- do.call(rbind, source_rows)
source_registry_path <- qdesn_ssv2_write_csv(
  source_registry, file.path(output_root, "canonical_source_registry.csv")
)

plan_rows <- list(smoke = list(), confirmation = list())
window_rows <- list()
for (i in seq_len(nrow(profiles))) {
  profile <- profiles[i, , drop = FALSE]
  target <- targets[targets$target_cell_id == profile$target_cell_id[[1L]], , drop = FALSE]
  source_row <- source_registry[
    source_registry$target_cell_id == profile$target_cell_id[[1L]], , drop = FALSE
  ]
  staged <- qdesn_ssv2_stage_source_window(
    source_row, "canonical_article", profile$m[[1L]], profile$washout[[1L]],
    file.path(output_root, "canonical_windows")
  )
  staged$target_cell_id <- profile$target_cell_id[[1L]]
  staged$canonical_series_wide_sha256 <- source_row$series_wide_sha256[[1L]]
  window_rows[[i]] <- staged
  for (stage in c("smoke", "confirmation")) {
    chain_ids <- if (stage == "smoke") 1L else 1:3
    for (chain_id in chain_ids) {
      job <- qdesn_ssv2_make_job(
        repo_root, profile, target, staged, stage, source_registry_path, chain_id
      )
      job$study_contract$confirmation_scope <-
        "paired_repair_two_candidate_canonical_full_budget"
      job$study_contract$sealed_handoff_id <- contract$sealed_handoff$promotion_id
      job$study_contract$sealed_handoff_manifest_path <- handoff_paths$manifest
      job$study_contract$sealed_handoff_manifest_sha256 <-
        qdesn_ssv2_sha256(handoff_paths$manifest)
      job$study_contract$selection_evidence_path <- handoff_paths$metric_selection
      job$study_contract$selection_evidence_sha256 <-
        qdesn_ssv2_sha256(handoff_paths$metric_selection)
      job$study_contract$article_metric_baseline_path <-
        handoff_paths$article_metric_baseline
      job$study_contract$article_metric_baseline_sha256 <-
        qdesn_ssv2_sha256(handoff_paths$article_metric_baseline)
      job$study_contract$all_confirmation_metrics <-
        as.list(contract$promotion_contract$metrics)
      job$study_contract$promotion_contract <- contract$promotion_contract
      job$study_contract$article_promotion_automatic <- FALSE
      config_path <- file.path(output_root, "configs", stage,
                               paste0(job$job_id, ".json"))
      qdesn_ssv2_write_json(job, config_path)
      plan_rows[[stage]][[length(plan_rows[[stage]]) + 1L]] <- data.frame(
        job_id = job$job_id, stage = stage,
        target_cell_id = job$target_cell_id, family = target$family[[1L]],
        tau = target$tau[[1L]], candidate_id = job$candidate_id,
        chain_id = job$chain_id, reservoir_seed_id = job$reservoir_seed_id,
        reservoir_seed = job$reservoir_seed, source_id = job$source_id,
        source_role = job$source_role, objective_metric = job$objective_metric,
        current_value = job$current_value, comparator_value = job$comparator_value,
        config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
        config_sha256 = qdesn_ssv2_sha256(config_path),
        n_burn = job$config$inference$mcmc$n_burn,
        n_mcmc = job$config$inference$mcmc$n_mcmc,
        expected_n_burn = job$config$inference$mcmc$n_burn,
        expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
        thin = job$config$inference$mcmc$thin,
        mcmc_seed = job$config$inference$mcmc$control$seed,
        mcmc_rng_seed = job$config$inference$mcmc$control$rng_seed,
        vb_warm_start_seed = job$config$inference$mcmc$vb_warm_start_seed,
        inference_method_id = job$inference_method_id,
        source_registry_hash_value = job$source_registry_hash_value,
        article_promotion_automatic = FALSE,
        stringsAsFactors = FALSE
      )
    }
  }
}

plans <- lapply(plan_rows, function(rows) do.call(rbind, rows))
expected <- c(smoke = 2L, confirmation = 6L)
for (stage in names(plans)) {
  plan <- plans[[stage]]
  if (nrow(plan) != expected[[stage]] || anyDuplicated(plan$job_id) ||
      !identical(sort(unique(plan$target_cell_id)), target_ids)) {
    stop(sprintf("%s plan violated its cardinality contract.", stage), call. = FALSE)
  }
}
if (any(table(plans$confirmation$target_cell_id) != 3L) ||
    any(table(plans$smoke$target_cell_id) != 1L)) {
  stop("Per-candidate chain counts are invalid.", call. = FALSE)
}
plan_paths <- lapply(names(plans), function(stage) {
  qdesn_ssv2_write_csv(plans[[stage]], file.path(output_root, paste0(stage, "_plan.csv")))
})
names(plan_paths) <- names(plans)
window_path <- qdesn_ssv2_write_csv(
  do.call(rbind, window_rows), file.path(output_root, "canonical_window_registry.csv")
)
materialization_manifest_path <- qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()),
  schema_version = contract$schema_version,
  package_version = contract$package_version,
  method_id = contract$method_id,
  validation_branch = contract$validation_branch,
  validation_commit = system("git rev-parse HEAD", intern = TRUE),
  contract = list(path = contract_path, sha256 = qdesn_ssv2_sha256(contract_path)),
  sealed_handoff = list(
    promotion_id = contract$sealed_handoff$promotion_id,
    manifest_path = handoff_paths$manifest,
    manifest_sha256 = qdesn_ssv2_sha256(handoff_paths$manifest)
  ),
  target_cells = as.list(target_ids), candidates = nrow(profiles),
  smoke = list(jobs = nrow(plans$smoke), n_burn = 4L, n_mcmc = 4L,
               plan_path = plan_paths$smoke,
               plan_sha256 = qdesn_ssv2_sha256(plan_paths$smoke)),
  confirmation = list(jobs = nrow(plans$confirmation), chains_per_candidate = 3L,
                      n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
                      plan_path = plan_paths$confirmation,
                      plan_sha256 = qdesn_ssv2_sha256(plan_paths$confirmation)),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  source_registry = list(path = source_registry_path,
                         sha256 = qdesn_ssv2_sha256(source_registry_path)),
  canonical_windows = list(path = window_path, sha256 = qdesn_ssv2_sha256(window_path)),
  rolling_origin_contract = contract$fit_forecast_contract,
  promotion_contract = contract$promotion_contract,
  storage_policy = contract$storage_policy,
  article_promotion_automatic = FALSE
), file.path(output_root, "materialization_manifest.json"))

cat(sprintf(
  "paired_confirmation candidates=%d smoke_jobs=%d confirmation_jobs=%d manifest=%s\n",
  nrow(profiles), nrow(plans$smoke), nrow(plans$confirmation),
  materialization_manifest_path
))
