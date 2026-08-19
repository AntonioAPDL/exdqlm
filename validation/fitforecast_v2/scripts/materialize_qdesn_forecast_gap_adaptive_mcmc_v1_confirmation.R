#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop(sprintf("Missing package: %s", pkg))
  }
})
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(
  arg("--output-root", file.path(state_root, "confirmation")),
  winslash = "/", mustWork = FALSE
)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_forecast_gap_adaptive_mcmc_v1.R"))

adaptive <- file.path(state_root, "adaptive")
eligible_path <- file.path(adaptive, "sealed_eligible_metrics.csv")
handoff_path <- file.path(adaptive, "confirmation_handoff.csv")
gate_path <- file.path(adaptive, "sealed_gate.csv")
advance_path <- file.path(adaptive, "advance_after_sealed.json")
eligible <- qdesn_ssv2_read_csv(eligible_path)
handoff <- qdesn_ssv2_read_csv(handoff_path)
gate <- qdesn_ssv2_read_csv(gate_path)
advance <- qdesn_ssv2_read_json(advance_path)
stub <- file.path(repo_root, "config", "validation", qdesn_fgav1_stage)
targets_all <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
profiles_all <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))

expected_handoff <- 3L * nrow(eligible)
checks <- c(
  sealed_gate = nrow(gate) == 1L && isTRUE(gate$gate_pass[[1L]]) &&
    gate$successful_jobs[[1L]] == 96L && gate$failed_jobs[[1L]] == 0L,
  sealed_decision = identical(
    as.character(advance$decision),
    if (nrow(eligible)) "advance_to_canonical_confirmation" else
      "no_sealed_forecast_gain_retain_v7"
  ),
  eligible = nrow(eligible) <= 14L && !anyDuplicated(paste(
    eligible$target_cell_id, eligible$metric, sep = "\r"
  )),
  handoff = nrow(handoff) == expected_handoff &&
    (!nrow(handoff) || all(handoff$launch_approved)),
  registry = !nrow(handoff) || identical(
    unique(handoff$canonical_source_registry_hash_value), qdesn_ssv2_registry_hash
  ),
  budget = !nrow(handoff) || (
    all(handoff$n_burn == 5000L) && all(handoff$n_mcmc == 20000L) &&
      all(handoff$thin == 1L)
  )
)
if (!all(checks)) {
  stop(sprintf("Confirmation handoff failed: %s",
               paste(names(checks)[!checks], collapse = ", ")))
}

metric_map <- eligible[, c(
  "target_cell_id", "metric", "candidate_id", "mean_paired_ratio",
  "median_paired_ratio", "sources_improved"
), drop = FALSE]
if (nrow(metric_map)) {
  target_index <- match(metric_map$target_cell_id, targets_all$target_cell_id)
  metric_map$current_value <- vapply(seq_len(nrow(metric_map)), function(i) {
    targets_all[[paste0("current_", metric_map$metric[[i]])]][[target_index[[i]]]]
  }, numeric(1L))
  metric_map$authority_version <- "v7_postm0_forecast_20260818"
}
metric_map_path <- qdesn_ssv2_write_csv(
  metric_map, file.path(output_root, "confirmation_metric_map.csv")
)

empty_plan <- data.frame(
  job_id = character(), stage = character(), tier = character(),
  target_cell_id = character(), likelihood_target = character(),
  target_metrics = character(), candidate_id = character(), chain_id = integer(),
  source_id = character(), reservoir_seed_id = character(), config_path = character(),
  config_sha256 = character(), expected_n_burn = integer(),
  expected_n_mcmc = integer(), stringsAsFactors = FALSE
)
if (!nrow(eligible)) {
  plan_path <- qdesn_ssv2_write_csv(
    empty_plan, file.path(output_root, "confirmation_plan.csv")
  )
  qdesn_ssv2_write_json(list(
    schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_confirmation_v1",
    generated_at = as.character(Sys.time()),
    validation_commit = system("git rev-parse HEAD", intern = TRUE),
    decision = "NO_SEALED_GAIN_RETAIN_V7", confirmation_jobs = 0L,
    metric_roles = 0L, explicit_campaign_approval = TRUE,
    plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
    metric_map = list(path = metric_map_path, sha256 = qdesn_ssv2_sha256(metric_map_path)),
    article_promotion_automatic = FALSE
  ), file.path(output_root, "confirmation_materialization_manifest.json"))
  cat(sprintf("confirmation_materialized jobs=0 output=%s\n", output_root))
  quit(save = "no", status = 0L)
}

combos <- unique(metric_map[, c("target_cell_id", "candidate_id"), drop = FALSE])
targets <- targets_all[match(combos$target_cell_id, targets_all$target_cell_id), , drop = FALSE]
profiles <- profiles_all[match(combos$candidate_id, profiles_all$candidate_id), , drop = FALSE]
if (anyNA(targets$target_cell_id) || anyNA(profiles$candidate_id)) {
  stop("Eligible target/profile mapping is incomplete.")
}

