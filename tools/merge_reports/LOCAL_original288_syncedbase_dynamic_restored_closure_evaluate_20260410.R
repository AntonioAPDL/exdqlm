#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_helpers_20260410.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

args <- commandArgs(trailingOnly = TRUE)
manifest_path <- paths_original288_syncedbase_dynamic_restored_closure()$manifest
tag <- run_tag_original288_syncedbase_dynamic_restored_closure()

for (arg in args) {
  if (grepl("^--manifest=", arg)) manifest_path <- sub("^--manifest=", "", arg)
  if (grepl("^--tag=", arg)) tag <- sub("^--tag=", "", arg)
}

status <- read_original288_syncedbase_dynamic_restored_closure_status(manifest_path = manifest_path, run_tag = tag)
paths <- paths_original288_syncedbase_dynamic_restored_closure()

utils::write.csv(status, paths$manifest_status, row.names = FALSE)

summarize_status <- function(df, group_cols) {
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
      matches_accepted = sum(d$accepted_compare == "matches_accepted"),
      better_than_accepted = sum(d$accepted_compare == "better_than_accepted"),
      worse_than_accepted = sum(d$accepted_compare == "worse_than_accepted"),
      pending_compare = sum(d$accepted_compare == "pending"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

phase_summary <- summarize_status(status, "phase")
phase_summary$phase_order <- unname(phase_order_original288_syncedbase_dynamic_restored_closure[phase_summary$phase])
phase_summary <- phase_summary[order(phase_summary$phase_order), setdiff(names(phase_summary), "phase_order"), drop = FALSE]
utils::write.csv(phase_summary, paths$phase_summary, row.names = FALSE)

block_summary <- summarize_status(status, c("block", "model", "inference"))
block_summary <- block_summary[order(block_summary$block, block_summary$model, block_summary$inference), , drop = FALSE]
utils::write.csv(block_summary, paths$block_summary, row.names = FALSE)

accepted_compare <- summarize_status(status, "accepted_compare")
utils::write.csv(accepted_compare, paths$accepted_compare, row.names = FALSE)

cat(sprintf(
  "SUMMARY total=%d done=%d missing=%d pass=%d warn=%d fail=%d healthy=%d matches=%d better=%d worse=%d pending=%d\n",
  nrow(status),
  sum(status$gate_current != "MISSING"),
  sum(status$gate_current == "MISSING"),
  sum(status$gate_current == "PASS"),
  sum(status$gate_current == "WARN"),
  sum(status$gate_current == "FAIL"),
  sum(status$healthy_current),
  sum(status$accepted_compare == "matches_accepted"),
  sum(status$accepted_compare == "better_than_accepted"),
  sum(status$accepted_compare == "worse_than_accepted"),
  sum(status$accepted_compare == "pending")
))
