#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_exactspec_multiseed()

run_dir <- paths$run_root
if (dir.exists(run_dir)) {
  unlink(run_dir, recursive = TRUE, force = TRUE)
}

for (path in c(
  paths$run_root,
  paths$config_dir,
  paths$rows_dir,
  paths$health_dir,
  paths$metrics_dir,
  paths$draws_dir,
  paths$logs_dir,
  dirname(paths$program_doc),
  dirname(paths$comparison_report)
)) {
  ensure_dir_original288_exactspec_multiseed(path)
}

selection <- read.csv(paths$selection, stringsAsFactors = FALSE, check.names = FALSE)
selection$base_row_id <- seq_len(nrow(selection))

full_built <- build_manifest_original288_exactspec_multiseed(
  selection = selection,
  kind = "full",
  repo_root = repo_root
)
utils::write.csv(full_built$config_index, paths$config_index, row.names = FALSE)
utils::write.csv(full_built$audit, paths$resolution_audit, row.names = FALSE)
utils::write.csv(full_built$seedbank, paths$seedbank, row.names = FALSE)
utils::write.csv(full_built$manifest, paths$full_manifest, row.names = FALSE)

smoke_keys <- smoke_case_keys_original288_exactspec_multiseed(selection)
smoke_selection <- selection[selection$original_case_key %in% smoke_keys, , drop = FALSE]
smoke_built <- build_manifest_original288_exactspec_multiseed(
  selection = smoke_selection,
  kind = "smoke",
  repo_root = repo_root
)
utils::write.csv(smoke_built$manifest, paths$smoke_manifest, row.names = FALSE)

full_stage_counts <- as.data.frame(with(full_built$manifest, table(phase)), stringsAsFactors = FALSE)
names(full_stage_counts) <- c("phase", "rows")
full_stage_counts$phase_order <- unname(phase_order_original288_exactspec_multiseed[full_stage_counts$phase])
full_stage_counts <- full_stage_counts[order(full_stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(full_stage_counts, paths$full_stage_counts, row.names = FALSE)

smoke_stage_counts <- as.data.frame(with(smoke_built$manifest, table(phase)), stringsAsFactors = FALSE)
names(smoke_stage_counts) <- c("phase", "rows")
smoke_stage_counts$phase_order <- unname(phase_order_original288_exactspec_multiseed[smoke_stage_counts$phase])
smoke_stage_counts <- smoke_stage_counts[order(smoke_stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(smoke_stage_counts, paths$smoke_stage_counts, row.names = FALSE)

control_audit <- aggregate(
  list(
    total = rep(1L, nrow(full_built$manifest)),
    missing_inputs = full_built$manifest$missing_inputs
  ),
  by = list(
    block = full_built$manifest$block,
    model = full_built$manifest$model,
    inference = full_built$manifest$inference,
    source_config_style = full_built$manifest$source_config_style,
    selected_source_type = full_built$manifest$selected_source_type
  ),
  FUN = function(x) sum(x, na.rm = TRUE)
)
utils::write.csv(control_audit, paths$control_audit, row.names = FALSE)

cat(sprintf("selection_rows=%d\n", nrow(selection)))
cat(sprintf("smoke_rows=%d\n", nrow(smoke_built$manifest)))
cat(sprintf("full_rows=%d\n", nrow(full_built$manifest)))
cat(sprintf("resolved_rows=%d\n", nrow(full_built$audit)))
cat(sprintf("resolution_min_score=%d\n", min(full_built$audit$resolution_score)))
cat(sprintf("missing_inputs_full=%d\n", sum(full_built$manifest$missing_inputs)))
cat("smoke_phase_counts:\n")
print(smoke_stage_counts, row.names = FALSE)
cat("full_phase_counts:\n")
print(full_stage_counts, row.names = FALSE)
