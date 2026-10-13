ifu8_schema <- "independent_qdesn_forecast_uncertainty_v8"
ifu8_cell <- igc7_cell
ifu8_stages <- c("replay", "smoke", "warm", "discovery",
  "confirm_warm", "confirmation")
ifu8_tau_multipliers <- c(0.5, 0.75, 1, 1.5, 2, 2.5, 3)
ifu8_parent_run <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_gausmix_conditioning_v7_20261011/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_gausmix_conditioning_v7_20261011_160201__git-a7639786")

ifu8_metric_draws <- function(forecast, source, window, p) {
  grid <- iqt12_grid(window)
  stopifnot(is.matrix(forecast), nrow(forecast) == nrow(grid),
    all(is.finite(forecast)))
  truth <- source$q_target[grid$target]
  observed <- source$y[grid$target]
  error <- sweep(forecast, 1L, truth, "-")
  residual <- sweep(forecast, 1L, observed, function(q, y) y - q)
  data.frame(draw = seq_len(ncol(forecast)),
    forecast_mae = colMeans(abs(error)),
    forecast_rmse = sqrt(colMeans(error^2)),
    forecast_check_loss = colMeans(residual * (p - (residual < 0))))
}

ifu8_metric_summary <- function(draws) {
  rows <- lapply(setdiff(names(draws), "draw"), function(metric) {
    interval <- quantile(draws[[metric]], c(.025, .975),
      names = FALSE, type = 8)
    data.frame(metric = metric, mean = mean(draws[[metric]]),
      lower = interval[1L], upper = interval[2L],
      width = diff(interval), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

ifu8_path_diagnostics <- function(forecast, truth, alpha = .05) {
  stopifnot(nrow(forecast) == length(truth), ncol(forecast) >= 2L)
  lower <- apply(forecast, 1L, quantile, alpha / 2, type = 8)
  upper <- apply(forecast, 1L, quantile, 1 - alpha / 2, type = 8)
  width <- upper - lower
  interval_score <- width + 2 / alpha * (lower - truth) * (truth < lower) +
    2 / alpha * (truth - upper) * (truth > upper)
  centered <- sweep(forecast, 1L, rowMeans(forecast), "-")
  singular <- svd(centered, nu = 0L, nv = 0L)$d^2
  total <- sum(singular)
  share <- if (total > 0) singular / total else c(1, rep(0, length(singular) - 1L))
  effective_rank <- exp(-sum(share[share > 0] * log(share[share > 0])))
  correlation <- suppressWarnings(cor(t(centered)))
  off <- correlation[upper.tri(correlation)]
  c(pointwise_interval_width = mean(width),
    pointwise_truth_coverage = mean(truth >= lower & truth <= upper),
    mean_interval_score = mean(interval_score),
    first_pc_share = share[1L], effective_rank = effective_rank,
    mean_offdiagonal_correlation = mean(off, na.rm = TRUE),
    mean_absolute_offdiagonal_correlation = mean(abs(off), na.rm = TRUE))
}

ifu8_decomposition <- function(forecasts, source, window, p) {
  grid <- iqt12_grid(window)
  truth <- source$q_target[grid$target]
  rows <- lapply(names(forecasts), function(estimator) {
    metric <- ifu8_metric_summary(ifu8_metric_draws(
      forecasts[[estimator]], source, window, p))
    path <- as.list(ifu8_path_diagnostics(forecasts[[estimator]], truth))
    cbind(data.frame(estimator = estimator, stringsAsFactors = FALSE),
      metric, as.data.frame(path, stringsAsFactors = FALSE))
  })
  do.call(rbind, rows)
}

ifu8_origin_lead <- function(forecasts, source, window, p) {
  grid <- iqt12_grid(window)
  truth <- source$q_target[grid$target]
  observed <- source$y[grid$target]
  rows <- lapply(names(forecasts), function(estimator) {
    q <- forecasts[[estimator]]
    lower <- apply(q, 1L, quantile, .025, type = 8)
    upper <- apply(q, 1L, quantile, .975, type = 8)
    residual <- sweep(q, 1L, observed, function(x, y) y - x)
    cbind(grid, estimator = estimator, q_mean = rowMeans(q),
      q025 = lower, q975 = upper, interval_width = upper - lower,
      true = truth, bias = rowMeans(sweep(q, 1L, truth, "-")),
      mae = rowMeans(abs(sweep(q, 1L, truth, "-"))),
      check_loss = rowMeans(residual * (p - (residual < 0))))
  })
  do.call(rbind, rows)
}

ifu8_particle_paths <- function(e, object, y, local, H, draws, noise,
                                conditioning) {
  r <- object$reservoir
  meta <- object$meta
  spec <- meta$readout_spec
  count <- nrow(draws$beta)
  stopifnot(all(r$Q_is_identity), identical(r$act_f, "tanh"),
    identical(r$act_k, "identity"), isTRUE(meta$add_bias),
    !isTRUE(spec$include_input), length(spec$y_lags) == 0L,
    length(spec$x_names) == 0L, (spec$reservoir_lags %||% 0L) == 0L,
    !isTRUE(spec$linear_transform$active),
    ncol(draws$beta) == sum(r$n) + 1L)
  h <- lapply(object$states$H_all, function(z)
    matrix(z[local, ], nrow = ncol(z), ncol = count))
  lags <- matrix(y[local - seq_len(r$m) + 1L], nrow = r$m, ncol = count)
  abc <- lapply(draws$gamma, function(g)
    e$exal_get_ABC(meta$p0 %||% object$fit$misc$p0, g))
  A <- vapply(abc, `[[`, 0, "A")
  B <- vapply(abc, `[[`, 0, "B")
  lambda <- vapply(abc, `[[`, 0, "C") * abs(draws$gamma)
  beta <- t(draws$beta)
  mu <- yrep <- matrix(0, H, count)
  state_sums <- matrix(0, H, ncol(draws$beta))
  for (lead in seq_len(H)) {
    z <- (lags - meta$lag_center) / meta$lag_scale
    if (meta$input_bound == "tanh") z <- tanh(z / meta$input_bound_divisor)
    u <- rbind(rep(meta$win_scale_bias, count), z * meta$win_scale_global)
    for (d in seq_len(r$D)) {
      input <- if (d == 1L) u else h[[d - 1L]]
      h[[d]] <- as.matrix((1 - r$alpha[d]) * h[[d]] + r$alpha[d] *
        tanh(r$W[[d]] %*% h[[d]] + r$Win[[d]] %*% input))
    }
    x <- rbind(rep(1, count), h[[r$D]], do.call(rbind, head(h, -1L)))
    x <- t(igc7_condition_apply(t(x), conditioning))
    state_sums[lead, ] <- rowSums(x)
    mu[lead, ] <- colSums(x * beta)
    yrep[lead, ] <- mu[lead, ] + lambda * draws$sigma * noise$s[lead, ] +
      A * noise$v[lead, ] +
      sqrt(B * draws$sigma * noise$v[lead, ]) * noise$z[lead, ]
    lags <- rbind(yrep[lead, ], head(lags, -1L))
  }
  stopifnot(all(is.finite(mu)), all(is.finite(yrep)),
    all(is.finite(state_sums)))
  list(mu_draws = mu, yrep = yrep, state_sums = state_sums)
}

ifu8_qforecast_hook <- function(e, cx, cfg, fit, draws, progress = NULL) {
  object <- cx$object
  object$fit <- fit
  window <- cfg$window
  current <- plugin <- common <- list()
  guards <- list()
  for (i in seq_along(window$origins)) {
    origin <- window$origins[i]
    local <- origin - cx$first + 1L
    H <- min(window$horizon, window$end - origin)
    bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L,
      if (cfg$inner >= 128L) 256L else cfg$inner, cfg$seed + origin)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1L]]
    outer <- nrow(draws$beta)
    means <- plug <- matrix(0, H, outer)
    state_sum <- matrix(0, H, ncol(draws$beta))
    batches <- split(seq_len(outer),
      ceiling(seq_len(outer) / max(1L, 256L %/% cfg$inner)))
    for (ids in batches) {
      subset <- e$iqcf_v3_subset_draws(draws, ids)
      repeated <- e$iqcf_v3_repeat_draws(subset, cfg$inner)
      columns <- unlist(lapply(ids,
        function(j) (j - 1L) * cfg$inner + seq_len(cfg$inner)))
      path <- ifu8_particle_paths(e, object, cx$y, local, H, repeated,
        lapply(noise, function(z) z[, columns, drop = FALSE]),
        cx$conditioning)
      means[, ids] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws,
        length(ids), cfg$inner, "mean")
      state_sum <- state_sum + path$state_sums
      zeros <- matrix(0, H, length(ids))
      plug[, ids] <- ifu8_particle_paths(e, object, cx$y, local, H, subset,
        list(s = zeros, v = zeros, z = zeros), cx$conditioning)$mu_draws
    }
    mean_state <- state_sum / (outer * cfg$inner)
    shared <- mean_state %*% t(draws$beta)
    expected <- cx$all_X[local + 1L, , drop = FALSE] %*%
      t(draws$beta) * cx$scale
    current_actual <- means[1L, , drop = FALSE] * cx$scale
    shared_actual <- shared[1L, , drop = FALSE] * cx$scale
    error <- max(abs(expected - current_actual))
    shared_error <- max(abs(expected - shared_actual))
    tolerance <- 1e-6 * max(1, max(abs(expected)))
    guards[[i]] <- data.frame(origin = origin,
      current_prediction_max_absolute_error = error,
      shared_state_prediction_max_absolute_error = shared_error,
      pass = error <= tolerance && shared_error <= tolerance)
    stopifnot(guards[[i]]$pass)
    current[[i]] <- means * cx$scale
    plugin[[i]] <- plug * cx$scale
    common[[i]] <- shared * cx$scale
    if (!is.null(progress)) progress(i, length(window$origins))
  }
  common <- do.call(rbind, common)
  assign(".ifu8_common_state", common, envir = .GlobalEnv)
  list(primary = do.call(rbind, current), plugin = do.call(rbind, plugin),
    common_state = common, first_step_guard = do.call(rbind, guards))
}

