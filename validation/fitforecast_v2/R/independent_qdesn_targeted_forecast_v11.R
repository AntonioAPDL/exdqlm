iqtf_v11_schema <- "independent_qdesn_targeted_forecast_v11"
iqtf_v11_stages <- c("cost", "initializers", "discovery", "pilot", "confirmation")
iqtf_v11_metrics <- c("forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss")

iqtf_v11_source <- function(repo) {
  source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_frozen_preprocessing_v10.R"),
    local = FALSE)
  iqfp_v10_source(repo)
}

iqtf_v11_hash <- function(paths, out) {
  paths <- unique(paths)
  stopifnot(length(paths) > 0L, all(file.exists(paths)), !any(file.info(paths)$isdir))
  iqbs_v5_hash_manifest(paths, out)
}

iqtf_v11_verify <- function(path) {
  stopifnot(file.exists(path), nrow(read.csv(path)) > 0L)
  iqbs_v5_verify_manifest(path)
  invisible(TRUE)
}

iqtf_v11_campaign <- function(path) {
  # Candidate arrays are records, not rectangular JSON tables.
  z <- jsonlite::fromJSON(path, simplifyVector = TRUE, simplifyDataFrame = FALSE)
  stopifnot(is.list(z$references), is.list(z$candidates),
    setequal(names(z$references), names(z$candidates)),
    all(vapply(z$candidates, function(cs) is.list(cs) && !is.data.frame(cs) &&
      length(cs) > 0L && all(vapply(cs, is.list, TRUE)), TRUE)))
  z
}

iqtf_v11_valid <- function(cfg) {
  if (!file.exists(cfg$status_path)) return(FALSE)
  tryCatch({
    s <- iqfr_v2_read_json(cfg$status_path)
    stopifnot(s$status == "SUCCESS", s$config_sha256 == iqfr_v2_sha256(cfg$config_path))
    iqtf_v11_verify(s$manifest)
    iqtf_v11_verify(s$input_manifest)
    TRUE
  }, error = function(e) FALSE)
}

iqtf_v11_candidate <- function(x, anchor, role, multiplier) {
  x$canonical_structure_signature <- iqcb_v4_canonical_signature(x)
  x$structure_id <- paste0("iqtf11_s_", substr(digest::digest(
    x$canonical_structure_signature, algo = "sha256"), 1, 12))
  x$representation_role <- role
  x$tau0_multiplier <- multiplier
  x$tau0_reference <- anchor$rhs_tau0
  x$rhs_tau0 <- anchor$rhs_tau0 * multiplier
  x$rhs_tau0_source_scale <- x$rhs_tau0 * anchor$response_scale
  x$generation <- iqtf_v11_schema
  x$candidate_signature <- paste(iqtf_v11_schema, x$cell_id,
    x$canonical_structure_signature, sprintf("%.17g", x$rhs_tau0),
    "frozen_prefix_full_covariance_explicit_M0", sep = "|")
  x$candidate_id <- paste0("iqtf11_", substr(digest::digest(
    x$candidate_signature, algo = "sha256"), 1, 16))
  x
}

iqtf_v11_bank <- function(ref, bank) {
  anchor <- ref$candidate
  archived <- bank[bank$cell_id == anchor$cell_id, , drop = FALSE]
  archived <- archived[!duplicated(archived$canonical_structure_signature), , drop = FALSE]
  roles <- c("current_article_authority", "ridge_forecast_best",
    if (ref$likelihood_family == "al") "rhs_diverse_required_2" else "ridge_diverse_fill_3")
  history <- lapply(roles, function(role) {
    row <- archived[archived$representation_role == role, , drop = FALSE]
    stopifnot(nrow(row) == 1L)
    as.list(row[1, ])
  })
  shapes <- if (ref$likelihood_family == "al") list(
    list(n = c(120L, 80L), m = 120L, alpha = .7, rho = .95, gain = .5),
    list(n = c(200L, 100L, 100L), m = 240L, alpha = .9, rho = .995, gain = .3),
    list(n = c(200L, 150L, 100L, 50L), m = 300L, alpha = .97, rho = .98, gain = .7)
  ) else list(
    list(n = c(150L, 150L), m = 150L, alpha = .6, rho = .95, gain = .3),
    list(n = c(300L, 150L, 50L), m = 300L, alpha = .85, rho = .995, gain = .5),
    list(n = c(200L, 150L, 100L, 50L), m = 240L, alpha = .98, rho = .99, gain = .25))
  novel <- lapply(shapes, function(z) {
    x <- anchor
    x$D <- length(z$n); x$n <- paste(z$n, collapse = ";")
    x$n_tilde <- paste(head(z$n, -1L), collapse = ";")
    x$total_states <- sum(z$n); x$readout_dimension <- 1L + sum(z$n)
    x$m <- z$m; x$alpha <- z$alpha; x$rho <- z$rho; x$input_gain <- z$gain
    x$input_fanin_fraction <- .25
    x$input_fanin <- max(1L, ceiling((z$m + 1L) * x$input_fanin_fraction))
    x$recurrent_indegree <- 20L; x$interlayer_fanin <- 10L
    x$source_candidate_id <- "predeclared_v11_novel"
    stopifnot(!iqcb_v4_canonical_signature(x) %in% bank$canonical_structure_signature)
    x
  })
  out <- lapply(c(1, .1, .01, .001, .0001, 3), function(t)
    iqtf_v11_candidate(anchor, anchor, "same_structure_tau_sensitivity", t))
  for (x in history) for (t in c(1, .1))
    out[[length(out) + 1L]] <- iqtf_v11_candidate(x, anchor, "archived_repaired_protocol_recheck", t)
  for (x in novel) for (t in c(1, .1))
    out[[length(out) + 1L]] <- iqtf_v11_candidate(x, anchor, "novel_richer_identity_Q", t)
  stopifnot(length(out) == 18L, !anyDuplicated(vapply(out, function(x) x$candidate_signature, "")))
  out
}

