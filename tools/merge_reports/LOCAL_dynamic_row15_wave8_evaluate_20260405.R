#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

phase_filter <- ""
for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--phase=", arg)) phase_filter <- sub("^--phase=", "", arg)
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
matrix_path <- file.path(out_dir, "LOCAL_dynamic_row15_wave8_matrix_20260405.csv")

if (!file.exists(matrix_path)) {
  stop(sprintf("matrix not found: %s", matrix_path))
}

schedule <- utils::read.csv(matrix_path, stringsAsFactors = FALSE, check.names = FALSE)
if (nzchar(phase_filter)) {
  wanted <- unlist(strsplit(phase_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted <- wanted[nzchar(wanted)]
  schedule <- schedule[schedule$phase %in% wanted, , drop = FALSE]
}
if (!nrow(schedule)) stop("dynamic row15 wave-8 schedule subset is empty")

schedule$summary_path <- file.path(out_dir, sprintf("LOCAL_dynamic_case_health_summary_%s.csv", schedule$variant_tag))
schedule$gate_overall <- "MISSING"
schedule$healthy <- NA
schedule$unhealthy_reason <- NA_character_
schedule$runtime_sec <- NA_real_

for (i in seq_len(nrow(schedule))) {
  path <- schedule$summary_path[i]
  if (!file.exists(path)) next
  x <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(x) || !nrow(x)) next
  schedule$gate_overall[i] <- x$gate_overall[1]
  if ("healthy" %in% names(x)) schedule$healthy[i] <- x$healthy[1]
  if ("unhealthy_reason" %in% names(x)) schedule$unhealthy_reason[i] <- x$unhealthy_reason[1]
  if ("run_time_sec" %in% names(x)) schedule$runtime_sec[i] <- suppressWarnings(as.numeric(x$run_time_sec[1]))
}

stage_summary <- do.call(rbind, lapply(split(schedule, schedule$phase), function(df) {
  data.frame(
    phase = df$phase[1],
    total = nrow(df),
    done = sum(df$gate_overall != "MISSING"),
    missing = sum(df$gate_overall == "MISSING"),
    PASS = sum(df$gate_overall == "PASS"),
    WARN = sum(df$gate_overall == "WARN"),
    FAIL = sum(df$gate_overall == "FAIL"),
    resolved = sum(df$gate_overall %in% c("PASS", "WARN")),
    stringsAsFactors = FALSE
  )
}))

candidate_summary <- schedule[, c("phase", "config_id", "variant_tag", "gate_overall", "healthy", "runtime_sec"), drop = FALSE]
candidate_summary <- candidate_summary[order(candidate_summary$config_id), , drop = FALSE]

rank_gate <- function(g) c(PASS = 3L, WARN = 2L, FAIL = 1L, MISSING = 0L)[g]
schedule$rank <- rank_gate(schedule$gate_overall)
row_best <- schedule[order(-schedule$rank, schedule$config_id), , drop = FALSE][1, c("queue_id", "config_id", "variant_tag", "gate_overall", "healthy"), drop = FALSE]

latest_mtime <- "NA"
latest_file <- "NA"
existing <- schedule$summary_path[file.exists(schedule$summary_path)]
if (length(existing)) {
  latest_file <- existing[order(file.info(existing)$mtime, decreasing = TRUE)][1]
  latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

cat(sprintf(
  "SUMMARY phase=%s done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  if (nzchar(phase_filter)) phase_filter else "all",
  sum(schedule$gate_overall != "MISSING"),
  sum(schedule$gate_overall == "MISSING"),
  sum(schedule$gate_overall == "PASS"),
  sum(schedule$gate_overall == "WARN"),
  sum(schedule$gate_overall == "FAIL"),
  latest_mtime,
  latest_file
))

cat("PHASE_SUMMARY\n")
print(stage_summary, row.names = FALSE)

cat("CANDIDATE_SUMMARY\n")
print(candidate_summary, row.names = FALSE)

cat("ROW_BEST\n")
print(row_best, row.names = FALSE)
