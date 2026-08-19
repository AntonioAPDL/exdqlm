#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop(sprintf("Missing package: %s", pkg))
  }
})
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
                           winslash = "/", mustWork = TRUE)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(arg("--output-root", file.path(state_root, "forecast_first_confirmation")),
                             winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_postm0_legacy_recheck_v1.R"))

adaptive <- file.path(state_root, "adaptive")
eligible_path <- file.path(adaptive, "tier_a_sealed_eligible_metrics.csv")
handoff_path <- file.path(adaptive, "tier_a_confirmation_manifest.csv")
gate_path <- file.path(adaptive, "tier_a_sealed_gate.csv")
advance_path <- file.path(adaptive, "advance_after_tier_a_sealed.json")
eligible <- qdesn_ssv2_read_csv(eligible_path)
handoff <- qdesn_ssv2_read_csv(handoff_path)
gate <- qdesn_ssv2_read_csv(gate_path)
advance <- qdesn_ssv2_read_json(advance_path)
stub <- file.path(repo_root, "config", "validation", qdesn_plrv1_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))

expected_target <- "exal_gausmix_t0p25"
expected_candidate <- "plrv1_exal_gausmix_t0p25_08_576957a0bd"
expected_metric <- "forecast_qtrue_mae_H1000"
checks <- c(
  sealed_gate = nrow(gate) == 1L && isTRUE(gate$gate_pass[[1L]]) &&
    gate$successful_jobs[[1L]] == 60L && gate$failed_jobs[[1L]] == 0L,
  sealed_decision = identical(as.character(advance$decision),
                              "confirmation_manifest_only_wait_for_explicit_approval"),
  eligible = nrow(eligible) == 1L && eligible$target_cell_id[[1L]] == expected_target &&
    eligible$candidate_id[[1L]] == expected_candidate &&
    eligible$metric[[1L]] == expected_metric && eligible$sources_improved[[1L]] == 4L &&
    eligible$mean_paired_ratio[[1L]] < 1 && eligible$max_paired_ratio[[1L]] < 1,
  handoff = nrow(handoff) == 3L && identical(sort(handoff$chain_id), 1:3) &&
    all(!handoff$launch_approved),
  registry = identical(unique(handoff$canonical_source_registry_hash_value),
                       qdesn_ssv2_registry_hash),
  budget = all(handoff$n_burn == 5000L) && all(handoff$n_mcmc == 20000L) &&
    all(handoff$thin == 1L)
)
if (!all(checks)) stop(sprintf("Forecast-first handoff failed: %s",
                               paste(names(checks)[!checks], collapse = ", ")))

target <- targets[match(expected_target, targets$target_cell_id), , drop = FALSE]
profile <- profiles[match(expected_candidate, profiles$candidate_id), , drop = FALSE]
if (nrow(target) != 1L || nrow(profile) != 1L ||
    is.na(target$target_cell_id[[1L]]) || is.na(profile$candidate_id[[1L]])) {
  stop("Frozen target/profile mapping is incomplete.")
}
request_path <- normalizePath(file.path(repo_root, target$parent_request_path[[1L]]),
                              winslash = "/", mustWork = TRUE)
if (!identical(qdesn_ssv2_sha256(request_path), target$parent_request_sha256[[1L]])) {
  stop("Frozen parent request drifted.")
}
request <- qdesn_ssv2_read_json(request_path)
series_path <- normalizePath(request$root_spec$source_series_wide_path,
                             winslash = "/", mustWork = TRUE)
sim_path <- normalizePath(request$root_spec$source_sim_path,
                          winslash = "/", mustWork = TRUE)
if (!identical(qdesn_ssv2_sha256(series_path), request$root_spec$source_series_wide_sha256) ||
    !identical(qdesn_ssv2_sha256(sim_path), request$root_spec$source_sim_sha256)) {
  stop("Canonical source hash drifted.")
}
series <- qdesn_ssv2_read_csv(series_path)
if (nrow(series) != 1890L || !all(c("y", "q_target", "mu") %in% names(series))) {
  stop("Canonical source schema failed.")
}
source_registry <- data.frame(
  source_id = "canonical_article", source_role = "canonical_confirmation",
  scenario = as.character(request$root_spec$scenario %||% request$root_spec$source_scenario),
  family = target$family[[1L]], tau = target$tau[[1L]],
  series_wide_path = series_path, series_wide_sha256 = qdesn_ssv2_sha256(series_path),
  sim_output_path = sim_path, sim_output_sha256 = qdesn_ssv2_sha256(sim_path),
  parent_request_path = request_path, parent_request_sha256 = qdesn_ssv2_sha256(request_path),
  canonical_registry_hash_value = qdesn_ssv2_registry_hash,
  stringsAsFactors = FALSE
)
source_registry_path <- qdesn_ssv2_write_csv(
  source_registry, file.path(output_root, "canonical_source_registry.csv")
)

all_idx <- 8111:10000
raw_start <- 8501L - as.integer(profile$m[[1L]]) - as.integer(profile$washout[[1L]])
keep <- all_idx >= raw_start
x <- series[keep, , drop = FALSE]
idx <- all_idx[keep]
x$source_index <- idx
x$t <- seq_len(nrow(x))
window_dir <- file.path(output_root, "canonical_window", "gausmix", "tau_0p25",
                        sprintf("m%d_w%d", profile$m[[1L]], profile$washout[[1L]]))
