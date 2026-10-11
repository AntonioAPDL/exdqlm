igc7_schema <- "independent_qdesn_gausmix_conditioning_v7"
igc7_cell <- "gausmix__al__p005"
igc7_stages <- c("smoke", "representation", "quantile", "validation", "mcmc")
igc7_folds <- itm6_folds
igc7_N <- 2000L
igc7_tau_multipliers <- c(0.5, 1, 2, 3)
igc7_conditioning_modes <- c("none", "fold_zscore")
igc7_parent_run <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_training_size_mechanism_v6_20261009/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_training_size_mechanism_v6_20261010_042600__git-c4feb0fb")

igc7_halton <- function(index, base) {
  stopifnot(index >= 1L, base >= 2L)
  value <- 0
  factor <- 1 / base
  while (index > 0L) {
    value <- value + factor * (index %% base)
    index <- index %/% base
    factor <- factor / base
  }
  value
}

igc7_allocate_states <- function(total, D, shape) {
  stopifnot(total >= 20L * D, D >= 1L)
  weights <- switch(shape,
    equal = rep(1, D),
    front_loaded = rev(seq_len(D)),
    back_loaded = seq_len(D),
    mild_front = rev(seq_len(D))^0.5,
    stop("Unknown layer shape: ", shape))
  extra <- total - 20L * D
  raw <- extra * weights / sum(weights)
  add <- floor(raw)
  remainder <- extra - sum(add)
  if (remainder > 0L) {
    order_fraction <- order(raw - add, decreasing = TRUE)
    add[order_fraction[seq_len(remainder)]] <-
      add[order_fraction[seq_len(remainder)]] + 1L
  }
  as.integer(20L + add)
}

igc7_new_candidate <- function(reference, index) {
  primes <- c(2L, 3L, 5L, 7L, 11L, 13L, 17L, 19L, 23L, 29L)
  u <- vapply(primes, function(base) igc7_halton(index + 17L, base), 0)
  D <- 3L + min(3L, floor(4 * u[1L]))
  total <- as.integer(round((250 + 350 * u[2L]) / 10) * 10)
  shape_names <- c("equal", "front_loaded", "back_loaded", "mild_front")
  shape <- shape_names[1L + min(3L, floor(4 * u[3L]))]
  n <- igc7_allocate_states(total, D, shape)
  m <- as.integer(round((240 + 260 * u[4L]) / 20) * 20)
  alpha <- exp(log(0.04) + u[5L] * log(0.60 / 0.04))
  spectral_gap <- exp(log(0.03) + u[6L] * log(0.0005 / 0.03))
  rho <- 1 - spectral_gap
  input_gain <- exp(log(0.08) + u[7L] * log(1.6 / 0.08))
  recurrent <- c(10L, 20L, 30L, 40L, 60L)[1L + min(4L, floor(5 * u[8L]))]
  interlayer <- c(5L, 10L, 20L, 40L, 60L)[1L + min(4L, floor(5 * u[9L]))]
  candidate <- reference$candidate
  candidate$n <- paste(n, collapse = ";")
  candidate$m <- m
  candidate$alpha <- alpha
  candidate$rho <- rho
  candidate$input_gain <- input_gain
  candidate$input_fanin <- max(1L, round((m + 1L) * (0.05 + 0.25 * u[10L])))
  candidate$recurrent_indegree <- min(recurrent, min(n))
  candidate$interlayer_fanin <- min(interlayer, min(n))
  candidate$center_scale <- if (u[3L] < 0.5) "mean_sd" else "median_mad"
  candidate$input_bound <- "tanh_z_over_3"
  candidate$effective_p0 <- as.integer(round(8 + 32 * u[10L]))
  candidate$layer_shape <- shape
  itm6_candidate(candidate, reference,
    sprintf("halton_intermediate_%02d_%s", index, shape))
}

igc7_historical_structures <- function(repo, parent_bank) {
  rows <- list(data.frame(structure_id = unique(parent_bank$structure_id),
    source = "v6_parent_candidate_bank", stringsAsFactors = FALSE))
  files <- list.files(file.path(repo, "validation/fitforecast_v2/promotions"),
    pattern = "[.]csv$", recursive = TRUE, full.names = TRUE)
  for (path in files) {
    value <- tryCatch(read.csv(path, stringsAsFactors = FALSE),
      error = function(error) NULL)
    if (is.null(value) || !"structure_id" %in% names(value)) next
    ids <- unique(as.character(value$structure_id))
    ids <- ids[!is.na(ids) & nzchar(ids)]
    if (!length(ids)) next
    rows[[length(rows) + 1L]] <- data.frame(structure_id = ids,
      source = sub(paste0("^", repo, "/?"), "", path),
      stringsAsFactors = FALSE)
  }
  history <- unique(do.call(rbind, rows))
  history[order(history$structure_id, history$source), , drop = FALSE]
}

