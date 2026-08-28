#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
manifest_path <- file.path(state_root, "manifests", "materialization_manifest.json")
plan_path <- file.path(state_root, "manifests", "job_plan.csv")
import_path <- file.path(state_root, "manifests", "imported_vb_evidence.csv")
preflight_path <- file.path(state_root, "preflight", "preflight_checks.csv")
manifest <- ffv2_read_json(manifest_path)
plan <- ffv2_read_csv(plan_path)
imported <- ffv2_read_csv(import_path)
preflight <- ffv2_read_csv(preflight_path)

plan_contract <- i111s_plan_checks(plan)
config_hash_ok <- vapply(seq_len(nrow(plan)), function(i) {
  file.exists(plan$config_path[[i]]) &&
    identical(ffv2_file_sha256(plan$config_path[[i]]), plan$config_sha256[[i]])
}, logical(1L))
configs <- lapply(plan$config_path, ffv2_read_json)

config_model_ok <- vapply(configs, function(x) {
  identical(as.character(x$model_variant), "exdqlm") &&
    isFALSE(x$dqlm_ind)
}, logical(1L))
config_identity_ok <- vapply(seq_along(configs), function(i) {
  x <- configs[[i]]
    identical(as.character(x$source_replay_id), as.character(plan$replay_id[[i]])) &&
    identical(as.character(x$inference), as.character(plan$inference[[i]])) &&
    identical(as.integer(x$chain_id), as.integer(plan$chain_id[[i]])) &&
    identical(as.character(x$family), as.character(plan$family[[i]])) &&
    abs(as.numeric(x$tau) - as.numeric(plan$tau[[i]])) < 1e-12
}, logical(1L))
package_contract_ok <- vapply(configs, function(x) {
  pkg <- x$package_contract %||% list()
  identical(as.character(pkg$version), i111_package_version) &&
    identical(as.character(pkg$source_commit), i111_package_source_commit) &&
    identical(as.character(pkg$authority_id), i111_authority_id)
}, logical(1L))
thread_contract_ok <- vapply(configs, function(x) {
  identical(as.integer(x$runtime$threads), 1L)
}, logical(1L))

vb_index <- which(plan$inference == "vb")
mcmc_index <- which(plan$inference == "mcmc")
vb_contract_ok <- vapply(vb_index, function(i) {
  x <- configs[[i]]
  sg <- x$budget$vb$sigmagam %||% list()
  identical(as.character(sg$factorization), "structured") &&
    identical(as.integer(sg$structured_grid_size), 151L) &&
    identical(as.integer(x$metric_intervals$draws), 10000L) &&
    identical(as.character(x$package_contract$gamma_update),
              "structured_qgamma_qsigma_given_gamma")
}, logical(1L))
mcmc_contract_ok <- vapply(mcmc_index, function(i) {
  x <- configs[[i]]
  m <- x$budget$mcmc %||% list()
  identical(as.character(m$mh_proposal), "collapsed_slice") &&
    identical(as.integer(m$n_burn), 5000L) &&
    identical(as.integer(m$n_mcmc), 20000L) &&
    identical(as.integer(m$thin), 1L) &&
    isTRUE(m$init_from_vb) &&
    identical(as.integer(x$metric_intervals$draws), 4000L) &&
    identical(as.character(x$package_contract$gamma_update), "collapsed_slice")
}, logical(1L))

artifact_ok <- function(path, expected_sha) {
  path <- as.character(path %||% "")[1L]
  expected_sha <- as.character(expected_sha %||% "")[1L]
  nzchar(path) && nzchar(expected_sha) && file.exists(path) &&
    identical(ffv2_file_sha256(path), expected_sha)
}
import_status_ok <- vapply(seq_len(nrow(imported)), function(i) {
  x <- ffv2_read_json(imported$imported_status_path[[i]])
  identical(as.character(x$status), "SUCCESS") &&
    artifact_ok(x$metric_draws_path, x$metric_draws_sha256) &&
    artifact_ok(x$metric_interval_summary_path, x$metric_interval_summary_sha256) &&
    artifact_ok(x$metric_interval_manifest_path, x$metric_interval_manifest_sha256) &&
    artifact_ok(x$inference_diagnostics_path, x$inference_diagnostics_sha256) &&
    identical(as.integer(x$metric_draws), 10000L) &&
    identical(as.integer(x$heavy_binary_count), 0L)
}, logical(1L))

