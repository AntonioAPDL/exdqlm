#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/freeze_independent_exdqlm_mcmc_rolling_state_fix_v1_promotion.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
git_state <- iems_v1_assert_clean_synced_task_branch(repo_root)
run_id <- as.character(args$`run-id` %||% iems_v1_full_run_id)
if (!identical(run_id, iems_v1_full_run_id)) {
  stop(sprintf("Refusing non-authoritative full run: %s", run_id), call. = FALSE)
}
run_root <- normalizePath(iems_v1_results_root(repo_root, run_id), winslash = "/",
                          mustWork = TRUE)
orchestration_root <- normalizePath(
  iems_v1_orchestration_root(repo_root, run_id), winslash = "/", mustWork = TRUE
)
closeout_root <- file.path(run_root, "closeout")
output_root <- ffv2_resolve_path(
  args$`output-root` %||% iems_v1_frozen_promotion_root(repo_root),
  repo_root = repo_root, must_work = FALSE
)
if (!startsWith(output_root, paste0(repo_root, "/"))) {
  stop("Promotion output must remain inside the task worktree.", call. = FALSE)
}
if (dir.exists(output_root) && length(list.files(output_root, all.files = TRUE,
                                                  no.. = TRUE))) {
  stop(sprintf("Refusing nonempty promotion root: %s", output_root), call. = FALSE)
}
ffv2_ensure_dir(output_root)

source_handoff <- ffv2_read_json(file.path(closeout_root, "integration_handoff.json"))
source_manifest <- ffv2_read_csv(file.path(closeout_root, "output_file_manifest.csv"))
source_paths <- as.character(source_manifest$path)
source_ok <- file.exists(source_paths) &
  vapply(source_paths, ffv2_file_sha256, character(1L)) == source_manifest$sha256 &
  as.numeric(file.info(source_paths)$size) == as.numeric(source_manifest$bytes)
if (!all(source_ok) || nrow(source_manifest) != 13L) {
  stop("The source closeout manifest is incomplete or changed.", call. = FALSE)
}
if (!identical(as.character(source_handoff$scientific_decision),
               "READY_FOR_INTEGRATION_REPLACE_COMPLETE_EXDQLM_MCMC_BLOCK")) {
  stop("The source closeout is not authorized for complete-block integration.",
       call. = FALSE)
}

copy_one <- function(source, relative_target) {
  if (!file.exists(source)) stop(sprintf("Missing freeze source: %s", source),
                                 call. = FALSE)
  target <- file.path(output_root, relative_target)
  ffv2_ensure_dir(dirname(target))
  if (!file.copy(source, target, overwrite = FALSE, copy.mode = TRUE)) {
    stop(sprintf("Could not freeze %s.", source), call. = FALSE)
  }
  normalizePath(target, winslash = "/", mustWork = TRUE)
}

for (i in seq_len(nrow(source_manifest))) {
  copy_one(source_paths[[i]], file.path("scientific", source_manifest$file[[i]]))
}
support_map <- c(
  "source/closeout_integration_handoff.json" =
    file.path(closeout_root, "integration_handoff.json"),
  "source/closeout_output_file_manifest.csv" =
    file.path(closeout_root, "output_file_manifest.csv"),
  "manifests/job_manifest.csv" = file.path(run_root, "manifests", "job_manifest.csv"),
  "manifests/materialization_manifest.json" =
    file.path(run_root, "manifests", "materialization_manifest.json"),
  "manifests/preflight_report.json" =
    file.path(run_root, "manifests", "preflight_report.json"),
  "runtime/run_contract.env" = file.path(orchestration_root, "run_contract.env"),
  "runtime/stage_status.csv" = file.path(orchestration_root, "stage_status.csv"),
  "runtime/pipeline.status" = file.path(orchestration_root, "pipeline.status"),
  "runtime/health_snapshot.json" =
    file.path(orchestration_root, "healthcheck_latest", "health_snapshot.json"),
  "runtime/row_health_snapshot.csv" =
    file.path(orchestration_root, "healthcheck_latest", "row_health_snapshot.csv"),
  "diagnostics/packet_manifest.json" =
    file.path(orchestration_root, "diagnostics", "packet_manifest.json"),
  "diagnostics/figure_manifest.csv" =
    file.path(orchestration_root, "diagnostics", "figure_manifest.csv")
)
invisible(vapply(names(support_map), function(target) {
  copy_one(unname(support_map[[target]]), target)
}, character(1L)))

