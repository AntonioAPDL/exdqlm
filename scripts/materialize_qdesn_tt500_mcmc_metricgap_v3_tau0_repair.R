#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(path))) return(NULL)
  if (!grepl("^(/|~)", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value,
    path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) {
  unname(tools::sha256sum(resolve_path(path)))
}

source_stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3"
repair_stage <- as.character(get_arg(
  "--repair-stage",
  paste0(source_stage, "_tau0_repair")
))[1L]
source_run_tag <- "qdesn-tt500-mcmc-metricgap-v3-full-20260726__git-fa5dca4"
source_campaign_stamp <- "20260726-193528__git-fa5dca4"
source_report_root <- resolve_path(get_arg(
  "--source-report-root",
  file.path(
    "reports", "qdesn_mcmc_validation", source_stage,
    source_run_tag, source_campaign_stamp
  )
))

source_paths <- c(
  defaults = file.path("config", "validation", paste0(source_stage, "_defaults.yaml")),
  profiles = file.path("config", "validation", paste0(source_stage, "_profiles.csv")),
  assignments = file.path("config", "validation", paste0(source_stage, "_cell_assignments.csv")),
  grid = file.path("config", "validation", paste0(source_stage, "_grid.csv")),
  target_specs = file.path("config", "validation", paste0(source_stage, "_target_spec_ids.csv")),
  campaign_progress = file.path(source_report_root, "tables", "campaign_progress.csv"),
  campaign_completed = file.path(source_report_root, "manifest", "campaign_completed.json")
)
source_paths <- vapply(source_paths, resolve_path, character(1L))

out_paths <- c(
  defaults = file.path("config", "validation", paste0(repair_stage, "_defaults.yaml")),
  profiles = file.path("config", "validation", paste0(repair_stage, "_profiles.csv")),
  assignments = file.path("config", "validation", paste0(repair_stage, "_cell_assignments.csv")),
  grid = file.path("config", "validation", paste0(repair_stage, "_grid.csv")),
  target_specs = file.path("config", "validation", paste0(repair_stage, "_target_spec_ids.csv")),
  manifest = file.path("config", "validation", paste0(repair_stage, "_materialization_manifest.json"))
)
out_paths <- vapply(out_paths, resolve_path, character(1L), must_work = FALSE)

defaults <- yaml::read_yaml(source_paths[["defaults"]])
profiles <- read_csv(source_paths[["profiles"]])
assignments <- read_csv(source_paths[["assignments"]])
grid <- read_csv(source_paths[["grid"]])
target_specs <- read_csv(source_paths[["target_specs"]])
progress <- read_csv(source_paths[["campaign_progress"]])
completion <- jsonlite::read_json(source_paths[["campaign_completed"]], simplifyVector = TRUE)

required_target <- c(
  "root_id", "spec_id", "rhs_tau0", "likelihood_target",
  "family.x", "tau.x", "screening_profile_id.x"
)
missing_target <- setdiff(required_target, names(target_specs))
if (length(missing_target)) {
  stop(sprintf("Source target table is missing: %s", paste(missing_target, collapse = ", ")), call. = FALSE)
}
required_progress <- c("root_id", "root_status")
missing_progress <- setdiff(required_progress, names(progress))
if (length(missing_progress)) {
  stop(sprintf("Source progress table is missing: %s", paste(missing_progress, collapse = ", ")), call. = FALSE)
}
if (nrow(target_specs) != 80L || nrow(progress) != 80L) {
  stop("Repair materialization requires the frozen 80-spec target and 80-root progress tables.", call. = FALSE)
}
if (as.integer(completion$n_roots) != 80L) {
  stop("Source completion manifest does not certify 80 attempted roots.", call. = FALSE)
}

tau0 <- suppressWarnings(as.numeric(target_specs$rhs_tau0))
repair_mask <- is.finite(tau0) & abs(tau0 - 3e-5) <= 1e-12
repair_targets <- target_specs[repair_mask, , drop = FALSE]
repair_roots <- unique(as.character(repair_targets$root_id))
repair_specs <- unique(as.character(repair_targets$spec_id))
failed_roots <- unique(as.character(progress$root_id[progress$root_status == "FAIL"]))
successful_roots <- unique(as.character(progress$root_id[progress$root_status == "SUCCESS"]))

if (nrow(repair_targets) != 25L ||
    length(repair_roots) != 25L ||
    length(repair_specs) != 25L) {
  stop("Expected exactly 25 unique rhs_tau0=3e-5 repair specs.", call. = FALSE)
}
if (!setequal(failed_roots, repair_roots) || length(failed_roots) != 25L) {
  stop("The source campaign failure set is not exactly the 25 rhs_tau0=3e-5 roots.", call. = FALSE)
}
if (length(intersect(successful_roots, repair_roots))) {
  stop("Repair selection overlaps a successful source-campaign root.", call. = FALSE)
}

repair_grid <- grid[as.character(grid$root_id) %in% repair_roots, , drop = FALSE]
repair_assignments <- assignments[
  as.character(assignments$root_id) %in% repair_roots,
  ,
  drop = FALSE
]
repair_profile_ids <- unique(as.character(repair_targets$screening_profile_id.x))
selected_profiles <- profiles[
  as.character(profiles$screening_profile_id) %in% repair_profile_ids,
  ,
  drop = FALSE
]

if (nrow(repair_grid) != 25L ||
    nrow(repair_assignments) != 25L ||
    nrow(selected_profiles) != 25L ||
    nrow(profiles) != 80L) {
  stop("Repair grid/assignments/selected profiles must contain 25 rows and the canonical profile catalog must contain 80 rows.", call. = FALSE)
}
if (!setequal(repair_grid$root_id, repair_roots) ||
    !setequal(repair_assignments$root_id, repair_roots) ||
    !setequal(selected_profiles$screening_profile_id, repair_profile_ids)) {
  stop("Repair artifacts do not preserve the exact failed-root/profile identity set.", call. = FALSE)
}
if (!all(abs(as.numeric(repair_grid$rhs_tau0) - 3e-5) <= 1e-12) ||
    !all(abs(as.numeric(selected_profiles$rhs_tau0) - 3e-5) <= 1e-12)) {
  stop("A repair artifact lost the exact rhs_tau0=3e-5 contract.", call. = FALSE)
}

defaults$campaign$name <- repair_stage
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", repair_stage)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", repair_stage)
defaults$execution$allowed_fit_spec_ids <- as.list(repair_specs)
defaults$study_contract$id <- paste0(repair_stage, "_2026_07_26")
defaults$study_contract$description <- paste(
  "Deterministic re-execution of only the 25 metric-gap v3 roots invalidated",
  "before fitting by loss of numeric precision at the EXDQLM_CFG_JSON subprocess boundary."
)
defaults$study_contract$screening_policy$launch_status <- "prepared_not_launched"
defaults$study_contract$repair_contract <- list(
  source_stage = source_stage,
  source_run_tag = source_run_tag,
  source_campaign_stamp = source_campaign_stamp,
  source_attempted_roots = 80L,
  preserved_successful_roots = 55L,
  selected_failed_roots = 25L,
  selection_rule = "rhs_tau0 equals 3e-5 and source root_status equals FAIL",
  statistical_spec_change = FALSE,
  transport_fix = "precision-preserving EXDQLM_CFG_JSON serialization with digits=NA",
  overwrite_source_results = FALSE
)
defaults$reference_contract$expected_qdesn_roots <- nrow(profiles) *
  as.integer(defaults$screening_profiles$canonical_dataset_cell_count)
