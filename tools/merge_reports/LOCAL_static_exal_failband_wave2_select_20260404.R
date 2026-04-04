#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

stage_filter <- ""
candidate_filter <- ""
top_n <- 1L

for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--stage=", arg)) stage_filter <- sub("^--stage=", "", arg)
  if (grepl("^--candidate=", arg)) candidate_filter <- sub("^--candidate=", "", arg)
  if (grepl("^--top-n=", arg)) top_n <- as.integer(sub("^--top-n=", "", arg))
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_schedule_20260404.csv")
if (!file.exists(schedule_path)) stop(sprintf("schedule not found: %s", schedule_path))

schedule <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (nzchar(stage_filter)) {
  schedule <- schedule[schedule$stage == stage_filter, , drop = FALSE]
}
if (nzchar(candidate_filter)) {
  wanted <- unlist(strsplit(candidate_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted <- wanted[nzchar(wanted)]
  schedule <- schedule[schedule$candidate_id %in% wanted, , drop = FALSE]
}
if (!nrow(schedule)) quit(save = "no", status = 0)

summary_files <- list.files(out_dir, pattern = "^LOCAL_static_case_health_summary_failband2_.*\\.csv$", full.names = TRUE)
summ <- if (length(summary_files)) {
  do.call(rbind, lapply(summary_files, function(path) utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)))
} else {
  data.frame()
}

schedule$case_id <- paste0(gsub("^.*/results/", "results/", schedule$run_root), "::exal")
schedule$key <- paste(schedule$case_id, schedule$variant_tag, schedule$row_id, sep = "\r")
schedule$gate_overall <- "MISSING"
if (nrow(summ)) {
  summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
  idx <- match(schedule$key, summ$key)
  schedule$gate_overall <- summ$gate_overall[idx]
  schedule$gate_overall[is.na(schedule$gate_overall) | !nzchar(schedule$gate_overall)] <- "MISSING"
}

candidate_summary <- do.call(rbind, lapply(split(schedule, schedule$candidate_id), function(df) {
  data.frame(
    candidate_id = df$candidate_id[1],
    total = nrow(df),
    done = sum(df$gate_overall != "MISSING"),
    missing = sum(df$gate_overall == "MISSING"),
    PASS = sum(df$gate_overall == "PASS"),
    WARN = sum(df$gate_overall == "WARN"),
    FAIL = sum(df$gate_overall == "FAIL"),
    stringsAsFactors = FALSE
  )
}))

candidate_summary <- candidate_summary[order(
  candidate_summary$missing,
  candidate_summary$FAIL,
  candidate_summary$WARN,
  -candidate_summary$PASS,
  candidate_summary$candidate_id
), , drop = FALSE]

candidate_summary <- candidate_summary[candidate_summary$done > 0, , drop = FALSE]
if (!nrow(candidate_summary)) quit(save = "no", status = 0)

top_n <- min(top_n, nrow(candidate_summary))
cat(paste(candidate_summary$candidate_id[seq_len(top_n)], collapse = "\n"))
cat("\n")
