iqps_v8_schema <- "independent_qdesn_paired_forecast_v8"
iqps_v8_stages <- c("cost_smoke", "same_seed_replay", "paired_confirmation")

iqps_v8_source <- function(repo) {
  source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_coupled_design_v7.R"), local = FALSE)
  iqdr_v7_source(repo)
}

iqps_v8_expected <- function(reference, stage, seed) {
  if (!stage %in% iqps_v8_stages) stop("Unknown v8 stage.")
  cfg <- reference
  cfg$seed <- as.integer(seed)
  if (stage == "cost_smoke") {
    cfg$outer_draws <- 4L
    cfg$inner_path_grid <- 32L
    cfg$origins$end <- as.integer(cfg$origins$start + cfg$origins$stride)
  }
  if (stage == "paired_confirmation") cfg$outer_draws <- 64L
  cfg
}

iqps_v8_science_check <- function(reference, cfg) {
  expected <- iqps_v8_expected(reference, cfg$stage, cfg$seed)
  fields <- c(iqbs_v5_science_fields, "beta_covariance_approximation",
    "collect_solver_diagnostics", "baseline_config_path", "baseline_config_sha256",
    "frozen_initializer_sha256")
  all(vapply(fields, function(k) identical(expected[[k]], cfg[[k]]), TRUE)) &&
    identical(cfg$beta_covariance_approximation, "full") &&
    identical(cfg$case_id, iqdr_v7_case(reference)) &&
    cfg$pair_role %in% c("challenger", "control") &&
    cfg$seed_index %in% 1:3 &&
    (cfg$stage == "paired_confirmation" || cfg$seed_index == 1L) &&
    (cfg$stage == "paired_confirmation" || cfg$seed == reference$seed)
}

iqps_v8_config <- function(reference, role, stage, seed_index, seed, repo, run) {
  cfg <- iqps_v8_expected(reference, stage, seed)
  cfg$schema_version <- iqps_v8_schema
  cfg$stage <- stage
  cfg$pair_role <- role
  cfg$seed_index <- as.integer(seed_index)
  cfg$case_id <- iqdr_v7_case(reference)
  cfg$source_job_id <- reference$job_id
  cfg$source_config_path <- reference$config_path
  cfg$source_config_sha256 <- iqfr_v2_sha256(reference$config_path)
  cfg$repo_root <- repo; cfg$run_root <- run
  cfg$job_id <- paste("paired_forecast_v8", cfg$case_id, role, stage, seed_index, sep = "__")
  cfg$config_path <- file.path(run, "configs", paste0(cfg$job_id, ".json"))
  cfg$status_path <- file.path(run, "status", paste0(cfg$job_id, ".json"))
  suffixes <- c(result_path = ".csv", metric_draw_path = "__metric_draws.csv.gz",
    origin_lead_path = "__origin_lead.csv.gz", lead_profile_path = "__lead_profile.csv",
    origin_profile_path = "__origin_profile.csv", origin_block_path = "__origin_blocks.csv")
  for (k in names(suffixes)) cfg[[k]] <- file.path(run, "results", paste0(cfg$job_id, suffixes[[k]]))
  stopifnot(iqps_v8_science_check(reference, cfg))
  cfg
}

iqps_v8_compare_scores <- function(reference, result, tolerance = 1e-6) {
  fields <- c("forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss",
    "fit_qtrue_rmse_mean", "fit_qtrue_mae_mean", "fit_check_loss_mean")
  stopifnot(nrow(reference) > 0L, nrow(result) > 0L,
    all(c("estimator", "inner_paths", fields) %in% names(reference)),
    all(c("estimator", "inner_paths", fields) %in% names(result)))
  key <- function(x) paste(x$estimator, x$inner_paths, sep = "|")
  stopifnot(!anyDuplicated(key(reference)), !anyDuplicated(key(result)),
    setequal(key(reference), key(result)))
  result <- result[match(key(reference), key(result)), ]
  errors <- vapply(fields, function(k) {
    stopifnot(all(is.finite(reference[[k]])), all(is.finite(result[[k]])))
    max(abs(reference[[k]] - result[[k]]))
  }, 1)
  data.frame(field = fields, maximum_absolute_error = errors,
    tolerance = tolerance, pass = errors <= tolerance)
}

