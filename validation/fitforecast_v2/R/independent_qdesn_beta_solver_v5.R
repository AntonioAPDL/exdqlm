iqbs_v5_schema <- "independent_qdesn_beta_solver_v5"

iqbs_v5_progress <- function(cfg, phase) {
  iqfr_v2_write_json(list(job_id = cfg$job_id, phase = phase, pid = Sys.getpid(),
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE)),
    file.path(cfg$run_root, "progress", paste0(cfg$job_id, ".json")))
}

iqbs_v5_source <- function(repo) {
  for (f in c("independent_qdesn_full_redesign_v2.R",
              "independent_qdesn_full_redesign_v2_runtime.R",
              "independent_qdesn_cellwise_refinement_v2_superseded_closeout.R",
              "independent_qdesn_corrected_forecast_v3.R",
              "independent_qdesn_corrected_forecast_v3_campaign.R",
              "independent_qdesn_corrected_broad_v4.R")) {
    source(file.path(repo, "validation/fitforecast_v2/R", f), local = FALSE)
  }
}

iqbs_v5_fit_summaries <- function(X, mean_beta, beta_draws, truth, observed, p, transport) {
  q <- transport$inverse(X %*% t(beta_draws))
  point <- as.numeric(transport$inverse(X %*% mean_beta))
  draw_mean <- rowMeans(q)
  bounds <- t(apply(q, 1L, quantile, probs = c(.025, .975), names = FALSE))
  draw_rmse <- sqrt(colMeans(sweep(q, 1L, truth, `-`)^2))
  list(path = data.frame(q_true = truth, observed = observed,
       coefficient_mean_path = point, posterior_draw_mean_path = draw_mean,
       lower_025 = bounds[, 1L], upper_975 = bounds[, 2L]),
       draws = q,
       scores = list(fit_point_rmse = sqrt(mean((point - truth)^2)),
         fit_sample_mean_path_rmse = sqrt(mean((draw_mean - truth)^2)),
         fit_draw_rmse_mean = mean(draw_rmse),
         fit_draw_rmse_lower = unname(quantile(draw_rmse, .025)),
         fit_draw_rmse_upper = unname(quantile(draw_rmse, .975)),
         fit_point_check_loss = mean(iqcf_v3_check_loss(observed, point, p)),
         fit_point_bias = mean(point - truth)))
}

