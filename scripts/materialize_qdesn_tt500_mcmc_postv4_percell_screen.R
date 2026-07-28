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
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

materialization_git_sha <- trimws(system("git rev-parse HEAD", intern = TRUE))
materialization_git_branch <- trimws(system("git branch --show-current", intern = TRUE))
tracked_source_dirty_before_materialization <-
  system("git diff --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
  system("git diff --cached --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
tau_label <- function(x) sub("0+$", "", sub("[.]$", "", sprintf("%.2f", as.numeric(x))))
model_to_likelihood <- function(x) {
  out <- rep(NA_character_, length(x))
  out[as.character(x) == "qdesn_al_rhs_ns"] <- "al"
  out[as.character(x) == "qdesn_exal_rhs_ns"] <- "exal"
  out
}
safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_|_$", "", x)
  x
}
md_table <- function(x, cols, max_rows = 80L) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    values <- vapply(y[i, , drop = TRUE], function(value) {
      value <- as.character(value)
      value[is.na(value)] <- ""
      gsub("\n", " ", value, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(values, collapse = " | "), "|"))
  }
  out
}

stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell"
))[1L]
stamp <- as.character(get_arg("--stamp", "20260727"))[1L]
workers <- int(get_arg("--workers", "16"))[1L]
if (!is.finite(workers) || workers < 1L) workers <- 16L
workers <- min(workers, 24L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

design_root <- resolve_path(get_arg(
  "--design-root",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_postv4_percell_design_20260727"
  )
))
design_id <- basename(design_root)
design_path <- resolve_path(file.path(design_root, paste0(design_id, "_candidate_arm_design.csv")))
diagnostic_path <- resolve_path(file.path(design_root, paste0(design_id, "_unresolved_cell_diagnostic.csv")))
design_manifest_path <- resolve_path(file.path(design_root, paste0(design_id, "_manifest.json")))
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path(
    "config", "validation",
    "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_defaults.yaml"
  )
))
out_root <- resolve_path(get_arg(
  "--out-root",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    paste0("qdesn_tt500_mcmc_postv4_percell_prelaunch_", stamp)
  )
), must_work = FALSE)

profiles_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_profiles.csv")),
  must_work = FALSE
)
assignments_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv")),
  must_work = FALSE
)
defaults_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_defaults.yaml")),
  must_work = FALSE
)
grid_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_grid.csv")),
  must_work = FALSE
)
target_specs_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv")),
  must_work = FALSE
)
manifest_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")),
  must_work = FALSE
)

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Post-v4 launch materialization requires the exdqlm 1.0.0 worktree.", call. = FALSE)
}

design <- read_csv(design_path)
diagnostic <- read_csv(diagnostic_path)
design_manifest <- jsonlite::read_json(design_manifest_path, simplifyVector = TRUE)
source_hash <- as.character(design_manifest$source_registry_hash_value)
if (!identical(source_hash, "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275")) {
  stop("Post-v4 design does not carry the frozen source-registry hash.", call. = FALSE)
}
if (nrow(design) != 90L ||
    nrow(unique(design[c("model_variant", "family", "tau", "fit_size")])) != 15L ||
    any(table(paste(design$model_variant, design$family, tau_key(design$tau), design$fit_size, sep = "\r")) != 6L)) {
  stop("Post-v4 design must contain exactly 90 arms, six for each of 15 cells.", call. = FALSE)
}
if (any(as.character(design$launch_status) != "not_materialized_not_launched_review_required")) {
  stop("Post-v4 design was not in a review-gated state.", call. = FALSE)
}
if (any(num(design$p_over_n_tt500) > 1.60)) {
  stop("Post-v4 design exceeds the p/n gate.", call. = FALSE)
}

design$likelihood_target <- model_to_likelihood(design$model_variant)
if (any(!design$likelihood_target %in% c("al", "exal"))) {
  stop("Unsupported model variant in post-v4 design.", call. = FALSE)
}
design <- design[order(
  match(design$family, c("normal", "laplace", "gausmix")),
  num(design$tau),
  design$likelihood_target,
  int(design$arm_rank)
), , drop = FALSE]
design$screening_profile_id <- sprintf(
  "postv4_%03d_%s_%s",
  seq_len(nrow(design)),
  design$likelihood_target,
  safe_token(design$arm_role)
)

