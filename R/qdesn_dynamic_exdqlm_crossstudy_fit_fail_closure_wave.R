`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_crossstudy_fitfail_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml"),
                                                           repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic cross-study fit-fail closure manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_crossstudy_fitfail_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.qdesn_dynamic_crossstudy_fitfail_pick_campaign_root <- function(outer_root, required_child = "tables") {
  outer_root <- .qdesn_validation_resolve_path(outer_root, must_work = TRUE)
  if (dir.exists(file.path(outer_root, required_child))) {
    return(outer_root)
  }
  kids <- sort(list.dirs(outer_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (kid in kids) {
    if (dir.exists(file.path(kid, required_child))) return(kid)
  }
  stop(sprintf("Unable to locate dynamic cross-study campaign root under %s", outer_root), call. = FALSE)
}

.qdesn_dynamic_crossstudy_fitfail_match_selector <- function(df, selector = NULL) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  selector <- selector %||% list()
  if (!nrow(df) || !length(selector)) return(df)
  keep <- rep(TRUE, nrow(df))

  match_chr <- function(cols, values) {
    values <- as.character(unlist(values, use.names = FALSE))
    cols <- as.character(unlist(cols, use.names = FALSE))
    cols <- cols[cols %in% names(df)]
    if (!length(values) || !length(cols)) return(invisible(NULL))
    matched <- Reduce(`|`, lapply(cols, function(col) as.character(df[[col]]) %in% values))
    keep <<- keep & matched
  }

  match_num <- function(cols, values) {
    values <- as.numeric(unlist(values, use.names = FALSE))
    cols <- as.character(unlist(cols, use.names = FALSE))
    cols <- cols[cols %in% names(df)]
    if (!length(values) || !length(cols)) return(invisible(NULL))
    matched <- Reduce(`|`, lapply(cols, function(col) as.numeric(df[[col]]) %in% values))
    keep <<- keep & matched
  }

  match_chr("root_id", selector$root_id)
  match_chr(c("scenario", "source_scenario"), selector$scenario)
  match_chr(c("root_kind", "source_root_kind"), selector$root_kind)
  match_chr(c("family", "source_family"), selector$family)
  match_num("tau", selector$tau)
  match_num("fit_size", selector$fit_size)
  match_chr(c("prior", "beta_prior_type"), selector$prior %||% selector$beta_prior_type)
  match_chr(c("inference", "method"), selector$inference %||% selector$method)
  match_chr(c("model", "likelihood_family"), selector$model %||% selector$likelihood_family)
  match_chr("signoff_grade", selector$signoff_grade)
  match_chr("signoff_reason", selector$signoff_reason)
  match_chr("root_status", selector$root_status)

  df[keep, , drop = FALSE]
}

qdesn_dynamic_crossstudy_fitfail_collect_source_state <- function(source_run_tag,
                                                                  source_report_root = file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"),
                                                                  defaults = NULL,
                                                                  grid = NULL,
                                                                  defaults_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"),
                                                                  grid_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv")) {
  defaults <- defaults %||% qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- grid %||% qdesn_dynamic_crossstudy_load_grid(grid_path)

  outer_report_root <- file.path(
    .qdesn_validation_resolve_path(source_report_root, must_work = FALSE),
    source_run_tag
  )
  campaign_report_root <- .qdesn_dynamic_crossstudy_fitfail_pick_campaign_root(outer_report_root, required_child = "tables")

  fit_summary <- .qdesn_dynamic_crossstudy_fitfail_read_csv(file.path(campaign_report_root, "tables", "campaign_fit_summary.csv"))
  root_summary <- .qdesn_dynamic_crossstudy_fitfail_read_csv(file.path(campaign_report_root, "tables", "campaign_root_signoff_summary.csv"))
  progress <- .qdesn_dynamic_crossstudy_fitfail_read_csv(file.path(campaign_report_root, "tables", "campaign_progress.csv"))
  if (!nrow(fit_summary) || !nrow(root_summary)) {
    stop(sprintf("Source run '%s' is missing campaign fit/root summary tables.", source_run_tag), call. = FALSE)
  }

  fail_summary <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  fail_root_ids <- sort(unique(as.character(fail_summary$root_id)))

  list(
    source_run_tag = source_run_tag,
    outer_report_root = outer_report_root,
    campaign_report_root = campaign_report_root,
    fit_summary = fit_summary,
    root_summary = root_summary,
    progress = progress,
    fail_summary = fail_summary,
    fail_root_ids = fail_root_ids,
    grid = grid,
    defaults = defaults
  )
}

qdesn_dynamic_crossstudy_fitfail_stage_root_ids <- function(source_state, grid_df, stage_cfg) {
  selector <- stage_cfg$stage_selector %||% stage_cfg$target_selector %||% list()
  matched_fail_dt <- .qdesn_dynamic_crossstudy_fitfail_match_selector(source_state$fail_summary, selector)
  root_ids <- sort(unique(as.character(matched_fail_dt$root_id)))
  if (!length(root_ids)) {
    stop(sprintf("Stage '%s' selector produced no roots.", as.character(stage_cfg$id %||% "UNKNOWN")), call. = FALSE)
  }
  stage_grid_df <- qdesn_static_crossstudy_debt_subset_grid(grid_df, root_ids)
  sort(unique(as.character(stage_grid_df$root_id)))
}

.qdesn_dynamic_crossstudy_fitfail_safe_num <- function(x, default = Inf) {
  out <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(out)) default else out
}

qdesn_dynamic_crossstudy_fitfail_profile_metrics <- function(profile_id,
                                                             stage_name,
                                                             stage_root_ids,
                                                             run_obj,
                                                             stage_cfg) {
  root_summary <- run_obj$summary$root_summary %||% data.frame(stringsAsFactors = FALSE)
  fit_summary <- run_obj$summary$fit_summary %||% data.frame(stringsAsFactors = FALSE)

  stage_root_ids <- unique(as.character(stage_root_ids))
  if (nrow(root_summary)) {
    root_summary <- root_summary[match(stage_root_ids, root_summary$root_id, nomatch = 0L), , drop = FALSE]
  }
  if (nrow(fit_summary)) {
    fit_summary <- fit_summary[fit_summary$root_id %in% stage_root_ids, , drop = FALSE]
  }

  fail_summary <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  target_selector <- stage_cfg$target_selector %||% stage_cfg$stage_selector %||% list()
  target_fail_dt <- .qdesn_dynamic_crossstudy_fitfail_match_selector(fail_summary, target_selector)
  target_fail_root_ids <- sort(unique(as.character(target_fail_dt$root_id)))

  root_n_seen <- if (nrow(root_summary)) length(unique(as.character(root_summary$root_id))) else 0L
  any_vals <- if (nrow(root_summary) && "root_comparison_eligible_any" %in% names(root_summary)) {
    as.logical(root_summary$root_comparison_eligible_any)
  } else logical(0)
  full_vals <- if (nrow(root_summary) && "root_comparison_eligible_full" %in% names(root_summary)) {
    as.logical(root_summary$root_comparison_eligible_full)
  } else logical(0)

  data.frame(
    stage_name = stage_name,
    profile_id = profile_id,
    root_n_planned = length(stage_root_ids),
    root_n_status_success = sum(as.character(root_summary$root_status) == "SUCCESS", na.rm = TRUE),
    root_n_status_fail = sum(as.character(root_summary$root_status) == "FAIL", na.rm = TRUE),
    root_n_status_missing = length(stage_root_ids) - root_n_seen,
    root_n_compare_any = sum(any_vals, na.rm = TRUE),
    root_n_compare_full = sum(full_vals, na.rm = TRUE),
    root_n_noneligible = sum(!any_vals, na.rm = TRUE),
    fit_n_fail = nrow(fail_summary),
    fit_n_warn = sum(as.character(fit_summary$signoff_grade) == "WARN", na.rm = TRUE),
    fit_n_pass = sum(as.character(fit_summary$signoff_grade) == "PASS", na.rm = TRUE),
    target_fit_fail_n = nrow(target_fail_dt),
    target_root_fail_n = length(target_fail_root_ids),
    vb_fail_n = sum(as.character(fail_summary$inference) == "vb", na.rm = TRUE),
    mcmc_fail_n = sum(as.character(fail_summary$inference) == "mcmc", na.rm = TRUE),
    exal_fail_n = sum(as.character(fail_summary$model) == "exal", na.rm = TRUE),
    al_fail_n = sum(as.character(fail_summary$model) == "al", na.rm = TRUE),
    vb_exal_fail_n = sum(as.character(fail_summary$inference) == "vb" & as.character(fail_summary$model) == "exal", na.rm = TRUE),
    mcmc_exal_fail_n = sum(as.character(fail_summary$inference) == "mcmc" & as.character(fail_summary$model) == "exal", na.rm = TRUE),
    median_runtime_sec = if (nrow(fit_summary) && "runtime_sec" %in% names(fit_summary)) stats::median(as.numeric(fit_summary$runtime_sec), na.rm = TRUE) else NA_real_,
    error_message = "",
    stringsAsFactors = FALSE
  )
}

.qdesn_dynamic_crossstudy_fitfail_metric_vector <- function(row, primary_metric = "target_fit_fail_n") {
  c(
    .qdesn_dynamic_crossstudy_fitfail_safe_num(row[[primary_metric]], default = 1e9),
    .qdesn_dynamic_crossstudy_fitfail_safe_num(row[["target_root_fail_n"]], default = 1e9),
    .qdesn_dynamic_crossstudy_fitfail_safe_num(row[["root_n_status_fail"]], default = 1e9),
    .qdesn_dynamic_crossstudy_fitfail_safe_num(row[["root_n_noneligible"]], default = 1e9),
    -.qdesn_dynamic_crossstudy_fitfail_safe_num(row[["root_n_compare_full"]], default = 0),
    -.qdesn_dynamic_crossstudy_fitfail_safe_num(row[["root_n_compare_any"]], default = 0),
    .qdesn_dynamic_crossstudy_fitfail_safe_num(row[["fit_n_fail"]], default = 1e9),
    -.qdesn_dynamic_crossstudy_fitfail_safe_num(row[["fit_n_pass"]], default = 0),
    .qdesn_dynamic_crossstudy_fitfail_safe_num(row[["median_runtime_sec"]], default = 1e9)
  )
}

.qdesn_dynamic_crossstudy_fitfail_is_better <- function(candidate_row, source_row, primary_metric = "target_fit_fail_n") {
  cand_vec <- .qdesn_dynamic_crossstudy_fitfail_metric_vector(candidate_row, primary_metric = primary_metric)
  src_vec <- .qdesn_dynamic_crossstudy_fitfail_metric_vector(source_row, primary_metric = primary_metric)
  for (i in seq_along(cand_vec)) {
    if (cand_vec[[i]] < src_vec[[i]]) return(TRUE)
    if (cand_vec[[i]] > src_vec[[i]]) return(FALSE)
  }
  FALSE
}

qdesn_dynamic_crossstudy_fitfail_rank_profiles <- function(metrics_df, primary_metric = "target_fit_fail_n") {
  if (!nrow(metrics_df)) return(metrics_df)
  score_mat <- t(apply(metrics_df, 1L, function(row) {
    .qdesn_dynamic_crossstudy_fitfail_metric_vector(as.list(row), primary_metric = primary_metric)
  }))
  score_df <- as.data.frame(score_mat, stringsAsFactors = FALSE)
  names(score_df) <- c(
    "score_primary",
    "score_target_root_fail",
    "score_root_status_fail",
    "score_root_noneligible",
    "score_compare_full",
    "score_compare_any",
    "score_fit_fail",
    "score_fit_pass",
    "score_runtime"
  )
  out <- cbind(metrics_df, score_df)
  out <- out[do.call(order, out[, names(score_df), drop = FALSE]), , drop = FALSE]
  out$rank <- seq_len(nrow(out))
  out
}

qdesn_dynamic_crossstudy_fitfail_pick_stage_lead <- function(metrics_df,
                                                             source_metric,
                                                             primary_metric = "target_fit_fail_n") {
  if (!nrow(metrics_df)) return("SOURCE_BASELINE")
  ranked <- qdesn_dynamic_crossstudy_fitfail_rank_profiles(metrics_df, primary_metric = primary_metric)
  for (i in seq_len(nrow(ranked))) {
    candidate <- ranked[i, , drop = FALSE]
    if (.qdesn_dynamic_crossstudy_fitfail_is_better(candidate, source_metric, primary_metric = primary_metric)) {
      return(as.character(candidate$profile_id)[1L])
    }
  }
  "SOURCE_BASELINE"
}
