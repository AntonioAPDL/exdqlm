itm6_schema <- "independent_qdesn_training_size_mechanism_v6"
itm6_stages <- c("smoke", "representation", "quantile", "validation",
  "rolling", "mcmc")
itm6_cells <- c("normal__exal__p005", "laplace__exal__p005",
  "gausmix__al__p005")
itm6_folds <- c(S1 = 7000L, S2 = 7500L, S3 = 8000L, S4 = 8500L)
itm6_training_sizes <- c(500L, 1000L, 2000L, 5000L)
itm6_tau_multipliers <- c(0.1, 0.3, 1, 3)

itm6_parent_run <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_training1000_targeted_v2_20261006/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_training1000_targeted_v2_20261006_060137__git-c27fc70a")
itm6_sentinel_run <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_sentinel_mechanism_recovery_v1_20261008/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_sentinel_mechanism_recovery_v1_20261008_051156__git-d1093191")

itm6_window <- function(fold, N, candidate, origin_stride = 30L) {
  stopifnot(fold %in% names(itm6_folds), N %in% itm6_training_sizes,
    origin_stride %in% c(30L, 60L))
  end <- unname(itm6_folds[fold])
  train <- seq.int(end - N + 1L, end)
  washout <- seq.int(min(train) - 500L, min(train) - 1L)
  m <- as.integer(candidate$m)
  buffer <- seq.int(min(washout) - max(500L, m), min(washout) - 1L)
  stopifnot(min(buffer) >= 1L)
  list(fold = fold, N = as.integer(N), train = train, washout = washout,
    buffer = buffer, origins = seq.int(end, end + 210L, origin_stride),
    end = end + 240L, horizon = 30L, origin_stride = origin_stride)
}

itm6_seed <- function(...) {
  key <- digest::digest(paste(..., collapse = "|"), algo = "sha256")
  83000000L + strtoi(substr(key, 1L, 7L), base = 16L) %% 9000000L
}

itm6_candidate <- function(candidate, reference, role, tau_multiplier = 1,
                           N = 1000L) {
  n <- iqt12_unpack(candidate$n)
  stopifnot(length(n) >= 1L, length(n) <= 6L, all(n >= 20L),
    sum(n) <= 2500L, candidate$m >= 1L, candidate$m <= 500L,
    candidate$alpha > 0, candidate$alpha < 1,
    candidate$rho > 0, candidate$rho < 1,
    tau_multiplier > 0, N > 0L)
  candidate$n <- paste(n, collapse = ";")
  candidate$n_tilde <- paste(head(n, -1L), collapse = ";")
  candidate$D <- length(n)
  candidate$total_states <- sum(n)
  candidate$readout_mode <- "reservoir_only"
  candidate$readout_dimension <- sum(n) + 1L
  candidate$matrix_seed <- 920001L
  candidate$input_fanin <- min(as.integer(candidate$input_fanin),
    as.integer(candidate$m) + 1L)
  candidate$recurrent_indegree <- min(as.integer(candidate$recurrent_indegree),
    min(n))
  candidate$interlayer_fanin <- if (length(n) == 1L) 1L else
    min(as.integer(candidate$interlayer_fanin), min(n))
  candidate$effective_p0 <- as.numeric(candidate$effective_p0 %||% 15)
  candidate$lag_precision_multiplier <- 1
  p <- candidate$readout_dimension - 1L
  p0 <- min(max(1, candidate$effective_p0), max(1, p - 1))
  response_scale <- reference$candidate$sigma_b_source %||%
    reference$candidate$response_scale %||% 1
  candidate$tau_source <- response_scale * p0 / max(1, p - p0) /
    sqrt(N) * tau_multiplier
  candidate$tau_multiplier <- tau_multiplier
  candidate$tau_reference_N <- as.integer(N)
  candidate$slab_source <- reference$candidate$slab_source
  candidate$sigma_b_source <- reference$candidate$sigma_b_source
  candidate$omega_b_source <- reference$candidate$omega_b_source
  candidate$role <- role
  fields <- c("n", "m", "alpha", "rho", "center_scale", "input_bound",
    "input_gain", "recurrent_indegree", "input_fanin", "interlayer_fanin",
    "matrix_seed", "readout_mode")
  candidate$structure_id <- substr(digest::digest(candidate[fields],
    algo = "sha256"), 1L, 16L)
  candidate$id <- substr(digest::digest(list(schema = itm6_schema,
    structure = candidate$structure_id, tau_source = candidate$tau_source,
    role = role), algo = "sha256"), 1L, 20L)
  candidate
}

itm6_large_template <- function(reference, n, m, alpha, rho, input_gain,
                                role) {
  candidate <- reference$candidate
  candidate$n <- paste(n, collapse = ";")
  candidate$m <- as.integer(m)
  candidate$alpha <- alpha
  candidate$rho <- rho
  candidate$input_gain <- input_gain
  candidate$input_fanin <- max(1L, ceiling((m + 1L) * 0.1))
  candidate$recurrent_indegree <- min(40L, min(n))
  candidate$interlayer_fanin <- min(40L, min(n))
  candidate$center_scale <- "median_mad"
  candidate$input_bound <- "tanh_z_over_3"
  candidate$effective_p0 <- min(60, max(8, round(sum(n) * 0.025)))
  itm6_candidate(candidate, reference, role)
}

itm6_candidate_panel <- function(reference, sentinel_bank) {
  ids <- c("23eb3c867723c85379f2", "3a7a6653cb244f49813c",
    "692c5633606b6c208a69", "3dd60ff4dedae56a62a5",
    "94db7090bd0c4ea2bd01")
  old <- lapply(ids, function(id) {
    row <- sentinel_bank[sentinel_bank$id == id, , drop = FALSE]
    stopifnot(nrow(row) == 1L)
    candidate <- as.list(row[1L, ])
    itm6_candidate(candidate, reference, paste0("historical_diverse_", id))
  })
  anchor <- itm6_candidate(reference$candidate, reference,
    "cell_specific_N1000_anchor")
  large <- list(
    itm6_large_template(reference, c(300L, 300L, 300L), 500L,
      0.75, 0.995, 0.35, "large_D3_900"),
    itm6_large_template(reference, rep(400L, 4L), 500L,
      0.40, 0.995, 0.20, "large_D4_1600"),
    itm6_large_template(reference, rep(400L, 5L), 360L,
      0.12, 0.998, 0.12, "large_D5_2000"),
    itm6_large_template(reference, rep(400L, 6L), 240L,
      0.04, 0.990, 0.08, "large_D6_2400"))
  panel <- c(list(anchor), old, large)
  structures <- vapply(panel, `[[`, "", "structure_id")
  panel <- panel[!duplicated(structures)]
  stopifnot(length(panel) >= 8L, length(panel) <= 10L,
    all(vapply(panel, function(x) x$readout_mode == "reservoir_only", TRUE)),
    all(vapply(panel, function(x) x$total_states <= 2500L, TRUE)))
  panel
}