source_rows <- vector("list", nrow(combos))
for (i in seq_len(nrow(combos))) {
  request_path <- normalizePath(
    file.path(repo_root, targets$parent_request_path[[i]]),
    winslash = "/", mustWork = TRUE
  )
  if (!identical(qdesn_ssv2_sha256(request_path), targets$parent_request_sha256[[i]])) {
    stop(sprintf("Frozen parent request drifted for %s.", targets$target_cell_id[[i]]))
  }
  request <- qdesn_ssv2_read_json(request_path)
  series_path <- normalizePath(request$root_spec$source_series_wide_path,
                               winslash = "/", mustWork = TRUE)
  sim_path <- normalizePath(request$root_spec$source_sim_path,
                            winslash = "/", mustWork = TRUE)
  if (!identical(qdesn_ssv2_sha256(series_path),
                 request$root_spec$source_series_wide_sha256) ||
      !identical(qdesn_ssv2_sha256(sim_path), request$root_spec$source_sim_sha256)) {
    stop(sprintf("Canonical source hash drifted for %s.", targets$target_cell_id[[i]]))
  }
  series <- qdesn_ssv2_read_csv(series_path)
  if (nrow(series) != 1890L || !all(c("y", "q_target", "mu") %in% names(series))) {
    stop(sprintf("Canonical source schema failed for %s.", targets$target_cell_id[[i]]))
  }
  source_rows[[i]] <- data.frame(
    target_cell_id = targets$target_cell_id[[i]], source_id = "canonical_article",
    source_role = "canonical_confirmation",
    scenario = as.character(request$root_spec$scenario %||%
                              request$root_spec$source_scenario),
    family = targets$family[[i]], tau = targets$tau[[i]],
    series_wide_path = series_path, series_wide_sha256 = qdesn_ssv2_sha256(series_path),
    sim_output_path = sim_path, sim_output_sha256 = qdesn_ssv2_sha256(sim_path),
    parent_request_path = request_path,
    parent_request_sha256 = qdesn_ssv2_sha256(request_path),
    canonical_registry_hash_value = qdesn_ssv2_registry_hash,
    stringsAsFactors = FALSE
  )
}
source_registry <- unique(do.call(rbind, source_rows))
source_registry_path <- qdesn_ssv2_write_csv(
  source_registry, file.path(output_root, "canonical_source_registry.csv")
)

stage_canonical <- function(source_row, profile) {
  series <- qdesn_ssv2_read_csv(source_row$series_wide_path[[1L]])
  all_idx <- 8111:10000
  raw_start <- 8501L - as.integer(profile$m[[1L]]) - as.integer(profile$washout[[1L]])
  keep <- all_idx >= raw_start
  x <- series[keep, , drop = FALSE]
  idx <- all_idx[keep]
  x$source_index <- idx
  x$t <- seq_len(nrow(x))
  dir <- file.path(
    output_root, "canonical_windows", qdesn_ssv2_safe(source_row$target_cell_id[[1L]]),
    qdesn_ssv2_safe(profile$candidate_id[[1L]])
  )
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  series_out <- qdesn_ssv2_write_csv(x, file.path(dir, "series_wide.csv"))
  selection <- qdesn_ssv2_write_csv(
    data.frame(t = seq_len(nrow(x)), source_index = idx),
    file.path(dir, "selection_indices.csv")
  )
  phase1 <- 2 * pi * idx / 90
  phase2 <- 4 * pi * idx / 90
  trend <- (idx - mean(idx)) / stats::sd(idx)
  observed <- qdesn_ssv2_write_csv(data.frame(
    y = x$y, period90_sin_h1 = sin(phase1), period90_cos_h1 = cos(phase1),
    period90_sin_h2 = sin(phase2), period90_cos_h2 = cos(phase2),
    period90_trend_z = trend
  ), file.path(dir, "observed.csv"))
  qtrue <- qdesn_ssv2_write_csv(data.frame(
    t = seq_len(nrow(x)), source_index = idx, q_true = x$q_target,
    y = x$y, mu = x$mu
  ), file.path(dir, "q_true.csv"))
  data.frame(
    source_id = "canonical_article", source_role = "canonical_confirmation",
    scenario = source_row$scenario[[1L]], family = source_row$family[[1L]],
    tau = source_row$tau[[1L]], m = profile$m[[1L]], washout = profile$washout[[1L]],
    raw_start_source_index = raw_start, raw_end_source_index = 10000L,
    train_start_source_index = 8501L, train_end_source_index = 9000L,
    forecast_start_source_index = 9001L, forecast_end_source_index = 10000L,
    source_total_size = nrow(x), source_series_wide_path = series_out,
    source_series_wide_sha256 = qdesn_ssv2_sha256(series_out),
    source_selection_indices_path = selection,
    source_selection_indices_sha256 = qdesn_ssv2_sha256(selection),
    source_sim_path = source_row$sim_output_path[[1L]],
    source_sim_sha256 = source_row$sim_output_sha256[[1L]],
    source_latent_seed = NA_integer_, source_noise_seed = NA_integer_,
    observed_path = observed, observed_sha256 = qdesn_ssv2_sha256(observed),
    qtrue_path = qtrue, qtrue_sha256 = qdesn_ssv2_sha256(qtrue),
    stringsAsFactors = FALSE
  )
}

