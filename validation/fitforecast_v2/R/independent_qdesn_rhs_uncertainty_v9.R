ifu9_schema <- "independent_qdesn_rhs_uncertainty_v9"
ifu9_cell <- ifu8_cell
ifu9_stages <- c("smoke", "attribution", "warm", "discovery",
  "confirm_warm", "confirmation")
ifu9_parent_run <- paste0(
  "/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_forecast_uncertainty_v8_20261011/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_forecast_uncertainty_v8_20261011_220044__git-f21bf2a2")
ifu9_tau_grid <- c(1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3)
ifu9_slab_grid <- c(0.25, 0.5, 0.75, 1)

ifu9_format_number <- function(x) {
  sub("[.]0+$", "", sub("([.][0-9]*?)0+$", "\\1",
    format(as.numeric(x), scientific = FALSE, trim = TRUE)))
}

ifu9_parent_classification <- function(comparison) {
  stopifnot(nrow(comparison) >= 1L)
  best <- comparison[1L, , drop = FALSE]
  denominator <- best$v7_forecast_mae_width - best$dqlm_forecast_mae_width
  gap_closed <- if (is.finite(denominator) && denominator > 0)
    (best$v7_forecast_mae_width - best$forecast_mae_width) / denominator else NA_real_
  classification <- if (isTRUE(best$eligible) && is.finite(gap_closed) &&
      gap_closed >= 0.50) "FULL_RESCUE" else if (isTRUE(best$eligible))
    "PARTIAL_RESCUE" else "NO_RESCUE"
  list(classification = classification, excess_width_gap_closed = gap_closed,
    run_required = classification != "FULL_RESCUE", best = best)
}