registry <- ffv2_read_csv(file.path(state_root, "materialization", "source_replay_registry.csv"))
roles <- ffv2_read_csv(file.path(state_root, "materialization", "metric_role_ledger.csv"))
checks <- c(
  schema = identical(as.character(manifest$schema_version), i111s_schema),
  scope = identical(as.character(manifest$scope_id), i111s_scope_id),
  parent_schema = identical(as.character(manifest$parent_schema_version), i111_schema),
  authority = identical(as.character(manifest$authority_id), i111_authority_id),
  package_version = identical(as.character(manifest$package_version), i111_package_version),
  package_source_commit = identical(as.character(manifest$package_source_commit),
                                    i111_package_source_commit),
  parent_manifest_hash = identical(
    ffv2_file_sha256(as.character(manifest$parent_materialization_manifest_path)),
    as.character(manifest$parent_materialization_manifest_sha256)
  ),
  parent_plan_hash = identical(
    ffv2_file_sha256(as.character(manifest$parent_job_plan_path)),
    as.character(manifest$parent_job_plan_sha256)
  ),
  plan_hash = identical(ffv2_file_sha256(plan_path), as.character(manifest$plan_sha256)),
  plan_contract = all(plan_contract),
  config_hashes = all(config_hash_ok),
  config_model_scope = all(config_model_ok),
  config_identities = all(config_identity_ok),
  package_contracts = all(package_contract_ok),
  one_thread_per_job = all(thread_contract_ok),
  vb_contract = length(vb_contract_ok) == i111s_expected_vb_jobs && all(vb_contract_ok),
  mcmc_contract = length(mcmc_contract_ok) == i111s_expected_mcmc_jobs &&
    all(mcmc_contract_ok),
  imported_vb_9 = nrow(imported) == i111s_expected_vb_jobs,
  imported_vb_hashes = nrow(imported) == i111s_expected_vb_jobs &&
    all(imported$source_status_sha256 == imported$imported_status_sha256),
  imported_vb_artifacts = length(import_status_ok) == i111s_expected_vb_jobs &&
    all(import_status_ok),
  no_mcmc_status_before_launch = !any(file.exists(file.path(
    state_root, "status", paste0(plan$job_id[mcmc_index], ".json")
  ))),
  source_registry_18 = nrow(registry) == i111s_expected_source_identities &&
    all(registry$model_variant == "exdqlm"),
  metric_roles_54 = nrow(roles) == i111s_expected_metric_roles &&
    all(roles$model_variant == "exdqlm"),
  preflight_pass = nrow(preflight) == 15L && all(as.logical(preflight$pass)),
  no_out_of_scope_jobs = !any(plan$model_variant %in%
    c("dqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"))
)
check_table <- data.frame(check = names(checks), pass = unname(checks),
                          stringsAsFactors = FALSE)
check_path <- ffv2_write_csv(check_table,
                             file.path(state_root, "manifests", "scope_verification.csv"))
payload <- list(
  schema_version = i111s_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = if (all(checks)) "PASS" else "FAIL",
  checks_pass = sum(checks), checks_total = length(checks),
  jobs = nrow(plan), imported_vb_jobs = nrow(imported),
  mcmc_jobs_to_execute = nrow(plan) - nrow(imported),
  verification_path = check_path,
  verification_sha256 = ffv2_file_sha256(check_path)
)
ffv2_write_json(payload, file.path(state_root, "manifests", "scope_verification.json"))
if (!all(checks)) {
  stop(sprintf("Scoped continuation verification failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}
cat(sprintf("scope verification: %d/%d checks pass; jobs=%d imported_vb=%d mcmc=%d\n",
            sum(checks), length(checks), nrow(plan), nrow(imported),
            nrow(plan) - nrow(imported)))
