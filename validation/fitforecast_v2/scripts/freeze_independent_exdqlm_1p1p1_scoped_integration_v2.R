#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/freeze_independent_exdqlm_1p1p1_scoped_integration_v2.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
git_state <- i111s_assert_clean_synced_branch(repo_root)
state_root <- i111s_assert_scoped_state_root(args$`state-root` %||% "", repo_root)
output_root <- ffv2_resolve_path(
  args$`output-root` %||% i111s_promotion_root(repo_root),
  repo_root = repo_root, must_work = FALSE
)
repo_prefix <- paste0(repo_root, "/")
if (!startsWith(output_root, repo_prefix)) {
  stop("Frozen integration output must remain inside the scientific worktree.",
       call. = FALSE)
}
if (dir.exists(output_root) && length(list.files(output_root, all.files = TRUE, no.. = TRUE))) {
  stop(sprintf("Refusing nonempty promotion root: %s", output_root), call. = FALSE)
}
ffv2_ensure_dir(output_root)

closeout_root <- file.path(state_root, "closeout_v2")
recovery_root <- file.path(state_root, "postprocessing_recovery_v2")
diagnostic_root <- file.path(state_root, "diagnostics", "exdqlm_1p1p1_scoped_v2")
final_handoff <- ffv2_read_json(file.path(closeout_root, "integration_handoff_v2.json"))
recovery_manifest <- ffv2_read_json(file.path(recovery_root, "recovery_manifest.json"))
packet_manifest <- ffv2_read_json(file.path(diagnostic_root, "packet_manifest.json"))
if (!identical(as.character(final_handoff$status), "READY_FOR_INTEGRATION") ||
    !identical(as.character(recovery_manifest$status), "PASS") ||
    !identical(as.character(packet_manifest$status), "PASS")) {
  stop("Closeout, recovery, and diagnostics must all pass before freezing.",
       call. = FALSE)
}

copy_one <- function(source, relative_target, normalize_text = FALSE) {
  if (!file.exists(source)) stop(sprintf("Freeze source is missing: %s", source),
                                 call. = FALSE)
  target <- file.path(output_root, relative_target)
  ffv2_ensure_dir(dirname(target))
  if (!file.copy(source, target, overwrite = FALSE, copy.mode = TRUE)) {
    stop(sprintf("Could not freeze %s.", source), call. = FALSE)
  }
  if (isTRUE(normalize_text)) {
    lines <- readLines(target, warn = FALSE)
    writeLines(sub("[[:blank:]]+$", "", lines), target, useBytes = TRUE)
  }
  normalizePath(target, winslash = "/", mustWork = TRUE)
}

closeout_files <- c(
  "job_artifact_audit.csv", "exdqlm_1p1p1_scoped_vs_authority_v2.csv",
  "source_point_metric_summary.csv", "source_interval_summary.csv",
  "mcmc_metric_diagnostics.csv", "exdqlm_inference_diagnostics.csv",
  "candidate_point_interface_exdqlm_only_replacement.csv",
  "candidate_point_exdqlm_rows.csv",
  "candidate_interval_roles_exdqlm_only_replacement.csv",
  "candidate_interval_exdqlm_roles.csv",
  "non_exdqlm_interval_invariance_ledger.csv",
  "point_winner_change_ledger.csv", "interval_winner_change_ledger.csv",
  "scientific_change_summary.csv", "closeout_checks_v2.csv", "CLOSEOUT_V2.md"
)
frozen_paths <- vapply(
  closeout_files,
  function(name) copy_one(file.path(closeout_root, name), name),
  character(1L)
)