iqbs_v5_capture_fit <- function(cfg, fit, draws, source, rows, transport) {
  root <- file.path(cfg$run_root, "fit_diagnostics", cfg$job_id)
  X <- fit$X
  f <- fit$fit
  moments <- iqbs_v5_fit_summaries(X, f$qbeta$m, draws$beta,
    source$q_target[rows], source$y[rows], cfg$probability, transport)
  prior <- exdqlm:::exal_make_beta_prior(type = f$beta_prior$type,
                                       rhs = f$beta_prior$hypers)
  precision <- prior$expected_prec(f$beta_prior$state, ncol(X))
  stats <- exdqlm:::.exal_beta_data_stats(X, transport$forward(source$y[rows]),
    f$qsiggam$xi, f$qv$m_inv, f$qs$m)
  full <- exdqlm:::.exal_beta_solve_from_data_stats(stats, precision)
  diagonal <- exdqlm:::.exal_beta_solve_diagonal_from_data_stats(stats, precision)
  norm <- function(x) sqrt(sum(x^2))
  residual <- function(m) norm(full$P %*% m - full$h) / max(norm(full$h), 1e-12)
  covariance <- (f$qbeta$V + t(f$qbeta$V)) / 2
  eigenvalues <- eigen(covariance, symmetric = TRUE, only.values = TRUE)$values
  diagnostic <- c(list(schema = iqbs_v5_schema, job_id = cfg$job_id,
    beta_covariance = cfg$beta_covariance_approximation,
    source_config_sha256 = cfg$baseline_config_sha256,
    design_sha256 = digest::digest(X, algo = "sha256"),
    response_sha256 = digest::digest(transport$forward(source$y[rows]), algo = "sha256"),
    response_center = transport$center, response_scale = transport$scale,
    rows = nrow(X), columns = ncol(X), vb_iterations = f$iter,
    vb_converged = f$converged, sigma_mean = f$qsiggam$sigma_mean,
    gamma_mean = f$qsiggam$gamma_mean,
    beta_mean_norm = norm(f$qbeta$m), covariance_min_eigenvalue = min(eigenvalues),
    covariance_max_eigenvalue = max(eigenvalues),
    full_frozen_moment_residual = residual(full$sol$x),
    diagonal_frozen_moment_residual = residual(diagonal$sol$x),
    fitted_final_moment_residual = residual(f$qbeta$m),
    residual_note = "Final moments follow sequential updates; fitted residual is diagnostic, not an exact fixed-point assertion.",
    sigma_gamma_factorization = f$qsiggam$factorization), moments$scores)
  paths <- c(
    solver_diagnostics = iqfr_v2_write_json(diagnostic, file.path(root, "summary.json")),
    fit_paths = iqfr_v2_write_csv(cbind(t = source$t[rows], moments$path), file.path(root, "fit_paths.csv")),
    fit_draws = iqfr_v2_write_csv_gz(cbind(t = source$t[rows], as.data.frame(moments$draws)), file.path(root, "fit_quantile_draws.csv.gz")),
    beta_moments = iqfr_v2_write_csv(data.frame(column = seq_len(ncol(X)),
      mean = f$qbeta$m, sd = sqrt(pmax(diag(covariance), 0)), prior_precision = precision), file.path(root, "beta_moments.csv")),
    beta_covariance = iqfr_v2_write_csv_gz(as.data.frame(covariance), file.path(root, "beta_covariance.csv.gz")))
  fields <- c("elbo_trace", "gamma_trace", "sigma_trace", "rhs_tau_trace", "rhs_c2_trace")
  count <- max(vapply(f$misc[fields], length, 1L))
  trace <- data.frame(iteration = seq_len(count))
  for (field in fields) {
    value <- f$misc[[field]]
    trace[[field]] <- if (is.null(value)) rep(NA_real_, count) else c(value, rep(NA_real_, count - length(value)))
  }
  paths <- c(paths, fit_trace = iqfr_v2_write_csv(trace, file.path(root, "trace.csv")))
  paths
}

iqbs_v5_science_fields <- c("candidate", "source", "probability", "likelihood_family",
  "rhs_s2", "fit_end", "rollout_end", "origins", "horizon", "outer_draws",
  "inner_path_grid", "include_mean_readout_state", "seed", "budget")

iqbs_v5_science_check <- function(original, candidate) {
  vapply(iqbs_v5_science_fields, function(k) identical(original[[k]], candidate[[k]]), TRUE)
}

iqbs_v5_hash_manifest <- function(paths, output) {
  paths <- unique(paths[file.exists(paths)])
  iqfr_v2_write_csv(data.frame(path = normalizePath(paths),
    bytes = file.info(paths)$size, sha256 = unname(tools::sha256sum(paths))), output)
}

