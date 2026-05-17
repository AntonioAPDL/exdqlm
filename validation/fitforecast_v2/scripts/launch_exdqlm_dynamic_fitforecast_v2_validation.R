#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
phase <- args$phase %||% "smoke"
allowed <- c("smoke", "pilot", "vb_full", "mcmc_tt500", "mcmc_tt5000", "all")
if (!phase %in% allowed) stop(sprintf("--phase must be one of: %s", paste(allowed, collapse = ", ")), call. = FALSE)
dry_run <- ffv2_truthy(args$`dry-run` %||% FALSE)
include_completed <- ffv2_truthy(args$`include-completed` %||% FALSE)
validation_stage <- ffv2_validation_stage(args$`validation-stage` %||% "all")
runtime_overrides <- ffv2_runtime_overrides_from_args(args)
selectors <- list(
  spec_ids = ffv2_split_csv_arg(args$`spec-ids` %||% args$`spec-id` %||% ""),
  row_ids = ffv2_split_int_arg(args$`row-ids` %||% args$`row-id` %||% ""),
  row_keys = ffv2_split_csv_arg(args$`row-keys` %||% args$`row-key` %||% ""),
  families = ffv2_split_csv_arg(args$families %||% args$family %||% ""),
  taus = ffv2_split_num_arg(args$taus %||% args$tau %||% ""),
  fit_sizes = ffv2_split_int_arg(args$`fit-sizes` %||% args$`fit-size` %||% ""),
  model_variants = ffv2_split_csv_arg(args$`model-variants` %||% args$`model-variant` %||% ""),
  inferences = ffv2_split_csv_arg(args$inferences %||% args$inference %||% "")
)
manifest_path <- args$manifest %||% NULL
if (is.null(manifest_path)) {
  defaults <- ffv2_load_defaults(args$defaults %||% ffv2_default_defaults_path())
  run_root <- ffv2_resolve_path(file.path(defaults$study$results_root, defaults$study$run_tag), must_work = TRUE)
  manifest_path <- file.path(run_root, "manifests", "row_manifest.csv")
}
manifest <- ffv2_read_csv(manifest_path)
ffv2_stop_stale_paths(manifest)
selected <- ffv2_select_manifest_rows(
  manifest,
  phase = phase,
  include_completed = include_completed,
  selectors = selectors
)

cat("exDQLM/DQLM dynamic fit+forecast v2 launch wrapper\n")
cat(sprintf("phase: %s\n", phase))
cat(sprintf("validation_stage: %s\n", validation_stage))
cat(sprintf("dry_run: %s\n", dry_run))
cat(sprintf("manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("selected_rows: %d\n", nrow(selected)))
if (!nrow(selected)) quit(status = 0L, save = "no")
print(selected[, intersect(c("row_id", "spec_id", "family", "tau", "fit_size", "model_variant", "inference", "phase"), names(selected))])

runtime_cli_args <- ffv2_runtime_override_cli_args(runtime_overrides)
cmds <- sprintf(
  "Rscript %s --row-config %s --validation-stage %s%s",
  shQuote(file.path(harness_root, "scripts", "run_exdqlm_dynamic_fitforecast_v2_row.R")),
  shQuote(selected$row_config_path),
  shQuote(validation_stage),
  if (length(runtime_cli_args)) paste0(" ", paste(shQuote(runtime_cli_args), collapse = " ")) else ""
)
if (dry_run) {
  cat("dry_run_commands:\n")
  cat(paste(cmds, collapse = "\n"), "\n")
  quit(status = 0L, save = "no")
}
approved <- ffv2_truthy(Sys.getenv("EXDQLM_FFV2_LAUNCH_APPROVED", "false"))
if (!approved) {
  stop("Refusing to launch. Set EXDQLM_FFV2_LAUNCH_APPROVED=true for an approved staged run.",
       call. = FALSE)
}
defaults <- ffv2_load_defaults(args$defaults %||% ffv2_default_defaults_path())
worker_defaults <- defaults$runtime$workers %||% list()
workers <- as.integer(args$workers %||% worker_defaults[[phase]] %||% 1L)
workers <- max(1L, workers)
cat(sprintf("workers: %d\n", workers))
if (length(runtime_overrides)) {
  cat("runtime_overrides:\n")
  print(runtime_overrides)
}
parallel::mclapply(selected$row_config_path, function(path) {
  ffv2_run_row(path, runtime_overrides = runtime_overrides, validation_stage = validation_stage)
}, mc.cores = workers)
