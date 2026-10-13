icav2_schema <- "independent_qdesn_causal_adaptation_v2"
icav2_candidates <- c("23eb3c867723c85379f2", "3a7a6653cb244f49813c",
  "1b071df459e29d74d20f")
icav2_modes <- c("beta_only", "beta_rhs")
icav2_bridge_offsets <- c(50L, 125L, 200L)

icav2_files <- function(path) {
  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  files[file.exists(files) & !file.info(files)$isdir]
}

icav2_status <- function(path) {
  if (!file.exists(path)) return("PENDING")
  as.character(iqt12_read(path)$status)
}

icav2_verify_parent_closeout <- function(parent_run) {
  stopifnot(dir.exists(parent_run))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv")) iqt12_verify(file.path(parent_run, name))
  health <- ism1r_health(parent_run)
  stopifnot(health$total == 836L, health$complete == 836L,
    health$running == 0L, health$pending == 0L, health$failed == 0L)
  old <- read.csv(file.path(parent_run, "closeout_manifest.csv"),
    stringsAsFactors = FALSE)
  info <- file.info(old$path)
  defect <- info$isdir %in% TRUE & !nzchar(old$sha256)
  stopifnot(nrow(old) == 17L, sum(defect) == 1L,
    basename(old$path[defect]) == "pre_recovery_window_audit")
  files <- !info$isdir
  stopifnot(all(file.exists(old$path[files])),
    identical(unname(tools::sha256sum(old$path[files])), old$sha256[files]))
  invisible(list(health = health, old = old, defect = defect))
}

icav2_write_parent_closeout_supplement <- function(parent_run, run) {
  audit <- icav2_verify_parent_closeout(parent_run)
  files <- c(file.path(parent_run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "frozen_hashes.csv", "closeout.json")),
    icav2_files(file.path(parent_run, "selections")),
    icav2_files(file.path(parent_run, "review")))
  manifest <- file.path(run, "manifests", "parent_closeout_manifest_v2.csv")
  iqt12_hash(files, manifest)
  stopifnot(iqt12_verify(manifest))
  record <- list(schema = "parent_closeout_manifest_supplement_v2",
    parent_run = normalizePath(parent_run, mustWork = TRUE),
    parent_head = iqt12_read(file.path(parent_run, "campaign.json"))$head,
    original_manifest = file.path(parent_run, "closeout_manifest.csv"),
    original_manifest_sha256 = unname(tools::sha256sum(
      file.path(parent_run, "closeout_manifest.csv"))),
    original_rows = nrow(audit$old), verified_file_rows = sum(!audit$defect),
    excluded_directory_rows = sum(audit$defect), scientific_outputs_changed = FALSE,
    model_jobs_rerun = 0L, corrected_manifest = manifest)
  iqt12_json(record, file.path(run, "manifests",
    "parent_closeout_manifest_v2.json"))
  invisible(record)
}