support_map <- c(
  "environment/preflight_checks.csv" = file.path(state_root, "preflight", "preflight_checks.csv"),
  "environment/environment_manifest.json" = file.path(state_root, "preflight", "environment_manifest.json"),
  "environment/sessionInfo.txt" = file.path(state_root, "preflight", "sessionInfo.txt"),
  "manifests/materialization_manifest.json" = file.path(state_root, "manifests", "materialization_manifest.json"),
  "manifests/orchestration_manifest.json" = file.path(state_root, "manifests", "orchestration_manifest.json"),
  "manifests/scope_verification.csv" = file.path(state_root, "manifests", "scope_verification.csv"),
  "recovery/recovery_checks.csv" = file.path(recovery_root, "recovery_checks.csv"),
  "recovery/recovery_manifest.json" = file.path(recovery_root, "recovery_manifest.json"),
  "diagnostics/packet_manifest.json" = file.path(diagnostic_root, "packet_manifest.json"),
  "diagnostics/figure_manifest.csv" = file.path(diagnostic_root, "figure_manifest.csv"),
  "diagnostics/table_manifest.csv" = file.path(diagnostic_root, "table_manifest.csv"),
  "diagnostics/diagnostic_input_checks.csv" = file.path(diagnostic_root, "diagnostic_input_checks.csv")
)
support_paths <- vapply(names(support_map), function(target) {
  copy_one(
    unname(support_map[[target]]), target,
    normalize_text = identical(target, "environment/sessionInfo.txt")
  )
}, character(1L))
frozen_paths <- c(frozen_paths, support_paths)

point_candidate <- ffv2_read_csv(file.path(
  output_root, "candidate_point_interface_exdqlm_only_replacement.csv"
))
interval_candidate <- ffv2_read_csv(file.path(
  output_root, "candidate_interval_roles_exdqlm_only_replacement.csv"
))
invariance <- ffv2_read_csv(file.path(
  output_root, "non_exdqlm_interval_invariance_ledger.csv"
))
closeout_checks <- ffv2_read_csv(file.path(output_root, "closeout_checks_v2.csv"))
point_hash <- ffv2_file_sha256(file.path(output_root, "source_point_metric_summary.csv"))
interval_hash <- ffv2_file_sha256(file.path(output_root, "source_interval_summary.csv"))
exdqlm_rows <- point_candidate$model_variant == "exdqlm"
interval_rows <- interval_candidate$model_variant == "exdqlm"
freeze_checks <- c(
  point_candidate_rows_72 = nrow(point_candidate) == 72L,
  point_candidate_exdqlm_rows_18 = sum(exdqlm_rows) == 18L,
  point_candidate_source_hashes = all(vapply(
    c("fit_source_sha256", "forecast_mae_source_sha256",
      "forecast_check_source_sha256"),
    function(field) all(point_candidate[[field]][exdqlm_rows] == point_hash),
    logical(1L)
  )),
  interval_candidate_rows_216 = nrow(interval_candidate) == 216L,
  interval_candidate_exdqlm_rows_54 = sum(interval_rows) == 54L,
  interval_candidate_source_hashes = all(
    interval_candidate$source_sha256[interval_rows] == interval_hash
  ),
  non_exdqlm_rows_162_invariant = sum(invariance$inherited_role) == 162L &&
    all(invariance$unchanged[invariance$inherited_role]),
  closeout_checks_pass = all(closeout_checks$pass),
  no_heavy_binaries = !any(grepl("[.](rds|rda|RData)$", frozen_paths,
                                  ignore.case = TRUE))
)
freeze_checks_path <- ffv2_write_csv(
  data.frame(check = names(freeze_checks), pass = unname(freeze_checks),
             stringsAsFactors = FALSE),
  file.path(output_root, "freeze_checks.csv")
)
if (!all(freeze_checks)) {
  stop(sprintf("Frozen integration checks failed: %s",
               paste(names(freeze_checks)[!freeze_checks], collapse = ", ")),
       call. = FALSE)
}

