iqct_v6_schema <- "independent_qdesn_coupled_tau_v6"
iqct_v6_multipliers <- c(1, 3.5, 30, 300)
iqct_v6_reference_ids <- c("iqcb4_normal_al_p005_36b501b2c57e", "iqcb4_normal_exal_p025_4e36250372e6")

iqct_v6_source <- function(repo) {
  source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_beta_solver_v5.R"), local = FALSE)
  iqbs_v5_source(repo)
}

iqct_v6_candidate_fields <- c("rhs_tau0", "rhs_tau0_source_scale", "tau0_multiplier",
  "tau_arm", "candidate_signature", "candidate_id")

iqct_v6_science_check <- function(original, cfg) {
  fixed <- setdiff(iqbs_v5_science_fields, "candidate")
  candidate_fixed <- setdiff(union(names(original$candidate), names(cfg$candidate)),
                             iqct_v6_candidate_fields)
  same <- all(vapply(fixed, function(k) identical(original[[k]], cfg[[k]]), TRUE)) &&
    all(vapply(candidate_fixed, function(k) identical(original$candidate[[k]], cfg$candidate[[k]]), TRUE))
  tau <- as.numeric(cfg$candidate$rhs_tau0)
  multiplier <- as.numeric(cfg$tau_multiplier)
  same && identical(cfg$beta_covariance_approximation, "full") &&
    length(tau) == 1L && is.finite(tau) && tau > 0 &&
    length(multiplier) == 1L && multiplier %in% iqct_v6_multipliers &&
    abs(tau - original$candidate$rhs_tau0 * multiplier) <= 1e-12 &&
    abs(cfg$candidate$rhs_tau0_source_scale - original$candidate$rhs_tau0_source_scale * multiplier) <= 1e-12
}

iqct_v6_init_digest <- function(init) {
  digest::digest(list(beta_m = as.numeric(init$beta_m),
    beta_V = unname(as.matrix(init$beta_V)), sigma = as.numeric(init$sigma)), algo = "sha256")
}

iqct_v6_prepare_initializer <- function(cfg, path) {
  source_rows <- iqfr_v2_source_rows(cfg$source$frozen_path)
  stopifnot(identical(iqfr_v2_sha256(cfg$source$frozen_path), cfg$source$frozen_sha256))
  fit_rows <- source_rows$t >= 8501L & source_rows$t <= cfg$fit_end
  transport <- iqcf_v3_response_transport(source_rows, fit_rows)
  model_y <- transport$forward(source_rows$y)
  preprocess <- iqfr_v2_training_preprocess(model_y[fit_rows], cfg$candidate$center_scale)
  normal_args <- list(beta_prior_type = "rhs_ns",
    rhs = list(tau0 = cfg$candidate$rhs_tau0, s2 = cfg$rhs_s2,
      shrink_intercept = FALSE, n_inner = 2L),
    control = list(max_iter = 200L, min_iter = 10L, tol = 1e-5,
      covariance = "woodbury_diagonal", verbose = FALSE))
  normal <- do.call(qdesn_fit_normal, iqfr_v2_design_args(model_y[source_rows$t <= cfg$fit_end],
    cfg$candidate, preprocess, p0 = cfg$probability, fit_readout = TRUE, normal_args = normal_args))
  iqfr_v2_assert_design(normal, cfg$candidate, sum(fit_rows))
  init <- qdesn_normal_to_vb_init(normal, cfg$likelihood_family, "rhs_ns", cfg$probability)
  init <- list(beta_m = as.numeric(init$beta_m), beta_V = unname(as.matrix(init$beta_V)),
    sigma = as.numeric(init$sigma), source = init$source)
  stopifnot(is.null(init$beta_state), all(is.finite(init$beta_m)),
    all(is.finite(init$beta_V)), is.finite(init$sigma), init$sigma > 0)
  payload <- list(schema = iqct_v6_schema, initialization = init,
    initialization_digest = iqct_v6_init_digest(init),
    source_sha256 = cfg$source$frozen_sha256,
    design_sha256 = digest::digest(normal$X, algo = "sha256"),
    reference_tau0 = cfg$candidate$rhs_tau0,
    reference_config_sha256 = iqfr_v2_sha256(cfg$config_path),
    probability = cfg$probability, likelihood = cfg$likelihood_family,
    response_center = transport$center, response_scale = transport$scale,
    rng_kind = RNGkind(), rng_after_normal = get(".Random.seed", envir = .GlobalEnv),
    prior_state_policy = "fresh_quantile_RHS_state_from_arm_tau0_no_transferred_beta_state")
  iqfr_v2_write_json(payload, path)
  roundtrip <- iqfr_v2_read_json(path)$initialization
  roundtrip_error <- max(abs(c(as.numeric(roundtrip$beta_m) - init$beta_m,
    as.numeric(roundtrip$beta_V) - as.numeric(init$beta_V), roundtrip$sigma - init$sigma)))
  stopifnot(is.finite(roundtrip_error), roundtrip_error <= 1e-12)
  payload$initialization <- roundtrip
  payload$initialization_digest <- iqct_v6_init_digest(roundtrip)
  payload$serialization_maximum_absolute_error <- roundtrip_error
  iqfr_v2_write_json(payload, path)
  roundtrip <- iqfr_v2_read_json(path)$initialization
  stopifnot(identical(iqct_v6_init_digest(roundtrip), payload$initialization_digest))
  path
}

