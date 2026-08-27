idolv2r_schema <-
  "independent_location_orthogonalized_tau0_v2_interval_replay_v1"
idolv2r_parent_run_id <-
  "independent_location_orthogonalized_tau0_v2_20260827_005026"
idolv2r_candidate_id <-
  "idol2_al_normal_t0p05_o1_orthogonalized_3e09_132580d19b"
idolv2r_draws_per_chain <- 1000L
idolv2r_chains <- 3L
idolv2r_branch <-
  "validation/independent-location-orthogonalized-tau0-v2-1.0.0"

idolv2r_source_plan <- function(repo_root = ffv2_repo_root()) {
  path <- file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    idolv2r_parent_run_id, "materialization", "confirmation_plan.csv"
  )
  plan <- ffv2_read_csv(path)
  plan <- plan[plan$candidate_id == idolv2r_candidate_id, , drop = FALSE]
  plan <- plan[order(plan$chain_id), , drop = FALSE]
  if (nrow(plan) != idolv2r_chains ||
      !identical(as.integer(plan$chain_id), seq_len(idolv2r_chains)) ||
      !all(file.exists(plan$config_path))) {
    stop("The frozen V2 winner confirmation panel is incomplete.", call. = FALSE)
  }
  plan
}

idolv2r_replay_job <- function(source_job, source_config_sha256) {
  chain_id <- as.integer(source_job$chain_id)
  source_job_id <- as.character(source_job$job_id)
  job_id <- paste(
    "interval_replay", idolv2r_candidate_id, "canonical_article",
    "interval_replay_r01", sprintf("c%02d", chain_id), sep = "__"
  )
  job <- source_job
  job$job_id <- job_id
  job$spec_id <- paste0(
    "independent_location_orthogonalized_tau0_v2_interval_replay__", job_id
  )
  job$profile$declared_replay <- TRUE
  job$config$validation_spec_id <- job$spec_id
  job$config$metrics$posterior_metric_draws <- idolv2r_draws_per_chain
  job$config$metrics$posterior_metric_intervals$draws <-
    idolv2r_draws_per_chain
  job$config$sampling$nd_draws <- idolv2r_draws_per_chain
  job$config$sampling$chunk <- min(120L, idolv2r_draws_per_chain)
  job$config$synthesis$n_samp <- idolv2r_draws_per_chain
  job$config$outputs$retention_profile <-
    "storage_light_location_orthogonalized_tau0_v2_interval_replay"
  job$root_spec$root_id <- job_id
  job$root_spec$screening_wave <- "interval_replay"
  job$study_contract$interval_replay <- list(
    schema_version = idolv2r_schema,
    purpose = "increase_metric_interval_endpoint_precision_only",
    parent_job_id = source_job_id,
    parent_config_sha256 = source_config_sha256,
    draws_per_chain = idolv2r_draws_per_chain,
    model_refit_contract = "same_model_same_mcmc_seeds_same_mcmc_budget",
    point_authority_contract = "retain_original_three_chain_point_confirmation"
  )
  job$replay_contract <- list(
    schema_version = idolv2r_schema,
    parent_run_id = idolv2r_parent_run_id,
    parent_job_id = source_job_id,
    parent_config_sha256 = source_config_sha256,
    allowed_change = "posterior_metric_draw_budget_only",
    draws_per_chain = idolv2r_draws_per_chain
  )
  job
}

idolv2r_normalize_to_source <- function(replay, source) {
  replay$job_id <- source$job_id
  replay$spec_id <- source$spec_id
  replay$profile$declared_replay <- source$profile$declared_replay
  replay$config$validation_spec_id <- source$config$validation_spec_id
  replay$config$metrics$posterior_metric_draws <-
    source$config$metrics$posterior_metric_draws
  replay$config$metrics$posterior_metric_intervals$draws <-
    source$config$metrics$posterior_metric_intervals$draws
  replay$config$sampling$nd_draws <- source$config$sampling$nd_draws
  replay$config$sampling$chunk <- source$config$sampling$chunk
  replay$config$synthesis$n_samp <- source$config$synthesis$n_samp
  replay$config$outputs$retention_profile <-
    source$config$outputs$retention_profile
  replay$root_spec$root_id <- source$root_spec$root_id
  replay$root_spec$screening_wave <- source$root_spec$screening_wave
  replay$study_contract$interval_replay <- NULL
  replay$replay_contract <- NULL
  replay
}

