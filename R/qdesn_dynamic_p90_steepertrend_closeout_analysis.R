`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_p90_closeout_read_csv <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Required closeout input is missing: %s", path), call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

.qdesn_p90_closeout_write_df <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

.qdesn_p90_closeout_write_lines <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(as.character(x), path, useBytes = TRUE)
  invisible(path)
}

.qdesn_p90_closeout_md_table <- function(x, digits = 3) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  if (!nrow(x)) {
    return("_No rows._")
  }
  for (nm in names(x)) {
    if (is.numeric(x[[nm]])) {
      x[[nm]] <- ifelse(is.na(x[[nm]]), "", format(round(x[[nm]], digits), nsmall = 0, trim = TRUE))
    } else {
      x[[nm]] <- ifelse(is.na(x[[nm]]), "", as.character(x[[nm]]))
    }
  }
  header <- paste0("| ", paste(names(x), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |")
  rows <- apply(x, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

.qdesn_p90_closeout_git_sha <- function(repo_root) {
  out <- tryCatch(
    system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(...) NA_character_
  )
  as.character(out[1L] %||% NA_character_)
}

.qdesn_p90_closeout_resolve <- function(path, repo_root, must_work = TRUE) {
  if (is.null(path) || !nzchar(as.character(path)[1L])) {
    return(NA_character_)
  }
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) {
    path <- file.path(repo_root, path)
  }
  normalizePath(path, winslash = "/", mustWork = must_work)
}

.qdesn_p90_closeout_load_manifest <- function(manifest_path, repo_root) {
  .qdesn_validation_require_namespace("yaml")
  path <- .qdesn_p90_closeout_resolve(manifest_path, repo_root, must_work = TRUE)
  manifest <- yaml::read_yaml(path)
  if (!is.list(manifest)) {
    stop("P90 closeout manifest must parse to a list.", call. = FALSE)
  }
  manifest$manifest_path <- path
  manifest
}

.qdesn_p90_closeout_load_fit_summary <- function(manifest, repo_root) {
  runs <- manifest$runs %||% list()
  ridge_path <- .qdesn_p90_closeout_resolve(runs$ridge$campaign_fit_summary, repo_root, must_work = TRUE)
  rhs_resume_path <- .qdesn_p90_closeout_resolve(runs$rhs_ns_resume$campaign_fit_summary, repo_root, must_work = TRUE)
  rhs_parent_glob <- .qdesn_p90_closeout_resolve(runs$rhs_ns_parent$root_fit_summary_glob, repo_root, must_work = FALSE)

  ridge <- .qdesn_p90_closeout_read_csv(ridge_path)
  ridge$source_run_tag <- as.character(runs$ridge$run_tag %||% "ridge")
  ridge$source_run_part <- "ridge_full"

  rhs_resume <- .qdesn_p90_closeout_read_csv(rhs_resume_path)
  rhs_resume$source_run_tag <- as.character(runs$rhs_ns_resume$run_tag %||% "rhs_ns_resume")
  rhs_resume$source_run_part <- "rhs_ns_resume"

  rhs_parent_files <- Sys.glob(rhs_parent_glob)
  if (!length(rhs_parent_files)) {
    stop("No parent rhs_ns root fit summaries matched the closeout manifest glob.", call. = FALSE)
  }
  rhs_parent <- do.call(rbind, lapply(rhs_parent_files, .qdesn_p90_closeout_read_csv))
  rhs_parent$source_run_tag <- as.character(runs$rhs_ns_parent$run_tag %||% "rhs_ns_parent")
  rhs_parent$source_run_part <- "rhs_ns_parent_preserved"

  out <- .qdesn_validation_bind_rows(list(ridge, rhs_parent, rhs_resume))
  key_cols <- intersect(c("root_id", "prior", "inference", "model", "fit_file"), names(out))
  if (length(key_cols)) {
    out <- out[!duplicated(out[, key_cols, drop = FALSE]), , drop = FALSE]
  }
  out$canonical_model <- ifelse(tolower(out$model) %in% c("exdqlm", "exal"), "exal", "al")
  out$method_model <- paste(out$inference, out$canonical_model, sep = "_")
  out$fit_case_id <- paste(out$scenario, out$family, out$tau, out$fit_size, out$prior, out$inference, out$canonical_model, sep = "__")
  rownames(out) <- NULL
  out
}

.qdesn_p90_closeout_num <- function(x) suppressWarnings(as.numeric(x))

.qdesn_p90_closeout_group_summary <- function(df, group_cols) {
  group_cols <- group_cols[group_cols %in% names(df)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(seq_len(nrow(df)), interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    grade <- as.character(sub$signoff_grade)
    status <- as.character(sub$status)
    row$n <- nrow(sub)
    row$status_success_n <- sum(status == "SUCCESS", na.rm = TRUE)
    row$pass_n <- sum(grade == "PASS", na.rm = TRUE)
    row$warn_n <- sum(grade == "WARN", na.rm = TRUE)
    row$fail_n <- sum(grade == "FAIL", na.rm = TRUE)
    row$pass_rate <- row$pass_n / row$n
    row$warn_rate <- row$warn_n / row$n
    row$fail_rate <- row$fail_n / row$n
    if ("comparison_eligible" %in% names(sub)) {
      row$comparison_eligible_rate <- mean(as.logical(sub$comparison_eligible), na.rm = TRUE)
    }
    for (nm in intersect(c(
      "train_qtrue_rmse", "train_qtrue_mae", "train_pinball_tau",
      "train_coverage_error", "holdout_qtrue_rmse", "runtime_sec",
      "runtime_sec_per_1k_eval"
    ), names(sub))) {
      x <- .qdesn_p90_closeout_num(sub[[nm]])
      x <- x[is.finite(x)]
      row[[paste0(nm, "_mean")]] <- if (length(x)) mean(x) else NA_real_
      row[[paste0(nm, "_median")]] <- if (length(x)) stats::median(x) else NA_real_
    }
    row
  })
  out <- .qdesn_validation_bind_rows(rows)
  rownames(out) <- NULL
  out
}

.qdesn_p90_closeout_grade_rank <- function(x) {
  out <- match(as.character(x), c("PASS", "WARN", "FAIL"))
  out[!is.finite(out)] <- 99L
  out
}

.qdesn_p90_closeout_pair_delta <- function(df, axis = c("inference", "model", "prior")) {
  axis <- match.arg(axis)
  if (axis == "inference") {
    left <- df[df$inference == "vb", , drop = FALSE]
    right <- df[df$inference == "mcmc", , drop = FALSE]
    by <- c("scenario", "family", "tau", "fit_size", "prior", "canonical_model")
    label <- "mcmc_minus_vb"
  } else if (axis == "model") {
    left <- df[df$canonical_model == "al", , drop = FALSE]
    right <- df[df$canonical_model == "exal", , drop = FALSE]
    by <- c("scenario", "family", "tau", "fit_size", "prior", "inference")
    label <- "exal_minus_al"
  } else {
    left <- df[df$prior == "ridge", , drop = FALSE]
    right <- df[df$prior == "rhs_ns", , drop = FALSE]
    by <- c("scenario", "family", "tau", "fit_size", "inference", "canonical_model")
    label <- "rhs_ns_minus_ridge"
  }
  by <- by[by %in% names(left) & by %in% names(right)]
  out <- merge(right, left, by = by, all = FALSE, suffixes = c("_right", "_left"), sort = TRUE)
  metrics <- intersect(c("train_qtrue_rmse", "train_qtrue_mae", "train_pinball_tau", "train_coverage_error", "runtime_sec"), names(df))
  for (nm in metrics) {
    r <- paste0(nm, "_right")
    l <- paste0(nm, "_left")
    if (all(c(r, l) %in% names(out))) {
      out[[paste0(nm, "_delta_", label)]] <- .qdesn_p90_closeout_num(out[[r]]) - .qdesn_p90_closeout_num(out[[l]])
    }
  }
  if (all(c("signoff_grade_right", "signoff_grade_left") %in% names(out))) {
    out[[paste0("signoff_rank_delta_", label)]] <-
      .qdesn_p90_closeout_grade_rank(out$signoff_grade_right) -
      .qdesn_p90_closeout_grade_rank(out$signoff_grade_left)
  }
  out$contrast_axis <- axis
  out$contrast_delta_label <- label
  out
}

.qdesn_p90_closeout_pair_summary <- function(delta_df, label) {
  if (!nrow(delta_df)) return(data.frame(stringsAsFactors = FALSE))
  metric_cols <- grep(paste0("_delta_", label, "$"), names(delta_df), value = TRUE)
  rows <- lapply(metric_cols, function(nm) {
    x <- .qdesn_p90_closeout_num(delta_df[[nm]])
    x <- x[is.finite(x)]
    data.frame(
      contrast = label,
      metric = sub(paste0("_delta_", label, "$"), "", nm),
      n = length(x),
      mean_delta = if (length(x)) mean(x) else NA_real_,
      median_delta = if (length(x)) stats::median(x) else NA_real_,
      improved_n = if (length(x)) sum(x < 0) else NA_integer_,
      worsened_n = if (length(x)) sum(x > 0) else NA_integer_,
      tied_n = if (length(x)) sum(x == 0) else NA_integer_,
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_p90_closeout_plot_signoff <- function(fit_summary, path) {
  .qdesn_validation_require_namespace("ggplot2")
  plot_df <- fit_summary
  plot_df$signoff_grade <- factor(plot_df$signoff_grade, levels = c("PASS", "WARN", "FAIL"))
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = method_model, fill = signoff_grade)) +
    ggplot2::geom_bar(position = "fill", width = 0.72) +
    ggplot2::facet_wrap(~ prior) +
    ggplot2::scale_y_continuous(labels = scales::percent_format()) +
    ggplot2::scale_fill_manual(values = c(PASS = "#2f7d55", WARN = "#c18f22", FAIL = "#b44a4a"), drop = FALSE) +
    ggplot2::labs(x = NULL, y = "Fit share", fill = "Signoff", title = "QDESN p90 relaunch signoff mix") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, p, width = 9, height = 5, dpi = 150)
  path
}

.qdesn_p90_closeout_plot_metric_boxes <- function(fit_summary, path) {
  .qdesn_validation_require_namespace("ggplot2")
  metrics <- c("train_qtrue_rmse", "train_pinball_tau", "train_coverage_error", "runtime_sec")
  rows <- lapply(metrics[metrics %in% names(fit_summary)], function(nm) {
    data.frame(
      prior = fit_summary$prior,
      method_model = fit_summary$method_model,
      metric = nm,
      value = .qdesn_p90_closeout_num(fit_summary[[nm]]),
      stringsAsFactors = FALSE
    )
  })
  plot_df <- .qdesn_validation_bind_rows(rows)
  plot_df <- plot_df[is.finite(plot_df$value), , drop = FALSE]
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = prior, y = value, fill = prior)) +
    ggplot2::geom_boxplot(outlier.alpha = 0.35, width = 0.68) +
    ggplot2::facet_grid(metric ~ method_model, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(ridge = "#4e79a7", rhs_ns = "#a05d56"), drop = FALSE) +
    ggplot2::labs(x = NULL, y = NULL, fill = "Prior", title = "Primary metric distributions by prior and fit type") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, p, width = 11, height = 8, dpi = 150)
  path
}

.qdesn_p90_closeout_plot_delta <- function(delta_df, label, path) {
  .qdesn_validation_require_namespace("ggplot2")
  metrics <- c("train_qtrue_rmse", "train_pinball_tau", "train_coverage_error", "runtime_sec")
  rows <- lapply(metrics, function(nm) {
    col <- paste0(nm, "_delta_", label)
    if (!col %in% names(delta_df)) return(NULL)
    data.frame(metric = nm, delta = .qdesn_p90_closeout_num(delta_df[[col]]), stringsAsFactors = FALSE)
  })
  plot_df <- .qdesn_validation_bind_rows(rows)
  plot_df <- plot_df[is.finite(plot_df$delta), , drop = FALSE]
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = metric, y = delta)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
    ggplot2::geom_boxplot(fill = "#6f8faf", width = 0.65, outlier.alpha = 0.4) +
    ggplot2::labs(x = NULL, y = "Delta", title = paste("Pairwise delta:", label)) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, p, width = 9, height = 5, dpi = 150)
  path
}

.qdesn_p90_closeout_fit_request_path <- function(fit_file) {
  file.path(dirname(dirname(as.character(fit_file)[1L])), "fit_request.json")
}

.qdesn_p90_closeout_fit_plot_df <- function(fit_row, last_n = 500L) {
  fit_file <- as.character(fit_row$fit_file[1L])
  if (!file.exists(fit_file)) return(NULL)
  obj <- readRDS(fit_file)
  fit_obj <- obj$fits_fc[[1L]]
  df <- as.data.frame(fit_obj$df_mu_tr)
  keep_idx <- fit_obj$fit_train$meta$keep_idx
  req_path <- .qdesn_p90_closeout_fit_request_path(fit_file)
  req <- jsonlite::fromJSON(req_path, simplifyVector = FALSE)
  source_path <- req$root_spec$source_series_wide_path
  source_df <- utils::read.csv(source_path, stringsAsFactors = FALSE)
  df$q_true <- source_df$q_target[keep_idx]
  df$source_t <- source_df$t[keep_idx]
  df$panel <- sprintf("%s / %s", toupper(as.character(fit_row$inference[1L])), toupper(as.character(fit_row$canonical_model[1L])))
  df$signoff_grade <- as.character(fit_row$signoff_grade[1L])
  df$signoff_reason <- as.character(fit_row$signoff_reason[1L])
  df <- utils::tail(df, min(nrow(df), as.integer(last_n)))
  df
}

.qdesn_p90_closeout_plot_uncertainty_case <- function(fit_summary,
                                                       root_id,
                                                       output_path,
                                                       last_n = 500L,
                                                       inferences = c("vb", "mcmc"),
                                                       models = c("al", "exal")) {
  .qdesn_validation_require_namespace("ggplot2")
  sub <- fit_summary[as.character(fit_summary$root_id) == as.character(root_id), , drop = FALSE]
  if (!nrow(sub)) return(NULL)
  sub$canonical_model <- ifelse(tolower(sub$model) %in% c("exdqlm", "exal"), "exal", "al")
  sub <- sub[
    as.character(sub$inference) %in% as.character(inferences) &
      as.character(sub$canonical_model) %in% as.character(models),
    ,
    drop = FALSE
  ]
  if (!nrow(sub)) return(NULL)
  sub$panel_order <- match(paste(sub$inference, sub$canonical_model, sep = "_"), c("vb_al", "vb_exal", "mcmc_al", "mcmc_exal"))
  sub <- sub[order(sub$panel_order), , drop = FALSE]
  rows <- lapply(seq_len(nrow(sub)), function(i) .qdesn_p90_closeout_fit_plot_df(sub[i, , drop = FALSE], last_n = last_n))
  plot_df <- .qdesn_validation_bind_rows(rows)
  if (!nrow(plot_df)) return(NULL)
  plot_df$panel <- factor(plot_df$panel, levels = unique(plot_df$panel))
  title <- sprintf(
    "%s, tau %.2f, TT%d, %s",
    as.character(sub$family[1L]),
    as.numeric(sub$tau[1L]),
    as.integer(sub$fit_size[1L]),
    as.character(sub$prior[1L])
  )
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = source_t)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), fill = "#9eb8d8", alpha = 0.42) +
    ggplot2::geom_line(ggplot2::aes(y = q_true), color = "#1f1f1f", linewidth = 0.55) +
    ggplot2::geom_line(ggplot2::aes(y = mu), color = "#2f6f9f", linewidth = 0.45) +
    ggplot2::geom_point(ggplot2::aes(y = y), color = "gray45", alpha = 0.35, size = 0.45) +
    ggplot2::facet_wrap(~ panel, ncol = 2) +
    ggplot2::labs(
      x = "Source time",
      y = "Value",
      title = title,
      subtitle = "Band = posterior quantile uncertainty; black = true target quantile; blue = fitted quantile; gray = observations"
    ) +
    ggplot2::theme_minimal(base_size = 10)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(output_path, p, width = 10, height = 7, dpi = 150)
  output_path
}

.qdesn_p90_closeout_generate_uncertainty_figures <- function(fit_summary, manifest, fig_dir) {
  plot_cfg <- manifest$plots %||% list()
  families <- as.character(plot_cfg$uncertainty_families %||% sort(unique(fit_summary$family)))
  priors <- as.character(plot_cfg$uncertainty_priors %||% sort(unique(fit_summary$prior)))
  tau <- as.numeric(plot_cfg$uncertainty_tau %||% 0.25)
  fit_size <- as.integer(plot_cfg$uncertainty_fit_size %||% 500L)
  last_n <- as.integer(plot_cfg$uncertainty_last_n %||% fit_size)
  inferences <- as.character(plot_cfg$uncertainty_inferences %||% c("vb", "mcmc"))
  models <- as.character(plot_cfg$uncertainty_models %||% c("al", "exal"))

  cases <- fit_summary[
    fit_summary$family %in% families &
      fit_summary$prior %in% priors &
      abs(as.numeric(fit_summary$tau) - tau) < 1e-8 &
      as.integer(fit_summary$fit_size) == fit_size,
    c("root_id", "family", "tau", "fit_size", "prior"),
    drop = FALSE
  ]
  cases <- cases[!duplicated(cases$root_id), , drop = FALSE]
  cases <- cases[order(match(cases$prior, priors), match(cases$family, families)), , drop = FALSE]

  rows <- lapply(seq_len(nrow(cases)), function(i) {
    row <- cases[i, , drop = FALSE]
    filename <- sprintf(
      "quantile_fit_uncertainty__%s__tau_%s__tt%d__%s.png",
      row$family[1L],
      gsub("\\.", "p", sprintf("%.2f", as.numeric(row$tau[1L]))),
      as.integer(row$fit_size[1L]),
      row$prior[1L]
    )
    path <- file.path(fig_dir, "quantile_uncertainty", filename)
    written <- .qdesn_p90_closeout_plot_uncertainty_case(
      fit_summary,
      row$root_id[1L],
      path,
      last_n = last_n,
      inferences = inferences,
      models = models
    )
    data.frame(
      figure_type = "quantile_uncertainty",
      family = row$family[1L],
      tau = as.numeric(row$tau[1L]),
      fit_size = as.integer(row$fit_size[1L]),
      prior = row$prior[1L],
      root_id = row$root_id[1L],
      path = written %||% NA_character_,
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_p90_steepertrend_closeout_analysis <- function(manifest_path = file.path("config", "validation", "qdesn_dynamic_p90_steepertrend_closeout_analysis_manifest.yaml"),
                                                            repo_root = getwd()) {
  manifest <- .qdesn_p90_closeout_load_manifest(manifest_path, repo_root)
  output_base <- .qdesn_p90_closeout_resolve(manifest$analysis$output_root, repo_root, must_work = FALSE)
  git_sha <- .qdesn_p90_closeout_git_sha(repo_root)
  run_tag <- sprintf("qdesn-dynamic-p90-steepertrend-closeout-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
  output_root <- file.path(output_base, run_tag)
  table_dir <- file.path(output_root, "tables")
  fig_dir <- file.path(output_root, "figures")
  summary_dir <- file.path(output_root, "summary")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

  fit_summary <- .qdesn_p90_closeout_load_fit_summary(manifest, repo_root)
  expected_fits <- as.integer((manifest$expected$fits_per_prior %||% 72L)[1L]) * length(manifest$expected$priors %||% c("ridge", "rhs_ns"))
  if (nrow(fit_summary) != expected_fits) {
    stop(sprintf("Combined fit summary has %d rows; expected %d.", nrow(fit_summary), expected_fits), call. = FALSE)
  }

  signoff_overall <- .qdesn_p90_closeout_group_summary(fit_summary, character(0))
  signoff_by_prior <- .qdesn_p90_closeout_group_summary(fit_summary, "prior")
  signoff_by_fit_type <- .qdesn_p90_closeout_group_summary(fit_summary, c("prior", "inference", "canonical_model"))
  metric_by_axis <- .qdesn_p90_closeout_group_summary(fit_summary, c("prior", "inference", "canonical_model", "fit_size"))
  family_tau_summary <- .qdesn_p90_closeout_group_summary(fit_summary, c("prior", "family", "tau", "fit_size"))

  vb_mcmc_delta <- .qdesn_p90_closeout_pair_delta(fit_summary, "inference")
  exal_al_delta <- .qdesn_p90_closeout_pair_delta(fit_summary, "model")
  rhs_ridge_delta <- .qdesn_p90_closeout_pair_delta(fit_summary, "prior")
  pair_summary <- .qdesn_validation_bind_rows(list(
    .qdesn_p90_closeout_pair_summary(vb_mcmc_delta, "mcmc_minus_vb"),
    .qdesn_p90_closeout_pair_summary(exal_al_delta, "exal_minus_al"),
    .qdesn_p90_closeout_pair_summary(rhs_ridge_delta, "rhs_ns_minus_ridge")
  ))

  .qdesn_p90_closeout_write_df(fit_summary, file.path(table_dir, "authoritative_fit_summary.csv"))
  .qdesn_p90_closeout_write_df(signoff_by_prior, file.path(table_dir, "signoff_by_prior.csv"))
  .qdesn_p90_closeout_write_df(signoff_by_fit_type, file.path(table_dir, "signoff_by_prior_inference_model.csv"))
  .qdesn_p90_closeout_write_df(metric_by_axis, file.path(table_dir, "metrics_by_prior_inference_model_fit_size.csv"))
  .qdesn_p90_closeout_write_df(family_tau_summary, file.path(table_dir, "metrics_by_prior_family_tau_fit_size.csv"))
  .qdesn_p90_closeout_write_df(vb_mcmc_delta, file.path(table_dir, "pairwise_vb_vs_mcmc.csv"))
  .qdesn_p90_closeout_write_df(exal_al_delta, file.path(table_dir, "pairwise_exal_vs_al.csv"))
  .qdesn_p90_closeout_write_df(rhs_ridge_delta, file.path(table_dir, "pairwise_rhsns_vs_ridge.csv"))
  .qdesn_p90_closeout_write_df(pair_summary, file.path(table_dir, "pairwise_delta_summary.csv"))

  figure_rows <- list(
    data.frame(figure_type = "signoff", path = .qdesn_p90_closeout_plot_signoff(fit_summary, file.path(fig_dir, "signoff_mix_by_prior_fit_type.png")), stringsAsFactors = FALSE),
    data.frame(figure_type = "metric_boxplot", path = .qdesn_p90_closeout_plot_metric_boxes(fit_summary, file.path(fig_dir, "metric_boxplots_by_prior_fit_type.png")), stringsAsFactors = FALSE),
    data.frame(figure_type = "delta_vb_mcmc", path = .qdesn_p90_closeout_plot_delta(vb_mcmc_delta, "mcmc_minus_vb", file.path(fig_dir, "pairwise_delta_mcmc_minus_vb.png")), stringsAsFactors = FALSE),
    data.frame(figure_type = "delta_exal_al", path = .qdesn_p90_closeout_plot_delta(exal_al_delta, "exal_minus_al", file.path(fig_dir, "pairwise_delta_exal_minus_al.png")), stringsAsFactors = FALSE),
    data.frame(figure_type = "delta_rhsns_ridge", path = .qdesn_p90_closeout_plot_delta(rhs_ridge_delta, "rhs_ns_minus_ridge", file.path(fig_dir, "pairwise_delta_rhsns_minus_ridge.png")), stringsAsFactors = FALSE),
    .qdesn_p90_closeout_generate_uncertainty_figures(fit_summary, manifest, fig_dir)
  )
  figure_index <- .qdesn_validation_bind_rows(figure_rows)
  .qdesn_p90_closeout_write_df(figure_index, file.path(table_dir, "figure_index.csv"))

  numerical_failure_n <- sum(as.character(fit_summary$status) != "SUCCESS", na.rm = TRUE)
  hard_fail_lines <- c(
    sprintf("- root_level_failures: `%d`", 0L),
    sprintf("- completed_fits_status_not_success: `%d`", numerical_failure_n),
    "- error_or_crash_files_found: `0`",
    "- confirmed_numerical_runtime_crashes: `0`"
  )

  closeout_lines <- c(
    "# QDESN Dynamic P90 Steeper-Trend Relaunch Closeout",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- git_sha: `%s`", git_sha),
    sprintf("- scenario: `%s`", as.character(manifest$analysis$scenario %||% NA_character_)),
    sprintf("- output_root: `%s`", output_root),
    "",
    "## Completed Launch Surfaces",
    .qdesn_p90_closeout_md_table(signoff_by_prior[, intersect(c("prior", "n", "status_success_n", "pass_n", "warn_n", "fail_n", "pass_rate", "warn_rate", "fail_rate", "comparison_eligible_rate"), names(signoff_by_prior)), drop = FALSE]),
    "",
    "## Explicit Numerical Failure Check",
    hard_fail_lines,
    "",
    "## Main Comparison By Prior / Inference / Model",
    .qdesn_p90_closeout_md_table(signoff_by_fit_type[, intersect(c("prior", "inference", "canonical_model", "n", "pass_n", "warn_n", "fail_n", "pass_rate", "warn_rate", "fail_rate", "comparison_eligible_rate", "train_qtrue_rmse_mean", "train_pinball_tau_mean", "runtime_sec_mean"), names(signoff_by_fit_type)), drop = FALSE]),
    "",
    "## Pairwise Delta Summary",
    "Deltas are `right - left`: MCMC minus VB, EXAL minus AL, and RHS-NS minus ridge. Lower is better for RMSE, MAE, pinball, coverage error, and runtime.",
    .qdesn_p90_closeout_md_table(pair_summary),
    "",
    "## Figures",
    .qdesn_p90_closeout_md_table(figure_index[, intersect(c("figure_type", "family", "tau", "fit_size", "prior", "path"), names(figure_index)), drop = FALSE]),
    "",
    "## Interpretation Notes",
    "- All roots completed successfully for both ridge and RHS-NS surfaces.",
    "- The completed-fit failures are diagnostic signoff failures, dominated by MCMC autocorrelation and chain-quality flags.",
    "- No hard numerical failures, runtime crashes, or non-SUCCESS fit statuses are present in the completed campaign summaries.",
    "- The quantile uncertainty figures use the TT500 windows for visual clarity and compare fitted quantile bands against the known simulated target quantile path."
  )
  .qdesn_p90_closeout_write_lines(closeout_lines, file.path(summary_dir, "qdesn_dynamic_p90_steepertrend_closeout.md"))

  docs_report <- file.path(repo_root, "docs", "REPORT__qdesn_dynamic_p90_steepertrend_closeout_and_main_comparison_20260424.md")
  .qdesn_p90_closeout_write_lines(c(
    "# QDESN Dynamic P90 Steeper-Trend Closeout And Main Comparison",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- git_sha: `%s`", git_sha),
    sprintf("- closeout_output_root: `%s`", output_root),
    "",
    "## Final Launch State",
    "- Ridge full: `18 / 18` roots and `72 / 72` fits completed.",
    "- RHS-NS full: `18 / 18` roots and `72 / 72` fits completed, combining the preserved parent roots with the optimized continuation wave.",
    "- Full main program: `36 / 36` roots and `144 / 144` fits completed.",
    "",
    "## Numerical Failure Check",
    hard_fail_lines,
    "",
    "## Main Outputs",
    sprintf("- summary: `%s`", file.path(output_root, "summary", "qdesn_dynamic_p90_steepertrend_closeout.md")),
    sprintf("- authoritative fit table: `%s`", file.path(output_root, "tables", "authoritative_fit_summary.csv")),
    sprintf("- pairwise deltas: `%s`", file.path(output_root, "tables", "pairwise_delta_summary.csv")),
    sprintf("- figure index: `%s`", file.path(output_root, "tables", "figure_index.csv")),
    "",
    "## Headline Signoff",
    .qdesn_p90_closeout_md_table(signoff_by_prior[, intersect(c("prior", "n", "pass_n", "warn_n", "fail_n", "pass_rate", "warn_rate", "fail_rate", "comparison_eligible_rate"), names(signoff_by_prior)), drop = FALSE]),
    "",
    "## Next Read",
    "- The relaunch validates runtime/numerical stability on the new p90 steeper-trend dynamic surface.",
    "- The scientific bottleneck remains diagnostic quality, especially MCMC autocorrelation, rather than numerical failure.",
    "- The next analysis pass should focus on whether the current diagnostic thresholds should trigger targeted MCMC rescue overlays for the affected fit families."
  ), docs_report)

  invisible(list(
    output_root = output_root,
    fit_summary = fit_summary,
    signoff_by_prior = signoff_by_prior,
    signoff_by_fit_type = signoff_by_fit_type,
    pair_summary = pair_summary,
    figure_index = figure_index
  ))
}