iqps_v8_fit_check <- function(reference, cfg) {
  root <- function(c) file.path(c$run_root, "fit_diagnostics", c$job_id)
  a <- iqfr_v2_read_json(file.path(root(reference), "summary.json"))
  b <- iqfr_v2_read_json(file.path(root(cfg), "summary.json"))
  stopifnot(identical(a$design_sha256, b$design_sha256),
    identical(a$response_sha256, b$response_sha256), a$vb_iterations == b$vb_iterations)
  fields <- c("sigma_mean", "gamma_mean", "fit_point_rmse", "fit_point_check_loss", "beta_mean_norm")
  errors <- vapply(fields, function(k) abs(a[[k]] - b[[k]]), 1)
  beta_a <- read.csv(file.path(root(reference), "beta_moments.csv"))
  beta_b <- read.csv(file.path(root(cfg), "beta_moments.csv"))
  stopifnot(identical(beta_a$column, beta_b$column))
  beta_fields <- c("mean", "sd", "prior_precision")
  errors <- c(errors, setNames(vapply(beta_fields, function(k)
    max(abs(beta_a[[k]] - beta_b[[k]])), 1), paste0("beta_", beta_fields)))
  covariance_a <- as.matrix(read.csv(file.path(root(reference), "beta_covariance.csv.gz")))
  covariance_b <- as.matrix(read.csv(file.path(root(cfg), "beta_covariance.csv.gz")))
  stopifnot(identical(dim(covariance_a), dim(covariance_b)))
  errors <- c(errors, beta_covariance = max(abs(covariance_a - covariance_b)))
  data.frame(field = names(errors), maximum_absolute_error = errors,
    tolerance = 1e-6, pass = is.finite(errors) & errors <= 1e-6)
}

