#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "validation/fitforecast_v2/scripts/run_exdqlm_dynamic_fitforecast_v2_row.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
row_config <- args$`row-config`
if (is.null(row_config)) stop("--row-config is required.", call. = FALSE)
force <- ffv2_truthy(args$force %||% FALSE)
runtime_overrides <- ffv2_runtime_overrides_from_args(args)
validation_stage <- ffv2_validation_stage(args$`validation-stage` %||% "all")
ffv2_run_row(
  row_config,
  force = force,
  runtime_overrides = runtime_overrides,
  validation_stage = validation_stage
)
