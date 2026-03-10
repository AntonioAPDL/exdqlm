# Fixed-candidate debug runner for staged RHS / quantile stability checks.

bench_qdesn_fixed_debug_series_ids <- function(meta_ds, cfg, dataset_name) {
  dataset_name <- as.character(dataset_name)[1L]
  ids <- unique(c(
    bench_qdesn_override_series_ids(meta_ds, cfg, dataset_name, "selection"),
    bench_qdesn_override_series_ids(meta_ds, cfg, dataset_name, "evaluation")
  ))
  ids <- ids[!is.na(ids) & nzchar(ids)]

  if (length(ids)) {
    return(ids)
  }

  bench_qdesn_select_series_ids(
    meta_ds,
    n_target = cfg$evaluation$max_series_per_dataset,
    purpose = "evaluation"
  )
}

bench_qdesn_fixed_debug_selection_summary <- function(dataset_name, route_key, candidate_id) {
  data.table::data.table(
    dataset = dataset_name,
    route_key = route_key,
    candidate_id = candidate_id,
    selection_metric = NA_character_,
    selection_metric_value = NA_real_,
    n_series = NA_integer_,
    n_applicable = NA_integer_,
    n_failed = NA_integer_,
    n_inapplicable = NA_integer_,
    crps_mean = NA_real_,
    pinball_mean = NA_real_,
    mase_mean = NA_real_,
    smape_mean = NA_real_,
    msis95_mean = NA_real_,
    coverage95_mean = NA_real_,
    acd95_mean = NA_real_,
    runtime_sec = NA_real_,
    selected = TRUE
  )
}