igc7_candidate_panel <- function(reference, parent_bank, historical_ids) {
  anchors <- c("c94ca9d5a842257f", "7cb0a147f6527379",
    "66ab15c29415d6e0", "de5e216a86e81e6a")
  historical <- lapply(anchors, function(structure_id) {
    row <- parent_bank[parent_bank$cell == igc7_cell &
      parent_bank$structure_id == structure_id, , drop = FALSE]
    stopifnot(nrow(row) == 1L)
    candidate <- as.list(row[1L, ])
    candidate$layer_shape <- "historical"
    itm6_candidate(candidate, reference, paste0("v6_anchor_", structure_id))
  })
  candidates <- historical
  known <- unique(historical_ids)
  index <- 1L
  while (length(candidates) < 48L) {
    candidate <- igc7_new_candidate(reference, index)
    index <- index + 1L
    ids <- vapply(candidates, `[[`, "", "structure_id")
    if (candidate$structure_id %in% c(known, ids)) next
    candidates[[length(candidates) + 1L]] <- candidate
  }
  stopifnot(length(candidates) == 48L,
    !anyDuplicated(vapply(candidates, `[[`, "", "structure_id")),
    all(vapply(candidates, function(x) x$D >= 2L && x$D <= 6L, TRUE)),
    all(vapply(candidates, function(x) x$total_states <= 600L, TRUE)),
    all(vapply(candidates, function(x) x$m <= 500L, TRUE)))
  candidates
}

igc7_candidate_frame <- function(panel) {
  rows <- lapply(panel, function(candidate) data.frame(
    cell = igc7_cell, candidate_id = candidate$id,
    structure_id = candidate$structure_id, role = candidate$role,
    n = candidate$n, D = candidate$D, total_states = candidate$total_states,
    m = candidate$m, alpha = candidate$alpha, rho = candidate$rho,
    input_gain = candidate$input_gain, input_fanin = candidate$input_fanin,
    recurrent_indegree = candidate$recurrent_indegree,
    interlayer_fanin = candidate$interlayer_fanin,
    center_scale = candidate$center_scale, input_bound = candidate$input_bound,
    effective_p0 = candidate$effective_p0,
    layer_shape = candidate$layer_shape %||% "historical",
    readout_dimension = candidate$readout_dimension,
    exact_identity_Q = TRUE, matrix_seed = candidate$matrix_seed,
    stringsAsFactors = FALSE))
  do.call(rbind, rows)
}

igc7_condition_fit <- function(X, mode) {
  stopifnot(is.matrix(X), ncol(X) >= 2L, mode %in% igc7_conditioning_modes)
  idx <- seq.int(2L, ncol(X))
  center <- colMeans(X[, idx, drop = FALSE])
  scale <- apply(X[, idx, drop = FALSE], 2L, stats::sd)
  scale[!is.finite(scale) | scale < 1e-8] <- 1
  out <- X
  if (mode == "fold_zscore") {
    out[, idx] <- sweep(sweep(out[, idx, drop = FALSE], 2L, center, "-"),
      2L, scale, "/")
  } else {
    center[] <- 0
    scale[] <- 1
  }
  list(X = out, mode = mode, idx = idx, center = as.numeric(center),
    scale = as.numeric(scale), fit_rows = nrow(X))
}

igc7_condition_apply <- function(X, info) {
  stopifnot(is.matrix(X), ncol(X) == length(info$scale) + 1L)
  if (info$mode == "none") return(X)
  X[, info$idx] <- sweep(sweep(X[, info$idx, drop = FALSE], 2L,
    info$center, "-"), 2L, info$scale, "/")
  X
}

igc7_condition_number <- function(X) {
  value <- tryCatch(kappa(X, exact = FALSE), error = function(error) Inf)
  if (!is.finite(value)) .Machine$double.xmax else as.numeric(value)
}

igc7_design_hook <- function(e, cfg, source, last) {
  cx <- ism1_design(e, cfg, source, last)
  raw_X <- cx$object$X
  fit <- igc7_condition_fit(raw_X, cfg$readout_conditioning)
  raw_kappa <- igc7_condition_number(raw_X)
  conditioned_kappa <- igc7_condition_number(fit$X)
  conditioned_X <- fit$X
  fit$X <- NULL
  cx$object$X <- conditioned_X
  cx$all_X <- igc7_condition_apply(cx$all_X, fit)
  cx$conditioning <- c(fit, list(raw_condition_kappa = raw_kappa,
    conditioned_condition_kappa = conditioned_kappa,
    condition_gain_ratio = raw_kappa / max(conditioned_kappa, 1)))
  cx$design_hash <- digest::digest(list(X = cx$object$X,
    mode = cfg$readout_conditioning), algo = "sha256")
  cx
}

