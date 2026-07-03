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
default_c13_cleanup <- file.path(run_root, "storage/prune_c13_missing_cell_fit_handoffs_20260703.csv")
default_challenger_cleanup <- file.path(run_root, "storage/prune_c11_c12_challenger_fit_handoffs_20260703.csv")
default_health_storage <- file.path(run_root, "storage/storage_audit.csv")
default_out_csv <- file.path(repo_root, "validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv")
default_out_md <- file.path(repo_root, "validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_CURRENT_BEST_AUDIT_2026-07-03.md")

interface_path <- get_arg("interface", default_interface)
article_summary_path <- get_arg("article-summary", default_article_summary)
c13_cleanup_path <- get_arg("c13-cleanup", default_c13_cleanup)
challenger_cleanup_path <- get_arg("challenger-cleanup", default_challenger_cleanup)
health_storage_path <- get_arg("health-storage", default_health_storage)
out_csv <- get_arg("out-csv", default_out_csv)
out_md <- get_arg("out-md", default_out_md)

candidate_ids <- c(
  "c11_trend100_season1_df0995",
  "c12_trend100_season10_df0995",
  "c13_trend100_season1_df0995s099"
)

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Required CSV does not exist: ", path, call. = FALSE)
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

read_optional_csv <- function(path) {
  if (!file.exists(path)) return(data.frame())
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

cleanup_bytes <- function(data) {
  if (!nrow(data)) return(0)
  for (nm in c("fit_bytes_pruned", "bytes_removed", "before_bytes")) {
    if (nm %in% names(data)) return(sum(as.numeric(data[[nm]]), na.rm = TRUE))
  }
  0
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

candidate_rows <- subset(
  interface,
  candidate_id %in% candidate_ids &
    model_family == "exdqlm_dqlm" &
    inference == "vb" &
    fit_size == 500 &
    status == "done" &
    health_gate == "PASS"
)

if (!nrow(candidate_rows)) {
  stop("No done/PASS c11/c12/c13 rows found in shared interface.", call. = FALSE)
}

candidate_key <- paste(candidate_rows$model_variant, candidate_rows$family, candidate_rows$tau, candidate_rows$candidate_id, sep = "\r")
candidate_groups <- split(candidate_rows, candidate_key)

candidate_summaries <- lapply(candidate_groups, function(block) {
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

candidate_summary <- do.call(rbind, candidate_summaries)
candidate_summary <- candidate_summary[order(
  candidate_summary$model_variant,
  candidate_summary$family,
  candidate_summary$tau,
  candidate_summary$forecast_check,
  candidate_summary$forecast_qtrue_mae,
  candidate_summary$fit_qtrue_rmse
), , drop = FALSE]

cell_cols <- c("model_variant", "family", "tau")
cell_key <- do.call(paste, c(candidate_summary[cell_cols], sep = "\r"))
best <- candidate_summary[!duplicated(cell_key), , drop = FALSE]
best <- best[order(best$family, best$tau, best$model_variant), , drop = FALSE]

if (nrow(best) != 18L) {
  stop("Expected 18 current-best model/family/tau cells; found ", nrow(best), call. = FALSE)
}
if (any(best$n_leads != 30L) || any(best$n_origins_scored_total != 1000L)) {
  stop("Current-best summaries do not all have 30 leads and 1000 scored origin/lead targets.", call. = FALSE)
}

availability <- aggregate(
  candidate_id ~ model_variant + family + tau,
  data = candidate_summary,
  FUN = function(x) paste(sort(unique(x)), collapse = ";")
)
names(availability)[names(availability) == "candidate_id"] <- "available_candidate_ids"
best <- merge(best, availability, by = c("model_variant", "family", "tau"), all.x = TRUE, sort = FALSE)
best <- best[order(best$family, best$tau, best$model_variant), , drop = FALSE]

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

qdesn_best$key <- paste(qdesn_best$family, qdesn_best$tau, sep = "||")
article_ex_best$key <- paste(article_ex_best$model_variant, article_ex_best$family, article_ex_best$tau, sep = "||")

rows <- vector("list", nrow(best))
for (i in seq_len(nrow(best))) {
  cur <- best[i, , drop = FALSE]
  q_row <- qdesn_best[qdesn_best$key == paste(cur$family, cur$tau, sep = "||"), , drop = FALSE]
  old <- article_ex_best[article_ex_best$key == paste(cur$model_variant, cur$family, cur$tau, sep = "||"), , drop = FALSE]
  if (nrow(q_row) != 1L) stop("Expected one Q-DESN comparator for ", cur$family, " tau=", cur$tau, call. = FALSE)
  if (nrow(old) != 1L) stop("Expected one Article exDQLM/DQLM comparator for ", cur$model_variant, "/", cur$family, "/", cur$tau, call. = FALSE)

  fit_ratio_qdesn <- cur$fit_qtrue_rmse / q_row$fit_qtrue_rmse
  mae_ratio_qdesn <- cur$forecast_qtrue_mae / q_row$forecast_qtrue_mae_lead_weighted
  check_ratio_qdesn <- cur$forecast_check / q_row$forecast_pinball_mean_lead_weighted
  old_fit_ratio <- cur$fit_qtrue_rmse / old$fit_qtrue_rmse
  old_mae_ratio <- cur$forecast_qtrue_mae / old$forecast_qtrue_mae_lead_weighted
  old_check_ratio <- cur$forecast_check / old$forecast_pinball_mean_lead_weighted

  recommendation <- "promote VB current-best evidence; no broad MCMC"
  if (isTRUE(check_ratio_qdesn <= 1.05 && mae_ratio_qdesn <= 1.20 && fit_ratio_qdesn <= 1.25)) {
    recommendation <- "eligible for narrow MCMC follow-up if a matched MCMC row is required"
  } else if (isTRUE(check_ratio_qdesn > 1.50 || mae_ratio_qdesn > 1.50)) {
    recommendation <- "keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger"
  }

  rows[[i]] <- data.frame(
    model_variant = cur$model_variant,
    family = cur$family,
    tau = cur$tau,
    row_id = cur$row_id,
    candidate_id = cur$candidate_id,
    available_candidate_ids = cur$available_candidate_ids,
    fit_qtrue_rmse = cur$fit_qtrue_rmse,
    fit_check = cur$fit_check,
    forecast_qtrue_mae = cur$forecast_qtrue_mae,
    forecast_qtrue_rmse = cur$forecast_qtrue_rmse,
    forecast_check = cur$forecast_check,
    qdesn_best_label = gsub("--", "-", q_row$model_label, fixed = TRUE),
    qdesn_best_fit_qtrue_rmse = q_row$fit_qtrue_rmse,
    qdesn_best_fit_check = q_row$fit_pinball_mean,
    qdesn_best_forecast_qtrue_mae = q_row$forecast_qtrue_mae_lead_weighted,
    qdesn_best_forecast_check = q_row$forecast_pinball_mean_lead_weighted,
    ratio_fit_rmse_vs_qdesn = fit_ratio_qdesn,
    ratio_forecast_mae_vs_qdesn = mae_ratio_qdesn,
    ratio_forecast_check_vs_qdesn = check_ratio_qdesn,
    article_ex_fit_qtrue_rmse = old$fit_qtrue_rmse,
    article_ex_forecast_qtrue_mae = old$forecast_qtrue_mae_lead_weighted,
    article_ex_forecast_check = old$forecast_pinball_mean_lead_weighted,
    ratio_fit_rmse_vs_article_ex = old_fit_ratio,
    ratio_forecast_mae_vs_article_ex = old_mae_ratio,
    ratio_forecast_check_vs_article_ex = old_check_ratio,
    improves_article_ex_fit_rmse = old_fit_ratio < 1,
    improves_article_ex_forecast_mae = old_mae_ratio < 1,
    improves_article_ex_forecast_check = old_check_ratio < 1,
    qdesn_beats_current_best_fit_rmse = q_row$fit_qtrue_rmse < cur$fit_qtrue_rmse,
    qdesn_beats_current_best_forecast_mae = q_row$forecast_qtrue_mae_lead_weighted < cur$forecast_qtrue_mae,
    qdesn_beats_current_best_forecast_check = q_row$forecast_pinball_mean_lead_weighted < cur$forecast_check,
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
    article_ex_validation_commit = old$validation_commit,
    article_ex_interface_ids = old$article_interface_ids,
    stringsAsFactors = FALSE
  )
}

comparison <- do.call(rbind, rows)
comparison <- comparison[order(comparison$family, comparison$tau, comparison$model_variant), , drop = FALSE]

c13_cleanup <- read_optional_csv(c13_cleanup_path)
challenger_cleanup <- read_optional_csv(challenger_cleanup_path)
storage_audit <- read_optional_csv(health_storage_path)
storage_status <- if (nrow(storage_audit) && "status" %in% names(storage_audit)) first_value(storage_audit$status) else NA_character_
storage_files <- if (nrow(storage_audit) && "n_files" %in% names(storage_audit)) first_value(storage_audit$n_files) else NA
storage_bytes <- if (nrow(storage_audit) && "total_bytes" %in% names(storage_audit)) first_value(storage_audit$total_bytes) else NA
forbidden_payloads <- if (nrow(storage_audit) && "forbidden_payloads" %in% names(storage_audit)) first_value(storage_audit$forbidden_payloads) else NA

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(comparison, out_csv, row.names = FALSE, na = "")

repo_branch <- git_value("rev-parse", "--abbrev-ref", "HEAD")
repo_head <- git_value("rev-parse", "HEAD")
repo_subject <- git_value("log", "-1", "--format=%s")

selected_counts <- sort(table(comparison$candidate_id), decreasing = TRUE)
qdesn_wins_check <- comparison$qdesn_beats_current_best_forecast_check
qdesn_wins_mae <- comparison$qdesn_beats_current_best_forecast_mae
eligible_mcmc <- grepl("^eligible", comparison$recommendation)
avoid_mcmc <- grepl("^keep as documented", comparison$recommendation)

total_cleanup_bytes <- cleanup_bytes(c13_cleanup) + cleanup_bytes(challenger_cleanup)

md <- c(
  "# exDQLM/DQLM and Q-DESN Current-Best VB Audit",
  "",
  "Date: 2026-07-03",
  "",
  "## Scope",
  "",
  "This audit selects the current best exDQLM/DQLM VB row for each model/family/tau cell from the completed c11/c12/c13 targeted screen. Selection is by lead-weighted rolling-origin forecast check loss, with forecast MAE and fit RMSE used only as tie breakers.",
  "",
  "## Inputs",
  "",
  paste0("- validation worktree: `", repo_root, "`"),
  paste0("- validation branch: `", repo_branch, "`"),
  paste0("- validation HEAD at audit generation: `", repo_head, "`"),
  paste0("- validation HEAD subject: `", repo_subject, "`"),
  paste0("- shared interface: `", interface_path, "`"),
  paste0("- Article-facing summary read-only input: `", article_summary_path, "`"),
  paste0("- c13 cleanup manifest: `", c13_cleanup_path, "`"),
  paste0("- c11/c12 cleanup manifest: `", challenger_cleanup_path, "`"),
  paste0("- storage audit: `", health_storage_path, "`"),
  paste0("- reproducible CSV output: `", out_csv, "`"),
  "",
  "## Evidence Counts",
  "",
  paste0("- current-best done/PASS cells: `", nrow(comparison), "/18`"),
  paste0("- completed c11/c12/c13 lead rows in interface: `", nrow(candidate_rows), "`"),
  paste0("- selected candidates: `", paste(paste(names(selected_counts), as.integer(selected_counts), sep = "="), collapse = ", "), "`"),
  paste0("- cells where Q-DESN VB still has lower forecast check: `", sum(qdesn_wins_check), "/", length(qdesn_wins_check), "`"),
  paste0("- cells where Q-DESN VB still has lower forecast MAE: `", sum(qdesn_wins_mae), "/", length(qdesn_wins_mae), "`"),
  paste0("- cells eligible for narrow MCMC follow-up under this audit rule: `", sum(eligible_mcmc), "/", length(eligible_mcmc), "`"),
  paste0("- cells where MCMC is not recommended without stronger VB evidence: `", sum(avoid_mcmc), "/", length(avoid_mcmc), "`"),
  paste0("- storage audit status: `", storage_status, "`"),
  paste0("- storage audit files/bytes: `", storage_files, "` / `", storage_bytes, "`"),
  paste0("- forbidden payloads in storage audit: `", forbidden_payloads, "`"),
  paste0("- fit handoff GiB pruned across c13 plus c11/c12: `", fmt(total_cleanup_bytes / 1024^3, 3), "`"),
  "",
  "## Current-Best Comparison",
  "",
  "| Family | Tau | Model | Winner candidate | Fit RMSE | Forecast MAE | Forecast check | Q-DESN forecast check ratio | Recommendation |",
  "| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | --- |"
)

for (i in seq_len(nrow(comparison))) {
  row <- comparison[i, ]
  md <- c(md, paste0(
    "| ", row$family,
    " | ", fmt(row$tau, 2),
    " | ", row$model_variant,
    " | ", row$candidate_id,
    " | ", fmt(row$fit_qtrue_rmse),
    " | ", fmt(row$forecast_qtrue_mae),
    " | ", fmt(row$forecast_check),
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
  "- The targeted c11/c12/c13 VB screen now gives complete done/PASS exDQLM/DQLM evidence for all 18 fit-size-500 model/family/tau cells.",
  "- The current-best rows should replace any mixed or stale exDQLM/DQLM VB evidence in downstream Article-facing comparison tables when those tables are regenerated.",
  "- Q-DESN remains competitive or dominant in many cells, so this audit still does not support broad exDQLM/DQLM MCMC as the next default action.",
  "- Narrow exDQLM/DQLM MCMC should be considered only for the cells explicitly marked eligible after Article-facing VB promotion is stable.",
  "- Storage-light policy is preserved: successful fit-object handoffs from the c13 and c11/c12 targeted launches were pruned after forecast summaries and lead metrics were written.",
  "",
  "## Next Recommended Action",
  "",
  "Use the current-best CSV as the validation-side source of truth for an Article table refresh, then decide whether a small matched MCMC follow-up is worth the compute for the eligible cells only.",
  "",
  "## Regeneration Command",
  "",
  "```bash",
  "Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_current_best.R",
  "```"
)

writeLines(md, out_md)

cat("wrote_csv:", out_csv, "\n")
cat("wrote_md:", out_md, "\n")
cat("current_best_cells:", nrow(comparison), "\n")
cat("eligible_mcmc:", sum(eligible_mcmc), "\n")
cat("avoid_mcmc_without_stronger_vb:", sum(avoid_mcmc), "\n")
