#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop(sprintf("Missing package: %s", pkg))
  }
})
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_forecast_gap_adaptive_mcmc_v1.R"))
from_stage <- get_arg("--from")
run_tag <- get_arg("--run-tag")
materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg("--output-root"), winslash = "/",
                             mustWork = FALSE)
if (!from_stage %in% c(
  "discovery", "replication", "sealed"
) || is.null(run_tag) || !nzchar(run_tag)) {
  stop("Valid --from, --run-tag, --materialization-root, and --output-root are required.")
}
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

stub <- file.path(repo_root, "config", "validation", qdesn_fgav1_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
parents <- qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
parents <- parents[parents$target_cell_id %in% targets$target_cell_id, , drop = FALSE]
source_roots <- qdesn_ssv2_read_csv(file.path(
  materialization_root, "source_root_registry.csv"
))
source_registry_path <- file.path(materialization_root, "source_root_registry.csv")
target_map <- split(targets, targets$target_cell_id)

plan_path <- function(stage) {
  candidates <- c(
    file.path(output_root, paste0(stage, "_plan.csv")),
    file.path(materialization_root, paste0(stage, "_plan.csv"))
  )
  found <- candidates[file.exists(candidates)]
  if (!length(found)) stop(sprintf("No plan for %s.", stage), call. = FALSE)
  found[[1L]]
}

collect_stage <- function(stage) {
  plan <- qdesn_ssv2_read_csv(plan_path(stage))
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    root <- qdesn_fgav1_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
      list(status = "MISSING", binary_payloads_remaining = NA_integer_)
    metrics <- qdesn_fgav1_metric_values(root)
    data.frame(
      stage = stage, job_id = plan$job_id[[i]], tier = plan$tier[[i]],
      target_cell_id = plan$target_cell_id[[i]],
      likelihood_target = plan$likelihood_target[[i]],
      candidate_id = plan$candidate_id[[i]], source_id = plan$source_id[[i]],
      reservoir_seed_id = plan$reservoir_seed_id[[i]],
      status = as.character(status$status %||% "MISSING"),
      fit_qtrue_rmse = metrics[["fit_qtrue_rmse"]],
      forecast_qtrue_mae_H1000 = metrics[["forecast_qtrue_mae_H1000"]],
      forecast_check_loss_H1000 = metrics[["forecast_check_loss_H1000"]],
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
      binary_payloads_remaining =
        as.integer(status$binary_payloads_remaining %||% NA_integer_),
      config_path = plan$config_path[[i]], stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

current <- collect_stage(from_stage)
current_path <- qdesn_ssv2_write_csv(
  current, file.path(output_root, paste0(from_stage, "_collected_results.csv"))
)
required_finite <- vapply(seq_len(nrow(current)), function(i) {
  target <- target_map[[current$target_cell_id[[i]]]]
  metrics <- strsplit(target$target_metrics[[1L]], ";", fixed = TRUE)[[1L]]
  all(is.finite(as.numeric(current[i, metrics, drop = TRUE])))
}, logical(1L))
artifact_ok <- current$status == "SUCCESS" & required_finite &
  current$binary_payloads_remaining == 0L
gate <- data.frame(
  stage = from_stage, expected_jobs = nrow(current),
  successful_jobs = sum(current$status == "SUCCESS"),
  finite_required_metric_jobs = sum(required_finite),
  storage_clean_jobs = sum(current$binary_payloads_remaining == 0L, na.rm = TRUE),
  complete_artifact_jobs = sum(artifact_ok), failed_jobs = sum(current$status == "FAIL"),
  missing_jobs = sum(current$status == "MISSING"), gate_pass = all(artifact_ok),
  stringsAsFactors = FALSE
)
gate_path <- qdesn_ssv2_write_csv(
  gate, file.path(output_root, paste0(from_stage, "_gate.csv"))
)
if (!all(artifact_ok)) {
  stop(sprintf("%s gate failed: %d/%d complete jobs.", from_stage,
               sum(artifact_ok), length(artifact_ok)), call. = FALSE)
}

stages <- switch(from_stage,
  discovery = "discovery",
  replication = c("discovery", "replication"),
  sealed = "sealed"
)
evidence <- do.call(rbind, lapply(stages, collect_stage))
evidence <- evidence[evidence$status == "SUCCESS", , drop = FALSE]

paired_rows <- list()
k <- 0L
for (cell_id in targets$target_cell_id) {
  cell <- evidence[evidence$target_cell_id == cell_id, , drop = FALSE]
  parent_id <- paste0("fgav1_", cell_id, "_parent")
  parent <- cell[cell$candidate_id == parent_id, , drop = FALSE]
  candidates <- setdiff(unique(cell$candidate_id), parent_id)
  target_metrics <- strsplit(
    target_map[[cell_id]]$target_metrics[[1L]], ";", fixed = TRUE
  )[[1L]]
  for (candidate_id in candidates) {
    candidate <- cell[cell$candidate_id == candidate_id, , drop = FALSE]
    shared_sources <- intersect(candidate$source_id, parent$source_id)
    for (metric in target_metrics) {
      ratios <- vapply(shared_sources, function(source_id) {
        cv <- candidate[candidate$source_id == source_id, metric][[1L]]
        pv <- parent[parent$source_id == source_id, metric][[1L]]
        as.numeric(cv) / as.numeric(pv)
      }, numeric(1L))
      k <- k + 1L
      paired_rows[[k]] <- data.frame(
        target_cell_id = cell_id, candidate_id = candidate_id, metric = metric,
        source_count = length(ratios), mean_paired_ratio = mean(ratios),
        median_paired_ratio = stats::median(ratios),
        sources_improved = sum(ratios < 1),
        max_paired_ratio = max(ratios),
        stringsAsFactors = FALSE
      )
    }
  }
}
paired <- do.call(rbind, paired_rows)
paired_path <- qdesn_ssv2_write_csv(
  paired, file.path(output_root, paste0(from_stage, "_paired_metric_summary.csv"))
)

select_candidates <- function(cell_id, n_select, minimum_sources) {
  target <- target_map[[cell_id]]
  metrics <- strsplit(target$target_metrics[[1L]], ";", fixed = TRUE)[[1L]]
  cell <- paired[paired$target_cell_id == cell_id, , drop = FALSE]
  candidate_sources <- stats::aggregate(source_count ~ candidate_id, cell, max)
  eligible_ids <- candidate_sources$candidate_id[
    candidate_sources$source_count >= minimum_sources
  ]
  cell <- cell[cell$candidate_id %in% eligible_ids, , drop = FALSE]
  if (!nrow(cell)) {
    stop(sprintf("No candidates for %s have at least %d sources.",
                 cell_id, minimum_sources), call. = FALSE)
  }
  leaders <- unique(vapply(metrics, function(metric) {
    x <- cell[cell$metric == metric, , drop = FALSE]
    x$candidate_id[order(x$mean_paired_ratio, x$median_paired_ratio,
                         x$candidate_id)][[1L]]
  }, character(1L)))
  wide <- reshape(
    cell[, c("candidate_id", "metric", "mean_paired_ratio")],
    idvar = "candidate_id", timevar = "metric", direction = "wide"
  )
  ratio_cols <- grep("^mean_paired_ratio[.]", names(wide), value = TRUE)
  wide$worst_ratio <- apply(wide[, ratio_cols, drop = FALSE], 1L, max, na.rm = TRUE)
  fill <- wide$candidate_id[order(wide$worst_ratio, wide$candidate_id)]
  utils::head(unique(c(leaders, fill)), n_select)
}

profile_from_plan <- function(candidate_id) {
  stages <- c("discovery", "replication", "sealed")
  all_plans <- unique(unlist(lapply(stages, function(stage) {
    candidates <- c(
      file.path(output_root, paste0(stage, "_plan.csv")),
      file.path(materialization_root, paste0(stage, "_plan.csv"))
    )
    candidates[file.exists(candidates)]
  }), use.names = FALSE))
  for (path in all_plans) {
    plan <- qdesn_ssv2_read_csv(path)
    hit <- which(plan$candidate_id == candidate_id)
    if (length(hit)) {
      job <- qdesn_ssv2_read_json(plan$config_path[[hit[[1L]]]])
      return(qdesn_ssv2_profile_from_job(job))
    }
  }
  stop(sprintf("No profile for %s.", candidate_id), call. = FALSE)
}

window_cache <- new.env(parent = emptyenv())
window_rows <- list()
resolve_window <- function(profile, target, source_id) {
  key <- paste(source_id, target$family[[1L]], sprintf("%.2f", target$tau[[1L]]),
               profile$m[[1L]], profile$washout[[1L]], sep = "|")
  if (exists(key, envir = window_cache, inherits = FALSE)) {
    return(get(key, envir = window_cache))
  }
  root <- source_roots[
    source_roots$source_id == source_id &
      source_roots$family == target$family[[1L]] &
      abs(source_roots$tau - target$tau[[1L]]) < 1e-10,
    , drop = FALSE
  ]
  staged <- qdesn_ssv2_stage_source_window(
    root, source_id, profile$m[[1L]], profile$washout[[1L]],
    file.path(repo_root, "results", "qdesn_mcmc_validation",
              qdesn_fgav1_stage, "staged_source_windows")
  )
  assign(key, staged, envir = window_cache)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, source_id, stage, reservoir_seed_id) {
  source <- resolve_window(profile, target, source_id)
  job <- qdesn_fgav1_make_job(
    repo_root, profile, target, source, stage, source_registry_path,
    reservoir_seed_id = reservoir_seed_id
  )
  path <- file.path(output_root, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  data.frame(
    job_id = job$job_id, stage = stage, tier = target$tier[[1L]],
    target_cell_id = job$target_cell_id,
    likelihood_target = target$likelihood_target[[1L]],
    target_metrics = target$target_metrics[[1L]],
    candidate_id = job$candidate_id, chain_id = job$chain_id,
    reservoir_seed_id = job$reservoir_seed_id,
    source_id = job$source_id, source_role = job$source_role,
    objective_metric = job$objective_metric,
    current_value = job$current_value, comparator_value = job$comparator_value,
    config_path = path, config_sha256 = qdesn_ssv2_sha256(path),
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    effective_readout_dimension = job$root_spec$effective_readout_dimension,
    timeout_seconds = job$config$validation$timeout_seconds,
    stringsAsFactors = FALSE
  )
}

write_plan <- function(selected, stage, source_ids, reservoir_seed_id) {
  rows <- list()
  k <- 0L
  for (cell_id in targets$target_cell_id) {
    ids <- selected[[cell_id]]
    profiles <- do.call(rbind, lapply(ids, profile_from_plan))
    parent <- parents[parents$target_cell_id == cell_id, , drop = FALSE]
    parent <- parent[, names(profiles), drop = FALSE]
    profiles <- rbind(profiles, parent)
    for (i in seq_len(nrow(profiles))) {
      for (source_id in source_ids) {
        k <- k + 1L
        rows[[k]] <- write_job(
          profiles[i, , drop = FALSE], target_map[[cell_id]], source_id,
          stage, reservoir_seed_id
        )
      }
    }
  }
  plan <- do.call(rbind, rows)
  qdesn_ssv2_write_csv(plan, file.path(output_root, paste0(stage, "_plan.csv")))
  plan
}

decision <- NULL
if (from_stage == "discovery") {
  selected <- setNames(lapply(
    targets$target_cell_id, select_candidates, n_select = 3L,
    minimum_sources = 2L
  ),
                       targets$target_cell_id)
  ranking <- do.call(rbind, lapply(names(selected), function(cell_id) data.frame(
    target_cell_id = cell_id, rank = seq_along(selected[[cell_id]]),
    candidate_id = selected[[cell_id]], stringsAsFactors = FALSE
  )))
  qdesn_ssv2_write_csv(ranking, file.path(output_root, "replication_ranking.csv"))
  plan <- write_plan(selected, "replication", c("dev39", "dev40"), "r02")
  if (nrow(plan) != 64L) stop("Replication plan must contain 64 jobs.")
  decision <- "advance_to_replication"
} else if (from_stage == "replication") {
  selected <- setNames(lapply(
    targets$target_cell_id, select_candidates, n_select = 2L,
    minimum_sources = 4L
  ),
                       targets$target_cell_id)
  ranking <- do.call(rbind, lapply(names(selected), function(cell_id) data.frame(
    target_cell_id = cell_id, rank = seq_along(selected[[cell_id]]),
    candidate_id = selected[[cell_id]], stringsAsFactors = FALSE
  )))
  qdesn_ssv2_write_csv(ranking, file.path(output_root, "sealed_ranking.csv"))
  plan <- write_plan(
    selected, "sealed", c("dev41", "dev42", "dev43", "dev44"), "r03"
  )
  if (nrow(plan) != 96L) stop("Sealed plan must contain 96 jobs.")
  decision <- "advance_to_sealed"
} else {
  eligible <- do.call(rbind, lapply(targets$target_cell_id, function(cell_id) {
    metrics <- strsplit(
      target_map[[cell_id]]$target_metrics[[1L]], ";", fixed = TRUE
    )[[1L]]
    do.call(rbind, lapply(metrics, function(metric) {
      x <- paired[paired$target_cell_id == cell_id & paired$metric == metric, , drop = FALSE]
      x <- x[x$mean_paired_ratio < 1 & x$median_paired_ratio < 1 &
               x$sources_improved >= 3L, , drop = FALSE]
      if (!nrow(x)) return(NULL)
      x[order(x$mean_paired_ratio, x$median_paired_ratio,
              x$candidate_id), , drop = FALSE][1L, , drop = FALSE]
    }))
  }))
  if (is.null(eligible)) eligible <- paired[FALSE, , drop = FALSE]
  confirmation_schema <- data.frame(
    target_cell_id = character(), metric = character(), candidate_id = character(),
    chain_id = integer(), n_burn = integer(), n_mcmc = integer(), thin = integer(),
    canonical_source_registry_hash_value = character(), launch_approved = logical(),
    blocking_gate = character(), stringsAsFactors = FALSE
  )
  confirmation <- if (nrow(eligible)) do.call(rbind, lapply(seq_len(nrow(eligible)), function(i) {
    do.call(rbind, lapply(1:3, function(chain) data.frame(
      target_cell_id = eligible$target_cell_id[[i]],
      metric = eligible$metric[[i]], candidate_id = eligible$candidate_id[[i]],
      chain_id = chain, n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
      canonical_source_registry_hash_value = qdesn_ssv2_registry_hash,
      launch_approved = TRUE,
      blocking_gate = "canonical_source_materialization_and_clean_synced_branch",
      stringsAsFactors = FALSE
    )))
  })) else confirmation_schema
  qdesn_ssv2_write_csv(
    eligible, file.path(output_root, "sealed_eligible_metrics.csv")
  )
  qdesn_ssv2_write_csv(
    confirmation, file.path(output_root, "confirmation_handoff.csv")
  )
  if (nrow(confirmation) > 42L) stop("Confirmation exceeds the 42-chain cap.")
  decision <- if (nrow(confirmation)) "advance_to_canonical_confirmation" else
    "no_sealed_forecast_gain_retain_v7"
}

if (length(window_rows)) {
  qdesn_ssv2_write_csv(
    unique(do.call(rbind, window_rows)),
    file.path(output_root, paste0("windows_materialized_after_", from_stage, ".csv"))
  )
}
manifest <- list(
  schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_advancement_v1",
  generated_at = as.character(Sys.time()), from_stage = from_stage,
  run_tag = run_tag, input_results_path = current_path,
  input_results_sha256 = qdesn_ssv2_sha256(current_path),
  gate_path = gate_path, gate_sha256 = qdesn_ssv2_sha256(gate_path),
  paired_summary_path = paired_path,
  paired_summary_sha256 = qdesn_ssv2_sha256(paired_path),
  decision = decision, article_state = "v7_frozen_unchanged"
)
qdesn_ssv2_write_json(
  manifest, file.path(output_root, paste0("advance_after_", from_stage, ".json"))
)
cat(sprintf("advance_after=%s decision=%s complete=%d/%d\n",
            from_stage, decision, sum(artifact_ok), length(artifact_ok)))