igc7_particle_paths <- function(e, object, y, local, H, draws, noise,
                                conditioning) {
  r <- object$reservoir
  meta <- object$meta
  spec <- meta$readout_spec
  count <- nrow(draws$beta)
  stopifnot(all(r$Q_is_identity), identical(r$act_f, "tanh"),
    identical(r$act_k, "identity"), isTRUE(meta$add_bias),
    !isTRUE(spec$include_input), length(spec$y_lags) == 0L,
    length(spec$x_names) == 0L, (spec$reservoir_lags %||% 0L) == 0L,
    !isTRUE(spec$linear_transform$active), ncol(draws$beta) == sum(r$n) + 1L)
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
    mu[lead, ] <- colSums(x * beta)
    yrep[lead, ] <- mu[lead, ] + lambda * draws$sigma * noise$s[lead, ] +
      A * noise$v[lead, ] +
      sqrt(B * draws$sigma * noise$v[lead, ]) * noise$z[lead, ]
    lags <- rbind(yrep[lead, ], head(lags, -1L))
  }
  stopifnot(all(is.finite(mu)), all(is.finite(yrep)))
  list(mu_draws = mu, yrep = yrep)
}

igc7_qforecast_hook <- function(e, cx, cfg, fit, draws, progress = NULL) {
  object <- cx$object
  object$fit <- fit
  w <- cfg$window
  out <- plugin <- list()
  guards <- list()
  for (i in seq_along(w$origins)) {
    origin <- w$origins[i]
    local <- origin - cx$first + 1L
    H <- min(w$horizon, w$end - origin)
    bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L,
      if (cfg$inner >= 128L) 256L else cfg$inner, cfg$seed + origin)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1L]]
    outer <- nrow(draws$beta)
    means <- plug <- matrix(0, H, outer)
    batches <- split(seq_len(outer),
      ceiling(seq_len(outer) / max(1L, 256L %/% cfg$inner)))
    for (ids in batches) {
      subset <- e$iqcf_v3_subset_draws(draws, ids)
      repeated <- e$iqcf_v3_repeat_draws(subset, cfg$inner)
      columns <- unlist(lapply(ids,
        function(j) (j - 1L) * cfg$inner + seq_len(cfg$inner)))
      path <- igc7_particle_paths(e, object, cx$y, local, H, repeated,
        lapply(noise, function(z) z[, columns, drop = FALSE]), cx$conditioning)
      means[, ids] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws,
        length(ids), cfg$inner, "mean")
      zeros <- matrix(0, H, length(ids))
      plug[, ids] <- igc7_particle_paths(e, object, cx$y, local, H, subset,
        list(s = zeros, v = zeros, z = zeros), cx$conditioning)$mu_draws
    }
    expected <- cx$all_X[local + 1L, , drop = FALSE] %*%
      t(draws$beta) * cx$scale
    actual <- means[1L, , drop = FALSE] * cx$scale
    error <- max(abs(expected - actual))
    tolerance <- 1e-6 * max(1, max(abs(expected)))
    guards[[i]] <- data.frame(origin = origin,
      feature_max_absolute_error = 0,
      feature_max_relative_error = 0,
      prediction_max_absolute_error = error,
      prediction_max_relative_error = error / max(1, max(abs(expected))),
      pass = error <= tolerance)
    stopifnot(guards[[i]]$pass)
    out[[i]] <- means * cx$scale
    plugin[[i]] <- plug * cx$scale
    if (!is.null(progress)) progress(i, length(w$origins))
  }
  list(primary = do.call(rbind, out), plugin = do.call(rbind, plugin),
    first_step_guard = do.call(rbind, guards))
}

igc7_config <- function(state, candidate, stage, estimator, fold,
                        chain = 1L, tau_multiplier = 1,
                        conditioning = "none") {
  stopifnot(stage %in% igc7_stages,
    conditioning %in% igc7_conditioning_modes)
  cfg <- itm6_config(state, igc7_cell, candidate, stage, estimator,
    igc7_N, fold, chain, tau_multiplier = tau_multiplier)
  cfg$schema <- igc7_schema
  cfg$readout_conditioning <- conditioning
  cfg$id <- paste(cfg$id, paste0("condition-", conditioning), sep = "__")
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg
}

igc7_plan <- function(state, configs, stage) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Frozen stage already exists: ", stage)
  rows <- lapply(configs, function(cfg) {
    iqt12_json(cfg, cfg$path)
    data.frame(id = cfg$id, stage = stage, cell = cfg$cell,
      estimator = cfg$estimator, engine = cfg$engine, N = cfg$window$N,
      fold = cfg$window$fold, chain = cfg$chain,
      candidate_id = cfg$candidate$id,
      structure_id = cfg$candidate$structure_id,
      tau_multiplier = cfg$tau_multiplier,
      readout_conditioning = cfg$readout_conditioning,
      config_path = cfg$path,
      config_sha = unname(tools::sha256sum(cfg$path)),
      status_path = cfg$status_path, timeout = cfg$timeout,
      stringsAsFactors = FALSE)
  })
  plan <- if (length(rows)) do.call(rbind, rows) else data.frame(
    id = character(), stage = character(), cell = character(),
    estimator = character(), engine = character(), N = integer(),
    fold = character(), chain = integer(), candidate_id = character(),
    structure_id = character(), tau_multiplier = numeric(),
    readout_conditioning = character(), config_path = character(),
    config_sha = character(), status_path = character(), timeout = integer())
  stopifnot(!anyDuplicated(plan$id))
  iqt12_csv(plan, path)
  iqt12_hash(c(path, plan$config_path), file.path(state$run, "plans",
    paste0(stage, "_hashes.csv")))
  plan
}

