#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

stage_filter <- ""

for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--stage=", arg)) stage_filter <- sub("^--stage=", "", arg)
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_schedule_20260404.csv")

if (!file.exists(schedule_path)) {
  stop(sprintf("schedule not found: %s", schedule_path))
}

schedule <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (nzchar(stage_filter)) {
  wanted <- unlist(strsplit(stage_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted <- wanted[nzchar(wanted)]
  schedule <- schedule[schedule$stage %in% wanted, , drop = FALSE]
}
if (!nrow(schedule)) stop("wave-6 schedule subset is empty")

schedule$case_id <- paste0(gsub("^.*/results/", "results/", schedule$run_root), "::exal")
schedule$key <- paste(schedule$case_id, schedule$variant_tag, schedule$row_id, sep = "\r")

summary_files <- unique(file.path(
  out_dir,
  sprintf("LOCAL_static_case_health_summary_%s.csv", unique(schedule$variant_tag))
))
summary_files <- summary_files[file.exists(summary_files)]

summary_list <- lapply(summary_files, function(path) {
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
})
summary_list <- Filter(Negate(is.null), summary_list)

schedule$gate_overall <- "MISSING"
schedule$healthy <- NA
schedule$unhealthy_reason <- NA_character_

if (length(summary_list)) {
  all_cols <- unique(unlist(lapply(summary_list, names), use.names = FALSE))
  summary_list <- lapply(summary_list, function(x) {
    for (nm in setdiff(all_cols, names(x))) x[[nm]] <- NA
    x[, all_cols, drop = FALSE]
  })
  summ <- do.call(rbind, summary_list)
  summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
  idx <- match(schedule$key, summ$key)
  schedule$gate_overall <- summ$gate_overall[idx]
  schedule$healthy <- summ$healthy[idx]
  schedule$unhealthy_reason <- summ$unhealthy_reason[idx]
  schedule$gate_overall[is.na(schedule$gate_overall) | !nzchar(schedule$gate_overall)] <- "MISSING"
}

stage_levels <- unique(schedule$stage)
stage_summary <- do.call(rbind, lapply(stage_levels, function(st) {
  df <- schedule[schedule$stage == st, , drop = FALSE]
  data.frame(
    stage = st,
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

candidate_summary <- do.call(rbind, lapply(split(schedule, paste(schedule$stage, schedule$candidate_id, sep = "\r")), function(df) {
  data.frame(
    stage = df$stage[1],
    candidate_id = df$candidate_id[1],
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
candidate_summary <- candidate_summary[order(candidate_summary$stage, candidate_summary$missing, candidate_summary$FAIL, candidate_summary$candidate_id), , drop = FALSE]

rank_gate <- function(g) c(PASS = 3L, WARN = 2L, FAIL = 1L, MISSING = 0L)[g]
schedule$rank <- rank_gate(schedule$gate_overall)
schedule$jump_dist <- abs(schedule$p_global_eta_jump - 0.085)
schedule$scale_dist <- abs(schedule$global_eta_jump_scale - 1.0)

row_best <- do.call(rbind, lapply(split(schedule, paste(schedule$scope_label, schedule$row_id, sep = "\r")), function(df) {
  ord <- order(-df$rank, df$jump_dist, df$scale_dist, df$stage_order, df$candidate_id)
  best <- df[ord[1], , drop = FALSE]
  data.frame(
    scope_label = best$scope_label,
    row_id = best$row_id,
    family = best$family,
    tt = best$tt,
    tau = best$tau,
    best_stage = best$stage,
    best_candidate_id = best$candidate_id,
    best_gate = best$gate_overall,
    stringsAsFactors = FALSE
  )
}))
row_best <- row_best[order(row_best$scope_label, row_best$row_id), , drop = FALSE]

latest_mtime <- "NA"
latest_file <- "NA"
if (length(summary_files)) {
  latest_file <- summary_files[order(file.info(summary_files)$mtime, decreasing = TRUE)][1]
  latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

cat(sprintf(
  "SUMMARY stage=%s done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  if (nzchar(stage_filter)) stage_filter else "all",
  sum(schedule$gate_overall != "MISSING"),
  sum(schedule$gate_overall == "MISSING"),
  sum(schedule$gate_overall == "PASS"),
  sum(schedule$gate_overall == "WARN"),
  sum(schedule$gate_overall == "FAIL"),
  latest_mtime,
  latest_file
))

cat("STAGE_SUMMARY\n")
print(stage_summary, row.names = FALSE)

cat("CANDIDATE_SUMMARY\n")
print(candidate_summary, row.names = FALSE)

remaining <- schedule[schedule$gate_overall %in% c("MISSING", "FAIL"),
  c("stage", "candidate_id", "scope_label", "row_id", "family", "tt", "tau", "gate_overall", "healthy", "unhealthy_reason"),
  drop = FALSE
]
remaining <- remaining[order(remaining$stage, remaining$candidate_id, remaining$scope_label, remaining$row_id), , drop = FALSE]
cat("UNRESOLVED_DETAIL\n")
if (nrow(remaining)) {
  print(remaining, row.names = FALSE)
} else {
  cat("none\n")
}

cat("ROW_BEST\n")
print(row_best, row.names = FALSE)