ifu8_selected_draws <- function(path) {
  value <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  beta_names <- grep("^var[0-9]+$", names(value), value = TRUE)
  stopifnot(length(beta_names) > 1L, all(c("sigma", "gamma") %in% names(value)))
  list(beta = as.matrix(value[, beta_names, drop = FALSE]),
    sigma = value$sigma, gamma = value$gamma,
    sigmagam_draw_contract = "retained_MCMC_pairs")
}

ifu8_common_only <- function(e, cx, cfg, draws, progress = NULL) {
  object <- cx$object
  object$fit <- list(misc = list(p0 = cfg$p))
  output <- list()
  for (i in seq_along(cfg$window$origins)) {
    origin <- cfg$window$origins[i]
    local <- origin - cx$first + 1L
    H <- min(cfg$window$horizon, cfg$window$end - origin)
    bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L,
      if (cfg$inner >= 128L) 256L else cfg$inner, cfg$seed + origin)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1L]]
    outer <- nrow(draws$beta)
    state_sum <- matrix(0, H, ncol(draws$beta))
    batches <- split(seq_len(outer),
      ceiling(seq_len(outer) / max(1L, 256L %/% cfg$inner)))
    for (ids in batches) {
      subset <- e$iqcf_v3_subset_draws(draws, ids)
      repeated <- e$iqcf_v3_repeat_draws(subset, cfg$inner)
      columns <- unlist(lapply(ids,
        function(j) (j - 1L) * cfg$inner + seq_len(cfg$inner)))
      path <- ifu8_particle_paths(e, object, cx$y, local, H, repeated,
        lapply(noise, function(z) z[, columns, drop = FALSE]),
        cx$conditioning)
      state_sum <- state_sum + path$state_sums
    }
    mean_state <- state_sum / (outer * cfg$inner)
    output[[i]] <- mean_state %*% t(draws$beta) * cx$scale
    if (!is.null(progress)) progress(i, length(cfg$window$origins))
  }
  do.call(rbind, output)
}