scientific <- function(name) file.path(output_root, "scientific", name)
point <- ffv2_read_csv(scientific("candidate_point_exdqlm_mcmc_rows.csv"))
interval <- ffv2_read_csv(scientific("candidate_interval_exdqlm_mcmc_roles.csv"))
chains <- ffv2_read_csv(scientific("chain_metric_comparison.csv"))
metric_diagnostics <- ffv2_read_csv(scientific("mcmc_metric_diagnostics.csv"))
confirmation_checks <- ffv2_read_csv(scientific("full_confirmation_checks.csv"))
promotion_checks <- iems_v1_promotion_contract_checks(
  point, interval, chains, metric_diagnostics, confirmation_checks
)
promotion_checks <- c(
  promotion_checks,
  source_manifest_13 = nrow(source_manifest) == 13L && all(source_ok),
  no_heavy_binaries = !length(list.files(
    output_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  ))
)
if (!all(promotion_checks)) {
  stop(sprintf("Promotion freeze checks failed: %s",
               paste(names(promotion_checks)[!promotion_checks], collapse = ", ")),
       call. = FALSE)
}
ffv2_write_csv(
  data.frame(check = names(promotion_checks), pass = unname(promotion_checks),
             stringsAsFactors = FALSE),
  file.path(output_root, "promotion_checks.csv")
)

replacement_contract <- data.frame(
  surface = c("fixed_path_point_metrics", "posterior_draw_metric_intervals"),
  candidate_file = c(
    "scientific/candidate_point_exdqlm_mcmc_rows.csv",
    "scientific/candidate_interval_exdqlm_mcmc_roles.csv"
  ),
  key_columns = c(
    "inference;model_variant;family;tau",
    "inference;model_variant;family;tau;metric"
  ),
  replacement_rows = c(9L, 27L),
  estimator_contract = c(
    "fixed_path_point_metric_three_chain_mean_v1",
    "posterior_mean_draw_metric_equal_tailed_95cri_v1"
  ),
  replacement_policy = rep(
    "replace_complete_exdqlm_mcmc_block_preserve_all_non_exdqlm_rows", 2L
  ),
  stringsAsFactors = FALSE
)
ffv2_write_csv(replacement_contract,
               file.path(output_root, "replacement_contract.csv"))

integration_checklist <- data.frame(
  order = seq_len(12L),
  owner = rep("ARTICLE_QDESN_INTEGRATION", 12L),
  required_action = c(
    "merge the dedicated validation branch into the latest shared validation authority",
    "verify the frozen packet manifest and all promotion checks",
    "start from the latest article point and interval authorities",
    "replace exactly nine MCMC exDQLM point rows by family and tau",
    "replace exactly twenty-seven MCMC exDQLM interval roles by family tau and metric",
    "preserve every non-exDQLM and every VB value exactly",
    "regenerate point tables interval tables figures diagnostics and manifests",
    "recompute boldface rankings from unrounded values",
    "keep fixed-path point metrics distinct from posterior draw-metric means",
    "compile the main article and supplement to convergence",
    "commit and push through command-line git using the integration workflow",
    "publish the article-only Overleaf snapshot after read-back verification"
  ),
  status = "REQUIRED",
  stringsAsFactors = FALSE
)
ffv2_write_csv(integration_checklist,
               file.path(output_root, "integration_checklist.csv"))

packet_manifest <- ffv2_read_json(file.path(
  orchestration_root, "diagnostics", "packet_manifest.json"
))
runtime_evidence <- data.frame(
  role = c("pipeline_log", "diagnostic_review_pdf"),
  tracked = FALSE,
  path = c(
    file.path(orchestration_root, "pipeline.stdout.log"),
    as.character(packet_manifest$combined_pdf_path)
  ),
  stringsAsFactors = FALSE
)
runtime_evidence$sha256 <- vapply(runtime_evidence$path, ffv2_file_sha256,
                                 character(1L))
runtime_evidence$bytes <- as.numeric(file.info(runtime_evidence$path)$size)
ffv2_write_csv(runtime_evidence,
               file.path(output_root, "runtime_evidence_ledger.csv"))

