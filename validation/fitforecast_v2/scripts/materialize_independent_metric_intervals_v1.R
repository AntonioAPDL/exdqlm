#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_metric_intervals_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

suppressPackageStartupMessages({
  if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required.", call. = FALSE)
})

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
run_id <- as.character(args$`run-id` %||%
  paste0("independent_metric_intervals_v1_", format(Sys.time(), "%Y%m%d_%H%M%S")))[1L]
smoke <- ffv2_truthy(args$smoke %||% FALSE)
campaign_schema <- as.character(args$schema %||% imi_v1_schema)[1L]
campaign_stage <- as.character(args$stage %||% imi_v1_stage)[1L]
campaign_authority_id <- as.character(args$`authority-id` %||% imi_v1_authority_id)[1L]
campaign_package_version <- as.character(args$`package-version` %||% as.character(packageVersion("exdqlm")))[1L]
campaign_package_commit <- as.character(args$`package-source-commit` %||% "")[1L]
campaign_package_tarball_sha256 <- as.character(args$`package-tarball-sha256` %||% "")[1L]
campaign_seed_ledger_path <- as.character(args$`seed-ledger` %||% "")[1L]
campaign_seed_ledger <- if (nzchar(campaign_seed_ledger_path)) {
  ffv2_read_csv(ffv2_resolve_path(campaign_seed_ledger_path, repo_root = repo_root,
                                  must_work = TRUE))
} else NULL
workers <- as.integer(args$workers %||% if (smoke) 4L else imi_v1_workers)[1L]
if (!is.finite(workers) || workers < 1L || workers > 20L) {
  stop("--workers must be between 1 and 20.", call. = FALSE)
}
state_root <- ffv2_resolve_path(args$`state-root` %||% imi_v1_state_root(repo_root, run_id),
                                repo_root = repo_root, must_work = FALSE)
if (dir.exists(state_root)) {
  stop(sprintf("State root already exists; refusing to overwrite: %s", state_root),
       call. = FALSE)
}
dirs <- file.path(state_root, c(
  "materialization", "configs", "logs", "status", "sources", "manifests", "health",
  "closeout"
))
invisible(lapply(dirs, ffv2_ensure_dir))

rel_or_abs <- function(path) {
  path <- as.character(path)[1L]
  if (startsWith(path, "/")) path else file.path(repo_root, path)
}

audit <- imi_v1_static_audit(repo_root, authority_id = campaign_authority_id)
if (!all(audit$checks$pass)) {
  stop(sprintf("Static authority audit failed: %s",
               paste(audit$checks$check[!audit$checks$pass], collapse = ", ")),
       call. = FALSE)
}
materialization_root <- file.path(state_root, "materialization")
ffv2_write_csv(audit$metric_roles, file.path(materialization_root, "metric_role_ledger.csv"))
ffv2_write_csv(audit$source_registry, file.path(materialization_root, "source_replay_registry.csv"))
ffv2_write_csv(audit$checks, file.path(materialization_root, "static_audit.csv"))

seed_row_for <- function(source_identity, chain_id) {
  if (is.null(campaign_seed_ledger)) return(NULL)
  keep <- campaign_seed_ledger$source_identity == as.character(source_identity) &
    as.integer(campaign_seed_ledger$chain_id) == as.integer(chain_id)
  if (sum(keep) != 1L) {
    stop(sprintf("Frozen seed-ledger join failed for chain %d: %s",
                 chain_id, source_identity), call. = FALSE)
  }
  campaign_seed_ledger[keep, , drop = FALSE]
}

seed_int <- function(row, field, fallback) {
  if (is.null(row) || !field %in% names(row)) return(as.integer(fallback))
  value <- suppressWarnings(as.integer(row[[field]][[1L]]))
  if (is.finite(value) && value > 0L) value else as.integer(fallback)
}