handoff <- list(
  schema_version = i111s_schema,
  handoff_revision = "frozen_integration_v2",
  status = "READY_FOR_INTEGRATION",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  lane = "IND_QDESN_VAL",
  run_id = as.character(final_handoff$run_id),
  promotion_id = i111s_promotion_id,
  package_version = i111_package_version,
  package_source_commit = i111_package_source_commit,
  package_tarball_sha256 = as.character(final_handoff$package_tarball_sha256),
  scientific_jobs = 36L,
  scientific_jobs_reexecuted_during_recovery = 0L,
  point_candidate = "candidate_point_interface_exdqlm_only_replacement.csv",
  point_candidate_rows = 72L,
  point_candidate_exdqlm_rows = 18L,
  point_estimator_id = i111s_point_estimator_id,
  interval_candidate = "candidate_interval_roles_exdqlm_only_replacement.csv",
  interval_candidate_rows = 216L,
  interval_candidate_exdqlm_roles = 54L,
  interval_estimator_id = i111s_interval_estimator_id,
  inherited_non_exdqlm_interval_roles = 162L,
  scientific_decision = as.character(final_handoff$scientific_decision),
  replacement_policy = as.character(final_handoff$replacement_policy),
  article_recommendation = paste(
    "Replace the complete exDQLM point and interval blocks only if Article-v2",
    "adopts exdqlm 1.1.1 as its validation runtime. Do not cherry-pick favorable cells",
    "and do not describe the refresh as a material forecast improvement."
  ),
  diagnostic_pdf_local_path = as.character(packet_manifest$combined_pdf_path),
  diagnostic_pdf_sha256 = as.character(packet_manifest$combined_pdf_sha256),
  diagnostic_pdf_tracked = FALSE,
  source_state_root = state_root,
  source_materialization_sha256 = ffv2_file_sha256(file.path(
    state_root, "manifests", "materialization_manifest.json"
  )),
  article_write_performed = FALSE,
  shared_validation_merge_performed = FALSE,
  overleaf_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION",
  branch = git_state$branch,
  upstream = git_state$upstream,
  handoff_commit = git_state$head
)
handoff_path <- ffv2_write_json(
  handoff, file.path(output_root, "integration_handoff.json")
)
writeLines(c(
  "# Independent exDQLM 1.1.1 compatibility refresh",
  "",
  "This frozen packet is the integration handoff for the scoped exDQLM-only rerun.",
  "It contains separate point-estimate and posterior-interval candidates. The",
  "original pipeline failure is retained in runtime evidence and was caused only",
  "by diagnostic postprocessing after all 36 scientific jobs had completed.",
  "",
  "- Scientific decision: `EXDQLM_1P1P1_COMPATIBILITY_REFRESH_CONCLUSIONS_STABLE`",
  "- Jobs: 36/36 complete; 0 rerun during recovery",
  "- Point candidate: 18 exDQLM rows in a 72-row interface",
  "- Interval candidate: 54 exDQLM roles in a 216-role interface",
  "- Non-exDQLM interval roles: 162/162 invariant",
  "- Diagnostic packet: local and ignored; hash recorded in the handoff",
  "- Article/shared-validation/Overleaf writes: none",
  "- Integration policy: use the complete exDQLM block; never cherry-pick gains."
), file.path(output_root, "README.md"), useBytes = TRUE)

all_files <- list.files(output_root, recursive = TRUE, full.names = TRUE)
all_files <- all_files[basename(all_files) != "output_file_manifest.csv"]
ledger <- imir_v1_file_ledger(all_files, output_root)
ledger <- ledger[order(ledger$relative_path), , drop = FALSE]
ledger_path <- ffv2_write_csv(ledger, file.path(output_root, "output_file_manifest.csv"))
verify_paths <- file.path(output_root, ledger$relative_path)
if (!all(file.exists(verify_paths)) ||
    !all(vapply(verify_paths, ffv2_file_sha256, character(1L)) == ledger$sha256)) {
  stop("Frozen integration output manifest did not verify.", call. = FALSE)
}
cat(sprintf("INTEGRATION_PACKET_FROZEN files=%d handoff=%s manifest=%s\n",
            nrow(ledger), handoff_path, ledger_path))