ifu9_maximin_panel <- function(parent_tau, count = 12L) {
  grid <- expand.grid(tau_multiplier = ifu9_tau_grid,
    slab_multiplier = ifu9_slab_grid, KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  grid <- grid[order(grid$tau_multiplier, grid$slab_multiplier), , drop = FALSE]
  anchors <- unique(rbind(
    c(parent_tau, 1),
    c(2, 1),
    c(2, 0.5),
    c(1.5, 0.5)))
  anchor_index <- vapply(seq_len(nrow(anchors)), function(i) {
    which(abs(grid$tau_multiplier - anchors[i, 1L]) < 1e-12 &
      abs(grid$slab_multiplier - anchors[i, 2L]) < 1e-12)[1L]
  }, 1L)
  selected <- unique(anchor_index)
  features <- scale(cbind(log(grid$tau_multiplier), log(grid$slab_multiplier)))
  while (length(selected) < count) {
    remaining <- setdiff(seq_len(nrow(grid)), selected)
    distance <- vapply(remaining, function(i)
      min(rowSums((features[selected, , drop = FALSE] -
        matrix(features[i, ], nrow = length(selected), ncol = 2L,
          byrow = TRUE))^2)), 0)
    selected <- c(selected, remaining[which.max(distance)])
  }
  panel <- grid[selected, , drop = FALSE]
  panel$role <- ifelse(abs(panel$tau_multiplier - parent_tau) < 1e-12 &
      abs(panel$slab_multiplier - 1) < 1e-12,
    "v8_parent_anchor", "space_filling_rhs")
  panel$prior_id <- vapply(seq_len(nrow(panel)), function(i)
    substr(digest::digest(as.list(panel[i, c("tau_multiplier",
      "slab_multiplier")]), algo = "sha256"), 1L, 16L), "")
  panel[order(panel$tau_multiplier, panel$slab_multiplier), , drop = FALSE]
}

ifu9_config <- function(state, stage, estimator, fold, tau_multiplier,
                        slab_multiplier, chain = 1L, warm_path = NULL) {
  stopifnot(stage %in% setdiff(ifu9_stages, "attribution"),
    fold %in% names(itm6_folds), tau_multiplier > 0,
    slab_multiplier > 0)
  base_stage <- if (stage == "smoke") "smoke" else
    if (estimator == "quantile_vb") "validation" else "mcmc"
  cfg <- igc7_config(state, state$winner, base_stage, estimator, fold,
    chain, tau_multiplier, "fold_zscore")
  cfg$schema <- ifu9_schema
  cfg$stage <- stage
  cfg$slab_multiplier <- as.numeric(slab_multiplier)
  cfg$candidate$parent_candidate_id <- cfg$candidate$id
  cfg$candidate$slab_source <- state$base_slab_source * slab_multiplier
  cfg$candidate$slab_multiplier <- as.numeric(slab_multiplier)
  cfg$candidate$prior_id <- substr(digest::digest(list(
    structure_id = cfg$candidate$structure_id,
    tau_source = cfg$candidate$tau_source,
    slab_source = cfg$candidate$slab_source), algo = "sha256"), 1L, 20L)
  cfg$candidate$id <- cfg$candidate$prior_id
  cfg$id <- paste(
    sub(paste0("^", base_stage, "__"), paste0(stage, "__"), cfg$id),
    paste0("slab", ifu9_format_number(slab_multiplier)), sep = "__")
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

ifu9_attribution_config <- function(state, parent_row) {
  parent_cfg <- iqt12_read(parent_row$config_path)
  id <- paste0("attribution__", parent_cfg$id)
  list(schema = ifu9_schema, run = state$run, repo = state$repo,
    library = state$library, id = id, stage = "attribution",
    cell = parent_cfg$cell, family = parent_cfg$family, p = parent_cfg$p,
    likelihood = parent_cfg$likelihood, model = parent_cfg$model,
    estimator = "retained_draw_beta_block_attribution", engine = "attribution",
    chain = parent_cfg$chain, fold = parent_cfg$window$fold,
    tau_multiplier = parent_cfg$tau_multiplier, slab_multiplier = 1,
    readout_conditioning = parent_cfg$readout_conditioning,
    candidate = parent_cfg$candidate, window = parent_cfg$window,
    source_path = state$references[[ifu9_cell]]$source_path,
    source_sha = state$references[[ifu9_cell]]$source_sha,
    parent_config_path = normalizePath(parent_row$config_path, mustWork = TRUE),
    parent_config_sha = unname(tools::sha256sum(parent_row$config_path)),
    parent_evidence = normalizePath(parent_cfg$evidence, mustWork = TRUE),
    parent_manifest = normalizePath(iqt12_read(parent_row$status_path)$manifest,
      mustWork = TRUE),
    path = file.path(state$run, "configs", paste0(id, ".json")),
    status_path = file.path(state$run, "status", paste0(id, ".json")),
    evidence = file.path(state$run, "evidence", id), timeout = 172800L)
}

ifu9_plan <- function(state, configs, stage) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Frozen stage already exists: ", stage)
  rows <- lapply(configs, function(cfg) {
    iqt12_json(cfg, cfg$path)
    data.frame(id = cfg$id, stage = stage, cell = cfg$cell,
      estimator = cfg$estimator, engine = cfg$engine,
      fold = cfg$window$fold %||% cfg$fold, chain = cfg$chain,
      candidate_id = cfg$candidate$id,
      structure_id = cfg$candidate$structure_id,
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

ifu9_materialize <- function(repo, run, library, parent = ifu9_parent_run) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(library),
    dir.exists(parent), file.exists(file.path(parent, "closeout.json")))
  iqt12_verify(file.path(parent, "closeout_manifest.csv"))
  parent_closeout <- iqt12_read(file.path(parent, "closeout.json"))
  parent_comparison <- read.csv(file.path(parent, "review",
    "confirmation_decision_table.csv"), stringsAsFactors = FALSE)
  parent_class <- ifu9_parent_classification(parent_comparison)
  stopifnot(parent_closeout$status == "COMPLETE_REVIEW_REQUIRED",
    parent_closeout$failures == 0L, parent_closeout$active_jobs == 0L)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "references", "sources"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  parent_state <- iqt12_read(file.path(parent, "campaign.json"))
  reference <- parent_state$references[[ifu9_cell]]
  source <- read.csv(reference$source_path, stringsAsFactors = FALSE)
  stopifnot(max(source$t) == 9000L)
  source_path <- file.path(run, "sources", paste0(ifu9_cell, ".csv"))
  iqt12_csv(source, source_path)
  reference$source_path <- source_path
  reference$source_sha <- unname(tools::sha256sum(source_path))
  parent_plan <- read.csv(file.path(parent, "plans", "confirmation.csv"),
    stringsAsFactors = FALSE)
  best_tau <- parent_class$best$tau_multiplier[[1L]]
  parent_plan <- parent_plan[abs(parent_plan$tau_multiplier - best_tau) < 1e-12,
    , drop = FALSE]
  stopifnot(nrow(parent_plan) == 6L)
  winner <- iqt12_read(parent_plan$config_path[1L])$candidate
  panel <- ifu9_maximin_panel(best_tau)
  state <- list(schema = ifu9_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE),
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    parent_run = normalizePath(parent, mustWork = TRUE),
    max_workers = 30L, cell = ifu9_cell, winner = winner,
    base_slab_source = winner$slab_source,
    parent_best_tau = best_tau, parent_classification = parent_class,
    panel = split(panel, seq_len(nrow(panel))),
    references = setNames(list(reference), ifu9_cell),
    contract = list(
      target = "Gaussian-mixture_AL_p0.05_RHS_score_interval_width",
      fixed_structure = winner$structure_id,
      distinct_prior_axes = c("global_tau0", "RHS_NS_slab_b_zeta"),
      effective_p0_status = paste0("elicitation_only; redundant_with_tau_",
        "multiplier_when_p_N_are_fixed"),
      selection_folds = c("S1", "S3"),
      confirmation_folds = c("S2", "S4"),
      article_holdout = "source_indices_9001_to_10000_never_opened",
      primary_estimator = "current_recursive_inner_average",
      teacher_forcing = "observations_assimilated_between_origins",
      within_origin = "recursive_30_step_forecast",
      closure = "at_least_half_of_v7_to_DQLM_excess_width_gap_closed",
      article_promotion = FALSE,
      fitted_model_binaries = "forbidden"))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(panel, file.path(run, "candidate_bank.csv"))
  iqt12_json(parent_class, file.path(run, "references",
    "v8_parent_classification.json"))
  for (file in c("dqlm_baseline_scores.csv", "v7_primary_comparison.csv"))
    stopifnot(file.copy(file.path(parent, "references", file),
      file.path(run, "references", file)))
  stopifnot(file.copy(file.path(parent, "review",
      "confirmation_decision_table.csv"), file.path(run, "references",
      "v8_confirmation_decision_table.csv")),
    file.copy(file.path(parent, "closeout.json"), file.path(run,
      "references", "v8_closeout.json")))
  environment <- list(schema = ifu9_schema,
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
    "scripts/independent_qdesn_rhs_uncertainty_v9.R",
    "scripts/run_independent_qdesn_rhs_uncertainty_v9.sh",
    "docs/INDEPENDENT_QDESN_RHS_UNCERTAINTY_V9_20261012.md"))
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
  if (!isTRUE(parent_class$run_required)) {
    closeout <- list(schema = ifu9_schema, status = "COMPLETE_NO_RUN_REQUIRED",
      scientific_decision = "V8_FULL_RESCUE_NO_ADDITIONAL_RHS_SCREEN",
      parent_classification = parent_class$classification,
      excess_width_gap_closed = parent_class$excess_width_gap_closed,
      article_changed = FALSE, jobs = 0L, failures = 0L, active_jobs = 0L,
      fitted_binary_payloads = 0L,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
    iqt12_json(closeout, file.path(run, "closeout.json"))
    iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
      "candidate_bank.csv", "source_hashes.csv", "package_hashes.csv",
      "input_hashes.csv", "frozen_hashes.csv", "closeout.json")),
      list.files(file.path(run, "references"), full.names = TRUE)),
      file.path(run, "closeout_manifest.csv"))
    return(invisible(state))
  }
  anchor <- panel[panel$role == "v8_parent_anchor", , drop = FALSE]
  stopifnot(nrow(anchor) == 1L)
  ifu9_plan(state, list(ifu9_config(state, "smoke", "quantile_mcmc",
    "S1", anchor$tau_multiplier, anchor$slab_multiplier)), "smoke")
  invisible(state)
}

