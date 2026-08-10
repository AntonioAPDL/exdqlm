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
                 "independent_exal_m0_structural_screen_v2.R"))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Structural screen v2 requires exdqlm 1.0.0.", call. = FALSE)
}

output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "independent_exal_m0_structural_screen_v2_materialization")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
config_stub <- file.path(repo_root, "config", "validation", qdesn_ssv2_stage)
source_cfg_path <- paste0(config_stub, "_sources.yaml")
source_cfg <- yaml::read_yaml(source_cfg_path)

targets <- qdesn_ssv2_targets(repo_root)
frozen_history_path <- paste0(config_stub, "_history_signature_ledger.csv")
history <- if (has_flag("--use-frozen-designs") && file.exists(frozen_history_path)) {
  qdesn_ssv2_read_csv(frozen_history_path)
} else {
  qdesn_ssv2_history_ledger(repo_root)
}
cached_universe_path <- file.path(output_root, "virtual_candidate_universe.csv")
universe <- if (file.exists(cached_universe_path) && !has_flag("--refresh-universe")) {
  qdesn_ssv2_read_csv(cached_universe_path)
} else {
  qdesn_ssv2_virtual_universe()
}
universe <- qdesn_ssv2_ensure_effective_dimension(universe)
frozen_profiles_path <- paste0(config_stub, "_wave1_profiles.csv")
frozen_parents_path <- paste0(config_stub, "_parent_controls.csv")
selection <- if (has_flag("--use-frozen-designs")) {
  if (!file.exists(frozen_profiles_path) || !file.exists(frozen_parents_path)) {
    stop("Frozen structural-screen design ledgers are missing.", call. = FALSE)
  }
  frozen <- list(
    selected = qdesn_ssv2_ensure_effective_dimension(
      qdesn_ssv2_read_csv(frozen_profiles_path)
    ),
    parents = qdesn_ssv2_ensure_effective_dimension(
      qdesn_ssv2_read_csv(frozen_parents_path)
    )
  )
  if (nrow(frozen$selected) != 96L || nrow(frozen$parents) != 7L ||
      !setequal(frozen$selected$target_cell_id, targets$target_cell_id) ||
      !setequal(frozen$parents$target_cell_id, targets$target_cell_id) ||
      any(frozen$selected$effective_readout_dimension >
            qdesn_ssv2_max_effective_readout_dimension) ||
      any(frozen$parents$effective_readout_dimension >
            qdesn_ssv2_max_effective_readout_dimension)) {
    stop("Frozen structural-screen design ledgers violate the target/count contract.",
         call. = FALSE)
  }
  frozen
} else {
  qdesn_ssv2_select_wave1(repo_root, universe, history, targets)
}

tracked_targets <- targets
tracked_targets$parent_request_path <- vapply(
  tracked_targets$parent_request_path, qdesn_ssv2_rel, character(1L), repo_root = repo_root
)
targets_path <- qdesn_ssv2_write_csv(tracked_targets, paste0(config_stub, "_target_cells.csv"))
history_path <- qdesn_ssv2_write_csv(history, frozen_history_path)
profiles_path <- qdesn_ssv2_write_csv(selection$selected, frozen_profiles_path)
parents_path <- qdesn_ssv2_write_csv(selection$parents, frozen_parents_path)
universe_path <- qdesn_ssv2_write_csv(universe, cached_universe_path)

