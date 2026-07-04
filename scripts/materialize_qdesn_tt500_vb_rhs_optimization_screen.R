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
slug_num <- function(x) {
  out <- format(as.numeric(x), scientific = FALSE, trim = TRUE)
  out <- sub("0+$", "", out)
  out <- sub("\\.$", "", out)
  gsub("\\.", "p", out)
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization"
article_summary_path <- resolve_path(
  get_arg("--article-summary", "/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv"),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_defaults.yaml")),
  must_work = TRUE
)
gap_audit_path <- resolve_path(
  get_arg("--gap-audit", file.path("validation", "fitforecast_v2", "docs", "validation_optimization_gap_audit_20260704.csv")),
  must_work = TRUE
)
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
manifest_path <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)
diagnostic_out <- resolve_path(
  get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")),
  must_work = FALSE
)

workers <- int_arg("--workers", 24L)
max_profiles <- int_arg("--max-profiles", 48L)
max_p_over_n <- num_arg("--max-p-over-n", 0.30)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("rhs_optimization_", format(Sys.Date(), "%Y_%m_%d"))))[1L]

article <- utils::read.csv(article_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
gap <- utils::read.csv(gap_audit_path, stringsAsFactors = FALSE, check.names = FALSE)
required_article <- c(
  "model_family", "model_key", "qdesn_likelihood", "inference", "family", "tau", "fit_size",
  "fit_qtrue_rmse", "fit_pinball_mean",
  "forecast_qtrue_mae_lead_weighted", "forecast_pinball_mean_lead_weighted"
)
missing_article <- setdiff(required_article, names(article))
if (length(missing_article)) {
  stop(sprintf("Article summary missing column(s): %s", paste(missing_article, collapse = ", ")), call. = FALSE)
}

article$tau <- as.numeric(article$tau)
article$fit_size <- as.integer(article$fit_size)
target_cells <- unique(article[
  as.character(article$model_family) == "qdesn" &
    as.character(article$model_key) %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns") &
    as.character(article$inference) == "vb" &
    as.integer(article$fit_size) == 500L,
  c("family", "tau"),
  drop = FALSE
])
target_cells <- target_cells[order(target_cells$family, target_cells$tau), , drop = FALSE]
if (nrow(target_cells) != 9L) {
  stop(sprintf("Expected 9 Q-DESN RHS VB family/tau cells, observed %d.", nrow(target_cells)), call. = FALSE)
}

cell_plan <- lapply(seq_len(nrow(target_cells)), function(i) {
  fam <- target_cells$family[[i]]
  tau <- target_cells$tau[[i]]
  g <- gap[
    as.character(gap$comparison_group) == "qdesn_rhs_vs_best_exdqlm_dqlm" &
      as.character(gap$inference) == "vb" &
      as.character(gap$family) == fam &
      abs(as.numeric(gap$tau) - tau) < 1e-8,
    ,
    drop = FALSE
  ]
  a <- article[
    as.character(article$family) == fam &
      abs(as.numeric(article$tau) - tau) < 1e-8 &
      as.character(article$inference) == "vb" &
      as.character(article$model_key) %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
    ,
    drop = FALSE
  ]
  worst_ratio <- suppressWarnings(max(c(g$fit_ratio, g$forecast_mae_ratio, g$forecast_check_ratio), na.rm = TRUE))
  if (!is.finite(worst_ratio)) worst_ratio <- NA_real_
  priority <- if (!is.finite(worst_ratio)) {
    "unknown"
  } else if (worst_ratio >= 1.50) {
    "high"
  } else if (worst_ratio >= 1.10) {
    "watch"
  } else {
    "ok"
  }
  data.frame(
    family = fam,
    tau = tau,
    fit_size = 500L,
    cell_status = priority,
    worst_qdesn_rhs_ratio_vs_best_external = worst_ratio,
    current_al_fit_rmse = a$fit_qtrue_rmse[match("qdesn_al_rhs_ns", a$model_key)],
    current_exal_fit_rmse = a$fit_qtrue_rmse[match("qdesn_exal_rhs_ns", a$model_key)],
    current_al_forecast_mae = a$forecast_qtrue_mae_lead_weighted[match("qdesn_al_rhs_ns", a$model_key)],
    current_exal_forecast_mae = a$forecast_qtrue_mae_lead_weighted[match("qdesn_exal_rhs_ns", a$model_key)],
    current_al_check_loss = a$forecast_pinball_mean_lead_weighted[match("qdesn_al_rhs_ns", a$model_key)],
    current_exal_check_loss = a$forecast_pinball_mean_lead_weighted[match("qdesn_exal_rhs_ns", a$model_key)],
    bottleneck_metric = paste(unique(as.character(g$priority)), collapse = ";"),
    stringsAsFactors = FALSE
  )
})
cell_plan <- exdqlm:::.qdesn_validation_bind_rows(cell_plan)
prio_order <- c(high = 1L, watch = 2L, ok = 3L, unknown = 4L)
cell_plan$priority <- unname(prio_order[as.character(cell_plan$cell_status)])
cell_plan <- cell_plan[order(cell_plan$priority, -cell_plan$worst_qdesn_rhs_ratio_vs_best_external, cell_plan$family, cell_plan$tau), , drop = FALSE]
cell_plan$priority_rank <- seq_len(nrow(cell_plan))

make_profile <- function(D, n_each, alpha, rho, m, readout_y_lags, reservoir_lags, pi_w, pi_in,
                         rhs_tau0, seed = 123L, role = "rhs_local") {
  n_tilde_each <- if (D > 1L) n_each else 0L
  p_est <- 1L + as.integer(n_each) * as.integer(D) + as.integer(readout_y_lags) + 5L
  data.frame(
    screening_profile_id = sprintf(
      "tt500rhsopt_d%d_n%d_a%s_r%s_m%d_lag%d_rl%d_pw%s_pin%s_tau%s_s%d",
      as.integer(D), as.integer(n_each), slug_num(alpha), slug_num(rho),
      as.integer(m), as.integer(readout_y_lags), as.integer(reservoir_lags),
      slug_num(pi_w), slug_num(pi_in), slug_num(rhs_tau0), as.integer(seed)
    ),
    screening_stage = "vb_rhs_optimization",
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
    seed = as.integer(seed),
    readout_y_lags = as.integer(readout_y_lags),
    reservoir_lags = as.integer(reservoir_lags),
    rhs_tau0 = as.numeric(rhs_tau0),
    dimension_p_estimate = as.integer(p_est),
    p_over_n_tt500 = as.numeric(p_est) / 500,
    x_feature_count = 5L,
    stringsAsFactors = FALSE
  )
}

profiles <- list(
  make_profile(1, 30, 0.02, 0.45, 15, 15, 0, 0.03, 0.30, 1e-4, role = "current_exal_transfer"),
  make_profile(1, 30, 0.03, 0.50, 15, 15, 0, 0.03, 0.30, 1e-4, role = "current_exal_transfer"),
  make_profile(2, 20, 0.05, 0.60, 15, 15, 0, 0.03, 0.30, 1e-4, role = "gausmix005_refinement_transfer"),
  make_profile(1, 20, 0.01, 0.35, 15, 15, 0, 0.03, 0.30, 1e-4, role = "current_al_transfer"),
  make_profile(1, 30, 0.02, 0.45, 15, 15, 0, 0.05, 0.50, 1e-4, role = "current_al_transfer"),
  make_profile(1, 30, 0.03, 0.50, 15, 15, 0, 0.05, 0.50, 1e-4, role = "current_al_transfer")
)
arch_grid <- expand.grid(
  D = c(1L, 2L),
  n_each = c(20L, 30L, 40L, 50L),
  ar_id = seq_len(6L),
  rhs_tau0 = c(1e-4, 3e-4, 1e-3),
  stringsAsFactors = FALSE
)
ar_pairs <- data.frame(
  alpha = c(0.005, 0.01, 0.02, 0.03, 0.05, 0.08),
  rho = c(0.25, 0.35, 0.45, 0.50, 0.60, 0.70)
)
for (i in seq_len(nrow(arch_grid))) {
  ar <- ar_pairs[arch_grid$ar_id[[i]], , drop = FALSE]
  profiles[[length(profiles) + 1L]] <- make_profile(
    D = arch_grid$D[[i]],
    n_each = arch_grid$n_each[[i]],
    alpha = ar$alpha[[1L]],
    rho = ar$rho[[1L]],
    m = 15L,
    readout_y_lags = 15L,
    reservoir_lags = 0L,
    pi_w = 0.03,
    pi_in = 0.30,
    rhs_tau0 = arch_grid$rhs_tau0[[i]],
    role = "bounded_local_grid"
  )
}
for (mem in c(10L, 20L, 30L)) {
  profiles[[length(profiles) + 1L]] <- make_profile(1, 30, 0.02, 0.45, mem, mem, 0, 0.03, 0.30, 1e-4, role = "memory_probe")
  profiles[[length(profiles) + 1L]] <- make_profile(1, 30, 0.03, 0.50, mem, mem, 0, 0.03, 0.30, 1e-4, role = "memory_probe")
}
for (seed in c(777L, 2027L)) {
  profiles[[length(profiles) + 1L]] <- make_profile(1, 30, 0.02, 0.45, 15, 15, 0, 0.03, 0.30, 1e-4, seed = seed, role = "seed_stability_probe")
  profiles[[length(profiles) + 1L]] <- make_profile(2, 20, 0.05, 0.60, 15, 15, 0, 0.03, 0.30, 1e-4, seed = seed, role = "seed_stability_probe")
}
profiles <- do.call(rbind, profiles)
profiles <- profiles[profiles$p_over_n_tt500 <= max_p_over_n, , drop = FALSE]
role_rank <- c(
  current_exal_transfer = 1L,
  current_al_transfer = 2L,
  gausmix005_refinement_transfer = 3L,
  bounded_local_grid = 4L,
  memory_probe = 5L,
  seed_stability_probe = 6L
)
profiles$role_rank <- unname(role_rank[as.character(profiles$profile_role)])
profiles$role_rank[is.na(profiles$role_rank)] <- 99L
profiles <- profiles[order(profiles$role_rank, profiles$p_over_n_tt500, profiles$D, profiles$n_each, profiles$rhs_tau0, profiles$alpha, profiles$rho), , drop = FALSE]
profiles <- profiles[!duplicated(as.character(profiles$screening_profile_id)), , drop = FALSE]
profiles <- utils::head(profiles, max_profiles)
profiles$rhs_optimization_profile_rank <- seq_len(nrow(profiles))
profiles$target_cells <- paste(paste(cell_plan$family, sprintf("%.2f", cell_plan$tau), sep = ":"), collapse = ";")
profiles$target_cell_statuses <- paste(unique(cell_plan$cell_status), collapse = ";")
profiles$role_rank <- NULL

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
      source_profile = "rhs_optimization_20260704",
      source_worst_ratio = as.numeric(cell$worst_qdesn_rhs_ratio_vs_best_external[[1L]]),
      bottleneck_metric = as.character(cell$bottleneck_metric[[1L]]),
      assignment_id = sprintf("rhs_optimization_cell_%04d", (i - 1L) * nrow(profiles) + j),
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
    stage = "vb_rhs_optimization",
    screening_wave = screening_wave,
    target_cells = nrow(cell_plan),
    candidate_profiles = nrow(profiles),
    selected_assignments = nrow(assignments),
    likelihoods_per_root = c("al", "exal"),
    design = "Q-DESN RHS VB screen: AL and exAL run on the same compact/cell-specific profile roots."
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)
diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_rhs_optimization_cell_plan.csv"),
  candidate_ledger = file.path(diag_tables, "qdesn_tt500_vb_rhs_optimization_candidate_ledger.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_rhs_optimization_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_rhs_optimization_cell_assignments.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_rhs_optimization.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_rhs_optimization_manifest.json")
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
  stage_desc = "Q-DESN TT500 VB RHS optimization over all family x tau cells.",
  stage = "rhs_optimization",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- c("al", "exal")
