#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml", "jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (is.na(idx) || idx >= length(args)) return(default)
  args[idx + 1L]
}
`%||%` <- function(a, b) if (is.null(a)) b else a
num_arg <- function(flag, default) {
  val <- suppressWarnings(as.numeric(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.numeric(default)
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
runtime_snapshot <- exdqlm:::qdesn_validation_assert_runtime(repo_root = repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  info <- file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) || info$size[[1L]] <= 0) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  preview <- trimws(readLines(path, warn = FALSE, n = 5L))
  preview <- preview[nzchar(preview)]
  if (!length(preview)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  if (all(preview %in% c('""', "''"))) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("no lines available in input", msg, fixed = TRUE)) {
        return(data.frame(stringsAsFactors = FALSE))
      }
      stop(e)
    }
  )
}

read_json_safe <- function(path) {
  if (!file.exists(path)) return(list())
  jsonlite::fromJSON(path)
}

file_inventory <- function(root, pattern) {
  if (!dir.exists(root)) return(data.frame(path = character(), bytes = numeric(), stringsAsFactors = FALSE))
  files <- list.files(root, pattern = pattern, recursive = TRUE, full.names = TRUE)
  files <- files[file.exists(files)]
  if (!length(files)) return(data.frame(path = character(), bytes = numeric(), stringsAsFactors = FALSE))
  info <- file.info(files)
  data.frame(path = normalizePath(files, winslash = "/", mustWork = FALSE), bytes = as.numeric(info$size), stringsAsFactors = FALSE)
}

read_first_line_safe <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  out <- readLines(path, warn = FALSE, n = 1L)
  if (length(out)) trimws(out[[1L]]) else NA_character_
}

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml")),
  must_work = TRUE
)
defaults <- yaml::read_yaml(defaults_path)
campaign_cfg <- defaults$campaign %||% list()

base_results_root <- resolve_path(
  get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation")),
  must_work = FALSE
)
base_report_root <- resolve_path(
  get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation")),
  must_work = FALSE
)

