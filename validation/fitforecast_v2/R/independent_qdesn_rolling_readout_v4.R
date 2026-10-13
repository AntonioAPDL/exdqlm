irrv4_schema <- "independent_qdesn_rolling_readout_v4"
irrv4_recovery_schema <- "independent_qdesn_rolling_readout_v4_recovery_v1"
irrv4_candidate_id <- "3a7a6653cb244f49813c"
irrv4_screen_offsets <- c(50L, 125L, 200L)
irrv4_validation_offsets <- c(25L, 75L, 150L, 220L)

irrv4_arms <- function() data.frame(
  policy_id = c("expanding_calibrated", "rolling_1000", "rolling_750",
    "rolling_500", "rolling_250"),
  window_size = c(0L, 1000L, 750L, 500L, 250L),
  window_type = c("expanding", rep("rolling", 4L)),
  recalibrate_tau = TRUE,
  stringsAsFactors = FALSE)

irrv4_files <- function(path) {
  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  files[file.exists(files) & !file.info(files)$isdir]
}

irrv4_status <- function(path) {
  if (!file.exists(path)) return("PENDING")
  as.character(iqt12_read(path)$status)
}

irrv4_bind_rows <- function(...) {
  x <- list(...)
  x <- x[vapply(x, nrow, 0L) > 0L]
  all_names <- unique(unlist(lapply(x, names), use.names = FALSE))
  x <- lapply(x, function(z) {
    missing <- setdiff(all_names, names(z))
    for (name in missing) z[[name]] <- NA
    z[all_names]
  })
  do.call(rbind, x)
}

irrv4_verify_parent <- function(parent_run) {
  stopifnot(dir.exists(parent_run))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv", "closeout_manifest.csv"))
    iqt12_verify(file.path(parent_run, name))
  closeout <- iqt12_read(file.path(parent_run, "closeout.json"))
  stopifnot(closeout$status == "COMPLETE_REVIEW_REQUIRED",
    closeout$scientific_decision ==
      "NO_EXACT_MCMC_FINALIST_CLOSES_GAP_DYNAMIC_READOUT_SCOPE_REQUIRED",
    closeout$selected_candidate_id == irrv4_candidate_id,
    closeout$active_jobs == 0L, closeout$candidate_bridge_jobs == 24L,
    closeout$confirmation_jobs == 0L)
  health <- ifbv3_health(parent_run)
  stopifnot(health$total == 24L, health$complete == 24L,
    health$running == 0L, health$pending == 0L, health$failed == 0L)
  statuses <- list.files(file.path(parent_run, "status"), pattern = "[.]json$",
    full.names = TRUE)
  stopifnot(length(statuses) == 24L)
  for (path in statuses) ifbv3_verify_status_manifest(path)
  ifbv3_verify_imports(parent_run)
  invisible(list(closeout = closeout, health = health))
}

