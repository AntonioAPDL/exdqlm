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
            "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_paired_rolling_repair_v1.json")
), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "independent_exal_m0_paired_rolling_repair_v1_materialization")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

contract <- qdesn_ssv2_read_json(contract_path)
resolve_input <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}
inputs <- lapply(contract$inputs, resolve_input)
rebaseline_manifest_path <- file.path(
  inputs$rebaseline_root, "rolling_metric_contract_manifest.json"
)
rebaseline_manifest <- qdesn_ssv2_read_json(rebaseline_manifest_path)
cell_gap_path <- file.path(
  inputs$rebaseline_root, "qdesn_comparator_cell_priority_ledger.csv"
)
metric_gap_path <- file.path(
  inputs$rebaseline_root, "qdesn_comparator_metric_gap_ledger.csv"
)
if (!file.exists(cell_gap_path) || !file.exists(metric_gap_path)) {
  stop("The rolling-origin rebaseline outputs are incomplete.", call. = FALSE)
}
manifest_cell_hash <- as.character(
  rebaseline_manifest$outputs$cell_priority_ledger$sha256
)
manifest_metric_hash <- as.character(
  rebaseline_manifest$outputs$metric_gap_ledger$sha256
)
if (!identical(qdesn_ssv2_sha256(cell_gap_path), manifest_cell_hash) ||
    !identical(qdesn_ssv2_sha256(metric_gap_path), manifest_metric_hash) ||
    as.integer(rebaseline_manifest$unresolved_rows) != 0L) {
  stop("The rolling-origin rebaseline manifest/hash contract failed.", call. = FALSE)
}

cell_gap <- qdesn_ssv2_read_csv(cell_gap_path)
metric_gap <- qdesn_ssv2_read_csv(metric_gap_path)
cell_gap <- cell_gap[
  cell_gap$inference == as.character(contract$target_inference) &
    cell_gap$model_variant == as.character(contract$target_model_variant) &
    cell_gap$metrics_gap_gt_5pct > 0,
  , drop = FALSE
]
if (nrow(cell_gap) != 7L) {
  stop(sprintf("Expected seven corrected exAL MCMC target cells; found %d.", nrow(cell_gap)),
       call. = FALSE)
}

metric_name <- c(
  fit_rmse = "fit_qtrue_rmse",
  forecast_mae = "forecast_qtrue_mae_H1000",
  forecast_check = "forecast_check_loss_H1000"
)
target_rows <- lapply(seq_len(nrow(cell_gap)), function(i) {
  cell <- cell_gap[i, , drop = FALSE]
  metrics <- metric_gap[
    metric_gap$inference == cell$inference &
      metric_gap$model_variant == cell$model_variant &
      metric_gap$family == cell$family &
      abs(metric_gap$tau - cell$tau) < 1e-10,
    , drop = FALSE
  ]
  gaps <- metrics[metrics$outcome == "GAP_GT_5PCT", , drop = FALSE]
  primary <- gaps[which.max(gaps$relative_gap_pct), , drop = FALSE]
  target_cell_id <- sprintf(
    "%s_t%s", cell$family[[1L]],
    sub("[.]", "p", sprintf("%.2f", cell$tau[[1L]]))
  )
  data.frame(
    target_cell_id = target_cell_id,
    family = cell$family[[1L]],
    tau = as.numeric(cell$tau[[1L]]),
    priority = cell$priority[[1L]],
    objective_metric = unname(metric_name[[primary$metric[[1L]]]]),
    current_value = as.numeric(primary$qdesn_value[[1L]]),
    comparator_model = primary$comparator_model[[1L]],
    comparator_value = as.numeric(primary$comparator_value[[1L]]),
    current_gap_percent = as.numeric(primary$relative_gap_pct[[1L]]),
    companion_metrics = paste(gaps$metric, collapse = ";"),
    rolling_rebaseline_manifest = normalizePath(
      rebaseline_manifest_path, winslash = "/", mustWork = TRUE
    ),
    rolling_rebaseline_manifest_sha256 = qdesn_ssv2_sha256(
      rebaseline_manifest_path
    ),
    stringsAsFactors = FALSE
  )
})
targets <- do.call(rbind, target_rows)
historical_targets <- qdesn_ssv2_read_csv(file.path(
  repo_root, "config", "validation",
  paste0(qdesn_ssv2_stage, "_target_cells.csv")
))
targets$parent_anchor_id <- historical_targets$parent_anchor_id[
  match(targets$target_cell_id, historical_targets$target_cell_id)
]
targets$parent_request_path <- historical_targets$parent_request_path[
  match(targets$target_cell_id, historical_targets$target_cell_id)
]
targets$parent_request_path <- vapply(targets$parent_request_path, function(path) {
  resolve_input(path)
}, character(1L))
targets$parent_request_sha256 <- vapply(
  targets$parent_request_path, qdesn_ssv2_sha256, character(1L)
)
if (anyNA(targets$parent_anchor_id) || anyNA(targets$parent_request_sha256)) {
  stop("The corrected target-to-parent request mapping is incomplete.", call. = FALSE)
}
targets <- targets[order(-targets$current_gap_percent, targets$target_cell_id), , drop = FALSE]
targets_path <- qdesn_ssv2_write_csv(
  targets, file.path(output_root, "corrected_target_contract.csv")
)

