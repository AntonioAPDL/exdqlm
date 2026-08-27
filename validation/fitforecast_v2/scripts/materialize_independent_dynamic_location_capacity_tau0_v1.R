#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite", "pkgload")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing package: ", pkg)
  }
})

args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
setwd(repo)
pkgload::load_all(repo, quiet = TRUE)
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_dynamic_location_capacity_tau0_v1.R"
))
out <- normalizePath(
  arg("--output-root", file.path(
    repo, "reports", "shared_fitforecast_v2_orchestration",
    "independent_dynamic_location_capacity_tau0_v1_materialization"
  )), winslash = "/", mustWork = FALSE
)
dir.create(out, recursive = TRUE, showWarnings = FALSE)

authorities <- idlc_v1_assert_authorities(repo)
targets <- idlc_v1_read_targets(repo)
ladder <- idlc_v1_read_tau0_ladder(repo)
candidates <- idlc_v1_build_candidate_profiles(repo)
inventory <- idlc_v1_history_inventory(repo)
history <- idlc_v1_history_signatures(repo, inventory)
nonrepeat <- idlc_v1_nonrepeat_audit(candidates, history)
nearest <- idlc_v1_nearest_history(candidates, history)
if (any(nonrepeat$decision != "PASS")) {
  stop(sprintf("Undeclared history duplicates: %s",
               paste(nonrepeat$candidate_id[nonrepeat$decision != "PASS"],
                     collapse = ", ")), call. = FALSE)
}

qdesn_ssv2_write_csv(authorities, file.path(out, "authority_hash_audit.csv"))
qdesn_ssv2_write_csv(targets, file.path(out, "target_cell_authority.csv"))
qdesn_ssv2_write_csv(ladder, file.path(out, "tau0_ladder.csv"))
qdesn_ssv2_write_csv(candidates, file.path(out, "candidate_profiles.csv"))
qdesn_ssv2_write_csv(inventory, file.path(out, "history_inventory.csv"))
qdesn_ssv2_write_csv(history, file.path(out, "history_signature_ledger.csv"))
qdesn_ssv2_write_csv(nonrepeat, file.path(out, "candidate_nonrepeat_audit.csv"))
qdesn_ssv2_write_csv(nearest, file.path(out, "candidate_nearest_history.csv"))

