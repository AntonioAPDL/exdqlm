#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
  missing <- required[!vapply(required, requireNamespace, logical(1L),
                              quietly = TRUE)]
  if (length(missing)) {
    stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")))
  }
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
                 "qdesn_postm0_legacy_recheck_v1.R"))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("The post-M0 legacy recheck requires exdqlm 1.0.0.", call. = FALSE)
}
output_root <- normalizePath(get_arg(
  "--output-root", file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    "qdesn_postm0_legacy_recheck_v1_materialization"
  )
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
stub <- file.path(repo_root, "config", "validation", qdesn_plrv1_stage)
source_cfg_path <- paste0(stub, "_sources.yaml")
source_cfg <- yaml::read_yaml(source_cfg_path)
parent_path <- paste0(stub, "_parent_controls.csv")
profile_path <- paste0(stub, "_candidate_profiles.csv")
use_frozen <- has_flag("--use-frozen-designs") && file.exists(parent_path) &&
  file.exists(profile_path)

targets <- qdesn_plrv1_targets(repo_root, freeze_requests = !use_frozen)
target_path <- qdesn_ssv2_write_csv(targets, paste0(stub, "_target_cells.csv"))
history <- qdesn_plrv1_history_audit(repo_root)
postm0 <- qdesn_plrv1_postm0_signatures(repo_root)
history_rows_path <- qdesn_ssv2_write_csv(
  history$rows, paste0(stub, "_historical_evidence_rows.csv")
)
history_signature_path <- qdesn_ssv2_write_csv(
  history$signatures, paste0(stub, "_historical_signature_evidence.csv")
)
postm0_path <- qdesn_ssv2_write_csv(
  postm0, paste0(stub, "_postm0_signature_coverage.csv")
)

if (use_frozen) {
  parents <- qdesn_ssv2_ensure_effective_dimension(
    qdesn_ssv2_read_csv(parent_path)
  )
  profiles <- qdesn_ssv2_ensure_effective_dimension(
    qdesn_ssv2_read_csv(profile_path)
  )
  selection_audit <- qdesn_ssv2_read_csv(
    paste0(stub, "_candidate_selection_audit.csv")
  )
} else {
  parents <- qdesn_ltcv1_parent_profiles(repo_root, targets)
  selection <- qdesn_plrv1_candidate_profiles(
    repo_root, parents, targets, postm0
  )
  profiles <- selection$profiles
  selection_audit <- selection$audit
}
if (nrow(parents) != 5L || nrow(profiles) != 40L ||
    any(table(profiles$target_cell_id) != 8L) ||
    any(profiles$profile_signature %in% postm0$profile_signature)) {
  stop("Frozen parent/candidate evidence contract failed.", call. = FALSE)
}
parent_path <- qdesn_ssv2_write_csv(parents, parent_path)
profile_path <- qdesn_ssv2_write_csv(profiles, profile_path)
selection_audit_path <- qdesn_ssv2_write_csv(
  selection_audit, paste0(stub, "_candidate_selection_audit.csv")
)

replicates <- source_cfg$replicates
roles <- vapply(replicates, function(x) as.character(x$role), character(1L))
if (length(replicates) != 7L || sum(roles == "discovery") != 2L ||
    sum(roles == "replication") != 1L || sum(roles == "sealed_holdout") != 4L) {
  stop("Sources require 2 discovery, 1 replication, and 4 sealed blocks.",
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
      notes = sprintf("Post-M0 legacy recheck %s source %s.",
                      replicate$role, replicate$replicate_id)
    ),
    generation = utils::modifyList(
      source_cfg$generation, list(family_profiles = family_profiles)
    ),
    qdesn_materialization = list(staged_root = file.path(
      "results", "qdesn_mcmc_validation", qdesn_plrv1_stage,
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
  stop("Every source seed must be unique.", call. = FALSE)
}
seed_path <- qdesn_ssv2_write_csv(
  seed_contract, paste0(stub, "_source_seed_contract.csv")
)
source_roots <- do.call(rbind, root_rows)
source_roots <- source_roots[order(
  source_roots$source_id, source_roots$family, source_roots$tau
), , drop = FALSE]
source_registry_path <- qdesn_ssv2_write_csv(
  source_roots, file.path(output_root, "source_root_registry.csv")
)

window_cache <- new.env(parent = emptyenv())
window_rows <- list()
resolve_window <- function(profile, target, source_id) {
  key <- paste(source_id, target$family[[1L]], sprintf("%.2f", target$tau[[1L]]),
               profile$m[[1L]], profile$washout[[1L]], sep = "|")
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
              qdesn_plrv1_stage, "staged_source_windows")
  )
  assign(key, staged, envir = window_cache)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, source_id, stage, chain_id = 1L,
                      reservoir_seed_id = "r01") {
  source <- resolve_window(profile, target, source_id)
  job <- qdesn_plrv1_make_job(
    repo_root, profile, target, source, stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  path <- file.path(output_root, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  data.frame(
    job_id = job$job_id, stage = stage, tier = "A",
    target_cell_id = job$target_cell_id, likelihood_target = "exal",
    target_metrics = target$target_metrics[[1L]], candidate_id = job$candidate_id,
    chain_id = job$chain_id, reservoir_seed_id = job$reservoir_seed_id,
    source_id = job$source_id, source_role = job$source_role,
    objective_metric = job$objective_metric, current_value = job$current_value,
    comparator_value = job$comparator_value, config_path = path,
    config_sha256 = qdesn_ssv2_sha256(path),
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    effective_readout_dimension = job$root_spec$effective_readout_dimension,
    timeout_seconds = job$config$validation$timeout_seconds,
    historical_evidence_class =
      as.character(job$study_contract$historical_evidence_class),
    stringsAsFactors = FALSE
  )
}

target_map <- split(targets, targets$target_cell_id)
smoke_cell <- targets$target_cell_id[[1L]]
smoke_candidate <- profiles[profiles$target_cell_id == smoke_cell, , drop = FALSE][1L, ]
smoke_parent <- parents[parents$target_cell_id == smoke_cell, , drop = FALSE]
smoke_plan <- rbind(
  write_job(smoke_candidate, target_map[[smoke_cell]], "dev30", "smoke"),
  write_job(smoke_parent, target_map[[smoke_cell]], "dev30", "smoke")
)
calibration_plan <- do.call(rbind, lapply(targets$target_cell_id, function(cell) {
  p <- profiles[profiles$target_cell_id == cell, , drop = FALSE]
  p <- p[which.max(p$effective_readout_dimension), , drop = FALSE]
  write_job(p, target_map[[cell]], "dev30", "calibration")
}))
discovery_rows <- list()
k <- 0L
for (cell in targets$target_cell_id) {
  cell_profiles <- .qdesn_ltcv1_bind_fill(
    profiles[profiles$target_cell_id == cell, , drop = FALSE],
    parents[parents$target_cell_id == cell, , drop = FALSE]
  )
  for (i in seq_len(nrow(cell_profiles))) {
    for (source_id in c("dev30", "dev31")) {
      k <- k + 1L
      discovery_rows[[k]] <- write_job(
        cell_profiles[i, , drop = FALSE], target_map[[cell]], source_id,
        "tier_a_discovery", reservoir_seed_id = "r01"
      )
    }
  }
}
discovery_plan <- do.call(rbind, discovery_rows)
if (nrow(smoke_plan) != 2L || nrow(calibration_plan) != 5L ||
    nrow(discovery_plan) != 90L) {
  stop("Materialized plan counts do not match 2/5/90.", call. = FALSE)
}
plan_paths <- c(
  smoke = qdesn_ssv2_write_csv(smoke_plan, file.path(output_root, "smoke_plan.csv")),
  calibration = qdesn_ssv2_write_csv(
    calibration_plan, file.path(output_root, "calibration_plan.csv")
  ),
  tier_a_discovery = qdesn_ssv2_write_csv(
    discovery_plan, file.path(output_root, "tier_a_discovery_plan.csv")
  )
)
window_path <- qdesn_ssv2_write_csv(
  unique(do.call(rbind, window_rows)),
  file.path(output_root, "staged_source_window_registry.csv")
)

tracked_manifest <- qdesn_plrv1_tracked_manifest(repo_root)
tracked_manifest_path <- qdesn_ssv2_write_csv(
  tracked_manifest, paste0(stub, "_tracked_manifest.csv")
)
manifest <- list(
  schema_version = "qdesn_postm0_legacy_recheck_v1_materialization_v1",
  generated_at = as.character(Sys.time()),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  package_version = "1.0.0", base_authority_commit = qdesn_plrv1_base_commit,
  canonical_source_registry_hash_value = qdesn_ssv2_registry_hash,
  frozen_history_rows = nrow(history$rows),
  frozen_history_unique_signatures = nrow(history$signatures),
  frozen_history_sha256 = history$source_sha256,
  postm0_exact_signature_rows = nrow(postm0),
  postm0_exact_unique_signatures = length(unique(postm0$profile_signature)),
  source_config_path = source_cfg_path,
  source_config_sha256 = qdesn_ssv2_sha256(source_cfg_path),
  source_registry_path = source_registry_path,
  source_registry_sha256 = qdesn_ssv2_sha256(source_registry_path),
  source_window_registry_path = window_path,
  source_window_registry_sha256 = qdesn_ssv2_sha256(window_path),
  tracked_manifest_path = tracked_manifest_path,
  tracked_manifest_sha256 = qdesn_ssv2_sha256(tracked_manifest_path),
  plans = as.list(plan_paths),
  counts = list(
    target_cells = nrow(targets), candidates = nrow(profiles),
    parent_controls = nrow(parents), smoke_jobs = nrow(smoke_plan),
    calibration_jobs = nrow(calibration_plan),
    discovery_jobs = nrow(discovery_plan)
  ),
  gates = list(
    replication = "top three per cell after paired two-source discovery",
    sealed = "top two per cell after independent replication",
    confirmation = "maximum one candidate per target metric; explicit human approval",
    article = "v6 remains frozen until full canonical confirmation"
  ),
  article_state = "v6_frozen_unchanged"
)
manifest_path <- qdesn_ssv2_write_json(
  manifest, file.path(output_root, "materialization_manifest.json")
)
cat(sprintf("materialization_manifest=%s\n", manifest_path))
cat(sprintf("history=%d/%d postm0_unique=%d targets=%d candidates=%d\n",
            nrow(history$rows), nrow(history$signatures),
            length(unique(postm0$profile_signature)), nrow(targets),
            nrow(profiles)))
cat(sprintf("smoke=%d calibration=%d discovery=%d\n",
            nrow(smoke_plan), nrow(calibration_plan), nrow(discovery_plan)))