parents <- qdesn_ssv2_read_csv(inputs$parent_profiles)
finalists <- qdesn_ssv2_read_csv(inputs$prior_screen_profiles)
ranking <- qdesn_ssv2_read_csv(inputs$prior_screen_ranking)
parents <- parents[match(targets$target_cell_id, parents$target_cell_id), , drop = FALSE]
finalists <- finalists[match(targets$target_cell_id, finalists$target_cell_id), , drop = FALSE]
ranking <- ranking[match(targets$target_cell_id, ranking$target_cell_id), , drop = FALSE]
if (anyNA(parents$candidate_id) || anyNA(finalists$candidate_id) ||
    anyNA(ranking$candidate_id) ||
    !identical(as.character(finalists$candidate_id), as.character(ranking$candidate_id))) {
  stop("Parent/finalist profile alignment failed.", call. = FALSE)
}
parents$candidate_role <- "current_anchor"
finalists$candidate_role <- "prior_screen_finalist"
profiles <- rbind(parents, finalists)
profiles$current_value <- targets$current_value[
  match(profiles$target_cell_id, targets$target_cell_id)
]
profiles$comparator_value <- targets$comparator_value[
  match(profiles$target_cell_id, targets$target_cell_id)
]
profiles$objective_metric <- targets$objective_metric[
  match(profiles$target_cell_id, targets$target_cell_id)
]
profiles$profile_source_path <- ifelse(
  profiles$candidate_role == "current_anchor", inputs$parent_profiles,
  inputs$prior_screen_profiles
)
profiles$profile_source_sha256 <- vapply(
  profiles$profile_source_path, qdesn_ssv2_sha256, character(1L)
)
if (anyDuplicated(paste(profiles$target_cell_id, profiles$candidate_role)) ||
    any(profiles$effective_readout_dimension > qdesn_ssv2_max_effective_readout_dimension)) {
  stop("Candidate-pair profile contract failed.", call. = FALSE)
}
profiles_path <- qdesn_ssv2_write_csv(
  profiles, file.path(output_root, "paired_candidate_profiles.csv")
)

source_registry <- qdesn_ssv2_read_csv(inputs$source_root_registry)
development_ids <- unlist(contract$development_source_ids, use.names = FALSE)
source_registry <- source_registry[source_registry$source_id %in% development_ids, , drop = FALSE]
source_registry <- source_registry[
  paste(source_registry$family, sprintf("%.2f", source_registry$tau)) %in%
    paste(targets$family, sprintf("%.2f", targets$tau)),
  , drop = FALSE
]
if (nrow(source_registry) != length(development_ids) * nrow(targets) ||
    any(!file.exists(source_registry$series_wide_path)) ||
    any(vapply(seq_len(nrow(source_registry)), function(i) {
      !identical(
        qdesn_ssv2_sha256(source_registry$series_wide_path[[i]]),
        source_registry$series_wide_sha256[[i]]
      )
    }, logical(1L)))) {
  stop("Development source registry/hash contract failed.", call. = FALSE)
}
source_registry_path <- qdesn_ssv2_write_csv(
  source_registry, file.path(output_root, "paired_source_registry.csv")
)

