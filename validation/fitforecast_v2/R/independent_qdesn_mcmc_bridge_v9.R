iqmb_v9_schema <- "independent_qdesn_mcmc_bridge_v9"
iqmb_v9_stages <- c("cost_smoke", "pilot", "confirmation")

iqmb_v9_source <- function(repo) {
  source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_paired_forecast_v8.R"), local = FALSE)
  iqps_v8_source(repo)
}

iqmb_v9_budget <- function(stage) {
  switch(stage,
    cost_smoke = list(burn = 100L, retained = 200L, outer = 8L, inner = 32L),
    pilot = list(burn = 1000L, retained = 4000L, outer = 120L, inner = 128L),
    confirmation = list(burn = 5000L, retained = 20000L, outer = 300L, inner = 128L),
    stop("Unknown v9 stage."))
}

iqmb_v9_config <- function(ref, stage, index, repo, run) {
  b <- iqmb_v9_budget(stage)
  cfg <- ref
  cfg$schema_version <- iqmb_v9_schema
  cfg$stage <- stage; cfg$chain_index <- as.integer(index)
  cfg$reference_config_path <- ref$config_path
  cfg$reference_config_sha256 <- iqfr_v2_sha256(ref$config_path)
  cfg$repo_root <- repo; cfg$run_root <- run
  cfg$seed <- as.integer(41000000L + match(ref$case_id, c("normal_al_p005", "normal_exal_p025")) * 1000000L +
    match(stage, iqmb_v9_stages) * 10000L + index * 101L)
  cfg$chain_seed <- as.integer(cfg$seed + 500000000L)
  cfg$mcmc_burn <- b$burn; cfg$mcmc_retained <- b$retained
  cfg$outer_draws <- b$outer; cfg$inner_path_grid <- b$inner
  if (stage == "cost_smoke") cfg$origins$end <- cfg$origins$start + cfg$origins$stride
  cfg$job_id <- paste("mcmc_bridge_v9", cfg$case_id, cfg$pair_role, stage, index, sep = "__")
  cfg$config_path <- file.path(run, "configs", paste0(cfg$job_id, ".json"))
  cfg$status_path <- file.path(run, "status", paste0(cfg$job_id, ".json"))
  suffix <- c(result_path = ".csv", metric_draw_path = "__metric_draws.csv.gz",
    origin_lead_path = "__origin_lead.csv.gz", lead_profile_path = "__lead_profile.csv",
    origin_profile_path = "__origin_profile.csv")
  for (k in names(suffix)) cfg[[k]] <- file.path(run, "results", paste0(cfg$job_id, suffix[[k]]))
  cfg
}

iqmb_v9_science_check <- function(ref, cfg) {
  frozen <- c("candidate", "source", "probability", "likelihood_family", "rhs_s2",
    "fit_end", "rollout_end", "horizon", "budget", "frozen_initializer_path",
    "frozen_initializer_sha256", "baseline_config_path", "baseline_config_sha256",
    "beta_covariance_approximation", "case_id", "pair_role", "include_mean_readout_state")
  if (!cfg$stage %in% iqmb_v9_stages) return(FALSE)
  b <- iqmb_v9_budget(cfg$stage)
  origins <- ref$origins
  if (cfg$stage == "cost_smoke") origins$end <- origins$start + origins$stride
  all(vapply(frozen, function(k) identical(ref[[k]], cfg[[k]]), TRUE)) &&
    identical(cfg$origins, origins) && identical(cfg$beta_covariance_approximation, "full") &&
    cfg$mcmc_burn == b$burn && cfg$mcmc_retained == b$retained &&
    cfg$outer_draws == b$outer && cfg$inner_path_grid == b$inner &&
    cfg$chain_index %in% if (cfg$stage == "confirmation") 1:3 else 1L
}