igc7_copy_parent_reference <- function(parent, run) {
  plans <- lapply(c("validation", "mcmc"), function(stage)
    read.csv(file.path(parent, "plans", paste0(stage, ".csv")),
      stringsAsFactors = FALSE))
  names(plans) <- c("validation", "mcmc")
  rows <- list()
  for (stage in names(plans)) {
    plan <- plans[[stage]]
    take <- plan$cell == igc7_cell & plan$model == "baseline" & plan$N == igc7_N
    if (stage == "validation") take <- take & plan$fold %in% names(igc7_folds)
    if (stage == "mcmc") take <- take & plan$fold %in% c("S2", "S4")
    selected <- plan[take, , drop = FALSE]
    for (i in seq_len(nrow(selected))) {
      status <- iqt12_read(selected$status_path[i])
      stopifnot(status$status == "SUCCESS")
      iqt12_verify(status$manifest)
      value <- read.csv(file.path(parent, "evidence", selected$id[i],
        "summary.csv"), stringsAsFactors = FALSE)
      value$source_stage <- stage
      rows[[length(rows) + 1L]] <- value
    }
  }
  baseline <- do.call(rbind, rows)
  iqt12_csv(baseline, file.path(run, "references", "v6_baseline_scores.csv"))
  parent_mcmc <- read.csv(file.path(parent, "summaries", "mcmc.csv"),
    stringsAsFactors = FALSE)
  parent_mcmc <- parent_mcmc[parent_mcmc$cell == igc7_cell, , drop = FALSE]
  iqt12_csv(parent_mcmc,
    file.path(run, "references", "v6_gausmix_mcmc_authority.csv"))
  invisible(baseline)
}

igc7_materialize <- function(repo, run, library, parent = igc7_parent_run) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(library),
    dir.exists(parent))
  iqt12_verify(file.path(parent, "closeout_manifest.csv"))
  parent_state <- iqt12_read(file.path(parent, "campaign.json"))
  stopifnot(parent_state$head ==
      "c4feb0fb72399cb3636dd9815b1a5607675a8e6f",
    parent_state$references[[igc7_cell]]$likelihood == "al")
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "references", "sources"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  reference <- parent_state$references[[igc7_cell]]
  stopifnot(file.exists(reference$source_path),
    unname(tools::sha256sum(reference$source_path)) == reference$source_sha)
  source <- read.csv(reference$source_path)
  stopifnot(max(source$t) == 9000L)
  source_path <- file.path(run, "sources", paste0(igc7_cell, ".csv"))
  iqt12_csv(source, source_path)
  reference$source_path <- source_path
  reference$source_sha <- unname(tools::sha256sum(source_path))
  parent_bank <- read.csv(file.path(parent, "candidate_bank.csv"),
    stringsAsFactors = FALSE)
  history <- igc7_historical_structures(repo, parent_bank)
  panel <- igc7_candidate_panel(reference, parent_bank,
    history$structure_id)
  anchors <- startsWith(vapply(panel, `[[`, "", "role"), "v6_anchor_")
  stopifnot(sum(anchors) == 4L,
    !any(vapply(panel[!anchors], `[[`, "", "structure_id") %in%
      history$structure_id))
  state <- list(schema = igc7_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE),
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    shared_base = "5b85bb3a3894a88968e4987f330e3ec66711f9c7",
    scientific_parent = "c4feb0fb72399cb3636dd9815b1a5607675a8e6f",
    parent_run = normalizePath(parent, mustWork = TRUE),
    max_workers = 30L, cells = igc7_cell, training_size = igc7_N,
    folds = as.list(igc7_folds), tau_multipliers = igc7_tau_multipliers,
    conditioning_modes = igc7_conditioning_modes,
    references = setNames(list(reference), igc7_cell),
    panels = setNames(list(panel), igc7_cell),
    contract = list(
      target = "Gaussian-mixture_AL_p0.05_only",
      selection_data = "source_indices_1_to_8240_only_for_discovery_then_1_to_8740_for_validation",
      article_holdout = "source_indices_9001_to_10000_never_opened",
      readout = "intercept_plus_all_identity_Q_reservoir_layers",
      conditioning = "training_fold_only_column_centering_and_scaling_nonintercept_states",
      teacher_forcing = "observations_assimilated_when_origin_moves",
      within_origin = "recursive_30_step_forecast",
      primary_selection = "internal_rolling_origin_forecast_MAE",
      secondary_selection = "forecast_check_loss_then_complexity",
      comparator = "hash_verified_frozen_v6_DQLM_AL",
      article_promotion = FALSE,
      full_18_cell_confirmation = "not_part_of_this_campaign"))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(igc7_candidate_frame(panel), file.path(run, "candidate_bank.csv"))
  iqt12_csv(history, file.path(run, "historical_structure_ledger.csv"))
  igc7_copy_parent_reference(parent, run)
  environment <- list(schema = igc7_schema,
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
  source_files <- c(file.path(repo, "validation/fitforecast_v2/R", c(
    "independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R",
    "independent_qdesn_gausmix_conditioning_v7.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_gausmix_conditioning_v7.R",
      "run_independent_qdesn_gausmix_conditioning_v7.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_GAUSMIX_CONDITIONING_V7_20261011.md"))
  iqt12_hash(source_files, file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "historical_structure_ledger.csv",
    "source_hashes.csv", "package_hashes.csv")),
    source_path, file.path(run, "references", c("v6_baseline_scores.csv",
      "v6_gausmix_mcmc_authority.csv"))), file.path(run, "frozen_hashes.csv"))
  anchor <- panel[[1L]]
  smoke <- lapply(igc7_conditioning_modes, function(mode)
    igc7_config(state, anchor, "smoke", "quantile_vb", "S1",
      tau_multiplier = 1, conditioning = mode))
  igc7_plan(state, smoke, "smoke")
  invisible(state)
}

