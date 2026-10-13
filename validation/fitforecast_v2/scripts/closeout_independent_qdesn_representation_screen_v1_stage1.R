#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  index <- match(flag, args)
  if (is.na(index) || index == length(args)) return(default)
  args[[index + 1L]]
}

run_root <- value_after("--run-root")
if (is.null(run_root)) {
  stop("Usage: --run-root PATH [--output-dir PATH]", call. = FALSE)
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
output_dir <- value_after(
  "--output-dir",
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "independent_qdesn_representation_screen_v1_stage1_closeout_20260929"
  )
)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)

suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2_runtime.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_representation_screen_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_representation_screen_v1_runtime.R"))

plan_path <- file.path(run_root, "plans", "ridge_screen.csv")
plan <- utils::read.csv(plan_path, check.names = FALSE,
                        stringsAsFactors = FALSE)
health <- iqrs_v1_stage_health(plan_path)
if (nrow(plan) != 960L || !isTRUE(health$complete[[1L]]) ||
    health$success[[1L]] != 960L || health$failed[[1L]] != 0L) {
  stop("The ridge stage is not a complete 960-job authority.", call. = FALSE)
}

integrity_rows <- lapply(seq_len(nrow(plan)), function(i) {
  status <- iqfr_v2_read_json(plan$status_path[[i]])
  observed <- iqfr_v2_sha256(plan$result_path[[i]])
  data.frame(
    job_id = plan$job_id[[i]], family = plan$family[[i]],
    structure_id = plan$structure_id[[i]],
    config_path = plan$config_path[[i]],
    config_sha256 = plan$config_sha256[[i]],
    result_path = plan$result_path[[i]],
    result_size_bytes = as.numeric(file.info(plan$result_path[[i]])$size),
    expected_result_sha256 = as.character(status$result_sha256),
    observed_result_sha256 = observed,
    result_rows = as.integer(status$rows),
    status = as.character(status$status),
    hash_pass = identical(observed, as.character(status$result_sha256)),
    row_contract_pass = identical(as.integer(status$rows), 12L),
    fitted_model_binaries = as.integer(status$fitted_model_binaries %||% 0L),
    stringsAsFactors = FALSE
  )
})
integrity <- do.call(rbind, integrity_rows)
if (!all(integrity$status == "SUCCESS") || !all(integrity$hash_pass) ||
    !all(integrity$row_contract_pass) ||
    any(integrity$fitted_model_binaries != 0L)) {
  stop("Ridge result integrity audit failed.", call. = FALSE)
}

ridge <- iqrs_v1_collect_results(plan_path, require_complete = TRUE)
numeric_metrics <- c(
  "fit_oracle_location_rmse", "fit_oracle_location_mae",
  "forecast_oracle_location_mae", "forecast_oracle_location_rmse",
  "forecast_observed_mae", "lead_1_mae", "leads_2_5_mae",
  "leads_6_15_mae", "leads_16_30_mae"
)
if (nrow(ridge) != 11520L || any(!is.finite(as.matrix(ridge[numeric_metrics]))) ||
    !all(ridge$exact_identity_projection) ||
    any(ridge$zero_variance_readout_columns != 0L) ||
    !all(ridge$normal_converged)) {
  stop("Ridge scientific-result contract failed.", call. = FALSE)
}

ranking <- iqrs_v1_aggregate_normal(ridge)
best <- iqrs_v1_best_scale_per_structure(ranking)
shortlist <- iqrs_v1_select_diverse(ranking, 120L)

champion_fields <- c(
  robust = "robust_score", forecast_median = "median_forecast_mae",
  forecast_worst = "worst_forecast_mae", fit = "median_fit_rmse",
  long_lead = "median_leads_16_30_mae"
)
champions <- do.call(rbind, lapply(iqrs_v1_families, function(family) {
  x <- best[best$family == family, , drop = FALSE]
  do.call(rbind, lapply(names(champion_fields), function(role) {
    field <- champion_fields[[role]]
    row <- x[order(x[[field]], x$median_forecast_mae,
                   x$structure_id), , drop = FALSE][1L, , drop = FALSE]
    row$champion_role <- role
    row
  }))
}))
champion_keys <- paste(champions$family, champions$structure_id,
                       champions$prior_scale, sep = "|")
shortlist_keys <- paste(shortlist$family, shortlist$structure_id,
                        shortlist$prior_scale, sep = "|")
if (!all(champion_keys %in% shortlist_keys)) {
  stop("The frozen shortlist lost a mandatory champion.", call. = FALSE)
}