profiles <- data.frame(
  screening_profile_id = design$screening_profile_id,
  screening_stage = "mcmc_postv4_percell_screen",
  screening_wave = "mcmc_postv4_percell_2026_07_27",
  profile_role = design$arm_role,
  enabled = TRUE,
  D = int(design$D),
  n_each = int(design$n_each),
  n_tilde_each = int(design$n_tilde_each),
  m = int(design$m),
  alpha = num(design$alpha),
  rho = num(design$rho),
  pi_w = num(design$pi_w),
  pi_in = num(design$pi_in),
  washout = 300L,
  add_bias = TRUE,
  seed = int(design$seed),
  readout_y_lags = int(design$readout_y_lags),
  reservoir_lags = int(design$reservoir_lags),
  rhs_tau0 = num(design$rhs_tau0),
  dimension_p_estimate = int(design$dimension_p_estimate),
  p_over_n_tt500 = num(design$p_over_n_tt500),
  x_feature_count = 5L,
  target_cells = paste(design$family, tau_label(design$tau), design$likelihood_target, sep = ":"),
  source_screening_profile_id = as.character(design$source_screening_profile_id),
  candidate_source = as.character(design$arm_role),
  selection_reason = as.character(design$rationale),
  stringsAsFactors = FALSE
)

diagnostic_key <- paste(diagnostic$model_variant, diagnostic$family, tau_key(diagnostic$tau), diagnostic$fit_size, sep = "\r")
design_key <- paste(design$model_variant, design$family, tau_key(design$tau), design$fit_size, sep = "\r")
diagnostic_lookup <- diagnostic[match(design_key, diagnostic_key), , drop = FALSE]
if (any(is.na(diagnostic_lookup$model_variant))) {
  stop("Could not match every post-v4 design arm to the unresolved-cell diagnostic.", call. = FALSE)
}

assignments <- data.frame(
  assignment_key = paste(design$screening_profile_id, design$family, tau_key(design$tau), sep = "\r"),
  assignment_id = sprintf("mcmc_postv4_percell_%03d", seq_len(nrow(design))),
  family = as.character(design$family),
  tau = num(design$tau),
  likelihood_target = as.character(design$likelihood_target),
  cell_status = as.character(diagnostic_lookup$dominant_gap_class),
  priority_rank = match(design_key, unique(design_key)),
  target_profile_rank = int(design$arm_rank),
  screening_profile_id = design$screening_profile_id,
  source_profile = as.character(design$source_screening_profile_id),
  candidate_source = as.character(design$arm_role),
  selection_reason = as.character(design$rationale),
  primary_gap = as.character(diagnostic_lookup$primary_remaining_gap),
  current_worst_ratio = num(diagnostic_lookup$worst_ratio_refreshed),
  fit_ratio_to_external_best = num(diagnostic_lookup$fit_ratio_refreshed),
  forecast_mae_ratio_to_external_best = num(diagnostic_lookup$forecast_mae_ratio_refreshed),
  forecast_check_ratio_to_external_best = num(diagnostic_lookup$forecast_check_ratio_refreshed),
  bottleneck_metric = as.character(diagnostic_lookup$primary_remaining_gap),
  source_path = design_path,
  launch_status = "prepared_not_launched",
  stringsAsFactors = FALSE
)

cell_plan <- do.call(rbind, lapply(split(assignments, design_key), function(rows) {
  data.frame(
    family = rows$family[[1L]],
    tau = rows$tau[[1L]],
    likelihood_target = rows$likelihood_target[[1L]],
    primary_gap = rows$primary_gap[[1L]],
    current_worst_ratio = rows$current_worst_ratio[[1L]],
    n_candidates = nrow(rows),
    cell_status = rows$cell_status[[1L]],
    priority_rank = rows$priority_rank[[1L]],
    target_profiles = paste(rows$screening_profile_id, collapse = ";"),
    launch_status = "prepared_not_launched",
    stringsAsFactors = FALSE
  )
}))
cell_plan <- cell_plan[order(cell_plan$priority_rank), , drop = FALSE]

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    stage_file = stage_file,
    selection_policy = "Post-v4 per-cell MCMC screen from 90 reviewed arms."
  )
)

