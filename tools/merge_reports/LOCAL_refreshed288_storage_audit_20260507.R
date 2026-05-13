#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260507_p90_dynamic72_qdesn_comparable_fresh_v1"))
run_root <- arg_value("run-root", file.path(repo_root, "tools/merge_reports", sprintf("full288_refreshed288_%s", run_tag)))
report_dir <- arg_value("report-dir", file.path(repo_root, "reports/static_exal_tuning_20260507"))
out_csv <- arg_value("out-csv", file.path(report_dir, sprintf("refreshed288_storage_audit_%s.csv", run_tag)))
out_md <- arg_value("out-md", file.path(report_dir, sprintf("refreshed288_storage_audit_%s.md", run_tag)))
top_n <- as.integer(arg_value("top-n", "50"))

dir_size_bytes <- function(path) {
  if (!dir.exists(path)) return(NA_real_)
  files <- list.files(path, recursive = TRUE, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  files <- files[file.exists(files) & !dir.exists(files)]
  sum(file.info(files)$size, na.rm = TRUE)
}

classify_file <- function(path) {
  rel <- sub(paste0("^", normalizePath(run_root, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(path, winslash = "/", mustWork = FALSE))
  ext <- tolower(tools::file_ext(path))
  if (grepl("^configs/row_[0-9]+_run_config\\.rds$", rel)) return("allowed_config_rds")
  if (grepl("^plot_summaries/.*\\.csv$", rel)) return("compact_plot_summary")
  if (grepl("^parameter_summaries/.*\\.csv$", rel)) return("compact_parameter_summary")
  if (grepl("^rows/.*\\.csv$", rel)) return("row_status")
  if (grepl("^health/.*\\.csv$", rel)) return("health")
  if (grepl("^metrics/.*\\.csv$", rel)) return("metrics")
  if (ext %in% c("rds", "rda", "rdata")) return("forbidden_binary_payload")
  "other"
}

if (!dir.exists(run_root)) {
  stop("Run root does not exist: ", run_root, call. = FALSE)
}

files <- list.files(run_root, recursive = TRUE, all.files = TRUE, full.names = TRUE, no.. = TRUE)
files <- files[file.exists(files) & !dir.exists(files)]
info <- file.info(files)
audit <- data.frame(
  path = normalizePath(files, winslash = "/", mustWork = FALSE),
  relative_path = sub(paste0("^", normalizePath(run_root, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(files, winslash = "/", mustWork = FALSE)),
  size_bytes = as.numeric(info$size),
  class = vapply(files, classify_file, character(1)),
  stringsAsFactors = FALSE
)
audit <- audit[order(-audit$size_bytes, audit$relative_path), , drop = FALSE]

summary <- as.data.frame(table(audit$class), stringsAsFactors = FALSE)
names(summary) <- c("class", "file_count")
summary$size_bytes <- vapply(summary$class, function(cls) sum(audit$size_bytes[audit$class == cls], na.rm = TRUE), numeric(1))

forbidden_count <- sum(audit$class == "forbidden_binary_payload")
status <- if (forbidden_count == 0L) "PASS" else "FAIL"

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(audit, out_csv, row.names = FALSE)

md <- c(
  "# refreshed288 Storage Audit",
  "",
  sprintf("- Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Run root: `%s`", run_root),
  sprintf("- Total size bytes: `%s`", format(dir_size_bytes(run_root), scientific = FALSE, trim = TRUE)),
  sprintf("- Overall status: `%s`", status),
  "",
  "## Class Summary",
  "",
  "| Class | Files | Bytes |",
  "| --- | ---: | ---: |"
)
md <- c(md, vapply(seq_len(nrow(summary)), function(i) {
  sprintf("| `%s` | %d | %s |", summary$class[i], summary$file_count[i], format(summary$size_bytes[i], scientific = FALSE, trim = TRUE))
}, character(1)))
md <- c(
  md,
  "",
  sprintf("## Largest %d Files", min(top_n, nrow(audit))),
  "",
  "| Bytes | Class | Path |",
  "| ---: | --- | --- |"
)
md <- c(md, vapply(seq_len(min(top_n, nrow(audit))), function(i) {
  sprintf("| %s | `%s` | `%s` |", format(audit$size_bytes[i], scientific = FALSE, trim = TRUE), audit$class[i], audit$relative_path[i])
}, character(1)))
md <- c(md, "", sprintf("CSV details: `%s`", out_csv), "")
writeLines(md, out_md)

cat(sprintf("storage_audit_status=%s files=%d forbidden_binary_payloads=%d\n", status, nrow(audit), forbidden_count))
cat(sprintf("wrote_csv=%s\n", out_csv))
cat(sprintf("wrote_md=%s\n", out_md))
if (!identical(status, "PASS")) {
  stop("Storage audit found forbidden binary payloads.", call. = FALSE)
}
