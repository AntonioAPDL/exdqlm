#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
manifest_path <- file.path(out_dir, "LOCAL_targeted_manifest_dynamic_tail3_20260329.csv")

if (!file.exists(manifest_path)) {
  stop(sprintf("manifest not found: %s", manifest_path))
}

x <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
row15 <- x[x$row_id == 15L, , drop = FALSE]
if (nrow(row15) != 1L) {
  stop(sprintf("expected one row15 entry, found %d", nrow(row15)))
}

row15$sidecar_tag <- "dynamic_row15_sidecar_20260403"
row15$launch_readiness <- "blocked_pending_repair_hypothesis"
row15$current_health_csv <- file.path(
  out_dir, "full288_dynamic_tail_cppgig_refresh_20260331", "health", "health_0015.csv"
)
row15$current_row_csv <- file.path(
  out_dir, "full288_dynamic_tail_cppgig_refresh_20260331", "rows", "row_0015.csv"
)

schedule_path <- file.path(out_dir, "LOCAL_dynamic_row15_sidecar_schedule_20260403.csv")
utils::write.csv(row15, schedule_path, row.names = FALSE)
cat(sprintf("schedule: %s\n", schedule_path))