ifu9_block_indices <- function(n) {
  n <- as.integer(n)
  order <- c(length(n), if (length(n) > 1L) seq_len(length(n) - 1L))
  labels <- c("intercept", paste0("layer_", order))
  indices <- list(1L)
  cursor <- 2L
  for (d in order) {
    indices[[length(indices) + 1L]] <- seq.int(cursor, length.out = n[d])
    cursor <- cursor + n[d]
  }
  names(indices) <- labels
  indices
}

ifu9_attribution_worker <- function(cfg) {
  started <- proc.time()[["elapsed"]]
  for (name in c("source_hashes.csv", "package_hashes.csv", "input_hashes.csv",
      "frozen_hashes.csv")) iqt12_verify(file.path(cfg$run, name))
  iqt12_verify(file.path(cfg$run, "plans", "attribution_hashes.csv"))
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
    names(full) <- names(source); full[source$t, ] <- source; source <- full
    cx <- igc7_design_hook(e, cfg, source, cfg$window$end)
    draws <- ifu8_selected_draws(file.path(cfg$parent_evidence,
      "selected_parameters.csv.gz"))
    beta <- draws$beta
    indices <- ifu9_block_indices(iqt12_unpack(cfg$candidate$n))
    stopifnot(sum(lengths(indices)) == ncol(beta))
    local <- cfg$window$origins - cx$first + 1L
    X <- cx$all_X[local + 1L, , drop = FALSE]
    total <- X %*% t(beta) * cx$scale
    beta_rows <- contribution_rows <- list()
    for (block in names(indices)) {
      idx <- indices[[block]]
      centered <- scale(beta[, idx, drop = FALSE], center = TRUE, scale = FALSE)
      singular <- svd(centered, nu = 0L, nv = 0L)$d^2
      trace <- sum(singular) / max(1, nrow(beta) - 1L)
      contribution <- X[, idx, drop = FALSE] %*%
        t(beta[, idx, drop = FALSE]) * cx$scale
      covariance_share <- vapply(seq_len(nrow(contribution)), function(i) {
        denominator <- stats::var(total[i, ])
        if (!is.finite(denominator) || denominator <= 0) NA_real_ else
          stats::cov(contribution[i, ], total[i, ]) / denominator
      }, 0)
      beta_rows[[block]] <- data.frame(block = block, coefficients = length(idx),
        covariance_trace = trace,
        first_pc_share = if (sum(singular) > 0) singular[1L] / sum(singular) else 0,
        posterior_mean_l2 = sqrt(sum(colMeans(beta[, idx, drop = FALSE])^2)),
        mean_coefficient_sd = mean(apply(beta[, idx, drop = FALSE], 2L, sd)),
        stringsAsFactors = FALSE)
      contribution_rows[[block]] <- data.frame(block = block,
        mean_origin_sd = mean(apply(contribution, 1L, sd)),
        max_origin_sd = max(apply(contribution, 1L, sd)),
        mean_absolute_contribution = mean(abs(contribution)),
        mean_covariance_share = mean(covariance_share, na.rm = TRUE),
        stringsAsFactors = FALSE)
    }
    centered <- scale(beta[, -1L, drop = FALSE], center = TRUE, scale = FALSE)
    singular <- svd(centered, nu = 0L, nv = 0L)$d^2
    spectrum <- data.frame(component = seq_along(singular),
      variance_share = singular / sum(singular),
      cumulative_share = cumsum(singular / sum(singular)))
    iqt12_csv(do.call(rbind, beta_rows), file.path(cfg$evidence,
      "beta_block_attribution.csv"))
    iqt12_csv(do.call(rbind, contribution_rows), file.path(cfg$evidence,
      "first_step_block_attribution.csv"))
    iqt12_csv(spectrum, file.path(cfg$evidence, "beta_eigenspectrum.csv"))
    iqt12_json(list(parent_config = cfg$parent_config_path,
      posterior_draws = nrow(beta), first_step_origins = nrow(X),
      fitted_binary_payloads = 0L,
      elapsed = proc.time()[["elapsed"]] - started),
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

ifu9_worker <- function(path) {
  cfg <- iqt12_read(path)
  if (cfg$stage == "attribution") return(ifu9_attribution_worker(cfg))
  tryCatch({
    ifu8_worker(path)
    diagnostics_path <- file.path(cfg$evidence, "diagnostics.json")
    diagnostics <- iqt12_read(diagnostics_path)
    diagnostics$rhs_uncertainty_v9 <- list(
      global_tau_multiplier = cfg$tau_multiplier,
      slab_multiplier = cfg$slab_multiplier,
      tau_source = cfg$candidate$tau_source,
      slab_source = cfg$candidate$slab_source,
      prior_id = cfg$candidate$prior_id,
      effective_p0_status = paste0("elicitation_only_redundant_with_tau_",
        "multiplier_for_fixed_readout_dimension_and_sample_size"))
    iqt12_json(diagnostics, diagnostics_path)
    manifest_path <- file.path(cfg$evidence, "manifest.csv")
    if (file.exists(manifest_path)) unlink(manifest_path)
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      manifest_path)
    status <- iqt12_read(cfg$status_path)
    status$manifest <- manifest
    status$rhs_uncertainty_v9 <- "COMPLETE"
    iqt12_json(status, cfg$status_path)
    invisible(TRUE)
  }, error = function(error) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(error)), cfg$status_path)
    stop(error)
  })
}

