ilr10_schema <- "independent_qdesn_layerwise_readout_v10"
ilr10_cell <- ifu9_cell
ilr10_stages <- c("smoke", "warm", "discovery", "confirm_warm",
  "confirmation")
ilr10_parent_run <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_rhs_uncertainty_v9_20261012/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_rhs_uncertainty_v9_20261012_001700__git-1af1443d")
ilr10_scale_grid <- c(0.25, 0.40, 0.55, 0.70, 0.85, 1.00)

ilr10_maximin_panel <- function(count = 12L) {
  grid <- expand.grid(layer1_scale = ilr10_scale_grid,
    layer2_scale = ilr10_scale_grid, KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  grid <- grid[order(grid$layer1_scale, grid$layer2_scale), , drop = FALSE]
  anchors <- rbind(c(1, 1), c(.4, .7), c(.55, .55), c(.7, .85))
  selected <- unique(vapply(seq_len(nrow(anchors)), function(i)
    which(abs(grid$layer1_scale - anchors[i, 1L]) < 1e-12 &
      abs(grid$layer2_scale - anchors[i, 2L]) < 1e-12)[1L], 1L))
  features <- scale(cbind(log(grid$layer1_scale), log(grid$layer2_scale)))
  while (length(selected) < count) {
    remaining <- setdiff(seq_len(nrow(grid)), selected)
    distance <- vapply(remaining, function(i)
      min(rowSums((features[selected, , drop = FALSE] -
        matrix(features[i, ], nrow = length(selected), ncol = 2L,
          byrow = TRUE))^2)), 0)
    selected <- c(selected, remaining[which.max(distance)])
  }
  panel <- grid[selected, , drop = FALSE]
  panel$role <- ifelse(panel$layer1_scale == 1 & panel$layer2_scale == 1,
    "unmodified_v9_anchor", "layerwise_relative_shrinkage")
  panel$scale_id <- vapply(seq_len(nrow(panel)), function(i)
    substr(digest::digest(as.list(panel[i, c("layer1_scale",
      "layer2_scale")]), algo = "sha256"), 1L, 16L), "")
  panel[order(panel$layer1_scale, panel$layer2_scale), , drop = FALSE]
}

ilr10_multiplier_vector <- function(n, layer1_scale, layer2_scale) {
  blocks <- ifu9_block_indices(n)
  multiplier <- rep(1, sum(lengths(blocks)))
  multiplier[blocks$layer_1] <- as.numeric(layer1_scale)
  multiplier[blocks$layer_2] <- as.numeric(layer2_scale)
  stopifnot(length(multiplier) == sum(as.integer(n)) + 1L,
    all(is.finite(multiplier)), all(multiplier > 0), multiplier[1L] == 1,
    all(multiplier[blocks$layer_3] == 1))
  multiplier
}

ilr10_apply_multiplier <- function(X, multiplier) {
  stopifnot(is.matrix(X), ncol(X) == length(multiplier))
  sweep(X, 2L, multiplier, "*")
}

ilr10_design_hook <- function(e, cfg, source, last) {
  cx <- igc7_design_hook(e, cfg, source, last)
  multiplier <- ilr10_multiplier_vector(cx$object$reservoir$n,
    cfg$layer1_scale, cfg$layer2_scale)
  cx$object$X <- ilr10_apply_multiplier(cx$object$X, multiplier)
  cx$all_X <- ilr10_apply_multiplier(cx$all_X, multiplier)
  cx$readout_multiplier <- multiplier
  cx$design_hash <- digest::digest(list(X = cx$object$X,
    conditioning = cfg$readout_conditioning,
    readout_multiplier = multiplier), algo = "sha256")
  cx
}

ilr10_particle_paths <- function(e, object, y, local, H, draws, noise,
                                 conditioning, multiplier) {
  r <- object$reservoir
  meta <- object$meta
  spec <- meta$readout_spec
  count <- nrow(draws$beta)
  stopifnot(all(r$Q_is_identity), identical(r$act_f, "tanh"),
    identical(r$act_k, "identity"), isTRUE(meta$add_bias),
    !isTRUE(spec$include_input), length(spec$y_lags) == 0L,
    length(spec$x_names) == 0L, (spec$reservoir_lags %||% 0L) == 0L,
    !isTRUE(spec$linear_transform$active),
    ncol(draws$beta) == sum(r$n) + 1L,
    length(multiplier) == ncol(draws$beta))
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
    x <- ilr10_apply_multiplier(igc7_condition_apply(t(x), conditioning),
      multiplier)
    x <- t(x)
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

ilr10_qforecast_hook <- function(e, cx, cfg, fit, draws, progress = NULL) {
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
      path <- ilr10_particle_paths(e, object, cx$y, local, H, repeated,
        lapply(noise, function(z) z[, columns, drop = FALSE]),
        cx$conditioning, cx$readout_multiplier)
      means[, ids] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws,
        length(ids), cfg$inner, "mean")
      state_sum <- state_sum + path$state_sums
      zeros <- matrix(0, H, length(ids))
      plug[, ids] <- ilr10_particle_paths(e, object, cx$y, local, H, subset,
        list(s = zeros, v = zeros, z = zeros), cx$conditioning,
        cx$readout_multiplier)$mu_draws
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

ilr10_config <- function(state, stage, estimator, fold, layer1_scale,
                         layer2_scale, chain = 1L, warm_path = NULL) {
  stopifnot(stage %in% ilr10_stages, fold %in% names(itm6_folds),
    layer1_scale %in% ilr10_scale_grid, layer2_scale %in% ilr10_scale_grid)
  cfg <- ifu9_config(state, stage, estimator, fold,
    state$fixed_tau_multiplier, state$fixed_slab_multiplier, chain, warm_path)
  cfg$schema <- ilr10_schema
  cfg$layer1_scale <- as.numeric(layer1_scale)
  cfg$layer2_scale <- as.numeric(layer2_scale)
  cfg$layer3_scale <- 1
  cfg$scale_id <- substr(digest::digest(list(layer1_scale = layer1_scale,
    layer2_scale = layer2_scale), algo = "sha256"), 1L, 16L)
  cfg$candidate$parent_candidate_id <- cfg$candidate$id
  cfg$candidate$readout_scale_id <- cfg$scale_id
  cfg$candidate$id <- substr(digest::digest(list(
    parent_candidate_id = cfg$candidate$parent_candidate_id,
    readout_scale_id = cfg$scale_id), algo = "sha256"), 1L, 20L)
  cfg$id <- paste(cfg$id, paste0("L1x", ifu9_format_number(layer1_scale)),
    paste0("L2x", ifu9_format_number(layer2_scale)), sep = "__")
  cfg$seed <- itm6_seed(cfg$id)
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg
}

ilr10_plan <- function(state, configs, stage) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Frozen stage already exists: ", stage)
  rows <- lapply(configs, function(cfg) {
    iqt12_json(cfg, cfg$path)
    data.frame(id = cfg$id, stage = stage, cell = cfg$cell,
      estimator = cfg$estimator, engine = cfg$engine,
      fold = cfg$window$fold, chain = cfg$chain,
      candidate_id = cfg$candidate$id,
      structure_id = cfg$candidate$structure_id,
      scale_id = cfg$scale_id, layer1_scale = cfg$layer1_scale,
      layer2_scale = cfg$layer2_scale,
      tau_multiplier = cfg$tau_multiplier,
      slab_multiplier = cfg$slab_multiplier,
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

ilr10_materialize <- function(repo, run, library, parent = ilr10_parent_run) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(library),
    dir.exists(parent), file.exists(file.path(parent, "closeout.json")))
  iqt12_verify(file.path(parent, "closeout_manifest.csv"))
  closeout <- iqt12_read(file.path(parent, "closeout.json"))
  stopifnot(closeout$status == "COMPLETE_REVIEW_REQUIRED",
    closeout$scientific_decision ==
      "RHS_RESCUE_INSUFFICIENT_PREPARE_LOCAL_REPRESENTATION_FALLBACK",
    closeout$failures == 0L, closeout$active_jobs == 0L)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "references", "sources"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  parent_state <- iqt12_read(file.path(parent, "campaign.json"))
  reference <- parent_state$references[[ilr10_cell]]
  source <- read.csv(reference$source_path, stringsAsFactors = FALSE)
  stopifnot(max(source$t) == 9000L)
  source_path <- file.path(run, "sources", paste0(ilr10_cell, ".csv"))
  iqt12_csv(source, source_path)
  reference$source_path <- source_path
  reference$source_sha <- unname(tools::sha256sum(source_path))
  parent_plan <- read.csv(file.path(parent, "plans", "confirmation.csv"),
    stringsAsFactors = FALSE)
  parent_best <- read.csv(file.path(parent, "review",
    "confirmation_decision_table.csv"), stringsAsFactors = FALSE)[1L, ]
  parent_plan <- parent_plan[parent_plan$candidate_id == parent_best$prior_id,
    , drop = FALSE]
  stopifnot(nrow(parent_plan) == 6L,
    parent_best$tau_multiplier == 2,
    parent_best$slab_multiplier == 0.5)
  winner <- iqt12_read(parent_plan$config_path[1L])$candidate
  panel <- ilr10_maximin_panel()
  state <- list(schema = ilr10_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE),
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    parent_run = normalizePath(parent, mustWork = TRUE),
    max_workers = 30L, cell = ilr10_cell, winner = winner,
    base_slab_source = winner$slab_source,
    fixed_tau_multiplier = parent_best$tau_multiplier,
    fixed_slab_multiplier = parent_best$slab_multiplier,
    panel = split(panel, seq_len(nrow(panel))),
    references = setNames(list(reference), ilr10_cell),
    contract = list(
      target = "Gaussian-mixture_AL_p0.05_layerwise_readout_uncertainty",
      intervention = paste0("post-fold-zscore_block_multipliers_equivalent_",
        "to_relative_layer_specific_prior_scales"),
      fixed_structure = winner$structure_id,
      fixed_prior = "v9_tau2_slab0.5",
      unchanged_blocks = c("intercept", "layer_3"),
      targeted_blocks = c("layer_1", "layer_2"),
      selection_folds = c("S1", "S3"),
      confirmation_folds = c("S2", "S4"),
      article_holdout = "source_indices_9001_to_10000_never_opened",
      primary_estimator = "current_recursive_inner_average",
      teacher_forcing = "observations_assimilated_between_origins",
      within_origin = "recursive_30_step_forecast",
      closure = "strict_width_gain_with_mean_and_interval_score_guards",
      article_promotion = FALSE, fitted_model_binaries = "forbidden"))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(panel, file.path(run, "candidate_bank.csv"))
  for (file in c("dqlm_baseline_scores.csv", "v7_primary_comparison.csv"))
    stopifnot(file.copy(file.path(parent, "references", file),
      file.path(run, "references", file)))
  stopifnot(file.copy(file.path(parent, "review",
      "confirmation_decision_table.csv"), file.path(run, "references",
      "v9_confirmation_decision_table.csv")),
    file.copy(file.path(parent, "review", "beta_block_attribution_summary.csv"),
      file.path(run, "references", "v9_beta_block_attribution_summary.csv")),
    file.copy(file.path(parent, "closeout.json"), file.path(run,
      "references", "v9_closeout.json")))
  environment <- list(schema = ilr10_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    exdqlm_repository = utils::packageDescription("exdqlm", lib.loc = library)$Repository,
    package_path = find.package("exdqlm", lib.loc = library),
    R = R.version.string, session = capture.output(sessionInfo()),
    threads = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS",
      "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"))), source_head = state$head)
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
    "R/independent_qdesn_rhs_uncertainty_v9.R",
    "R/independent_qdesn_layerwise_readout_v10.R",
    "scripts/independent_qdesn_layerwise_readout_v10.R",
    "scripts/run_independent_qdesn_layerwise_readout_v10.sh",
    "docs/INDEPENDENT_QDESN_LAYERWISE_READOUT_V10_20261012.md"))
  iqt12_hash(source_files, file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(parent, c("closeout.json", "closeout_manifest.csv")),
    parent_plan$config_path, parent_plan$status_path),
    file.path(run, "input_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "package_hashes.csv",
    "input_hashes.csv")), source_path,
    list.files(file.path(run, "references"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  anchor <- panel[panel$role == "unmodified_v9_anchor", , drop = FALSE]
  stopifnot(nrow(anchor) == 1L)
  ilr10_plan(state, list(ilr10_config(state, "smoke", "quantile_mcmc",
    "S1", anchor$layer1_scale, anchor$layer2_scale)), "smoke")
  invisible(state)
}

ilr10_worker <- function(path) {
  cfg <- iqt12_read(path)
  if (exists(".ifu8_common_state", envir = .GlobalEnv, inherits = FALSE))
    rm(".ifu8_common_state", envir = .GlobalEnv)
  assign("iqt12_design_hook", ilr10_design_hook, envir = .GlobalEnv)
  assign("iqt12_qforecast_hook", ilr10_qforecast_hook, envir = .GlobalEnv)
  tryCatch({
    iqt12_worker(path)
    stopifnot(exists(".ifu8_common_state", envir = .GlobalEnv,
      inherits = FALSE))
    common <- get(".ifu8_common_state", envir = .GlobalEnv)
    source <- read.csv(cfg$source_path)
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source); full[source$t, ] <- source; source <- full
    current_raw <- read.csv(file.path(cfg$evidence,
      "forecast_location_draws.csv.gz"), check.names = FALSE)
    plugin_raw <- read.csv(file.path(cfg$evidence,
      "plugin_location_draws.csv.gz"), check.names = FALSE)
    ifu8_augment_evidence(cfg, source, common,
      as.matrix(current_raw[, -(1:3), drop = FALSE]),
      as.matrix(plugin_raw[, -(1:3), drop = FALSE]),
      list(stage = cfg$stage, tau_multiplier = cfg$tau_multiplier,
        slab_multiplier = cfg$slab_multiplier,
        layer1_scale = cfg$layer1_scale,
        layer2_scale = cfg$layer2_scale))
    diagnostics_path <- file.path(cfg$evidence, "diagnostics.json")
    diagnostics <- iqt12_read(diagnostics_path)
    diagnostics$layerwise_readout_v10 <- list(
      layer1_scale = cfg$layer1_scale, layer2_scale = cfg$layer2_scale,
      layer3_scale = 1, intercept_scale = 1,
      interpretation = paste0("post_zscore_feature_scale_g_implies_",
        "relative_original_coefficient_prior_scale_g"),
      prior_tau_multiplier = cfg$tau_multiplier,
      prior_slab_multiplier = cfg$slab_multiplier)
    iqt12_json(diagnostics, diagnostics_path)
    manifest_path <- file.path(cfg$evidence, "manifest.csv")
    if (file.exists(manifest_path)) unlink(manifest_path)
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      manifest_path)
    status <- iqt12_read(cfg$status_path)
    status$manifest <- manifest
    status$layerwise_readout_v10 <- "COMPLETE"
    iqt12_json(status, cfg$status_path)
    invisible(TRUE)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error)), cfg$status_path)
    stop(error)
  })
}