icav2_plan_rows <- function(parent_run, stage) {
  plan <- read.csv(file.path(parent_run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  stopifnot(nrow(plan) > 0L)
  plan
}

icav2_import <- function(parent_run) {
  rows <- list(); add <- function(row, role, mode) {
    cfg <- iqt12_read(row$config_path)
    status <- iqt12_read(row$status_path)
    stopifnot(status$status == "SUCCESS", iqt12_verify(status$manifest))
    rows[[length(rows) + 1L]] <<- data.frame(role = role, mode = mode,
      stage = row$stage, id = row$id, candidate_id = row$candidate_id,
      fold = row$fold, model = row$model, chain = cfg$chain,
      config_path = normalizePath(row$config_path, mustWork = TRUE),
      config_sha256 = unname(tools::sha256sum(row$config_path)),
      status_path = normalizePath(row$status_path, mustWork = TRUE),
      status_sha256 = unname(tools::sha256sum(row$status_path)),
      evidence = normalizePath(cfg$evidence, mustWork = TRUE),
      evidence_manifest = normalizePath(status$manifest, mustWork = TRUE),
      evidence_manifest_sha256 = unname(tools::sha256sum(status$manifest)),
      stringsAsFactors = FALSE)
  }
  static <- icav2_plan_rows(parent_run, "quantile_screen")
  online <- icav2_plan_rows(parent_run, "online_pilot")
  full <- icav2_plan_rows(parent_run, "full_mcmc")
  for (id in icav2_candidates) for (fold in ism1_folds) {
    z <- static[static$candidate_id == id & static$fold == fold &
      static$model == "qdesn", ]
    stopifnot(nrow(z) == 1L); add(z, "static_vb", "static")
    z <- online[online$candidate_id == id & online$fold == fold &
      online$model == "qdesn", ]
    stopifnot(nrow(z) == 1L); add(z, "online_vb", "full")
  }
  for (fold in ism1_folds) for (chain in 1:3) {
    z <- full[full$model == "baseline" & full$fold == fold, ]
    cfg_chain <- vapply(z$config_path, function(p) iqt12_read(p)$chain, 0L)
    z <- z[cfg_chain == chain, ]; stopifnot(nrow(z) == 1L)
    add(z, "baseline_mcmc", "static")
    for (id in icav2_candidates) {
      z <- full[full$model == "qdesn" & full$fold == fold &
        full$candidate_id == id, ]
      cfg_chain <- vapply(z$config_path, function(p) iqt12_read(p)$chain, 0L)
      z <- z[cfg_chain == chain, ]; stopifnot(nrow(z) == 1L)
      add(z, "qdesn_mcmc", "static")
    }
  }
  do.call(rbind, rows)
}

icav2_verify_imports <- function(run) {
  x <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(x) == 72L,
    identical(unname(tools::sha256sum(x$config_path)), x$config_sha256),
    identical(unname(tools::sha256sum(x$status_path)), x$status_sha256),
    identical(unname(tools::sha256sum(x$evidence_manifest)),
      x$evidence_manifest_sha256))
  for (path in x$evidence_manifest) iqt12_verify(path)
  invisible(TRUE)
}

icav2_clone_online_config <- function(parent_run, state, candidate_id, fold, mode) {
  plan <- icav2_plan_rows(parent_run, "online_pilot")
  row <- plan[plan$candidate_id == candidate_id & plan$fold == fold &
    plan$model == "qdesn", ]
  stopifnot(nrow(row) == 1L, mode %in% icav2_modes)
  cfg <- iqt12_read(row$config_path)
  cfg$parent_config_path <- normalizePath(row$config_path, mustWork = TRUE)
  cfg$parent_config_sha256 <- unname(tools::sha256sum(row$config_path))
  cfg$schema <- icav2_schema; cfg$repo <- state$repo; cfg$run <- state$run
  cfg$library <- state$library; cfg$stage <- "online_ablation"
  cfg$online_update <- TRUE; cfg$online_update_mode <- mode
  cfg$id <- paste("online_ablation", cfg$cell, cfg$model, cfg$engine,
    fold, candidate_id, mode, sep = "__")
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$timeout <- 43200L
  cfg
}

icav2_materialize <- function(repo, run, parent_run, library) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(parent_run),
    dir.exists(library))
  icav2_verify_parent_closeout(parent_run)
  parent <- iqt12_read(file.path(parent_run, "campaign.json"))
  head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = icav2_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE), head = head,
    parent_run = normalizePath(parent_run, mustWork = TRUE),
    parent_head = parent$head, references = parent$references,
    bank = parent$bank, candidate_ids = icav2_candidates,
    folds = ism1_folds, online_modes = icav2_modes,
    bridge_offsets = icav2_bridge_offsets,
    contract = list(selection_block = "internal_training_only_S1_to_S4",
      sealed_block = "source_indices_9001_to_10000_unopened",
      teacher_forced_between_origins = TRUE, recursive_within_origin = TRUE,
      preprocessing_frozen_at_fold_training_end = TRUE,
      primary_metric = "forecast_mae", secondary_metric = "forecast_check_loss",
      article_promotion = FALSE))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(read.csv(file.path(parent_run, "candidate_bank.csv"),
    stringsAsFactors = FALSE), file.path(run, "candidate_bank.csv"))
  imports <- icav2_import(parent_run)
  iqt12_csv(imports, file.path(run, "manifests", "parent_imports.csv"))
  icav2_write_parent_closeout_supplement(parent_run, run)
  env <- list(schema = icav2_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    package_path = find.package("exdqlm", lib.loc = library),
    session = capture.output(sessionInfo()),
    threads = list(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1,
      MKL_NUM_THREADS = 1, RCPP_PARALLEL_NUM_THREADS = 1), source_head = head)
  iqt12_json(env, file.path(run, "environment.json"))
  configs <- list()
  for (id in icav2_candidates) for (fold in ism1_folds) for (mode in icav2_modes)
    configs[[length(configs) + 1L]] <- icav2_clone_online_config(
      parent_run, state, id, fold, mode)
  iqt12_plan(state, configs, "online_ablation")
  e <- ism1_runtime(repo, library)
  code <- unique(c(e$iqt12_loaded_files,
    file.path(repo, "R/exal_online_vbld.R"),
    file.path(repo, "validation/fitforecast_v2/R", c(
      "independent_qdesn_training1000_runtime_v1.R",
      "independent_qdesn_training1000_campaign_v1.R",
      "independent_qdesn_sentinel_mechanism_v1.R",
      "independent_qdesn_sentinel_mechanism_recovery_v1.R",
      "independent_qdesn_causal_adaptation_v2.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_causal_adaptation_v2.R",
      "run_independent_qdesn_causal_adaptation_v2.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_CAUSAL_ADAPTATION_V2_20261008.md"),
    file.path(repo, "validation/fitforecast_v2/tests",
      "test_independent_qdesn_causal_adaptation_v2.R")))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(icav2_files(file.path(library, "exdqlm")),
    file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "manifests/parent_imports.csv",
    "manifests/parent_closeout_manifest_v2.csv",
    "manifests/parent_closeout_manifest_v2.json")),
    vapply(parent$references, `[[`, "", "source_path"),
    file.path(parent_run, c("source_hashes.csv", "input_hashes.csv",
      "package_hashes.csv", "frozen_hashes.csv"))),
    file.path(run, "input_hashes.csv"))
  preflight <- list(schema = icav2_schema, status = "READY_TO_LAUNCH",
    parent_jobs = 836L, imported_comparison_jobs = nrow(imports),
    online_ablation_jobs = length(configs), planned_bridge_jobs = 12L,
    article_changed = FALSE, sealed_block_opened = FALSE)
  iqt12_json(preflight, file.path(run, "preflight.json"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "preflight.json",
    "manifests/parent_imports.csv",
    "manifests/parent_closeout_manifest_v2.csv",
    "manifests/parent_closeout_manifest_v2.json")),
    list.files(file.path(run, "plans"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  icav2_verify_imports(run)
  invisible(preflight)
}

icav2_mode_flags <- function(mode) {
  switch(mode,
    beta_only = list(update_rhs = FALSE, update_sigmagam = FALSE),
    beta_rhs = list(update_rhs = TRUE, update_sigmagam = FALSE),
    full = list(update_rhs = TRUE, update_sigmagam = TRUE),
    stop("Unknown online update mode: ", mode))
}

icav2_qforecast_online <- function(e, cx, cfg, fit, draws, progress = NULL) {
  stopifnot(inherits(fit, "exal_vb"), cfg$likelihood == "exal")
  flags <- icav2_mode_flags(cfg$online_update_mode)
  prior <- iqt12_prior(e, cfg, cx$scale)
  state <- e$exal_online_init(cx$object$y_fit, cx$object$X, cfg$p,
    c(e$L.fn(cfg$p), e$U.fn(cfg$p)),
    control = list(M = 5L, K = 20L, W = 250L, L_loc = 2L,
      window_passes = 1L), batch_fit = fit,
    prior_gamma = list(mu0 = 0, s20 = 10), prior_sigma = prior$sigma,
    beta_prior_obj = prior$beta)
  beta_initial <- state$qbeta$m
  object <- cx$object; object$fit <- fit; previous <- max(cfg$window$train)
  out <- plugin <- guards <- trace <- vector("list", length(cfg$window$origins))
  for (i in seq_along(cfg$window$origins)) {
    o <- cfg$window$origins[i]; added <- 0L
    if (o > previous) {
      idx <- seq.int(previous + 1L, o); local_idx <- idx - cx$first + 1L
      added <- length(idx)
      state <- e$exal_online_run(state, cx$y[local_idx],
        cx$all_X[local_idx, , drop = FALSE],
        update_rhs = flags$update_rhs,
        update_sigmagam = flags$update_sigmagam, keep_trace = FALSE)
    }
    previous <- o; local <- o - cx$first + 1L
    H <- min(cfg$window$horizon, cfg$window$end - o)
    online_draws <- list(beta = ism1_mvn(state$qbeta$m, state$qbeta$V,
      cfg$outer, cfg$seed + o), sigma = rep(state$qsiggam$sigma_mean, cfg$outer),
      gamma = rep(state$qsiggam$gamma_mean, cfg$outer))
    bank <- e$iqcf_v3_make_noise_bank(online_draws, H, 1L, cfg$inner, cfg$seed + o)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1L]]
    repeated <- e$iqcf_v3_repeat_draws(online_draws, cfg$inner)
    path <- ism1_particle_paths(e, object, cx$y, local, H, repeated, noise,
      capture_first_step = TRUE)
    out[[i]] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws,
      cfg$outer, cfg$inner, "mean") * cx$scale
    zeros <- matrix(0, H, cfg$outer)
    plugin[[i]] <- ism1_particle_paths(e, object, cx$y, local, H,
      online_draws, list(s = zeros, v = zeros, z = zeros))$mu_draws * cx$scale
    expected_x <- matrix(cx$all_X[local + 1L, ], nrow = nrow(path$first_step_x),
      ncol = ncol(path$first_step_x))
    expected_prediction <- cx$all_X[local + 1L, , drop = FALSE] %*%
      t(online_draws$beta) * cx$scale
    checked <- ism1_assert_first_step(expected_x, path$first_step_x,
      expected_prediction, out[[i]][1L, , drop = FALSE])
    guards[[i]] <- data.frame(origin = o,
      feature_max_absolute_error = checked$feature$max_absolute_error,
      feature_max_relative_error = checked$feature$max_relative_error,
      prediction_max_absolute_error = checked$prediction$max_absolute_error,
      prediction_max_relative_error = checked$prediction$max_relative_error,
      prediction_comparison_scale = checked$prediction$comparison_scale,
      pass = TRUE)
    trace[[i]] <- data.frame(origin = o, observations_added = added,
      beta_l2_shift = sqrt(sum((state$qbeta$m - beta_initial)^2)),
      intercept_shift = state$qbeta$m[1L] - beta_initial[1L],
      rhs_refreshes = state$refresh_counts$rhs,
      sigmagam_refreshes = state$refresh_counts$sigmagam,
      gamma_mean = state$qsiggam$gamma_mean,
      sigma_mean_source_units = state$qsiggam$sigma_mean * cx$scale)
    if (!is.null(progress)) progress(i, length(cfg$window$origins))
  }
  iqt12_csv(do.call(rbind, trace), file.path(cfg$evidence,
    "online_update_trace.csv"))
  iqt12_json(c(list(mode = cfg$online_update_mode), flags),
    file.path(cfg$evidence, "online_update_contract.json"))
  list(primary = do.call(rbind, out), plugin = do.call(rbind, plugin),
    first_step_guard = do.call(rbind, guards))
}

