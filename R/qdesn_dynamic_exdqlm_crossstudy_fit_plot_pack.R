`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_fitplotpack_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack_manifest.yaml"),
                                                    repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic fit plot pack manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_fitplotpack_read_csv <- function(path,
                                                required_cols = NULL) {
  if (!file.exists(path)) {
    stop(sprintf("Required fit plot pack source table is missing: %s", path), call. = FALSE)
  }
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required_cols <- unique(as.character(required_cols %||% character(0)))
  missing_cols <- setdiff(required_cols, names(out))
  if (length(missing_cols)) {
    stop(sprintf(
      "Fit plot pack table '%s' is missing required columns: %s",
      path,
      paste(missing_cols, collapse = ", ")
    ), call. = FALSE)
  }
  out
}

.qdesn_dynamic_fitplotpack_resolve_run_root <- function(path_cfg = NULL,
                                                        report_root_cfg = NULL,
                                                        run_tag_cfg = NULL,
                                                        repo_root = NULL,
                                                        label = "run") {
  direct_root <- path_cfg %||% NULL
  if (!is.null(direct_root) && nzchar(trimws(as.character(direct_root)[1L]))) {
    return(.qdesn_validation_resolve_path(direct_root, repo_root = repo_root, must_work = TRUE))
  }

  report_root <- as.character(report_root_cfg %||% "")[1L]
  run_tag <- as.character(run_tag_cfg %||% "")[1L]
  if (!nzchar(report_root) || !nzchar(run_tag)) {
    stop(sprintf(
      "Fit plot pack manifest must define %s root directly or provide report_root + run_tag.",
      label
    ), call. = FALSE)
  }
  .qdesn_validation_resolve_path(file.path(report_root, run_tag), repo_root = repo_root, must_work = TRUE)
}

.qdesn_dynamic_fitplotpack_panel_order <- function() {
  c("vb_al", "vb_exal", "mcmc_al", "mcmc_exal")
}

.qdesn_dynamic_fitplotpack_panel_label <- function(fit_key) {
  fit_key <- as.character(fit_key)
  out <- fit_key
  out[fit_key == "vb_al"] <- "VB / AL"
  out[fit_key == "vb_exal"] <- "VB / EXAL"
  out[fit_key == "mcmc_al"] <- "MCMC / AL"
  out[fit_key == "mcmc_exal"] <- "MCMC / EXAL"
  out[!(fit_key %in% c("vb_al", "vb_exal", "mcmc_al", "mcmc_exal"))] <-
    gsub("_", " / ", fit_key[!(fit_key %in% c("vb_al", "vb_exal", "mcmc_al", "mcmc_exal"))], fixed = TRUE)
  out
}

.qdesn_dynamic_fitplotpack_fit_key <- function(method, model) {
  paste(as.character(method), as.character(model), sep = "_")
}

.qdesn_dynamic_fitplotpack_resolve_source_state <- function(manifest,
                                                            repo_root = NULL) {
  source_cfg <- manifest$source %||% list()
  source_run_root <- .qdesn_dynamic_fitplotpack_resolve_run_root(
    path_cfg = source_cfg$source_run_root,
    report_root_cfg = source_cfg$source_run_report_root,
    run_tag_cfg = source_cfg$source_run_tag,
    repo_root = repo_root,
    label = "source_run"
  )
  comparison_root <- .qdesn_dynamic_fitplotpack_resolve_run_root(
    path_cfg = source_cfg$comparison_root,
    report_root_cfg = source_cfg$comparison_report_root,
    run_tag_cfg = source_cfg$comparison_run_tag,
    repo_root = repo_root,
    label = "comparison"
  )
  fit_summary <- .qdesn_dynamic_fitplotpack_read_csv(
    file.path(comparison_root, "tables", "authoritative_fit_summary.csv"),
    required_cols = c(
      "root_id", "family", "tau", "fit_size", "prior",
      "method", "model", "status", "signoff_grade",
      "holdout_qtrue_mae", "holdout_pinball_tau", "runtime_sec"
    )
  )

  list(
    source_run_root = source_run_root,
    comparison_root = comparison_root,
    fit_summary = fit_summary
  )
}

.qdesn_dynamic_fitplotpack_case_table <- function(manifest,
                                                  source_state) {
  cases <- manifest$cases %||% list()
  if (!length(cases)) {
    stop("Fit plot pack manifest must define at least one case.", call. = FALSE)
  }
  rows <- lapply(seq_along(cases), function(i) {
    case_cfg <- cases[[i]] %||% list()
    root_id <- as.character(case_cfg$root_id %||% "")[1L]
    if (!nzchar(root_id)) {
      stop(sprintf("Fit plot pack case %d is missing root_id.", i), call. = FALSE)
    }
    source_rows <- source_state$fit_summary[as.character(source_state$fit_summary$root_id) == root_id, , drop = FALSE]
    if (!nrow(source_rows)) {
      stop(sprintf("Fit plot pack case '%s' has no source rows in authoritative_fit_summary.", root_id), call. = FALSE)
    }
    source_rows$fit_key <- .qdesn_dynamic_fitplotpack_fit_key(source_rows$method, source_rows$model)
    if (!all(.qdesn_dynamic_fitplotpack_panel_order() %in% source_rows$fit_key)) {
      missing_fit_keys <- setdiff(.qdesn_dynamic_fitplotpack_panel_order(), source_rows$fit_key)
      stop(sprintf(
        "Fit plot pack case '%s' is missing required fit variants: %s",
        root_id,
        paste(missing_fit_keys, collapse = ", ")
      ), call. = FALSE)
    }
    top <- source_rows[1L, , drop = FALSE]
    data.frame(
      case_id = as.character(case_cfg$case_id %||% sprintf("case_%02d", i))[1L],
      case_label = as.character(case_cfg$label %||% root_id)[1L],
      root_id = root_id,
      family = as.character(top$family[1L]),
      tau = as.numeric(top$tau[1L]),
      fit_size = as.numeric(top$fit_size[1L]),
      prior = as.character(top$prior[1L]),
      rationale = as.character(case_cfg$rationale %||% NA_character_)[1L],
      stringsAsFactors = FALSE
    )
  })
  out <- .qdesn_validation_bind_rows(rows)
  if (nrow(out)) {
    out <- out[order(out$family, out$tau, out$fit_size, out$prior), , drop = FALSE]
    rownames(out) <- NULL
  }
  out
}

.qdesn_dynamic_fitplotpack_source_fit_table <- function(case_table,
                                                        source_state) {
  fit_summary <- source_state$fit_summary
  fit_rows <- fit_summary[fit_summary$root_id %in% case_table$root_id, , drop = FALSE]
  fit_rows$fit_key <- .qdesn_dynamic_fitplotpack_fit_key(fit_rows$method, fit_rows$model)
  fit_rows$panel_label <- vapply(fit_rows$fit_key, .qdesn_dynamic_fitplotpack_panel_label, character(1))
  fit_rows <- merge(
    fit_rows,
    case_table[, c("case_id", "case_label", "root_id", "rationale"), drop = FALSE],
    by = "root_id",
    all.x = TRUE,
    sort = FALSE
  )
  keep_cols <- c(
    "case_id", "case_label", "root_id", "family", "tau", "fit_size", "prior",
    "fit_key", "panel_label", "method", "model", "status", "signoff_grade",
    "holdout_qtrue_mae", "holdout_pinball_tau", "runtime_sec", "rationale"
  )
  out <- fit_rows[, intersect(keep_cols, names(fit_rows)), drop = FALSE]
  ord_case <- match(out$case_id, case_table$case_id)
  ord_fit <- match(out$fit_key, .qdesn_dynamic_fitplotpack_panel_order())
  out <- out[order(ord_case, ord_fit), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.qdesn_dynamic_fitplotpack_prepare_cfg <- function(cfg,
                                                   manifest) {
  cfg <- cfg %||% list()
  plotting_cfg <- manifest$plotting %||% list()
  execution_cfg <- manifest$execution %||% list()

  cfg$pipeline <- modifyList(cfg$pipeline %||% list(), list(verbose = FALSE))
  cfg$diagnostics <- modifyList(cfg$diagnostics %||% list(), list(
    plots = TRUE,
    fan_charts = FALSE,
    lead_eval = FALSE,
    pit = FALSE
  ))
  cfg$forecast <- modifyList(cfg$forecast %||% list(), list(
    train_last_window = as.integer(plotting_cfg$train_last_window %||% 100L)[1L],
    fore_last_window = as.integer(plotting_cfg$forecast_last_window %||% 100L)[1L]
  ))
  cfg$outputs <- modifyList(cfg$outputs %||% list(), list(
    save = TRUE,
    keep_draws = FALSE,
    thesis_subset = FALSE
  ))
  cfg$orchestrate <- modifyList(cfg$orchestrate %||% list(), list(
    threads_per_proc = as.integer(execution_cfg$threads_per_proc %||% 1L)[1L]
  ))
  cfg
}

.qdesn_dynamic_fitplotpack_build_jobs <- function(case_table,
                                                  source_fit_table,
                                                  source_state,
                                                  manifest,
                                                  output_root) {
  jobs <- list()
  for (i in seq_len(nrow(source_fit_table))) {
    row <- source_fit_table[i, , drop = FALSE]
    fit_key <- as.character(row$fit_key[1L])
    source_fit_dir <- file.path(source_state$source_run_root, "roots", row$root_id[1L], "fits", fit_key)
    fit_request_path <- file.path(source_fit_dir, "fit_request.json")
    fit_request <- .qdesn_validation_read_json_if_exists(fit_request_path)
    if (is.null(fit_request)) {
      stop(sprintf("Missing fit_request.json for source fit: %s", source_fit_dir), call. = FALSE)
    }
    observed_path <- .qdesn_validation_resolve_path(
      fit_request$observed_path %||% fit_request$inputs$observed_path %||% NULL,
      must_work = TRUE
    )
    if (is.null(observed_path)) {
      stop(sprintf("Fit request for '%s' is missing observed_path.", source_fit_dir), call. = FALSE)
    }
    cfg <- .qdesn_dynamic_fitplotpack_prepare_cfg(fit_request$config %||% list(), manifest)
    jobs[[length(jobs) + 1L]] <- list(
      case_id = as.character(row$case_id[1L]),
      case_label = as.character(row$case_label[1L]),
      root_id = as.character(row$root_id[1L]),
      family = as.character(row$family[1L]),
      tau = as.numeric(row$tau[1L]),
      fit_size = as.numeric(row$fit_size[1L]),
      prior = as.character(row$prior[1L]),
      fit_key = fit_key,
      panel_label = as.character(row$panel_label[1L]),
      method = as.character(row$method[1L]),
      model = as.character(row$model[1L]),
      source_fit_dir = source_fit_dir,
      source_fit_request_path = fit_request_path,
      observed_path = observed_path,
      cfg = cfg,
      output_dir = file.path(output_root, "reruns", row$case_id[1L], fit_key),
      source_metrics = row
    )
  }
  jobs
}

.qdesn_dynamic_fitplotpack_run_job <- function(job) {
  dir.create(job$output_dir, recursive = TRUE, showWarnings = FALSE)
  res <- tryCatch(
    run_esn_pipeline_from_cfg(
      cfg = job$cfg,
      file_long = job$observed_path,
      file_obs = job$observed_path,
      out_dir = job$output_dir,
      save_outputs = TRUE,
      verbose = FALSE
    ),
    error = function(e) {
      structure(list(status = 1L, stdout = conditionMessage(e), elapsed_seconds = NA_real_), class = "fitplotpack_error")
    }
  )
  if (!is.null(res$stdout)) {
    .qdesn_validation_write_lines(
      as.character(res$stdout),
      file.path(job$output_dir, "logs", "fit_plot_pack_stdout.log")
    )
  }
  summary_obj <- collect_pipeline_run_summary(job$output_dir)
  train_plot <- file.path(job$output_dir, "figs", "train_mu_band.png")
  forecast_plot <- file.path(job$output_dir, "figs", "forecast_mu_band.png")
  data.frame(
    case_id = job$case_id,
    case_label = job$case_label,
    root_id = job$root_id,
    fit_key = job$fit_key,
    panel_label = job$panel_label,
    method = job$method,
    model = job$model,
    source_fit_dir = job$source_fit_dir,
    rerun_fit_dir = normalizePath(job$output_dir, winslash = "/", mustWork = FALSE),
    pipeline_status = as.integer(res$status %||% 1L),
    summary_status = as.character(summary_obj$status %||% NA_character_),
    rerun_wall_seconds = suppressWarnings(as.numeric(summary_obj$summary$wall_seconds[1L] %||% res$elapsed_seconds %||% NA_real_)),
    rerun_total_stage_seconds = suppressWarnings(as.numeric(summary_obj$summary$total_stage_seconds[1L] %||% NA_real_)),
    train_plot_exists = file.exists(train_plot),
    train_plot_path = if (file.exists(train_plot)) normalizePath(train_plot, winslash = "/", mustWork = TRUE) else NA_character_,
    forecast_plot_exists = file.exists(forecast_plot),
    forecast_plot_path = if (file.exists(forecast_plot)) normalizePath(forecast_plot, winslash = "/", mustWork = TRUE) else NA_character_,
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_fitplotpack_run_jobs <- function(jobs,
                                               max_workers = 1L) {
  if (!length(jobs)) return(data.frame(stringsAsFactors = FALSE))
  max_workers <- max(1L, min(as.integer(max_workers)[1L], length(jobs)))
  runner <- function(job) .qdesn_dynamic_fitplotpack_run_job(job)
  if (.Platform$OS.type == "unix" && max_workers > 1L) {
    # Use dynamic pickup so short VB jobs do not leave workers idle while
    # longer MCMC jobs monopolize early chunks.
    rows <- parallel::mclapply(
      jobs,
      runner,
      mc.cores = max_workers,
      mc.preschedule = FALSE
    )
  } else {
    rows <- lapply(jobs, runner)
  }
  .qdesn_validation_bind_rows(rows)
}

.qdesn_dynamic_fitplotpack_copy_plots <- function(rerun_status,
                                                  output_root) {
  if (!nrow(rerun_status)) return(data.frame(stringsAsFactors = FALSE))
  rows <- lapply(seq_len(nrow(rerun_status)), function(i) {
    row <- rerun_status[i, , drop = FALSE]
    rel_dir <- file.path("plots", row$case_id[1L])
    dest_dir <- file.path(output_root, rel_dir)
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    dest_name <- sprintf("%s_train_mu_band.png", row$fit_key[1L])
    dest_path <- file.path(dest_dir, dest_name)
    if (isTRUE(row$train_plot_exists[1L]) && file.exists(row$train_plot_path[1L])) {
      file.copy(row$train_plot_path[1L], dest_path, overwrite = TRUE)
    } else {
      dest_path <- NA_character_
    }
    data.frame(
      case_id = as.character(row$case_id[1L]),
      fit_key = as.character(row$fit_key[1L]),
      panel_label = as.character(row$panel_label[1L]),
      rel_plot_path = if (is.na(dest_path)) NA_character_ else file.path(rel_dir, dest_name),
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_dynamic_fitplotpack_case_contrast_table <- function(source_fit_table) {
  case_ids <- unique(as.character(source_fit_table$case_id))
  rows <- lapply(case_ids, function(case_id) {
    sub <- source_fit_table[as.character(source_fit_table$case_id) == case_id, , drop = FALSE]
    if (!nrow(sub)) return(NULL)
    metric <- suppressWarnings(as.numeric(sub$holdout_qtrue_mae))
    runtime <- suppressWarnings(as.numeric(sub$runtime_sec))
    best_idx <- if (any(is.finite(metric))) which.min(metric) else 1L
    fast_idx <- if (any(is.finite(runtime))) which.min(runtime) else 1L
    vb_sub <- sub[sub$method == "vb", , drop = FALSE]
    mcmc_sub <- sub[sub$method == "mcmc", , drop = FALSE]
    al_sub <- sub[sub$model == "al", , drop = FALSE]
    exal_sub <- sub[sub$model == "exal", , drop = FALSE]
    data.frame(
      case_id = case_id,
      case_label = as.character(sub$case_label[1L]),
      best_holdout_fit = as.character(sub$panel_label[best_idx]),
      best_holdout_qtrue_mae = metric[best_idx],
      fastest_fit = as.character(sub$panel_label[fast_idx]),
      fastest_runtime_sec = runtime[fast_idx],
      vb_mean_holdout_qtrue_mae = if (nrow(vb_sub)) mean(as.numeric(vb_sub$holdout_qtrue_mae), na.rm = TRUE) else NA_real_,
      mcmc_mean_holdout_qtrue_mae = if (nrow(mcmc_sub)) mean(as.numeric(mcmc_sub$holdout_qtrue_mae), na.rm = TRUE) else NA_real_,
      al_mean_holdout_qtrue_mae = if (nrow(al_sub)) mean(as.numeric(al_sub$holdout_qtrue_mae), na.rm = TRUE) else NA_real_,
      exal_mean_holdout_qtrue_mae = if (nrow(exal_sub)) mean(as.numeric(exal_sub$holdout_qtrue_mae), na.rm = TRUE) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_dynamic_fitplotpack_case_image_block <- function(case_id,
                                                        figure_index) {
  sub <- figure_index[figure_index$case_id == case_id, , drop = FALSE]
  if (!nrow(sub)) {
    return(c("_No plots available for this case._", ""))
  }
  rel_for <- function(fit_key) {
    path <- sub$rel_plot_path[sub$fit_key == fit_key][1L] %||% NA_character_
    if (is.na(path) || !nzchar(path)) return("_(missing)_")
    sprintf("![](%s)", file.path("..", path))
  }
  c(
    "| VB / AL | VB / EXAL |",
    "| --- | --- |",
    sprintf("| %s | %s |", rel_for("vb_al"), rel_for("vb_exal")),
    "",
    "| MCMC / AL | MCMC / EXAL |",
    "| --- | --- |",
    sprintf("| %s | %s |", rel_for("mcmc_al"), rel_for("mcmc_exal")),
    ""
  )
}

qdesn_dynamic_fitplotpack_write_analysis <- function(source_state,
                                                     case_table,
                                                     source_fit_table,
                                                     rerun_status,
                                                     output_root,
                                                     manifest = list()) {
  output_root <- normalizePath(output_root, winslash = "/", mustWork = FALSE)
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "summary"))
  .qdesn_validation_dir_create(file.path(output_root, "plots"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  figure_index <- .qdesn_dynamic_fitplotpack_copy_plots(rerun_status, output_root)
  contrast_table <- .qdesn_dynamic_fitplotpack_case_contrast_table(source_fit_table)

  .qdesn_validation_write_df(case_table, file.path(output_root, "tables", "selected_case_table.csv"))
  .qdesn_validation_write_df(source_fit_table, file.path(output_root, "tables", "source_fit_scorecard.csv"))
  .qdesn_validation_write_df(rerun_status, file.path(output_root, "tables", "rerun_status.csv"))
  .qdesn_validation_write_df(figure_index, file.path(output_root, "tables", "figure_index.csv"))
  .qdesn_validation_write_df(contrast_table, file.path(output_root, "tables", "case_contrast_summary.csv"))

  headline_lines <- c(
    "# QDESN Tau050 Last-100 Fit Plot Comparison Pack",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_run_root: `%s`", source_state$source_run_root),
    sprintf("- comparison_root: `%s`", source_state$comparison_root),
    sprintf("- train_last_window: `%s`", as.integer((manifest$plotting %||% list())$train_last_window %||% 100L)),
    sprintf("- selected_cases: `%d`", nrow(case_table)),
    sprintf("- selected_fits: `%d`", nrow(source_fit_table)),
    sprintf("- rerun_success_n: `%d`", sum(as.integer(rerun_status$pipeline_status) == 0L & rerun_status$train_plot_exists, na.rm = TRUE)),
    "",
    "## Selected Cases",
    .qdesn_validation_df_to_markdown(case_table),
    "",
    "## Source Fit Scorecard",
    .qdesn_validation_df_to_markdown(source_fit_table[, c(
      "case_id", "panel_label", "signoff_grade", "holdout_qtrue_mae", "holdout_pinball_tau", "runtime_sec"
    ), drop = FALSE]),
    "",
    "## Case Contrast Summary",
    .qdesn_validation_df_to_markdown(contrast_table),
    "",
    "## Rerun Status",
    .qdesn_validation_df_to_markdown(rerun_status[, c(
      "case_id", "fit_key", "pipeline_status", "summary_status", "rerun_wall_seconds", "train_plot_exists"
    ), drop = FALSE]),
    ""
  )

  for (i in seq_len(nrow(case_table))) {
    case_row <- case_table[i, , drop = FALSE]
    case_id <- as.character(case_row$case_id[1L])
    case_source <- source_fit_table[source_fit_table$case_id == case_id, , drop = FALSE]
    headline_lines <- c(
      headline_lines,
      sprintf("## %s", as.character(case_row$case_label[1L])),
      "",
      sprintf("- root_id: `%s`", as.character(case_row$root_id[1L])),
      sprintf("- family / tau / fit_size / prior: `%s / %.2f / %d / %s`",
              as.character(case_row$family[1L]),
              as.numeric(case_row$tau[1L]),
              as.integer(case_row$fit_size[1L]),
              as.character(case_row$prior[1L])),
      sprintf("- rationale: %s", as.character(case_row$rationale[1L] %||% "")),
      "",
      .qdesn_validation_df_to_markdown(case_source[, c(
        "panel_label", "signoff_grade", "holdout_qtrue_mae", "holdout_pinball_tau", "runtime_sec"
      ), drop = FALSE]),
      "",
      .qdesn_dynamic_fitplotpack_case_image_block(case_id, figure_index)
    )
  }

  .qdesn_validation_write_lines(
    headline_lines,
    file.path(output_root, "summary", "qdesn_tau050_fit_plot_comparison_pack.md")
  )
  .qdesn_validation_write_json(list(
    generated_at = as.character(Sys.time()),
    source_run_root = source_state$source_run_root,
    comparison_root = source_state$comparison_root,
    selected_cases_n = nrow(case_table),
    selected_fits_n = nrow(source_fit_table)
  ), file.path(output_root, "manifest", "analysis_manifest.json"))

  list(
    case_table = case_table,
    source_fit_table = source_fit_table,
    rerun_status = rerun_status,
    figure_index = figure_index,
    contrast_table = contrast_table
  )
}