igc7_representation_worker <- function(cfg) {
  started <- proc.time()[["elapsed"]]
  e <- ism1_runtime(cfg$repo, cfg$library)
  for (name in c("source_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", "representation_hashes.csv"))
  stopifnot(!file.exists(cfg$status_path))
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
    raw_kappa <- igc7_condition_number(cx$object$X)
    conditioned <- igc7_condition_fit(cx$object$X, "fold_zscore")
    conditioned_kappa <- igc7_condition_number(conditioned$X)
    grid <- iqt12_grid(cfg$window)
    summaries <- profiles <- draws_out <- list()
    diagnostics <- list()
    for (estimator in c("oracle_ridge", "gaussian_ridge")) {
      target <- if (estimator == "oracle_ridge")
        source$q_target[cfg$window$train] / cx$scale else
        source$y[cfg$window$train] / cx$scale
      fit <- itm6_ridge_fit(cx$object$X, target, lambda = 1)
      if (estimator == "oracle_ridge") {
        fit_draws <- matrix(fit$fitted * cx$scale, ncol = 1L)
        forecast <- itm6_deterministic_forecast(cx, cfg, fit$beta, oracle = TRUE)
      } else {
        fit_draws <- matrix((fit$fitted + qnorm(cfg$p) * fit$sigma) *
          cx$scale, ncol = 1L)
        forecast <- itm6_deterministic_forecast(cx, cfg, fit$beta,
          fit$sigma, oracle = FALSE)
      }
      score <- iqt12_scores(fit_draws, forecast, source, cfg$window, cfg$p)
      teacher <- as.numeric(cx$all_X[grid$target - cx$first + 1L, , drop = FALSE] %*%
        fit$beta) * cx$scale
      if (estimator == "gaussian_ridge")
        teacher <- teacher + qnorm(cfg$p) * fit$sigma * cx$scale
      teacher_mae <- mean(abs(teacher - source$q_target[grid$target]))
      amplitude <- stats::sd(forecast[, 1L]) /
        max(stats::sd(source$q_target[grid$target]), 1e-12)
      extra <- data.frame(metric = c("teacher_forced_mae",
        "recursive_to_teacher_ratio", "forecast_amplitude_ratio"),
        mean = c(teacher_mae,
          score$summary$mean[score$summary$metric == "forecast_mae"] /
            max(teacher_mae, 1e-12), amplitude),
        lower = NA_real_, upper = NA_real_)
      summaries[[estimator]] <- rbind(score$summary, extra)
      profiles[[estimator]] <- transform(score$profile,
        estimator = estimator, teacher_forced_q = teacher)
      draws_out[[estimator]] <- transform(score$draws, estimator = estimator)
      diagnostics[[estimator]] <- fit[c("lambda", "validation_mae",
        "cg_iterations", "cg_relative_residual")]
    }
    rows <- lapply(names(summaries), function(estimator) {
      add <- data.frame(id = cfg$id, cell = cfg$cell,
        candidate_id = cfg$candidate$id, model = cfg$model,
        estimator = estimator, engine = estimator, family = cfg$family,
        p = cfg$p, N = cfg$window$N, fold = cfg$window$fold,
        chain = cfg$chain, normal_observed_mae = NA_real_)
      cbind(add[rep(1L, nrow(summaries[[estimator]])), ],
        summaries[[estimator]])
    })
    iqt12_csv(do.call(rbind, rows), file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(do.call(rbind, draws_out),
      file.path(cfg$evidence, "metric_draws.csv.gz"))
    iqt12_csv(do.call(rbind, profiles),
      file.path(cfg$evidence, "origin_lead.csv.gz"))
    diag <- list(estimator = cfg$estimator, ridge = diagnostics,
      raw_condition_kappa = raw_kappa,
      conditioned_condition_kappa = conditioned_kappa,
      condition_gain_ratio = raw_kappa / max(conditioned_kappa, 1),
      state_saturation_fraction = mean(abs(cx$object$X[, -1, drop = FALSE]) > .99),
      initialization_dependence = cx$initialization_dependence,
      exact_identity_Q = all(cx$object$reservoir$Q_is_identity),
      total_states = cfg$candidate$total_states,
      elapsed = proc.time()[["elapsed"]] - started,
      fitted_binary_payloads = 0L)
    iqt12_json(diag, file.path(cfg$evidence, "diagnostics.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = diag$elapsed, fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
      cfg$status_path)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error),
      elapsed = proc.time()[["elapsed"]] - started), cfg$status_path)
    stop(error)
  })
}

