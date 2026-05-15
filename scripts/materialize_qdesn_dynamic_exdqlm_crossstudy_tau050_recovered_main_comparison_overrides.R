#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = FALSE) {
  path <- as.character(path)[1L]
  if (!grepl("^(/|~)", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE)
}

output_path <- resolve_path(
  get_arg(
    "--output",
    file.path(
      "config",
      "validation",
      "qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_root_override_map.csv"
    )
  ),
  must_work = FALSE
)

source_fit_path <- resolve_path(file.path(
  "reports",
  "qdesn_mcmc_validation",
  "dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation",
  "qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674",
  "20260416-212707__git-15fe674",
  "tables",
  "campaign_fit_summary.csv"
), must_work = TRUE)

candidate_specs <- data.frame(
  source_wave = c(
    "sfreeze_al",
    "sfreeze_exal",
    "remaining_hard_fail_latent_v_al",
    "remaining_hard_fail_latent_v_exal",
    "remaining_hard_fail_exal_ridge_precision_v1",
    "remaining_precision_closeout_al_ladder_v2",
    "remaining_precision_closeout_exal_ladder_v2"
  ),
  priority = c(10L, 10L, 20L, 20L, 20L, 30L, 30L),
  roots_dir = c(
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_sfreeze-20260419-031755__git-e44a56a",
      "20260419-031803__git-e44a56a", "roots"
    ),
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_sfreeze-20260419-031810__git-e44a56a",
      "20260419-031817__git-e44a56a", "roots"
    ),
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_al-20260420-030610__git-dbafa6a",
      "20260420-030618__git-dbafa6a", "roots"
    ),
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_exal-20260420-030619__git-dbafa6a",
      "20260420-030626__git-dbafa6a", "roots"
    ),
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_exal_ridge_precision_v1-20260420-030633__git-dbafa6a",
      "20260420-030642__git-dbafa6a", "roots"
    ),
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_ladder_v2_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_closeout_al_ladder_v2-20260421-000540__git-2c7e975",
      "20260421-000549__git-2c7e975", "roots"
    ),
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_ladder_v2_validation",
      "qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_closeout_exal_ladder_v2-20260421-000540__git-2c7e975",
      "20260421-000550__git-2c7e975", "roots"
    )
  ),
  stringsAsFactors = FALSE
)

source_fit <- read_csv(source_fit_path)
source_fail <- subset(source_fit, as.character(status) == "FAIL")
if (!nrow(source_fail)) {
  stop("Authoritative tau050 source fit summary has no FAIL rows.", call. = FALSE)
}
source_fail$key <- paste(source_fail$root_id, source_fail$inference, source_fail$model, sep = "||")

candidate_rows <- list()
for (i in seq_len(nrow(candidate_specs))) {
  spec <- candidate_specs[i, , drop = FALSE]
  roots_dir <- resolve_path(spec$roots_dir, must_work = TRUE)
  fit_paths <- sort(list.files(roots_dir, pattern = "^fit_summary\\.csv$", recursive = TRUE, full.names = TRUE))
  for (fit_path in fit_paths) {
    fit_df <- read_csv(fit_path)
    if (!nrow(fit_df)) next
    fit_df <- subset(fit_df, as.character(status) == "SUCCESS")
    if (!nrow(fit_df)) next
    fit_df$key <- paste(fit_df$root_id, fit_df$inference, fit_df$model, sep = "||")
    fit_df <- fit_df[fit_df$key %in% source_fail$key, , drop = FALSE]
    if (!nrow(fit_df)) next
    root_path <- file.path(dirname(fit_path), "root_signoff_summary.csv")
    fit_df$fit_summary_path <- normalizePath(fit_path, winslash = "/", mustWork = TRUE)
    fit_df$root_summary_path <- normalizePath(root_path, winslash = "/", mustWork = TRUE)
    fit_df$source_wave <- spec$source_wave[1L]
    fit_df$priority <- as.integer(spec$priority[1L])
    fit_df$profile_id <- spec$source_wave[1L]
    fit_df$stage_id <- spec$source_wave[1L]
    fit_df$run_tag <- basename(dirname(dirname(roots_dir)))
    fit_df$rationale <- sprintf("Recovered tau050 source FAIL fit from %s.", spec$source_wave[1L])
    candidate_rows[[length(candidate_rows) + 1L]] <- fit_df[, c(
      "root_id", "inference", "model", "status", "signoff_grade",
      "fit_summary_path", "root_summary_path",
      "source_wave", "priority", "profile_id", "stage_id", "run_tag", "rationale", "key"
    ), drop = FALSE]
  }
}

candidate_dt <- do.call(rbind, candidate_rows)
if (!nrow(candidate_dt)) {
  stop("No successful recovered fit candidates were found for the tau050 source FAIL surface.", call. = FALSE)
}

candidate_dt <- candidate_dt[order(candidate_dt$key, candidate_dt$priority), , drop = FALSE]
selected_dt <- candidate_dt[!duplicated(candidate_dt$key, fromLast = TRUE), , drop = FALSE]
selected_dt <- selected_dt[order(selected_dt$root_id, selected_dt$inference, selected_dt$model, selected_dt$priority), , drop = FALSE]

missing_keys <- setdiff(source_fail$key, selected_dt$key)
if (length(missing_keys)) {
  stop(
    sprintf(
      "Recovered main comparison override map is missing %d original FAIL fits:\n%s",
      length(missing_keys),
      paste(missing_keys, collapse = "\n")
    ),
    call. = FALSE
  )
}

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  selected_dt[, c(
    "root_id", "inference", "model", "status", "signoff_grade",
    "fit_summary_path", "root_summary_path",
    "source_wave", "priority", "profile_id", "stage_id", "run_tag", "rationale"
  ), drop = FALSE],
  output_path,
  row.names = FALSE
)

cat(sprintf("Wrote tau050 recovered main comparison override map: %s\n", output_path))
cat(sprintf("Recovered FAIL fits covered: %d / %d\n", nrow(selected_dt), nrow(source_fail)))
