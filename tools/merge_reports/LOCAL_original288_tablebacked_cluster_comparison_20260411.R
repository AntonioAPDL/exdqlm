#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

PRIMARY_ROOT <- "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
FALLBACK_ROOTS <- c(
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
)
ALL_ROOTS <- c(PRIMARY_ROOT, FALLBACK_ROOTS)

selection_path <- file.path(
  PRIMARY_ROOT,
  "tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv"
)
dynamic_update_path <- file.path(
  PRIMARY_ROOT,
  "tools/merge_reports/LOCAL_original288_dynamic_restored_selection_update_20260411.csv"
)
output_dir <- file.path(
  PRIMARY_ROOT,
  "tools/merge_reports/original288_tablebacked_comparison_20260411"
)
report_dir <- file.path(
  PRIMARY_ROOT,
  "reports/static_exal_tuning_20260411"
)
report_path <- file.path(
  report_dir,
  "original288_tablebacked_cluster_comparison_20260411.md"
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

gate_rank_20260411 <- function(x) {
  out <- rep(NA_integer_, length(x))
  out[toupper(x) == "PASS"] <- 3L
  out[toupper(x) == "WARN"] <- 2L
  out[toupper(x) == "FAIL"] <- 1L
  out
}

resolve_existing_path_20260411 <- function(path) {
  if (is.na(path) || !nzchar(path)) {
    return(NA_character_)
  }
  if (file.exists(path)) {
    return(normalizePath(path, winslash = "/", mustWork = TRUE))
  }
  norm_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  for (root in ALL_ROOTS) {
    if (!startsWith(norm_path, root)) {
      next
    }
    rel <- sub(paste0("^", root), "", norm_path)
    for (alt_root in ALL_ROOTS) {
      cand <- paste0(alt_root, rel)
      if (file.exists(cand)) {
        return(normalizePath(cand, winslash = "/", mustWork = TRUE))
      }
    }
  }
  NA_character_
}

resolve_validation_dir_20260411 <- function(sel_row) {
  fit_path <- as.character(sel_row$selected_fit_path[[1]] %||% "")
  if (!nzchar(fit_path)) {
    return(NA_character_)
  }
  val_dir_raw <- sub("/fits/.*$", "", fit_path)
  candidate_dirs <- c(val_dir_raw)
  norm_raw <- normalizePath(val_dir_raw, winslash = "/", mustWork = FALSE)
  for (root in ALL_ROOTS) {
    if (!startsWith(norm_raw, root)) {
      next
    }
    rel <- sub(paste0("^", root), "", norm_raw)
    for (alt_root in ALL_ROOTS) {
      candidate_dirs <- c(candidate_dirs, paste0(alt_root, rel))
    }
  }
  candidate_dirs <- unique(candidate_dirs)
  for (cand in candidate_dirs) {
    cand_resolved <- resolve_existing_path_20260411(cand)
    if (is.na(cand_resolved)) {
      next
    }
    if (file.exists(file.path(cand_resolved, "tables", "fit_metrics_by_task.csv"))) {
      return(cand_resolved)
    }
  }
  NA_character_
}

read_csv_safe_20260411 <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) {
    return(NULL)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

dynamic_mean_ci_width_20260411 <- function(fit_path, sim_path) {
  fit_raw <- readRDS(fit_path)
  fit_obj <- fit_raw$fit %||% fit_raw
  sim <- readRDS(sim_path)
  pred <- as.matrix(fit_obj$samp.post.pred)
  lower <- apply(pred, 1, stats::quantile, probs = 0.025, na.rm = TRUE)
  upper <- apply(pred, 1, stats::quantile, probs = 0.975, na.rm = TRUE)
  mean(upper - lower, na.rm = TRUE)
}

extract_rhsns_metrics_20260411 <- function(sel_row) {
  metrics_path <- resolve_existing_path_20260411(as.character(sel_row$selected_summary_path[[1]] %||% ""))
  if (is.na(metrics_path)) {
    stop(sprintf("rhs_ns metrics path missing for %s", sel_row$original_case_key[[1]]))
  }
  metrics <- read.csv(metrics_path, stringsAsFactors = FALSE, check.names = FALSE)
  data.frame(
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = as.integer(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = sel_row$model[[1]],
    inference = sel_row$inference[[1]],
    original_case_key = sel_row$original_case_key[[1]],
    original_scenario_key = sel_row$original_scenario_key[[1]],
    gate_overall = sel_row$gate_overall[[1]],
    healthy = isTRUE(sel_row$healthy[[1]]),
    runtime_sec = suppressWarnings(as.numeric(sel_row$runtime_sec[[1]] %||% metrics$runtime_sec[[1]])),
    primary_accuracy = suppressWarnings(as.numeric(metrics$q_rmse[[1]])),
    coverage = NA_real_,
    mean_ci_width = NA_real_,
    mae = NA_real_,
    bias = NA_real_,
    corr = NA_real_,
    cie = suppressWarnings(as.numeric(metrics$cie[[1]])),
    beta_rmse_mean = suppressWarnings(as.numeric(metrics$beta_rmse_mean[[1]])),
    beta_coverage_gap = suppressWarnings(as.numeric(metrics$beta_coverage_gap[[1]])),
    metric_source = "rhsns_wave_metrics",
    metric_error = NA_character_,
    stringsAsFactors = FALSE
  )
}

validation_table_cache <- new.env(parent = emptyenv())

load_validation_tables_20260411 <- function(validation_dir) {
  key <- validation_dir
  if (exists(key, envir = validation_table_cache, inherits = FALSE)) {
    return(get(key, envir = validation_table_cache, inherits = FALSE))
  }
  tables <- list(
    fit_metrics = read_csv_safe_20260411(file.path(validation_dir, "tables", "fit_metrics_by_task.csv")),
    metrics_summary = read_csv_safe_20260411(file.path(validation_dir, "tables", "metrics_summary.csv")),
    fit_summary = read_csv_safe_20260411(file.path(validation_dir, "tables", "fit_summary.csv")),
    method_signoff = read_csv_safe_20260411(file.path(validation_dir, "tables", "method_signoff_long.csv")),
    model_pair = read_csv_safe_20260411(file.path(validation_dir, "tables", "model_pair_signoff.csv")),
    algorithm_pair = read_csv_safe_20260411(file.path(validation_dir, "tables", "pairwise_vb_vs_mcmc.csv"))
  )
  assign(key, tables, envir = validation_table_cache)
  tables
}

extract_table_metrics_20260411 <- function(sel_row) {
  validation_dir <- resolve_validation_dir_20260411(sel_row)
  if (is.na(validation_dir)) {
    stop(sprintf("validation tables unavailable for %s", sel_row$original_case_key[[1]]))
  }
  tables <- load_validation_tables_20260411(validation_dir)
  row_inference <- as.character(sel_row$inference[[1]])
  row_model <- as.character(sel_row$model[[1]])

  fit_metrics <- tables$fit_metrics
  metrics_summary <- tables$metrics_summary
  fit_summary <- tables$fit_summary

  if (is.null(fit_metrics)) {
    stop(sprintf("fit_metrics_by_task.csv unavailable under %s", validation_dir))
  }

  if ("method" %in% names(fit_metrics)) {
    metric_row <- fit_metrics[
      fit_metrics$method == row_inference & fit_metrics$model == row_model,
      ,
      drop = FALSE
    ]
  } else {
    metric_row <- fit_metrics[
      fit_metrics$inference == row_inference & fit_metrics$model == row_model,
      ,
      drop = FALSE
    ]
  }
  if (!nrow(metric_row)) {
    stop(sprintf("metric row missing for %s / %s under %s", row_inference, row_model, validation_dir))
  }
  metric_row <- metric_row[1, , drop = FALSE]

  coverage <- NA_real_
  mean_ci_width <- NA_real_
  if (!is.null(metrics_summary)) {
    inf_col <- if ("inference" %in% names(metrics_summary)) "inference" else "method"
    summary_row <- metrics_summary[
      metrics_summary[[inf_col]] == row_inference & metrics_summary$model == row_model,
      ,
      drop = FALSE
    ]
    if (nrow(summary_row)) {
      summary_row <- summary_row[1, , drop = FALSE]
      if ("coverage" %in% names(summary_row)) {
        coverage <- suppressWarnings(as.numeric(summary_row$coverage[[1]]))
      }
      if ("mean_ci_width" %in% names(summary_row)) {
        mean_ci_width <- suppressWarnings(as.numeric(summary_row$mean_ci_width[[1]]))
      }
    }
  } else {
    if ("coverage" %in% names(metric_row)) {
      coverage <- suppressWarnings(as.numeric(metric_row$coverage[[1]]))
    }
    if ("mean_ci_width" %in% names(metric_row)) {
      mean_ci_width <- suppressWarnings(as.numeric(metric_row$mean_ci_width[[1]]))
    }
  }

  runtime_sec <- suppressWarnings(as.numeric(sel_row$runtime_sec[[1]]))
  if ((!is.finite(runtime_sec) || is.na(runtime_sec)) && !is.null(fit_summary)) {
    inf_col <- if ("inference" %in% names(fit_summary)) "inference" else "method"
    fit_row <- fit_summary[
      fit_summary[[inf_col]] == row_inference & fit_summary$model == row_model,
      ,
      drop = FALSE
    ]
    if (nrow(fit_row) && "runtime_sec" %in% names(fit_row)) {
      runtime_sec <- suppressWarnings(as.numeric(fit_row$runtime_sec[[1]]))
    }
  }

  data.frame(
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = as.integer(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = row_model,
    inference = row_inference,
    original_case_key = sel_row$original_case_key[[1]],
    original_scenario_key = sel_row$original_scenario_key[[1]],
    gate_overall = sel_row$gate_overall[[1]],
    healthy = isTRUE(sel_row$healthy[[1]]),
    runtime_sec = runtime_sec,
    primary_accuracy = suppressWarnings(as.numeric(metric_row$rmse[[1]])),
    coverage = coverage,
    mean_ci_width = mean_ci_width,
    mae = if ("mae" %in% names(metric_row)) suppressWarnings(as.numeric(metric_row$mae[[1]])) else NA_real_,
    bias = if ("bias" %in% names(metric_row)) suppressWarnings(as.numeric(metric_row$bias[[1]])) else NA_real_,
    corr = if ("corr" %in% names(metric_row)) suppressWarnings(as.numeric(metric_row$corr[[1]])) else NA_real_,
    cie = NA_real_,
    beta_rmse_mean = NA_real_,
    beta_coverage_gap = NA_real_,
    metric_source = "validation_tables",
    metric_error = NA_character_,
    stringsAsFactors = FALSE
  )
}

extract_dynamic_restored_metrics_20260411 <- function(sel_row, dynamic_update) {
  key <- sel_row$original_case_key[[1]]
  hit <- subset(dynamic_update, original_case_key == key)
  if (!nrow(hit)) {
    stop(sprintf("dynamic restored update missing for %s", key))
  }
  hit <- hit[1, , drop = FALSE]
  fit_path <- resolve_existing_path_20260411(hit$selected_fit_path[[1]])
  sim_path <- resolve_existing_path_20260411(hit$metric_sim_path_override[[1]])
  mean_ci_width <- dynamic_mean_ci_width_20260411(fit_path, sim_path)
  data.frame(
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = as.integer(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = sel_row$model[[1]],
    inference = sel_row$inference[[1]],
    original_case_key = key,
    original_scenario_key = sel_row$original_scenario_key[[1]],
    gate_overall = sel_row$gate_overall[[1]],
    healthy = isTRUE(sel_row$healthy[[1]]),
    runtime_sec = suppressWarnings(as.numeric(hit$runtime_sec[[1]])),
    primary_accuracy = suppressWarnings(as.numeric(hit$q_rmse_metric[[1]])),
    coverage = suppressWarnings(as.numeric(hit$coverage95_metric[[1]])),
    mean_ci_width = mean_ci_width,
    mae = NA_real_,
    bias = NA_real_,
    corr = NA_real_,
    cie = NA_real_,
    beta_rmse_mean = NA_real_,
    beta_coverage_gap = suppressWarnings(as.numeric(hit$coverage95_gap_metric[[1]])),
    metric_source = "dynamic_restored_metrics",
    metric_error = NA_character_,
    stringsAsFactors = FALSE
  )
}

build_metric_long_20260411 <- function(selection, dynamic_update) {
  rows <- vector("list", length = nrow(selection))
  for (i in seq_len(nrow(selection))) {
    sel_row <- selection[i, , drop = FALSE]
    rows[[i]] <- tryCatch(
      {
        if (identical(sel_row$block[[1]], "static_shrink") && identical(sel_row$prior_semantics[[1]], "rhs_ns")) {
          extract_rhsns_metrics_20260411(sel_row)
        } else if (
          identical(sel_row$block[[1]], "dynamic") &&
            identical(sel_row$model[[1]], "exdqlm") &&
            identical(sel_row$inference[[1]], "mcmc") &&
            sel_row$original_case_key[[1]] %in% dynamic_update$original_case_key
        ) {
          extract_dynamic_restored_metrics_20260411(sel_row, dynamic_update)
        } else {
          extract_table_metrics_20260411(sel_row)
        }
      },
      error = function(e) {
        data.frame(
          block = sel_row$block[[1]],
          root_kind = sel_row$root_kind[[1]],
          family = sel_row$family[[1]],
          tau_label = sel_row$tau[[1]],
          fit_size = as.integer(sel_row$fit_size[[1]]),
          prior_semantics = sel_row$prior_semantics[[1]],
          model = sel_row$model[[1]],
          inference = sel_row$inference[[1]],
          original_case_key = sel_row$original_case_key[[1]],
          original_scenario_key = sel_row$original_scenario_key[[1]],
          gate_overall = sel_row$gate_overall[[1]],
          healthy = isTRUE(sel_row$healthy[[1]]),
          runtime_sec = suppressWarnings(as.numeric(sel_row$runtime_sec[[1]])),
          primary_accuracy = NA_real_,
          coverage = NA_real_,
          mean_ci_width = NA_real_,
          mae = NA_real_,
          bias = NA_real_,
          corr = NA_real_,
          cie = NA_real_,
          beta_rmse_mean = NA_real_,
          beta_coverage_gap = NA_real_,
          metric_source = "error",
          metric_error = conditionMessage(e),
          stringsAsFactors = FALSE
        )
      }
    )
  }
  metric_long <- do.call(rbind, rows)
  if (!"metric_error" %in% names(metric_long)) {
    metric_long$metric_error <- NA_character_
  }
  metric_long
}

build_model_pairs_20260411 <- function(metric_long, block_name, base_model, ext_model, prefix) {
  sub <- subset(metric_long, block == block_name)
  split_key <- paste(sub$original_scenario_key, sub$inference, sep = "\r")
  parts <- split(sub, split_key)
  out <- lapply(parts, function(df) {
    base <- subset(df, model == base_model)
    ext <- subset(df, model == ext_model)
    if (!nrow(base) || !nrow(ext)) {
      return(NULL)
    }
    base <- base[1, , drop = FALSE]
    ext <- ext[1, , drop = FALSE]
    data.frame(
      block = block_name,
      family = base$family[[1]],
      tau_label = base$tau_label[[1]],
      fit_size = base$fit_size[[1]],
      prior_semantics = base$prior_semantics[[1]],
      inference = base$inference[[1]],
      original_scenario_key = base$original_scenario_key[[1]],
      base_model = base_model,
      extended_model = ext_model,
      primary_accuracy_base = base$primary_accuracy[[1]],
      primary_accuracy_extended = ext$primary_accuracy[[1]],
      primary_accuracy_delta = suppressWarnings(as.numeric(ext$primary_accuracy[[1]] - base$primary_accuracy[[1]])),
      coverage_base = base$coverage[[1]],
      coverage_extended = ext$coverage[[1]],
      coverage_delta = suppressWarnings(as.numeric(ext$coverage[[1]] - base$coverage[[1]])),
      mean_ci_width_base = base$mean_ci_width[[1]],
      mean_ci_width_extended = ext$mean_ci_width[[1]],
      mean_ci_width_delta = suppressWarnings(as.numeric(ext$mean_ci_width[[1]] - base$mean_ci_width[[1]])),
      runtime_sec_base = base$runtime_sec[[1]],
      runtime_sec_extended = ext$runtime_sec[[1]],
      runtime_ratio_extended_over_base = suppressWarnings(as.numeric(ext$runtime_sec[[1]] / base$runtime_sec[[1]])),
      gate_base = base$gate_overall[[1]],
      gate_extended = ext$gate_overall[[1]],
      healthy_base = base$healthy[[1]],
      healthy_extended = ext$healthy[[1]],
      extended_better_accuracy = if (is.finite(base$primary_accuracy[[1]]) && is.finite(ext$primary_accuracy[[1]])) ext$primary_accuracy[[1]] < base$primary_accuracy[[1]] else NA,
      extended_healthier = {
        br <- gate_rank_20260411(base$gate_overall[[1]])
        er <- gate_rank_20260411(ext$gate_overall[[1]])
        if (is.na(br) || is.na(er)) NA else er > br
      },
      base_metric_source = base$metric_source[[1]],
      extended_metric_source = ext$metric_source[[1]],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out[!vapply(out, is.null, logical(1))])
  names(out)[names(out) == "extended_better_accuracy"] <- sprintf("%s_better_accuracy", prefix)
  names(out)[names(out) == "extended_healthier"] <- sprintf("%s_healthier", prefix)
  out
}

build_algorithm_pairs_20260411 <- function(metric_long, block_name) {
  sub <- subset(metric_long, block == block_name)
  split_key <- paste(sub$original_scenario_key, sub$model, sep = "\r")
  parts <- split(sub, split_key)
  out <- lapply(parts, function(df) {
    vb <- subset(df, inference == "vb")
    mcmc <- subset(df, inference == "mcmc")
    if (!nrow(vb) || !nrow(mcmc)) {
      return(NULL)
    }
    vb <- vb[1, , drop = FALSE]
    mcmc <- mcmc[1, , drop = FALSE]
    data.frame(
      block = block_name,
      family = vb$family[[1]],
      tau_label = vb$tau_label[[1]],
      fit_size = vb$fit_size[[1]],
      prior_semantics = vb$prior_semantics[[1]],
      model = vb$model[[1]],
      original_scenario_key = vb$original_scenario_key[[1]],
      primary_accuracy_vb = vb$primary_accuracy[[1]],
      primary_accuracy_mcmc = mcmc$primary_accuracy[[1]],
      primary_accuracy_delta_mcmc_minus_vb = suppressWarnings(as.numeric(mcmc$primary_accuracy[[1]] - vb$primary_accuracy[[1]])),
      coverage_vb = vb$coverage[[1]],
      coverage_mcmc = mcmc$coverage[[1]],
      coverage_delta_mcmc_minus_vb = suppressWarnings(as.numeric(mcmc$coverage[[1]] - vb$coverage[[1]])),
      mean_ci_width_vb = vb$mean_ci_width[[1]],
      mean_ci_width_mcmc = mcmc$mean_ci_width[[1]],
      mean_ci_width_delta_mcmc_minus_vb = suppressWarnings(as.numeric(mcmc$mean_ci_width[[1]] - vb$mean_ci_width[[1]])),
      runtime_sec_vb = vb$runtime_sec[[1]],
      runtime_sec_mcmc = mcmc$runtime_sec[[1]],
      runtime_ratio_mcmc_over_vb = suppressWarnings(as.numeric(mcmc$runtime_sec[[1]] / vb$runtime_sec[[1]])),
      gate_vb = vb$gate_overall[[1]],
      gate_mcmc = mcmc$gate_overall[[1]],
      mcmc_better_accuracy = if (is.finite(vb$primary_accuracy[[1]]) && is.finite(mcmc$primary_accuracy[[1]])) mcmc$primary_accuracy[[1]] < vb$primary_accuracy[[1]] else NA,
      mcmc_healthier = {
        vr <- gate_rank_20260411(vb$gate_overall[[1]])
        mr <- gate_rank_20260411(mcmc$gate_overall[[1]])
        if (is.na(vr) || is.na(mr)) NA else mr > vr
      },
      vb_metric_source = vb$metric_source[[1]],
      mcmc_metric_source = mcmc$metric_source[[1]],
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out[!vapply(out, is.null, logical(1))])
}

summary_bool_mean_20260411 <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

build_cluster_summary_20260411 <- function(df, group_cols, better_col, healthier_col, delta_col, runtime_col) {
  split_key <- interaction(df[, group_cols], drop = TRUE, lex.order = TRUE)
  parts <- split(df, split_key)
  out <- lapply(parts, function(part) {
    base <- part[1, group_cols, drop = FALSE]
    base$n <- nrow(part)
    base$available_accuracy <- sum(!is.na(part[[better_col]]))
    base$better_accuracy <- sum(part[[better_col]] %in% TRUE, na.rm = TRUE)
    base$better_accuracy_share <- summary_bool_mean_20260411(part[[better_col]])
    base$healthier <- sum(part[[healthier_col]] %in% TRUE, na.rm = TRUE)
    base$healthier_share <- summary_bool_mean_20260411(part[[healthier_col]])
    delta_vals <- suppressWarnings(as.numeric(part[[delta_col]]))
    delta_vals <- delta_vals[is.finite(delta_vals)]
    base$delta_median <- if (length(delta_vals)) stats::median(delta_vals) else NA_real_
    base$delta_mean <- if (length(delta_vals)) mean(delta_vals) else NA_real_
    runtime_vals <- suppressWarnings(as.numeric(part[[runtime_col]]))
    runtime_vals <- runtime_vals[is.finite(runtime_vals)]
    base$runtime_ratio_median <- if (length(runtime_vals)) stats::median(runtime_vals) else NA_real_
    base
  })
  do.call(rbind, out)
}

fmt_int_20260411 <- function(x) {
  ifelse(is.na(x), "NA", format(as.integer(x), trim = TRUE, scientific = FALSE))
}

fmt_pct_20260411 <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.1f%%", 100 * x))
}

fmt_num_20260411 <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", sprintf(paste0("%.", digits, "f"), x))
}

fmt_ratio_20260411 <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.2fx", x))
}

markdown_table_20260411 <- function(df) {
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  rule <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, rule, rows)
}

selection <- read.csv(selection_path, stringsAsFactors = FALSE, check.names = FALSE)
dynamic_update <- read.csv(dynamic_update_path, stringsAsFactors = FALSE, check.names = FALSE)

metric_long <- build_metric_long_20260411(selection, dynamic_update)
metric_long <- metric_long[order(metric_long$block, metric_long$prior_semantics, metric_long$family, metric_long$tau_label, metric_long$fit_size, metric_long$inference, metric_long$model), , drop = FALSE]

static_model_pairs <- build_model_pairs_20260411(metric_long, "static_paper", "al", "exal", "exal")
static_model_pairs <- rbind(
  static_model_pairs,
  build_model_pairs_20260411(metric_long, "static_shrink", "al", "exal", "exal")
)
dynamic_model_pairs <- build_model_pairs_20260411(metric_long, "dynamic", "dqlm", "exdqlm", "exdqlm")

static_algorithm_pairs <- build_algorithm_pairs_20260411(metric_long, "static_paper")
static_algorithm_pairs <- rbind(
  static_algorithm_pairs,
  build_algorithm_pairs_20260411(metric_long, "static_shrink")
)
dynamic_algorithm_pairs <- build_algorithm_pairs_20260411(metric_long, "dynamic")

static_model_cluster_summary <- build_cluster_summary_20260411(
  static_model_pairs,
  group_cols = c("block", "prior_semantics", "inference"),
  better_col = "exal_better_accuracy",
  healthier_col = "exal_healthier",
  delta_col = "primary_accuracy_delta",
  runtime_col = "runtime_ratio_extended_over_base"
)
static_model_cluster_detail <- build_cluster_summary_20260411(
  static_model_pairs,
  group_cols = c("block", "prior_semantics", "inference", "family", "tau_label", "fit_size"),
  better_col = "exal_better_accuracy",
  healthier_col = "exal_healthier",
  delta_col = "primary_accuracy_delta",
  runtime_col = "runtime_ratio_extended_over_base"
)
dynamic_model_cluster_summary <- build_cluster_summary_20260411(
  dynamic_model_pairs,
  group_cols = c("inference"),
  better_col = "exdqlm_better_accuracy",
  healthier_col = "exdqlm_healthier",
  delta_col = "primary_accuracy_delta",
  runtime_col = "runtime_ratio_extended_over_base"
)
dynamic_model_cluster_by_tau <- build_cluster_summary_20260411(
  dynamic_model_pairs,
  group_cols = c("inference", "tau_label"),
  better_col = "exdqlm_better_accuracy",
  healthier_col = "exdqlm_healthier",
  delta_col = "primary_accuracy_delta",
  runtime_col = "runtime_ratio_extended_over_base"
)
static_algorithm_cluster_summary <- build_cluster_summary_20260411(
  static_algorithm_pairs,
  group_cols = c("block", "prior_semantics", "model"),
  better_col = "mcmc_better_accuracy",
  healthier_col = "mcmc_healthier",
  delta_col = "primary_accuracy_delta_mcmc_minus_vb",
  runtime_col = "runtime_ratio_mcmc_over_vb"
)
dynamic_algorithm_cluster_summary <- build_cluster_summary_20260411(
  dynamic_algorithm_pairs,
  group_cols = c("model"),
  better_col = "mcmc_better_accuracy",
  healthier_col = "mcmc_healthier",
  delta_col = "primary_accuracy_delta_mcmc_minus_vb",
  runtime_col = "runtime_ratio_mcmc_over_vb"
)

static_mcmc_pairs <- subset(static_model_pairs, inference == "mcmc")
static_vb_pairs <- subset(static_model_pairs, inference == "vb")
dynamic_mcmc_pairs <- subset(dynamic_model_pairs, inference == "mcmc")
dynamic_vb_pairs <- subset(dynamic_model_pairs, inference == "vb")

meta <- data.frame(
  selection_rows = nrow(selection),
  metric_rows = nrow(metric_long),
  metric_errors = sum(!is.na(metric_long$metric_error) & nzchar(metric_long$metric_error)),
  static_model_pairs = nrow(static_model_pairs),
  dynamic_model_pairs = nrow(dynamic_model_pairs),
  static_algorithm_pairs = nrow(static_algorithm_pairs),
  dynamic_algorithm_pairs = nrow(dynamic_algorithm_pairs),
  stringsAsFactors = FALSE
)

write.csv(metric_long, file.path(output_dir, "original288_tablebacked_metric_long_20260411.csv"), row.names = FALSE)
write.csv(static_model_pairs, file.path(output_dir, "original288_static_model_pair_comparison_20260411.csv"), row.names = FALSE)
write.csv(dynamic_model_pairs, file.path(output_dir, "original288_dynamic_model_pair_comparison_20260411.csv"), row.names = FALSE)
write.csv(static_algorithm_pairs, file.path(output_dir, "original288_static_algorithm_pair_comparison_20260411.csv"), row.names = FALSE)
write.csv(dynamic_algorithm_pairs, file.path(output_dir, "original288_dynamic_algorithm_pair_comparison_20260411.csv"), row.names = FALSE)
write.csv(static_model_cluster_summary, file.path(output_dir, "original288_static_model_cluster_summary_20260411.csv"), row.names = FALSE)
write.csv(static_model_cluster_detail, file.path(output_dir, "original288_static_model_cluster_detail_20260411.csv"), row.names = FALSE)
write.csv(dynamic_model_cluster_summary, file.path(output_dir, "original288_dynamic_model_cluster_summary_20260411.csv"), row.names = FALSE)
write.csv(dynamic_model_cluster_by_tau, file.path(output_dir, "original288_dynamic_model_cluster_by_tau_20260411.csv"), row.names = FALSE)
write.csv(static_algorithm_cluster_summary, file.path(output_dir, "original288_static_algorithm_cluster_summary_20260411.csv"), row.names = FALSE)
write.csv(dynamic_algorithm_cluster_summary, file.path(output_dir, "original288_dynamic_algorithm_cluster_summary_20260411.csv"), row.names = FALSE)
write.csv(meta, file.path(output_dir, "original288_tablebacked_metric_meta_20260411.csv"), row.names = FALSE)

static_mcmc_better <- sum(static_mcmc_pairs$exal_better_accuracy %in% TRUE, na.rm = TRUE)
static_mcmc_available <- sum(!is.na(static_mcmc_pairs$exal_better_accuracy))
static_vb_better <- sum(static_vb_pairs$exal_better_accuracy %in% TRUE, na.rm = TRUE)
static_vb_available <- sum(!is.na(static_vb_pairs$exal_better_accuracy))
dynamic_mcmc_better <- sum(dynamic_mcmc_pairs$exdqlm_better_accuracy %in% TRUE, na.rm = TRUE)
dynamic_mcmc_available <- sum(!is.na(dynamic_mcmc_pairs$exdqlm_better_accuracy))
dynamic_vb_better <- sum(dynamic_vb_pairs$exdqlm_better_accuracy %in% TRUE, na.rm = TRUE)
dynamic_vb_available <- sum(!is.na(dynamic_vb_pairs$exdqlm_better_accuracy))

static_model_report <- static_model_cluster_summary
static_model_report$better <- sprintf(
  "%s / %s",
  fmt_int_20260411(static_model_report$better_accuracy),
  fmt_int_20260411(static_model_report$available_accuracy)
)
static_model_report$better_share <- fmt_pct_20260411(static_model_report$better_accuracy_share)
static_model_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_20260411(static_model_report$healthier),
  fmt_int_20260411(static_model_report$n)
)
static_model_report$healthier_share <- fmt_pct_20260411(static_model_report$healthier_share)
static_model_report$delta_mean <- fmt_num_20260411(static_model_report$delta_mean, 3)
static_model_report$runtime_ratio <- fmt_ratio_20260411(static_model_report$runtime_ratio_median)
static_model_report <- static_model_report[, c(
  "block", "prior_semantics", "inference", "better", "better_share",
  "healthier", "healthier_share", "delta_mean", "runtime_ratio"
)]

dynamic_model_report <- dynamic_model_cluster_summary
dynamic_model_report$better <- sprintf(
  "%s / %s",
  fmt_int_20260411(dynamic_model_report$better_accuracy),
  fmt_int_20260411(dynamic_model_report$available_accuracy)
)
dynamic_model_report$better_share <- fmt_pct_20260411(dynamic_model_report$better_accuracy_share)
dynamic_model_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_20260411(dynamic_model_report$healthier),
  fmt_int_20260411(dynamic_model_report$n)
)
dynamic_model_report$healthier_share <- fmt_pct_20260411(dynamic_model_report$healthier_share)
dynamic_model_report$delta_mean <- fmt_num_20260411(dynamic_model_report$delta_mean, 3)
dynamic_model_report$runtime_ratio <- fmt_ratio_20260411(dynamic_model_report$runtime_ratio_median)
dynamic_model_report <- dynamic_model_report[, c(
  "inference", "better", "better_share", "healthier",
  "healthier_share", "delta_mean", "runtime_ratio"
)]

dynamic_tau_report <- dynamic_model_cluster_by_tau
dynamic_tau_report$better <- sprintf(
  "%s / %s",
  fmt_int_20260411(dynamic_tau_report$better_accuracy),
  fmt_int_20260411(dynamic_tau_report$available_accuracy)
)
dynamic_tau_report$better_share <- fmt_pct_20260411(dynamic_tau_report$better_accuracy_share)
dynamic_tau_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_20260411(dynamic_tau_report$healthier),
  fmt_int_20260411(dynamic_tau_report$n)
)
dynamic_tau_report$healthier_share <- fmt_pct_20260411(dynamic_tau_report$healthier_share)
dynamic_tau_report$delta_mean <- fmt_num_20260411(dynamic_tau_report$delta_mean, 3)
dynamic_tau_report$runtime_ratio <- fmt_ratio_20260411(dynamic_tau_report$runtime_ratio_median)
dynamic_tau_report <- dynamic_tau_report[, c(
  "inference", "tau_label", "better", "better_share", "healthier",
  "healthier_share", "delta_mean", "runtime_ratio"
)]

static_algorithm_report <- static_algorithm_cluster_summary
static_algorithm_report$better <- sprintf(
  "%s / %s",
  fmt_int_20260411(static_algorithm_report$better_accuracy),
  fmt_int_20260411(static_algorithm_report$available_accuracy)
)
static_algorithm_report$better_share <- fmt_pct_20260411(static_algorithm_report$better_accuracy_share)
static_algorithm_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_20260411(static_algorithm_report$healthier),
  fmt_int_20260411(static_algorithm_report$n)
)
static_algorithm_report$healthier_share <- fmt_pct_20260411(static_algorithm_report$healthier_share)
static_algorithm_report$delta_mean <- fmt_num_20260411(static_algorithm_report$delta_mean, 3)
static_algorithm_report$runtime_ratio <- fmt_ratio_20260411(static_algorithm_report$runtime_ratio_median)
static_algorithm_report <- static_algorithm_report[, c(
  "block", "prior_semantics", "model", "better", "better_share",
  "healthier", "healthier_share", "delta_mean", "runtime_ratio"
)]

