#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

stage_filter <- ""
candidate_filter <- ""

for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--stage=", arg)) stage_filter <- sub("^--stage=", "", arg)
  if (grepl("^--candidate=", arg)) candidate_filter <- sub("^--candidate=", "", arg)
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
manifest_files <- Sys.glob(file.path(out_dir, "LOCAL_static_exal_failband_wave3_manifest_*.csv"))

if (!length(manifest_files)) {
  stop("no wave-3 launch manifests found")
}

manifest_list <- lapply(manifest_files, function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x$manifest_path <- path
  x
})
manifests <- do.call(rbind, manifest_list)
manifests <- manifests[order(manifests$ts, manifests$manifest_path), , drop = FALSE]
manifests$key <- paste(manifests$stage, manifests$candidate_id, manifests$scope_label, manifests$row_id, manifests$variant_tag, sep = "\r")
manifests <- manifests[!duplicated(manifests$key, fromLast = TRUE), , drop = FALSE]

if (nzchar(stage_filter)) {
  manifests <- manifests[manifests$stage == stage_filter, , drop = FALSE]
}
if (nzchar(candidate_filter)) {
  wanted <- unlist(strsplit(candidate_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted <- wanted[nzchar(wanted)]
  manifests <- manifests[manifests$candidate_id %in% wanted, , drop = FALSE]
}
if (!nrow(manifests)) stop("wave-3 manifest subset is empty")

summary_files <- unique(file.path(
  out_dir,
  sprintf("LOCAL_static_case_health_summary_%s.csv", unique(manifests$variant_tag))
))
summary_files <- summary_files[file.exists(summary_files)]

summary_list <- lapply(summary_files, function(path) {
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
})
summary_list <- Filter(Negate(is.null), summary_list)

manifests$case_id <- paste0(gsub("^.*/results/", "results/", manifests$run_root), "::exal")
manifests$gate_overall <- "MISSING"
manifests$healthy <- NA
manifests$unhealthy_reason <- NA_character_
manifests$rhs_collapse_flag <- NA
manifests$ess_sigma_per1k_cand <- NA_real_
manifests$ess_gamma_per1k_cand <- NA_real_
manifests$runtime_sec_cand <- NA_real_

if (length(summary_list)) {
  all_cols <- unique(unlist(lapply(summary_list, names), use.names = FALSE))
  summary_list <- lapply(summary_list, function(x) {
    for (nm in setdiff(all_cols, names(x))) x[[nm]] <- NA
    x[, all_cols, drop = FALSE]
  })
  summ <- do.call(rbind, summary_list)
  manifests$key2 <- paste(manifests$case_id, manifests$variant_tag, manifests$row_id, sep = "\r")
  summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
  idx <- match(manifests$key2, summ$key)
  manifests$gate_overall <- summ$gate_overall[idx]
  manifests$healthy <- summ$healthy[idx]
  manifests$unhealthy_reason <- summ$unhealthy_reason[idx]
  manifests$rhs_collapse_flag <- summ$rhs_collapse_flag[idx]
  manifests$ess_sigma_per1k_cand <- summ$ess_sigma_per1k_cand[idx]
  manifests$ess_gamma_per1k_cand <- summ$ess_gamma_per1k_cand[idx]
  manifests$runtime_sec_cand <- summ$runtime_sec_cand[idx]
  manifests$gate_overall[is.na(manifests$gate_overall) | !nzchar(manifests$gate_overall)] <- "MISSING"
}

aggregate_stage <- function(df) {
  data.frame(
    stage = df$stage[1],
    total = nrow(df),
    done = sum(df$gate_overall != "MISSING"),
    missing = sum(df$gate_overall == "MISSING"),
    PASS = sum(df$gate_overall == "PASS"),
    WARN = sum(df$gate_overall == "WARN"),
    FAIL = sum(df$gate_overall == "FAIL"),
    resolved = sum(df$gate_overall %in% c("PASS", "WARN")),
    stringsAsFactors = FALSE
  )
}

aggregate_candidate <- function(df) {
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
}

stage_summary <- do.call(rbind, lapply(split(manifests, manifests$stage), aggregate_stage))
stage_summary <- stage_summary[order(match(stage_summary$stage, c("residual18", "confirm30"))), , drop = FALSE]

candidate_summary <- do.call(rbind, lapply(split(manifests, paste(manifests$stage, manifests$candidate_id, sep = "\r")), aggregate_candidate))
candidate_summary <- candidate_summary[order(
  match(candidate_summary$stage, c("residual18", "confirm30")),
  candidate_summary$missing,
  candidate_summary$FAIL,
  candidate_summary$WARN,
  -candidate_summary$PASS,
  candidate_summary$candidate_id
), , drop = FALSE]

row_coverage <- do.call(rbind, lapply(split(manifests, paste(manifests$stage, manifests$scope_label, manifests$row_id, sep = "\r")), function(df) {
  data.frame(
    stage = df$stage[1],
    scope_label = df$scope_label[1],
    row_id = df$row_id[1],
    family = df$family[1],
    tt = df$tt[1],
    tau = df$tau_label[1],
    resolved_by_candidates = sum(df$gate_overall %in% c("PASS", "WARN")),
    fail_by_candidates = sum(df$gate_overall == "FAIL"),
    missing_by_candidates = sum(df$gate_overall == "MISSING"),
    stringsAsFactors = FALSE
  )
}))
row_coverage <- row_coverage[order(
  match(row_coverage$stage, c("residual18", "confirm30")),
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

summary_stage_label <- if (nzchar(stage_filter)) stage_filter else "all"
cat(sprintf(
  "SUMMARY stage=%s done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  summary_stage_label,
  sum(candidate_summary$done),
  sum(candidate_summary$missing),
  sum(candidate_summary$PASS),
  sum(candidate_summary$WARN),
  sum(candidate_summary$FAIL),
  latest_mtime,
  latest_file
))

cat("STAGE_SUMMARY\n")
print(stage_summary, row.names = FALSE)

cat("CANDIDATE_SUMMARY\n")
print(candidate_summary, row.names = FALSE)

remaining <- manifests[manifests$gate_overall %in% c("MISSING", "FAIL"),
  c("stage", "candidate_id", "scope_label", "row_id", "family", "tt", "tau_label", "gate_overall", "healthy", "unhealthy_reason"),
  drop = FALSE
]
remaining <- remaining[order(
  match(remaining$stage, c("residual18", "confirm30")),
  remaining$candidate_id,
  remaining$scope_label,
  remaining$row_id
), , drop = FALSE]
cat("UNRESOLVED_DETAIL\n")
if (nrow(remaining)) {
  print(remaining, row.names = FALSE)
} else {
  cat("none\n")
}

cat("ROW_COVERAGE\n")
print(row_coverage, row.names = FALSE)
