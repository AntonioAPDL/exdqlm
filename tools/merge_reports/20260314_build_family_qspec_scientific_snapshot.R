#!/usr/bin/env Rscript

suppressWarnings({
  options(stringsAsFactors = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1) normalizePath(args[[1]], mustWork = TRUE) else getwd()

merge_dir <- file.path(repo_root, "tools", "merge_reports")
global_tables_dir <- file.path(
  merge_dir,
  "20260312_family_qspec_global_cross_family_summary",
  "tables"
)

vb_vs_mcmc_path <- file.path(global_tables_dir, "vb_vs_mcmc_summary.tsv")
extended_vs_baseline_path <- file.path(global_tables_dir, "pairwise_model_compare_long.tsv")

out_tsv <- file.path(merge_dir, "20260314_family_qspec_scientific_comparison_snapshot.tsv")
out_md <- file.path(merge_dir, "20260314_family_qspec_scientific_comparison_snapshot.md")

stopifnot(file.exists(vb_vs_mcmc_path))
stopifnot(file.exists(extended_vs_baseline_path))

vb_vs_mcmc <- utils::read.delim(vb_vs_mcmc_path, sep = "\t", check.names = FALSE)
extended_vs_baseline <- utils::read.delim(
  extended_vs_baseline_path,
  sep = "\t",
  check.names = FALSE
)

format_num <- function(x, digits = 3) {
  if (length(x) == 0 || is.na(x) || !is.finite(x)) {
    return("NA")
  }
  formatC(x, digits = digits, format = "f")
}

campaign_label <- function(root_kind) {
  switch(
    root_kind,
    "static_paper" = "static paper",
    "static_shrink" = "static shrink",
    "dynamic" = "dynamic",
    root_kind
  )
}

model_labels <- function(root_kind) {
  if (identical(root_kind, "dynamic")) {
    c("dqlm", "exdqlm")
  } else {
    c("al", "exal")
  }
}

format_vb_vs_mcmc <- function(df, root_kind, family, model) {
  row <- df[df$root_kind == root_kind & df$family == family & df$model == model, , drop = FALSE]
  if (nrow(row) == 0) {
    return("not available")
  }

  rmse_delta <- suppressWarnings(as.numeric(row$mean_rmse_delta_mcmc_minus_vb[[1]]))
  runtime_ratio <- suppressWarnings(as.numeric(row$mean_runtime_ratio_mcmc_vs_vb[[1]]))
  mcmc_better <- suppressWarnings(as.integer(row$mcmc_better_rmse_count[[1]]))
  vb_better <- suppressWarnings(as.integer(row$vb_better_rmse_count[[1]]))
  n_rows <- suppressWarnings(as.integer(row$comparison_rows[[1]]))

  better_label <- if (is.finite(rmse_delta) && rmse_delta < 0) {
    "MCMC lower RMSE"
  } else if (is.finite(rmse_delta) && rmse_delta > 0) {
    "VB lower RMSE"
  } else {
    "near tie"
  }

  win_counts <- sprintf("%s/%s", ifelse(is.na(mcmc_better), "0", mcmc_better), ifelse(is.na(n_rows), "0", n_rows))
  if (startsWith(better_label, "VB")) {
    win_counts <- sprintf("%s/%s", ifelse(is.na(vb_better), "0", vb_better), ifelse(is.na(n_rows), "0", n_rows))
  }

  runtime_text <- if (is.finite(runtime_ratio)) {
    paste0(", runtime x", format_num(runtime_ratio, 1))
  } else {
    ""
  }

  sprintf(
    "%s (%s rows, mean ΔRMSE=%s%s)",
    better_label,
    win_counts,
    format_num(rmse_delta, 3),
    runtime_text
  )
}

summarise_extended_vs_baseline <- function(df) {
  split_key <- interaction(df$root_kind, df$family, df$method, drop = TRUE)
  pieces <- lapply(split(df, split_key), function(chunk) {
    root_kind <- unique(chunk$root_kind)[[1]]
    family <- unique(chunk$family)[[1]]
    method <- unique(chunk$method)[[1]]
    delta <- suppressWarnings(as.numeric(chunk$rmse_delta_extended_minus_baseline))
    delta <- delta[is.finite(delta)]
    n_rows <- length(delta)
    mean_delta <- if (n_rows > 0) mean(delta) else NA_real_
    ext_wins <- if (n_rows > 0) sum(delta < 0) else 0L
    base_wins <- if (n_rows > 0) sum(delta > 0) else 0L
    extended_label <- if (identical(root_kind, "dynamic")) "extended" else "exAL"
    baseline_label <- if (identical(root_kind, "dynamic")) "baseline" else "AL"
    outcome <- if (is.finite(mean_delta) && mean_delta < 0) {
      paste(extended_label, "lower RMSE")
    } else if (is.finite(mean_delta) && mean_delta > 0) {
      paste(baseline_label, "lower RMSE")
    } else {
      "near tie"
    }
    data.frame(
      root_kind = root_kind,
      family = family,
      method = method,
      summary = sprintf(
        "%s (%s/%s rows, mean ΔRMSE=%s)",
        outcome,
        if (startsWith(outcome, extended_label)) ext_wins else if (startsWith(outcome, baseline_label)) base_wins else n_rows,
        n_rows,
        format_num(mean_delta, 3)
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, pieces)
}

collect_shrink_rows <- function(root) {
  files <- Sys.glob(file.path(
    root,
    "results",
    "function_testing_20260309_static_shrinkage_family_qspec",
    "*",
    "tau_*",
    "fit_input_subsample_tt*",
    "compare_ridge_vs_rhs_family_qspec",
    "tables",
    "rhs_vs_ridge_summary.csv"
  ))
  if (!length(files)) {
    return(data.frame())
  }

  rows <- lapply(files, function(path) {
    df <- utils::read.csv(path, check.names = FALSE)
    if (!nrow(df)) {
      return(NULL)
    }
    family <- sub(
      ".*/function_testing_20260309_static_shrinkage_family_qspec/([^/]+)/tau_.*",
      "\\1",
      path
    )
    df$family <- family
    df
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) {
    return(data.frame())
  }
  do.call(rbind, rows)
}

format_prior_summary <- function(df, family) {
  chunk <- df[df$family == family, , drop = FALSE]
  if (!nrow(chunk)) {
    return("N/A")
  }

  signal_delta <- suppressWarnings(as.numeric(chunk$beta_rmse_signal_rhs_minus_ridge))
  fpr_delta <- suppressWarnings(as.numeric(chunk$support_fpr_zero_rhs_minus_ridge))
  signal_delta <- signal_delta[is.finite(signal_delta)]
  fpr_delta <- fpr_delta[is.finite(fpr_delta)]

  mean_signal_delta <- if (length(signal_delta)) mean(signal_delta) else NA_real_
  mean_fpr_delta <- if (length(fpr_delta)) mean(fpr_delta) else NA_real_

  signal_text <- if (is.finite(mean_signal_delta) && mean_signal_delta < 0) {
    "rhs slightly better signal RMSE"
  } else if (is.finite(mean_signal_delta) && mean_signal_delta > 0) {
    "ridge better signal RMSE"
  } else {
    "signal RMSE roughly tied"
  }

  fpr_text <- if (is.finite(mean_fpr_delta) && mean_fpr_delta < 0) {
    "rhs lowers false positives"
  } else if (is.finite(mean_fpr_delta) && mean_fpr_delta > 0) {
    "ridge lowers false positives"
  } else {
    "false-positive rate roughly tied"
  }

  sprintf(
    "%s; %s (Δsignal=%s, ΔFPR=%s)",
    signal_text,
    fpr_text,
    format_num(mean_signal_delta, 3),
    format_num(mean_fpr_delta, 3)
  )
}

extended_summary <- summarise_extended_vs_baseline(extended_vs_baseline)
shrink_summary_rows <- collect_shrink_rows(repo_root)

families <- c("gausmix", "laplace", "normal")
root_kinds <- c("dynamic", "static_paper", "static_shrink")

lookup_extended_summary <- function(root_kind, family, method) {
  vals <- extended_summary$summary[
    extended_summary$root_kind == root_kind &
      extended_summary$family == family &
      extended_summary$method == method
  ]
  if (!length(vals)) {
    return("not available")
  }
  vals[[1]]
}

snapshot_rows <- lapply(root_kinds, function(root_kind) {
  lapply(families, function(family) {
    models <- model_labels(root_kind)
    data.frame(
      campaign = campaign_label(root_kind),
      family = family,
      vb_vs_mcmc_baseline = format_vb_vs_mcmc(vb_vs_mcmc, root_kind, family, models[[1]]),
      vb_vs_mcmc_extended = format_vb_vs_mcmc(vb_vs_mcmc, root_kind, family, models[[2]]),
      extended_vs_baseline_vb = lookup_extended_summary(root_kind, family, "vb"),
      extended_vs_baseline_mcmc = lookup_extended_summary(root_kind, family, "mcmc"),
      prior_takeaway = if (identical(root_kind, "static_shrink")) {
        format_prior_summary(shrink_summary_rows, family)
      } else {
        "N/A"
      },
      stringsAsFactors = FALSE
    )
  })
})

snapshot_df <- do.call(rbind, unlist(snapshot_rows, recursive = FALSE))
rownames(snapshot_df) <- NULL

utils::write.table(
  snapshot_df,
  file = out_tsv,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

md_lines <- c(
  "# 20260314 Family-QSpec Scientific Comparison Snapshot",
  "",
  paste0("- generated_at: `", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "`"),
  paste0("- source_vb_vs_mcmc: `", sub(paste0("^", normalizePath(repo_root), "/?"), "", normalizePath(vb_vs_mcmc_path)), "`"),
  paste0("- source_extended_vs_baseline: `", sub(paste0("^", normalizePath(repo_root), "/?"), "", normalizePath(extended_vs_baseline_path)), "`"),
  "",
  "| Campaign | Family | VB vs MCMC baseline | VB vs MCMC extended | Extended vs baseline under VB | Extended vs baseline under MCMC | RHS vs ridge |",
  "|---|---|---|---|---|---|---|"
)

for (i in seq_len(nrow(snapshot_df))) {
  row <- snapshot_df[i, , drop = FALSE]
  md_lines <- c(
    md_lines,
    paste(
      "|",
      row$campaign,
      "|",
      row$family,
      "|",
      row$vb_vs_mcmc_baseline,
      "|",
      row$vb_vs_mcmc_extended,
      "|",
      ifelse(length(row$extended_vs_baseline_vb) && nzchar(row$extended_vs_baseline_vb), row$extended_vs_baseline_vb, "not available"),
      "|",
      ifelse(length(row$extended_vs_baseline_mcmc) && nzchar(row$extended_vs_baseline_mcmc), row$extended_vs_baseline_mcmc, "not available"),
      "|",
      row$prior_takeaway,
      "|"
    )
  )
}

writeLines(md_lines, con = out_md)

cat("WROTE\n")
cat(out_tsv, "\n")
cat(out_md, "\n")
