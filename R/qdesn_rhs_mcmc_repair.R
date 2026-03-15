`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_rhs_mcmc_repair_load_matrix <- function(path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
                                              repo_root = NULL) {
  csv_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("RHS MCMC repair matrix CSV is empty.", call. = FALSE)
  }
  out
}

qdesn_rhs_mcmc_repair_load_profiles <- function(path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"),
                                                repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("RHS MCMC repair profiles YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_rhs_mcmc_repair_field_is_placeholder <- function(x) {
  x <- trimws(as.character(x %||% ""))
  !nzchar(x) || identical(tolower(x), "na") || startsWith(tolower(x), "best_from_") || identical(tolower(x), "n/a")
}

.qdesn_rhs_mcmc_repair_parse_bool <- function(x) {
  x <- trimws(as.character(x %||% ""))
  if (!nzchar(x) || identical(tolower(x), "na")) return(NA)
  switch(tolower(x),
         "true" = TRUE,
         "false" = FALSE,
         stop(sprintf("Cannot parse boolean value '%s'.", x), call. = FALSE))
}

.qdesn_rhs_mcmc_repair_parse_int <- function(x) {
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(x)) return(NA_integer_)
  as.integer(x)[1L]
}

.qdesn_rhs_mcmc_repair_parse_num <- function(x) {
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(x)) return(NA_real_)
  as.numeric(x)[1L]
}

.qdesn_rhs_mcmc_repair_select_row <- function(matrix_df, experiment_id = NULL, run_order = NULL) {
  if (!is.null(experiment_id)) {
    idx <- which(as.character(matrix_df$experiment_id) == as.character(experiment_id)[1L])
  } else if (!is.null(run_order)) {
    idx <- which(as.integer(matrix_df$run_order) == as.integer(run_order)[1L])
  } else {
    stop("Provide experiment_id or run_order.", call. = FALSE)
  }
  if (!length(idx)) {
    stop("Requested RHS MCMC repair experiment was not found in the matrix.", call. = FALSE)
  }
  matrix_df[idx[[1L]], , drop = FALSE]
}

.qdesn_rhs_mcmc_repair_root_set_path <- function(root_set, profiles, repo_root = NULL) {
  root_sets <- profiles$root_sets %||% list()
  rel <- root_sets[[as.character(root_set)[1L]]] %||% NULL
  if (is.null(rel)) {
    stop(sprintf("Unknown RHS MCMC repair root_set '%s'.", as.character(root_set)[1L]), call. = FALSE)
  }
  .qdesn_validation_resolve_path(rel, repo_root = repo_root, must_work = TRUE)
}

.qdesn_rhs_mcmc_repair_vb_profile <- function(profile_name, profiles) {
  profs <- profiles$vb_warm_start_profiles %||% list()
  prof <- profs[[as.character(profile_name)[1L]]] %||% NULL
  if (is.null(prof)) {
    stop(sprintf("Unknown RHS MCMC repair VB warm-start profile '%s'.", as.character(profile_name)[1L]), call. = FALSE)
  }
  prof
}

qdesn_rhs_mcmc_repair_resolve_experiment <- function(experiment_id = NULL,
                                                     run_order = NULL,
                                                     matrix_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
                                                     profiles_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"),
                                                     vb_warm_start_profile_override = NULL,
                                                     freeze_tau_burnin_iters_override = NULL,
                                                     freeze_tau_only_during_burn_override = NULL,
                                                     repo_root = NULL) {
  repo_root <- .qdesn_validation_repo_root(repo_root)
  matrix_df <- qdesn_rhs_mcmc_repair_load_matrix(matrix_path, repo_root = repo_root)
  profiles <- qdesn_rhs_mcmc_repair_load_profiles(profiles_path, repo_root = repo_root)
  row <- .qdesn_rhs_mcmc_repair_select_row(matrix_df, experiment_id = experiment_id, run_order = run_order)

  vb_profile_name <- as.character(vb_warm_start_profile_override %||% row$vb_warm_start_profile)[1L]
  freeze_tau_burnin_iters <- if (is.null(freeze_tau_burnin_iters_override)) {
    .qdesn_rhs_mcmc_repair_parse_int(row$mcmc_rhs_freeze_tau_burnin_iters)
  } else {
    as.integer(freeze_tau_burnin_iters_override)[1L]
  }
  freeze_tau_only_during_burn <- if (is.null(freeze_tau_only_during_burn_override)) {
    .qdesn_rhs_mcmc_repair_parse_bool(row$mcmc_rhs_freeze_tau_only_during_burn)
  } else {
    isTRUE(freeze_tau_only_during_burn_override)
  }

  executable <- TRUE
  blockers <- character(0)

  if (isTRUE(.qdesn_rhs_mcmc_repair_parse_bool(row$multichain))) {
    executable <- FALSE
    blockers <- c(blockers, "multichain_experiment_not_yet_implemented")
  }
  if (.qdesn_rhs_mcmc_repair_field_is_placeholder(vb_profile_name)) {
    executable <- FALSE
    blockers <- c(blockers, "vb_warm_start_profile_placeholder")
  }
  if (!is.finite(freeze_tau_burnin_iters) || freeze_tau_burnin_iters < 0L) {
    executable <- FALSE
    blockers <- c(blockers, "mcmc_rhs_freeze_tau_burnin_iters_placeholder")
  }
  if (any(is.na(c(
    .qdesn_rhs_mcmc_repair_parse_int(row$n_burn),
    .qdesn_rhs_mcmc_repair_parse_int(row$n_mcmc),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_gamma),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_lambda),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_tau),
    .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_c2),
    .qdesn_rhs_mcmc_repair_parse_int(row$max_steps_out),
    .qdesn_rhs_mcmc_repair_parse_int(row$max_shrink)
  )))) {
    executable <- FALSE
    blockers <- c(blockers, "numeric_control_placeholder")
  }

  root_grid_path <- .qdesn_rhs_mcmc_repair_root_set_path(row$root_set, profiles, repo_root = repo_root)
  vb_profile <- if (!.qdesn_rhs_mcmc_repair_field_is_placeholder(vb_profile_name)) {
    .qdesn_rhs_mcmc_repair_vb_profile(vb_profile_name, profiles)
  } else {
    NULL
  }

  defaults_path <- .qdesn_validation_resolve_path(as.character(row$defaults_base)[1L], repo_root = repo_root, must_work = TRUE)
  defaults <- qdesn_validation_load_defaults(defaults_path, repo_root = repo_root)
  defaults$campaign$name <- as.character(row$experiment_id)[1L]
  defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_mcmc_repair", as.character(row$experiment_id)[1L])
  defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_mcmc_repair", as.character(row$experiment_id)[1L])

  rhs_override <- defaults$pipeline$inference$mcmc$prior_overrides$rhs %||% list()
  rhs_override$n_burn <- .qdesn_rhs_mcmc_repair_parse_int(row$n_burn)
  rhs_override$n_mcmc <- .qdesn_rhs_mcmc_repair_parse_int(row$n_mcmc)
  rhs_override$slice <- modifyList(rhs_override$slice %||% list(), list(
    width_gamma = .qdesn_rhs_mcmc_repair_parse_num(row$width_gamma),
    width_rhs_lambda = .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_lambda),
    width_rhs_tau = .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_tau),
    width_rhs_c2 = .qdesn_rhs_mcmc_repair_parse_num(row$width_rhs_c2),
    max_steps_out = .qdesn_rhs_mcmc_repair_parse_int(row$max_steps_out),
    max_shrink = .qdesn_rhs_mcmc_repair_parse_int(row$max_shrink)
  ))
  rhs_override$rhs <- modifyList(rhs_override$rhs %||% list(), list(
    freeze_tau_burnin_iters = freeze_tau_burnin_iters,
    freeze_tau_only_during_burn = isTRUE(freeze_tau_only_during_burn)
  ))
  if (!is.null(vb_profile)) {
    rhs_override$vb_warm_start_control <- modifyList(rhs_override$vb_warm_start_control %||% list(), vb_profile)
  }
  defaults$pipeline$inference$mcmc$prior_overrides$rhs <- rhs_override

  list(
    executable = executable,
    blockers = unique(blockers),
    row = row,
    defaults = defaults,
    defaults_path = defaults_path,
    matrix_path = .qdesn_validation_resolve_path(matrix_path, repo_root = repo_root, must_work = TRUE),
    profiles_path = .qdesn_validation_resolve_path(profiles_path, repo_root = repo_root, must_work = TRUE),
    grid_path = root_grid_path,
    applied_controls = list(
      vb_warm_start_profile = vb_profile_name,
      freeze_tau_burnin_iters = freeze_tau_burnin_iters,
      freeze_tau_only_during_burn = isTRUE(freeze_tau_only_during_burn)
    ),
    repo_root = repo_root
  )
}

qdesn_rhs_mcmc_repair_run_experiment <- function(experiment_id = NULL,
                                                 run_order = NULL,
                                                 matrix_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
                                                 profiles_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"),
                                                 results_root = NULL,
                                                 reports_root = NULL,
                                                 create_plots = TRUE,
                                                 verbose = TRUE,
                                                 vb_warm_start_profile_override = NULL,
                                                 freeze_tau_burnin_iters_override = NULL,
                                                 freeze_tau_only_during_burn_override = NULL,
                                                 repo_root = NULL) {
  resolved <- qdesn_rhs_mcmc_repair_resolve_experiment(
    experiment_id = experiment_id,
    run_order = run_order,
    matrix_path = matrix_path,
    profiles_path = profiles_path,
    vb_warm_start_profile_override = vb_warm_start_profile_override,
    freeze_tau_burnin_iters_override = freeze_tau_burnin_iters_override,
    freeze_tau_only_during_burn_override = freeze_tau_only_during_burn_override,
    repo_root = repo_root
  )

  if (!isTRUE(resolved$executable)) {
    stop(sprintf(
      "Experiment '%s' is not directly executable yet. Blockers: %s",
      as.character(resolved$row$experiment_id)[1L],
      paste(resolved$blockers, collapse = ", ")
    ), call. = FALSE)
  }

  .qdesn_validation_require_namespace("yaml")
  tmp_defaults <- tempfile(pattern = paste0(as.character(resolved$row$experiment_id)[1L], "-"), fileext = ".yaml")
  yaml::write_yaml(resolved$defaults, tmp_defaults)

  res <- qdesn_validation_run_campaign(
    grid_path = resolved$grid_path,
    defaults = resolved$defaults,
    defaults_path = tmp_defaults,
    results_root = results_root,
    report_root = reports_root,
    create_plots = create_plots,
    verbose = verbose
  )

  file.copy(tmp_defaults, file.path(res$report_root, "manifest", "materialized_defaults.yaml"), overwrite = TRUE)
  .qdesn_validation_write_json(file.path(res$report_root, "manifest", "repair_experiment_manifest.json"), list(
    experiment_id = as.character(resolved$row$experiment_id)[1L],
    run_order = as.integer(resolved$row$run_order)[1L],
    stage = as.character(resolved$row$stage)[1L],
    matrix_path = resolved$matrix_path,
    profiles_path = resolved$profiles_path,
    grid_path = resolved$grid_path,
    defaults_source = resolved$defaults_path,
    applied_controls = resolved$applied_controls,
    report_root = normalizePath(res$report_root, winslash = "/", mustWork = TRUE),
    results_root = normalizePath(res$results_root, winslash = "/", mustWork = TRUE),
    generated_at = as.character(Sys.time())
  ))

  list(
    experiment_id = as.character(resolved$row$experiment_id)[1L],
    report_root = normalizePath(res$report_root, winslash = "/", mustWork = TRUE),
    results_root = normalizePath(res$results_root, winslash = "/", mustWork = TRUE),
    resolved = resolved
  )
}

.qdesn_rhs_mcmc_repair_grade_score <- function(x) {
  x <- toupper(trimws(as.character(x %||% "")))
  out <- rep(NA_real_, length(x))
  out[x == "PASS"] <- 2
  out[x == "WARN"] <- 1
  out[x == "FAIL"] <- 0
  out
}

.qdesn_rhs_mcmc_repair_rank_experiments <- function(summary_df) {
  if (!nrow(summary_df)) return(summary_df)
  ord <- do.call(order, list(
    -summary_df$pair_eligible_count,
    -summary_df$pair_signoff_score_sum,
    -summary_df$mcmc_signoff_score_sum,
    summary_df$mcmc_fail_count,
    summary_df$forecast_qhat_mae_delta_mean,
    summary_df$forecast_pinball_tau_delta_mean,
    summary_df$mcmc_fit_runtime_seconds_mean,
    summary_df$runtime_ratio_mcmc_vs_vb_mean,
    summary_df$experiment_id
  ))
  out <- summary_df[ord, , drop = FALSE]
  out$rank <- seq_len(nrow(out))
  out
}

qdesn_rhs_mcmc_repair_summarize_reports <- function(report_roots,
                                                    output_root,
                                                    experiment_ids = NULL,
                                                    create_plots = TRUE) {
  if (!length(report_roots)) {
    stop("Provide at least one report root.", call. = FALSE)
  }
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "plots"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  rows_summary <- vector("list", length(report_roots))
  rows_pair <- vector("list", length(report_roots))
  rows_method <- vector("list", length(report_roots))

  for (ii in seq_along(report_roots)) {
    report_root <- normalizePath(report_roots[[ii]], winslash = "/", mustWork = TRUE)
    manifest <- .qdesn_validation_read_json_if_exists(file.path(report_root, "manifest", "repair_experiment_manifest.json")) %||% list()
    pair_df <- utils::read.csv(file.path(report_root, "tables", "campaign_pair_summary.csv"), stringsAsFactors = FALSE)
    method_df <- utils::read.csv(file.path(report_root, "tables", "campaign_method_signoff.csv"), stringsAsFactors = FALSE)
    progress_df <- utils::read.csv(file.path(report_root, "tables", "campaign_progress.csv"), stringsAsFactors = FALSE)

    experiment_id_i <- as.character(experiment_ids[[ii]] %||% manifest$experiment_id %||% basename(report_root))[1L]
    applied <- manifest$applied_controls %||% list()
    mcmc_df <- subset(method_df, method == "mcmc")
    pair_score <- .qdesn_rhs_mcmc_repair_grade_score(pair_df$pair_signoff_grade)
    mcmc_score <- .qdesn_rhs_mcmc_repair_grade_score(mcmc_df$signoff_grade)

    rows_summary[[ii]] <- data.frame(
      experiment_id = experiment_id_i,
      report_root = report_root,
      stage = as.character(manifest$stage %||% NA_character_),
      vb_warm_start_profile = as.character(applied$vb_warm_start_profile %||% NA_character_),
      freeze_tau_burnin_iters = as.integer(applied$freeze_tau_burnin_iters %||% NA_integer_),
      freeze_tau_only_during_burn = isTRUE(applied$freeze_tau_only_during_burn %||% FALSE),
      n_roots = nrow(progress_df),
      success_count = sum(progress_df$root_status == "SUCCESS", na.rm = TRUE),
      pair_eligible_count = sum(as.logical(pair_df$pair_comparison_eligible), na.rm = TRUE),
      pair_pass_count = sum(pair_df$pair_signoff_grade == "PASS", na.rm = TRUE),
      pair_warn_count = sum(pair_df$pair_signoff_grade == "WARN", na.rm = TRUE),
      pair_fail_count = sum(pair_df$pair_signoff_grade == "FAIL", na.rm = TRUE),
      pair_signoff_score_sum = sum(pair_score, na.rm = TRUE),
      mcmc_pass_count = sum(mcmc_df$signoff_grade == "PASS", na.rm = TRUE),
      mcmc_warn_count = sum(mcmc_df$signoff_grade == "WARN", na.rm = TRUE),
      mcmc_fail_count = sum(mcmc_df$signoff_grade == "FAIL", na.rm = TRUE),
      mcmc_signoff_score_sum = sum(mcmc_score, na.rm = TRUE),
      runtime_ratio_mcmc_vs_vb_mean = mean(pair_df$runtime_ratio_mcmc_vs_vb, na.rm = TRUE),
      mcmc_fit_runtime_seconds_mean = mean(pair_df$mcmc_fit_runtime_seconds, na.rm = TRUE),
      forecast_qhat_mae_delta_mean = mean(pair_df$forecast_qhat_mae_delta_mcmc_minus_vb, na.rm = TRUE),
      forecast_pinball_tau_delta_mean = mean(pair_df$forecast_pinball_tau_delta_mcmc_minus_vb, na.rm = TRUE),
      stringsAsFactors = FALSE
    )

    pair_df$experiment_id <- experiment_id_i
    pair_df$vb_warm_start_profile <- as.character(applied$vb_warm_start_profile %||% NA_character_)
    pair_df$freeze_tau_burnin_iters <- as.integer(applied$freeze_tau_burnin_iters %||% NA_integer_)
    rows_pair[[ii]] <- pair_df

    method_df$experiment_id <- experiment_id_i
    method_df$vb_warm_start_profile <- as.character(applied$vb_warm_start_profile %||% NA_character_)
    method_df$freeze_tau_burnin_iters <- as.integer(applied$freeze_tau_burnin_iters %||% NA_integer_)
    rows_method[[ii]] <- method_df
  }

  summary_df <- .qdesn_validation_bind_rows(rows_summary)
  summary_ranked <- .qdesn_rhs_mcmc_repair_rank_experiments(summary_df)
  pair_long <- .qdesn_validation_bind_rows(rows_pair)
  method_long <- .qdesn_validation_bind_rows(rows_method)

  .qdesn_validation_write_df(summary_ranked, file.path(output_root, "tables", "experiment_summary.csv"))
  .qdesn_validation_write_df(pair_long, file.path(output_root, "tables", "pair_summary_long.csv"))
  .qdesn_validation_write_df(method_long, file.path(output_root, "tables", "method_signoff_long.csv"))

  best_row <- if (nrow(summary_ranked)) summary_ranked[1L, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
  .qdesn_validation_write_json(file.path(output_root, "manifest", "repair_selection_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    best_experiment_id = if (nrow(best_row)) best_row$experiment_id[[1L]] else NA_character_,
    best_vb_warm_start_profile = if (nrow(best_row)) best_row$vb_warm_start_profile[[1L]] else NA_character_,
    best_freeze_tau_burnin_iters = if (nrow(best_row)) best_row$freeze_tau_burnin_iters[[1L]] else NA_integer_
  ))

  lines <- c(
    "# RHS MCMC Repair Experiment Comparison",
    "",
    sprintf("- Output root: `%s`", output_root),
    "",
    "## Experiment Summary",
    ""
  )
  lines <- c(lines, .qdesn_validation_df_to_markdown(summary_ranked))
  .qdesn_validation_write_lines(file.path(output_root, "comparison_summary.md"), lines)

  if (isTRUE(create_plots) && nrow(summary_ranked)) {
    .qdesn_validation_require_namespace("ggplot2")
    plt_df <- summary_ranked
    plt_df$experiment_id <- factor(plt_df$experiment_id, levels = summary_ranked$experiment_id)

    p_health <- ggplot2::ggplot(plt_df, ggplot2::aes(x = experiment_id, y = pair_eligible_count, fill = vb_warm_start_profile)) +
      ggplot2::geom_col(width = 0.65) +
      ggplot2::labs(title = "RHS Repair: Pair Eligibility Count", x = NULL, y = "eligible roots", fill = "VB init") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))
    ggplot2::ggsave(file.path(output_root, "plots", "pair_eligibility_count.png"), p_health, width = 10, height = 5, dpi = 150)

    p_runtime <- ggplot2::ggplot(plt_df, ggplot2::aes(x = experiment_id, y = runtime_ratio_mcmc_vs_vb_mean, fill = vb_warm_start_profile)) +
      ggplot2::geom_col(width = 0.65) +
      ggplot2::labs(title = "RHS Repair: Mean MCMC/VB Runtime Ratio", x = NULL, y = "ratio", fill = "VB init") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))
    ggplot2::ggsave(file.path(output_root, "plots", "runtime_ratio_mean.png"), p_runtime, width = 10, height = 5, dpi = 150)
  }

  list(
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    experiment_summary = summary_ranked,
    pair_summary_long = pair_long,
    method_signoff_long = method_long,
    best_experiment_id = if (nrow(best_row)) best_row$experiment_id[[1L]] else NA_character_,
    best_vb_warm_start_profile = if (nrow(best_row)) best_row$vb_warm_start_profile[[1L]] else NA_character_,
    best_freeze_tau_burnin_iters = if (nrow(best_row)) best_row$freeze_tau_burnin_iters[[1L]] else NA_integer_
  )
}
