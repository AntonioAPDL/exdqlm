#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1) args[[1]] else getwd()
repo_root <- normalizePath(repo_root, mustWork = TRUE)
report_dir <- file.path(repo_root, "tools", "merge_reports")

run_step <- function(args_vec) {
  status <- system2("Rscript", args = args_vec, stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) {
    stop(sprintf("command failed: Rscript %s", paste(args_vec, collapse = " ")))
  }
}

old_wd <- getwd()
setwd(repo_root)
on.exit(setwd(old_wd), add = TRUE)

run_step(c("tools/merge_reports/20260312_build_family_qspec_reusable_state_audit.R", repo_root))
run_step(c("tools/merge_reports/20260312_build_family_qspec_runtime_queue.R", repo_root))
run_step(c("tools/merge_reports/20260312_snapshot_family_qspec_v2_active_tasks.R"))

read_tsv <- function(path) {
  read.delim(path, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
}

write_tsv <- function(df, path) {
  write.table(df, file = path, sep = "\t", row.names = FALSE, quote = FALSE, na = "")
}

add_percentage_columns <- function(df, category_col, count_col, total_count,
                                   category_total_name, pct_category_name, pct_total_name) {
  category_totals <- aggregate(df[[count_col]], by = list(df[[category_col]]), FUN = sum)
  names(category_totals) <- c(category_col, category_total_name)
  df <- merge(df, category_totals, by = category_col, sort = FALSE)
  df[[pct_category_name]] <- round(100 * df[[count_col]] / df[[category_total_name]], 1)
  df[[pct_total_name]] <- round(100 * df[[count_col]] / total_count, 1)
  df
}

md_cell <- function(x) {
  x <- ifelse(is.na(x) | x == "", "-", as.character(x))
  x <- gsub("\\|", "\\\\|", x)
  x
}

write_markdown_table <- function(df, path, title, intro = NULL) {
  lines <- c(sprintf("# %s", title), "")
  if (!is.null(intro) && nzchar(intro)) {
    lines <- c(lines, intro, "")
  }
  header <- paste(sprintf("| %s ", names(df)), collapse = "")
  divider <- paste(rep("|---", ncol(df)), collapse = "")
  divider <- paste0(divider, "|")
  lines <- c(lines, header, divider)
  if (nrow(df) > 0) {
    for (i in seq_len(nrow(df))) {
      row_vals <- vapply(df[i, , drop = FALSE], md_cell, character(1))
      lines <- c(lines, paste0("| ", paste(row_vals, collapse = " | "), " |"))
    }
  }
  writeLines(lines, con = path)
}

format_pct_cols_for_md <- function(df) {
  pct_cols <- grep("^pct_", names(df), value = TRUE)
  for (col in pct_cols) {
    df[[col]] <- sprintf("%.1f%%", as.numeric(df[[col]]))
  }
  df
}

queue <- read_tsv(file.path(report_dir, "20260312_family_qspec_runtime_queue.tsv"))
audit <- read_tsv(file.path(report_dir, "20260312_family_qspec_reusable_state_audit.tsv"))
active_path <- file.path(report_dir, "20260312_family_qspec_v2_active_tasks.tsv")
active <- if (file.exists(active_path)) read_tsv(active_path) else data.frame(task_id = character(), session_name = character(), launch_mode = character(), stringsAsFactors = FALSE)
active_task_ids <- if (nrow(active) > 0) active$task_id else character()

logical_true <- function(x) {
  tolower(as.character(x)) %in% c("true", "t", "1")
}

model_df <- queue[queue$unit_type == "model_path", c(
  "task_id", "root_id", "root_kind", "family", "tau", "fit_size", "prior", "model",
  "state", "launch_ready", "launch_mode", "priority", "prepared_root", "run_root", "notes"
)]
model_df$launch_ready <- logical_true(model_df$launch_ready)
model_df$active_now <- model_df$task_id %in% active_task_ids
model_df$session_name <- ""
model_df$active_launch_mode <- ""
if (nrow(active) > 0) {
  hit <- match(model_df$task_id, active$task_id)
  model_df$session_name[!is.na(hit)] <- active$session_name[hit[!is.na(hit)]]
  model_df$active_launch_mode[!is.na(hit)] <- active$launch_mode[hit[!is.na(hit)]]
}
model_df$effective_launch_mode <- ifelse(model_df$active_now & nzchar(model_df$active_launch_mode), model_df$active_launch_mode, model_df$launch_mode)

model_df$stage_label <- model_df$state
model_df$stage_label[model_df$state == "complete_reusable"] <- "complete_reusable"
model_df$stage_label[model_df$state == "blocked"] <- "blocked"
model_df$stage_label[model_df$state == "partial_reusable" & model_df$launch_ready] <- "queued_resume_ready"
model_df$stage_label[model_df$state == "partial_stale" & model_df$launch_ready] <- "queued_restart_ready"
model_df$stage_label[model_df$state == "missing" & model_df$launch_ready] <- "queued_fresh_ready"
model_df$stage_label[model_df$active_now] <- "running"
model_df$stage_label[model_df$active_now & model_df$effective_launch_mode == "fresh_vb_then_mcmc"] <- "running_fresh_vb_then_mcmc"
model_df$stage_label[model_df$active_now & model_df$effective_launch_mode == "resume_mcmc_from_vb"] <- "running_resume_mcmc"
model_df$stage_label[model_df$state == "complete_reusable"] <- "complete_reusable"

model_df$next_action <- model_df$stage_label
model_df$next_action[model_df$stage_label == "complete_reusable"] <- "skip"
model_df$next_action[model_df$stage_label == "running_resume_mcmc"] <- "monitor_resume_mcmc"
model_df$next_action[model_df$stage_label == "running_fresh_vb_then_mcmc"] <- "monitor_fresh_pipeline"
model_df$next_action[model_df$stage_label == "running"] <- "monitor_running_task"
model_df$next_action[model_df$stage_label == "queued_resume_ready"] <- "await_slot_resume"
model_df$next_action[model_df$stage_label == "queued_restart_ready"] <- "await_slot_restart"
model_df$next_action[model_df$stage_label == "queued_fresh_ready"] <- "await_slot_fresh"
model_df$next_action[model_df$stage_label == "blocked"] <- "wait_for_prerequisites"

stage_order <- c(
  "running_resume_mcmc", "running_fresh_vb_then_mcmc", "running",
  "queued_resume_ready", "queued_restart_ready", "queued_fresh_ready",
  "complete_reusable", "blocked"
)
model_df$stage_rank <- match(model_df$stage_label, stage_order)
model_df$stage_rank[is.na(model_df$stage_rank)] <- length(stage_order) + 1L
model_df <- model_df[order(
  model_df$stage_rank,
  model_df$root_kind,
  model_df$family,
  as.numeric(model_df$tau),
  suppressWarnings(as.numeric(model_df$fit_size)),
  model_df$prior,
  model_df$model
), ]
model_df$stage_rank <- NULL

model_progress <- model_df[, c(
  "root_kind", "family", "tau", "fit_size", "prior", "model",
  "stage_label", "state", "active_now", "effective_launch_mode", "next_action",
  "session_name", "run_root", "notes", "task_id"
)]
names(model_progress)[names(model_progress) == "effective_launch_mode"] <- "launch_mode"

model_summary <- as.data.frame(xtabs(~ root_kind + stage_label, data = model_progress), stringsAsFactors = FALSE)
model_summary <- model_summary[model_summary$Freq > 0, ]
names(model_summary)[3] <- "count"
model_summary <- add_percentage_columns(
  model_summary,
  category_col = "root_kind",
  count_col = "count",
  total_count = nrow(model_progress),
  category_total_name = "root_kind_total",
  pct_category_name = "pct_of_root_kind",
  pct_total_name = "pct_of_all_model_paths"
)
model_summary <- model_summary[order(model_summary$root_kind, model_summary$stage_label), ]

barrier_df <- audit[audit$unit_type %in% c("root_postprocess", "root_review", "prior_compare", "campaign_review", "global_summary"), c(
  "unit_type", "root_kind", "family", "tau", "fit_size", "prior", "state", "recommended_action", "location", "notes", "unit_id"
)]
barrier_df$stage_label <- barrier_df$state
barrier_df$stage_label[barrier_df$unit_type == "root_postprocess" & barrier_df$state == "complete_reusable"] <- "root_postprocess_complete"
barrier_df$stage_label[barrier_df$unit_type == "root_postprocess" & barrier_df$state == "missing"] <- "root_postprocess_ready"
barrier_df$stage_label[barrier_df$unit_type == "root_postprocess" & barrier_df$state == "blocked"] <- "root_postprocess_waiting_for_model_paths"
barrier_df$stage_label[barrier_df$unit_type == "root_review" & barrier_df$state == "complete_reusable"] <- "root_review_complete"
barrier_df$stage_label[barrier_df$unit_type == "root_review" & barrier_df$state == "blocked"] <- "root_review_waiting_for_postprocess"
barrier_df$stage_label[barrier_df$unit_type == "prior_compare" & barrier_df$state == "missing"] <- "prior_compare_ready"
barrier_df$stage_label[barrier_df$unit_type == "prior_compare" & barrier_df$state == "blocked"] <- "prior_compare_waiting_for_root_reviews"
barrier_df$stage_label[barrier_df$unit_type == "campaign_review" & barrier_df$state == "complete_reusable"] <- "campaign_review_complete"
barrier_df$stage_label[barrier_df$unit_type == "campaign_review" & barrier_df$state == "blocked"] <- "campaign_review_waiting_for_prerequisites"
barrier_df$stage_label[barrier_df$unit_type == "global_summary" & barrier_df$state == "complete_reusable"] <- "global_summary_complete"
barrier_df$stage_label[barrier_df$unit_type == "global_summary" & barrier_df$state == "blocked"] <- "global_summary_waiting_for_campaigns"
barrier_progress <- barrier_df[, c(
  "unit_type", "root_kind", "family", "tau", "fit_size", "prior",
  "stage_label", "state", "recommended_action", "location", "notes", "unit_id"
)]
barrier_progress <- barrier_progress[order(barrier_progress$unit_type, barrier_progress$root_kind, barrier_progress$family, as.character(barrier_progress$tau), as.character(barrier_progress$fit_size), barrier_progress$prior), ]
barrier_summary <- as.data.frame(xtabs(~ unit_type + stage_label, data = barrier_progress), stringsAsFactors = FALSE)
barrier_summary <- barrier_summary[barrier_summary$Freq > 0, ]
names(barrier_summary)[3] <- "count"
barrier_summary <- add_percentage_columns(
  barrier_summary,
  category_col = "unit_type",
  count_col = "count",
  total_count = nrow(barrier_progress),
  category_total_name = "unit_type_total",
  pct_category_name = "pct_of_unit_type",
  pct_total_name = "pct_of_all_barriers"
)
barrier_summary <- barrier_summary[order(barrier_summary$unit_type, barrier_summary$stage_label), ]

model_tsv <- file.path(report_dir, "20260312_family_qspec_model_path_progress.tsv")
model_summary_tsv <- file.path(report_dir, "20260312_family_qspec_model_path_progress_summary.tsv")
model_md <- file.path(report_dir, "20260312_family_qspec_model_path_progress.md")
barrier_tsv <- file.path(report_dir, "20260312_family_qspec_barrier_progress.tsv")
barrier_summary_tsv <- file.path(report_dir, "20260312_family_qspec_barrier_progress_summary.tsv")
barrier_md <- file.path(report_dir, "20260312_family_qspec_barrier_progress.md")

write_tsv(model_progress, model_tsv)
write_tsv(model_summary, model_summary_tsv)
write_tsv(barrier_progress, barrier_tsv)
write_tsv(barrier_summary, barrier_summary_tsv)

model_summary_md <- format_pct_cols_for_md(model_summary)
barrier_summary_md <- format_pct_cols_for_md(barrier_summary)

write_markdown_table(
  model_summary_md,
  file.path(report_dir, "20260312_family_qspec_model_path_progress_summary.md"),
  "Family-Qspec Model-Path Progress Summary",
  "Authoritative per-model-path count summary. Regenerate with `Rscript tools/merge_reports/20260312_build_family_qspec_progress_views.R \"$PWD\"` from the repo root."
)
write_markdown_table(
  model_progress,
  model_md,
  "Family-Qspec Model-Path Progress",
  "Authoritative full 144-row per-model-path table for the canonical tau grid `0.05, 0.25, 0.95`."
)
write_markdown_table(
  barrier_progress,
  barrier_md,
  "Family-Qspec Root/Barrier Progress",
  "Authoritative higher-layer progress table for root postprocess, root review, prior compare, campaign review, and global summary."
)
write_markdown_table(
  barrier_summary_md,
  file.path(report_dir, "20260312_family_qspec_barrier_progress_summary.md"),
  "Family-Qspec Root/Barrier Progress Summary",
  "Authoritative higher-layer count summary. Regenerate with `Rscript tools/merge_reports/20260312_build_family_qspec_progress_views.R \"$PWD\"` from the repo root."
)

cat(model_tsv, "\n")
cat(model_summary_tsv, "\n")
cat(barrier_tsv, "\n")
cat(barrier_summary_tsv, "\n")