window_cache <- new.env(parent = emptyenv())
get_window <- function(profile, target, source_id) {
  key <- paste(
    source_id, target$family[[1L]], sprintf("%.2f", target$tau[[1L]]),
    profile$m[[1L]], profile$washout[[1L]], sep = "|"
  )
  if (!exists(key, envir = window_cache, inherits = FALSE)) {
    root <- source_registry[
      source_registry$source_id == source_id &
        source_registry$family == target$family[[1L]] &
        abs(source_registry$tau - target$tau[[1L]]) < 1e-10,
      , drop = FALSE
    ]
    staged <- qdesn_ssv2_stage_source_window(
      root, source_id, profile$m[[1L]], profile$washout[[1L]],
      file.path(output_root, "source_windows")
    )
    assign(key, staged, envir = window_cache)
  }
  get(key, envir = window_cache, inherits = FALSE)
}

configure_required_rolling <- function(job) {
  rolling <- contract$rolling_origin_contract
  job$config$metrics$rolling_origin$enabled <- TRUE
  job$config$metrics$rolling_origin$max_lead_configured <- as.integer(rolling$max_lead)
  job$config$metrics$rolling_origin$origin_stride <- as.integer(rolling$origin_stride)
  job$config$metrics$rolling_origin$refit_per_origin <- isTRUE(rolling$refit_per_origin)
  job$config$metrics$rolling_origin$require_lead_export <- isTRUE(rolling$require_lead_export)
  job$study_contract$campaign_id <- "independent_exal_m0_paired_rolling_repair_v1"
  job$study_contract$rolling_rebaseline_manifest <- normalizePath(
    rebaseline_manifest_path, winslash = "/", mustWork = TRUE
  )
  job$study_contract$rolling_rebaseline_manifest_sha256 <- qdesn_ssv2_sha256(
    rebaseline_manifest_path
  )
  job$study_contract$candidate_role <- job$profile$candidate_role
  job$study_contract$paired_factors <- c("source_id", "reservoir_seed_id")
  job$study_contract$article_promotion_automatic <- FALSE
  job
}

