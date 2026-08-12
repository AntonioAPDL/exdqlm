#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
  missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_lower_tail_cellwise_mcmc_v1.R"))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Lower-tail cellwise MCMC v1 requires exdqlm 1.0.0.", call. = FALSE)
}

output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "qdesn_lower_tail_cellwise_mcmc_v1_materialization")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
stub <- file.path(repo_root, "config", "validation", qdesn_ltcv1_stage)
source_cfg_path <- paste0(stub, "_sources.yaml")
source_cfg <- yaml::read_yaml(source_cfg_path)
parent_path <- paste0(stub, "_parent_controls.csv")
profile_path <- paste0(stub, "_candidate_profiles.csv")
use_frozen_designs <- has_flag("--use-frozen-designs") &&
  file.exists(parent_path) && file.exists(profile_path)

targets <- qdesn_ltcv1_targets(
  repo_root, freeze_requests = !has_flag("--use-frozen-designs")
)
target_path <- qdesn_ssv2_write_csv(targets, paste0(stub, "_target_cells.csv"))
history_path <- paste0(stub, "_history_signature_ledger.csv")
history <- if (file.exists(history_path) && !has_flag("--refresh-history")) {
  qdesn_ssv2_read_csv(history_path)
} else {
  qdesn_ssv2_history_ledger(repo_root)
}
history <- history[
  !grepl(qdesn_ltcv1_stage, history$source_file, fixed = TRUE), , drop = FALSE
]
history_path <- qdesn_ssv2_write_csv(history, history_path)

universe_path <- if (use_frozen_designs) NA_character_ else
  file.path(output_root, "virtual_candidate_universe.csv")
universe <- if (use_frozen_designs) {
  NULL
} else if (file.exists(universe_path) && !has_flag("--refresh-universe")) {
  qdesn_ssv2_read_csv(universe_path)
} else {
  qdesn_ssv2_virtual_universe()
}
if (!use_frozen_designs) {
  universe <- qdesn_ssv2_ensure_effective_dimension(universe)
  universe_path <- qdesn_ssv2_write_csv(universe, universe_path)
}

if (use_frozen_designs) {
  parents <- qdesn_ssv2_ensure_effective_dimension(qdesn_ssv2_read_csv(parent_path))
  profiles <- qdesn_ssv2_ensure_effective_dimension(qdesn_ssv2_read_csv(profile_path))
} else {
  parents <- qdesn_ltcv1_parent_profiles(repo_root, targets)
  profiles <- qdesn_ltcv1_candidate_profiles(parents, universe, history)
}
if (nrow(parents) != 10L || nrow(profiles) != 80L ||
    any(profiles$profile_signature %in% history$profile_signature)) {
  stop("Frozen parent/candidate profile contract failed.", call. = FALSE)
}
parent_path <- qdesn_ssv2_write_csv(parents, parent_path)
profile_path <- qdesn_ssv2_write_csv(profiles, profile_path)

