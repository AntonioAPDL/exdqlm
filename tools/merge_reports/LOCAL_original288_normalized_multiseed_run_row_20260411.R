#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R")

parse_args_original288_normalized_multiseed <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    } else if (grepl("^--", x)) {
      key <- sub("^--", "", x)
      out[[key]] <- "TRUE"
    }
  }
  out
}

collect_vb_health_original288_normalized_multiseed <- function(wrapped, case_id, variant, candidate_path, vhg_extract_rhs_collapse) {
  fit <- wrapped$fit %||% wrapped
  conv <- fit$diagnostics$convergence$converged %||% fit$converged %||% NA
  stop_reason <- as.character(fit$diagnostics$convergence$stop_reason %||% NA_character_)
  rhs <- vhg_extract_rhs_collapse(fit)

  finite_ok <- TRUE
  if (!is.null(fit$diagnostics$deltas)) {
    d <- unlist(fit$diagnostics$deltas, use.names = FALSE)
    d <- d[is.finite(d)]
    finite_ok <- length(d) > 0L
  }

  gate_overall <- if (isTRUE(rhs$collapse_flag)) {
    "FAIL"
  } else if (isTRUE(conv)) {
    "PASS"
  } else if (isTRUE(finite_ok)) {
    "WARN"
  } else {
    "FAIL"
  }

  data.frame(
    case_id = case_id,
    variant = variant,
    gate_overall = gate_overall,
    healthy = gate_overall %in% c("PASS", "WARN") && !isTRUE(rhs$collapse_flag),
    unhealthy_reason = if (isTRUE(rhs$collapse_flag)) "rhs_collapse" else if (gate_overall == "FAIL") "vb_fail" else NA_character_,
    rhs_collapse_flag = isTRUE(rhs$collapse_flag),
    rhs_collapse_sources = rhs$collapse_sources,
    vb_converged = isTRUE(conv),
    vb_stop_reason = stop_reason,
    run_time_sec = safe_num_original288_normalized_multiseed(wrapped$meta$runtime_sec %||% fit$run.time, NA_real_),
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

compact_fit_original288_normalized_multiseed <- function(fit, inference) {
  out <- fit
  if (identical(inference, "mcmc")) {
    out$samp.v <- NULL
    out$samp.s <- NULL
    if (!is.null(out$mh.diagnostics$trace)) out$mh.diagnostics$trace <- NULL
  } else {
    if (!is.null(out$diagnostics$trace)) out$diagnostics$trace <- NULL
  }
  out
}

write_row_failure_original288_normalized_multiseed <- function(row, row_id, reason) {
  health_row <- data.frame(
    case_id = row$original_case_key,
    variant = run_tag_original288_normalized_multiseed(),
    gate_overall = "FAIL",
    healthy = FALSE,
    unhealthy_reason = "runtime_fail",
    rhs_collapse_flag = NA,
    run_time_sec = NA_real_,
    candidate_path = row$candidate_fit_path,
    stringsAsFactors = FALSE
  )
  metrics_row <- data.frame(
    row_id = row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    phase = row$phase,
    seed_slot = row$seed_slot,
    seed = row$seed,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    crps_metric = NA_real_,
    primary_accuracy_metric = NA_real_,
    q_rmse_metric = NA_real_,
    coverage95_metric = NA_real_,
    coverage95_gap_metric = NA_real_,
    mean_ci_width_metric = NA_real_,
    cie_metric = NA_real_,
    beta_rmse_mean_metric = NA_real_,
    beta_coverage_gap_metric = NA_real_,
    metric_source = "runtime_fail",
    metric_error = reason,
    stringsAsFactors = FALSE
  )
  row_out <- data.frame(
    row_id = row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    ts_start = as.character(Sys.time()),
    ts_end = as.character(Sys.time()),
    status = "failed_runtime",
    error = reason,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    phase = row$phase,
    runner_kind = row$runner_kind,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    seed_slot = row$seed_slot,
    seed = row$seed,
    candidate_fit_path = row$candidate_fit_path,
    health_csv = row$health_path,
    metrics_csv = row$metrics_path,
    draws_rds = row$draws_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(health_row, row$health_path, row.names = FALSE)
  utils::write.csv(metrics_row, row$metrics_path, row.names = FALSE)
  utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
}

args <- parse_args_original288_normalized_multiseed(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

manifest_path <- safe_chr_original288_normalized_multiseed(
  args$manifest,
  paths_original288_normalized_multiseed()$pilot_manifest
)
row_id <- safe_int_original288_normalized_multiseed(args$row_id, NA_integer_)
tag <- safe_chr_original288_normalized_multiseed(args$tag, run_tag_original288_normalized_multiseed())
force <- as_flag_original288_normalized_multiseed(args$force, FALSE)

if (is.na(manifest_path) || !file.exists(manifest_path)) stop("manifest is required and must exist")
if (!is.finite(row_id)) stop("row_id is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
if (nrow(row) > 1L) stop(sprintf("row_id %d appears multiple times in manifest", row_id))
row <- row[1, , drop = FALSE]

for (path in c(dirname(row$candidate_fit_path), dirname(row$row_status_path), dirname(row$health_path), dirname(row$metrics_path), dirname(row$draws_path))) {
  ensure_dir_original288_normalized_multiseed(path)
}

if (isTRUE(row$missing_inputs)) {
  write_row_failure_original288_normalized_multiseed(row, row_id, "missing_inputs flag is TRUE in manifest")
  quit(save = "no", status = 0)
}

if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required")
if (!requireNamespace("mvtnorm", quietly = TRUE)) stop("mvtnorm is required")

pkgload::load_all(repo_root, quiet = TRUE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1"
)

run_dynamic_generic_original288_normalized_multiseed <- function() {
  rc <- system2(
    "Rscript",
    args = c(
      "tools/merge_reports/LOCAL_full288_case_runner_20260327.R",
      sprintf("--manifest=%s", manifest_path),
      sprintf("--row_id=%s", row_id),
      sprintf("--tag=%s", tag),
      sprintf("--force=%s", if (isTRUE(force)) "1" else "0")
    )
  )
  if (!is.null(rc) && rc != 0L && !file.exists(row$row_status_path)) {
    stop(sprintf("generic runner exited with code %s", rc))
  }

  row_out <- if (file.exists(row$row_status_path)) {
    utils::read.csv(row$row_status_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame(
      row_id = row_id,
      status = "failed_runtime",
      error = sprintf("generic runner exited with code %s", rc),
      gate_overall = "FAIL",
      healthy = FALSE,
      runtime_sec = NA_real_,
      stringsAsFactors = FALSE
    )
  }
  health_row <- if (file.exists(row$health_path)) {
    utils::read.csv(row$health_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame(
      case_id = row$original_case_key,
      variant = tag,
      gate_overall = safe_chr_original288_normalized_multiseed(row_out$gate_overall[1], "FAIL"),
      healthy = isTRUE(row_out$healthy[1]),
      run_time_sec = safe_num_original288_normalized_multiseed(row_out$runtime_sec[1], NA_real_),
      candidate_path = row$candidate_fit_path,
      stringsAsFactors = FALSE
    )
  }

  metrics_row <- data.frame(
    row_id = row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    phase = row$phase,
    seed_slot = row$seed_slot,
    seed = row$seed,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    gate_overall = safe_chr_original288_normalized_multiseed(row_out$gate_overall[1], "FAIL"),
    healthy = isTRUE(row_out$healthy[1]),
    runtime_sec = safe_num_original288_normalized_multiseed(row_out$runtime_sec[1], safe_num_original288_normalized_multiseed(health_row$run_time_sec[1], NA_real_)),
    crps_metric = NA_real_,
    primary_accuracy_metric = NA_real_,
    q_rmse_metric = NA_real_,
    coverage95_metric = NA_real_,
    coverage95_gap_metric = NA_real_,
    mean_ci_width_metric = NA_real_,
    cie_metric = NA_real_,
    beta_rmse_mean_metric = NA_real_,
    beta_coverage_gap_metric = NA_real_,
    metric_source = "dynamic_generic",
    metric_error = NA_character_,
    stringsAsFactors = FALSE
  )

  if (file.exists(row$candidate_fit_path)) {
    wrapped <- readRDS(row$candidate_fit_path)
    fit_obj <- wrapped$fit %||% wrapped
    sim_obj <- readRDS(row$sim_output_path)
    draw_all <- as.matrix(fit_obj$samp.post.pred)
    draw_idx <- select_draw_indices_original288_normalized_multiseed(ncol(draw_all), 20000L, row$seed)
    draw_mat <- draw_all[, draw_idx, drop = FALSE]
    metric_core <- dynamic_metrics_original288_normalized_multiseed(row, sim_obj, draw_mat)
    metrics_row$crps_metric <- metric_core$crps[[1]]
    metrics_row$primary_accuracy_metric <- metric_core$q_rmse[[1]]
    metrics_row$q_rmse_metric <- metric_core$q_rmse[[1]]
    metrics_row$coverage95_metric <- metric_core$coverage95[[1]]
    metrics_row$coverage95_gap_metric <- metric_core$coverage95_gap[[1]]
    metrics_row$mean_ci_width_metric <- metric_core$mean_ci_width[[1]]
    saveRDS(
      list(
        kind = "dynamic_predictive_draw_contract",
        source_fit_path = row$candidate_fit_path,
        n_posterior_draws = 20000L,
        selected_indices = draw_idx,
        source_draw_count = ncol(draw_all),
        seed = as.integer(row$seed)
      ),
      row$draws_path
    )
  }

  utils::write.csv(metrics_row, row$metrics_path, row.names = FALSE)
  row_out$base_row_id <- row$base_row_id
  row_out$original_case_key <- row$original_case_key
  row_out$phase <- row$phase
  row_out$runner_kind <- row$runner_kind
  row_out$fit_size <- row$fit_size
  row_out$prior_semantics <- row$prior_semantics
  row_out$seed_slot <- row$seed_slot
  row_out$seed <- row$seed
  row_out$metrics_csv <- row$metrics_path
  row_out$draws_rds <- row$draws_path
  utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
}

run_static_native_original288_normalized_multiseed <- function() {
  cfg <- readRDS(row$run_config_path)
  series_wide <- utils::read.csv(cfg$series_wide_path, stringsAsFactors = FALSE)
  coef_truth <- utils::read.csv(cfg$coef_truth_path, stringsAsFactors = FALSE)
  design <- static_build_design_original288_normalized_multiseed(series_wide)

  start_ts <- as.character(Sys.time())
  status <- "pending"
  error_msg <- NA_character_
  health_row <- NULL
  metrics_row <- NULL
  wrapped <- NULL

  tryCatch({
    if (file.exists(cfg$fit_path) && !force) {
      wrapped <- readRDS(cfg$fit_path)
      status <- "skipped_existing"
    } else {
      fit_obj <- NULL
      runtime_obj <- NULL
      set.seed(cfg$fit_seed)

      if (identical(cfg$inference, "vb")) {
        runtime_obj <- system.time({
          fit_obj <- exal_static_LDVB(
            y = design$y,
            X = design$X,
            p0 = cfg$tau,
            max_iter = safe_int_original288_normalized_multiseed(cfg$max_iter, 1000L),
            tol = safe_num_original288_normalized_multiseed(cfg$tol, 1e-4),
            beta_prior = cfg$beta_prior,
            beta_prior_controls = NULL,
            dqlm.ind = isTRUE(cfg$dqlm_ind),
            n_samp_xi = safe_int_original288_normalized_multiseed(cfg$n_samp_xi, 200L),
            ld_controls = cfg$ld_controls %||% list(store_trace = FALSE),
            verbose = FALSE
          )
        })
      } else {
        old_refresh_int <- getOption("exdqlm.static.mcmc.laplace_refresh_interval")
        old_refresh_start <- getOption("exdqlm.static.mcmc.laplace_refresh_start")
        old_refresh_weight <- getOption("exdqlm.static.mcmc.laplace_refresh_weight")
        options(
          exdqlm.static.mcmc.laplace_refresh_interval = safe_int_original288_normalized_multiseed(cfg$laplace_refresh_interval, 50L),
          exdqlm.static.mcmc.laplace_refresh_start = safe_int_original288_normalized_multiseed(cfg$laplace_refresh_start, 250L),
          exdqlm.static.mcmc.laplace_refresh_weight = safe_num_original288_normalized_multiseed(cfg$laplace_refresh_weight, 0.60)
        )
        on.exit(
          options(
            exdqlm.static.mcmc.laplace_refresh_interval = old_refresh_int,
            exdqlm.static.mcmc.laplace_refresh_start = old_refresh_start,
            exdqlm.static.mcmc.laplace_refresh_weight = old_refresh_weight
          ),
          add = TRUE
        )

        call_args <- list(
          y = design$y,
          X = design$X,
          p0 = cfg$tau,
          beta_prior = cfg$beta_prior,
          beta_prior_controls = NULL,
          dqlm.ind = isTRUE(cfg$dqlm_ind),
          n.burn = safe_int_original288_normalized_multiseed(cfg$n_burn, 5000L),
          n.mcmc = safe_int_original288_normalized_multiseed(cfg$n_mcmc, 20000L),
          thin = safe_int_original288_normalized_multiseed(cfg$thin, 1L),
          init.from.vb = as_flag_original288_normalized_multiseed(cfg$init_from_vb, TRUE),
          vb_init_controls = cfg$vb_init_controls %||% list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE),
          mh.proposal = safe_chr_original288_normalized_multiseed(cfg$mh_proposal, "laplace_rw"),
          mh.adapt = as_flag_original288_normalized_multiseed(cfg$mh_adapt, TRUE),
          gamma.substeps = safe_int_original288_normalized_multiseed(cfg$gamma_substeps, 3L),
          p.global.eta.jump = safe_num_original288_normalized_multiseed(cfg$p_global_eta_jump, 0.05),
          global.eta.jump.scale = safe_num_original288_normalized_multiseed(cfg$global_eta_jump_scale, 1),
          trace.diagnostics = TRUE,
          trace.every = safe_int_original288_normalized_multiseed(cfg$trace_every, 50L),
          verbose = FALSE
        )
        if (is.finite(safe_num_original288_normalized_multiseed(cfg$slice_width, NA_real_))) {
          call_args$slice.width <- safe_num_original288_normalized_multiseed(cfg$slice_width, 0.10)
        }
        if (is.finite(safe_int_original288_normalized_multiseed(cfg$slice_max_steps, NA_integer_))) {
          call_args$slice.max.steps <- safe_int_original288_normalized_multiseed(cfg$slice_max_steps, 80L)
        }

        runtime_obj <- system.time({
          fit_obj <- do.call(exal_static_mcmc, call_args)
        })
      }

      wrapped <- list(
        fit = compact_fit_original288_normalized_multiseed(fit_obj, cfg$inference),
        meta = list(
          runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
          seed = cfg$fit_seed,
          tag = tag
        )
      )
      saveRDS(wrapped, cfg$fit_path)
      status <- "done"
    }

    case_id <- safe_chr_original288_normalized_multiseed(cfg$original_case_key %||% row$original_case_key, sprintf("row_%04d", row_id))
    fit_obj <- wrapped$fit %||% wrapped
    if (identical(cfg$inference, "mcmc")) {
      health_metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = cfg$fit_path)
      health_row <- vhg_apply_health_gates(health_metrics)
    } else {
      health_row <- collect_vb_health_original288_normalized_multiseed(
        wrapped,
        case_id = case_id,
        variant = tag,
        candidate_path = cfg$fit_path,
        vhg_extract_rhs_collapse = vhg_extract_rhs_collapse
      )
    }

    draw_bundle <- static_predictive_draws_original288_normalized_multiseed(
      fit_obj = fit_obj,
      row = row,
      series_wide = series_wide,
      n_draws = 20000L,
      seed = row$seed
    )
    metric_core <- static_metrics_original288_normalized_multiseed(row, fit_obj, series_wide, coef_truth, draw_bundle)

    saveRDS(
      list(
        kind = "static_parameter_draw_export",
        model = row$model,
        inference = row$inference,
        n_posterior_draws = 20000L,
        seed = as.integer(row$seed),
        beta_draws = draw_bundle$beta_draws,
        sigma_draws = draw_bundle$sigma_draws,
        gamma_draws = draw_bundle$gamma_draws
      ),
      row$draws_path
    )

    metrics_row <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      phase = row$phase,
      seed_slot = row$seed_slot,
      seed = row$seed,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      gate_overall = safe_chr_original288_normalized_multiseed(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_original288_normalized_multiseed(health_row$run_time_sec[1], safe_num_original288_normalized_multiseed(wrapped$meta$runtime_sec, NA_real_)),
      crps_metric = metric_core$crps[[1]],
      primary_accuracy_metric = metric_core$q_rmse[[1]],
      q_rmse_metric = metric_core$q_rmse[[1]],
      coverage95_metric = metric_core$coverage95[[1]],
      coverage95_gap_metric = metric_core$coverage95_gap[[1]],
      mean_ci_width_metric = metric_core$mean_ci_width[[1]],
      cie_metric = metric_core$cie[[1]],
      beta_rmse_mean_metric = metric_core$beta_rmse_mean[[1]],
      beta_coverage_gap_metric = metric_core$beta_coverage_gap[[1]],
      metric_source = "normalized_multiseed_static",
      metric_error = NA_character_,
      stringsAsFactors = FALSE
    )
    utils::write.csv(health_row, row$health_path, row.names = FALSE)
    utils::write.csv(metrics_row, row$metrics_path, row.names = FALSE)

    row_out <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      ts_start = start_ts,
      ts_end = as.character(Sys.time()),
      status = status,
      error = error_msg,
      gate_overall = safe_chr_original288_normalized_multiseed(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_original288_normalized_multiseed(metrics_row$runtime_sec[1], NA_real_),
      phase = row$phase,
      runner_kind = row$runner_kind,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      seed_slot = row$seed_slot,
      seed = row$seed,
      candidate_fit_path = row$candidate_fit_path,
      health_csv = row$health_path,
      metrics_csv = row$metrics_path,
      draws_rds = row$draws_path,
      stringsAsFactors = FALSE
    )
    utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
    gc()
  }, error = function(e) {
    write_row_failure_original288_normalized_multiseed(row, row_id, conditionMessage(e))
  })
}

if (identical(row$runner_kind[[1]], "dynamic_generic")) {
  run_dynamic_generic_original288_normalized_multiseed()
} else {
  run_static_native_original288_normalized_multiseed()
}

cat(sprintf(
  "[normalized-multiseed row %d] phase=%s model=%s inference=%s seed_slot=%s done\n",
  row_id,
  row$phase[[1]],
  row$model[[1]],
  row$inference[[1]],
  row$seed_slot[[1]]
))
