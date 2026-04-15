#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_helpers_20260414.R")

parse_args_original288_dynamic_tt5000_exactspec_repair_eval <- function(args) {
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

summarize_status_original288_dynamic_tt5000_exactspec_repair <- function(df, group_cols) {
  key <- interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  spl <- split(df, key)
  out <- lapply(spl, function(d) {
    base <- d[1, group_cols, drop = FALSE]
    data.frame(
      base,
      total = nrow(d),
      done = sum(d$gate_current != "MISSING"),
      missing = sum(d$gate_current == "MISSING"),
      pass = sum(d$gate_current == "PASS"),
      warn = sum(d$gate_current == "WARN"),
      fail = sum(d$gate_current == "FAIL"),
      healthy = sum(d$healthy_current),
      better_than_reference = sum(d$reference_compare == "better_than_reference"),
      matches_reference = sum(d$reference_compare == "matches_reference"),
      worse_than_reference = sum(d$reference_compare == "worse_than_reference"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

args <- parse_args_original288_dynamic_tt5000_exactspec_repair_eval(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_dynamic_tt5000_exactspec_repair()
manifest_path <- safe_chr_original288_dynamic_tt5000_exactspec_repair(args$manifest, paths$full_manifest)
status_out <- safe_chr_original288_dynamic_tt5000_exactspec_repair(args$status_out, paths$full_manifest_status)
phase_out <- safe_chr_original288_dynamic_tt5000_exactspec_repair(args$phase_out, paths$full_phase_summary)

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)

if (!nrow(manifest)) {
  utils::write.csv(manifest, status_out, row.names = FALSE)
  utils::write.csv(data.frame(), phase_out, row.names = FALSE)
  cat("SUMMARY total=0 done=0 missing=0 pass=0 warn=0 fail=0 healthy=0 better=0 matches=0 worse=0\n")
  quit(save = "no", status = 0)
}

status_rows <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, , drop = FALSE]
  row_csv <- if (file.exists(row$row_status_path)) {
    utils::read.csv(row$row_status_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else NULL
  metrics_csv <- if (file.exists(row$metrics_path)) {
    utils::read.csv(row$metrics_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else NULL

  gate_current <- if (!is.null(row_csv) && nrow(row_csv)) safe_chr_original288_dynamic_tt5000_exactspec_repair(row_csv$gate_overall[1], "FAIL") else "MISSING"
  healthy_current <- if (!is.null(row_csv) && nrow(row_csv)) isTRUE(row_csv$healthy[1]) else FALSE
  status_current <- if (!is.null(row_csv) && nrow(row_csv)) safe_chr_original288_dynamic_tt5000_exactspec_repair(row_csv$status[1], "missing") else "missing"
  error_current <- if (!is.null(row_csv) && nrow(row_csv)) safe_chr_original288_dynamic_tt5000_exactspec_repair(row_csv$error[1], NA_character_) else NA_character_
  runtime_sec_current <- if (!is.null(metrics_csv) && nrow(metrics_csv)) {
    safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$runtime_sec[1], NA_real_)
  } else if (!is.null(row_csv) && nrow(row_csv)) {
    safe_num_original288_dynamic_tt5000_exactspec_repair(row_csv$runtime_sec[1], NA_real_)
  } else {
    NA_real_
  }

  reference_gate <- safe_chr_original288_dynamic_tt5000_exactspec_repair(row$reference_gate[1], "FAIL")
  reference_compare <- if (identical(gate_current, "MISSING")) {
    "pending"
  } else {
    current_rank <- gate_rank_original288_dynamic_tt5000_exactspec_repair(gate_current)
    reference_rank <- gate_rank_original288_dynamic_tt5000_exactspec_repair(reference_gate)
    if (current_rank < reference_rank) "better_than_reference" else if (current_rank > reference_rank) "worse_than_reference" else "matches_reference"
  }

  status_rows[[i]] <- data.frame(
    row_id = row$row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    phase = row$phase,
    phase_order = row$phase_order,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    candidate_label = row$candidate_label,
    seed_slot = row$seed_slot,
    seed = row$seed,
    status_current = status_current,
    error_current = error_current,
    gate_current = gate_current,
    healthy_current = healthy_current,
    runtime_sec_current = runtime_sec_current,
    crps_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$crps_metric[1], NA_real_) else NA_real_,
    primary_accuracy_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$primary_accuracy_metric[1], NA_real_) else NA_real_,
    q_rmse_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$q_rmse_metric[1], NA_real_) else NA_real_,
    coverage95_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$coverage95_metric[1], NA_real_) else NA_real_,
    coverage95_gap_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$coverage95_gap_metric[1], NA_real_) else NA_real_,
    mean_ci_width_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$mean_ci_width_metric[1], NA_real_) else NA_real_,
    cie_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$cie_metric[1], NA_real_) else NA_real_,
    beta_rmse_mean_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$beta_rmse_mean_metric[1], NA_real_) else NA_real_,
    beta_coverage_gap_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_original288_dynamic_tt5000_exactspec_repair(metrics_csv$beta_coverage_gap_metric[1], NA_real_) else NA_real_,
    metric_source = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_chr_original288_dynamic_tt5000_exactspec_repair(metrics_csv$metric_source[1], NA_character_) else NA_character_,
    metric_error = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_chr_original288_dynamic_tt5000_exactspec_repair(metrics_csv$metric_error[1], NA_character_) else NA_character_,
    reference_gate = reference_gate,
    reference_compare = reference_compare,
    accepted_baseline_gate = safe_chr_original288_dynamic_tt5000_exactspec_repair(row$accepted_baseline_gate[1], NA_character_),
    stringsAsFactors = FALSE
  )
}

status_df <- do.call(rbind, status_rows)
status_df <- status_df[order(status_df$phase_order, status_df$row_id), , drop = FALSE]
utils::write.csv(status_df, status_out, row.names = FALSE)

phase_summary <- summarize_status_original288_dynamic_tt5000_exactspec_repair(status_df, "phase")
phase_summary <- phase_summary[order(unname(phase_order_original288_dynamic_tt5000_exactspec_repair[phase_summary$phase])), , drop = FALSE]
utils::write.csv(phase_summary, phase_out, row.names = FALSE)

cat(sprintf(
  "SUMMARY total=%d done=%d missing=%d pass=%d warn=%d fail=%d healthy=%d better=%d matches=%d worse=%d\n",
  nrow(status_df),
  sum(status_df$gate_current != "MISSING"),
  sum(status_df$gate_current == "MISSING"),
  sum(status_df$gate_current == "PASS"),
  sum(status_df$gate_current == "WARN"),
  sum(status_df$gate_current == "FAIL"),
  sum(status_df$healthy_current),
  sum(status_df$reference_compare == "better_than_reference"),
  sum(status_df$reference_compare == "matches_reference"),
  sum(status_df$reference_compare == "worse_than_reference")
))
