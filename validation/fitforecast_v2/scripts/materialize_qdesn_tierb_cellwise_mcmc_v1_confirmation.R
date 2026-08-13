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
repo_root <- normalizePath(arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
                           winslash = "/", mustWork = TRUE)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(arg("--output-root", file.path(state_root, "confirmation")),
                             winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_tierb_cellwise_mcmc_v1.R"))

adaptive <- file.path(state_root, "adaptive")
eligible_path <- file.path(adaptive, "tier_b_sealed_eligible_metrics.csv")
handoff_path <- file.path(adaptive, "tier_b_confirmation_manifest.csv")
gate_path <- file.path(adaptive, "tier_b_sealed_gate.csv")
advance_path <- file.path(adaptive, "advance_after_tier_b_sealed.json")
eligible <- qdesn_ssv2_read_csv(eligible_path)
handoff <- qdesn_ssv2_read_csv(handoff_path)
gate <- qdesn_ssv2_read_csv(gate_path)
advance <- qdesn_ssv2_read_json(advance_path)
stub <- file.path(repo_root, "config", "validation", qdesn_tbcv1_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))

checks <- c(
  sealed_gate = nrow(gate) == 1L && isTRUE(gate$gate_pass[[1L]]) &&
    gate$successful_jobs[[1L]] == 48L && gate$failed_jobs[[1L]] == 0L,
  sealed_decision = identical(as.character(advance$decision),
                              "confirmation_manifest_only_wait_for_explicit_approval"),
  eligible = nrow(eligible) >= 1L && nrow(eligible) <= 4L &&
    !anyDuplicated(paste(eligible$target_cell_id, eligible$metric)),
  handoff = nrow(handoff) == 3L * nrow(eligible) &&
    all(table(handoff$target_cell_id) == 3L) &&
    all(!handoff$launch_approved),
  registry = identical(unique(handoff$canonical_source_registry_hash_value),
                       qdesn_ssv2_registry_hash),
  budget = all(handoff$n_burn == 5000L) && all(handoff$n_mcmc == 20000L) &&
    all(handoff$thin == 1L)
)
if (!all(checks)) stop(sprintf("Confirmation handoff failed: %s",
                               paste(names(checks)[!checks], collapse = ", ")))

targets <- targets[match(eligible$target_cell_id, targets$target_cell_id), , drop = FALSE]
profiles <- profiles[match(eligible$candidate_id, profiles$candidate_id), , drop = FALSE]
if (anyNA(targets$target_cell_id) || anyNA(profiles$candidate_id)) {
  stop("Eligible target/profile mapping is incomplete.")
}

source_rows <- vector("list", nrow(targets))
window_rows <- vector("list", nrow(targets))
for (i in seq_len(nrow(targets))) {
  request_path <- normalizePath(file.path(repo_root, targets$parent_request_path[[i]]),
                                winslash = "/", mustWork = TRUE)
  if (!identical(qdesn_ssv2_sha256(request_path), targets$parent_request_sha256[[i]])) {
    stop(sprintf("Frozen parent request drifted for %s.", targets$target_cell_id[[i]]))
  }
  request <- qdesn_ssv2_read_json(request_path)
  series_path <- normalizePath(request$root_spec$source_series_wide_path,
                               winslash = "/", mustWork = TRUE)
  sim_path <- normalizePath(request$root_spec$source_sim_path,
                            winslash = "/", mustWork = TRUE)
  if (!identical(qdesn_ssv2_sha256(series_path), request$root_spec$source_series_wide_sha256) ||
      !identical(qdesn_ssv2_sha256(sim_path), request$root_spec$source_sim_sha256)) {
    stop(sprintf("Canonical source hash drifted for %s.", targets$target_cell_id[[i]]))
  }
  series <- qdesn_ssv2_read_csv(series_path)
  if (nrow(series) != 1890L || !all(c("y", "q_target", "mu") %in% names(series))) {
    stop(sprintf("Canonical source schema failed for %s.", targets$target_cell_id[[i]]))
  }
  # Frozen article windows represent source indices 8111:10000; reconstruct the
  # canonical 1:10000 index before staging each candidate-specific input window.
  full <- series
  full$source_index <- 8111:10000
  source_rows[[i]] <- data.frame(
    source_id = "canonical_article", source_role = "canonical_confirmation",
    scenario = as.character(request$root_spec$scenario %||% request$root_spec$source_scenario),
    family = targets$family[[i]], tau = targets$tau[[i]],
    series_wide_path = series_path,
    series_wide_sha256 = qdesn_ssv2_sha256(series_path),
    sim_output_path = sim_path, sim_output_sha256 = qdesn_ssv2_sha256(sim_path),
    parent_request_path = request_path,
    parent_request_sha256 = qdesn_ssv2_sha256(request_path),
    canonical_registry_hash_value = qdesn_ssv2_registry_hash,
    stringsAsFactors = FALSE
  )
}
source_registry <- do.call(rbind, source_rows)
source_registry_path <- qdesn_ssv2_write_csv(
  source_registry, file.path(output_root, "canonical_source_registry.csv")
)

