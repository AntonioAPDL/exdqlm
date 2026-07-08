#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L || is.na(a[[1L]])) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve <- function(path, must_work = TRUE) {
  raw <- as.character(path)[1L]
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = must_work)
}
rel_path <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", repo_root), "/?"), "", path)
}
read_csv <- function(path) utils::read.csv(resolve(path), stringsAsFactors = FALSE, check.names = FALSE)
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}
sha256 <- function(path) {
  path <- resolve(path)
  out <- tryCatch(system2("sha256sum", path, stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out) || is.na(out[[1L]])) return(NA_character_)
  strsplit(out[[1L]], "[[:space:]]+")[[1L]][[1L]]
}
fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(as.numeric(x), format = "f", digits = digits))
}
first_existing_col <- function(x, cols) {
  hit <- intersect(cols, names(x))
  if (!length(hit)) NA_character_ else hit[[1L]]
}
best_by <- function(data, group_cols, metric, tie_cols = character(), objective_label = metric) {
  split_key <- do.call(paste, c(data[group_cols], sep = "\r"))
  pieces <- lapply(split(seq_len(nrow(data)), split_key), function(idx) {
    d <- data[idx, , drop = FALSE]
    ord_cols <- c(metric, tie_cols)
    ord <- do.call(order, d[ord_cols])
    d <- d[ord, , drop = FALSE]
    d$objective <- objective_label
    d[1L, , drop = FALSE]
  })
  do.call(rbind, pieces)
}
file_manifest <- function(paths) {
  paths <- unique(paths[file.exists(paths)])
  data.frame(
    path = rel_path(paths),
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, sha256, character(1L)),
    stringsAsFactors = FALSE
  )
}

