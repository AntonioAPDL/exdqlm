#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop(sprintf("Missing package: %s", pkg))
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)

repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

predecessor_ref <- get_arg("--predecessor-ref", "20b8022")
predecessor_commit <- system2(
  "git", c("rev-parse", paste0(predecessor_ref, "^{commit}")), stdout = TRUE
)
if (length(predecessor_commit) != 1L) stop("Could not resolve predecessor commit.", call. = FALSE)

stub_rel <- file.path("config", "validation", qdesn_ssv2_stage)
profiles_rel <- paste0(stub_rel, "_wave1_profiles.csv")
parents_path <- file.path(repo_root, paste0(stub_rel, "_parent_controls.csv"))
history_path <- file.path(repo_root, paste0(stub_rel, "_history_signature_ledger.csv"))
ledger_path <- file.path(repo_root, paste0(stub_rel, "_capacity_repair_ledger.csv"))
manifest_path <- file.path(repo_root, paste0(stub_rel, "_capacity_repair_manifest.json"))
universe_path <- file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration",
  "independent_exal_m0_structural_screen_v2_materialization",
  "virtual_candidate_universe.csv"
)

predecessor_lines <- system2(
  "git", c("show", paste0(predecessor_commit, ":", profiles_rel)), stdout = TRUE
)
if (!length(predecessor_lines)) stop("Predecessor profile ledger is empty.", call. = FALSE)
predecessor <- utils::read.csv(
  text = paste(predecessor_lines, collapse = "\n"), check.names = FALSE,
  stringsAsFactors = FALSE
)
predecessor <- qdesn_ssv2_ensure_effective_dimension(predecessor)
if (nrow(predecessor) != 96L) stop("Predecessor Wave-1 ledger must have 96 rows.", call. = FALSE)

universe <- if (file.exists(universe_path)) {
  qdesn_ssv2_read_csv(universe_path)
} else {
  qdesn_ssv2_virtual_universe()
}
universe <- qdesn_ssv2_ensure_effective_dimension(universe)
universe_identity_sha256 <- digest::digest(
  paste(universe$virtual_id, universe$profile_signature, sep = "|", collapse = "\n"),
  algo = "sha256", serialize = FALSE
)
parents <- qdesn_ssv2_read_csv(parents_path)
history <- qdesn_ssv2_read_csv(history_path)
repair <- qdesn_ssv2_repair_capacity(predecessor, universe, history, parents)

replaced <- repair$ledger$action == "replaced_above_capacity_contract"
retained <- !replaced
if (!all(repair$ledger$predecessor_candidate_id[retained] ==
         repair$ledger$repaired_candidate_id[retained])) {
  stop("Capacity repair changed a feasible predecessor candidate.", call. = FALSE)
}
if (!all(repair$ledger$predecessor_profile_signature[retained] ==
         repair$ledger$repaired_profile_signature[retained])) {
  stop("Capacity repair changed a feasible predecessor design.", call. = FALSE)
}

cat(sprintf(
  paste0("predecessor=%s profiles=%d retained_exact=%d replaced=%d ",
         "maximum_effective_readout_dimension=%d repaired_maximum=%d\n"),
  predecessor_commit, nrow(predecessor), sum(retained), sum(replaced),
  qdesn_ssv2_max_effective_readout_dimension,
  max(repair$profiles$effective_readout_dimension)
))
if (has_flag("--dry-run")) quit(save = "no", status = 0L)

profiles_path <- file.path(repo_root, profiles_rel)
qdesn_ssv2_write_csv(repair$profiles, profiles_path)
qdesn_ssv2_write_csv(repair$ledger, ledger_path)
predecessor_blob <- system2(
  "git", c("rev-parse", paste0(predecessor_commit, ":", profiles_rel)), stdout = TRUE
)
manifest <- list(
  schema_version = "independent_exal_m0_structural_screen_v2_capacity_repair_v1",
  algorithm = "retain_feasible_exact_and_replace_over_cap_with_cell_arm_aware_deterministic_maximin",
  predecessor_commit = predecessor_commit,
  predecessor_profile_ledger_path = profiles_rel,
  predecessor_profile_ledger_blob = predecessor_blob,
  virtual_universe_path = qdesn_ssv2_rel(universe_path, repo_root),
  virtual_universe_seed = qdesn_ssv2_virtual_seed,
  virtual_universe_designs = nrow(universe),
  virtual_universe_design_identity_sha256 = universe_identity_sha256,
  effective_readout_dimension_formula =
    "(sum(n_tilde)+tail(n,1))*(reservoir_lags+1)+readout_y_lags+6",
  maximum_effective_readout_dimension = qdesn_ssv2_max_effective_readout_dimension,
  predecessor_profiles = nrow(predecessor),
  retained_exact_profiles = sum(retained),
  replaced_profiles = sum(replaced),
  repaired_maximum_effective_readout_dimension =
    max(repair$profiles$effective_readout_dimension),
  repaired_profile_ledger_path = qdesn_ssv2_rel(profiles_path, repo_root),
  repaired_profile_ledger_sha256 = qdesn_ssv2_sha256(profiles_path),
  repair_ledger_path = qdesn_ssv2_rel(ledger_path, repo_root),
  repair_ledger_sha256 = qdesn_ssv2_sha256(ledger_path)
)
qdesn_ssv2_write_json(manifest, manifest_path)
cat(sprintf("profiles=%s\nledger=%s\nmanifest=%s\n",
            profiles_path, ledger_path, manifest_path))
