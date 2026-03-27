#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

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

`%||%` <- function(a, b) if (is.null(a)) b else a

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)

manifest_path <- as.character(get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageN_manifest.yaml")))[1L]
if (!grepl("^(/|~)", manifest_path)) manifest_path <- file.path(repo_root, manifest_path)
manifest_path <- normalizePath(manifest_path, winslash = "/", mustWork = FALSE)

report_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", "rhs_stageM_repair_wave", run_tag)
results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", "rhs_stageM_repair_wave", run_tag)

exists_file <- function(path) if (file.exists(path)) "yes" else "no"
read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

mr1_table <- file.path(report_root, "tables", "mr1_profile_matrix.csv")
mr2_summary <- file.path(report_root, "tables", "mr2_canary_summary.csv")
mr3_summary <- file.path(report_root, "tables", "mr3_full_summary.csv")
final_manifest <- file.path(report_root, "manifest", "stageM_repair_manifest.json")
winner_json <- file.path(report_root, "manifest", "mr1_winner.json")

mr1_df <- read_csv_safe(mr1_table)
mr2_dir <- if (dir.exists(file.path(report_root, "mr2_canary"))) {
  dd <- sort(list.dirs(file.path(report_root, "mr2_canary"), recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  if (length(dd)) dd[[1L]] else NA_character_
} else {
  NA_character_
}
mr2_pair <- if (!is.na(mr2_dir)) read_csv_safe(file.path(mr2_dir, "tables", "campaign_pair_summary.csv")) else data.frame(stringsAsFactors = FALSE)
mr2_completed <- if (!is.na(mr2_dir) && file.exists(file.path(mr2_dir, "manifest", "campaign_completed.json"))) "yes" else "no"

manifest <- if (file.exists(manifest_path)) yaml::read_yaml(manifest_path) else list()
canary_grid_path <- as.character(manifest$inputs$canary_grid %||% "")[1L]
if (nzchar(canary_grid_path) && !grepl("^(/|~)", canary_grid_path)) canary_grid_path <- file.path(repo_root, canary_grid_path)
canary_grid_path <- normalizePath(canary_grid_path, winslash = "/", mustWork = FALSE)
grid <- read_csv_safe(canary_grid_path)
mr2_expected <- if (nrow(grid)) nrow(grid) else NA_integer_
mr2_done <- nrow(mr2_pair)

status_files <- if (dir.exists(results_root)) list.files(results_root, pattern = "root_status.txt", recursive = TRUE, full.names = TRUE) else character(0)
status_vals <- if (length(status_files)) vapply(status_files, function(f) trimws(readLines(f, warn = FALSE)[1L]), character(1)) else character(0)
status_tab <- if (length(status_vals)) sort(table(status_vals), decreasing = TRUE) else integer(0)
non_success <- if (length(status_files)) status_files[status_vals != "SUCCESS"] else character(0)

proc_cmd <- sprintf("pgrep -fa 'run_qdesn_rhs_stageN_wave.R.*%s|run_qdesn_rhs_stageM_repair_wave.R.*%s|pipeline_sim_main.R' | wc -l", run_tag, run_tag)
proc_count <- suppressWarnings(as.integer(system(proc_cmd, intern = TRUE)))
if (!length(proc_count) || !is.finite(proc_count)) proc_count <- 0L
active <- if (proc_count > 1L) "yes" else "no"

mr1_gate <- if (nrow(mr1_df)) sprintf("%d/%d", sum(mr1_df$gate_pass, na.rm = TRUE), nrow(mr1_df)) else "na"
mr1_winner <- if (file.exists(winner_json)) as.character(jsonlite::fromJSON(winner_json)$winner_profile_id %||% "na") else "na"
mr2_signoff <- if (nrow(mr2_pair)) paste(names(table(mr2_pair$pair_signoff_grade)), as.integer(table(mr2_pair$pair_signoff_grade)), collapse = ", ") else "na"
mr2_eligible <- if (nrow(mr2_pair)) sprintf("%d/%d", sum(mr2_pair$pair_comparison_eligible, na.rm = TRUE), nrow(mr2_pair)) else "na"
mr2_fd <- if (nrow(mr2_pair)) sprintf("%s/%s", all(mr2_pair$both_finite_ok), all(mr2_pair$both_domain_ok)) else "na"
status_str <- if (length(status_tab)) paste(names(status_tab), as.integer(status_tab), collapse = ", ") else "none"

cat(sprintf("run_tag: %s\n", run_tag))
cat("| Checkpoint | Status | Detail |\n")
cat("|---|---|---|\n")
cat(sprintf("| Active process | %s | matching_processes=%d |\n", active, proc_count - 1L))
cat(sprintf("| MR1 matrix | %s | present=%s, gate_pass=%s, winner=%s |\n",
            if (nrow(mr1_df)) "complete" else "missing",
            exists_file(mr1_table), mr1_gate, mr1_winner))
cat(sprintf("| MR2 canary table | %s | pair_rows=%d, expected=%s, pair_signoff=%s, eligible=%s, finite/domain=%s |\n",
            if (nrow(mr2_pair)) "partial_or_complete" else "missing",
            mr2_done, ifelse(is.na(mr2_expected), "na", as.character(mr2_expected)), mr2_signoff, mr2_eligible, mr2_fd))
cat(sprintf("| MR2 completed marker | %s | mr2_run_dir=%s |\n",
            mr2_completed,
            ifelse(is.na(mr2_dir), "na", mr2_dir)))
cat(sprintf("| MR3 summary | %s | present=%s |\n",
            if (file.exists(mr3_summary)) "present" else "missing",
            exists_file(mr3_summary)))
cat(sprintf("| Final Stage-M manifest | %s | present=%s |\n",
            if (file.exists(final_manifest)) "present" else "missing",
            exists_file(final_manifest)))
cat(sprintf("| Root status distribution | %s | non_success=%d |\n", status_str, length(non_success)))

if (length(non_success)) {
  cat("\nnon_success_roots:\n")
  cat(paste(non_success, collapse = "\n"))
  cat("\n")
}