bench_qdesn_run_fixed_debug_experiment <- function(context) {
  cfg <- bench_qdesn_default_cfg(context$config)
  loaded <- bench_qdesn_load_processed(context)
  selected_datasets <- bench_qdesn_select_datasets(loaded, cfg)
  candidate_cfgs <- bench_qdesn_candidate_configs(cfg)

  if (length(candidate_cfgs) != 1L) {
    stop(
      sprintf(
        "Fixed debug experiment requires exactly one Q-DESN candidate. Got %d.",
        length(candidate_cfgs)
      ),
      call. = FALSE
    )
  }

  candidate_cfg <- candidate_cfgs[[1L]]
  candidate_registry <- bench_qdesn_candidate_registry_table(candidate_cfgs)
  run_dirs <- bench_qdesn_run_dirs(context, cfg)
  bench_qdesn_write_run_manifest(context, cfg, run_dirs, selected_datasets)
  bench_write_json(candidate_cfgs, file.path(run_dirs$manifests_dir, "candidate_registry.json"))

  debug_stages <- unique(as.character(unlist(
    cfg$evaluation$debug_stages %||% c("validation", "test"),
    use.names = FALSE
  )))
  debug_stages <- debug_stages[debug_stages %in% c("validation", "test")]
  if (!length(debug_stages)) {
    stop("Fixed debug experiment requires at least one stage in evaluation.debug_stages.", call. = FALSE)
  }

  series_metrics_all <- list()
  lead_metrics_all <- list()
  forecast_summary_all <- list()
  quantile_model_metrics_all <- list()
  rhs_diagnostics_all <- list()
  series_status_all <- list()
  selection_summary_all <- list()
  idx_sm <- idx_lm <- idx_fs <- idx_qm <- idx_rhs <- idx_st <- idx_sel <- 1L

  for (dataset_name in selected_datasets) {
    message(sprintf("[benchmark_qdesn_fixed_debug] dataset=%s", dataset_name))
    dataset_name_local <- as.character(dataset_name)[1L]
    meta_ds <- loaded$metadata[dataset == dataset_name_local]
    series_ids <- bench_qdesn_fixed_debug_series_ids(meta_ds, cfg, dataset_name_local)
    audit_ids <- bench_qdesn_override_series_ids(meta_ds, cfg, dataset_name_local, "audit")
    if (is.null(audit_ids)) {
      audit_ids <- series_ids
    }

    route_map <- bench_qdesn_route_map(
      loaded = loaded,
      dataset_name = dataset_name_local,
      series_ids = series_ids,
      cfg = cfg
    )
    if (!nrow(route_map)) {
      next
    }

    route_keys <- unique(route_map$route_key %||% "global")
    for (route_key in route_keys) {
      selection_summary_all[[idx_sel]] <- bench_qdesn_fixed_debug_selection_summary(
        dataset_name = dataset_name_local,
        route_key = route_key,
        candidate_id = candidate_cfg$candidate_id
      )
      idx_sel <- idx_sel + 1L
    }

    for (stage_name in debug_stages) {
      stage_results <- bench_qdesn_lapply(
        series_ids,
        function(series_id) {
          bundle <- bench_qdesn_assign_route(
            bench_qdesn_build_series_bundle(
              loaded,
              dataset_name_local,
              series_id,
              stage = stage_name,
              cfg = cfg
            ),
            cfg
          )

          if (!bench_qdesn_candidate_applicable(
            candidate_cfg,
            fit_n = length(bundle$fit_y),
            route_key = bundle$route_key %||% "global"
          )) {
            return(list(
              series_metrics = data.table::data.table(),
              lead_metrics = data.table::data.table(),
              forecast_summary = data.table::data.table(),
              quantile_model_metrics = data.table::data.table(),
              rhs_diagnostics = data.table::data.table(),
              series_status = bench_qdesn_status_row(
                bundle = bundle,
                model_name = "qdesn_synth",
                candidate_id = candidate_cfg$candidate_id,
                status = "inapplicable",
                runtime_sec = 0,
                notes = "fixed_debug_inapplicable"
              ),
              artifacts = NULL
            ))
          }

          keep_artifacts <- isTRUE(cfg$evaluation$audit$save_draws) &&
            identical(stage_name, "test") &&
            series_id %in% audit_ids

          bench_qdesn_evaluate_series_models(
            bundle = bundle,
            candidate_cfg = candidate_cfg,
            cfg = cfg,
            keep_audit_artifacts = keep_artifacts
          )
        },
        workers = as.integer(cfg$evaluation$parallel$workers %||% 1L)
      )

      for (res in stage_results) {
        if (nrow(res$series_metrics)) {
          series_metrics_all[[idx_sm]] <- res$series_metrics
          idx_sm <- idx_sm + 1L
        }
        if (nrow(res$lead_metrics)) {
          lead_metrics_all[[idx_lm]] <- res$lead_metrics
          idx_lm <- idx_lm + 1L
        }
        if (nrow(res$forecast_summary)) {
          forecast_summary_all[[idx_fs]] <- res$forecast_summary
          idx_fs <- idx_fs + 1L
        }
        if (nrow(res$quantile_model_metrics)) {
          quantile_model_metrics_all[[idx_qm]] <- res$quantile_model_metrics
          idx_qm <- idx_qm + 1L
        }
        if (nrow(res$rhs_diagnostics)) {
          rhs_diagnostics_all[[idx_rhs]] <- res$rhs_diagnostics
          idx_rhs <- idx_rhs + 1L
        }
        if (nrow(res$series_status)) {
          series_status_all[[idx_st]] <- res$series_status
          idx_st <- idx_st + 1L
        }
        if (!is.null(res$artifacts)) {
          bench_qdesn_save_audit_artifact(run_dirs, res)
        }
      }
    }
  }

  bind_or_empty <- function(lst) {
    if (!length(lst)) return(data.table::data.table())
    data.table::rbindlist(lst, fill = TRUE)
  }

  results <- list(
    series_metrics = bind_or_empty(series_metrics_all),
    lead_metrics = bind_or_empty(lead_metrics_all),
    forecast_summary = bind_or_empty(forecast_summary_all),
    quantile_model_metrics = bind_or_empty(quantile_model_metrics_all),
    rhs_diagnostics = bind_or_empty(rhs_diagnostics_all),
    series_status = bind_or_empty(series_status_all),
    model_selection_summary = bind_or_empty(selection_summary_all),
    model_selection_detail = data.table::data.table(),
    candidate_registry = candidate_registry,
    m4_comparability = data.table::data.table()
  )

  bench_qdesn_write_experiment_tables(results, run_dirs)
  summary_dt <- bench_qdesn_dataset_summary_table(results$series_metrics)
  bench_save_table(
    summary_dt,
    file.path(run_dirs$tables_dir, "dataset_model_summary"),
    write_csv = TRUE,
    write_rds = TRUE,
    compress = "gzip"
  )

  list(
    run_dirs = run_dirs,
    datasets = selected_datasets,
    results = results,
    summary = summary_dt
  )
}
