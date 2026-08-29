#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_exdqlm_mcmc_rolling_state_fix_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
run_id <- as.character(args$`run-id` %||% "")[1L]
mode <- as.character(args$mode %||% "sentinel")[1L]
if (!nzchar(run_id)) stop("--run-id is required.", call. = FALSE)
if (!(mode %in% c("sentinel", "full"))) {
  stop("--mode must be sentinel or full.", call. = FALSE)
}
out <- iems_v1_materialize(repo_root, run_id, mode = mode)
cat(sprintf("MATERIALIZED mode=%s jobs=%d manifest=%s\n",
            mode, nrow(out$jobs), out$manifest_path))
