#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}
num_or_na <- function(x) {
  out <- suppressWarnings(as.numeric(x))
  out[!is.finite(out)] <- NA_real_
  out
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
write_df <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
pick_col <- function(df, names, default = NA) {
  for (nm in names) {
    if (nm %in% colnames(df)) return(df[[nm]])
  }
  rep(default, nrow(df))
}
md_table <- function(x, cols) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return("| none |\n|---|")
  y <- x[, cols, drop = FALSE]
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    out <- c(out, paste("|", paste(vapply(y[i, , drop = TRUE], as.character, character(1L)), collapse = " | "), "|"))
  }
  out
}

stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff"
))[1L]
stamp <- as.character(get_arg("--stamp", "20260709"))[1L]
selection_csv <- resolve_path(get_arg(
  "--selection-csv",
  file.path("validation", "fitforecast_v2", "docs", paste0("qdesn_tt500_vb_historical_winner_handoff_selected_designs_", stamp, ".csv"))
), must_work = TRUE)
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_defaults.yaml")
), must_work = TRUE)
profiles_out <- resolve_path(get_arg(
  "--profiles-out",
  file.path("config", "validation", paste0(stage_file, "_profiles.csv"))
), must_work = FALSE)
assignments_out <- resolve_path(get_arg(
  "--assignments-out",
  file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))
), must_work = FALSE)
defaults_out <- resolve_path(get_arg(
  "--defaults-out",
  file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))
), must_work = FALSE)
grid_out <- resolve_path(get_arg(
  "--grid-out",
  file.path("config", "validation", paste0(stage_file, "_grid.csv"))
), must_work = FALSE)
manifest_path <- resolve_path(get_arg(
  "--manifest-out",
  file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))
), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg(
  "--diagnostic-out",
  file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")
), must_work = FALSE)
workers <- int_arg("--workers", 20L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("historical_winner_handoff_", format(Sys.Date(), "%Y_%m_%d"))))[1L]
likelihoods <- as.character(get_arg("--likelihoods", "exal"))[1L]
likelihoods <- trimws(strsplit(likelihoods, ",", fixed = TRUE)[[1L]])
likelihoods <- likelihoods[nzchar(likelihoods)]
if (!length(likelihoods)) likelihoods <- "exal"