replicates <- source_cfg$replicates
roles <- vapply(replicates, function(x) as.character(x$role), character(1L))
if (length(replicates) != 5L || sum(roles == "discovery") != 3L ||
    sum(roles == "sealed_holdout") != 1L || sum(roles == "sealed_reserve") != 1L) {
  stop("Source contract must contain 3 discovery, 1 sealed holdout, and 1 reserve.", call. = FALSE)
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
      notes = sprintf("Structural-screen %s source %s.", replicate$role, replicate$replicate_id)
    ),
    generation = utils::modifyList(source_cfg$generation,
                                   list(family_profiles = family_profiles)),
    qdesn_materialization = list(staged_root = file.path(
      "results", "qdesn_mcmc_validation", qdesn_ssv2_stage,
      "source_windows", replicate$scenario_id
    ))
  )
  source_parent <- as.character(source_cfg$generation$output_parent)
  if (!grepl("^/", source_parent)) source_parent <- file.path(repo_root, source_parent)
  cached_root_inventory <- file.path(source_parent, replicate$scenario_id,
                                     "000__full_root_inventory.csv")
  roots <- if (file.exists(cached_root_inventory) && !has_flag("--refresh-sources")) {
    qdesn_ssv2_read_csv(cached_root_inventory)
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
source_roots <- do.call(rbind, root_rows)
source_roots <- source_roots[order(source_roots$source_id, source_roots$family,
                                   source_roots$tau), , drop = FALSE]
seed_path <- qdesn_ssv2_write_csv(seed_contract, paste0(config_stub, "_source_seed_contract.csv"))
source_registry_path <- qdesn_ssv2_write_csv(source_roots,
                                             file.path(output_root, "source_root_registry.csv"))

source_window_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation", qdesn_ssv2_stage,
  "staged_source_windows"
)
window_cache <- new.env(parent = emptyenv())
window_rows <- list()
resolve_window <- function(profile, target, source_id) {
  key <- paste(source_id, target$family[[1L]], sprintf("%.2f", target$tau[[1L]]),
               profile$m[[1L]], profile$washout[[1L]], sep = "|")
  if (exists(key, envir = window_cache, inherits = FALSE)) return(get(key, envir = window_cache))
  root <- source_roots[
    source_roots$source_id == source_id & source_roots$family == target$family[[1L]] &
      abs(source_roots$tau - target$tau[[1L]]) < 1e-10,
    , drop = FALSE
  ]
  if (nrow(root) != 1L) stop(sprintf("Could not resolve source window: %s", key), call. = FALSE)
  staged <- qdesn_ssv2_stage_source_window(
    root, source_id, profile$m[[1L]], profile$washout[[1L]], source_window_root
  )
  assign(key, staged, envir = window_cache)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, source_id, stage, chain_id = 1L) {
  source <- resolve_window(profile, target, source_id)
  job <- qdesn_ssv2_make_job(repo_root, profile, target, source, stage,
                             source_registry_path, chain_id)
  path <- file.path(output_root, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  data.frame(
    job_id = job$job_id, stage = stage, target_cell_id = job$target_cell_id,
    candidate_id = job$candidate_id, chain_id = job$chain_id,
    source_id = job$source_id, source_role = job$source_role,
    objective_metric = job$objective_metric,
    current_value = job$current_value, comparator_value = job$comparator_value,
    config_path = path, config_sha256 = qdesn_ssv2_sha256(path),
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    effective_readout_dimension = job$root_spec$effective_readout_dimension,
    timeout_seconds = job$config$validation$timeout_seconds,
    stringsAsFactors = FALSE
  )
}

profiles <- selection$selected
parents <- selection$parents
target_map <- split(targets, targets$target_cell_id)

# Smoke uses one D=2 and one D>=3 configuration, both with vector alpha/rho.
smoke_indices <- c(
  which(profiles$D == 2L)[[1L]],
  which(profiles$D >= 3L)[[1L]]
)
smoke_plan <- do.call(rbind, lapply(smoke_indices, function(i) {
  write_job(profiles[i, , drop = FALSE], target_map[[profiles$target_cell_id[[i]]]],
            "dev09", "smoke")
}))

# Runtime calibration spans targets and deliberately includes high-capacity boundaries.
calibration_indices <- unique(c(
  vapply(split(seq_len(nrow(profiles)), profiles$target_cell_id), `[[`, integer(1L), 1L),
  order(-profiles$effective_readout_dimension, -profiles$m,
        -profiles$max_alpha)[seq_len(5L)]
))[seq_len(12L)]
calibration_plan <- do.call(rbind, lapply(calibration_indices, function(i) {
  write_job(profiles[i, , drop = FALSE], target_map[[profiles$target_cell_id[[i]]]],
            "dev09", "calibration")
}))

wave1_rows <- list(); k <- 0L
for (i in seq_len(nrow(profiles))) {
  k <- k + 1L
  wave1_rows[[k]] <- write_job(
    profiles[i, , drop = FALSE], target_map[[profiles$target_cell_id[[i]]]],
    "dev09", "wave1"
  )
}
for (i in seq_len(nrow(parents))) {
  k <- k + 1L
  wave1_rows[[k]] <- write_job(
    parents[i, , drop = FALSE], target_map[[parents$target_cell_id[[i]]]],
    "dev09", "wave1"
  )
}
wave1_plan <- do.call(rbind, wave1_rows)

plan_paths <- c(
  smoke = qdesn_ssv2_write_csv(smoke_plan, file.path(output_root, "smoke_plan.csv")),
  calibration = qdesn_ssv2_write_csv(calibration_plan, file.path(output_root, "calibration_plan.csv")),
  wave1 = qdesn_ssv2_write_csv(wave1_plan, file.path(output_root, "wave1_plan.csv"))
)
window_registry <- do.call(rbind, window_rows)
window_registry <- unique(window_registry)
window_registry_path <- qdesn_ssv2_write_csv(window_registry,
                                             file.path(output_root, "staged_source_window_registry.csv"))

tracked_paths <- c(source_cfg_path, targets_path, history_path, profiles_path,
                   parents_path, seed_path)
repair_paths <- c(
  paste0(config_stub, "_capacity_repair_ledger.csv"),
  paste0(config_stub, "_capacity_repair_manifest.json")
)
tracked_paths <- c(tracked_paths, repair_paths[file.exists(repair_paths)])
tracked_manifest <- data.frame(
  relative_path = vapply(tracked_paths, qdesn_ssv2_rel, character(1L), repo_root = repo_root),
  bytes = as.numeric(file.info(tracked_paths)$size),
  sha256 = vapply(tracked_paths, qdesn_ssv2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
tracked_manifest_path <- qdesn_ssv2_write_csv(
  tracked_manifest, paste0(config_stub, "_tracked_manifest.csv")
)
materialization_manifest <- list(
  schema_version = "independent_exal_m0_structural_screen_v2_materialization_v2",
  generated_at = as.character(Sys.time()), git_commit = system("git rev-parse HEAD", intern = TRUE),
  package_version = "1.0.0", canonical_registry_hash = qdesn_ssv2_registry_hash,
  source_config_path = source_cfg_path, source_config_sha256 = qdesn_ssv2_sha256(source_cfg_path),
  source_registry_path = source_registry_path,
  source_registry_sha256 = qdesn_ssv2_sha256(source_registry_path),
  staged_source_window_registry_path = window_registry_path,
  staged_source_window_registry_sha256 = qdesn_ssv2_sha256(window_registry_path),
  virtual_universe_path = universe_path, virtual_universe_sha256 = qdesn_ssv2_sha256(universe_path),
  tracked_manifest_path = tracked_manifest_path,
  plans = as.list(plan_paths),
  counts = list(
    virtual_candidates = nrow(universe), historical_signatures = nrow(history),
    wave1_designs = nrow(profiles), parent_controls = nrow(parents),
    maximum_effective_readout_dimension =
      max(c(profiles$effective_readout_dimension, parents$effective_readout_dimension)),
    capacity_contract = qdesn_ssv2_max_effective_readout_dimension,
    smoke_jobs = nrow(smoke_plan), calibration_jobs = nrow(calibration_plan),
    wave1_jobs = nrow(wave1_plan), maximum_exploratory_jobs = 428L
  ),
  gates = list(
    wave2 = "generated only after wave1 finite-artifact gate",
    wave3 = "generated only after wave2 paired-block collection",
    sealed = "generated only after predeclared finalist selection",
    full_confirmation = "materialize only; explicit human approval required"
  ),
  article_state = "unchanged_screening_only"
)
manifest_path <- qdesn_ssv2_write_json(
  materialization_manifest, file.path(output_root, "materialization_manifest.json")
)

cat(sprintf("materialization_manifest=%s\n", manifest_path))
cat(sprintf("virtual_candidates=%d history_signatures=%d\n", nrow(universe), nrow(history)))
cat(sprintf("smoke=%d calibration=%d wave1=%d\n",
            nrow(smoke_plan), nrow(calibration_plan), nrow(wave1_plan)))
cat(sprintf("source_registry_sha256=%s\n", qdesn_ssv2_sha256(source_registry_path)))
