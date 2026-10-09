idrv5_schema <- "independent_qdesn_dynamic_readout_v5"
idrv5_candidate_id <- "3a7a6653cb244f49813c"
idrv5_screen_offsets <- c(50L, 125L, 200L)
idrv5_validation_offsets <- c(25L, 75L, 150L, 220L)

idrv5_policies <- function() data.frame(
  policy_id = c("online_infinite", "half_life_1000", "half_life_500",
    "half_life_250", "half_life_125", "half_life_62p5"),
  half_life = c(Inf, 1000, 500, 250, 125, 62.5),
  half_life_label = c("infinite", "1000", "500", "250", "125", "62.5"),
  stringsAsFactors = FALSE)

idrv5_delta <- function(half_life) {
  if (is.character(half_life) && identical(tolower(half_life[1L]), "infinite"))
    return(1)
  half_life <- as.numeric(half_life)[1L]
  if (is.infinite(half_life)) return(1)
  stopifnot(is.finite(half_life), half_life > 0)
  2^(-1 / half_life)
}

idrv5_files <- function(path) {
  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  files[file.exists(files) & !file.info(files)$isdir]
}

idrv5_status <- function(path) {
  if (!file.exists(path)) return("PENDING")
  as.character(iqt12_read(path)$status)
}

idrv5_verify_parent <- function(parent_run) {
  stopifnot(dir.exists(parent_run))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv", "closeout_manifest.csv"))
    iqt12_verify(file.path(parent_run, name))
  closeout <- iqt12_read(file.path(parent_run, "closeout.json"))
  stopifnot(closeout$status == "COMPLETE_REVIEW_REQUIRED",
    closeout$scientific_decision ==
      "ROLLING_READOUT_SCREEN_GAIN_FAILED_DISJOINT_ORIGIN_VALIDATION",
    closeout$selected_policy == "rolling_1000", closeout$active_jobs == 0L,
    closeout$screen_jobs == 60L, closeout$validation_jobs == 16L,
    closeout$confirmation_jobs == 0L)
  health <- irrv4_health(parent_run)
  stopifnot(health$total == 16L, health$complete == 16L,
    health$running == 0L, health$pending == 0L, health$failed == 0L)
  irrv4_verify_imports(parent_run)
  invisible(list(closeout = closeout, health = health))
}

idrv5_control_manifest <- function(parent_run) {
  screen <- read.csv(file.path(parent_run, "manifests", "screen_imports.csv"),
    stringsAsFactors = FALSE)
  keep <- vapply(screen$config_path, function(path) {
    cfg <- iqt12_read(path)
    identical(cfg$readout_policy$policy_id, "rolling_1000")
  }, FALSE)
  screen <- screen[keep, ]
  screen$stage <- "screen"
  screen$origin <- vapply(screen$config_path,
    function(path) as.integer(iqt12_read(path)$refit_origin), 0L)

  plan <- read.csv(file.path(parent_run, "plans", "validation.csv"),
    stringsAsFactors = FALSE)
  validation <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    status <- ifbv3_verify_status_manifest(plan$status_path[i])
    data.frame(id = cfg$id, policy_id = cfg$readout_policy$policy_id,
      fold = cfg$window$fold, origin = cfg$refit_origin,
      config_path = normalizePath(plan$config_path[i], mustWork = TRUE),
      config_sha256 = unname(tools::sha256sum(plan$config_path[i])),
      status_path = normalizePath(plan$status_path[i], mustWork = TRUE),
      status_sha256 = unname(tools::sha256sum(plan$status_path[i])),
      evidence = normalizePath(cfg$evidence, mustWork = TRUE),
      evidence_manifest = normalizePath(status$manifest, mustWork = TRUE),
      evidence_manifest_sha256 = unname(tools::sha256sum(status$manifest)),
      stage = "validation", stringsAsFactors = FALSE)
  }))
  screen$policy_id <- "rolling_1000"
  screen <- screen[, names(validation)]
  out <- rbind(screen, validation)
  stopifnot(nrow(out) == 28L, all(out$policy_id == "rolling_1000"),
    sum(out$stage == "screen") == 12L,
    sum(out$stage == "validation") == 16L)
  out
}