itm6_candidate_frame <- function(panels) {
  rows <- list()
  for (cell in names(panels)) for (candidate in panels[[cell]]) {
    rows[[length(rows) + 1L]] <- data.frame(cell = cell,
      candidate_id = candidate$id, structure_id = candidate$structure_id,
      role = candidate$role, n = candidate$n, D = candidate$D,
      total_states = candidate$total_states, m = candidate$m,
      alpha = candidate$alpha, rho = candidate$rho,
      input_gain = candidate$input_gain,
      input_fanin = candidate$input_fanin,
      recurrent_indegree = candidate$recurrent_indegree,
      interlayer_fanin = candidate$interlayer_fanin,
      center_scale = candidate$center_scale,
      input_bound = candidate$input_bound,
      effective_p0 = candidate$effective_p0,
      readout_dimension = candidate$readout_dimension,
      stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

itm6_config <- function(state, cell, candidate, stage, estimator,
                        N, fold, chain = 1L, tau_multiplier = 1,
                        rolling_window = 0L, origin_offset = NA_integer_,
                        model = "qdesn") {
  stopifnot(stage %in% itm6_stages, cell %in% names(state$references),
    N %in% itm6_training_sizes, fold %in% names(itm6_folds))
  reference <- state$references[[cell]]
  tau_N <- if (rolling_window > 0L) rolling_window else N
  candidate <- itm6_candidate(candidate, reference, candidate$role,
    tau_multiplier = tau_multiplier, N = tau_N)
  engine <- switch(estimator,
    oracle_ridge = "oracle_ridge", gaussian_ridge = "gaussian_ridge",
    mechanism_bundle = "mechanism_bundle",
    normal_rhs = "normal", quantile_vb = "vb", quantile_mcmc = "mcmc",
    baseline_vb = "vb", baseline_mcmc = "mcmc",
    rolling_vb = "rolling_vb", rolling_mcmc = "rolling_mcmc",
    stop("Unknown estimator: ", estimator))
  if (startsWith(estimator, "baseline_")) model <- "baseline"
  budget <- switch(stage,
    smoke = list(outer = 8L, inner = 8L, vb = 30L, normal = 40L,
      burn = 20L, retained = 40L),
    representation = list(outer = 24L, inner = 24L, vb = 200L,
      normal = 100L, burn = 0L, retained = 0L),
    quantile = list(outer = 48L, inner = 48L, vb = 650L,
      normal = 300L, burn = 0L, retained = 0L),
    validation = list(outer = 160L, inner = 128L, vb = 800L,
      normal = 300L, burn = 0L, retained = 0L),
    rolling = list(outer = 120L, inner = 96L, vb = 700L,
      normal = 300L, burn = 1500L, retained = 4000L),
    mcmc = list(outer = 300L, inner = 128L, vb = 800L,
      normal = 300L, burn = 3000L, retained = 10000L))
  window <- itm6_window(fold, N, candidate,
    origin_stride = if (stage %in% c("smoke", "representation")) 60L else 30L)
  if (!is.na(origin_offset)) {
    origin <- unname(itm6_folds[fold]) + as.integer(origin_offset)
    window$origins <- origin
    window$end <- origin + 30L
  }
  suffix <- c(stage, cell, estimator, paste0("N", N), fold,
    candidate$id, paste0("tau", format(tau_multiplier, scientific = FALSE)),
    if (rolling_window > 0L) paste0("roll", rolling_window) else "static",
    if (!is.na(origin_offset)) paste0("o", origin_offset) else "all",
    paste0("chain", chain))
  id <- paste(suffix, collapse = "__")
  list(schema = itm6_schema, run = state$run, repo = state$repo,
    library = state$library, id = id, cell = cell, family = reference$family,
    p = reference$p, likelihood = reference$likelihood,
    candidate = candidate, stage = stage, estimator = estimator,
    engine = engine, model = model, chain = as.integer(chain),
    source_path = reference$source_path, source_sha = reference$source_sha,
    baseline = reference$baseline, window = window,
    base_window = itm6_window(fold, N, candidate),
    rolling_window = as.integer(rolling_window),
    origin_offset = if (is.na(origin_offset)) NULL else as.integer(origin_offset),
    outer = budget$outer, inner = budget$inner, vb_iter = budget$vb,
    normal_iter = budget$normal, burn = budget$burn,
    retained = budget$retained, tau_multiplier = tau_multiplier,
    seed = itm6_seed(id),
    path = file.path(state$run, "configs", paste0(id, ".json")),
    status_path = file.path(state$run, "status", paste0(id, ".json")),
    evidence = file.path(state$run, "evidence", id),
    timeout = if (stage == "mcmc") 259200L else 172800L)
}

itm6_plan <- function(state, configs, stage) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Frozen stage already exists: ", stage)
  rows <- lapply(configs, function(cfg) {
    iqt12_json(cfg, cfg$path)
    data.frame(id = cfg$id, stage = stage, cell = cfg$cell,
      estimator = cfg$estimator, model = cfg$model, engine = cfg$engine,
      N = cfg$window$N, fold = cfg$window$fold,
      candidate_id = cfg$candidate$id,
      structure_id = cfg$candidate$structure_id,
      tau_multiplier = cfg$tau_multiplier,
      rolling_window = cfg$rolling_window,
      config_path = cfg$path,
      config_sha = unname(tools::sha256sum(cfg$path)),
      status_path = cfg$status_path, timeout = cfg$timeout,
      stringsAsFactors = FALSE)
  })
  if (length(rows)) {
    plan <- do.call(rbind, rows)
  } else {
    plan <- data.frame(id = character(), stage = character(), cell = character(),
      estimator = character(), model = character(), engine = character(),
      N = integer(), fold = character(), candidate_id = character(),
      structure_id = character(), tau_multiplier = numeric(),
      rolling_window = integer(), config_path = character(),
      config_sha = character(), status_path = character(), timeout = integer())
  }
  stopifnot(!anyDuplicated(plan$id))
  iqt12_csv(plan, path)
  paths <- c(path, plan$config_path)
  iqt12_hash(paths[file.exists(paths)], file.path(state$run, "plans",
    paste0(stage, "_hashes.csv")))
  plan
}

itm6_verify_parent <- function(parent, sentinel) {
  stopifnot(dir.exists(parent), dir.exists(sentinel))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv")) iqt12_verify(file.path(parent, name))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv")) iqt12_verify(file.path(sentinel, name))
  parent_state <- iqt12_read(file.path(parent, "campaign.json"))
  sentinel_state <- iqt12_read(file.path(sentinel, "campaign.json"))
  stopifnot(all(itm6_cells %in% names(parent_state$references)),
    sentinel_state$sentinel == "normal__exal__p005")
  list(parent = parent_state, sentinel = sentinel_state)
}