ilr10_health <- function(run) ifu9_health(run)

ilr10_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    status <- iqt12_read(plan$status_path[i]); stopifnot(status$status == "SUCCESS")
    iqt12_verify(status$manifest)
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence, "summary.csv"),
      stringsAsFactors = FALSE)
    value$scale_id <- cfg$scale_id
    value$layer1_scale <- cfg$layer1_scale
    value$layer2_scale <- cfg$layer2_scale
    value$config_path <- cfg$path
    value
  })
  do.call(rbind, rows)
}

ilr10_uncertainty_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence, "uncertainty_decomposition.csv"),
      stringsAsFactors = FALSE)
    value$id <- cfg$id; value$fold <- cfg$window$fold; value$chain <- cfg$chain
    value$scale_id <- cfg$scale_id
    value$layer1_scale <- cfg$layer1_scale
    value$layer2_scale <- cfg$layer2_scale
    value$config_path <- cfg$path
    value
  })
  do.call(rbind, rows)
}

ilr10_scale_rank <- function(run, results, uncertainty) {
  baseline <- read.csv(file.path(run, "references", "dqlm_baseline_scores.csv"),
    stringsAsFactors = FALSE)
  baseline <- baseline[baseline$source_stage == "mcmc" &
    baseline$fold %in% c("S1", "S3"), ]
  baseline_mae <- baseline[baseline$metric == "forecast_mae", ]
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  path <- uncertainty[uncertainty$estimator == "current_recursive" &
    uncertainty$metric == "forecast_mae", ]
  keys <- unique(mae[c("scale_id", "layer1_scale", "layer2_scale")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    m <- mae[mae$scale_id == key$scale_id, ]
    c <- check[check$scale_id == key$scale_id, ]
    u <- path[path$scale_id == key$scale_id, ]
    fold_means <- aggregate(mean ~ fold, m, mean)
    baseline_fold <- aggregate(mean ~ fold, baseline_mae, mean)
    names(baseline_fold)[2L] <- "baseline"
    fold_means <- merge(fold_means, baseline_fold, by = "fold")
    data.frame(key, forecast_mae = mean(m$mean),
      ratio_to_dqlm = mean(m$mean) / mean(baseline_mae$mean),
      worst_fold_ratio = max(fold_means$mean / fold_means$baseline),
      forecast_mae_width = mean(m$upper - m$lower),
      forecast_check_loss = mean(c$mean),
      interval_score = mean(u$mean_interval_score),
      pointwise_interval_width = mean(u$pointwise_interval_width),
      folds = length(unique(m$fold)), stringsAsFactors = FALSE)
  })
  rank <- do.call(rbind, rows)
  rank$eligible <- with(rank, ratio_to_dqlm <= 1.10 & worst_fold_ratio <= 1.20)
  eligible <- rank[rank$eligible, , drop = FALSE]
  if (!nrow(eligible)) {
    cutoff <- 1.10 * min(rank$forecast_mae)
    eligible <- rank[rank$forecast_mae <= cutoff, , drop = FALSE]
    rank$eligible <- rank$scale_id %in% eligible$scale_id
  }
  fields <- c("forecast_mae_width", "interval_score", "forecast_mae")
  scaled <- sapply(fields, function(field)
    eligible[[field]] / min(eligible[[field]]))
  eligible$composite <- scaled[, 1L] + .5 * scaled[, 2L] +
    .25 * scaled[, 3L]
  eligible <- eligible[order(eligible$composite, eligible$forecast_mae_width,
    eligible$forecast_mae), ]
  anchor <- rank[rank$layer1_scale == 1 & rank$layer2_scale == 1, , drop = FALSE]
  intervention <- eligible[eligible$scale_id != anchor$scale_id, , drop = FALSE]
  if (nrow(intervention) < 2L)
    intervention <- rank[rank$scale_id != anchor$scale_id,
      ][order(rank$forecast_mae_width[rank$scale_id != anchor$scale_id]), ]
  selected_columns <- c("scale_id", "layer1_scale", "layer2_scale")
  selected <- rbind(anchor[, selected_columns, drop = FALSE],
    head(intervention[, selected_columns, drop = FALSE], 2L))
  selected <- selected[!duplicated(selected$scale_id), , drop = FALSE]
  stopifnot(nrow(selected) == 3L)
  rank$selected <- rank$scale_id %in% selected$scale_id
  rank$selection_rule <- ifelse(rank$scale_id == anchor$scale_id,
    "mandatory_concurrent_anchor", ifelse(rank$selected,
      "top_width_first_guarded_intervention", "not_selected"))
  list(rank = rank[order(rank$forecast_mae_width, rank$interval_score,
    rank$forecast_mae), ], selected = selected)
}

