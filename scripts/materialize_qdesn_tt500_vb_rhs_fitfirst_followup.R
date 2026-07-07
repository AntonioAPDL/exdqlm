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
`%||%` <- function(a, b) if (is.null(a)) b else a

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
num_arg <- function(flag, default) {
  val <- suppressWarnings(as.numeric(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.numeric(default)
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup"
default_report_root <- file.path(
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue",
  "qdesn-vb-rhs-fitforecast-rescue-20260707-144646__git-438a156",
  "20260707-144724__git-438a156"
)
report_root <- resolve_path(get_arg("--report-root", default_report_root), must_work = TRUE)
fit_summary_path <- resolve_path(
  get_arg("--fit-summary", file.path(report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")),
  must_work = TRUE
)
baseline_path <- resolve_path(get_arg(
  "--baseline",
  "/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = TRUE)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue_defaults.yaml")),
  must_work = TRUE
)
profiles_out <- resolve_path(
  get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))),
  must_work = FALSE
)
assignments_out <- resolve_path(
  get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))),
  must_work = FALSE
)
defaults_out <- resolve_path(
  get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))),
  must_work = FALSE
)
grid_out <- resolve_path(
  get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))),
  must_work = FALSE
)
manifest_path <- resolve_path(
  get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))),
  must_work = FALSE
)
diagnostic_out <- resolve_path(
  get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")),
  must_work = FALSE
)

workers <- int_arg("--workers", 24L)
max_profiles_per_cell <- int_arg("--max-profiles-per-cell", 24L)
max_p_over_n <- num_arg("--max-p-over-n", 0.30)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("rhs_fitfirst_followup_", format(Sys.Date(), "%Y_%m_%d"))))[1L]

plan <- exdqlm:::qdesn_dynamic_fitforecast_rhs_fitfirst_followup_plan(
  fit_forecast_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  screening_wave = screening_wave,
  fit_size = 500L,
  max_p_over_n = max_p_over_n,
  max_profiles_per_cell = max_profiles_per_cell
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)
diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_followup_cell_plan.csv"),
  candidate_ledger = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_followup_candidate_ledger.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_followup_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_followup_cell_assignments.csv"),
  cell_bottlenecks = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_cell_bottlenecks.csv"),
  likelihood_bottlenecks = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_likelihood_bottlenecks.csv"),
  promotion_decision = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_promotion_decision.csv"),
  baseline_targets = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitfirst_baseline_targets.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_rhs_fitfirst_followup.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_rhs_fitfirst_followup_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(plan$cell_plan, diagnostic_paths$cell_plan)
exdqlm:::.qdesn_validation_write_df(plan$candidate_ledger, diagnostic_paths$candidate_ledger)
exdqlm:::.qdesn_validation_write_df(plan$profiles, diagnostic_paths$selected_profiles)
exdqlm:::.qdesn_validation_write_df(plan$assignments, diagnostic_paths$cell_assignments)
exdqlm:::.qdesn_validation_write_df(plan$diagnostics$cell_bottlenecks, diagnostic_paths$cell_bottlenecks)
exdqlm:::.qdesn_validation_write_df(plan$diagnostics$likelihood_bottlenecks, diagnostic_paths$likelihood_bottlenecks)
exdqlm:::.qdesn_validation_write_df(plan$diagnostics$promotion_decision, diagnostic_paths$promotion_decision)
exdqlm:::.qdesn_validation_write_df(plan$baseline_targets, diagnostic_paths$baseline_targets)

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
  stage_desc = "Q-DESN 500-observation VB RHS fit-first follow-up screen over fit-RMSE bottleneck cells.",
  stage = "rhs_fitfirst_followup",
  priors = "rhs_ns"
)