defaults$reference_contract$expected_selected_qdesn_roots <- nrow(repair_grid)
defaults$screening_profiles$csv <- file.path(
  "config", "validation", paste0(repair_stage, "_profiles.csv")
)
defaults$screening_profiles$cell_assignments_csv <- file.path(
  "config", "validation", paste0(repair_stage, "_cell_assignments.csv")
)
defaults$screening_profiles$design <- paste(
  "Metric-gap v3 tau0 repair: exact 25-spec subset invalidated by JSON precision loss;",
  "no statistical specification, seed, source, likelihood, or MCMC budget changes."
)
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_qdesn_root_count <- nrow(profiles) *
  as.integer(defaults$screening_profiles$canonical_dataset_cell_count)
defaults$screening_profiles$selected_assignment_root_count <- nrow(repair_assignments)

smoke_order <- order(
  suppressWarnings(as.numeric(repair_targets$p_over_n_tt500)),
  as.character(repair_targets$spec_id)
)
smoke_target <- repair_targets[smoke_order[[1L]], , drop = FALSE]
defaults$smoke$family <- as.character(smoke_target$family.x[[1L]])
defaults$smoke$tau <- as.numeric(smoke_target$tau.x[[1L]])
defaults$smoke$screening_profile_ids <- as.list(
  as.character(smoke_target$screening_profile_id.x[[1L]])
)
defaults$smoke$max_roots <- 1L

written <- c(
  profiles = write_csv(profiles, out_paths[["profiles"]]),
  assignments = write_csv(repair_assignments, out_paths[["assignments"]]),
  grid = write_csv(repair_grid, out_paths[["grid"]]),
  target_specs = write_csv(repair_targets, out_paths[["target_specs"]])
)
dir.create(dirname(out_paths[["defaults"]]), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(defaults, out_paths[["defaults"]])
written <- c(defaults = normalizePath(out_paths[["defaults"]], winslash = "/", mustWork = TRUE), written)

source_manifest <- data.frame(
  role = names(source_paths),
  path = unname(source_paths),
  sha256 = vapply(source_paths, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
output_manifest <- data.frame(
  role = names(written),
  path = unname(written),
  sha256 = vapply(written, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  repair_stage = repair_stage,
  launch_status = "prepared_not_launched",
  root_cause = "jsonlite default numeric precision serialized rhs_tau0=3e-5 as zero",
  repair = "R/run_esn_pipeline.R serializes EXDQLM_CFG_JSON with digits=NA",
  counts = list(
    source_target_specs = nrow(target_specs),
    source_successful_roots_preserved = length(successful_roots),
    source_failed_roots = length(failed_roots),
    repair_target_specs = nrow(repair_targets),
    repair_grid_rows = nrow(repair_grid),
    canonical_profile_rows = nrow(profiles),
    repair_selected_profile_rows = nrow(selected_profiles),
    repair_assignment_rows = nrow(repair_assignments)
  ),
  invariants = list(
    exact_tau0 = 3e-5,
    source_failure_set_equals_repair_set = TRUE,
    overlaps_source_success_set = FALSE,
    statistical_specs_unchanged = TRUE,
    source_results_overwritten = FALSE,
    full_confirmation_launched = FALSE
  ),
  smoke_spec_id = as.character(smoke_target$spec_id[[1L]]),
  source_manifest = source_manifest,
  output_manifest = output_manifest
)
manifest_path <- write_json(manifest, out_paths[["manifest"]])

cat(sprintf("repair_stage: %s\n", repair_stage))
cat("launch_status: prepared_not_launched\n")
cat(sprintf("source_successful_roots_preserved: %d\n", length(successful_roots)))
cat(sprintf("repair_target_specs: %d\n", nrow(repair_targets)))
cat(sprintf("smoke_spec_id: %s\n", manifest$smoke_spec_id))
cat(sprintf("manifest: %s\n", manifest_path))
