#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "validation/fitforecast_v2/scripts/export_exdqlm_dynamic_fitforecast_v2_shared_interface.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
manifest_path <- args$manifest
if (is.null(manifest_path)) {
  defaults <- ffv2_load_defaults(args$defaults %||% ffv2_default_defaults_path())
  run_root <- ffv2_resolve_path(file.path(defaults$study$results_root, defaults$study$run_tag), must_work = TRUE)
  manifest_path <- file.path(run_root, "manifests", "row_manifest.csv")
}
manifest <- ffv2_read_csv(manifest_path)
out <- args$out %||% file.path(unique(manifest$run_root)[[1L]], "interfaces", "exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv")
interface <- ffv2_export_shared_interface(manifest, out)
cat(sprintf("shared_interface_rows: %d\n", nrow(interface)))
cat(sprintf("shared_interface: %s\n", normalizePath(out, winslash = "/", mustWork = TRUE)))
