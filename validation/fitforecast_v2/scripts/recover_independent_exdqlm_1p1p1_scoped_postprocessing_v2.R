#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/recover_independent_exdqlm_1p1p1_scoped_postprocessing_v2.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
git_state <- i111s_assert_clean_synced_branch(repo_root)
state_root <- i111s_assert_scoped_state_root(args$`state-root` %||% "", repo_root)
manifest <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
if (!identical(as.character(manifest$schema_version), i111s_schema)) {
  stop("Postprocessing recovery requires the scoped exDQLM 1.1.1 campaign.",
       call. = FALSE)
}

original_status_path <- file.path(state_root, "pipeline.status")
original_handoff_path <- file.path(state_root, "closeout", "integration_handoff.json")
original_candidate_path <- file.path(
  state_root, "closeout", "candidate_full_interface_exdqlm_only_replacement.csv"
)
required_original <- c(original_status_path, original_handoff_path, original_candidate_path)
if (!all(file.exists(required_original))) {
  stop("The immutable original failure evidence is incomplete.", call. = FALSE)
}
original_status <- paste(readLines(original_status_path, warn = FALSE), collapse = "\n")
if (!grepl("^status=FAIL", original_status)) {
  stop("Recovery is only valid for the preserved postprocessing failure.", call. = FALSE)
}

health_path <- file.path(state_root, "health", "health_current.json")
health <- ffv2_read_json(health_path)
if (!isTRUE(health$all_complete) || as.integer(health$completed) != i111s_expected_jobs ||
    as.integer(health$running) != 0L || as.integer(health$failed) != 0L) {
  stop("Scientific jobs are not completely and cleanly closed.", call. = FALSE)
}

closeout_root <- file.path(state_root, "closeout_v2")
diagnostic_root <- file.path(state_root, "diagnostics", "exdqlm_1p1p1_scoped_v2")
recovery_root <- file.path(state_root, "postprocessing_recovery_v2")
for (path in c(closeout_root, diagnostic_root, recovery_root)) {
  if (dir.exists(path) && length(list.files(path, all.files = TRUE, no.. = TRUE))) {
    stop(sprintf("Refusing nonempty recovery output: %s", path), call. = FALSE)
  }
  ffv2_ensure_dir(path)
}

run_step <- function(name, script, step_args) {
  log_path <- file.path(recovery_root, paste0(name, ".log"))
  command <- file.path(R.home("bin"), "Rscript")
  status <- system2(
    command,
    c(shQuote(script), vapply(step_args, shQuote, character(1L))),
    stdout = log_path, stderr = log_path
  )
  if (!identical(as.integer(status), 0L)) {
    stop(sprintf("Recovery step %s failed; see %s.", name, log_path), call. = FALSE)
  }
  normalizePath(log_path, winslash = "/", mustWork = TRUE)
}

script_root <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
closeout_log <- run_step(
  "01_closeout_v2",
  file.path(script_root, "closeout_independent_exdqlm_1p1p1_scoped_continuation_v1.R"),
  c("--repo-root", repo_root, "--state-root", state_root,
    "--output-root", closeout_root)
)
diagnostic_log <- run_step(
  "02_diagnostic_packet_v2",
  file.path(script_root, "build_independent_exdqlm_1p1p1_scoped_diagnostic_packet_v1.R"),
  c("--state-root", state_root, "--closeout-root", closeout_root,
    "--output-root", diagnostic_root)
)

closeout_handoff_path <- file.path(closeout_root, "closeout_handoff_v2.json")
closeout_checks_path <- file.path(closeout_root, "closeout_checks_v2.csv")
packet_manifest_path <- file.path(diagnostic_root, "packet_manifest.json")
figure_manifest_path <- file.path(diagnostic_root, "figure_manifest.csv")
closeout_handoff <- ffv2_read_json(closeout_handoff_path)
closeout_checks <- ffv2_read_csv(closeout_checks_path)
packet_manifest <- ffv2_read_json(packet_manifest_path)
figure_manifest <- ffv2_read_csv(figure_manifest_path)