ilr10_plan_warm <- function(state) {
  panel <- do.call(rbind, lapply(state$panel, as.data.frame))
  configs <- list()
  for (i in seq_len(nrow(panel))) for (fold in c("S1", "S3"))
    configs[[length(configs) + 1L]] <- ilr10_config(state, "warm",
      "quantile_vb", fold, panel$layer1_scale[i], panel$layer2_scale[i])
  ilr10_plan(state, configs, "warm")
}

ilr10_plan_discovery <- function(state, run) {
  warm <- read.csv(file.path(run, "plans", "warm.csv"), stringsAsFactors = FALSE)
  configs <- lapply(seq_len(nrow(warm)), function(i) ilr10_config(state,
    "discovery", "quantile_mcmc", warm$fold[i], warm$layer1_scale[i],
    warm$layer2_scale[i], 1L, file.path(run, "evidence", warm$id[i],
      "mcmc_initializer.json")))
  ilr10_plan(state, configs, "discovery")
}

ilr10_plan_confirm_warm <- function(state, run) {
  selection <- ilr10_scale_rank(run, ilr10_results(run, "discovery"),
    ilr10_uncertainty_results(run, "discovery"))
  iqt12_csv(selection$rank, file.path(run, "summaries",
    "discovery_scale_rank.csv"))
  iqt12_csv(selection$selected, file.path(run, "selections",
    "discovery_to_confirmation.csv"))
  configs <- list()
  for (i in seq_len(nrow(selection$selected))) for (fold in c("S2", "S4"))
    configs[[length(configs) + 1L]] <- ilr10_config(state, "confirm_warm",
      "quantile_vb", fold, selection$selected$layer1_scale[i],
      selection$selected$layer2_scale[i])
  ilr10_plan(state, configs, "confirm_warm")
}