registry_authority <- qdesn_ssv2_read_csv(
  authorities$absolute_path[authorities$authority == "canonical_source_registry"]
)
full_source <- qdesn_ssv2_read_csv(file.path(
  repo, paste0(idlc_v1_config_stem, "_full_source_registry.csv")
))
if (nrow(full_source) != 2L || anyDuplicated(paste(full_source$family,
                                                   full_source$tau))) {
  stop("The full-source registry contract has drifted.", call. = FALSE)
}
overlap_rows <- list()
registry_rows <- lapply(seq_len(nrow(targets)), function(i) {
  target <- targets[i, , drop = FALSE]
  canonical <- registry_authority[
    registry_authority$family == target$family[[1L]] &
      abs(registry_authority$tau - target$tau[[1L]]) < 1e-10,
    , drop = FALSE
  ]
  master <- full_source[
    full_source$family == target$family[[1L]] &
      abs(full_source$tau - target$tau[[1L]]) < 1e-10,
    , drop = FALSE
  ]
  if (!nrow(canonical) || !nrow(master)) {
    stop("No canonical/full source pair for ", target$target_cell_id[[1L]])
  }
  canonical <- canonical[1L, , drop = FALSE]
  master <- master[1L, , drop = FALSE]
  if (!file.exists(master$master_series_wide_path[[1L]]) ||
      !identical(qdesn_ssv2_sha256(master$master_series_wide_path[[1L]]),
                 master$master_series_wide_sha256[[1L]])) {
    stop("Full-source hash failed for ", target$target_cell_id[[1L]])
  }
  master_data <- qdesn_ssv2_read_csv(master$master_series_wide_path[[1L]])
  canonical_data <- qdesn_ssv2_read_csv(canonical$series_wide_path[[1L]])
  overlap <- master_data[
    seq.int(master$canonical_overlap_start[[1L]],
            master$canonical_overlap_end[[1L]]), , drop = FALSE
  ]
  common <- intersect(names(overlap), names(canonical_data))
  column_ok <- vapply(common, function(name) {
    a <- overlap[[name]]
    b <- canonical_data[[name]]
    if (is.numeric(a) && is.numeric(b)) {
      length(a) == length(b) && max(abs(a - b), na.rm = TRUE) <= 1e-12
    } else identical(as.character(a), as.character(b))
  }, logical(1L))
  overlap_ok <- nrow(master_data) == 10000L &&
    nrow(overlap) == nrow(canonical_data) && all(column_ok)
  overlap_rows[[length(overlap_rows) + 1L]] <<- data.frame(
    target_cell_id = target$target_cell_id[[1L]],
    master_series_wide_path = master$master_series_wide_path[[1L]],
    master_series_wide_sha256 = master$master_series_wide_sha256[[1L]],
    canonical_series_wide_path = canonical$series_wide_path[[1L]],
    canonical_series_wide_sha256 = canonical$series_wide_sha256[[1L]],
    master_rows = nrow(master_data), overlap_rows = nrow(overlap),
    canonical_rows = nrow(canonical_data), common_columns = length(common),
    overlap_status = if (overlap_ok) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
  if (!overlap_ok) {
    stop("The full source does not reproduce the frozen canonical overlap for ",
         target$target_cell_id[[1L]])
  }
  root <- canonical
  root$series_wide_path <- master$master_series_wide_path[[1L]]
  root$series_wide_sha256 <- master$master_series_wide_sha256[[1L]]
  root$canonical_overlap_series_wide_path <- canonical$series_wide_path[[1L]]
  root$canonical_overlap_series_wide_sha256 <- canonical$series_wide_sha256[[1L]]
  root$target_cell_id <- target$target_cell_id[[1L]]
  root$parent_request_path <- normalizePath(
    file.path(repo, target$parent_request_path[[1L]]), winslash = "/", mustWork = TRUE
  )
  root$parent_request_sha256 <- target$parent_request_sha256[[1L]]
  root
})
registry <- do.call(rbind, registry_rows)
qdesn_ssv2_write_csv(do.call(rbind, overlap_rows),
                     file.path(out, "full_source_overlap_audit.csv"))
for (i in seq_len(nrow(registry))) {
  checks <- c(
    series = file.exists(registry$series_wide_path[[i]]) &&
      identical(qdesn_ssv2_sha256(registry$series_wide_path[[i]]),
                registry$series_wide_sha256[[i]]),
    parent = file.exists(registry$parent_request_path[[i]]) &&
      identical(qdesn_ssv2_sha256(registry$parent_request_path[[i]]),
                registry$parent_request_sha256[[i]])
  )
  if (!all(checks)) {
    stop(sprintf("Canonical source contract failed for %s: %s",
                 registry$target_cell_id[[i]],
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
}
registry_path <- qdesn_ssv2_write_csv(
  registry, file.path(out, "canonical_source_registry.csv")
)

windows <- new.env(parent = emptyenv())
window_rows <- list()
resolve_window <- function(profile, target) {
  key <- paste(target$family[[1L]], target$tau[[1L]], profile$m[[1L]],
               profile$washout[[1L]], sep = "|")
  if (exists(key, windows, inherits = FALSE)) return(get(key, windows))
  root <- registry[registry$target_cell_id == target$target_cell_id[[1L]],
                   , drop = FALSE]
  staged <- idlc_v1_stage_full_source_window(
    root, profile$m[[1L]], profile$washout[[1L]],
    file.path(repo, "results", "qdesn_mcmc_validation", idlc_v1_stage,
              "staged_source_windows")
  )
  assign(key, staged, windows)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, stage, chain_id, reservoir_seed_id) {
  job <- idlc_v1_make_job(
    repo, profile, target, resolve_window(profile, target), stage,
    registry_path, chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job <- idlc_v1_apply_seeds(job)
  config_path <- file.path(out, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, config_path)
  data.frame(
    job_id = job$job_id, stage = stage,
    target_cell_id = job$target_cell_id,
    likelihood_target = job$likelihood_target,
    candidate_id = job$candidate_id,
    profile_role = profile$selection_arm[[1L]],
    rhs_tau0 = as.numeric(profile$rhs_tau0[[1L]]),
    chain_id = as.integer(job$chain_id),
    reservoir_seed_id = job$reservoir_seed_id,
    source_id = job$source_id,
    target_metrics = paste(job$target_metrics, collapse = ";"),
    objective_metric = job$objective_metric,
    current_value = job$current_value,
    comparator_value = job$comparator_value,
    effective_readout_dimension = job$root_spec$effective_readout_dimension,
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    expected_metric_draws = job$config$metrics$posterior_metric_intervals$draws,
    timeout_seconds = job$config$validation$timeout_seconds,
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = qdesn_ssv2_sha256(config_path), stringsAsFactors = FALSE
  )
}

target_map <- split(targets, targets$target_cell_id)
candidate_map <- split(candidates, candidates$target_cell_id)
smoke_cells <- c("al_normal_t0p05", "exal_normal_t0p05")
smoke <- do.call(rbind, lapply(smoke_cells, function(cell) {
  profiles <- candidate_map[[cell]]
  profile <- profiles[
    profiles$selection_arm == "P3_deep_selective" &
      profiles$rhs_tau0 == min(profiles$rhs_tau0), , drop = FALSE
  ]
  write_job(profile, target_map[[cell]], "smoke", 1L, "smoke_boundary_r01")
}))
screen <- do.call(rbind, lapply(seq_len(nrow(candidates)), function(i) {
  profile <- candidates[i, , drop = FALSE]
  write_job(profile, target_map[[profile$target_cell_id[[1L]]]],
            "screen", 1L, "screen_r01")
}))
qdesn_ssv2_write_csv(smoke, file.path(out, "smoke_plan.csv"))
qdesn_ssv2_write_csv(screen, file.path(out, "screen_plan.csv"))
window_registry <- do.call(rbind, window_rows)
qdesn_ssv2_write_csv(window_registry, file.path(out, "source_window_registry.csv"))

static_design <- candidates[, c(
  "candidate_id", "target_cell_id", "likelihood_target", "selection_arm",
  "D", "n", "n_tilde", "m", "alpha", "rho", "pi_w", "pi_in",
  "rhs_tau0", "readout_y_lags", "reservoir_lags", "washout",
  "total_states", "effective_readout_dimension", "declared_replay",
  "profile_signature", "exact_signature"
), drop = FALSE]
static_design$dimension_fraction_of_training_n <-
  static_design$effective_readout_dimension / 500
static_design$topology_positive <- vapply(seq_len(nrow(static_design)), function(i) {
  all(qdesn_ssv2_vec(static_design$pi_w[[i]], "numeric") > 0) &&
    all(qdesn_ssv2_vec(static_design$pi_in[[i]], "numeric") > 0)
}, logical(1L))
qdesn_ssv2_write_csv(static_design, file.path(out, "static_design_audit.csv"))

manifest <- list(
  schema_version = "independent_dynamic_location_capacity_tau0_v1_materialization_v1",
  generated_at = as.character(Sys.time()),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  branch = system("git branch --show-current", intern = TRUE),
  target_cells = nrow(targets), architecture_profiles = 4L,
  tau0_levels_per_cell = 4L, candidate_profiles = nrow(candidates),
  smoke_jobs = nrow(smoke), screen_jobs = nrow(screen),
  exact_exal_method = qdesn_ssv2_method_id,
  al_method = "sigma_then_gamma", maximum_effective_dimension =
    idlc_v1_max_effective_dimension,
  canonical_source_registry_path = registry_path,
  canonical_source_registry_sha256 = qdesn_ssv2_sha256(registry_path),
  authority_hash_audit_sha256 = qdesn_ssv2_sha256(
    file.path(out, "authority_hash_audit.csv")
  ),
  history_inventory_rows = nrow(inventory),
  history_signature_rows = nrow(history),
  undeclared_history_duplicates = sum(nonrepeat$decision != "PASS"),
  launch_performed = FALSE, article_update_allowed = FALSE,
  storage_contract = "no fitted-model binary payload after each terminal job"
)
qdesn_ssv2_write_json(manifest, file.path(out, "materialization_manifest.json"))
cat(sprintf(
  "MATERIALIZATION_OK candidates=%d smoke=%d screen=%d history=%d windows=%d\n",
  nrow(candidates), nrow(smoke), nrow(screen), nrow(history), nrow(window_registry)
))
