iqdr_v7_schema <- "independent_qdesn_coupled_design_v7"
iqdr_v7_design_ids <- c(
  "iqcb4_normal_al_p005_acc5a4e1a159", "iqcb4_normal_al_p005_3ed9396c0484",
  "iqcb4_normal_al_p005_462ef9273443", "iqcb4_normal_exal_p025_7ab7e7c72b85",
  "iqcb4_normal_exal_p025_f52df3dcb74e", "iqcb4_normal_exal_p025_ad5e720aaf0d")

iqdr_v7_source <- function(repo) {
  source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_coupled_tau_v6.R"), local = FALSE)
  iqct_v6_source(repo)
}

iqdr_v7_case <- function(cfg) paste(cfg$candidate$family, cfg$likelihood_family,
  sprintf("p%03d", as.integer(round(cfg$probability * 100))), sep = "_")

iqdr_v7_expected_contract <- function(reference, stage) {
  if (stage == "engineering_cost_smoke") {
    reference$budget <- list(max_iter = 8L, tol = 0L, n_samp_xi = 64L)
    reference$outer_draws <- 4L
    reference$inner_path_grid <- 32L
    reference$origins <- list(start = 8750L, end = 8755L, stride = 5L)
  } else if (stage != "design_replay") stop("Unknown v7 stage.")
  reference
}

iqdr_v7_science_check <- function(original, reference, cfg) {
  expected <- iqdr_v7_expected_contract(reference, cfg$stage)
  fixed <- setdiff(iqbs_v5_science_fields, "candidate")
  candidate_fixed <- setdiff(union(names(original$candidate), names(cfg$candidate)), iqct_v6_candidate_fields)
  tau <- cfg$candidate$rhs_tau0
  same <- all(vapply(fixed, function(k) identical(expected[[k]], cfg[[k]]), TRUE)) &&
    all(vapply(candidate_fixed, function(k) identical(original$candidate[[k]], cfg$candidate[[k]]), TRUE))
  same && identical(cfg$beta_covariance_approximation, "full") &&
    identical(iqdr_v7_case(original), iqdr_v7_case(reference)) &&
    identical(original$source$frozen_sha256, reference$source$frozen_sha256) &&
    is.finite(tau) && tau %in% cfg$allowed_model_tau0 &&
    abs(cfg$candidate$rhs_tau0_source_scale - tau * cfg$response_scale_frozen) <= 1e-10 &&
    abs(cfg$candidate$tau0_multiplier - tau / original$candidate$rhs_tau0) <= 1e-10
}

iqdr_v7_config <- function(original, reference, tau, repo, run, initializer, stage) {
  cfg <- iqdr_v7_expected_contract(reference, stage)
  cfg$candidate <- original$candidate
  cfg$stage <- stage; cfg$schema_version <- iqdr_v7_schema
  cfg$repo_root <- repo; cfg$run_root <- run
  cfg$case_id <- iqdr_v7_case(reference)
  cfg$source_design_id <- original$candidate$candidate_id
  cfg$baseline_config_path <- original$config_path
  cfg$baseline_config_sha256 <- iqfr_v2_sha256(original$config_path)
  cfg$reference_config_path <- reference$config_path
  cfg$reference_config_sha256 <- iqfr_v2_sha256(reference$config_path)
  cfg$baseline_candidate_id <- reference$baseline_candidate_id
  cfg$frozen_initializer_path <- initializer
  cfg$frozen_initializer_sha256 <- iqfr_v2_sha256(initializer)
  payload <- iqfr_v2_read_json(initializer)
  cfg$response_scale_frozen <- payload$response_scale
  cfg$allowed_model_tau0 <- as.numeric(c(.0998613997947909, .998613997947909))
  cfg$tau_multiplier <- tau / original$candidate$rhs_tau0
  cfg$beta_covariance_approximation <- "full"; cfg$collect_solver_diagnostics <- TRUE
  cfg$candidate$rhs_tau0 <- tau
  cfg$candidate$rhs_tau0_source_scale <- tau * payload$response_scale
  cfg$candidate$tau0_multiplier <- cfg$tau_multiplier
  cfg$candidate$tau_arm <- if (tau < .5) "explicit_model_tau_low" else "explicit_model_tau_high"
  cfg$candidate$candidate_signature <- paste(iqdr_v7_schema, original$candidate$candidate_signature,
    format(tau, digits = 17), "full_beta", "case_paired_forecast_seed", stage, sep = "|")
  cfg$candidate$candidate_id <- paste0("iqdr7_", substr(digest::digest(
    cfg$candidate$candidate_signature, algo = "sha256", serialize = FALSE), 1L, 16L))
  cfg$job_id <- paste("coupled_design_v7", cfg$case_id, original$candidate$candidate_id,
    if (tau < .5) "low" else "high", stage, sep = "__")
  cfg$config_path <- file.path(run, "configs", paste0(cfg$job_id, ".json"))
  cfg$status_path <- file.path(run, "status", paste0(cfg$job_id, ".json"))
  suffixes <- c(result_path = ".csv", metric_draw_path = "__metric_draws.csv.gz",
    origin_lead_path = "__origin_lead.csv.gz", lead_profile_path = "__lead_profile.csv",
    origin_profile_path = "__origin_profile.csv", origin_block_path = "__origin_blocks.csv")
  for (k in names(suffixes)) cfg[[k]] <- file.path(run, "results", paste0(cfg$job_id, suffixes[[k]]))
  stopifnot(iqdr_v7_science_check(original, reference, cfg))
  cfg
}

