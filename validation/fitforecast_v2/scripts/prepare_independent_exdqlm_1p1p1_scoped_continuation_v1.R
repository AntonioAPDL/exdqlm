#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/prepare_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
parent_state_root <- normalizePath(args$`parent-state-root` %||% "", winslash = "/",
                                   mustWork = TRUE)
state_root <- ffv2_resolve_path(args$`state-root` %||% "", repo_root = repo_root,
                                must_work = FALSE)
run_id <- as.character(args$`run-id` %||% basename(state_root))[1L]
if (!nzchar(run_id) || !nzchar(state_root)) {
  stop("--parent-state-root, --state-root, and --run-id are required.", call. = FALSE)
}

parent_manifest_path <- file.path(parent_state_root, "manifests", "materialization_manifest.json")
parent_plan_path <- file.path(parent_state_root, "manifests", "job_plan.csv")
parent_registry_path <- file.path(parent_state_root, "materialization", "source_replay_registry.csv")
parent_roles_path <- file.path(parent_state_root, "materialization", "metric_role_ledger.csv")
required_parent <- c(parent_manifest_path, parent_plan_path, parent_registry_path,
                     parent_roles_path)
if (any(!file.exists(required_parent))) {
  stop("The parent campaign is missing required materialization evidence.", call. = FALSE)
}
parent_manifest <- ffv2_read_json(parent_manifest_path)
if (!identical(as.character(parent_manifest$schema_version), i111_schema) ||
    !identical(as.character(parent_manifest$package_version), i111_package_version) ||
    !identical(as.character(parent_manifest$package_source_commit),
               i111_package_source_commit)) {
  stop("The parent campaign is not the pinned exdqlm 1.1.1 campaign.", call. = FALSE)
}

allowed_existing <- c("pipeline.status", "pipeline.stdout.log", "preflight", "manifests")
if (dir.exists(state_root)) {
  existing <- list.files(state_root, all.files = TRUE, no.. = TRUE)
  if (length(setdiff(existing, allowed_existing)) ||
      file.exists(file.path(state_root, "manifests", "job_plan.csv"))) {
    stop("Scoped continuation state root is not a clean preflight-only root.", call. = FALSE)
  }
}
dirs <- file.path(state_root, c("manifests", "materialization", "status", "logs",
                                "health", "closeout", "diagnostics"))
invisible(lapply(dirs, ffv2_ensure_dir))

parent_plan <- ffv2_read_csv(parent_plan_path)
scoped_plan <- i111s_filter_plan(parent_plan)
plan_checks <- i111s_plan_checks(scoped_plan)
if (!all(plan_checks)) {
  stop(sprintf("Scoped plan selection failed: %s",
               paste(names(plan_checks)[!plan_checks], collapse = ", ")), call. = FALSE)
}

parent_registry <- ffv2_read_csv(parent_registry_path)
registry <- parent_registry[parent_registry$model_variant == "exdqlm", , drop = FALSE]
parent_roles <- ffv2_read_csv(parent_roles_path)
roles <- parent_roles[parent_roles$model_variant == "exdqlm", , drop = FALSE]
if (nrow(registry) != i111s_expected_source_identities ||
    nrow(roles) != i111s_expected_metric_roles ||
    !setequal(registry$source_identity, scoped_plan$source_identity)) {
  stop("Scoped source registry or metric-role ledger is incomplete.", call. = FALSE)
}

artifact_ok <- function(path, expected_sha) {
  path <- as.character(path %||% "")[1L]
  expected_sha <- as.character(expected_sha %||% "")[1L]
  nzchar(path) && nzchar(expected_sha) && file.exists(path) &&
    identical(ffv2_file_sha256(path), expected_sha)
}