ifu8_augment_evidence <- function(cfg, source, common, current, plugin,
                                  provenance = list()) {
  forecasts <- list(current_recursive = current,
    beta_specific_zero_noise = plugin,
    shared_mean_state = common)
  common_draws <- ifu8_metric_draws(common, source, cfg$window, cfg$p)
  iqt12_csv(cbind(iqt12_grid(cfg$window), common),
    file.path(cfg$evidence, "shared_mean_state_location_draws.csv.gz"))
  iqt12_csv(common_draws,
    file.path(cfg$evidence, "shared_mean_state_metric_draws.csv.gz"))
  iqt12_csv(ifu8_decomposition(forecasts, source, cfg$window, cfg$p),
    file.path(cfg$evidence, "uncertainty_decomposition.csv"))
  iqt12_csv(ifu8_origin_lead(forecasts, source, cfg$window, cfg$p),
    file.path(cfg$evidence, "origin_lead_uncertainty.csv.gz"))
  diagnostics_path <- file.path(cfg$evidence, "diagnostics.json")
  diagnostics <- if (file.exists(diagnostics_path)) iqt12_read(diagnostics_path) else list()
  diagnostics$forecast_uncertainty_v8 <- c(list(
    estimators = names(forecasts),
    shared_state_contract = paste0(
      "average_recursive_conditioned_readout_states_across_posterior_",
      "coefficient_and_process_paths_then_apply_each_coefficient_draw"),
    primary_estimator_unchanged = TRUE,
    promotion_status = "diagnostic_only_until_confirmed"), provenance)
  iqt12_json(diagnostics, diagnostics_path)
  manifest_path <- file.path(cfg$evidence, "manifest.csv")
  if (file.exists(manifest_path)) unlink(manifest_path)
  files <- list.files(cfg$evidence, full.names = TRUE)
  manifest <- iqt12_hash(files, manifest_path)
  status <- iqt12_read(cfg$status_path)
  status$manifest <- manifest
  status$fitted_binary_payloads <- 0L
  status$forecast_uncertainty_v8 <- "COMPLETE"
  iqt12_json(status, cfg$status_path)
  invisible(TRUE)
}