irrv4_copy_imports <- function(parent_run, run) {
  base <- read.csv(file.path(parent_run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  bridge <- read.csv(file.path(parent_run, "manifests", "v2_bridge_imports.csv"),
    stringsAsFactors = FALSE)
  bridge <- bridge[bridge$candidate_id == irrv4_candidate_id, ]
  stopifnot(nrow(base) == 72L, nrow(bridge) == 12L)
  iqt12_csv(base, file.path(run, "manifests", "parent_imports.csv"))
  iqt12_csv(bridge, file.path(run, "manifests", "expanding_fixed_imports.csv"))
  invisible(TRUE)
}

irrv4_verify_imports <- function(run) {
  base <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  fixed <- read.csv(file.path(run, "manifests", "expanding_fixed_imports.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(base) == 72L, nrow(fixed) == 12L,
    all(fixed$candidate_id == irrv4_candidate_id))
  for (x in list(base, fixed)) {
    stopifnot(identical(unname(tools::sha256sum(x$config_path)),
        x$config_sha256),
      identical(unname(tools::sha256sum(x$status_path)), x$status_sha256),
      identical(unname(tools::sha256sum(x$evidence_manifest)),
        x$evidence_manifest_sha256))
    for (path in x$evidence_manifest) iqt12_verify(path)
  }
  screen_path <- file.path(run, "manifests", "screen_imports.csv")
  if (file.exists(screen_path)) {
    screen <- read.csv(screen_path, stringsAsFactors = FALSE)
    stopifnot(nrow(screen) == 60L,
      identical(unname(tools::sha256sum(screen$config_path)),
        screen$config_sha256),
      identical(unname(tools::sha256sum(screen$status_path)),
        screen$status_sha256),
      identical(unname(tools::sha256sum(screen$evidence_manifest)),
        screen$evidence_manifest_sha256))
    for (path in screen$evidence_manifest) iqt12_verify(path)
  }
  invisible(TRUE)
}

irrv4_tau_source <- function(candidate, N) {
  p <- as.integer(candidate$readout_dimension) - 1L
  p0 <- as.numeric(candidate$effective_p0)
  sigma <- as.numeric(candidate$sigma_b_source)
  stopifnot(N > 0L, p > p0, p0 > 0, sigma > 0)
  p0 / (p - p0) * sigma / sqrt(N)
}

irrv4_readout_contract <- function(candidate, base_train, origin, policy_id) {
  arm <- irrv4_arms()
  arm <- arm[arm$policy_id == policy_id, ]
  stopifnot(nrow(arm) == 1L, length(base_train) == 1000L,
    origin > max(base_train))
  if (arm$window_type == "expanding") {
    start <- min(base_train)
  } else {
    start <- origin - arm$window_size + 1L
  }
  index <- seq.int(start, origin)
  if (arm$window_type == "rolling")
    stopifnot(length(index) == arm$window_size)
  tau <- irrv4_tau_source(candidate, length(index))
  list(policy_id = policy_id, window_type = arm$window_type,
    window_size = as.integer(arm$window_size), start = as.integer(start),
    end = as.integer(origin), N = length(index), index = index,
    tau_source = tau)
}

irrv4_config <- function(state, fold, offset, policy_id, stage, chain = 1L) {
  selected <- list(candidate_id = irrv4_candidate_id,
    mode = "rolling_readout_exact_refit")
  cfg <- icav2_bridge_config(state, selected, fold, offset)
  cfg$schema <- irrv4_schema; cfg$stage <- stage
  cfg$chain <- as.integer(chain); cfg$adaptation_mode <- policy_id
  cfg$readout_policy <- irrv4_readout_contract(cfg$candidate,
    cfg$base_train, cfg$refit_origin, policy_id)
  cfg$candidate$tau_source_original <- cfg$candidate$tau_source
  cfg$candidate$tau_source <- cfg$readout_policy$tau_source
  cfg$id <- paste(stage, cfg$cell, cfg$model, cfg$engine, fold,
    irrv4_candidate_id, policy_id, paste0("o", cfg$refit_origin),
    paste0("chain", chain), sep = "__")
  cfg$seed <- ism1_seed(cfg$id)
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$timeout <- 172800L
  cfg
}

irrv4_make_plan <- function(run, stage, offsets, policies, chains = 1L) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  configs <- list()
  for (policy_id in policies) for (fold in ism1_folds) for (offset in offsets)
    for (chain in chains)
      configs[[length(configs) + 1L]] <- irrv4_config(state, fold, offset,
        policy_id, stage, chain)
  iqt12_plan(state, configs, stage)
  invisible(configs)
}

irrv4_materialize <- function(repo, run, parent_run, library) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(parent_run),
    dir.exists(library))
  irrv4_verify_parent(parent_run)
  parent <- iqt12_read(file.path(parent_run, "campaign.json"))
  head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = irrv4_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE), head = head,
    parent_run = normalizePath(parent_run, mustWork = TRUE),
    parent_head = parent$head, references = parent$references,
    bank = parent$bank, candidate_id = irrv4_candidate_id,
    folds = ism1_folds, screen_offsets = irrv4_screen_offsets,
    validation_offsets = irrv4_validation_offsets,
    arms = irrv4_arms(),
    contract = list(selection_block = "internal_training_only_S1_to_S4",
      sealed_block = "source_indices_9001_to_10000_unopened",
      reservoir_and_preprocessing = "frozen_from_base_fold_training_window",
      readout_rows = "policy_specific_causal_rows_through_origin",
      rolling_reservoir_history = "retains_all_admissible_prior_input_history",
      teacher_forced_between_origins = TRUE,
      recursive_within_origin = TRUE, horizon = 30L,
      primary_metric = "forecast_mae",
      secondary_metrics = c("forecast_check_loss", "fit_rmse"),
      mcmc_method = "m0_v_collapsed_support_logit",
      diagnostics_are_descriptive_not_predictive_veto = TRUE,
      article_promotion = FALSE))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(read.csv(file.path(parent_run, "candidate_bank.csv"),
    stringsAsFactors = FALSE), file.path(run, "candidate_bank.csv"))
  irrv4_copy_imports(parent_run, run)
  env <- list(schema = irrv4_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    package_path = find.package("exdqlm", lib.loc = library),
    session = capture.output(sessionInfo()),
    threads = list(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1,
      MKL_NUM_THREADS = 1, RCPP_PARALLEL_NUM_THREADS = 1), source_head = head)
  iqt12_json(env, file.path(run, "environment.json"))
  configs <- irrv4_make_plan(run, "screen", irrv4_screen_offsets,
    irrv4_arms()$policy_id, 1L)
  e <- ism1_runtime(repo, library)
  code <- unique(c(e$iqt12_loaded_files, file.path(repo, "R/exal_online_vbld.R"),
    file.path(repo, "validation/fitforecast_v2/R", c(
      "independent_qdesn_training1000_runtime_v1.R",
      "independent_qdesn_training1000_campaign_v1.R",
      "independent_qdesn_sentinel_mechanism_v1.R",
      "independent_qdesn_sentinel_mechanism_recovery_v1.R",
      "independent_qdesn_causal_adaptation_v2.R",
      "independent_qdesn_mcmc_finalist_bridge_v3.R",
      "independent_qdesn_rolling_readout_v4.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_rolling_readout_v4.R",
      "run_independent_qdesn_rolling_readout_v4.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_ROLLING_READOUT_V4_20261009.md"),
    file.path(repo, "validation/fitforecast_v2/tests",
      "test_independent_qdesn_rolling_readout_v4.R")))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(irrv4_files(file.path(library, "exdqlm")),
    file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "manifests/parent_imports.csv",
    "manifests/expanding_fixed_imports.csv")),
    file.path(parent_run, c("source_hashes.csv", "input_hashes.csv",
      "package_hashes.csv", "frozen_hashes.csv", "closeout.json",
      "closeout_manifest.csv"))), file.path(run, "input_hashes.csv"))
  preflight <- list(schema = irrv4_schema, status = "READY_TO_LAUNCH",
    imported_base_jobs = 72L, imported_expanding_fixed_jobs = 12L,
    screen_jobs = length(configs), possible_validation_jobs = 16L,
    possible_confirmation_jobs = 32L, maximum_new_jobs = 108L,
    sealed_block_opened = FALSE, article_changed = FALSE)
  iqt12_json(preflight, file.path(run, "preflight.json"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "preflight.json",
    "manifests/parent_imports.csv",
    "manifests/expanding_fixed_imports.csv")),
    list.files(file.path(run, "plans"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  irrv4_verify_imports(run)
  invisible(preflight)
}

irrv4_worker <- function(path) {
  cfg <- iqt12_read(path); start <- proc.time()[["elapsed"]]
  e <- ism1_runtime(cfg$repo, cfg$library)
  iqt12_verify(file.path(cfg$run, "source_hashes.csv"))
  iqt12_verify(file.path(cfg$run, "package_hashes.csv"))
  iqt12_verify(file.path(cfg$run, "frozen_hashes.csv"))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(!file.exists(cfg$status_path),
    unname(tools::sha256sum(cfg$source_path)) == cfg$source_sha)
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", pid = Sys.getpid(), id = cfg$id,
    started = format(Sys.time(), tz = "UTC", usetz = TRUE)), cfg$status_path)
  tryCatch({
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source); full[source$t, ] <- source; source <- full
    cx <- ism1_design(e, cfg, source, cfg$window$end)
    contract <- irrv4_readout_contract(cfg$candidate, cfg$base_train,
      cfg$refit_origin, cfg$readout_policy$policy_id)
    stopifnot(contract$start == cfg$readout_policy$start,
      contract$end == cfg$readout_policy$end,
      contract$N == cfg$readout_policy$N,
      abs(contract$tau_source - cfg$candidate$tau_source) < 1e-12,
      max(contract$index) == cfg$refit_origin,
      max(cfg$base_train) < cfg$refit_origin,
      cfg$refit_origin + cfg$window$horizon <= 9000L,
      max(cfg$window$train) <= max(cfg$base_train))
    index <- contract$index - cx$first + 1L
    stopifnot(min(index) >= 1L, max(index) <= nrow(cx$all_X))
    cx$object$X <- cx$all_X[index, , drop = FALSE]
    cx$object$y_fit <- cx$y[index]
    cx$object$meta$keep_idx <- index
    cx$train <- index
    cx$design_hash <- digest::digest(cx$object$X, algo = "sha256")
    stopifnot(nrow(cx$object$X) == contract$N,
      ncol(cx$object$X) == cfg$candidate$readout_dimension)
    fit <- iqt12_quantile(e, cx, cfg)
    draws <- iqt12_draws(e, fit, cfg$outer, cfg$seed + 1L)
    fit_draws <- cx$object$X %*% t(draws$beta) * cx$scale
    forecast_cfg <- cfg
    forecast_cfg$window$train <- contract$index
    forecast_cfg$window$N <- contract$N
    forecast_cfg$window$origins <- cfg$refit_origin
    forecast_cfg$window$end <- cfg$refit_origin + cfg$window$horizon
    fc <- ism1_qforecast_static(e, cx, forecast_cfg, fit, draws)
    score <- iqt12_scores(fit_draws, fc$primary, source,
      forecast_cfg$window, cfg$p)
    add <- data.frame(id = cfg$id, cell = cfg$cell,
      candidate_id = cfg$candidate$id, model = "qdesn", engine = "mcmc",
      family = cfg$family, p = cfg$p, N = contract$N,
      fold = cfg$window$fold, chain = cfg$chain,
      refit_origin = cfg$refit_origin,
      offset = cfg$refit_origin - max(cfg$base_train),
      policy_id = contract$policy_id, window_type = contract$window_type,
      window_size = contract$window_size,
      readout_start = contract$start, readout_end = contract$end,
      tau_source = contract$tau_source)
    iqt12_csv(cbind(add[rep(1, nrow(score$summary)), ], score$summary),
      file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(score$draws, file.path(cfg$evidence, "metric_draws.csv.gz"))
    iqt12_csv(score$profile, file.path(cfg$evidence, "origin_lead.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(forecast_cfg$window), fc$primary),
      file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(forecast_cfg$window), fc$plugin),
      file.path(cfg$evidence, "plugin_location_draws.csv.gz"))
    iqt12_csv(fc$first_step_guard,
      file.path(cfg$evidence, "first_step_guard.csv"))
    iqt12_csv(data.frame(draw = seq_len(nrow(draws$beta)), sigma = draws$sigma,
      gamma = draws$gamma, draws$beta),
      file.path(cfg$evidence, "selected_parameters.csv.gz"))
    iqt12_csv(iqt12_nuisance_trace(fit$samp.sigma * cx$scale,
      fit$samp.gamma, fit$samp.beta[, 1L] * cx$scale),
      file.path(cfg$evidence, "nuisance_trace.csv.gz"))
    diag <- list(method = fit$diagnostics$core_update_mode,
      policy_id = contract$policy_id, refit_origin = cfg$refit_origin,
      base_train_start = min(cfg$base_train),
      base_train_end = max(cfg$base_train),
      readout_start = contract$start, readout_end = contract$end,
      readout_observations = contract$N,
      reservoir_history_first = cx$first,
      preprocessing_last = max(cfg$base_train),
      tau_source_original = cfg$candidate$tau_source_original,
      tau_source_recalibrated = cfg$candidate$tau_source,
      tau_model_scale = cfg$candidate$tau_source / cx$scale,
      design_rows = nrow(cx$object$X), design_hash = cx$design_hash,
      first_step_guard_pass = all(fc$first_step_guard$pass),
      sigma_ESS = unname(coda::effectiveSize(fit$samp.sigma)),
      gamma_ESS = unname(coda::effectiveSize(fit$samp.gamma)),
      intercept_ESS = unname(coda::effectiveSize(fit$samp.beta[, 1L])),
      total_seconds = proc.time()[["elapsed"]] - start,
      cpu_seconds = sum(proc.time()[c("user.self", "sys.self")]),
      diagnostic_grade_is_not_a_predictive_veto = TRUE,
      article_promotion = FALSE)
    iqt12_json(diag, file.path(cfg$evidence, "diagnostics.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = proc.time()[["elapsed"]] - start,
      fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
  }, error = function(err) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      message = conditionMessage(err),
      failed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
    stop(err)
  })
  invisible(TRUE)
}