iqtf_v11_config <- function(ref, candidate, stage, run, repo, chain = 1L) {
  id <- paste(stage, ref$case_id, candidate$candidate_id, chain, sep = "__")
  cfg <- list(schema_version = iqtf_v11_schema, stage = stage, job_id = id,
    repo_root = repo, run_root = run, case_id = ref$case_id,
    candidate = candidate, source = ref$source, probability = ref$probability,
    likelihood_family = ref$likelihood_family, rhs_s2 = 1,
    fit_end = 8750L, rollout_end = 9000L,
    origins = list(start = 8750L, end = 8970L, stride = 5L), horizon = 30L,
    seed = if (ref$likelihood_family == "al") 42020101L else 43030101L,
    chain_index = chain, beta_covariance_approximation = "full",
    baseline_config_sha256 = iqfr_v2_sha256(ref$config_path),
    normal_initializer_path = file.path(run, "initializers",
      paste0(ref$case_id, "__", candidate$structure_id, ".json")),
    budget = list(max_iter = 750L, tol = 1e-4, n_samp_xi = 400L),
    outer_draws = 16L, inner_path_grid = 32L,
    mcmc_burn = 1000L, mcmc_retained = 4000L,
    inference = if (stage %in% c("pilot", "confirmation")) "mcmc" else "vb",
    scientific_role = "internal_training_development_not_article_replacement",
    execution_kind = "production", worker_timeout_seconds = 43200L)
  cfg$chain_seed <- 500000000L + cfg$seed + chain * 100000L
  cfg$seed <- cfg$seed + chain * 100000L
  if (stage == "cost") {
    cfg$budget$max_iter <- 80L
    cfg$origins$end <- 8755L; cfg$outer_draws <- 4L; cfg$inner_path_grid <- 8L
    cfg$mcmc_burn <- 40L; cfg$mcmc_retained <- 160L
    cfg$scientific_role <- "measured_cost_and_real_kernel_smoke_not_selection"
  }
  if (stage == "pilot") {
    cfg$outer_draws <- 120L; cfg$inner_path_grid <- 128L
  }
  if (stage == "confirmation") {
    cfg$worker_timeout_seconds <- 172800L
    cfg$outer_draws <- 300L; cfg$inner_path_grid <- 128L
    cfg$mcmc_burn <- 5000L; cfg$mcmc_retained <- 20000L
  }
  cfg$config_path <- file.path(run, "configs", paste0(id, ".json"))
  cfg$status_path <- file.path(run, "status", paste0(id, ".json"))
  cfg$result_path <- file.path(run, "results", paste0(id, ".csv"))
  cfg
}

