idol_v2_repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
source(file.path(
  idol_v2_repo_root, "validation", "fitforecast_v2", "R",
  "independent_dynamic_location_capacity_tau0_v1.R"
))

idol_v2_stage <-
  "qdesn_dynamic_fitforecast_v2_500obs_location_orthogonalized_tau0_v2"
idol_v2_schema <- "independent_location_orthogonalized_tau0_v2_job_v1"
idol_v2_branch <-
  "validation/independent-location-orthogonalized-tau0-v2-1.0.0"
idol_v2_config_stem <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_location_orthogonalized_tau0_v2"
)
idol_v2_reconstruction_tolerance <- 1e-6
idol_v2_max_effective_dimension <- 400L
idol_v2_metric_values <- idlc_v1_metric_values
idol_v2_promotion_metrics <- c(
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)

idol_v2_read_targets <- function(repo_root) {
  path <- file.path(repo_root, paste0(idol_v2_config_stem, "_target_cells.csv"))
  x <- qdesn_ssv2_read_csv(path)
  expected <- c("al_normal_t0p05", "al_normal_t0p50", "exal_normal_t0p50")
  if (nrow(x) != 3L || !setequal(x$target_cell_id, expected) ||
      anyDuplicated(x$target_cell_id) || !all(x$family == "normal")) {
    stop("The V2 target-cell contract has drifted.", call. = FALSE)
  }
  x$objective_current_value <- vapply(seq_len(nrow(x)), function(i) {
    as.numeric(x[[paste0("current_", x$objective_metric[[i]])]][[i]])
  }, numeric(1L))
  x$objective_comparator_value <- vapply(seq_len(nrow(x)), function(i) {
    as.numeric(x[[paste0("comparator_", x$objective_metric[[i]])]][[i]])
  }, numeric(1L))
  for (i in seq_len(nrow(x))) {
    request <- file.path(repo_root, x$parent_request_path[[i]])
    if (!file.exists(request) ||
        !identical(qdesn_ssv2_sha256(request), x$parent_request_sha256[[i]])) {
      stop("Parent request hash failed for ", x$target_cell_id[[i]], call. = FALSE)
    }
  }
  x
}

idol_v2_read_arms <- function(repo_root) {
  x <- qdesn_ssv2_read_csv(file.path(
    repo_root, paste0(idol_v2_config_stem, "_transform_arms.csv")
  ))
  expected <- c("C0_parent", "O1_orthogonalized", "O2_orthogonalized_svd")
  if (nrow(x) != 3L || !identical(x$transform_arm, expected) ||
      anyDuplicated(x$transform_mode)) {
    stop("The V2 readout-transform arm contract has drifted.", call. = FALSE)
  }
  x
}

idol_v2_read_ladder <- function(repo_root) {
  x <- qdesn_ssv2_read_csv(file.path(
    repo_root, paste0(idol_v2_config_stem, "_tau0_ladder.csv")
  ))
  targets <- idol_v2_read_targets(repo_root)$target_cell_id
  if (nrow(x) != 15L || any(!is.finite(x$tau0)) || any(x$tau0 <= 0) ||
      !setequal(x$target_cell_id, targets) ||
      any(table(x$target_cell_id) != 5L) ||
      anyDuplicated(paste(x$target_cell_id, format(x$tau0, digits = 17)))) {
    stop("The V2 cell-specific tau0 ladder contract has drifted.", call. = FALSE)
  }
  x
}

idol_v2_transform_spec <- function(row) {
  list(
    mode = as.character(row$transform_mode[[1L]]),
    deterministic_prefix = as.character(row$deterministic_prefix[[1L]]),
    projection_ridge = as.numeric(row$projection_ridge[[1L]]),
    svd_energy_threshold = as.numeric(row$svd_energy_threshold[[1L]]),
    svd_min_rank = as.integer(row$svd_min_rank[[1L]]),
    svd_max_rank = as.integer(row$svd_max_rank[[1L]])
  )
}

idol_v2_exact_signature <- function(row, method_id) {
  paste(
    row$target_cell_id[[1L]], row$likelihood_target[[1L]], row$family[[1L]],
    sprintf("%.8f", row$tau[[1L]]), row$profile_signature[[1L]],
    row$transform_mode[[1L]], row$deterministic_prefix[[1L]],
    format(row$projection_ridge[[1L]], scientific = TRUE),
    format(row$svd_energy_threshold[[1L]], digits = 8),
    row$svd_max_rank[[1L]], method_id, sep = "||"
  )
}

