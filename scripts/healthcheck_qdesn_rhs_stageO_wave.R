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

manifest_path <- as.character(get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageO_manifest.yaml")))[1L]
if (!grepl("^(/|~)", manifest_path)) manifest_path <- file.path(repo_root, manifest_path)
manifest_path <- normalizePath(manifest_path, winslash = "/", mustWork = FALSE)

report_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", "rhs_stageO_wave", run_tag)
results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", "rhs_stageO_wave", run_tag)

exists_file <- function(path) if (file.exists(path)) "yes" else "no"
read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

read_profiles_n <- function(path) {
  if (!file.exists(path)) return(NA_integer_)
  cfg <- yaml::read_yaml(path)
  profiles <- cfg$profiles %||% list()
  if (!is.list(profiles)) return(NA_integer_)
  as.integer(length(profiles))
}

o1_table <- file.path(report_root, "tables", "o1_profile_matrix.csv")
o2_table <- file.path(report_root, "tables", "o2_profile_matrix.csv")
o3_summary <- file.path(report_root, "tables", "o3_stress6_summary.csv")
o4_summary <- file.path(report_root, "tables", "o4_full_summary.csv")
selected_json <- file.path(report_root, "manifest", "selected_candidate.json")

manifest <- if (file.exists(manifest_path)) yaml::read_yaml(manifest_path) else list()
meta <- manifest$meta %||% list()
output_manifest_name <- as.character(meta$output_manifest_name %||% "stageO_manifest.json")[1L]
if (!nzchar(trimws(output_manifest_name))) output_manifest_name <- "stageO_manifest.json"
final_manifest <- file.path(report_root, "manifest", output_manifest_name)

blocker_grid_path <- as.character((manifest$inputs %||% list())$blocker_grid %||% "")[1L]
stress_grid_path <- as.character((manifest$inputs %||% list())$stress_grid %||% "")[1L]
full_grid_path <- as.character((manifest$inputs %||% list())$full_grid %||% "")[1L]
o1_profiles_path <- as.character((manifest$inputs %||% list())$o1_profiles %||% "")[1L]
o2_profiles_path <- as.character((manifest$inputs %||% list())$o2_profiles %||% "")[1L]
for (nm in c("blocker_grid_path", "stress_grid_path", "full_grid_path", "o1_profiles_path", "o2_profiles_path")) {
  val <- get(nm)
  if (nzchar(val) && !grepl("^(/|~)", val)) assign(nm, file.path(repo_root, val))
}

o1_expected <- read_profiles_n(o1_profiles_path)
o2_expected <- read_profiles_n(o2_profiles_path)
blocker_expected <- nrow(read_csv_safe(blocker_grid_path))
stress_expected <- nrow(read_csv_safe(stress_grid_path))
full_expected <- nrow(read_csv_safe(full_grid_path))

o1_df <- read_csv_safe(o1_table)
o2_df <- read_csv_safe(o2_table)
o3_df <- read_csv_safe(o3_summary)
o4_df <- read_csv_safe(o4_summary)

selected_candidate <- if (file.exists(selected_json)) {
  tryCatch(jsonlite::fromJSON(selected_json), error = function(...) list())
} else {
  list()
}
selected_label <- if (length(selected_candidate$phase) && length(selected_candidate$profile_id)) {
  sprintf("%s/%s", as.character(selected_candidate$phase)[1L], as.character(selected_candidate$profile_id)[1L])
} else {
  "na"
}

status_files <- if (dir.exists(results_root)) list.files(results_root, pattern = "root_status.txt", recursive = TRUE, full.names = TRUE) else character(0)
status_vals <- if (length(status_files)) vapply(status_files, function(f) trimws(readLines(f, warn = FALSE)[1L]), character(1)) else character(0)
status_tab <- if (length(status_vals)) sort(table(status_vals), decreasing = TRUE) else integer(0)
non_success <- if (length(status_files)) status_files[status_vals != "SUCCESS"] else character(0)

proc_cmd <- sprintf("pgrep -fa 'run_qdesn_rhs_stageO_wave.R.*%s|pipeline_sim_main.R' | wc -l", run_tag)
proc_count <- suppressWarnings(as.integer(system(proc_cmd, intern = TRUE)))
if (!length(proc_count) || !is.finite(proc_count)) proc_count <- 0L
active <- if (proc_count > 1L) "yes" else "no"

o1_gate <- if (nrow(o1_df)) sprintf("%d/%d", sum(o1_df$gate_pass, na.rm = TRUE), nrow(o1_df)) else "na"
o2_gate <- if (nrow(o2_df)) sprintf("%d/%d", sum(o2_df$gate_pass, na.rm = TRUE), nrow(o2_df)) else "na"
o3_gate <- if (nrow(o3_df)) as.character(o3_df$gate_pass[1L]) else "na"
o4_gate <- if (nrow(o4_df)) as.character(o4_df$gate_pass[1L]) else "na"
status_str <- if (length(status_tab)) paste(names(status_tab), as.integer(status_tab), collapse = ", ") else "none"

cat(sprintf("run_tag: %s\n", run_tag))
cat("| Checkpoint | Status | Detail |\n")
cat("|---|---|---|\n")
cat(sprintf("| Active process | %s | matching_processes=%d |\n", active, proc_count - 1L))
cat(sprintf("| O1 probe matrix | %s | present=%s, profiles=%d/%s, blocker_roots=%s, gate_pass=%s |\n",
            if (nrow(o1_df)) "complete" else "missing",
            exists_file(o1_table), nrow(o1_df), ifelse(is.na(o1_expected), "na", as.character(o1_expected)),
            ifelse(is.na(blocker_expected), "na", as.character(blocker_expected)), o1_gate))
cat(sprintf("| O2 candidate matrix | %s | present=%s, profiles=%d/%s, blocker_roots=%s, gate_pass=%s |\n",
            if (nrow(o2_df)) "partial_or_complete" else "missing_or_skipped",
            exists_file(o2_table), nrow(o2_df), ifelse(is.na(o2_expected), "na", as.character(o2_expected)),
            ifelse(is.na(blocker_expected), "na", as.character(blocker_expected)), o2_gate))
cat(sprintf("| Selected candidate | %s | source=%s |\n",
            if (file.exists(selected_json)) "present" else "missing",
            selected_label))
cat(sprintf("| O3 stress6 summary | %s | present=%s, stress_roots=%s, gate_pass=%s |\n",
            if (nrow(o3_df)) "present" else "missing",
            exists_file(o3_summary),
            ifelse(is.na(stress_expected), "na", as.character(stress_expected)),
            o3_gate))
cat(sprintf("| O4 full summary | %s | present=%s, full_roots=%s, gate_pass=%s |\n",
            if (nrow(o4_df)) "present" else "missing",
            exists_file(o4_summary),
            ifelse(is.na(full_expected), "na", as.character(full_expected)),
            o4_gate))
cat(sprintf("| Final Stage-O manifest | %s | present=%s |\n",
            if (file.exists(final_manifest)) "present" else "missing",
            exists_file(final_manifest)))
cat(sprintf("| Root status distribution | %s | non_success=%d |\n", status_str, length(non_success)))

if (length(non_success)) {
  cat("\nnon_success_roots:\n")
  cat(paste(non_success, collapse = "\n"))
  cat("\n")
}
