iqfcr_v1_schema <- "independent_qdesn_fixed_comparator_forecast_recovery_v1"
iqfcr_v1_expected_jobs <- 54L
iqfcr_v1_expected_fit_iterations <- 25000L
iqfcr_v1_failure_pattern <- "make_df_mat"

iqfcr_v1_normalize <- function(path, must_work = TRUE) {
  normalizePath(as.character(path)[1L], winslash = "/", mustWork = must_work)
}

iqfcr_v1_read_pipeline_status <- function(source_run_root) {
  path <- file.path(source_run_root, "orchestration", "pipeline.status")
  if (!file.exists(path)) stop("Source pipeline status is missing.", call. = FALSE)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

iqfcr_v1_fit_completed <- function(progress_path) {
  if (!file.exists(progress_path)) return(FALSE)
  progress <- tryCatch(iqfc_v1_read_csv(progress_path), error = function(e) NULL)
  if (is.null(progress) || !nrow(progress)) return(FALSE)
  current <- suppressWarnings(as.integer(progress$current_iter))
  total <- suppressWarnings(as.integer(progress$total_iter))
  any(
    progress$stage == "fit" & progress$substage == "mcmc" &
      progress$event == "complete" &
      current == iqfcr_v1_expected_fit_iterations &
      total == iqfcr_v1_expected_fit_iterations,
    na.rm = TRUE
  )
}

iqfcr_v1_source_audit <- function(source_run_root, verify_payload_hashes = TRUE) {
  source_run_root <- iqfcr_v1_normalize(source_run_root)
  pipeline_status <- iqfcr_v1_read_pipeline_status(source_run_root)
  if (!grepl("^status=FAILED", pipeline_status)) {
    stop("Recovery source is not the frozen failed pipeline.", call. = FALSE)
  }
  manifest_path <- file.path(source_run_root, "manifests", "job_manifest.csv")
  preflight_path <- file.path(source_run_root, "manifests", "preflight_report.json")
  if (!file.exists(preflight_path)) stop("Source preflight is missing.", call. = FALSE)
  manifest <- iqfc_v1_read_csv(manifest_path)
  if (nrow(manifest) != iqfcr_v1_expected_jobs || anyDuplicated(manifest$job_id)) {
    stop("Recovery source must contain exactly 54 unique jobs.", call. = FALSE)
  }

  rows <- lapply(seq_len(nrow(manifest)), function(i) {
    config_path <- manifest$row_config_path[[i]]
    config <- ffv2_read_json(config_path)
    status <- iqfc_v1_read_csv(config$row_status_path)
    last <- status[nrow(status), , drop = FALSE]
    handoff_manifest <- ffv2_read_json(config$fit_handoff_manifest_path)
    handoff_path <- iqfcr_v1_normalize(config$fit_handoff_path)
    manifest_handoff_path <- iqfcr_v1_normalize(handoff_manifest$path)
    checks <- c(
      config_hash = identical(
        iqfc_v1_sha256(config_path), manifest$row_config_sha256[[i]]
      ),
      failed_runtime = identical(as.character(last$status[[1L]]), "failed_runtime"),
      expected_failure = grepl(
        iqfcr_v1_failure_pattern,
        as.character(last$error_message[[1L]]),
        fixed = TRUE
      ),
      handoff_exists = file.exists(handoff_path),
      handoff_manifest_exists = file.exists(config$fit_handoff_manifest_path),
      handoff_role = identical(as.character(handoff_manifest$role), "fit"),
      handoff_path = identical(handoff_path, manifest_handoff_path),
      handoff_bytes = identical(
        as.numeric(file.info(handoff_path)$size),
        as.numeric(handoff_manifest$bytes)
      ),
      fit_complete = iqfcr_v1_fit_completed(config$row_progress_path),
      package_version = identical(
        as.character((config$package_contract %||% list())$version), "1.1.1"
      ),
      installed_namespace = identical(
        as.character(config$package_runtime_mode), "installed_namespace"
      )
    )
    if (isTRUE(verify_payload_hashes)) {
      checks <- c(
        checks,
        handoff_hash = identical(
          iqfc_v1_sha256(handoff_path), as.character(handoff_manifest$sha256)
        )
      )
    }
    if (!all(checks)) {
      stop(sprintf(
        "Recovery source audit failed for %s: %s",
        manifest$job_id[[i]], paste(names(checks)[!checks], collapse = ", ")
      ), call. = FALSE)
    }
    data.frame(
      job_id = manifest$job_id[[i]],
      model_variant = manifest$model_variant[[i]],
      family = manifest$family[[i]],
      tau = as.numeric(manifest$tau[[i]]),
      chain_id = as.integer(manifest$chain_id[[i]]),
      source_config_path = iqfcr_v1_normalize(config_path),
      source_config_sha256 = iqfc_v1_sha256(config_path),
      source_status_path = iqfcr_v1_normalize(config$row_status_path),
      source_status_sha256 = iqfc_v1_sha256(config$row_status_path),
      source_progress_path = iqfcr_v1_normalize(config$row_progress_path),
      source_progress_sha256 = iqfc_v1_sha256(config$row_progress_path),
      source_handoff_path = handoff_path,
      source_handoff_manifest_path = iqfcr_v1_normalize(
        config$fit_handoff_manifest_path
      ),
      source_handoff_manifest_sha256 = iqfc_v1_sha256(
        config$fit_handoff_manifest_path
      ),
      source_handoff_sha256 = as.character(handoff_manifest$sha256),
      source_handoff_bytes = as.numeric(handoff_manifest$bytes),
      source_inference_diagnostics_path = iqfcr_v1_normalize(
        config$inference_diagnostics_path
      ),
      source_inference_diagnostics_sha256 = iqfc_v1_sha256(
        config$inference_diagnostics_path
      ),
      stringsAsFactors = FALSE
    )
  })
  ledger <- do.call(rbind, rows)
  expected_keys <- with(expand.grid(
    model_variant = c("dqlm", "exdqlm"),
    family = c("normal", "laplace", "gausmix"),
    tau = c(0.05, 0.25, 0.50),
    chain_id = 1:3,
    stringsAsFactors = FALSE
  ), paste(model_variant, family, sprintf("%.2f", tau), chain_id, sep = "|"))
  observed_keys <- with(
    ledger,
    paste(model_variant, family, sprintf("%.2f", tau), chain_id, sep = "|")
  )
  if (!setequal(expected_keys, observed_keys)) {
    stop("Recovery source does not cover the exact comparator lattice.", call. = FALSE)
  }
  list(
    source_run_root = source_run_root,
    source_manifest_path = iqfcr_v1_normalize(manifest_path),
    source_manifest_sha256 = iqfc_v1_sha256(manifest_path),
    source_preflight_path = iqfcr_v1_normalize(preflight_path),
    source_preflight_sha256 = iqfc_v1_sha256(preflight_path),
    pipeline_status = pipeline_status,
    jobs = ledger,
    total_bytes = sum(ledger$source_handoff_bytes)
  )
}

iqfcr_v1_config_audit <- function(source, recovery) {
  fields <- union(names(source), names(recovery))
  changed <- fields[vapply(fields, function(field) {
    !identical(source[[field]], recovery[[field]])
  }, logical(1L))]
  input_fields <- c(
    "series_wide_path", "true_quantile_grid_path", "sim_output_path", "meta_path"
  )
  generated_paths <- setdiff(fields[grepl("_path$", fields)], input_fields)
  allowed <- unique(c(
    generated_paths, "run_tag", "run_root", "repo_root", "harness_root",
    "defaults_path", "status", "validation_stage", "screen_stage",
    "state_update_strategy", "source_config_sha256",
    "source_failure_config_sha256", "source_failure_run_root",
    "source_fit_handoff_sha256", "source_fit_handoff_bytes",
    "candidate_notes", "handoff", "retention"
  ))
  invariant_fields <- c(
    "model_variant", "family", "tau", "chain_id", "seed", "spec_id",
    "models", "budget", "series_wide_path", "series_wide_sha256",
    "true_quantile_grid_path", "true_quantile_grid_sha256",
    "train_start_source_index", "train_end_source_index",
    "forecast_start_source_index", "forecast_end_source_index",
    "origin_stride", "require_full_horizon", "max_lead_configured",
    "forecast_horizon_max", "forecast_window_rows", "forecast_protocol",
    "state_update_method", "metric_intervals", "package_contract",
    "package_runtime_mode"
  )
  invariant <- vapply(invariant_fields, function(field) {
    identical(source[[field]], recovery[[field]])
  }, logical(1L))
  unexpected <- setdiff(changed, allowed)
  list(
    changed = sort(changed), unexpected = sort(unexpected),
    invariant = invariant,
    pass = !length(unexpected) && all(invariant)
  )
}

iqfcr_v1_copy_verified <- function(source, target, expected_sha256 = NULL) {
  ffv2_ensure_dir(dirname(target))
  if (!file.copy(source, target, overwrite = FALSE, copy.mode = TRUE)) {
    stop(sprintf("Could not freeze recovery input: %s", source), call. = FALSE)
  }
  observed <- iqfc_v1_sha256(target)
  expected <- as.character(expected_sha256 %||% iqfc_v1_sha256(source))[1L]
  if (!identical(observed, expected)) {
    stop(sprintf("Frozen recovery input hash mismatch: %s", target), call. = FALSE)
  }
  iqfcr_v1_normalize(target)
}

iqfcr_v1_recovery_config <- function(source_config,
                                     repo_root,
                                     recovery_run_root,
                                     job_id,
                                     frozen_scientific_config_path,
                                     frozen_failed_config_path,
                                     source_row) {
  source_job_root <- iqfcr_v1_normalize(source_config$run_root)
  recovery_job_root <- file.path(recovery_run_root, "jobs", job_id)
  config <- source_config
  input_fields <- c(
    "series_wide_path", "true_quantile_grid_path", "sim_output_path", "meta_path"
  )
  path_fields <- names(config)[grepl("_path$", names(config))]
  for (field in setdiff(path_fields, input_fields)) {
    config[[field]] <- iqfc_v1_remap_path(
      config[[field]], source_job_root, recovery_job_root
    )
  }
  config$run_tag <- paste0(basename(recovery_run_root), "__", job_id)
  config$run_root <- recovery_job_root
  config$repo_root <- repo_root
  config$harness_root <- file.path(repo_root, "validation", "fitforecast_v2")
  config$defaults_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "config",
    "exdqlm_dynamic_fitforecast_v2_defaults.yaml"
  )
  config$status <- "pending"
  config$validation_stage <- "forecast-only"
  config$screen_stage <- iqfcr_v1_schema
  config$state_update_strategy <- "incremental_teacher_forced"
  config$fit_handoff_path <- source_row$source_handoff_path[[1L]]
  config$fit_handoff_manifest_path <-
    source_row$source_handoff_manifest_path[[1L]]
  config$source_config_path <- frozen_scientific_config_path
  config$source_config_sha256 <- iqfc_v1_sha256(frozen_scientific_config_path)
  config$source_failure_config_path <- frozen_failed_config_path
  config$source_failure_config_sha256 <- iqfc_v1_sha256(frozen_failed_config_path)
  config$source_failure_run_root <- dirname(dirname(dirname(dirname(
    source_row$source_config_path[[1L]]
  ))))
  config$source_fit_handoff_sha256 <-
    source_row$source_handoff_sha256[[1L]]
  config$source_fit_handoff_bytes <-
    as.numeric(source_row$source_handoff_bytes[[1L]])
  config$candidate_notes <- paste(
    "Forecast-only recovery from the hash-verified completed MCMC fit.",
    "Scientific specification, fit draws, data, scoring, origins, leads,",
    "and seeds are unchanged; only the namespace integration defect is repaired."
  )
  config$handoff <- utils::modifyList(
    config$handoff %||% list(),
    list(fit = TRUE, prune_fit_on_success = FALSE)
  )
  config$retention <- utils::modifyList(
    config$retention %||% list(),
    list(mode = "compact_success_only", allow_success_binary_payloads = FALSE)
  )
  config
}