idrv5_copy_imports <- function(parent_run, run) {
  parent <- read.csv(file.path(parent_run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  init <- parent[parent$role == "qdesn_mcmc" &
    parent$candidate_id == idrv5_candidate_id, ]
  stopifnot(nrow(init) == 12L, all(table(init$fold) == 3L),
    setequal(init$chain, 1:3))
  iqt12_csv(parent, file.path(run, "manifests", "parent_imports.csv"))
  iqt12_csv(init, file.path(run, "manifests", "m0_initialization_imports.csv"))
  iqt12_csv(idrv5_control_manifest(parent_run),
    file.path(run, "manifests", "rolling_control_imports.csv"))
  invisible(TRUE)
}

idrv5_verify_imports <- function(run) {
  for (name in c("parent_imports.csv", "m0_initialization_imports.csv",
      "rolling_control_imports.csv")) {
    x <- read.csv(file.path(run, "manifests", name), stringsAsFactors = FALSE)
    stopifnot(nrow(x) > 0L,
      identical(unname(tools::sha256sum(x$config_path)), x$config_sha256),
      identical(unname(tools::sha256sum(x$status_path)), x$status_sha256),
      identical(unname(tools::sha256sum(x$evidence_manifest)),
        x$evidence_manifest_sha256))
    for (path in x$evidence_manifest) iqt12_verify(path)
  }
  init <- read.csv(file.path(run, "manifests", "m0_initialization_imports.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(init) == 12L, all(table(init$fold) == 3L),
    all(file.exists(file.path(init$evidence, "selected_parameters.csv.gz"))))
  controls <- read.csv(file.path(run, "manifests", "rolling_control_imports.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(controls) == 28L, all(controls$policy_id == "rolling_1000"))
  invisible(TRUE)
}

idrv5_initial_draws <- function(run, fold) {
  imports <- read.csv(file.path(run, "manifests", "m0_initialization_imports.csv"),
    stringsAsFactors = FALSE)
  imports <- imports[imports$fold == fold, ]
  stopifnot(nrow(imports) == 3L, setequal(imports$chain, 1:3))
  draws <- do.call(rbind, lapply(seq_len(nrow(imports)), function(i) {
    path <- file.path(imports$evidence[i], "selected_parameters.csv.gz")
    z <- read.csv(path, check.names = FALSE)
    z$source_chain <- imports$chain[i]
    z$source_draw <- z$draw
    z
  }))
  beta_names <- grep("^var[0-9]+$", names(draws), value = TRUE)
  beta_names <- beta_names[order(as.integer(sub("var", "", beta_names)))]
  chain_counts <- table(draws$source_chain)
  stopifnot(length(beta_names) == 144L, length(chain_counts) == 3L,
    length(unique(as.integer(chain_counts))) == 1L,
    all(as.integer(chain_counts) >= 160L),
    all(is.finite(as.matrix(draws[, c("sigma", "gamma", beta_names)]))),
    all(draws$sigma > 0))
  list(raw = draws, beta = as.matrix(draws[, beta_names, drop = FALSE]),
    sigma = draws$sigma, gamma = draws$gamma, beta_names = beta_names,
    chains = sort(unique(draws$source_chain)))
}

idrv5_exact_xis <- function(e, sigma, gamma, p0) {
  abc <- lapply(gamma, function(g) e$exal_get_ABC(p0, g))
  A <- vapply(abc, `[[`, 0, "A")
  B <- pmax(vapply(abc, `[[`, 0, "B"), 1e-12)
  lambda <- vapply(abc, `[[`, 0, "C") * abs(gamma)
  out <- list(xi1 = mean(1 / (B * sigma)),
    xi_lambda = mean(lambda / B),
    xi_lambda2 = mean(lambda^2 * sigma / B),
    xi_A = mean(A / (B * sigma)),
    xi_A2 = mean(A^2 / (B * sigma)),
    zeta_lam = mean(lambda * A / B),
    xi_siginv = mean(1 / sigma))
  stopifnot(all(is.finite(unlist(out))), out$xi1 > 0,
    out$xi_A2 >= 0, out$xi_siginv > 0)
  out
}

idrv5_stabilize_covariance <- function(V, relative_floor = 1e-10) {
  V <- (as.matrix(V) + t(as.matrix(V))) / 2
  eigen <- eigen(V, symmetric = TRUE)
  floor <- max(1e-12, max(eigen$values) * relative_floor)
  clipped <- pmax(eigen$values, floor)
  out <- eigen$vectors %*% (clipped * t(eigen$vectors))
  out <- (out + t(out)) / 2
  attr(out, "eigen_floor") <- floor
  attr(out, "clipped_eigenvalues") <- sum(eigen$values < floor)
  out
}

idrv5_initial_state <- function(e, draws, p0) {
  V <- idrv5_stabilize_covariance(stats::cov(draws$beta))
  list(m = colMeans(draws$beta), V = V,
    xis = idrv5_exact_xis(e, draws$sigma, draws$gamma, p0),
    sigma = draws$sigma, gamma = draws$gamma,
    initial_eigen_floor = attr(V, "eigen_floor"),
    initial_clipped_eigenvalues = attr(V, "clipped_eigenvalues"),
    updates = 0L)
}

idrv5_update <- function(e, state, y_t, x_t, half_life) {
  delta <- idrv5_delta(half_life)
  prior_V <- state$V / delta
  local <- e$.online_local_update_one(y_t = y_t, x_t = x_t,
    qbeta = list(m = state$m, V = prior_V), xis = state$xis,
    n_alt = 2L)
  vx <- as.numeric(prior_V %*% x_t)
  denominator <- 1 / local$barw + sum(x_t * vx)
  pseudo_response <- local$barm / local$barw
  innovation <- pseudo_response - sum(x_t * state$m)
  gain <- vx / denominator
  updated_V <- prior_V - tcrossprod(vx) / denominator
  updated_V <- (updated_V + t(updated_V)) / 2
  clipped <- 0L
  if (((state$updates + 1L) %% 25L) == 0L) {
    updated_V <- idrv5_stabilize_covariance(updated_V)
    clipped <- attr(updated_V, "clipped_eigenvalues")
  }
  stopifnot(all(is.finite(updated_V)), all(diag(updated_V) > 0))
  state$m <- state$m + gain * innovation
  state$V <- updated_V
  state$updates <- state$updates + 1L
  state$last <- list(delta = delta, barw = local$barw,
    barm = local$barm, pseudo_response = pseudo_response,
    innovation = innovation, gain_l2 = sqrt(sum(gain^2)),
    covariance_trace = sum(diag(updated_V)),
    clipped_eigenvalues = clipped)
  state
}

idrv5_policy <- function(policy_id) {
  z <- idrv5_policies()
  z <- z[z$policy_id == policy_id, ]
  stopifnot(nrow(z) == 1L)
  z
}

idrv5_config <- function(state, fold, policy_id, stage, replicate = 1L) {
  offsets <- if (stage == "screen") idrv5_screen_offsets else
    idrv5_validation_offsets
  selected <- list(candidate_id = idrv5_candidate_id,
    mode = "exact_m0_initialized_dynamic_readout_adf")
  cfg <- icav2_bridge_config(state, selected, fold, max(offsets))
  policy <- idrv5_policy(policy_id)
  cfg$schema <- idrv5_schema; cfg$stage <- stage
  cfg$engine <- "m0_initialized_adf"; cfg$model <- "qdesn"
  cfg$policy_id <- policy_id; cfg$half_life <- policy$half_life_label
  cfg$discount_delta <- idrv5_delta(policy$half_life)
  cfg$replicate <- as.integer(replicate); cfg$offsets <- offsets
  cfg$origins <- as.integer(max(cfg$base_train) + offsets)
  cfg$window$origins <- cfg$origins
  cfg$window$end <- max(cfg$origins) + cfg$window$horizon
  cfg$id <- paste(stage, cfg$cell, "qdesn", cfg$engine, fold,
    idrv5_candidate_id, policy_id, paste0("rep", replicate), sep = "__")
  cfg$seed <- ism1_seed(cfg$id)
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$timeout <- 21600L
  cfg
}

idrv5_make_plan <- function(run, stage, policies, replicates = 1L) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  configs <- list()
  for (policy in policies) for (fold in ism1_folds) for (replicate in replicates)
    configs[[length(configs) + 1L]] <- idrv5_config(state, fold, policy,
      stage, replicate)
  iqt12_plan(state, configs, stage)
  invisible(configs)
}

idrv5_materialize <- function(repo, run, parent_run, library) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(parent_run),
    dir.exists(library))
  idrv5_verify_parent(parent_run)
  parent <- iqt12_read(file.path(parent_run, "campaign.json"))
  head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = idrv5_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE), head = head,
    parent_run = normalizePath(parent_run, mustWork = TRUE),
    parent_head = parent$head, references = parent$references,
    bank = parent$bank, candidate_id = idrv5_candidate_id,
    folds = ism1_folds, screen_offsets = idrv5_screen_offsets,
    validation_offsets = idrv5_validation_offsets,
    policies = idrv5_policies(),
    contract = list(selection_block = "internal_training_only_S1_to_S4",
      sealed_block = "source_indices_9001_to_10000_unopened",
      initialization = "three_chain_exact_M0_posterior_moments",
      transition = "exAL_local_moment_Gaussian_assumed_density_filter",
      evolution = "coefficient_covariance_discount",
      nuisance_policy = "fixed_exact_M0_Monte_Carlo_moments",
      estimator_scope = "mechanism_screen_not_exact_MCMC_replacement",
      teacher_forced_between_origins = TRUE,
      recursive_within_origin = TRUE, horizon = 30L,
      primary_metric = "forecast_mae",
      secondary_metrics = c("forecast_check_loss", "forecast_rmse"),
      diagnostics_are_descriptive_not_predictive_veto = TRUE,
      article_promotion = FALSE))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(read.csv(file.path(parent_run, "candidate_bank.csv"),
    stringsAsFactors = FALSE), file.path(run, "candidate_bank.csv"))
  idrv5_copy_imports(parent_run, run)
  env <- list(schema = idrv5_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    package_path = find.package("exdqlm", lib.loc = library),
    session = capture.output(sessionInfo()),
    threads = list(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1,
      MKL_NUM_THREADS = 1, RCPP_PARALLEL_NUM_THREADS = 1),
    source_head = head)
  iqt12_json(env, file.path(run, "environment.json"))
  configs <- idrv5_make_plan(run, "screen", idrv5_policies()$policy_id, 1L)
  e <- ism1_runtime(repo, library)
  code <- unique(c(e$iqt12_loaded_files, file.path(repo, "R/exal_online_vbld.R"),
    file.path(repo, "validation/fitforecast_v2/R", c(
      "independent_qdesn_training1000_runtime_v1.R",
      "independent_qdesn_training1000_campaign_v1.R",
      "independent_qdesn_sentinel_mechanism_v1.R",
      "independent_qdesn_sentinel_mechanism_recovery_v1.R",
      "independent_qdesn_causal_adaptation_v2.R",
      "independent_qdesn_mcmc_finalist_bridge_v3.R",
      "independent_qdesn_rolling_readout_v4.R",
      "independent_qdesn_dynamic_readout_v5.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_dynamic_readout_v5.R",
      "run_independent_qdesn_dynamic_readout_v5.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_DYNAMIC_READOUT_V5_20261009.md"),
    file.path(repo, "validation/fitforecast_v2/tests",
      "test_independent_qdesn_dynamic_readout_v5.R")))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(irrv4_files(file.path(library, "exdqlm")),
    file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv")), idrv5_files(file.path(run, "manifests")),
    file.path(parent_run, c("campaign.json", "source_hashes.csv",
      "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv",
      "closeout.json", "closeout_manifest.csv"))),
    file.path(run, "input_hashes.csv"))
  preflight <- list(schema = idrv5_schema, status = "READY_TO_LAUNCH",
    m0_initialization_chains = 12L, rolling_control_cells = 28L,
    screen_jobs = length(configs), possible_validation_jobs = 4L,
    possible_confirmation_jobs = 8L, maximum_new_jobs = 36L,
    sealed_block_opened = FALSE, article_changed = FALSE)
  iqt12_json(preflight, file.path(run, "preflight.json"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "preflight.json")),
    idrv5_files(file.path(run, "manifests")),
    list.files(file.path(run, "plans"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  idrv5_verify_imports(run)
  invisible(preflight)
}

idrv5_resample_nuisance <- function(state, n, seed) {
  set.seed(seed)
  index <- sample.int(length(state$sigma), n, replace = length(state$sigma) < n)
  list(sigma = state$sigma[index], gamma = state$gamma[index])
}

idrv5_forecast <- function(e, cx, cfg, state, origin) {
  beta <- ism1_mvn(state$m, state$V, cfg$outer, cfg$seed + origin +
    100000L * cfg$replicate)
  nuisance <- idrv5_resample_nuisance(state, cfg$outer,
    cfg$seed + origin + 200000L * cfg$replicate)
  draws <- list(beta = beta, sigma = nuisance$sigma, gamma = nuisance$gamma)
  object <- cx$object
  object$fit <- list(misc = list(p0 = cfg$p))
  local <- origin - cx$first + 1L
  H <- cfg$window$horizon
  bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L, cfg$inner,
    cfg$seed + origin + 300000L * cfg$replicate)
  noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1L]]
  repeated <- e$iqcf_v3_repeat_draws(draws, cfg$inner)
  path <- ism1_particle_paths(e, object, cx$y, local, H, repeated, noise,
    capture_first_step = TRUE)
  primary <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws,
    cfg$outer, cfg$inner, "mean") * cx$scale
  zeros <- matrix(0, H, cfg$outer)
  plugin <- ism1_particle_paths(e, object, cx$y, local, H, draws,
    list(s = zeros, v = zeros, z = zeros))$mu_draws * cx$scale
  expected_x <- matrix(cx$all_X[local + 1L, ],
    nrow = nrow(path$first_step_x), ncol = ncol(path$first_step_x))
  expected_prediction <- cx$all_X[local + 1L, , drop = FALSE] %*%
    t(draws$beta) * cx$scale
  guard <- ism1_assert_first_step(expected_x, path$first_step_x,
    expected_prediction, primary[1L, , drop = FALSE])
  list(primary = primary, plugin = plugin, draws = draws,
    guard = data.frame(origin = origin,
      feature_max_absolute_error = guard$feature$max_absolute_error,
      feature_max_relative_error = guard$feature$max_relative_error,
      prediction_max_absolute_error = guard$prediction$max_absolute_error,
      prediction_max_relative_error = guard$prediction$max_relative_error,
      prediction_comparison_scale = guard$prediction$comparison_scale,
      pass = TRUE))
}