ifu8_config <- function(state, stage, estimator, fold, tau_multiplier,
                        chain = 1L, warm_path = NULL) {
  stopifnot(stage %in% setdiff(ifu8_stages, "replay"),
    fold %in% names(itm6_folds), tau_multiplier %in% ifu8_tau_multipliers)
  base_stage <- if (stage == "smoke") "smoke" else
    if (estimator == "quantile_vb") "validation" else "mcmc"
  cfg <- igc7_config(state, state$winner, base_stage, estimator, fold,
    chain, tau_multiplier, "fold_zscore")
  cfg$schema <- ifu8_schema
  cfg$stage <- stage
  cfg$id <- sub(paste0("^", base_stage, "__"), paste0(stage, "__"), cfg$id)
  cfg$seed <- itm6_seed(cfg$id)
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  if (stage == "smoke") {
    cfg$window$origins <- head(cfg$window$origins, 2L)
    cfg$outer <- 4L; cfg$inner <- 8L; cfg$burn <- 20L; cfg$retained <- 40L
  } else if (stage == "warm") {
    cfg$outer <- 48L; cfg$inner <- 32L; cfg$vb_iter <- 800L
  } else if (stage == "discovery") {
    cfg$outer <- 300L; cfg$inner <- 128L
    cfg$burn <- 1500L; cfg$retained <- 5000L
  } else if (stage == "confirm_warm") {
    cfg$outer <- 32L; cfg$inner <- 32L; cfg$vb_iter <- 1000L
  } else if (stage == "confirmation") {
    cfg$outer <- 300L; cfg$inner <- 128L
    cfg$burn <- 3000L; cfg$retained <- 10000L
    cfg$timeout <- 259200L
  }
  if (!is.null(warm_path)) {
    cfg$warm_path <- normalizePath(warm_path, mustWork = TRUE)
    cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path))
  }
  cfg
}

ifu8_replay_config <- function(state, parent_row) {
  parent_cfg <- iqt12_read(parent_row$config_path)
  id <- paste0("replay__", parent_cfg$id)
  list(schema = ifu8_schema, run = state$run, repo = state$repo,
    library = state$library, id = id, stage = "replay", cell = parent_cfg$cell,
    family = parent_cfg$family, p = parent_cfg$p,
    likelihood = parent_cfg$likelihood, model = parent_cfg$model,
    estimator = "retained_draw_replay", engine = "replay",
    chain = parent_cfg$chain, candidate = parent_cfg$candidate,
    tau_multiplier = parent_cfg$tau_multiplier,
    readout_conditioning = parent_cfg$readout_conditioning,
    source_path = state$references[[ifu8_cell]]$source_path,
    source_sha = state$references[[ifu8_cell]]$source_sha,
    window = parent_cfg$window, outer = parent_cfg$outer,
    inner = parent_cfg$inner, seed = parent_cfg$seed,
    parent_config_path = normalizePath(parent_row$config_path, mustWork = TRUE),
    parent_config_sha = unname(tools::sha256sum(parent_row$config_path)),
    parent_evidence = normalizePath(parent_cfg$evidence, mustWork = TRUE),
    parent_manifest = normalizePath(iqt12_read(parent_row$status_path)$manifest,
      mustWork = TRUE),
    path = file.path(state$run, "configs", paste0(id, ".json")),
    status_path = file.path(state$run, "status", paste0(id, ".json")),
    evidence = file.path(state$run, "evidence", id), timeout = 172800L)
}

ifu8_plan <- function(state, configs, stage) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Frozen stage already exists: ", stage)
  rows <- lapply(configs, function(cfg) {
    iqt12_json(cfg, cfg$path)
    data.frame(id = cfg$id, stage = stage, cell = cfg$cell,
      estimator = cfg$estimator, engine = cfg$engine,
      fold = cfg$window$fold, chain = cfg$chain,
      candidate_id = cfg$candidate$id,
      structure_id = cfg$candidate$structure_id,
      tau_multiplier = cfg$tau_multiplier,
      config_path = cfg$path,
      config_sha = unname(tools::sha256sum(cfg$path)),
      status_path = cfg$status_path, timeout = cfg$timeout,
      stringsAsFactors = FALSE)
  })
  plan <- do.call(rbind, rows)
  stopifnot(nrow(plan) > 0L, !anyDuplicated(plan$id))
  iqt12_csv(plan, path)
  iqt12_hash(c(path, plan$config_path), file.path(state$run, "plans",
    paste0(stage, "_hashes.csv")))
  plan
}

