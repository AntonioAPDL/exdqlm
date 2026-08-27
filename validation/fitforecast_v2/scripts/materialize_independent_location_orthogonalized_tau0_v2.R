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
  "independent_location_orthogonalized_tau0_v2.R"
))
out <- normalizePath(
  arg("--output-root", file.path(
    repo, "reports", "shared_fitforecast_v2_orchestration",
    "independent_location_orthogonalized_tau0_v2_materialization"
  )), winslash = "/", mustWork = FALSE
)
dir.create(out, recursive = TRUE, showWarnings = FALSE)

authorities <- idlc_v1_assert_authorities(repo)
targets <- idol_v2_read_targets(repo)
arms <- idol_v2_read_arms(repo)
ladder <- idol_v2_read_ladder(repo)
candidates <- idol_v2_build_candidates(repo)
inventory <- idlc_v1_history_inventory(repo)
history <- idlc_v1_history_signatures(repo, inventory)
nonrepeat <- idol_v2_nonrepeat_audit(candidates, history)
if (any(nonrepeat$decision != "PASS")) {
  stop("V2 nonrepeat audit failed.", call. = FALSE)
}
qdesn_ssv2_write_csv(authorities, file.path(out, "authority_hash_audit.csv"))
qdesn_ssv2_write_csv(targets, file.path(out, "target_cell_authority.csv"))
qdesn_ssv2_write_csv(arms, file.path(out, "transform_arms.csv"))
qdesn_ssv2_write_csv(ladder, file.path(out, "tau0_ladder.csv"))
qdesn_ssv2_write_csv(candidates, file.path(out, "candidate_profiles.csv"))
qdesn_ssv2_write_csv(inventory, file.path(out, "history_inventory.csv"))
qdesn_ssv2_write_csv(history, file.path(out, "history_signature_ledger.csv"))
qdesn_ssv2_write_csv(nonrepeat, file.path(out, "candidate_nonrepeat_audit.csv"))

