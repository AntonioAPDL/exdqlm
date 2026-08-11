#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("Missing package: %s", pkg), call. = FALSE)
    }
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

run_tag <- as.character(get_arg(
  "--run-tag",
  "ind-exal-m0-paired-rolling-repair-v1-calibration-20260811_overnight_v1"
))[1L]
promotion_id <- "independent_exal_m0_paired_rolling_repair_v1_closeout_20260811"
state_root <- normalizePath(file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration", run_tag
), winslash = "/", mustWork = TRUE)
closeout_root <- normalizePath(file.path(state_root, "paired_closeout"),
                               winslash = "/", mustWork = TRUE)
materialization_root <- normalizePath(file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration",
  "independent_exal_m0_paired_rolling_repair_v1_materialization"
), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

closeout_manifest_path <- file.path(closeout_root, "paired_closeout_manifest.json")
closeout_manifest <- qdesn_ssv2_read_json(closeout_manifest_path)
metric_selection_path <- file.path(closeout_root, "paired_metric_selection_ledger.csv")
confirmation_profiles_path <- file.path(closeout_root, "canonical_confirmation_profiles.csv")
target_contract_path <- file.path(materialization_root, "corrected_target_contract.csv")
runtime_verification_path <- file.path(state_root, "runtime_verification.json")
run_env_path <- file.path(state_root, "run.env")
for (path in c(closeout_manifest_path, metric_selection_path,
               confirmation_profiles_path, target_contract_path,
               runtime_verification_path, run_env_path)) {
  if (!file.exists(path)) stop(sprintf("Missing closeout input: %s", path), call. = FALSE)
}