outer_results_root <- file.path(base_results_root, run_tag)
outer_report_root <- file.path(base_report_root, run_tag)
launch_root <- file.path(outer_report_root, "launch")
preflight_manifest <- read_json_safe(file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json"))
launch_manifest <- read_json_safe(file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_launch_manifest.json"))
launcher_meta <- read_json_safe(file.path(launch_root, "launcher_session.json"))

resolve_campaign_root <- function(run_root, child) {
  if (!dir.exists(run_root)) return(run_root)
  direct <- file.path(run_root, child)
  if (dir.exists(direct)) return(run_root)
  kids <- sort(list.dirs(run_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (k in kids) {
    if (dir.exists(file.path(k, child))) return(k)
  }
  run_root
}

results_root <- resolve_campaign_root(outer_results_root, "roots")
report_root <- resolve_campaign_root(outer_report_root, "tables")

root_dirs <- if (dir.exists(file.path(results_root, "roots"))) {
  sort(list.dirs(file.path(results_root, "roots"), recursive = FALSE, full.names = TRUE))
} else {
  character(0)
}
root_status_vals <- vapply(file.path(root_dirs, "manifest", "root_status.txt"), function(path) {
  if (!file.exists(path)) return("MISSING")
  trimws(readLines(path, warn = FALSE, n = 1L))
}, character(1))
root_status_tab <- if (length(root_status_vals)) sort(table(root_status_vals), decreasing = TRUE) else integer(0)

index_alignment_files <- file.path(
  list.dirs(file.path(results_root, "roots"), recursive = TRUE, full.names = TRUE),
  "manifest",
  "index_alignment.json"
)
index_alignment_files <- index_alignment_files[file.exists(index_alignment_files)]
index_alignment_status <- vapply(index_alignment_files, function(path) {
  as.character((read_json_safe(path)$status %||% NA_character_)[1L])
}, character(1))
index_alignment_tab <- if (length(index_alignment_status)) sort(table(index_alignment_status), decreasing = TRUE) else integer(0)

horizon_summary_files <- list.files(
  file.path(results_root, "roots"),
  pattern = "^forecast_horizon_summary\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)
horizon_summary_rows <- sum(vapply(horizon_summary_files, function(path) nrow(read_csv_safe(path)), integer(1)), na.rm = TRUE)

heavy_results <- rbind(
  file_inventory(results_root, "forecast_objects\\.rds$"),
  file_inventory(results_root, "\\.rda$"),
  file_inventory(results_root, "\\.RData$"),
  file_inventory(results_root, "rhs_trace\\.rds$"),
  file_inventory(results_root, "timing_summary\\.rds$")
)
heavy_reports <- rbind(
  file_inventory(report_root, "forecast_objects\\.rds$"),
  file_inventory(report_root, "\\.rda$"),
  file_inventory(report_root, "\\.RData$"),
  file_inventory(report_root, "rhs_trace\\.rds$"),
  file_inventory(report_root, "timing_summary\\.rds$")
)
heavy_all <- rbind(heavy_results, heavy_reports)
heavy_bytes <- sum(as.numeric(heavy_all$bytes), na.rm = TRUE)

du_line <- function(path) {
  if (!dir.exists(path)) return("missing")
  out <- tryCatch(system2("du", c("-sh", path), stdout = TRUE, stderr = TRUE), error = function(e) sprintf("ERROR: %s", conditionMessage(e)))
  if (length(out)) out[[1L]] else NA_character_
}
df_line <- tryCatch(system2("df", c("-h", dirname(results_root)), stdout = TRUE, stderr = TRUE), error = function(e) sprintf("ERROR: %s", conditionMessage(e)))
free_line <- tryCatch(system2("free", "-h", stdout = TRUE, stderr = TRUE), error = function(e) sprintf("ERROR: %s", conditionMessage(e)))

fit_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_fit_summary.csv"))
pair_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_pairwise_vb_vs_mcmc.csv"))
root_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_root_signoff_summary.csv"))
fit_group <- read_csv_safe(file.path(report_root, "tables", "campaign_fit_group_summary.csv"))
compare_delta <- read_csv_safe(file.path(report_root, "comparison_vs_reference", "tables", "qdesn_vs_reference_surface_delta.csv"))
seed_selection <- read_csv_safe(file.path(report_root, "tables", "campaign_mcmc_seed_selection.csv"))
seed_winners <- read_csv_safe(file.path(report_root, "tables", "campaign_mcmc_seed_winners.csv"))
completed_manifest <- read_json_safe(file.path(report_root, "manifest", "campaign_completed.json"))

selected_roots <- as.integer(preflight_manifest$selected_grid_summary$selected_roots %||% NA_integer_)[1L]
batch <- as.character(preflight_manifest$batch %||% get_arg("--batch", "unknown"))[1L]

launcher_mode <- as.character(launcher_meta$launcher_mode %||% NA_character_)
launcher_session <- as.character(launcher_meta$session_name %||% NA_character_)
launcher_pid <- suppressWarnings(as.integer(launcher_meta$launcher_pid %||% NA_integer_)[1L])
launcher_log <- as.character(launcher_meta$launcher_log %||% NA_character_)
launcher_session_live <- if (!is.na(launcher_session) && nzchar(launcher_session) && identical(launcher_mode, "tmux")) {
  identical(suppressWarnings(system2("tmux", c("has-session", "-t", launcher_session))), 0L)
} else {
  NA
}
launcher_pid_live <- if (is.finite(launcher_pid) && launcher_pid > 0L) {
  identical(suppressWarnings(system2("ps", c("-p", as.character(launcher_pid)))), 0L)
} else {
  NA
}
launcher_log_mtime <- if (!is.na(launcher_log) && nzchar(launcher_log) && file.exists(launcher_log)) {
  as.character(file.info(launcher_log)$mtime[1L])
} else {
  NA_character_
}
stale_threshold_seconds <- num_arg("--stale-threshold-seconds", 1800)
progress_files <- c(
  file.path(root_dirs, "manifest", "root_status.txt"),
  list.files(file.path(results_root, "roots"), pattern = "fit_status\\.txt$|progress_trace\\.csv$|progress_trace_long\\.csv$|health_summary\\.csv$", recursive = TRUE, full.names = TRUE),
  file.path(report_root, "tables", "campaign_progress.csv"),
  file.path(report_root, "tables", "campaign_progress_trace_long.csv"),
  if (!is.na(launcher_log) && nzchar(launcher_log)) launcher_log else character(0)
)
progress_files <- unique(progress_files[file.exists(progress_files)])
latest_progress_mtime <- if (length(progress_files)) {
  max(file.info(progress_files)$mtime, na.rm = TRUE)
} else {
  as.POSIXct(NA)
}
latest_progress_age_seconds <- if (!is.na(latest_progress_mtime)) {
  as.numeric(difftime(Sys.time(), latest_progress_mtime, units = "secs"))
} else {
  NA_real_
}

pct <- function(num, den) {
  if (!is.finite(den) || den <= 0) return("NA")
  sprintf("%.1f%%", 100 * (as.numeric(num) / as.numeric(den)))
}

n_materialized <- length(root_dirs)
n_success <- if ("SUCCESS" %in% names(root_status_tab)) as.integer(root_status_tab[["SUCCESS"]]) else 0L
n_running <- if ("RUNNING" %in% names(root_status_tab)) as.integer(root_status_tab[["RUNNING"]]) else 0L
n_fail <- if ("FAIL" %in% names(root_status_tab)) as.integer(root_status_tab[["FAIL"]]) else 0L
stale_status <- if (!length(progress_files)) {
  "NO_PROGRESS_FILES"
} else if (n_running > 0L && is.finite(latest_progress_age_seconds) && latest_progress_age_seconds > stale_threshold_seconds) {
  "STALE"
} else if (n_running > 0L) {
  "ACTIVE"
} else {
  "NO_RUNNING_ROOTS"
}

cat(sprintf("Snapshot: %s\n", as.character(Sys.time())))
cat(sprintf("Run tag: %s\n", run_tag))
cat(sprintf("Batch: %s\n", batch))
cat(sprintf("Outer report root: %s\n", outer_report_root))
cat(sprintf("Outer results root: %s\n", outer_results_root))
cat(sprintf("Campaign report root: %s\n", report_root))
cat(sprintf("Campaign results root: %s\n", results_root))
cat(sprintf("Selected roots: %s\n", as.character(selected_roots)))
cat(sprintf("Materialized roots: %d (%s)\n", n_materialized, pct(n_materialized, selected_roots)))
cat(sprintf("SUCCESS roots: %d (%s)\n", n_success, pct(n_success, selected_roots)))
cat(sprintf("RUNNING roots: %d (%s)\n", n_running, pct(n_running, selected_roots)))
cat(sprintf("FAIL roots: %d (%s)\n", n_fail, pct(n_fail, selected_roots)))
cat(sprintf("Fit summary rows: %d\n", nrow(fit_summary)))
cat(sprintf("Pair summary rows: %d\n", nrow(pair_summary)))
cat(sprintf("Root summary rows: %d\n", nrow(root_summary)))
cat(sprintf("Fit group rows: %d\n", nrow(fit_group)))
cat(sprintf("Surface delta rows: %d\n", nrow(compare_delta)))
cat(sprintf("MCMC seed selection rows: %d\n", nrow(seed_selection)))
cat(sprintf("MCMC seed winner rows: %d\n", nrow(seed_winners)))
cat(sprintf("Campaign completed manifest present: %s\n", if (length(completed_manifest)) "TRUE" else "FALSE"))
cat(sprintf("Index alignment manifests: %d\n", length(index_alignment_files)))
cat(sprintf("Forecast horizon summary files: %d\n", length(horizon_summary_files)))
cat(sprintf("Forecast horizon summary rows: %d\n", as.integer(horizon_summary_rows)))
cat(sprintf("Retained heavy artifact files: %d\n", nrow(heavy_all)))
cat(sprintf("Retained heavy artifact bytes: %.0f\n", heavy_bytes))
cat(sprintf("Results footprint: %s\n", du_line(results_root)))
cat(sprintf("Reports footprint: %s\n", du_line(report_root)))
cat(sprintf("Launcher mode: %s\n", launcher_mode))
cat(sprintf("Launcher session: %s\n", launcher_session))
cat(sprintf("Launcher session live: %s\n", as.character(launcher_session_live)))
cat(sprintf("Launcher pid: %s\n", as.character(launcher_pid)))
cat(sprintf("Launcher pid live: %s\n", as.character(launcher_pid_live)))
cat(sprintf("Launcher log: %s\n", launcher_log))
cat(sprintf("Launcher log mtime: %s\n", launcher_log_mtime))
cat(sprintf("Latest progress mtime: %s\n", as.character(latest_progress_mtime)))
cat(sprintf("Latest progress age seconds: %s\n", if (is.finite(latest_progress_age_seconds)) sprintf("%.0f", latest_progress_age_seconds) else "NA"))
cat(sprintf("Stale threshold seconds: %.0f\n", stale_threshold_seconds))
cat(sprintf("Stale status: %s\n", stale_status))

if (nrow(fit_summary) && "signoff_grade" %in% names(fit_summary)) {
  cat("\nfit_signoff_mix:\n")
  mix <- as.data.frame(table(fit_summary$signoff_grade), stringsAsFactors = FALSE)
  for (i in seq_len(nrow(mix))) {
    cat(sprintf("- %s: %d\n", as.character(mix$Var1[i]), as.integer(mix$Freq[i])))
  }
}

if (length(root_status_tab)) {
  cat("\nroot_status_distribution:\n")
  cat(paste(sprintf("- %s: %d", names(root_status_tab), as.integer(root_status_tab)), collapse = "\n"))
  cat("\n")
}

if (length(index_alignment_tab)) {
  cat("\nindex_alignment_distribution:\n")
  cat(paste(sprintf("- %s: %d", names(index_alignment_tab), as.integer(index_alignment_tab)), collapse = "\n"))
  cat("\n")
}

if (nrow(heavy_all)) {
  cat("\nretained_heavy_artifacts_by_name:\n")
  heavy_name <- basename(heavy_all$path)
  heavy_tab <- sort(tapply(heavy_all$bytes, heavy_name, length), decreasing = TRUE)
  cat(paste(sprintf("- %s: %d", names(heavy_tab), as.integer(heavy_tab)), collapse = "\n"))
  cat("\n")
}

cat("\ndisk_available:\n")
cat(paste(df_line, collapse = "\n"))
cat("\n\nmemory_available:\n")
cat(paste(free_line, collapse = "\n"))
cat("\n")