rows <- list()
windows <- list()
k <- 0L
for (i in seq_len(nrow(combos))) {
  target <- targets[i, , drop = FALSE]
  profile <- profiles[i, , drop = FALSE]
  source <- stage_canonical(source_rows[[i]], profile)
  windows[[i]] <- cbind(
    target_cell_id = target$target_cell_id[[1L]],
    candidate_id = profile$candidate_id[[1L]], source,
    stringsAsFactors = FALSE
  )
  eligible_metrics <- metric_map$metric[
    metric_map$target_cell_id == target$target_cell_id[[1L]] &
      metric_map$candidate_id == profile$candidate_id[[1L]]
  ]
  for (chain in 1:3) {
    job <- qdesn_fgav1_make_job(
      repo_root, profile, target, source, "confirmation", source_registry_path,
      chain_id = chain, reservoir_seed_id = "canonical_r01"
    )
    job$study_contract$explicit_campaign_approval <- TRUE
    job$study_contract$approval_instruction <-
      "2026-08-18 user instruction to implement and launch the complete campaign"
    job$study_contract$eligible_metrics <- eligible_metrics
    job$study_contract$sealed_eligible_metrics_path <- eligible_path
    job$study_contract$sealed_eligible_metrics_sha256 <- qdesn_ssv2_sha256(eligible_path)
    job$study_contract$sealed_gate_path <- gate_path
    job$study_contract$sealed_gate_sha256 <- qdesn_ssv2_sha256(gate_path)
    job$study_contract$canonical_source_materialized <- TRUE
    path <- file.path(output_root, "configs", paste0(job$job_id, ".json"))
    qdesn_ssv2_write_json(job, path)
    k <- k + 1L
    rows[[k]] <- data.frame(
      job_id = job$job_id, stage = job$stage, tier = target$tier[[1L]],
      target_cell_id = job$target_cell_id,
      likelihood_target = target$likelihood_target[[1L]],
      target_metrics = paste(eligible_metrics, collapse = ";"),
      candidate_id = job$candidate_id, chain_id = chain,
      source_id = job$source_id, reservoir_seed_id = job$reservoir_seed_id,
      config_path = normalizePath(path, winslash = "/", mustWork = TRUE),
      config_sha256 = qdesn_ssv2_sha256(path), expected_n_burn = 5000L,
      expected_n_mcmc = 20000L, stringsAsFactors = FALSE
    )
  }
}
plan <- do.call(rbind, rows)
if (nrow(plan) != 3L * nrow(combos) || nrow(plan) > 42L ||
    any(table(paste(plan$target_cell_id, plan$candidate_id)) != 3L) ||
    anyDuplicated(plan$job_id)) {
  stop("Confirmation plan cardinality failed.")
}
plan_path <- qdesn_ssv2_write_csv(plan, file.path(output_root, "confirmation_plan.csv"))
window_path <- qdesn_ssv2_write_csv(
  do.call(rbind, windows), file.path(output_root, "canonical_window_registry.csv")
)
qdesn_ssv2_write_json(list(
  schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_confirmation_v1",
  generated_at = as.character(Sys.time()),
  validation_commit = system("git rev-parse HEAD", intern = TRUE),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  explicit_campaign_approval = TRUE, confirmation_jobs = nrow(plan),
  confirmed_candidates = nrow(combos), metric_roles = nrow(metric_map),
  chains_per_candidate = 3L, n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
  plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
  source_registry = list(path = source_registry_path,
                         sha256 = qdesn_ssv2_sha256(source_registry_path)),
  windows = list(path = window_path, sha256 = qdesn_ssv2_sha256(window_path)),
  metric_map = list(path = metric_map_path, sha256 = qdesn_ssv2_sha256(metric_map_path)),
  eligible = list(path = eligible_path, sha256 = qdesn_ssv2_sha256(eligible_path)),
  article_promotion_automatic = FALSE
), file.path(output_root, "confirmation_materialization_manifest.json"))
cat(sprintf("confirmation_materialized jobs=%d metrics=%d output=%s\n",
            nrow(plan), nrow(metric_map), output_root))
