`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_static_crossstudy_residual_load_manifest <- function(path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave_manifest.yaml"),
                                                           repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Static cross-study residual MCMC closure manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_static_crossstudy_residual_match_selector <- function(df, selector = NULL) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  selector <- selector %||% list()
  if (!nrow(df) || !length(selector)) return(df)
  keep <- rep(TRUE, nrow(df))

  match_chr <- function(cols, values) {
    values <- as.character(unlist(values, use.names = FALSE))
    cols <- as.character(unlist(cols, use.names = FALSE))
    cols <- cols[cols %in% names(df)]
    if (!length(values) || !length(cols)) return(invisible(NULL))
    matched <- Reduce(
      `|`,
      lapply(cols, function(col) as.character(df[[col]]) %in% values)
    )
    keep <<- keep & matched
  }

  match_num <- function(cols, values) {
    values <- as.numeric(unlist(values, use.names = FALSE))
    cols <- as.character(unlist(cols, use.names = FALSE))
    cols <- cols[cols %in% names(df)]
    if (!length(values) || !length(cols)) return(invisible(NULL))
    matched <- Reduce(
      `|`,
      lapply(cols, function(col) as.numeric(df[[col]]) %in% values)
    )
    keep <<- keep & matched
  }

  match_chr("root_id", selector$root_id)
  match_chr(c("root_kind", "source_root_kind"), selector$root_kind)
  match_chr(c("family", "source_family"), selector$family)
  match_num("tau", selector$tau)
  match_num("fit_size", selector$fit_size)
  match_chr(c("prior", "beta_prior_type"), selector$prior %||% selector$beta_prior_type)
  match_chr("method", selector$method)
  match_chr(c("model", "likelihood_family"), selector$model %||% selector$likelihood_family)
  match_chr("signoff_grade", selector$signoff_grade)
  match_chr("signoff_reason", selector$signoff_reason)
  match_chr("root_status", selector$root_status)

  df[keep, , drop = FALSE]
}

.qdesn_static_crossstudy_residual_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.qdesn_static_crossstudy_residual_overlay_fit_rows <- function(base_df, overlay_df) {
  if (!nrow(base_df)) return(overlay_df)
  if (!nrow(overlay_df)) return(base_df)
  key_base <- paste(base_df$root_id, base_df$method, base_df$model, sep = "||")
  key_overlay <- paste(overlay_df$root_id, overlay_df$method, overlay_df$model, sep = "||")
  keep <- !(key_base %in% key_overlay)
  out <- exdqlm:::.qdesn_validation_bind_rows(list(base_df[keep, , drop = FALSE], overlay_df))
  out[order(out$root_id, out$method, out$model), , drop = FALSE]
}

.qdesn_static_crossstudy_residual_overlay_root_rows <- function(base_df, overlay_df) {
  if (!nrow(base_df)) return(overlay_df)
  if (!nrow(overlay_df)) return(base_df)
  keep <- !(as.character(base_df$root_id) %in% as.character(overlay_df$root_id))
  out <- exdqlm:::.qdesn_validation_bind_rows(list(base_df[keep, , drop = FALSE], overlay_df))
  out[order(out$root_id), , drop = FALSE]
}

.qdesn_static_crossstudy_residual_profile_report_root <- function(stage_report_root, profile_id) {
  .qdesn_static_crossstudy_pick_campaign_report_root(file.path(stage_report_root, "profiles", profile_id))
}

qdesn_static_crossstudy_residual_collect_source_state <- function(source_run_tag,
                                                                  defaults = NULL,
                                                                  grid = NULL,
                                                                  prior_wave_report_root = file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_fit_fail_closure_wave"),
                                                                  defaults_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"),
                                                                  grid_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv")) {
  .qdesn_validation_require_namespace("jsonlite")
  defaults <- defaults %||% qdesn_static_crossstudy_load_defaults(defaults_path)
  grid <- grid %||% qdesn_static_crossstudy_load_grid(grid_path)

  outer_report_root <- file.path(
    .qdesn_validation_resolve_path(prior_wave_report_root, must_work = FALSE),
    source_run_tag
  )
  completed_manifest_path <- file.path(outer_report_root, "manifest", "fit_fail_closure_completed.json")
  preflight_manifest_path <- file.path(
    outer_report_root,
    "launch",
    "qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_preflight_manifest.json"
  )
  current_wave_tables_present <- all(file.exists(c(
    file.path(outer_report_root, "tables", "promoted_source_fit_summary.csv"),
    file.path(outer_report_root, "tables", "promoted_source_root_signoff_summary.csv"),
    file.path(outer_report_root, "tables", "promoted_source_root_status.csv"),
    file.path(outer_report_root, "tables", "source_root_status_fail_grid.csv"),
    file.path(outer_report_root, "tables", "stage_execution_status.csv")
  )))

  if (file.exists(completed_manifest_path)) {
    completed_manifest <- jsonlite::fromJSON(completed_manifest_path)
    upstream_source_run_tag <- as.character(completed_manifest$source_run_tag %||% "")[1L]
    if (!nzchar(upstream_source_run_tag)) {
      stop("Completed fit-fail closure manifest is missing source_run_tag.", call. = FALSE)
    }

    upstream_source_state <- qdesn_static_crossstudy_fitfail_collect_source_state(
      source_run_tag = upstream_source_run_tag,
      defaults = defaults,
      grid = grid,
      defaults_path = defaults_path,
      grid_path = grid_path
    )

    stage_status <- .qdesn_static_crossstudy_residual_read_csv(file.path(outer_report_root, "tables", "stage_execution_status.csv"))
    if (!nrow(stage_status)) {
      stop(sprintf("Missing stage_execution_status.csv under %s", outer_report_root), call. = FALSE)
    }
    local_baseline_map <- .qdesn_static_crossstudy_residual_read_csv(file.path(outer_report_root, "tables", "local_baseline_map.csv"))

    promoted_fit_summary <- upstream_source_state$fit_summary
    promoted_root_summary <- upstream_source_state$root_summary
    promoted_root_status <- upstream_source_state$root_status
    original_source_run_tag <- upstream_source_run_tag
    original_source_root_fail_grid <- qdesn_static_crossstudy_debt_subset_grid(grid, upstream_source_state$root_fail_root_ids)
    original_source_state <- upstream_source_state
  } else if (current_wave_tables_present) {
    completed_manifest <- if (file.exists(preflight_manifest_path)) {
      jsonlite::fromJSON(preflight_manifest_path)
    } else {
      list()
    }
    stage_status <- .qdesn_static_crossstudy_residual_read_csv(file.path(outer_report_root, "tables", "stage_execution_status.csv"))
    if (!nrow(stage_status)) {
      stop(sprintf("Missing stage_execution_status.csv under %s", outer_report_root), call. = FALSE)
    }
    local_baseline_map <- .qdesn_static_crossstudy_residual_read_csv(file.path(outer_report_root, "tables", "source_local_baseline_map.csv"))

    promoted_fit_summary <- .qdesn_static_crossstudy_residual_read_csv(
      file.path(outer_report_root, "tables", "promoted_source_fit_summary.csv")
    )
    promoted_root_summary <- .qdesn_static_crossstudy_residual_read_csv(
      file.path(outer_report_root, "tables", "promoted_source_root_signoff_summary.csv")
    )
    promoted_root_status <- .qdesn_static_crossstudy_residual_read_csv(
      file.path(outer_report_root, "tables", "promoted_source_root_status.csv")
    )
    original_source_root_fail_grid <- .qdesn_static_crossstudy_residual_read_csv(
      file.path(outer_report_root, "tables", "source_root_status_fail_grid.csv")
    )
    original_source_run_tag <- as.character(
      completed_manifest$original_source_run_tag %||% completed_manifest$source_run_tag %||% ""
    )[1L]
    original_source_state <- list(
      root_fail_root_ids = unique(as.character(original_source_root_fail_grid$root_id))
    )
  } else {
    stop(
      sprintf(
        "Missing source state under %s; expected either a completed Wave-3 manifest or residual-wave source tables.",
        outer_report_root
      ),
      call. = FALSE
    )
  }

  winner_inventory <- list()

  for (i in seq_len(nrow(stage_status))) {
    stage_row <- stage_status[i, , drop = FALSE]
    if (!identical(as.character(stage_row$execution_status[1L]), "COMPLETED")) next
    stage_id <- as.character(stage_row$stage_id[1L])
    profile_id <- as.character(stage_row$recommended_profile[1L])
    stage_report_root <- as.character(stage_row$stage_report_root[1L])
    profile_report_root <- .qdesn_static_crossstudy_residual_profile_report_root(stage_report_root, profile_id)
    fit_path <- file.path(profile_report_root, "tables", "campaign_fit_summary.csv")
    root_path <- file.path(profile_report_root, "tables", "campaign_root_signoff_summary.csv")
    stage_root_ids_path <- file.path(stage_report_root, "tables", "stage_root_ids.csv")

    winner_fit_summary <- .qdesn_static_crossstudy_residual_read_csv(fit_path)
    winner_root_summary <- .qdesn_static_crossstudy_residual_read_csv(root_path)
    if (!nrow(winner_fit_summary) || !nrow(winner_root_summary)) {
      stop(sprintf("Winner profile '%s' for stage '%s' is missing campaign summary tables.", profile_id, stage_id), call. = FALSE)
    }

    promoted_fit_summary <- .qdesn_static_crossstudy_residual_overlay_fit_rows(promoted_fit_summary, winner_fit_summary)
    promoted_root_summary <- .qdesn_static_crossstudy_residual_overlay_root_rows(promoted_root_summary, winner_root_summary)
    promoted_root_status <- .qdesn_static_crossstudy_residual_overlay_root_rows(
      promoted_root_status,
      winner_root_summary[, c("root_id", "root_status"), drop = FALSE]
    )

    winner_inventory[[length(winner_inventory) + 1L]] <- data.frame(
      stage_id = stage_id,
      local_baseline_profile = profile_id,
      stage_report_root = stage_report_root,
      profile_report_root = profile_report_root,
      fit_summary_path = fit_path,
      root_summary_path = root_path,
      stage_root_ids_path = stage_root_ids_path,
      stringsAsFactors = FALSE
    )
  }

  promoted_fail_summary <- promoted_fit_summary[as.character(promoted_fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  original_source_root_fail_root_ids <- unique(as.character(original_source_root_fail_grid$root_id))

  list(
    source_run_tag = source_run_tag,
    outer_report_root = outer_report_root,
    completed_manifest = completed_manifest,
    local_baseline_map = local_baseline_map,
    stage_status = stage_status,
    winner_inventory = exdqlm:::.qdesn_validation_bind_rows(winner_inventory),
    original_source_run_tag = original_source_run_tag,
    original_source_state = original_source_state,
    promoted_fit_summary = promoted_fit_summary,
    promoted_root_summary = promoted_root_summary,
    promoted_root_status = promoted_root_status,
    promoted_fail_summary = promoted_fail_summary,
    original_source_root_fail_root_ids = original_source_root_fail_root_ids,
    original_source_root_fail_grid = original_source_root_fail_grid,
    grid = grid
  )
}

qdesn_static_crossstudy_residual_stage_root_ids <- function(source_state, grid_df, stage_cfg) {
  selector <- stage_cfg$stage_selector %||% stage_cfg$target_selector %||% list()
  fail_summary <- source_state$promoted_fit_summary
  fail_summary <- fail_summary[as.character(fail_summary$signoff_grade) == "FAIL", , drop = FALSE]
  matched_fail_dt <- .qdesn_static_crossstudy_residual_match_selector(fail_summary, selector)
  root_ids <- sort(unique(as.character(matched_fail_dt$root_id)))

  extra_root_fail_selector <- stage_cfg$include_source_root_status_fail_selector %||% list()
  if (length(extra_root_fail_selector)) {
    extra_fail_grid <- .qdesn_static_crossstudy_residual_match_selector(
      source_state$original_source_root_fail_grid,
      extra_root_fail_selector
    )
    root_ids <- sort(unique(c(root_ids, as.character(extra_fail_grid$root_id))))
  }

  if (!length(root_ids)) {
    stop(sprintf("Stage '%s' residual selector produced no roots.", as.character(stage_cfg$id %||% "UNKNOWN")), call. = FALSE)
  }

  stage_grid_df <- qdesn_static_crossstudy_debt_subset_grid(grid_df, root_ids)
  sort(unique(as.character(stage_grid_df$root_id)))
}

qdesn_static_crossstudy_residual_profile_metrics <- function(profile_id,
                                                             stage_name,
                                                             stage_root_ids,
                                                             run_obj,
                                                             stage_cfg) {
  root_status <- run_obj$summary$root_status %||% qdesn_static_crossstudy_debt_read_root_status(run_obj$results_root)
  root_summary <- run_obj$summary$root_summary %||% data.frame(stringsAsFactors = FALSE)
  fit_summary <- run_obj$summary$fit_summary %||% data.frame(stringsAsFactors = FALSE)
  stage_root_ids <- unique(as.character(stage_root_ids))

  root_status <- root_status[match(stage_root_ids, root_status$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(root_summary)) {
    root_summary <- root_summary[match(stage_root_ids, root_summary$root_id, nomatch = 0L), , drop = FALSE]
  }
  if (nrow(fit_summary)) {
    fit_summary <- fit_summary[fit_summary$root_id %in% stage_root_ids, , drop = FALSE]
  }

  fail_summary <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  target_selector <- stage_cfg$target_selector %||% stage_cfg$stage_selector %||% list()
  target_fail_dt <- .qdesn_static_crossstudy_residual_match_selector(fail_summary, target_selector)
  target_fail_root_ids <- unique(as.character(target_fail_dt$root_id))

  data.frame(
    stage_name = stage_name,
    profile_id = profile_id,
    root_n_planned = length(stage_root_ids),
    root_n_status_success = sum(as.character(root_status$root_status) == "SUCCESS", na.rm = TRUE),
    root_n_status_fail = sum(as.character(root_status$root_status) == "FAIL", na.rm = TRUE),
    root_n_status_missing = sum(!stage_root_ids %in% as.character(root_status$root_id)),
    root_n_compare_any = sum(as.logical(root_summary$root_comparison_eligible_any), na.rm = TRUE),
    root_n_compare_full = sum(as.logical(root_summary$root_comparison_eligible_full), na.rm = TRUE),
    fit_n_fail = nrow(fail_summary),
    fit_n_warn = sum(as.character(fit_summary$signoff_grade) == "WARN", na.rm = TRUE),
    fit_n_pass = sum(as.character(fit_summary$signoff_grade) == "PASS", na.rm = TRUE),
    target_fit_fail_n = nrow(target_fail_dt),
    target_root_fail_n = length(target_fail_root_ids),
    rhs_vb_fail_n = nrow(.qdesn_static_crossstudy_residual_match_selector(
      fail_summary,
      list(prior = "rhs_ns", method = "vb", signoff_reason = "rhs_diagnostics_missing")
    )),
    rhs_mcmc_fail_n = nrow(.qdesn_static_crossstudy_residual_match_selector(
      fail_summary,
      list(prior = "rhs_ns", method = "mcmc")
    )),
    ridge_exal_mcmc_fail_n = nrow(.qdesn_static_crossstudy_residual_match_selector(
      fail_summary,
      list(prior = "ridge", method = "mcmc", model = "exal")
    )),
    exal_mcmc_fail_n = nrow(.qdesn_static_crossstudy_residual_match_selector(
      fail_summary,
      list(method = "mcmc", model = "exal")
    )),
    mcmc_fail_n = nrow(.qdesn_static_crossstudy_residual_match_selector(
      fail_summary,
      list(method = "mcmc")
    )),
    median_runtime_sec = if (nrow(fit_summary) && any(is.finite(as.numeric(fit_summary$runtime_sec)))) {
      stats::median(as.numeric(fit_summary$runtime_sec), na.rm = TRUE)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}

qdesn_static_crossstudy_residual_rank_profiles <- function(metrics_df,
                                                           primary_metric = "target_fit_fail_n") {
  if (!nrow(metrics_df)) return(metrics_df)
  if (!primary_metric %in% names(metrics_df)) {
    stop(sprintf("Primary metric '%s' not found in residual metrics table.", primary_metric), call. = FALSE)
  }

  ord <- order(
    as.numeric(metrics_df$root_n_status_fail),
    as.numeric(metrics_df[[primary_metric]]),
    as.numeric(metrics_df$target_root_fail_n),
    as.numeric(metrics_df$fit_n_fail),
    -as.numeric(metrics_df$root_n_compare_full),
    -as.numeric(metrics_df$root_n_status_success),
    as.numeric(metrics_df$median_runtime_sec)
  )
  out <- metrics_df[ord, , drop = FALSE]
  out$rank <- seq_len(nrow(out))
  out
}

qdesn_static_crossstudy_residual_pick_stage_lead <- function(metrics_df,
                                                             control_profile_id,
                                                             primary_metric = "target_fit_fail_n") {
  ranked <- qdesn_static_crossstudy_residual_rank_profiles(metrics_df, primary_metric = primary_metric)
  if (!nrow(ranked)) return(as.character(control_profile_id)[1L])

  control_profile_id <- as.character(control_profile_id)[1L]
  control_row <- ranked[as.character(ranked$profile_id) == control_profile_id, , drop = FALSE]
  best_row <- ranked[1, , drop = FALSE]
  if (!nrow(control_row)) return(as.character(best_row$profile_id[1L]))
  if (identical(as.character(best_row$profile_id[1L]), control_profile_id)) return(control_profile_id)

  best_root_fail <- as.numeric(best_row$root_n_status_fail[1L])
  control_root_fail <- as.numeric(control_row$root_n_status_fail[1L])
  best_primary <- as.numeric(best_row[[primary_metric]][1L])
  control_primary <- as.numeric(control_row[[primary_metric]][1L])
  best_fail <- as.numeric(best_row$fit_n_fail[1L])
  control_fail <- as.numeric(control_row$fit_n_fail[1L])

  if (is.finite(best_root_fail) && is.finite(control_root_fail) && best_root_fail < control_root_fail) {
    return(as.character(best_row$profile_id[1L]))
  }
  if (is.finite(best_root_fail) && is.finite(control_root_fail) &&
      best_root_fail == control_root_fail &&
      is.finite(best_primary) && is.finite(control_primary) &&
      best_primary < control_primary) {
    return(as.character(best_row$profile_id[1L]))
  }
  if (is.finite(best_root_fail) && is.finite(control_root_fail) &&
      best_root_fail == control_root_fail &&
      is.finite(best_primary) && is.finite(control_primary) &&
      best_primary == control_primary &&
      is.finite(best_fail) && is.finite(control_fail) &&
      best_fail < control_fail) {
    return(as.character(best_row$profile_id[1L]))
  }
  control_profile_id
}
