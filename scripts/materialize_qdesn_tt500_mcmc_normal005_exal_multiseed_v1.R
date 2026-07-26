#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("yaml", quietly = TRUE) ||
      !requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Packages `yaml` and `jsonlite` are required.", call. = FALSE)
  }
})

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)

source_stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2"
target_stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_normal005_exal_multiseed_v1"
config_root <- file.path("config", "validation")
source_path <- function(suffix) file.path(config_root, paste0(source_stub, suffix))
target_path <- function(suffix) file.path(config_root, paste0(target_stub, suffix))

read_csv <- function(path) {
  utils::read.csv(normalizePath(path, winslash = "/", mustWork = TRUE),
                  check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) {
  unname(tools::sha256sum(normalizePath(path, winslash = "/", mustWork = TRUE)))
}

profiles <- read_csv(source_path("_profiles.csv"))
assignments <- read_csv(source_path("_cell_assignments.csv"))
grid <- read_csv(source_path("_grid.csv"))
specs <- read_csv(source_path("_target_spec_ids.csv"))
defaults <- yaml::read_yaml(source_path("_defaults.yaml"))

profile_id <- "mcvbc_060_exal"
profiles <- profiles[profiles$screening_profile_id == profile_id, , drop = FALSE]
assignments <- assignments[
  assignments$screening_profile_id == profile_id &
    assignments$likelihood_target == "exal",
  , drop = FALSE
]
grid <- grid[
  grid$screening_profile_id == profile_id &
    grid$source_family == "normal" &
    abs(as.numeric(grid$tau) - 0.05) < 1e-8,
  , drop = FALSE
]
spec_profile_col <- if ("screening_profile_id.x" %in% names(specs)) {
  "screening_profile_id.x"
} else {
  "screening_profile_id"
}
specs <- specs[
  specs[[spec_profile_col]] == profile_id &
    specs$likelihood_target == "exal",
  , drop = FALSE
]
if (any(c(nrow(profiles), nrow(assignments), nrow(grid), nrow(specs)) != 1L)) {
  stop("Targeted stage requires exactly one profile, assignment, root, and spec.",
       call. = FALSE)
}

defaults$campaign$name <- target_stub
defaults$campaign$results_root <- file.path(
  "results", "qdesn_mcmc_validation", target_stub
)
defaults$campaign$reports_root <- file.path(
  "reports", "qdesn_mcmc_validation", target_stub
)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- "exal"
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(specs$spec_id))
defaults$execution$seed_policy$base_seed <- 76000L
defaults$study_contract$id <- paste0(target_stub, "_2026_07_26")
defaults$study_contract$description <- paste(
  "Four-seed MCMC diagnostic confirmation of normal tau=0.05 exQ-DESN",
  "candidate mcvbc_060_exal. This is a diagnostic gate, not a broad screen."
)
defaults$source_materialization$families <- "normal"
defaults$source_materialization$taus <- 0.05
defaults$pilot$source_family <- "normal"
defaults$pilot$tau <- 0.05
# Source materialization uses the canonical 300-observation context profile.
# The targeted DESN design is selected from screening_profiles.csv at fit time.
defaults$pilot$reservoir_profile <- "deep_d3_n400x3_skip100_w300_m60"
defaults$reference_contract$families <- "normal"
defaults$reference_contract$taus <- 0.05
defaults$reference_contract$expected_unique_dataset_cells <- 1L
defaults$reference_contract$expected_qdesn_roots <- 1L
defaults$reference_contract$expected_selected_qdesn_roots <- 1L
defaults$screening_profiles$csv <- target_path("_profiles.csv")
defaults$screening_profiles$cell_assignments_csv <-
  target_path("_cell_assignments.csv")