iqct_v6_load_initializer <- function(cfg) {
  stopifnot(identical(iqfr_v2_sha256(cfg$frozen_initializer_path), cfg$frozen_initializer_sha256))
  payload <- iqfr_v2_read_json(cfg$frozen_initializer_path)
  init <- payload$initialization
  init$beta_V <- as.matrix(init$beta_V)
  init$beta_m <- as.numeric(init$beta_m)
  init$sigma <- as.numeric(init$sigma)
  stopifnot(identical(payload$schema, iqct_v6_schema), is.null(init$beta_state),
    identical(payload$initialization_digest, iqct_v6_init_digest(init)),
    identical(payload$source_sha256, cfg$source$frozen_sha256),
    identical(payload$reference_config_sha256, cfg$baseline_config_sha256),
    identical(payload$probability, cfg$probability), identical(payload$likelihood, cfg$likelihood_family),
    nrow(init$beta_V) == length(init$beta_m), ncol(init$beta_V) == length(init$beta_m),
    all(is.finite(init$beta_V)), all(is.finite(init$beta_m)), init$sigma > 0)
  prior <- exdqlm:::exal_make_beta_prior(type = "rhs_ns",
    rhs = list(tau0 = cfg$candidate$rhs_tau0, s2 = cfg$rhs_s2,
      shrink_intercept = FALSE, n_inner = 2L))
  state <- prior$init(length(init$beta_m))
  precision <- prior$expected_prec(state, length(init$beta_m))
  stopifnot(abs(state$tau2 - cfg$candidate$rhs_tau0^2) <= 1e-12,
    !state$shrink_intercept, state$iter == 0L)
  artifact <- iqfr_v2_write_json(list(schema = iqct_v6_schema, job_id = cfg$job_id,
    initialization_digest = payload$initialization_digest,
    initializer_sha256 = cfg$frozen_initializer_sha256,
    reference_tau0 = payload$reference_tau0, arm_tau0 = cfg$candidate$rhs_tau0,
    fresh_RHS_state = TRUE, initial_tau2 = state$tau2,
    initial_median_nonintercept_precision = median(precision[-1L]),
    initial_intercept_precision = precision[1L], beta_state_transferred = FALSE),
    file.path(cfg$run_root, "fit_diagnostics", cfg$job_id, "initialization.json"))
  do.call(RNGkind, as.list(payload$rng_kind))
  assign(".Random.seed", as.integer(payload$rng_after_normal), envir = .GlobalEnv)
  list(init = init, artifact = c(initialization = artifact))
}

