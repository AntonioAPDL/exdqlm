idolp_v2_schema <- "independent_location_orthogonalized_tau0_v2_promotion_v1"
idolp_v2_branch <-
  "validation/independent-location-orthogonalized-tau0-v2-1.0.0"
idolp_v2_scientific_commit <-
  "985bb3e1ba9a9f96472964929738e9e39ee75951"
idolp_v2_run_id <-
  "independent_location_orthogonalized_tau0_v2_20260827_005026"
idolp_v2_run_tag <-
  "independent-location-orthogonalized-tau0-v2-20260827_005026__git-985bb3e"
idolp_v2_candidate_id <-
  "idol2_al_normal_t0p05_o1_orthogonalized_3e09_132580d19b"
idolp_v2_target_cell_id <- "al_normal_t0p05"
idolp_v2_point_parent_id <-
  "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821"
idolp_v2_interval_parent_id <-
  "qdesn_dqlm_500obs_metric_interval_reporting_v10_1_20260825"
idolp_v2_point_id <-
  "qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827"
idolp_v2_interval_id <-
  "qdesn_dqlm_500obs_metric_interval_reporting_v11_1_20260827"
idolp_v2_audit_id <-
  "independent_location_orthogonalized_tau0_v2_20260827"
idolp_v2_estimator_id <-
  "chain_balanced_draw_metric_equal_tailed_95cri_v1"
idolp_v2_point_estimator <-
  "arithmetic_mean_of_three_full_budget_mcmc_point_paths"
idolp_v2_tolerance <- 1e-6
idolp_v2_quantile_type <- 7L
idolp_v2_bootstrap_seed <- 20260827L
idolp_v2_bootstrap_replicates <- 1000L
idolp_v2_bootstrap_block_length <- 10L
idolp_v2_loo_mean_sd_limit <- 0.20
idolp_v2_loo_endpoint_width_limit <- 0.15
idolp_v2_bootstrap_endpoint_mcse_width_limit <- 0.05
idolp_v2_parent_hashes <- c(
  point_interface =
    "eb697b6f3e366581d158a41ecd2213761486be769b541439d2d862d840ea4b27",
  point_manifest =
    "b5a87a3b5a69ac36a1a16ee8a2638ca3d374ea1d6a80b6b72ba44901376a3993",
  interval_roles =
    "4ebdda337937a9cabcb97d5acb026793cc23c401eb1f3c114c7c94892bb7c56d",
  interval_decision =
    "790e424aa450f9e3c8cc5f659ccb933a772a0c2bbca0db69d8ff6708498e0295"
)
idolp_v2_runtime_hashes <- c(
  confirmation_verification =
    "76a950d85163517bb155ce771c7e35ea2d4a5cf46c59d1466ae65565f720c979",
  materialization_manifest =
    "4d356731d210114f78ffdd041cdb68636dcffa74ffbbc33913d2f01c519d22a3",
  final_metric_ledger =
    "376f5741591b44a7833b2fbe29dc48218e520a6f7a7ad9d3292954998072517c"
)
idolp_v2_replay_run_id <-
  "independent_location_orthogonalized_tau0_v2_interval_replay_20260827_162303"
idolp_v2_replay_run_tag <- paste0(
  "independent-location-orthogonalized-tau0-v2-interval-replay-",
  "20260827_162303__git-d6bc4c5"
)
idolp_v2_replay_draws_per_chain <- 1000L
idolp_v2_replay_total_draws <- 3000L
idolp_v2_replay_hashes <- c(
  materialization_manifest =
    "42cdb9954e1724d6e72bb7dd5ae5d2b3f88c346206993abc1bebb0f0488ce3dd",
  replay_plan =
    "1972d16ca3aef68216c0ecc96045e0b78751da9b982836feb3f5f748517047a5",
  source_provenance =
    "5400b52cbaafc1f4828f7cfb350c8667fe49ec83d1f8cb6c7127f39b1945bb15",
  replay_decision =
    "e8e5a25290234668393b1e54b7dcfefd2cdbda06aec5291325ab866d39030da9",
  closeout_manifest =
    "5ac0785ffec49d9c37ceb237df3a712317be4faf2f3d12fadf7f6701f20317b5"
)

idolp_v2_paths <- function(repo_root = ffv2_repo_root()) {
  point_parent <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    idolp_v2_point_parent_id
  )
  interval_parent <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    idolp_v2_interval_parent_id
  )
  state <- file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    idolp_v2_run_id
  )
  result <- file.path(
    repo_root, "results", "qdesn_mcmc_validation",
    "qdesn_dynamic_fitforecast_v2_500obs_location_orthogonalized_tau0_v2",
    idolp_v2_run_tag
  )
  replay_state <- file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    idolp_v2_replay_run_id
  )
  replay_result <- file.path(
    repo_root, "results", "qdesn_mcmc_validation",
    "qdesn_dynamic_fitforecast_v2_500obs_location_orthogonalized_tau0_v2",
    idolp_v2_replay_run_tag
  )
  list(
    point_parent = point_parent,
    point_interface = file.path(
      point_parent, paste0(idolp_v2_point_parent_id, "_interface.csv")
    ),
    point_manifest = file.path(
      point_parent, paste0(idolp_v2_point_parent_id, "_manifest.json")
    ),
    point_source_ledger = file.path(point_parent, "source_ledger.csv"),
    point_gap_ledger = file.path(point_parent, "remaining_gap_ledger.csv"),
    interval_parent = interval_parent,
    interval_roles = file.path(interval_parent, "plot_ready_metric_intervals.csv"),
    interval_decision = file.path(interval_parent, "decision_manifest.json"),
    state = state,
    closeout = file.path(state, "closeout"),
    materialization = file.path(state, "materialization"),
    confirmation_plan = file.path(state, "materialization", "confirmation_plan.csv"),
    confirmation_verification = file.path(state, "confirmation_verification.json"),
    confirmation_runtime = file.path(state, "confirmation_verification_runtime.csv"),
    materialization_manifest = file.path(
      state, "materialization", "materialization_manifest.json"
    ),
    final_decision = file.path(state, "closeout", "final_decision.json"),
    final_metric_ledger = file.path(
      state, "closeout", "final_metric_promotion_ledger.csv"
    ),
    closeout_file_manifest = file.path(state, "closeout", "file_manifest.csv"),
    confirmation_points = file.path(
      state, "closeout", "confirmation_point_metrics.csv"
    ),
    confirmation_intervals = file.path(
      state, "closeout", "confirmation_posterior_metric_intervals.csv"
    ),
    confirmation_transform = file.path(
      state, "closeout", "confirmation_transform_diagnostics.csv"
    ),
    confirmation_conditioning = file.path(
      state, "closeout", "confirmation_conditioning_diagnostics.csv"
    ),
    candidate_profiles = file.path(
      state, "materialization", "candidate_profiles.csv"
    ),
    source_registry = file.path(
      state, "materialization", "canonical_source_registry.csv"
    ),
    window_registry = file.path(
      state, "materialization", "source_window_registry.csv"
    ),
    result = result,
    replay_state = replay_state,
    replay_materialization = file.path(replay_state, "materialization"),
    replay_closeout = file.path(replay_state, "closeout"),
    replay_materialization_manifest = file.path(
      replay_state, "materialization", "materialization_manifest.json"
    ),
    replay_plan = file.path(
      replay_state, "materialization", "replay_plan.csv"
    ),
    replay_source_provenance = file.path(
      replay_state, "materialization", "source_provenance.csv"
    ),
    replay_decision = file.path(
      replay_state, "closeout", "replay_decision.json"
    ),
    replay_closeout_manifest = file.path(
      replay_state, "closeout", "closeout_file_manifest.csv"
    ),
    replay_runtime = file.path(
      replay_state, "closeout", "runtime_verification.csv"
    ),
    replay_result = replay_result,
    audit = file.path(
      repo_root, "validation", "fitforecast_v2", "audits", idolp_v2_audit_id
    ),
    point = file.path(
      repo_root, "validation", "fitforecast_v2", "promotions", idolp_v2_point_id
    ),
    interval = file.path(
      repo_root, "validation", "fitforecast_v2", "promotions",
      idolp_v2_interval_id
    )
  )
}

idolp_v2_read_json <- function(path) {
  ffv2_require_namespace("jsonlite")
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

idolp_v2_repo_relative <- function(path, repo_root) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  prefix <- paste0(repo_root, "/")
  if (!startsWith(path, prefix)) {
    stop(sprintf("Path escapes the repository: %s", path), call. = FALSE)
  }
  substring(path, nchar(prefix) + 1L)
}

idolp_v2_git_output <- function(repo_root, ...) {
  out <- system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  out
}