ifu9_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "^[a-z_]+[.]csv$",
    full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  if (!length(plans)) return(data.frame(stage = character(), planned = integer(),
    complete = integer(), running = integer(), failed = integer(),
    pending = integer()))
  rows <- lapply(plans, function(path) {
    plan <- read.csv(path, stringsAsFactors = FALSE)
    statuses <- vapply(plan$status_path, function(status_path) {
      if (!file.exists(status_path)) return("PENDING")
      iqt12_read(status_path)$status
    }, "")
    data.frame(stage = sub("[.]csv$", "", basename(path)), planned = nrow(plan),
      complete = sum(statuses == "SUCCESS"), running = sum(statuses == "RUNNING"),
      failed = sum(grepl("FAILED", statuses)), pending = sum(statuses == "PENDING"),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

ifu9_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    status <- iqt12_read(plan$status_path[i]); stopifnot(status$status == "SUCCESS")
    iqt12_verify(status$manifest)
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence, "summary.csv"),
      stringsAsFactors = FALSE)
    value$tau_multiplier <- cfg$tau_multiplier
    value$slab_multiplier <- cfg$slab_multiplier
    value$prior_id <- cfg$candidate$prior_id
    value$config_path <- cfg$path
    value
  })
  do.call(rbind, rows)
}