itm6_materialize <- function(repo, run, library, parent = itm6_parent_run,
                             sentinel = itm6_sentinel_run) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(library))
  verified <- itm6_verify_parent(parent, sentinel)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests", "sources"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = itm6_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE),
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    shared_base = "5b85bb3a3894a88968e4987f330e3ec66711f9c7",
    scientific_parent = "5808668bab0e8904c4bc732f0af980fa462f40bb",
    parent_run = normalizePath(parent, mustWork = TRUE),
    sentinel_run = normalizePath(sentinel, mustWork = TRUE),
    max_workers = 30L, cells = itm6_cells,
    training_sizes = itm6_training_sizes, folds = as.list(itm6_folds),
    tau_multipliers = itm6_tau_multipliers, references = list(), panels = list(),
    contract = list(selection_data = "source_indices_1_to_8740_only",
      article_holdout = "source_indices_9001_to_10000_never_opened",
      readout = "intercept_plus_all_identity_Q_reservoir_layers",
      activation = "tanh_reservoir_recurrence_with_identity_Q_projection",
      teacher_forcing = "observations_assimilated_when_origin_moves",
      within_origin = "recursive_30_step_forecast",
      primary_selection = "internal_rolling_origin_forecast_MAE",
      diagnostics = c("oracle_quantile_ridge", "Gaussian_ridge",
        "Gaussian_RHS", "matched_AL_or_exAL_VB", "rolling_readout"),
      mcmc = "M0_for_exAL_sigma_then_gamma_for_AL",
      diagnostic_status_is_not_a_metric_veto = TRUE,
      article_promotion = FALSE))
  sentinel_bank <- read.csv(file.path(sentinel, "candidate_bank.csv"),
    stringsAsFactors = FALSE)
  for (cell in itm6_cells) {
    reference <- verified$parent$references[[cell]]
    original <- reference$original_source
    stopifnot(file.exists(original),
      unname(tools::sha256sum(original)) == reference$original_sha)
    source <- read.csv(original)
    stopifnot(nrow(source) == 10000L, all(source$t == seq_len(10000L)))
    frozen <- file.path(run, "sources", paste0(cell, ".csv"))
    iqt12_csv(source[source$t <= 9000L, ], frozen)
    reference$source_path <- frozen
    reference$source_sha <- unname(tools::sha256sum(frozen))
    state$references[[cell]] <- reference
    state$panels[[cell]] <- itm6_candidate_panel(reference, sentinel_bank)
  }
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(itm6_candidate_frame(state$panels),
    file.path(run, "candidate_bank.csv"))
  environment <- list(schema = itm6_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    exdqlm_repository = utils::packageDescription("exdqlm", lib.loc = library)$Repository,
    package_path = find.package("exdqlm", lib.loc = library),
    R = R.version.string, session = capture.output(sessionInfo()),
    threads = list(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1,
      MKL_NUM_THREADS = 1, BLIS_NUM_THREADS = 1,
      RCPP_PARALLEL_NUM_THREADS = 1), source_head = state$head)
  stopifnot(environment$exdqlm_version == "1.1.2",
    environment$exdqlm_repository == "CRAN")
  iqt12_json(environment, file.path(run, "environment.json"))
  provenance <- data.frame(
    role = c("N1000_parent", "sentinel_recovery"),
    path = c(normalizePath(parent), normalizePath(sentinel)),
    campaign_sha256 = unname(tools::sha256sum(c(file.path(parent,
      "campaign.json"), file.path(sentinel, "campaign.json")))),
    stringsAsFactors = FALSE)
  iqt12_csv(provenance, file.path(run, "manifests", "parent_runs.csv"))
  code <- c(file.path(repo, "validation/fitforecast_v2/R", c(
    "independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_training_size_mechanism_v6.R",
      "run_independent_qdesn_training_size_mechanism_v6.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_TRAINING_SIZE_MECHANISM_V6_20261009.md"))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv")), file.path(run, "manifests", "parent_runs.csv"),
    vapply(state$references, `[[`, "", "source_path")),
    file.path(run, "input_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  smoke_candidate <- state$panels[[itm6_cells[1L]]][[1L]]
  configs <- list(
    itm6_config(state, itm6_cells[1L], smoke_candidate, "smoke",
      "oracle_ridge", 500L, "S1"),
    itm6_config(state, itm6_cells[1L], smoke_candidate, "smoke",
      "quantile_vb", 5000L, "S1"))
  itm6_plan(state, configs, "smoke")
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv")), file.path(run, "manifests", "parent_runs.csv"),
    vapply(state$references, `[[`, "", "source_path")),
    file.path(run, "frozen_hashes.csv"))
  invisible(state)
}