choose_smoke_assignment <- function(plan) {
  cell_order <- plan$cell_plan[order(plan$cell_plan$priority_rank), , drop = FALSE]
  if (!nrow(cell_order)) return(plan$assignments[1L, , drop = FALSE])
  first_cell <- cell_order[1L, , drop = FALSE]
  candidates <- plan$candidate_ledger[
    as.character(plan$candidate_ledger$target_family) == as.character(first_cell$family[[1L]]) &
      abs(as.numeric(plan$candidate_ledger$target_tau) - as.numeric(first_cell$tau[[1L]])) < 1e-8,
    ,
    drop = FALSE
  ]
  generated <- candidates[
    !grepl("^fitfirst_anchor_", as.character(candidates$profile_role)) &
      grepl("^tt500vb_rhsfit1_", as.character(candidates$screening_profile_id)),
    ,
    drop = FALSE
  ]
  if (nrow(generated)) {
    generated$role_priority <- ifelse(as.character(generated$profile_role) == "fitfirst_depth_probe", 0L, 1L)
    generated <- generated[order(generated$role_priority, generated$p_over_n_tt500, generated$screening_profile_id), , drop = FALSE]
    return(data.frame(
      family = as.character(generated$target_family[[1L]]),
      tau = as.numeric(generated$target_tau[[1L]]),
      screening_profile_id = as.character(generated$screening_profile_id[[1L]]),
      profile_role = as.character(generated$profile_role[[1L]]),
      stringsAsFactors = FALSE
    ))
  }
  first_assignment <- plan$assignments[order(plan$assignments$priority_rank, plan$assignments$target_profile_rank), , drop = FALSE][1L, , drop = FALSE]
  data.frame(
    family = as.character(first_assignment$family[[1L]]),
    tau = as.numeric(first_assignment$tau[[1L]]),
    screening_profile_id = as.character(first_assignment$screening_profile_id[[1L]]),
    profile_role = NA_character_,
    stringsAsFactors = FALSE
  )
}
smoke_assignment <- choose_smoke_assignment(plan)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- c("al", "exal")
defaults$reference_contract$expected_selected_qdesn_roots <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$selected_assignment_root_count <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$design <- sprintf(
  "Q-DESN RHS VB fit-first follow-up. Profiles: %d; selected roots: %d; likelihoods per root: AL and exAL.",
  nrow(plan$profiles),
  as.integer(materialized$expected_qdesn_roots)
)
defaults$study_contract$description <- paste(
  "Q-DESN RHS VB fit-first follow-up for the 500-observation simulation validation.",
  "This stage uses the completed fit+forecast rescue as diagnostic evidence,",
  "prioritizes fit RMSE and fit check recovery before forecast gains,",
  "and remains screening-only until explicit freeze/signoff."
)
defaults$screening_profiles$fitfirst_followup_design <- list(
  source_report_root = report_root,
  source_fit_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  max_profiles_per_cell = as.integer(max_profiles_per_cell),
  max_p_over_n = as.numeric(max_p_over_n),
  tau0_policy = "1e-4 anchor plus 3e-4, 1e-3, and 3e-3 fit-first probes; exclude failed 3e-5 surface",
  launch_policy = "do not run full compute without explicit human launch approval",
  promotion_policy = "do not promote unless all target cells clear the fit-first and forecast primary metrics against current best DQLM/exDQLM VB baselines"
)
defaults$smoke <- defaults$smoke %||% list()
defaults$smoke$family <- as.character(smoke_assignment$family[[1L]])
defaults$smoke$tau <- as.numeric(smoke_assignment$tau[[1L]])
defaults$smoke$screening_profile_ids <- as.list(as.character(smoke_assignment$screening_profile_id[[1L]]))
defaults$smoke$fitfirst_followup_smoke_profile_role <- as.character(smoke_assignment$profile_role[[1L]] %||% NA_character_)
yaml::write_yaml(defaults, defaults_out)

cell_display <- plan$cell_plan[, intersect(
  c(
    "priority_rank", "family", "tau", "cell_status", "target_profiles",
    "min_fit_rmse_ratio", "min_forecast_mae_ratio",
    "current_best_worst_ratio", "current_best_fit_rmse_ratio",
    "current_best_forecast_mae_ratio", "best_fit_rmse_profile"
  ),
  names(plan$cell_plan)
), drop = FALSE]
profile_display <- plan$profiles[, intersect(
  c(
    "fitfirst_followup_profile_rank", "screening_profile_id", "profile_role",
    "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "pi_w", "pi_in",
    "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "target_cells",
    "target_source_metrics"
  ),
  names(plan$profiles)
), drop = FALSE]
summary_lines <- c(
  "# Q-DESN 500-Observation VB RHS Fit-First Follow-Up Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- source_report_root: `%s`", report_root),
  sprintf("- fit_summary_path: `%s`", fit_summary_path),
  sprintf("- baseline_path: `%s`", baseline_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- max_profiles_per_cell: `%d`", as.integer(max_profiles_per_cell)),
  sprintf("- max_p_over_n: `%s`", format(max_p_over_n, trim = TRUE)),
  sprintf("- target_cells: `%d`", nrow(plan$cell_plan)),
  sprintf("- unique_profiles: `%d`", nrow(plan$profiles)),
  sprintf("- selected_roots: `%d`", as.integer(materialized$expected_qdesn_roots)),
  sprintf("- expected_vb_fits_if_AL_and_exAL: `%d`", as.integer(materialized$expected_qdesn_roots) * 2L),
  "",
  "## Diagnosis",
  "",
  "The completed RHS VB fit+forecast rescue remains a diagnostic screen, not a promotion candidate. It improved forecast MAE in several cells but did not clear the fit-RMSE baseline in every family/quantile cell. This follow-up stage shifts the search objective toward compact fit recovery while keeping forecast metrics as guardrails.",
  "",
  "## Promotion Decision From Source Run",
  exdqlm:::.qdesn_validation_df_to_markdown(plan$diagnostics$promotion_decision),
  "",
  "## Cell Plan",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_display),
  "",
  "## Selected Profile Registry",
  exdqlm:::.qdesn_validation_df_to_markdown(profile_display),
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
exdqlm:::.qdesn_validation_write_lines(diagnostic_paths$summary, summary_lines)

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = "qdesn_vb_rhs_fitfirst_followup",
  stage_file = stage_file,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  source_report_root = report_root,
  fit_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  base_defaults_path = base_defaults_path,
  workers = as.integer(workers),
  max_profiles_per_cell = as.integer(max_profiles_per_cell),
  max_p_over_n = as.numeric(max_p_over_n),
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  plan = plan$manifest,
  materialized = materialized,
  smoke_assignment = smoke_assignment,
  diagnostic_paths = diagnostic_paths,
  output_paths = list(
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    manifest = manifest_path
  ),
  file_manifest = qdesn_validation_file_manifest(c(
    fit_summary_path,
    baseline_path,
    base_defaults_path,
    profiles_out,
    assignments_out,
    defaults_out,
    grid_out
  ))
)
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)
exdqlm:::.qdesn_validation_write_json(diagnostic_paths$manifest, manifest)

cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", as.integer(materialized$n_profiles)))
cat(sprintf("n_assignments: %d\n", as.integer(materialized$n_assignments)))
cat(sprintf("n_grid_rows: %d\n", as.integer(materialized$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))
cat("launch_policy: gated; use orchestrator --full --launch-approved only after explicit approval\n")
