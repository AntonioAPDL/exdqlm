#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_refreshed288()

manifest_path <- safe_chr_refreshed288(args$manifest, paths$full_manifest)
manifest_kind <- if (grepl("smoke_manifest", basename(manifest_path), fixed = TRUE)) "smoke" else "full"
status_path <- safe_chr_refreshed288(args$status, if (identical(manifest_kind, "smoke")) paths$smoke_manifest_status else paths$full_manifest_status)
phase_path <- safe_chr_refreshed288(args$phase, if (identical(manifest_kind, "smoke")) paths$smoke_phase_summary else paths$full_phase_summary)
method_path <- safe_chr_refreshed288(args$method, if (identical(manifest_kind, "smoke")) paths$smoke_method_summary else paths$full_method_summary)
report_path <- safe_chr_refreshed288(args$report, if (identical(manifest_kind, "smoke")) paths$smoke_report else paths$full_report)

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
status_df <- if (file.exists(status_path)) utils::read.csv(status_path, stringsAsFactors = FALSE, check.names = FALSE) else manifest
phase_df <- if (file.exists(phase_path)) utils::read.csv(phase_path, stringsAsFactors = FALSE, check.names = FALSE) else data.frame()
method_df <- if (file.exists(method_path)) utils::read.csv(method_path, stringsAsFactors = FALSE, check.names = FALSE) else data.frame()

ensure_dir_refreshed288(dirname(report_path))

md_table_refreshed288 <- function(df) {
  if (!nrow(df)) return(c("| none |", "|---|"))
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  body <- apply(df, 1L, function(x) paste0("| ", paste(as.character(x), collapse = " | "), " |"))
  c(hdr, sep, body)
}

total_rows <- nrow(manifest)
completed <- if ("status_current" %in% names(status_df)) sum(status_df$status_current %in% c("done", "skipped_existing", "failed_runtime")) else 0L
running <- if ("status_current" %in% names(status_df)) sum(status_df$status_current == "running") else 0L
not_started <- if ("status_current" %in% names(status_df)) sum(status_df$status_current == "not_started") else total_rows
pass <- if ("gate_current" %in% names(status_df)) sum(status_df$gate_current == "PASS") else 0L
warn <- if ("gate_current" %in% names(status_df)) sum(status_df$gate_current == "WARN") else 0L
fail <- if ("gate_current" %in% names(status_df)) sum(status_df$gate_current == "FAIL") else 0L
healthy <- if ("healthy_current" %in% names(status_df)) sum(status_df$healthy_current) else 0L

overview <- data.frame(
  total = total_rows,
  completed = completed,
  running = running,
  not_started = not_started,
  pass = pass,
  warn = warn,
  fail = fail,
  healthy = healthy,
  pct_completed = sprintf("%.1f", 100 * completed / total_rows),
  pct_active_or_done = sprintf("%.1f", 100 * (completed + running) / total_rows),
  stringsAsFactors = FALSE
)

lines <- c(
  sprintf("# Refreshed288 %s Status", if (identical(manifest_kind, "smoke")) "Smoke" else "Full"),
  "",
  sprintf("Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Overview",
  "",
  md_table_refreshed288(overview),
  "",
  "## Phase Summary",
  "",
  md_table_refreshed288(phase_df),
  "",
  "## Method Summary",
  "",
  md_table_refreshed288(method_df[, intersect(c("root_kind", "prior_semantics", "model", "inference", "total", "completed", "running", "not_started", "pass", "warn", "fail", "healthy", "pct_completed"), names(method_df)), drop = FALSE]),
  ""
)

writeLines(lines, con = report_path)
cat(sprintf("report=%s\n", report_path))