igc7_worker <- function(path) {
  cfg <- iqt12_read(path)
  if (cfg$stage == "representation") return(igc7_representation_worker(cfg))
  assign("iqt12_design_hook", igc7_design_hook, envir = .GlobalEnv)
  assign("iqt12_qforecast_hook", igc7_qforecast_hook, envir = .GlobalEnv)
  iqt12_worker(path)
}

igc7_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  if (!nrow(plan)) return(data.frame())
  rows <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    status <- iqt12_read(plan$status_path[i])
    stopifnot(status$status == "SUCCESS")
    iqt12_verify(status$manifest)
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence, "summary.csv"),
      stringsAsFactors = FALSE)
    value$structure_id <- cfg$candidate$structure_id
    value$total_states <- cfg$candidate$total_states
    value$output_lags <- cfg$candidate$m
    value$tau_multiplier <- cfg$tau_multiplier
    value$readout_conditioning <- cfg$readout_conditioning
    value$config_path <- cfg$path
    rows[[i]] <- value
  }
  do.call(rbind, rows)
}

igc7_plan_representation <- function(state) {
  configs <- list()
  for (candidate in state$panels[[igc7_cell]]) for (fold in c("S1", "S3"))
    configs[[length(configs) + 1L]] <- igc7_config(state, candidate,
      "representation", "mechanism_bundle", fold)
  igc7_plan(state, configs, "representation")
}

igc7_representation_rank <- function(run, results) {
  keys <- unique(results[c("structure_id")])
  rows <- lapply(keys$structure_id, function(structure_id) {
    z <- results[results$structure_id == structure_id, ]
    get <- function(estimator, metric) {
      x <- z$mean[z$estimator == estimator & z$metric == metric]
      if (!length(x)) NA_real_ else median(x)
    }
    diagnostics <- lapply(unique(z$config_path), function(path) {
      cfg <- iqt12_read(path)
      iqt12_read(file.path(cfg$evidence, "diagnostics.json"))
    })
    data.frame(structure_id = structure_id,
      total_states = median(z$total_states),
      output_lags = median(z$output_lags),
      oracle_teacher_mae = get("oracle_ridge", "teacher_forced_mae"),
      oracle_recursive_mae = get("oracle_ridge", "forecast_mae"),
      gaussian_recursive_mae = get("gaussian_ridge", "forecast_mae"),
      gaussian_amplitude_ratio = get("gaussian_ridge", "forecast_amplitude_ratio"),
      raw_condition_kappa = median(vapply(diagnostics, `[[`, 0,
        "raw_condition_kappa")),
      conditioned_condition_kappa = median(vapply(diagnostics, `[[`, 0,
        "conditioned_condition_kappa")), stringsAsFactors = FALSE)
  })
  rank <- do.call(rbind, rows)
  rank$stable <- with(rank, is.finite(oracle_teacher_mae) &
    is.finite(oracle_recursive_mae) & is.finite(gaussian_recursive_mae) &
    oracle_recursive_mae <= 8 & gaussian_recursive_mae <= 12 &
    gaussian_amplitude_ratio >= 0.05 & gaussian_amplitude_ratio <= 5)
  stable <- rank[rank$stable, , drop = FALSE]
  if (nrow(stable) < 12L)
    stop("Fewer than 12 candidates passed the predeclared stability screen.")
  columns <- c("oracle_teacher_mae", "oracle_recursive_mae",
    "gaussian_recursive_mae")
  relative <- sapply(columns, function(column)
    stable[[column]] / min(stable[[column]]))
  stable$composite <- rowMeans(log(pmax(relative, 1e-12)))
  selected_ids <- unique(c(
    stable$structure_id[order(stable$composite, stable$total_states,
      stable$output_lags)],
    stable$structure_id[order(stable$oracle_recursive_mae,
      stable$total_states, stable$output_lags)],
    stable$structure_id[order(stable$gaussian_recursive_mae,
      stable$total_states, stable$output_lags)]))
  selected_ids <- head(selected_ids, 12L)
  rank$composite <- NA_real_
  rank$composite[match(stable$structure_id, rank$structure_id)] <- stable$composite
  selected <- rank[match(selected_ids, rank$structure_id), ]
  iqt12_csv(rank, file.path(run, "summaries", "representation_rank.csv"))
  iqt12_csv(selected, file.path(run, "selections",
    "representation_to_quantile.csv"))
  selected
}