irrv4_local_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  stopifnot(all(vapply(plan$status_path, irrv4_status, "") == "SUCCESS"))
  do.call(rbind, lapply(plan$config_path, function(path) {
    cfg <- iqt12_read(path)
    z <- read.csv(file.path(cfg$evidence, "summary.csv"),
      stringsAsFactors = FALSE)
    z$config_path <- path
    z
  }))
}

irrv4_imported_screen_results <- function(run) {
  imports <- read.csv(file.path(run, "manifests", "screen_imports.csv"),
    stringsAsFactors = FALSE)
  do.call(rbind, lapply(seq_len(nrow(imports)), function(i) {
    z <- read.csv(file.path(imports$evidence[i], "summary.csv"),
      stringsAsFactors = FALSE)
    z$config_path <- imports$config_path[i]
    z
  }))
}

irrv4_fixed_results <- function(run) {
  imports <- read.csv(file.path(run, "manifests", "expanding_fixed_imports.csv"),
    stringsAsFactors = FALSE)
  do.call(rbind, lapply(seq_len(nrow(imports)), function(i) {
    z <- read.csv(file.path(imports$evidence[i], "summary.csv"),
      stringsAsFactors = FALSE)
    cfg <- iqt12_read(imports$config_path[i])
    z$offset <- cfg$bridge_offset
    z$policy_id <- "expanding_fixed"
    z$window_type <- "expanding"
    z$window_size <- 0L
    z$readout_start <- min(cfg$base_train)
    z$readout_end <- cfg$refit_origin
    z$tau_source <- cfg$candidate$tau_source
    z$config_path <- imports$config_path[i]
    z
  }))
}