materialize_plan <- function(stage, source_ids, reservoir_ids, target_ids = NULL) {
  rows <- list()
  k <- 0L
  selected_targets <- targets
  if (!is.null(target_ids)) {
    selected_targets <- selected_targets[selected_targets$target_cell_id %in% target_ids,
                                         , drop = FALSE]
  }
  for (i in seq_len(nrow(selected_targets))) {
    target <- selected_targets[i, , drop = FALSE]
    paired_profiles <- profiles[profiles$target_cell_id == target$target_cell_id[[1L]],
                                , drop = FALSE]
    for (source_id in source_ids) {
      for (reservoir_id in reservoir_ids) {
        for (j in seq_len(nrow(paired_profiles))) {
          profile <- paired_profiles[j, , drop = FALSE]
          source <- get_window(profile, target, source_id)
          job <- qdesn_ssv2_make_job(
            repo_root, profile, target, source, stage, source_registry_path,
            chain_id = 1L, reservoir_seed_id = reservoir_id
          )
          job <- configure_required_rolling(job)
          config_path <- file.path(output_root, "configs", stage,
                                   paste0(job$job_id, ".json"))
          qdesn_ssv2_write_json(job, config_path)
          k <- k + 1L
          rows[[k]] <- data.frame(
            job_id = job$job_id,
            stage = stage,
            target_cell_id = job$target_cell_id,
            family = target$family[[1L]],
            tau = target$tau[[1L]],
            candidate_id = job$candidate_id,
            candidate_role = profile$candidate_role[[1L]],
            source_id = job$source_id,
            source_latent_seed = source$source_latent_seed[[1L]],
            source_noise_seed = source$source_noise_seed[[1L]],
            reservoir_seed_id = job$reservoir_seed_id,
            reservoir_seed = job$reservoir_seed,
            mcmc_seed = job$config$inference$mcmc$control$seed,
            objective_metric = job$objective_metric,
            current_value = job$current_value,
            comparator_value = job$comparator_value,
            n_burn = job$config$inference$mcmc$n_burn,
            n_mcmc = job$config$inference$mcmc$n_mcmc,
            config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
            config_sha256 = qdesn_ssv2_sha256(config_path),
            method_id = job$inference_method_id,
            require_lead_export = job$config$metrics$rolling_origin$require_lead_export,
            article_promotion_automatic = FALSE,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  do.call(rbind, rows)
}

smoke_plan <- materialize_plan(
  "smoke", as.character(contract$smoke$source_id),
  as.character(contract$smoke$reservoir_seed_id),
  as.character(contract$smoke$target_cell_id)
)
calibration_plan <- materialize_plan(
  "calibration", development_ids,
  unlist(contract$reservoir_seed_ids, use.names = FALSE)
)

pair_contract <- function(plan) {
  key <- paste(plan$target_cell_id, plan$source_id, plan$reservoir_seed_id, sep = "|")
  groups <- split(plan, key)
  checks <- vapply(groups, function(x) {
    nrow(x) == 2L &&
      identical(sort(x$candidate_role), sort(c("current_anchor", "prior_screen_finalist"))) &&
      length(unique(x$reservoir_seed)) == 1L &&
      length(unique(x$source_latent_seed)) == 1L &&
      length(unique(x$source_noise_seed)) == 1L &&
      length(unique(x$mcmc_seed)) == 2L
  }, logical(1L))
  list(groups = length(groups), pass = sum(checks), failed = names(checks)[!checks])
}
smoke_pair <- pair_contract(smoke_plan)
calibration_pair <- pair_contract(calibration_plan)
expected_calibration <- as.integer(contract$calibration$expected_jobs)
if (nrow(smoke_plan) != 2L || nrow(calibration_plan) != expected_calibration ||
    anyDuplicated(smoke_plan$job_id) || anyDuplicated(calibration_plan$job_id) ||
    length(smoke_pair$failed) || length(calibration_pair$failed) ||
    !all(smoke_plan$require_lead_export) || !all(calibration_plan$require_lead_export)) {
  stop("Paired materialization invariants failed.", call. = FALSE)
}

smoke_path <- qdesn_ssv2_write_csv(
  smoke_plan, file.path(output_root, "smoke_plan.csv")
)
calibration_path <- qdesn_ssv2_write_csv(
  calibration_plan, file.path(output_root, "calibration_plan.csv")
)
manifest <- list(
  generated_at = as.character(Sys.time()),
  schema_version = "independent_exal_m0_paired_rolling_repair_v1_materialization",
  package_version = "1.0.0",
  method_id = "M0_v_collapsed_support_logit",
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  rolling_contract = contract$rolling_origin_contract,
  target_cells = nrow(targets),
  candidate_roles = as.list(unlist(contract$candidate_roles, use.names = FALSE)),
  development_sources = as.list(development_ids),
  reservoir_seed_ids = as.list(unlist(contract$reservoir_seed_ids, use.names = FALSE)),
  smoke_jobs = nrow(smoke_plan),
  calibration_jobs = nrow(calibration_plan),
  calibration_launch_state = "PREPARED_NOT_APPROVED_NOT_LAUNCHED",
  paired_contract = list(
    smoke_groups = smoke_pair$groups, smoke_pass = smoke_pair$pass,
    calibration_groups = calibration_pair$groups,
    calibration_pass = calibration_pair$pass
  ),
  inputs = list(
    contract = list(path = contract_path, sha256 = qdesn_ssv2_sha256(contract_path)),
    rebaseline_manifest = list(
      path = normalizePath(rebaseline_manifest_path, winslash = "/", mustWork = TRUE),
      sha256 = qdesn_ssv2_sha256(rebaseline_manifest_path)
    ),
    prior_screen_ranking = list(
      path = inputs$prior_screen_ranking,
      sha256 = qdesn_ssv2_sha256(inputs$prior_screen_ranking)
    )
  ),
  outputs = list(
    targets = list(path = targets_path, sha256 = qdesn_ssv2_sha256(targets_path)),
    profiles = list(path = profiles_path, sha256 = qdesn_ssv2_sha256(profiles_path)),
    sources = list(path = source_registry_path,
                   sha256 = qdesn_ssv2_sha256(source_registry_path)),
    smoke_plan = list(path = smoke_path, sha256 = qdesn_ssv2_sha256(smoke_path)),
    calibration_plan = list(path = calibration_path,
                            sha256 = qdesn_ssv2_sha256(calibration_path))
  ),
  article_promotion_automatic = FALSE,
  full_confirmation_requires_explicit_approval = TRUE
)
manifest_path <- qdesn_ssv2_write_json(
  manifest, file.path(output_root, "materialization_manifest.json")
)
cat(sprintf(
  "targets=%d smoke_jobs=%d calibration_jobs=%d paired_groups=%d launch_state=%s\n",
  nrow(targets), nrow(smoke_plan), nrow(calibration_plan),
  calibration_pair$groups, manifest$calibration_launch_state
))
cat(sprintf("materialization_manifest=%s\n", manifest_path))
