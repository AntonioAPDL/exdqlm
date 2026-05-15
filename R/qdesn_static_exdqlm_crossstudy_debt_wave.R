`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_static_crossstudy_debt_load_manifest <- function(path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml"),
                                                       repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Static cross-study debt-wave manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_static_crossstudy_pick_campaign_report_root <- function(path) {
  if (!dir.exists(path)) return(path)
  if (file.exists(file.path(path, "manifest", "campaign_manifest.json")) || dir.exists(file.path(path, "tables"))) {
    return(path)
  }
  children <- sort(list.dirs(path, recursive = FALSE, full.names = TRUE))
  keep <- children[
    grepl("__git-", basename(children)) &
      (file.exists(file.path(children, "manifest", "campaign_manifest.json")) | dir.exists(file.path(children, "tables")))
  ]
  if (length(keep)) utils::tail(keep, 1L) else path
}

.qdesn_static_crossstudy_pick_campaign_results_root <- function(path) {
  if (!dir.exists(path)) return(path)
  if (dir.exists(file.path(path, "roots"))) {
    return(path)
  }
  children <- sort(list.dirs(path, recursive = FALSE, full.names = TRUE))
  keep <- children[grepl("__git-", basename(children)) & dir.exists(file.path(children, "roots"))]
  if (length(keep)) utils::tail(keep, 1L) else path
}

qdesn_static_crossstudy_debt_resolve_source_run <- function(source_run_tag,
                                                            defaults = NULL,
                                                            defaults_path = file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml")) {
  defaults <- defaults %||% qdesn_static_crossstudy_load_defaults(defaults_path)
  campaign_cfg <- defaults$campaign %||% list()
  outer_results_root <- file.path(
    .qdesn_validation_resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy"), must_work = FALSE),
    source_run_tag
  )
  outer_report_root <- file.path(
    .qdesn_validation_resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy"), must_work = FALSE),
    source_run_tag
  )
  list(
    source_run_tag = source_run_tag,
    outer_results_root = outer_results_root,
    outer_report_root = outer_report_root,
    campaign_results_root = .qdesn_static_crossstudy_pick_campaign_results_root(outer_results_root),
    campaign_report_root = .qdesn_static_crossstudy_pick_campaign_report_root(outer_report_root)
  )
}

qdesn_static_crossstudy_debt_read_root_status <- function(campaign_results_root) {
  roots_dir <- file.path(campaign_results_root, "roots")
  root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
  if (!length(root_dirs)) {
    return(data.frame(
      root_id = character(0),
      root_status = character(0),
      root_dir = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    root_id = basename(root_dirs),
    root_status = vapply(
      root_dirs,
      function(root_dir) {
        status_path <- file.path(root_dir, "manifest", "root_status.txt")
        if (!file.exists(status_path)) return("MISSING")
        trimws(readLines(status_path, warn = FALSE, n = 1L))
      },
      character(1)
    ),
    root_dir = root_dirs,
    stringsAsFactors = FALSE
  )
}

qdesn_static_crossstudy_debt_collect_source_state <- function(source_run_tag,
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

  hard_fail_root_ids <- sort(unique(as.character(root_status$root_id[root_status$root_status == "FAIL"])))
  rhs_ns_noneligible_root_ids <- sort(unique(as.character(
    root_summary$root_id[
      as.character(root_summary$prior) == "rhs_ns" &
        !as.logical(root_summary$root_comparison_eligible_any)
    ]
  )))
  full_debt_root_ids <- sort(unique(c(hard_fail_root_ids, rhs_ns_noneligible_root_ids)))
  ridge_completed_root_ids <- sort(unique(as.character(
    root_summary$root_id[as.character(root_summary$prior) == "ridge"]
  )))

  list(
    source_roots = roots,
    source_run_tag = source_run_tag,
    grid = grid,
    root_status = root_status,
    root_summary = root_summary,
    fit_summary = fit_summary,
    hard_fail_root_ids = hard_fail_root_ids,
    rhs_ns_noneligible_root_ids = rhs_ns_noneligible_root_ids,
    full_debt_root_ids = full_debt_root_ids,
    ridge_completed_root_ids = ridge_completed_root_ids
  )
}

qdesn_static_crossstudy_debt_subset_grid <- function(grid_df, root_ids) {
  root_ids <- unique(as.character(root_ids))
  out <- grid_df[match(root_ids, grid_df$root_id, nomatch = 0L), , drop = FALSE]
  if (!nrow(out)) {
    stop("Debt-wave subset grid is empty.", call. = FALSE)
  }
  missing <- setdiff(root_ids, as.character(out$root_id))
  if (length(missing)) {
    stop(sprintf(
      "Debt-wave subset grid is missing requested root ids: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  out
}

qdesn_static_crossstudy_debt_apply_overrides <- function(base_defaults, overrides = NULL) {
  if (is.null(overrides) || !length(overrides)) return(base_defaults)
  utils::modifyList(base_defaults, overrides)
}

qdesn_static_crossstudy_debt_write_yaml <- function(x, path) {
  .qdesn_validation_require_namespace("yaml")
  .qdesn_validation_dir_create(dirname(path))
  yaml::write_yaml(x, path)
  invisible(path)
}

qdesn_static_crossstudy_debt_profile_metrics <- function(profile_id,
                                                         stage_name,
                                                         stage_root_ids,
                                                         hard_fail_root_ids,
                                                         run_obj) {
  root_status <- qdesn_static_crossstudy_debt_read_root_status(run_obj$results_root)
  root_summary <- run_obj$summary$root_summary %||% data.frame(stringsAsFactors = FALSE)
  fit_summary <- run_obj$summary$fit_summary %||% data.frame(stringsAsFactors = FALSE)

  stage_root_ids <- unique(as.character(stage_root_ids))
  hard_ids <- intersect(stage_root_ids, unique(as.character(hard_fail_root_ids)))

  root_status <- root_status[match(stage_root_ids, root_status$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(root_summary)) {
    root_summary <- root_summary[match(stage_root_ids, root_summary$root_id, nomatch = 0L), , drop = FALSE]
  }
  if (nrow(fit_summary)) {
    fit_summary <- fit_summary[fit_summary$root_id %in% stage_root_ids, , drop = FALSE]
  }

  data.frame(
    stage_name = stage_name,
    profile_id = profile_id,
    root_n_planned = length(stage_root_ids),
    root_n_status_success = sum(as.character(root_status$root_status) == "SUCCESS", na.rm = TRUE),
    root_n_status_fail = sum(as.character(root_status$root_status) == "FAIL", na.rm = TRUE),
    root_n_status_missing = sum(!stage_root_ids %in% as.character(root_status$root_id)),
    hard_fail_n_planned = length(hard_ids),
    hard_fail_n_rescued = sum(as.character(root_status$root_id) %in% hard_ids & as.character(root_status$root_status) == "SUCCESS", na.rm = TRUE),
    hard_fail_n_remaining = sum(as.character(root_status$root_id) %in% hard_ids & as.character(root_status$root_status) != "SUCCESS", na.rm = TRUE),
    root_n_compare_any = sum(as.logical(root_summary$root_comparison_eligible_any), na.rm = TRUE),
    root_n_compare_full = sum(as.logical(root_summary$root_comparison_eligible_full), na.rm = TRUE),
    fit_n_fail = sum(as.character(fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
    fit_n_warn = sum(as.character(fit_summary$signoff_grade) == "WARN", na.rm = TRUE),
    fit_n_pass = sum(as.character(fit_summary$signoff_grade) == "PASS", na.rm = TRUE),
    exal_mcmc_fail_n = sum(as.character(fit_summary$model) == "exal" & as.character(fit_summary$method) == "mcmc" & as.character(fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
    rhs_vb_fail_n = sum(as.character(fit_summary$prior) == "rhs_ns" & as.character(fit_summary$method) == "vb" & as.character(fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
    median_runtime_sec = if (nrow(fit_summary) && any(is.finite(as.numeric(fit_summary$runtime_sec)))) stats::median(as.numeric(fit_summary$runtime_sec), na.rm = TRUE) else NA_real_,
    stringsAsFactors = FALSE
  )
}

qdesn_static_crossstudy_debt_rank_profiles <- function(metrics_df) {
  if (!nrow(metrics_df)) return(metrics_df)
  metrics_df <- metrics_df[order(
    -as.numeric(metrics_df$hard_fail_n_rescued),
    -as.numeric(metrics_df$root_n_status_success),
    -as.numeric(metrics_df$root_n_compare_any),
    -as.numeric(metrics_df$root_n_compare_full),
    as.numeric(metrics_df$fit_n_fail),
    as.numeric(metrics_df$exal_mcmc_fail_n),
    as.numeric(metrics_df$median_runtime_sec)
  ), , drop = FALSE]
  metrics_df$rank <- seq_len(nrow(metrics_df))
  metrics_df
}

qdesn_static_crossstudy_debt_stage1_root_ids <- function(source_state, rhs_probe_root_ids = character(0)) {
  hard_fail_root_ids <- unique(as.character(source_state$hard_fail_root_ids %||% character(0)))
  rhs_probe_root_ids <- unique(as.character(rhs_probe_root_ids))
  out <- sort(unique(c(hard_fail_root_ids, rhs_probe_root_ids)))
  if (!length(out)) {
    stop("Stage-1 debt root set is empty.", call. = FALSE)
  }
  out
}

qdesn_static_crossstudy_debt_pick_top_experimental <- function(metrics_df,
                                                               anchor_profile_id,
                                                               top_n = 1L) {
  top_n <- as.integer(top_n %||% 1L)[1L]
  if (!is.finite(top_n) || top_n < 1L) top_n <- 1L
  ranked <- qdesn_static_crossstudy_debt_rank_profiles(metrics_df)
  ranked <- ranked[as.character(ranked$profile_id) != as.character(anchor_profile_id)[1L], , drop = FALSE]
  utils::head(as.character(ranked$profile_id), top_n)
}