iqct_v6_assert_initial_design <- function(cfg, X) {
  payload <- iqfr_v2_read_json(cfg$frozen_initializer_path)
  if (!identical(digest::digest(X, algo = "sha256"), payload$design_sha256)) {
    stop("Frozen initializer and quantile fit designs differ.")
  }
  invisible(TRUE)
}

iqct_v6_input_paths <- function(repo, baseline_run) {
  p <- read.csv(file.path(baseline_run, "plan.csv"))
  p <- p[p$mode == "full", ]
  stopifnot(nrow(p) == 2L,
    all(vapply(seq_len(nrow(p)), function(i) iqcb_v4_status_valid(p$config_path[i], p$status_path[i]), TRUE)))
  environment <- iqfr_v2_read_json(file.path(baseline_run, "environment.json"))
  paths <- c(file.path(baseline_run, c("plan.csv", "comparison.csv", "decision.json", "environment.json", "final_artifact_manifest.csv")),
    file.path(environment$prior_run, c("summaries/development_comparators.csv",
      "manifests/broad_candidates.csv", "plans/broad_screen.csv")),
    p$config_path, p$status_path, p$result_path,
    unlist(lapply(p$status_path, function(path) unlist(iqfr_v2_read_json(path)$artifact_paths))))
  unique(paths)
}

iqct_v6_verify_inputs <- function(run) {
  for (name in c("source_hashes.csv", "input_hashes.csv", "materialization_hashes.csv"))
    iqbs_v5_verify_manifest(file.path(run, name))
  invisible(TRUE)
}