idolp_v2_assert_git <- function(repo_root, require_clean = TRUE) {
  branch <- idolp_v2_git_output(repo_root, "branch", "--show-current")[[1L]]
  head <- idolp_v2_git_output(repo_root, "rev-parse", "HEAD")[[1L]]
  ancestor <- system2(
    "git",
    c("-C", repo_root, "merge-base", "--is-ancestor",
      idolp_v2_scientific_commit, "HEAD"),
    stdout = FALSE, stderr = FALSE
  )
  dirty <- idolp_v2_git_output(repo_root, "status", "--porcelain")
  if (!identical(branch, idolp_v2_branch) || ancestor != 0L ||
      (require_clean && length(dirty))) {
    stop("Promotion requires the clean committed V2 task branch.", call. = FALSE)
  }
  list(branch = branch, head = head, dirty = length(dirty) > 0L)
}

idolp_v2_assert_hash <- function(path, expected, label) {
  if (!file.exists(path) || !identical(ffv2_file_sha256(path), expected)) {
    stop(sprintf("Frozen %s is missing or changed: %s", label, path),
         call. = FALSE)
  }
  invisible(TRUE)
}

idolp_v2_assert_empty <- function(path) {
  if (dir.exists(path) && length(list.files(path, all.files = TRUE, no.. = TRUE))) {
    stop(sprintf("Refusing to overwrite nonempty output: %s", path), call. = FALSE)
  }
  invisible(TRUE)
}