iqtf_v11_plan <- function(configs, stage, run) {
  path <- file.path(run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Refusing to overwrite a frozen stage plan.")
  rows <- lapply(configs, function(cfg) {
    iqfr_v2_write_json(cfg, cfg$config_path)
    data.frame(job_id = cfg$job_id, stage = cfg$stage, case_id = cfg$case_id,
      candidate_id = cfg$candidate$candidate_id, columns = cfg$candidate$readout_dimension,
      chain_index = cfg$chain_index, config_path = cfg$config_path,
      config_sha256 = iqfr_v2_sha256(cfg$config_path), status_path = cfg$status_path)
  })
  p <- if (length(rows)) do.call(rbind, rows) else data.frame(job_id = character(),
    stage = character(), case_id = character(), candidate_id = character(),
    columns = integer(), chain_index = integer(), config_path = character(),
    config_sha256 = character(), status_path = character())
  p <- p[order(-p$columns, p$case_id, p$candidate_id), , drop = FALSE]
  iqfr_v2_write_csv(p, path)
  iqtf_v11_hash(c(path, p$config_path), file.path(run, "plans", paste0(stage, "__hashes.csv")))
  p
}

iqtf_v11_materialize <- function(repo, legacy, history, run, tests) {
  if (dir.exists(run)) stop("Refusing to overwrite a run.")
  for (f in c("source_hashes.csv", "materialization_hashes.csv", "final_artifact_manifest.csv"))
    iqtf_v11_verify(file.path(legacy, f))
  stopifnot(any(readLines(file.path(legacy, "pipeline.status")) == "status=COMPLETE"),
    nrow(read.csv(file.path(legacy, "plan.csv"))) == 14L)
  test <- read.csv(file.path(tests, "test_results.csv"))
  stopifnot(nrow(test) > 0, all(test$failed == 0), !any(test$error), all(test$warning == 0))
  dir.create(run, recursive = TRUE)
  history_path <- file.path(run, "frozen_history.csv")
  file.copy(history, history_path)
  old <- read.csv(file.path(legacy, "plan.csv"))
  refs <- list(); inputs <- c(history, file.path(legacy, "final_artifact_manifest.csv"))
  for (case in c("normal_al_p005", "normal_exal_p025")) {
    role <- if (case == "normal_al_p005") "control" else "challenger"
    pick <- old[old$case_id == case & old$inference == "mcmc" & old$pair_role == role, ][1L, ]
    r <- iqfr_v2_read_json(pick$config_path)
    stopifnot(iqfr_v2_sha256(r$reference_config_path) == r$reference_config_sha256)
    ref <- iqfr_v2_read_json(r$reference_config_path)
    refs[[case]] <- ref
    inputs <- c(inputs, pick$config_path, ref$config_path, ref$source$frozen_path)
  }
  bank <- read.csv(history_path)
  specs <- lapply(refs, function(ref) iqtf_v11_bank(ref, bank))
  iqfr_v2_write_json(list(schema = iqtf_v11_schema, references = refs, candidates = specs),
    file.path(run, "campaign.json"))
  table <- do.call(rbind, lapply(names(specs), function(case) do.call(rbind, lapply(specs[[case]], function(c)
    data.frame(case_id = case, candidate_id = c$candidate_id, structure_id = c$structure_id,
      arm = c$representation_role, source_candidate_id = c$source_candidate_id,
      D = c$D, n = c$n, m = c$m, alpha = c$alpha, rho = c$rho, input_gain = c$input_gain,
      input_fanin_fraction = c$input_fanin_fraction, tau0_ratio = c$tau0_multiplier,
      tau0_model = c$rhs_tau0, tau0_source = c$rhs_tau0_source_scale,
      canonical_structure_signature = c$canonical_structure_signature,
      candidate_signature = c$candidate_signature)))))
  stopifnot(nrow(table) == 36L, !anyDuplicated(table$candidate_signature))
  iqfr_v2_write_csv(table, file.path(run, "candidate_ledger.csv"))
  costs <- lapply(names(specs), function(case) {
    rich <- Filter(function(c) c$representation_role == "novel_richer_identity_Q" &&
      c$tau0_multiplier == 1, specs[[case]])
    c <- rich[[which.max(vapply(rich, function(c) c$readout_dimension, 1L))]]
    iqtf_v11_config(refs[[case]], c, "cost", run, repo)
  })
  iqtf_v11_plan(costs, "cost", run)
  sources <- c(list.files(file.path(repo, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "src"), full.names = TRUE, pattern = "[.](c|cpp|h|so)$"),
    list.files(file.path(repo, "validation/fitforecast_v2/R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), full.names = TRUE, pattern = "targeted_forecast_v11"),
    list.files(file.path(repo, "validation/fitforecast_v2/tests/testthat"), full.names = TRUE, pattern = "targeted-forecast-v11"),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_TARGETED_FORECAST_V11_PLAN_20261005.md"))
  iqtf_v11_hash(sources, file.path(run, "source_hashes.csv"))
  iqtf_v11_hash(c(inputs, list.files(tests, recursive = TRUE, full.names = TRUE)),
    file.path(run, "input_hashes.csv"))
  iqfr_v2_write_json(list(schema = iqtf_v11_schema,
    head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    runtime = "exdqlm_1.1.1_validation_source_with_frozen_preprocessing_repair",
    package_version = as.character(packageVersion("exdqlm")),
    compiled_sha256 = iqfr_v2_sha256(file.path(repo, "src/exdqlm.so")),
    R_version = R.version.string, session_info = capture.output(sessionInfo()),
    compiler = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"), stdout = TRUE),
    blas_lapack = as.list(extSoftVersion()),
    threads = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    concurrency = 6L, maximum_jobs = 76L, diagnostic_exclusion = FALSE,
    article_promotion = FALSE, comparator_rerun = FALSE, minimum_gain = 0,
    preprocessing = "observed_prefix_through_fit_origin_including_warmup",
    selections = "MAE_and_check_separately_not_fit_or_normal_VB_gate"),
    file.path(run, "environment.json"))
  iqtf_v11_hash(file.path(run, c("campaign.json", "candidate_ledger.csv", "frozen_history.csv",
    "source_hashes.csv", "input_hashes.csv", "environment.json", "plans/cost__hashes.csv")),
    file.path(run, "materialization_hashes.csv"))
  invisible(run)
}

iqtf_v11_normal <- function(cfg, cx, out) {
  set.seed(cfg$seed)
  a <- iqfr_v2_design_args(cx$y[cx$source$t <= cfg$fit_end], cfg$candidate,
    cx$preprocess, cfg$probability, TRUE, normal_args = list(beta_prior_type = "rhs_ns",
      rhs = list(tau0 = cfg$candidate$tau0_reference, s2 = 1, shrink_intercept = FALSE, n_inner = 2L),
      control = list(max_iter = 200L, min_iter = 10L, tol = 1e-5,
        covariance = "woodbury_diagonal", verbose = FALSE)))
  z <- do.call(qdesn_fit_normal, a)
  iqfr_v2_assert_design(z, cfg$candidate, cfg$fit_end - 8500L)
  init <- qdesn_normal_to_vb_init(z, cfg$likelihood_family, "rhs_ns", cfg$probability)
  init <- list(beta_m = as.numeric(init$beta_m), beta_V = unname(as.matrix(init$beta_V)),
    sigma = as.numeric(init$sigma), source = init$source)
  stopifnot(is.null(init$beta_state), all(is.finite(unlist(init[c("beta_m", "beta_V", "sigma")]))),
    init$sigma > 0)
  iqfr_v2_write_json(list(schema = iqtf_v11_schema, initialization = init,
    source_sha256 = cfg$source$frozen_sha256,
    design_sha256 = digest::digest(z$X, algo = "sha256"),
    structure_signature = cfg$candidate$canonical_structure_signature,
    rng_kind = RNGkind(), rng_after_normal = .Random.seed,
    reference_tau0 = cfg$candidate$tau0_reference, prior_state_transferred = FALSE), out)
  round <- iqfr_v2_read_json(out)$initialization
  stopifnot(max(abs(c(unlist(round[c("beta_m", "beta_V", "sigma")]) -
    unlist(init[c("beta_m", "beta_V", "sigma")])))) <= 1e-6)
  out
}

iqtf_v11_vb <- function(cfg, cx, initializer) {
  payload <- iqfr_v2_read_json(initializer)
  stopifnot(payload$schema == iqtf_v11_schema,
    payload$source_sha256 == cfg$source$frozen_sha256,
    payload$structure_signature == cfg$candidate$canonical_structure_signature,
    !payload$prior_state_transferred)
  init <- payload$initialization; init$beta_V <- as.matrix(init$beta_V)
  do.call(RNGkind, as.list(payload$rng_kind))
  assign(".Random.seed", as.integer(payload$rng_after_normal), envir = .GlobalEnv)
  args <- list(likelihood_family = cfg$likelihood_family,
    al_fixed_gamma = if (cfg$likelihood_family == "al") 0 else NULL,
    beta_prior_type = "rhs_ns", beta_rhs = list(tau0 = cfg$candidate$rhs_tau0,
      s2 = 1, shrink_intercept = FALSE, n_inner = 2L),
    init = init, max_iter = cfg$budget$max_iter, min_iter_elbo = 10L,
    tol = cfg$budget$tol, tol_par = cfg$budget$tol, n_samp_xi = cfg$budget$n_samp_xi,
    verbose = FALSE, sigmagam = exal_make_vb_sigmagam_control(),
    beta_covariance = list(approximation = "full", label_uncertainty = TRUE))
  fit <- iqfp_v10_design(cfg, cx, cfg$fit_end, TRUE, args)
  stopifnot(digest::digest(fit$X, algo = "sha256") == payload$design_sha256)
  fit
}

iqtf_v11_worker <- function(path) {
  cfg <- iqfr_v2_read_json(path); start <- Sys.time()
  iqtf_v11_verify(file.path(cfg$run_root, "source_hashes.csv"))
  iqtf_v11_verify(file.path(cfg$run_root, "materialization_hashes.csv"))
  plan <- read.csv(file.path(cfg$run_root, "plans", paste0(cfg$stage, ".csv")))
  stopifnot(iqfr_v2_sha256(path) == plan$config_sha256[match(cfg$job_id, plan$job_id)])
  if (file.exists(cfg$status_path)) stop("Refusing to overwrite a worker status.")
  iqfr_v2_write_json(list(status = "RUNNING", pid = Sys.getpid(), job_id = cfg$job_id,
    started = format(start, tz = "UTC", usetz = TRUE)), cfg$status_path)
  tryCatch({
    root <- file.path(cfg$run_root, "evidence", cfg$job_id)
    cx <- iqfp_v10_context(cfg)
    inputs <- c(path, cfg$source$frozen_path)
    fit_start <- proc.time()[["elapsed"]]
    if (cfg$stage == "initializers") {
      artifacts <- iqtf_v11_normal(cfg, cx, cfg$normal_initializer_path)
    } else {
      if (cfg$stage == "cost") {
        cfg$normal_initializer_path <- file.path(root, "normal_initializer.json")
        iqtf_v11_normal(cfg, cx, cfg$normal_initializer_path)
      }
      if (cfg$inference == "vb") {
        inputs <- c(inputs, cfg$normal_initializer_path)
        if (cfg$stage != "cost") stopifnot(iqfr_v2_sha256(cfg$normal_initializer_path) ==
          cfg$normal_initializer_sha256)
        fit <- iqtf_v11_vb(cfg, cx, cfg$normal_initializer_path)
        init <- iqmb_v9_explicit_init(fit$fit, cfg$likelihood_family)
        init_path <- file.path(root, "mcmc_initializer.json")
        iqfr_v2_write_json(list(values = init, source_sha256 = cfg$source$frozen_sha256,
          candidate_signature = cfg$candidate$candidate_signature,
          design_sha256 = digest::digest(fit$X, algo = "sha256"),
          policy = "state_only_fresh_RHS_prior_not_posterior_reinforcement"), init_path)
      } else {
        inputs <- c(inputs, cfg$mcmc_initializer_path)
        stopifnot(iqfr_v2_sha256(cfg$mcmc_initializer_path) == cfg$mcmc_initializer_sha256)
        payload <- iqfr_v2_read_json(cfg$mcmc_initializer_path)
        fit <- iqfp_v10_design(cfg, cx, cfg$fit_end)
        stopifnot(payload$source_sha256 == cfg$source$frozen_sha256,
          payload$candidate_signature == cfg$candidate$candidate_signature,
          payload$design_sha256 == digest::digest(fit$X, algo = "sha256"))
        fit <- iqmb_v9_fit_mcmc(fit, cfg, payload$values)
        iqmb_v9_kernel_check(fit$fit, cfg)
        init_path <- cfg$mcmc_initializer_path
      }
      fit_seconds <- proc.time()[["elapsed"]] - fit_start
      draws <- exal_posterior_draws(fit$fit, nd = cfg$outer_draws,
        seed = iqfr_v2_seed(cfg$seed, "posterior_draws"))
      mean_beta <- if (cfg$inference == "vb") fit$fit$qbeta$m else fit$fit$summary$beta_mean
      moments <- iqbs_v5_fit_summaries(fit$X, mean_beta, draws$beta,
        cx$source$q_target[cx$rows], cx$source$y[cx$rows], cfg$probability, cx$transport)
      artifacts <- c(iqfr_v2_write_csv(cbind(t = cx$source$t[cx$rows], moments$path),
        file.path(root, "fit_paths.csv")),
        iqfr_v2_write_csv_gz(cbind(t = cx$source$t[cx$rows], as.data.frame(moments$draws)),
          file.path(root, "fit_quantile_draws.csv.gz")))
      if (cfg$inference == "vb") {
        artifacts <- c(artifacts, init_path, iqbs_v5_capture_fit(cfg, fit, draws,
          cx$source, cx$rows, cx$transport))
        solve <- iqfr_v2_read_json(file.path(cfg$run_root, "fit_diagnostics", cfg$job_id, "summary.json"))
        stopifnot(solve$full_frozen_moment_residual <= 1e-6,
          solve$covariance_min_eigenvalue >= -1e-10 * max(1, solve$covariance_max_eigenvalue))
      } else {
        f <- fit$fit
        pars <- data.frame(draw = seq_len(nrow(f$samp.beta)), sigma = f$samp.sigma,
          gamma = f$samp.gamma, as.data.frame(f$samp.beta))
        names(pars)[-(1:3)] <- paste0("beta_", seq_len(ncol(f$samp.beta)))
        diagnostics <- data.frame(parameter = names(pars)[-1L],
          mean = vapply(pars[-1L], mean, 1), sd = vapply(pars[-1L], sd, 1),
          ess = vapply(pars[-1L], function(x) if (sd(x) > 0)
            as.numeric(coda::effectiveSize(coda::mcmc(x))) else NA_real_, 1))
        artifacts <- c(artifacts,
          iqfr_v2_write_csv_gz(pars, file.path(root, "parameter_draws.csv.gz")),
          iqfr_v2_write_csv(diagnostics, file.path(root, "parameter_summary.csv")),
          iqfr_v2_write_json(list(kernel = f$diagnostics$core_update_mode,
            control = f$control, diagnostics = f$diagnostics, prior = f$beta_prior$hypers),
            file.path(root, "mcmc_diagnostics.json")),
          iqfr_v2_write_csv_gz(data.frame(iteration = seq_along(f$misc$sigma_trace),
            sigma = f$misc$sigma_trace, gamma = f$misc$gamma_trace),
            file.path(root, "scale_shape_trace.csv.gz")))
      }
      rollout <- iqfp_v10_design(cfg, cx, cfg$rollout_end)
      rollout <- if (cfg$inference == "vb") iqfr_v2_attach_quantile_readout(rollout, fit)
        else iqfr_v2_attach_mcmc_readout(rollout, fit)
      checks <- iqfp_v10_assert_prefix(fit, rollout, cx$preprocess)
      artifacts <- c(artifacts, iqfr_v2_write_json(list(
        policy = "observed_prefix_through_fit_origin_including_warmup",
        lag_center = cx$preprocess$center, lag_scale = cx$preprocess$scale,
        response_center = cx$transport$center, response_scale = cx$transport$scale,
        design_sha256 = digest::digest(fit$X, algo = "sha256"),
        fit_last = cfg$fit_end, teacher_forced_between_origins = TRUE,
        recursive_within_origin = TRUE, readout_refit_between_origins = FALSE),
        file.path(root, "preprocessing.json")))
      forecast_start <- proc.time()[["elapsed"]]
      output <- iqfp_v10_forecast(list(ref = cfg, context = cx, rollout = rollout, draws = draws))
      forecast_seconds <- proc.time()[["elapsed"]] - forecast_start
      scored <- output$score; point <- scored$point_metrics
      stopifnot(all(is.finite(as.matrix(point[iqtf_v11_metrics]))))
      point$fit_point_rmse <- moments$scores$fit_point_rmse
      point$fit_point_check_loss <- moments$scores$fit_point_check_loss
      point$case_id <- cfg$case_id; point$candidate_id <- cfg$candidate$candidate_id
      point$arm <- cfg$candidate$representation_role; point$stage <- cfg$stage
      point$chain_index <- cfg$chain_index
      profile <- scored$origin_lead[scored$origin_lead$estimator == "mean_conditional_location", ]
      primary <- point[point$estimator == "mean_conditional_location", ]
      stopifnot(nrow(primary) == 1L, nrow(profile) == length(seq(
        cfg$origins$start, cfg$origins$end, cfg$origins$stride)) * cfg$horizon,
        abs(mean(profile$absolute_oracle_error) - primary$forecast_qtrue_mae) <= 1e-6,
        abs(mean(profile$check_loss) - primary$forecast_check_loss) <= 1e-6)
      metrics <- merge(scored$metric_draws,
        iqcf_v3_fit_metric_draws(fit, draws, cx$source, cx$rows, cfg$probability, cx$transport),
        by = c("posterior_draw", "posterior_source_draw_index"), sort = FALSE)
      artifacts <- c(artifacts, iqfr_v2_write_csv(point, cfg$result_path),
        iqfr_v2_write_csv(rbind(checks, output$check), file.path(root, "checks.csv")),
        iqfr_v2_write_csv_gz(metrics, file.path(root, "metric_draws.csv.gz")),
        iqfr_v2_write_csv_gz(scored$origin_lead, file.path(root, "origin_lead.csv.gz")),
        iqfr_v2_write_csv(scored$lead_profile, file.path(root, "lead_profile.csv")),
        iqfr_v2_write_csv(scored$origin_profile, file.path(root, "origin_profile.csv")),
        iqfr_v2_write_csv_gz(cbind(profile[c("source_origin", "lead", "source_target")],
          as.data.frame(do.call(rbind, output$lattice$oracle_location$mean_conditional_location))),
          file.path(root, "forecast_location_draws.csv.gz")))
      cost_mcmc_seconds <- NA_real_
      if (cfg$stage == "cost") {
        begin <- proc.time()[["elapsed"]]
        mc <- iqmb_v9_fit_mcmc(fit, cfg, init)
        iqmb_v9_kernel_check(mc$fit, cfg)
        cost_mcmc_seconds <- proc.time()[["elapsed"]] - begin
        artifacts <- c(artifacts, cfg$normal_initializer_path,
          iqfr_v2_write_json(list(kernel = mc$fit$diagnostics$core_update_mode,
            finite_draws = TRUE, retained = cfg$mcmc_retained, state_only_init = TRUE),
            file.path(root, "cost_kernel.json")))
      }
      artifacts <- c(artifacts, iqfr_v2_write_json(list(fit_seconds = fit_seconds,
        forecast_seconds = forecast_seconds, cost_mcmc_seconds = cost_mcmc_seconds,
        vb_max_iter = cfg$budget$max_iter, outer = cfg$outer_draws, inner = cfg$inner_path_grid,
        origins = length(seq(cfg$origins$start, cfg$origins$end, cfg$origins$stride)),
        horizon = cfg$horizon, mcmc_iterations = cfg$mcmc_burn + cfg$mcmc_retained,
        memory = grep("^Vm(HWM|RSS):", readLines("/proc/self/status"), value = TRUE)),
        file.path(root, "timing.json")))
    }
    iqtf_v11_hash(inputs, file.path(root, "input_hashes.csv"))
    iqtf_v11_hash(c(artifacts, file.path(root, "input_hashes.csv")), file.path(root, "artifacts.csv"))
    iqfr_v2_write_json(list(status = "SUCCESS", job_id = cfg$job_id, pid = Sys.getpid(),
      seconds = as.numeric(difftime(Sys.time(), start, units = "secs")),
      config_sha256 = iqfr_v2_sha256(path), manifest = file.path(root, "artifacts.csv"),
      input_manifest = file.path(root, "input_hashes.csv"), fitted_model_binaries = 0),
      cfg$status_path)
  }, error = function(e) {
    iqfr_v2_write_json(list(status = "FAILED", job_id = cfg$job_id,
      error = conditionMessage(e), pid = Sys.getpid()), cfg$status_path)
    stop(e)
  })
}

iqtf_v11_rows <- function(run, stage) {
  p <- read.csv(file.path(run, "plans", paste0(stage, ".csv")))
  iqtf_v11_verify(file.path(run, "plans", paste0(stage, "__hashes.csv")))
  if (!nrow(p)) return(data.frame())
  stopifnot(all(vapply(p$config_path, function(path) iqtf_v11_valid(iqfr_v2_read_json(path)), TRUE)))
  rows <- lapply(p$config_path, function(path) {
    cfg <- iqfr_v2_read_json(path)
    z <- read.csv(cfg$result_path)
    z <- z[z$estimator == "mean_conditional_location", , drop = FALSE]
    z$config_path <- path
    z
  })
  do.call(rbind, rows)
}

iqtf_v11_pick <- function(rows, anchors, require_gain = FALSE) {
  picks <- character()
  for (case in unique(rows$case_id)) {
    z <- rows[rows$case_id == case & rows$candidate_id != anchors[[case]], , drop = FALSE]
    a <- rows[rows$case_id == case & rows$candidate_id == anchors[[case]], , drop = FALSE]
    if (require_gain) stopifnot(nrow(a) == 1L)
    for (metric in c("forecast_qtrue_mae", "forecast_check_loss")) {
      y <- z[is.finite(z[[metric]]), , drop = FALSE]
      if (require_gain) y <- y[y[[metric]] < a[[metric]], , drop = FALSE]
      if (nrow(y)) picks <- c(picks, y$config_path[order(y[[metric]], y$candidate_id)][1L])
    }
  }
  unique(picks)
}

iqtf_v11_advance <- function(repo, run, stage) {
  iqtf_v11_verify(file.path(run, "source_hashes.csv"))
  iqtf_v11_verify(file.path(run, "materialization_hashes.csv"))
  campaign <- iqtf_v11_campaign(file.path(run, "campaign.json"))
  refs <- campaign$references; specs <- campaign$candidates
  anchors <- lapply(specs, function(cs) cs[[1L]]$candidate_id)
  p <- read.csv(file.path(run, "plans", paste0(stage, ".csv")))
  iqtf_v11_verify(file.path(run, "plans", paste0(stage, "__hashes.csv")))
  stopifnot(all(vapply(p$config_path, function(path) iqtf_v11_valid(iqfr_v2_read_json(path)), TRUE)))
  configs <- list()
  if (stage == "cost") {
    records <- lapply(p$job_id, function(id) {
      t <- iqfr_v2_read_json(file.path(run, "evidence", id, "timing.json"))
      forecast_full <- t$forecast_seconds * (45 / t$origins) * (300 / t$outer) * (128 / t$inner)
      data.frame(job_id = id,
        estimated_discovery_seconds = t$fit_seconds * (750 / t$vb_max_iter) +
          t$forecast_seconds * (45 / t$origins) * (16 / t$outer) * (32 / t$inner),
        estimated_confirmation_seconds = t$cost_mcmc_seconds * (25000 / t$mcmc_iterations) + forecast_full)
    })
    costs <- do.call(rbind, records)
    iqfr_v2_write_csv(costs, file.path(run, "cost_gate.csv"))
    stopifnot(all(is.finite(as.matrix(costs[-1L]))),
      all(costs$estimated_discovery_seconds < 21600))
    for (case in names(specs)) {
      cs <- specs[[case]]; cs <- cs[!duplicated(vapply(cs, function(c) c$structure_id, ""))]
      for (c in cs) configs[[length(configs) + 1L]] <-
        iqtf_v11_config(refs[[case]], c, "initializers", run, repo)
    }
  } else if (stage == "initializers") {
    for (case in names(specs)) for (c in specs[[case]]) {
      cfg <- iqtf_v11_config(refs[[case]], c, "discovery", run, repo)
      cfg$normal_initializer_sha256 <- iqfr_v2_sha256(cfg$normal_initializer_path)
      configs[[length(configs) + 1L]] <- cfg
    }
  } else if (stage %in% c("discovery", "pilot")) {
    rows <- iqtf_v11_rows(run, stage)
    picks <- iqtf_v11_pick(rows, anchors, require_gain = stage == "pilot")
    cases <- if (stage == "discovery") names(refs) else unique(rows$case_id[rows$config_path %in% picks])
    for (case in cases) {
      chosen <- picks[rows$case_id[match(picks, rows$config_path)] == case]
      anchor_path <- rows$config_path[rows$case_id == case & rows$candidate_id == anchors[[case]]][1L]
      chosen <- unique(c(anchor_path, chosen))
      for (path in chosen) {
        old <- iqfr_v2_read_json(path)
        initializer <- if (stage == "discovery") file.path(run, "evidence", old$job_id,
          "mcmc_initializer.json") else old$mcmc_initializer_path
        for (chain in if (stage == "discovery") 1L else 1:3) {
          cfg <- iqtf_v11_config(refs[[case]], old$candidate,
            if (stage == "discovery") "pilot" else "confirmation", run, repo, chain)
          cfg$mcmc_initializer_path <- initializer
          cfg$mcmc_initializer_sha256 <- iqfr_v2_sha256(initializer)
          configs[[length(configs) + 1L]] <- cfg
        }
      }
    }
    iqfr_v2_write_json(list(stage = stage, selected = picks, anchors = anchors,
      thresholds = 0, diagnostic_veto = FALSE, VB_gain_gate = FALSE),
      file.path(run, paste0(stage, "_selection.json")))
    if (stage == "pilot" && length(configs)) {
      budgets <- lapply(unique(vapply(configs, function(c) c$candidate$candidate_id, "")), function(id) {
        path <- rows$config_path[rows$candidate_id == id][1L]
        old <- iqfr_v2_read_json(path)
        t <- iqfr_v2_read_json(file.path(run, "evidence", old$job_id, "timing.json"))
        data.frame(candidate_id = id, case_id = old$case_id,
          estimated_confirmation_seconds = t$fit_seconds * (25000 / 5000) +
            t$forecast_seconds * (300 / old$outer_draws) * (128 / old$inner_path_grid))
      })
      budgets <- do.call(rbind, budgets)
      iqfr_v2_write_csv(budgets, file.path(run, "selected_confirmation_cost_gate.csv"))
      stopifnot(all(is.finite(budgets$estimated_confirmation_seconds)),
        all(budgets$estimated_confirmation_seconds < 172800))
    }
  }
  next_stage <- iqtf_v11_stages[match(stage, iqtf_v11_stages) + 1L]
  if (!is.na(next_stage)) iqtf_v11_plan(configs, next_stage, run)
  invisible(TRUE)
}

iqtf_v11_health <- function(run) {
  files <- list.files(file.path(run, "plans"), pattern = "^[a-z]+[.]csv$", full.names = TRUE)
  p <- do.call(rbind, lapply(files, read.csv))
  states <- vapply(p$config_path, function(path) {
    cfg <- iqfr_v2_read_json(path)
    if (!file.exists(cfg$status_path)) return("PENDING")
    s <- iqfr_v2_read_json(cfg$status_path)
    if (s$status == "SUCCESS") return(if (iqtf_v11_valid(cfg)) "SUCCESS" else "INVALID")
    if (s$status == "RUNNING" && !file.exists(paste0("/proc/", s$pid))) return("STALE")
    s$status
  }, "")
  counts <- table(factor(states, levels = c("SUCCESS", "RUNNING", "PENDING", "FAILED", "STALE", "INVALID")))
  list(materialized_jobs = nrow(p), counts = as.list(counts),
    conditional_maximum_jobs = 76L, conditional_stages_not_materialized_are_not_failures = TRUE,
    jobs = data.frame(p, state = states), article_promotion = FALSE)
}

iqtf_v11_closeout <- function(run) {
  h <- iqtf_v11_health(run)
  stopifnot(h$counts$SUCCESS == h$materialized_jobs)
  rows <- lapply(c("discovery", "pilot", "confirmation"), function(stage) iqtf_v11_rows(run, stage))
  rows <- do.call(rbind, Filter(function(z) nrow(z) > 0, rows))
  iqfr_v2_write_csv(rows, file.path(run, "all_primary_scores.csv"))
  conf <- rows[rows$stage == "confirmation", ]
  profiles <- list()
  for (path in rows$config_path) {
    cfg <- iqfr_v2_read_json(path)
    z <- read.csv(file.path(run, "evidence", cfg$job_id, "origin_lead.csv.gz"))
    z <- z[z$estimator == "mean_conditional_location", ]
    origins <- sort(unique(z$source_origin))
    block <- c("early", "middle", "late")[pmin(3L,
      ceiling(seq_along(origins) * 3 / length(origins)))]
    z$origin_block <- block[match(z$source_origin, origins)]
    for (period in c("all", "early", "middle", "late")) for (horizon in c("H1", "H1_30")) {
      x <- z[(period == "all" | z$origin_block == period) & (horizon == "H1_30" | z$lead == 1), ]
      if (!nrow(x)) next
      profiles[[length(profiles) + 1L]] <- data.frame(case_id = cfg$case_id,
        candidate_id = cfg$candidate$candidate_id, stage = cfg$stage, chain_index = cfg$chain_index,
        origin_block = period, horizon = horizon, scored_pairs = nrow(x),
        oracle_mae = mean(x$absolute_oracle_error), check_loss = mean(x$check_loss),
        signed_bias = mean(x$point_prediction - x$q_target), posterior_sd = mean(x$posterior_sd))
    }
  }
  iqfr_v2_write_csv(do.call(rbind, profiles), file.path(run, "origin_horizon_diagnosis.csv"))
  means <- if (nrow(conf)) aggregate(conf[c("fit_point_rmse", iqtf_v11_metrics)],
    conf[c("case_id", "candidate_id", "arm")], mean) else data.frame()
  iqfr_v2_write_csv(means, file.path(run, "confirmation_means.csv"))
  intervals <- list()
  if (nrow(conf)) for (key in unique(paste(conf$case_id, conf$candidate_id))) {
    z <- conf[paste(conf$case_id, conf$candidate_id) == key, ]
    d <- do.call(rbind, lapply(z$config_path, function(path) {
      c <- iqfr_v2_read_json(path)
      x <- read.csv(file.path(run, "evidence", c$job_id, "metric_draws.csv.gz"))
      x[x$estimator == "mean_conditional_location", ]
    }))
    for (metric in intersect(c("fit_qtrue_rmse", iqtf_v11_metrics), names(d))) {
      x <- d[[metric]]
      intervals[[length(intervals) + 1L]] <- data.frame(case_id = z$case_id[1],
        candidate_id = z$candidate_id[1], metric = metric, posterior_score_mean = mean(x),
        lower_025 = unname(quantile(x, .025)), upper_975 = unname(quantile(x, .975)),
        draws = length(x), chains = nrow(z), interpretation = "equal_tail_per_draw_score_range_not_CI_of_chain_mean")
    }
  }
  iqfr_v2_write_csv(if (length(intervals)) do.call(rbind, intervals) else data.frame(),
    file.path(run, "posterior_score_intervals.csv"))
  campaign <- iqtf_v11_campaign(file.path(run, "campaign.json"))
  gains <- list()
  for (case in unique(means$case_id)) {
    z <- means[means$case_id == case, ]
    id <- campaign$candidates[[case]][[1L]]$candidate_id
    a <- z[z$candidate_id == id, ]
    for (i in which(z$candidate_id != id)) for (metric in c("forecast_qtrue_mae", "forecast_check_loss"))
      gains[[length(gains) + 1L]] <- data.frame(case_id = case, candidate_id = z$candidate_id[i],
        metric = metric, candidate = z[[metric]][i], anchor = a[[metric]],
        improvement = a[[metric]] - z[[metric]][i], strict_gain = z[[metric]][i] < a[[metric]])
  }
  iqfr_v2_write_csv(if (length(gains)) do.call(rbind, gains) else data.frame(),
    file.path(run, "confirmed_forecast_gains.csv"))
  pdf <- file.path(run, "targeted_forecast_review.pdf")
  grDevices::pdf(pdf, width = 11, height = 8.5)
  tryCatch({
    for (case in unique(rows$case_id)) {
      z <- rows[rows$case_id == case, ]
      par(mfrow = c(1, 3), mar = c(5, 4, 3, 1))
      for (metric in iqtf_v11_metrics) {
        plot(seq_len(nrow(z)), z[[metric]], pch = 4, col = match(z$stage, c("discovery", "pilot", "confirmation")),
          xlab = "Case-specific candidate / chain", ylab = metric, main = case)
        legend("topright", legend = c("VB discovery", "MCMC pilot", "MCMC confirmation"),
          col = 1:3, pch = 4, cex = .7)
      }
    }
  }, finally = grDevices::dev.off())
  decision <- if (any(vapply(gains, function(g) g$strict_gain, TRUE))) "CONFIRMED_INTERNAL_FORECAST_GAIN"
    else "NO_CONFIRMED_INTERNAL_GAIN_RETAIN_ANCHORS"
  iqfr_v2_write_json(list(decision = decision, jobs = h$materialized_jobs, active_jobs = 0,
    article_promotion = FALSE, integration_status = "REQUIRES_FROZEN_HANDOFF_NOT_ARTICLE_READY",
    external_confirmation_required = TRUE, diagnostic_veto = FALSE),
    file.path(run, "closeout.json"))
  files <- list.files(run, recursive = TRUE, full.names = TRUE)
  files <- files[!file.info(files)$isdir &
    !basename(files) %in% c("pipeline.status", "orchestrator.log", "final_artifact_manifest.csv", ".launcher.lock") &
    !grepl("[.]tmp$", files)]
  iqtf_v11_hash(files, file.path(run, "final_artifact_manifest.csv"))
  iqtf_v11_verify(file.path(run, "final_artifact_manifest.csv"))
}