defaults$reference_contract$expected_selected_qdesn_roots <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$selected_assignment_root_count <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$design <- sprintf(
  "Q-DESN RHS VB optimization. Profiles: %d; selected roots: %d; likelihoods per root: AL and exAL.",
  nrow(profiles),
  as.integer(materialized$expected_qdesn_roots)
)
defaults$study_contract$description <- paste(
  "Q-DESN RHS VB optimization over all 500-observation family/quantile cells.",
  "Both AL and exAL likelihoods are evaluated on the same roots; this lane is screening-only until explicit promotion."
)
yaml::write_yaml(defaults, defaults_out)

summary_lines <- c(
  "# Q-DESN TT500 VB RHS Optimization Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- article_summary_path: `%s`", article_summary_path),
  sprintf("- gap_audit_path: `%s`", gap_audit_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- max_profiles: `%d`", as.integer(max_profiles)),
  sprintf("- max_p_over_n: `%s`", as.character(max_p_over_n)),
  sprintf("- target_cells: `%d`", nrow(cell_plan)),
  sprintf("- candidate_profiles: `%d`", nrow(profiles)),
  sprintf("- selected_roots: `%d`", as.integer(materialized$expected_qdesn_roots)),
  sprintf("- likelihoods_per_root: `%s`", "al, exal"),
  "",
  "## Cell Plan",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_plan[, c(
    "priority_rank", "family", "tau", "cell_status",
    "worst_qdesn_rhs_ratio_vs_best_external",
    "current_al_forecast_mae", "current_exal_forecast_mae"
  ), drop = FALSE]),
  "",
  "## Candidate Profiles",
  exdqlm:::.qdesn_validation_df_to_markdown(profiles[, c(
    "rhs_optimization_profile_rank", "screening_profile_id", "profile_role",
    "D", "n_each", "alpha", "rho", "m", "readout_y_lags",
    "pi_w", "pi_in", "rhs_tau0", "seed", "p_over_n_tt500"
  ), drop = FALSE]),
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
exdqlm:::.qdesn_validation_write_lines(diagnostic_paths$summary, summary_lines)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  article_summary_path, gap_audit_path, base_defaults_path, profiles_out,
  assignments_out, defaults_out, grid_out, diagnostic_paths$cell_plan,
  diagnostic_paths$candidate_ledger, diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  article_summary_path = article_summary_path,
  gap_audit_path = gap_audit_path,
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
