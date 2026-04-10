#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_helpers_20260410.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

args <- commandArgs(trailingOnly = TRUE)
manifest_path <- paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()$manifest
tag <- run_tag_original288_static_shrink_rhsns_exal_mcmc_final_closure()

for (arg in args) {
  if (grepl("^--manifest=", arg)) manifest_path <- sub("^--manifest=", "", arg)
  if (grepl("^--tag=", arg)) tag <- sub("^--tag=", "", arg)
}

status <- read_original288_static_shrink_rhsns_exal_mcmc_final_closure_status(manifest_path = manifest_path, run_tag = tag)
paths <- paths_original288_static_shrink_rhsns_exal_mcmc_final_closure()

if (!"phase" %in% names(status)) {
  if ("phase_manifest" %in% names(status)) {
    status$phase <- status$phase_manifest
  } else if ("phase_row" %in% names(status)) {
    status$phase <- status$phase_row
  } else {
    stop("status frame is missing phase columns")
  }
}

status$base_row_id <- suppressWarnings(as.integer(coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
  status,
  c("base_row_id", "base_row_id_manifest", "base_row_id_row")
)))
status$fit_size <- suppressWarnings(as.integer(coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
  status,
  c("fit_size", "fit_size_manifest", "fit_size_row")
)))
status$family <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
  status,
  c("family", "family_manifest", "family_row")
)
status$tau_label <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
  status,
  c("tau_label", "tau_label_manifest", "tau_label_row")
)
status$repair_class <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
  status,
  c("repair_class", "repair_class_manifest", "repair_class_row")
)
status$profile_id <- coalesce_col_original288_static_shrink_rhsns_exal_mcmc_repair(
  status,
  c("profile_id", "profile_id_manifest", "profile_id_row")
)

status$rebuild_compare <- mapply(
  gate_compare_original288_static_shrink_rhsns_exal_mcmc_repair,
  status$gate_current,
  status$rebuild_gate,
  USE.NAMES = FALSE
)

utils::write.csv(status, paths$manifest_status, row.names = FALSE)

summarize_status_rhsns_exal_repair <- function(df, group_cols) {
  key <- interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  spl <- split(df, key)
  out <- lapply(spl, function(d) {
    base <- d[1, group_cols, drop = FALSE]
    data.frame(
      base,
      total = nrow(d),
      done = sum(d$gate_current != "MISSING"),
      missing = sum(d$gate_current == "MISSING"),
      pass = sum(d$gate_current == "PASS"),
      warn = sum(d$gate_current == "WARN"),
      fail = sum(d$gate_current == "FAIL"),
      healthy = sum(d$healthy_current),
      better_than_accepted = sum(d$accepted_compare == "better_than_accepted"),
      matches_accepted = sum(d$accepted_compare == "matches_accepted"),
      worse_than_accepted = sum(d$accepted_compare == "worse_than_accepted"),
      better_than_rebuild = sum(d$rebuild_compare == "better_than_accepted"),
      matches_rebuild = sum(d$rebuild_compare == "matches_accepted"),
      worse_than_rebuild = sum(d$rebuild_compare == "worse_than_accepted"),
      pending_compare = sum(d$accepted_compare == "pending"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

phase_summary <- summarize_status_rhsns_exal_repair(status, "phase")
phase_summary$phase_order <- unname(phase_order_original288_static_shrink_rhsns_exal_mcmc_final_closure[phase_summary$phase])
phase_summary <- phase_summary[order(phase_summary$phase_order), setdiff(names(phase_summary), "phase_order"), drop = FALSE]
utils::write.csv(phase_summary, paths$phase_summary, row.names = FALSE)

target_summary <- summarize_status_rhsns_exal_repair(status, c("base_row_id", "family", "tau_label", "fit_size"))
target_summary <- target_summary[order(target_summary$base_row_id), , drop = FALSE]
utils::write.csv(target_summary, paths$target_summary, row.names = FALSE)

compare_accepted <- summarize_status_rhsns_exal_repair(status, "accepted_compare")
utils::write.csv(compare_accepted, paths$compare_accepted, row.names = FALSE)

compare_rebuild <- summarize_status_rhsns_exal_repair(status, "rebuild_compare")
utils::write.csv(compare_rebuild, paths$compare_working, row.names = FALSE)

cat(sprintf(
  "SUMMARY total=%d done=%d missing=%d pass=%d warn=%d fail=%d healthy=%d better_vs_rebuild=%d matches_vs_rebuild=%d worse_vs_rebuild=%d better_vs_accepted=%d matches_vs_accepted=%d worse_vs_accepted=%d pending=%d\n",
  nrow(status),
  sum(status$gate_current != "MISSING"),
  sum(status$gate_current == "MISSING"),
  sum(status$gate_current == "PASS"),
  sum(status$gate_current == "WARN"),
  sum(status$gate_current == "FAIL"),
  sum(status$healthy_current),
  sum(status$rebuild_compare == "better_than_accepted"),
  sum(status$rebuild_compare == "matches_accepted"),
  sum(status$rebuild_compare == "worse_than_accepted"),
  sum(status$accepted_compare == "better_than_accepted"),
  sum(status$accepted_compare == "matches_accepted"),
  sum(status$accepted_compare == "worse_than_accepted"),
  sum(status$accepted_compare == "pending")
))