ifu8_materialize <- function(repo, run, library, parent = ifu8_parent_run) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(library),
    dir.exists(parent))
  iqt12_verify(file.path(parent, "closeout_manifest.csv"))
  parent_closeout <- iqt12_read(file.path(parent, "closeout.json"))
  stopifnot(parent_closeout$status == "COMPLETE_REVIEW_REQUIRED",
    parent_closeout$scientific_decision ==
      "MECHANISM_RESOLVED_PREPARE_FULL_18_CELL_CONFIRMATION",
    parent_closeout$failures == 0L,
    parent_closeout$best$candidate_id == "1c2ea98bf70da2a87aec")
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "references", "sources"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  parent_state <- iqt12_read(file.path(parent, "campaign.json"))
  reference <- parent_state$references[[ifu8_cell]]
  source <- read.csv(reference$source_path, stringsAsFactors = FALSE)
  stopifnot(max(source$t) == 9000L)
  source_path <- file.path(run, "sources", paste0(ifu8_cell, ".csv"))
  iqt12_csv(source, source_path)
  reference$source_path <- source_path
  reference$source_sha <- unname(tools::sha256sum(source_path))
  parent_plan <- read.csv(file.path(parent, "plans", "mcmc.csv"),
    stringsAsFactors = FALSE)
  parent_plan <- parent_plan[
    parent_plan$candidate_id == parent_closeout$best$candidate_id &
    parent_plan$fold %in% c("S2", "S4"), , drop = FALSE]
  stopifnot(nrow(parent_plan) == 6L)
  winner <- iqt12_read(parent_plan$config_path[1L])$candidate
  state <- list(schema = ifu8_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE),
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    scientific_parent_head = parent_state$head,
    parent_run = normalizePath(parent, mustWork = TRUE),
    max_workers = 30L, cell = ifu8_cell, winner = winner,
    tau_multipliers = ifu8_tau_multipliers,
    references = setNames(list(reference), ifu8_cell),
    contract = list(
      target = "Gaussian-mixture_AL_p0.05_forecast_uncertainty_rescue",
      fixed_structure = winner$structure_id,
      selection_folds = c("S1", "S3"),
      confirmation_folds = c("S2", "S4"),
      article_holdout = "source_indices_9001_to_10000_never_opened",
      primary_estimator = "current_recursive_inner_average",
      diagnostic_estimator = "shared_mean_recursive_state_then_beta_draws",
      teacher_forcing = "observations_assimilated_between_origins",
      within_origin = "recursive_30_step_forecast",
      article_promotion = FALSE,
      fallback = "local_architecture_search_only_if_tau_rescue_fails"))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_json(winner, file.path(run, "references", "winner_candidate.json"))
  stopifnot(file.copy(file.path(parent, "references", "v6_baseline_scores.csv"),
      file.path(run, "references", "dqlm_baseline_scores.csv")),
    file.copy(file.path(parent, "review", "mcmc_primary_comparison.csv"),
      file.path(run, "references", "v7_primary_comparison.csv")))
  environment <- list(schema = ifu8_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    exdqlm_repository = utils::packageDescription("exdqlm", lib.loc = library)$Repository,
    package_path = find.package("exdqlm", lib.loc = library),
    R = R.version.string, session = capture.output(sessionInfo()),
    threads = as.list(Sys.getenv(c("OMP_NUM_THREADS",
      "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLIS_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "RCPP_PARALLEL_NUM_THREADS"))),
    source_head = state$head)
  stopifnot(environment$exdqlm_version == "1.1.2",
    environment$exdqlm_repository == "CRAN")
  iqt12_json(environment, file.path(run, "environment.json"))
  source_files <- file.path(repo, "validation/fitforecast_v2", c(
    "R/independent_qdesn_training1000_runtime_v1.R",
    "R/independent_qdesn_training1000_campaign_v1.R",
    "R/independent_qdesn_sentinel_mechanism_v1.R",
    "R/independent_qdesn_training_size_mechanism_v6.R",
    "R/independent_qdesn_gausmix_conditioning_v7.R",
    "R/independent_qdesn_forecast_uncertainty_v8.R",
    "scripts/independent_qdesn_forecast_uncertainty_v8.R",
    "scripts/run_independent_qdesn_forecast_uncertainty_v8.sh",
    "docs/INDEPENDENT_QDESN_FORECAST_UNCERTAINTY_V8_20261011.md"))
  iqt12_hash(source_files, file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(parent, c("closeout.json", "closeout_manifest.csv")),
    parent_plan$config_path, parent_plan$status_path),
    file.path(run, "input_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "source_hashes.csv", "package_hashes.csv", "input_hashes.csv")),
    source_path, file.path(run, "references", c("winner_candidate.json",
      "dqlm_baseline_scores.csv", "v7_primary_comparison.csv"))),
    file.path(run, "frozen_hashes.csv"))
  replay <- lapply(seq_len(nrow(parent_plan)), function(i)
    ifu8_replay_config(state, parent_plan[i, , drop = FALSE]))
  ifu8_plan(state, replay, "replay")
  invisible(state)
}

ifu8_replay_worker <- function(cfg) {
  started <- proc.time()[["elapsed"]]
  for (name in c("source_hashes.csv", "package_hashes.csv", "input_hashes.csv",
      "frozen_hashes.csv")) iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", "replay_hashes.csv"))
  stopifnot(!file.exists(cfg$status_path),
    unname(tools::sha256sum(cfg$parent_config_path)) == cfg$parent_config_sha)
  iqt12_verify(cfg$parent_manifest)
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid()),
    cfg$status_path)
  tryCatch({
    e <- ism1_runtime(cfg$repo, cfg$library)
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source); full[source$t, ] <- source
    source <- full
    cx <- igc7_design_hook(e, cfg, source, cfg$window$end)
    draws <- ifu8_selected_draws(file.path(cfg$parent_evidence,
      "selected_parameters.csv.gz"))
    stopifnot(nrow(draws$beta) == cfg$outer)
    progress <- function(i, total) iqt12_json(list(status = "RUNNING",
      id = cfg$id, pid = Sys.getpid(), phase = "shared_state_replay",
      origin = i, total_origins = total), cfg$status_path)
    common <- ifu8_common_only(e, cx, cfg, draws, progress)
    current_raw <- read.csv(file.path(cfg$parent_evidence,
      "forecast_location_draws.csv.gz"), check.names = FALSE)
    plugin_raw <- read.csv(file.path(cfg$parent_evidence,
      "plugin_location_draws.csv.gz"), check.names = FALSE)
    current <- as.matrix(current_raw[, -(1:3), drop = FALSE])
    plugin <- as.matrix(plugin_raw[, -(1:3), drop = FALSE])
    stopifnot(identical(dim(common), dim(current)),
      identical(current_raw[, 1:3], plugin_raw[, 1:3]))
    iqt12_csv(data.frame(metric_source = "retained_parent_v7",
      parent_config = cfg$parent_config_path,
      parent_manifest = cfg$parent_manifest,
      parent_selected_parameters_sha = unname(tools::sha256sum(file.path(
        cfg$parent_evidence, "selected_parameters.csv.gz")))),
      file.path(cfg$evidence, "replay_provenance.csv"))
    iqt12_csv(cbind(iqt12_grid(cfg$window), common),
      file.path(cfg$evidence, "shared_mean_state_location_draws.csv.gz"))
    iqt12_csv(ifu8_metric_draws(common, source, cfg$window, cfg$p),
      file.path(cfg$evidence, "shared_mean_state_metric_draws.csv.gz"))
    forecasts <- list(current_recursive = current,
      beta_specific_zero_noise = plugin, shared_mean_state = common)
    iqt12_csv(ifu8_decomposition(forecasts, source, cfg$window, cfg$p),
      file.path(cfg$evidence, "uncertainty_decomposition.csv"))
    iqt12_csv(ifu8_origin_lead(forecasts, source, cfg$window, cfg$p),
      file.path(cfg$evidence, "origin_lead_uncertainty.csv.gz"))
    iqt12_json(list(replay = TRUE,
      shared_state_contract = paste0("average_recursive_conditioned_readout_",
        "states_then_apply_each_retained_beta_draw"),
      elapsed = proc.time()[["elapsed"]] - started,
      fitted_binary_payloads = 0L),
      file.path(cfg$evidence, "diagnostics.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = proc.time()[["elapsed"]] - started,
      fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error),
      elapsed = proc.time()[["elapsed"]] - started), cfg$status_path)
    stop(error)
  })
}