icav2_qforecast <- function(e, cx, cfg, fit, draws, progress = NULL) {
  if (isTRUE(cfg$online_update) && !is.null(cfg$online_update_mode))
    icav2_qforecast_online(e, cx, cfg, fit, draws, progress)
  else ism1_qforecast(e, cx, cfg, fit, draws, progress)
}

icav2_local_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  stopifnot(all(vapply(plan$status_path, icav2_status, "") == "SUCCESS"))
  do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    z <- read.csv(file.path(cfg$evidence, "summary.csv"), stringsAsFactors = FALSE)
    z$mode <- cfg$online_update_mode %||% "bridge"
    z$config_path <- plan$config_path[i]
    z
  }))
}

icav2_imported_vb_results <- function(run) {
  imports <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  imports <- imports[imports$role %in% c("static_vb", "online_vb"), ]
  do.call(rbind, lapply(seq_len(nrow(imports)), function(i) {
    z <- read.csv(file.path(imports$evidence[i], "summary.csv"),
      stringsAsFactors = FALSE)
    z$mode <- imports$mode[i]; z$config_path <- imports$config_path[i]
    z
  }))
}

icav2_adaptation_rank <- function(results) {
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  key <- unique(mae[, c("candidate_id", "mode")])
  rows <- lapply(seq_len(nrow(key)), function(i) {
    m <- mae[mae$candidate_id == key$candidate_id[i] & mae$mode == key$mode[i], ]
    c <- check[check$candidate_id == key$candidate_id[i] & check$mode == key$mode[i], ]
    s <- mae[mae$candidate_id == key$candidate_id[i] & mae$mode == "static", ]
    sc <- check[check$candidate_id == key$candidate_id[i] & check$mode == "static", ]
    paired <- merge(m[, c("fold", "mean")], s[, c("fold", "mean")],
      by = "fold", suffixes = c("_mode", "_static"))
    data.frame(candidate_id = key$candidate_id[i], mode = key$mode[i],
      median_forecast_mae = median(m$mean), max_forecast_mae = max(m$mean),
      median_check_loss = median(c$mean),
      static_median_forecast_mae = median(s$mean),
      static_median_check_loss = median(sc$mean),
      folds_improved = sum(paired$mean_mode < paired$mean_static),
      median_mae_gain_pct = 100 * (median(s$mean) - median(m$mean)) / median(s$mean),
      stringsAsFactors = FALSE)
  })
  z <- do.call(rbind, rows)
  z[order(z$median_forecast_mae, z$median_check_loss, z$max_forecast_mae,
    z$candidate_id, z$mode), ]
}