materialized <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  stage_stub = stage_file,
  stage_desc = paste(
    "Q-DESN 500-observation post-v4 per-cell MCMC screen.",
    "Six arms per unresolved family x tau x likelihood cell."
  ),
  stage = "mcmc_postv4_percell_screen",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
families <- sort(unique(as.character(assignments$family)))
taus <- sort(unique(num(assignments$tau)))
selected_dataset_cells <- length(unique(paste(assignments$family, tau_key(assignments$tau), sep = "\r")))
canonical_dataset_cells <- length(families) * length(taus)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$study_contract$id <- paste0(stage_file, "_2026_07_27")
defaults$study_contract$description <- paste(
  "Post-v4 per-cell reduced-budget MCMC screen for independent Q-DESN/exQ-DESN",
  "RHS rows still outside the external DQLM/exDQLM tolerance band."
)
defaults$study_contract$budget$posterior_metric_draws <- 100L
defaults$study_contract$budget$vb_sampling_nd_draws <- 100L
defaults$study_contract$budget$vb_synthesis_n_samp <- 100L
defaults$study_contract$budget$mcmc_n_burn <- 2000L
defaults$study_contract$budget$mcmc_n_mcmc <- 8000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$mcmc <- defaults$study_contract$mcmc %||% list()
defaults$study_contract$mcmc$require_init_from_vb <- TRUE
defaults$study_contract$screening_policy <- list(
  unit = "model_family_tau_likelihood_metric_cell",
  parent_design = design_id,
  candidates_per_cell = 6L,
  comparison_policy = "status_agnostic_metrics_with_status_retained",
  promotion_policy = "screening_selects_metric_improvements_then_full_confirmation_for_article_claims",
  launch_status = "prepared_not_launched"
)
defaults$study_contract$confirmation_budget <- list(
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L,
  candidates_per_cell = 1L,
  required_before_article_promotion = TRUE
)
defaults$study_contract$exploration_policy <- list(
  reason = "post-v4 per-cell screen avoids global-specification search",
  p_over_n_gate = 1.60,
  max_proposed_p_over_n = max(num(profiles$p_over_n_tt500)),
  local_tau0_values = as.list(sort(unique(num(profiles$rhs_tau0)))),
  objective = "improve Q-DESN/exQ-DESN RHS MCMC lower-quantile fit and forecast gaps"
)
defaults$source_materialization$families <- as.list(families)
defaults$source_materialization$taus <- as.list(taus)
defaults$reference_contract$families <- as.list(families)
defaults$reference_contract$taus <- as.list(taus)
defaults$reference_contract$expected_unique_dataset_cells <- canonical_dataset_cells
defaults$reference_contract$expected_qdesn_roots <- nrow(profiles) * canonical_dataset_cells
defaults$reference_contract$expected_selected_qdesn_roots <- nrow(assignments)
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_dataset_cell_count <- canonical_dataset_cells
defaults$screening_profiles$canonical_qdesn_root_count <- nrow(profiles) * canonical_dataset_cells
defaults$screening_profiles$selected_assignment_root_count <- nrow(assignments)
defaults$screening_profiles$design <- paste(
  "Post-v4 per-cell MCMC screen: 15 unresolved family/tau/likelihood rows x 6 arms;",
  "historical bottleneck winner, coherent historical replay, two tau0 perturbations, and two axis-specific breakouts."
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$pilot$source_family <- as.character(assignments$family[[1L]])
defaults$pilot$tau <- num(assignments$tau)[1L]
defaults$smoke$family <- as.character(assignments$family[[1L]])
defaults$smoke$tau <- num(assignments$tau)[1L]
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$screening_profile_ids <- as.list(assignments$screening_profile_id[[1L]])
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
defaults$pipeline$inference$mcmc$n_burn <- 2000L
defaults$pipeline$inference$mcmc$n_mcmc <- 8000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 2000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 8000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "postv4_percell_metric_gap",
  prune_nonwinning_heavy_outputs = TRUE
)
yaml::write_yaml(defaults, defaults_out)

defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_out)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded,
  refresh_materialized = refresh_materialized,
  verbose = FALSE
)
canonical_key <- paste(
  canonical_grid$screening_profile_id,
  canonical_grid$source_family,
  tau_key(canonical_grid$tau),
  sep = "\r"
)
assignment_keys <- unique(assignments$assignment_key)
missing_assignment_keys <- setdiff(assignment_keys, canonical_key)
if (length(missing_assignment_keys)) {
  stop(
    sprintf(
      "Canonical grid is missing %d assignment(s), including `%s`.",
      length(missing_assignment_keys),
      missing_assignment_keys[[1L]]
    ),
    call. = FALSE
  )
}
selected_mask <- canonical_key %in% assignment_keys
grid <- canonical_grid[selected_mask, , drop = FALSE]
grid$assignment_key <- canonical_key[selected_mask]
grid <- grid[order(grid$source_family, grid$tau, grid$screening_profile_id), , drop = FALSE]
root_lookup <- grid[, c("assignment_key", "root_id"), drop = FALSE]
grid$assignment_key <- NULL
write_csv(grid, grid_out)

assignments_after <- merge(assignments, root_lookup, by = "assignment_key", all.x = TRUE, sort = FALSE)
if (any(!nzchar(as.character(assignments_after$root_id)))) {
  stop("Failed to attach canonical root IDs to every post-v4 assignment.", call. = FALSE)
}
assignments_after <- assignments_after[order(assignments_after$priority_rank, assignments_after$target_profile_rank), , drop = FALSE]
write_csv(assignments_after, assignments_out)

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults = defaults_loaded,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
target_map <- assignments_after[, c(
  "assignment_key", "root_id", "family", "tau", "likelihood_target",
  "screening_profile_id", "candidate_source", "selection_reason",
  "primary_gap", "current_worst_ratio", "fit_ratio_to_external_best",
  "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
  "launch_status"
), drop = FALSE]
target_specs <- merge(
  target_map,
  atomic,
  by.x = c("root_id", "likelihood_target"),
  by.y = c("root_id", "likelihood_family"),
  all.x = TRUE,
  sort = FALSE
)
if (any(!nzchar(as.character(target_specs$spec_id)))) {
  stop("Failed to resolve one or more post-v4 MCMC atomic spec IDs.", call. = FALSE)
}
target_specs <- target_specs[order(
  target_specs$family.x,
  target_specs$tau.x,
  target_specs$likelihood_target,
  target_specs$screening_profile_id.x
), , drop = FALSE]
target_specs_out <- write_csv(target_specs, target_specs_out)
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_out)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
diagnostic_out <- write_csv(
  diagnostic,
  file.path(out_root, paste0("qdesn_tt500_mcmc_postv4_percell_diagnostic_", stamp, ".csv"))
)
design_out <- write_csv(
  design,
  file.path(out_root, paste0("qdesn_tt500_mcmc_postv4_percell_design_", stamp, ".csv"))
)
cell_plan_out <- write_csv(
  cell_plan,
  file.path(out_root, paste0("qdesn_tt500_mcmc_postv4_percell_cell_plan_", stamp, ".csv"))
)
pattern_audit <- data.frame(
  finding = c(
    "source_design_rows", "unresolved_cells", "arms_per_cell",
    "target_mcmc_specs", "max_p_over_n", "launch_policy", "article_policy"
  ),
  value = c(
    nrow(design), nrow(cell_plan), 6L, nrow(target_specs),
    sprintf("%.3f", max(profiles$p_over_n_tt500)),
    "prepare, smoke, detached full screen after clean commit",
    "no direct article update from screening launch"
  ),
  interpretation = c(
    "Reviewed post-v4 candidate arms.",
    "Independent Q-DESN/exQ-DESN RHS rows still outside tolerance.",
    "Each cell receives historical replay, coherent replay, tau0 perturbations, and two breakout arms.",
    "One MCMC spec for each selected profile/family/tau/likelihood assignment.",
    "Current launch stays below the v4 p/n gate.",
    "The launch is staged and reproducible.",
    "Article-facing updates require closeout and explicit promotion."
  ),
  stringsAsFactors = FALSE
)
pattern_audit_out <- write_csv(
  pattern_audit,
  file.path(out_root, paste0("qdesn_tt500_mcmc_postv4_percell_pattern_audit_", stamp, ".csv"))
)