iqps_v8_materialize <- function(repo, baseline, run, tests_path, smoke_path) {
  if (dir.exists(run)) stop("Refusing to overwrite a v8 run.")
  stopifnot(!length(system2("git", c("status", "--porcelain"), stdout = TRUE)))
  iqct_v6_verify_inputs(baseline)
  iqbs_v5_verify_manifest(file.path(baseline, "final_artifact_manifest.csv"))
  stopifnot(all(iqdr_v7_health(baseline)$status == "SUCCESS"))
  prior <- iqfr_v2_read_json(file.path(baseline, "environment.json"))
  stopifnot(prior$head == "e39c46e2e6d3c547c0f49d78b48eaa596f431ea2")
  tests <- read.csv(tests_path); smoke <- read.csv(smoke_path)
  stopifnot(all(tests$failed == 0), !any(tests$error), all(tests$warning == 0),
    nrow(smoke) == 6L, all(smoke$pass))
  evidence <- read.csv(file.path(baseline, "comparison.csv"))
  cases <- sort(unique(evidence$case_id))
  stopifnot(identical(cases, c("normal_al_p005", "normal_exal_p025")))
  selection <- list(); configs <- list(); seeds <- list()
  for (case in cases) {
    new <- evidence[evidence$case_id == case & evidence$provenance == "new_v7", ]
    old <- evidence[evidence$case_id == case & evidence$provenance == "cached_v6", ]
    pair <- rbind(new[which.min(new$forecast_mae), ], old[which.min(old$forecast_mae), ])
    pair$pair_role <- c("challenger", "control")
    source_cfgs <- lapply(pair$config_path, iqfr_v2_read_json)
    stopifnot(source_cfgs[[1]]$seed == source_cfgs[[2]]$seed,
      identical(source_cfgs[[1]]$source, source_cfgs[[2]]$source))
    offsets <- c(0L, 100003L, 200003L)
    seeds[[case]] <- as.integer(source_cfgs[[1]]$seed + offsets)
    stopifnot(!anyNA(seeds[[case]]), !anyDuplicated(seeds[[case]]))
    for (i in seq_len(nrow(pair))) {
      cfg <- source_cfgs[[i]]
      stopifnot(iqcb_v4_status_valid(cfg$config_path, cfg$status_path),
        cfg$fit_end == 8750L, cfg$rollout_end == 9000L, cfg$horizon == 30L,
        cfg$outer_draws == 16L, cfg$inner_path_grid == 128L,
        identical(cfg$origins, list(start = 8750L, end = 8970L, stride = 5L)))
      selection[[length(selection) + 1L]] <- pair[i, ]
      for (stage in iqps_v8_stages) for (index in if (stage == "paired_confirmation") 1:3 else 1L)
        configs[[length(configs) + 1L]] <- iqps_v8_config(cfg, pair$pair_role[i],
          stage, index, seeds[[case]][index], repo, run)
    }
  }
  p <- do.call(rbind, lapply(configs, function(cfg) {
    iqfr_v2_write_json(cfg, cfg$config_path)
    roundtrip <- iqfr_v2_read_json(cfg$config_path)
    stopifnot(iqps_v8_science_check(iqfr_v2_read_json(cfg$source_config_path), roundtrip))
    data.frame(job_id = cfg$job_id, stage = cfg$stage, case_id = cfg$case_id,
      pair_role = cfg$pair_role, seed_index = cfg$seed_index, seed = cfg$seed,
      tau0 = cfg$candidate$rhs_tau0, columns = cfg$candidate$readout_dimension,
      config_path = cfg$config_path, config_sha256 = iqfr_v2_sha256(cfg$config_path),
      status_path = cfg$status_path, result_path = cfg$result_path)
  }))
  p <- p[order(match(p$stage, iqps_v8_stages), -p$columns, p$case_id, p$pair_role, p$seed_index), ]
  stopifnot(nrow(p) == 20L, !anyDuplicated(p$job_id))
  iqfr_v2_write_csv(p, file.path(run, "plan.csv"))
  selection <- do.call(rbind, selection)
  iqfr_v2_write_csv(selection, file.path(run, "frozen_selection.csv"))
  inputs <- unique(c(read.csv(file.path(baseline, "final_artifact_manifest.csv"))$path,
    read.csv(file.path(baseline, "input_hashes.csv"))$path,
    file.path(baseline, "final_artifact_manifest.csv"), tests_path, smoke_path))
  iqbs_v5_hash_manifest(inputs, file.path(run, "input_hashes.csv"))
  sources <- c(list.files(file.path(repo, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "src"), full.names = TRUE, pattern = "[.](cpp|c|h|so)$"),
    list.files(file.path(repo, "validation/fitforecast_v2/R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), full.names = TRUE, pattern = "paired_forecast_v8"),
    list.files(file.path(repo, "validation/fitforecast_v2/tests/testthat"), full.names = TRUE, pattern = "paired-forecast-v8"),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_PAIRED_FORECAST_V8_PLAN_20261002.md"))
  iqbs_v5_hash_manifest(sources, file.path(run, "source_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqps_v8_schema,
    head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE), baseline_run = baseline,
    comparator_path = prior$comparator_path, production_jobs = 12L, cost_jobs = 4L,
    replay_jobs = 4L, concurrency = 6L, seeds = seeds,
    runtime = "pkgload_validation_source_not_unmodified_CRAN_binary",
    package_version = as.character(packageVersion("exdqlm")), R_version = R.version.string,
    session_info = capture.output(sessionInfo()), blas_lapack = as.list(extSoftVersion()),
    thread_environment = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    compiler = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"), stdout = TRUE),
    fit_rng_policy = "frozen_initializer_RNG_independent_of_forecast_seed",
    score_replay_tolerance = 1e-6, minimum_gain_threshold = 0,
    diagnostic_exclusion = FALSE, article_promotion = FALSE, automatic_MCMC = FALSE,
    automatic_other_cell_expansion = FALSE, legacy_v2_process_action = "NONE_KEEP_HELD"),
    file.path(run, "environment.json"))
  iqbs_v5_hash_manifest(c(file.path(run, c("plan.csv", "frozen_selection.csv", "source_hashes.csv",
    "input_hashes.csv", "environment.json")), p$config_path), file.path(run, "materialization_hashes.csv"))
  p[c("stage", "case_id", "pair_role", "seed_index")]
}

iqps_v8_status_valid <- function(path) {
  cfg <- iqfr_v2_read_json(path)
  if (!iqcb_v4_status_valid(path, cfg$status_path)) return(FALSE)
  status <- iqfr_v2_read_json(cfg$status_path)
  required <- c("fit_contract", "worker_timing")
  if (cfg$stage == "same_seed_replay") required <- c(required, "replay_contract")
  if (!all(required %in% names(status$artifact_paths))) return(FALSE)
  checks <- setdiff(required, "worker_timing")
  all(vapply(checks, function(k) {
    z <- read.csv(status$artifact_paths[[k]])
    nrow(z) > 0L && "pass" %in% names(z) && isTRUE(all(z$pass))
  }, TRUE))
}

iqps_v8_health <- function(run) {
  h <- iqdr_v7_health(run)
  p <- read.csv(file.path(run, "plan.csv"))
  for (i in which(h$status == "SUCCESS"))
    if (!iqps_v8_status_valid(p$config_path[i])) h$status[i] <- "POSTCHECK_INCOMPLETE"
  h
}

iqps_v8_worker <- function(path) {
  cfg <- iqfr_v2_read_json(path)
  iqct_v6_verify_inputs(cfg$run_root)
  env <- iqfr_v2_read_json(file.path(cfg$run_root, "environment.json"))
  reference <- iqfr_v2_read_json(cfg$source_config_path)
  stopifnot(env$head == system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    iqfr_v2_sha256(cfg$source_config_path) == cfg$source_config_sha256,
    iqps_v8_science_check(reference, cfg),
    cfg$seed == env$seeds[[cfg$case_id]][cfg$seed_index])
  check_path <- file.path(cfg$run_root, "checks", paste0(cfg$job_id, "__fit.csv"))
  if (iqps_v8_status_valid(path)) return(invisible("ALREADY_COMPLETE"))
  tryCatch({
    iqdr_v7_run_measured(cfg)
    checked <- iqps_v8_fit_check(reference, cfg)
    iqfr_v2_write_csv(checked, check_path)
    stopifnot(all(checked$pass))
    if (cfg$stage == "same_seed_replay") {
      replay <- iqps_v8_compare_scores(read.csv(reference$result_path), read.csv(cfg$result_path))
      replay_path <- file.path(cfg$run_root, "checks", paste0(cfg$job_id, "__replay.csv"))
      iqfr_v2_write_csv(replay, replay_path)
      stopifnot(all(replay$pass))
    }
    status <- iqfr_v2_read_json(cfg$status_path)
    extra <- c(fit_contract = check_path,
      worker_timing = file.path(cfg$run_root, "timing", cfg$job_id, "worker_timing.json"))
    if (cfg$stage == "same_seed_replay") extra <- c(extra, replay_contract = replay_path)
    status$artifact_paths <- c(status$artifact_paths, as.list(extra))
    status$artifact_sha256 <- c(status$artifact_sha256, lapply(extra, iqfr_v2_sha256))
    iqfr_v2_write_json(status, cfg$status_path)
    stopifnot(iqps_v8_status_valid(path))
  }, error = function(e) {
    iqcf_v3_status_write(cfg, "FAILED", Sys.time(), list(error = conditionMessage(e),
      fitted_model_binaries = 0L, failure_kind = "COMPUTE_OR_REPRODUCIBILITY_CONTRACT"))
    stop(e)
  })
}

iqps_v8_project_cost <- function(timing) {
  stopifnot(is.finite(timing$quantile_seconds), timing$quantile_seconds > 0,
    is.finite(timing$forecast_and_artifact_seconds), timing$forecast_and_artifact_seconds > 0)
  timing$quantile_seconds + timing$forecast_and_artifact_seconds * (45/2) * (64/4) * (128/32)
}

iqps_v8_cost_gate <- function(run) {
  iqct_v6_verify_inputs(run)
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "cost_smoke", ]
  stopifnot(nrow(p) == 4L)
  z <- do.call(rbind, lapply(p$config_path, function(path) {
    cfg <- iqfr_v2_read_json(path)
    stopifnot(iqps_v8_status_valid(path))
    timing <- iqfr_v2_read_json(file.path(run, "timing", cfg$job_id, "worker_timing.json"))
    estimate <- iqps_v8_project_cost(timing)
    data.frame(case_id = cfg$case_id, pair_role = cfg$pair_role,
      conservative_projected_seconds = estimate, safety_factor = 2,
      timeout_seconds = 21600L, pass = 2 * estimate < 21600)
  }))
  iqfr_v2_write_csv(z, file.path(run, "cost_gate.csv"))
  stopifnot(all(z$pass))
  z
}

iqps_v8_replay_gate <- function(run) {
  iqct_v6_verify_inputs(run)
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "same_seed_replay", ]
  stopifnot(nrow(p) == 4L)
  rows <- lapply(p$config_path, function(path) {
    cfg <- iqfr_v2_read_json(path)
    stopifnot(iqps_v8_status_valid(path))
    z <- read.csv(file.path(run, "checks", paste0(cfg$job_id, "__replay.csv")))
    stopifnot(all(z$pass))
    cbind(job_id = cfg$job_id, z)
  })
  x <- do.call(rbind, rows)
  iqfr_v2_write_csv(x, file.path(run, "replay_gate.csv"))
  x
}