iqfcr_v1_materialize <- function(repo_root,
                                 source_run_root,
                                 recovery_run_root,
                                 tarball_path) {
  git <- iqfc_v1_assert_branch(
    repo_root, require_clean = TRUE, require_synced = TRUE
  )
  package <- iqfc_v1_package_preflight(tarball_path)
  source <- iqfcr_v1_source_audit(
    source_run_root, verify_payload_hashes = TRUE
  )
  recovery_run_root <- iqfcr_v1_normalize(recovery_run_root, must_work = FALSE)
  if (file.exists(recovery_run_root) && !dir.exists(recovery_run_root)) {
    stop("Recovery run root exists as a file.", call. = FALSE)
  }
  if (dir.exists(recovery_run_root)) {
    existing <- list.files(recovery_run_root, all.files = FALSE, no.. = TRUE)
    unexpected <- setdiff(existing, c("orchestration", "runtime"))
    if (length(unexpected)) {
      stop(sprintf(
        "Recovery run root contains unexpected pre-materialization entries: %s",
        paste(unexpected, collapse = ", ")
      ), call. = FALSE)
    }
  }
  ffv2_ensure_dir(file.path(recovery_run_root, "manifests"))
  failed_config_root <- ffv2_ensure_dir(file.path(
    recovery_run_root, "manifests", "failed_execution_configs"
  ))
  scientific_config_root <- ffv2_ensure_dir(file.path(
    recovery_run_root, "manifests", "scientific_source_configs"
  ))

  manifest_rows <- vector("list", nrow(source$jobs))
  audit_rows <- vector("list", nrow(source$jobs))
  for (i in seq_len(nrow(source$jobs))) {
    row <- source$jobs[i, , drop = FALSE]
    source_config <- ffv2_read_json(row$source_config_path[[1L]])
    failed_copy <- iqfcr_v1_copy_verified(
      row$source_config_path[[1L]],
      file.path(failed_config_root, paste0(row$job_id[[1L]], ".json")),
      row$source_config_sha256[[1L]]
    )
    scientific_source <- iqfcr_v1_normalize(source_config$source_config_path)
    scientific_copy <- iqfcr_v1_copy_verified(
      scientific_source,
      file.path(scientific_config_root, paste0(row$job_id[[1L]], ".json")),
      source_config$source_config_sha256
    )
    config <- iqfcr_v1_recovery_config(
      source_config, repo_root, recovery_run_root, row$job_id[[1L]],
      scientific_copy, failed_copy, row
    )
    audit <- iqfcr_v1_config_audit(source_config, config)
    if (!isTRUE(audit$pass)) {
      stop(sprintf(
        "Recovery config audit failed for %s: %s",
        row$job_id[[1L]],
        paste(c(
          audit$unexpected,
          names(audit$invariant)[!audit$invariant]
        ), collapse = ", ")
      ), call. = FALSE)
    }
    ffv2_ensure_dir(dirname(config$row_config_path))
    ffv2_ensure_dir(dirname(config$inference_diagnostics_path))
    iqfcr_v1_copy_verified(
      row$source_inference_diagnostics_path[[1L]],
      config$inference_diagnostics_path
    )
    ffv2_write_json(config, config$row_config_path)
    manifest_rows[[i]] <- data.frame(
      job_id = row$job_id[[1L]], row_id = as.integer(config$row_id),
      row_key = as.character(config$row_key), spec_id = as.character(config$spec_id),
      family = as.character(config$family), tau = as.numeric(config$tau),
      fit_size = as.integer(config$fit_size),
      model_variant = as.character(config$model_variant), inference = "mcmc",
      phase = "mcmc_tt500", chain_id = as.integer(config$chain_id),
      source_authority = as.character(config$source_authority),
      source_job_id = as.character(config$source_job_id),
      source_config_path = failed_copy,
      source_config_sha256 = iqfc_v1_sha256(failed_copy),
      source_handoff_path = row$source_handoff_path[[1L]],
      source_handoff_sha256 = row$source_handoff_sha256[[1L]],
      source_handoff_bytes = row$source_handoff_bytes[[1L]],
      row_config_path = iqfcr_v1_normalize(config$row_config_path),
      row_config_sha256 = iqfc_v1_sha256(config$row_config_path),
      row_status_path = config$row_status_path,
      status = "pending", stringsAsFactors = FALSE
    )
    audit_rows[[i]] <- data.frame(
      job_id = row$job_id[[1L]],
      changed_top_level_fields = paste(audit$changed, collapse = ";"),
      unexpected_top_level_fields = paste(audit$unexpected, collapse = ";"),
      scientific_invariants_preserved = all(audit$invariant),
      config_contract_pass = audit$pass,
      validation_stage = config$validation_stage,
      state_update_strategy = config$state_update_strategy,
      refit_requested = FALSE,
      source_handoff_pruning_enabled = isTRUE(config$handoff$prune_fit_on_success),
      stringsAsFactors = FALSE
    )
  }
  manifest <- do.call(rbind, manifest_rows)
  config_audit <- do.call(rbind, audit_rows)
  manifest_path <- iqfc_v1_write_csv(
    manifest, file.path(recovery_run_root, "manifests", "job_manifest.csv")
  )
  source_ledger_path <- iqfc_v1_write_csv(
    source$jobs,
    file.path(recovery_run_root, "manifests", "source_fit_handoff_ledger.csv")
  )
  config_audit_path <- iqfc_v1_write_csv(
    config_audit,
    file.path(recovery_run_root, "manifests", "config_change_audit.csv")
  )
  session_path <- file.path(recovery_run_root, "manifests", "session_info.txt")
  capture.output(sessionInfo(), file = session_path)
  preflight <- list(
    schema_version = iqfcr_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    git = git, package = package,
    source_run_root = source$source_run_root,
    source_pipeline_status = source$pipeline_status,
    source_manifest_path = source$source_manifest_path,
    source_manifest_sha256 = source$source_manifest_sha256,
    source_preflight_path = source$source_preflight_path,
    source_preflight_sha256 = source$source_preflight_sha256,
    source_handoff_ledger_path = source_ledger_path,
    source_handoff_ledger_sha256 = iqfc_v1_sha256(source_ledger_path),
    source_handoff_files = nrow(source$jobs),
    source_handoff_bytes = source$total_bytes,
    source_handoff_gib = source$total_bytes / 1024^3,
    recovery_manifest_path = manifest_path,
    recovery_manifest_sha256 = iqfc_v1_sha256(manifest_path),
    config_change_audit_path = config_audit_path,
    config_change_audit_sha256 = iqfc_v1_sha256(config_audit_path),
    jobs = nrow(manifest), validation_stage = "forecast-only",
    state_update_strategy = "incremental_teacher_forced",
    source_handoffs_pruned_during_recovery = FALSE,
    session_info_path = iqfcr_v1_normalize(session_path),
    session_info_sha256 = iqfc_v1_sha256(session_path),
    article_write_performed = FALSE,
    shared_validation_write_performed = FALSE,
    overleaf_write_performed = FALSE
  )
  preflight_path <- ffv2_write_json(
    preflight, file.path(recovery_run_root, "manifests", "preflight_report.json")
  )
  list(
    manifest = manifest, preflight = preflight,
    preflight_path = preflight_path
  )
}