readme_lines <- c(
  "# Q-DESN 500-Observation MCMC Post-v4 Per-cell Prelaunch",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  "- launch_status: `prepared_not_launched`",
  sprintf("- source registry SHA-256: `%s`", source_hash),
  sprintf("- unresolved cells: `%d`", nrow(cell_plan)),
  sprintf("- target MCMC specs: `%d`", nrow(target_specs)),
  sprintf("- workers prepared: `%d`", workers),
  "",
  "## Decision",
  "",
  "This launch materialization implements the reviewed post-v4 per-cell plan.",
  "It launches all 15 unresolved cells and all six arms per cell, for 90",
  "reduced-budget MCMC specifications. The goal is metric-gap calibration, not",
  "a global DESN specification.",
  "",
  "## Cell Plan",
  "",
  md_table(
    cell_plan,
    c(
      "priority_rank", "family", "tau", "likelihood_target", "primary_gap",
      "current_worst_ratio", "n_candidates", "cell_status", "launch_status"
    ),
    max_rows = 20L
  ),
  "",
  "## Gates",
  "",
  "- Prepare-only must resolve all 90 specs.",
  "- Smoke runs one MCMC spec before full launch.",
  "- Full screen runs in detached tmux only after the config state is committed.",
  "- Storage-light settings remain active.",
  "- No article table update is implied by this launch.",
  "",
  "## Prepared Inputs",
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- target specs: `%s`", target_specs_out),
  sprintf("- materialization manifest: `%s`", manifest_out)
)
readme_path <- file.path(out_root, "README.md")
writeLines(readme_lines, readme_path, useBytes = TRUE)
readme_path <- normalizePath(readme_path, winslash = "/", mustWork = TRUE)

file_manifest <- data.frame(
  role = c(
    "design", "diagnostic", "design_manifest", "base_defaults",
    "profiles", "assignments", "defaults", "grid", "target_specs",
    "diagnostic_out", "design_out", "cell_plan", "pattern_audit", "readme"
  ),
  path = c(
    design_path, diagnostic_path, design_manifest_path, base_defaults_path,
    profiles_out, assignments_out, defaults_out, grid_out, target_specs_out,
    diagnostic_out, design_out, cell_plan_out, pattern_audit_out, readme_path
  ),
  sha256 = NA_character_,
  stringsAsFactors = FALSE
)
file_manifest$sha256 <- vapply(file_manifest$path, sha256_file, character(1L))
file_manifest_out <- write_csv(file_manifest, file.path(out_root, "file_manifest.csv"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = materialization_git_sha,
  git_branch = materialization_git_branch,
  git_dirty = tracked_source_dirty_before_materialization,
  git_dirty_scope = "tracked_source_before_materialization",
  git_dirty_at_manifest_write = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  purpose = "post_v4_per_cell_qdesn_mcmc_metric_gap_screen",
  launch_status = "prepared_not_launched",
  source_registry_hash = source_hash,
  budgets = list(
    screening = list(n_burn = 2000L, n_mcmc = 8000L, thin = 1L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, thin = 1L)
  ),
  counts = list(
    unresolved_cells = nrow(cell_plan),
    candidates_per_cell = 6L,
    profiles = nrow(profiles),
    assignments = nrow(assignments_after),
    selected_grid_roots = nrow(grid),
    target_mcmc_atomic_specs = nrow(target_specs)
  ),
  materialized = materialized,
  outputs = list(
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    target_specs = target_specs_out,
    diagnostic = diagnostic_out,
    design = design_out,
    cell_plan = cell_plan_out,
    pattern_audit = pattern_audit_out,
    readme = readme_path,
    file_manifest = file_manifest_out
  )
)
write_json(manifest, manifest_out)
write_json(manifest, file.path(out_root, paste0("qdesn_tt500_mcmc_postv4_percell_prelaunch_manifest_", stamp, ".json")))

cat(sprintf("stage_file: %s\n", stage_file))
cat("launch_status: prepared_not_launched\n")
cat(sprintf("unresolved_cells: %d\n", nrow(cell_plan)))
cat(sprintf("profiles: %d\n", nrow(profiles)))
cat(sprintf("target_specs: %d\n", nrow(target_specs)))
cat(sprintf("manifest: %s\n", manifest_out))