replicates <- source_cfg$replicates
roles <- vapply(replicates, function(x) as.character(x$role), character(1L))
if (length(replicates) != 7L || sum(roles == "discovery") != 2L ||
    sum(roles == "replication") != 1L || sum(roles == "sealed_holdout") != 4L) {
  stop("Source contract must contain 2 discovery, 1 replication, and 4 sealed blocks.",
       call. = FALSE)
}
seed_rows <- list()
root_rows <- list()
for (i in seq_along(replicates)) {
  replicate <- replicates[[i]]
  family_profiles <- source_cfg$generation$family_profiles
  for (family in names(family_profiles)) {
    family_profiles[[family]]$seeds <- replicate$seeds[[family]]
    seed_rows[[length(seed_rows) + 1L]] <- data.frame(
      source_id = replicate$replicate_id, source_role = replicate$role,
      scenario = replicate$scenario_id, family = family,
      latent_seed = as.integer(replicate$seeds[[family]]$latent),
      noise_seed = as.integer(replicate$seeds[[family]]$noise),
      stringsAsFactors = FALSE
    )
  }
  manifest <- list(
    meta = list(
      study_id = source_cfg$meta$study_id,
      scenario_id = replicate$scenario_id,
      notes = sprintf("Lower-tail cellwise %s source %s.",
                      replicate$role, replicate$replicate_id)
    ),
    generation = utils::modifyList(
      source_cfg$generation, list(family_profiles = family_profiles)
    ),
    qdesn_materialization = list(staged_root = file.path(
      "results", "qdesn_mcmc_validation", qdesn_ltcv1_stage,
      "source_windows", replicate$scenario_id
    ))
  )
  source_parent <- as.character(source_cfg$generation$output_parent)
  if (!grepl("^/", source_parent)) source_parent <- file.path(repo_root, source_parent)
  cached <- file.path(source_parent, replicate$scenario_id,
                      "000__full_root_inventory.csv")
  roots <- if (file.exists(cached) && !has_flag("--refresh-sources")) {
    qdesn_ssv2_read_csv(cached)
  } else {
    exdqlm:::qdesn_dynamic_candidate_generate_bundle(
      manifest = manifest, repo_root = repo_root,
      refresh = has_flag("--refresh-sources"), verbose = TRUE
    )$root_inventory
  }
  roots$source_id <- replicate$replicate_id
  roots$source_role <- replicate$role
  root_rows[[i]] <- roots
}
seed_contract <- do.call(rbind, seed_rows)
if (anyDuplicated(c(seed_contract$latent_seed, seed_contract$noise_seed))) {
  stop("Every development source seed must be unique.", call. = FALSE)
}
source_roots <- do.call(rbind, root_rows)
source_roots <- source_roots[order(
  source_roots$source_id, source_roots$family, source_roots$tau
), , drop = FALSE]
seed_path <- qdesn_ssv2_write_csv(
  seed_contract, paste0(stub, "_source_seed_contract.csv")
)
source_registry_path <- qdesn_ssv2_write_csv(
  source_roots, file.path(output_root, "source_root_registry.csv")
)