icav2_bridge_config <- function(state, selected, fold, offset) {
  imports <- read.csv(file.path(state$run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  row <- imports[imports$role == "qdesn_mcmc" &
    imports$candidate_id == selected$candidate_id & imports$fold == fold &
    imports$chain == 1L, ]
  stopifnot(nrow(row) == 1L)
  cfg <- iqt12_read(row$config_path)
  cfg$schema <- icav2_schema; cfg$repo <- state$repo; cfg$run <- state$run
  cfg$library <- state$library; cfg$stage <- "mcmc_bridge"; cfg$engine <- "mcmc"
  cfg$online_update <- FALSE; cfg$adaptation_mode <- selected$mode
  cfg$refit_origin <- max(cfg$window$train) + as.integer(offset)
  cfg$base_train <- cfg$window$train; cfg$bridge_offset <- as.integer(offset)
  cfg$burn <- 3000L; cfg$retained <- 10000L; cfg$outer <- 160L; cfg$inner <- 64L
  cfg$warm_path <- NULL; cfg$warm_sha <- NULL; cfg$chain <- 1L
  cfg$id <- paste("mcmc_bridge", cfg$cell, cfg$model, cfg$engine, fold,
    cfg$candidate$id, selected$mode, paste0("o", cfg$refit_origin), sep = "__")
  cfg$seed <- ism1_seed(cfg$id); cfg$path <- file.path(state$run,
    "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$timeout <- 172800L
  cfg
}

icav2_make_bridge_plan <- function(run, selected) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  configs <- list()
  for (fold in ism1_folds) for (offset in icav2_bridge_offsets)
    configs[[length(configs) + 1L]] <- icav2_bridge_config(state, selected,
      fold, offset)
  iqt12_plan(state, configs, "mcmc_bridge")
}

icav2_bridge_worker <- function(path) {
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
    first_train <- min(cfg$base_train) - cx$first + 1L
    last_train <- cfg$refit_origin - cx$first + 1L
    index <- seq.int(first_train, last_train)
    cx$object$X <- cx$all_X[index, , drop = FALSE]
    cx$object$y_fit <- cx$y[index]
    cx$object$meta$keep_idx <- index
    cx$train <- index
    cx$design_hash <- digest::digest(cx$object$X, algo = "sha256")
    stopifnot(nrow(cx$object$X) == length(cfg$base_train) + cfg$bridge_offset)
    fit <- iqt12_quantile(e, cx, cfg)
    draws <- iqt12_draws(e, fit, cfg$outer, cfg$seed + 1L)
    fit_draws <- cx$object$X %*% t(draws$beta) * cx$scale
    forecast_cfg <- cfg
    forecast_cfg$window$train <- seq.int(min(cfg$base_train), cfg$refit_origin)
    forecast_cfg$window$N <- length(forecast_cfg$window$train)
    forecast_cfg$window$origins <- cfg$refit_origin
    forecast_cfg$window$end <- cfg$refit_origin + cfg$window$horizon
    fc <- ism1_qforecast_static(e, cx, forecast_cfg, fit, draws)
    score <- iqt12_scores(fit_draws, fc$primary, source,
      forecast_cfg$window, cfg$p)
    add <- data.frame(id = cfg$id, cell = cfg$cell,
      candidate_id = cfg$candidate$id, model = "qdesn", engine = "mcmc",
      family = cfg$family, p = cfg$p, N = forecast_cfg$window$N,
      fold = cfg$window$fold, chain = cfg$chain, refit_origin = cfg$refit_origin,
      adaptation_mode = cfg$adaptation_mode)
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
      refit_origin = cfg$refit_origin, base_train_end = max(cfg$base_train),
      observations_added = cfg$bridge_offset,
      preprocessing_last = max(cfg$base_train),
      design_rows = nrow(cx$object$X), design_hash = cx$design_hash,
      first_step_guard_pass = all(fc$first_step_guard$pass),
      sigma_ESS = unname(coda::effectiveSize(fit$samp.sigma)),
      gamma_ESS = unname(coda::effectiveSize(fit$samp.gamma)),
      intercept_ESS = unname(coda::effectiveSize(fit$samp.beta[, 1L])),
      total_seconds = proc.time()[["elapsed"]] - start,
      cpu_seconds = sum(proc.time()[c("user.self", "sys.self")]),
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

icav2_parent_origin_metric <- function(imports, role, candidate_id, fold,
                                       origin) {
  z <- imports[imports$role == role & imports$fold == fold, ]
  if (!is.null(candidate_id)) z <- z[z$candidate_id == candidate_id, ]
  stopifnot(nrow(z) == 3L)
  values <- lapply(z$evidence, function(path) {
    p <- read.csv(gzfile(file.path(path, "origin_lead.csv.gz")),
      stringsAsFactors = FALSE)
    p <- p[p$origin == origin, ]
    stopifnot(nrow(p) == 30L)
    c(forecast_mae = mean(p$mae), forecast_check_loss = mean(p$check_loss))
  })
  colMeans(do.call(rbind, values))
}

icav2_bridge_closeout <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  selected <- iqt12_read(file.path(run, "selections", "adaptation_selected.json"))
  local <- icav2_local_results(run, "mcmc_bridge")
  imports <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  mae <- local[local$metric == "forecast_mae", ]
  check <- local[local$metric == "forecast_check_loss", ]
  rows <- lapply(seq_len(nrow(mae)), function(i) {
    fold <- mae$fold[i]; origin <- mae$refit_origin[i]
    static <- icav2_parent_origin_metric(imports, "qdesn_mcmc",
      selected$candidate_id, fold, origin)
    baseline <- icav2_parent_origin_metric(imports, "baseline_mcmc",
      NULL, fold, origin)
    check_value <- check$mean[check$fold == fold & check$refit_origin == origin]
    data.frame(fold = fold, origin = origin, candidate_id = selected$candidate_id,
      mode = selected$mode, adapted_mae = mae$mean[i], static_mae = static[1L],
      baseline_mae = baseline[1L], adapted_check_loss = check_value,
      static_check_loss = static[2L], baseline_check_loss = baseline[2L],
      adapted_static_mae_ratio = mae$mean[i] / static[1L],
      adapted_baseline_mae_ratio = mae$mean[i] / baseline[1L])
  })
  comparison <- do.call(rbind, rows)
  iqt12_csv(comparison, file.path(run, "review", "mcmc_bridge_comparison.csv"))
  supported <- median(comparison$adapted_static_mae_ratio) < 1 &&
    sum(comparison$adapted_static_mae_ratio < 1) >= 8L
  closes_gap <- median(comparison$adapted_baseline_mae_ratio) < 1 &&
    sum(comparison$adapted_baseline_mae_ratio < 1) >= 7L
  decision <- if (supported && closes_gap)
    "CAUSAL_READOUT_ADAPTATION_CLOSES_SENTINEL_GAP_FRESH_DGP_REQUIRED" else
    if (supported) "CAUSAL_READOUT_ADAPTATION_SUPPORTED_GAP_REMAINS" else
      "CAUSAL_READOUT_ADAPTATION_NOT_CONFIRMED_STOP_STATIC_SCREENING"
  closeout <- list(status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE, active_jobs = 0L,
    online_gate_passed = TRUE, mcmc_adaptation_supported = supported,
    mcmc_closes_baseline_gap = closes_gap, bridge_jobs = nrow(mae),
    next_action = if (closes_gap) "design_fresh_DGP_confirmation_only" else
      if (supported) "review_dynamic_readout_scope_before_more_compute" else
        "retain_current_authority_and_stop_static_DESN_screening")
  iqt12_json(closeout, file.path(run, "closeout.json"))
  payloads <- list.files(run, recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  stopifnot(!length(payloads))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "frozen_hashes.csv", "preflight.json",
    "closeout.json")), icav2_files(file.path(run, "manifests")),
    icav2_files(file.path(run, "selections")),
    icav2_files(file.path(run, "summaries")),
    icav2_files(file.path(run, "review")))
  iqt12_hash(files, file.path(run, "closeout_manifest.csv"))
  stopifnot(iqt12_verify(file.path(run, "closeout_manifest.csv")))
  "COMPLETE_REVIEW_REQUIRED"
}