irrv4_parent_metric <- function(run, role, fold, origin) {
  imports <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  candidate <- if (role == "qdesn_mcmc") irrv4_candidate_id else NULL
  icav2_parent_origin_metric(imports, role, candidate, fold, origin)
}

irrv4_compare <- function(run, results) {
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  stopifnot(nrow(mae) == nrow(check), all(is.finite(mae$mean)),
    all(is.finite(check$mean)))
  rows <- lapply(seq_len(nrow(mae)), function(i) {
    fold <- mae$fold[i]; origin <- mae$refit_origin[i]
    same <- check$policy_id == mae$policy_id[i] & check$fold == fold &
      check$refit_origin == origin
    check_value <- check$mean[same]
    stopifnot(length(check_value) == 1L)
    static <- irrv4_parent_metric(run, "qdesn_mcmc", fold, origin)
    baseline <- irrv4_parent_metric(run, "baseline_mcmc", fold, origin)
    data.frame(policy_id = mae$policy_id[i], fold = fold, origin = origin,
      offset = origin - c(S1 = 8000L, S2 = 8250L, S3 = 8500L,
        S4 = 8750L)[fold], N = mae$N[i], tau_source = mae$tau_source[i],
      adapted_mae = mae$mean[i], static_mae = static[1L],
      baseline_mae = baseline[1L], adapted_check_loss = check_value,
      static_check_loss = static[2L], baseline_check_loss = baseline[2L],
      adapted_static_mae_ratio = mae$mean[i] / static[1L],
      adapted_baseline_mae_ratio = mae$mean[i] / baseline[1L],
      adapted_static_check_ratio = check_value / static[2L],
      adapted_baseline_check_ratio = check_value / baseline[2L])
  })
  do.call(rbind, rows)
}

