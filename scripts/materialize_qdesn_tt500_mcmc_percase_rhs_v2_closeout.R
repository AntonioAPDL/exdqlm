#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
})

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)

date_stamp <- "20260726"
promotion_id <- paste0("qdesn_tt500_mcmc_percase_rhs_v2_closeout_", date_stamp)
promotion_root <- file.path("validation", "fitforecast_v2", "promotions", promotion_id)
stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2"
run_tag <- "qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c"
campaign_stamp <- "20260725-203156__git-7df241c"
report_root <- file.path("reports", "qdesn_mcmc_validation", stage, run_tag, campaign_stamp)
results_root <- file.path("results", "qdesn_mcmc_validation", stage, run_tag, campaign_stamp)
fit_path <- file.path(report_root, "tables", "campaign_fit_summary.csv")
progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
completion_path <- file.path(report_root, "manifest", "campaign_completed.json")
prelaunch_root <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725"
)
ledger_path <- file.path(
  prelaunch_root,
  "qdesn_tt500_mcmc_percase_rhs_v2_current_percase_ledger_20260725.csv"
)
target_specs_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_target_spec_ids.csv"
)

read_csv <- function(path) {
  utils::read.csv(normalizePath(path, winslash = "/", mustWork = TRUE),
                  check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) {
  unname(tools::sha256sum(normalizePath(path, winslash = "/", mustWork = TRUE)))
}
num <- function(x) suppressWarnings(as.numeric(x))
bool <- function(x) toupper(trimws(as.character(x))) == "TRUE"
git_value <- function(args) {
  out <- system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE)
  if (length(out)) out[[1L]] else NA_character_
}

required <- c(fit_path, progress_path, completion_path, ledger_path, target_specs_path)
invisible(lapply(required, normalizePath, winslash = "/", mustWork = TRUE))

fit <- read_csv(fit_path)
progress <- read_csv(progress_path)
ledger <- read_csv(ledger_path)
target_specs <- read_csv(target_specs_path)
completion <- jsonlite::read_json(completion_path)

if (nrow(fit) != 90L || nrow(progress) != 90L || nrow(target_specs) != 90L) {
  stop("Closeout requires exactly 90 fits, progress rows, and target specifications.",
       call. = FALSE)
}
if (!all(progress$root_status == "SUCCESS")) {
  stop("Closeout requires every root to have SUCCESS status.", call. = FALSE)
}
if (as.integer(completion$n_roots) != 90L || as.integer(completion$n_fits) != 90L) {
  stop("Campaign completion manifest does not certify 90 roots and 90 fits.",
       call. = FALSE)
}