idrv5_worker <- function(path) {
  cfg <- iqt12_read(path); start <- proc.time()[["elapsed"]]
  e <- ism1_runtime(cfg$repo, cfg$library)
  for (name in c("source_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(!file.exists(cfg$status_path),
    unname(tools::sha256sum(cfg$source_path)) == cfg$source_sha,
    max(cfg$origins) + cfg$window$horizon <= 9000L,
    min(cfg$origins) > max(cfg$base_train))
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", pid = Sys.getpid(), id = cfg$id,
    started = format(Sys.time(), tz = "UTC", usetz = TRUE)), cfg$status_path)
  tryCatch({
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source); full[source$t, ] <- source; source <- full
    cx <- ism1_design(e, cfg, source, cfg$window$end)
    imported <- idrv5_initial_draws(cfg$run, cfg$window$fold)
    state <- idrv5_initial_state(e, imported, cfg$p)
    initial_m <- state$m
    set.seed(cfg$seed + 11L)
    init_index <- sample.int(nrow(imported$beta), cfg$outer)
    base_fit <- cx$object$X %*% t(imported$beta[init_index, , drop = FALSE]) *
      cx$scale
    stopifnot(nrow(base_fit) == length(cfg$base_train),
      ncol(base_fit) == cfg$outer)
    previous <- max(cfg$base_train)
    summaries <- metric_draws <- profiles <- locations <- plugins <- guards <-
      traces <- states <- list()
    for (i in seq_along(cfg$origins)) {
      origin <- cfg$origins[i]
      idx <- seq.int(previous + 1L, origin)
      step_trace <- vector("list", length(idx))
      for (j in seq_along(idx)) {
        local <- idx[j] - cx$first + 1L
        state <- idrv5_update(e, state, cx$y[local],
          cx$all_X[local, , drop = TRUE], cfg$half_life)
        step_trace[[j]] <- data.frame(t = idx[j], origin = origin,
          delta = state$last$delta, barw = state$last$barw,
          barm = state$last$barm, innovation = state$last$innovation,
          gain_l2 = state$last$gain_l2,
          covariance_trace = state$last$covariance_trace,
          clipped_eigenvalues = state$last$clipped_eigenvalues)
      }
      previous <- origin
      forecast <- idrv5_forecast(e, cx, cfg, state, origin)
      one_window <- cfg$window
      one_window$train <- cfg$base_train; one_window$N <- length(cfg$base_train)
      one_window$origins <- origin; one_window$end <- origin + one_window$horizon
      score <- iqt12_scores(base_fit, forecast$primary, source,
        one_window, cfg$p)
      metadata <- data.frame(id = cfg$id, cell = cfg$cell,
        candidate_id = cfg$candidate$id, model = "qdesn",
        engine = cfg$engine, family = cfg$family, p = cfg$p,
        fold = cfg$window$fold, replicate = cfg$replicate,
        origin = origin, offset = origin - max(cfg$base_train),
    policy_id = cfg$policy_id, half_life = cfg$half_life,
        discount_delta = cfg$discount_delta,
        initialization_chains = length(imported$chains),
        initialization_draws = nrow(imported$beta))
      summaries[[i]] <- cbind(metadata[rep(1L, nrow(score$summary)), ],
        score$summary)
      score$draws$origin <- origin; metric_draws[[i]] <- score$draws
      profiles[[i]] <- score$profile
      locations[[i]] <- cbind(iqt12_grid(one_window), forecast$primary)
      plugins[[i]] <- cbind(iqt12_grid(one_window), forecast$plugin)
      guards[[i]] <- forecast$guard
      traces[[i]] <- do.call(rbind, step_trace)
      states[[i]] <- data.frame(origin = origin, updates = state$updates,
        beta_l2_shift = sqrt(sum((state$m - initial_m)^2)),
        intercept_shift = state$m[1L] - initial_m[1L],
        covariance_trace = sum(diag(state$V)),
        covariance_max_diagonal = max(diag(state$V)),
        covariance_min_diagonal = min(diag(state$V)))
    }
    iqt12_csv(do.call(rbind, summaries), file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(do.call(rbind, metric_draws),
      file.path(cfg$evidence, "metric_draws.csv.gz"))
    iqt12_csv(do.call(rbind, profiles),
      file.path(cfg$evidence, "origin_lead.csv.gz"))
    iqt12_csv(do.call(rbind, locations),
      file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
    iqt12_csv(do.call(rbind, plugins),
      file.path(cfg$evidence, "plugin_location_draws.csv.gz"))
    iqt12_csv(do.call(rbind, guards),
      file.path(cfg$evidence, "first_step_guard.csv"))
    iqt12_csv(do.call(rbind, traces),
      file.path(cfg$evidence, "dynamic_update_trace.csv.gz"))
    iqt12_csv(do.call(rbind, states),
      file.path(cfg$evidence, "origin_state_summary.csv"))
    iqt12_json(list(estimator =
        "exact_M0_initialized_exAL_local_moment_Gaussian_ADF",
      exact_mcmc_after_initialization = FALSE,
      policy_id = cfg$policy_id, half_life = cfg$half_life,
      discount_delta = cfg$discount_delta,
      initial_chains = imported$chains,
      initial_draws = nrow(imported$beta),
      initial_eigen_floor = state$initial_eigen_floor,
      initial_clipped_eigenvalues = state$initial_clipped_eigenvalues,
      nuisance_moments_fixed = TRUE,
      first_step_guard_pass = all(do.call(rbind, guards)$pass),
      total_seconds = proc.time()[["elapsed"]] - start,
      diagnostic_grade_is_not_a_predictive_veto = TRUE,
      article_promotion = FALSE),
      file.path(cfg$evidence, "diagnostics.json"))
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

idrv5_local_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  stopifnot(all(vapply(plan$status_path, idrv5_status, "") == "SUCCESS"))
  do.call(rbind, lapply(plan$config_path, function(path) {
    z <- read.csv(file.path(iqt12_read(path)$evidence, "summary.csv"),
      stringsAsFactors = FALSE)
    z$config_path <- path
    z
  }))
}

idrv5_control_metric <- function(run, fold, origin) {
  controls <- read.csv(file.path(run, "manifests", "rolling_control_imports.csv"),
    stringsAsFactors = FALSE)
  z <- controls[controls$fold == fold & controls$origin == origin, ]
  stopifnot(nrow(z) == 1L)
  summary <- read.csv(file.path(z$evidence, "summary.csv"),
    stringsAsFactors = FALSE)
  c(forecast_mae = summary$mean[summary$metric == "forecast_mae"],
    forecast_check_loss = summary$mean[summary$metric == "forecast_check_loss"])
}

idrv5_baseline_metric <- function(run, fold, origin) {
  imports <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  icav2_parent_origin_metric(imports, "baseline_mcmc", NULL, fold, origin)
}

idrv5_compare <- function(run, results) {
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  stopifnot(nrow(mae) == nrow(check), all(is.finite(mae$mean)),
    all(is.finite(check$mean)))
  do.call(rbind, lapply(seq_len(nrow(mae)), function(i) {
    same <- check$policy_id == mae$policy_id[i] &
      check$fold == mae$fold[i] & check$origin == mae$origin[i] &
      check$replicate == mae$replicate[i]
    check_value <- check$mean[same]
    stopifnot(length(check_value) == 1L)
    rolling <- idrv5_control_metric(run, mae$fold[i], mae$origin[i])
    baseline <- idrv5_baseline_metric(run, mae$fold[i], mae$origin[i])
    data.frame(policy_id = mae$policy_id[i], half_life = mae$half_life[i],
      fold = mae$fold[i], origin = mae$origin[i], offset = mae$offset[i],
      replicate = mae$replicate[i], dynamic_mae = mae$mean[i],
      rolling_mae = rolling[1L], baseline_mae = baseline[1L],
      dynamic_check_loss = check_value, rolling_check_loss = rolling[2L],
      baseline_check_loss = baseline[2L],
      dynamic_rolling_mae_ratio = mae$mean[i] / rolling[1L],
      dynamic_baseline_mae_ratio = mae$mean[i] / baseline[1L],
      dynamic_rolling_check_ratio = check_value / rolling[2L],
      dynamic_baseline_check_ratio = check_value / baseline[2L])
  }))
}

idrv5_rank <- function(comparison) {
  z <- do.call(rbind, lapply(split(comparison, comparison$policy_id), function(x)
    data.frame(policy_id = x$policy_id[1L], half_life = x$half_life[1L],
      cells = nrow(x), median_dynamic_mae = median(x$dynamic_mae),
      median_rolling_mae_ratio = median(x$dynamic_rolling_mae_ratio),
      rolling_mae_wins = sum(x$dynamic_rolling_mae_ratio < 1),
      median_baseline_mae_ratio = median(x$dynamic_baseline_mae_ratio),
      baseline_mae_wins = sum(x$dynamic_baseline_mae_ratio < 1),
      worst_baseline_mae_ratio = max(x$dynamic_baseline_mae_ratio),
      median_baseline_check_ratio = median(x$dynamic_baseline_check_ratio),
      baseline_check_wins = sum(x$dynamic_baseline_check_ratio < 1),
      stringsAsFactors = FALSE)))
  z[order(z$median_baseline_mae_ratio, -z$baseline_mae_wins,
    z$median_rolling_mae_ratio, z$median_baseline_check_ratio,
    z$worst_baseline_mae_ratio, z$policy_id), ]
}

idrv5_evidence_manifests <- function(run) {
  statuses <- list.files(file.path(run, "status"), pattern = "[.]json$",
    full.names = TRUE)
  manifests <- vapply(statuses, function(path) {
    status <- iqt12_read(path)
    if (status$status == "SUCCESS") status$manifest else NA_character_
  }, "")
  unique(manifests[!is.na(manifests)])
}

idrv5_closeout <- function(run, decision, details) {
  closeout <- c(list(status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE, active_jobs = 0L,
    fitted_model_binary_payloads = 0L, sealed_block_opened = FALSE,
    estimator_is_exact_mcmc = FALSE,
    integration_scope = "validation_only_no_article_metric_replacement"), details)
  iqt12_json(closeout, file.path(run, "closeout.json"))
  payloads <- list.files(run, recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  stopifnot(!length(payloads))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "frozen_hashes.csv", "preflight.json",
    "closeout.json")), idrv5_files(file.path(run, "manifests")),
    idrv5_files(file.path(run, "plans")), idrv5_files(file.path(run, "configs")),
    idrv5_files(file.path(run, "status")),
    idrv5_files(file.path(run, "selections")),
    idrv5_files(file.path(run, "summaries")),
    idrv5_files(file.path(run, "review")), idrv5_evidence_manifests(run))
  iqt12_hash(files, file.path(run, "closeout_manifest.csv"))
  stopifnot(iqt12_verify(file.path(run, "closeout_manifest.csv")))
  "COMPLETE_REVIEW_REQUIRED"
}