import_rows <- list()
for (i in which(scoped_plan$inference == "vb")) {
  row <- scoped_plan[i, , drop = FALSE]
  source_status <- file.path(parent_state_root, "status", paste0(row$job_id[[1L]], ".json"))
  if (!file.exists(source_status)) {
    stop(sprintf("Missing completed parent VB status: %s", row$job_id[[1L]]), call. = FALSE)
  }
  payload <- ffv2_read_json(source_status)
  checks <- c(
    success = identical(as.character(payload$status), "SUCCESS"),
    config_hash = identical(as.character(payload$config_sha256),
                            as.character(row$config_sha256[[1L]])),
    draws = artifact_ok(payload$metric_draws_path, payload$metric_draws_sha256),
    interval_summary = artifact_ok(payload$metric_interval_summary_path,
                                   payload$metric_interval_summary_sha256),
    interval_manifest = artifact_ok(payload$metric_interval_manifest_path,
                                    payload$metric_interval_manifest_sha256),
    inference_diagnostics = artifact_ok(payload$inference_diagnostics_path,
                                        payload$inference_diagnostics_sha256),
    draw_count = identical(as.integer(payload$metric_draws),
                           as.integer(row$expected_draws[[1L]])),
    no_heavy_binary = identical(as.integer(payload$heavy_binary_count), 0L)
  )
  if (!all(checks)) {
    stop(sprintf("Parent VB evidence failed for %s: %s", row$job_id[[1L]],
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
  target_status <- file.path(state_root, "status", basename(source_status))
  if (!file.copy(source_status, target_status, overwrite = FALSE)) {
    stop(sprintf("Could not import status evidence: %s", source_status), call. = FALSE)
  }
  import_rows[[length(import_rows) + 1L]] <- data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    family = row$family[[1L]], tau = row$tau[[1L]],
    source_status_path = normalizePath(source_status, winslash = "/", mustWork = TRUE),
    source_status_sha256 = ffv2_file_sha256(source_status),
    imported_status_path = normalizePath(target_status, winslash = "/", mustWork = TRUE),
    imported_status_sha256 = ffv2_file_sha256(target_status),
    metric_draws_path = as.character(payload$metric_draws_path),
    metric_draws_sha256 = as.character(payload$metric_draws_sha256),
    metric_draws = as.integer(payload$metric_draws),
    all_checks_pass = all(checks), stringsAsFactors = FALSE
  )
}
imported_vb <- ffv2_bind_rows(import_rows)
if (nrow(imported_vb) != i111s_expected_vb_jobs ||
    any(imported_vb$source_status_sha256 != imported_vb$imported_status_sha256)) {
  stop("The scoped continuation did not import exactly nine immutable VB statuses.",
       call. = FALSE)
}

scoped_plan$status <- ifelse(scoped_plan$inference == "vb", "IMPORTED_SUCCESS", "PENDING")
plan_path <- ffv2_write_csv(scoped_plan, file.path(state_root, "manifests", "job_plan.csv"))
ffv2_write_csv(imported_vb, file.path(state_root, "manifests", "imported_vb_evidence.csv"))
ffv2_write_csv(registry, file.path(state_root, "materialization", "source_replay_registry.csv"))
ffv2_write_csv(roles, file.path(state_root, "materialization", "metric_role_ledger.csv"))

generated_rows_path <- file.path(parent_state_root, "materialization", "dqlm_generated_rows.csv")
if (file.exists(generated_rows_path)) {
  generated <- ffv2_read_csv(generated_rows_path)
  generated <- generated[generated$model_variant == "exdqlm", , drop = FALSE]
  ffv2_write_csv(generated,
                 file.path(state_root, "materialization", "exdqlm_generated_rows.csv"))
}

parent_status <- lapply(seq_len(nrow(parent_plan)), function(i) {
  row <- parent_plan[i, , drop = FALSE]
  path <- file.path(parent_state_root, "status", paste0(row$job_id[[1L]], ".json"))
  status <- if (!file.exists(path)) "NOT_STARTED" else {
    toupper(as.character(ffv2_read_json(path)$status %||% "UNKNOWN"))[1L]
  }
  data.frame(model_variant = row$model_variant[[1L]], inference = row$inference[[1L]],
             status = status, stringsAsFactors = FALSE)
})
parent_status <- ffv2_bind_rows(parent_status)
parent_status_summary <- stats::aggregate(
  rep(1L, nrow(parent_status)),
  by = parent_status[c("model_variant", "inference", "status")], FUN = sum
)
names(parent_status_summary)[[4L]] <- "jobs"
ffv2_write_csv(parent_status_summary,
               file.path(state_root, "manifests", "parent_interruption_audit.csv"))

head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)
manifest <- list(
  schema_version = i111s_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = run_id,
  scope_id = i111s_scope_id,
  status = "PREPARED",
  parent_run_id = as.character(parent_manifest$run_id),
  parent_state_root = parent_state_root,
  parent_schema_version = as.character(parent_manifest$schema_version),
  parent_materialization_manifest_path = parent_manifest_path,
  parent_materialization_manifest_sha256 = ffv2_file_sha256(parent_manifest_path),
  parent_job_plan_path = parent_plan_path,
  parent_job_plan_sha256 = ffv2_file_sha256(parent_plan_path),
  authority_id = i111_authority_id,
  package_version = i111_package_version,
  package_source_commit = i111_package_source_commit,
  package_tarball_sha256 = as.character(parent_manifest$package_tarball_sha256),
  preparation_commit = head,
  jobs = nrow(scoped_plan),
  vb_jobs = sum(scoped_plan$inference == "vb"),
  mcmc_jobs = sum(scoped_plan$inference == "mcmc"),
  imported_vb_jobs = nrow(imported_vb),
  jobs_to_execute = sum(scoped_plan$inference == "mcmc"),
  source_identities = nrow(registry),
  metric_roles = nrow(roles),
  plan_path = plan_path,
  plan_sha256 = ffv2_file_sha256(plan_path),
  imported_vb_evidence_path = file.path(state_root, "manifests", "imported_vb_evidence.csv"),
  imported_vb_evidence_sha256 = ffv2_file_sha256(file.path(
    state_root, "manifests", "imported_vb_evidence.csv"
  )),
  contract = i111s_contract(repo_root),
  execution_policy = list(
    workers_max = i111_workers,
    numerical_threads_per_job = 1L,
    allowed_model_variant = "exdqlm",
    allowed_engine = "dqlm",
    allowed_inference = c("vb", "mcmc"),
    imported_vb_is_immutable = TRUE,
    article_write_performed = FALSE,
    shared_validation_write_performed = FALSE
  )
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "materialization_manifest.json"))
cat(sprintf("scoped continuation prepared: jobs=%d imported_vb=%d remaining_mcmc=%d\n",
            nrow(scoped_plan), nrow(imported_vb), sum(scoped_plan$inference == "mcmc")))