selection <- qdesn_ssv2_read_csv(metric_selection_path)
profiles <- qdesn_ssv2_read_csv(confirmation_profiles_path)
runtime <- qdesn_ssv2_read_json(runtime_verification_path)
run_env <- readLines(run_env_path, warn = FALSE)
source_commit_line <- grep("^GIT_COMMIT=", run_env, value = TRUE)
if (length(source_commit_line) != 1L) {
  stop("The calibration run.env does not contain exactly one GIT_COMMIT.",
       call. = FALSE)
}
source_commit <- sub("^GIT_COMMIT=", "", source_commit_line)
eligible <- selection[
  selection$decision == "ELIGIBLE_FOR_CANONICAL_FULL_BUDGET_CONFIRMATION",
  , drop = FALSE
]
expected_cells <- c("normal_t0p05", "normal_t0p50")
closeout_hash_checks <- c(
  calibration_job_evidence = identical(
    qdesn_ssv2_sha256(file.path(closeout_root, "calibration_job_evidence.csv")),
    as.character(closeout_manifest$outputs$evidence$sha256)
  ),
  calibration_metric_evidence = identical(
    qdesn_ssv2_sha256(file.path(closeout_root, "calibration_metric_evidence.csv")),
    as.character(closeout_manifest$outputs$metric_evidence$sha256)
  ),
  paired_contrasts = identical(
    qdesn_ssv2_sha256(file.path(closeout_root, "paired_contrasts.csv")),
    as.character(closeout_manifest$outputs$contrasts$sha256)
  ),
  paired_selection = identical(
    qdesn_ssv2_sha256(file.path(closeout_root, "paired_selection_ledger.csv")),
    as.character(closeout_manifest$outputs$primary_selection$sha256)
  ),
  paired_metric_selection = identical(
    qdesn_ssv2_sha256(metric_selection_path),
    as.character(closeout_manifest$outputs$metric_selection$sha256)
  ),
  confirmation_profiles = identical(
    qdesn_ssv2_sha256(confirmation_profiles_path),
    as.character(closeout_manifest$outputs$confirmation_profiles$sha256)
  )
)
checks <- c(
  run_tag = identical(as.character(closeout_manifest$run_tag), run_tag),
  closeout_decision = identical(
    as.character(closeout_manifest$decision),
    "PAIRED_CALIBRATION_CLOSED_MANUAL_CONFIRMATION_REQUIRED"
  ),
  jobs = identical(as.integer(closeout_manifest$jobs), 84L),
  metric_cells = identical(as.integer(closeout_manifest$metric_cells), 21L),
  eligible_metrics = nrow(eligible) == 3L,
  eligible_cells = identical(sort(unique(eligible$target_cell_id)), sort(expected_cells)),
  profiles = nrow(profiles) == 2L &&
    identical(sort(profiles$target_cell_id), sort(expected_cells)),
  runtime = identical(as.character(runtime$decision), "PASS") &&
    identical(as.integer(runtime$runtime_pass), 84L),
  closeout_output_hashes = all(closeout_hash_checks),
  no_minimum_effect = identical(
    as.numeric(closeout_manifest$selection_rule$minimum_effect_threshold), 0
  )
)
if (!all(checks)) {
  stop(sprintf("Closeout sealing gate failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

copy_inputs <- c(
  "calibration_job_evidence.csv", "calibration_metric_evidence.csv",
  "paired_contrasts.csv", "paired_metric_selection_ledger.csv",
  "paired_selection_ledger.csv", "canonical_confirmation_profiles.csv"
)
copied <- vapply(copy_inputs, function(name) {
  src <- file.path(closeout_root, name)
  dst <- file.path(output_root, name)
  if (!file.copy(src, dst, overwrite = TRUE, copy.mode = FALSE)) {
    stop(sprintf("Failed to freeze %s.", name), call. = FALSE)
  }
  dst
}, character(1L))
target_copy <- file.path(output_root, "corrected_target_contract.csv")
if (!file.copy(target_contract_path, target_copy, overwrite = TRUE, copy.mode = FALSE)) {
  stop("Failed to freeze the corrected target contract.", call. = FALSE)
}

article_promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v5_rolling_rebaseline_20260811"
article_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", article_promotion_id
)
article_interface_path <- file.path(article_root, paste0(article_promotion_id, "_interface.csv"))
article_manifest_path <- file.path(article_root, paste0(article_promotion_id, "_manifest.json"))
article <- qdesn_ssv2_read_csv(article_interface_path)
baseline_rows <- article[
  article$model_variant == "qdesn_exal_rhs_ns" & article$inference == "mcmc" &
    article$family == "normal" & article$tau %in% c(0.05, 0.50),
  , drop = FALSE
]
if (nrow(baseline_rows) != 2L ||
    !identical(sort(baseline_rows$tau), c(0.05, 0.50))) {
  stop("The authoritative article baseline does not contain the two target rows.",
       call. = FALSE)
}
baseline_rows_path <- qdesn_ssv2_write_csv(
  baseline_rows, file.path(output_root, "article_baseline_rows.csv")
)
metric_map <- list(
  fit_qtrue_rmse = c("fit_source_candidate_id", "fit_source_run_tag",
                     "fit_source_signoff_grade", "fit_source_status",
                     "fit_source_path", "fit_source_sha256"),
  forecast_qtrue_mae_H1000 = c(
    "forecast_mae_source_candidate_id", "forecast_mae_source_run_tag",
    "forecast_mae_source_signoff_grade", "forecast_mae_source_status",
    "forecast_mae_source_path", "forecast_mae_source_sha256"
  ),
  forecast_check_loss_H1000 = c(
    "forecast_check_source_candidate_id", "forecast_check_source_run_tag",
    "forecast_check_source_signoff_grade", "forecast_check_source_status",
    "forecast_check_source_path", "forecast_check_source_sha256"
  )
)
baseline_metric_rows <- list()
k <- 0L
for (i in seq_len(nrow(baseline_rows))) {
  row <- baseline_rows[i, , drop = FALSE]
  target_cell_id <- sprintf("normal_t%s", sub("[.]", "p", sprintf("%.2f", row$tau)))
  for (metric in names(metric_map)) {
    fields <- metric_map[[metric]]
    k <- k + 1L
    baseline_metric_rows[[k]] <- data.frame(
      target_cell_id = target_cell_id, family = row$family, tau = row$tau,
      model_variant = row$model_variant, inference = row$inference,
      metric = metric, current_article_value = as.numeric(row[[metric]]),
      source_candidate_id = as.character(row[[fields[[1L]]]]),
      source_run_tag = as.character(row[[fields[[2L]]]]),
      source_signoff_grade = as.character(row[[fields[[3L]]]]),
      source_status = as.character(row[[fields[[4L]]]]),
      source_path = as.character(row[[fields[[5L]]]]),
      source_sha256 = as.character(row[[fields[[6L]]]]),
      article_interface_id = row$article_interface_id,
      article_interface_path = normalizePath(article_interface_path, winslash = "/",
                                             mustWork = TRUE),
      article_interface_sha256 = qdesn_ssv2_sha256(article_interface_path),
      source_registry_hash_value = row$source_registry_hash_value,
      stringsAsFactors = FALSE
    )
  }
}
baseline_metrics <- do.call(rbind, baseline_metric_rows)
baseline_metrics_path <- qdesn_ssv2_write_csv(
  baseline_metrics, file.path(output_root, "article_metric_baseline.csv")
)

evidence <- data.frame(
  role = c(names(copied), "target_contract", "closeout_manifest",
           "runtime_verification", "article_interface", "article_manifest",
           "article_baseline_rows", "article_metric_baseline"),
  source_path = c(
    file.path(closeout_root, names(copied)), target_contract_path,
    closeout_manifest_path, runtime_verification_path, article_interface_path,
    article_manifest_path, baseline_rows_path, baseline_metrics_path
  ),
  frozen_path = c(
    unname(copied), target_copy, rep(NA_character_, 4L),
    baseline_rows_path, baseline_metrics_path
  ),
  stringsAsFactors = FALSE
)
evidence$source_sha256 <- vapply(evidence$source_path, qdesn_ssv2_sha256, character(1L))
evidence$frozen_sha256 <- vapply(seq_len(nrow(evidence)), function(i) {
  path <- evidence$frozen_path[[i]]
  if (is.na(path)) NA_character_ else qdesn_ssv2_sha256(path)
}, character(1L))
evidence$hash_preserved <- is.na(evidence$frozen_sha256) |
  evidence$source_sha256 == evidence$frozen_sha256
evidence_path <- qdesn_ssv2_write_csv(
  evidence, file.path(output_root, "source_evidence_manifest.csv")
)
if (!all(evidence$hash_preserved)) stop("A frozen closeout hash changed.", call. = FALSE)

frozen_files <- c(
  unname(copied), target_copy, baseline_rows_path, baseline_metrics_path,
  evidence_path
)
file_manifest <- data.frame(
  path = normalizePath(frozen_files, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(frozen_files)$size),
  sha256 = vapply(frozen_files, qdesn_ssv2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- qdesn_ssv2_write_csv(
  file_manifest, file.path(output_root, "file_manifest.csv")
)
manifest_path <- qdesn_ssv2_write_json(list(
  generated_at = as.character(closeout_manifest$generated_at), promotion_id = promotion_id,
  decision = "CALIBRATION_CLOSED_TWO_CANDIDATES_READY_FOR_FULL_CONFIRMATION",
  source_run_tag = run_tag,
  source_validation_branch = system("git branch --show-current", intern = TRUE),
  source_validation_commit = source_commit,
  package_version = "1.0.0", method_id = "M0_v_collapsed_support_logit",
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  jobs = 84L, paired_blocks = 42L, metric_cells = 21L,
  selected_target_cells = as.list(expected_cells),
  selected_metric_cells = nrow(eligible), candidates = nrow(profiles),
  selection_rule = closeout_manifest$selection_rule,
  article_baseline = list(
    promotion_id = article_promotion_id,
    interface_path = normalizePath(article_interface_path, winslash = "/", mustWork = TRUE),
    interface_sha256 = qdesn_ssv2_sha256(article_interface_path),
    manifest_path = normalizePath(article_manifest_path, winslash = "/", mustWork = TRUE),
    manifest_sha256 = qdesn_ssv2_sha256(article_manifest_path)
  ),
  outputs = list(
    confirmation_profiles = list(
      path = copied[["canonical_confirmation_profiles.csv"]],
      sha256 = qdesn_ssv2_sha256(copied[["canonical_confirmation_profiles.csv"]])
    ),
    metric_selection = list(
      path = copied[["paired_metric_selection_ledger.csv"]],
      sha256 = qdesn_ssv2_sha256(copied[["paired_metric_selection_ledger.csv"]])
    ),
    article_metric_baseline = list(
      path = baseline_metrics_path, sha256 = qdesn_ssv2_sha256(baseline_metrics_path)
    ),
    evidence_manifest = list(
      path = evidence_path, sha256 = qdesn_ssv2_sha256(evidence_path)
    ),
    file_manifest = list(
      path = file_manifest_path, sha256 = qdesn_ssv2_sha256(file_manifest_path)
    )
  ),
  routine_binary_payloads = 0L,
  article_update_automatic = FALSE
), file.path(output_root, paste0(promotion_id, "_manifest.json")))

cat(sprintf(
  "promotion_id=%s candidates=%d eligible_metrics=%d decision=%s manifest=%s\n",
  promotion_id, nrow(profiles), nrow(eligible),
  "READY_FOR_FULL_CONFIRMATION", manifest_path
))