idrv5_evaluate <- function(run, stage, results) {
  comparison <- idrv5_compare(run, results)
  rank <- idrv5_rank(comparison)
  iqt12_csv(results, file.path(run, "summaries", paste0(stage, "_metrics.csv")))
  iqt12_csv(comparison, file.path(run, "review", paste0(stage,
    "_comparison.csv")))
  iqt12_csv(rank, file.path(run, "review", paste0(stage, "_rank.csv")))
  list(comparison = comparison, rank = rank)
}

idrv5_advance_screen <- function(run) {
  evaluated <- idrv5_evaluate(run, "screen", idrv5_local_results(run, "screen"))
  selected <- evaluated$rank[1L, ]
  gate <- selected$median_rolling_mae_ratio < 1 &&
    selected$baseline_mae_wins >= 6L
  iqt12_json(as.list(selected), file.path(run, "selections",
    "screen_selected.json"))
  iqt12_json(list(status = if (gate) "PASS" else "STOP",
    selected_policy = selected$policy_id,
    selected_half_life = selected$half_life,
    median_rolling_mae_ratio = selected$median_rolling_mae_ratio,
    baseline_mae_wins = selected$baseline_mae_wins,
    rule = "strict_median_MAE_improvement_over_rolling1000_and_at_least_6_of_12_exDQLM_wins"),
    file.path(run, "review", "screen_gate.json"))
  if (!gate) return(idrv5_closeout(run,
    "NO_DYNAMIC_READOUT_SCREEN_GAIN_OVER_ROLLING1000",
    list(screen_jobs = 24L, validation_jobs = 0L, confirmation_jobs = 0L,
      selected_policy = selected$policy_id,
      next_action = "reject_tested_ADF_dynamic_readout_and_reassess_model_class")))
  idrv5_make_plan(run, "validation", selected$policy_id, 1L)
  "validation"
}