igc7_plan_quantile <- function(state, run) {
  selected <- igc7_representation_rank(run,
    igc7_results(run, "representation"))
  configs <- list()
  for (structure_id in selected$structure_id) {
    index <- match(structure_id,
      vapply(state$panels[[igc7_cell]], `[[`, "", "structure_id"))
    candidate <- state$panels[[igc7_cell]][[index]]
    for (conditioning in igc7_conditioning_modes)
      for (tau in igc7_tau_multipliers) for (fold in c("S1", "S3"))
        configs[[length(configs) + 1L]] <- igc7_config(state, candidate,
          "quantile", "quantile_vb", fold, tau_multiplier = tau,
          conditioning = conditioning)
  }
  igc7_plan(state, configs, "quantile")
}

igc7_quantile_rank <- function(results) {
  mae <- results[results$metric == "forecast_mae", ]
  keys <- unique(mae[c("structure_id", "tau_multiplier",
    "readout_conditioning")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    z <- mae[mae$structure_id == key$structure_id &
      mae$tau_multiplier == key$tau_multiplier &
      mae$readout_conditioning == key$readout_conditioning, ]
    check <- results[results$config_path %in% z$config_path &
      results$metric == "forecast_check_loss", ]
    data.frame(key, forecast_mae = mean(z$mean),
      forecast_mae_worst = max(z$mean),
      robust_mae = 0.75 * mean(z$mean) + 0.25 * max(z$mean),
      forecast_check_loss = mean(check$mean),
      total_states = median(z$total_states),
      output_lags = median(z$output_lags),
      folds = length(unique(z$fold)), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out[order(out$robust_mae, out$forecast_check_loss, out$total_states,
    out$output_lags, out$structure_id), ]
}

igc7_plan_validation <- function(state, run) {
  results <- igc7_results(run, "quantile")
  rank <- igc7_quantile_rank(results)
  best <- head(rank, 3L)
  alternate_mode <- if (best$readout_conditioning[1L] == "fold_zscore")
    "none" else "fold_zscore"
  paired <- rank[rank$structure_id == best$structure_id[1L] &
    rank$tau_multiplier == best$tau_multiplier[1L] &
    rank$readout_conditioning == alternate_mode, , drop = FALSE]
  selected <- unique(rbind(best, paired, rank))
  selected <- head(selected, 4L)
  iqt12_csv(rank, file.path(run, "summaries", "quantile_rank.csv"))
  effects <- merge(
    rank[rank$readout_conditioning == "none", ],
    rank[rank$readout_conditioning == "fold_zscore", ],
    by = c("structure_id", "tau_multiplier"),
    suffixes = c("_none", "_zscore"))
  effects$mae_change_zscore_minus_none <-
    effects$forecast_mae_zscore - effects$forecast_mae_none
  iqt12_csv(effects, file.path(run, "summaries", "conditioning_effects.csv"))
  iqt12_csv(selected, file.path(run, "selections",
    "quantile_to_validation.csv"))
  configs <- list()
  for (i in seq_len(nrow(selected))) {
    index <- match(selected$structure_id[i],
      vapply(state$panels[[igc7_cell]], `[[`, "", "structure_id"))
    candidate <- state$panels[[igc7_cell]][[index]]
    for (fold in names(igc7_folds))
      configs[[length(configs) + 1L]] <- igc7_config(state, candidate,
        "validation", "quantile_vb", fold,
        tau_multiplier = selected$tau_multiplier[i],
        conditioning = selected$readout_conditioning[i])
  }
  igc7_plan(state, configs, "validation")
}

igc7_validation_rank <- function(run, results) {
  mae <- results[results$metric == "forecast_mae", ]
  baseline <- read.csv(file.path(run, "references", "v6_baseline_scores.csv"),
    stringsAsFactors = FALSE)
  baseline <- baseline[baseline$source_stage == "validation" &
    baseline$metric == "forecast_mae", c("fold", "mean")]
  names(baseline)[2L] <- "baseline_mae"
  keys <- unique(mae[c("candidate_id", "structure_id", "tau_multiplier",
    "readout_conditioning")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    z <- mae[mae$candidate_id == key$candidate_id &
      mae$readout_conditioning == key$readout_conditioning,
      c("fold", "mean")]
    z <- merge(z, baseline, by = "fold", all.x = TRUE)
    data.frame(key, forecast_mae = mean(z$mean),
      baseline_mae = mean(z$baseline_mae),
      ratio = mean(z$mean) / mean(z$baseline_mae),
      worst_fold_ratio = max(z$mean / z$baseline_mae),
      total_states = median(mae$total_states[
        mae$candidate_id == key$candidate_id]),
      output_lags = median(mae$output_lags[
        mae$candidate_id == key$candidate_id]),
      folds = nrow(z), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out[order(out$ratio, out$worst_fold_ratio, out$forecast_mae,
    out$total_states, out$output_lags), ]
}

igc7_plan_mcmc <- function(state, run) {
  rank <- igc7_validation_rank(run, igc7_results(run, "validation"))
  selected <- head(rank, 2L)
  iqt12_csv(rank, file.path(run, "summaries", "validation_rank.csv"))
  iqt12_csv(selected, file.path(run, "selections", "validation_to_mcmc.csv"))
  validation_plan <- read.csv(file.path(run, "plans", "validation.csv"),
    stringsAsFactors = FALSE)
  configs <- list()
  for (i in seq_len(nrow(selected))) {
    index <- match(selected$structure_id[i],
      vapply(state$panels[[igc7_cell]], `[[`, "", "structure_id"))
    candidate <- state$panels[[igc7_cell]][[index]]
    for (fold in c("S2", "S4")) for (chain in 1:3) {
      cfg <- igc7_config(state, candidate, "mcmc", "quantile_mcmc",
        fold, chain, selected$tau_multiplier[i],
        selected$readout_conditioning[i])
      warm <- validation_plan[
        validation_plan$fold == fold &
        validation_plan$structure_id == selected$structure_id[i] &
        validation_plan$tau_multiplier == selected$tau_multiplier[i] &
        validation_plan$readout_conditioning ==
          selected$readout_conditioning[i], , drop = FALSE]
      stopifnot(nrow(warm) == 1L)
      initializer <- file.path(run, "evidence", warm$id,
        "mcmc_initializer.json")
      cfg$warm_path <- normalizePath(initializer, mustWork = TRUE)
      cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path))
      configs[[length(configs) + 1L]] <- cfg
    }
  }
  igc7_plan(state, configs, "mcmc")
}

igc7_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "^[a-z]+[.]csv$",
    full.names = TRUE)
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

igc7_closeout <- function(run) {
  results <- igc7_results(run, "mcmc")
  mae <- results[results$metric == "forecast_mae", ]
  keys <- unique(mae[c("candidate_id", "structure_id", "tau_multiplier",
    "readout_conditioning")])
  baseline <- read.csv(file.path(run, "references", "v6_baseline_scores.csv"),
    stringsAsFactors = FALSE)
  baseline <- baseline[baseline$source_stage == "mcmc" &
    baseline$metric == "forecast_mae", ]
  baseline_mae <- mean(baseline$mean)
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    z <- mae[mae$candidate_id == key$candidate_id &
      mae$readout_conditioning == key$readout_conditioning, ]
    data.frame(key, qdesn_mae = mean(z$mean), baseline_mae = baseline_mae,
      ratio_qdesn_to_baseline = mean(z$mean) / baseline_mae,
      chain_fold_sd = stats::sd(z$mean), chains = nrow(z),
      total_states = median(z$total_states),
      output_lags = median(z$output_lags),
      stringsAsFactors = FALSE)
  })
  comparison <- do.call(rbind, rows)
  comparison <- comparison[order(comparison$ratio_qdesn_to_baseline), ]
  authority <- read.csv(file.path(run, "references",
    "v6_gausmix_mcmc_authority.csv"), stringsAsFactors = FALSE)
  old_q <- mean(authority$mean[authority$model == "qdesn" &
    authority$metric == "forecast_mae"])
  comparison$v6_qdesn_mae <- old_q
  comparison$improvement_over_v6 <- old_q - comparison$qdesn_mae
  iqt12_csv(comparison, file.path(run, "review", "mcmc_primary_comparison.csv"))
  health <- igc7_health(run)
  stopifnot(all(health$failed == 0L), all(health$pending == 0L),
    all(health$running == 0L))
  decision <- if (comparison$ratio_qdesn_to_baseline[1L] <= 1.10)
    "MECHANISM_RESOLVED_PREPARE_FULL_18_CELL_CONFIRMATION" else
    "MECHANISM_NOT_RESOLVED_REPORT_PERSISTENT_GAUSMIX_LIMITATION"
  closeout <- list(schema = igc7_schema, status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE,
    selection_used_article_holdout = FALSE,
    jobs = sum(health$planned), failures = sum(health$failed),
    best = as.list(comparison[1L, ]), active_jobs = 0L,
    fitted_binary_payloads = 0L,
    completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  iqt12_json(closeout, file.path(run, "closeout.json"))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "historical_structure_ledger.csv",
    "source_hashes.csv", "package_hashes.csv", "frozen_hashes.csv",
    "closeout.json")),
    list.files(file.path(run, "references"), full.names = TRUE),
    list.files(file.path(run, "summaries"), full.names = TRUE),
    list.files(file.path(run, "selections"), full.names = TRUE),
    list.files(file.path(run, "review"), full.names = TRUE),
    list.files(file.path(run, "plans"), full.names = TRUE))
  iqt12_hash(files[file.exists(files)], file.path(run, "closeout_manifest.csv"))
  invisible(closeout)
}

igc7_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  results <- igc7_results(run, finished)
  iqt12_csv(results, file.path(run, "summaries", paste0(finished, ".csv")))
  if (finished == "smoke") return(igc7_plan_representation(state))
  if (finished == "representation") return(igc7_plan_quantile(state, run))
  if (finished == "quantile") return(igc7_plan_validation(state, run))
  if (finished == "validation") return(igc7_plan_mcmc(state, run))
  if (finished == "mcmc") return(igc7_closeout(run))
  stop("Unknown completed stage: ", finished)
}

igc7_resources <- itm6_resources
