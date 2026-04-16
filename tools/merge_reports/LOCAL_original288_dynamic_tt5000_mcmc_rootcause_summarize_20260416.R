#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

rows_dir <- file.path(repo_root, "tools/merge_reports", "full288_original288_dynamic_tt5000_mcmc_rootcause_20260416", "rows")
summary_path <- file.path(repo_root, "tools/merge_reports", "LOCAL_original288_dynamic_tt5000_mcmc_rootcause_summary_20260416.csv")

row_files <- Sys.glob(file.path(rows_dir, "row_*.csv"))
if (!length(row_files)) {
  quit(save = "no", status = 0)
}

rows <- do.call(rbind, lapply(row_files, function(p) utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE)))
if (!"baseline_mode" %in% names(rows)) rows$baseline_mode <- NA_character_

agg <- aggregate(
  list(rows = rows$row_id),
  by = list(
    family = rows$family,
    tau_label = rows$tau_label,
    model = rows$model,
    inference = rows$inference,
    variant = rows$variant,
    baseline_mode = rows$baseline_mode,
    status = rows$status,
    gate_overall = rows$gate_overall
  ),
  FUN = length
)

utils::write.csv(agg, summary_path, row.names = FALSE)