ifu9_uncertainty_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    value <- read.csv(file.path(cfg$evidence, "uncertainty_decomposition.csv"),
      stringsAsFactors = FALSE)
    value$id <- cfg$id; value$fold <- cfg$window$fold; value$chain <- cfg$chain
    value$tau_multiplier <- cfg$tau_multiplier
    value$slab_multiplier <- cfg$slab_multiplier
    value$prior_id <- cfg$candidate$prior_id
    value$config_path <- cfg$path
    value
  })
  do.call(rbind, rows)
}

ifu9_select_priors <- function(results, uncertainty, parent_tau) {
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  path <- uncertainty[uncertainty$estimator == "current_recursive" &
    uncertainty$metric == "forecast_mae", ]
  keys <- unique(mae[c("tau_multiplier", "slab_multiplier", "prior_id")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    take <- abs(mae$tau_multiplier - key$tau_multiplier) < 1e-12 &
      abs(mae$slab_multiplier - key$slab_multiplier) < 1e-12
    take_check <- abs(check$tau_multiplier - key$tau_multiplier) < 1e-12 &
      abs(check$slab_multiplier - key$slab_multiplier) < 1e-12
    take_path <- abs(path$tau_multiplier - key$tau_multiplier) < 1e-12 &
      abs(path$slab_multiplier - key$slab_multiplier) < 1e-12
    m <- mae[take, ]; c <- check[take_check, ]; u <- path[take_path, ]
    data.frame(key, forecast_mae = mean(m$mean), worst_fold_mae = max(m$mean),
      forecast_mae_width = mean(m$upper - m$lower),
      forecast_check_loss = mean(c$mean),
      interval_score = mean(u$mean_interval_score),
      pointwise_interval_width = mean(u$pointwise_interval_width),
      folds = length(unique(m$fold)), stringsAsFactors = FALSE)
  })
  rank <- do.call(rbind, rows)
  eligible <- rank[rank$forecast_mae <= 1.10 * min(rank$forecast_mae), , drop = FALSE]
  fields <- c("forecast_mae", "forecast_mae_width", "interval_score")
  scaled <- sapply(fields, function(field) eligible[[field]] / min(eligible[[field]]))
  eligible$composite <- scaled[, 1L] + .75 * scaled[, 2L] +
    .25 * scaled[, 3L]
  eligible <- eligible[order(eligible$composite, eligible$forecast_mae,
    eligible$forecast_mae_width), ]
  best <- eligible[1L, , drop = FALSE]
  anchor <- rank[abs(rank$tau_multiplier - parent_tau) < 1e-12 &
    abs(rank$slab_multiplier - 1) < 1e-12, , drop = FALSE]
  chosen <- unique(c(best$prior_id, anchor$prior_id))
  if (length(chosen) < 2L)
    chosen <- unique(c(chosen, eligible$prior_id[eligible$prior_id != chosen[1L]][1L]))
  rank$selected <- rank$prior_id %in% head(chosen, 2L)
  rank$selection_rule <- ifelse(rank$selected,
    "best_multiobjective_plus_v8_parent_anchor", "not_selected")
  list(rank = rank[order(rank$forecast_mae, rank$forecast_mae_width), ],
    selected = rank[rank$selected, c("tau_multiplier", "slab_multiplier",
      "prior_id"), drop = FALSE])
}