idrv5_advance_validation <- function(run) {
  evaluated <- idrv5_evaluate(run, "validation",
    idrv5_local_results(run, "validation"))
  selected <- evaluated$rank[1L, ]
  gate <- selected$median_baseline_mae_ratio < 1 &&
    selected$baseline_mae_wins >= 9L && selected$median_rolling_mae_ratio < 1
  iqt12_json(list(status = if (gate) "PASS" else "STOP",
    selected_policy = selected$policy_id,
    median_baseline_mae_ratio = selected$median_baseline_mae_ratio,
    baseline_mae_wins = selected$baseline_mae_wins,
    median_rolling_mae_ratio = selected$median_rolling_mae_ratio,
    rule = "median_exDQLM_MAE_ratio_below_1_at_least_9_of_16_wins_and_strict_median_improvement_over_rolling1000"),
    file.path(run, "review", "validation_gate.json"))
  if (!gate) return(idrv5_closeout(run,
    "DYNAMIC_READOUT_SCREEN_GAIN_FAILED_DISJOINT_ORIGIN_VALIDATION",
    list(screen_jobs = 24L, validation_jobs = 4L, confirmation_jobs = 0L,
      selected_policy = selected$policy_id,
      validation_median_baseline_mae_ratio = selected$median_baseline_mae_ratio,
      validation_baseline_mae_wins = selected$baseline_mae_wins,
      validation_median_rolling_mae_ratio = selected$median_rolling_mae_ratio,
      next_action = "reject_tested_ADF_dynamic_readout_and_reassess_model_class")))
  idrv5_make_plan(run, "confirmation", selected$policy_id, 2:3)
  "confirmation"
}