itm6_cg <- function(X, y, lambda, max_iter = 30L, tolerance = 1e-5) {
  p <- ncol(X)
  penalty <- c(0, rep(lambda, p - 1L))
  multiply <- function(beta) as.numeric(crossprod(X, X %*% beta)) + penalty * beta
  rhs <- as.numeric(crossprod(X, y))
  beta <- numeric(p)
  residual <- rhs - multiply(beta)
  preconditioner <- pmax(as.numeric(colSums(X^2)) + penalty,
    .Machine$double.eps)
  scaled_residual <- residual / preconditioner
  direction <- scaled_residual
  product_residual <- sum(residual * scaled_residual)
  initial <- max(sqrt(sum(residual^2)), 1)
  iterations <- 0L
  for (iteration in seq_len(max_iter)) {
    product <- multiply(direction)
    step <- product_residual /
      max(sum(direction * product), .Machine$double.eps)
    beta <- beta + step * direction
    residual <- residual - step * product
    iterations <- iteration
    if (sqrt(sum(residual^2)) <= tolerance * initial) break
    next_scaled <- residual / preconditioner
    next_product <- sum(residual * next_scaled)
    direction <- next_scaled + next_product / product_residual * direction
    scaled_residual <- next_scaled
    product_residual <- next_product
  }
  list(beta = beta, iterations = iterations,
    relative_residual = sqrt(sum(residual^2)) / initial)
}

itm6_ridge_fit <- function(X, y, lambda = 1) {
  stopifnot(nrow(X) == length(y), ncol(X) >= 2L, all(is.finite(X)),
    all(is.finite(y)))
  center <- colMeans(X[, -1L, drop = FALSE])
  scale <- apply(X[, -1L, drop = FALSE], 2L, sd)
  scale[!is.finite(scale) | scale < 1e-8] <- 1
  Z <- cbind(1, sweep(sweep(X[, -1L, drop = FALSE], 2L, center, "-"),
    2L, scale, "/"))
  stopifnot(length(lambda) == 1L, is.finite(lambda), lambda > 0)
  final <- itm6_cg(Z, y, lambda, 30L)
  beta <- final$beta
  raw <- c(beta[1L] - sum(center / scale * beta[-1L]), beta[-1L] / scale)
  fitted <- as.numeric(X %*% raw)
  list(beta = raw, fitted = fitted,
    sigma = sqrt(mean((y - fitted)^2)), lambda = lambda,
    validation_mae = mean(abs(y - fitted)), cg_iterations = final$iterations,
    cg_relative_residual = final$relative_residual,
    lambda_grid = lambda, lambda_losses = mean(abs(y - fitted)))
}

itm6_deterministic_forecast <- function(cx, cfg, beta, sigma = 0,
                                        oracle = FALSE) {
  object <- cx$object
  out <- vector("list", length(cfg$window$origins))
  for (i in seq_along(cfg$window$origins)) {
    origin <- cfg$window$origins[i]
    local <- origin - cx$first + 1L
    horizon <- min(cfg$window$horizon, cfg$window$end - origin)
    h <- lapply(object$states$H_all, function(z) as.numeric(z[local, ]))
    lags <- cx$y[local - seq_len(object$reservoir$m) + 1L]
    values <- numeric(horizon)
    for (lead in seq_len(horizon)) {
      one <- iqt12_step(object, h, lags)
      h <- one$h
      location <- sum(one$x * beta)
      values[lead] <- if (oracle) location else
        location + qnorm(cfg$p) * sigma
      recursive_value <- if (oracle) values[lead] else location
      lags <- c(recursive_value, head(lags, -1L))
    }
    out[[i]] <- values * cx$scale
  }
  matrix(unlist(out), ncol = 1L)
}

itm6_ridge_worker <- function(cfg) {
  started <- proc.time()[["elapsed"]]
  e <- ism1_runtime(cfg$repo, cfg$library)
  for (name in c("source_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(unname(tools::sha256sum(cfg$source_path)) == cfg$source_sha,
    !file.exists(cfg$status_path))
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid(),
    started = format(Sys.time(), tz = "UTC", usetz = TRUE)), cfg$status_path)
  tryCatch({
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source)
    full[source$t, ] <- source
    source <- full
    cx <- ism1_design(e, cfg, source, cfg$window$end)
    iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid(),
      phase = "shared_design_complete"), cfg$status_path)
    if (cfg$estimator == "oracle_ridge") {
      target <- source$q_target[cfg$window$train] / cx$scale
    } else {
      target <- source$y[cfg$window$train] / cx$scale
    }
    fit <- itm6_ridge_fit(cx$object$X, target)
    if (cfg$estimator == "oracle_ridge") {
      fit_draws <- matrix(fit$fitted * cx$scale, ncol = 1L)
      forecast <- itm6_deterministic_forecast(cx, cfg, fit$beta,
        oracle = TRUE)
    } else {
      fit_draws <- matrix((fit$fitted + qnorm(cfg$p) * fit$sigma) *
        cx$scale, ncol = 1L)
      forecast <- itm6_deterministic_forecast(cx, cfg, fit$beta,
        fit$sigma, oracle = FALSE)
    }
    score <- iqt12_scores(fit_draws, forecast, source, cfg$window, cfg$p)
    grid <- iqt12_grid(cfg$window)
    teacher <- as.numeric(cx$all_X[grid$target - cx$first + 1L, , drop = FALSE] %*%
      fit$beta) * cx$scale
    if (cfg$estimator == "gaussian_ridge")
      teacher <- teacher + qnorm(cfg$p) * fit$sigma * cx$scale
    teacher_mae <- mean(abs(teacher - source$q_target[grid$target]))
    extra <- data.frame(metric = c("teacher_forced_mae",
      "recursive_to_teacher_ratio"),
      mean = c(teacher_mae,
        score$summary$mean[score$summary$metric == "forecast_mae"] / teacher_mae),
      lower = NA_real_, upper = NA_real_)
    summary <- rbind(score$summary, extra)
    add <- data.frame(id = cfg$id, cell = cfg$cell,
      candidate_id = cfg$candidate$id, model = cfg$model,
      estimator = cfg$estimator, engine = cfg$engine,
      family = cfg$family, p = cfg$p, N = cfg$window$N,
      fold = cfg$window$fold, chain = cfg$chain,
      normal_observed_mae = if (cfg$estimator == "gaussian_ridge")
        mean(abs(forecast[, 1L] - source$y[grid$target])) else NA_real_)
    iqt12_csv(cbind(add[rep(1L, nrow(summary)), ], summary),
      file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(score$draws, file.path(cfg$evidence, "metric_draws.csv.gz"))
    profile <- score$profile
    profile$teacher_forced_q <- teacher
    iqt12_csv(profile, file.path(cfg$evidence, "origin_lead.csv.gz"))
    iqt12_csv(cbind(source_index = cfg$window$train, fit_draws),
      file.path(cfg$evidence, "fit_location_draws.csv.gz"))
    iqt12_csv(cbind(grid, forecast),
      file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
    diagnostics <- list(estimator = cfg$estimator, lambda = fit$lambda,
      nested_validation_mae = fit$validation_mae,
      cg_iterations = fit$cg_iterations,
      cg_relative_residual = fit$cg_relative_residual,
      teacher_forced_mae = teacher_mae,
      elapsed = proc.time()[["elapsed"]] - started,
      fitted_binary_payloads = 0L)
    iqt12_json(diagnostics, file.path(cfg$evidence, "diagnostics.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = diagnostics$elapsed, fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error), elapsed = proc.time()[["elapsed"]] - started),
      cfg$status_path)
    stop(error)
  })
}

