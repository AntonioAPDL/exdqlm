#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_schedule_20260403.csv")

if (!file.exists(schedule_path)) {
  stop(sprintf("schedule not found: %s", schedule_path))
}

schedule <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!nrow(schedule)) {
  stop("refresh schedule is empty")
}

schedule$case_id <- paste0(gsub("^.*/results/", "results/", schedule$run_root), "::exal")
schedule$key <- paste(schedule$case_id, schedule$variant_tag, schedule$row_id, sep = "\r")

summary_files <- unique(file.path(
  out_dir,
  sprintf("LOCAL_static_case_health_summary_%s.csv", unique(schedule$variant_tag))
))
summary_files <- summary_files[file.exists(summary_files)]

summary_list <- lapply(summary_files, function(p) {
  tryCatch(utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
})
summary_list <- Filter(Negate(is.null), summary_list)
summ <- if (length(summary_list)) {
  all_cols <- unique(unlist(lapply(summary_list, names), use.names = FALSE))
  aligned <- lapply(summary_list, function(x) {
    for (nm in setdiff(all_cols, names(x))) x[[nm]] <- NA
    x[, all_cols, drop = FALSE]
  })
  do.call(rbind, aligned)
} else {
  data.frame()
}

schedule$gate_overall <- "MISSING"
schedule$healthy <- NA
schedule$unhealthy_reason <- NA_character_
schedule$rhs_collapse_flag <- NA
schedule$ess_sigma_per1k_cand <- NA_real_
schedule$ess_gamma_per1k_cand <- NA_real_
schedule$runtime_sec_cand <- NA_real_

if (nrow(summ)) {
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

aggregate_scope <- function(df) {
  data.frame(
    scope_label = df$scope_label[1],
    variant_tag = df$variant_tag[1],
    total = nrow(df),
    done = sum(df$gate_overall != "MISSING"),
    missing = sum(df$gate_overall == "MISSING"),
    PASS = sum(df$gate_overall == "PASS"),
    WARN = sum(df$gate_overall == "WARN"),
    FAIL = sum(df$gate_overall == "FAIL"),
    stringsAsFactors = FALSE
  )
}

scope_summary <- do.call(rbind, lapply(split(schedule, schedule$scope_label), aggregate_scope))
scope_summary <- scope_summary[order(scope_summary$scope_label), , drop = FALSE]
overall <- data.frame(
  scope_label = "overall",
  variant_tag = "combined",
  total = nrow(schedule),
  done = sum(schedule$gate_overall != "MISSING"),
  missing = sum(schedule$gate_overall == "MISSING"),
  PASS = sum(schedule$gate_overall == "PASS"),
  WARN = sum(schedule$gate_overall == "WARN"),
  FAIL = sum(schedule$gate_overall == "FAIL"),
  stringsAsFactors = FALSE
)

latest_mtime <- "NA"
latest_file <- "NA"
if (length(summary_files)) {
  latest_file <- summary_files[order(file.info(summary_files)$mtime, decreasing = TRUE)][1]
  latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

cat(sprintf(
  "SUMMARY done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  overall$done, overall$missing, overall$PASS, overall$WARN, overall$FAIL,
  latest_mtime, latest_file
))

cat("SCOPE_SUMMARY\n")
print(scope_summary, row.names = FALSE)

remaining <- schedule[schedule$gate_overall == "MISSING" | schedule$gate_overall == "FAIL",
  c("scope_label", "row_id", "family", "tt", "tau_label", "variant_tag", "gate_overall", "healthy", "unhealthy_reason"),
  drop = FALSE
]
remaining <- remaining[order(remaining$scope_label, remaining$row_id), , drop = FALSE]
cat("REMAINING_DETAIL\n")
if (nrow(remaining)) {
  print(remaining, row.names = FALSE)
} else {
  cat("none\n")
}
