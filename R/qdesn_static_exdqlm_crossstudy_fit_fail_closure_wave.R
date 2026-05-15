`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_static_crossstudy_fitfail_load_manifest <- function(path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml"),
                                                          repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Static cross-study fit-fail closure manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_static_crossstudy_fitfail_match_selector <- function(df, selector = NULL) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  selector <- selector %||% list()
  if (!nrow(df) || !length(selector)) return(df)
  keep <- rep(TRUE, nrow(df))

  match_chr <- function(col, values) {
    values <- as.character(unlist(values, use.names = FALSE))
    if (!length(values) || !col %in% names(df)) return(invisible(NULL))
    keep <<- keep & as.character(df[[col]]) %in% values
  }

  match_num <- function(col, values) {
    values <- as.numeric(unlist(values, use.names = FALSE))
    if (!length(values) || !col %in% names(df)) return(invisible(NULL))
    keep <<- keep & as.numeric(df[[col]]) %in% values
  }

  match_chr("root_id", selector$root_id)
  match_chr("root_kind", selector$root_kind)
  match_chr("family", selector$family)
  match_num("tau", selector$tau)
  match_num("fit_size", selector$fit_size)
  match_chr("prior", selector$prior %||% selector$beta_prior_type)
  match_chr("method", selector$method)
  match_chr("model", selector$model %||% selector$likelihood_family)
  match_chr("signoff_grade", selector$signoff_grade)
  match_chr("signoff_reason", selector$signoff_reason)

  df[keep, , drop = FALSE]
}

qdesn_static_crossstudy_fitfail_collect_source_state <- function(source_run_tag,
                                                                 defaults = NULL,
                                                                 grid = NULL,
                                                                 defaults_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"),
                                                                 grid_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv")) {
  defaults <- defaults %||% qdesn_static_crossstudy_load_defaults(defaults_path)
  grid <- grid %||% qdesn_static_crossstudy_load_grid(grid_path)
  roots <- qdesn_static_crossstudy_debt_resolve_source_run(
    source_run_tag = source_run_tag,
    defaults = defaults,
    defaults_path = defaults_path
  )
  root_status <- qdesn_static_crossstudy_debt_read_root_status(roots$campaign_results_root)
  root_summary <- .qdesn_static_crossstudy_collect_root_tables(root_status$root_dir, "root_signoff_summary.csv")
  fit_summary <- .qdesn_static_crossstudy_collect_root_tables(root_status$root_dir, "fit_summary.csv")
  if (!nrow(fit_summary)) {
    stop("Source cross-study fit summary inventory is empty.", call. = FALSE)
  }

  rhs_ns_vb_diag_dt <- .qdesn_static_crossstudy_fitfail_match_selector(
    fit_summary,
    list(prior = "rhs_ns", method = "vb", signoff_grade = "FAIL", signoff_reason = "rhs_diagnostics_missing")
  )
  ridge_exal_mcmc_dt <- .qdesn_static_crossstudy_fitfail_match_selector(
    fit_summary,
    list(prior = "ridge", method = "mcmc", model = "exal", signoff_grade = "FAIL")
  )
  rhs_ns_mcmc_dt <- .qdesn_static_crossstudy_fitfail_match_selector(
    fit_summary,
    list(prior = "rhs_ns", method = "mcmc", signoff_grade = "FAIL")
  )

  rhs_ns_vb_diagnostics_root_ids <- sort(unique(as.character(rhs_ns_vb_diag_dt$root_id)))
  ridge_exal_mcmc_root_ids <- sort(unique(as.character(ridge_exal_mcmc_dt$root_id)))
  rhs_ns_mcmc_root_ids <- sort(unique(as.character(rhs_ns_mcmc_dt$root_id)))
  root_fail_root_ids <- sort(unique(as.character(root_status$root_id[root_status$root_status == "FAIL"])))
  bug_only_root_ids <- sort(setdiff(rhs_ns_vb_diagnostics_root_ids, rhs_ns_mcmc_root_ids))
  all_fit_fail_root_ids <- sort(unique(as.character(fit_summary$root_id[as.character(fit_summary$signoff_grade) == "FAIL"])))
  remaining_fit_fail_root_ids <- sort(unique(c(ridge_exal_mcmc_root_ids, rhs_ns_mcmc_root_ids)))

  list(
    source_roots = roots,
    source_run_tag = source_run_tag,
    grid = grid,
    root_status = root_status,
    root_summary = root_summary,
    fit_summary = fit_summary,
    root_fail_root_ids = root_fail_root_ids,
    all_fit_fail_root_ids = all_fit_fail_root_ids,
    rhs_ns_vb_diagnostics_root_ids = rhs_ns_vb_diagnostics_root_ids,
    ridge_exal_mcmc_root_ids = ridge_exal_mcmc_root_ids,
    rhs_ns_mcmc_root_ids = rhs_ns_mcmc_root_ids,
    bug_only_root_ids = bug_only_root_ids,
    remaining_fit_fail_root_ids = remaining_fit_fail_root_ids
  )
}

qdesn_static_crossstudy_fitfail_stage_root_ids <- function(source_state, grid_df, stage_cfg) {
  bucket <- as.character(stage_cfg$bucket %||% "")[1L]
  root_ids <- switch(
    bucket,
    rhs_ns_vb_diagnostics = source_state$rhs_ns_vb_diagnostics_root_ids,
    ridge_exal_mcmc_fail = source_state$ridge_exal_mcmc_root_ids,
    rhs_ns_mcmc_fail = source_state$rhs_ns_mcmc_root_ids,
    root_status_fail = source_state$root_fail_root_ids,
    remaining_fit_fail = source_state$remaining_fit_fail_root_ids,
    stop(sprintf("Unsupported fit-fail closure bucket '%s'.", bucket), call. = FALSE)
  )

  stage_grid_df <- qdesn_static_crossstudy_debt_subset_grid(grid_df, root_ids)
  stage_grid_df <- .qdesn_static_crossstudy_fitfail_match_selector(stage_grid_df, stage_cfg$filters %||% list())
  if (!nrow(stage_grid_df)) {
    stop(sprintf("Stage '%s' root selector produced no rows.", as.character(stage_cfg$id %||% bucket)), call. = FALSE)
  }
  sort(unique(as.character(stage_grid_df$root_id)))
}

qdesn_static_crossstudy_fitfail_profile_metrics <- function(profile_id,
                                                            stage_name,
                                                            stage_root_ids,
                                                            run_obj,
                                                            stage_cfg) {
  root_status <- qdesn_static_crossstudy_debt_read_root_status(run_obj$results_root)
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
  target_fail_dt <- .qdesn_static_crossstudy_fitfail_match_selector(fail_summary, stage_cfg$target_selector %||% list())
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
    rhs_vb_fail_n = nrow(.qdesn_static_crossstudy_fitfail_match_selector(
      fail_summary,
      list(prior = "rhs_ns", method = "vb", signoff_reason = "rhs_diagnostics_missing")
    )),
    rhs_mcmc_fail_n = nrow(.qdesn_static_crossstudy_fitfail_match_selector(
      fail_summary,
      list(prior = "rhs_ns", method = "mcmc")
    )),
    ridge_exal_mcmc_fail_n = nrow(.qdesn_static_crossstudy_fitfail_match_selector(
      fail_summary,
      list(prior = "ridge", method = "mcmc", model = "exal")
    )),
    exal_mcmc_fail_n = nrow(.qdesn_static_crossstudy_fitfail_match_selector(
      fail_summary,
      list(method = "mcmc", model = "exal")
    )),
    mcmc_fail_n = nrow(.qdesn_static_crossstudy_fitfail_match_selector(
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

qdesn_static_crossstudy_fitfail_rank_profiles <- function(metrics_df,
                                                          primary_metric = "target_fit_fail_n") {
  if (!nrow(metrics_df)) return(metrics_df)
  if (!primary_metric %in% names(metrics_df)) {
    stop(sprintf("Primary metric '%s' not found in metrics table.", primary_metric), call. = FALSE)
  }

  ord <- order(
    as.numeric(metrics_df[[primary_metric]]),
    as.numeric(metrics_df$target_root_fail_n),
    as.numeric(metrics_df$fit_n_fail),
    -as.numeric(metrics_df$root_n_status_success),
    as.numeric(metrics_df$median_runtime_sec)
  )
  out <- metrics_df[ord, , drop = FALSE]
  out$rank <- seq_len(nrow(out))
  out
}

qdesn_static_crossstudy_fitfail_pick_stage_lead <- function(metrics_df,
                                                            anchor_profile_id,
                                                            primary_metric = "target_fit_fail_n") {
  ranked <- qdesn_static_crossstudy_fitfail_rank_profiles(metrics_df, primary_metric = primary_metric)
  if (!nrow(ranked)) {
    return(as.character(anchor_profile_id)[1L])
  }

  anchor_profile_id <- as.character(anchor_profile_id)[1L]
  anchor_row <- ranked[as.character(ranked$profile_id) == anchor_profile_id, , drop = FALSE]
  best_row <- ranked[1, , drop = FALSE]
  if (!nrow(anchor_row)) return(as.character(best_row$profile_id[1L]))
  if (identical(as.character(best_row$profile_id[1L]), anchor_profile_id)) return(anchor_profile_id)

  best_primary <- as.numeric(best_row[[primary_metric]][1L])
  anchor_primary <- as.numeric(anchor_row[[primary_metric]][1L])
  best_fail <- as.numeric(best_row$fit_n_fail[1L])
  anchor_fail <- as.numeric(anchor_row$fit_n_fail[1L])

  if (is.finite(best_primary) && is.finite(anchor_primary) && best_primary < anchor_primary) {
    return(as.character(best_row$profile_id[1L]))
  }
  if (is.finite(best_primary) && is.finite(anchor_primary) &&
      best_primary == anchor_primary &&
      is.finite(best_fail) && is.finite(anchor_fail) &&
      best_fail < anchor_fail) {
    return(as.character(best_row$profile_id[1L]))
  }
  anchor_profile_id
}