dir.create(window_dir, recursive = TRUE, showWarnings = FALSE)
series_out <- qdesn_ssv2_write_csv(x, file.path(window_dir, "series_wide.csv"))
selection <- qdesn_ssv2_write_csv(
  data.frame(t = seq_len(nrow(x)), source_index = idx),
  file.path(window_dir, "selection_indices.csv")
)
phase1 <- 2 * pi * idx / 90
phase2 <- 4 * pi * idx / 90
trend <- (idx - mean(idx)) / stats::sd(idx)
observed <- qdesn_ssv2_write_csv(data.frame(
  y = x$y, period90_sin_h1 = sin(phase1), period90_cos_h1 = cos(phase1),
  period90_sin_h2 = sin(phase2), period90_cos_h2 = cos(phase2),
  period90_trend_z = trend
), file.path(window_dir, "observed.csv"))
qtrue <- qdesn_ssv2_write_csv(data.frame(
  t = seq_len(nrow(x)), source_index = idx, q_true = x$q_target, y = x$y, mu = x$mu
), file.path(window_dir, "q_true.csv"))
source <- data.frame(
  source_id = "canonical_article", source_role = "canonical_confirmation",
  scenario = source_registry$scenario[[1L]], family = "gausmix", tau = 0.25,
  m = profile$m[[1L]], washout = profile$washout[[1L]],
  raw_start_source_index = raw_start, raw_end_source_index = 10000L,
  train_start_source_index = 8501L, train_end_source_index = 9000L,
  forecast_start_source_index = 9001L, forecast_end_source_index = 10000L,
  source_total_size = nrow(x), source_series_wide_path = series_out,
  source_series_wide_sha256 = qdesn_ssv2_sha256(series_out),
  source_selection_indices_path = selection,
  source_selection_indices_sha256 = qdesn_ssv2_sha256(selection),
  source_sim_path = sim_path, source_sim_sha256 = qdesn_ssv2_sha256(sim_path),
  source_latent_seed = NA_integer_, source_noise_seed = NA_integer_,
  observed_path = observed, observed_sha256 = qdesn_ssv2_sha256(observed),
  qtrue_path = qtrue, qtrue_sha256 = qdesn_ssv2_sha256(qtrue),
  stringsAsFactors = FALSE
)
window_path <- qdesn_ssv2_write_csv(source, file.path(output_root, "canonical_window_registry.csv"))

rows <- vector("list", 3L)
for (chain in 1:3) {
  job <- qdesn_plrv1_make_job(repo_root, profile, target, source,
                              "tier_a_confirmation", source_registry_path,
                              chain_id = chain, reservoir_seed_id = "canonical_r01")
  job$study_contract$explicit_human_approval <- TRUE
  job$study_contract$approval_instruction <-
    "QDESN_PLRV1_FORECAST_CONFIRMATION_APPROVED=true"
  job$study_contract$sealed_eligible_metrics_path <- eligible_path
  job$study_contract$sealed_eligible_metrics_sha256 <- qdesn_ssv2_sha256(eligible_path)
  job$study_contract$sealed_gate_path <- gate_path
  job$study_contract$sealed_gate_sha256 <- qdesn_ssv2_sha256(gate_path)
  job$study_contract$canonical_source_materialized <- TRUE
  job$study_contract$promotion_primary_metric <- expected_metric
  job$study_contract$promotion_rule <-
    "strict_three_chain_mean_forecast_mae_below_v6"
  job$study_contract$diagnostics_used_as_promotion_gate <- FALSE
  job$study_contract$execution_integrity_required <- TRUE
  path <- file.path(output_root, "configs", paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  rows[[chain]] <- data.frame(
    job_id = job$job_id, stage = job$stage, tier = "A",
    target_cell_id = job$target_cell_id, likelihood_target = job$likelihood_target,
    target_metrics = paste(unlist(job$target_metrics), collapse = ";"),
    metric = expected_metric, candidate_id = job$candidate_id, chain_id = chain,
    source_id = job$source_id, reservoir_seed_id = job$reservoir_seed_id,
    config_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    config_sha256 = qdesn_ssv2_sha256(path), expected_n_burn = 5000L,
    expected_n_mcmc = 20000L,
    current_value = target$current_forecast_qtrue_mae_H1000[[1L]],
    source_registry_hash_value = qdesn_ssv2_registry_hash,
    stringsAsFactors = FALSE
  )
}
plan <- do.call(rbind, rows)
if (nrow(plan) != 3L || anyDuplicated(plan$job_id) ||
    !identical(sort(plan$chain_id), 1:3)) stop("Confirmation cardinality failed.")
plan_path <- qdesn_ssv2_write_csv(plan, file.path(output_root, "confirmation_plan.csv"))
qdesn_ssv2_write_json(list(
  schema_version = "qdesn_postm0_forecast_first_confirmation_v1",
  generated_at = as.character(Sys.time()),
  validation_commit = system("git rev-parse HEAD", intern = TRUE),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  explicit_human_approval = TRUE, confirmation_jobs = 3L,
  chains_per_candidate = 3L, n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
  promotion_primary_metric = expected_metric,
  promotion_rule = "strict_three_chain_mean_forecast_mae_below_v6",
  diagnostics_used_as_promotion_gate = FALSE,
  plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
  source_registry = list(path = source_registry_path,
                         sha256 = qdesn_ssv2_sha256(source_registry_path)),
  windows = list(path = window_path, sha256 = qdesn_ssv2_sha256(window_path)),
  eligible = list(path = eligible_path, sha256 = qdesn_ssv2_sha256(eligible_path)),
  article_promotion_automatic = FALSE
), file.path(output_root, "confirmation_materialization_manifest.json"))
cat(sprintf("forecast_first_confirmation_materialized jobs=3 output=%s\n", output_root))