iqps_v8_paired_ledger <- function(z) {
  metrics <- c("forecast_mae", "forecast_rmse", "conditional_check_loss", "pooled_predictive_check_loss", "fit_point_rmse")
  rows <- list()
  for (case in unique(z$case_id)) for (seed in sort(unique(z$seed_index))) {
    a <- z[z$case_id == case & z$seed_index == seed & z$pair_role == "challenger", ]
    b <- z[z$case_id == case & z$seed_index == seed & z$pair_role == "control", ]
    stopifnot(nrow(a) == 1L, nrow(b) == 1L, a$seed == b$seed)
    for (metric in metrics) rows[[length(rows) + 1L]] <- data.frame(case_id = case,
      seed_index = seed, seed = a$seed, metric = metric, challenger = a[[metric]], control = b[[metric]],
      gain = b[[metric]] - a[[metric]], strict_gain = a[[metric]] < b[[metric]],
      challenger_job = a$job_id, control_job = b$job_id)
  }
  do.call(rbind, rows)
}

iqps_v8_granular_pairs <- function(z, axis) {
  keys <- c("case_id", "seed_index", "seed", axis)
  a <- z[z$pair_role == "challenger", c(keys, "absolute_oracle_error", "check_loss")]
  b <- z[z$pair_role == "control", c(keys, "absolute_oracle_error", "check_loss")]
  stopifnot(nrow(a) == nrow(b), !anyDuplicated(a[keys]), !anyDuplicated(b[keys]))
  paired <- merge(a, b, by = keys, suffixes = c("_challenger", "_control"))
  stopifnot(nrow(paired) == nrow(a))
  paired$mae_gain <- paired$absolute_oracle_error_control - paired$absolute_oracle_error_challenger
  paired$conditional_check_gain <- paired$check_loss_control - paired$check_loss_challenger
  paired
}