quantile_value <- function(x, probability) {
  as.numeric(stats::quantile(x, probability, names = FALSE, type = 8L))
}
pattern_rows <- list()
k <- 0L
for (family in iqrs_v1_families) {
  family_best <- best[best$family == family, , drop = FALSE]
  family_best <- family_best[order(
    family_best$robust_score, family_best$median_forecast_mae,
    family_best$structure_id
  ), , drop = FALSE]
  for (top_n in c(20L, 50L)) {
    x <- utils::head(family_best, top_n)
    ratio <- x$worst_forecast_mae / pmax(x$median_forecast_mae * 2 -
                                           x$worst_forecast_mae, 1e-12)
    k <- k + 1L
    pattern_rows[[k]] <- data.frame(
      family = family, top_n = top_n,
      depth_3_or_4 = sum(x$D %in% c(3L, 4L)),
      response_lag_over_150 = sum(x$m > 150L),
      states_over_600 = sum(x$total_states > 600L),
      states_q10 = quantile_value(x$total_states, 0.10),
      states_median = stats::median(x$total_states),
      states_q90 = quantile_value(x$total_states, 0.90),
      alpha_q10 = quantile_value(x$alpha, 0.10),
      alpha_median = stats::median(x$alpha),
      alpha_q90 = quantile_value(x$alpha, 0.90),
      rho_q10 = quantile_value(x$rho, 0.10),
      rho_median = stats::median(x$rho),
      rho_q90 = quantile_value(x$rho, 0.90),
      distinct_best_ridge_scales = length(unique(x$prior_scale)),
      median_worst_to_best_fold_ratio = stats::median(ratio),
      maximum_worst_to_best_fold_ratio = max(ratio),
      stringsAsFactors = FALSE
    )
  }
}
patterns <- do.call(rbind, pattern_rows)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
paths <- c(
  integrity = iqfr_v2_write_csv(
    integrity, file.path(output_dir, "ridge_result_integrity.csv")
  ),
  ranking = iqfr_v2_write_csv(
    ranking, file.path(output_dir, "ridge_robust_ranking.csv")
  ),
  best = iqfr_v2_write_csv(
    best, file.path(output_dir, "ridge_best_scale_per_structure.csv")
  ),
  shortlist = iqfr_v2_write_csv(
    shortlist, file.path(output_dir, "ridge_shortlist.csv")
  ),
  champions = iqfr_v2_write_csv(
    champions, file.path(output_dir, "ridge_family_champions.csv")
  ),
  patterns = iqfr_v2_write_csv(
    patterns, file.path(output_dir, "ridge_pattern_summary.csv")
  )
)

git_head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                    stdout = TRUE)
decision <- list(
  schema_version = "independent_qdesn_representation_screen_v1_stage1_closeout_v1",
  status = "STAGE1_COMPLETE_SUPERSEDED_BY_CELLWISE_REFINEMENT_V2",
  completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  branch = system2("git", c("-C", repo_root, "branch", "--show-current"),
                   stdout = TRUE),
  git_head_at_closeout = git_head,
  run_root = run_root,
  ridge_jobs_planned = 960L,
  ridge_jobs_successful = 960L,
  ridge_jobs_failed = 0L,
  ridge_internal_fits = nrow(ridge),
  downstream_jobs_intentionally_not_launched = 816L,
  fitted_model_binaries = 0L,
  active_campaign_processes = 0L,
  article_promotion_authorized = FALSE,
  supersession_reason = paste(
    "Stage 1 is valid, but family-level Normal/VB transfer is insufficient",
    "for a defensible cellwise MCMC funnel; v2 imports this evidence and",
    "adds family-targeted capacity plus cell-specific quantile/MCMC selection."
  ),
  artifacts = lapply(paths, function(path) list(
    path = path, sha256 = iqfr_v2_sha256(path)
  ))
)
closeout_path <- iqfr_v2_write_json(
  decision, file.path(output_dir, "stage1_closeout.json")
)
runtime_closeout <- file.path(run_root, "manifests", "stage1_closeout.json")
iqfr_v2_write_json(decision, runtime_closeout)

readme_path <- file.path(output_dir, "README.md")
writeLines(c(
  "# Independent Q-DESN representation screen v1: Stage 1 closeout",
  "",
  "Status: `STAGE1_COMPLETE_SUPERSEDED_BY_CELLWISE_REFINEMENT_V2`.",
  "",
  "The exact Normal-ridge stage completed 960/960 scheduler jobs and",
  "11,520 internal fold-by-scale fits with no worker failures, nonfinite",
  "metrics, projection violations, zero-variance readout columns, or fitted",
  "model binaries. The pipeline stopped after Stage 1 because the inherited",
  "collector keyed valid multirow results too coarsely. That orchestration",
  "defect does not invalidate the ridge evidence.",
  "",
  "The remaining 816 jobs from the original stage graph were deliberately",
  "not resumed. Historical audits show weak and sometimes negative transfer",
  "from family-level Normal/VB ranks to cell-specific MCMC performance.",
  "The successor campaign therefore imports these frozen ridge results, adds",
  "targeted family-specific structures, establishes fresh cellwise quantile",
  "evidence, and preserves diverse candidates for direct MCMC.",
  "",
  "No article, shared-validation, integration, or Overleaf write is authorized",
  "by this closeout."
), readme_path)

artifact_files <- c(unname(paths), closeout_path, readme_path)
manifest <- data.frame(
  relative_path = basename(artifact_files),
  size_bytes = as.numeric(file.info(artifact_files)$size),
  sha256 = vapply(artifact_files, iqfr_v2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
manifest_path <- iqfr_v2_write_csv(
  manifest, file.path(output_dir, "artifact_manifest.csv")
)

cat(sprintf(
  paste0(
    "status=%s ridge_jobs=%d internal_fits=%d downstream_unlaunched=%d ",
    "output=%s manifest=%s\n"
  ),
  decision$status, 960L, nrow(ridge), 816L, output_dir, manifest_path
))
