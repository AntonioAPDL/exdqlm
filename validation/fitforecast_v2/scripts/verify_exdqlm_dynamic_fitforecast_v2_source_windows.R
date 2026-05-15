#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "validation/fitforecast_v2/scripts/verify_exdqlm_dynamic_fitforecast_v2_source_windows.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
defaults_path <- args$defaults %||% ffv2_default_defaults_path()
out <- args$out %||% NULL
defaults <- ffv2_load_defaults(defaults_path)
ffv2_assert_runtime(defaults$runtime$r_min_version %||% "4.6.0")
registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
verification <- ffv2_verify_source_windows(registry, stop_on_fail = TRUE)
if (!is.null(out)) ffv2_write_csv(verification, out)

cat("exDQLM/DQLM dynamic fit+forecast v2 source verification\n")
cat(sprintf("registry_rows: %d\n", nrow(registry)))
cat(sprintf("verification_rows: %d\n", nrow(verification)))
print(table(verification$status, useNA = "ifany"))
if (!is.null(out)) cat(sprintf("verification: %s\n", normalizePath(out, winslash = "/", mustWork = TRUE)))
