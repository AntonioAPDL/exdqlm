#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg("--repo-root", system(
  "git rev-parse --show-toplevel", intern = TRUE
)), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))
materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg("--output-root"), winslash = "/", mustWork = FALSE)
run_tag <- get_arg("--run-tag")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
plan <- qdesn_ssv2_read_csv(file.path(materialization_root,
                                      "targeted_confirmation_plan.csv"))
rows <- lapply(seq_len(nrow(plan)), function(i) {
  root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
  status <- qdesn_ssv2_read_json(file.path(root, "job_status.json"))
  signoff_path <- file.path(root, "signoff_summary.csv")
  signoff <- if (file.exists(signoff_path)) qdesn_ssv2_read_csv(signoff_path) else data.frame()
  grade_fields <- intersect(c("signoff_grade", "status", "decision"), names(signoff))
  binary_payloads <- length(list.files(
    root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  ))
  data.frame(
    target_cell_id = plan$target_cell_id[[i]], candidate_id = plan$candidate_id[[i]],
    chain_id = plan$chain_id[[i]], job_id = plan$job_id[[i]],
    objective_metric = plan$objective_metric[[i]],
    objective_value = qdesn_ssv2_metric_value(root, plan$objective_metric[[i]]),
    current_value = plan$current_value[[i]], comparator_value = plan$comparator_value[[i]],
    status = as.character(status$status %||% "MISSING"),
    elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
    signoff = if (length(grade_fields) && nrow(signoff))
      as.character(signoff[[grade_fields[[1L]]]][[1L]]) else NA_character_,
    binary_payloads = binary_payloads,
    stringsAsFactors = FALSE
  )
})
chains <- do.call(rbind, rows)
chain_path <- qdesn_ssv2_write_csv(chains, file.path(output_root,
                                                     "confirmation_chain_metrics.csv"))
summary <- do.call(rbind, lapply(split(chains, chains$target_cell_id), function(x) {
  values <- x$objective_value
  mean_value <- mean(values)
  data.frame(
    target_cell_id = x$target_cell_id[[1L]], candidate_id = x$candidate_id[[1L]],
    objective_metric = x$objective_metric[[1L]], chains = nrow(x),
    successful_chains = sum(x$status == "SUCCESS"), finite_chains = sum(is.finite(values)),
    objective_mean = mean_value, objective_median = stats::median(values),
    objective_sd = stats::sd(values), objective_min = min(values), objective_max = max(values),
    current_value = x$current_value[[1L]], comparator_value = x$comparator_value[[1L]],
    improvement_over_current_pct = 100 * (x$current_value[[1L]] - mean_value) /
      x$current_value[[1L]],
    comparator_gap_pct = 100 * (mean_value - x$comparator_value[[1L]]) /
      x$comparator_value[[1L]],
    chains_improving_current = sum(values < x$current_value[[1L]]),
    chains_beating_comparator = sum(values < x$comparator_value[[1L]]),
    manual_promotion_eligible = nrow(x) == 3L && all(x$status == "SUCCESS") &&
      all(is.finite(values)) && all(x$binary_payloads == 0L) &&
      mean_value < x$current_value[[1L]],
    article_update_automatic = FALSE,
    stringsAsFactors = FALSE
  )
}))
summary$decision <- ifelse(summary$manual_promotion_eligible,
                           "eligible_for_manual_metric_promotion",
                           "retain_current_article_metric")
summary_path <- qdesn_ssv2_write_csv(summary, file.path(output_root,
                                                        "confirmation_cell_summary.csv"))
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  chain_metrics = list(path = chain_path, sha256 = qdesn_ssv2_sha256(chain_path)),
  cell_summary = list(path = summary_path, sha256 = qdesn_ssv2_sha256(summary_path)),
  promotion_eligible_cells = as.list(summary$target_cell_id[summary$manual_promotion_eligible]),
  article_update_automatic = FALSE,
  next_gate = "manual_scientific_review_before_article_promotion"
), file.path(output_root, "targeted_confirmation_closeout_manifest.json"))
cat(sprintf("confirmation_cells=%d eligible=%d article_unchanged=TRUE\n",
            nrow(summary), sum(summary$manual_promotion_eligible)))
