#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(name, default = NULL) {
  flag <- paste0("--", name)
  idx <- match(flag, args)
  if (!is.na(idx) && idx < length(args)) args[[idx + 1L]] else default
}

repo_root <- normalizePath(getwd(), mustWork = TRUE)
run_root <- file.path(
  repo_root,
  "validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen"
)

default_interface <- file.path(run_root, "interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv")
default_article_summary <- "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"
default_cleanup_manifest <- file.path(run_root, "storage/prune_c13_missing_cell_fit_handoffs_20260703.csv")
default_out_csv <- file.path(repo_root, "validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_full_c13_comparison_20260703.csv")
default_out_md <- file.path(repo_root, "validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_FULL_C13_AUDIT_2026-07-03.md")

interface_path <- get_arg("interface", default_interface)
article_summary_path <- get_arg("article-summary", default_article_summary)
cleanup_manifest_path <- get_arg("cleanup-manifest", default_cleanup_manifest)
out_csv <- get_arg("out-csv", default_out_csv)
out_md <- get_arg("out-md", default_out_md)

c13_id <- "c13_trend100_season1_df0995s099"

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Required CSV does not exist: ", path, call. = FALSE)
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

require_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(label, " is missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(as.numeric(x), format = "f", digits = digits))
}

