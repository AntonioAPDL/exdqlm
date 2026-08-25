#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_metric_interval_coupling_pilot_v1.R"
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
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    engine = row$engine[[1L]], model_variant = row$model_variant[[1L]],
    family = row$family[[1L]], tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    status = as.character(status$status),
    coupling_draws_path = as.character(status$metric_coupling_draws_path %||% ""),
    coupling_draws_sha256 = as.character(status$metric_coupling_draws_sha256 %||% ""),
    heavy_binary_count = as.integer(status$heavy_binary_count %||% NA_integer_),
    stringsAsFactors = FALSE
  )
})
status_index <- do.call(rbind, status_rows)
if (nrow(status_index) != 33L || any(status_index$status != "SUCCESS")) {
  stop("Coupling pilot is not complete and successful for all 33 jobs.", call. = FALSE)
}
status_index$coupling_draws_exist <- file.exists(status_index$coupling_draws_path)
status_index$coupling_hash_match <- vapply(seq_len(nrow(status_index)), function(i) {
  status_index$coupling_draws_exist[[i]] &&
    identical(ffv2_file_sha256(status_index$coupling_draws_path[[i]]),
              status_index$coupling_draws_sha256[[i]])
}, logical(1L))
if (any(!status_index$coupling_hash_match)) {
  stop("One or more coupling artifacts fail their terminal-status hash.", call. = FALSE)
}

summary <- imic_v1_pool_coupling_draws(status_index)
paired <- imic_v1_compare_coupling_modes(summary)
primary_replay <- imic_v1_primary_replay_comparison(summary, imic_v1_promotion_dir(repo_root))
overlap <- imic_v1_article_overlap_sensitivity(summary, imic_v1_promotion_dir(repo_root))

heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
storage <- data.frame(
  heavy_binary_count = length(heavy),
  heavy_binary_bytes = if (length(heavy)) sum(as.numeric(file.info(heavy)$size)) else 0,
  coupling_draw_files = nrow(status_index),
  coupling_draw_bytes = sum(as.numeric(file.info(status_index$coupling_draws_path)$size)),
  stringsAsFactors = FALSE
)

replay_pass <- all(primary_replay$primary_replay_match)
material <- any(paired$severity == "MATERIAL") || any(overlap$overlap_conclusion_changed)
decision <- if (!replay_pass) {
  "PILOT_INVALID_REPLAY_MISMATCH"
} else if (material) {
  "V10_1_MATCHED_COUPLING_REPLAY_REQUIRED"
} else {
  "RETAIN_V10_COUPLING_SENSITIVITY_PASS"
}
checks <- data.frame(
  check = c("jobs_33_success", "coupling_hashes_match", "three_chains_per_source",
            "primary_replay_matches_v10", "finite_paired_statistics",
            "mean_invariance", "no_overlap_conclusion_change", "no_heavy_binaries"),
  pass = c(
    nrow(status_index) == 33L && all(status_index$status == "SUCCESS"),
    all(status_index$coupling_hash_match),
    all(table(status_index$replay_id) == 3L),
    replay_pass,
    all(is.finite(as.matrix(paired[c("relative_mean_shift", "width_ratio",
                                     "endpoint_shift_primary_width")]))),
    all(paired$relative_mean_shift <= 5e-10),
    !any(overlap$overlap_conclusion_changed),
    length(heavy) == 0L
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  status = ffv2_write_csv(status_index, file.path(closeout_root, "job_artifact_audit.csv")),
  summary = ffv2_write_csv(summary, file.path(closeout_root, "coupling_interval_summary.csv")),
  paired = ffv2_write_csv(paired, file.path(closeout_root, "paired_coupling_comparison.csv")),
  replay = ffv2_write_csv(primary_replay,
                          file.path(closeout_root, "primary_replay_vs_v10.csv")),
  overlap = ffv2_write_csv(overlap,
                           file.path(closeout_root, "article_overlap_sensitivity.csv")),
  storage = ffv2_write_csv(storage, file.path(closeout_root, "storage_audit.csv")),
  checks = ffv2_write_csv(checks, file.path(closeout_root, "closeout_checks.csv"))
)
manifest <- list(
  schema_version = imic_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  decision = decision,
  article_update_authorized = FALSE,
  v10_remains_frozen = TRUE,
  planned_jobs = nrow(status_index),
  completed_jobs = sum(status_index$status == "SUCCESS"),
  replay_sources = length(unique(status_index$replay_id)),
  material_comparisons = sum(paired$severity == "MATERIAL"),
  review_comparisons = sum(paired$severity == "REVIEW"),
  overlap_conclusion_changes = sum(overlap$overlap_conclusion_changed),
  heavy_binary_count = length(heavy),
  output_hashes = lapply(paths, ffv2_file_sha256)
)
ffv2_write_json(manifest, file.path(closeout_root, "decision_manifest.json"))
cat(sprintf("decision=%s jobs=%d/%d material=%d review=%d overlap_changes=%d heavy=%d\n",
            decision, manifest$completed_jobs, manifest$planned_jobs,
            manifest$material_comparisons, manifest$review_comparisons,
            manifest$overlap_conclusion_changes, manifest$heavy_binary_count))
if (!replay_pass || !all(checks[c(1, 2, 3, 5, 8), "pass"])) {
  quit(save = "no", status = 1L)
}