handoff <- list(
  schema_version = iems_v1_schema,
  handoff_revision = "frozen_complete_block_v1",
  status = "READY_FOR_INTEGRATION",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  lane = "IND_QDESN_VAL",
  run_id = run_id,
  promotion_id = iems_v1_frozen_promotion_id,
  worktree = repo_root,
  branch = git_state$branch,
  upstream = git_state$upstream,
  packet_build_commit = git_state$head,
  scientific_execution_commit = as.character(source_handoff$head),
  package_version = "1.1.1",
  package_repository = "CRAN",
  package_tarball_sha256 = iems_v1_cran_tarball_sha256,
  jobs = 27L,
  cells = 9L,
  chains_per_cell = 3L,
  point_candidate = "scientific/candidate_point_exdqlm_mcmc_rows.csv",
  point_candidate_sha256 = ffv2_file_sha256(scientific(
    "candidate_point_exdqlm_mcmc_rows.csv"
  )),
  interval_candidate = "scientific/candidate_interval_exdqlm_mcmc_roles.csv",
  interval_candidate_sha256 = ffv2_file_sha256(scientific(
    "candidate_interval_exdqlm_mcmc_roles.csv"
  )),
  scientific_decision =
    "READY_FOR_INTEGRATION_REPLACE_COMPLETE_EXDQLM_MCMC_BLOCK",
  replacement_policy = paste(
    "Replace all nine MCMC exDQLM point rows and all twenty-seven corresponding",
    "posterior interval roles. Never mix corrected and historical rolling-state",
    "rows, and preserve every non-exDQLM and VB value exactly."
  ),
  diagnostic_pdf_local_path = as.character(packet_manifest$combined_pdf_path),
  diagnostic_pdf_sha256 = as.character(packet_manifest$combined_pdf_sha256),
  diagnostic_pdf_tracked = FALSE,
  fitted_model_binaries = 0L,
  article_write_performed = FALSE,
  shared_validation_merge_performed = FALSE,
  overleaf_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION"
)
ffv2_write_json(handoff, file.path(output_root, "integration_handoff.json"))

cell <- ffv2_read_csv(scientific("cell_metric_comparison.csv"))
result_lines <- vapply(seq_len(nrow(cell)), function(i) sprintf(
  "| %s | %.2f | %.3f -> %.3f | %.1f%% | %.3f -> %.3f | %.1f%% |",
  cell$family[[i]], cell$tau[[i]], cell$historical_forecast_mae[[i]],
  cell$corrected_forecast_mae[[i]], 100 * (1 - cell$forecast_mae_ratio[[i]]),
  cell$historical_forecast_check[[i]], cell$corrected_forecast_check[[i]],
  100 * (1 - cell$forecast_check_ratio[[i]])
), character(1L))
writeLines(c(
  "# Independent exDQLM MCMC rolling-state repair v1",
  "",
  "This is the compact, tracked integration packet for the completed independent",
  "single-quantile exDQLM MCMC rolling-state repair. It contains no fitted-model",
  "binary, raw execution log, article file, or application artifact.",
  "",
  "## Scientific decision",
  "",
  "`READY_FOR_INTEGRATION_REPLACE_COMPLETE_EXDQLM_MCMC_BLOCK`",
  "",
  "The historical validation bridge requested VB-only exAL fields from an MCMC",
  "fit and silently substituted a zero forecast-error mean. The corrected bridge",
  "uses posterior-predictive moments from paired sigma and gamma MCMC draws.",
  "Fit RMSE and first-origin forecasts are invariant; all nine aggregate forecast",
  "MAE and check-loss values improve.",
  "",
  "| Family | tau | Forecast MAE | Gain | Check loss | Gain |",
  "|---|---:|---:|---:|---:|---:|",
  result_lines,
  "",
  "## Integration contract",
  "",
  "1. Merge this dedicated branch into the latest shared validation authority.",
  "2. Run the packet verifier before consuming any result.",
  "3. Replace the complete nine-cell MCMC exDQLM point block and the complete",
  "   twenty-seven-role exDQLM interval block. Do not cherry-pick cells.",
  "4. Preserve every DQLM, Q-DESN, VB, joint-study, and application value.",
  "5. Regenerate all dependent tables, interval figures, rankings, prose, and",
  "   manifests from unrounded values, then compile both manuscripts.",
  "6. Publish Article-v2 and Overleaf only from the integration lane.",
  "",
  "Point metrics score the fixed posterior-summary path. Interval-table means are",
  "means of draw-level nonlinear metrics. They are separate estimands and must not",
  "be substituted for one another.",
  "",
  "Verification command:",
  "",
  "```bash",
  "Rscript validation/fitforecast_v2/scripts/verify_independent_exdqlm_mcmc_rolling_state_fix_v1_promotion.R",
  "```"
), file.path(output_root, "README.md"), useBytes = TRUE)

all_files <- list.files(output_root, recursive = TRUE, full.names = TRUE)
all_files <- all_files[basename(all_files) != "artifact_manifest.csv"]
relative <- substring(all_files, nchar(output_root) + 2L)
artifact_manifest <- data.frame(
  relative_path = relative,
  sha256 = vapply(all_files, ffv2_file_sha256, character(1L)),
  bytes = as.numeric(file.info(all_files)$size),
  stringsAsFactors = FALSE
)
artifact_manifest <- artifact_manifest[order(artifact_manifest$relative_path), ]
ffv2_write_csv(artifact_manifest, file.path(output_root, "artifact_manifest.csv"))

cat(sprintf(
  "PROMOTION_PACKET_FROZEN files=%d packet=%s decision=%s\n",
  nrow(artifact_manifest), output_root, handoff$scientific_decision
))