ifu9_plan_attribution <- function(state, run) {
  parent <- read.csv(file.path(state$parent_run, "plans", "confirmation.csv"),
    stringsAsFactors = FALSE)
  parent <- parent[abs(parent$tau_multiplier - state$parent_best_tau) < 1e-12,
    , drop = FALSE]
  stopifnot(nrow(parent) == 6L)
  ifu9_plan(state, lapply(seq_len(nrow(parent)), function(i)
    ifu9_attribution_config(state, parent[i, , drop = FALSE])), "attribution")
}

ifu9_plan_warm <- function(state) {
  configs <- list()
  panel <- do.call(rbind, lapply(state$panel, as.data.frame))
  for (i in seq_len(nrow(panel))) for (fold in c("S1", "S3"))
    configs[[length(configs) + 1L]] <- ifu9_config(state, "warm", "quantile_vb",
      fold, panel$tau_multiplier[i], panel$slab_multiplier[i])
  ifu9_plan(state, configs, "warm")
}

ifu9_plan_discovery <- function(state, run) {
  warm <- read.csv(file.path(run, "plans", "warm.csv"), stringsAsFactors = FALSE)
  configs <- lapply(seq_len(nrow(warm)), function(i) ifu9_config(state,
    "discovery", "quantile_mcmc", warm$fold[i], warm$tau_multiplier[i],
    warm$slab_multiplier[i], 1L, file.path(run, "evidence", warm$id[i],
      "mcmc_initializer.json")))
  ifu9_plan(state, configs, "discovery")
}

ifu9_plan_confirm_warm <- function(state, run) {
  selection <- ifu9_select_priors(ifu9_results(run, "discovery"),
    ifu9_uncertainty_results(run, "discovery"), state$parent_best_tau)
  iqt12_csv(selection$rank, file.path(run, "summaries", "discovery_prior_rank.csv"))
  iqt12_csv(selection$selected,
    file.path(run, "selections", "discovery_to_confirmation.csv"))
  configs <- list()
  for (i in seq_len(nrow(selection$selected))) for (fold in c("S2", "S4"))
    configs[[length(configs) + 1L]] <- ifu9_config(state, "confirm_warm",
      "quantile_vb", fold, selection$selected$tau_multiplier[i],
      selection$selected$slab_multiplier[i])
  ifu9_plan(state, configs, "confirm_warm")
}

ifu9_plan_confirmation <- function(state, run) {
  warm <- read.csv(file.path(run, "plans", "confirm_warm.csv"),
    stringsAsFactors = FALSE)
  configs <- list()
  for (i in seq_len(nrow(warm))) for (chain in 1:3)
    configs[[length(configs) + 1L]] <- ifu9_config(state, "confirmation",
      "quantile_mcmc", warm$fold[i], warm$tau_multiplier[i],
      warm$slab_multiplier[i], chain, file.path(run, "evidence", warm$id[i],
        "mcmc_initializer.json"))
  ifu9_plan(state, configs, "confirmation")
}