itm6_rolling_worker <- function(cfg) {
  started <- proc.time()[["elapsed"]]
  e <- ism1_runtime(cfg$repo, cfg$library)
  for (name in c("source_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(cfg$rolling_window > 0L, length(cfg$window$origins) == 1L,
    !file.exists(cfg$status_path))
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid()),
    cfg$status_path)
  tryCatch({
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source)
    full[source$t, ] <- source
    source <- full
    base <- cfg
    base$window <- cfg$base_window
    origin <- cfg$window$origins[1L]
    cx <- ism1_design(e, base, source, origin + 30L)
    rows <- seq.int(origin - cfg$rolling_window + 1L, origin)
    local <- rows - cx$first + 1L
    stopifnot(min(local) >= 1L, max(local) <= nrow(cx$all_X))
    cx$object$X <- cx$all_X[local, , drop = FALSE]
    cx$object$y_fit <- cx$y[local]
    cx$train <- local
    cx$design_hash <- digest::digest(cx$object$X, algo = "sha256")
    cfg$window$train <- rows
    cfg$window$N <- length(rows)
    fit <- iqt12_quantile(e, cx, cfg)
    draws <- iqt12_draws(e, fit, cfg$outer, cfg$seed + 1L)
    fit_draws <- cx$object$X %*% t(draws$beta) * cx$scale
    forecast <- ism1_qforecast(e, cx, cfg, fit, draws)$primary
    score <- iqt12_scores(fit_draws, forecast, source, cfg$window, cfg$p)
    add <- data.frame(id = cfg$id, cell = cfg$cell,
      candidate_id = cfg$candidate$id, model = cfg$model,
      estimator = cfg$estimator, engine = cfg$engine,
      family = cfg$family, p = cfg$p, N = cfg$window$N,
      fold = cfg$window$fold, chain = cfg$chain,
      normal_observed_mae = NA_real_)
    iqt12_csv(cbind(add[rep(1L, nrow(score$summary)), ], score$summary),
      file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(score$draws, file.path(cfg$evidence, "metric_draws.csv.gz"))
    iqt12_csv(score$profile, file.path(cfg$evidence, "origin_lead.csv.gz"))
    iqt12_csv(cbind(source_index = rows, fit_draws),
      file.path(cfg$evidence, "fit_location_draws.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(cfg$window), forecast),
      file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
    diagnostics <- list(estimator = cfg$estimator,
      rolling_window = cfg$rolling_window, origin = origin,
      method = fit$diagnostics$core_update_mode %||%
        "structured_full_covariance_VB",
      elapsed = proc.time()[["elapsed"]] - started,
      fitted_binary_payloads = 0L)
    iqt12_json(diagnostics, file.path(cfg$evidence, "diagnostics.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = diagnostics$elapsed, fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error), elapsed = proc.time()[["elapsed"]] - started),
      cfg$status_path)
    stop(error)
  })
}

itm6_bundle_worker <- function(cfg) {
  started <- proc.time()[["elapsed"]]
  e <- ism1_runtime(cfg$repo, cfg$library)
  for (name in c("source_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(cfg$estimator == "mechanism_bundle", !file.exists(cfg$status_path))
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid()),
    cfg$status_path)
  tryCatch({
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source)
    full[source$t, ] <- source
    source <- full
    cx <- ism1_design(e, cfg, source, cfg$window$end)
    grid <- iqt12_grid(cfg$window)
    summaries <- draws_out <- profiles <- list()
    ridge_diagnostics <- list()
    for (estimator in c("oracle_ridge", "gaussian_ridge")) {
      target <- if (estimator == "oracle_ridge")
        source$q_target[cfg$window$train] / cx$scale else
        source$y[cfg$window$train] / cx$scale
      ridge <- itm6_ridge_fit(cx$object$X, target, lambda = 1)
      if (estimator == "oracle_ridge") {
        fit_draws <- matrix(ridge$fitted * cx$scale, ncol = 1L)
        forecast <- itm6_deterministic_forecast(cx, cfg, ridge$beta,
          oracle = TRUE)
      } else {
        fit_draws <- matrix((ridge$fitted + qnorm(cfg$p) * ridge$sigma) *
          cx$scale, ncol = 1L)
        forecast <- itm6_deterministic_forecast(cx, cfg, ridge$beta,
          ridge$sigma, oracle = FALSE)
      }
      score <- iqt12_scores(fit_draws, forecast, source, cfg$window, cfg$p)
      teacher <- as.numeric(cx$all_X[grid$target - cx$first + 1L, , drop = FALSE] %*%
        ridge$beta) * cx$scale
      if (estimator == "gaussian_ridge")
        teacher <- teacher + qnorm(cfg$p) * ridge$sigma * cx$scale
      teacher_mae <- mean(abs(teacher - source$q_target[grid$target]))
      extra <- data.frame(metric = c("teacher_forced_mae",
        "recursive_to_teacher_ratio"),
        mean = c(teacher_mae,
          score$summary$mean[score$summary$metric == "forecast_mae"] /
            teacher_mae), lower = NA_real_, upper = NA_real_)
      summaries[[estimator]] <- rbind(score$summary, extra)
      draws_out[[estimator]] <- transform(score$draws, estimator = estimator)
      profiles[[estimator]] <- transform(score$profile,
        estimator = estimator, teacher_forced_q = teacher)
      ridge_diagnostics[[estimator]] <- ridge[c("lambda", "validation_mae",
        "cg_iterations", "cg_relative_residual")]
      iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid(),
        phase = paste0(estimator, "_complete")), cfg$status_path)
    }

    normal <- NULL
    normal_forecast <- NULL
    if (cfg$candidate$total_states <= 1000L) {
      normal <- iqt12_normal(e, cx, cfg)
      normal_draws <- e$normal_desn_posterior_draws(normal, cfg$outer,
        seed = cfg$seed)
      normal_fit <- cx$object$X %*% t(normal_draws$beta) * cx$scale
      normal_forecast <- ism1_normal_forecast(e, cx, cfg, normal, normal_draws)
      normal_score <- iqt12_scores(normal_fit, normal_forecast, source,
        cfg$window, cfg$p)
      summaries$normal_rhs <- normal_score$summary
      draws_out$normal_rhs <- transform(normal_score$draws,
        estimator = "normal_rhs")
      profiles$normal_rhs <- transform(normal_score$profile,
        estimator = "normal_rhs", teacher_forced_q = NA_real_)
      iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid(),
        phase = "normal_rhs_complete"), cfg$status_path)
    }

    rows <- list()
    for (estimator in names(summaries)) {
      add <- data.frame(id = cfg$id, cell = cfg$cell,
        candidate_id = cfg$candidate$id, model = cfg$model,
        estimator = estimator,
        engine = if (estimator == "normal_rhs") "normal" else estimator,
        family = cfg$family, p = cfg$p, N = cfg$window$N,
        fold = cfg$window$fold, chain = cfg$chain,
        normal_observed_mae = if (estimator == "normal_rhs")
          mean(abs(normal_forecast - source$y[grid$target])) else NA_real_)
      rows[[estimator]] <- cbind(add[rep(1L, nrow(summaries[[estimator]])), ],
        summaries[[estimator]])
    }
    iqt12_csv(do.call(rbind, rows), file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(do.call(rbind, draws_out),
      file.path(cfg$evidence, "metric_draws.csv.gz"))
    iqt12_csv(do.call(rbind, profiles),
      file.path(cfg$evidence, "origin_lead.csv.gz"))
    diagnostics <- list(estimator = cfg$estimator,
      shared_design = TRUE, ridge = ridge_diagnostics,
      normal_rhs_run = !is.null(normal),
      normal_rhs_converged = if (is.null(normal)) NA else normal$fit$converged,
      design_hash = cx$design_hash,
      total_states = cfg$candidate$total_states,
      elapsed = proc.time()[["elapsed"]] - started,
      fitted_binary_payloads = 0L)
    iqt12_json(diagnostics, file.path(cfg$evidence, "diagnostics.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = diagnostics$elapsed, fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error), elapsed = proc.time()[["elapsed"]] - started),
      cfg$status_path)
    stop(error)
  })
}

