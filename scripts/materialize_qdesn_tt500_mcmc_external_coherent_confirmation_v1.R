#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(required, require, character.only = TRUE))
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
pkgload::load_all(repo_root, quiet = TRUE)

git_branch_before_materialization <- trimws(
  system("git branch --show-current", intern = TRUE)
)
git_commit_before_materialization <- trimws(
  system("git rev-parse HEAD", intern = TRUE)
)
tracked_dirty_before_materialization <- length(
  system("git diff --name-only", intern = TRUE)
) > 0L || length(
  system("git diff --cached --name-only", intern = TRUE)
) > 0L
untracked_before_materialization <- system(
  "git ls-files --others --exclude-standard",
  intern = TRUE
)

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
copy_exact <- function(source, target) {
  source <- resolve_path(source)
  target <- resolve_path(target, must_work = FALSE)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, target, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)) {
    stop(sprintf("Could not copy `%s` to `%s`.", source, target), call. = FALSE)
  }
  normalizePath(target, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
tau_key <- function(x) sprintf("%.8f", num(x))

stage <- as.character(get_arg(
  "--stage",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1"
))[1L]
stamp <- as.character(get_arg("--stamp", "20260727"))[1L]
source_stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3"
closeout_id <- "qdesn_tt500_mcmc_metricgap_v3_combined_closeout_20260727"
expected_spec_id <- "qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0"
expected_root_id <- paste0(
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
  "__laplace__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_mgv3_16_exal_local"
)
expected_profile_id <- "mgv3_16_exal_local"

source_paths <- c(
  closeout_candidates = file.path(
    "validation", "fitforecast_v2", "promotions", closeout_id,
    paste0(closeout_id, "_all_candidates.csv")
  ),
  closeout_closest = file.path(
    "validation", "fitforecast_v2", "promotions", closeout_id,
    paste0(closeout_id, "_closest_balanced_candidates.csv")
  ),
  closeout_manifest = file.path(
    "validation", "fitforecast_v2", "promotions", closeout_id,
    paste0(closeout_id, "_manifest.json")
  ),
  defaults = file.path("config", "validation", paste0(source_stage, "_defaults.yaml")),
  profiles = file.path("config", "validation", paste0(source_stage, "_profiles.csv")),
  assignments = file.path("config", "validation", paste0(source_stage, "_cell_assignments.csv")),
  grid = file.path("config", "validation", paste0(source_stage, "_grid.csv")),
  target_specs = file.path("config", "validation", paste0(source_stage, "_target_spec_ids.csv"))
)
source_paths <- vapply(source_paths, resolve_path, character(1L))

out_paths <- c(
  defaults = file.path("config", "validation", paste0(stage, "_defaults.yaml")),
  profiles = file.path("config", "validation", paste0(stage, "_profiles.csv")),
  assignments = file.path("config", "validation", paste0(stage, "_cell_assignments.csv")),
  grid = file.path("config", "validation", paste0(stage, "_grid.csv")),
  target_specs = file.path("config", "validation", paste0(stage, "_target_spec_ids.csv")),
  manifest = file.path("config", "validation", paste0(stage, "_materialization_manifest.json"))
)
out_paths <- vapply(out_paths, resolve_path, character(1L), must_work = FALSE)
promotion_root <- resolve_path(
  get_arg(
    "--promotion-root",
    file.path(
      "validation", "fitforecast_v2", "promotions",
      paste0("qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_", stamp)
    )
  ),
  must_work = FALSE
)

description <- read.dcf(resolve_path("DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("This confirmation must be materialized from the exdqlm 1.0.0 worktree.", call. = FALSE)
}

candidates <- read_csv(source_paths[["closeout_candidates"]])
closest <- read_csv(source_paths[["closeout_closest"]])
profiles <- read_csv(source_paths[["profiles"]])
assignments <- read_csv(source_paths[["assignments"]])
grid <- read_csv(source_paths[["grid"]])
target_specs <- read_csv(source_paths[["target_specs"]])
defaults <- yaml::read_yaml(source_paths[["defaults"]])

required_candidate <- c(
  "model_variant", "family", "tau", "root_id", "spec_id", "screening_profile_id",
  "seed", "rhs_tau0", "likelihood_family", "status", "finite_ok", "domain_ok",
  "signoff_grade", "signoff_reason", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "current_fit_qtrue_rmse", "current_forecast_qtrue_mae_H1000",
  "current_forecast_check_loss_H1000", "external_best_fit_rmse",
  "external_best_forecast_mae", "external_best_forecast_check",
  "fit_ratio_to_external_best", "forecast_mae_ratio_to_external_best",
  "forecast_check_ratio_to_external_best", "source_registry_hash_value", "fit_file"
)
missing_candidate <- setdiff(required_candidate, names(candidates))
if (length(missing_candidate)) {
  stop(sprintf(
    "Combined closeout is missing candidate column(s): %s",
    paste(missing_candidate, collapse = ", ")
  ), call. = FALSE)
}

eligible <- candidates[
  candidates$model_variant == "qdesn_exal_rhs_ns" &
    candidates$likelihood_family == "exal" &
    candidates$family == "laplace" &
    abs(num(candidates$tau) - 0.25) <= 1e-12 &
    as.character(candidates$status) == "SUCCESS" &
    as_bool(candidates$finite_ok) &
    as_bool(candidates$domain_ok) &
    num(candidates$fit_ratio_to_external_best) <= 1 &
    num(candidates$forecast_mae_ratio_to_external_best) <= 1 &
    num(candidates$forecast_check_ratio_to_external_best) <= 1,
  ,
  drop = FALSE
]
if (nrow(eligible) != 2L ||
    !expected_spec_id %in% eligible$spec_id ||
    !all(eligible$screening_profile_id %in% c(
      "mgv3_16_exal_anchor",
      "mgv3_16_exal_local"
    ))) {
  stop(
    "Expected exactly the two audited Laplace/tau=0.25/exAL external-coherent candidates.",
    call. = FALSE
  )
}
eligible <- eligible[order(
  num(eligible$fit_qtrue_rmse),
  num(eligible$forecast_check_loss_H1000),
  eligible$spec_id
), , drop = FALSE]
candidate <- eligible[1L, , drop = FALSE]
if (candidate$spec_id[[1L]] != expected_spec_id ||
    candidate$root_id[[1L]] != expected_root_id ||
    candidate$screening_profile_id[[1L]] != expected_profile_id) {
  stop("The audited tau0=1e-4 local candidate is no longer the best fit-RMSE coherent candidate.", call. = FALSE)
}

source_profile <- profiles[
  profiles$screening_profile_id == expected_profile_id,
  ,
  drop = FALSE
]
source_assignment <- assignments[
  assignments$root_id == expected_root_id &
    assignments$likelihood_target == "exal",
  ,
  drop = FALSE
]
source_grid <- grid[grid$root_id == expected_root_id, , drop = FALSE]
source_target <- target_specs[target_specs$spec_id == expected_spec_id, , drop = FALSE]
if (nrow(profiles) != 80L ||
    nrow(source_profile) != 1L ||
    nrow(source_assignment) != 1L ||
    nrow(source_grid) != 1L ||
    nrow(source_target) != 1L) {
  stop("Could not recover the exact 80-profile catalog and one selected atomic candidate.", call. = FALSE)
}
if (as.integer(source_grid$seed[[1L]]) != 52086L ||
    as.integer(source_profile$seed[[1L]]) != 83016L ||
    abs(num(source_grid$rhs_tau0[[1L]]) - 1e-4) > 1e-12) {
  stop("The selected profile/root seed or RHS tau0 no longer matches audited evidence.", call. = FALSE)
}

fit_request_path <- file.path(
  dirname(dirname(as.character(candidate$fit_file[[1L]]))),
  "fit_request.json"
)
fit_request_path <- resolve_path(fit_request_path)
fit_request <- jsonlite::read_json(fit_request_path, simplifyVector = TRUE)
if (fit_request$spec_id != expected_spec_id ||
    as.integer(fit_request$root_spec$seed) != 52086L ||
    as.integer(fit_request$root_spec$desn_seed) != 123L ||
    as.integer(fit_request$config$desn$seed) != 123L) {
  stop("The observed screening fit request does not preserve the audited seed contract.", call. = FALSE)
}

written <- c(
  profiles = copy_exact(source_paths[["profiles"]], out_paths[["profiles"]])
)
source_assignment$launch_status <- "prepared_confirmation_not_launched"
source_assignment$confirmation_stage <- stage
source_assignment$confirmation_policy <- "coherent_external_benchmark"
source_target$launch_status <- "prepared_confirmation_not_launched"
source_target$confirmation_stage <- stage
written <- c(
  written,
  assignments = write_csv(source_assignment, out_paths[["assignments"]]),
  grid = write_csv(source_grid, out_paths[["grid"]]),
  target_specs = write_csv(source_target, out_paths[["target_specs"]])
)

defaults$campaign$name <- stage
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list("exal")
defaults$execution$allowed_fit_spec_ids <- as.list(expected_spec_id)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- 1L
defaults$runtime$workers <- 1L
defaults$runtime$root_scheduler <- "load_balanced"
defaults$reference_contract$expected_selected_qdesn_roots <- 1L
defaults$screening_profiles$csv <- file.path(
  "config", "validation", paste0(stage, "_profiles.csv")
)
defaults$screening_profiles$cell_assignments_csv <- file.path(
  "config", "validation", paste0(stage, "_cell_assignments.csv")
)
defaults$screening_profiles$canonical_profile_count <- 80L
defaults$screening_profiles$canonical_dataset_cell_count <- 9L
defaults$screening_profiles$canonical_qdesn_root_count <- 720L
defaults$screening_profiles$selected_assignment_root_count <- 1L
defaults$screening_profiles$design <- paste(
  "Exact one-root full-budget confirmation of the metric-gap v3 candidate that",
  "coherently beats the external DQLM/exDQLM benchmark on fit RMSE, H=1000",
  "forecast MAE, and H=1000 forecast check loss."
)
defaults$study_contract$id <- paste0(stage, "_2026_07_27")
defaults$study_contract$description <- paste(
  "Full-budget confirmation of one coherent Q-DESN exAL-RHS candidate.",
  "The statistical design, source registry, root seed, profile declaration,",
  "effective DESN seed, likelihood, rolling-origin protocol, and atomic spec",
  "identity are frozen from metric-gap v3; only the MCMC and metric-draw budgets change."
)
defaults$study_contract$budget$posterior_metric_draws <- 200L
defaults$study_contract$budget$vb_sampling_nd_draws <- 200L
defaults$study_contract$budget$vb_synthesis_n_samp <- 200L
defaults$study_contract$budget$mcmc_n_burn <- 5000L
defaults$study_contract$budget$mcmc_n_mcmc <- 20000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$screening_policy <- list(
  unit = "one_family_tau_likelihood_candidate",
  candidates_per_cell = 1L,
  comparison_policy = "coherent_external_benchmark_with_internal_envelope_context",
  promotion_policy = "full_budget_confirmation_required_before_scientific_promotion",
  launch_status = "prepared_not_launched"
)
defaults$study_contract$confirmation_contract <- list(
  source_closeout_id = closeout_id,
  source_spec_id = expected_spec_id,
  source_root_id = expected_root_id,
  source_profile_id = expected_profile_id,
  source_registry_hash = as.character(candidate$source_registry_hash_value[[1L]]),
  external_ratio_max = 1.05,
  screening_stability_ratio_max = 1.10,
  internal_metric_envelope_is_context_only = TRUE,
  diagnostic_grade_is_reported_not_metric_suppressing = TRUE,
  article_update_is_automatic = FALSE
)
defaults$study_contract$confirmation_budget <- list(
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L,
  posterior_metric_draws = 200L,
  candidates = 1L,
  required_before_article_promotion = TRUE
)
defaults$metrics$posterior_metric_draws <- 200L
defaults$pipeline$sampling$nd_draws <- 200L
defaults$pipeline$synthesis$n_samp <- 200L
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_confirmation"
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "coherent_external_benchmark",
  prune_nonwinning_heavy_outputs = TRUE
)
defaults$pilot$source_family <- "laplace"
defaults$pilot$tau <- 0.25
defaults$smoke$family <- "laplace"
defaults$smoke$tau <- 0.25
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$screening_profile_ids <- as.list(expected_profile_id)
defaults$smoke$max_roots <- 1L
defaults$smoke$budget <- list(
  posterior_metric_draws = 4L,
  vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L,
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
defaults$smoke$pipeline <- list(
  inference = list(
    mcmc = list(
      n_burn = 4L,
      n_mcmc = 4L,
      thin = 1L,
      progress_every = 1L,
      init_from_vb = TRUE
    )
  )
)
dir.create(dirname(out_paths[["defaults"]]), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(defaults, out_paths[["defaults"]])
written <- c(
  defaults = normalizePath(out_paths[["defaults"]], winslash = "/", mustWork = TRUE),
  written
)

defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(out_paths[["defaults"]])
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded,
  refresh_materialized = FALSE,
  verbose = FALSE
)
canonical_selected <- canonical_grid[
  canonical_grid$root_id == expected_root_id,
  ,
  drop = FALSE
]
if (nrow(canonical_selected) != 1L ||
    as.integer(canonical_selected$seed[[1L]]) != 52086L ||
    canonical_selected$screening_profile_id[[1L]] != expected_profile_id) {
  stop("The confirmation defaults do not reconstruct the exact canonical source root.", call. = FALSE)
}
common_grid_columns <- setdiff(intersect(names(source_grid), names(canonical_selected)), "enabled")
encode_row <- function(value, columns) {
  paste(vapply(value[1L, columns, drop = FALSE], as.character, character(1L)), collapse = "\r")
}
if (!identical(
  encode_row(source_grid, common_grid_columns),
  encode_row(canonical_selected, common_grid_columns)
)) {
  stop("The confirmation grid differs from the canonical source root.", call. = FALSE)
}
atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  source_grid,
  defaults = defaults_loaded,
  methods = "mcmc",
  likelihood_families = "exal"
)
if (nrow(atomic) != 1L || atomic$spec_id[[1L]] != expected_spec_id) {
  stop("Changing the confirmation budget changed the frozen atomic spec identity.", call. = FALSE)
}

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
selected_candidate_path <- write_csv(
  candidate,
  file.path(promotion_root, "selected_coherent_external_candidate.csv")
)
eligible_candidates_path <- write_csv(
  eligible,
  file.path(promotion_root, "eligible_coherent_external_candidates.csv")
)
benchmark_contract <- data.frame(
  metric = c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"),
  screening_value = c(
    num(candidate$fit_qtrue_rmse),
    num(candidate$forecast_qtrue_mae_H1000),
    num(candidate$forecast_check_loss_H1000)
  ),
  internal_mixed_envelope = c(
    num(candidate$current_fit_qtrue_rmse),
    num(candidate$current_forecast_qtrue_mae_H1000),
    num(candidate$current_forecast_check_loss_H1000)
  ),
  external_best = c(
    num(candidate$external_best_fit_rmse),
    num(candidate$external_best_forecast_mae),
    num(candidate$external_best_forecast_check)
  ),
  full_external_ratio_max = 1.05,
  full_screening_stability_ratio_max = 1.10,
  internal_envelope_role = "context_only",
  stringsAsFactors = FALSE
)
benchmark_contract_path <- write_csv(
  benchmark_contract,
  file.path(promotion_root, "external_confirmation_contract.csv")
)
seed_contract <- data.frame(
  seed_role = c(
    "profile_declared_seed",
    "deterministic_root_seed",
    "observed_effective_desn_seed"
  ),
  value = c(
    as.integer(source_profile$seed[[1L]]),
    as.integer(source_grid$seed[[1L]]),
    as.integer(fit_request$config$desn$seed)
  ),
  provenance = c(
    source_paths[["profiles"]],
    source_paths[["grid"]],
    fit_request_path
  ),
  confirmation_action = c(
    "preserve_full_profile_catalog_and_row_order",
    "require_exact_grid_row",
    "require_exact_effective_fit_request"
  ),
  stringsAsFactors = FALSE
)
seed_contract_path <- write_csv(
  seed_contract,
  file.path(promotion_root, "seed_contract.csv")
)

lower <- closest[
  num(closest$tau) %in% c(0.05, 0.25),
  ,
  drop = FALSE
]
lower <- lower[lower$spec_id != expected_spec_id, , drop = FALSE]
if (nrow(lower) != 11L) {
  stop(sprintf("Expected 11 unresolved lower-quantile cells; found %d.", nrow(lower)), call. = FALSE)
}
ratio_columns <- c(
  "fit_ratio_to_external_best",
  "forecast_mae_ratio_to_external_best",
  "forecast_check_ratio_to_external_best"
)
ratio_labels <- c("fit_rmse", "forecast_mae_h1000", "forecast_check_h1000")
lower$external_bottleneck <- ratio_labels[
  max.col(as.matrix(lower[, ratio_columns, drop = FALSE]), ties.method = "first")
]
lower$target_external_ratio_max <- 1.05
lower$design_policy <- ifelse(
  lower$external_bottleneck == "fit_rmse",
  "D=1 compact case-local fit neighborhood; vary one of width, memory, or tau0 at a time",
  "D=1 case-local forecast neighborhood; preserve fit while varying memory and persistence one factor at a time"
)
lower$tau0_policy <- "cell-specific among 1e-4, 2e-4, 3e-4; do not repeat the failed 3e-5 broad arm"
lower$launch_status <- "design_handoff_only_not_launched"
lower$global_specification_allowed <- FALSE
lower_redesign_path <- write_csv(
  lower,
  file.path(promotion_root, "lower_quantile_cell_specific_redesign_handoff.csv")
)

source_manifest <- data.frame(
  role = c(names(source_paths), "screening_fit_request"),
  path = c(unname(source_paths), fit_request_path),
  sha256 = vapply(c(unname(source_paths), fit_request_path), sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))
output_files <- c(
  written,
  selected_candidate = selected_candidate_path,
  eligible_candidates = eligible_candidates_path,
  benchmark_contract = benchmark_contract_path,
  seed_contract = seed_contract_path,
  lower_quantile_redesign = lower_redesign_path,
  source_manifest = source_manifest_path
)
output_manifest <- data.frame(
  role = names(output_files),
  path = unname(output_files),
  sha256 = vapply(output_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
output_manifest_path <- write_csv(output_manifest, file.path(promotion_root, "file_manifest.csv"))

readme_lines <- c(
  "# Q-DESN External-Coherent Full-Budget Confirmation v1",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- package: `exdqlm %s`", as.character(description[1L, "Version"])),
  sprintf("- source closeout: `%s`", closeout_id),
  sprintf("- selected atomic spec: `%s`", expected_spec_id),
  sprintf("- selected root: `%s`", expected_root_id),
  sprintf("- source registry SHA-256: `%s`", candidate$source_registry_hash_value[[1L]]),
  "- launch status: `prepared_not_launched`",
  "",
  "## Decision",
  "",
  "Two reduced-budget candidates coherently beat the external DQLM/exDQLM",
  "benchmark on fit RMSE, H=1000 forecast MAE, and H=1000 forecast check loss.",
  "The tau0=3e-4 anchor already has 20,000-iteration full-budget evidence. The",
  "tau0=1e-4 local candidate has the better screening fit RMSE and is therefore",
  "the only remaining candidate promoted to confirmation. The mixed historical",
  "Q-DESN metric envelope remains context rather than a blocking target.",
  "",
  "## Confirmation Gates",
  "",
  "- One exact root and one exact exAL atomic spec.",
  "- External ratio at most 1.05 for each of the three metrics.",
  "- Full-budget metric at most 1.10 times its reduced-budget screening value.",
  paste(
    "- Exact source-registry hash, all three source-file hashes, and source",
    "windows: train 8501:9000; forecast 9001:10000."
  ),
  "- Complete scalar/path/status artifacts and no retained `.rds`, `.rda`, or `.RData` payload.",
  "- Chain diagnostics are retained and reported; they do not silently erase metric evidence.",
  "- No article update is automatic.",
  "",
  "## Remaining Lower-Quantile Work",
  "",
  "The other 11 lower-quantile family/quantile/likelihood cells are frozen as a",
  "cell-specific redesign handoff. No broad follow-up is launched by this stage.",
  "The redesign excludes a global specification and the already unproductive",
  "D=2 / tau0=3e-5 broad direction.",
  "",
  sprintf("- selected candidate: `%s`", selected_candidate_path),
  sprintf("- all externally coherent screening candidates: `%s`", eligible_candidates_path),
  sprintf("- benchmark contract: `%s`", benchmark_contract_path),
  sprintf("- seed contract: `%s`", seed_contract_path),
  sprintf("- lower-quantile redesign: `%s`", lower_redesign_path),
  sprintf("- defaults: `%s`", out_paths[["defaults"]]),
  sprintf("- grid: `%s`", out_paths[["grid"]]),
  sprintf("- target spec: `%s`", out_paths[["target_specs"]])
)
readme_path <- file.path(promotion_root, "README.md")
writeLines(readme_lines, readme_path, useBytes = TRUE)
readme_path <- normalizePath(readme_path, winslash = "/", mustWork = TRUE)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = git_branch_before_materialization,
  git_commit = git_commit_before_materialization,
  tracked_source_dirty_before_materialization = tracked_dirty_before_materialization,
  untracked_before_materialization = unname(untracked_before_materialization),
  git_dirty_after_materialization = length(
    system("git status --porcelain", intern = TRUE)
  ) > 0L,
  package = list(name = "exdqlm", version = "1.0.0", loading = "pkgload_local_worktree"),
  stage = stage,
  launch_status = "prepared_not_launched",
  selected = list(
    root_id = expected_root_id,
    spec_id = expected_spec_id,
    profile_id = expected_profile_id,
    family = "laplace",
    tau = 0.25,
    likelihood = "exal",
    source_registry_hash = as.character(candidate$source_registry_hash_value[[1L]])
  ),
  budgets = list(
    screening = list(mcmc_n_burn = 2000L, mcmc_n_mcmc = 8000L, metric_draws = 100L),
    confirmation = list(mcmc_n_burn = 5000L, mcmc_n_mcmc = 20000L, metric_draws = 200L)
  ),
  gates = list(
    external_ratio_max = 1.05,
    screening_stability_ratio_max = 1.10,
    exact_source_and_spec = TRUE,
    storage_light = TRUE,
    article_update_automatic = FALSE
  ),
  counts = list(
    externally_coherent_screening_candidates = nrow(eligible),
    preserved_profile_catalog_rows = nrow(profiles),
    selected_assignments = nrow(source_assignment),
    selected_grid_roots = nrow(source_grid),
    selected_atomic_specs = nrow(source_target),
    lower_quantile_redesign_cells = nrow(lower)
  ),
  source_manifest = source_manifest,
  output_manifest_path = output_manifest_path,
  readme = readme_path
)
manifest_path <- write_json(manifest, out_paths[["manifest"]])

cat(sprintf("stage: %s\n", stage))
cat("launch_status: prepared_not_launched\n")
cat(sprintf("selected_root: %s\n", expected_root_id))
cat(sprintf("selected_spec: %s\n", expected_spec_id))
cat(sprintf("lower_quantile_redesign_cells: %d\n", nrow(lower)))
cat(sprintf("manifest: %s\n", manifest_path))