stage_source <- local({
  cache <- new.env(parent = emptyenv())
  function(root_spec, grid_row = NULL) {
    source_path <- as.character(root_spec$source_series_wide_path %||% "")[1L]
    expected_sha <- as.character(root_spec$source_series_wide_sha256 %||% "")[1L]
    if (!is.null(grid_row)) {
      source_path <- as.character(grid_row$source_series_wide_path[[1L]])
      expected_sha <- as.character(grid_row$source_series_wide_sha256[[1L]])
    }
    if (!file.exists(source_path)) {
      stop(sprintf("Frozen source series is missing: %s", source_path), call. = FALSE)
    }
    observed_sha <- ffv2_file_sha256(source_path)
    if (!nzchar(expected_sha) || !identical(observed_sha, expected_sha)) {
      stop(sprintf("Frozen source hash mismatch: %s", source_path), call. = FALSE)
    }
    key <- observed_sha
    if (exists(key, envir = cache, inherits = FALSE)) return(get(key, envir = cache))
    source_dir <- file.path(state_root, "sources", substr(key, 1L, 16L))
    ffv2_ensure_dir(source_dir)
    staged_series <- file.path(source_dir, "series_wide.csv")
    if (!file.copy(source_path, staged_series, overwrite = FALSE, copy.mode = TRUE)) {
      stop(sprintf("Could not stage source series: %s", source_path), call. = FALSE)
    }
    if (!identical(ffv2_file_sha256(staged_series), expected_sha)) {
      stop("Staged source series failed SHA-256 verification.", call. = FALSE)
    }
    source_df <- ffv2_read_csv(staged_series)
    source_index <- if ("source_index" %in% names(source_df)) {
      as.integer(source_df$source_index)
    } else if ("t" %in% names(source_df)) {
      as.integer(source_df$t)
    } else seq_len(nrow(source_df))
    contiguous <- identical(source_index, seq.int(min(source_index), max(source_index)))
    required_window <- all(seq.int(8501L, 10000L) %in% source_index)
    train_rows <- sum(source_index <= 9000L)
    if (!contiguous || !required_window || max(source_index) != 10000L ||
        train_rows < 500L || !"y" %in% names(source_df)) {
      stop(sprintf(
        "Staged Q-DESN source violates its native-context/evaluation contract: %s rows=%d range=%d:%d.",
        source_path, nrow(source_df), min(source_index), max(source_index)
      ), call. = FALSE)
    }
    observed <- data.frame(
      y = as.numeric(source_df$y),
      period90_sin_h1 = sin(2 * pi * source_index / 90),
      period90_cos_h1 = cos(2 * pi * source_index / 90),
      period90_sin_h2 = sin(4 * pi * source_index / 90),
      period90_cos_h2 = cos(4 * pi * source_index / 90),
      period90_trend_z = as.numeric(scale(source_index)),
      stringsAsFactors = FALSE
    )
    observed_path <- file.path(source_dir, "observed.csv")
    ffv2_write_csv(observed, observed_path)
    source_index_path <- file.path(source_dir, "source_index.csv")
    ffv2_write_csv(data.frame(local_index = seq_along(source_index), source_index = source_index),
                   source_index_path)
    out <- list(
      source_path = normalizePath(staged_series, winslash = "/", mustWork = TRUE),
      source_sha256 = expected_sha,
      observed_path = normalizePath(observed_path, winslash = "/", mustWork = TRUE),
      observed_sha256 = ffv2_file_sha256(observed_path),
      source_index_path = normalizePath(source_index_path, winslash = "/", mustWork = TRUE),
      source_index_sha256 = ffv2_file_sha256(source_index_path),
      n_rows = nrow(source_df), train_rows = train_rows,
      raw_start_source_index = min(source_index), raw_end_source_index = max(source_index)
    )
    assign(key, out, envir = cache)
    out
  }
})

qdesn_rows <- audit$source_registry[grepl("^qdesn_", audit$source_registry$model_variant),
                                    , drop = FALSE]
if (smoke) {
  smoke_keys <- c(
    which(qdesn_rows$inference == "vb" & qdesn_rows$model_variant == "qdesn_al_rhs_ns")[1L],
    which(qdesn_rows$inference == "mcmc" & qdesn_rows$model_variant == "qdesn_exal_rhs_ns")[1L]
  )
  qdesn_rows <- qdesn_rows[smoke_keys, , drop = FALSE]
}