itm6_worker <- function(path) {
  cfg <- iqt12_read(path)
  if (cfg$engine %in% c("oracle_ridge", "gaussian_ridge")) {
    itm6_ridge_worker(cfg)
  } else if (cfg$engine == "mechanism_bundle") {
    itm6_bundle_worker(cfg)
  } else if (cfg$engine %in% c("rolling_vb", "rolling_mcmc")) {
    itm6_rolling_worker(cfg)
  } else {
    iqt12_worker(path)
  }
}

itm6_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  if (!nrow(plan)) return(data.frame())
  rows <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    status <- iqt12_read(plan$status_path[i])
    stopifnot(status$status == "SUCCESS")
    iqt12_verify(status$manifest)
    rows[[i]] <- read.csv(file.path(dirname(plan$config_path[i]), "..",
      "evidence", plan$id[i], "summary.csv"), stringsAsFactors = FALSE)
    cfg <- iqt12_read(plan$config_path[i])
    if (!"estimator" %in% names(rows[[i]])) rows[[i]]$estimator <- cfg$estimator
    rows[[i]]$structure_id <- cfg$candidate$structure_id
    rows[[i]]$tau_multiplier <- cfg$tau_multiplier
    rows[[i]]$rolling_window <- cfg$rolling_window
    rows[[i]]$config_path <- plan$config_path[i]
  }
  do.call(rbind, rows)
}

itm6_metric <- function(results, metric) {
  results[results$metric == metric, , drop = FALSE]
}

itm6_representative_candidates <- function(results) {
  keys <- unique(results[c("cell", "N", "structure_id")])
  rows <- list()
  for (i in seq_len(nrow(keys))) {
    key <- keys[i, ]
    z <- results[results$cell == key$cell & results$N == key$N &
      results$structure_id == key$structure_id, ]
    value <- function(estimator, metric, field = "mean") {
      x <- z[z$estimator == estimator & z$metric == metric, field]
      if (!length(x)) return(NA_real_)
      median(x, na.rm = TRUE)
    }
    rows[[i]] <- data.frame(key,
      oracle_teacher_mae = value("oracle_ridge", "teacher_forced_mae"),
      oracle_recursive_mae = value("oracle_ridge", "forecast_mae"),
      gaussian_recursive_mae = value("gaussian_ridge", "forecast_mae"),
      normal_rhs_observed_mae = value("normal_rhs", "forecast_mae",
        "normal_observed_mae"), stringsAsFactors = FALSE)
  }
  score <- do.call(rbind, rows)
  score$composite <- NA_real_
  for (cell in unique(score$cell)) for (N in unique(score$N)) {
    take <- score$cell == cell & score$N == N
    columns <- c("oracle_teacher_mae", "oracle_recursive_mae",
      "gaussian_recursive_mae", "normal_rhs_observed_mae")
    ratios <- sapply(columns, function(column) score[take, column] /
      min(score[take, column], na.rm = TRUE))
    score$composite[take] <- rowMeans(log(pmax(ratios, 1e-12)),
      na.rm = TRUE)
  }
  score
}

itm6_select_top <- function(score, count = 3L) {
  rows <- list()
  for (cell in unique(score$cell)) for (N in unique(score$N)) {
    z <- score[score$cell == cell & score$N == N, ]
    chosen <- unique(c(z$structure_id[order(z$composite)],
      z$structure_id[order(z$oracle_teacher_mae)],
      z$structure_id[order(z$normal_rhs_observed_mae)]))
    chosen <- head(chosen, count)
    rows[[length(rows) + 1L]] <- z[match(chosen, z$structure_id), ]
  }
  do.call(rbind, rows)
}