icav2_advance <- function(run, stage) {
  icav2_verify_imports(run)
  if (stage == "online_ablation") {
    results <- rbind(icav2_imported_vb_results(run),
      icav2_local_results(run, stage))
    iqt12_csv(results, file.path(run, "summaries", "adaptation_cell_metrics.csv"))
    rank <- icav2_adaptation_rank(results)
    iqt12_csv(rank, file.path(run, "review", "adaptation_mode_rank.csv"))
    eligible <- rank[rank$mode != "static" & rank$folds_improved >= 3L &
      rank$median_forecast_mae < rank$static_median_forecast_mae &
      rank$median_check_loss <= 1.02 * rank$static_median_check_loss, ]
    gate <- nrow(eligible) > 0L
    selected <- if (gate) eligible[1L, ] else rank[rank$mode != "static", ][1L, ]
    iqt12_json(as.list(selected), file.path(run, "selections",
      "adaptation_selected.json"))
    iqt12_json(list(status = if (gate) "PASS" else "STOP",
      candidate_id = selected$candidate_id, mode = selected$mode,
      folds_improved = selected$folds_improved,
      median_mae_gain_pct = selected$median_mae_gain_pct,
      rule = "at_least_3_of_4_folds_plus_positive_median_MAE_gain_plus_check_loss_within_2pct"),
      file.path(run, "review", "adaptation_gate.json"))
    if (!gate) {
      iqt12_json(list(status = "COMPLETE_REVIEW_REQUIRED",
        scientific_decision = "ONLINE_ADAPTATION_GATE_FAILED_STOP",
        article_changed = FALSE, active_jobs = 0L,
        next_action = "retain_current_authority_and_stop_static_DESN_screening"),
        file.path(run, "closeout.json"))
      files <- c(file.path(run, c("campaign.json", "environment.json",
        "source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
        "frozen_hashes.csv", "closeout.json")),
        icav2_files(file.path(run, "manifests")),
        icav2_files(file.path(run, "selections")),
        icav2_files(file.path(run, "summaries")),
        icav2_files(file.path(run, "review")))
      iqt12_hash(files, file.path(run, "closeout_manifest.csv"))
      return("COMPLETE_REVIEW_REQUIRED")
    }
    icav2_make_bridge_plan(run, selected)
    return("mcmc_bridge")
  }
  if (stage == "mcmc_bridge") return(icav2_bridge_closeout(run))
  stop("Unsupported causal-adaptation stage: ", stage)
}

icav2_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "[.]csv$",
    full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  z <- do.call(rbind, lapply(plans, read.csv, stringsAsFactors = FALSE))
  status <- vapply(z$status_path, icav2_status, "")
  data.frame(total = nrow(z), complete = sum(status == "SUCCESS"),
    running = sum(status == "RUNNING"), pending = sum(status == "PENDING"),
    failed = sum(grepl("FAILED", status)), stages = length(unique(z$stage)))
}
