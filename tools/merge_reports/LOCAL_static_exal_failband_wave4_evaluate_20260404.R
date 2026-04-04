#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

candidate_filter <- ""
row_filter <- ""

for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--candidate=", arg)) candidate_filter <- sub("^--candidate=", "", arg)
  if (grepl("^--row-ids=", arg)) row_filter <- sub("^--row-ids=", "", arg)
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_schedule_20260404.csv")

if (!file.exists(schedule_path)) {
  stop(sprintf("schedule not found: %s", schedule_path))
}

schedule <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (nzchar(candidate_filter)) {
  wanted <- unlist(strsplit(candidate_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted <- wanted[nzchar(wanted)]
  schedule <- schedule[schedule$candidate_id %in% wanted, , drop = FALSE]
}
if (nzchar(row_filter)) {
  wanted_rows <- unlist(strsplit(row_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted_rows <- as.integer(wanted_rows[nzchar(wanted_rows)])
  schedule <- schedule[schedule$row_id %in% wanted_rows, , drop = FALSE]
}
if (!nrow(schedule)) stop("wave-4 schedule subset is empty")

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
schedule$rhs_collapse_flag <- NA
schedule$ess_sigma_per1k_cand <- NA_real_
schedule$ess_gamma_per1k_cand <- NA_real_
schedule$runtime_sec_cand <- NA_real_

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
  schedule$rhs_collapse_flag <- summ$rhs_collapse_flag[idx]
  schedule$ess_sigma_per1k_cand <- summ$ess_sigma_per1k_cand[idx]
  schedule$ess_gamma_per1k_cand <- summ$ess_gamma_per1k_cand[idx]
  schedule$runtime_sec_cand <- summ$runtime_sec_cand[idx]
  schedule$gate_overall[is.na(schedule$gate_overall) | !nzchar(schedule$gate_overall)] <- "MISSING"
}

stage_summary <- data.frame(
  stage = "repair9",
  total = nrow(schedule),
  done = sum(schedule$gate_overall != "MISSING"),
  missing = sum(schedule$gate_overall == "MISSING"),
  PASS = sum(schedule$gate_overall == "PASS"),
  WARN = sum(schedule$gate_overall == "WARN"),
  FAIL = sum(schedule$gate_overall == "FAIL"),
  resolved = sum(schedule$gate_overall %in% c("PASS", "WARN")),
  stringsAsFactors = FALSE
)

candidate_summary <- do.call(rbind, lapply(split(schedule, schedule$candidate_id), function(df) {
  data.frame(
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
candidate_summary <- candidate_summary[order(
  candidate_summary$missing,
  candidate_summary$FAIL,
  candidate_summary$WARN,
  -candidate_summary$PASS,
  candidate_summary$candidate_id
), , drop = FALSE]

row_coverage <- do.call(rbind, lapply(split(schedule, paste(schedule$scope_label, schedule$row_id, sep = "\r")), function(df) {
  data.frame(
    scope_label = df$scope_label[1],
    row_id = df$row_id[1],
    family = df$family[1],
    tt = df$tt[1],
    tau = df$tau[1],
    resolved_by_candidates = sum(df$gate_overall %in% c("PASS", "WARN")),
    fail_by_candidates = sum(df$gate_overall == "FAIL"),
    missing_by_candidates = sum(df$gate_overall == "MISSING"),
    stringsAsFactors = FALSE
  )
}))
row_coverage <- row_coverage[order(
  row_coverage$resolved_by_candidates,
  -row_coverage$fail_by_candidates,
  row_coverage$scope_label,
  row_coverage$row_id
), , drop = FALSE]

latest_mtime <- "NA"
latest_file <- "NA"
if (length(summary_files)) {
  latest_file <- summary_files[order(file.info(summary_files)$mtime, decreasing = TRUE)][1]
  latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

cat(sprintf(
  "SUMMARY stage=repair9 done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  stage_summary$done,
  stage_summary$missing,
  stage_summary$PASS,
  stage_summary$WARN,
  stage_summary$FAIL,
  latest_mtime,
  latest_file
))

cat("STAGE_SUMMARY\n")
print(stage_summary, row.names = FALSE)

cat("CANDIDATE_SUMMARY\n")
print(candidate_summary, row.names = FALSE)

remaining <- schedule[schedule$gate_overall %in% c("MISSING", "FAIL"),
  c("candidate_id", "scope_label", "row_id", "family", "tt", "tau", "gate_overall", "healthy", "unhealthy_reason"),
  drop = FALSE
]
remaining <- remaining[order(remaining$candidate_id, remaining$scope_label, remaining$row_id), , drop = FALSE]
cat("UNRESOLVED_DETAIL\n")
if (nrow(remaining)) {
  print(remaining, row.names = FALSE)
} else {
  cat("none\n")
}

cat("ROW_COVERAGE\n")
print(row_coverage, row.names = FALSE)