iqbs_v5_freeze_v4 <- function(old_run, out) {
  plans <- lapply(list.files(file.path(old_run, "plans"), full.names = TRUE), read.csv)
  jobs <- artifacts <- list()
  for (p in plans) for (i in seq_len(nrow(p))) {
    cfg <- iqfr_v2_read_json(p$config_path[i])
    stopifnot(identical(iqfr_v2_sha256(p$config_path[i]), p$config_sha256[i]))
    if (p$stage[i] == "development_comparator") {
      state <- iqcb_v4_comparator_status(p$config_path[i], p$status_path[i])
    } else {
      s <- iqcb_v4_status_payload(p$status_path[i])
      state <- if (is.null(s)) "PENDING" else s$status
      if (state == "SUCCESS") stopifnot(iqcb_v4_status_valid(p$config_path[i], p$status_path[i]))
    }
    jobs[[length(jobs) + 1L]] <- data.frame(stage = p$stage[i], job_id = p$job_id[i],
      original_status = state, closeout_status = switch(state,
        RUNNING = "INTERRUPTED_BY_USER_AUTHORIZED_CLOSEOUT", PENDING = "CANCELLED_BEFORE_START", state))
  }
  ledger <- do.call(rbind, jobs)
  iqfr_v2_write_csv(ledger, file.path(out, "job_closeout.csv"))
  paths <- list.files(old_run, recursive = TRUE, full.names = TRUE)
  paths <- paths[!file.info(paths)$isdir]
  manifest <- iqbs_v5_hash_manifest(paths, file.path(out, "original_run_final_observed_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqbs_v5_schema,
    decision = "STOPPED_FOR_BETA_SOLVER_VALIDATION_DIAGNOSTIC_ONLY",
    success = sum(ledger$original_status == "SUCCESS"),
    interrupted = sum(ledger$original_status == "RUNNING"),
    cancelled = sum(ledger$original_status == "PENDING"),
    failed = sum(ledger$original_status == "FAILED"),
    original_run = old_run, manifest = manifest, manifest_sha256 = iqfr_v2_sha256(manifest),
    original_statuses_preserved = TRUE, article_promotion = FALSE,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(out, "closeout.json"))
}

iqbs_v5_materialize <- function(repo, old_run, run) {
  if (dir.exists(run)) stop("Refusing to overwrite an existing v5 run.")
  if (length(system2("git", c("status", "--porcelain"), stdout = TRUE))) stop("Commit the dedicated branch before freezing a run.")
  preflight <- file.path(repo, "validation/fitforecast_v2/local_trackers")
  test_path <- file.path(preflight, "beta_solver_v5_tests_20261001/test_results.csv")
  smoke_path <- file.path(preflight, "beta_solver_v5_smoke_20261001/smoke_summary.csv")
  tests <- read.csv(test_path); smoke <- read.csv(smoke_path)
  stopifnot(nrow(tests) > 0L, all(tests$failed == 0), !any(tests$error),
    nrow(smoke) == 4L, all(smoke$diagnostic_hook_pass), all(smoke$full_solve_residual < 1e-6))
  bank <- read.csv(file.path(old_run, "manifests/broad_candidates.csv"))
  plan <- read.csv(file.path(old_run, "plans/broad_screen.csv"))
  selected <- bank[bank$family == "normal" & bank$representation_role == "corrected_v3_cell_winner" &
    bank$tau0_multiplier == 1 & ((bank$likelihood_family == "al" & bank$probability == .05) |
      (bank$likelihood_family == "exal" & bank$probability == .25)), ]
  stopifnot(nrow(selected) == 2L, all(selected$readout_dimension <= 100))
  rows <- list()
  for (i in seq_len(nrow(selected))) {
    old_row <- plan[plan$candidate_id == selected$candidate_id[i], ]
    stopifnot(nrow(old_row) == 1L, iqcb_v4_status_valid(old_row$config_path, old_row$status_path))
    original <- iqfr_v2_read_json(old_row$config_path)
    for (mode in c("diagonal", "full")) {
      cfg <- original
      cfg$job_id <- paste0("solver_v5__", selected$candidate_id[i], "__", mode)
      cfg$stage <- "solver_comparison"
      cfg$schema_version <- iqbs_v5_schema
      cfg$repo_root <- repo; cfg$run_root <- run
      cfg$config_path <- file.path(run, "configs", paste0(cfg$job_id, ".json"))
      cfg$status_path <- file.path(run, "status", paste0(cfg$job_id, ".json"))
      cfg$baseline_config_path <- old_row$config_path
      cfg$baseline_config_sha256 <- iqfr_v2_sha256(old_row$config_path)
      cfg$baseline_result_path <- old_row$result_path
      cfg$baseline_result_sha256 <- iqfr_v2_sha256(old_row$result_path)
      cfg$beta_covariance_approximation <- mode
      cfg$collect_solver_diagnostics <- TRUE
      suffixes <- c(result_path = ".csv", metric_draw_path = "__metric_draws.csv.gz",
        origin_lead_path = "__origin_lead.csv.gz", lead_profile_path = "__lead_profile.csv",
        origin_profile_path = "__origin_profile.csv", origin_block_path = "__origin_blocks.csv")
      for (k in names(suffixes)) cfg[[k]] <- file.path(run, "results", paste0(cfg$job_id, suffixes[[k]]))
      stopifnot(all(iqbs_v5_science_check(original, cfg)))
      iqfr_v2_write_json(cfg, cfg$config_path)
      rows[[length(rows) + 1L]] <- data.frame(job_id = cfg$job_id, mode = mode,
        candidate_id = selected$candidate_id[i], family = "normal",
        probability = cfg$probability, likelihood_family = cfg$likelihood_family,
        config_path = cfg$config_path, config_sha256 = iqfr_v2_sha256(cfg$config_path),
        status_path = cfg$status_path, result_path = cfg$result_path,
        baseline_config_path = cfg$baseline_config_path,
        baseline_config_sha256 = cfg$baseline_config_sha256)
    }
  }
  jobs <- do.call(rbind, rows)
  iqfr_v2_write_csv(jobs, file.path(run, "plan.csv"))
  source_paths <- c(list.files(file.path(repo, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "src"), full.names = TRUE, pattern = "[.](cpp|c|h|so)$"),
    list.files(file.path(repo, "validation/fitforecast_v2/R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), full.names = TRUE, pattern = "beta_solver_v5"),
    list.files(file.path(repo, "validation/fitforecast_v2/tests/testthat"), full.names = TRUE, pattern = "(beta-solver-v5|corrected-broad-v4|corrected-forecast-v3)[.]R$"),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_BETA_SOLVER_AUDIT_V5_20261001.md"))
  iqbs_v5_hash_manifest(source_paths, file.path(run, "source_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqbs_v5_schema, head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    prior_run = old_run, jobs = 4L, threads_per_job = 1L,
    preflight_tests = test_path, preflight_tests_sha256 = iqfr_v2_sha256(test_path),
    preflight_smoke = smoke_path, preflight_smoke_sha256 = iqfr_v2_sha256(smoke_path),
    automatic_expansion = FALSE, article_promotion = FALSE,
    R_version = R.version.string, version = as.character(packageVersion("exdqlm")),
    blas_lapack = as.list(extSoftVersion()),
    compiler_cxx = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"), stdout = TRUE),
    compiler_cxxflags = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXXFLAGS"), stdout = TRUE),
    runtime = "pkgload_source_not_unmodified_CRAN_binary",
    session_info = capture.output(sessionInfo()),
    thread_environment = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(run, "environment.json"))
  iqbs_v5_hash_manifest(c(file.path(run, c("plan.csv", "environment.json", "source_hashes.csv")),
    jobs$config_path, test_path, smoke_path), file.path(run, "materialization_hashes.csv"))
  jobs
}

iqbs_v5_verify_manifest <- function(path) {
  m <- read.csv(path)
  if (!all(file.exists(m$path)) || !all(unname(tools::sha256sum(m$path)) == m$sha256)) stop("Manifest hash mismatch: ", path)
  invisible(TRUE)
}

iqbs_v5_worker <- function(config_path) {
  cfg <- iqfr_v2_read_json(config_path)
  iqbs_v5_verify_manifest(file.path(cfg$run_root, "materialization_hashes.csv"))
  iqbs_v5_verify_manifest(file.path(cfg$run_root, "source_hashes.csv"))
  original <- iqfr_v2_read_json(cfg$baseline_config_path)
  stopifnot(all(iqbs_v5_science_check(original, cfg)),
    identical(iqfr_v2_sha256(cfg$baseline_config_path), cfg$baseline_config_sha256),
    identical(iqfr_v2_sha256(cfg$baseline_result_path), cfg$baseline_result_sha256))
  env <- iqfr_v2_read_json(file.path(cfg$run_root, "environment.json"))
  stopifnot(identical(env$head, system2("git", c("rev-parse", "HEAD"), stdout = TRUE)))
  if (iqcb_v4_status_valid(config_path, cfg$status_path)) return(invisible("ALREADY_COMPLETE"))
  iqbs_v5_progress(cfg, "STARTED")
  iqcf_v3_run_job(config_path)
  iqbs_v5_progress(cfg, "COMPLETE")
}

iqbs_v5_replay_check <- function(old, replay, tolerance = 1e-6) {
  keys <- c("estimator", "inner_paths")
  fields <- c("forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss",
    "fit_qtrue_rmse_mean", "fit_qtrue_mae_mean", "fit_check_loss_mean")
  stopifnot(all(c(keys, fields) %in% names(old)), all(c(keys, fields) %in% names(replay)),
    !anyDuplicated(old[keys]), !anyDuplicated(replay[keys]))
  x <- merge(old[c(keys, fields)], replay[c(keys, fields)], by = keys,
    suffixes = c("_old", "_replay"), all = TRUE)
  errors <- vapply(fields, function(field) {
    delta <- abs(x[[paste0(field, "_old")]] - x[[paste0(field, "_replay")]])
    if (!length(delta) || any(!is.finite(delta))) return(Inf)
    max(delta)
  }, 1.0)
  list(pass = all(errors <= tolerance), max_error = max(errors), errors = as.list(errors))
}

iqbs_v5_health <- function(run) {
  p <- read.csv(file.path(run, "plan.csv"))
  exits_path <- file.path(run, "launcher_exit_codes.csv")
  exits <- if (file.exists(exits_path)) read.csv(exits_path) else data.frame()
  p$status <- vapply(seq_len(nrow(p)), function(i) {
    s <- iqcb_v4_status_payload(p$status_path[i])
    state <- if (is.null(s)) "PENDING" else s$status
    if (state == "SUCCESS" && !iqcb_v4_status_valid(p$config_path[i], p$status_path[i])) state <- "STALE_SUCCESS"
    if (nrow(exits)) {
      e <- exits[exits$slot == i - 1L, ]
      if (nrow(e) && e$exit_code != 0 && state != "SUCCESS") state <- paste0("FAILED_EXIT_", e$exit_code)
    }
    state
  }, "")
  p$phase <- vapply(p$job_id, function(id) {
    path <- file.path(run, "progress", paste0(id, ".json"))
    if (file.exists(path)) iqfr_v2_read_json(path)$phase else "NOT_STARTED"
  }, "")
  p[c("job_id", "mode", "status", "phase")]
}

iqbs_v5_audit <- function(run) {
  p <- read.csv(file.path(run, "plan.csv"))
  states <- vapply(p$status_path, function(path) {
    x <- iqcb_v4_status_payload(path); if (is.null(x)) "PENDING" else x$status
  }, "")
  cat("States:", paste(names(table(states)), table(states), collapse = "; "), "\n")
  if (!all(states == "SUCCESS")) return(invisible(FALSE))
  stopifnot(all(vapply(seq_len(nrow(p)), function(i) iqcb_v4_status_valid(p$config_path[i], p$status_path[i]), TRUE)))
  rows <- list()
  for (i in seq_len(nrow(p))) {
    cfg <- iqfr_v2_read_json(p$config_path[i]); z <- read.csv(cfg$result_path)
    diag <- iqfr_v2_read_json(file.path(run, "fit_diagnostics", cfg$job_id, "summary.json"))
    oracle <- z[z$estimator == "mean_conditional_location", ]
    pred <- z[z$estimator == "posterior_predictive_quantile_pooled", ]
    baseline <- read.csv(cfg$baseline_result_path)
    replay <- if (p$mode[i] == "diagonal") iqbs_v5_replay_check(baseline, z) else list(pass = NA, max_error = NA_real_)
    old_oracle <- baseline[baseline$estimator == "mean_conditional_location", ]
    rows[[i]] <- data.frame(job_id = cfg$job_id, candidate_id = p$candidate_id[i], mode = p$mode[i],
      probability = cfg$probability, likelihood = cfg$likelihood_family,
      forecast_mae = oracle$forecast_qtrue_mae,
      forecast_check_loss = pred$forecast_check_loss,
      old_forecast_mae = old_oracle$forecast_qtrue_mae,
      fit_point_rmse = diag$fit_point_rmse, fit_draw_rmse_mean = diag$fit_draw_rmse_mean,
      beta_mean_norm = diag$beta_mean_norm, vb_converged = diag$vb_converged,
      all_score_replay_pass = replay$pass, all_score_replay_max_error = replay$max_error,
      design_hash = diag$design_sha256, response_hash = diag$response_sha256,
      final_moment_residual = diag$fitted_final_moment_residual,
      covariance_min_eigenvalue = diag$covariance_min_eigenvalue,
      covariance_max_eigenvalue = diag$covariance_max_eigenvalue,
      full_frozen_residual = diag$full_frozen_moment_residual)
  }
  z <- do.call(rbind, rows)
  iqfr_v2_write_csv(z, file.path(run, "comparison.csv"))
  d <- z[z$mode == "diagonal", ]; f <- z[z$mode == "full", ]
  paired <- merge(d, f, by = "candidate_id", suffixes = c("_diagonal", "_full"))
  paired$baseline_replay_error <- abs(paired$forecast_mae_diagonal - paired$old_forecast_mae_diagonal)
  paired$forecast_mae_improvement <- paired$forecast_mae_diagonal - paired$forecast_mae_full
  paired$forecast_check_improvement <- paired$forecast_check_loss_diagonal - paired$forecast_check_loss_full
  paired$inputs_match <- paired$design_hash_diagonal == paired$design_hash_full & paired$response_hash_diagonal == paired$response_hash_full
  iqfr_v2_write_csv(paired, file.path(run, "paired_comparison.csv"))
  reproducible <- all(paired$all_score_replay_pass_diagonal) && all(paired$inputs_match)
  finite <- all(is.finite(z$forecast_mae)) && all(is.finite(z$forecast_check_loss)) &&
    all(is.finite(z$fit_point_rmse)) && all(z$full_frozen_residual < 1e-6) &&
    all(z$covariance_min_eigenvalue >= -1e-10 * pmax(1, z$covariance_max_eigenvalue))
  decision <- if (!reproducible || !finite) "HOLD_REPLAY_OR_NUMERIC_MISMATCH" else if (any(paired$forecast_mae_improvement > 0)) "COMPACT_SOLVER_COMPARISON_SUPPORTS_WIDE_BENCHMARK" else "NO_FORECAST_GAIN_INVESTIGATE_BEFORE_EXPANSION"
  iqfr_v2_write_json(list(decision = decision, paired_inputs_match = all(paired$inputs_match),
    replay_within_1e6 = all(paired$all_score_replay_pass_diagonal),
    finite_scores_and_frozen_solve_checks = finite, automatic_launch = FALSE,
    article_promotion = FALSE, jobs = 4L, comment = "Full versus diagonal changes mean and covariance; final-moment residual is not a fixed-point pass/fail gate."), file.path(run, "decision.json"))
  print(z)
  cat("Decision:", decision, "\n")
  paths <- list.files(run, full.names = TRUE, recursive = TRUE)
  paths <- paths[!file.info(paths)$isdir & basename(paths) != "final_artifact_manifest.csv"]
  iqbs_v5_hash_manifest(paths, file.path(run, "final_artifact_manifest.csv"))
  invisible(TRUE)
}