irrv4_rank <- function(comparison) {
  z <- do.call(rbind, lapply(split(comparison, comparison$policy_id), function(x)
    data.frame(policy_id = x$policy_id[1L], cells = nrow(x),
      median_adapted_mae = median(x$adapted_mae),
      median_static_mae_ratio = median(x$adapted_static_mae_ratio),
      static_mae_wins = sum(x$adapted_static_mae_ratio < 1),
      median_baseline_mae_ratio = median(x$adapted_baseline_mae_ratio),
      baseline_mae_wins = sum(x$adapted_baseline_mae_ratio < 1),
      worst_baseline_mae_ratio = max(x$adapted_baseline_mae_ratio),
      median_baseline_check_ratio = median(x$adapted_baseline_check_ratio),
      baseline_check_wins = sum(x$adapted_baseline_check_ratio < 1),
      stringsAsFactors = FALSE)))
  z[order(z$median_baseline_mae_ratio, -z$baseline_mae_wins,
    z$median_baseline_check_ratio, z$worst_baseline_mae_ratio,
    z$policy_id), ]
}

irrv4_better_than_anchor <- function(selected, anchor, tolerance = 1e-12) {
  selected$median_baseline_mae_ratio <
      anchor$median_baseline_mae_ratio - tolerance ||
    (abs(selected$median_baseline_mae_ratio -
        anchor$median_baseline_mae_ratio) <= tolerance &&
      selected$baseline_mae_wins > anchor$baseline_mae_wins)
}

irrv4_aggregate_confirmation <- function(chain1, added, policy_id) {
  z <- rbind(chain1[chain1$policy_id == policy_id, ], added)
  keys <- c("policy_id", "fold", "refit_origin", "metric", "N", "tau_source")
  counts <- aggregate(z$mean, z[keys], length)
  stopifnot(nrow(counts) == 16L * length(unique(z$metric)), all(counts$x == 3L))
  mean_rows <- aggregate(z$mean, z[keys], mean)
  names(mean_rows)[names(mean_rows) == "x"] <- "mean"
  spread <- aggregate(z$mean, z[keys], function(x) max(x) - min(x))
  names(spread)[names(spread) == "x"] <- "chain_range"
  list(mean = mean_rows, spread = spread, raw = z)
}

irrv4_evidence_manifests <- function(run) {
  statuses <- list.files(file.path(run, "status"), pattern = "[.]json$",
    full.names = TRUE)
  manifests <- vapply(statuses, function(path) {
    status <- iqt12_read(path)
    if (status$status == "SUCCESS") status$manifest else NA_character_
  }, "")
  unique(manifests[!is.na(manifests)])
}

irrv4_closeout <- function(run, decision, details) {
  closeout <- c(list(status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE, active_jobs = 0L,
    fitted_model_binary_payloads = 0L, sealed_block_opened = FALSE), details)
  iqt12_json(closeout, file.path(run, "closeout.json"))
  payloads <- list.files(run, recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  stopifnot(!length(payloads))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "frozen_hashes.csv", "preflight.json",
    "closeout.json")), irrv4_files(file.path(run, "manifests")),
    irrv4_files(file.path(run, "plans")), irrv4_files(file.path(run, "configs")),
    irrv4_files(file.path(run, "status")),
    irrv4_files(file.path(run, "selections")),
    irrv4_files(file.path(run, "summaries")),
    irrv4_files(file.path(run, "review")), irrv4_evidence_manifests(run))
  iqt12_hash(files, file.path(run, "closeout_manifest.csv"))
  stopifnot(iqt12_verify(file.path(run, "closeout_manifest.csv")))
  "COMPLETE_REVIEW_REQUIRED"
}