job_rows <- list()
job_i <- 0L
for (i in seq_len(nrow(qdesn_rows))) {
  registry_row <- qdesn_rows[i, , drop = FALSE]
  request_path <- rel_or_abs(registry_row$request_path[[1L]])
  if (!file.exists(request_path) ||
      !identical(ffv2_file_sha256(request_path), registry_row$request_sha256[[1L]])) {
    stop(sprintf("Frozen Q-DESN request failed verification: %s", request_path),
         call. = FALSE)
  }
  request <- ffv2_read_json(request_path)
  grid_row <- NULL
  if (identical(registry_row$provenance_kind[[1L]], "tracked_target_registry_and_grid")) {
    grid_path <- rel_or_abs(registry_row$grid_path[[1L]])
    if (!identical(ffv2_file_sha256(grid_path), registry_row$grid_sha256[[1L]])) {
      stop("Frozen Q-DESN grid hash mismatch.", call. = FALSE)
    }
    grid <- ffv2_read_csv(grid_path)
    grid_row <- grid[as.integer(registry_row$grid_row[[1L]]), , drop = FALSE]
  }
  n_chains <- if (smoke) 1L else as.integer(registry_row$planned_chains[[1L]])
  for (chain_id in seq_len(n_chains)) {
    frozen_seed <- seed_row_for(registry_row$source_identity[[1L]], chain_id)
    chain_request_path <- request_path
    chain_request_sha256 <- registry_row$request_sha256[[1L]]
    chain_request <- request
    chain_grid_row <- grid_row
    if (!is.null(frozen_seed) && "request_override_path" %in% names(frozen_seed) &&
        nzchar(as.character(frozen_seed$request_override_path[[1L]]))) {
      chain_request_path <- rel_or_abs(frozen_seed$request_override_path[[1L]])
      chain_request_sha256 <- as.character(frozen_seed$request_override_sha256[[1L]])
      if (!file.exists(chain_request_path) ||
          !identical(ffv2_file_sha256(chain_request_path), chain_request_sha256)) {
        stop(sprintf("Frozen chain-specific request failed verification: %s",
                     chain_request_path), call. = FALSE)
      }
      chain_request <- ffv2_read_json(chain_request_path)
      chain_grid_row <- NULL
    }
    if (!is.null(frozen_seed) && "source_override_path" %in% names(frozen_seed) &&
        nzchar(as.character(frozen_seed$source_override_path[[1L]]))) {
      source_override_path <- rel_or_abs(frozen_seed$source_override_path[[1L]])
      source_override_sha256 <- as.character(frozen_seed$source_override_sha256[[1L]])
      if (!file.exists(source_override_path) ||
          !identical(ffv2_file_sha256(source_override_path), source_override_sha256)) {
        stop(sprintf("Frozen source override failed verification: %s",
                     source_override_path), call. = FALSE)
      }
      chain_request$root_spec$source_series_wide_path <- source_override_path
      chain_request$root_spec$source_series_wide_sha256 <- source_override_sha256
    }
    staged <- stage_source(chain_request$root_spec, chain_grid_row)
    method <- as.character(registry_row$inference[[1L]])
    likelihood <- if (identical(registry_row$model_variant[[1L]], "qdesn_al_rhs_ns")) "al" else "exal"
    job_id <- sprintf("qdesn__%s__c%02d", registry_row$replay_id[[1L]], chain_id)
    job_root <- file.path(
      repo_root, "results", "qdesn_mcmc_validation", campaign_stage, run_id, "jobs", job_id
    )
    config <- chain_request$config
    root_spec <- chain_request$root_spec
    root_spec$root_id <- job_id
    root_spec$scenario <- as.character(root_spec$scenario %||% root_spec$source_scenario)
    root_spec$source_family <- as.character(registry_row$family[[1L]])
    root_spec$tau <- as.numeric(registry_row$tau[[1L]])
    root_spec$likelihood_family <- likelihood
    root_spec$beta_prior_type <- "rhs_ns"
    root_spec$source_series_wide_path <- staged$source_path
    root_spec$source_series_wide_sha256 <- staged$source_sha256
    root_spec$raw_start_source_index <- staged$raw_start_source_index
    root_spec$raw_end_source_index <- staged$raw_end_source_index
    root_spec$train_start_source_index <- 8501L
    root_spec$train_end_source_index <- 9000L
    root_spec$forecast_start_source_index <- 9001L
    root_spec$forecast_end_source_index <- 10000L
    root_spec$fit_size <- 500L
    root_spec$effective_fit_size <- 500L
    root_spec$source_total_size <- staged$n_rows
    root_spec$desn_seed <- as.integer(registry_row$reservoir_seed[[1L]])
    root_spec$seed <- root_spec$desn_seed
    root_spec$mcmc_seed <- seed_int(
      frozen_seed, "mcmc_seed",
      imi_v1_seed(run_id, registry_row$replay_id[[1L]], chain_id, "mcmc")
    )
    root_spec$mcmc_rng_seed <- seed_int(
      frozen_seed, "mcmc_rng_seed",
      imi_v1_seed(run_id, registry_row$replay_id[[1L]], chain_id, "rng")
    )
    root_spec$vb_warm_start_seed <- seed_int(
      frozen_seed, "vb_warm_start_seed", imi_v1_seed(registry_row$replay_id[[1L]], "vb_warm")
    )
    root_spec$synthesis_seed <- seed_int(
      frozen_seed, "synthesis_seed",
      imi_v1_seed(run_id, registry_row$replay_id[[1L]], chain_id, "synthesis")
    )
    root_spec$desn_seed <- seed_int(frozen_seed, "desn_seed", root_spec$desn_seed)
    root_spec$seed <- root_spec$desn_seed

    config$pipeline$mode <- "real"
    config$split <- list(use_last = TRUE, T_use = staged$n_rows,
                         train_n = staged$train_rows)
    config$p_vec <- as.numeric(root_spec$tau)
    config$columns <- list(
      y = "y",
      x = c("period90_sin_h1", "period90_cos_h1", "period90_sin_h2",
            "period90_cos_h2", "period90_trend_z")
    )
    config$preproc <- list(scale_y = TRUE, scale_x = TRUE)
    config$desn$seed <- root_spec$desn_seed
    config$inference$method <- method
    config$inference$likelihood_family <- likelihood
    config$outputs$save <- TRUE
    config$outputs$keep_draws <- FALSE
    config$outputs$keep_mcmc_vb_init <- FALSE
    config$outputs$save_forecast_objects <- FALSE
    config$outputs$save_compact_fit_paths <- TRUE
    config$outputs$save_metric_summaries <- TRUE
    config$outputs$retain_full_rds_on_failure <- FALSE
    config$outputs$retention_profile <- "storage_light_metric_intervals_v1"
    interval_draws <- if (smoke) 8L else if (method == "vb") imi_v1_vb_draws else
      imi_v1_mcmc_metric_draws
    config$sampling$nd_draws <- interval_draws
    config$sampling$chunk <- min(250L, interval_draws)
    config$synthesis$n_samp <- interval_draws
    config$synthesis$seed <- root_spec$synthesis_seed
    config$metrics$posterior_metric_draws <- interval_draws
    config$metrics$posterior_metric_intervals <- list(
      enabled = TRUE, required = TRUE, draws = interval_draws,
      chain_id = chain_id,
      estimator_id = "posterior_mean_draw_metric_equal_tailed_95cri_v1",
      draw_source_contract = "conditional_quantile_not_response_predictive"
    )
    config$metrics$rolling_origin$enabled <- TRUE
    config$metrics$rolling_origin$require_lead_export <- TRUE
    config$metrics$rolling_origin$forecast_protocol <- "rolling_origin_no_refit_state_update"
    config$metrics$rolling_origin$refit_per_origin <- FALSE
    config$metrics$rolling_origin$max_lead_configured <- 30L
    config$metrics$rolling_origin$origin_stride <- 30L
    config$validation$timeout_seconds <- if (smoke) 3600L else 1209600L
    config$validation$timeout_kill_after_seconds <- 60L
    if (method == "vb") {
      config$inference$vb$max_iter <- if (smoke) 5L else
        max(300L, as.integer(config$inference$vb$max_iter %||% 0L))
      config$inference$vb$min_iter_elbo <- if (smoke) 2L else
        max(40L, as.integer(config$inference$vb$min_iter_elbo %||% 0L))
      config$inference$vb$n_samp_xi <- if (smoke) 20L else
        max(500L, as.integer(config$inference$vb$n_samp_xi %||% 0L))
      config$inference$vb$progress_every <- if (smoke) 1L else 50L
      if (likelihood == "exal") {
        config$inference$vb$sigmagam <- list(
          factorization = "structured",
          structured_grid_size = 151L,
          structured_span_sd = 6,
          freeze_warmup_iters = 10L,
          force_after_warmup = TRUE,
          postwarmup_damping = 0.6,
          postwarmup_damping_iters = 5L,
          min_postwarmup_updates = 1L
        )
      }
    } else {
      n_burn <- if (smoke) 4L else 5000L
      n_mcmc <- if (smoke) 8L else 20000L
      config$inference$mcmc$n_burn <- n_burn
      config$inference$mcmc$n_mcmc <- n_mcmc
      config$inference$mcmc$thin <- 1L
      config$inference$mcmc$progress_every <- if (smoke) 1L else 50L
      config$inference$mcmc$control$seed <- root_spec$mcmc_seed
      config$inference$mcmc$control$rng_seed <- root_spec$mcmc_rng_seed
      config$inference$mcmc$vb_warm_start_seed <- root_spec$vb_warm_start_seed
      config$inference$mcmc$prior_overrides$rhs_ns$n_burn <- n_burn
      config$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- n_mcmc
      config$inference$mcmc$prior_overrides$rhs_ns$progress_every <-
        if (smoke) 1L else 50L
      if (likelihood == "exal") {
        config$inference$mcmc$slice$core_update_mode <- "m0_v_collapsed_support_logit"
      }
    }
    config$desn$seed <- root_spec$desn_seed
    config_path <- file.path(state_root, "configs", paste0(job_id, ".json"))
    job <- list(
      schema_version = campaign_schema,
      run_id = run_id,
      job_id = job_id,
      engine = "qdesn",
      replay_id = registry_row$replay_id[[1L]],
      source_identity = registry_row$source_identity[[1L]],
      model_variant = registry_row$model_variant[[1L]],
      family = registry_row$family[[1L]], tau = registry_row$tau[[1L]],
      inference = method, likelihood_family = likelihood, chain_id = chain_id,
      source_candidate_id = registry_row$source_candidate_id[[1L]],
      source_run_tag = registry_row$source_run_tag[[1L]],
      source_request_path = chain_request_path,
      source_request_sha256 = chain_request_sha256,
      provenance_kind = registry_row$provenance_kind[[1L]],
      observed_path = staged$observed_path,
      observed_sha256 = staged$observed_sha256,
      source_series_path = staged$source_path,
      source_series_sha256 = staged$source_sha256,
      job_root = job_root,
      root_spec = root_spec,
      config = config,
      study_contract = list(
        authority_id = campaign_authority_id,
        package_version = campaign_package_version,
        package_source_commit = campaign_package_commit,
        package_tarball_sha256 = campaign_package_tarball_sha256,
        exal_mcmc_update = if (likelihood == "exal" && method == "mcmc") {
          "m0_v_collapsed_support_logit"
        } else if (likelihood == "al") "gamma_fixed_al" else NA_character_,
        exal_vb_factorization = if (likelihood == "exal" && method == "vb") {
          "structured_qgamma_qsigma_given_gamma"
        } else NA_character_,
        interval_estimand = "posterior_mean_of_draw_specific_metric",
        interval = "equal_tailed_95pct_credible_interval",
        fixed_reservoir_realization = TRUE,
        no_hyperparameter_reselection = TRUE,
        heavy_binary_retained = FALSE
      )
    )
    ffv2_write_json(job, config_path)
    job_i <- job_i + 1L
    job_rows[[job_i]] <- data.frame(
      job_id = job_id, engine = "qdesn", replay_id = registry_row$replay_id[[1L]],
      source_identity = registry_row$source_identity[[1L]],
      model_variant = registry_row$model_variant[[1L]], family = registry_row$family[[1L]],
      tau = registry_row$tau[[1L]], inference = method, chain_id = chain_id,
      config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
      config_sha256 = ffv2_file_sha256(config_path), job_root = job_root,
      expected_draws = interval_draws, status = "PENDING", stringsAsFactors = FALSE
    )
  }
}

