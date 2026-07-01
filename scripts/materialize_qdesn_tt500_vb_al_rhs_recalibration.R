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

tau_key <- function(x) sprintf("%.8f", as.numeric(x))
slug_num <- function(x) {
  out <- format(as.numeric(x), scientific = FALSE, trim = TRUE)
  out <- sub("0+$", "", out)
  out <- sub("\\.$", "", out)
  gsub("\\.", "p", out)
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration"
article_summary_path <- resolve_path(
  get_arg("--article-summary", "/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv"),
  must_work = TRUE
)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue_profiles.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_defaults.yaml")),
  must_work = TRUE
)
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")), must_work = FALSE)
manifest_path <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)

workers <- int_arg("--workers", 20L)
max_profiles <- int_arg("--max-profiles", 24L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("al_rhs_recalibration_", format(Sys.Date(), "%Y_%m_%d"))))[1L]

article <- utils::read.csv(article_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
profiles_src <- utils::read.csv(source_profiles_path, stringsAsFactors = FALSE, check.names = FALSE)
required_article <- c("model_family", "model_variant", "qdesn_likelihood", "model_key", "inference", "family", "tau", "fit_size", "forecast_qtrue_mae_lead_weighted", "forecast_pinball_mean_lead_weighted")
missing_article <- setdiff(required_article, names(article))
if (length(missing_article)) stop(sprintf("Article summary missing column(s): %s", paste(missing_article, collapse = ", ")), call. = FALSE)

article$tau <- as.numeric(article$tau)
article$fit_size <- as.integer(article$fit_size)
targets <- unique(article[
  as.character(article$model_family) == "qdesn" &
    as.character(article$model_variant) == "rhs_ns" &
    as.character(article$qdesn_likelihood) == "al" &
    as.character(article$inference) == "vb" &
    as.integer(article$fit_size) == 500L,
  c("family", "tau"),
  drop = FALSE
])
targets <- targets[order(targets$family, targets$tau), , drop = FALSE]
if (nrow(targets) != 9L) {
  stop(sprintf("Expected 9 AL RHS VB target cells, observed %d.", nrow(targets)), call. = FALSE)
}

baseline <- article[
  as.character(article$model_family) == "exdqlm_dqlm" &
    as.character(article$inference) == "vb" &
    as.integer(article$fit_size) == 500L,
  ,
  drop = FALSE
]
al_rows <- article[
  as.character(article$model_family) == "qdesn" &
    as.character(article$model_key) == "qdesn_al_rhs_ns" &
    as.character(article$inference) == "vb" &
    as.integer(article$fit_size) == 500L,
  ,
  drop = FALSE
]
exal_rows <- article[
  as.character(article$model_family) == "qdesn" &
    as.character(article$model_key) == "qdesn_exal_rhs_ns" &
    as.character(article$inference) == "vb" &
    as.integer(article$fit_size) == 500L,
  ,
  drop = FALSE
]

cell_plan <- exdqlm:::.qdesn_validation_bind_rows(lapply(seq_len(nrow(targets)), function(i) {
  fam <- targets$family[[i]]
  tau <- targets$tau[[i]]
  key_mask <- function(df) as.character(df$family) == fam & abs(as.numeric(df$tau) - tau) < 1e-8
  al <- al_rows[key_mask(al_rows), , drop = FALSE]
  exal <- exal_rows[key_mask(exal_rows), , drop = FALSE]
  base <- baseline[key_mask(baseline), , drop = FALSE]
  best_base_mae <- min(as.numeric(base$forecast_qtrue_mae_lead_weighted), na.rm = TRUE)
  best_base_pinball <- min(as.numeric(base$forecast_pinball_mean_lead_weighted), na.rm = TRUE)
  al_mae <- as.numeric(al$forecast_qtrue_mae_lead_weighted[[1L]])
  exal_mae <- as.numeric(exal$forecast_qtrue_mae_lead_weighted[[1L]])
  data.frame(
    family = fam,
    tau = tau,
    fit_size = 500L,
    cell_status = ifelse(al_mae / exal_mae > 8, "extreme_hard", ifelse(al_mae / exal_mae > 4, "hard", "near_pass")),
    current_al_forecast_mae = al_mae,
    current_exal_forecast_mae = exal_mae,
    current_best_external_vb_forecast_mae = best_base_mae,
    current_al_pinball = as.numeric(al$forecast_pinball_mean_lead_weighted[[1L]]),
    current_exal_pinball = as.numeric(exal$forecast_pinball_mean_lead_weighted[[1L]]),
    current_best_external_vb_pinball = best_base_pinball,
    al_mae_ratio_vs_exal = al_mae / exal_mae,
    al_pinball_ratio_vs_exal = as.numeric(al$forecast_pinball_mean_lead_weighted[[1L]]) / as.numeric(exal$forecast_pinball_mean_lead_weighted[[1L]]),
    bottleneck_metric = "forecast_mae",
    stringsAsFactors = FALSE
  )
}))
cell_plan$priority <- match(cell_plan$cell_status, c("extreme_hard", "hard", "near_pass"))
cell_plan <- cell_plan[order(cell_plan$priority, -cell_plan$al_mae_ratio_vs_exal, cell_plan$family, cell_plan$tau), , drop = FALSE]
cell_plan$priority_rank <- seq_len(nrow(cell_plan))
cell_plan$target_profiles <- max_profiles

make_profile <- function(D, n_each, alpha, rho, m, readout_y_lags, reservoir_lags, pi_w, pi_in, rhs_tau0, role) {
  n_tilde_each <- if (D > 1L) n_each else 0L
  p_est <- 1L + as.integer(n_each) * as.integer(D) + as.integer(readout_y_lags) + 5L
  data.frame(
    screening_profile_id = sprintf(
      "tt500alrhs_d%d_n%d_a%s_r%s_m%d_lag%d_rl%d_pw%s_pin%s_tau%s",
      as.integer(D), as.integer(n_each), slug_num(alpha), slug_num(rho), as.integer(m),
      as.integer(readout_y_lags), as.integer(reservoir_lags), slug_num(pi_w), slug_num(pi_in),
      slug_num(rhs_tau0)
    ),
    screening_stage = "vb_al_rhs_recalibration",
    screening_wave = screening_wave,
    profile_role = role,
    enabled = TRUE,
    D = as.integer(D),
    n_each = as.integer(n_each),
    n_tilde_each = as.integer(n_tilde_each),
    m = as.integer(m),
    alpha = as.numeric(alpha),
    rho = as.numeric(rho),
    pi_w = as.numeric(pi_w),
    pi_in = as.numeric(pi_in),
    washout = 300L,
    add_bias = TRUE,
    seed = 123L,
    readout_y_lags = as.integer(readout_y_lags),
    reservoir_lags = as.integer(reservoir_lags),
    rhs_tau0 = as.numeric(rhs_tau0),
    dimension_p_estimate = as.integer(p_est),
    p_over_n_tt500 = as.numeric(p_est) / 500,
    x_feature_count = 5L,
    stringsAsFactors = FALSE
  )
}

profile_rows <- list(
  make_profile(1, 30, 0.02, 0.45, 15, 15, 0, 0.03, 0.3, 1e-4, "transfer_compact_exal_winner"),
  make_profile(1, 30, 0.03, 0.50, 15, 15, 0, 0.03, 0.3, 1e-4, "transfer_compact_exal_winner"),
  make_profile(2, 20, 0.05, 0.60, 15, 15, 0, 0.03, 0.3, 1e-4, "transfer_ridge_corrected_winner")
)
for (tau0 in c(3e-5, 1e-4, 3e-4)) {
  for (D in c(1L, 2L)) {
    for (n in c(20L, 30L, 40L)) {
      for (ar in list(c(0.01, 0.35), c(0.02, 0.45), c(0.03, 0.50), c(0.05, 0.60))) {
        profile_rows[[length(profile_rows) + 1L]] <- make_profile(
          D = D, n_each = n, alpha = ar[[1L]], rho = ar[[2L]], m = 15L,
          readout_y_lags = 15L, reservoir_lags = 0L, pi_w = 0.03, pi_in = 0.3,
          rhs_tau0 = tau0, role = "al_rhs_local_regularization_probe"
        )
      }
    }
  }
}
for (ar in list(c(0.02, 0.45), c(0.03, 0.50), c(0.05, 0.60))) {
  profile_rows[[length(profile_rows) + 1L]] <- make_profile(1, 30, ar[[1L]], ar[[2L]], 30, 30, 0, 0.03, 0.3, 1e-4, "al_rhs_memory_sensitivity")
  profile_rows[[length(profile_rows) + 1L]] <- make_profile(1, 30, ar[[1L]], ar[[2L]], 15, 15, 0, 0.05, 0.5, 1e-4, "al_rhs_input_sensitivity")
}
profiles <- unique(do.call(rbind, profile_rows))
profiles <- profiles[profiles$p_over_n_tt500 <= 0.25, , drop = FALSE]
profiles <- profiles[order(profiles$profile_role, profiles$D, profiles$n_each, profiles$alpha, profiles$rho, profiles$rhs_tau0), , drop = FALSE]
profiles <- utils::head(profiles, max_profiles)
profiles$al_rhs_profile_rank <- seq_len(nrow(profiles))
profiles$target_cells <- paste(paste(cell_plan$family, sprintf("%.2f", cell_plan$tau), sep = ":"), collapse = ";")
profiles$target_cell_statuses <- paste(unique(cell_plan$cell_status), collapse = ";")
if (!nrow(profiles)) stop("No AL RHS candidate profiles were generated.", call. = FALSE)

assignments <- exdqlm:::.qdesn_validation_bind_rows(lapply(seq_len(nrow(cell_plan)), function(i) {
  cell <- cell_plan[i, , drop = FALSE]
  exdqlm:::.qdesn_validation_bind_rows(lapply(seq_len(nrow(profiles)), function(j) {
    prof <- profiles[j, , drop = FALSE]
    data.frame(
      assignment_key = paste(prof$screening_profile_id[[1L]], cell$family[[1L]], tau_key(cell$tau[[1L]]), sep = "\r"),
      family = as.character(cell$family[[1L]]),
      tau = as.numeric(cell$tau[[1L]]),
      cell_status = as.character(cell$cell_status[[1L]]),
      priority_rank = as.integer(cell$priority_rank[[1L]]),
      target_profile_rank = as.integer(j),
      screening_profile_id = as.character(prof$screening_profile_id[[1L]]),
      source_profile = "al_rhs_recalibration_wave_a",
      source_worst_ratio = as.numeric(cell$al_mae_ratio_vs_exal[[1L]]),
      bottleneck_metric = "forecast_mae",
      assignment_id = sprintf("al_rhs_recalibration_cell_%04d", (i - 1L) * nrow(profiles) + j),
      stringsAsFactors = FALSE
    )
  }))
}))

plan <- list(
  cell_plan = cell_plan,
  candidate_ledger = profiles,
  profiles = profiles,
  assignments = assignments,
  manifest = list(
    stage = "vb_al_rhs_recalibration",
    screening_wave = screening_wave,
    target_cells = nrow(cell_plan),
    candidate_profiles = nrow(profiles),
    selected_assignments = nrow(assignments),
    design = "AL RHS Wave A: exAL/ridge transfer plus bounded AL-specific shrinkage/local reservoir perturbation."
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_al_rhs_recalibration_cell_plan.csv"),
  candidate_ledger = file.path(diag_tables, "qdesn_tt500_vb_al_rhs_recalibration_candidate_ledger.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_al_rhs_recalibration_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_al_rhs_recalibration_cell_assignments.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_al_rhs_recalibration.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_al_rhs_recalibration_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(cell_plan, diagnostic_paths$cell_plan)
exdqlm:::.qdesn_validation_write_df(profiles, diagnostic_paths$candidate_ledger)
exdqlm:::.qdesn_validation_write_df(profiles, diagnostic_paths$selected_profiles)
exdqlm:::.qdesn_validation_write_df(assignments, diagnostic_paths$cell_assignments)

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
  stage_desc = "Q-DESN TT500 VB AL RHS recalibration over all family x tau cells.",
  stage = "al_rhs_recalibration",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- "al"
defaults$study_contract$description <- paste(defaults$study_contract$description, "Likelihood is AL; exAL/RHS and ridge remain unchanged.")
yaml::write_yaml(defaults, defaults_out)

summary_lines <- c(
  "# Q-DESN TT500 VB AL RHS Recalibration Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- article_summary_path: `%s`", article_summary_path),
  sprintf("- source_profiles_path: `%s`", source_profiles_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- target_cells: `%d`", nrow(cell_plan)),
  sprintf("- candidate_profiles: `%d`", nrow(profiles)),
  sprintf("- selected_assignments: `%d`", nrow(assignments)),
  sprintf("- selected_grid_rows: `%d`", as.integer(materialized$n_grid_rows)),
  "",
  "## Cell Plan",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_plan[, c("priority_rank", "family", "tau", "cell_status", "current_al_forecast_mae", "current_exal_forecast_mae", "al_mae_ratio_vs_exal"), drop = FALSE]),
  "",
  "## Candidate Profiles",
  exdqlm:::.qdesn_validation_df_to_markdown(profiles[, c("al_rhs_profile_rank", "screening_profile_id", "profile_role", "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "pi_w", "pi_in", "rhs_tau0", "p_over_n_tt500"), drop = FALSE]),
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
exdqlm:::.qdesn_validation_write_lines(diagnostic_paths$summary, summary_lines)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  article_summary_path, source_profiles_path, base_defaults_path, profiles_out,
  assignments_out, defaults_out, grid_out, diagnostic_paths$cell_plan,
  diagnostic_paths$candidate_ledger, diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  article_summary_path = article_summary_path,
  source_profiles_path = source_profiles_path,
  base_defaults_path = base_defaults_path,
  diagnostic_output_paths = diagnostic_paths,
  plan = plan$manifest,
  materialized = materialized,
  file_manifest = file_manifest,
  screening_wave = screening_wave,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized
)
exdqlm:::.qdesn_validation_write_json(diagnostic_paths$manifest, manifest)
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)

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