itm6_find_candidate <- function(state, cell, structure_id) {
  panel <- state$panels[[cell]]
  index <- match(structure_id, vapply(panel, `[[`, "", "structure_id"))
  stopifnot(!is.na(index))
  panel[[index]]
}

itm6_plan_representation <- function(state) {
  configs <- list()
  for (cell in itm6_cells) for (N in itm6_training_sizes)
    for (candidate in state$panels[[cell]]) for (fold in c("S1", "S3"))
      configs[[length(configs) + 1L]] <- itm6_config(state, cell,
        candidate, "representation", "mechanism_bundle", N, fold)
  itm6_plan(state, configs, "representation")
}

itm6_plan_quantile <- function(state, run) {
  results <- itm6_results(run, "representation")
  score <- itm6_representative_candidates(results)
  selected <- itm6_select_top(score, 3L)
  iqt12_csv(score, file.path(run, "summaries", "representation_scores.csv"))
  iqt12_csv(selected, file.path(run, "selections",
    "representation_to_quantile.csv"))
  configs <- list()
  for (i in seq_len(nrow(selected))) {
    row <- selected[i, ]
    candidate <- itm6_find_candidate(state, row$cell, row$structure_id)
    for (tau in itm6_tau_multipliers) for (fold in c("S1", "S3"))
      configs[[length(configs) + 1L]] <- itm6_config(state, row$cell,
        candidate, "quantile", "quantile_vb", row$N, fold,
        tau_multiplier = tau)
  }
  itm6_plan(state, configs, "quantile")
}