ifu8_worker <- function(path) {
  cfg <- iqt12_read(path)
  if (cfg$stage == "replay") return(ifu8_replay_worker(cfg))
  if (exists(".ifu8_common_state", envir = .GlobalEnv, inherits = FALSE))
    rm(".ifu8_common_state", envir = .GlobalEnv)
  assign("iqt12_design_hook", igc7_design_hook, envir = .GlobalEnv)
  assign("iqt12_qforecast_hook", ifu8_qforecast_hook, envir = .GlobalEnv)
  tryCatch({
    iqt12_worker(path)
    stopifnot(exists(".ifu8_common_state", envir = .GlobalEnv,
      inherits = FALSE))
    common <- get(".ifu8_common_state", envir = .GlobalEnv)
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source); full[source$t, ] <- source
    source <- full
    current_raw <- read.csv(file.path(cfg$evidence,
      "forecast_location_draws.csv.gz"), check.names = FALSE)
    plugin_raw <- read.csv(file.path(cfg$evidence,
      "plugin_location_draws.csv.gz"), check.names = FALSE)
    ifu8_augment_evidence(cfg, source, common,
      as.matrix(current_raw[, -(1:3), drop = FALSE]),
      as.matrix(plugin_raw[, -(1:3), drop = FALSE]),
      list(stage = cfg$stage, tau_multiplier = cfg$tau_multiplier))
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error)), cfg$status_path)
    stop(error)
  })
}

ifu8_health <- function(run) {
  plans <- list.files(file.path(run, "plans"),
    pattern = "^[a-z_]+[.]csv$", full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  rows <- lapply(plans, function(path) {
    plan <- read.csv(path, stringsAsFactors = FALSE)
    statuses <- vapply(plan$status_path, function(status_path) {
      if (!file.exists(status_path)) return("PENDING")
      iqt12_read(status_path)$status
    }, "")
    data.frame(stage = sub("[.]csv$", "", basename(path)),
      planned = nrow(plan), complete = sum(statuses == "SUCCESS"),
      running = sum(statuses == "RUNNING"),
      failed = sum(grepl("FAILED", statuses)),
      pending = sum(statuses == "PENDING"), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

ifu8_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    status <- iqt12_read(plan$status_path[i])
    stopifnot(status$status == "SUCCESS")
    iqt12_verify(status$manifest)
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence, "summary.csv"),
      stringsAsFactors = FALSE)
    value$tau_multiplier <- cfg$tau_multiplier
    value$structure_id <- cfg$candidate$structure_id
    value$config_path <- cfg$path
    value
  })
  do.call(rbind, rows)
}

ifu8_uncertainty_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence,
      "uncertainty_decomposition.csv"), stringsAsFactors = FALSE)
    value$id <- cfg$id; value$fold <- cfg$window$fold
    value$chain <- cfg$chain; value$tau_multiplier <- cfg$tau_multiplier
    value$config_path <- cfg$path
    value
  })
  do.call(rbind, rows)
}

