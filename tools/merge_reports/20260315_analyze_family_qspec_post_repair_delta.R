#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) args[[1L]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

run_git_show <- function(repo_root, path) {
  out <- system2(
    "git",
    c("-C", repo_root, "show", paste0("HEAD:", path)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    stop("git show failed for ", path, call. = FALSE)
  }
  out
}

read_git_tsv <- function(repo_root, path) {
  txt <- run_git_show(repo_root, path)
  utils::read.delim(
    text = txt,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

read_current_tsv <- function(repo_root, path) {
  fq_read_tsv(file.path(repo_root, path))
}

count_reason_tokens <- function(df) {
  if (!nrow(df)) {
    return(data.frame(signoff_reason = character(0), count = integer(0), stringsAsFactors = FALSE))
  }
  tokens <- unlist(strsplit(df$signoff_reason %||% "", ";", fixed = TRUE), use.names = FALSE)
  tokens <- trimws(tokens)
  tokens <- tokens[nzchar(tokens)]
  if (!length(tokens)) {
    return(data.frame(signoff_reason = character(0), count = integer(0), stringsAsFactors = FALSE))
  }
  tab <- sort(table(tokens), decreasing = TRUE)
  data.frame(
    signoff_reason = names(tab),
    count = as.integer(tab),
    stringsAsFactors = FALSE
  )
}

full_join_counts <- function(before_df, after_df, key = "signoff_reason") {
  out <- merge(before_df, after_df, by = key, all = TRUE, suffixes = c("_before", "_after"), sort = TRUE)
  out$count_before[is.na(out$count_before)] <- 0L
  out$count_after[is.na(out$count_after)] <- 0L
  out$count_delta <- out$count_after - out$count_before
  out[order(out$count_after, out$count_before, decreasing = TRUE), , drop = FALSE]
}

hard_reasons <- c(
  "non_finite_fit",
  "missing_elbo_trace",
  "domain_violation",
  "kernel_not_signoff_ready",
  "rhs_collapse"
)

soft_reasons <- c(
  "geweke_drift",
  "low_ess",
  "half_chain_drift",
  "high_autocorrelation",
  "vb_converged_false",
  "ld_unstable",
  "elbo_tail_unstable",
  "core_parameter_tail_unstable"
)

classify_failure_bucket <- function(reason_string) {
  tokens <- trimws(strsplit(reason_string %||% "", ";", fixed = TRUE)[[1L]])
  tokens <- tokens[nzchar(tokens)]
  has_hard <- any(tokens %in% hard_reasons)
  has_soft <- any(tokens %in% soft_reasons)
  if (has_hard && has_soft) return("mixed")
  if (has_hard) return("hard_only")
  if (has_soft) return("soft_only")
  "uncategorized"
}

key_cols <- c("root_id", "inference", "model")

summarize_signoff_delta <- function(before_summary, after_summary) {
  fields <- c(
    "method_fit_pass_count",
    "method_fit_warn_count",
    "method_fit_fail_count",
    "method_fit_eligible_count",
    "method_fit_certified_count",
    "algorithm_pair_eligible_count",
    "model_pair_eligible_count",
    "root_full_eligible_count",
    "root_any_eligible_count",
    "unhealthy_target_count"
  )
  out <- data.frame(
    metric = fields,
    before = as.integer(before_summary[1L, fields, drop = TRUE]),
    after = as.integer(after_summary[1L, fields, drop = TRUE]),
    stringsAsFactors = FALSE
  )
  out$delta <- out$after - out$before
  out
}

summarize_bucket_counts <- function(df) {
  if (!nrow(df)) {
    return(data.frame(failure_bucket = character(0), count = integer(0), stringsAsFactors = FALSE))
  }
  tab <- sort(table(df$failure_bucket), decreasing = TRUE)
  data.frame(
    failure_bucket = names(tab),
    count = as.integer(tab),
    stringsAsFactors = FALSE
  )
}

summarize_bucket_by_model <- function(df) {
  if (!nrow(df)) {
    return(data.frame(
      inference = character(0),
      model = character(0),
      failure_bucket = character(0),
      count = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  out <- aggregate(
    list(count = rep(1L, nrow(df))),
    by = list(
      inference = df$inference,
      model = df$model,
      failure_bucket = df$failure_bucket
    ),
    FUN = sum
  )
  out[order(out$inference, out$model, out$failure_bucket), , drop = FALSE]
}

summarize_row_level_changes <- function(before_df, after_df) {
  before_df$key <- apply(before_df[, key_cols, drop = FALSE], 1L, paste, collapse = "||")
  after_df$key <- apply(after_df[, key_cols, drop = FALSE], 1L, paste, collapse = "||")
  merged <- merge(
    before_df[, c("key", key_cols, "signoff_reason"), drop = FALSE],
    after_df[, c("key", key_cols, "signoff_reason"), drop = FALSE],
    by = c("key", key_cols),
    all = TRUE,
    suffixes = c("_before", "_after"),
    sort = FALSE
  )
  merged$change_class <- ifelse(
    is.na(merged$signoff_reason_before), "new_after",
    ifelse(
      is.na(merged$signoff_reason_after), "resolved",
      ifelse(merged$signoff_reason_before == merged$signoff_reason_after, "unchanged", "changed")
    )
  )
  merged
}

write_md_summary <- function(path, signoff_delta, reason_delta, bucket_counts, bucket_by_model, row_changes) {
  lines <- c(
    "# Family-QSpec Post-Repair Delta",
    "",
    "## Aggregate Delta",
    "",
    "| metric | before | after | delta |",
    "|---|---:|---:|---:|"
  )
  for (i in seq_len(nrow(signoff_delta))) {
    lines <- c(lines, sprintf(
      "| %s | %d | %d | %+d |",
      signoff_delta$metric[[i]],
      signoff_delta$before[[i]],
      signoff_delta$after[[i]],
      signoff_delta$delta[[i]]
    ))
  }

  lines <- c(lines, "", "## Reason Delta", "", "| reason | before | after | delta |", "|---|---:|---:|---:|")
  for (i in seq_len(nrow(reason_delta))) {
    lines <- c(lines, sprintf(
      "| %s | %d | %d | %+d |",
      reason_delta$signoff_reason[[i]],
      reason_delta$count_before[[i]],
      reason_delta$count_after[[i]],
      reason_delta$count_delta[[i]]
    ))
  }

  lines <- c(lines, "", "## Residual Failure Buckets", "", "| bucket | count |", "|---|---:|")
  for (i in seq_len(nrow(bucket_counts))) {
    lines <- c(lines, sprintf("| %s | %d |", bucket_counts$failure_bucket[[i]], bucket_counts$count[[i]]))
  }

  lines <- c(lines, "", "## Residual Bucket By Model", "", "| inference | model | bucket | count |", "|---|---|---|---:|")
  for (i in seq_len(nrow(bucket_by_model))) {
    lines <- c(lines, sprintf(
      "| %s | %s | %s | %d |",
      bucket_by_model$inference[[i]],
      bucket_by_model$model[[i]],
      bucket_by_model$failure_bucket[[i]],
      bucket_by_model$count[[i]]
    ))
  }

  row_change_tab <- sort(table(row_changes$change_class), decreasing = TRUE)
  lines <- c(lines, "", "## Row-Level Change Classes", "", "| class | count |", "|---|---:|")
  for (nm in names(row_change_tab)) {
    lines <- c(lines, sprintf("| %s | %d |", nm, as.integer(row_change_tab[[nm]])))
  }

  writeLines(lines, con = path)
}

summary_path <- "tools/merge_reports/20260314_family_qspec_signoff_summary.tsv"
unhealthy_path <- "tools/merge_reports/20260314_family_qspec_unhealthy_targets.tsv"

before_summary <- read_git_tsv(repo_root, summary_path)
after_summary <- read_current_tsv(repo_root, summary_path)
before_unhealthy <- read_git_tsv(repo_root, unhealthy_path)
after_unhealthy <- read_current_tsv(repo_root, unhealthy_path)

after_unhealthy$failure_bucket <- vapply(after_unhealthy$signoff_reason, classify_failure_bucket, character(1))

signoff_delta <- summarize_signoff_delta(before_summary, after_summary)
reason_delta <- full_join_counts(count_reason_tokens(before_unhealthy), count_reason_tokens(after_unhealthy))
bucket_counts <- summarize_bucket_counts(after_unhealthy)
bucket_by_model <- summarize_bucket_by_model(after_unhealthy)
row_changes <- summarize_row_level_changes(before_unhealthy, after_unhealthy)

out_dir <- file.path(repo_root, "tools", "merge_reports")
fq_write_tsv(signoff_delta, file.path(out_dir, "20260315_family_qspec_post_repair_signoff_delta.tsv"))
fq_write_tsv(reason_delta, file.path(out_dir, "20260315_family_qspec_post_repair_reason_delta.tsv"))
fq_write_tsv(after_unhealthy, file.path(out_dir, "20260315_family_qspec_post_repair_unhealthy_classification.tsv"))
fq_write_tsv(bucket_counts, file.path(out_dir, "20260315_family_qspec_post_repair_bucket_summary.tsv"))
fq_write_tsv(bucket_by_model, file.path(out_dir, "20260315_family_qspec_post_repair_bucket_by_model.tsv"))
fq_write_tsv(row_changes, file.path(out_dir, "20260315_family_qspec_post_repair_row_changes.tsv"))

write_md_summary(
  file.path(out_dir, "20260315_family_qspec_post_repair_delta_summary.md"),
  signoff_delta = signoff_delta,
  reason_delta = reason_delta,
  bucket_counts = bucket_counts,
  bucket_by_model = bucket_by_model,
  row_changes = row_changes
)

cat("Wrote post-repair delta analysis under tools/merge_reports\n")