idol_v2_build_candidates <- function(repo_root) {
  targets <- idol_v2_read_targets(repo_root)
  arms <- idol_v2_read_arms(repo_root)
  ladder <- idol_v2_read_ladder(repo_root)
  rows <- list()
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, , drop = FALSE]
    request <- qdesn_ssv2_read_json(file.path(
      repo_root, target$parent_request_path[[1L]]
    ))
    parent <- idlc_v1_profile_from_request(request, profile_role = "C0_parent")
    for (j in seq_len(nrow(arms))) {
      arm <- arms[j, , drop = FALSE]
      tau_rows <- if (arm$transform_arm[[1L]] == "C0_parent") {
        data.frame(
          target_cell_id = target$target_cell_id[[1L]],
          tau0 = as.numeric(target$parent_tau0[[1L]]),
          ladder_role = "authority_control", rationale = "matched authority control",
          stringsAsFactors = FALSE
        )
      } else ladder[ladder$target_cell_id == target$target_cell_id[[1L]], , drop = FALSE]
      for (h in seq_len(nrow(tau_rows))) {
        z <- parent
        z$rhs_tau0 <- as.numeric(tau_rows$tau0[[h]])
        z$profile_signature <- qdesn_ssv2_profile_signature(z)
        z$selection_arm <- arm$transform_arm[[1L]]
        z$design_role <- arm$design_role[[1L]]
        z$transform_mode <- arm$transform_mode[[1L]]
        z$deterministic_prefix <- arm$deterministic_prefix[[1L]]
        z$projection_ridge <- as.numeric(arm$projection_ridge[[1L]])
        z$svd_energy_threshold <- as.numeric(arm$svd_energy_threshold[[1L]])
        z$svd_min_rank <- as.integer(arm$svd_min_rank[[1L]])
        z$svd_max_rank <- as.integer(arm$svd_max_rank[[1L]])
        z$target_cell_id <- target$target_cell_id[[1L]]
        z$family <- target$family[[1L]]
        z$tau <- as.numeric(target$tau[[1L]])
        z$priority <- target$tier[[1L]]
        z$objective_metric <- target$objective_metric[[1L]]
        z$current_value <- target$objective_current_value[[1L]]
        z$comparator_value <- target$objective_comparator_value[[1L]]
        z$parent_anchor_id <- basename(target$parent_request_path[[1L]])
        z$likelihood_target <- target$likelihood_target[[1L]]
        z$target_metrics <- target$target_metrics[[1L]]
        z$tau0_ladder_role <- tau_rows$ladder_role[[h]]
        z$declared_replay <- arm$transform_arm[[1L]] == "C0_parent"
        method <- if (z$likelihood_target[[1L]] == "exal") {
          qdesn_ssv2_method_id
        } else "sigma_then_gamma"
        z$exact_signature <- idol_v2_exact_signature(z, method)
        hash <- digest::digest(z$exact_signature, algo = "sha256", serialize = FALSE)
        z$candidate_id <- sprintf(
          "idol2_%s_%s_%s_%s", z$target_cell_id[[1L]],
          tolower(z$selection_arm[[1L]]),
          gsub("[^0-9a-z]", "", format(z$rhs_tau0[[1L]], scientific = TRUE)),
          substr(hash, 1L, 10L)
        )
        z$screening_profile_id <- z$candidate_id
        rows[[length(rows) + 1L]] <- z
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (nrow(out) != 33L || any(table(out$target_cell_id) != 11L) ||
      anyDuplicated(out$candidate_id) || anyDuplicated(out$exact_signature) ||
      any(table(out$selection_arm) != c(3L, 15L, 15L))) {
    stop("The 33-candidate V2 contract failed.", call. = FALSE)
  }
  out
}

idol_v2_nonrepeat_audit <- function(candidates, history) {
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    z <- candidates[i, , drop = FALSE]
    old_match <- history$profile_signature == z$profile_signature[[1L]] &
      history$target_cell_id == z$target_cell_id[[1L]]
    transform_new <- z$transform_mode[[1L]] != "none"
    duplicate <- any(old_match) && !transform_new
    permitted <- !duplicate || isTRUE(z$declared_replay[[1L]])
    data.frame(
      candidate_id = z$candidate_id, target_cell_id = z$target_cell_id,
      transform_mode = z$transform_mode, rhs_tau0 = z$rhs_tau0,
      old_profile_match = any(old_match), transform_is_new = transform_new,
      declared_replay = z$declared_replay,
      decision = if (permitted) "PASS" else "FAIL_UNDECLARED_DUPLICATE",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

idol_v2_budget <- function(stage) {
  switch(stage,
    smoke = list(n_burn = 4L, n_mcmc = 8L, draws = 8L),
    initial_replication = list(n_burn = 2500L, n_mcmc = 7500L, draws = 160L),
    screen = list(n_burn = 1000L, n_mcmc = 4000L, draws = 120L),
    replication = list(n_burn = 2500L, n_mcmc = 7500L, draws = 160L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, draws = 200L),
    stop("Unknown V2 stage: ", stage, call. = FALSE)
  )
}

idol_v2_timeout_seconds <- function(stage) {
  switch(stage, smoke = 3600L, screen = 259200L,
         initial_replication = 432000L, replication = 432000L,
         confirmation = 604800L,
         stop("Unknown V2 stage: ", stage, call. = FALSE))
}

idol_v2_make_job <- function(repo_root, profile, target, source, stage,
                             source_registry_path, chain_id = 1L,
                             reservoir_seed_id = "screen_r01") {
  base_stage <- if (stage == "initial_replication") "replication" else stage
  job <- idlc_v1_make_job(
    repo_root, profile, target, source, base_stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job$schema_version <- idol_v2_schema
  job$stage <- stage
  job$profile$transform_mode <- profile$transform_mode[[1L]]
  job$profile$deterministic_prefix <- profile$deterministic_prefix[[1L]]
  job$profile$projection_ridge <- as.numeric(profile$projection_ridge[[1L]])
  job$profile$svd_energy_threshold <- as.numeric(profile$svd_energy_threshold[[1L]])
  job$profile$svd_min_rank <- as.integer(profile$svd_min_rank[[1L]])
  job$profile$svd_max_rank <- as.integer(profile$svd_max_rank[[1L]])
  job$config$readout$linear_transform <- idol_v2_transform_spec(profile)
  budget <- idol_v2_budget(stage)
  job$config$inference$mcmc$n_burn <- budget$n_burn
  job$config$inference$mcmc$n_mcmc <- budget$n_mcmc
  job$config$metrics$posterior_metric_draws <- budget$draws
  job$config$metrics$posterior_metric_intervals$draws <- budget$draws
  job$config$sampling$nd_draws <- budget$draws
  job$config$sampling$chunk <- min(120L, budget$draws)
  job$config$synthesis$n_samp <- budget$draws
  job$config$validation$timeout_seconds <- idol_v2_timeout_seconds(stage)
  job$config$outputs$retention_profile <-
    "storage_light_location_orthogonalized_tau0_v2"
  job$job_id <- paste(
    stage, profile$candidate_id[[1L]], "canonical_article", reservoir_seed_id,
    sprintf("c%02d", chain_id), sep = "__"
  )
  job$spec_id <- paste0("independent_location_orthogonalized_tau0_v2__", job$job_id)
  job$config$validation_spec_id <- job$spec_id
  job$root_spec$root_id <- job$job_id
  job$root_spec$screening_stage <- idol_v2_stage
  job$root_spec$screening_wave <- stage
  job$root_spec$readout_transform_mode <- profile$transform_mode[[1L]]
  job$root_spec$readout_transform_signature <- profile$exact_signature[[1L]]
  job$study_contract$validation_stage <- idol_v2_stage
  job$study_contract$readout_transform_training_only <- TRUE
  job$study_contract$readout_transform_forecast_consistent <- TRUE
  job$study_contract$case_specific_tau0 <- TRUE
  job$study_contract$global_specification_required <- FALSE
  job$study_contract$diagnostics_are_promotion_veto <- FALSE
  job$study_contract$promotion_tolerance <- idol_v2_reconstruction_tolerance
  job$study_contract$posterior_recycled_as_prior <- FALSE
  job$config$cpp$use_postpred <- FALSE
  job$config$cpp$postpred_omp <- FALSE
  job$config$cpp$postpred_threads <- 1L
  job
}

idol_v2_apply_seeds <- function(job) {
  key <- paste(idol_v2_stage, job$stage, job$target_cell_id,
               job$candidate_id, job$reservoir_seed_id, job$chain_id, sep = "|")
  job$config$desn$seed <- qdesn_cgcv2_seed(key, "desn")
  job$config$inference$mcmc$control$seed <- qdesn_cgcv2_seed(key, "mcmc")
  job$config$inference$mcmc$control$rng_seed <- qdesn_cgcv2_seed(key, "rng")
  job$config$inference$mcmc$vb_warm_start_seed <- qdesn_cgcv2_seed(key, "vb")
  job$config$synthesis$seed <- qdesn_cgcv2_seed(key, "synthesis")
  job$root_spec$desn_seed <- job$config$desn$seed
  job$root_spec$mcmc_seed <- job$config$inference$mcmc$control$seed
  job$root_spec$mcmc_rng_seed <- job$config$inference$mcmc$control$rng_seed
  job$root_spec$vb_warm_start_seed <- job$config$inference$mcmc$vb_warm_start_seed
  job$root_spec$synthesis_seed <- job$config$synthesis$seed
  job
}

idol_v2_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_ssv2_path(repo_root, "results", "qdesn_mcmc_validation",
                  idol_v2_stage, run_tag, "jobs", job_id)
}

idol_v2_required_diagnostic_paths <- function(job_root) {
  c(
    idlc_v1_required_diagnostic_paths(job_root),
    file.path(job_root, "tables", "design_conditioning_diagnostics.csv"),
    file.path(job_root, "tables", "readout_linear_transform_diagnostics.csv")
  )
}

idol_v2_write_design_diagnostics <- function(job, observed_path, job_root) {
  cfg <- job$config
  observed <- qdesn_ssv2_read_csv(observed_path)
  n_train <- as.integer(cfg$split$train_n)
  x_names <- as.character(unlist(cfg$columns$x, use.names = FALSE))
  X <- if (length(x_names)) as.matrix(observed[, x_names, drop = FALSE]) else NULL
  scaled <- qdesn_ttav2_scale_train_only(observed$y, X, n_train)
  d <- cfg$desn
  D <- as.integer(d$D)
  d$n <- rep(as.integer(unlist(d$n, use.names = FALSE)), length.out = D)
  d$n_tilde <- if (D > 1L) as.integer(unlist(d$n_tilde, use.names = FALSE)) else integer()
  allowed <- c("D", "n", "n_tilde", "m", "alpha", "rho", "act_f", "act_k",
               "pi_w", "pi_in", "washout", "add_bias", "seed")
  readout <- ms_build_readout_design_real(
    y_full = scaled$y, X_use = scaled$X, cfg = cfg,
    desn_args = d[intersect(names(d), allowed)],
    readout_include_input = isTRUE(cfg$readout$include_input),
    readout_reservoir_lags = as.integer(cfg$readout$reservoir_lags),
    readout_scale = isTRUE(cfg$inference$readout_scale),
    readout_input_mode = cfg$readout$input_mode,
    readout_decomposition = cfg$decomposition
  )
  raw_start <- as.integer(job$root_spec$raw_start_source_index)
  effective_start <- as.integer(job$root_spec$train_start_source_index) - raw_start + 1L
  effective_end <- as.integer(job$root_spec$train_end_source_index) - raw_start + 1L
  train_idx <- readout$keep_aug_abs >= effective_start &
    readout$keep_aug_abs <= effective_end
  forecast_idx <- readout$keep_aug_abs > effective_end
  train_raw <- readout$X_aug_all[train_idx, , drop = FALSE]
  forecast_raw <- readout$X_aug_all[forecast_idx, , drop = FALSE]
  transform_fit <- readout_linear_transform_fit(
    train_raw, cfg$readout$linear_transform,
    p_res = ncol(readout$X_res_all), has_intercept = isTRUE(d$add_bias)
  )
  train_design <- transform_fit$X
  forecast_design <- readout_linear_transform_apply(
    forecast_raw, transform_fit$transform
  )
  diag <- qdesn_ttav2_matrix_diagnostics(
    train_design, forecast_design,
    readout$X_res_all[train_idx, , drop = FALSE],
    readout$X_res_all[forecast_idx, , drop = FALSE]
  )
  diag$job_id <- job$job_id
  diag$target_cell_id <- job$target_cell_id
  diag$candidate_id <- job$candidate_id
  diag$profile_role <- job$profile$selection_arm
  diag$transform_mode <- job$profile$transform_mode
  diag$rhs_tau0 <- as.numeric(job$profile$rhs_tau0)
  diag$raw_readout_dimension <- ncol(train_raw)
  diag$transformed_readout_dimension <- ncol(train_design)
  qdesn_ssv2_write_csv(diag, file.path(
    job_root, "tables", "design_conditioning_diagnostics.csv"
  ))
  info <- transform_fit$transform
  transform_diag <- data.frame(
    job_id = job$job_id, target_cell_id = job$target_cell_id,
    candidate_id = job$candidate_id, transform_mode = info$mode,
    active = isTRUE(info$active), input_dimension = as.integer(info$input_dimension),
    output_dimension = as.integer(info$output_dimension),
    selected_rank = as.integer(info$selected_rank %||% NA_integer_),
    projection_r2_median = as.numeric(info$reservoir_projection_r2_median %||% NA_real_),
    projection_r2_max = as.numeric(info$reservoir_projection_r2_max %||% NA_real_),
    projection_fitted_frobenius = as.numeric(info$projection_fitted_frobenius %||% NA_real_),
    residual_frobenius = as.numeric(info$residual_frobenius %||% NA_real_),
    training_rows = nrow(train_design), forecast_rows = nrow(forecast_design),
    finite = all(is.finite(train_design)) && all(is.finite(forecast_design)),
    stringsAsFactors = FALSE
  )
  qdesn_ssv2_write_csv(transform_diag, file.path(
    job_root, "tables", "readout_linear_transform_diagnostics.csv"
  ))
}

idol_v2_collect_result <- function(repo_root, run_tag, plan_row) {
  root <- idol_v2_job_root(repo_root, run_tag, plan_row$job_id[[1L]])
  status_path <- file.path(root, "job_status.json")
  status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
    list(status = "MISSING")
  values <- idlc_v1_metric_values(root)
  data.frame(
    job_id = plan_row$job_id[[1L]], stage = plan_row$stage[[1L]],
    target_cell_id = plan_row$target_cell_id[[1L]],
    likelihood_target = plan_row$likelihood_target[[1L]],
    candidate_id = plan_row$candidate_id[[1L]],
    profile_role = plan_row$profile_role[[1L]],
    transform_mode = plan_row$transform_mode[[1L]],
    rhs_tau0 = plan_row$rhs_tau0[[1L]], chain_id = plan_row$chain_id[[1L]],
    reservoir_seed_id = plan_row$reservoir_seed_id[[1L]],
    status = as.character(status$status),
    fit_qtrue_rmse = values[["fit_qtrue_rmse"]],
    forecast_qtrue_mae_H1000 = values[["forecast_qtrue_mae_H1000"]],
    forecast_check_loss_H1000 = values[["forecast_check_loss_H1000"]],
    metric_interval_summary_path = file.path(root, "tables", "metric_interval_summary.csv"),
    transform_diagnostics_path = file.path(
      root, "tables", "readout_linear_transform_diagnostics.csv"
    ),
    common_shift_effects_path = file.path(
      root, "tables", "common_shift_intervention_effects.csv"
    ),
    origin_horizon_reconstruction_path = file.path(
      root, "tables", "origin_horizon_reconstruction_audit.csv"
    ),
    design_conditioning_path = file.path(
      root, "tables", "design_conditioning_diagnostics.csv"
    ),
    binary_payloads_remaining = as.integer(
      status$binary_payloads_remaining %||% NA_integer_
    ), stringsAsFactors = FALSE
  )
}

idol_v2_plan_row <- function(job, config_path) {
  data.frame(
    job_id = job$job_id, stage = job$stage,
    target_cell_id = job$target_cell_id,
    likelihood_target = job$likelihood_target,
    candidate_id = job$candidate_id,
    profile_role = job$profile$selection_arm,
    transform_mode = job$profile$transform_mode,
    rhs_tau0 = as.numeric(job$profile$rhs_tau0),
    chain_id = as.integer(job$chain_id), reservoir_seed_id = job$reservoir_seed_id,
    source_id = job$source_id,
    target_metrics = paste(job$target_metrics, collapse = ";"),
    objective_metric = job$objective_metric,
    current_value = job$current_value, comparator_value = job$comparator_value,
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    expected_metric_draws = job$config$metrics$posterior_metric_intervals$draws,
    timeout_seconds = job$config$validation$timeout_seconds,
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = qdesn_ssv2_sha256(config_path), stringsAsFactors = FALSE
  )
}