iqct_v6_materialize <- function(repo, baseline_run, run) {
  if (dir.exists(run)) stop("Refusing to overwrite an existing v6 run.")
  if (length(system2("git", c("status", "--porcelain"), stdout = TRUE))) stop("Freeze a clean dedicated branch first.")
  iqbs_v5_verify_manifest(file.path(baseline_run, "final_artifact_manifest.csv"))
  iqbs_v5_verify_manifest(file.path(baseline_run, "source_hashes.csv"))
  baseline_environment <- iqfr_v2_read_json(file.path(baseline_run, "environment.json"))
  stopifnot(identical(baseline_environment$head, "7cd8477267b3abb4cab11eb9e47f57b754a911f8"))
  tests_path <- file.path(repo, "validation/fitforecast_v2/local_trackers/coupled_tau_v6_tests_20261001/test_results.csv")
  smoke_path <- file.path(repo, "validation/fitforecast_v2/local_trackers/coupled_tau_v6_smoke_20261001/smoke_summary.csv")
  tests <- read.csv(tests_path); smoke <- read.csv(smoke_path)
  stopifnot(nrow(tests) > 0, all(tests$failed == 0), !any(tests$error),
    nrow(smoke) == 4L, all(smoke$pass))
  old_plan <- read.csv(file.path(baseline_run, "plan.csv")); old_plan <- old_plan[old_plan$mode == "full", ]
  stopifnot(setequal(old_plan$candidate_id, iqct_v6_reference_ids))
  input_paths <- iqct_v6_input_paths(repo, baseline_run)
  configs <- list(); rows <- list()
  for (i in seq_len(nrow(old_plan))) {
    original <- iqfr_v2_read_json(old_plan$config_path[i])
    initializer <- file.path(run, "initializers", paste0(original$candidate$candidate_id, ".json"))
    iqct_v6_prepare_initializer(original, initializer)
    for (multiplier in iqct_v6_multipliers) {
      cfg <- original
      cfg$schema_version <- iqct_v6_schema
      cfg$stage <- if (multiplier == 1) "reference_replay" else "tau_screen"
      cfg$tau_multiplier <- multiplier
      cfg$job_id <- paste0("coupled_tau_v6__", original$candidate$candidate_id,
        "__", gsub("[.]", "p", as.character(multiplier)), "x")
      cfg$repo_root <- repo; cfg$run_root <- run
      cfg$baseline_config_path <- old_plan$config_path[i]
      cfg$baseline_config_sha256 <- iqfr_v2_sha256(old_plan$config_path[i])
      cfg$baseline_result_path <- old_plan$result_path[i]
      cfg$baseline_result_sha256 <- iqfr_v2_sha256(old_plan$result_path[i])
      cfg$baseline_candidate_id <- original$candidate$candidate_id
      cfg$frozen_initializer_path <- initializer
      cfg$frozen_initializer_sha256 <- iqfr_v2_sha256(initializer)
      cfg$beta_covariance_approximation <- "full"
      cfg$collect_solver_diagnostics <- TRUE
      cfg$candidate$rhs_tau0 <- original$candidate$rhs_tau0 * multiplier
      cfg$candidate$rhs_tau0_source_scale <- original$candidate$rhs_tau0_source_scale * multiplier
      cfg$candidate$tau0_multiplier <- multiplier
      cfg$candidate$tau_arm <- paste0("coupled_", multiplier, "x")
      cfg$candidate$candidate_signature <- paste(iqct_v6_schema, original$candidate$candidate_signature,
        format(cfg$candidate$rhs_tau0, digits = 17), sep = "|")
      cfg$candidate$candidate_id <- paste0("iqct6_", substr(digest::digest(cfg$candidate$candidate_signature,
        algo = "sha256", serialize = FALSE), 1L, 16L))
      cfg$config_path <- file.path(run, "configs", paste0(cfg$job_id, ".json"))
      cfg$status_path <- file.path(run, "status", paste0(cfg$job_id, ".json"))
      suffixes <- c(result_path = ".csv", metric_draw_path = "__metric_draws.csv.gz",
        origin_lead_path = "__origin_lead.csv.gz", lead_profile_path = "__lead_profile.csv",
        origin_profile_path = "__origin_profile.csv", origin_block_path = "__origin_blocks.csv")
      for (k in names(suffixes)) cfg[[k]] <- file.path(run, "results", paste0(cfg$job_id, suffixes[[k]]))
      stopifnot(iqct_v6_science_check(original, cfg))
      iqfr_v2_write_json(cfg, cfg$config_path)
      configs[[length(configs) + 1L]] <- cfg
      rows[[length(rows) + 1L]] <- data.frame(job_id = cfg$job_id, stage = cfg$stage,
        baseline_candidate_id = original$candidate$candidate_id, family = original$candidate$family,
        likelihood = cfg$likelihood_family, probability = cfg$probability,
        tau_multiplier = multiplier, tau0 = cfg$candidate$rhs_tau0,
        config_path = cfg$config_path, config_sha256 = iqfr_v2_sha256(cfg$config_path),
        status_path = cfg$status_path, result_path = cfg$result_path)
    }
    input_paths <- c(input_paths, original$source$frozen_path)
  }
  p <- do.call(rbind, rows)
  p <- p[order(p$stage != "reference_replay", p$probability, p$tau_multiplier), ]
  iqfr_v2_write_csv(p, file.path(run, "plan.csv"))
  old_environment <- iqfr_v2_read_json(file.path(baseline_run, "environment.json"))
  old_bank <- read.csv(file.path(old_environment$prior_run, "manifests/broad_candidates.csv"))
  wide <- old_bank[old_bank$family == "normal" & old_bank$likelihood_family == "al" &
    old_bank$probability == .05 & old_bank$tau0_multiplier == 1, ]
  wide <- wide[order(-wide$readout_dimension, wide$candidate_id), ][1L, ]
  stopifnot(wide$readout_dimension > 250L)
  old_jobs <- read.csv(file.path(old_environment$prior_run, "plans/broad_screen.csv"))
  wide_job <- old_jobs[old_jobs$candidate_id == wide$candidate_id, ]
  stopifnot(nrow(wide_job) == 1L,
    identical(iqfr_v2_sha256(wide_job$config_path), wide_job$config_sha256))
  wide_cfg <- iqfr_v2_read_json(wide_job$config_path)
  iqfr_v2_write_json(list(schema = iqct_v6_schema, candidate = wide_cfg$candidate,
    source = wide_cfg$source, fit_end = wide_cfg$fit_end, probability = .05,
    source_config_path = wide_job$config_path, source_config_sha256 = wide_job$config_sha256,
    purpose = "unit_weight_coupled_solve_cost_benchmark_not_a_quantile_fit",
    timeout_seconds = 1800L), file.path(run, "wide_benchmark_config.json"))
  input_paths <- c(input_paths, wide_job$config_path)
  stopifnot(all(file.exists(input_paths)))
  input_manifest <- iqbs_v5_hash_manifest(input_paths, file.path(run, "input_hashes.csv"))
  source_paths <- c(list.files(file.path(repo, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "src"), full.names = TRUE, pattern = "[.](cpp|c|h|so)$"),
    list.files(file.path(repo, "validation/fitforecast_v2/R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), full.names = TRUE, pattern = "coupled_tau_v6"),
    list.files(file.path(repo, "validation/fitforecast_v2/tests/testthat"), full.names = TRUE, pattern = "coupled-tau-v6"),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_COUPLED_TAU_V6_PLAN_20261001.md"))
  iqbs_v5_hash_manifest(source_paths, file.path(run, "source_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqct_v6_schema,
    head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    baseline_run = baseline_run, jobs = 8L, reference_replays = 2L, new_tau_fits = 6L,
    concurrency = 6L, automatic_screen_expansion = FALSE, article_promotion = FALSE,
    package_version = as.character(packageVersion("exdqlm")),
    runtime = "pkgload_source_not_unmodified_CRAN_binary", R_version = R.version.string,
    blas_lapack = as.list(extSoftVersion()), session_info = capture.output(sessionInfo()),
    thread_environment = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    tests_path = tests_path, smoke_path = smoke_path,
    initialization_policy = "same_reference_normal_beta_sigma_fresh_arm_RHS_state",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(run, "environment.json"))
  initializers <- unique(vapply(configs, `[[`, "", "frozen_initializer_path"))
  iqbs_v5_hash_manifest(c(file.path(run, c("plan.csv", "source_hashes.csv", "environment.json", "wide_benchmark_config.json")),
    input_manifest, p$config_path, initializers, tests_path, smoke_path), file.path(run, "materialization_hashes.csv"))
  p
}

iqct_v6_worker <- function(path) {
  cfg <- iqfr_v2_read_json(path)
  iqct_v6_verify_inputs(cfg$run_root)
  original <- iqfr_v2_read_json(cfg$baseline_config_path)
  stopifnot(iqct_v6_science_check(original, cfg),
    identical(iqfr_v2_sha256(cfg$baseline_config_path), cfg$baseline_config_sha256),
    identical(iqfr_v2_sha256(cfg$baseline_result_path), cfg$baseline_result_sha256))
  env <- iqfr_v2_read_json(file.path(cfg$run_root, "environment.json"))
  stopifnot(identical(env$head, system2("git", c("rev-parse", "HEAD"), stdout = TRUE)))
  if (iqcb_v4_status_valid(path, cfg$status_path)) return(invisible("ALREADY_COMPLETE"))
  iqbs_v5_progress(cfg, "STARTED")
  iqcf_v3_run_job(path)
  iqbs_v5_progress(cfg, "COMPLETE")
}

iqct_v6_replay_gate <- function(run) {
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "reference_replay", ]
  stopifnot(nrow(p) == 2L)
  rows <- lapply(seq_len(nrow(p)), function(i) {
    cfg <- iqfr_v2_read_json(p$config_path[i])
    valid <- iqcb_v4_status_valid(p$config_path[i], p$status_path[i])
    replay <- if (valid) iqbs_v5_replay_check(read.csv(cfg$baseline_result_path), read.csv(cfg$result_path)) else
      list(pass = FALSE, max_error = Inf)
    data.frame(job_id = cfg$job_id, pass = valid && replay$pass, maximum_error = replay$max_error)
  })
  x <- do.call(rbind, rows)
  iqfr_v2_write_csv(x, file.path(run, "reference_replay_audit.csv"))
  if (!all(x$pass)) stop("Frozen-init reference replay failed; hold all tau scheduling.")
  iqct_v6_verify_inputs(run)
  invisible(TRUE)
}

iqct_v6_health <- function(run) {
  p <- read.csv(file.path(run, "plan.csv"))
  exits_path <- file.path(run, "launcher_exit_codes.csv")
  exits <- if (file.exists(exits_path)) read.csv(exits_path) else data.frame()
  p$status <- vapply(seq_len(nrow(p)), function(i) {
    s <- iqcb_v4_status_payload(p$status_path[i])
    if (nrow(exits)) {
      slot <- match(i, which(p$stage == p$stage[i])) - 1L
      e <- exits[exits$stage == p$stage[i] & exits$slot == slot, ]
      if (nrow(e) && any(e$exit_code != 0)) return(paste0("FAILED_EXIT_", tail(e$exit_code, 1L)))
    }
    if (is.null(s)) return("PENDING")
    if (s$status == "SUCCESS" && !iqcb_v4_status_valid(p$config_path[i], p$status_path[i])) return("STALE_SUCCESS")
    s$status
  }, "")
  p$phase <- vapply(p$job_id, function(id) {
    path <- file.path(run, "progress", paste0(id, ".json"))
    if (file.exists(path)) iqfr_v2_read_json(path)$phase else "NOT_STARTED"
  }, "")
  p[c("job_id", "stage", "tau_multiplier", "status", "phase")]
}

iqct_v6_audit <- function(run) {
  iqct_v6_verify_inputs(run)
  p <- read.csv(file.path(run, "plan.csv")); h <- iqct_v6_health(run)
  if (!all(h$status == "SUCCESS")) stop("Incomplete v6 campaign; no final selection.")
  iqct_v6_replay_gate(run)
  env <- iqfr_v2_read_json(file.path(run, "environment.json"))
  old_env <- iqfr_v2_read_json(file.path(env$baseline_run, "environment.json"))
  comparators <- read.csv(file.path(old_env$prior_run, "summaries/development_comparators.csv"))
  records <- list()
  for (i in seq_len(nrow(p))) {
    cfg <- iqfr_v2_read_json(p$config_path[i]); z <- read.csv(cfg$result_path)
    root <- file.path(run, "fit_diagnostics", cfg$job_id)
    summary <- iqfr_v2_read_json(file.path(root, "summary.json"))
    initial <- iqfr_v2_read_json(file.path(root, "initialization.json"))
    paths <- read.csv(file.path(root, "fit_paths.csv"))
    moments <- read.csv(file.path(root, "beta_moments.csv"))
    oracle <- z[z$estimator == "mean_conditional_location", ]
    pooled <- z[z$estimator == "posterior_predictive_quantile_pooled", ]
    constant <- z[z$estimator == "training_empirical_quantile_baseline", ]
    comparator <- comparators[comparators$family == cfg$candidate$family &
      comparators$probability == cfg$probability & comparators$likelihood_family == cfg$likelihood_family, ]
    stopifnot(nrow(comparator) == 1L, nrow(oracle) == 1L, nrow(pooled) == 1L,
      summary$full_frozen_moment_residual < 1e-6, summary$covariance_min_eigenvalue > 0,
      all(is.finite(c(oracle$forecast_qtrue_mae, pooled$forecast_check_loss, summary$fit_point_rmse))))
    records[[i]] <- data.frame(job_id = cfg$job_id, baseline_candidate_id = cfg$baseline_candidate_id,
      family = cfg$candidate$family, likelihood = cfg$likelihood_family, probability = cfg$probability,
      tau_multiplier = cfg$tau_multiplier, tau0 = cfg$candidate$rhs_tau0,
      tau0_source_scale = cfg$candidate$rhs_tau0_source_scale,
      forecast_mae = oracle$forecast_qtrue_mae, pooled_check_loss = pooled$forecast_check_loss,
      fit_point_rmse = summary$fit_point_rmse, fit_draw_rmse_mean = summary$fit_draw_rmse_mean,
      constant_forecast_mae = constant$forecast_qtrue_mae,
      comparator_forecast_mae = comparator$forecast_qtrue_mae,
      comparator_check_loss = comparator$forecast_check_loss,
      fitted_path_sd = sd(paths$coefficient_mean_path), true_path_sd = sd(paths$q_true),
      nonintercept_precision = median(moments$prior_precision[-1L]),
      initializer_digest = initial$initialization_digest, design_hash = summary$design_sha256,
      vb_converged = summary$vb_converged, vb_iterations = summary$vb_iterations,
      sigma = summary$sigma_mean, gamma = summary$gamma_mean)
  }
  z <- do.call(rbind, records)
  control <- z[z$tau_multiplier == 1, c("baseline_candidate_id", "forecast_mae", "pooled_check_loss", "initializer_digest", "design_hash")]
  names(control)[-1L] <- paste0("reference_", names(control)[-1L])
  z <- merge(z, control, by = "baseline_candidate_id", sort = FALSE)
  stopifnot(all(z$initializer_digest == z$reference_initializer_digest), all(z$design_hash == z$reference_design_hash))
  z$mae_gain <- z$reference_forecast_mae - z$forecast_mae
  z$check_gain <- z$reference_pooled_check_loss - z$pooled_check_loss
  z$beats_constant <- z$forecast_mae < z$constant_forecast_mae
  z$beats_matched_comparator <- z$forecast_mae < z$comparator_forecast_mae
  z$dynamic_sd_ratio <- z$fitted_path_sd / z$true_path_sd
  iqfr_v2_write_csv(z, file.path(run, "comparison.csv"))
  winners <- lapply(split(z, z$baseline_candidate_id), function(x) {
    rbind(transform(x[which.min(x$forecast_mae), ], selected_metric = "forecast_mae"),
      transform(x[which.min(x$pooled_check_loss), ], selected_metric = "pooled_check_loss"))
  })
  winners <- do.call(rbind, winners)
  iqfr_v2_write_csv(winners, file.path(run, "per_case_internal_winners.csv"))
  supports <- any(z$tau_multiplier != 1 & z$mae_gain > 0)
  iqfr_v2_write_json(list(schema = iqct_v6_schema, jobs = 8L,
    decision = if (supports) "TAU_GAIN_SUPPORTS_BOUNDED_WIDE_BENCHMARK" else "NO_MAE_GAIN_INSPECT_PRIOR_VB_FEEDBACK",
    any_forecast_mae_gain = supports, any_check_loss_gain = any(z$tau_multiplier != 1 & z$check_gain > 0),
    any_beats_matched_comparator = any(z$beats_matched_comparator),
    reference_replay_pass = TRUE, full_solve_pass = TRUE,
    article_promotion = FALSE, automatic_broad_replay = FALSE, automatic_MCMC = FALSE,
    note = "Internal metric-specific selections; no convergence or minimum-gain exclusion."), file.path(run, "decision.json"))
  print(z[c("likelihood", "probability", "tau_multiplier", "forecast_mae", "pooled_check_loss", "fit_point_rmse", "dynamic_sd_ratio", "vb_converged")])
  invisible(supports)
}

iqct_v6_wide_benchmark <- function(run) {
  cfg <- iqfr_v2_read_json(file.path(run, "wide_benchmark_config.json"))
  iqct_v6_verify_inputs(run)
  decision <- iqfr_v2_read_json(file.path(run, "decision.json"))
  stopifnot(isTRUE(decision$any_forecast_mae_gain))
  results <- read.csv(file.path(run, "comparison.csv"))
  winner <- results[results$likelihood == "al" & results$probability == .05, ]
  winner <- winner[which.min(winner$forecast_mae), ]
  if (winner$tau_multiplier == 1) {
    winner <- results[which.max(results$mae_gain), ]
  }
  iqfr_v2_write_json(list(status = "RUNNING", pid = Sys.getpid(),
    candidate_id = cfg$candidate$candidate_id), file.path(run, "wide_benchmark_status.json"))
  source_rows <- iqfr_v2_source_rows(cfg$source$frozen_path)
  stopifnot(identical(iqfr_v2_sha256(cfg$source$frozen_path), cfg$source$frozen_sha256))
  rows <- source_rows$t >= 8501L & source_rows$t <= cfg$fit_end
  transport <- iqcf_v3_response_transport(source_rows, rows)
  y <- transport$forward(source_rows$y)
  preprocess <- iqfr_v2_training_preprocess(y[rows], cfg$candidate$center_scale)
  args <- iqfr_v2_design_args(y[source_rows$t <= cfg$fit_end], cfg$candidate,
    preprocess, p0 = cfg$probability, fit_readout = FALSE)
  args$normal_args <- NULL
  started <- proc.time()[["elapsed"]]
  design <- do.call(qdesn_fit_vb, args)
  design_seconds <- proc.time()[["elapsed"]] - started
  iqfr_v2_assert_design(design, cfg$candidate, sum(rows))
  X <- design$X
  prior <- exdqlm:::exal_make_beta_prior(type = "rhs_ns",
    rhs = list(tau0 = winner$tau0, s2 = 1, shrink_intercept = FALSE, n_inner = 2L))
  precision <- prior$expected_prec(prior$init(ncol(X)), ncol(X))
  started <- proc.time()[["elapsed"]]
  stats <- list(S = crossprod(X), g = as.numeric(crossprod(X, y[rows])))
  solved <- exdqlm:::.exal_beta_solve_from_data_stats(stats, precision)
  solve_seconds <- proc.time()[["elapsed"]] - started
  residual <- sqrt(sum((solved$P %*% solved$sol$x - solved$h)^2)) / max(sqrt(sum(solved$h^2)), 1e-12)
  stopifnot(is.finite(residual), residual < 1e-6,
    all(is.finite(solved$sol$inv)), all(diag(solved$sol$inv) > 0))
  rss <- readLines("/proc/self/status")
  rss <- rss[grepl("^Vm(HWM|RSS):", rss)]
  iqfr_v2_write_json(list(schema = iqct_v6_schema, status = "SUCCESS",
    purpose = cfg$purpose, candidate_id = cfg$candidate$candidate_id,
    rows = nrow(X), columns = ncol(X), D = cfg$candidate$D, n = cfg$candidate$n,
    m = cfg$candidate$m, identity_Q = all(design$reservoir$Q_is_identity),
    tau0 = winner$tau0, tau_source_case = winner$baseline_candidate_id,
    weights = "unit_weights_for_numerical_cost_only",
    design_seconds = design_seconds, crossproduct_and_solve_seconds = solve_seconds,
    residual = residual, solver_method = solved$sol$method, jitter = solved$sol$jitter_eps,
    design_sha256 = digest::digest(X, algo = "sha256"),
    matrix_bytes_estimate = as.numeric(object.size(stats$S)) + as.numeric(object.size(solved$sol$inv)),
    process_memory = rss, quantile_fit_performed = FALSE,
    fitted_model_binaries = 0L), file.path(run, "wide_benchmark_status.json"))
  invisible(TRUE)
}