idrv5_advance_confirmation <- function(run) {
  first <- idrv5_local_results(run, "validation")
  added <- idrv5_local_results(run, "confirmation")
  z <- rbind(first, added)
  keys <- c("policy_id", "half_life", "fold", "origin", "offset", "metric")
  counts <- aggregate(z$mean, z[keys], length)
  stopifnot(all(counts$x == 3L))
  means <- aggregate(z$mean, z[keys], mean)
  names(means)[names(means) == "x"] <- "mean"
  means$replicate <- 0L
  evaluated <- idrv5_evaluate(run, "confirmation", means)
  selected <- evaluated$rank[1L, ]
  gate <- selected$median_baseline_mae_ratio < 1 &&
    selected$baseline_mae_wins >= 9L && selected$median_rolling_mae_ratio < 1
  iqt12_csv(z, file.path(run, "summaries", "confirmation_replicates.csv"))
  iqt12_json(list(status = if (gate) "PASS" else "STOP",
    selected_policy = selected$policy_id,
    median_baseline_mae_ratio = selected$median_baseline_mae_ratio,
    baseline_mae_wins = selected$baseline_mae_wins,
    median_rolling_mae_ratio = selected$median_rolling_mae_ratio),
    file.path(run, "review", "confirmation_gate.json"))
  idrv5_closeout(run, if (gate)
    "DYNAMIC_READOUT_MECHANISM_CONFIRMED_REQUIRES_FORMAL_ESTIMATOR_AND_FRESH_DGP" else
    "DYNAMIC_READOUT_GAIN_NOT_CONFIRMED_ACROSS_POSTERIOR_PREDICTIVE_SEEDS",
    list(screen_jobs = 24L, validation_jobs = 4L, confirmation_jobs = 8L,
      selected_policy = selected$policy_id,
      confirmation_median_baseline_mae_ratio = selected$median_baseline_mae_ratio,
      confirmation_baseline_mae_wins = selected$baseline_mae_wins,
      confirmation_median_rolling_mae_ratio = selected$median_rolling_mae_ratio,
      next_action = if (gate)
        "formalize_dynamic_Bayesian_readout_then_confirm_on_fresh_DGP" else
        "reject_tested_ADF_dynamic_readout_and_reassess_model_class"))
}

idrv5_advance <- function(run, stage) {
  stopifnot(!file.exists(file.path(run, "closeout.json")))
  switch(stage, screen = idrv5_advance_screen(run),
    validation = idrv5_advance_validation(run),
    confirmation = idrv5_advance_confirmation(run),
    stop("Unknown stage"))
}

idrv5_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "^[a-z]+[.]csv$",
    full.names = TRUE)
  if (!length(plans)) return(data.frame())
  do.call(rbind, lapply(plans, function(path) {
    x <- read.csv(path, stringsAsFactors = FALSE)
    status <- vapply(x$status_path, idrv5_status, "")
    data.frame(stage = sub("[.]csv$", "", basename(path)), total = nrow(x),
      complete = sum(status == "SUCCESS"),
      running = sum(status == "RUNNING"), pending = sum(status == "PENDING"),
      failed = sum(!status %in% c("SUCCESS", "RUNNING", "PENDING")))
  }))
}
