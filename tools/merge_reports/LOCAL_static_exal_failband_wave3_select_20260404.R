#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

stage_filter <- "residual18"
candidate_filter <- ""
top_n <- 1L

for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--stage=", arg)) stage_filter <- sub("^--stage=", "", arg)
  if (grepl("^--candidate=", arg)) candidate_filter <- sub("^--candidate=", "", arg)
  if (grepl("^--top-n=", arg)) top_n <- as.integer(sub("^--top-n=", "", arg))
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
manifest_files <- Sys.glob(file.path(out_dir, "LOCAL_static_exal_failband_wave3_manifest_*.csv"))
if (!length(manifest_files)) quit(save = "no", status = 0)

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
if (!nrow(manifests)) quit(save = "no", status = 0)

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

if (length(summary_list)) {
  all_cols <- unique(unlist(lapply(summary_list, names), use.names = FALSE))
  summary_list <- lapply(summary_list, function(x) {
    for (nm in setdiff(all_cols, names(x))) x[[nm]] <- NA
    x[, all_cols, drop = FALSE]
  })
  summ <- do.call(rbind, summary_list)
  summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
  manifests$key2 <- paste(manifests$case_id, manifests$variant_tag, manifests$row_id, sep = "\r")
  idx <- match(manifests$key2, summ$key)
  manifests$gate_overall <- summ$gate_overall[idx]
  manifests$gate_overall[is.na(manifests$gate_overall) | !nzchar(manifests$gate_overall)] <- "MISSING"
}

candidate_summary <- do.call(rbind, lapply(split(manifests, manifests$candidate_id), function(df) {
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

candidate_summary <- candidate_summary[candidate_summary$done > 0, , drop = FALSE]
if (!nrow(candidate_summary)) quit(save = "no", status = 0)

candidate_summary <- candidate_summary[order(
  candidate_summary$missing,
  candidate_summary$FAIL,
  candidate_summary$WARN,
  -candidate_summary$PASS,
  candidate_summary$candidate_id
), , drop = FALSE]

top_n <- min(top_n, nrow(candidate_summary))
cat(paste(candidate_summary$candidate_id[seq_len(top_n)], collapse = "\n"))
cat("\n")
