#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_interval_dispersion_diagnostic_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
closeout_root <- ffv2_ensure_dir(file.path(state_root, "closeout"))

status_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  status_path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  status <- ffv2_read_json(status_path)
  data.frame(
    job_id = row$job_id[[1L]],
    replay_id = row$replay_id[[1L]],
    model_variant = row$model_variant[[1L]],
    family = row$family[[1L]],
    tau = row$tau[[1L]],
    chain_id = row$chain_id[[1L]],
    sentinel_role = row$sentinel_role[[1L]],
    status = as.character(status$status),
    dispersion_manifest_path = as.character(status$metric_dispersion_manifest_path %||% ""),
    dispersion_manifest_sha256 = as.character(status$metric_dispersion_manifest_sha256 %||% ""),
    dispersion_draws_path = as.character(status$metric_dispersion_draws_path %||% ""),
    dispersion_draws_sha256 = as.character(status$metric_dispersion_draws_sha256 %||% ""),
    coupling_draws_path = as.character(status$metric_coupling_draws_path %||% ""),
    coupling_draws_sha256 = as.character(status$metric_coupling_draws_sha256 %||% ""),
    heavy_binary_count = as.integer(status$heavy_binary_count %||% NA_integer_),
    stringsAsFactors = FALSE
  )
})
status_index <- do.call(rbind, status_rows)
if (nrow(status_index) != 21L || any(status_index$status != "SUCCESS") ||
    any(table(status_index$replay_id) != 3L)) {
  stop("Dispersion campaign is not complete for all 21 jobs.", call. = FALSE)
}

hash_fields <- list(
  dispersion_manifest = c("dispersion_manifest_path", "dispersion_manifest_sha256"),
  dispersion_draws = c("dispersion_draws_path", "dispersion_draws_sha256"),
  coupling_draws = c("coupling_draws_path", "coupling_draws_sha256")
)
for (name in names(hash_fields)) {
  fields <- hash_fields[[name]]
  status_index[[paste0(name, "_hash_match")]] <- vapply(seq_len(nrow(status_index)), function(i) {
    path <- status_index[[fields[[1L]]]][[i]]
    nzchar(path) && file.exists(path) && identical(
      ffv2_file_sha256(path), status_index[[fields[[2L]]]][[i]]
    )
  }, logical(1L))
}
hash_columns <- grep("_hash_match$", names(status_index), value = TRUE)
if (any(!as.matrix(status_index[hash_columns]))) {
  stop("One or more terminal diagnostic artifacts fail hash verification.", call. = FALSE)
}

pooled <- imid_v1_pool_diagnostics(status_index)
gate <- imid_v1_followup_gate(pooled)
heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
storage <- data.frame(
  heavy_binary_count = length(heavy),
  heavy_binary_bytes = if (length(heavy)) sum(as.numeric(file.info(heavy)$size)) else 0,
  compact_artifact_bytes = sum(vapply(unique(plan$job_root), function(root) {
    files <- if (dir.exists(root)) list.files(root, recursive = TRUE, full.names = TRUE) else character(0)
    if (length(files)) sum(as.numeric(file.info(files)$size), na.rm = TRUE) else 0
  }, numeric(1L))),
  stringsAsFactors = FALSE
)
checks <- data.frame(
  check = c("jobs_21_success", "three_chains_per_source", "terminal_hashes_match",
            "finite_width_decomposition", "same_primary_estimator", "no_auto_followup",
            "no_article_promotion", "no_heavy_binaries"),
  pass = c(
    nrow(status_index) == 21L && all(status_index$status == "SUCCESS"),
    all(table(status_index$replay_id) == 3L),
    all(as.matrix(status_index[hash_columns])),
    all(is.finite(as.matrix(pooled[c("native_mae_width", "plugin_mae_width",
                                     "plugin_to_native_width_ratio",
                                     "origin_permuted_to_native_width_ratio")]))),
    all(gate$preserve_primary_stochastic_recursion),
    !any(gate$automatic_followup_launch_authorized),
    !any(gate$article_update_authorized),
    length(heavy) == 0L
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  status = ffv2_write_csv(status_index, file.path(closeout_root, "job_artifact_audit.csv")),
  pooled = ffv2_write_csv(pooled, file.path(closeout_root, "pooled_mechanism_diagnosis.csv")),
  gate = ffv2_write_csv(gate, file.path(closeout_root, "mechanism_gated_followup_plan.csv")),
  storage = ffv2_write_csv(storage, file.path(closeout_root, "storage_audit.csv")),
  checks = ffv2_write_csv(checks, file.path(closeout_root, "closeout_checks.csv"))
)
decision <- if (!all(checks$pass)) {
  "DIAGNOSTIC_CLOSEOUT_FAILED"
} else if (all(pooled$mechanism %in% c("recursive_innovation_and_cross_origin_dependence",
                                       "recursive_innovation_dominant"))) {
  "RECURSIVE_INNOVATION_DOMINANT_DO_NOT_START_TAU0_SCREEN"
} else if (any(pooled$tau0_only_screen_authorized)) {
  "CASE_SPECIFIC_PRIOR_INTERVENTION_ELIGIBLE_FOR_SELECTED_CELLS"
} else {
  "MIXED_MECHANISMS_REQUIRE_CASE_SPECIFIC_FOLLOWUP"
}
report_path <- file.path(closeout_root, "scientific_closeout.md")
lines <- c(
  "# Independent Q-DESN metric-interval dispersion diagnosis",
  "",
  sprintf("Decision: `%s`", decision),
  "",
  "The authoritative posterior-predictive recursion and point metrics were not changed.",
  "The conditional-mean plug-in recursion is a mechanism diagnostic, not an alternative promoted estimator.",
  "No article update or automatic hyperparameter launch is authorized by this closeout.",
  "",
  "## Cell-level mechanism decisions",
  "",
  paste0("- `", pooled$replay_id, "`: ", pooled$mechanism,
         "; plug-in/native width ratio = ",
         format(round(pooled$plugin_to_native_width_ratio, 3), nsmall = 3),
         "; origin-permuted/native ratio = ",
         format(round(pooled$origin_permuted_to_native_width_ratio, 3), nsmall = 3),
         ".")
)
writeLines(lines, report_path)
paths$report <- normalizePath(report_path, winslash = "/", mustWork = TRUE)
manifest <- list(
  schema_version = imid_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  decision = decision,
  article_update_authorized = FALSE,
  automatic_followup_launch_authorized = FALSE,
  primary_estimator_changed = FALSE,
  completed_jobs = sum(status_index$status == "SUCCESS"),
  planned_jobs = nrow(status_index),
  replay_sources = length(unique(status_index$replay_id)),
  heavy_binary_count = length(heavy),
  output_hashes = lapply(paths, ffv2_file_sha256)
)
ffv2_write_json(manifest, file.path(closeout_root, "decision_manifest.json"))
cat(sprintf("decision=%s jobs=%d/%d sources=%d heavy=%d\n", decision,
            manifest$completed_jobs, manifest$planned_jobs, manifest$replay_sources,
            manifest$heavy_binary_count))
if (!all(checks$pass)) quit(save = "no", status = 1L)
