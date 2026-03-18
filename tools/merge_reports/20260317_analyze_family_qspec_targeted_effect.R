#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) normalizePath(args[[1L]], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)
baseline_method_signoff_path <- if (length(args) >= 2L) normalizePath(args[[2L]], mustWork = TRUE) else NA_character_
out_prefix <- if (length(args) >= 3L) as.character(args[[3L]]) else "20260317_family_qspec_targeted_effect"

if (!nzchar(out_prefix)) out_prefix <- "20260317_family_qspec_targeted_effect"

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

after_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_method_signoff.tsv")
if (!file.exists(after_path)) stop("Missing current method signoff TSV: ", after_path, call. = FALSE)
if (!nzchar(baseline_method_signoff_path) || is.na(baseline_method_signoff_path)) {
  stop("Baseline method signoff path must be provided.", call. = FALSE)
}

hard_targets_path <- file.path(repo_root, "tools", "merge_reports", "20260315_family_qspec_second_wave_hard_holdouts.tsv")
vb_targets_path <- file.path(repo_root, "tools", "merge_reports", "20260315_family_qspec_second_wave_vb_debug_targets.tsv")

before <- fq_read_tsv(baseline_method_signoff_path)
after <- fq_read_tsv(after_path)

read_target_keys <- function(path, group_name) {
  if (!file.exists(path)) return(data.frame(
    root_id = character(0),
    inference = character(0),
    model = character(0),
    target_group = character(0),
    stringsAsFactors = FALSE
  ))
  df <- fq_read_tsv(path)
  if (!nrow(df)) return(data.frame(
    root_id = character(0),
    inference = character(0),
    model = character(0),
    target_group = character(0),
    stringsAsFactors = FALSE
  ))
  keys <- unique(df[, c("root_id", "inference", "model"), drop = FALSE])
  keys$target_group <- group_name
  keys
}

hard_keys <- read_target_keys(hard_targets_path, "hard_only")
vb_keys <- read_target_keys(vb_targets_path, "vb_debug")
target_keys <- unique(rbind(hard_keys, vb_keys))

if (!nrow(target_keys)) {
  stop("No targeted rows found in hard-only or vb-debug target files.", call. = FALSE)
}

select_cols <- c(
  "root_id", "inference", "model",
  "signoff_grade", "signoff_reason", "comparison_eligible", "convergence_certified"
)
missing_before <- setdiff(select_cols, names(before))
missing_after <- setdiff(select_cols, names(after))
if (length(missing_before)) stop("Baseline method signoff missing columns: ", paste(missing_before, collapse = ", "), call. = FALSE)
if (length(missing_after)) stop("Current method signoff missing columns: ", paste(missing_after, collapse = ", "), call. = FALSE)

before_sel <- before[, select_cols, drop = FALSE]
names(before_sel)[names(before_sel) != "root_id" & names(before_sel) != "inference" & names(before_sel) != "model"] <-
  paste0("before_", names(before_sel)[names(before_sel) != "root_id" & names(before_sel) != "inference" & names(before_sel) != "model"])

after_sel <- after[, select_cols, drop = FALSE]
names(after_sel)[names(after_sel) != "root_id" & names(after_sel) != "inference" & names(after_sel) != "model"] <-
  paste0("after_", names(after_sel)[names(after_sel) != "root_id" & names(after_sel) != "inference" & names(after_sel) != "model"])

rows <- merge(target_keys, before_sel, by = c("root_id", "inference", "model"), all.x = TRUE, sort = FALSE)
rows <- merge(rows, after_sel, by = c("root_id", "inference", "model"), all.x = TRUE, sort = FALSE)

classify_change <- function(before_grade, after_grade, before_reason, after_reason) {
  if (is.na(before_grade) || is.na(after_grade)) return("missing_data")
  if (identical(before_grade, "FAIL") && !identical(after_grade, "FAIL")) return("resolved")
  if (identical(before_grade, "FAIL") && identical(after_grade, "FAIL")) {
    if (identical(before_reason, after_reason)) return("unchanged_fail")
    return("reshuffled_fail")
  }
  if (!identical(before_grade, after_grade) || !identical(before_reason, after_reason)) return("changed_nonfail")
  "unchanged_nonfail"
}

rows$change_class <- vapply(
  seq_len(nrow(rows)),
  function(i) classify_change(
    as.character(rows$before_signoff_grade[[i]]),
    as.character(rows$after_signoff_grade[[i]]),
    as.character(rows$before_signoff_reason[[i]]),
    as.character(rows$after_signoff_reason[[i]])
  ),
  character(1)
)

rows$resolved <- rows$change_class == "resolved"
rows$reason_changed <- rows$before_signoff_reason != rows$after_signoff_reason
rows$reason_changed[is.na(rows$reason_changed)] <- FALSE

summary_overall <- as.data.frame(table(change_class = rows$change_class), stringsAsFactors = FALSE)
names(summary_overall)[names(summary_overall) == "Freq"] <- "count"
summary_overall <- summary_overall[order(summary_overall$change_class), , drop = FALSE]

summary_group <- as.data.frame(table(
  target_group = rows$target_group,
  change_class = rows$change_class
), stringsAsFactors = FALSE)
names(summary_group)[names(summary_group) == "Freq"] <- "count"
summary_group <- summary_group[summary_group$count > 0, , drop = FALSE]
summary_group <- summary_group[order(summary_group$target_group, summary_group$change_class), , drop = FALSE]

out_dir <- file.path(repo_root, "tools", "merge_reports")
rows_path <- file.path(out_dir, sprintf("%s_rows.tsv", out_prefix))
summary_path <- file.path(out_dir, sprintf("%s_summary.tsv", out_prefix))
group_path <- file.path(out_dir, sprintf("%s_by_group.tsv", out_prefix))
md_path <- file.path(out_dir, sprintf("%s_summary.md", out_prefix))

fq_write_tsv(rows, rows_path)
fq_write_tsv(summary_overall, summary_path)
fq_write_tsv(summary_group, group_path)

md <- c(
  "# Family-QSpec Targeted Effect Summary",
  "",
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- baseline_method_signoff: `%s`", baseline_method_signoff_path),
  sprintf("- current_method_signoff: `%s`", after_path),
  sprintf("- targeted_rows: `%d`", nrow(rows)),
  "",
  "## Overall Change Classes",
  "",
  "| change_class | count |",
  "|---|---:|"
)
if (!nrow(summary_overall)) {
  md <- c(md, "| (none) | 0 |")
} else {
  for (i in seq_len(nrow(summary_overall))) {
    md <- c(md, sprintf("| %s | %d |", summary_overall$change_class[[i]], summary_overall$count[[i]]))
  }
}
md <- c(md, "", "## By Target Group", "", "| target_group | change_class | count |", "|---|---|---:|")
if (!nrow(summary_group)) {
  md <- c(md, "| (none) | (none) | 0 |")
} else {
  for (i in seq_len(nrow(summary_group))) {
    md <- c(md, sprintf(
      "| %s | %s | %d |",
      summary_group$target_group[[i]],
      summary_group$change_class[[i]],
      summary_group$count[[i]]
    ))
  }
}
writeLines(md, con = md_path)

cat("Wrote:\n")
cat(rows_path, "\n")
cat(summary_path, "\n")
cat(group_path, "\n")
cat(md_path, "\n")