ifu8_select_taus <- function(results, uncertainty) {
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  path <- uncertainty[uncertainty$estimator == "current_recursive" &
    uncertainty$metric == "forecast_mae", ]
  taus <- sort(unique(mae$tau_multiplier))
  rows <- lapply(taus, function(tau) {
    m <- mae[mae$tau_multiplier == tau, ]
    c <- check[check$tau_multiplier == tau, ]
    u <- path[path$tau_multiplier == tau, ]
    data.frame(tau_multiplier = tau, forecast_mae = mean(m$mean),
      worst_fold_mae = max(m$mean), forecast_mae_width = mean(m$upper - m$lower),
      forecast_check_loss = mean(c$mean),
      interval_score = mean(u$mean_interval_score),
      pointwise_interval_width = mean(u$pointwise_interval_width),
      folds = length(unique(m$fold)), stringsAsFactors = FALSE)
  })
  rank <- do.call(rbind, rows)
  gate <- rank$forecast_mae <= 1.10 * min(rank$forecast_mae)
  eligible <- rank[gate, , drop = FALSE]
  fields <- c("forecast_mae", "forecast_mae_width", "interval_score")
  scaled <- sapply(fields, function(field)
    eligible[[field]] / min(eligible[[field]]))
  eligible$composite <- scaled[, 1L] + .5 * scaled[, 2L] + .25 * scaled[, 3L]
  eligible <- eligible[order(eligible$composite, eligible$forecast_mae,
    eligible$forecast_mae_width), ]
  chosen <- eligible$tau_multiplier[1L]
  if (chosen != 3) chosen <- c(chosen, 3) else {
    alternatives <- setdiff(eligible$tau_multiplier, chosen)
    if (!length(alternatives)) alternatives <- setdiff(rank$tau_multiplier, chosen)
    chosen <- c(chosen, alternatives[1L])
  }
  chosen <- unique(head(chosen, 2L))
  rank$selected <- rank$tau_multiplier %in% chosen
  rank$selection_rule <- ifelse(rank$selected,
    "best_multiobjective_plus_tau3_anchor", "not_selected")
  list(rank = rank[order(rank$forecast_mae), ], selected = chosen)
}

ifu8_plan_smoke <- function(state) {
  ifu8_plan(state, list(ifu8_config(state, "smoke", "quantile_mcmc",
    "S1", 2, 1L)), "smoke")
}

ifu8_plan_warm <- function(state) {
  configs <- list()
  for (tau in ifu8_tau_multipliers) for (fold in c("S1", "S3"))
    configs[[length(configs) + 1L]] <- ifu8_config(state, "warm",
      "quantile_vb", fold, tau)
  ifu8_plan(state, configs, "warm")
}

ifu8_plan_discovery <- function(state, run) {
  warm <- read.csv(file.path(run, "plans", "warm.csv"), stringsAsFactors = FALSE)
  configs <- list()
  for (i in seq_len(nrow(warm))) {
    initializer <- file.path(run, "evidence", warm$id[i],
      "mcmc_initializer.json")
    configs[[length(configs) + 1L]] <- ifu8_config(state, "discovery",
      "quantile_mcmc", warm$fold[i], warm$tau_multiplier[i], 1L,
      initializer)
  }
  ifu8_plan(state, configs, "discovery")
}

ifu8_plan_confirm_warm <- function(state, run) {
  results <- ifu8_results(run, "discovery")
  uncertainty <- ifu8_uncertainty_results(run, "discovery")
  selection <- ifu8_select_taus(results, uncertainty)
  iqt12_csv(selection$rank,
    file.path(run, "summaries", "discovery_tau_rank.csv"))
  iqt12_csv(data.frame(tau_multiplier = selection$selected),
    file.path(run, "selections", "discovery_to_confirmation.csv"))
  configs <- list()
  for (tau in selection$selected) for (fold in c("S2", "S4"))
    configs[[length(configs) + 1L]] <- ifu8_config(state, "confirm_warm",
      "quantile_vb", fold, tau)
  ifu8_plan(state, configs, "confirm_warm")
}

ifu8_plan_confirmation <- function(state, run) {
  warm <- read.csv(file.path(run, "plans", "confirm_warm.csv"),
    stringsAsFactors = FALSE)
  configs <- list()
  for (i in seq_len(nrow(warm))) for (chain in 1:3) {
    initializer <- file.path(run, "evidence", warm$id[i],
      "mcmc_initializer.json")
    configs[[length(configs) + 1L]] <- ifu8_config(state, "confirmation",
      "quantile_mcmc", warm$fold[i], warm$tau_multiplier[i], chain,
      initializer)
  }
  ifu8_plan(state, configs, "confirmation")
}