weighted_mean <- function(x, w) {
  x <- as.numeric(x)
  w <- as.numeric(w)
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

first_value <- function(x) {
  if (!length(x)) return(NA)
  x[[1L]]
}

git_value <- function(...) {
  value <- tryCatch(system2("git", c(...), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (length(value) == 0) NA_character_ else value[[1L]]
}

choose_min <- function(data, group_cols, order_cols) {
  if (!nrow(data)) return(data)
  ord <- do.call(order, data[order_cols])
  data <- data[ord, , drop = FALSE]
  key <- do.call(paste, c(data[group_cols], sep = "\r"))
  data[!duplicated(key), , drop = FALSE]
}

interface <- read_required_csv(interface_path)
article <- read_required_csv(article_summary_path)

require_columns(
  interface,
  c(
    "candidate_id", "model_variant", "model_family",
    "inference", "family", "tau", "fit_size", "forecast_lead",
    "n_origins_scored", "status", "health_gate", "fit_qtrue_rmse",
    "fit_pinball_mean", "forecast_qtrue_mae", "forecast_qtrue_rmse",
    "forecast_pinball_mean", "runtime_sec_total", "source_registry_hash_value",
    "validation_branch", "validation_commit", "run_tag", "package_version",
    "forecast_protocol", "state_update_method", "max_lead_configured",
    "origin_stride", "row_status_path"
  ),
  "shared interface"
)

if (!"row_key" %in% names(interface)) {
  interface$row_key <- sub("_status[.]csv$", "", basename(interface$row_status_path))
}
if (!"row_id" %in% names(interface)) {
  interface$row_id <- suppressWarnings(as.integer(sub("^row_0*", "", interface$row_key)))
}

require_columns(
  article,
  c(
    "model_family", "model_variant", "model_label", "inference", "family",
    "tau", "fit_qtrue_rmse", "fit_pinball_mean",
    "forecast_qtrue_mae_lead_weighted",
    "forecast_pinball_mean_lead_weighted", "validation_branch",
    "validation_commit", "article_interface_ids"
  ),
  "Article summary"
)

c13 <- subset(
  interface,
  candidate_id == c13_id &
    model_family == "exdqlm_dqlm" &
    inference == "vb" &
    fit_size == 500 &
    status == "done" &
    health_gate == "PASS"
)

if (!nrow(c13)) stop("No done/PASS c13 rows found in shared interface.", call. = FALSE)

cell_key <- paste(c13$model_variant, c13$family, c13$tau, sep = "\r")
groups <- split(c13, cell_key)

summaries <- lapply(groups, function(block) {
  data.frame(
    model_variant = first_value(block$model_variant),
    family = first_value(block$family),
    tau = as.numeric(first_value(block$tau)),
    row_id = as.integer(first_value(block$row_id)),
    row_key = first_value(block$row_key),
    candidate_id = first_value(block$candidate_id),
    n_leads = length(unique(as.integer(block$forecast_lead))),
    n_origins_scored_total = sum(as.numeric(block$n_origins_scored), na.rm = TRUE),
    fit_qtrue_rmse = as.numeric(first_value(block$fit_qtrue_rmse)),
    fit_check = as.numeric(first_value(block$fit_pinball_mean)),
    forecast_qtrue_mae = weighted_mean(block$forecast_qtrue_mae, block$n_origins_scored),
    forecast_qtrue_rmse = weighted_mean(block$forecast_qtrue_rmse, block$n_origins_scored),
    forecast_check = weighted_mean(block$forecast_pinball_mean, block$n_origins_scored),
    runtime_sec_total = as.numeric(first_value(block$runtime_sec_total)),
    source_registry_hash_value = first_value(block$source_registry_hash_value),
    validation_branch = first_value(block$validation_branch),
    validation_commit = first_value(block$validation_commit),
    run_tag = first_value(block$run_tag),
    package_version = first_value(block$package_version),
    forecast_protocol = first_value(block$forecast_protocol),
    state_update_method = first_value(block$state_update_method),
    max_lead_configured = as.integer(first_value(block$max_lead_configured)),
    origin_stride = as.integer(first_value(block$origin_stride)),
    stringsAsFactors = FALSE
  )
})

c13_summary <- do.call(rbind, summaries)
c13_summary <- c13_summary[order(c13_summary$family, c13_summary$tau, c13_summary$model_variant), , drop = FALSE]

if (nrow(c13_summary) != 18L) {
  stop("Expected 18 c13 model/family/tau cells; found ", nrow(c13_summary), call. = FALSE)
}
if (any(c13_summary$n_leads != 30L) || any(c13_summary$n_origins_scored_total != 1000L)) {
  stop("c13 summaries do not all have 30 leads and 1000 scored origin/lead targets.", call. = FALSE)
}

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

c13_summary$key <- paste(c13_summary$model_variant, c13_summary$family, c13_summary$tau, sep = "||")
qdesn_best$key <- paste(qdesn_best$family, qdesn_best$tau, sep = "||")
article_ex_best$key <- paste(article_ex_best$model_variant, article_ex_best$family, article_ex_best$tau, sep = "||")

rows <- vector("list", nrow(c13_summary))
for (i in seq_len(nrow(c13_summary))) {
  cur <- c13_summary[i, , drop = FALSE]
  q_row <- qdesn_best[qdesn_best$key == paste(cur$family, cur$tau, sep = "||"), , drop = FALSE]
  old <- article_ex_best[article_ex_best$key == cur$key, , drop = FALSE]
  if (nrow(q_row) != 1L) stop("Expected one Q-DESN comparator for ", cur$family, " tau=", cur$tau, call. = FALSE)
  if (nrow(old) != 1L) stop("Expected one old Article baseline for ", cur$key, call. = FALSE)

  fit_ratio_qdesn <- cur$fit_qtrue_rmse / q_row$fit_qtrue_rmse
  mae_ratio_qdesn <- cur$forecast_qtrue_mae / q_row$forecast_qtrue_mae_lead_weighted
  check_ratio_qdesn <- cur$forecast_check / q_row$forecast_pinball_mean_lead_weighted
  old_fit_ratio <- cur$fit_qtrue_rmse / old$fit_qtrue_rmse
  old_mae_ratio <- cur$forecast_qtrue_mae / old$forecast_qtrue_mae_lead_weighted
  old_check_ratio <- cur$forecast_check / old$forecast_pinball_mean_lead_weighted

  recommendation <- "promote as coherent current c13 VB baseline; no MCMC"
  if (cur$family == "laplace" && cur$tau <= 0.05) {
    recommendation <- "keep as current evidence but run targeted laplace-left-tail VB challenger screen before MCMC"
  } else if (isTRUE(check_ratio_qdesn <= 1.05 && mae_ratio_qdesn <= 1.20 && fit_ratio_qdesn <= 1.25)) {
    recommendation <- "eligible for narrow MCMC follow-up if a matched MCMC counterpart is required"
  } else if (isTRUE(old_check_ratio > 1.02 || check_ratio_qdesn > 1.10)) {
    recommendation <- "promote only with evidence-status flag; consider small c11/c12 challenger screen"
  }

  rows[[i]] <- data.frame(
    model_variant = cur$model_variant,
    family = cur$family,
    tau = cur$tau,
    row_id = cur$row_id,
    candidate_id = cur$candidate_id,
    fit_qtrue_rmse = cur$fit_qtrue_rmse,
    fit_check = cur$fit_check,
    forecast_qtrue_mae = cur$forecast_qtrue_mae,
    forecast_check = cur$forecast_check,
    qdesn_best_label = gsub("--", "-", q_row$model_label, fixed = TRUE),
    qdesn_best_fit_qtrue_rmse = q_row$fit_qtrue_rmse,
    qdesn_best_fit_check = q_row$fit_pinball_mean,
    qdesn_best_forecast_qtrue_mae = q_row$forecast_qtrue_mae_lead_weighted,
    qdesn_best_forecast_check = q_row$forecast_pinball_mean_lead_weighted,
    ratio_fit_rmse_vs_qdesn = fit_ratio_qdesn,
    ratio_forecast_mae_vs_qdesn = mae_ratio_qdesn,
    ratio_forecast_check_vs_qdesn = check_ratio_qdesn,
    old_article_fit_qtrue_rmse = old$fit_qtrue_rmse,
    old_article_forecast_qtrue_mae = old$forecast_qtrue_mae_lead_weighted,
    old_article_forecast_check = old$forecast_pinball_mean_lead_weighted,
    ratio_fit_rmse_vs_old_article = old_fit_ratio,
    ratio_forecast_mae_vs_old_article = old_mae_ratio,
    ratio_forecast_check_vs_old_article = old_check_ratio,
    improves_old_fit_rmse = old_fit_ratio < 1,
    improves_old_forecast_mae = old_mae_ratio < 1,
    improves_old_forecast_check = old_check_ratio < 1,
    qdesn_beats_c13_fit_rmse = q_row$fit_qtrue_rmse < cur$fit_qtrue_rmse,
    qdesn_beats_c13_forecast_mae = q_row$forecast_qtrue_mae_lead_weighted < cur$forecast_qtrue_mae,
    qdesn_beats_c13_forecast_check = q_row$forecast_pinball_mean_lead_weighted < cur$forecast_check,
    n_leads = cur$n_leads,
    n_origins_scored_total = cur$n_origins_scored_total,
    runtime_sec_total = cur$runtime_sec_total,
    source_registry_hash_value = cur$source_registry_hash_value,
    validation_branch = cur$validation_branch,
    validation_commit = cur$validation_commit,
    run_tag = cur$run_tag,
    package_version = cur$package_version,
    forecast_protocol = cur$forecast_protocol,
    state_update_method = cur$state_update_method,
    max_lead_configured = cur$max_lead_configured,
    origin_stride = cur$origin_stride,
    recommendation = recommendation,
    old_article_validation_commit = old$validation_commit,
    old_article_interface_ids = old$article_interface_ids,
    stringsAsFactors = FALSE
  )
}

comparison <- do.call(rbind, rows)
comparison <- comparison[order(comparison$family, comparison$tau, comparison$model_variant), , drop = FALSE]

cleanup <- if (file.exists(cleanup_manifest_path)) read.csv(cleanup_manifest_path, check.names = FALSE, stringsAsFactors = FALSE) else data.frame()
cleanup_rows <- nrow(cleanup)
cleanup_gib <- if (nrow(cleanup) && "fit_bytes_pruned" %in% names(cleanup)) sum(as.numeric(cleanup$fit_bytes_pruned), na.rm = TRUE) / 1024^3 else NA_real_

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(comparison, out_csv, row.names = FALSE, na = "")

repo_branch <- git_value("rev-parse", "--abbrev-ref", "HEAD")
repo_head <- git_value("rev-parse", "HEAD")
repo_subject <- git_value("log", "-1", "--format=%s")

old_check_improved <- comparison$improves_old_forecast_check
old_fit_improved <- comparison$improves_old_fit_rmse
qdesn_wins_check <- comparison$qdesn_beats_c13_forecast_check
eligible_mcmc <- grepl("^eligible", comparison$recommendation)
challenger <- grepl("challenger|laplace-left-tail", comparison$recommendation)

md <- c(
  "# exDQLM/DQLM and Q-DESN Full c13 VB Audit",
  "",
  "Date: 2026-07-03",
  "",
  "## Scope",
  "",
  "This audit evaluates the current c13 exDQLM/DQLM VB evidence after the missing-cell fit+forecast launch. It covers all 18 exDQLM/DQLM VB model/family/tau cells at fit size 500 and compares them against the current Article-facing Q-DESN VB rows and the older Article exDQLM/DQLM baseline rows.",
  "",
  "## Inputs",
  "",
  paste0("- validation worktree: `", repo_root, "`"),
  paste0("- validation branch: `", repo_branch, "`"),
  paste0("- validation HEAD at audit generation: `", repo_head, "`"),
  paste0("- validation HEAD subject: `", repo_subject, "`"),
  paste0("- shared interface: `", interface_path, "`"),
  paste0("- Article-facing summary read-only input: `", article_summary_path, "`"),
  paste0("- cleanup manifest: `", cleanup_manifest_path, "`"),
  paste0("- reproducible CSV output: `", out_csv, "`"),
  "",
  "## Evidence Counts",
  "",
  paste0("- current c13 done/PASS cells: `", nrow(comparison), "/18`"),
  paste0("- c13 lead rows in interface: `", nrow(c13), "`"),
  paste0("- cells where c13 improves old Article fit RMSE: `", sum(old_fit_improved), "/", length(old_fit_improved), "`"),
  paste0("- cells where c13 improves old Article forecast check: `", sum(old_check_improved), "/", length(old_check_improved), "`"),
  paste0("- cells where Q-DESN VB still has lower forecast check than c13: `", sum(qdesn_wins_check), "/", length(qdesn_wins_check), "`"),
  paste0("- cells eligible for narrow MCMC follow-up under this audit rule: `", sum(eligible_mcmc), "/", length(eligible_mcmc), "`"),
  paste0("- cells flagged for challenger screening before MCMC: `", sum(challenger), "/", length(challenger), "`"),
  paste0("- newly generated fit handoffs pruned: `", cleanup_rows, "`"),
  paste0("- newly generated fit handoff GiB pruned: `", fmt(cleanup_gib, 3), "`"),
  "",
  "## Full c13 Comparison",
  "",
  "| Family | Tau | Model | Fit RMSE | Forecast MAE | Forecast check | Old forecast check ratio | Q-DESN forecast check ratio | Recommendation |",
  "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |"
)

for (i in seq_len(nrow(comparison))) {
  row <- comparison[i, ]
  md <- c(md, paste0(
    "| ", row$family,
    " | ", fmt(row$tau, 2),
    " | ", row$model_variant,
    " | ", fmt(row$fit_qtrue_rmse),
    " | ", fmt(row$forecast_qtrue_mae),
    " | ", fmt(row$forecast_check),
    " | ", fmt(row$ratio_forecast_check_vs_old_article),
    " | ", fmt(row$ratio_forecast_check_vs_qdesn),
    " | ", row$recommendation,
    " |"
  ))
}

md <- c(
  md,
  "",
  "## Interpretation",
  "",
  "- The c13 specification now gives current, done/PASS VB evidence for every exDQLM/DQLM model/family/tau cell in the fit-size-500 validation table.",
  "- c13 dramatically improves old Article fit RMSE in every exDQLM/DQLM VB cell, but it does not improve old Article forecast check in every cell.",
  "- Q-DESN remains the stronger forecast-check row in a majority of cells, so this audit does not justify broad exDQLM/DQLM MCMC.",
  "- Article promotion is technically possible only with an explicit evidence-status/provenance update; silently mixing old d0759413 rows with current c13 rows is no longer acceptable.",
  "- Cells flagged for challenger screening should be explored with the predeclared small c11/c12 challenger set before any MCMC decision.",
  "",
  "## MCMC Recommendation",
  "",
  if (any(eligible_mcmc)) {
    paste0(
      "Narrow MCMC may be considered only after Article-facing VB promotion/audit for: `",
      paste(paste(comparison$model_variant[eligible_mcmc], comparison$family[eligible_mcmc], comparison$tau[eligible_mcmc], sep = "/"), collapse = "`, `"),
      "`. Do not launch broad exDQLM/DQLM MCMC."
    )
  } else {
    "No c13 cell passes the narrow MCMC eligibility rule. Do not launch exDQLM/DQLM MCMC."
  },
  "",
  "## Next Recommended Action",
  "",
  "Build a cell-level Article promotion override for the current c13 VB evidence only after adding explicit evidence-status fields, or run the small c11/c12 challenger screen for flagged cells first. The stronger validation-first path is to run the challenger screen before changing Article tables.",
  "",
  "## Regeneration Command",
  "",
  "```bash",
  "Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_full_c13.R",
  "```"
)

writeLines(md, out_md)

cat("wrote_csv:", out_csv, "\n")
cat("wrote_md:", out_md, "\n")
cat("current_c13_cells:", nrow(comparison), "\n")
cat("eligible_mcmc:", sum(eligible_mcmc), "\n")
cat("challenger_flags:", sum(challenger), "\n")