defaults$screening_profiles$canonical_profile_count <- 1L
defaults$screening_profiles$canonical_dataset_cell_count <- 1L
defaults$screening_profiles$canonical_qdesn_root_count <- 1L
defaults$screening_profiles$selected_assignment_root_count <- 1L
defaults$screening_profiles$design <- paste(
  "One fixed DESN design with four independent MCMC seeds.",
  "Promotion requires replicated diagnostic and metric stability."
)
defaults$multiseed <- list(
  enabled = TRUE,
  mcmc_seed_reps = 4L,
  parallel_seed_workers = 4L,
  selection_metric = "train_qtrue_rmse",
  prune_nonwinning_heavy_outputs = TRUE,
  seed_base = 760000L,
  model_offsets = list(al = 0L, exal = 5000L),
  desn_offset = 30000L,
  mcmc_seed_offset = 0L,
  mcmc_rng_offset = 0L,
  vb_warm_start_offset = 10000L,
  synthesis_offset = 20000L
)

profiles$screening_stage <- "mcmc_normal005_exal_multiseed_confirmation_v1"
profiles$screening_wave <- "mcmc_normal005_exal_multiseed_confirmation_2026_07_26"
profiles$profile_role <- "diagnostic_all_primary_candidate_multiseed_confirmation"
assignments$cell_status <- "targeted_multiseed_diagnostic_confirmation"
assignments$selection_reason <- paste(
  "all-primary MCMC metric win blocked by gamma autocorrelation 0.983;",
  "confirm with four independent seeds"
)
grid$screening_stage <- profiles$screening_stage
grid$screening_wave <- profiles$screening_wave
grid$profile_role <- profiles$profile_role
# deterministic_per_root: base 76000 + RHS prior offset 10.
grid$seed <- 76010L

profile_out <- write_csv(profiles, target_path("_profiles.csv"))
assignment_out <- write_csv(assignments, target_path("_cell_assignments.csv"))
grid_out <- write_csv(grid, target_path("_grid.csv"))
spec_out <- write_csv(specs, target_path("_target_spec_ids.csv"))
yaml::write_yaml(defaults, target_path("_defaults.yaml"))
defaults_out <- normalizePath(target_path("_defaults.yaml"), winslash = "/",
                              mustWork = TRUE)

source_files <- c(
  source_profiles = source_path("_profiles.csv"),
  source_assignments = source_path("_cell_assignments.csv"),
  source_grid = source_path("_grid.csv"),
  source_target_specs = source_path("_target_spec_ids.csv"),
  source_defaults = source_path("_defaults.yaml"),
  closeout_plan = file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726",
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726_targeted_confirmation_plan.csv"
  )
)
outputs <- c(
  profiles = profile_out, assignments = assignment_out, grid = grid_out,
  target_specs = spec_out, defaults = defaults_out
)
manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = target_stub,
  candidate = list(
    family = "normal", tau = 0.05, likelihood = "exal",
    profile_id = profile_id, spec_id = as.character(specs$spec_id),
    prior = "rhs_ns"
  ),
  multiseed = list(
    n_seed_reps = 4L,
    parallel_seed_workers = 4L,
    selection_metric = "train_qtrue_rmse",
    promotion_gate = paste(
      "at least 2 of 4 DESN/MCMC seed replicates PASS/WARN; selected replicate PASS/WARN;",
      "fit RMSE, H1000 forecast MAE, and H1000 check-loss ratios remain below 1"
    )
  ),
  mcmc = list(
    n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
    init_from_vb = TRUE, progress_every = 50L
  ),
  storage = list(
    keep_draws = FALSE, save_forecast_objects = FALSE,
    retain_full_rds_on_failure = FALSE,
    prune_nonwinning_heavy_outputs = TRUE
  ),
  source_files = lapply(source_files, function(path) {
    list(path = normalizePath(path, winslash = "/", mustWork = TRUE),
         sha256 = sha256(path))
  }),
  output_files = lapply(outputs, function(path) {
    list(path = normalizePath(path, winslash = "/", mustWork = TRUE),
         sha256 = sha256(path))
  }),
  launch_status = "prepared_not_launched"
)
jsonlite::write_json(
  manifest, target_path("_materialization_manifest.json"),
  pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
)

cat(sprintf(
  "stage=%s roots=%d specs=%d seed_reps=%d workers=%d profile=%s\n",
  target_stub, nrow(grid), nrow(specs),
  defaults$multiseed$mcmc_seed_reps,
  defaults$multiseed$parallel_seed_workers,
  profile_id
))