irrv4_evaluate_screen <- function(run, local_results) {
  results <- irrv4_bind_rows(irrv4_fixed_results(run), local_results)
  comparison <- irrv4_compare(run, results)
  rank <- irrv4_rank(comparison)
  iqt12_csv(results, file.path(run, "summaries", "screen_metrics.csv"))
  iqt12_csv(comparison, file.path(run, "review", "screen_comparison.csv"))
  iqt12_csv(rank, file.path(run, "review", "screen_rank.csv"))
  anchor <- rank[rank$policy_id == "expanding_fixed", ]
  new <- rank[rank$policy_id != "expanding_fixed", ]
  selected <- new[1L, ]
  gate <- selected$median_baseline_mae_ratio < 1.05 &&
    selected$baseline_mae_wins >= 6L &&
    irrv4_better_than_anchor(selected, anchor)
  iqt12_json(as.list(selected), file.path(run, "selections",
    "screen_selected.json"))
  iqt12_json(list(status = if (gate) "PASS" else "STOP",
    selected_policy = selected$policy_id,
    selected_median_baseline_mae_ratio = selected$median_baseline_mae_ratio,
    selected_baseline_mae_wins = selected$baseline_mae_wins,
    anchor_median_baseline_mae_ratio = anchor$median_baseline_mae_ratio,
    anchor_baseline_mae_wins = anchor$baseline_mae_wins,
    rule = "new_policy_beats_expanding_fixed_and_median_exDQLM_MAE_ratio_below_1.05_and_at_least_6_of_12_wins"),
    file.path(run, "review", "screen_gate.json"))
  list(gate = gate, selected = selected, anchor = anchor)
}

irrv4_advance_screen <- function(run) {
  decision <- irrv4_evaluate_screen(run, irrv4_local_results(run, "screen"))
  selected <- decision$selected
  if (!decision$gate) return(irrv4_closeout(run,
    "NO_ROLLING_READOUT_IMPROVEMENT_OVER_EXPANDING_FIXED_RETAIN_V3",
    list(screen_jobs = 60L, validation_jobs = 0L, confirmation_jobs = 0L,
      selected_policy = selected$policy_id,
      next_action = "design_explicit_time_varying_readout_not_more_static_or_window_screening")))
  irrv4_make_plan(run, "validation", irrv4_validation_offsets,
    selected$policy_id, 1L)
  "validation"
}

irrv4_verify_source_at_frozen_head <- function(run) {
  campaign <- iqt12_read(file.path(run, "campaign.json"))
  manifest <- read.csv(file.path(run, "source_hashes.csv"),
    stringsAsFactors = FALSE)
  prefix <- paste0(normalizePath(campaign$repo, mustWork = TRUE), "/")
  stopifnot(all(startsWith(manifest$path, prefix)))
  observed <- vapply(manifest$path, function(path) {
    relative <- substring(path, nchar(prefix) + 1L)
    target <- tempfile("irrv4_frozen_source_")
    on.exit(unlink(target), add = TRUE)
    status <- system2("git", c("-C", campaign$repo, "show",
      paste0(campaign$head, ":", relative)), stdout = target)
    stopifnot(status == 0L, file.exists(target))
    unname(tools::sha256sum(target))
  }, "")
  stopifnot(identical(unname(observed), manifest$sha256))
  invisible(TRUE)
}