# The generic stage helper indexes a 10,000-row source. Canonical article files
# are frozen 1,890-row windows, so stage directly using their explicit source indices.
stage_canonical <- function(source_row, profile) {
  series <- qdesn_ssv2_read_csv(source_row$series_wide_path[[1L]])
  all_idx <- 8111:10000
  raw_start <- 8501L - as.integer(profile$m[[1L]]) - as.integer(profile$washout[[1L]])
  keep <- all_idx >= raw_start
  x <- series[keep, , drop = FALSE]
  idx <- all_idx[keep]
  x$source_index <- idx
  x$t <- seq_len(nrow(x))
  dir <- file.path(output_root, "canonical_windows", source_row$family[[1L]],
                   sprintf("tau_%s", sub("[.]", "p", sprintf("%.2f", source_row$tau[[1L]]))),
                   sprintf("m%d_w%d", profile$m[[1L]], profile$washout[[1L]]))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  series_out <- qdesn_ssv2_write_csv(x, file.path(dir, "series_wide.csv"))
  selection <- qdesn_ssv2_write_csv(data.frame(t = seq_len(nrow(x)), source_index = idx),
                                     file.path(dir, "selection_indices.csv"))
  phase1 <- 2 * pi * idx / 90; phase2 <- 4 * pi * idx / 90
  trend <- (idx - mean(idx)) / stats::sd(idx)
  observed <- qdesn_ssv2_write_csv(data.frame(
    y = x$y, period90_sin_h1 = sin(phase1), period90_cos_h1 = cos(phase1),
    period90_sin_h2 = sin(phase2), period90_cos_h2 = cos(phase2),
    period90_trend_z = trend), file.path(dir, "observed.csv"))
  qtrue <- qdesn_ssv2_write_csv(data.frame(
    t = seq_len(nrow(x)), source_index = idx, q_true = x$q_target, y = x$y, mu = x$mu),
    file.path(dir, "q_true.csv"))
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

rows <- list(); windows <- list(); k <- 0L
for (i in seq_len(nrow(eligible))) {
  target <- targets[i, , drop = FALSE]
  profile <- profiles[i, , drop = FALSE]
  source <- stage_canonical(source_registry[i, , drop = FALSE], profile)
  windows[[i]] <- source
  for (chain in 1:3) {
    job <- qdesn_tbcv1_make_job(repo_root, profile, target, source,
                                "tier_b_confirmation", source_registry_path,
                                chain_id = chain, reservoir_seed_id = "canonical_r01")
    job$study_contract$explicit_human_approval <- TRUE
    job$study_contract$approval_instruction <-
      "QDESN_TBCV1_CONFIRMATION_APPROVED=true explicit launch gate"
    job$study_contract$sealed_eligible_metrics_path <- eligible_path
    job$study_contract$sealed_eligible_metrics_sha256 <- qdesn_ssv2_sha256(eligible_path)
    job$study_contract$sealed_gate_path <- gate_path
    job$study_contract$sealed_gate_sha256 <- qdesn_ssv2_sha256(gate_path)
    job$study_contract$canonical_source_materialized <- TRUE
    path <- file.path(output_root, "configs", paste0(job$job_id, ".json"))
    qdesn_ssv2_write_json(job, path)
    k <- k + 1L
    rows[[k]] <- data.frame(
      job_id = job$job_id, stage = job$stage, target_cell_id = job$target_cell_id,
      target_metrics = paste(unlist(job$target_metrics), collapse = ";"),
      metric = eligible$metric[[i]], candidate_id = job$candidate_id,
      chain_id = chain, source_id = job$source_id,
      reservoir_seed_id = job$reservoir_seed_id,
      config_path = normalizePath(path, winslash = "/", mustWork = TRUE),
      config_sha256 = qdesn_ssv2_sha256(path), expected_n_burn = 5000L,
      expected_n_mcmc = 20000L, current_value = target[[paste0("current_", eligible$metric[[i]])]],
      source_registry_hash_value = qdesn_ssv2_registry_hash,
      stringsAsFactors = FALSE
    )
  }
}
plan <- do.call(rbind, rows)
if (nrow(plan) != 3L * nrow(eligible) || nrow(plan) > 12L ||
    any(table(plan$target_cell_id) != 3L) || anyDuplicated(plan$job_id)) {
  stop("Confirmation plan cardinality failed.")
}
plan_path <- qdesn_ssv2_write_csv(plan, file.path(output_root, "confirmation_plan.csv"))
window_path <- qdesn_ssv2_write_csv(do.call(rbind, windows),
                                    file.path(output_root, "canonical_window_registry.csv"))
qdesn_ssv2_write_json(list(
  schema_version = "qdesn_tierb_cellwise_mcmc_v1_confirmation_v1",
  generated_at = as.character(Sys.time()), validation_commit = system("git rev-parse HEAD", intern = TRUE),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  explicit_human_approval = TRUE, confirmation_jobs = nrow(plan),
  chains_per_candidate = 3L,
  n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
  plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
  source_registry = list(path = source_registry_path, sha256 = qdesn_ssv2_sha256(source_registry_path)),
  windows = list(path = window_path, sha256 = qdesn_ssv2_sha256(window_path)),
  eligible = list(path = eligible_path, sha256 = qdesn_ssv2_sha256(eligible_path)),
  article_promotion_automatic = FALSE
), file.path(output_root, "confirmation_materialization_manifest.json"))
cat(sprintf("confirmation_materialized jobs=%d output=%s\n", nrow(plan), output_root))