selection <- utils::read.csv(selection_csv, check.names = FALSE, stringsAsFactors = FALSE)
if (!nrow(selection)) stop("Historical-winner selection CSV is empty.", call. = FALSE)
required <- c("family", "tau", "resolved_screening_profile_id", "priority_rank", "target_profile_rank")
missing <- setdiff(required, names(selection))
if (length(missing)) stop(sprintf("Selection CSV missing column(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
selection$family <- as.character(selection$family)
selection$tau <- num_or_na(selection$tau)
selection$resolved_screening_profile_id <- as.character(selection$resolved_screening_profile_id)
selection$priority_rank <- as.integer(selection$priority_rank)
selection$target_profile_rank <- as.integer(selection$target_profile_rank)
selection <- selection[order(selection$priority_rank, selection$target_profile_rank), , drop = FALSE]

profile_ids <- unique(selection$resolved_screening_profile_id)
profile_rows <- lapply(profile_ids, function(pid) {
  rows <- selection[selection$resolved_screening_profile_id == pid, , drop = FALSE]
  r <- rows[1L, , drop = FALSE]
  target_cells <- paste(rows$family, sprintf("%.2f", rows$tau), sep = ":")
  source_runs <- unique(paste(rows$stage, rows$run_tag, sep = "::"))
  data.frame(
    screening_profile_id = pid,
    screening_stage = "vb_historical_winner_handoff",
    screening_wave = screening_wave,
    profile_role = paste0("historical_exact_", as.character(pick_col(r, c("profile_profile_role", "profile_role"), "winner"))),
    enabled = TRUE,
    D = as.integer(num_or_na(pick_col(r, c("profile_D", "D")))),
    n_each = as.integer(num_or_na(pick_col(r, c("profile_n_each", "n_each")))),
    n_tilde_each = as.integer(num_or_na(pick_col(r, c("profile_n_tilde_each", "n_tilde_each"), 0))),
    m = as.integer(num_or_na(pick_col(r, c("profile_m", "m")))),
    alpha = num_or_na(pick_col(r, c("profile_alpha", "alpha"))),
    rho = num_or_na(pick_col(r, c("profile_rho", "rho"))),
    pi_w = num_or_na(pick_col(r, c("profile_pi_w", "pi_w"))),
    pi_in = num_or_na(pick_col(r, c("profile_pi_in", "pi_in"))),
    washout = as.integer(num_or_na(pick_col(r, c("profile_washout", "washout"), 300))),
    add_bias = as.logical(pick_col(r, c("profile_add_bias", "add_bias"), TRUE)),
    seed = as.integer(num_or_na(pick_col(r, c("profile_seed", "seed"), 123))),
    readout_y_lags = as.integer(num_or_na(pick_col(r, c("profile_readout_y_lags", "readout_y_lags")))),
    reservoir_lags = as.integer(num_or_na(pick_col(r, c("profile_reservoir_lags", "reservoir_lags"), 0))),
    rhs_tau0 = num_or_na(pick_col(r, c("profile_rhs_tau0", "rhs_tau0"), 1e-4)),
    dimension_p_estimate = as.integer(num_or_na(pick_col(r, c("profile_dimension_p_estimate", "dimension_p_estimate")))),
    p_over_n_tt500 = num_or_na(pick_col(r, c("profile_p_over_n_tt500", "p_over_n_tt500"))),
    x_feature_count = as.integer(num_or_na(pick_col(r, c("profile_x_feature_count", "x_feature_count"), 5))),
    target_cells = paste(unique(target_cells), collapse = ";"),
    source_historical_runs = paste(unique(source_runs), collapse = ";"),
    source_best_max_ratio = min(num_or_na(rows$max_primary_ratio), na.rm = TRUE),
    source_best_fit_rmse_ratio = min(num_or_na(rows$fit_rmse_ratio_vs_best_vb_baseline), na.rm = TRUE),
    source_best_forecast_mae_ratio = min(num_or_na(rows$forecast_mae_ratio_vs_best_vb_baseline), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
})
profiles <- do.call(rbind, profile_rows)
core_missing <- !is.finite(profiles$D) |
  !is.finite(profiles$n_each) |
  !is.finite(profiles$m) |
  !is.finite(profiles$alpha) |
  !is.finite(profiles$rho) |
  !is.finite(profiles$pi_w) |
  !is.finite(profiles$pi_in) |
  !is.finite(profiles$readout_y_lags) |
  !is.finite(profiles$reservoir_lags) |
  !is.finite(profiles$rhs_tau0)
if (any(core_missing)) {
  bad <- paste(profiles$screening_profile_id[core_missing], collapse = ", ")
  stop(sprintf("Cannot materialize handoff; selected profile(s) have incomplete core DESN/RHS specs: %s", bad), call. = FALSE)
}
profiles <- profiles[order(profiles$p_over_n_tt500, profiles$screening_profile_id), , drop = FALSE]

assignments <- selection[, intersect(
  c(
    "family", "tau", "resolved_screening_profile_id", "priority_rank", "target_profile_rank",
    "stage", "run_tag", "run_stamp", "screening_profile_base", "profile_role",
    "forecast_mae_ratio_vs_best_vb_baseline", "forecast_pinball_ratio_vs_best_vb_baseline",
    "fit_rmse_ratio_vs_best_vb_baseline", "fit_pinball_ratio_vs_best_vb_baseline",
    "max_primary_ratio", "dominance_cell_path"
  ),
  names(selection)
), drop = FALSE]
assignments$screening_profile_id <- assignments$resolved_screening_profile_id
assignments$cell_status <- "historical_all_primary_win"
assignments$source_profile <- assignments$screening_profile_base
assignments$source_worst_ratio <- num_or_na(assignments$max_primary_ratio)
assignments$bottleneck_metric <- "none_historical_all_primary"
assignments$assignment_key <- paste(assignments$screening_profile_id, assignments$family, tau_key(assignments$tau), sep = "\r")
assignments$assignment_id <- sprintf("historical_handoff_cell_%04d", seq_len(nrow(assignments)))
assignments <- assignments[order(assignments$priority_rank, assignments$target_profile_rank), , drop = FALSE]

cell_plan <- aggregate(
  list(
    n_handoff_profiles = assignments$screening_profile_id,
    best_max_primary_ratio = assignments$source_worst_ratio,
    best_fit_rmse_ratio = num_or_na(assignments$fit_rmse_ratio_vs_best_vb_baseline),
    best_forecast_mae_ratio = num_or_na(assignments$forecast_mae_ratio_vs_best_vb_baseline)
  ),
  by = list(family = assignments$family, tau = assignments$tau),
  FUN = function(z) {
    if (is.numeric(z)) min(z, na.rm = TRUE) else length(unique(z))
  }
)
cell_plan$cell_status <- "historical_all_primary_win"
cell_plan$priority_rank <- seq_len(nrow(cell_plan))
cell_plan$target_profiles <- vapply(seq_len(nrow(cell_plan)), function(i) {
  rows <- assignments[assignments$family == cell_plan$family[[i]] & abs(assignments$tau - cell_plan$tau[[i]]) < 1e-8, , drop = FALSE]
  paste(rows$screening_profile_id, collapse = ";")
}, character(1L))
cell_plan <- cell_plan[order(cell_plan$family, cell_plan$tau), , drop = FALSE]

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    source_selection_csv = selection_csv,
    screening_wave = screening_wave,
    likelihoods = as.list(likelihoods),
    selection_policy = "top exact older broad-screen all-primary winners per family/tau",
    selected_unique_profiles = nrow(profiles),
    selected_assignments = nrow(assignments),
    selected_cells = nrow(cell_plan)
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)
diagnostic_paths <- list(
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_historical_winner_handoff_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_historical_winner_handoff_cell_assignments.csv"),
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_historical_winner_handoff_cell_plan.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_historical_winner_handoff.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_historical_winner_handoff_manifest.json")
)
write_df(profiles, diagnostic_paths$selected_profiles)
write_df(assignments, diagnostic_paths$cell_assignments)
write_df(cell_plan, diagnostic_paths$cell_plan)

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
  stage_desc = "Q-DESN 500-observation VB historical-winner handoff from exact older broad-screen all-primary designs.",
  stage = "historical_winner_handoff",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- as.list(likelihoods)
defaults$reference_contract <- defaults$reference_contract %||% list()
defaults$reference_contract$expected_selected_qdesn_roots <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles <- defaults$screening_profiles %||% list()
defaults$screening_profiles$selected_assignment_root_count <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$historical_winner_handoff <- list(
  selection_csv = selection_csv,
  exact_design_source = "older broad Q-DESN VB all-primary dominance rows joined back to committed profile CSVs",
  selected_unique_profiles = nrow(profiles),
  selected_assignments = nrow(assignments),
  selected_cells = nrow(cell_plan),
  likelihoods = as.list(likelihoods),
  promotion_policy = "fresh current-protocol VB dominance required before MCMC promotion"
)
defaults$study_contract <- defaults$study_contract %||% list()
defaults$study_contract$description <- paste(
  "Q-DESN historical-winner VB handoff for the 500-observation simulation validation.",
  "This stage reruns exact older broad-screen all-primary DESN/RHS designs under the current protocol.",
  "It is diagnostic and not article-facing until strict audit and explicit freeze."
)
defaults$smoke <- defaults$smoke %||% list()
defaults$smoke$family <- as.character(assignments$family[[1L]])
defaults$smoke$tau <- as.numeric(assignments$tau[[1L]])
defaults$smoke$screening_profile_ids <- as.list(as.character(assignments$screening_profile_id[[1L]]))
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$max_roots <- 1L
yaml::write_yaml(defaults, defaults_out)

summary_lines <- c(
  "# Q-DESN 500-Observation VB Historical-Winner Handoff Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- selection_csv: `%s`", selection_csv),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- likelihoods: `%s`", paste(likelihoods, collapse = ",")),
  sprintf("- selected_cells: `%d`", nrow(cell_plan)),
  sprintf("- selected_unique_profiles: `%d`", nrow(profiles)),
  sprintf("- selected_assignments: `%d`", nrow(assignments)),
  sprintf("- expected_qdesn_roots: `%d`", as.integer(materialized$expected_qdesn_roots)),
  "",
  "## Design Rationale",
  "",
  "The recent RHS rescue line completed cleanly but did not beat the DQLM/exDQLM VB baseline on fit RMSE. This handoff therefore returns to exact older broad-screen profiles that already passed all primary VB fit and forecast criteria, then reruns only a small current-protocol subset before any MCMC promotion.",
  "",
  "## Cell Plan",
  "",
  md_table(cell_plan, c("family", "tau", "n_handoff_profiles", "best_max_primary_ratio", "best_fit_rmse_ratio", "best_forecast_mae_ratio", "target_profiles")),
  "",
  "## Profile Registry",
  "",
  md_table(profiles, c("screening_profile_id", "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in", "rhs_tau0", "p_over_n_tt500", "target_cells")),
  "",
  "## Gates",
  "",
  "- Full VB compute is permitted only through the orchestrator with `--full --launch-approved`.",
  "- MCMC promotion is forbidden until the fresh current-protocol dominance ranking has all four primary ratios below 1 for the target cell.",
  "- Article updates are forbidden from this materialization alone.",
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
writeLines(summary_lines, diagnostic_paths$summary, useBytes = TRUE)
diagnostic_paths$summary <- normalizePath(diagnostic_paths$summary, winslash = "/", mustWork = TRUE)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  selection_csv,
  base_defaults_path,
  profiles_out,
  assignments_out,
  defaults_out,
  grid_out,
  diagnostic_paths$selected_profiles,
  diagnostic_paths$cell_assignments,
  diagnostic_paths$cell_plan,
  diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  selection_csv = selection_csv,
  base_defaults_path = base_defaults_path,
  likelihoods = as.list(likelihoods),
  workers = as.integer(workers),
  refresh_grid = isTRUE(refresh_grid),
  refresh_materialized = isTRUE(refresh_materialized),
  plan = plan$manifest,
  materialized = materialized,
  diagnostic_paths = diagnostic_paths,
  file_manifest = file_manifest,
  launch_gate = "materialization only; use orchestrator for prepare/smoke/full"
)
write_json(manifest, diagnostic_paths$manifest)
write_json(manifest, manifest_path)

cat(sprintf("diagnostics: %s\n", diagnostic_out))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", as.integer(materialized$n_profiles)))
cat(sprintf("n_assignments: %d\n", as.integer(materialized$n_assignments)))
cat(sprintf("n_grid_rows: %d\n", as.integer(materialized$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))
