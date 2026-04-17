#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_refreshed288()

if (dir.exists(paths$run_root)) {
  unlink(paths$run_root, recursive = TRUE, force = TRUE)
}

for (path in c(
  paths$run_root,
  paths$config_dir,
  paths$rows_dir,
  paths$health_dir,
  paths$metrics_dir,
  paths$draws_dir,
  paths$logs_dir,
  file.path(paths$fits_dir, "vb"),
  file.path(paths$fits_dir, "mcmc"),
  file.path(paths$vb_init_dir, "dynamic"),
  file.path(paths$vb_init_dir, "static"),
  dirname(paths$spec_doc),
  dirname(paths$full_report)
)) {
  ensure_dir_refreshed288(path)
}

dataset_registry <- build_dataset_registry_refreshed288()
method_registry <- flatten_method_profiles_refreshed288()
full_manifest <- build_manifest_refreshed288(dataset_registry = dataset_registry, repo_root = repo_root)

smoke_keys <- smoke_case_keys_refreshed288(full_manifest)
smoke_manifest <- full_manifest[full_manifest$original_case_key %in% smoke_keys, , drop = FALSE]
smoke_manifest$phase <- vapply(
  seq_len(nrow(smoke_manifest)),
  function(i) phase_for_row_refreshed288(smoke_manifest$block[i], smoke_manifest$inference[i], kind = "smoke"),
  character(1)
)
smoke_manifest$phase_order <- unname(phase_order_refreshed288[smoke_manifest$phase])

full_stage_counts <- as.data.frame(with(full_manifest, table(phase)), stringsAsFactors = FALSE)
names(full_stage_counts) <- c("phase", "rows")
full_stage_counts$phase_order <- unname(phase_order_refreshed288[full_stage_counts$phase])
full_stage_counts <- full_stage_counts[order(full_stage_counts$phase_order), c("phase", "rows"), drop = FALSE]

smoke_stage_counts <- as.data.frame(with(smoke_manifest, table(phase)), stringsAsFactors = FALSE)
names(smoke_stage_counts) <- c("phase", "rows")
smoke_stage_counts$phase_order <- unname(phase_order_refreshed288[smoke_stage_counts$phase])
smoke_stage_counts <- smoke_stage_counts[order(smoke_stage_counts$phase_order), c("phase", "rows"), drop = FALSE]

utils::write.csv(dataset_registry, paths$dataset_registry, row.names = FALSE)
utils::write.csv(method_registry, paths$method_registry, row.names = FALSE)
utils::write.csv(full_manifest, paths$full_manifest, row.names = FALSE)
utils::write.csv(smoke_manifest, paths$smoke_manifest, row.names = FALSE)
utils::write.csv(full_stage_counts, paths$full_stage_counts, row.names = FALSE)
utils::write.csv(smoke_stage_counts, paths$smoke_stage_counts, row.names = FALSE)

cat(sprintf("dataset_rows=%d\n", nrow(dataset_registry)))
cat(sprintf("method_profiles=%d\n", nrow(method_registry)))
cat(sprintf("full_rows=%d\n", nrow(full_manifest)))
cat(sprintf("smoke_rows=%d\n", nrow(smoke_manifest)))
cat(sprintf("dataset_missing_inputs=%d\n", sum(dataset_registry$missing_inputs)))
cat("full_phase_counts:\n")
print(full_stage_counts, row.names = FALSE)
cat("smoke_phase_counts:\n")
print(smoke_stage_counts, row.names = FALSE)
