#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

registry_output_path <- "tools/merge_reports/LOCAL_original288_registry_v1_20260405.csv"

registry <- read_original288_registry_original288()

write.csv(registry, registry_output_path, row.names = FALSE, na = "")

cat(sprintf("Wrote original-288 registry to %s\n", registry_output_path))
cat(sprintf("Rows: %d\n", nrow(registry)))
cat(sprintf("Unique original_case_key: %d\n", length(unique(registry$original_case_key))))