ifu8_confirmation_table <- function(run) {
  results <- ifu8_results(run, "confirmation")
  uncertainty <- ifu8_uncertainty_results(run, "confirmation")
  replay <- ifu8_uncertainty_results(run, "replay")
  baseline <- read.csv(file.path(run, "references", "dqlm_baseline_scores.csv"),
    stringsAsFactors = FALSE)
  baseline <- baseline[baseline$source_stage == "mcmc", ]
  baseline_mae <- baseline[baseline$metric == "forecast_mae", ]
  baseline_check <- baseline[baseline$metric == "forecast_check_loss", ]
  current_mae <- replay[replay$estimator == "current_recursive" &
    replay$metric == "forecast_mae", ]
  current_check <- replay[replay$estimator == "current_recursive" &
    replay$metric == "forecast_check_loss", ]
  current <- list(mae = mean(current_mae$mean),
    width = mean(current_mae$width),
    check = mean(current_check$mean),
    interval_score = mean(current_mae$mean_interval_score))
  taus <- sort(unique(results$tau_multiplier))
  rows <- lapply(taus, function(tau) {
    mae <- results[results$tau_multiplier == tau &
      results$metric == "forecast_mae", ]
    check <- results[results$tau_multiplier == tau &
      results$metric == "forecast_check_loss", ]
    path <- uncertainty[uncertainty$tau_multiplier == tau &
      uncertainty$estimator == "current_recursive" &
      uncertainty$metric == "forecast_mae", ]
    fold_means <- aggregate(mean ~ fold, mae, mean)
    baseline_fold <- aggregate(mean ~ fold, baseline_mae, mean)
    names(baseline_fold)[2L] <- "baseline"
    fold_means <- merge(fold_means, baseline_fold, by = "fold")
    data.frame(tau_multiplier = tau,
      qdesn_forecast_mae = mean(mae$mean),
      dqlm_forecast_mae = mean(baseline_mae$mean),
      ratio_to_dqlm = mean(mae$mean) / mean(baseline_mae$mean),
      worst_fold_ratio = max(fold_means$mean / fold_means$baseline),
      forecast_mae_width = mean(mae$upper - mae$lower),
      dqlm_forecast_mae_width = mean(baseline_mae$upper - baseline_mae$lower),
      v7_forecast_mae = current$mae,
      v7_forecast_mae_width = current$width,
      forecast_check_loss = mean(check$mean),
      dqlm_forecast_check_loss = mean(baseline_check$mean),
      v7_forecast_check_loss = current$check,
      interval_score = mean(path$mean_interval_score),
      v7_interval_score = current$interval_score,
      chains = nrow(mae), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out$eligible <- with(out, ratio_to_dqlm <= 1.10 &
    worst_fold_ratio <= 1.20 &
    qdesn_forecast_mae <= 1.02 * v7_forecast_mae &
    forecast_mae_width < v7_forecast_mae_width &
    forecast_check_loss <= 1.02 * v7_forecast_check_loss &
    interval_score <= 1.02 * v7_interval_score)
  out[order(!out$eligible, out$ratio_to_dqlm, out$forecast_mae_width), ]
}

ifu8_closeout <- function(run) {
  health <- ifu8_health(run)
  stopifnot(all(health$complete == health$planned),
    all(health$failed == 0L), all(health$running == 0L),
    all(health$pending == 0L))
  comparison <- ifu8_confirmation_table(run)
  iqt12_csv(comparison,
    file.path(run, "review", "confirmation_decision_table.csv"))
  eligible <- comparison[comparison$eligible, , drop = FALSE]
  decision <- if (nrow(eligible))
    "UNCERTAINTY_RESCUE_CONFIRMED_PREPARE_18_CELL_PROPAGATION" else
    "TAU_RESCUE_INSUFFICIENT_PREPARE_LOCAL_ARCHITECTURE_FALLBACK"
  closeout <- list(schema = ifu8_schema,
    status = "COMPLETE_REVIEW_REQUIRED", scientific_decision = decision,
    article_changed = FALSE, selection_used_article_holdout = FALSE,
    jobs = sum(health$planned), failures = sum(health$failed),
    best = as.list(comparison[1L, ]), active_jobs = 0L,
    fitted_binary_payloads = 0L,
    completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  iqt12_json(closeout, file.path(run, "closeout.json"))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "source_hashes.csv", "package_hashes.csv", "input_hashes.csv",
    "frozen_hashes.csv", "closeout.json")),
    list.files(file.path(run, "references"), full.names = TRUE),
    list.files(file.path(run, "summaries"), full.names = TRUE),
    list.files(file.path(run, "selections"), full.names = TRUE),
    list.files(file.path(run, "review"), full.names = TRUE),
    list.files(file.path(run, "plans"), full.names = TRUE))
  iqt12_hash(files[file.exists(files)],
    file.path(run, "closeout_manifest.csv"))
  invisible(closeout)
}

ifu8_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  if (finished == "replay") return(ifu8_plan_smoke(state))
  if (finished == "smoke") return(ifu8_plan_warm(state))
  if (finished == "warm") return(ifu8_plan_discovery(state, run))
  if (finished == "discovery") return(ifu8_plan_confirm_warm(state, run))
  if (finished == "confirm_warm") return(ifu8_plan_confirmation(state, run))
  if (finished == "confirmation") return(ifu8_closeout(run))
  stop("Unknown completed stage: ", finished)
}

ifu8_resources <- itm6_resources