base_defaults_path <- file.path(harness_root, "config", "exdqlm_dynamic_fitforecast_v2_defaults.yaml")
candidate <- ffv2_c13_mcmc_candidate(ffv2_read_vb_calibration_candidates())
dqlm_registry <- audit$source_registry[!grepl("^qdesn_", audit$source_registry$model_variant),
                                       , drop = FALSE]
dqlm_manifest_rows <- list()
dqlm_manifest_i <- 0L
for (method in c("vb", "mcmc")) {
  chains <- if (method == "mcmc") seq_len(imi_v1_mcmc_chains) else 1L
  if (smoke) chains <- 1L
  for (chain_id in chains) {
    d <- ffv2_load_defaults(base_defaults_path)
    d$study$run_tag <- sprintf("%s__dqlm_%s_c%02d", run_id, method, chain_id)
    d$study$results_root <- file.path("results", "qdesn_mcmc_validation", campaign_stage,
                                      run_id, "dqlm")
    d$source$fit_sizes <- 500L
    d$models <- ffv2_vb_screen_candidate_models(d, candidate)
    d$models$model_variants <- c("dqlm", "exdqlm")
    d$models$inference_methods <- method
    d$models$latent_clock_mode <- "post_warmup_source_index"
    d$budget$stored_draws <- if (smoke) 8L else 2000L
    d$budget$forecast_draws <- if (smoke) 8L else 2000L
    d$budget$vb$max_iter <- if (smoke) 5L else 300L
    d$budget$vb$tol <- if (smoke) 0.2 else 0.03
    d$budget$vb$n_samp <- if (smoke) 8L else imi_v1_vb_draws
    d$budget$mcmc$n_burn <- if (smoke) 4L else 5000L
    d$budget$mcmc$n_mcmc <- if (smoke) 8L else 20000L
    d$budget$mcmc$thin <- 1L
    d$budget$mcmc$init_from_vb <- !smoke
    d$runtime$threads <- 1L
    d$runtime$progress_every <- if (smoke) 1L else 50L
    d$runtime$trace_every <- if (smoke) 1L else 50L
    d$handoff$fit <- TRUE
    # Each replay is self-contained. MCMC computes its frozen inline VB
    # initializer, so cross-run VB handoff payloads are neither useful nor retained.
    d$handoff$vb_init <- FALSE
    d$handoff$reuse_vb_init <- FALSE
    d$handoff$prune_fit_on_success <- TRUE
    d$retention$mode <- "compact_success_only"
    d$retention$allow_success_binary_payloads <- FALSE
    d$smoke$rows <- list()
    d$pilot$rows <- list()
    source_registry <- ffv2_collect_source_registry(d, require_sources = TRUE)
    verification <- ffv2_verify_source_windows(source_registry, stop_on_fail = TRUE)
    if (nrow(source_registry) != 9L || any(verification$status != "PASS")) {
      stop("DQLM/exDQLM source contract is incomplete.", call. = FALSE)
    }
    manifest <- ffv2_prepare_manifest(d, source_registry, overwrite = FALSE)
    if (nrow(manifest) != 18L) stop("Expected 18 DQLM/exDQLM rows per manifest.", call. = FALSE)
    manifest$source_replay_id <- rep(NA_character_, nrow(manifest))
    manifest$chain_id <- rep(NA_integer_, nrow(manifest))
    manifest$seed <- rep(NA_integer_, nrow(manifest))
    manifest$metric_draws_path <- rep(NA_character_, nrow(manifest))
    manifest$metric_interval_summary_path <- rep(NA_character_, nrow(manifest))
    manifest$metric_interval_manifest_path <- rep(NA_character_, nrow(manifest))
    for (j in seq_len(nrow(manifest))) {
      row <- manifest[j, , drop = FALSE]
      replay_match <- dqlm_registry$inference == method &
        dqlm_registry$model_variant == row$model_variant[[1L]] &
        dqlm_registry$family == row$family[[1L]] &
        abs(dqlm_registry$tau - as.numeric(row$tau[[1L]])) < 1e-12
      if (sum(replay_match) != 1L) stop("DQLM replay registry join failed.", call. = FALSE)
      replay <- dqlm_registry[replay_match, , drop = FALSE]
      config <- ffv2_read_json(row$row_config_path[[1L]])
      config <- if (method == "mcmc") ffv2_stamp_c13_mcmc_config(config, candidate) else {
        config$models <- ffv2_vb_screen_candidate_models(config, candidate)
        config <- ffv2_sync_model_provenance(config)
        config
      }
      frozen_seed <- seed_row_for(replay$source_identity[[1L]], chain_id)
      seed <- seed_int(
        frozen_seed, "seed", imi_v1_seed(run_id, replay$replay_id[[1L]], chain_id, "dqlm")
      )
      interval_draws <- if (smoke) 8L else if (method == "vb") imi_v1_vb_draws else
        imi_v1_mcmc_metric_draws
      run_root <- row$run_root[[1L]]
      for (subdir in c("metric_draws", "metric_interval_summaries", "metric_interval_manifests")) {
        ffv2_ensure_dir(file.path(run_root, subdir))
      }
      config$seed <- seed
      config$chain_id <- chain_id
      config$source_replay_id <- replay$replay_id[[1L]]
      config$package_contract <- list(
        version = campaign_package_version,
        source_commit = campaign_package_commit,
        tarball_sha256 = campaign_package_tarball_sha256,
        authority_id = campaign_authority_id,
        gamma_update = if (row$model_variant[[1L]] == "exdqlm") {
          if (method == "mcmc") "collapsed_slice" else
            "structured_qgamma_qsigma_given_gamma"
        } else "gamma_fixed_al"
      )
      config$metric_intervals <- list(
        enabled = TRUE, required = TRUE, draws = interval_draws, chain_id = chain_id,
        estimator_id = "posterior_mean_draw_metric_equal_tailed_95cri_v1",
        draw_source_contract = "conditional_quantile_not_response_predictive"
      )
      config$metric_draws_path <- file.path(
        run_root, "metric_draws", sprintf("%s_metric_draws.csv.gz", row$row_key[[1L]])
      )
      config$metric_interval_summary_path <- file.path(
        run_root, "metric_interval_summaries", sprintf("%s_metric_intervals.csv", row$row_key[[1L]])
      )
      config$metric_interval_manifest_path <- file.path(
        run_root, "metric_interval_manifests", sprintf("%s_metric_intervals.json", row$row_key[[1L]])
      )
      config$budget$vb$n_samp <- if (smoke) 8L else imi_v1_vb_draws
      if (row$model_variant[[1L]] == "exdqlm") {
        config$budget$vb$sigmagam <- list(
          factorization = "structured", structured_grid_size = 151L,
          structured_span_sd = 6, freeze_warmup_iters = 10L,
          force_after_warmup = TRUE, postwarmup_damping = 0.6,
          postwarmup_damping_iters = 5L, min_postwarmup_updates = 1L
        )
        config$budget$mcmc$mh_proposal <- "collapsed_slice"
      } else {
        config$budget$mcmc$mh_proposal <- "slice"
      }
      config$budget$mcmc$n_burn <- if (smoke) 4L else 5000L
      config$budget$mcmc$n_mcmc <- if (smoke) 8L else 20000L
      config$budget$mcmc$thin <- 1L
      config$budget$mcmc$init_from_vb <- !smoke
      config$handoff$prune_fit_on_success <- TRUE
      config$retention$allow_success_binary_payloads <- FALSE
      config$inference_diagnostics_path <- file.path(
        run_root, "metrics", sprintf("%s_inference_diagnostics.json", row$row_key[[1L]])
      )
      ffv2_write_json(config, row$row_config_path[[1L]])
      manifest$source_replay_id[j] <- replay$replay_id[[1L]]
      manifest$chain_id[j] <- chain_id
      manifest$seed[j] <- seed
      manifest$metric_draws_path[j] <- config$metric_draws_path
      manifest$metric_interval_summary_path[j] <- config$metric_interval_summary_path
      manifest$metric_interval_manifest_path[j] <- config$metric_interval_manifest_path
      dqlm_manifest_i <- dqlm_manifest_i + 1L
      dqlm_manifest_rows[[dqlm_manifest_i]] <- manifest[j, , drop = FALSE]
      include <- TRUE
      if (smoke) {
        include <- (method == "vb" && row$model_variant[[1L]] == "dqlm" &&
                      row$family[[1L]] == "normal" && abs(row$tau[[1L]] - 0.25) < 1e-12) ||
          (method == "mcmc" && row$model_variant[[1L]] == "exdqlm" &&
             row$family[[1L]] == "laplace" && abs(row$tau[[1L]] - 0.05) < 1e-12)
      }
      if (include) {
        job_id <- sprintf("dqlm__%s__c%02d", replay$replay_id[[1L]], chain_id)
        job_i <- job_i + 1L
        job_rows[[job_i]] <- data.frame(
          job_id = job_id, engine = "dqlm", replay_id = replay$replay_id[[1L]],
          source_identity = replay$source_identity[[1L]], model_variant = row$model_variant[[1L]],
          family = row$family[[1L]], tau = row$tau[[1L]], inference = method,
          chain_id = chain_id,
          config_path = normalizePath(row$row_config_path[[1L]], winslash = "/", mustWork = TRUE),
          config_sha256 = ffv2_file_sha256(row$row_config_path[[1L]]),
          job_root = row$run_root[[1L]], expected_draws = interval_draws,
          status = "PENDING", stringsAsFactors = FALSE
        )
      }
    }
    ffv2_write_csv(manifest, unique(manifest$row_manifest_path)[[1L]])
  }
}

