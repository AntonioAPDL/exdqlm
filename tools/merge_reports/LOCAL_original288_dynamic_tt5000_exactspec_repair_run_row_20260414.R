#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_helpers_20260414.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args_original288_dynamic_tt5000_exactspec_repair <- function(args) {
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

safe_num_vec_original288_dynamic_tt5000_exactspec_repair <- function(x, default) {
  v <- suppressWarnings(as.numeric(x))
  if (!length(v) || any(!is.finite(v))) return(as.numeric(default))
  v
}

compact_fit_original288_dynamic_tt5000_exactspec_repair <- function(fit, inference) {
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

collect_vb_health_original288_dynamic_tt5000_exactspec_repair <- function(wrapped,
                                                                           case_id,
                                                                           variant,
                                                                           candidate_path,
                                                                           vhg_extract_rhs_collapse) {
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
    run_time_sec = safe_num_original288_dynamic_tt5000_exactspec_repair(wrapped$meta$runtime_sec %||% fit$run.time, NA_real_),
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

set_dynamic_ld_options_original288_dynamic_tt5000_exactspec_repair <- function(ld_list) {
  if (!is.list(ld_list) || !length(ld_list)) return(list())
  named <- ld_list
  names(named) <- paste0("exdqlm.dynamic.ldvb.", names(ld_list))
  options(named)
}

write_row_failure_original288_dynamic_tt5000_exactspec_repair <- function(row, row_id, reason) {
  health_row <- data.frame(
    case_id = row$original_case_key,
    variant = run_tag_original288_dynamic_tt5000_exactspec_repair(),
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
    candidate_label = row$candidate_label,
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
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    candidate_label = row$candidate_label,
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

args <- parse_args_original288_dynamic_tt5000_exactspec_repair(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

manifest_path <- safe_chr_original288_dynamic_tt5000_exactspec_repair(
  args$manifest,
  paths_original288_dynamic_tt5000_exactspec_repair()$full_manifest
)
row_id <- safe_int_original288_dynamic_tt5000_exactspec_repair(args$row_id, NA_integer_)
tag <- safe_chr_original288_dynamic_tt5000_exactspec_repair(
  args$tag,
  run_tag_original288_dynamic_tt5000_exactspec_repair()
)
force <- as_flag_original288_dynamic_tt5000_exactspec_repair(args$force, FALSE)

if (is.na(manifest_path) || !file.exists(manifest_path)) stop("manifest is required and must exist")
if (!is.finite(row_id)) stop("row_id is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
row <- row[1, , drop = FALSE]
cfg <- readRDS(row$run_config_path)

for (path in c(dirname(cfg$fit_path), dirname(row$row_status_path), dirname(row$health_path), dirname(row$metrics_path), dirname(row$draws_path))) {
  ensure_dir_original288_dynamic_tt5000_exactspec_repair(path)
}

if (isTRUE(row$missing_inputs)) {
  write_row_failure_original288_dynamic_tt5000_exactspec_repair(row, row_id, "missing_inputs flag is TRUE in manifest")
  quit(save = "no", status = 0)
}

if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required")
pkgload::load_all(repo_root, quiet = TRUE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1"
)

resolve_fit_original288_dynamic_tt5000_exactspec_repair <- function(obj) obj$fit %||% obj

run_dynamic_original288_dynamic_tt5000_exactspec_repair <- function() {
  sim_obj <- readRDS(row$sim_output_path)
  baseline_path <- safe_chr_original288_dynamic_tt5000_exactspec_repair(row$baseline_fit_path, NA_character_)
  if (is.na(baseline_path) || !nzchar(baseline_path) || !file.exists(baseline_path)) {
    synthetic_baseline_path <- sub("_run_config\\.rds$", "_synthetic_baseline.rds", row$run_config_path)
    synth_row <- list(
      selected_fit_path = safe_chr_original288_dynamic_tt5000_exactspec_repair(row$source_reference_fit_path, row$baseline_fit_path),
      family = row$family,
      tau = row$tau_label,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      model = row$model,
      original_case_key = row$original_case_key
    )
    build_dynamic_synthetic_baseline_original288_normalized_multiseed(synth_row, synthetic_baseline_path)
    baseline_path <- synthetic_baseline_path
  }
  baseline <- readRDS(baseline_path)
  bf <- resolve_fit_original288_dynamic_tt5000_exactspec_repair(baseline)

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

      if (identical(row$inference, "vb")) {
        vb_cfg <- cfg$vb %||% list()
        old_ld <- set_dynamic_ld_options_original288_dynamic_tt5000_exactspec_repair(vb_cfg$ld %||% list())
        on.exit(if (length(old_ld)) options(old_ld), add = TRUE)
        old_opt <- options(list(
          exdqlm.max_iter = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$max_iter %||% 300L, 300L),
          exdqlm.tol_sigma = safe_num_original288_dynamic_tt5000_exactspec_repair(vb_cfg$tol_sigma %||% vb_cfg$tol %||% 0.03, 0.03),
          exdqlm.tol_gamma = safe_num_original288_dynamic_tt5000_exactspec_repair(vb_cfg$tol_gamma %||% vb_cfg$tol %||% 0.03, 0.03),
          exdqlm.tol_elbo = safe_num_original288_dynamic_tt5000_exactspec_repair(vb_cfg$tol_elbo %||% 1e-6, 1e-6),
          exdqlm.vb.min_iter = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$min_iter %||% 10L, 10L),
          exdqlm.vb.patience = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$patience %||% 3L, 3L),
          exdqlm.vb.allow_elbo_drop = safe_num_original288_dynamic_tt5000_exactspec_repair(vb_cfg$allow_elbo_drop %||% 1e-5, 1e-5)
        ))
        on.exit(options(old_opt), add = TRUE)

        runtime_obj <- system.time({
          fit_obj <- exdqlmLDVB(
            y = as.numeric(sim_obj$y),
            p0 = bf$p0,
            model = bf$model,
            df = bf$df,
            dim.df = bf$dim.df,
            fix.sigma = FALSE,
            sig.init = safe_num_original288_dynamic_tt5000_exactspec_repair(bf$sig.init %||% NA_real_, NA_real_),
            dqlm.ind = identical(row$model, "dqlm"),
            tol = safe_num_original288_dynamic_tt5000_exactspec_repair(vb_cfg$tol %||% 0.03, 0.03),
            n.samp = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$n_samp %||% 1000L, 1000L),
            verbose = FALSE
          )
        })
      } else {
        vb_cfg <- cfg$vb %||% list()
        mc_cfg <- cfg$mcmc %||% list()
        mh <- mc_cfg$mh %||% list()
        accepted_mh <- bf$mh.diagnostics %||% list()

        vb_obj <- NULL
        if (!is.na(row$vb_reference_fit_path) && nzchar(row$vb_reference_fit_path) && file.exists(row$vb_reference_fit_path)) {
          vb_obj <- resolve_fit_original288_dynamic_tt5000_exactspec_repair(readRDS(row$vb_reference_fit_path))
        }

        refresh_opts <- list()
        refresh_interval <- safe_int_original288_dynamic_tt5000_exactspec_repair(
          mh$laplace_refresh_interval %||% accepted_mh$laplace_refresh$interval,
          NA_integer_
        )
        refresh_start <- safe_int_original288_dynamic_tt5000_exactspec_repair(
          mh$laplace_refresh_start %||% accepted_mh$laplace_refresh$start,
          NA_integer_
        )
        refresh_weight <- safe_num_original288_dynamic_tt5000_exactspec_repair(
          mh$laplace_refresh_weight %||% accepted_mh$laplace_refresh$weight,
          NA_real_
        )
        if (is.finite(refresh_interval)) refresh_opts$exdqlm.mcmc.laplace_refresh_interval <- refresh_interval
        if (is.finite(refresh_start)) refresh_opts$exdqlm.mcmc.laplace_refresh_start <- refresh_start
        if (is.finite(refresh_weight)) refresh_opts$exdqlm.mcmc.laplace_refresh_weight <- refresh_weight
        if (length(refresh_opts)) {
          old_refresh <- options(refresh_opts)
          on.exit(options(old_refresh), add = TRUE)
        }

        call_args <- list(
          y = as.numeric(sim_obj$y),
          p0 = bf$p0,
          model = bf$model,
          df = bf$df,
          dim.df = bf$dim.df,
          dqlm.ind = identical(row$model, "dqlm"),
          n.burn = safe_int_original288_dynamic_tt5000_exactspec_repair(mc_cfg$burn %||% 5000L, 5000L),
          n.mcmc = safe_int_original288_dynamic_tt5000_exactspec_repair(mc_cfg$n %||% 20000L, 20000L),
          init.from.vb = as_flag_original288_dynamic_tt5000_exactspec_repair(mc_cfg$init_from_vb, !is.null(vb_obj)),
          init.from.isvb = as_flag_original288_dynamic_tt5000_exactspec_repair(mc_cfg$init_from_isvb %||% identical(tolower(safe_chr_original288_dynamic_tt5000_exactspec_repair(bf$vb.init.method, "ldvb")), "isvb"), FALSE),
          vb_init_controls = list(
            method = safe_chr_original288_dynamic_tt5000_exactspec_repair(vb_cfg$method %||% bf$vb.init.method %||% "ldvb", "ldvb"),
            tol = safe_num_original288_dynamic_tt5000_exactspec_repair(vb_cfg$tol %||% 0.03, 0.03),
            n.IS = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$n_IS %||% vb_cfg$n_is %||% 200L, 200L),
            n.samp = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$n_samp %||% 1000L, 1000L),
            max_iter = safe_int_original288_dynamic_tt5000_exactspec_repair(vb_cfg$max_iter %||% 300L, 300L),
            verbose = FALSE
          ),
          joint.sample = as_flag_original288_dynamic_tt5000_exactspec_repair(mh$joint_sample %||% mh$primary_joint_sample %||% accepted_mh$joint_sample, FALSE),
          mh.proposal = safe_chr_original288_dynamic_tt5000_exactspec_repair(mh$proposal %||% mh$primary_proposal %||% accepted_mh$proposal %||% "laplace_rw", "laplace_rw"),
          mh.adapt = as_flag_original288_dynamic_tt5000_exactspec_repair(mh$adapt %||% accepted_mh$adapt, TRUE),
          mh.adapt.interval = safe_int_original288_dynamic_tt5000_exactspec_repair(mh$adapt_interval %||% accepted_mh$adapt_interval %||% 50L, 50L),
          mh.target.accept = safe_num_vec_original288_dynamic_tt5000_exactspec_repair(mh$target_accept %||% accepted_mh$target_accept %||% c(0.20, 0.45), c(0.20, 0.45)),
          mh.scale.bounds = safe_num_vec_original288_dynamic_tt5000_exactspec_repair(mh$scale_bounds %||% accepted_mh$scale_bounds %||% c(0.1, 10), c(0.1, 10)),
          mh.max_scale.step = safe_num_original288_dynamic_tt5000_exactspec_repair(mh$max_scale_step %||% accepted_mh$max_scale_step %||% 0.35, 0.35),
          mh.min_burn_adapt = safe_int_original288_dynamic_tt5000_exactspec_repair(mh$min_burn_adapt %||% accepted_mh$min_burn_adapt %||% 50L, 50L),
          trace.diagnostics = TRUE,
          trace.every = safe_int_original288_dynamic_tt5000_exactspec_repair(mh$trace_every %||% mc_cfg$trace_every %||% accepted_mh$trace_every %||% 50L, 50L),
          verbose = FALSE
        )
        slice_width <- safe_num_original288_dynamic_tt5000_exactspec_repair(mh$slice_width %||% accepted_mh$slice_width, NA_real_)
        slice_max_steps <- safe_int_original288_dynamic_tt5000_exactspec_repair(mh$slice_max_steps %||% accepted_mh$slice_max_steps, NA_integer_)
        if (is.finite(slice_width)) call_args$slice.width <- slice_width
        if (is.finite(slice_max_steps)) call_args$slice.max.steps <- slice_max_steps
        if (isTRUE(call_args$init.from.vb) && !is.null(vb_obj)) call_args$vb_init_fit <- vb_obj

        runtime_obj <- system.time({
          fit_obj <- do.call(exdqlmMCMC, call_args)
        })
      }

      wrapped <- list(
        fit = compact_fit_original288_dynamic_tt5000_exactspec_repair(fit_obj, row$inference),
        meta = list(
          runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
          seed = cfg$fit_seed,
          tag = tag
        )
      )
      saveRDS(wrapped, cfg$fit_path)
      status <- "done"
    }

    case_id <- safe_chr_original288_dynamic_tt5000_exactspec_repair(cfg$original_case_key, sprintf("row_%04d", row_id))
    fit_obj <- wrapped$fit %||% wrapped

    if (identical(row$inference, "mcmc")) {
      health_metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = cfg$fit_path)
      health_row <- vhg_apply_health_gates(health_metrics)
    } else {
      health_row <- collect_vb_health_original288_dynamic_tt5000_exactspec_repair(
        wrapped,
        case_id = case_id,
        variant = tag,
        candidate_path = cfg$fit_path,
        vhg_extract_rhs_collapse = vhg_extract_rhs_collapse
      )
    }

    draw_mat <- as.matrix(fit_obj$samp.post.pred)
    draw_idx <- select_draw_indices_original288_dynamic_tt5000_exactspec_repair(ncol(draw_mat), 20000L, cfg$fit_seed)
    draw_keep <- draw_mat[, draw_idx, drop = FALSE]
    metric_core <- dynamic_metrics_original288_dynamic_tt5000_exactspec_repair(row, sim_obj, draw_keep)

    saveRDS(
      list(
        kind = "dynamic_predictive_draw_contract",
        source_fit_path = cfg$fit_path,
        n_posterior_draws = 20000L,
        selected_indices = draw_idx,
        source_draw_count = ncol(draw_mat),
        seed = as.integer(cfg$fit_seed)
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
      candidate_label = row$candidate_label,
      gate_overall = safe_chr_original288_dynamic_tt5000_exactspec_repair(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_original288_dynamic_tt5000_exactspec_repair(health_row$run_time_sec[1], safe_num_original288_dynamic_tt5000_exactspec_repair(wrapped$meta$runtime_sec, NA_real_)),
      crps_metric = metric_core$crps[[1]],
      primary_accuracy_metric = metric_core$q_rmse[[1]],
      q_rmse_metric = metric_core$q_rmse[[1]],
      coverage95_metric = metric_core$coverage95[[1]],
      coverage95_gap_metric = metric_core$coverage95_gap[[1]],
      mean_ci_width_metric = metric_core$mean_ci_width[[1]],
      cie_metric = NA_real_,
      beta_rmse_mean_metric = NA_real_,
      beta_coverage_gap_metric = NA_real_,
      metric_source = "dynamic_tt5000_exact_repair",
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
      gate_overall = safe_chr_original288_dynamic_tt5000_exactspec_repair(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = metrics_row$runtime_sec[1],
      phase = row$phase,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      candidate_label = row$candidate_label,
      seed_slot = row$seed_slot,
      seed = row$seed,
      candidate_fit_path = row$candidate_fit_path,
      health_csv = row$health_path,
      metrics_csv = row$metrics_path,
      draws_rds = row$draws_path,
      stringsAsFactors = FALSE
    )
    utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
  }, error = function(e) {
    write_row_failure_original288_dynamic_tt5000_exactspec_repair(row, row_id, conditionMessage(e))
  })
}

run_dynamic_original288_dynamic_tt5000_exactspec_repair()