checks <- c(
  original_pipeline_failure_preserved = grepl("^status=FAIL", original_status),
  original_handoff_preserved = file.exists(original_handoff_path),
  original_candidate_preserved = file.exists(original_candidate_path),
  scientific_jobs_36_complete = isTRUE(health$all_complete) &&
    as.integer(health$completed) == i111s_expected_jobs,
  no_scientific_jobs_running = as.integer(health$running) == 0L,
  closeout_v2_checks_pass = all(closeout_checks$pass),
  closeout_v2_estimator_separated = identical(
    as.character(closeout_handoff$closeout_revision), "v2_estimator_separated"
  ),
  diagnostic_packet_pass = identical(as.character(packet_manifest$status), "PASS"),
  diagnostic_figures_5 = nrow(figure_manifest) == 5L,
  diagnostic_combined_pdf_exists = file.exists(packet_manifest$combined_pdf_path),
  no_article_write = isFALSE(closeout_handoff$article_write_performed) &&
    isFALSE(packet_manifest$article_write_performed)
)
checks_path <- ffv2_write_csv(
  data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE),
  file.path(recovery_root, "recovery_checks.csv")
)
if (!all(checks)) {
  stop(sprintf("Postprocessing recovery failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

recovery_manifest <- list(
  schema_version = i111s_schema,
  recovery_revision = "postprocessing_recovery_v2",
  status = "PASS",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = as.character(manifest$run_id),
  recovery_scope = "closeout_and_diagnostics_only_no_model_execution",
  original_pipeline_status_path = original_status_path,
  original_pipeline_status_sha256 = ffv2_file_sha256(original_status_path),
  original_pipeline_status = original_status,
  original_handoff_path = original_handoff_path,
  original_handoff_sha256 = ffv2_file_sha256(original_handoff_path),
  original_unsafe_candidate_path = original_candidate_path,
  original_unsafe_candidate_sha256 = ffv2_file_sha256(original_candidate_path),
  closeout_v2_path = closeout_handoff_path,
  closeout_v2_sha256 = ffv2_file_sha256(closeout_handoff_path),
  diagnostic_packet_manifest_path = packet_manifest_path,
  diagnostic_packet_manifest_sha256 = ffv2_file_sha256(packet_manifest_path),
  diagnostic_combined_pdf_path = as.character(packet_manifest$combined_pdf_path),
  diagnostic_combined_pdf_sha256 = as.character(packet_manifest$combined_pdf_sha256),
  checks_path = checks_path,
  checks_sha256 = ffv2_file_sha256(checks_path),
  closeout_log_path = closeout_log,
  closeout_log_sha256 = ffv2_file_sha256(closeout_log),
  diagnostic_log_path = diagnostic_log,
  diagnostic_log_sha256 = ffv2_file_sha256(diagnostic_log),
  scientific_jobs_reexecuted = 0L,
  article_write_performed = FALSE,
  shared_validation_write_performed = FALSE,
  overleaf_write_performed = FALSE,
  recovery_commit = system2(
    "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
  ),
  recovery_branch = git_state$branch,
  recovery_upstream = git_state$upstream
)
recovery_manifest_path <- ffv2_write_json(
  recovery_manifest, file.path(recovery_root, "recovery_manifest.json")
)

final_handoff <- closeout_handoff
final_handoff$status <- "READY_FOR_INTEGRATION"
final_handoff$generated_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
final_handoff$diagnostic_recovery_required <- FALSE
final_handoff$diagnostic_packet_manifest_path <- packet_manifest_path
final_handoff$diagnostic_packet_manifest_sha256 <- ffv2_file_sha256(packet_manifest_path)
final_handoff$diagnostic_combined_pdf_path <- as.character(
  packet_manifest$combined_pdf_path
)
final_handoff$diagnostic_combined_pdf_sha256 <- as.character(
  packet_manifest$combined_pdf_sha256
)
final_handoff$recovery_manifest_path <- recovery_manifest_path
final_handoff$recovery_manifest_sha256 <- ffv2_file_sha256(recovery_manifest_path)
final_handoff$original_pipeline_status_retained <- TRUE
final_handoff$integration_note <- paste(
  "The scientific run completed 36/36 jobs. The preserved pipeline FAIL belongs",
  "only to the original diagnostic renderer; estimator-separated closeout and",
  "diagnostic recovery both pass."
)
final_handoff_path <- ffv2_write_json(
  final_handoff, file.path(closeout_root, "integration_handoff_v2.json")
)
writeLines(
  sprintf(
    "status=PASS run_id=%s scientific_jobs_reexecuted=0 final_handoff_sha256=%s recovered_at=%s",
    as.character(manifest$run_id), ffv2_file_sha256(final_handoff_path),
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  ),
  file.path(state_root, "postprocessing_recovery.status"), useBytes = TRUE
)
cat(sprintf("POSTPROCESSING_RECOVERED handoff=%s\n", final_handoff_path))