dynamic_algorithm_report <- dynamic_algorithm_cluster_summary
dynamic_algorithm_report$better <- sprintf(
  "%s / %s",
  fmt_int_20260411(dynamic_algorithm_report$better_accuracy),
  fmt_int_20260411(dynamic_algorithm_report$available_accuracy)
)
dynamic_algorithm_report$better_share <- fmt_pct_20260411(dynamic_algorithm_report$better_accuracy_share)
dynamic_algorithm_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_20260411(dynamic_algorithm_report$healthier),
  fmt_int_20260411(dynamic_algorithm_report$n)
)
dynamic_algorithm_report$healthier_share <- fmt_pct_20260411(dynamic_algorithm_report$healthier_share)
dynamic_algorithm_report$delta_mean <- fmt_num_20260411(dynamic_algorithm_report$delta_mean, 3)
dynamic_algorithm_report$runtime_ratio <- fmt_ratio_20260411(dynamic_algorithm_report$runtime_ratio_median)
dynamic_algorithm_report <- dynamic_algorithm_report[, c(
  "model", "better", "better_share", "healthier",
  "healthier_share", "delta_mean", "runtime_ratio"
)]

report_lines <- c(
  "# Original288 Table-Backed Cluster Comparison (2026-04-11)",
  "",
  "This note refreshes the cluster-by-cluster comparison after the `static_shrink / rhs -> rhs_ns` correction, using stable validation tables and selected wave metrics rather than stale historical fit-RDS paths.",
  "",
  "## Scope",
  "",
  "- freeze legacy mixed-prior `static_shrink / rhs` as historical only",
  "- use corrected `rhs_ns` selection for the full `72`-row shrinkage branch",
  "- use accepted `v9` for the broader `288`-row current-state comparison",
  "- compare within inference (`al` vs `exal`, `dqlm` vs `exdqlm`) and within model (`vb` vs `mcmc`)",
  "",
  "## Source Rule",
  "",
  "- `static_paper`, `static_shrink / ridge`, and non-promoted dynamic rows use native validation tables (`fit_metrics_by_task.csv`, `metrics_summary.csv`, `fit_summary.csv`)",
  "- corrected `static_shrink / rhs_ns` rows use the selected wave metrics CSVs from the rebuild / repair / bridge lanes",
  "- the `3` promoted dynamic restored-closure rows use the selected restored-closure metrics plus direct posterior-width recomputation",
  "",
  "## Main Results",
  "",
  sprintf("- static `mcmc`: `exal` has better primary accuracy in `%d / %d` scenario pairs (`%.1f%%`)", static_mcmc_better, static_mcmc_available, 100 * static_mcmc_better / max(1, static_mcmc_available)),
  sprintf("- static `vb`: `exal` has better primary accuracy in `%d / %d` scenario pairs (`%.1f%%`)", static_vb_better, static_vb_available, 100 * static_vb_better / max(1, static_vb_available)),
  sprintf("- dynamic `mcmc`: `exdqlm` has better primary accuracy in `%d / %d` scenario pairs (`%.1f%%`)", dynamic_mcmc_better, dynamic_mcmc_available, 100 * dynamic_mcmc_better / max(1, dynamic_mcmc_available)),
  sprintf("- dynamic `vb`: `exdqlm` has better primary accuracy in `%d / %d` scenario pairs (`%.1f%%`)", dynamic_vb_better, dynamic_vb_available, 100 * dynamic_vb_better / max(1, dynamic_vb_available)),
  "",
  "## Static Model Comparison Within Inference",
  "",
  markdown_table_20260411(static_model_report),
  "",
  "## Dynamic Model Comparison Within Inference",
  "",
  markdown_table_20260411(dynamic_model_report),
  "",
  "## Dynamic Model Comparison By Tau",
  "",
  markdown_table_20260411(dynamic_tau_report),
  "",
  "## Algorithm Comparison Within Model",
  "",
  "Static:",
  "",
  markdown_table_20260411(static_algorithm_report),
  "",
  "Dynamic:",
  "",
  markdown_table_20260411(dynamic_algorithm_report),
  "",
  "## Interpretation",
  "",
  if (static_mcmc_better > static_mcmc_available / 2) {
    sprintf("- the corrected current-state comparison supports the intended static conclusion: `exal` is better than `al` overall within `mcmc`, after replacing legacy `rhs` with explicit `rhs_ns`")
  } else {
    sprintf("- the corrected current-state comparison does not support a broad static `mcmc` claim that `exal` is better than `al` overall")
  },
  "- the dynamic side remains more mixed and should be interpreted separately from the static `exal` claim",
  "- the strongest corrected static signal remains `mcmc`: all three static `mcmc` clusters now favor `exal` on the current primary-accuracy metric",
  "- the dynamic picture is cluster-dependent: `tau = 0p95` is the main `exdqlm` win region, while `0p05` and `0p25` remain unfavorable in `mcmc`",
  "- within-model algorithm comparisons now show that static `exal` usually benefits from `mcmc` over `vb`, while dynamic `exdqlm` more often favors `vb` on the current primary-accuracy metric",
  "- this pass is reproducible because it no longer depends on missing historical fit-RDS paths for the majority of rows",
  "- the older fit-RDS-based `20260409` comparison outputs should now be treated as superseded for the corrected `rhs_ns` question",
  "",
  "## Outputs",
  "",
  sprintf("- `%s`", file.path(output_dir, "original288_tablebacked_metric_long_20260411.csv")),
  sprintf("- `%s`", file.path(output_dir, "original288_static_model_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(output_dir, "original288_dynamic_model_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(output_dir, "original288_static_algorithm_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(output_dir, "original288_dynamic_algorithm_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(output_dir, "original288_static_model_cluster_summary_20260411.csv")),
  sprintf("- `%s`", file.path(output_dir, "original288_dynamic_model_cluster_summary_20260411.csv"))
)

writeLines(report_lines, con = report_path)

cat(
  sprintf(
    "TABLEBACKED_COMPARISON static_mcmc=%d/%d static_vb=%d/%d dynamic_mcmc=%d/%d dynamic_vb=%d/%d errors=%d\n",
    static_mcmc_better, static_mcmc_available,
    static_vb_better, static_vb_available,
    dynamic_mcmc_better, dynamic_mcmc_available,
    dynamic_vb_better, dynamic_vb_available,
    sum(!is.na(metric_long$metric_error) & nzchar(metric_long$metric_error))
  )
)