registry_authority <- qdesn_ssv2_read_csv(
  authorities$absolute_path[authorities$authority == "canonical_source_registry"]
)
full_source <- qdesn_ssv2_read_csv(file.path(
  repo, paste0(idlc_v1_config_stem, "_full_source_registry.csv")
))
overlap_rows <- list()
registry_rows <- lapply(seq_len(nrow(targets)), function(i) {
  target <- targets[i, , drop = FALSE]
  canonical <- registry_authority[
    registry_authority$family == target$family[[1L]] &
      abs(registry_authority$tau - target$tau[[1L]]) < 1e-10, , drop = FALSE
  ][1L, , drop = FALSE]
  master <- full_source[
    full_source$family == target$family[[1L]] &
      abs(full_source$tau - target$tau[[1L]]) < 1e-10, , drop = FALSE
  ][1L, , drop = FALSE]
  if (!nrow(canonical) || !nrow(master) ||
      !identical(qdesn_ssv2_sha256(master$master_series_wide_path[[1L]]),
                 master$master_series_wide_sha256[[1L]])) {
    stop("Canonical/full source contract failed for ", target$target_cell_id[[1L]])
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
    target_cell_id = target$target_cell_id,
    master_series_wide_path = master$master_series_wide_path,
    master_series_wide_sha256 = master$master_series_wide_sha256,
    canonical_series_wide_path = canonical$series_wide_path,
    canonical_series_wide_sha256 = canonical$series_wide_sha256,
    master_rows = nrow(master_data), overlap_rows = nrow(overlap),
    canonical_rows = nrow(canonical_data), common_columns = length(common),
    overlap_status = if (overlap_ok) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
  if (!overlap_ok) stop("Frozen source overlap failed.", call. = FALSE)
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
    file.path(repo, "results", "qdesn_mcmc_validation", idol_v2_stage,
              "staged_source_windows")
  )
  assign(key, staged, windows)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, stage, chain_id, reservoir_seed_id) {
  job <- idol_v2_make_job(
    repo, profile, target, resolve_window(profile, target), stage,
    registry_path, chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job <- idol_v2_apply_seeds(job)
  config_path <- file.path(out, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, config_path)
  idol_v2_plan_row(job, config_path)
}

target_map <- split(targets, targets$target_cell_id)
candidate_map <- split(candidates, candidates$target_cell_id)
smoke_specs <- list(
  c("al_normal_t0p05", "O2_orthogonalized_svd", "1e-10"),
  c("exal_normal_t0p50", "O2_orthogonalized_svd", "3e-7")
)
smoke <- do.call(rbind, lapply(smoke_specs, function(spec) {
  profiles <- candidate_map[[spec[[1L]]]]
  profile <- profiles[
    profiles$selection_arm == spec[[2L]] &
      abs(profiles$rhs_tau0 - as.numeric(spec[[3L]])) < 1e-20, , drop = FALSE
  ]
  write_job(profile, target_map[[spec[[1L]]]], "smoke", 1L, "smoke_boundary_r01")
}))
screen <- do.call(rbind, lapply(seq_len(nrow(candidates)), function(i) {
  profile <- candidates[i, , drop = FALSE]
  write_job(profile, target_map[[profile$target_cell_id[[1L]]]],
            "screen", 1L, "screen_r01")
}))

# The v1 AL lower-tail gain is replicated separately from the structural screen.
base <- candidate_map[["al_normal_t0p05"]]
control <- base[base$selection_arm == "C0_parent", , drop = FALSE]
candidate <- control
candidate$rhs_tau0 <- 1e-9
candidate$profile_signature <- qdesn_ssv2_profile_signature(candidate)
candidate$selection_arm <- "R0_v1_tau1e09"
candidate$design_role <- "v1 exact-parent tau0 gain replication"
candidate$declared_replay <- TRUE
candidate$exact_signature <- idol_v2_exact_signature(candidate, "sigma_then_gamma")
candidate$candidate_id <- paste0(
  "idol2_al_normal_t0p05_r0_v1_tau1e09_",
  substr(digest::digest(candidate$exact_signature, algo = "sha256",
                        serialize = FALSE), 1L, 10L)
)
candidate$screening_profile_id <- candidate$candidate_id
rep_profiles <- rbind(candidate, control)
qdesn_ssv2_write_csv(rep_profiles, file.path(out, "initial_replication_candidates.csv"))
initial_replication <- do.call(rbind, lapply(seq_len(nrow(rep_profiles)), function(i) {
  do.call(rbind, lapply(2:3, function(chain) {
    write_job(
      rep_profiles[i, , drop = FALSE], target_map[["al_normal_t0p05"]],
      "initial_replication", chain,
      sprintf("replication_r%02d", chain)
    )
  }))
}))

qdesn_ssv2_write_csv(smoke, file.path(out, "smoke_plan.csv"))
qdesn_ssv2_write_csv(initial_replication,
                     file.path(out, "initial_replication_plan.csv"))
qdesn_ssv2_write_csv(screen, file.path(out, "screen_plan.csv"))
qdesn_ssv2_write_csv(do.call(rbind, window_rows),
                     file.path(out, "source_window_registry.csv"))

static_design <- candidates[, c(
  "candidate_id", "target_cell_id", "likelihood_target", "selection_arm",
  "transform_mode", "rhs_tau0", "D", "n", "n_tilde", "m", "alpha", "rho",
  "readout_y_lags", "reservoir_lags", "washout", "total_states",
  "effective_readout_dimension", "declared_replay", "profile_signature",
  "exact_signature"
), drop = FALSE]
static_design$raw_dimension_fraction_of_training_n <-
  static_design$effective_readout_dimension / 500
qdesn_ssv2_write_csv(static_design, file.path(out, "static_design_audit.csv"))

manifest <- list(
  schema_version = "independent_location_orthogonalized_tau0_v2_materialization_v1",
  generated_at = as.character(Sys.time()),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  branch = system("git branch --show-current", intern = TRUE),
  target_cells = nrow(targets), transform_arms = nrow(arms),
  tau0_levels_per_transformed_cell = 5L, candidate_profiles = nrow(candidates),
  smoke_jobs = nrow(smoke), initial_replication_jobs = nrow(initial_replication),
  screen_jobs = nrow(screen), exact_exal_method = qdesn_ssv2_method_id,
  al_method = "sigma_then_gamma", canonical_source_registry_path = registry_path,
  canonical_source_registry_sha256 = qdesn_ssv2_sha256(registry_path),
  undeclared_history_duplicates = sum(nonrepeat$decision != "PASS"),
  launch_performed = FALSE, article_update_allowed = FALSE,
  storage_contract = "no fitted-model binary payload after each terminal job"
)
qdesn_ssv2_write_json(manifest, file.path(out, "materialization_manifest.json"))
cat(sprintf(
  "MATERIALIZATION_OK candidates=%d smoke=%d initial_replication=%d screen=%d windows=%d\n",
  nrow(candidates), nrow(smoke), nrow(initial_replication), nrow(screen),
  nrow(do.call(rbind, window_rows))
))