idolv2r_assert_scientific_identity <- function(replay, source) {
  normalized <- idolv2r_normalize_to_source(replay, source)
  difference <- all.equal(
    normalized, source, check.attributes = FALSE, tolerance = 0
  )
  if (!isTRUE(difference)) {
    stop(
      paste("Interval replay changed a non-authorized field:",
            paste(difference, collapse = "; ")),
      call. = FALSE
    )
  }
  expected <- c(
    mcmc_seed = identical(
      replay$config$inference$mcmc$control$seed,
      source$config$inference$mcmc$control$seed
    ),
    mcmc_rng_seed = identical(
      replay$config$inference$mcmc$control$rng_seed,
      source$config$inference$mcmc$control$rng_seed
    ),
    vb_seed = identical(
      replay$config$inference$mcmc$vb_warm_start_seed,
      source$config$inference$mcmc$vb_warm_start_seed
    ),
    synthesis_seed = identical(
      replay$config$synthesis$seed, source$config$synthesis$seed
    ),
    n_burn = identical(
      replay$config$inference$mcmc$n_burn,
      source$config$inference$mcmc$n_burn
    ),
    n_mcmc = identical(
      replay$config$inference$mcmc$n_mcmc,
      source$config$inference$mcmc$n_mcmc
    ),
    tau0 = identical(
      replay$config$inference$mcmc$priors$beta$rhs_ns$tau0,
      source$config$inference$mcmc$priors$beta$rhs_ns$tau0
    ),
    draw_budget = identical(
      as.integer(replay$config$metrics$posterior_metric_intervals$draws),
      idolv2r_draws_per_chain
    ),
    one_thread = identical(
      as.integer(replay$config$cpp$postpred_threads), 1L
    ),
    storage_light = !isTRUE(replay$config$outputs$keep_draws) &&
      !isTRUE(replay$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(replay$config$outputs$retain_full_rds_on_failure)
  )
  if (!all(expected)) {
    stop(
      paste("Interval replay contract failed:",
            paste(names(expected)[!expected], collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(expected)
}

idolv2r_materialize <- function(repo_root = ffv2_repo_root(), output_root,
                                run_id, run_tag) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  if (!identical(
    system2("git", c("-C", repo_root, "branch", "--show-current"),
            stdout = TRUE), idolv2r_branch
  )) stop("Interval replay requires the dedicated V2 task branch.", call. = FALSE)
  output_root <- normalizePath(output_root, winslash = "/", mustWork = FALSE)
  if (dir.exists(output_root) &&
      length(list.files(output_root, all.files = TRUE, no.. = TRUE))) {
    stop("Refusing to overwrite interval replay materialization.", call. = FALSE)
  }
  ffv2_ensure_dir(output_root)
  config_dir <- ffv2_ensure_dir(file.path(output_root, "configs"))
  source_plan <- idolv2r_source_plan(repo_root)
  rows <- vector("list", nrow(source_plan))
  provenance <- vector("list", nrow(source_plan))
  for (i in seq_len(nrow(source_plan))) {
    source_path <- normalizePath(
      source_plan$config_path[[i]], winslash = "/", mustWork = TRUE
    )
    source_hash <- ffv2_file_sha256(source_path)
    source_job <- idolp_v2_read_json(source_path)
    replay <- idolv2r_replay_job(source_job, source_hash)
    idolv2r_assert_scientific_identity(replay, source_job)
    config_path <- file.path(
      config_dir, sprintf("interval_replay_chain_%02d.json", i)
    )
    qdesn_ssv2_write_json(replay, config_path)
    rows[[i]] <- idol_v2_plan_row(replay, config_path)
    provenance[[i]] <- data.frame(
      chain_id = i,
      parent_job_id = source_job$job_id,
      parent_config_path = idolp_v2_repo_relative(source_path, repo_root),
      parent_config_sha256 = source_hash,
      replay_job_id = replay$job_id,
      replay_config_path = idolp_v2_repo_relative(config_path, repo_root),
      replay_config_sha256 = ffv2_file_sha256(config_path),
      stringsAsFactors = FALSE
    )
  }
  plan <- do.call(rbind, rows)
  plan_path <- ffv2_write_csv(plan, file.path(output_root, "replay_plan.csv"))
  provenance_path <- ffv2_write_csv(
    do.call(rbind, provenance), file.path(output_root, "source_provenance.csv")
  )
  files <- c(plan_path, provenance_path, plan$config_path)
  ledger <- data.frame(
    path = vapply(
      files, idolp_v2_repo_relative, character(1L), repo_root = repo_root
    ),
    bytes = as.numeric(file.info(files)$size),
    sha256 = vapply(files, ffv2_file_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  ledger_path <- ffv2_write_csv(
    ledger, file.path(output_root, "materialization_file_manifest.csv")
  )
  manifest <- list(
    schema_version = idolv2r_schema,
    status = "MATERIALIZED",
    run_id = run_id, run_tag = run_tag,
    branch = idolv2r_branch,
    launch_commit = system2(
      "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
    )[[1L]],
    parent_run_id = idolv2r_parent_run_id,
    candidate_id = idolv2r_candidate_id,
    jobs = nrow(plan), chains = idolv2r_chains,
    draws_per_chain = idolv2r_draws_per_chain,
    total_metric_draws = idolv2r_chains * idolv2r_draws_per_chain,
    scientific_change = "none",
    numerical_change = "posterior_metric_draw_budget_200_to_1000_per_chain",
    replay_plan_sha256 = ffv2_file_sha256(plan_path),
    source_provenance_sha256 = ffv2_file_sha256(provenance_path),
    file_manifest_sha256 = ffv2_file_sha256(ledger_path)
  )
  ffv2_write_json(manifest, file.path(output_root, "materialization_manifest.json"))
  invisible(list(plan = plan, manifest = manifest))
}

idolv2r_verify_materialization <- function(repo_root = ffv2_repo_root(),
                                           output_root) {
  source_plan <- idolv2r_source_plan(repo_root)
  plan <- ffv2_read_csv(file.path(output_root, "replay_plan.csv"))
  if (nrow(plan) != idolv2r_chains ||
      !identical(as.integer(plan$chain_id), seq_len(idolv2r_chains)) ||
      any(plan$expected_metric_draws != idolv2r_draws_per_chain) ||
      !all(file.exists(plan$config_path))) {
    stop("The interval replay plan is incomplete.", call. = FALSE)
  }
  for (i in seq_len(nrow(plan))) {
    replay <- idolp_v2_read_json(plan$config_path[[i]])
    source <- idolp_v2_read_json(source_plan$config_path[[i]])
    idolv2r_assert_scientific_identity(replay, source)
  }
  manifest <- ffv2_read_csv(file.path(
    output_root, "materialization_file_manifest.csv"
  ))
  paths <- file.path(repo_root, manifest$path)
  if (any(!file.exists(paths)) ||
      any(as.numeric(file.info(paths)$size) != manifest$bytes) ||
      any(vapply(paths, ffv2_file_sha256, character(1L)) != manifest$sha256)) {
    stop("The interval replay materialization manifest failed.", call. = FALSE)
  }
  invisible(plan)
}

idolv2r_verify_runtime <- function(repo_root = ffv2_repo_root(), output_root,
                                   closeout_root, run_tag) {
  plan <- idolv2r_verify_materialization(repo_root, output_root)
  ffv2_ensure_dir(closeout_root)
  draws_by_chain <- vector("list", nrow(plan))
  runtime <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    root <- idol_v2_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    draw_path <- file.path(root, "tables", "metric_draws.csv.gz")
    interval_path <- file.path(root, "tables", "metric_interval_summary.csv")
    reconstruction_path <- file.path(
      root, "tables", "origin_horizon_reconstruction_audit.csv"
    )
    signoff_path <- file.path(root, "signoff_summary.csv")
    required <- c(status_path, draw_path, interval_path, reconstruction_path,
                  signoff_path)
    if (!all(file.exists(required))) {
      stop(sprintf("Replay chain %d is incomplete.", i), call. = FALSE)
    }
    status <- idolp_v2_read_json(status_path)
    draws <- ffv2_read_csv(gzfile(draw_path))
    intervals <- ffv2_read_csv(interval_path)
    reconstruction <- ffv2_read_csv(reconstruction_path)
    binary <- list.files(
      root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
      full.names = TRUE, ignore.case = TRUE
    )
    checks <- c(
      success = identical(status$status, "SUCCESS"),
      config_hash = identical(
        ffv2_file_sha256(plan$config_path[[i]]), status$config_sha256
      ),
      draw_hash = identical(
        ffv2_file_sha256(draw_path),
        unname(status$diagnostic_artifact_hashes[["metric_draws.csv.gz"]])
      ),
      draw_rows = nrow(draws) == idolv2r_draws_per_chain,
      draw_chain = all(draws$chain_id == i),
      draw_keys = !anyDuplicated(draws[c("chain_id", "draw_id")]),
      finite = all(vapply(
        draws[c("fit_rmse", "forecast_mae", "forecast_check_loss")],
        function(x) all(is.finite(x)), logical(1L)
      )),
      interval_rows = nrow(intervals) >= 3L &&
        all(intervals$n_draws == idolv2r_draws_per_chain),
      reconstruction = nrow(reconstruction) > 0L && all(reconstruction$pass) &&
        max(reconstruction$forecast_mae_max_abs_error,
            reconstruction$forecast_check_max_abs_error,
            na.rm = TRUE) <= idolp_v2_tolerance,
      storage = !length(binary) &&
        as.integer(status$binary_payloads_remaining) == 0L
    )
    runtime[[i]] <- data.frame(
      chain_id = i, job_id = plan$job_id[[i]], status = status$status,
      elapsed_seconds = as.numeric(status$elapsed_seconds),
      metric_draws = nrow(draws), all_checks_pass = all(checks),
      failed_checks = paste(names(checks)[!checks], collapse = ";"),
      draw_path = idolp_v2_repo_relative(draw_path, repo_root),
      draw_sha256 = ffv2_file_sha256(draw_path),
      signoff_path = idolp_v2_repo_relative(signoff_path, repo_root),
      signoff_sha256 = ffv2_file_sha256(signoff_path),
      stringsAsFactors = FALSE
    )
    draws_by_chain[[i]] <- draws
  }
  runtime <- do.call(rbind, runtime)
  if (any(!runtime$all_checks_pass)) {
    stop("At least one replay chain failed verification.", call. = FALSE)
  }
  old_roles <- ffv2_read_csv(idolp_v2_paths(repo_root)$interval_roles)
  sensitivity <- idolp_v2_interval_sensitivity(draws_by_chain, old_roles)
  ffv2_write_csv(runtime, file.path(closeout_root, "runtime_verification.csv"))
  ffv2_write_csv(
    sensitivity$pooled, file.path(closeout_root, "pooled_metric_intervals.csv")
  )
  ffv2_write_csv(
    sensitivity$leave_one_chain_out,
    file.path(closeout_root, "interval_precision_leave_one_chain_out.csv")
  )
  ffv2_write_csv(
    sensitivity$bootstrap_summary,
    file.path(closeout_root, "interval_precision_block_bootstrap.csv")
  )
  ffv2_write_csv(
    sensitivity$checks, file.path(closeout_root, "interval_precision_checks.csv")
  )
  ffv2_write_csv(
    sensitivity$direction,
    file.path(closeout_root, "interval_direction_comparison.csv")
  )
  decision <- list(
    schema_version = idolv2r_schema,
    status = if (identical(
      sensitivity$decision, "PASS_USE_RETAINED_3000_DRAWS"
    )) "PASS" else "FAIL",
    run_tag = run_tag,
    candidate_id = idolv2r_candidate_id,
    chains = idolv2r_chains,
    draws_per_chain = idolv2r_draws_per_chain,
    total_metric_draws = sum(vapply(draws_by_chain, nrow, integer(1L))),
    interval_precision_decision = sensitivity$decision,
    point_authority_policy = "retain_original_three_chain_point_confirmation",
    article_update_automatic = FALSE
  )
  decision_path <- ffv2_write_json(
    decision, file.path(closeout_root, "replay_decision.json")
  )
  files <- list.files(closeout_root, recursive = TRUE, full.names = TRUE)
  files <- files[basename(files) != "closeout_file_manifest.csv"]
  manifest <- idolp_v2_file_ledger(files, closeout_root)
  manifest_path <- ffv2_write_csv(
    manifest, file.path(closeout_root, "closeout_file_manifest.csv")
  )
  result <- list(
    decision = decision,
    decision_path = decision_path,
    closeout_manifest_path = manifest_path,
    sensitivity = sensitivity,
    runtime = runtime
  )
  if (!identical(decision$status, "PASS")) {
    stop("The targeted interval replay did not pass the precision gate.",
         call. = FALSE)
  }
  invisible(result)
}