window_cache <- new.env(parent = emptyenv())
window_rows <- list()
resolve_window <- function(profile, target, source_id) {
  key <- paste(
    source_id, target$family[[1L]], sprintf("%.2f", target$tau[[1L]]),
    profile$m[[1L]], profile$washout[[1L]], sep = "|"
  )
  if (exists(key, envir = window_cache, inherits = FALSE)) {
    return(get(key, envir = window_cache))
  }
  root <- source_roots[
    source_roots$source_id == source_id &
      source_roots$family == target$family[[1L]] &
      abs(source_roots$tau - target$tau[[1L]]) < 1e-10,
    , drop = FALSE
  ]
  if (nrow(root) != 1L) stop(sprintf("Cannot resolve source window %s.", key))
  staged <- qdesn_ssv2_stage_source_window(
    root, source_id, profile$m[[1L]], profile$washout[[1L]],
    file.path(repo_root, "results", "qdesn_mcmc_validation",
              qdesn_ltcv1_stage, "staged_source_windows")
  )
  assign(key, staged, envir = window_cache)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, source_id, stage, chain_id = 1L,
                      reservoir_seed_id = "r01") {
  source <- resolve_window(profile, target, source_id)
  job <- qdesn_ltcv1_make_job(
    repo_root, profile, target, source, stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  path <- file.path(output_root, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  data.frame(
    job_id = job$job_id, stage = stage, tier = target$tier[[1L]],
    target_cell_id = job$target_cell_id,
    likelihood_target = target$likelihood_target[[1L]],
    target_metrics = target$target_metrics[[1L]],
    candidate_id = job$candidate_id, chain_id = job$chain_id,
    reservoir_seed_id = job$reservoir_seed_id,
    source_id = job$source_id, source_role = job$source_role,
    objective_metric = job$objective_metric,
    current_value = job$current_value,
    comparator_value = job$comparator_value,
    config_path = path, config_sha256 = qdesn_ssv2_sha256(path),
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    effective_readout_dimension = job$root_spec$effective_readout_dimension,
    timeout_seconds = job$config$validation$timeout_seconds,
    stringsAsFactors = FALSE
  )
}

target_map <- split(targets, targets$target_cell_id)
tier_a_targets <- targets[targets$tier == "A", , drop = FALSE]
tier_a_ids <- tier_a_targets$target_cell_id
tier_a_profiles <- profiles[profiles$target_cell_id %in% tier_a_ids, , drop = FALSE]
tier_a_parents <- parents[parents$target_cell_id %in% tier_a_ids, , drop = FALSE]

smoke_profiles <- rbind(
  tier_a_profiles[tier_a_profiles$likelihood_target == "al", , drop = FALSE][1L, ],
  tier_a_profiles[tier_a_profiles$likelihood_target == "exal", , drop = FALSE][1L, ]
)
smoke_plan <- do.call(rbind, lapply(seq_len(nrow(smoke_profiles)), function(i) {
  p <- smoke_profiles[i, , drop = FALSE]
  write_job(p, target_map[[p$target_cell_id[[1L]]]], "dev09", "smoke")
}))

calibration_plan <- do.call(rbind, lapply(tier_a_ids, function(cell_id) {
  cell <- tier_a_profiles[tier_a_profiles$target_cell_id == cell_id, , drop = FALSE]
  p <- cell[which.max(cell$effective_readout_dimension), , drop = FALSE]
  write_job(p, target_map[[cell_id]], "dev09", "calibration")
}))

discovery_rows <- list()
k <- 0L
for (cell_id in tier_a_ids) {
  cell <- rbind(
    tier_a_profiles[tier_a_profiles$target_cell_id == cell_id, , drop = FALSE],
    tier_a_parents[tier_a_parents$target_cell_id == cell_id, , drop = FALSE]
  )
  for (i in seq_len(nrow(cell))) {
    for (source_id in c("dev09", "dev10")) {
      k <- k + 1L
      discovery_rows[[k]] <- write_job(
        cell[i, , drop = FALSE], target_map[[cell_id]], source_id,
        "tier_a_discovery", reservoir_seed_id = "r01"
      )
    }
  }
}
discovery_plan <- do.call(rbind, discovery_rows)
if (nrow(smoke_plan) != 2L || nrow(calibration_plan) != 6L ||
    nrow(discovery_plan) != 108L) {
  stop("Materialized plan counts do not match 2/6/108.", call. = FALSE)
}

plan_paths <- c(
  smoke = qdesn_ssv2_write_csv(
    smoke_plan, file.path(output_root, "smoke_plan.csv")
  ),
  calibration = qdesn_ssv2_write_csv(
    calibration_plan, file.path(output_root, "calibration_plan.csv")
  ),
  tier_a_discovery = qdesn_ssv2_write_csv(
    discovery_plan, file.path(output_root, "tier_a_discovery_plan.csv")
  )
)
window_registry <- unique(do.call(rbind, window_rows))
window_path <- qdesn_ssv2_write_csv(
  window_registry, file.path(output_root, "staged_source_window_registry.csv")
)

frozen_requests <- list.files(
  paste0(stub, "_frozen_parent_requests"), pattern = "[.]json$", full.names = TRUE
)
tracked_paths <- c(
  source_cfg_path, target_path, history_path, parent_path, profile_path,
  seed_path, frozen_requests,
  file.path(repo_root, "validation", "fitforecast_v2", "R",
            "qdesn_lower_tail_cellwise_mcmc_v1.R"),
  file.path(repo_root, "validation", "fitforecast_v2", "scripts", c(
    "materialize_qdesn_lower_tail_cellwise_mcmc_v1.R",
    "run_qdesn_lower_tail_cellwise_mcmc_v1_chain.R",
    "healthcheck_qdesn_lower_tail_cellwise_mcmc_v1.R",
    "verify_qdesn_lower_tail_cellwise_mcmc_v1.R",
    "advance_qdesn_lower_tail_cellwise_mcmc_v1.R",
    "run_qdesn_lower_tail_cellwise_mcmc_v1_pipeline.sh",
    "launch_qdesn_lower_tail_cellwise_mcmc_v1.sh"
  )),
  file.path(repo_root, "validation", "fitforecast_v2", "tests", "testthat",
            "test-qdesn-lower-tail-cellwise-mcmc-v1.R"),
  file.path(repo_root, "validation", "fitforecast_v2", "docs",
            "QDESN_LOWER_TAIL_CELLWISE_MCMC_V1_PROTOCOL_2026-08-11.md")
)
tracked_manifest <- data.frame(
  relative_path = vapply(tracked_paths, qdesn_ssv2_rel, character(1L),
                         repo_root = repo_root),
  bytes = as.numeric(file.info(tracked_paths)$size),
  sha256 = vapply(tracked_paths, qdesn_ssv2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
tracked_manifest_path <- qdesn_ssv2_write_csv(
  tracked_manifest, paste0(stub, "_tracked_manifest.csv")
)
manifest <- list(
  schema_version = "qdesn_lower_tail_cellwise_mcmc_v1_materialization_v1",
  generated_at = as.character(Sys.time()),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  package_version = "1.0.0",
  base_authority_commit = qdesn_ltcv1_base_commit,
  canonical_source_registry_hash_value = qdesn_ssv2_registry_hash,
  source_config_path = source_cfg_path,
  source_config_sha256 = qdesn_ssv2_sha256(source_cfg_path),
  source_registry_path = source_registry_path,
  source_registry_sha256 = qdesn_ssv2_sha256(source_registry_path),
  source_window_registry_path = window_path,
  source_window_registry_sha256 = qdesn_ssv2_sha256(window_path),
  virtual_universe_path = if (use_frozen_designs) NULL else universe_path,
  virtual_universe_sha256 = if (use_frozen_designs) NULL else
    qdesn_ssv2_sha256(universe_path),
  frozen_designs_used = use_frozen_designs,
  tracked_manifest_path = tracked_manifest_path,
  tracked_manifest_sha256 = qdesn_ssv2_sha256(tracked_manifest_path),
  plans = as.list(plan_paths),
  counts = list(
    target_cells = nrow(targets), tier_a_cells = nrow(tier_a_targets),
    tier_b_cells = sum(targets$tier == "B"), candidates = nrow(profiles),
    parent_controls = nrow(parents), historical_signatures = nrow(history),
    smoke_jobs = nrow(smoke_plan), calibration_jobs = nrow(calibration_plan),
    tier_a_discovery_jobs = nrow(discovery_plan)
  ),
  gates = list(
    tier_a_replication = "three candidates per cell after paired discovery evidence",
    tier_a_sealed = "two candidates per cell after development replication",
    confirmation = "metric-specific finalists; explicit human launch approval",
    tier_b = "cannot launch before Tier-A closeout",
    article = "unchanged until canonical full-budget confirmation"
  ),
  article_state = "v6_frozen_unchanged"
)
manifest_path <- qdesn_ssv2_write_json(
  manifest, file.path(output_root, "materialization_manifest.json")
)
cat(sprintf("materialization_manifest=%s\n", manifest_path))
cat(sprintf("targets=%d candidates=%d parents=%d history=%d\n",
            nrow(targets), nrow(profiles), nrow(parents), nrow(history)))
cat(sprintf("smoke=%d calibration=%d tier_a_discovery=%d\n",
            nrow(smoke_plan), nrow(calibration_plan), nrow(discovery_plan)))
cat(sprintf("source_registry_sha256=%s\n",
            qdesn_ssv2_sha256(source_registry_path)))