plan <- do.call(rbind, job_rows)
plan <- plan[order(plan$engine, plan$inference, plan$model_variant, plan$family,
                   plan$tau, plan$replay_id, plan$chain_id), , drop = FALSE]
rownames(plan) <- NULL
expected_jobs <- if (smoke) 4L else 198L
if (nrow(plan) != expected_jobs || anyDuplicated(plan$job_id) ||
    any(!file.exists(plan$config_path))) {
  stop(sprintf("Materialized plan violates expected %d-job contract; found %d.",
               expected_jobs, nrow(plan)), call. = FALSE)
}
plan_path <- ffv2_write_csv(plan, file.path(state_root, "manifests", "job_plan.csv"))
utils::write.table(plan$config_path, file.path(state_root, "manifests", "config_paths.txt"),
                   row.names = FALSE, col.names = FALSE, quote = FALSE)
if (length(dqlm_manifest_rows)) {
  ffv2_write_csv(ffv2_bind_rows(dqlm_manifest_rows),
                 file.path(materialization_root, "dqlm_generated_rows.csv"))
}
source_inventory <- do.call(rbind, lapply(list.files(file.path(state_root, "sources"),
                                                     full.names = TRUE), function(path) {
  files <- list.files(path, full.names = TRUE)
  data.frame(path = normalizePath(files, winslash = "/", mustWork = TRUE),
             bytes = as.numeric(file.info(files)$size),
             sha256 = vapply(files, ffv2_file_sha256, character(1L)),
             stringsAsFactors = FALSE)
}))
ffv2_write_csv(source_inventory, file.path(materialization_root, "staged_source_inventory.csv"))
manifest <- list(
  schema_version = campaign_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = run_id, smoke = smoke, workers = workers,
  authority_id = campaign_authority_id,
  package_version = campaign_package_version,
  package_source_commit = campaign_package_commit,
  package_tarball_sha256 = campaign_package_tarball_sha256,
  seed_ledger_path = if (nzchar(campaign_seed_ledger_path)) {
    normalizePath(ffv2_resolve_path(campaign_seed_ledger_path, repo_root = repo_root,
                                    must_work = TRUE), winslash = "/", mustWork = TRUE)
  } else NULL,
  seed_ledger_sha256 = if (nzchar(campaign_seed_ledger_path)) {
    ffv2_file_sha256(ffv2_resolve_path(campaign_seed_ledger_path, repo_root = repo_root,
                                       must_work = TRUE))
  } else NULL,
  git_branch = system("git branch --show-current", intern = TRUE),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  jobs = nrow(plan), qdesn_jobs = sum(plan$engine == "qdesn"),
  dqlm_jobs = sum(plan$engine == "dqlm"),
  vb_jobs = sum(plan$inference == "vb"), mcmc_jobs = sum(plan$inference == "mcmc"),
  expected_metric_roles = 216L, expected_source_identities = 90L,
  scientific_contract = list(
    families = c("normal", "laplace", "gausmix"),
    quantiles = c(0.05, 0.25, 0.50),
    train_source_indices = c(8501L, 9000L),
    forecast_source_indices = c(9001L, 10000L),
    forecast_origins = 34L,
    origin_stride = 30L,
    maximum_lead = 30L,
    scored_origin_lead_pairs = 1000L,
    forecast_protocol = "rolling_origin_no_refit_state_update",
    models = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
    scores = list(
      fit_rmse = "sqrt(mean((conditional_quantile_draw-oracle_quantile)^2))",
      forecast_mae = "mean(abs(conditional_quantile_draw-oracle_quantile))",
      forecast_rmse = "available_in_granular_forecast_path_and_lead_summaries",
      forecast_check_loss = "mean((y-q)*(tau-I(y<q)))"
    ),
    metric_interval = "equal_tailed_95pct_over_draw_specific_metrics",
    metric_draw_source = "conditional_quantile_not_response_predictive"
  ),
  exclusions = list(
    acrps = "not_supported_by_the_frozen_independent_validation_tooling",
    dense_or_overlapping_origins = "not_part_of_the_official_protocol",
    response_predictive_noise = "excluded_from_metric_interval_draws",
    successful_fitted_model_binaries = "forbidden",
    article_or_overleaf_writes = "integration_lane_only"
  ),
  plan_path = plan_path, plan_sha256 = ffv2_file_sha256(plan_path),
  static_checks_pass = sum(audit$checks$pass), static_checks_total = nrow(audit$checks),
  storage_policy = list(successful_binary_payloads_allowed = FALSE,
                        retained_draw_format = "csv_gzip")
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "materialization_manifest.json"))
cat(sprintf("run_id=%s smoke=%s jobs=%d qdesn=%d dqlm=%d plan=%s\n",
            run_id, smoke, nrow(plan), sum(plan$engine == "qdesn"),
            sum(plan$engine == "dqlm"), plan_path))