iqmb_v9_materialize <- function(repo, baseline, run, test_path, smoke_path) {
  if (dir.exists(run)) stop("Refusing to overwrite v9 evidence.")
  stopifnot(!length(system2("git", c("status", "--porcelain"), stdout = TRUE)))
  iqct_v6_verify_inputs(baseline)
  iqbs_v5_verify_manifest(file.path(baseline, "final_artifact_manifest.csv"))
  stopifnot(all(iqps_v8_health(baseline)$status == "SUCCESS"))
  tests <- read.csv(test_path); smokes <- read.csv(smoke_path)
  stopifnot(nrow(tests) > 0L, all(tests$failed == 0), !any(tests$error), all(tests$warning == 0),
    nrow(smokes) == 6L, all(smokes$pass))
  p8 <- read.csv(file.path(baseline, "plan.csv"))
  p8 <- p8[p8$stage == "paired_confirmation" & p8$seed_index == 1L, ]
  stopifnot(nrow(p8) == 4L, setequal(p8$case_id, c("normal_al_p005", "normal_exal_p025")))
  configs <- list()
  for (path in p8$config_path) {
    ref <- iqfr_v2_read_json(path)
    stopifnot(ref$fit_end == 8750L, ref$rollout_end == 9000L, ref$horizon == 30L)
    for (stage in iqmb_v9_stages) for (index in if (stage == "confirmation") 1:3 else 1L) {
      cfg <- iqmb_v9_config(ref, stage, index, repo, run)
      iqfr_v2_write_json(cfg, cfg$config_path)
      stopifnot(iqmb_v9_science_check(ref, iqfr_v2_read_json(cfg$config_path)))
      configs[[length(configs) + 1L]] <- cfg
    }
  }
  plan <- do.call(rbind, lapply(configs, function(c) data.frame(job_id = c$job_id,
    stage = c$stage, case_id = c$case_id, pair_role = c$pair_role, chain_index = c$chain_index,
    seed = c$seed, chain_seed = c$chain_seed, tau0 = c$candidate$rhs_tau0, columns = c$candidate$readout_dimension,
    config_path = c$config_path, config_sha256 = iqfr_v2_sha256(c$config_path),
    status_path = c$status_path, result_path = c$result_path)))
  plan <- plan[order(match(plan$stage, iqmb_v9_stages), -plan$columns, plan$case_id, plan$pair_role, plan$chain_index), ]
  stopifnot(nrow(plan) == 20L, !anyDuplicated(plan$job_id))
  iqfr_v2_write_csv(plan, file.path(run, "plan.csv"))
  iqfr_v2_write_csv(p8, file.path(run, "frozen_selection.csv"))
  inputs <- unique(c(read.csv(file.path(baseline, "input_hashes.csv"))$path,
    read.csv(file.path(baseline, "final_artifact_manifest.csv"))$path,
    file.path(baseline, "final_artifact_manifest.csv"), test_path, smoke_path,
    list.files(dirname(test_path), full.names = TRUE),
    list.files(dirname(smoke_path), recursive = TRUE, full.names = TRUE)))
  inputs <- inputs[file.exists(inputs) & !file.info(inputs)$isdir]
  iqbs_v5_hash_manifest(inputs, file.path(run, "input_hashes.csv"))
  sources <- c(list.files(file.path(repo, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "src"), full.names = TRUE, pattern = "[.](cpp|c|h|so)$"),
    list.files(file.path(repo, "validation/fitforecast_v2/R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), full.names = TRUE, pattern = "mcmc_bridge_v9"),
    list.files(file.path(repo, "validation/fitforecast_v2/tests/testthat"), full.names = TRUE, pattern = "mcmc-bridge-v9"),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_MCMC_BRIDGE_V9_PLAN_20261003.md"))
  iqbs_v5_hash_manifest(sources, file.path(run, "source_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqmb_v9_schema, head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    baseline_run = baseline, concurrency = 6L, cost_jobs = 4L, pilot_jobs = 4L,
    maximum_confirmation_jobs = 12L, package_version = as.character(packageVersion("exdqlm")),
    runtime = "pkgload_validation_source_not_unmodified_CRAN_binary", R_version = R.version.string,
    session_info = capture.output(sessionInfo()), blas_lapack = as.list(extSoftVersion()),
    compiler = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"), stdout = TRUE),
    threads = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    warm_start = "verified_v8_full_coupled_VB_explicit_state_no_second_VB",
    RHS_state = "fresh_from_unchanged_prior_not_posterior_reinforcement",
    score_replay_tolerance = 1e-6, minimum_gain_threshold = 0,
    diagnostic_exclusion = FALSE, article_promotion = FALSE, comparator_rerun = FALSE,
    legacy_v2_process_action = "NONE_KEEP_HELD"), file.path(run, "environment.json"))
  iqbs_v5_hash_manifest(c(file.path(run, c("plan.csv", "frozen_selection.csv", "source_hashes.csv",
    "input_hashes.csv", "environment.json")), plan$config_path), file.path(run, "materialization_hashes.csv"))
  plan
}

iqmb_v9_explicit_init <- function(vb, likelihood) {
  init <- list(beta = as.numeric(vb$qbeta$m), sigma = as.numeric(vb$qsiggam$sigma_mean),
    gamma = if (likelihood == "al") 0 else as.numeric(vb$qsiggam$gamma_mean),
    v = as.numeric(vb$qv$E_v), s = as.numeric(vb$qs$E_s))
  stopifnot(all(is.finite(unlist(init))), init$sigma > 0, all(init$v > 0), all(init$s >= 0))
  init
}

iqmb_v9_mcmc_args <- function(cfg, init) {
  list(likelihood_family = cfg$likelihood_family,
    al_fixed_gamma = if (cfg$likelihood_family == "al") 0 else NULL,
    beta_prior_type = "rhs_ns", beta_rhs = list(tau0 = cfg$candidate$rhs_tau0,
      s2 = cfg$rhs_s2, shrink_intercept = FALSE, n_inner = 2L),
    n_burn = cfg$mcmc_burn, n_mcmc = cfg$mcmc_retained, thin = 1L,
    init = init, init_from_vb = FALSE, verbose = TRUE, progress_every = 500L,
    store_latent_draws = FALSE, store_rhs_draws = FALSE,
    sigmagam = exal_make_mcmc_sigmagam_control(),
    slice = list(core_update_mode = if (cfg$likelihood_family == "exal")
      "m0_v_collapsed_support_logit" else "sigma_then_gamma"),
    mcmc_control = list(rng_seed = cfg$chain_seed))
}

iqmb_v9_kernel_check <- function(fit, cfg) {
  expected <- if (cfg$likelihood_family == "exal") "m0_v_collapsed_support_logit" else "sigma_then_gamma"
  stopifnot(identical(fit$diagnostics$core_update_mode, expected),
    !fit$control$init_from_vb, fit$control$rng_seed == cfg$chain_seed,
    fit$control$n_burn == cfg$mcmc_burn, fit$control$thin == 1L,
    fit$beta_prior$type == "rhs_ns", fit$beta_prior$hypers$tau0 == cfg$candidate$rhs_tau0,
    fit$beta_prior$hypers$s2 == cfg$rhs_s2, !fit$beta_prior$hypers$shrink_intercept,
    nrow(fit$samp.beta) == cfg$mcmc_retained,
    all(is.finite(fit$samp.beta)), all(is.finite(fit$samp.sigma)), all(fit$samp.sigma > 0),
    all(is.finite(fit$samp.gamma)))
  if (cfg$likelihood_family == "al") stopifnot(all(fit$samp.gamma == 0),
    fit$diagnostics$core_gamma_refreshes_per_iter == 0L)
  else stopifnot(all(fit$samp.gamma > fit$bounds[1L]), all(fit$samp.gamma < fit$bounds[2L]))
  TRUE
}

iqmb_v9_fit_mcmc <- function(design, cfg, init) {
  args <- iqmb_v9_mcmc_args(cfg, init)
  names <- c("n_burn", "n_mcmc", "thin", "init_from_vb", "verbose", "progress_every",
    "store_latent_draws", "store_rhs_draws", "sigmagam", "slice")
  control <- do.call(exal_make_mcmc_control, args[names])
  # The generic control normalizer drops unknown RNG fields. Pin after normalization.
  control$rng_seed <- cfg$chain_seed
  design$fit <- exal_mcmc_fit(y = design$y_fit, X = design$X, p0 = cfg$probability,
    gamma_bounds = c(L.fn(cfg$probability), U.fn(cfg$probability)),
    likelihood_family = cfg$likelihood_family, al_fixed_gamma = args$al_fixed_gamma,
    mcmc_control = control, init = init,
    prior_gamma = list(mu0 = 0, s20 = 10), prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = exal_make_beta_prior(type = "rhs_ns", rhs = args$beta_rhs))
  design$mu_hat <- as.numeric(design$X %*% design$fit$summary$beta_mean)
  design$meta$inference_method <- "mcmc"
  design
}

iqmb_v9_status_valid <- function(path) {
  cfg <- iqfr_v2_read_json(path)
  if (!iqcb_v4_status_valid(path, cfg$status_path)) return(FALSE)
  s <- iqfr_v2_read_json(cfg$status_path)
  required <- c("warm_contract", "kernel_contract", "timing", "parameter_draws", "mcmc_diagnostics")
  if (!all(required %in% names(s$artifact_paths))) return(FALSE)
  all(vapply(c("warm_contract", "kernel_contract"), function(k) {
    z <- read.csv(s$artifact_paths[[k]])
    nrow(z) > 0L && "pass" %in% names(z) && all(z$pass)
  }, TRUE))
}

iqmb_v9_compute <- function(cfg, verify_warm = TRUE) {
  started <- Sys.time(); clock <- proc.time()[["elapsed"]]
  iqcf_v3_status_write(cfg, "RUNNING", started)
  source <- iqfr_v2_source_rows(cfg$source$frozen_path)
  stopifnot(iqfr_v2_sha256(cfg$source$frozen_path) == cfg$source$frozen_sha256)
  rows <- source$t >= 8501L & source$t <= cfg$fit_end
  train <- source$t <= cfg$fit_end; roll <- source$t <= cfg$rollout_end
  transport <- iqcf_v3_response_transport(source, rows)
  y <- transport$forward(source$y)
  preprocess <- iqfr_v2_training_preprocess(y[rows], cfg$candidate$center_scale)
  iqbs_v5_progress(cfg, "VERIFIED_VB_WARM_RUNNING")
  frozen <- iqct_v6_load_initializer(cfg)
  args <- iqfr_v2_design_args(y[train], cfg$candidate, preprocess, cfg$probability, TRUE)
  args$normal_args <- NULL
  args$vb_args <- list(likelihood_family = cfg$likelihood_family,
    al_fixed_gamma = if (cfg$likelihood_family == "al") 0 else NULL,
    beta_prior_type = "rhs_ns", beta_rhs = list(tau0 = cfg$candidate$rhs_tau0,
      s2 = cfg$rhs_s2, shrink_intercept = FALSE, n_inner = 2L), init = frozen$init,
    max_iter = cfg$budget$max_iter, min_iter_elbo = 10L, tol = cfg$budget$tol,
    tol_par = cfg$budget$tol, n_samp_xi = cfg$budget$n_samp_xi, verbose = FALSE,
    sigmagam = exal_make_vb_sigmagam_control(),
    beta_covariance = list(approximation = "full", label_uncertainty = TRUE))
  vb <- do.call(qdesn_fit_vb, args)
  iqfr_v2_assert_design(vb, cfg$candidate, cfg$fit_end - 8500L)
  iqct_v6_assert_initial_design(cfg, vb$X)
  warm_draws <- exal_posterior_draws(vb$fit, nd = 8L)
  artifacts <- c(frozen$artifact, iqbs_v5_capture_fit(cfg, vb, warm_draws, source, rows, transport))
  ref <- iqfr_v2_read_json(cfg$reference_config_path)
  checked <- if (verify_warm) iqps_v8_fit_check(ref, cfg) else data.frame(
    field = "synthetic_only", maximum_absolute_error = 0, tolerance = 1e-6, pass = TRUE)
  artifacts <- c(artifacts, warm_contract = iqfr_v2_write_csv(checked,
    file.path(cfg$run_root, "checks", paste0(cfg$job_id, "__warm.csv"))))
  stopifnot(all(checked$pass))
  warm_seconds <- proc.time()[["elapsed"]] - clock
  init <- iqmb_v9_explicit_init(vb$fit, cfg$likelihood_family)
  artifacts <- c(artifacts, initial_state = iqfr_v2_write_json(list(values = init,
    policy = "state_only_not_prior", RHS_state = "fresh", prior_tau0 = cfg$candidate$rhs_tau0,
    prior_s2 = cfg$rhs_s2, shrink_intercept = FALSE),
    file.path(cfg$run_root, "initial_states", paste0(cfg$job_id, ".json"))))
  design_hash <- digest::digest(vb$X, algo = "sha256")
  iqbs_v5_progress(cfg, "MCMC_RUNNING")
  begin <- proc.time()[["elapsed"]]
  fit <- iqmb_v9_fit_mcmc(vb, cfg, init)
  mcmc_seconds <- proc.time()[["elapsed"]] - begin
  stopifnot(identical(design_hash, digest::digest(fit$X, algo = "sha256")))
  iqfr_v2_assert_design(fit, cfg$candidate, cfg$fit_end - 8500L)
  iqmb_v9_kernel_check(fit$fit, cfg)
  artifacts <- c(artifacts, kernel_contract = iqfr_v2_write_csv(data.frame(
    field = c("recorded_kernel", "no_second_VB", "exact_design", "finite_draws", "recorded_chain_seed", "unchanged_prior"), pass = TRUE),
    file.path(cfg$run_root, "checks", paste0(cfg$job_id, "__kernel.csv"))))
  f <- fit$fit
  params <- data.frame(draw = seq_len(nrow(f$samp.beta)), sigma = as.numeric(f$samp.sigma),
    gamma = as.numeric(f$samp.gamma), as.data.frame(as.matrix(f$samp.beta)))
  names(params)[-(1:3)] <- paste0("beta_", seq_len(ncol(f$samp.beta)))
  diagnostics <- data.frame(parameter = names(params)[-1L], mean = vapply(params[-1L], mean, 1),
    sd = vapply(params[-1L], sd, 1), ess = vapply(params[-1L], function(x)
      if (sd(x) > 0) as.numeric(coda::effectiveSize(coda::mcmc(x))) else NA_real_, 1))
  root <- file.path(cfg$run_root, "mcmc_diagnostics", cfg$job_id)
  artifacts <- c(artifacts,
    parameter_draws = iqfr_v2_write_csv_gz(params, file.path(root, "parameter_draws.csv.gz")),
    parameter_summary = iqfr_v2_write_csv(diagnostics, file.path(root, "parameter_summary.csv")),
    mcmc_diagnostics = iqfr_v2_write_json(list(kernel = f$diagnostics$core_update_mode,
      control = f$control, diagnostics = f$diagnostics, prior = list(type = f$beta_prior$type,
        hypers = f$beta_prior$hypers), chain_seed = cfg$chain_seed), file.path(root, "summary.json")))
  artifacts <- c(artifacts, scale_shape_trace = iqfr_v2_write_csv_gz(data.frame(
    iteration = seq_along(f$misc$sigma_trace), sigma = f$misc$sigma_trace,
    gamma = f$misc$gamma_trace, post_burn = seq_along(f$misc$sigma_trace) > cfg$mcmc_burn),
    file.path(root,"scale_shape_trace.csv.gz")))
  draws <- exal_posterior_draws(f, nd = cfg$outer_draws, seed = iqfr_v2_seed(cfg$seed, "posterior_draws"))
  moments <- iqbs_v5_fit_summaries(fit$X, f$summary$beta_mean, draws$beta,
    source$q_target[rows], source$y[rows], cfg$probability, transport)
  artifacts <- c(artifacts, mcmc_fit_paths = iqfr_v2_write_csv(cbind(t = source$t[rows], moments$path),
    file.path(root, "fit_paths.csv")), mcmc_fit_draws = iqfr_v2_write_csv_gz(
    cbind(t = source$t[rows], as.data.frame(moments$draws)), file.path(root, "fit_quantile_draws.csv.gz")))
  fit_metrics <- iqcf_v3_fit_metric_draws(fit, draws, source, rows, cfg$probability, transport)
  rollargs <- iqfr_v2_design_args(y[roll], cfg$candidate, preprocess, cfg$probability, FALSE)
  rollargs$normal_args <- NULL; rollargs$vb_args <- list()
  rollout <- iqfr_v2_attach_mcmc_readout(do.call(qdesn_fit_vb, rollargs), fit)
  iqfr_v2_assert_design(rollout, cfg$candidate, cfg$rollout_end - 8500L)
  origins <- seq.int(cfg$origins$start, cfg$origins$end, by = cfg$origins$stride) - 8110L
  iqbs_v5_progress(cfg, "FORECAST_RUNNING")
  begin <- proc.time()[["elapsed"]]
  bank <- iqcf_v3_make_noise_bank(draws, cfg$horizon, length(origins), cfg$inner_path_grid,
    iqfr_v2_seed(cfg$seed, "inner_paths"))
  lattice <- iqcf_v3_nested_lattice(rollout, y_all = y[roll], origins = origins,
    horizon = cfg$horizon, draws = draws, probability = cfg$probability,
    inner_paths = cfg$inner_path_grid, seed = iqfr_v2_seed(cfg$seed, "inner_paths"),
    noise_bank = bank, include_mean_readout_state = FALSE)
  lattice <- iqcf_v3_inverse_lattice(lattice, transport)
  scored <- iqcf_v3_score_nested_lattice(lattice, source, 8110L)
  forecast_seconds <- proc.time()[["elapsed"]] - begin
  points <- scored$point_metrics
  stopifnot(all(is.finite(as.matrix(points[c("forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss")]))))
  points$fit_point_rmse <- moments$scores$fit_point_rmse
  points$fit_point_check_loss <- moments$scores$fit_point_check_loss
  points$case_id <- cfg$case_id; points$pair_role <- cfg$pair_role
  points$chain_index <- cfg$chain_index; points$inference <- "mcmc"
  points$inner_paths <- cfg$inner_path_grid; points$outer_draws <- cfg$outer_draws
  points$forecast_pairs <- length(origins) * cfg$horizon
  metric_draws <- merge(scored$metric_draws, fit_metrics,
    by = c("posterior_draw", "posterior_source_draw_index"), sort = FALSE)
  artifacts <- c(artifacts,
    result = iqfr_v2_write_csv(points, cfg$result_path),
    metric_draws = iqfr_v2_write_csv_gz(metric_draws, cfg$metric_draw_path),
    origin_lead = iqfr_v2_write_csv_gz(scored$origin_lead, cfg$origin_lead_path),
    lead_profile = iqfr_v2_write_csv(scored$lead_profile, cfg$lead_profile_path),
    origin_profile = iqfr_v2_write_csv(scored$origin_profile, cfg$origin_profile_path))
  profile <- scored$origin_lead[scored$origin_lead$estimator == "mean_conditional_location", ]
  point <- points[points$estimator == "mean_conditional_location", ]
  forecast_draws <- do.call(rbind, lattice$oracle_location$mean_conditional_location)
  artifacts <- c(artifacts, forecast_location_draws = iqfr_v2_write_csv_gz(
    cbind(profile[c("source_origin", "lead", "source_target")], as.data.frame(forecast_draws)),
    file.path(root, "forecast_location_draws.csv.gz")))
  stopifnot(nrow(point) == 1L, nrow(profile) == length(origins) * cfg$horizon,
    abs(mean(profile$absolute_oracle_error) - point$forecast_qtrue_mae) < 1e-6,
    abs(mean(profile$check_loss) - point$forecast_check_loss) < 1e-6)
  artifacts <- c(artifacts, timing = iqfr_v2_write_json(list(warm_seconds = warm_seconds,
    mcmc_seconds = mcmc_seconds, forecast_seconds = forecast_seconds,
    total_seconds = proc.time()[["elapsed"]] - clock, burn = cfg$mcmc_burn,
    retained = cfg$mcmc_retained, origins = length(origins), horizon = cfg$horizon,
    outer = cfg$outer_draws, inner = cfg$inner_path_grid,
    memory = grep("^Vm(HWM|RSS):", readLines("/proc/self/status"), value = TRUE)),
    file.path(root, "timing.json")))
  iqbs_v5_progress(cfg, "COMPLETE")
  iqcf_v3_status_write(cfg, "SUCCESS", started, list(artifact_paths = as.list(artifacts),
    artifact_sha256 = lapply(artifacts, iqfr_v2_sha256), fitted_model_binaries = 0L))
  stopifnot(iqmb_v9_status_valid(cfg$config_path))
  invisible(points)
}

iqmb_v9_worker <- function(path) {
  cfg <- iqfr_v2_read_json(path)
  iqct_v6_verify_inputs(cfg$run_root)
  env <- iqfr_v2_read_json(file.path(cfg$run_root, "environment.json"))
  ref <- iqfr_v2_read_json(cfg$reference_config_path)
  stopifnot(env$head == system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    iqfr_v2_sha256(cfg$reference_config_path) == cfg$reference_config_sha256,
    iqmb_v9_science_check(ref, cfg))
  if (iqmb_v9_status_valid(path)) return(invisible("ALREADY_COMPLETE"))
  tryCatch(iqmb_v9_compute(cfg), error = function(e) {
    iqcf_v3_status_write(cfg, "FAILED", Sys.time(), list(error = conditionMessage(e), fitted_model_binaries = 0L))
    stop(e)
  })
}

iqmb_v9_project <- function(t, stage) {
  b <- iqmb_v9_budget(stage)
  stopifnot(all(is.finite(c(t$warm_seconds, t$mcmc_seconds, t$forecast_seconds))),
    t$mcmc_seconds > 0, t$forecast_seconds > 0)
  t$warm_seconds + t$mcmc_seconds * (b$burn + b$retained) / (t$burn + t$retained) +
    t$forecast_seconds * 45 / t$origins * b$outer / t$outer * b$inner / t$inner
}

iqmb_v9_cost_gate <- function(run) {
  iqct_v6_verify_inputs(run)
  plan <- read.csv(file.path(run, "plan.csv")); plan <- plan[plan$stage == "cost_smoke", ]
  stopifnot(nrow(plan) == 4L)
  z <- do.call(rbind, lapply(plan$config_path, function(path) {
    stopifnot(iqmb_v9_status_valid(path))
    cfg <- iqfr_v2_read_json(path); s <- iqfr_v2_read_json(cfg$status_path)
    t <- iqfr_v2_read_json(s$artifact_paths$timing)
    data.frame(case_id = cfg$case_id, pair_role = cfg$pair_role,
      pilot_seconds = iqmb_v9_project(t, "pilot"), confirmation_seconds = iqmb_v9_project(t, "confirmation"))
  }))
  z$safety_factor <- 2
  z$pass <- 2 * z$pilot_seconds < 21600 & 2 * z$confirmation_seconds < 43200
  iqfr_v2_write_csv(z, file.path(run, "cost_gate.csv"))
  if (!all(z$pass)) stop("Cost budget exceeded; production remains unscheduled.")
  z
}

iqmb_v9_scores <- function(run, stage) {
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == stage, ]
  gate <- file.path(run, "confirmation_gate.csv")
  if (stage == "confirmation" && file.exists(gate)) {
    g <- read.csv(gate); p <- p[p$case_id %in% g$case_id[g$selected], ]
  }
  if (!nrow(p)) return(data.frame())
  do.call(rbind, lapply(p$config_path, function(path) {
    stopifnot(iqmb_v9_status_valid(path))
    cfg <- iqfr_v2_read_json(path); x <- read.csv(cfg$result_path)
    a <- x[x$estimator == "mean_conditional_location", ]
    b <- x[x$estimator == "posterior_predictive_quantile_pooled", ]
    stopifnot(nrow(a) == 1L, nrow(b) == 1L)
    data.frame(case_id = cfg$case_id, pair_role = cfg$pair_role, chain_index = cfg$chain_index,
      seed_index = cfg$chain_index, seed = cfg$seed, job_id = cfg$job_id,
      forecast_mae = a$forecast_qtrue_mae, forecast_rmse = a$forecast_qtrue_rmse,
      conditional_check_loss = a$forecast_check_loss, pooled_predictive_check_loss = b$forecast_check_loss,
      fit_point_rmse = a$fit_point_rmse, config_path = path)
  }))
}

iqmb_v9_select <- function(scores, projected) {
  stopifnot(nrow(scores) == 4L, !anyDuplicated(paste(scores$case_id, scores$pair_role)))
  do.call(rbind, lapply(unique(scores$case_id), function(case) {
    x <- scores[scores$case_id == case, ]; a <- x[x$pair_role == "challenger", ]; b <- x[x$pair_role == "control", ]
    fields <- c("forecast_mae", "conditional_check_loss", "pooled_predictive_check_loss")
    stopifnot(nrow(a) == 1L, nrow(b) == 1L, all(is.finite(unlist(x[fields]))))
    strict <- vapply(fields, function(k) a[[k]] < b[[k]], TRUE)
    cost_ok <- all(projected$pass[projected$case_id == case]) && sum(projected$case_id == case) == 2L
    data.frame(case_id = case, mae_gain = b$forecast_mae - a$forecast_mae,
      conditional_check_gain = b$conditional_check_loss - a$conditional_check_loss,
      pooled_check_gain = b$pooled_predictive_check_loss - a$pooled_predictive_check_loss,
      selected = any(strict) && cost_ok, reason = if (any(strict) && cost_ok)
        "FINITE_STRICT_FORECAST_GAIN_CONFIRM_BOTH_ROLES" else "NO_FORECAST_GAIN_OR_COST_LIMIT")
  }))
}

iqmb_v9_pilot_gate <- function(run) {
  iqct_v6_verify_inputs(run)
  scores <- iqmb_v9_scores(run, "pilot")
  cost <- read.csv(file.path(run, "cost_gate.csv"))
  p <- read.csv(file.path(run, "plan.csv")); p <- p[p$stage == "pilot", ]
  for (path in p$config_path) {
    cfg <- iqfr_v2_read_json(path); s <- iqfr_v2_read_json(cfg$status_path)
    t <- iqfr_v2_read_json(s$artifact_paths$timing)
    i <- cost$case_id == cfg$case_id & cost$pair_role == cfg$pair_role
    cost$confirmation_seconds[i] <- iqmb_v9_project(t, "confirmation")
    cost$pass[i] <- 2 * cost$confirmation_seconds[i] < 43200
  }
  iqfr_v2_write_csv(cost, file.path(run, "pilot_measured_cost.csv"))
  gate <- iqmb_v9_select(scores, cost)
  iqfr_v2_write_csv(scores, file.path(run, "pilot_scores.csv"))
  iqfr_v2_write_csv(gate, file.path(run, "confirmation_gate.csv"))
  gate
}

iqmb_v9_score_report <- function(run, scores, stage) {
  if (!nrow(scores)) return(invisible(NULL))
  ledger <- iqps_v8_paired_ledger(scores)
  iqfr_v2_write_csv(ledger, file.path(run, paste0(stage, "_paired_chain_gains.csv")))
  means <- aggregate(ledger[c("challenger", "control", "gain")], ledger[c("case_id", "metric")], mean)
  means$strict_mean_gain <- means$gain > 0
  iqfr_v2_write_csv(means, file.path(run, paste0(stage, "_mean_gain_ledger.csv")))
  intervals <- origins <- leads <- all_draw_scores <- transfer <- list()
  for (path in scores$config_path) {
    cfg <- iqfr_v2_read_json(path)
    id <- data.frame(case_id = cfg$case_id, pair_role = cfg$pair_role,
      seed_index = cfg$chain_index, seed = cfg$seed)
    for (axis in c("origin", "lead")) {
      x <- read.csv(cfg[[paste0(axis, "_profile_path")]])
      x <- x[x$estimator == "mean_conditional_location", ]
      part <- cbind(id[rep(1L,nrow(x)), ], x)
      if (axis == "origin") origins[[length(origins)+1L]] <- part else leads[[length(leads)+1L]] <- part
    }
    draws <- read.csv(cfg$metric_draw_path)
    all_draw_scores[[length(all_draw_scores)+1L]] <- cbind(
      id[rep(1L,nrow(draws)), ],draws)
    ref <- iqfr_v2_read_json(cfg$reference_config_path)
    v8 <- read.csv(ref$result_path); v8 <- v8[v8$estimator=="mean_conditional_location", ]
    mcmc <- scores[scores$config_path==path, ]
    stopifnot(nrow(v8)==1L,nrow(mcmc)==1L)
    transfer[[length(transfer)+1L]] <- data.frame(case_id=cfg$case_id,pair_role=cfg$pair_role,
      chain_index=cfg$chain_index,reference_inference="v8_VB_seed1",target_inference="MCMC",
      VB_mae=v8$forecast_qtrue_mae,MCMC_mae=mcmc$forecast_mae,
      gain=v8$forecast_qtrue_mae-mcmc$forecast_mae,
      note="Different posterior and outer-draw budget; not a matched MCMC comparator claim")
    for (estimator in unique(draws$estimator)) {
      x <- draws[draws$estimator == estimator, ]
      for (metric in c("forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss",
        "fit_qtrue_rmse", "fit_qtrue_mae", "fit_check_loss")) {
        v <- x[[metric]]; stopifnot(length(v) == cfg$outer_draws, all(is.finite(v)))
        intervals[[length(intervals)+1L]] <- data.frame(case_id = cfg$case_id, pair_role = cfg$pair_role,
          chain_index = cfg$chain_index, estimator = estimator, metric = metric,
          posterior_score_mean = mean(v), lower_025 = unname(quantile(v,.025,type=8)),
          upper_975 = unname(quantile(v,.975,type=8)), draw_count = length(v))
      }
    }
  }
  iqfr_v2_write_csv(do.call(rbind, intervals), file.path(run, paste0(stage,"_score_intervals.csv")))
  iqfr_v2_write_csv(do.call(rbind,transfer),file.path(run,paste0(stage,"_VB_transfer_comparison.csv")))
  all_draw_scores <- do.call(rbind,all_draw_scores)
  combined <- list()
  for (case in unique(all_draw_scores$case_id)) for (role in c("challenger","control"))
    for (estimator in unique(all_draw_scores$estimator)) {
      x<-all_draw_scores[all_draw_scores$case_id==case & all_draw_scores$pair_role==role &
        all_draw_scores$estimator==estimator, ]
      stopifnot(length(unique(table(x$seed_index)))==1L)
      for(metric in c("forecast_qtrue_mae","forecast_qtrue_rmse","forecast_check_loss",
        "fit_qtrue_rmse","fit_qtrue_mae","fit_check_loss")) {
        v<-x[[metric]]
        combined[[length(combined)+1L]]<-data.frame(case_id=case,pair_role=role,estimator=estimator,
          metric=metric,posterior_score_mean=mean(v),lower_025=unname(quantile(v,.025,type=8)),
          upper_975=unname(quantile(v,.975,type=8)),draw_count=length(v),
          aggregation="equal_weight_chain_score_mixture_not_score_of_pooled_mean_path")
      }
    }
  iqfr_v2_write_csv(do.call(rbind,combined),file.path(run,paste0(stage,"_combined_score_intervals.csv")))
  for (axis in c("origin", "lead")) {
    x <- do.call(rbind, if (axis == "origin") origins else leads)
    pairs <- iqps_v8_granular_pairs(x, if (axis == "origin") "source_origin" else "lead")
    iqfr_v2_write_csv(pairs, file.path(run, paste0(stage,"_paired_",axis,"_gains.csv")))
  }
  invisible(means)
}

iqmb_v9_health <- function(run) {
  h <- iqdr_v7_health(run)
  p <- read.csv(file.path(run, "plan.csv"))
  for (i in which(h$status == "SUCCESS")) if (!iqmb_v9_status_valid(p$config_path[i]))
    h$status[i] <- "POSTCHECK_INCOMPLETE"
  gate <- file.path(run, "confirmation_gate.csv")
  if (file.exists(gate)) {
    g <- read.csv(gate)
    skip <- h$stage == "confirmation" & !h$case_id %in% g$case_id[g$selected]
    h$status[skip & h$status == "PENDING"] <- "NOT_SELECTED"
  }
  h
}

iqmb_v9_audit <- function(run) {
  iqct_v6_verify_inputs(run)
  h <- iqmb_v9_health(run)
  stopifnot(all(h$status %in% c("SUCCESS", "NOT_SELECTED")))
  iqmb_v9_score_report(run, iqmb_v9_scores(run,"pilot"), "pilot")
  scores <- iqmb_v9_scores(run, "confirmation")
  if (nrow(scores)) {
    iqmb_v9_score_report(run, scores, "confirmation")
    avg <- aggregate(scores[c("forecast_mae", "forecast_rmse", "conditional_check_loss", "pooled_predictive_check_loss", "fit_point_rmse")],
      scores[c("case_id", "pair_role")], mean)
    iqfr_v2_write_csv(scores, file.path(run, "confirmation_chain_scores.csv"))
    iqfr_v2_write_csv(avg, file.path(run, "confirmation_mean_scores.csv"))
    diagnostics <- list()
    for (case in unique(scores$case_id)) for (role in c("challenger", "control")) {
      paths <- scores$config_path[scores$case_id == case & scores$pair_role == role]
      chains <- lapply(paths, function(path) {
        cfg <- iqfr_v2_read_json(path); s <- iqfr_v2_read_json(cfg$status_path)
        read.csv(s$artifact_paths$parameter_draws)
      })
      stopifnot(length(chains) == 3L, all(vapply(chains, nrow, 1L) == 20000L))
      for (k in setdiff(names(chains[[1]]), "draw")) {
        v <- lapply(chains, `[[`, k)
        rhat <- if (all(vapply(v, sd, 1) > 0)) tryCatch(coda::gelman.diag(
          coda::mcmc.list(lapply(v, coda::mcmc)), autoburnin = FALSE)$psrf[1L, 1L], error = function(e) NA_real_) else NA_real_
        diagnostics[[length(diagnostics) + 1L]] <- data.frame(case_id = case, pair_role = role,
          parameter = k, classical_Rhat = rhat, constant_parameter = all(vapply(v, sd, 1) == 0))
      }
    }
    iqfr_v2_write_csv(do.call(rbind, diagnostics), file.path(run, "confirmation_parameter_diagnostics.csv"))
  }
  iqfr_v2_write_csv(h, file.path(run, "health_final.csv"))
  iqfr_v2_write_json(list(status = "COMPLETE_INTERNAL_MCMC_BRIDGE", successful_jobs = sum(h$status == "SUCCESS"),
    not_selected_jobs = sum(h$status == "NOT_SELECTED"), failures = 0L,
    article_promotion = FALSE, comparator_claim = "v8_references_are_VB_not_matched_MCMC",
    diagnostic_exclusion = FALSE, posterior_interval_calibration_not_proven_by_predictive_gain = TRUE,
    fitted_model_binaries = 0L, finished_at = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(run, "closeout.json"))
  invisible(h)
}