ifu9_confirmation_table <- function(run) {
  results <- ifu9_results(run, "confirmation")
  uncertainty <- ifu9_uncertainty_results(run, "confirmation")
  baseline <- read.csv(file.path(run, "references", "dqlm_baseline_scores.csv"),
    stringsAsFactors = FALSE)
  baseline <- baseline[baseline$source_stage == "mcmc", ]
  baseline_mae <- baseline[baseline$metric == "forecast_mae", ]
  baseline_check <- baseline[baseline$metric == "forecast_check_loss", ]
  parent <- read.csv(file.path(run, "references",
    "v8_confirmation_decision_table.csv"), stringsAsFactors = FALSE)[1L, ]
  keys <- unique(results[c("tau_multiplier", "slab_multiplier", "prior_id")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    take <- results$prior_id == key$prior_id
    mae <- results[take & results$metric == "forecast_mae", ]
    check <- results[take & results$metric == "forecast_check_loss", ]
    path <- uncertainty[uncertainty$prior_id == key$prior_id &
      uncertainty$estimator == "current_recursive" &
      uncertainty$metric == "forecast_mae", ]
    fold_means <- aggregate(mean ~ fold, mae, mean)
    baseline_fold <- aggregate(mean ~ fold, baseline_mae, mean)
    names(baseline_fold)[2L] <- "baseline"
    fold_means <- merge(fold_means, baseline_fold, by = "fold")
    width <- mean(mae$upper - mae$lower)
    denominator <- parent$v7_forecast_mae_width -
      mean(baseline_mae$upper - baseline_mae$lower)
    data.frame(key,
      qdesn_forecast_mae = mean(mae$mean),
      dqlm_forecast_mae = mean(baseline_mae$mean),
      ratio_to_dqlm = mean(mae$mean) / mean(baseline_mae$mean),
      worst_fold_ratio = max(fold_means$mean / fold_means$baseline),
      forecast_mae_width = width,
      dqlm_forecast_mae_width = mean(baseline_mae$upper - baseline_mae$lower),
      v8_forecast_mae = parent$qdesn_forecast_mae,
      v8_forecast_mae_width = parent$forecast_mae_width,
      v7_forecast_mae_width = parent$v7_forecast_mae_width,
      excess_width_gap_closed = if (denominator > 0)
        (parent$v7_forecast_mae_width - width) / denominator else NA_real_,
      forecast_check_loss = mean(check$mean),
      v8_forecast_check_loss = parent$forecast_check_loss,
      interval_score = mean(path$mean_interval_score),
      v8_interval_score = parent$interval_score,
      chains = nrow(mae), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out$metric_rescue <- with(out, ratio_to_dqlm <= 1.10 &
    worst_fold_ratio <= 1.20 &
    qdesn_forecast_mae <= 1.02 * v8_forecast_mae &
    forecast_mae_width < v8_forecast_mae_width &
    forecast_check_loss <= 1.02 * v8_forecast_check_loss &
    interval_score <= 1.02 * v8_interval_score)
  out$full_closure <- out$metric_rescue & out$excess_width_gap_closed >= 0.50
  out[order(!out$full_closure, !out$metric_rescue, out$ratio_to_dqlm,
    out$forecast_mae_width), ]
}

ifu9_closeout <- function(run) {
  health <- ifu9_health(run)
  stopifnot(all(health$complete == health$planned), all(health$failed == 0L),
    all(health$running == 0L), all(health$pending == 0L))
  comparison <- ifu9_confirmation_table(run)
  iqt12_csv(comparison, file.path(run, "review", "confirmation_decision_table.csv"))
  decision <- if (any(comparison$full_closure))
    "RHS_UNCERTAINTY_RESCUE_CONFIRMED_PREPARE_CELLWISE_PROPAGATION" else
    if (any(comparison$metric_rescue))
      "PARTIAL_RHS_RESCUE_PREPARE_LOCAL_REPRESENTATION_FALLBACK" else
      "RHS_RESCUE_INSUFFICIENT_PREPARE_LOCAL_REPRESENTATION_FALLBACK"
  attribution_plan <- read.csv(file.path(run, "plans", "attribution.csv"),
    stringsAsFactors = FALSE)
  attribution <- do.call(rbind, lapply(attribution_plan$config_path, function(path) {
    cfg <- iqt12_read(path)
    read.csv(file.path(cfg$evidence, "first_step_block_attribution.csv"),
      stringsAsFactors = FALSE)
  }))
  iqt12_csv(aggregate(cbind(mean_origin_sd, max_origin_sd,
      mean_absolute_contribution, mean_covariance_share) ~ block,
    attribution, mean), file.path(run, "review", "beta_block_attribution_summary.csv"))
  closeout <- list(schema = ifu9_schema, status = "COMPLETE_REVIEW_REQUIRED",
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

ifu9_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  if (finished == "smoke") return(ifu9_plan_attribution(state, run))
  if (finished == "attribution") return(ifu9_plan_warm(state))
  if (finished == "warm") return(ifu9_plan_discovery(state, run))
  if (finished == "discovery") return(ifu9_plan_confirm_warm(state, run))
  if (finished == "confirm_warm") return(ifu9_plan_confirmation(state, run))
  if (finished == "confirmation") return(ifu9_closeout(run))
  stop("Unknown completed stage: ", finished)
}

ifu9_resources <- itm6_resources