extract_h1000 <- function(path) {
  hpath <- sub("forecast_lead_metrics[.]csv$", "forecast_horizon_summary.csv",
               as.character(path))
  h <- read_csv(hpath)
  h <- h[num(h$horizon) == 1000, , drop = FALSE]
  if (nrow(h) != 1L) {
    stop(sprintf("Expected one H=1000 row in %s.", hpath), call. = FALSE)
  }
  data.frame(
    root_id = h$root_id,
    forecast_qtrue_mae_H1000 = num(h$qtrue_mae),
    forecast_qtrue_rmse_H1000 = num(h$qtrue_rmse),
    forecast_check_loss_H1000 = num(h$pinball_tau),
    forecast_horizon_summary_path = normalizePath(hpath, winslash = "/",
                                                   mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}
h1000 <- do.call(rbind, lapply(fit$forecast_lead_metrics_path, extract_h1000))
fit <- merge(fit, h1000, by = "root_id", all.x = TRUE, sort = FALSE)
fit$likelihood_target <- as.character(fit$model)
fit$fit_qtrue_rmse <- num(fit$train_qtrue_rmse)
fit$fit_qtrue_mae <- num(fit$train_qtrue_mae)
fit$fit_check_loss <- num(fit$train_pinball_tau)
fit$comparison_eligible_closeout <- fit$status == "SUCCESS" &
  fit$signoff_grade %in% c("PASS", "WARN") &
  bool(fit$finite_ok) & bool(fit$domain_ok)

benchmark_cols <- c(
  "family", "tau", "likelihood_target", "candidate_id", "spec_id",
  "source_promotion_id", "run_tag", "signoff_grade", "status",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000", "benchmark_model_variant",
  "benchmark_candidate_id", "benchmark_fit_qtrue_rmse",
  "benchmark_forecast_qtrue_mae_H1000",
  "benchmark_forecast_check_loss_H1000"
)
missing_cols <- setdiff(benchmark_cols, names(ledger))
if (length(missing_cols)) {
  stop(sprintf("Prelaunch ledger is missing: %s",
               paste(missing_cols, collapse = ", ")), call. = FALSE)
}
old <- ledger[, benchmark_cols]
names(old)[names(old) == "candidate_id"] <- "current_candidate_id"
names(old)[names(old) == "spec_id"] <- "current_spec_id"
names(old)[names(old) == "source_promotion_id"] <- "current_source_promotion_id"
names(old)[names(old) == "run_tag"] <- "current_run_tag"
names(old)[names(old) == "signoff_grade"] <- "current_signoff_grade"
names(old)[names(old) == "status"] <- "current_status"
names(old)[names(old) == "fit_qtrue_rmse"] <- "current_fit_qtrue_rmse"
names(old)[names(old) == "forecast_qtrue_mae_H1000"] <-
  "current_forecast_qtrue_mae_H1000"
names(old)[names(old) == "forecast_check_loss_H1000"] <-
  "current_forecast_check_loss_H1000"

candidates <- merge(fit, old, by = c("family", "tau", "likelihood_target"),
                    all.x = TRUE, sort = FALSE)
candidates$fit_ratio_to_dqlm <- candidates$fit_qtrue_rmse /
  num(candidates$benchmark_fit_qtrue_rmse)
candidates$forecast_mae_ratio_to_dqlm <- candidates$forecast_qtrue_mae_H1000 /
  num(candidates$benchmark_forecast_qtrue_mae_H1000)
candidates$check_loss_ratio_to_dqlm <- candidates$forecast_check_loss_H1000 /
  num(candidates$benchmark_forecast_check_loss_H1000)
candidates$worst_ratio_to_dqlm <- pmax(
  candidates$fit_ratio_to_dqlm,
  candidates$forecast_mae_ratio_to_dqlm,
  candidates$check_loss_ratio_to_dqlm
)
candidates$all_primary_better_than_dqlm <-
  candidates$fit_ratio_to_dqlm < 1 &
  candidates$forecast_mae_ratio_to_dqlm < 1 &
  candidates$check_loss_ratio_to_dqlm < 1
candidates$fit_ratio_to_current <- candidates$fit_qtrue_rmse /
  num(candidates$current_fit_qtrue_rmse)
candidates$forecast_mae_ratio_to_current <-
  candidates$forecast_qtrue_mae_H1000 /
  num(candidates$current_forecast_qtrue_mae_H1000)
candidates$check_loss_ratio_to_current <-
  candidates$forecast_check_loss_H1000 /
  num(candidates$current_forecast_check_loss_H1000)
candidates$current_worst_ratio_to_dqlm <- pmax(
  num(candidates$current_fit_qtrue_rmse) /
    num(candidates$benchmark_fit_qtrue_rmse),
  num(candidates$current_forecast_qtrue_mae_H1000) /
    num(candidates$benchmark_forecast_qtrue_mae_H1000),
  num(candidates$current_forecast_check_loss_H1000) /
    num(candidates$benchmark_forecast_check_loss_H1000)
)
candidates$relative_worst_improvement <-
  candidates$current_worst_ratio_to_dqlm - candidates$worst_ratio_to_dqlm

cell_key <- interaction(candidates$family, candidates$tau,
                        candidates$likelihood_target, drop = TRUE)
groups <- split(candidates, cell_key)
select_best <- function(x, eligible_only = FALSE) {
  if (eligible_only) {
    x <- x[x$comparison_eligible_closeout, , drop = FALSE]
  }
  if (!nrow(x)) return(x)
  grade <- match(x$signoff_grade, c("PASS", "WARN", "FAIL"))
  x[order(x$worst_ratio_to_dqlm,
          x$forecast_mae_ratio_to_dqlm,
          x$fit_ratio_to_dqlm,
          grade), , drop = FALSE][1L, , drop = FALSE]
}
best_any <- do.call(rbind, lapply(groups, select_best, eligible_only = FALSE))
best_eligible <- do.call(rbind, lapply(groups, select_best, eligible_only = TRUE))
if (nrow(best_any) != 18L || nrow(best_eligible) != 14L) {
  stop("Expected 18 status-agnostic and 14 comparison-eligible cell winners.",
       call. = FALSE)
}

best_eligible$promotion_rule <- ifelse(
  best_eligible$current_signoff_grade == "FAIL" &
    best_eligible$worst_ratio_to_dqlm <=
      best_eligible$current_worst_ratio_to_dqlm * 1.01,
  "replace_failed_current_with_eligible_near_equivalent",
  ifelse(
    best_eligible$worst_ratio_to_dqlm <
      best_eligible$current_worst_ratio_to_dqlm * 0.995,
    "replace_current_on_material_minimax_improvement",
    "retain_current"
  )
)
best_eligible$promote_over_current <-
  best_eligible$promotion_rule != "retain_current"

promotions <- best_eligible[best_eligible$promote_over_current, , drop = FALSE]
all_primary <- candidates[
  candidates$all_primary_better_than_dqlm &
    candidates$comparison_eligible_closeout,
  , drop = FALSE
]
diagnostic_all_primary <- candidates[
  candidates$all_primary_better_than_dqlm &
    !candidates$comparison_eligible_closeout,
  , drop = FALSE
]

unresolved <- best_eligible
unresolved$bottleneck_metric <- apply(
  unresolved[, c("fit_ratio_to_dqlm", "forecast_mae_ratio_to_dqlm",
                 "check_loss_ratio_to_dqlm")],
  1L,
  function(z) c("fit_rmse", "forecast_mae", "forecast_check_loss")[which.max(z)]
)
unresolved <- unresolved[
  !unresolved$all_primary_better_than_dqlm, , drop = FALSE
]

target_confirmation <- best_any[
  best_any$family == "normal" &
    abs(num(best_any$tau) - 0.05) < 1e-8 &
    best_any$likelihood_target == "exal",
  , drop = FALSE
]
if (nrow(target_confirmation) != 1L ||
    target_confirmation$screening_profile_id != "mcvbc_060_exal" ||
    target_confirmation$signoff_grade != "FAIL" ||
    !target_confirmation$all_primary_better_than_dqlm) {
  stop("The targeted confirmation candidate is not the audited mcvbc_060_exal row.",
       call. = FALSE)
}
target_confirmation$followup_stage <-
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_normal005_exal_multiseed_v1"
target_confirmation$followup_reason <-
  "all-primary metric win blocked only by high autocorrelation"
target_confirmation$required_seed_reps <- 4L
target_confirmation$promotion_gate <-
  "at least 2 of 4 chains PASS/WARN; selected chain PASS/WARN; all three ratios remain below 1"
target_confirmation$launch_status <- "prepared_not_launched"

heavy <- list.files(results_root, recursive = TRUE, full.names = TRUE)
heavy <- heavy[grepl("[.](rds|rda|RData)$", heavy, ignore.case = TRUE)]
storage_audit <- if (length(heavy)) {
  info <- file.info(heavy)
  data.frame(
    path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(info$size),
    classification = "unexpected_binary_or_heavy",
    action = "defer_no_cleanup_performed",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(
    path = character(), bytes = numeric(), classification = character(),
    action = character(), stringsAsFactors = FALSE
  )
}

summary <- data.frame(
  promotion_id = promotion_id,
  run_tag = run_tag,
  n_planned = 90L,
  n_success = sum(progress$root_status == "SUCCESS"),
  n_pass = sum(fit$signoff_grade == "PASS"),
  n_warn = sum(fit$signoff_grade == "WARN"),
  n_fail = sum(fit$signoff_grade == "FAIL"),
  n_comparison_eligible = sum(candidates$comparison_eligible_closeout),
  n_all_primary_candidate_rows = nrow(all_primary),
  n_all_primary_eligible_cells = length(unique(paste(
    all_primary$family, all_primary$tau, all_primary$likelihood_target
  ))),
  n_current_ledger_promotions = nrow(promotions),
  n_unresolved_eligible_cells = nrow(unresolved),
  n_targeted_confirmations = nrow(target_confirmation),
  n_heavy_binary_artifacts = nrow(storage_audit),
  article_update_ready = FALSE,
  article_update_reason =
    "validation winners must be frozen after targeted normal-0.05 exAL confirmation",
  stringsAsFactors = FALSE
)

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
paths <- c(
  candidates = write_csv(candidates, file.path(
    promotion_root, paste0(promotion_id, "_all_candidates.csv"))),
  best_any = write_csv(best_any, file.path(
    promotion_root, paste0(promotion_id, "_status_agnostic_cell_winners.csv"))),
  best_eligible = write_csv(best_eligible, file.path(
    promotion_root, paste0(promotion_id, "_eligible_cell_winners.csv"))),
  promotions = write_csv(promotions, file.path(
    promotion_root, paste0(promotion_id, "_current_ledger_promotions.csv"))),
  all_primary = write_csv(all_primary, file.path(
    promotion_root, paste0(promotion_id, "_all_primary_eligible_candidates.csv"))),
  diagnostic = write_csv(diagnostic_all_primary, file.path(
    promotion_root, paste0(promotion_id, "_diagnostic_all_primary_candidates.csv"))),
  unresolved = write_csv(unresolved, file.path(
    promotion_root, paste0(promotion_id, "_unresolved_cells.csv"))),
  target = write_csv(target_confirmation, file.path(
    promotion_root, paste0(promotion_id, "_targeted_confirmation_plan.csv"))),
  storage = write_csv(storage_audit, file.path(
    promotion_root, paste0(promotion_id, "_storage_audit.csv"))),
  summary = write_csv(summary, file.path(
    promotion_root, paste0(promotion_id, "_summary.csv")))
)

source_paths <- c(
  campaign_fit_summary = fit_path,
  campaign_progress = progress_path,
  campaign_completion = completion_path,
  prelaunch_ledger = ledger_path,
  target_specs = target_specs_path
)
source_manifest <- data.frame(
  source_key = names(source_paths),
  path = vapply(source_paths, normalizePath, character(1L),
                winslash = "/", mustWork = TRUE),
  sha256 = vapply(source_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest, file.path(promotion_root, "source_manifest.csv")
)
paths <- c(paths, source_manifest = source_manifest_path)

file_manifest <- data.frame(
  artifact = names(paths),
  path = unname(paths),
  sha256 = vapply(paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(
  file_manifest, file.path(promotion_root, "file_manifest.csv")
)

manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  git_branch = git_value(c("branch", "--show-current")),
  git_commit = git_value(c("rev-parse", "HEAD")),
  source_run = list(
    stage = stage, run_tag = run_tag, campaign_stamp = campaign_stamp,
    report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
    results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE)
  ),
  protocol = list(
    fit_window = "source indices 8501:9000",
    forecast_origin_source_index = 9000L,
    forecast_window = "source indices 9001:10000",
    forecast_horizon = 1000L,
    candidate_objective = "minimize maximum ratio across fit RMSE, H1000 forecast MAE, and H1000 check loss relative to frozen best-DQLM benchmark",
    comparison_eligible = "SUCCESS and signoff PASS/WARN and finite/domain checks",
    current_ledger_replacement = "material minimax improvement >=0.5%, or eligible replacement within 1% of a failed current row"
  ),
  summary = as.list(summary[1L, , drop = FALSE]),
  source_manifest = source_manifest,
  file_manifest = file_manifest,
  article_gate = "closed_pending_targeted_normal_0.05_exAL_multiseed_confirmation"
)
manifest_path <- write_json(
  manifest, file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
)

readme <- c(
  "# Q-DESN 500-Observation MCMC Per-Case RHS v2 Closeout",
  "",
  sprintf("- Promotion ID: `%s`", promotion_id),
  sprintf("- Source run tag: `%s`", run_tag),
  sprintf("- Validation commit at materialization: `%s`", manifest$git_commit),
  "- Scope: independent Q-DESN/exQ-DESN RHS validation only.",
  "- Status: complete evidence package; article gate remains closed.",
  "",
  "## Completion",
  "",
  sprintf("- Planned/completed roots: `%d/%d`.", summary$n_planned, summary$n_success),
  sprintf("- Signoff mix: PASS `%d`, WARN `%d`, FAIL `%d`.",
          summary$n_pass, summary$n_warn, summary$n_fail),
  sprintf("- Comparison-eligible candidates: `%d`.", summary$n_comparison_eligible),
  sprintf("- Eligible all-primary candidate rows: `%d` across `%d` cells.",
          summary$n_all_primary_candidate_rows,
          summary$n_all_primary_eligible_cells),
  sprintf("- Current-ledger replacements proposed: `%d`.",
          summary$n_current_ledger_promotions),
  sprintf("- Unexpected heavy/binary artifacts: `%d`.",
          summary$n_heavy_binary_artifacts),
  "",
  "## Decision Rules",
  "",
  "All rankings use the dedicated `forecast_horizon_summary.csv` H=1000 rows.",
  "Legacy campaign-level forecast fields are intentionally ignored because they",
  "are not populated by the rolling-origin protocol. A candidate is comparison",
  "eligible only when execution succeeded, finite/domain checks passed, and the",
  "MCMC signoff is PASS or WARN.",
  "",
  "A current Q-DESN cell is replaced only when the eligible candidate improves",
  "the frozen minimax benchmark ratio by at least 0.5%, or replaces a failed",
  "current row while remaining within 1% of its minimax value.",
  "",
  "## Remaining Gate",
  "",
  "The Normal, tau=0.05, exQ-DESN candidate `mcvbc_060_exal` beats DQLM on all",
  "three primary metrics but has gamma autocorrelation 0.983 and is therefore",
  "diagnostic-only. It receives one four-seed confirmation stage. Article-facing",
  "tables remain unchanged until that confirmation is closed out.",
  "",
  "## Files",
  "",
  sprintf("- Artifact manifest: `%s`", basename(file_manifest_path)),
  sprintf("- Source manifest: `%s`", basename(source_manifest_path)),
  sprintf("- Closeout manifest: `%s`", basename(manifest_path))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf(
  "complete=%d/%d eligible=%d pass=%d warn=%d fail=%d promotions=%d all_primary_cells=%d heavy=%d\n",
  summary$n_success, summary$n_planned, summary$n_comparison_eligible,
  summary$n_pass, summary$n_warn, summary$n_fail,
  summary$n_current_ledger_promotions,
  summary$n_all_primary_eligible_cells,
  summary$n_heavy_binary_artifacts
))