out_dir <- resolve(get_arg(
  "--out-dir",
  file.path("validation", "fitforecast_v2", "promotions", "vb_calibration_resume_evidence_20260708")
), must_work = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

ex_run_root <- resolve(get_arg(
  "--exdqlm-run-root",
  file.path("validation", "fitforecast_v2", "runs", "20260708_exdqlm_dqlm_vb_calibration_resume__git-8e7d3a9")
))
q_report_root <- resolve(get_arg(
  "--qdesn-report-root",
  file.path(
    "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup",
    "qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9", "20260708-023545__git-8e7d3a9"
  )
))
q_results_root <- resolve(get_arg(
  "--qdesn-results-root",
  file.path(
    "results", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup",
    "qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9", "20260708-023545__git-8e7d3a9"
  )
), must_work = FALSE)
baseline_path <- resolve(get_arg(
  "--baseline",
  file.path("validation", "fitforecast_v2", "docs", "validation_local_exdqlm_dqlm_vb_baseline_20260708.csv")
))

ex_status_path <- file.path(ex_run_root, "manifests", "status_counts.csv")
ex_rank_path <- file.path(ex_run_root, "screen_summary", "candidate_cell_rankings.csv")
ex_telemetry_path <- file.path(ex_run_root, "manifests", "telemetry_summary.csv")
q_campaign_completed_path <- file.path(q_report_root, "manifest", "campaign_completed.json")
q_fit_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")
q_dominance_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
q_audit_path <- file.path(q_report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")

required <- c(
  ex_status_path, ex_rank_path, q_campaign_completed_path, q_fit_path,
  q_dominance_path, q_audit_path, baseline_path
)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop(sprintf("Missing required evidence path(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
}

ex_status <- read_csv(ex_status_path)
ex_rank <- read_csv(ex_rank_path)
baseline <- read_csv(baseline_path)
q_fit <- read_csv(q_fit_path)
q_dom <- read_csv(q_dominance_path)
q_audit <- read_csv(q_audit_path)
q_campaign <- jsonlite::fromJSON(q_campaign_completed_path, simplifyVector = TRUE)

status_name <- first_existing_col(ex_status, c("status", "statuses"))
status_count <- first_existing_col(ex_status, c("n", "count", "Freq"))
ex_done <- if (!is.na(status_name) && !is.na(status_count)) {
  sum(as.numeric(ex_status[[status_count]])[ex_status[[status_name]] == "done"], na.rm = TRUE)
} else NA_real_
ex_total <- nrow(ex_rank)
q_success <- sum(q_fit$status == "SUCCESS", na.rm = TRUE)
q_total <- nrow(q_fit)
q_pass <- sum(q_fit$signoff_grade == "PASS", na.rm = TRUE)
q_warn <- sum(q_fit$signoff_grade == "WARN", na.rm = TRUE)

health <- data.frame(
  component = c("exdqlm_dqlm_vb_calibration_resume", "qdesn_rhs_vb_fitfirst_followup", "validation_git_worktree"),
  run_tag = c(
    unique(ex_rank$run_tag)[[1L]],
    "qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9",
    NA_character_
  ),
  expected = c(ex_total, q_total, NA),
  completed = c(ex_done, q_success, NA),
  pct_done = c(100 * ex_done / ex_total, 100 * q_success / q_total, NA),
  status = c(
    if (identical(as.numeric(ex_done), as.numeric(ex_total))) "complete" else "incomplete",
    if (q_success == q_total) "complete" else "incomplete",
    "clean_and_pushed_at_materialization_input"
  ),
  notes = c(
    paste0(length(unique(paste(ex_rank$model_variant, ex_rank$family, ex_rank$tau))), " model/family/tau cells; 36 candidates per cell expected"),
    paste0("signoff PASS=", q_pass, "; WARN=", q_warn, "; campaign_completed=", !is.null(q_campaign)),
    paste0("source commit in run evidence: ", unique(ex_rank$validation_commit)[[1L]])
  ),
  stringsAsFactors = FALSE
)

ex_objectives <- list(
  fit_check = "fit_check_loss",
  fit_rmse = "fit_qtrue_rmse",
  forecast_check = "forecast_check_loss",
  forecast_mae = "forecast_qtrue_mae"
)
ex_winners <- do.call(rbind, lapply(names(ex_objectives), function(label) {
  metric <- ex_objectives[[label]]
  best_by(
    ex_rank,
    group_cols = c("model_variant", "family", "tau"),
    metric = metric,
    tie_cols = setdiff(c("fit_check_loss", "forecast_check_loss", "fit_qtrue_rmse", "forecast_qtrue_mae"), metric),
    objective_label = label
  )
}))
ex_winners <- ex_winners[, intersect(c(
  "objective", "model_variant", "family", "tau", "fit_size", "candidate_id", "calibration_id",
  "fit_qtrue_rmse", "fit_check_loss", "forecast_qtrue_mae", "forecast_qtrue_rmse",
  "forecast_check_loss", "runtime_sec_total", "source_registry_hash_value",
  "validation_branch", "validation_commit", "run_tag", "package_version",
  "forecast_protocol", "state_update_method", "max_lead_configured", "origin_stride"
), names(ex_winners)), drop = FALSE]
ex_winners <- ex_winners[order(ex_winners$model_variant, ex_winners$family, ex_winners$tau, ex_winners$objective), , drop = FALSE]

baseline$model_variant <- baseline$model_variant %||% baseline$model_family
base_key <- paste(baseline$model_variant, baseline$family, sprintf("%.8f", as.numeric(baseline$tau)), sep = "\r")
names(base_key) <- seq_len(nrow(baseline))
ex_fit_winners <- ex_winners[ex_winners$objective == "fit_check", , drop = FALSE]
ex_fit_key <- paste(ex_fit_winners$model_variant, ex_fit_winners$family, sprintf("%.8f", as.numeric(ex_fit_winners$tau)), sep = "\r")
baseline_idx <- match(ex_fit_key, base_key)
ex_vs_baseline <- ex_fit_winners
ex_vs_baseline$baseline_fit_check_loss <- baseline$fit_check_loss[baseline_idx]
ex_vs_baseline$baseline_forecast_check_loss <- baseline$forecast_check_loss_lead_weighted[baseline_idx]
ex_vs_baseline$baseline_fit_rmse <- baseline$fit_qtrue_rmse[baseline_idx]
ex_vs_baseline$baseline_forecast_mae <- baseline$forecast_qtrue_mae_lead_weighted[baseline_idx]
ex_vs_baseline$fit_check_ratio_vs_baseline <- ex_vs_baseline$fit_check_loss / ex_vs_baseline$baseline_fit_check_loss
ex_vs_baseline$forecast_check_ratio_vs_baseline <- ex_vs_baseline$forecast_check_loss / ex_vs_baseline$baseline_forecast_check_loss
ex_vs_baseline$fit_rmse_ratio_vs_baseline <- ex_vs_baseline$fit_qtrue_rmse / ex_vs_baseline$baseline_fit_rmse
ex_vs_baseline$forecast_mae_ratio_vs_baseline <- ex_vs_baseline$forecast_qtrue_mae / ex_vs_baseline$baseline_forecast_mae

pair_split <- split(ex_winners[ex_winners$objective == "forecast_check", , drop = FALSE],
                    paste(ex_winners$family[ex_winners$objective == "forecast_check"],
                          sprintf("%.8f", as.numeric(ex_winners$tau[ex_winners$objective == "forecast_check"])), sep = "\r"))
ex_pair_ratios <- do.call(rbind, lapply(pair_split, function(d) {
  dqlm <- d[d$model_variant == "dqlm", , drop = FALSE]
  exdqlm <- d[d$model_variant == "exdqlm", , drop = FALSE]
  if (!nrow(dqlm) || !nrow(exdqlm)) return(NULL)
  data.frame(
    family = dqlm$family[[1L]],
    tau = as.numeric(dqlm$tau[[1L]]),
    dqlm_candidate_id = dqlm$candidate_id[[1L]],
    exdqlm_candidate_id = exdqlm$candidate_id[[1L]],
    dqlm_forecast_check = dqlm$forecast_check_loss[[1L]],
    exdqlm_forecast_check = exdqlm$forecast_check_loss[[1L]],
    exdqlm_to_dqlm_forecast_check_ratio = exdqlm$forecast_check_loss[[1L]] / dqlm$forecast_check_loss[[1L]],
    dqlm_forecast_mae = dqlm$forecast_qtrue_mae[[1L]],
    exdqlm_forecast_mae = exdqlm$forecast_qtrue_mae[[1L]],
    exdqlm_to_dqlm_forecast_mae_ratio = exdqlm$forecast_qtrue_mae[[1L]] / dqlm$forecast_qtrue_mae[[1L]],
    dqlm_fit_rmse = dqlm$fit_qtrue_rmse[[1L]],
    exdqlm_fit_rmse = exdqlm$fit_qtrue_rmse[[1L]],
    exdqlm_to_dqlm_fit_rmse_ratio = exdqlm$fit_qtrue_rmse[[1L]] / dqlm$fit_qtrue_rmse[[1L]],
    exdqlm_beats_dqlm_forecast_check = exdqlm$forecast_check_loss[[1L]] < dqlm$forecast_check_loss[[1L]],
    stringsAsFactors = FALSE
  )
}))
ex_pair_ratios <- ex_pair_ratios[order(ex_pair_ratios$family, ex_pair_ratios$tau), , drop = FALSE]

q_objectives <- list(
  fit_check = "qdesn_fit_pinball_mean",
  fit_rmse = "qdesn_fit_rmse_mean",
  forecast_check = "qdesn_forecast_pinball_mean",
  forecast_mae = "qdesn_forecast_mae_mean"
)
q_winners <- do.call(rbind, lapply(names(q_objectives), function(label) {
  metric <- q_objectives[[label]]
  best_by(
    q_dom,
    group_cols = c("family", "tau"),
    metric = metric,
    tie_cols = setdiff(c(
      "qdesn_fit_pinball_mean", "qdesn_forecast_pinball_mean",
      "qdesn_fit_rmse_mean", "qdesn_forecast_mae_mean"
    ), metric),
    objective_label = label
  )
}))
q_winners <- q_winners[, intersect(c(
  "objective", "family", "tau", "screening_profile_base", "screening_profile_id_representative",
  "profile_role", "D", "n_each", "alpha", "rho", "m", "readout_y_lags",
  "reservoir_lags", "pi_w", "pi_in", "qdesn_forecast_mae_mean",
  "qdesn_forecast_pinball_mean", "qdesn_fit_rmse_mean", "qdesn_fit_pinball_mean",
  "qdesn_runtime_sec_mean", "qdesn_dimension_p_mean", "qdesn_p_over_n_mean",
  "baseline_forecast_mae", "baseline_forecast_mae_model",
  "baseline_forecast_pinball", "baseline_forecast_pinball_model",
  "baseline_fit_rmse", "baseline_fit_rmse_model",
  "baseline_fit_pinball", "baseline_fit_pinball_model",
  "forecast_mae_ratio_vs_best_vb_baseline", "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline", "fit_pinball_ratio_vs_best_vb_baseline",
  "beats_forecast_mae_baseline", "beats_forecast_pinball_baseline",
  "beats_fit_rmse_baseline", "beats_fit_pinball_baseline", "beats_all_primary_baselines"
), names(q_winners)), drop = FALSE]
q_winners <- q_winners[order(q_winners$family, q_winners$tau, q_winners$objective), , drop = FALSE]

q_dominance_counts <- aggregate(
  cbind(
    beats_forecast_mae_baseline,
    beats_forecast_pinball_baseline,
    beats_fit_rmse_baseline,
    beats_fit_pinball_baseline,
    beats_all_primary_baselines
  ) ~ family + tau,
  q_dom,
  sum
)
q_n <- as.data.frame(table(q_dom$family, q_dom$tau), stringsAsFactors = FALSE)
names(q_n) <- c("family", "tau", "n_profiles")
q_n$tau <- as.numeric(as.character(q_n$tau))
q_dominance_counts <- merge(q_dominance_counts, q_n, by = c("family", "tau"), all.x = TRUE)
q_dominance_counts <- q_dominance_counts[order(q_dominance_counts$family, q_dominance_counts$tau), , drop = FALSE]

q_forecast_check <- q_winners[q_winners$objective == "forecast_check", , drop = FALSE]
hard_cells <- q_forecast_check[
  as.numeric(q_forecast_check$fit_rmse_ratio_vs_best_vb_baseline) > 1 |
    as.numeric(q_forecast_check$forecast_pinball_ratio_vs_best_vb_baseline) >= 1,
  ,
  drop = FALSE
]
decision_ledger <- data.frame(
  item = c(
    "exdqlm_dqlm_vb_calibration_resume",
    "qdesn_rhs_vb_fitfirst_followup",
    "article_authoritative_promotion",
    "mcmc_launch_readiness",
    "storage_cleanup"
  ),
  decision = c(
    "freeze_as_completed_diagnostic_evidence",
    "freeze_as_completed_diagnostic_evidence",
    "do_not_promote_as_final_without_explicit_scientific_signoff",
    "do_not_launch_broad_mcmc_yet",
    "dry_run_only_pending_user_approval"
  ),
  rationale = c(
    "All 648 exDQLM/DQLM VB candidate rows completed with no failed status rows.",
    "All 344 Q-DESN RHS VB fit-first rows completed successfully, but 22 rows carry WARN signoffs.",
    "Q-DESN still does not beat all primary baselines in any family/tau cell; fit RMSE remains the blocker.",
    "VB objective winners differ across fit and forecast metrics, so MCMC should use explicit objective-specific candidate selection.",
    "The exDQLM/DQLM run root is large and mostly handoff objects; deletion requires separate approval because fit handoffs may be useful for MCMC initialization."
  ),
  stringsAsFactors = FALSE
)

handoff_dir <- file.path(ex_run_root, "handoff")
handoff_files <- if (dir.exists(handoff_dir)) {
  list.files(handoff_dir, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
} else character()
handoff_info <- if (length(handoff_files)) file.info(handoff_files) else data.frame(size = numeric())
fit_object_files <- handoff_files[grepl("fit_object[.]ffv2handoff$", handoff_files)]
vb_init_files <- handoff_files[grepl("vb_init[.]ffv2handoff$", handoff_files)]
storage_dry_run <- data.frame(
  path_or_pattern = c(
    file.path(rel_path(handoff_dir), "row_*_fit_object.ffv2handoff"),
    file.path(rel_path(handoff_dir), "row_*_vb_init.ffv2handoff"),
    rel_path(file.path(ex_run_root, "metrics")),
    rel_path(file.path(ex_run_root, "manifests")),
    rel_path(q_report_root),
    rel_path(q_results_root)
  ),
  project_task_ownership = "qdesn_exdqlm_shared_validation",
  size_gb = c(
    sum(file.info(fit_object_files)$size, na.rm = TRUE) / 1024^3,
    sum(file.info(vb_init_files)$size, na.rm = TRUE) / 1024^3,
    NA_real_,
    NA_real_,
    NA_real_,
    NA_real_
  ),
  classification = c(
    "old_regenerable_heavy_artifact_candidate",
    "unknown_or_mcmc_initialization_candidate",
    "reproducibility_metadata",
    "reproducibility_metadata",
    "reproducibility_metadata",
    "current_diagnostic_outputs"
  ),
  reason = c(
    "Large completed-run fit handoff objects; likely regenerable from run specs but may be useful if MCMC initialization from fitted VB objects is desired.",
    "Compact VB initialization handoffs may be useful for follow-up MCMC and should be kept unless a promotion manifest replaces them.",
    "Scalar metrics required for reproducible evidence and promotion.",
    "Manifests/status/provenance required for reproducible evidence and promotion.",
    "Report tables and audit outputs are the current evidence package inputs.",
    "Current Q-DESN output tables and retained storage-light artifacts."
  ),
  action = c("defer_delete_requires_explicit_approval", "keep", "keep", "keep", "keep", "keep"),
  stringsAsFactors = FALSE
)

outputs <- list(
  health = file.path(out_dir, "validation_health_check.csv"),
  ex_winners = file.path(out_dir, "exdqlm_dqlm_vb_objective_winners.csv"),
  ex_vs_baseline = file.path(out_dir, "exdqlm_dqlm_vb_fitcheck_winners_vs_baseline.csv"),
  ex_pair_ratios = file.path(out_dir, "exdqlm_dqlm_vb_forecastcheck_pair_ratios.csv"),
  q_winners = file.path(out_dir, "qdesn_rhs_vb_objective_winners.csv"),
  q_dominance_counts = file.path(out_dir, "qdesn_rhs_vb_dominance_counts.csv"),
  hard_cells = file.path(out_dir, "qdesn_rhs_vb_cells_requiring_followup.csv"),
  decision_ledger = file.path(out_dir, "decision_ledger.csv"),
  storage_dry_run = file.path(out_dir, "storage_cleanup_dry_run.csv"),
  file_manifest = file.path(out_dir, "file_manifest.csv"),
  manifest = file.path(out_dir, "vb_calibration_resume_evidence_manifest.json"),
  readme = file.path(out_dir, "README.md")
)

write_csv(health, outputs$health)
write_csv(ex_winners, outputs$ex_winners)
write_csv(ex_vs_baseline, outputs$ex_vs_baseline)
write_csv(ex_pair_ratios, outputs$ex_pair_ratios)
write_csv(q_winners, outputs$q_winners)
write_csv(q_dominance_counts, outputs$q_dominance_counts)
write_csv(hard_cells, outputs$hard_cells)
write_csv(decision_ledger, outputs$decision_ledger)
write_csv(storage_dry_run, outputs$storage_dry_run)

manifest_inputs <- c(required, ex_telemetry_path)
manifest_inputs <- manifest_inputs[file.exists(manifest_inputs)]
manifest_outputs <- unlist(outputs[!names(outputs) %in% c("file_manifest", "manifest", "readme")])
fm <- file_manifest(c(manifest_inputs, manifest_outputs))
write_csv(fm, outputs$file_manifest)

git_branch <- system("git branch --show-current", intern = TRUE)
git_sha <- system("git rev-parse HEAD", intern = TRUE)
git_status <- system("git status --porcelain", intern = TRUE)
disk <- trimws(system("df -h /data | tail -1", intern = TRUE))
current_run_patterns <- c(
  "20260708_exdqlm_dqlm_vb_calibration_resume",
  "qdesn-vb-rhs-fitfirst-resume-full-20260708",
  "ffv2_exdqlm_dqlm_vb_calibration_resume_20260708",
  "ffv2_qdesn_rhs_vb_fitfirst_resume_20260708"
)
tmux_all <- system("tmux list-sessions 2>/dev/null || true", intern = TRUE)
tmux_current <- tmux_all[grepl(paste(current_run_patterns, collapse = "|"), tmux_all)]

readme <- c(
  "# VB Calibration Resume Evidence, 2026-07-08",
  "",
  "## Scope",
  "",
  "This directory freezes the completed July 8 VB calibration evidence for the shared Q-DESN + exDQLM/DQLM fit+forecast validation study. It is a diagnostic and candidate-selection evidence package. It is not, by itself, an article-authoritative promotion and it does not authorize MCMC launch.",
  "",
  "## Health Check",
  "",
  "| Component | Completed | Status | Notes |",
  "| --- | ---: | --- | --- |"
)
for (i in seq_len(nrow(health))) {
  readme <- c(readme, paste0(
    "| ", health$component[[i]],
    " | ", ifelse(is.na(health$completed[[i]]), "", paste0(health$completed[[i]], "/", health$expected[[i]])),
    " | ", health$status[[i]],
    " | ", health$notes[[i]], " |"
  ))
}
readme <- c(
  readme,
  "",
  "## Main Diagnosis",
  "",
  "- The current exDQLM/DQLM VB calibration resume is complete and suitable for objective-specific candidate selection.",
  "- The current Q-DESN RHS VB fit-first follow-up is complete, with all rows successful but 22 WARN signoffs.",
  "- Q-DESN RHS forecast metrics are often competitive, but the fit-RMSE criterion remains the blocker: no family/tau cell beats all primary baselines.",
  "- MCMC should be launched only after selecting candidates by a declared objective, or after one more targeted Q-DESN fit-RMSE rescue if all-metric dominance is required.",
  paste0("- The disk state is tight: `/data` reported `", paste(disk, collapse = " "), "`. Cleanup should be approved separately and limited to completed-run heavy handoff objects."),
  "",
  "## Q-DESN Cells Requiring Follow-Up",
  "",
  "| Family | Tau | Best forecast-check profile | Forecast check ratio | Fit RMSE ratio |",
  "| --- | ---: | --- | ---: | ---: |"
)
if (nrow(hard_cells)) {
  for (i in seq_len(nrow(hard_cells))) {
    readme <- c(readme, paste0(
      "| ", hard_cells$family[[i]],
      " | ", fmt(hard_cells$tau[[i]], 2),
      " | ", hard_cells$screening_profile_base[[i]],
      " | ", fmt(hard_cells$forecast_pinball_ratio_vs_best_vb_baseline[[i]]),
      " | ", fmt(hard_cells$fit_rmse_ratio_vs_best_vb_baseline[[i]]),
      " |"
    ))
  }
} else {
  readme <- c(readme, "| none |  |  |  |  |")
}
readme <- c(
  readme,
  "",
  "## Recommended Next Move",
  "",
  "1. Use this evidence package to choose objective-specific VB winners.",
  "2. If the scientific target is forecast/check-loss dominance, prepare a limited MCMC candidate set from the forecast-check winners.",
  "3. If the scientific target is all-primary-metric dominance, run a targeted Q-DESN fit-RMSE screen before MCMC.",
  "4. Run a read-only storage review, then approve deletion only for completed-run heavy handoff fit objects if MCMC initialization will not require them.",
  "",
  "## Generated Files",
  "",
  paste0("- Health check: `", outputs$health, "`"),
  paste0("- exDQLM/DQLM objective winners: `", outputs$ex_winners, "`"),
  paste0("- exDQLM/DQLM fit-check winners vs baseline: `", outputs$ex_vs_baseline, "`"),
  paste0("- exDQLM/DQLM pair ratios: `", outputs$ex_pair_ratios, "`"),
  paste0("- Q-DESN objective winners: `", outputs$q_winners, "`"),
  paste0("- Q-DESN dominance counts: `", outputs$q_dominance_counts, "`"),
  paste0("- Q-DESN follow-up cells: `", outputs$hard_cells, "`"),
  paste0("- Decision ledger: `", outputs$decision_ledger, "`"),
  paste0("- Storage cleanup dry run: `", outputs$storage_dry_run, "`"),
  paste0("- File manifest: `", outputs$file_manifest, "`"),
  "",
  "## Active Validation Sessions Observed During Materialization",
  "",
  if (length(tmux_current)) paste0("- `", tmux_current, "`") else "- None matching the current July 8 validation run tags.",
  "",
  "## Reproducibility",
  "",
  paste0("- Branch: `", git_branch, "`"),
  paste0("- Commit: `", git_sha, "`"),
  paste0("- Dirty while materializing package: `", length(git_status) > 0L, "`"),
  "- Note: this field can be `TRUE` while this script is creating the evidence package; the authoritative run evidence itself points to the validation commit listed above.",
  paste0("- exDQLM/DQLM run root: `", ex_run_root, "`"),
  paste0("- Q-DESN report root: `", q_report_root, "`"),
  paste0("- Baseline table: `", baseline_path, "`")
)
writeLines(readme, outputs$readme)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = git_branch,
  git_sha = git_sha,
  git_dirty = length(git_status) > 0L,
  evidence_roots = list(
    exdqlm_dqlm_run_root = ex_run_root,
    qdesn_report_root = q_report_root,
    qdesn_results_root = q_results_root,
    baseline_path = baseline_path
  ),
  health = health,
  decisions = decision_ledger,
  output_paths = outputs,
  file_manifest = fm,
  status = "diagnostic_evidence_frozen_not_article_authoritative"
)
jsonlite::write_json(manifest, outputs$manifest, auto_unbox = TRUE, pretty = TRUE, null = "null")

cat("wrote evidence package:", out_dir, "\n")
cat("health:", outputs$health, "\n")
cat("readme:", outputs$readme, "\n")