irrv4_verify_failed_screen <- function(failed_run) {
  stopifnot(dir.exists(failed_run),
    !file.exists(file.path(failed_run, "closeout.json")))
  irrv4_verify_source_at_frozen_head(failed_run)
  for (name in c("input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(failed_run, name))
  health <- irrv4_health(failed_run)
  stopifnot(health$total == 60L, health$complete == 60L,
    health$running == 0L, health$pending == 0L, health$failed == 0L)
  scheduler <- readLines(file.path(failed_run, "scheduler.status"), warn = FALSE)
  stopifnot(length(scheduler) == 1L,
    grepl("^PAUSED_REVIEW_REQUIRED", scheduler),
    grepl("unexpected_scheduler_exit_1", scheduler))
  plan <- read.csv(file.path(failed_run, "plans", "screen.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(plan) == 60L)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    status <- ifbv3_verify_status_manifest(plan$status_path[i])
    data.frame(id = cfg$id, policy_id = cfg$readout_policy$policy_id,
      fold = cfg$window$fold, origin = cfg$refit_origin, chain = cfg$chain,
      config_path = normalizePath(plan$config_path[i], mustWork = TRUE),
      config_sha256 = unname(tools::sha256sum(plan$config_path[i])),
      status_path = normalizePath(plan$status_path[i], mustWork = TRUE),
      status_sha256 = unname(tools::sha256sum(plan$status_path[i])),
      evidence = normalizePath(cfg$evidence, mustWork = TRUE),
      evidence_manifest = normalizePath(status$manifest, mustWork = TRUE),
      evidence_manifest_sha256 = unname(tools::sha256sum(status$manifest)),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

irrv4_recovery_code_files <- function(repo, e) unique(c(e$iqt12_loaded_files,
  file.path(repo, "R/exal_online_vbld.R"),
  file.path(repo, "validation/fitforecast_v2/R", c(
    "independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_sentinel_mechanism_recovery_v1.R",
    "independent_qdesn_causal_adaptation_v2.R",
    "independent_qdesn_mcmc_finalist_bridge_v3.R",
    "independent_qdesn_rolling_readout_v4.R")),
  file.path(repo, "validation/fitforecast_v2/scripts", c(
    "independent_qdesn_rolling_readout_v4.R",
    "run_independent_qdesn_rolling_readout_v4.sh")),
  file.path(repo, "validation/fitforecast_v2/docs",
    "INDEPENDENT_QDESN_ROLLING_READOUT_V4_20261009.md"),
  file.path(repo, "validation/fitforecast_v2/tests",
    "test_independent_qdesn_rolling_readout_v4.R")))

irrv4_recover_materialize <- function(repo, run, failed_run, library) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(failed_run),
    dir.exists(library))
  screen_imports <- irrv4_verify_failed_screen(failed_run)
  failed <- iqt12_read(file.path(failed_run, "campaign.json"))
  irrv4_verify_parent(failed$parent_run)
  head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  state <- failed
  state$schema <- irrv4_recovery_schema
  state$repo <- normalizePath(repo, mustWork = TRUE)
  state$run <- normalizePath(run, mustWork = TRUE)
  state$library <- normalizePath(library, mustWork = TRUE)
  state$head <- head
  state$superseded_run <- normalizePath(failed_run, mustWork = TRUE)
  state$superseded_head <- failed$head
  state$recovery_scope <- "metadata_column_alignment_only_no_model_reruns"
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(read.csv(file.path(failed_run, "candidate_bank.csv"),
    stringsAsFactors = FALSE), file.path(run, "candidate_bank.csv"))
  for (name in c("parent_imports.csv", "expanding_fixed_imports.csv"))
    iqt12_csv(read.csv(file.path(failed_run, "manifests", name),
      stringsAsFactors = FALSE), file.path(run, "manifests", name))
  iqt12_csv(screen_imports, file.path(run, "manifests", "screen_imports.csv"))
  environment <- iqt12_read(file.path(failed_run, "environment.json"))
  environment$schema <- irrv4_recovery_schema
  environment$source_head <- head
  environment$recovered_from <- normalizePath(failed_run, mustWork = TRUE)
  iqt12_json(environment, file.path(run, "environment.json"))
  e <- ism1_runtime(repo, library)
  iqt12_hash(irrv4_recovery_code_files(repo, e),
    file.path(run, "source_hashes.csv"))
  iqt12_hash(irrv4_files(file.path(library, "exdqlm")),
    file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "manifests/parent_imports.csv",
    "manifests/expanding_fixed_imports.csv", "manifests/screen_imports.csv")),
    file.path(failed_run, c("campaign.json", "source_hashes.csv",
      "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv",
      "plans/screen.csv", "plans/screen_hashes.csv"))),
    file.path(run, "input_hashes.csv"))
  decision <- irrv4_evaluate_screen(run, irrv4_imported_screen_results(run))
  if (decision$gate) irrv4_make_plan(run, "validation",
    irrv4_validation_offsets, decision$selected$policy_id, 1L)
  preflight <- list(schema = irrv4_recovery_schema,
    status = if (decision$gate) "READY_TO_RESUME_VALIDATION" else
      "SCREEN_GATE_STOP", imported_screen_jobs = 60L,
    model_jobs_rerun = 0L, possible_validation_jobs = 16L,
    possible_confirmation_jobs = 32L, sealed_block_opened = FALSE,
    article_changed = FALSE)
  iqt12_json(preflight, file.path(run, "preflight.json"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "preflight.json")),
    irrv4_files(file.path(run, "manifests")),
    list.files(file.path(run, "plans"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  irrv4_verify_imports(run)
  if (!decision$gate) irrv4_closeout(run,
    "NO_ROLLING_READOUT_IMPROVEMENT_OVER_EXPANDING_FIXED_RETAIN_V3",
    list(screen_jobs = 60L, imported_screen_jobs = 60L,
      validation_jobs = 0L, confirmation_jobs = 0L,
      selected_policy = decision$selected$policy_id,
      recovery_model_jobs_rerun = 0L,
      next_action = "design_explicit_time_varying_readout_not_more_static_or_window_screening"))
  invisible(preflight)
}

irrv4_advance_validation <- function(run) {
  selected <- iqt12_read(file.path(run, "selections", "screen_selected.json"))
  results <- irrv4_local_results(run, "validation")
  comparison <- irrv4_compare(run, results)
  rank <- irrv4_rank(comparison)
  iqt12_csv(results, file.path(run, "summaries", "validation_metrics.csv"))
  iqt12_csv(comparison, file.path(run, "review", "validation_comparison.csv"))
  iqt12_csv(rank, file.path(run, "review", "validation_rank.csv"))
  gate <- rank$median_baseline_mae_ratio[1L] < 1 &&
    rank$baseline_mae_wins[1L] >= 9L
  iqt12_json(list(status = if (gate) "PASS" else "STOP",
    selected_policy = rank$policy_id[1L],
    median_baseline_mae_ratio = rank$median_baseline_mae_ratio[1L],
    baseline_mae_wins = rank$baseline_mae_wins[1L],
    rule = "median_exDQLM_MAE_ratio_below_1_and_at_least_9_of_16_disjoint_origin_wins"),
    file.path(run, "review", "validation_gate.json"))
  if (!gate) return(irrv4_closeout(run,
    "ROLLING_READOUT_SCREEN_GAIN_FAILED_DISJOINT_ORIGIN_VALIDATION",
    list(screen_jobs = 60L, validation_jobs = 16L, confirmation_jobs = 0L,
      selected_policy = selected$policy_id,
      validation_median_baseline_mae_ratio = rank$median_baseline_mae_ratio[1L],
      validation_baseline_mae_wins = rank$baseline_mae_wins[1L],
      next_action = "design_explicit_time_varying_readout_not_more_window_screening")))
  irrv4_make_plan(run, "confirmation", irrv4_validation_offsets,
    selected$policy_id, 2:3)
  "confirmation"
}

irrv4_advance_confirmation <- function(run) {
  selected <- iqt12_read(file.path(run, "selections", "screen_selected.json"))
  aggregate <- irrv4_aggregate_confirmation(
    irrv4_local_results(run, "validation"),
    irrv4_local_results(run, "confirmation"), selected$policy_id)
  comparison <- irrv4_compare(run, aggregate$mean)
  rank <- irrv4_rank(comparison)
  iqt12_csv(aggregate$raw,
    file.path(run, "summaries", "confirmed_three_chain_metrics.csv"))
  iqt12_csv(aggregate$spread,
    file.path(run, "review", "confirmed_three_chain_metric_spread.csv"))
  iqt12_csv(comparison,
    file.path(run, "review", "confirmed_three_chain_comparison.csv"))
  iqt12_csv(rank, file.path(run, "review", "confirmed_three_chain_rank.csv"))
  confirmed <- rank$median_baseline_mae_ratio[1L] < 1 &&
    rank$baseline_mae_wins[1L] >= 9L
  decision <- if (confirmed)
    "ROLLING_READOUT_CONFIRMED_INTERNAL_FRESH_DGP_PROTOCOL_REQUIRED" else
    "ROLLING_READOUT_VALIDATION_GAIN_NOT_CONFIRMED_ACROSS_CHAINS"
  irrv4_closeout(run, decision,
    list(screen_jobs = 60L, validation_jobs = 16L, confirmation_jobs = 32L,
      selected_policy = selected$policy_id,
      confirmed_median_baseline_mae_ratio = rank$median_baseline_mae_ratio[1L],
      confirmed_baseline_mae_wins = rank$baseline_mae_wins[1L],
      three_chain_confirmed = confirmed,
      next_action = if (confirmed) "freeze_protocol_then_fresh_DGP_confirmation" else
        "design_explicit_time_varying_readout_not_more_window_screening"))
}

irrv4_advance <- function(run, stage) {
  irrv4_verify_imports(run)
  if (stage == "screen") return(irrv4_advance_screen(run))
  if (stage == "validation") return(irrv4_advance_validation(run))
  if (stage == "confirmation") return(irrv4_advance_confirmation(run))
  stop("Unsupported rolling-readout stage: ", stage)
}

irrv4_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "[.]csv$",
    full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  z <- do.call(rbind, lapply(plans, read.csv, stringsAsFactors = FALSE))
  status <- vapply(z$status_path, irrv4_status, "")
  data.frame(total = nrow(z), complete = sum(status == "SUCCESS"),
    running = sum(status == "RUNNING"), pending = sum(status == "PENDING"),
    failed = sum(grepl("FAILED", status)), stages = length(unique(z$stage)))
}
