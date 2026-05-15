#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
repo_root <- normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
setwd(repo_root)

full_grid_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv"
)
output_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_grid.csv"
)

full_grid <- utils::read.csv(full_grid_path, stringsAsFactors = FALSE)
root_ids <- c(
  "root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_500__qdesn_ridge",
  "root__dynamic__dlm_constV_smallW__normal__tau_0p25__lasttt_500__qdesn_rhs_ns",
  "root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_5000__qdesn_ridge",
  "root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_rhs_ns",
  "root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_rhs_ns",
  "root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns"
)

canary_grid <- full_grid[match(root_ids, full_grid$root_id), , drop = FALSE]
missing_ids <- root_ids[is.na(match(root_ids, full_grid$root_id))]
if (length(missing_ids)) {
  stop(
    sprintf(
      "Failed to materialize normalized multiseed canary grid; missing root ids: %s",
      paste(missing_ids, collapse = ", ")
    ),
    call. = FALSE
  )
}

utils::write.csv(canary_grid, output_path, row.names = FALSE)
cat(sprintf("Wrote %d canary roots to %s\n", nrow(canary_grid), output_path))