iqfcr_v1_cleanup_candidates <- function(source_run_root, recovery_run_root) {
  health <- iqfc_v1_health(recovery_run_root)
  if (health$done != iqfcr_v1_expected_jobs || health$failed != 0L ||
      health$remaining != 0L || health$running != 0L) {
    stop("Cleanup candidates require a complete recovery run.", call. = FALSE)
  }
  source <- iqfcr_v1_source_audit(
    source_run_root, verify_payload_hashes = TRUE
  )
  data.frame(
    path = source$jobs$source_handoff_path,
    manifest_path = source$jobs$source_handoff_manifest_path,
    sha256 = source$jobs$source_handoff_sha256,
    bytes = source$jobs$source_handoff_bytes,
    classification = "old_regenerable_heavy_artifact_after_verified_recovery",
    action = "defer_delete_until_explicit_post_closeout_cleanup",
    stringsAsFactors = FALSE
  )
}

iqfcr_v1_closeout <- function(repo_root, source_run_root, recovery_run_root) {
  result <- iqfc_v1_closeout(repo_root, recovery_run_root)
  health <- iqfc_v1_health(recovery_run_root)
  configs <- lapply(health$jobs$row_config_path, ffv2_read_json)
  forecast_only <- all(vapply(
    configs, function(x) identical(as.character(x$validation_stage), "forecast-only"),
    logical(1L)
  ))
  non_pruning <- all(vapply(
    configs,
    function(x) !isTRUE((x$handoff %||% list())$prune_fit_on_success),
    logical(1L)
  ))
  progress_has_fit <- vapply(configs, function(config) {
    if (!file.exists(config$row_progress_path)) return(TRUE)
    progress <- iqfc_v1_read_csv(config$row_progress_path)
    any(progress$stage == "fit", na.rm = TRUE)
  }, logical(1L))
  checks <- c(
    jobs = health$total == iqfcr_v1_expected_jobs,
    complete = health$done == iqfcr_v1_expected_jobs && health$failed == 0L &&
      health$running == 0L && health$remaining == 0L,
    forecast_only = forecast_only,
    zero_refits = !any(progress_has_fit),
    source_handoffs_retained = non_pruning
  )
  if (!all(checks)) {
    stop(sprintf("Recovery closeout failed: %s",
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
  candidates <- iqfcr_v1_cleanup_candidates(source_run_root, recovery_run_root)
  cleanup_path <- iqfc_v1_write_csv(
    candidates,
    file.path(recovery_run_root, "storage", "deferred_cleanup_candidates.csv")
  )
  preflight_path <- file.path(recovery_run_root, "manifests", "preflight_report.json")
  closeout <- list(
    schema_version = iqfcr_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    status = "READY_FOR_SCIENTIFIC_REVIEW_NO_AUTOMATIC_ARTICLE_PROMOTION",
    checks = as.list(checks),
    jobs = health$total, refits = 0L,
    source_handoffs_reverified = nrow(candidates),
    source_handoff_bytes = sum(candidates$bytes),
    source_handoffs_pruned = 0L,
    comparison_decision_path = result$decision_path,
    comparison_decision_sha256 = iqfc_v1_sha256(result$decision_path),
    recovery_preflight_path = iqfcr_v1_normalize(preflight_path),
    recovery_preflight_sha256 = iqfc_v1_sha256(preflight_path),
    deferred_cleanup_path = cleanup_path,
    deferred_cleanup_sha256 = iqfc_v1_sha256(cleanup_path),
    article_write_performed = FALSE,
    shared_validation_write_performed = FALSE,
    overleaf_write_performed = FALSE
  )
  closeout_path <- ffv2_write_json(
    closeout, file.path(recovery_run_root, "manifests", "recovery_closeout.json")
  )
  list(
    comparison = result, closeout = closeout,
    closeout_path = closeout_path, cleanup_path = cleanup_path
  )
}
