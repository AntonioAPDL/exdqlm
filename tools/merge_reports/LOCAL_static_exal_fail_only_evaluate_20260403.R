#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_fail_only_schedule_20260403.csv")

if (!file.exists(schedule_path)) {
  stop(sprintf("schedule not found: %s", schedule_path))
}

schedule <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!nrow(schedule)) {
  stop("fail-only schedule is empty")
}

schedule$case_id <- paste0(gsub("^.*/results/", "results/", schedule$run_root), "::exal")
schedule$key <- paste(schedule$case_id, schedule$variant_tag, schedule$row_id, sep = "\r")

summary_files <- Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_*.csv"))
summary_list <- lapply(summary_files, function(p) {
  x <- tryCatch(utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(x)) return(NULL)
  x
})
summary_list <- Filter(Negate(is.null), summary_list)
summ <- if (length(summary_list)) {
  all_cols <- unique(unlist(lapply(summary_list, names), use.names = FALSE))
  aligned <- lapply(summary_list, function(x) {
    for (nm in setdiff(all_cols, names(x))) {
      x[[nm]] <- NA
    }
    x[, all_cols, drop = FALSE]
  })
  do.call(rbind, aligned)
} else {
  data.frame()
}

if (!nrow(summ)) {
  schedule$gate_overall <- "MISSING"
  schedule$healthy <- NA
  schedule$unhealthy_reason <- NA_character_
  schedule$rhs_collapse_flag <- NA
  schedule$ess_sigma_per1k_cand <- NA_real_
  schedule$ess_gamma_per1k_cand <- NA_real_
  schedule$acf1_sigma_cand <- NA_real_
  schedule$acf1_gamma_cand <- NA_real_
  schedule$geweke_sigma_cand <- NA_real_
  schedule$geweke_gamma_cand <- NA_real_
  schedule$runtime_sec_cand <- NA_real_
} else {
  summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
  idx <- match(schedule$key, summ$key)
  schedule$gate_overall <- summ$gate_overall[idx]
  schedule$healthy <- summ$healthy[idx]
  schedule$unhealthy_reason <- summ$unhealthy_reason[idx]
  schedule$rhs_collapse_flag <- summ$rhs_collapse_flag[idx]
  schedule$ess_sigma_per1k_cand <- summ$ess_sigma_per1k_cand[idx]
  schedule$ess_gamma_per1k_cand <- summ$ess_gamma_per1k_cand[idx]
  schedule$acf1_sigma_cand <- summ$acf1_sigma_cand[idx]
  schedule$acf1_gamma_cand <- summ$acf1_gamma_cand[idx]
  schedule$geweke_sigma_cand <- summ$geweke_sigma_cand[idx]
  schedule$geweke_gamma_cand <- summ$geweke_gamma_cand[idx]
  schedule$runtime_sec_cand <- summ$runtime_sec_cand[idx]
  schedule$gate_overall[is.na(schedule$gate_overall) | !nzchar(schedule$gate_overall)] <- "MISSING"
}

agg <- do.call(rbind, lapply(split(schedule, schedule$candidate_id), function(df) {
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
agg <- agg[order(agg$FAIL, agg$WARN, -agg$PASS, agg$candidate_id), , drop = FALSE]

latest_mtime <- "NA"
latest_file <- "NA"
if (length(summary_files)) {
  latest_file <- summary_files[order(file.info(summary_files)$mtime, decreasing = TRUE)][1]
  latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

cat(sprintf(
  "SUMMARY done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  sum(agg$done), sum(agg$missing), sum(agg$PASS), sum(agg$WARN), sum(agg$FAIL),
  latest_mtime, latest_file
))

detail <- schedule[, c(
  "candidate_id", "variant_tag", "row_id", "root_kind", "family", "tt",
  "tau_label", "gate_overall", "healthy", "unhealthy_reason",
  "rhs_collapse_flag", "ess_sigma_per1k_cand", "ess_gamma_per1k_cand",
  "acf1_sigma_cand", "acf1_gamma_cand", "geweke_sigma_cand",
  "geweke_gamma_cand", "runtime_sec_cand"
)]
detail <- detail[order(detail$candidate_id, detail$row_id), , drop = FALSE]
print(detail, row.names = FALSE)
cat("CANDIDATE_SUMMARY\n")
print(agg, row.names = FALSE)