idolp_v2_copy_verified <- function(source, destination) {
  source_hash <- ffv2_file_sha256(source)
  ffv2_ensure_dir(dirname(destination))
  if (!file.copy(source, destination, overwrite = FALSE, copy.mode = TRUE) ||
      !identical(ffv2_file_sha256(destination), source_hash)) {
    stop(sprintf("Could not freeze source: %s", source), call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

idolp_v2_portabilize <- function(x, repo_root) {
  prefix <- paste0(normalizePath(repo_root, winslash = "/", mustWork = TRUE), "/")
  if (is.character(x)) {
    return(vapply(x, function(one) {
      if (is.na(one)) return(NA_character_)
      if (startsWith(one, prefix)) {
        return(substring(one, nchar(prefix) + 1L))
      }
      workspace_prefix <- "/data/jaguir26/local/src/"
      if (startsWith(one, workspace_prefix)) {
        return(paste0(
          "external-workspace://",
          substring(one, nchar(workspace_prefix) + 1L)
        ))
      }
      if (startsWith(one, "/")) {
        return(paste0("external-location://", basename(one)))
      }
      one
    }, character(1L), USE.NAMES = FALSE))
  }
  if (is.list(x)) {
    return(lapply(x, idolp_v2_portabilize, repo_root = repo_root))
  }
  x
}

idolp_v2_worst_grade <- function(x) {
  severity <- c(MISSING = 4L, FAIL = 3L, WARN = 2L, PASS = 1L)
  x <- toupper(as.character(x))
  x[!x %in% names(severity)] <- "MISSING"
  x[[which.max(unname(severity[x]))]]
}

idolp_v2_assert_closeout_manifest <- function(path) {
  manifest <- ffv2_read_csv(path)
  required <- c("path", "bytes", "sha256")
  if (nrow(manifest) != 26L || !all(required %in% names(manifest))) {
    stop("The V2 closeout manifest is incomplete.", call. = FALSE)
  }
  ok <- vapply(seq_len(nrow(manifest)), function(i) {
    file.exists(manifest$path[[i]]) &&
      identical(as.numeric(file.info(manifest$path[[i]])$size),
                as.numeric(manifest$bytes[[i]])) &&
      identical(ffv2_file_sha256(manifest$path[[i]]), manifest$sha256[[i]])
  }, logical(1L))
  if (!all(ok)) stop("A V2 closeout artifact failed hash verification.", call. = FALSE)
  manifest
}

idolp_v2_assert_evidence <- function(repo_root = ffv2_repo_root(),
                                     require_clean = TRUE) {
  p <- idolp_v2_paths(repo_root)
  git <- idolp_v2_assert_git(repo_root, require_clean = require_clean)
  idolp_v2_assert_hash(
    p$point_interface, idolp_v2_parent_hashes[["point_interface"]],
    "v9 point interface"
  )
  idolp_v2_assert_hash(
    p$point_manifest, idolp_v2_parent_hashes[["point_manifest"]],
    "v9 point manifest"
  )
  idolp_v2_assert_hash(
    p$interval_roles, idolp_v2_parent_hashes[["interval_roles"]],
    "v10.1 interval roles"
  )
  idolp_v2_assert_hash(
    p$interval_decision, idolp_v2_parent_hashes[["interval_decision"]],
    "v10.1 interval decision"
  )
  idolp_v2_assert_hash(
    p$confirmation_verification,
    idolp_v2_runtime_hashes[["confirmation_verification"]],
    "V2 confirmation verification"
  )
  idolp_v2_assert_hash(
    p$materialization_manifest,
    idolp_v2_runtime_hashes[["materialization_manifest"]],
    "V2 materialization manifest"
  )
  idolp_v2_assert_hash(
    p$final_metric_ledger, idolp_v2_runtime_hashes[["final_metric_ledger"]],
    "V2 final metric ledger"
  )
  closeout_manifest <- idolp_v2_assert_closeout_manifest(
    p$closeout_file_manifest
  )
  verification <- idolp_v2_read_json(p$confirmation_verification)
  decision <- idolp_v2_read_json(p$final_decision)
  if (!identical(verification$decision, "PASS") ||
      length(unlist(verification$checks)) != 22L ||
      !all(as.logical(unlist(verification$checks))) ||
      as.integer(verification$runtime_rows) != 9L ||
      !identical(decision$decision,
                 "PROMOTION_CANDIDATES_READY_FOR_INTEGRATION") ||
      as.integer(decision$promotion_eligible_metrics) != 2L) {
    stop("The V2 runtime is not a complete promotable closeout.", call. = FALSE)
  }
  parent <- ffv2_read_csv(p$point_interface)
  roles <- ffv2_read_csv(p$interval_roles)
  ledger <- ffv2_read_csv(p$final_metric_ledger)
  points <- ffv2_read_csv(p$confirmation_points)
  intervals <- ffv2_read_csv(p$confirmation_intervals)
  profile <- ffv2_read_csv(p$candidate_profiles)
  runtime <- ffv2_read_csv(p$confirmation_runtime)
  if (nrow(parent) != 72L || nrow(roles) != 216L ||
      nrow(runtime) != 9L || any(runtime$status != "SUCCESS") ||
      any(runtime$binary_payloads_remaining != 0L)) {
    stop("The parent or runtime row contract is broken.", call. = FALSE)
  }
  promoted <- ledger[
    ledger$candidate_id == idolp_v2_candidate_id & ledger$promotion_eligible,
    , drop = FALSE
  ]
  expected_metrics <- c(
    "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
  )
  if (nrow(promoted) != 2L || !setequal(promoted$metric, expected_metrics)) {
    stop("The V2 closeout does not select exactly two forecast metrics.",
         call. = FALSE)
  }
  chain_points <- points[points$candidate_id == idolp_v2_candidate_id,
                         , drop = FALSE]
  chain_points <- chain_points[order(chain_points$chain_id), , drop = FALSE]
  profile <- profile[profile$candidate_id == idolp_v2_candidate_id,
                     , drop = FALSE]
  if (nrow(chain_points) != 3L || !identical(chain_points$chain_id, 1:3) ||
      any(chain_points$status != "SUCCESS") || nrow(profile) != 1L) {
    stop("The selected candidate is not backed by three complete chains.",
         call. = FALSE)
  }
  plan <- ffv2_read_csv(p$confirmation_plan)
  jobs <- plan[plan$candidate_id == idolp_v2_candidate_id, , drop = FALSE]
  jobs <- jobs[order(jobs$chain_id), , drop = FALSE]
  if (nrow(jobs) != 3L || !identical(jobs$chain_id, 1:3)) {
    stop("The confirmation plan does not contain the three winner chains.",
         call. = FALSE)
  }
  job_roots <- file.path(p$result, "jobs", jobs$job_id)
  config_paths <- jobs$config_path
  draw_paths <- file.path(job_roots, "tables", "metric_draws.csv.gz")
  status_paths <- file.path(job_roots, "job_status.json")
  signoff_paths <- file.path(job_roots, "signoff_summary.csv")
  required <- c(config_paths, draw_paths, status_paths, signoff_paths)
  if (!all(file.exists(required))) stop("Winner source evidence is incomplete.", call. = FALSE)
  statuses <- lapply(status_paths, idolp_v2_read_json)
  signoffs <- do.call(rbind, lapply(signoff_paths, ffv2_read_csv))
  draws_by_chain <- lapply(draw_paths, function(path) {
    ffv2_read_csv(gzfile(path))
  })
  for (i in seq_along(draws_by_chain)) {
    draws <- draws_by_chain[[i]]
    status <- statuses[[i]]
    expected_draw_hash <- unname(
      status$diagnostic_artifact_hashes[["metric_draws.csv.gz"]]
    )
    if (nrow(draws) != 200L || any(draws$chain_id != i) ||
        anyDuplicated(draws[c("chain_id", "draw_id")]) ||
        !all(vapply(draws[c("fit_rmse", "forecast_mae",
                            "forecast_check_loss")],
                    function(x) all(is.finite(x)), logical(1L))) ||
        !identical(ffv2_file_sha256(config_paths[[i]]), status$config_sha256) ||
        !identical(ffv2_file_sha256(draw_paths[[i]]), expected_draw_hash) ||
        !identical(status$status, "SUCCESS") ||
        as.integer(status$binary_payloads_remaining) != 0L) {
      stop(sprintf("Winner chain %d violates the evidence contract.", i),
           call. = FALSE)
    }
  }
  all_draws <- do.call(rbind, draws_by_chain)
  if (anyDuplicated(all_draws[c("chain_id", "draw_id")]) ||
      !identical(sort(unique(all_draws$chain_id)), 1:3) ||
      nrow(signoffs) != 3L || !all(signoffs$comparison_eligible)) {
    stop("Winner chain pooling or signoff identity is invalid.", call. = FALSE)
  }
  for (name in names(idolp_v2_replay_hashes)) {
    path <- switch(
      name,
      materialization_manifest = p$replay_materialization_manifest,
      replay_plan = p$replay_plan,
      source_provenance = p$replay_source_provenance,
      replay_decision = p$replay_decision,
      closeout_manifest = p$replay_closeout_manifest
    )
    idolp_v2_assert_hash(
      path, idolp_v2_replay_hashes[[name]], paste("interval replay", name)
    )
  }
  idolp_v2_verify_ledger(p$replay_closeout, p$replay_closeout_manifest)
  replay_decision <- idolp_v2_read_json(p$replay_decision)
  replay_runtime <- ffv2_read_csv(p$replay_runtime)
  replay_plan <- ffv2_read_csv(p$replay_plan)
  replay_plan <- replay_plan[order(replay_plan$chain_id), , drop = FALSE]
  if (!identical(replay_decision$status, "PASS") ||
      !identical(
        replay_decision$interval_precision_decision,
        "PASS_USE_RETAINED_3000_DRAWS"
      ) || as.integer(replay_decision$total_metric_draws) !=
        idolp_v2_replay_total_draws || nrow(replay_runtime) != 3L ||
      any(replay_runtime$status != "SUCCESS") ||
      any(!replay_runtime$all_checks_pass) || nrow(replay_plan) != 3L ||
      !identical(as.integer(replay_plan$chain_id), 1:3) ||
      any(replay_plan$expected_metric_draws !=
            idolp_v2_replay_draws_per_chain)) {
    stop("The targeted interval replay did not pass its frozen contract.",
         call. = FALSE)
  }
  replay_job_roots <- file.path(
    p$replay_result, "jobs", replay_plan$job_id
  )
  replay_config_paths <- replay_plan$config_path
  replay_draw_paths <- file.path(
    replay_job_roots, "tables", "metric_draws.csv.gz"
  )
  replay_status_paths <- file.path(replay_job_roots, "job_status.json")
  replay_signoff_paths <- file.path(replay_job_roots, "signoff_summary.csv")
  replay_required <- c(
    replay_config_paths, replay_draw_paths, replay_status_paths,
    replay_signoff_paths
  )
  if (!all(file.exists(replay_required))) {
    stop("The interval replay source evidence is incomplete.", call. = FALSE)
  }
  replay_statuses <- lapply(replay_status_paths, idolp_v2_read_json)
  replay_signoffs <- do.call(rbind, lapply(replay_signoff_paths, ffv2_read_csv))
  replay_draws_by_chain <- lapply(replay_draw_paths, function(path) {
    ffv2_read_csv(gzfile(path))
  })
  for (i in seq_along(replay_draws_by_chain)) {
    replay_draws <- replay_draws_by_chain[[i]]
    replay_status <- replay_statuses[[i]]
    expected_draw_hash <- unname(
      replay_status$diagnostic_artifact_hashes[["metric_draws.csv.gz"]]
    )
    if (nrow(replay_draws) != idolp_v2_replay_draws_per_chain ||
        any(replay_draws$chain_id != i) ||
        anyDuplicated(replay_draws[c("chain_id", "draw_id")]) ||
        !all(vapply(
          replay_draws[c("fit_rmse", "forecast_mae", "forecast_check_loss")],
          function(x) all(is.finite(x)), logical(1L)
        )) ||
        !identical(
          ffv2_file_sha256(replay_config_paths[[i]]),
          replay_status$config_sha256
        ) ||
        !identical(
          ffv2_file_sha256(replay_draw_paths[[i]]), expected_draw_hash
        ) || !identical(replay_status$status, "SUCCESS") ||
        as.integer(replay_status$binary_payloads_remaining) != 0L) {
      stop(sprintf("Interval replay chain %d violates its contract.", i),
           call. = FALSE)
    }
  }
  replay_draws <- do.call(rbind, replay_draws_by_chain)
  if (nrow(replay_draws) != idolp_v2_replay_total_draws ||
      anyDuplicated(replay_draws[c("chain_id", "draw_id")]) ||
      !identical(sort(unique(replay_draws$chain_id)), 1:3) ||
      nrow(replay_signoffs) != 3L) {
    stop("The interval replay pooling identity is invalid.", call. = FALSE)
  }
  binary <- list.files(
    c(p$result, p$replay_result), pattern = "[.](rds|rda|RData)$",
    recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  if (length(binary)) stop("Unexpected retained fitted-model payloads found.", call. = FALSE)
  list(
    paths = p, git = git, closeout_manifest = closeout_manifest,
    parent = parent, roles = roles, ledger = ledger, promoted = promoted,
    chain_points = chain_points, chain_intervals = intervals[
      intervals$candidate_id == idolp_v2_candidate_id, , drop = FALSE
    ],
    profile = profile, jobs = jobs, job_roots = job_roots,
    config_paths = config_paths, draw_paths = draw_paths,
    status_paths = status_paths, signoff_paths = signoff_paths,
    statuses = statuses, signoffs = signoffs,
    draws_by_chain = draws_by_chain, draws = all_draws,
    replay_decision = replay_decision, replay_runtime = replay_runtime,
    replay_plan = replay_plan, replay_job_roots = replay_job_roots,
    replay_config_paths = replay_config_paths,
    replay_draw_paths = replay_draw_paths,
    replay_status_paths = replay_status_paths,
    replay_signoff_paths = replay_signoff_paths,
    replay_statuses = replay_statuses, replay_signoffs = replay_signoffs,
    interval_draws_by_chain = replay_draws_by_chain,
    interval_draws = replay_draws
  )
}

idolp_v2_pooled_intervals <- function(draws) {
  map <- c(
    fit = "fit_rmse",
    forecast_mae = "forecast_mae",
    forecast_check = "forecast_check_loss"
  )
  do.call(rbind, lapply(names(map), function(role) {
    values <- as.numeric(draws[[map[[role]]]])
    qs <- stats::quantile(
      values, c(0.025, 0.5, 0.975), names = FALSE,
      type = idolp_v2_quantile_type
    )
    data.frame(
      metric_role = role,
      metric_name = switch(
        role, fit = "fit_qtrue_rmse",
        forecast_mae = "forecast_qtrue_mae_H1000",
        forecast_check = "forecast_check_loss_H1000"
      ),
      pooled_metric = map[[role]], posterior_mean = mean(values),
      posterior_sd = stats::sd(values), cri_lower = qs[[1L]],
      posterior_median = qs[[2L]], cri_upper = qs[[3L]],
      posterior_mean_inside_cri = mean(values) >= qs[[1L]] &&
        mean(values) <= qs[[3L]], n_draws = length(values),
      n_chains = length(unique(draws$chain_id)),
      quantile_type = idolp_v2_quantile_type,
      estimator_id = idolp_v2_estimator_id,
      stringsAsFactors = FALSE
    )
  }))
}

idolp_v2_circular_block_sample <- function(x, block_length) {
  n <- nrow(x)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  index <- unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)[seq_len(n)]
  x[index, , drop = FALSE]
}

idolp_v2_interval_sensitivity <- function(draws_by_chain, old_roles) {
  draws <- do.call(rbind, draws_by_chain)
  pooled <- idolp_v2_pooled_intervals(draws)
  target_roles <- c("forecast_mae", "forecast_check")
  pooled_target <- pooled[match(target_roles, pooled$metric_role), , drop = FALSE]
  loo <- do.call(rbind, lapply(seq_along(draws_by_chain), function(excluded) {
    kept <- do.call(rbind, draws_by_chain[-excluded])
    out <- idolp_v2_pooled_intervals(kept)
    out <- out[match(target_roles, out$metric_role), , drop = FALSE]
    out$excluded_chain <- excluded
    out
  }))
  old <- old_roles[
    old_roles$inference == "mcmc" &
      old_roles$model_variant == "qdesn_al_rhs_ns" &
      old_roles$family == "normal" & abs(old_roles$tau - 0.05) < 1e-12 &
      old_roles$metric_role %in% target_roles,
    , drop = FALSE
  ]
  old <- old[match(target_roles, old$metric_role), , drop = FALSE]
  old_mean <- setNames(old$posterior_mean, old$metric_role)
  old_upper <- setNames(old$cri_upper, old$metric_role)
  old_lower <- setNames(old$cri_lower, old$metric_role)
  old_width <- old_upper - old_lower
  old_direction <- data.frame(
    metric_role = target_roles,
    old_posterior_mean = unname(old_mean[target_roles]),
    new_posterior_mean = pooled_target$posterior_mean,
    posterior_mean_delta = pooled_target$posterior_mean -
      unname(old_mean[target_roles]),
    favorable_direction = pooled_target$posterior_mean <
      unname(old_mean[target_roles]),
    old_interval_width = unname(old_width[target_roles]),
    new_interval_width = pooled_target$cri_upper - pooled_target$cri_lower,
    stringsAsFactors = FALSE
  )
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    if (is.null(old_seed)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    } else assign(".Random.seed", old_seed, envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(idolp_v2_bootstrap_seed)
  bootstrap <- do.call(rbind, lapply(
    seq_len(idolp_v2_bootstrap_replicates), function(replicate_id) {
      sampled <- do.call(rbind, lapply(draws_by_chain, function(one) {
        idolp_v2_circular_block_sample(one, idolp_v2_bootstrap_block_length)
      }))
      summary <- idolp_v2_pooled_intervals(sampled)
      summary <- summary[match(target_roles, summary$metric_role), , drop = FALSE]
      data.frame(
        replicate_id = replicate_id, metric_role = summary$metric_role,
        posterior_mean = summary$posterior_mean,
        cri_lower = summary$cri_lower, cri_upper = summary$cri_upper,
        stringsAsFactors = FALSE
      )
    }
  ))
  bootstrap_summary <- do.call(rbind, lapply(target_roles, function(role) {
    block <- bootstrap[bootstrap$metric_role == role, , drop = FALSE]
    data.frame(
      metric_role = role,
      posterior_mean_mcse = stats::sd(block$posterior_mean),
      lower_endpoint_mcse = stats::sd(block$cri_lower),
      upper_endpoint_mcse = stats::sd(block$cri_upper),
      lower_endpoint_boot_q025 = stats::quantile(
        block$cri_lower, 0.025, names = FALSE, type = idolp_v2_quantile_type
      ),
      lower_endpoint_boot_q975 = stats::quantile(
        block$cri_lower, 0.975, names = FALSE, type = idolp_v2_quantile_type
      ),
      upper_endpoint_boot_q025 = stats::quantile(
        block$cri_upper, 0.025, names = FALSE, type = idolp_v2_quantile_type
      ),
      upper_endpoint_boot_q975 = stats::quantile(
        block$cri_upper, 0.975, names = FALSE, type = idolp_v2_quantile_type
      ),
      bootstrap_replicates = idolp_v2_bootstrap_replicates,
      block_length = idolp_v2_bootstrap_block_length,
      seed = idolp_v2_bootstrap_seed,
      stringsAsFactors = FALSE
    )
  }))
  checks <- do.call(rbind, lapply(target_roles, function(role) {
    p <- pooled_target[pooled_target$metric_role == role, , drop = FALSE]
    l <- loo[loo$metric_role == role, , drop = FALSE]
    b <- bootstrap_summary[bootstrap_summary$metric_role == role, , drop = FALSE]
    width <- p$cri_upper - p$cri_lower
    loo_mean <- max(abs(l$posterior_mean - p$posterior_mean)) /
      max(p$posterior_sd, .Machine$double.eps)
    loo_endpoint <- max(
      abs(l$cri_lower - p$cri_lower), abs(l$cri_upper - p$cri_upper)
    ) / max(width, .Machine$double.eps)
    bootstrap_endpoint <- max(
      b$lower_endpoint_mcse, b$upper_endpoint_mcse
    ) / max(width, .Machine$double.eps)
    direction <- old_direction$favorable_direction[
      old_direction$metric_role == role
    ]
    data.frame(
      metric_role = role,
      loo_max_mean_shift_in_pooled_sd = loo_mean,
      loo_mean_sd_limit = idolp_v2_loo_mean_sd_limit,
      loo_max_endpoint_shift_over_width = loo_endpoint,
      loo_endpoint_width_limit = idolp_v2_loo_endpoint_width_limit,
      bootstrap_max_endpoint_mcse_over_width = bootstrap_endpoint,
      bootstrap_endpoint_mcse_width_limit =
        idolp_v2_bootstrap_endpoint_mcse_width_limit,
      favorable_posterior_mean_direction = direction,
      pass = loo_mean <= idolp_v2_loo_mean_sd_limit &&
        loo_endpoint <= idolp_v2_loo_endpoint_width_limit &&
        bootstrap_endpoint <= idolp_v2_bootstrap_endpoint_mcse_width_limit &&
        direction,
      stringsAsFactors = FALSE
    )
  }))
  list(
    pooled = pooled, leave_one_chain_out = loo,
    bootstrap_draws = bootstrap, bootstrap_summary = bootstrap_summary,
    direction = old_direction, checks = checks,
    decision = if (all(checks$pass)) {
      sprintf("PASS_USE_RETAINED_%d_DRAWS", nrow(draws))
    } else "STOP_INTERVAL_REPLAY_REQUIRED"
  )
}

idolp_v2_origin_lead_comparison <- function(evidence) {
  control <- ffv2_read_csv(evidence$paths$confirmation_points)
  control <- control[
    control$target_cell_id == idolp_v2_target_cell_id &
      control$profile_role == "C0_parent", , drop = FALSE
  ]
  control <- control[order(control$chain_id), , drop = FALSE]
  if (nrow(control) != 3L || !identical(control$chain_id, 1:3)) {
    stop("Matched confirmation controls are incomplete.", call. = FALSE)
  }
  summarize <- function(path, group) {
    x <- ffv2_read_csv(path)
    if ("split_role" %in% names(x)) x <- x[x$split_role == "forecast", ]
    stats::aggregate(
      x[c("abs_q_error", "pinball_tau")],
      list(index = x[[group]]), mean
    )
  }
  rows <- list()
  for (chain in 1:3) {
    candidate_job <- evidence$chain_points$job_id[
      evidence$chain_points$chain_id == chain
    ]
    control_job <- control$job_id[control$chain_id == chain]
    candidate_path <- file.path(
      evidence$paths$result, "jobs", candidate_job, "tables",
      "forecast_rolling_origin_paths.csv"
    )
    control_path <- file.path(
      evidence$paths$result, "jobs", control_job, "tables",
      "forecast_rolling_origin_paths.csv"
    )
    for (spec in list(
      c("lead", "forecast_lead"),
      c("origin", "forecast_origin_source_index")
    )) {
      candidate <- summarize(candidate_path, spec[[2L]])
      control_data <- summarize(control_path, spec[[2L]])
      names(candidate)[2:3] <- c("candidate_mae", "candidate_check")
      names(control_data)[2:3] <- c("control_mae", "control_check")
      joined <- merge(candidate, control_data, by = "index", sort = TRUE)
      joined$dimension <- spec[[1L]]
      joined$chain_id <- chain
      joined$mae_delta <- joined$candidate_mae - joined$control_mae
      joined$check_delta <- joined$candidate_check - joined$control_check
      rows[[length(rows) + 1L]] <- joined
    }
  }
  out <- do.call(rbind, rows)
  out[, c("dimension", "chain_id", "index", "candidate_mae", "control_mae",
          "mae_delta", "candidate_check", "control_check", "check_delta")]
}

idolp_v2_file_ledger <- function(paths, root) {
  paths <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  prefix <- paste0(root, "/")
  if (any(!startsWith(paths, prefix))) stop("Manifest path escapes output root.")
  data.frame(
    relative_path = substring(paths, nchar(prefix) + 1L),
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, ffv2_file_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
}

idolp_v2_verify_ledger <- function(root, ledger_path) {
  ledger <- ffv2_read_csv(ledger_path)
  paths <- file.path(root, ledger$relative_path)
  ok <- file.exists(paths) &
    as.numeric(file.info(paths)$size) == as.numeric(ledger$bytes) &
    vapply(paths, ffv2_file_sha256, character(1L)) == ledger$sha256
  if (!all(ok)) stop("A materialized artifact failed its ledger hash.", call. = FALSE)
  invisible(ledger)
}

idolp_v2_write_audit <- function(evidence, sensitivity) {
  repo <- ffv2_repo_root()
  root <- evidence$paths$audit
  idolp_v2_assert_empty(root)
  ffv2_ensure_dir(root)
  ffv2_ensure_dir(file.path(root, "requests"))
  ffv2_ensure_dir(file.path(root, "metric_draws"))
  source_rows <- list()
  for (i in 1:3) {
    point_request <- idolp_v2_portabilize(
      idolp_v2_read_json(evidence$config_paths[[i]]), repo
    )
    point_request_path <- file.path(
      root, "requests", sprintf("point_confirmation_chain_%02d.json", i)
    )
    ffv2_write_json(point_request, point_request_path)
    interval_request <- idolp_v2_portabilize(
      idolp_v2_read_json(evidence$replay_config_paths[[i]]), repo
    )
    interval_request_path <- file.path(
      root, "requests", sprintf("interval_replay_chain_%02d.json", i)
    )
    ffv2_write_json(interval_request, interval_request_path)
    draw_path <- file.path(
      root, "metric_draws",
      sprintf("interval_replay_chain_%02d_metric_draws.csv.gz", i)
    )
    idolp_v2_copy_verified(evidence$replay_draw_paths[[i]], draw_path)
    source_rows[[length(source_rows) + 1L]] <- data.frame(
      source_role = c(
        "point_confirmation_request", "interval_replay_request",
        "interval_metric_draws"
      ),
      chain_id = i,
      source_path = c(
        idolp_v2_repo_relative(evidence$config_paths[[i]], repo),
        idolp_v2_repo_relative(evidence$replay_config_paths[[i]], repo),
        idolp_v2_repo_relative(evidence$replay_draw_paths[[i]], repo)
      ),
      source_sha256 = c(
        ffv2_file_sha256(evidence$config_paths[[i]]),
        ffv2_file_sha256(evidence$replay_config_paths[[i]]),
        ffv2_file_sha256(evidence$replay_draw_paths[[i]])
      ),
      frozen_path = c(
        idolp_v2_repo_relative(point_request_path, repo),
        idolp_v2_repo_relative(interval_request_path, repo),
        idolp_v2_repo_relative(draw_path, repo)
      ),
      frozen_sha256 = c(
        ffv2_file_sha256(point_request_path),
        ffv2_file_sha256(interval_request_path),
        ffv2_file_sha256(draw_path)
      ),
      stringsAsFactors = FALSE
    )
  }
  points <- evidence$chain_points
  points$metric_interval_summary_path <- NULL
  points$transform_diagnostics_path <- NULL
  points$common_shift_effects_path <- NULL
  points$origin_horizon_reconstruction_path <- NULL
  points$design_conditioning_path <- NULL
  ffv2_write_csv(points, file.path(root, "confirmation_chain_point_metrics.csv"))
  ffv2_write_csv(
    evidence$chain_intervals,
    file.path(root, "confirmation_chain_metric_intervals.csv")
  )
  ffv2_write_csv(evidence$signoffs, file.path(root, "confirmation_signoffs.csv"))
  ffv2_write_csv(
    evidence$replay_signoffs, file.path(root, "interval_replay_signoffs.csv")
  )
  ffv2_write_csv(
    evidence$replay_runtime,
    file.path(root, "interval_replay_runtime_verification.csv")
  )
  ffv2_write_csv(evidence$profile, file.path(root, "winner_specification.csv"))
  ffv2_write_csv(sensitivity$pooled, file.path(root, "pooled_metric_intervals.csv"))
  ffv2_write_csv(
    sensitivity$leave_one_chain_out,
    file.path(root, "interval_precision_leave_one_chain_out.csv")
  )
  ffv2_write_csv(
    sensitivity$bootstrap_summary,
    file.path(root, "interval_precision_block_bootstrap.csv")
  )
  ffv2_write_csv(
    sensitivity$direction,
    file.path(root, "interval_direction_comparison.csv")
  )
  ffv2_write_csv(
    sensitivity$checks, file.path(root, "interval_precision_checks.csv")
  )
  ffv2_write_csv(
    idolp_v2_origin_lead_comparison(evidence),
    file.path(root, "matched_origin_lead_comparison.csv")
  )
  for (spec in list(
    c("confirmation_transform", "confirmation_transform_diagnostics.csv"),
    c("confirmation_conditioning", "confirmation_conditioning_diagnostics.csv")
  )) {
    x <- ffv2_read_csv(evidence$paths[[spec[[1L]]]])
    x <- x[x$candidate_id == idolp_v2_candidate_id, , drop = FALSE]
    ffv2_write_csv(x, file.path(root, spec[[2L]]))
  }
  common_shift <- do.call(rbind, lapply(seq_len(3L), function(i) {
    path <- file.path(
      evidence$replay_job_roots[[i]], "tables",
      "common_shift_intervention_effects.csv"
    )
    x <- ffv2_read_csv(path)
    x$chain_id <- i
    x
  }))
  ffv2_write_csv(
    common_shift, file.path(root, "common_shift_intervention_effects.csv")
  )
  reconstruction <- do.call(rbind, lapply(seq_len(3L), function(i) {
    path <- file.path(
      evidence$replay_job_roots[[i]], "tables",
      "origin_horizon_reconstruction_audit.csv"
    )
    x <- ffv2_read_csv(path)
    x$chain_id <- i
    x
  }))
  ffv2_write_csv(
    reconstruction, file.path(root, "origin_horizon_reconstruction_audit.csv")
  )
  source_registry <- ffv2_read_csv(evidence$paths$source_registry)
  window_registry <- ffv2_read_csv(evidence$paths$window_registry)
  ffv2_stop_stale_paths(source_registry)
  ffv2_stop_stale_paths(window_registry)
  source_registry[] <- lapply(source_registry, function(column) {
    if (is.character(column)) idolp_v2_portabilize(column, repo) else column
  })
  window_registry[] <- lapply(window_registry, function(column) {
    if (is.character(column)) idolp_v2_portabilize(column, repo) else column
  })
  ffv2_write_csv(source_registry, file.path(root, "canonical_source_registry.csv"))
  ffv2_write_csv(window_registry, file.path(root, "source_window_registry.csv"))
  ffv2_write_csv(
    do.call(rbind, source_rows), file.path(root, "source_provenance.csv")
  )
  ffv2_write_json(
    idolp_v2_portabilize(idolp_v2_read_json(evidence$paths$final_decision), repo),
    file.path(root, "runtime_final_decision.json")
  )
  ffv2_write_json(
    idolp_v2_portabilize(evidence$replay_decision, repo),
    file.path(root, "interval_replay_decision.json")
  )
  ffv2_write_csv(
    evidence$promoted, file.path(root, "runtime_metric_promotion_ledger.csv")
  )
  readme <- c(
    "# Independent location-orthogonalized V2 portable audit packet",
    "",
    sprintf("- Run tag: `%s`", idolp_v2_run_tag),
    sprintf("- Scientific commit: `%s`", idolp_v2_scientific_commit),
    sprintf("- Winner: `%s`", idolp_v2_candidate_id),
    "- Target: MCMC Q-DESN AL-RHS, Gaussian, p=0.05",
    "- Confirmation: 3/3 full-budget chains, 0 execution failures",
    "- Promotion: forecast MAE and forecast check loss only",
    "- Fit RMSE: retained from v9",
    sprintf("- Interval decision: `%s`", sensitivity$decision),
    "- Retained interval draws: 3,000, balanced as 1,000 per chain",
    sprintf("- Interval replay: `%s`", idolp_v2_replay_run_tag),
    "- Fitted-model binary payloads: 0",
    "- Article publication owner: ARTICLE QDESN INTEGRATION",
    "",
    "The metric intervals are posterior distributions of draw-wise aggregate",
    "criteria. They are not repeated-simulation confidence intervals. The",
    "primary table point scores remain scores of the canonical posterior point",
    "paths and therefore need not equal the draw-wise posterior means."
  )
  writeLines(readme, file.path(root, "README.md"), useBytes = TRUE)
  evidence_files <- list.files(root, recursive = TRUE, full.names = TRUE)
  evidence_files <- evidence_files[!grepl(
    "(^|/)(artifact_manifest[.]csv|audit_manifest[.]json)$", evidence_files
  )]
  artifact_manifest <- idolp_v2_file_ledger(evidence_files, root)
  artifact_manifest <- artifact_manifest[order(artifact_manifest$relative_path), ]
  artifact_path <- ffv2_write_csv(
    artifact_manifest, file.path(root, "artifact_manifest.csv")
  )
  manifest <- list(
    schema_version = idolp_v2_schema,
    audit_id = idolp_v2_audit_id,
    status = "PORTABLE_EVIDENCE_PASS",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    run_id = idolp_v2_run_id, run_tag = idolp_v2_run_tag,
    scientific_commit = idolp_v2_scientific_commit,
    winner_candidate_id = idolp_v2_candidate_id,
    confirmation_chains = 3L, metric_draws = idolp_v2_replay_total_draws,
    interval_replay_run_tag = idolp_v2_replay_run_tag,
    interval_decision = sensitivity$decision,
    evidence_files = nrow(artifact_manifest),
    evidence_bytes = sum(artifact_manifest$bytes),
    artifact_manifest = "artifact_manifest.csv",
    artifact_manifest_sha256 = ffv2_file_sha256(artifact_path),
    binary_payload_count = 0L
  )
  ffv2_write_json(manifest, file.path(root, "audit_manifest.json"))
  idolp_v2_verify_ledger(root, artifact_path)
  invisible(root)
}

idolp_v2_point_source_row <- function(interface) {
  interface$inference == "mcmc" &
    interface$model_variant == "qdesn_al_rhs_ns" &
    interface$family == "normal" & abs(interface$tau - 0.05) < 1e-12
}

idolp_v2_write_point_authority <- function(evidence) {
  repo <- ffv2_repo_root()
  root <- evidence$paths$point
  audit <- evidence$paths$audit
  idolp_v2_assert_empty(root)
  ffv2_ensure_dir(root)
  parent <- evidence$parent
  interface <- parent
  interface$article_interface_id <- idolp_v2_point_id
  target <- which(idolp_v2_point_source_row(interface))
  if (length(target) != 1L) stop("Point target row is not unique.", call. = FALSE)
  means <- c(
    forecast_qtrue_mae_H1000 = mean(evidence$chain_points$forecast_qtrue_mae_H1000),
    forecast_check_loss_H1000 = mean(
      evidence$chain_points$forecast_check_loss_H1000
    )
  )
  old <- unlist(interface[target, names(means), drop = TRUE])
  if (any(!is.finite(means)) || any(means >= old - idolp_v2_tolerance)) {
    stop("The selected point metrics are not strict finite gains.", call. = FALSE)
  }
  chain_evidence_path <- file.path(
    audit, "confirmation_chain_point_metrics.csv"
  )
  chain_evidence_relative <- idolp_v2_repo_relative(chain_evidence_path, repo)
  chain_evidence_hash <- ffv2_file_sha256(chain_evidence_path)
  grade <- idolp_v2_worst_grade(evidence$signoffs$signoff_grade)
  interface[target, "forecast_qtrue_mae_H1000"] <- means[[1L]]
  interface[target, "forecast_check_loss_H1000"] <- means[[2L]]
  for (prefix in c("forecast_mae", "forecast_check")) {
    interface[target, paste0(prefix, "_source_candidate_id")] <-
      idolp_v2_candidate_id
    interface[target, paste0(prefix, "_source_run_tag")] <- idolp_v2_run_tag
    interface[target, paste0(prefix, "_source_signoff_grade")] <- grade
    interface[target, paste0(prefix, "_source_status")] <- "SUCCESS"
    interface[target, paste0(prefix, "_source_path")] <- chain_evidence_relative
    interface[target, paste0(prefix, "_source_sha256")] <- chain_evidence_hash
  }
  interface[target, "status"] <- "SUCCESS"
  interface[target, "signoff_grade"] <- grade
  interface[target, "metric_source_mixed"] <- TRUE
  interface[target, "source_promotion_id"] <- idolp_v2_point_id
  interface[target, "promotion_validation_branch"] <- idolp_v2_branch
  interface[target, "promotion_validation_commit"] <- evidence$git$head
  interface[target, "metric_estimator_contract"] <- idolp_v2_point_estimator
  interface[target, "confirmation_chain_count"] <- 3L
  interface[target, "confirmation_execution_commit"] <- idolp_v2_scientific_commit
  interface[target, "confirmation_closeout_commit"] <- evidence$git$head
  interface[target, "confirmation_state"] <-
    "CONFIRMED_LOCATION_ORTHOGONALIZED_V2_METRIC_SPECIFIC"
  interface_path <- ffv2_write_csv(
    interface, file.path(root, paste0(idolp_v2_point_id, "_interface.csv"))
  )
  decision <- data.frame(
    inference = "mcmc", model_variant = "qdesn_al_rhs_ns",
    family = "normal", tau = 0.05, metric = names(means),
    candidate_id = idolp_v2_candidate_id,
    parent_value = as.numeric(old), promoted_value = as.numeric(means),
    delta = as.numeric(means - old),
    relative_gain_pct = 100 * as.numeric((old - means) / old),
    strict_improvement = as.numeric(means) < as.numeric(old) - idolp_v2_tolerance,
    diagnostics_used_as_promotion_gate = FALSE,
    source_signoff_grade = grade,
    promotion_decision = "PROMOTE",
    stringsAsFactors = FALSE
  )
  decision_path <- ffv2_write_csv(
    decision, file.path(root, "promotion_decision_ledger.csv")
  )
  article_delta <- decision[c(
    "inference", "model_variant", "family", "tau", "metric",
    "parent_value", "promoted_value", "delta", "relative_gain_pct"
  )]
  article_delta$article_action <-
    "REPLACE_TARGET_METRIC_RETAIN_FIT_AND_ALL_OTHER_VALUES"
  ffv2_write_csv(article_delta, file.path(root, "article_delta_from_v9.csv"))
  rollback <- decision[c(
    "inference", "model_variant", "family", "tau", "metric"
  )]
  rollback$rollback_parent_id <- idolp_v2_point_parent_id
  rollback$rollback_value <- decision$parent_value
  rollback$promoted_value <- decision$promoted_value
  rollback$rollback_action <- "RESTORE_PARENT_BY_SHA256"
  ffv2_write_csv(rollback, file.path(root, "rollback_ledger.csv"))
  ffv2_write_csv(
    evidence$profile, file.path(root, "promoted_candidate_specification.csv")
  )
  ffv2_write_csv(
    evidence$chain_points[, setdiff(
      names(evidence$chain_points),
      c("metric_interval_summary_path", "transform_diagnostics_path",
        "common_shift_effects_path", "origin_horizon_reconstruction_path",
        "design_conditioning_path")
    ), drop = FALSE],
    file.path(root, "confirmation_chain_evidence.csv")
  )
  gaps <- ffv2_read_csv(evidence$paths$point_gap_ledger)
  gaps$authority_id <- idolp_v2_point_id
  for (i in seq_len(nrow(decision))) {
    row <- gaps$model_variant == decision$model_variant[[i]] &
      gaps$family == decision$family[[i]] &
      abs(gaps$tau - decision$tau[[i]]) < 1e-12 &
      gaps$metric == decision$metric[[i]]
    if (sum(row) != 1L) stop("Remaining-gap target is not unique.", call. = FALSE)
    gaps$value[row] <- decision$promoted_value[[i]]
    gaps$ratio_to_best_dqlm_exdqlm[row] <-
      gaps$value[row] / gaps$best_dqlm_exdqlm_value[row]
    gaps$relative_gap_pct[row] <-
      100 * (gaps$ratio_to_best_dqlm_exdqlm[row] - 1)
  }
  ffv2_write_csv(gaps, file.path(root, "remaining_gap_ledger.csv"))
  parent_sources <- ffv2_read_csv(evidence$paths$point_source_ledger)
  new_sources <- data.frame(
    source_id = c(
      "parent_v9_interface", "parent_v9_manifest", "v2_audit_manifest",
      "v2_confirmation_chain_points", "v2_pooled_metric_intervals"
    ),
    path = c(
      idolp_v2_repo_relative(evidence$paths$point_interface, repo),
      idolp_v2_repo_relative(evidence$paths$point_manifest, repo),
      idolp_v2_repo_relative(file.path(audit, "audit_manifest.json"), repo),
      chain_evidence_relative,
      idolp_v2_repo_relative(file.path(audit, "pooled_metric_intervals.csv"), repo)
    ),
    sha256 = vapply(c(
      evidence$paths$point_interface, evidence$paths$point_manifest,
      file.path(audit, "audit_manifest.json"), chain_evidence_path,
      file.path(audit, "pooled_metric_intervals.csv")
    ), ffv2_file_sha256, character(1L)),
    role = c(
      "parent_authority", "parent_authority", "portable_audit_control",
      "promoted_point_source", "promoted_interval_source"
    ),
    stringsAsFactors = FALSE
  )
  ffv2_write_csv(rbind(parent_sources, new_sources),
                 file.path(root, "source_ledger.csv"))
  readme <- c(
    "# Independent Q-DESN location-orthogonalized point authority v11",
    "",
    sprintf("Parent: `%s`.", idolp_v2_point_parent_id),
    sprintf("Winner: `%s`.", idolp_v2_candidate_id),
    "",
    "This 72-row authority changes exactly two forecast metrics for MCMC",
    "Q-DESN AL-RHS, Gaussian, p=0.05. Fit RMSE and every non-target metric",
    "remain inherited. Diagnostic WARN status is disclosed and is not used as",
    "a metric-promotion veto. Article publication is coordinator-owned."
  )
  writeLines(readme, file.path(root, "README.md"), useBytes = TRUE)
  manifest <- list(
    schema_version = idolp_v2_schema,
    promotion_id = idolp_v2_point_id,
    status = "READY_FOR_INTEGRATION",
    scientific_decision = "PROMOTE_TWO_CASE_SPECIFIC_FORECAST_METRICS",
    parent_promotion_id = idolp_v2_point_parent_id,
    parent_interface_sha256 = idolp_v2_parent_hashes[["point_interface"]],
    validation_branch = idolp_v2_branch,
    scientific_execution_commit = idolp_v2_scientific_commit,
    promotion_implementation_commit = evidence$git$head,
    run_id = idolp_v2_run_id, run_tag = idolp_v2_run_tag,
    campaign_jobs = 52L, campaign_failures = 0L,
    confirmation_chains = 3L,
    promoted_metric_roles = 2L,
    fit_metric_policy = "retain_v9_fit_source",
    diagnostics_used_as_promotion_gate = FALSE,
    interface_rows = nrow(interface),
    article_interface_path = idolp_v2_repo_relative(interface_path, repo),
    article_interface_sha256 = ffv2_file_sha256(interface_path),
    promotion_decision_ledger_sha256 = ffv2_file_sha256(decision_path),
    portable_audit_id = idolp_v2_audit_id,
    binary_payload_count = 0L,
    article_update_status = "READY_FOR_COORDINATOR_NO_DIRECT_MAIN_WRITE"
  )
  manifest_path <- ffv2_write_json(
    manifest, file.path(root, paste0(idolp_v2_point_id, "_manifest.json"))
  )
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  files <- files[basename(files) != "output_file_manifest.csv"]
  output_manifest <- idolp_v2_file_ledger(files, repo)
  names(output_manifest)[names(output_manifest) == "relative_path"] <- "path"
  output_manifest <- output_manifest[order(output_manifest$path), ]
  ffv2_write_csv(output_manifest, file.path(root, "output_file_manifest.csv"))
  invisible(list(interface = interface, path = interface_path,
                 manifest_path = manifest_path, decision = decision))
}

idolp_v2_write_interval_authority <- function(evidence, sensitivity, point) {
  repo <- ffv2_repo_root()
  root <- evidence$paths$interval
  audit <- evidence$paths$audit
  idolp_v2_assert_empty(root)
  ffv2_ensure_dir(root)
  roles <- evidence$roles
  target <- roles$inference == "mcmc" &
    roles$model_variant == "qdesn_al_rhs_ns" & roles$family == "normal" &
    abs(roles$tau - 0.05) < 1e-12 &
    roles$metric_role %in% c("forecast_mae", "forecast_check")
  if (sum(target) != 2L) stop("Interval target roles are not unique.", call. = FALSE)
  pooled <- sensitivity$pooled[sensitivity$pooled$metric_role %in%
                                  c("forecast_mae", "forecast_check"), ]
  pooled <- pooled[match(roles$metric_role[target], pooled$metric_role), ]
  point_row <- point$interface[idolp_v2_point_source_row(point$interface), ]
  point_values <- c(
    forecast_mae = point_row$forecast_qtrue_mae_H1000,
    forecast_check = point_row$forecast_check_loss_H1000
  )
  source_path <- file.path(audit, "pooled_metric_intervals.csv")
  source_relative <- idolp_v2_repo_relative(source_path, repo)
  source_hash <- ffv2_file_sha256(source_path)
  roles$point_authority_id <- idolp_v2_point_id
  roles$point_delta_from_v11 <- NA_real_
  roles$point_ratio_to_v11 <- NA_real_
  roles[target, "authoritative_value"] <- unname(
    point_values[roles$metric_role[target]]
  )
  roles[target, "source_candidate_id"] <- idolp_v2_candidate_id
  roles[target, "source_run_tag"] <- idolp_v2_run_tag
  roles[target, "source_status"] <- "SUCCESS"
  roles[target, "source_signoff_grade"] <- "WARN"
  roles[target, "source_path"] <- source_relative
  roles[target, "source_sha256"] <- source_hash
  roles[target, "source_identity"] <- paste(
    "mcmc", "qdesn_al_rhs_ns", "normal", "0.05", idolp_v2_candidate_id,
    idolp_v2_run_tag, sep = "|"
  )
  roles[target, "replay_id"] <- "idolp_v2_winner_three_chain_pool"
  fields <- c(
    "pooled_metric", "posterior_mean", "posterior_sd", "cri_lower",
    "posterior_median", "cri_upper", "posterior_mean_inside_cri",
    "n_draws", "n_chains", "estimator_id"
  )
  for (field in fields) roles[target, field] <- pooled[[field]]
  roles[target, "diagnostic_grade"] <- "WARN"
  point_map <- list(
    fit = "fit_qtrue_rmse", forecast_mae = "forecast_qtrue_mae_H1000",
    forecast_check = "forecast_check_loss_H1000"
  )
  for (i in seq_len(nrow(roles))) {
    row <- point$interface[
      point$interface$inference == roles$inference[[i]] &
        point$interface$model_variant == roles$model_variant[[i]] &
        point$interface$family == roles$family[[i]] &
        abs(point$interface$tau - roles$tau[[i]]) < 1e-12,
      , drop = FALSE
    ]
    if (nrow(row) != 1L) stop("Interval role lacks a unique point authority.")
    value <- row[[point_map[[roles$metric_role[[i]]]]]][[1L]]
    roles$point_delta_from_v11[[i]] <- roles$posterior_mean[[i]] - value
    roles$point_ratio_to_v11[[i]] <- roles$posterior_mean[[i]] / value
  }
  roles_path <- ffv2_write_csv(
    roles, file.path(root, "plot_ready_metric_intervals.csv")
  )
  update <- roles[target, c(
    "inference", "model_variant", "family", "tau", "metric_role",
    "metric_name", "authoritative_value", "posterior_mean", "posterior_sd",
    "cri_lower", "posterior_median", "cri_upper", "n_draws", "n_chains",
    "estimator_id", "source_candidate_id", "source_run_tag",
    "source_signoff_grade", "source_path", "source_sha256"
  )]
  ffv2_write_csv(update, file.path(root, "interval_update_ledger.csv"))
  ffv2_write_csv(
    sensitivity$leave_one_chain_out,
    file.path(root, "interval_precision_leave_one_chain_out.csv")
  )
  ffv2_write_csv(
    sensitivity$bootstrap_summary,
    file.path(root, "interval_precision_block_bootstrap.csv")
  )
  ffv2_write_csv(
    sensitivity$checks, file.path(root, "interval_precision_checks.csv")
  )
  ffv2_write_csv(
    sensitivity$direction, file.path(root, "interval_direction_comparison.csv")
  )
  invariant_key <- paste(
    roles$inference, roles$model_variant, roles$family,
    sprintf("%.2f", roles$tau), roles$metric_role, sep = "|"
  )
  parent_key <- paste(
    evidence$roles$inference, evidence$roles$model_variant,
    evidence$roles$family, sprintf("%.2f", evidence$roles$tau),
    evidence$roles$metric_role, sep = "|"
  )
  parent_match <- match(invariant_key, parent_key)
  invariance <- data.frame(
    key = invariant_key,
    inherited_role = !target,
    parent_row = parent_match,
    posterior_mean_delta = roles$posterior_mean -
      evidence$roles$posterior_mean[parent_match],
    lower_delta = roles$cri_lower - evidence$roles$cri_lower[parent_match],
    upper_delta = roles$cri_upper - evidence$roles$cri_upper[parent_match],
    source_changed = roles$source_sha256 != evidence$roles$source_sha256[parent_match],
    stringsAsFactors = FALSE
  )
  ffv2_write_csv(invariance, file.path(root, "parent_invariance_ledger.csv"))
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_metric_interval_reporting_v1.R"
  ))
  plot_data <- imir_v1_prepare_plot_data(roles)
  figure_dir <- file.path(root, "article_assets", "figures",
                          "independent_simulation")
  ffv2_ensure_dir(figure_dir)
  figure_paths <- character()
  for (metric_role in c("forecast_mae", "forecast_check")) {
    plot <- imir_v1_plot_metric_intervals(plot_data, "mcmc", metric_role)
    pdf <- file.path(
      figure_dir, imir_v1_figure_filename("mcmc", metric_role, "pdf")
    )
    png <- file.path(
      figure_dir, imir_v1_figure_filename("mcmc", metric_role, "png")
    )
    imir_v1_save_plot(plot, pdf, png, width = 7.2, height = 6.6, dpi = 600L)
    figure_paths <- c(figure_paths, pdf, png)
  }
  article_manifest <- idolp_v2_file_ledger(figure_paths, root)
  article_manifest$article_destination <- sub(
    "^article_assets/", "", article_manifest$relative_path
  )
  ffv2_write_csv(article_manifest, file.path(root, "article_asset_manifest.csv"))
  decision <- list(
    schema_version = idolp_v2_schema,
    reporting_id = idolp_v2_interval_id,
    status = "READY_FOR_INTEGRATION",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    parent_reporting_id = idolp_v2_interval_parent_id,
    parent_roles_sha256 = idolp_v2_parent_hashes[["interval_roles"]],
    point_authority_id = idolp_v2_point_id,
    decision = "REPLACE_TWO_FORECAST_INTERVAL_ROLES",
    interval_precision_decision = sensitivity$decision,
    estimator_id = idolp_v2_estimator_id,
    quantile_type = idolp_v2_quantile_type,
    n_draws = idolp_v2_replay_total_draws, n_chains = 3L,
    updated_roles = 2L, inherited_roles = 214L,
    fit_interval_policy = "retain_v10_1_fit_role",
    refit_required = FALSE,
    article_figures = 2L, article_publication_owner = "ARTICLE_QDESN_INTEGRATION"
  )
  ffv2_write_json(decision, file.path(root, "decision_manifest.json"))
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  files <- files[basename(files) != "reporting_file_ledger.csv"]
  ledger <- idolp_v2_file_ledger(files, root)
  ledger <- ledger[order(ledger$relative_path), ]
  ffv2_write_csv(ledger, file.path(root, "reporting_file_ledger.csv"))
  invisible(list(roles = roles, path = roles_path, decision = decision))
}

idolp_v2_materialize <- function(repo_root = ffv2_repo_root()) {
  evidence <- idolp_v2_assert_evidence(repo_root, require_clean = TRUE)
  lapply(
    c(evidence$paths$audit, evidence$paths$point, evidence$paths$interval),
    idolp_v2_assert_empty
  )
  sensitivity <- idolp_v2_interval_sensitivity(
    evidence$interval_draws_by_chain, evidence$roles
  )
  if (!identical(sensitivity$decision, "PASS_USE_RETAINED_3000_DRAWS")) {
    stop("The targeted replay failed the predeclared interval precision gate.",
         call. = FALSE)
  }
  idolp_v2_write_audit(evidence, sensitivity)
  point <- idolp_v2_write_point_authority(evidence)
  interval <- idolp_v2_write_interval_authority(evidence, sensitivity, point)
  list(evidence = evidence, sensitivity = sensitivity,
       point = point, interval = interval)
}

idolp_v2_verify_materialized <- function(repo_root = ffv2_repo_root(),
                                         require_clean = FALSE) {
  evidence <- idolp_v2_assert_evidence(repo_root, require_clean = require_clean)
  p <- evidence$paths
  required <- c(p$audit, p$point, p$interval)
  if (!all(dir.exists(required))) stop("Promotion outputs are incomplete.")
  idolp_v2_verify_ledger(
    p$audit, file.path(p$audit, "artifact_manifest.csv")
  )
  audit_manifest <- idolp_v2_read_json(file.path(p$audit, "audit_manifest.json"))
  if (!identical(audit_manifest$status, "PORTABLE_EVIDENCE_PASS") ||
      !identical(
        audit_manifest$artifact_manifest_sha256,
        ffv2_file_sha256(file.path(p$audit, "artifact_manifest.csv"))
      )) stop("Portable audit control manifest failed.")
  point_manifest <- ffv2_read_csv(file.path(p$point, "output_file_manifest.csv"))
  point_paths <- file.path(repo_root, point_manifest$path)
  if (any(!file.exists(point_paths)) ||
      any(vapply(point_paths, ffv2_file_sha256, character(1L)) !=
            point_manifest$sha256)) stop("Point authority manifest failed.")
  idolp_v2_verify_ledger(
    p$interval, file.path(p$interval, "reporting_file_ledger.csv")
  )
  point_path <- file.path(p$point, paste0(idolp_v2_point_id, "_interface.csv"))
  point <- ffv2_read_csv(point_path)
  if (nrow(point) != 72L || anyDuplicated(point[c(
    "inference", "model_variant", "family", "tau"
  )])) stop("Point authority key contract failed.")
  target <- idolp_v2_point_source_row(point)
  parent_target <- idolp_v2_point_source_row(evidence$parent)
  numeric_metrics <- c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000"
  )
  if (sum(target) != 1L ||
      point$fit_qtrue_rmse[target] != evidence$parent$fit_qtrue_rmse[parent_target] ||
      point$forecast_qtrue_mae_H1000[target] >=
        evidence$parent$forecast_qtrue_mae_H1000[parent_target] - idolp_v2_tolerance ||
      point$forecast_check_loss_H1000[target] >=
        evidence$parent$forecast_check_loss_H1000[parent_target] -
          idolp_v2_tolerance) {
    stop("Point authority promotion contract failed.")
  }
  other <- !target
  parent_other <- !parent_target
  point_key <- paste(point$inference, point$model_variant, point$family, point$tau)
  parent_key <- paste(
    evidence$parent$inference, evidence$parent$model_variant,
    evidence$parent$family, evidence$parent$tau
  )
  parent_match <- match(point_key[other], parent_key)
  if (any(!vapply(numeric_metrics, function(metric) {
    identical(point[[metric]][other], evidence$parent[[metric]][parent_match])
  }, logical(1L)))) stop("A non-target point metric changed.")
  roles <- ffv2_read_csv(file.path(p$interval, "plot_ready_metric_intervals.csv"))
  if (nrow(roles) != 216L || anyDuplicated(roles[c(
    "inference", "model_variant", "family", "tau", "metric_role"
  )])) stop("Interval role contract failed.")
  interval_target <- roles$inference == "mcmc" &
    roles$model_variant == "qdesn_al_rhs_ns" & roles$family == "normal" &
    abs(roles$tau - 0.05) < 1e-12 &
    roles$metric_role %in% c("forecast_mae", "forecast_check")
  invariance <- ffv2_read_csv(file.path(p$interval, "parent_invariance_ledger.csv"))
  checks <- ffv2_read_csv(file.path(p$interval, "interval_precision_checks.csv"))
  forbidden <- list.files(
    c(p$audit, p$point, p$interval), pattern = "[.](rds|rda|RData)$",
    recursive = TRUE, full.names = TRUE, ignore.case = TRUE
  )
  if (sum(interval_target) != 2L ||
      any(roles$n_draws[interval_target] != idolp_v2_replay_total_draws) ||
      any(roles$n_chains[interval_target] != 3L) ||
      any(roles$estimator_id[interval_target] != idolp_v2_estimator_id) ||
      any(!checks$pass) ||
      any(abs(invariance$posterior_mean_delta[invariance$inherited_role]) > 0) ||
      any(abs(invariance$lower_delta[invariance$inherited_role]) > 0) ||
      any(abs(invariance$upper_delta[invariance$inherited_role]) > 0) ||
      length(forbidden)) {
    stop("Interval authority or storage contract failed.")
  }
  data.frame(
    check = c(
      "runtime_authority", "portable_audit", "point_manifest",
      "point_metric_specificity", "interval_manifest",
      "interval_role_specificity", "interval_precision", "storage_light"
    ),
    pass = TRUE,
    stringsAsFactors = FALSE
  )
}
