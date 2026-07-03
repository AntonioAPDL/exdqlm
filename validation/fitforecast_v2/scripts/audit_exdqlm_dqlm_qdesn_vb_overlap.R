#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(name, default = NULL) {
  flag <- paste0("--", name)
  idx <- match(flag, args)
  if (!is.na(idx) && idx < length(args)) {
    return(args[[idx + 1]])
  }
  default
}

repo_root <- normalizePath(getwd(), mustWork = TRUE)

default_ex_summary <- file.path(
  repo_root,
  "validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen",
  "manifests/top3_forecast_confirmation_summary_20260703.csv"
)
default_article_summary <- "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"
default_out_csv <- file.path(
  repo_root,
  "validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_overlap_comparison_20260703.csv"
)
default_out_md <- file.path(
  repo_root,
  "validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_OVERLAP_AUDIT_2026-07-03.md"
)

ex_summary_path <- get_arg("ex-summary", default_ex_summary)
article_summary_path <- get_arg("article-summary", default_article_summary)
out_csv <- get_arg("out-csv", default_out_csv)
out_md <- get_arg("out-md", default_out_md)

read_required_csv <- function(path) {
  if (!file.exists(path)) {
    stop("Required CSV does not exist: ", path, call. = FALSE)
  }
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

require_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(label, " is missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(x, format = "f", digits = digits))
}

git_value <- function(...) {
  value <- tryCatch(
    system2("git", c(...), stdout = TRUE, stderr = TRUE),
    error = function(e) NA_character_
  )
  if (length(value) == 0) NA_character_ else value[[1]]
}

choose_min <- function(data, group_cols, order_cols) {
  if (!nrow(data)) {
    return(data)
  }
  ord <- do.call(order, data[order_cols])
  data <- data[ord, , drop = FALSE]
  key <- do.call(paste, c(data[group_cols], sep = "\r"))
  data[!duplicated(key), , drop = FALSE]
}

article <- read_required_csv(article_summary_path)
ex <- read_required_csv(ex_summary_path)

require_columns(
  ex,
  c(
    "row_id", "model_variant", "family", "tau", "candidate_id", "status",
    "health_gate", "runtime_sec", "fit_q_rmse", "fit_check",
    "forecast_h1000_mae", "forecast_h1000_rmse", "forecast_h1000_check",
    "rank_h1000_mae_in_cell", "rank_h1000_check_in_cell"
  ),
  "exDQLM/DQLM confirmation summary"
)

require_columns(
  article,
  c(
    "model_family", "model_variant", "model_label", "inference", "inference_label",
    "family", "tau", "fit_qtrue_rmse", "fit_pinball_mean",
    "forecast_qtrue_mae_lead_weighted", "forecast_pinball_mean_lead_weighted",
    "validation_branch", "validation_commit", "article_interface_ids"
  ),
  "Article summary"
)

confirmed <- subset(ex, status == "done" & health_gate == "PASS")
confirmed_winners <- choose_min(
  confirmed,
  c("model_variant", "family", "tau"),
  c("model_variant", "family", "tau", "forecast_h1000_check", "forecast_h1000_mae", "fit_q_rmse")
)

qdesn_vb <- subset(article, model_family == "qdesn" & inference == "vb")
qdesn_best <- choose_min(
  qdesn_vb,
  c("family", "tau"),
  c("family", "tau", "forecast_pinball_mean_lead_weighted", "forecast_qtrue_mae_lead_weighted", "fit_qtrue_rmse")
)

article_ex_vb <- subset(article, model_family == "exdqlm_dqlm" & inference == "vb")
article_ex_best <- choose_min(
  article_ex_vb,
  c("model_variant", "family", "tau"),
  c("model_variant", "family", "tau", "forecast_pinball_mean_lead_weighted", "forecast_qtrue_mae_lead_weighted", "fit_qtrue_rmse")
)

confirmed_winners$key <- paste(confirmed_winners$model_variant, confirmed_winners$family, confirmed_winners$tau, sep = "||")
qdesn_best$key <- paste(qdesn_best$family, qdesn_best$tau, sep = "||")
article_ex_best$key <- paste(article_ex_best$model_variant, article_ex_best$family, article_ex_best$tau, sep = "||")

rows <- vector("list", nrow(confirmed_winners))

for (i in seq_len(nrow(confirmed_winners))) {
  c_row <- confirmed_winners[i, , drop = FALSE]
  q_row <- qdesn_best[qdesn_best$key == paste(c_row$family, c_row$tau, sep = "||"), , drop = FALSE]
  old_row <- article_ex_best[article_ex_best$key == c_row$key, , drop = FALSE]
  if (nrow(q_row) != 1) {
    stop("Could not find one Q-DESN VB comparison row for ", c_row$family, " tau=", c_row$tau, call. = FALSE)
  }
  if (nrow(old_row) > 1) {
    stop("Found more than one old article exDQLM/DQLM row for ", c_row$key, call. = FALSE)
  }
  if (nrow(old_row) == 0) {
    old_row <- data.frame(
      fit_qtrue_rmse = NA_real_,
      forecast_qtrue_mae_lead_weighted = NA_real_,
      forecast_pinball_mean_lead_weighted = NA_real_,
      validation_commit = NA_character_,
      article_interface_ids = NA_character_
    )
  }

  fit_ratio_qdesn <- c_row$fit_q_rmse / q_row$fit_qtrue_rmse
  mae_ratio_qdesn <- c_row$forecast_h1000_mae / q_row$forecast_qtrue_mae_lead_weighted
  check_ratio_qdesn <- c_row$forecast_h1000_check / q_row$forecast_pinball_mean_lead_weighted

  old_fit_ratio <- c_row$fit_q_rmse / old_row$fit_qtrue_rmse
  old_mae_ratio <- c_row$forecast_h1000_mae / old_row$forecast_qtrue_mae_lead_weighted
  old_check_ratio <- c_row$forecast_h1000_check / old_row$forecast_pinball_mean_lead_weighted

  recommendation <- "promote as improved VB baseline only; do not launch broad MCMC"
  if (c_row$family == "laplace" && c_row$tau <= 0.05) {
    recommendation <- "defer MCMC; run targeted laplace-left-tail VB screen first"
  } else if (isTRUE(check_ratio_qdesn <= 1.05 && mae_ratio_qdesn <= 1.20 && fit_ratio_qdesn <= 1.25)) {
    recommendation <- "eligible for narrow MCMC follow-up if a matched VB/MCMC counterpart is required"
  }

  rows[[i]] <- data.frame(
    model_variant = c_row$model_variant,
    family = c_row$family,
    tau = c_row$tau,
    confirmed_candidate_id = c_row$candidate_id,
    confirmed_fit_rmse = c_row$fit_q_rmse,
    confirmed_fit_check = c_row$fit_check,
    confirmed_forecast_mae = c_row$forecast_h1000_mae,
    confirmed_forecast_check = c_row$forecast_h1000_check,
    qdesn_best_label = gsub("--", "-", q_row$model_label, fixed = TRUE),
    qdesn_best_likelihood = q_row$qdesn_likelihood,
    qdesn_best_fit_rmse = q_row$fit_qtrue_rmse,
    qdesn_best_fit_check = q_row$fit_pinball_mean,
    qdesn_best_forecast_mae = q_row$forecast_qtrue_mae_lead_weighted,
    qdesn_best_forecast_check = q_row$forecast_pinball_mean_lead_weighted,
    ratio_fit_rmse_vs_qdesn = fit_ratio_qdesn,
    ratio_forecast_mae_vs_qdesn = mae_ratio_qdesn,
    ratio_forecast_check_vs_qdesn = check_ratio_qdesn,
    old_article_fit_rmse = old_row$fit_qtrue_rmse,
    old_article_forecast_mae = old_row$forecast_qtrue_mae_lead_weighted,
    old_article_forecast_check = old_row$forecast_pinball_mean_lead_weighted,
    ratio_fit_rmse_vs_old_article = old_fit_ratio,
    ratio_forecast_mae_vs_old_article = old_mae_ratio,
    ratio_forecast_check_vs_old_article = old_check_ratio,
    qdesn_beats_confirmed_fit_rmse = q_row$fit_qtrue_rmse < c_row$fit_q_rmse,
    qdesn_beats_confirmed_forecast_mae = q_row$forecast_qtrue_mae_lead_weighted < c_row$forecast_h1000_mae,
    qdesn_beats_confirmed_forecast_check = q_row$forecast_pinball_mean_lead_weighted < c_row$forecast_h1000_check,
    recommendation = recommendation,
    qdesn_validation_commit = q_row$validation_commit,
    qdesn_article_interface_ids = q_row$article_interface_ids,
    old_article_validation_commit = old_row$validation_commit,
    old_article_interface_ids = old_row$article_interface_ids,
    stringsAsFactors = FALSE
  )
}

comparison <- do.call(rbind, rows)
comparison <- comparison[order(comparison$family, comparison$tau, comparison$model_variant), , drop = FALSE]

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(comparison, out_csv, row.names = FALSE, na = "")

repo_branch <- git_value("rev-parse", "--abbrev-ref", "HEAD")
repo_head <- git_value("rev-parse", "HEAD")
repo_subject <- git_value("log", "-1", "--format=%s")

old_improved <- with(comparison, is.na(ratio_forecast_check_vs_old_article) | ratio_forecast_check_vs_old_article < 1)
qdesn_wins_check <- comparison$qdesn_beats_confirmed_forecast_check
eligible_mcmc <- grepl("^eligible", comparison$recommendation)

md <- c(
  "# exDQLM/DQLM and Q-DESN VB Overlap Audit",
  "",
  "Date: 2026-07-03",
  "",
  "## Scope",
  "",
  "This audit compares the completed exDQLM/DQLM VB forecast-confirmation rows against the current Article-facing Q-DESN VB simulation-study rows. It is intentionally limited to overlap cells present in the confirmation run; it does not promote unconfirmed exDQLM/DQLM cells.",
  "",
  "## Inputs",
  "",
  paste0("- validation worktree: `", repo_root, "`"),
  paste0("- validation branch: `", repo_branch, "`"),
  paste0("- validation HEAD at audit generation: `", repo_head, "`"),
  paste0("- validation HEAD subject: `", repo_subject, "`"),
  paste0("- exDQLM/DQLM confirmation summary: `", ex_summary_path, "`"),
  paste0("- Article-facing summary read-only input: `", article_summary_path, "`"),
  paste0("- reproducible CSV output: `", out_csv, "`"),
  "",
  "## Evidence Counts",
  "",
  paste0("- confirmed exDQLM/DQLM PASS rows: `", nrow(confirmed), "`"),
  paste0("- confirmed model/family/tau winners compared here: `", nrow(comparison), "`"),
  paste0("- winners that improve the old Article exDQLM/DQLM forecast check where an old row exists: `", sum(old_improved, na.rm = TRUE), "/", length(old_improved), "`"),
  paste0("- cells where the current Q-DESN VB best row has lower forecast check than the confirmed exDQLM/DQLM winner: `", sum(qdesn_wins_check), "/", length(qdesn_wins_check), "`"),
  paste0("- cells eligible for narrow MCMC follow-up under the audit rule: `", sum(eligible_mcmc), "/", length(eligible_mcmc), "`"),
  "",
  "## Overlap Comparison",
  "",
  "| Family | Tau | Model | Candidate | Fit RMSE | Forecast MAE | Forecast check | Q-DESN comparator | Q-DESN fit RMSE | Q-DESN forecast MAE | Q-DESN forecast check | Check ratio vs Q-DESN | Recommendation |",
  "| --- | ---: | --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- |"
)

for (i in seq_len(nrow(comparison))) {
  row <- comparison[i, ]
  md <- c(
    md,
    paste0(
      "| ", row$family,
      " | ", fmt(row$tau, 2),
      " | ", row$model_variant,
      " | `", row$confirmed_candidate_id, "`",
      " | ", fmt(row$confirmed_fit_rmse),
      " | ", fmt(row$confirmed_forecast_mae),
      " | ", fmt(row$confirmed_forecast_check),
      " | ", row$qdesn_best_label,
      " | ", fmt(row$qdesn_best_fit_rmse),
      " | ", fmt(row$qdesn_best_forecast_mae),
      " | ", fmt(row$qdesn_best_forecast_check),
      " | ", fmt(row$ratio_forecast_check_vs_qdesn),
      " | ", row$recommendation,
      " |"
    )
  )
}

md <- c(
  md,
  "",
  "## Interpretation",
  "",
  "- The confirmed exDQLM/DQLM calibration improves the old Article exDQLM/DQLM rows in the overlap cells, especially fit RMSE for normal and gausmix cells.",
  "- The comparison does not support a broad exDQLM/DQLM MCMC launch. Only cells passing the narrow eligibility rule should be considered, and only if the article needs a matched MCMC counterpart.",
  "- Laplace left-tail behavior remains the weakest exDQLM/DQLM area in this evidence set; it should receive a targeted VB screen before any MCMC follow-up.",
  "- Article-facing tables should not consume unconfirmed exDQLM/DQLM rows from this run. Promotion should be cell-specific and tied to the CSV output above.",
  "",
  "## MCMC Recommendation",
  "",
  if (any(eligible_mcmc)) {
    paste0(
      "Narrow MCMC may be considered for: `",
      paste(paste(comparison$model_variant[eligible_mcmc], comparison$family[eligible_mcmc], comparison$tau[eligible_mcmc], sep = "/"), collapse = "`, `"),
      "`. Do not launch broad exDQLM/DQLM MCMC from this evidence alone."
    )
  } else {
    "No confirmed exDQLM/DQLM cell passes the narrow MCMC eligibility rule. Do not launch MCMC yet."
  },
  "",
  "## Regeneration Command",
  "",
  "```bash",
  "Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_overlap.R",
  "```"
)

writeLines(md, out_md)

cat("wrote_csv:", out_csv, "\n")
cat("wrote_md:", out_md, "\n")
cat("confirmed_winners:", nrow(comparison), "\n")
cat("eligible_mcmc:", sum(eligible_mcmc), "\n")