itm6_quantile_rank <- function(results) {
  z <- itm6_metric(results, "forecast_mae")
  rows <- list()
  combos <- unique(z[c("cell", "N", "candidate_id", "structure_id",
    "tau_multiplier")])
  for (i in seq_len(nrow(combos))) {
    key <- combos[i, ]
    x <- z[z$cell == key$cell & z$N == key$N &
      z$candidate_id == key$candidate_id &
      z$tau_multiplier == key$tau_multiplier, ]
    check <- results[results$config_path %in% x$config_path &
      results$metric == "forecast_check_loss", ]
    rows[[i]] <- data.frame(key,
      forecast_mae = median(x$mean),
      forecast_mae_max = max(x$mean),
      forecast_check_loss = median(check$mean),
      folds = length(unique(x$fold)), stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  out[order(out$cell, out$forecast_mae, out$forecast_check_loss,
    out$N), ]
}

itm6_plan_validation <- function(state, run) {
  rank <- itm6_quantile_rank(itm6_results(run, "quantile"))
  selected <- do.call(rbind, lapply(split(rank, rank$cell), function(z)
    head(z, 2L)))
  iqt12_csv(rank, file.path(run, "summaries", "quantile_rank.csv"))
  iqt12_csv(selected, file.path(run, "selections",
    "quantile_to_validation.csv"))
  configs <- list()
  baseline_keys <- character()
  for (i in seq_len(nrow(selected))) {
    row <- selected[i, ]
    candidate <- itm6_find_candidate(state, row$cell, row$structure_id)
    for (fold in names(itm6_folds)) {
      configs[[length(configs) + 1L]] <- itm6_config(state, row$cell,
        candidate, "validation", "quantile_vb", row$N, fold,
        tau_multiplier = row$tau_multiplier)
      key <- paste(row$cell, row$N, fold)
      if (!key %in% baseline_keys) {
        configs[[length(configs) + 1L]] <- itm6_config(state, row$cell,
          state$references[[row$cell]]$candidate, "validation",
          "baseline_vb", row$N, fold)
        baseline_keys <- c(baseline_keys, key)
      }
    }
  }
  itm6_plan(state, configs, "validation")
}

itm6_validation_rank <- function(results) {
  mae <- itm6_metric(results, "forecast_mae")
  q <- mae[mae$model == "qdesn", ]
  b <- mae[mae$model == "baseline", c("cell", "N", "fold", "mean")]
  names(b)[4L] <- "baseline_mae"
  q <- merge(q, b, by = c("cell", "N", "fold"), all.x = TRUE)
  q$ratio <- q$mean / q$baseline_mae
  keys <- unique(q[c("cell", "N", "candidate_id", "structure_id",
    "tau_multiplier")])
  rows <- list()
  for (i in seq_len(nrow(keys))) {
    key <- keys[i, ]
    z <- q[q$cell == key$cell & q$N == key$N &
      q$candidate_id == key$candidate_id, ]
    rows[[i]] <- data.frame(key, forecast_mae = mean(z$mean),
      baseline_mae = mean(z$baseline_mae), ratio = mean(z$ratio),
      folds = length(unique(z$fold)), stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  out[order(out$cell, out$ratio, out$forecast_mae), ]
}

itm6_plan_rolling <- function(state, run) {
  rank <- itm6_validation_rank(itm6_results(run, "validation"))
  selected <- do.call(rbind, lapply(split(rank, rank$cell), function(z)
    head(z, 1L)))
  iqt12_csv(rank, file.path(run, "summaries", "validation_rank.csv"))
  iqt12_csv(selected, file.path(run, "selections",
    "validation_to_rolling.csv"))
  configs <- list()
  for (i in seq_len(nrow(selected))) {
    row <- selected[i, ]
    if (row$ratio <= 1.05) next
    candidate <- itm6_find_candidate(state, row$cell, row$structure_id)
    for (fold in c("S2", "S4")) for (window in c(500L, 1000L, 2000L))
      for (offset in c(0L, 120L, 210L))
        configs[[length(configs) + 1L]] <- itm6_config(state, row$cell,
          candidate, "rolling", "rolling_vb", row$N, fold,
          tau_multiplier = row$tau_multiplier,
          rolling_window = window, origin_offset = offset)
  }
  itm6_plan(state, configs, "rolling")
}

itm6_plan_mcmc <- function(state, run) {
  selected <- read.csv(file.path(run, "selections",
    "validation_to_rolling.csv"), stringsAsFactors = FALSE)
  rolling <- itm6_results(run, "rolling")
  if (nrow(rolling)) {
    rmae <- itm6_metric(rolling, "forecast_mae")
    roll_rank <- aggregate(mean ~ cell + rolling_window, rmae, mean)
    names(roll_rank)[3L] <- "rolling_mae"
    iqt12_csv(roll_rank, file.path(run, "summaries", "rolling_rank.csv"))
  } else {
    iqt12_csv(data.frame(cell = character(), rolling_window = integer(),
      rolling_mae = numeric()), file.path(run, "summaries", "rolling_rank.csv"))
  }
  configs <- list()
  for (i in seq_len(nrow(selected))) {
    row <- selected[i, ]
    candidate <- itm6_find_candidate(state, row$cell, row$structure_id)
    for (fold in c("S2", "S4")) for (chain in 1:3) {
      qcfg <- itm6_config(state, row$cell, candidate, "mcmc",
        "quantile_mcmc", row$N, fold, chain,
        tau_multiplier = row$tau_multiplier)
      validation_plan <- read.csv(file.path(run, "plans", "validation.csv"),
        stringsAsFactors = FALSE)
      warm <- validation_plan[validation_plan$cell == row$cell &
        validation_plan$N == row$N & validation_plan$fold == fold &
        validation_plan$candidate_id == row$candidate_id &
        validation_plan$model == "qdesn", ]
      stopifnot(nrow(warm) == 1L)
      initializer <- file.path(dirname(warm$config_path), "..", "evidence",
        warm$id, "mcmc_initializer.json")
      qcfg$warm_path <- normalizePath(initializer, mustWork = TRUE)
      qcfg$warm_sha <- unname(tools::sha256sum(qcfg$warm_path))
      configs[[length(configs) + 1L]] <- qcfg
      bcfg <- itm6_config(state, row$cell,
        state$references[[row$cell]]$candidate, "mcmc",
        "baseline_mcmc", row$N, fold, chain)
      bwarm <- validation_plan[validation_plan$cell == row$cell &
        validation_plan$N == row$N & validation_plan$fold == fold &
        validation_plan$model == "baseline", ]
      stopifnot(nrow(bwarm) == 1L)
      initializer <- file.path(dirname(bwarm$config_path), "..", "evidence",
        bwarm$id, "mcmc_initializer.json")
      bcfg$warm_path <- normalizePath(initializer, mustWork = TRUE)
      bcfg$warm_sha <- unname(tools::sha256sum(bcfg$warm_path))
      configs[[length(configs) + 1L]] <- bcfg
    }
  }
  itm6_plan(state, configs, "mcmc")
}

itm6_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "[.]csv$",
    full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  rows <- lapply(plans, function(path) {
    plan <- read.csv(path, stringsAsFactors = FALSE)
    statuses <- if (nrow(plan)) vapply(plan$status_path, function(status_path) {
      if (!file.exists(status_path)) return("PENDING")
      iqt12_read(status_path)$status
    }, "") else character()
    data.frame(stage = sub("[.]csv$", "", basename(path)), planned = nrow(plan),
      complete = sum(statuses == "SUCCESS"),
      running = sum(statuses == "RUNNING"),
      failed = sum(grepl("FAILED", statuses)),
      pending = sum(statuses == "PENDING"), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

itm6_closeout <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  mcmc <- itm6_results(run, "mcmc")
  mae <- itm6_metric(mcmc, "forecast_mae")
  summary <- aggregate(mean ~ cell + model, mae, mean)
  wide <- reshape(summary, idvar = "cell", timevar = "model", direction = "wide")
  wide$ratio_qdesn_to_baseline <- wide$mean.qdesn / wide$mean.baseline
  iqt12_csv(wide, file.path(run, "review", "mcmc_primary_comparison.csv"))
  health <- itm6_health(run)
  stopifnot(all(health$failed == 0L), all(health$pending == 0L),
    all(health$running == 0L))
  decision <- if (all(wide$ratio_qdesn_to_baseline <= 1.1))
    "MECHANISM_RESOLVED_PREPARE_FULL_18_CELL_CONFIRMATION" else
    "MECHANISM_NOT_RESOLVED_RETAIN_DIAGNOSTIC_ONLY"
  closeout <- list(schema = itm6_schema, status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE,
    selection_used_article_holdout = FALSE,
    jobs = sum(health$planned), failures = sum(health$failed),
    ratios = split(wide, seq_len(nrow(wide))),
    active_jobs = 0L, fitted_binary_payloads = 0L,
    completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  iqt12_json(closeout, file.path(run, "closeout.json"))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "frozen_hashes.csv", "closeout.json")),
    list.files(file.path(run, "summaries"), full.names = TRUE),
    list.files(file.path(run, "selections"), full.names = TRUE),
    list.files(file.path(run, "review"), full.names = TRUE),
    list.files(file.path(run, "plans"), full.names = TRUE))
  iqt12_hash(files[file.exists(files)], file.path(run, "closeout_manifest.csv"))
  invisible(closeout)
}

itm6_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  results <- itm6_results(run, finished)
  iqt12_csv(results, file.path(run, "summaries", paste0(finished, ".csv")))
  if (finished == "smoke") return(itm6_plan_representation(state))
  if (finished == "representation") return(itm6_plan_quantile(state, run))
  if (finished == "quantile") return(itm6_plan_validation(state, run))
  if (finished == "validation") return(itm6_plan_rolling(state, run))
  if (finished == "rolling") return(itm6_plan_mcmc(state, run))
  if (finished == "mcmc") return(itm6_closeout(run))
  stop("Unknown completed stage: ", finished)
}

itm6_resources <- function(max_workers = 30L) {
  topology <- read.csv(pipe("lscpu -p=CPU,CORE,SOCKET,ONLINE | grep -v '^#'"),
    header = FALSE)
  names(topology) <- c("cpu", "core", "socket", "online")
  topology <- topology[topology$online == "Y", ]
  topology <- topology[!duplicated(paste(topology$socket, topology$core)), ]
  stopifnot(nrow(topology) >= max_workers)
  mem <- readLines("/proc/meminfo")
  available <- as.numeric(gsub("[^0-9]", "", mem[grepl("^MemAvailable:", mem)]))
  stopifnot(available >= 100 * 1024^2)
  head(topology$cpu, max_workers)
}