ilr10_plan_confirmation <- function(state, run) {
  warm <- read.csv(file.path(run, "plans", "confirm_warm.csv"),
    stringsAsFactors = FALSE)
  configs <- list()
  for (i in seq_len(nrow(warm))) for (chain in 1:3)
    configs[[length(configs) + 1L]] <- ilr10_config(state, "confirmation",
      "quantile_mcmc", warm$fold[i], warm$layer1_scale[i],
      warm$layer2_scale[i], chain, file.path(run, "evidence", warm$id[i],
        "mcmc_initializer.json"))
  ilr10_plan(state, configs, "confirmation")
}

ilr10_confirmation_table <- function(run) {
  results <- ilr10_results(run, "confirmation")
  uncertainty <- ilr10_uncertainty_results(run, "confirmation")
  baseline <- read.csv(file.path(run, "references", "dqlm_baseline_scores.csv"),
    stringsAsFactors = FALSE)
  baseline <- baseline[baseline$source_stage == "mcmc", ]
  baseline_mae <- baseline[baseline$metric == "forecast_mae", ]
  parent <- read.csv(file.path(run, "references",
    "v9_confirmation_decision_table.csv"), stringsAsFactors = FALSE)[1L, ]
  keys <- unique(results[c("scale_id", "layer1_scale", "layer2_scale")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    take <- results$scale_id == key$scale_id
    mae <- results[take & results$metric == "forecast_mae", ]
    check <- results[take & results$metric == "forecast_check_loss", ]
    path <- uncertainty[uncertainty$scale_id == key$scale_id &
      uncertainty$estimator == "current_recursive" &
      uncertainty$metric == "forecast_mae", ]
    fold_means <- aggregate(mean ~ fold, mae, mean)
    baseline_fold <- aggregate(mean ~ fold, baseline_mae, mean)
    names(baseline_fold)[2L] <- "baseline"
    fold_means <- merge(fold_means, baseline_fold, by = "fold")
    width <- mean(mae$upper - mae$lower)
    denominator <- parent$v7_forecast_mae_width -
      mean(baseline_mae$upper - baseline_mae$lower)
    data.frame(key, qdesn_forecast_mae = mean(mae$mean),
      dqlm_forecast_mae = mean(baseline_mae$mean),
      ratio_to_dqlm = mean(mae$mean) / mean(baseline_mae$mean),
      worst_fold_ratio = max(fold_means$mean / fold_means$baseline),
      forecast_mae_width = width,
      dqlm_forecast_mae_width = mean(baseline_mae$upper - baseline_mae$lower),
      v9_forecast_mae = parent$qdesn_forecast_mae,
      v9_forecast_mae_width = parent$forecast_mae_width,
      v7_forecast_mae_width = parent$v7_forecast_mae_width,
      excess_width_gap_closed = if (denominator > 0)
        (parent$v7_forecast_mae_width - width) / denominator else NA_real_,
      forecast_check_loss = mean(check$mean),
      v9_forecast_check_loss = parent$forecast_check_loss,
      interval_score = mean(path$mean_interval_score),
      v9_interval_score = parent$interval_score,
      chains = nrow(mae), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  anchor <- out[out$layer1_scale == 1 & out$layer2_scale == 1, , drop = FALSE]
  stopifnot(nrow(anchor) == 1L)
  out$concurrent_anchor_width <- anchor$forecast_mae_width
  out$width_reduction_vs_v9 <- 1 - out$forecast_mae_width /
    out$v9_forecast_mae_width
  out$width_reduction_vs_anchor <- 1 - out$forecast_mae_width /
    out$concurrent_anchor_width
  out$strict_metric_gain <- with(out, ratio_to_dqlm <= 1.05 &
    worst_fold_ratio <= 1.20 &
    qdesn_forecast_mae <= 1.02 * v9_forecast_mae &
    forecast_mae_width < v9_forecast_mae_width &
    forecast_mae_width < concurrent_anchor_width &
    forecast_check_loss <= 1.02 * v9_forecast_check_loss &
    interval_score <= 1.02 * v9_interval_score)
  out$meaningful_contraction <- out$strict_metric_gain &
    out$width_reduction_vs_v9 >= 0.10
  out$full_closure <- out$strict_metric_gain &
    out$excess_width_gap_closed >= 0.50
  out[order(!out$full_closure, !out$meaningful_contraction,
    !out$strict_metric_gain, out$forecast_mae_width, out$ratio_to_dqlm), ]
}

ilr10_closeout <- function(run) {
  health <- ilr10_health(run)
  stopifnot(all(health$complete == health$planned), all(health$failed == 0L),
    all(health$running == 0L), all(health$pending == 0L))
  comparison <- ilr10_confirmation_table(run)
  iqt12_csv(comparison, file.path(run, "review",
    "confirmation_decision_table.csv"))
  decision <- if (any(comparison$full_closure))
    "LAYERWISE_WIDTH_RESCUE_CONFIRMED_PREPARE_CELLWISE_PROPAGATION" else
    if (any(comparison$meaningful_contraction))
      "MEANINGFUL_LAYERWISE_CONTRACTION_RETAIN_FOR_FRESH_DGP" else
      if (any(comparison$strict_metric_gain))
        "SMALL_LAYERWISE_GAIN_RETAIN_BUT_STOP_TARGETED_RESCUE" else
        "NO_LAYERWISE_GAIN_STOP_TARGETED_RESCUE"
  closeout <- list(schema = ilr10_schema, status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE,
    selection_used_article_holdout = FALSE, jobs = sum(health$planned),
    failures = sum(health$failed), best = as.list(comparison[1L, ]),
    active_jobs = 0L, fitted_binary_payloads = 0L,
    completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  iqt12_json(closeout, file.path(run, "closeout.json"))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "package_hashes.csv",
    "input_hashes.csv", "frozen_hashes.csv", "closeout.json")),
    list.files(file.path(run, "references"), full.names = TRUE),
    list.files(file.path(run, "summaries"), full.names = TRUE),
    list.files(file.path(run, "selections"), full.names = TRUE),
    list.files(file.path(run, "review"), full.names = TRUE),
    list.files(file.path(run, "plans"), full.names = TRUE))
  iqt12_hash(files[file.exists(files)], file.path(run, "closeout_manifest.csv"))
  invisible(closeout)
}

ilr10_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  if (finished == "smoke") return(ilr10_plan_warm(state))
  if (finished == "warm") return(ilr10_plan_discovery(state, run))
  if (finished == "discovery") return(ilr10_plan_confirm_warm(state, run))
  if (finished == "confirm_warm") return(ilr10_plan_confirmation(state, run))
  if (finished == "confirmation") return(ilr10_closeout(run))
  stop("Unknown completed stage: ", finished)
}

ilr10_resources <- itm6_resources