iqps_v8_audit <- function(run) {
  iqct_v6_verify_inputs(run)
  h <- iqps_v8_health(run)
  stopifnot(nrow(h) == 20L, all(h$status == "SUCCESS"))
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "paired_confirmation", ]
  env <- iqfr_v2_read_json(file.path(run, "environment.json"))
  comparators <- read.csv(env$comparator_path)
  records <- origins <- leads <- list()
  for (path in p$config_path) {
    cfg <- iqfr_v2_read_json(path)
    score <- read.csv(cfg$result_path)
    point <- score[score$estimator == "mean_conditional_location", ]
    pool <- score[score$estimator == "posterior_predictive_quantile_pooled", ]
    stopifnot(nrow(point) == 1L, nrow(pool) == 1L, point$forecast_pairs == 1350L)
    summary <- iqfr_v2_read_json(file.path(run, "fit_diagnostics", cfg$job_id, "summary.json"))
    comparator <- comparators[comparators$family == cfg$candidate$family &
      comparators$likelihood_family == cfg$likelihood_family & comparators$probability == cfg$probability, ]
    stopifnot(nrow(comparator) == 1L)
    record <- data.frame(case_id = cfg$case_id, pair_role = cfg$pair_role,
      job_id = cfg$job_id, source_job_id = cfg$source_job_id, seed_index = cfg$seed_index, seed = cfg$seed,
      forecast_mae = point$forecast_qtrue_mae, forecast_rmse = point$forecast_qtrue_rmse,
      conditional_check_loss = point$forecast_check_loss,
      pooled_predictive_check_loss = pool$forecast_check_loss, fit_point_rmse = summary$fit_point_rmse,
      vb_converged = summary$vb_converged, vb_iterations = summary$vb_iterations,
      comparator_mae = comparator$forecast_qtrue_mae, comparator_conditional_check = comparator$forecast_check_loss,
      config_path = cfg$config_path, config_sha256 = iqfr_v2_sha256(cfg$config_path))
    stopifnot(all(is.finite(unlist(record[c("forecast_mae", "forecast_rmse", "conditional_check_loss",
      "pooled_predictive_check_loss", "fit_point_rmse")]))))
    records[[length(records) + 1L]] <- record
    id <- record[c("case_id", "pair_role", "job_id", "seed_index", "seed")]
    for (kind in c("origin", "lead")) {
      granular <- read.csv(cfg[[paste0(kind, "_profile_path")]])
      granular <- granular[granular$estimator == "mean_conditional_location", ]
      keep <- intersect(c("source_origin", "lead", "absolute_oracle_error", "check_loss"), names(granular))
      part <- cbind(id[rep(1L, nrow(granular)), ], granular[keep])
      if (kind == "origin") origins[[length(origins) + 1L]] <- part else leads[[length(leads) + 1L]] <- part
    }
  }
  z <- do.call(rbind, records)
  ledger <- iqps_v8_paired_ledger(z)
  means <- aggregate(cbind(challenger, control, gain) ~ case_id + metric, ledger, mean)
  counts <- aggregate(strict_gain ~ case_id + metric, ledger, sum)
  means <- merge(means, counts, by = c("case_id", "metric"))
  names(means)[names(means) == "strict_gain"] <- "seeds_with_strict_gain"
  means$seed_mean_strict_gain <- means$gain > 0
  iqfr_v2_write_csv(z, file.path(run, "confirmation_scores.csv"))
  iqfr_v2_write_csv(ledger, file.path(run, "paired_seed_gains.csv"))
  iqfr_v2_write_csv(means, file.path(run, "repeated_seed_summary.csv"))
  iqfr_v2_write_csv(ledger[ledger$strict_gain, ], file.path(run, "observed_strict_gain_ledger.csv"))
  origin_data <- do.call(rbind, origins); lead_data <- do.call(rbind, leads)
  iqfr_v2_write_csv(origin_data, file.path(run, "confirmation_origin_profiles.csv"))
  iqfr_v2_write_csv(lead_data, file.path(run, "confirmation_lead_profiles.csv"))
  for (kind in c("origin", "lead")) {
    axis <- if (kind == "origin") "source_origin" else "lead"
    pairs <- iqps_v8_granular_pairs(if (kind == "origin") origin_data else lead_data, axis)
    iqfr_v2_write_csv(pairs, file.path(run, paste0("paired_", kind, "_gains.csv")))
    summary <- aggregate(pairs[c("absolute_oracle_error_challenger", "absolute_oracle_error_control",
      "mae_gain", "conditional_check_gain")], pairs[c("case_id", axis)], mean)
    iqfr_v2_write_csv(summary, file.path(run, paste0("repeated_seed_", kind, "_summary.csv")))
  }
  primary <- means[means$metric == "forecast_mae", ]
  iqfr_v2_write_json(list(schema = iqps_v8_schema, production_success = 12L,
    cost_success = 4L, replay_success = 4L, decision = if (any(primary$seed_mean_strict_gain))
      "PAIRED_INTERNAL_GAIN_PREPARE_CASE_SPECIFIC_MCMC" else "SEED_SENSITIVITY_REVIEW_NO_AUTOMATIC_EXPANSION",
    mean_mae_winning_cases = as.list(primary$case_id[primary$seed_mean_strict_gain]),
    finite_strict_seed_metric_gains = sum(ledger$strict_gain), minimum_gain_threshold = 0,
    diagnostic_exclusion = FALSE, article_promotion = FALSE, automatic_MCMC = FALSE,
    automatic_other_cell_expansion = FALSE,
    note = "Keep every observed strict gain; seed-specific and repeated-seed point scores are distinct. VB is not a MCMC selection guarantee."),
    file.path(run, "decision.json"))
  print(means, row.names = FALSE)
  invisible(TRUE)
}