iqdr_v7_materialize <- function(repo, baseline_run, run) {
  if (dir.exists(run)) stop("Refusing to overwrite an existing v7 run.")
  stopifnot(!length(system2("git", c("status", "--porcelain"), stdout = TRUE)))
  iqct_v6_verify_inputs(baseline_run)
  iqbs_v5_verify_manifest(file.path(baseline_run, "final_artifact_manifest.csv"))
  env <- iqfr_v2_read_json(file.path(baseline_run, "environment.json"))
  stopifnot(env$head == "1b40f7dfef7cc2b65ed39e389af51bfea9d50871",
    all(iqct_v6_health(baseline_run)$status == "SUCCESS"))
  tests_path <- file.path(repo, "validation/fitforecast_v2/local_trackers/coupled_design_v7_tests_20261002/test_results.csv")
  smoke_path <- file.path(repo, "validation/fitforecast_v2/local_trackers/coupled_design_v7_smoke_20261002/smoke_summary.csv")
  tests <- read.csv(tests_path); smoke <- read.csv(smoke_path)
  stopifnot(nrow(tests) > 0, all(tests$failed == 0), !any(tests$error),
    all(tests$warning == 0), nrow(smoke) == 4L, all(smoke$pass))
  prior_env <- iqfr_v2_read_json(file.path(env$baseline_run, "environment.json"))
  bank_path <- file.path(prior_env$prior_run, "manifests/broad_candidates.csv")
  plan_path <- file.path(prior_env$prior_run, "plans/broad_screen.csv")
  comparator_path <- file.path(prior_env$prior_run, "summaries/development_comparators.csv")
  old <- read.csv(plan_path)
  selected <- old[match(iqdr_v7_design_ids, old$candidate_id), ]
  stopifnot(nrow(selected) == 6L, !anyNA(selected$config_path),
    all(unname(tools::sha256sum(selected$config_path)) == selected$config_sha256))
  v6 <- read.csv(file.path(baseline_run, "plan.csv"))
  controls <- v6[v6$tau_multiplier %in% c(30, 300), ]
  stopifnot(nrow(controls) == 4L)
  controls$case_id <- vapply(controls$config_path, function(p) iqdr_v7_case(iqfr_v2_read_json(p)), "")
  taus <- sort(unique(controls$tau0))
  stopifnot(length(taus) == 2L, max(abs(taus - c(.0998613997947909, .998613997947909))) < 1e-14)
  control_path <- iqfr_v2_write_csv(controls, file.path(run, "cached_controls.csv"))
  configs <- list(); initializers <- character(); provenance <- list()
  for (i in seq_len(nrow(selected))) {
    original <- iqfr_v2_read_json(selected$config_path[i])
    original$config_path <- selected$config_path[i]
    case <- iqdr_v7_case(original)
    ref_path <- controls$config_path[controls$case_id == case][1L]
    reference <- iqfr_v2_read_json(ref_path); reference$config_path <- ref_path
    initializer <- file.path(run, "initializers", paste0(original$candidate$candidate_id, ".json"))
    iqct_v6_prepare_initializer(original, initializer)
    initializers <- c(initializers, initializer)
    provenance[[i]] <- data.frame(source_design_id = original$candidate$candidate_id,
      source_config = original$config_path, source_sha256 = iqfr_v2_sha256(original$config_path),
      case_id = case, original_forecast_seed = original$seed, paired_forecast_seed = reference$seed,
      initializer_reference_tau0 = original$candidate$rhs_tau0,
      initializer_sha256 = iqfr_v2_sha256(initializer), D = original$candidate$D,
      n = original$candidate$n, m = original$candidate$m, alpha = original$candidate$alpha,
      rho = original$candidate$rho, input_gain = original$candidate$input_gain,
      readout_columns = original$candidate$readout_dimension)
    for (tau in taus) configs[[length(configs) + 1L]] <- iqdr_v7_config(
      original, reference, tau, repo, run, initializer, "design_replay")
    if (original$candidate$readout_dimension == 401L) {
      configs[[length(configs) + 1L]] <- iqdr_v7_config(
        original, reference, max(taus), repo, run, initializer, "engineering_cost_smoke")
    }
  }
  rows <- lapply(configs, function(cfg) {
    iqfr_v2_write_json(cfg, cfg$config_path)
    stopifnot(iqdr_v7_science_check(iqfr_v2_read_json(cfg$baseline_config_path),
      iqfr_v2_read_json(cfg$reference_config_path), iqfr_v2_read_json(cfg$config_path)))
    data.frame(job_id = cfg$job_id, stage = cfg$stage, case_id = cfg$case_id,
      source_design_id = cfg$source_design_id, candidate_id = cfg$candidate$candidate_id,
      tau0 = cfg$candidate$rhs_tau0, columns = cfg$candidate$readout_dimension,
      config_path = cfg$config_path, config_sha256 = iqfr_v2_sha256(cfg$config_path),
      status_path = cfg$status_path, result_path = cfg$result_path)
  })
  p <- do.call(rbind, rows)
  p <- p[order(p$stage != "engineering_cost_smoke", -p$columns, p$case_id, p$tau0), ]
  iqfr_v2_write_csv(p, file.path(run, "plan.csv"))
  stopifnot(sum(p$stage == "design_replay") == 12L, sum(p$stage == "engineering_cost_smoke") == 2L)
  provenance_path <- iqfr_v2_write_csv(do.call(rbind, provenance), file.path(run, "design_provenance.csv"))
  inputs <- unique(c(read.csv(file.path(baseline_run, "final_artifact_manifest.csv"))$path,
    read.csv(file.path(baseline_run, "input_hashes.csv"))$path,
    file.path(baseline_run, "final_artifact_manifest.csv"), selected$config_path, bank_path, plan_path, comparator_path))
  stopifnot(all(file.exists(inputs)))
  iqbs_v5_hash_manifest(inputs, file.path(run, "input_hashes.csv"))
  sources <- c(list.files(file.path(repo, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "src"), full.names = TRUE, pattern = "[.](cpp|c|h|so)$"),
    list.files(file.path(repo, "validation/fitforecast_v2/R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), full.names = TRUE, pattern = "coupled_design_v7"),
    list.files(file.path(repo, "validation/fitforecast_v2/tests/testthat"), full.names = TRUE, pattern = "coupled-design-v7"),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_COUPLED_DESIGN_V7_PLAN_20261002.md"))
  iqbs_v5_hash_manifest(sources, file.path(run, "source_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqdr_v7_schema,
    head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE), baseline_run = baseline_run,
    comparator_path = comparator_path, production_jobs = 12L, cost_jobs = 2L, reused_controls = 4L,
    concurrency = 6L, model_tau0 = taus, job_timeout_seconds = 21600L,
    runtime = "pkgload_validation_source_not_unmodified_CRAN_binary",
    package_version = as.character(packageVersion("exdqlm")), R_version = R.version.string,
    session_info = capture.output(sessionInfo()), blas_lapack = as.list(extSoftVersion()),
    thread_environment = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    article_promotion = FALSE, automatic_MCMC = FALSE, automatic_other_cell_expansion = FALSE,
    initialization_policy = "frozen_original_normal_init_per_design_fresh_quantile_arm_RHS_state",
    tests_path = tests_path, smoke_path = smoke_path), file.path(run, "environment.json"))
  iqbs_v5_hash_manifest(c(file.path(run, c("plan.csv", "source_hashes.csv", "input_hashes.csv", "environment.json")),
    control_path, provenance_path, p$config_path, initializers, tests_path, smoke_path),
    file.path(run, "materialization_hashes.csv"))
  p[c("stage", "case_id", "tau0", "columns")]
}

iqdr_v7_run_measured <- function(cfg) {
  original_progress <- iqbs_v5_progress
  phases <- list()
  started <- proc.time()[["elapsed"]]
  assign("iqbs_v5_progress", function(c, phase) {
    original_progress(c, phase)
    phases[[length(phases) + 1L]] <<- data.frame(phase = phase,
      seconds = proc.time()[["elapsed"]] - started)
  }, envir = .GlobalEnv)
  on.exit(assign("iqbs_v5_progress", original_progress, envir = .GlobalEnv), add = TRUE)
  iqbs_v5_progress(cfg, "STARTED")
  iqcf_v3_run_job(cfg$config_path)
  iqbs_v5_progress(cfg, "COMPLETE")
  p <- do.call(rbind, phases)
  time <- function(name) p$seconds[match(name, p$phase)]
  summary <- iqfr_v2_read_json(file.path(cfg$run_root, "fit_diagnostics", cfg$job_id, "summary.json"))
  stopifnot(summary$full_frozen_moment_residual < 1e-6, summary$covariance_min_eigenvalue > 0)
  root <- file.path(cfg$run_root, "timing", cfg$job_id)
  iqfr_v2_write_csv(p, file.path(root, "phases.csv"))
  memory <- readLines("/proc/self/status")
  iqfr_v2_write_json(list(job_id = cfg$job_id, config_sha256 = iqfr_v2_sha256(cfg$config_path),
    stage = cfg$stage, quantile_seconds = time("QUANTILE_VB_COMPLETE") - time("QUANTILE_VB_RUNNING"),
    forecast_and_artifact_seconds = time("COMPLETE") - time("FORECAST_RUNNING"),
    total_seconds = time("COMPLETE"), iterations = summary$vb_iterations,
    memory = memory[grepl("^Vm(HWM|RSS):", memory)]), file.path(root, "worker_timing.json"))
  invisible(TRUE)
}

iqdr_v7_worker <- function(path) {
  cfg <- iqfr_v2_read_json(path)
  iqct_v6_verify_inputs(cfg$run_root)
  env <- iqfr_v2_read_json(file.path(cfg$run_root, "environment.json"))
  stopifnot(env$head == system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    iqfr_v2_sha256(cfg$baseline_config_path) == cfg$baseline_config_sha256,
    iqfr_v2_sha256(cfg$reference_config_path) == cfg$reference_config_sha256,
    iqdr_v7_science_check(iqfr_v2_read_json(cfg$baseline_config_path),
      iqfr_v2_read_json(cfg$reference_config_path), cfg))
  timing <- file.path(cfg$run_root, "timing", cfg$job_id, "worker_timing.json")
  if (iqcb_v4_status_valid(path, cfg$status_path) && file.exists(timing)) return(invisible("ALREADY_COMPLETE"))
  iqdr_v7_run_measured(cfg)
}

iqdr_v7_project_cost <- function(timing) {
  stopifnot(timing$iterations == 8L, is.finite(timing$quantile_seconds),
    is.finite(timing$forecast_and_artifact_seconds), timing$quantile_seconds > 0,
    timing$forecast_and_artifact_seconds > 0)
  timing$quantile_seconds / 8 * 750 + timing$forecast_and_artifact_seconds * 360
}

iqdr_v7_cost_gate <- function(run) {
  iqct_v6_verify_inputs(run)
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "engineering_cost_smoke", ]
  stopifnot(nrow(p) == 2L)
  rows <- lapply(seq_len(nrow(p)), function(i) {
    cfg <- iqfr_v2_read_json(p$config_path[i])
    stopifnot(iqcb_v4_status_valid(cfg$config_path, cfg$status_path))
    timing <- iqfr_v2_read_json(file.path(run, "timing", cfg$job_id, "worker_timing.json"))
    stopifnot(timing$config_sha256 == iqfr_v2_sha256(cfg$config_path), timing$iterations == 8L)
    estimated_seconds <- iqdr_v7_project_cost(timing)
    data.frame(job_id = cfg$job_id, case_id = cfg$case_id,
      measured_fit_seconds = timing$quantile_seconds,
      measured_forecast_and_artifact_seconds = timing$forecast_and_artifact_seconds,
      conservative_projected_seconds = estimated_seconds,
      safety_factor = 2, timeout_seconds = 21600L,
      pass = is.finite(estimated_seconds) && estimated_seconds > 0 && 2 * estimated_seconds < 21600)
  })
  x <- do.call(rbind, rows)
  iqfr_v2_write_csv(x, file.path(run, "cost_gate.csv"))
  if (!all(x$pass)) stop("Cost gate failed; do not schedule production.")
  x
}

iqdr_v7_health <- function(run) {
  p <- read.csv(file.path(run, "plan.csv"))
  exit_path <- file.path(run, "launcher_exit_codes.csv")
  exits <- if (file.exists(exit_path)) read.csv(exit_path) else data.frame()
  p$status <- vapply(seq_len(nrow(p)), function(i) {
    e <- if (nrow(exits)) exits[exits$job_id == p$job_id[i], ] else data.frame()
    if (nrow(e) && tail(e$exit_code, 1) != 0) return(paste0("FAILED_EXIT_", tail(e$exit_code, 1)))
    s <- iqcb_v4_status_payload(p$status_path[i])
    if (is.null(s)) return("PENDING")
    if (s$status == "SUCCESS" && !iqcb_v4_status_valid(p$config_path[i], p$status_path[i])) return("STALE_SUCCESS")
    s$status
  }, "")
  p[c("job_id", "stage", "case_id", "tau0", "columns", "status")]
}

iqdr_v7_record <- function(cfg, provenance) {
  stopifnot(iqcb_v4_status_valid(cfg$config_path, cfg$status_path))
  z <- read.csv(cfg$result_path)
  oracle <- z[z$estimator == "mean_conditional_location", ]
  pooled <- z[z$estimator == "posterior_predictive_quantile_pooled", ]
  root <- file.path(cfg$run_root, "fit_diagnostics", cfg$job_id)
  s <- iqfr_v2_read_json(file.path(root, "summary.json"))
  initial <- iqfr_v2_read_json(file.path(root, "initialization.json"))
  path <- read.csv(file.path(root, "fit_paths.csv"))
  stopifnot(nrow(oracle) == 1L, nrow(pooled) == 1L, s$full_frozen_moment_residual < 1e-6,
    s$covariance_min_eigenvalue > 0, all(is.finite(c(oracle$forecast_qtrue_mae, pooled$forecast_check_loss))))
  data.frame(case_id = iqdr_v7_case(cfg), job_id = cfg$job_id,
    candidate_id = cfg$candidate$candidate_id, provenance = provenance,
    source_design_id = cfg$source_design_id %||% cfg$baseline_candidate_id,
    tau0 = cfg$candidate$rhs_tau0, D = cfg$candidate$D, n = cfg$candidate$n,
    m = cfg$candidate$m, columns = nrow(as.matrix(iqfr_v2_read_json(cfg$frozen_initializer_path)$initialization$beta_V)),
    forecast_mae = oracle$forecast_qtrue_mae, predictive_check_loss = pooled$forecast_check_loss,
    fit_point_rmse = s$fit_point_rmse, fit_bias = mean(path$coefficient_mean_path - path$q_true),
    dynamic_sd_ratio = sd(path$coefficient_mean_path) / sd(path$q_true),
    vb_converged = s$vb_converged, vb_iterations = s$vb_iterations,
    initializer_digest = initial$initialization_digest,
    config_path = cfg$config_path, config_sha256 = iqfr_v2_sha256(cfg$config_path))
}

iqdr_v7_audit <- function(run) {
  iqct_v6_verify_inputs(run)
  h <- iqdr_v7_health(run)
  stopifnot(all(h$status == "SUCCESS"))
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "design_replay", ]
  controls <- read.csv(file.path(run, "cached_controls.csv"))
  records <- c(lapply(p$config_path, function(path) iqdr_v7_record(iqfr_v2_read_json(path), "new_v7")),
    lapply(controls$config_path, function(path) iqdr_v7_record(iqfr_v2_read_json(path), "cached_v6")))
  z <- do.call(rbind, records)
  stopifnot(nrow(z) == 16L)
  env <- iqfr_v2_read_json(file.path(run, "environment.json"))
  comparators <- read.csv(env$comparator_path)
  for (case in unique(z$case_id)) {
    index <- z$case_id == case
    ref <- z[index & z$provenance == "cached_v6", ]
    new <- z[index & z$provenance == "new_v7", ]
    stopifnot(nrow(ref) == 2L, nrow(new) == 6L)
    cfg <- iqfr_v2_read_json(z$config_path[which(index)[1]])
    comparator <- comparators[comparators$family == cfg$candidate$family &
      comparators$likelihood_family == cfg$likelihood_family & comparators$probability == cfg$probability, ]
    stopifnot(nrow(comparator) == 1L)
    z$reference_mae[index] <- min(ref$forecast_mae)
    z$reference_check[index] <- min(ref$predictive_check_loss)
    z$comparator_mae[index] <- comparator$forecast_qtrue_mae
    z$comparator_check[index] <- comparator$forecast_check_loss
    stopifnot(length(unique(new$initializer_digest[new$source_design_id == new$source_design_id[1]])) == 1L)
  }
  for (x in split(z[z$provenance == "new_v7", ], z$source_design_id[z$provenance == "new_v7"]))
    stopifnot(nrow(x) == 2L, length(unique(x$initializer_digest)) == 1L)
  z$mae_gain <- z$reference_mae - z$forecast_mae
  z$check_gain <- z$reference_check - z$predictive_check_loss
  iqfr_v2_write_csv(z, file.path(run, "comparison.csv"))
  winners <- do.call(rbind, lapply(split(z, z$case_id), function(x) rbind(
    transform(x[which.min(x$forecast_mae), ], selected_metric = "forecast_mae"),
    transform(x[which.min(x$predictive_check_loss), ], selected_metric = "predictive_check_loss"))))
  iqfr_v2_write_csv(winners, file.path(run, "per_case_internal_winners.csv"))
  finalists <- winners[winners$provenance == "new_v7" &
    ifelse(winners$selected_metric == "forecast_mae", winners$mae_gain > 0, winners$check_gain > 0), ]
  iqfr_v2_write_csv(finalists, file.path(run, "internal_confirmation_candidates.csv"))
  gain <- nrow(finalists) > 0
  iqfr_v2_write_json(list(schema = iqdr_v7_schema, production_success = 12L, cost_success = 2L,
    cached_controls = 4L, decision = if (gain) "STRICT_INTERNAL_GAIN_PREPARE_CONFIRMATION" else "NO_NEW_GAIN_RETAIN_V6",
    eligible_metric_specific_rows = nrow(finalists), article_promotion = FALSE,
    automatic_MCMC = FALSE, automatic_other_cell_expansion = FALSE,
    diagnostic_exclusion = FALSE, minimum_gain_threshold = 0,
    confirmation_note = "Freeze internal finalists; larger-draw or repeated-seed comparison precedes article-protocol MCMC confirmation."),
    file.path(run, "decision.json"))
  print(winners[c("case_id", "tau0", "n", "selected_metric", "forecast_mae", "predictive_check_loss", "provenance")], row.names = FALSE)
  invisible(TRUE)
}
