#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args_static_bqrgal_eval <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    }
  }
  out
}

args <- parse_args_static_bqrgal_eval(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_static_bqrgal_aligned_helpers_20260408.R")

paths <- static_bqrgal_aligned_paths_20260408()
manifest_path <- safe_chr_static_bqrgal(args$manifest, paths$manifest)

if (!file.exists(manifest_path)) stop(sprintf("manifest not found: %s", manifest_path))

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)

read_optional_csv <- function(path) {
  if (!nzchar(safe_chr_static_bqrgal(path, "")) || !file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

status_rows <- vector("list", nrow(manifest))
metric_rows <- list()

for (i in seq_len(nrow(manifest))) {
  man <- manifest[i, , drop = FALSE]
  row_df <- read_optional_csv(man$row_status_path[1])
  health_df <- read_optional_csv(man$health_path[1])
  metrics_df <- read_optional_csv(man$metrics_path[1])

  state <- if (is.null(row_df)) {
    "pending"
  } else {
    safe_chr_static_bqrgal(row_df$status[1], "pending")
  }
  gate_current <- if (!is.null(health_df)) {
    safe_chr_static_bqrgal(health_df$gate_overall[1], "MISSING")
  } else {
    "MISSING"
  }
  healthy <- if (!is.null(health_df)) isTRUE(health_df$healthy[1]) else FALSE
  runtime_sec <- if (!is.null(row_df)) safe_num_static_bqrgal(row_df$runtime_sec[1], NA_real_) else NA_real_
  fit_exists <- file.exists(man$fit_path[1])

  status_rows[[i]] <- data.frame(
    row_id = man$row_id[1],
    phase = man$phase[1],
    phase_order = man$phase_order[1],
    lane_label = man$lane_label[1],
    family = man$family[1],
    tau = man$tau[1],
    tau_label = man$tau_label[1],
    n_train = man$n_train[1],
    rep_id = man$rep_id[1],
    model = man$model[1],
    engine = man$engine[1],
    status = state,
    gate_current = gate_current,
    healthy = healthy,
    runtime_sec = runtime_sec,
    fit_exists = fit_exists,
    fit_path = man$fit_path[1],
    row_status_path = man$row_status_path[1],
    health_path = man$health_path[1],
    metrics_path = man$metrics_path[1],
    stringsAsFactors = FALSE
  )

  if (!is.null(metrics_df) && nrow(metrics_df)) {
    metric_rows[[length(metric_rows) + 1L]] <- metrics_df
  }
}

status_df <- do.call(rbind, status_rows)
status_df <- status_df[order(status_df$row_id), , drop = FALSE]
utils::write.csv(status_df, paths$manifest_status, row.names = FALSE)

metrics_long <- if (length(metric_rows)) do.call(rbind, metric_rows) else data.frame()
utils::write.csv(metrics_long, paths$metrics_long, row.names = FALSE)

count_gate <- function(x, gate) sum(as.character(x) == gate, na.rm = TRUE)

health_summary <- data.frame(
  total = nrow(status_df),
  done = sum(status_df$status %in% c("done", "skipped_existing", "failed_runtime")),
  missing = sum(status_df$gate_current == "MISSING"),
  pass = count_gate(status_df$gate_current, "PASS"),
  warn = count_gate(status_df$gate_current, "WARN"),
  fail = count_gate(status_df$gate_current, "FAIL"),
  healthy = sum(status_df$gate_current %in% c("PASS", "WARN"), na.rm = TRUE),
  stringsAsFactors = FALSE
)
utils::write.csv(health_summary, paths$health_summary, row.names = FALSE)

if (nrow(metrics_long)) {
  scenario_keys <- unique(metrics_long[, c("lane_label", "family", "tau_label", "n_train", "model"), drop = FALSE])
  split_key <- with(metrics_long, paste(lane_label, family, tau_label, n_train, model, sep = "\r"))
  scenario_split <- split(metrics_long, split_key)

  summarize_scenario <- function(df) {
    out <- df[1, c("lane_label", "family", "tau", "tau_label", "n_train", "model", "engine"), drop = FALSE]
    out$n_rows <- nrow(df)
    out$runtime_sec_median <- stats::median(df$runtime_sec, na.rm = TRUE)
    out$runtime_sec_sd <- stats::sd(df$runtime_sec, na.rm = TRUE)
    out$cie_median <- stats::median(df$cie, na.rm = TRUE)
    out$cie_sd <- stats::sd(df$cie, na.rm = TRUE)
    out$beta_rmse_mean_median <- stats::median(df$beta_rmse_mean, na.rm = TRUE)
    out$beta_rmse_mean_sd <- stats::sd(df$beta_rmse_mean, na.rm = TRUE)
    out$beta_coverage_mean_mean <- mean(df$beta_coverage_mean, na.rm = TRUE)
    out$beta_coverage_mean_sd <- stats::sd(df$beta_coverage_mean, na.rm = TRUE)
    out$pred_interval_score_mean_median <- stats::median(df$pred_interval_score_mean, na.rm = TRUE)
    out$pred_interval_score_mean_sd <- stats::sd(df$pred_interval_score_mean, na.rm = TRUE)
    for (j in seq_len(8L)) {
      cov_col <- sprintf("beta_cover_b%02d", j)
      rmse_col <- sprintf("beta_rmse_b%02d", j)
      out[[cov_col]] <- mean(df[[cov_col]], na.rm = TRUE)
      out[[rmse_col]] <- stats::median(df[[rmse_col]], na.rm = TRUE)
    }
    gate_sub <- status_df[status_df$lane_label == out$lane_label[1] &
      status_df$family == out$family[1] &
      status_df$tau_label == out$tau_label[1] &
      status_df$n_train == out$n_train[1] &
      status_df$model == out$model[1], , drop = FALSE]
    out$pass <- count_gate(gate_sub$gate_current, "PASS")
    out$warn <- count_gate(gate_sub$gate_current, "WARN")
    out$fail <- count_gate(gate_sub$gate_current, "FAIL")
    out$healthy <- sum(gate_sub$gate_current %in% c("PASS", "WARN"), na.rm = TRUE)
    out
  }

  summary_by_scenario <- do.call(rbind, lapply(scenario_split, summarize_scenario))
  summary_by_scenario <- summary_by_scenario[order(
    summary_by_scenario$lane_label,
    summary_by_scenario$family,
    summary_by_scenario$tau,
    summary_by_scenario$model
  ), , drop = FALSE]
  rownames(summary_by_scenario) <- NULL
  utils::write.csv(summary_by_scenario, paths$summary_by_scenario, row.names = FALSE)

  model_split <- split(summary_by_scenario, paste(summary_by_scenario$lane_label, summary_by_scenario$model, sep = "\r"))
  summary_by_model <- do.call(rbind, lapply(model_split, function(df) {
    data.frame(
      lane_label = df$lane_label[1],
      model = df$model[1],
      scenarios = nrow(df),
      cie_median_median = stats::median(df$cie_median, na.rm = TRUE),
      beta_rmse_mean_median = stats::median(df$beta_rmse_mean_median, na.rm = TRUE),
      beta_coverage_mean_mean = mean(df$beta_coverage_mean_mean, na.rm = TRUE),
      pred_interval_score_mean_median = stats::median(df$pred_interval_score_mean_median, na.rm = TRUE),
      runtime_sec_median = stats::median(df$runtime_sec_median, na.rm = TRUE),
      pass = sum(df$pass, na.rm = TRUE),
      warn = sum(df$warn, na.rm = TRUE),
      fail = sum(df$fail, na.rm = TRUE),
      healthy = sum(df$healthy, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
  utils::write.csv(summary_by_model, paths$summary_by_model, row.names = FALSE)

  pair_keys <- unique(summary_by_scenario[, c("lane_label", "family", "tau", "tau_label", "n_train"), drop = FALSE])
  pair_rows <- vector("list", nrow(pair_keys))
  for (i in seq_len(nrow(pair_keys))) {
    key <- pair_keys[i, , drop = FALSE]
    sub <- summary_by_scenario[
      summary_by_scenario$lane_label == key$lane_label &
        summary_by_scenario$family == key$family &
        summary_by_scenario$tau_label == key$tau_label &
        summary_by_scenario$n_train == key$n_train,
      ,
      drop = FALSE
    ]
    al <- sub[sub$model == "al", , drop = FALSE]
    exal <- sub[sub$model == "exal", , drop = FALSE]
    if (nrow(al) == 1L && nrow(exal) == 1L) {
      pair_rows[[i]] <- data.frame(
        lane_label = key$lane_label,
        family = key$family,
        tau = key$tau,
        tau_label = key$tau_label,
        n_train = key$n_train,
        cie_delta_exal_minus_al = exal$cie_median - al$cie_median,
        beta_rmse_delta_exal_minus_al = exal$beta_rmse_mean_median - al$beta_rmse_mean_median,
        beta_coverage_delta_exal_minus_al = exal$beta_coverage_mean_mean - al$beta_coverage_mean_mean,
        interval_score_delta_exal_minus_al = exal$pred_interval_score_mean_median - al$pred_interval_score_mean_median,
        runtime_ratio_exal_over_al = exal$runtime_sec_median / al$runtime_sec_median,
        healthy_delta_exal_minus_al = exal$healthy - al$healthy,
        stringsAsFactors = FALSE
      )
    }
  }
  model_pair <- do.call(rbind, pair_rows)
  utils::write.csv(model_pair, paths$model_pair, row.names = FALSE)

  build_metric_table <- function(metric_med_col, metric_sd_col, out_path, digits = 3L) {
    rows <- list()
    idx <- 1L
    for (lane in c("paper_matched_core", "extension_n1000")) {
      lane_df <- summary_by_scenario[summary_by_scenario$lane_label == lane, , drop = FALSE]
      if (!nrow(lane_df)) next
      for (tau_label in c("0p05", "0p25", "0p50")) {
        for (model in c("exal", "al")) {
          sub <- lane_df[lane_df$tau_label == tau_label & lane_df$model == model, , drop = FALSE]
          row_out <- data.frame(
            lane_label = lane,
            tau_label = tau_label,
            model = model,
            normal = NA_character_,
            laplace = NA_character_,
            gausmix = NA_character_,
            stringsAsFactors = FALSE
          )
          for (fam in c("normal", "laplace", "gausmix")) {
            fam_sub <- sub[sub$family == fam, , drop = FALSE]
            if (nrow(fam_sub) == 1L) {
              row_out[[fam]] <- format_med_sd_static_bqrgal_20260408(
                fam_sub[[metric_med_col]][1],
                fam_sub[[metric_sd_col]][1],
                digits = digits
              )
            }
          }
          rows[[idx]] <- row_out
          idx <- idx + 1L
        }
      }
    }
    table_df <- do.call(rbind, rows)
    utils::write.csv(table_df, out_path, row.names = FALSE)
  }

  build_metric_table("cie_median", "cie_sd", paths$cie_table, digits = 3L)
  build_metric_table("beta_rmse_mean_median", "beta_rmse_mean_sd", paths$rmse_table, digits = 3L)
  build_metric_table("beta_coverage_mean_mean", "beta_coverage_mean_sd", paths$coverage_table, digits = 3L)
  build_metric_table("pred_interval_score_mean_median", "pred_interval_score_mean_sd", paths$interval_score_table, digits = 2L)
} else {
  utils::write.csv(data.frame(), paths$summary_by_scenario, row.names = FALSE)
  utils::write.csv(data.frame(), paths$summary_by_model, row.names = FALSE)
  utils::write.csv(data.frame(), paths$model_pair, row.names = FALSE)
  utils::write.csv(data.frame(), paths$cie_table, row.names = FALSE)
  utils::write.csv(data.frame(), paths$rmse_table, row.names = FALSE)
  utils::write.csv(data.frame(), paths$coverage_table, row.names = FALSE)
  utils::write.csv(data.frame(), paths$interval_score_table, row.names = FALSE)
}

cat(sprintf(
  "SUMMARY total=%d done=%d missing=%d pass=%d warn=%d fail=%d healthy=%d\n",
  health_summary$total[1],
  health_summary$done[1],
  health_summary$missing[1],
  health_summary$pass[1],
  health_summary$warn[1],
  health_summary$fail[1],
  health_summary$healthy[1]
))
