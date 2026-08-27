#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing package: ", pkg)
  }
})
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
setwd(repo)
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2.R"
))
phase <- match.arg(arg("--phase", "discovery"),
                   c("discovery", "replication", "final"))
run_tag <- arg("--run-tag")
mat <- normalizePath(arg("--materialization-root"), winslash = "/", mustWork = TRUE)
out <- normalizePath(arg("--output-root", file.path(mat, "closeout")),
                     winslash = "/", mustWork = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
targets <- idol_v2_read_targets(repo)
target_map <- split(targets, targets$target_cell_id)
candidates <- qdesn_ssv2_read_csv(file.path(mat, "candidate_profiles.csv"))
initial_candidates <- qdesn_ssv2_read_csv(
  file.path(mat, "initial_replication_candidates.csv")
)
registry <- qdesn_ssv2_read_csv(file.path(mat, "canonical_source_registry.csv"))
windows <- qdesn_ssv2_read_csv(file.path(mat, "source_window_registry.csv"))

collect_plan <- function(name) {
  path <- file.path(mat, paste0(name, "_plan.csv"))
  if (!file.exists(path)) return(data.frame())
  plan <- qdesn_ssv2_read_csv(path)
  if (!nrow(plan)) return(plan)
  do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    idol_v2_collect_result(repo, run_tag, plan[i, , drop = FALSE])
  }))
}

current_value <- function(target, metric) {
  as.numeric(target[[paste0("current_", metric)]][[1L]])
}

source_for <- function(profile, target) {
  z <- windows[
    windows$family == target$family[[1L]] &
      abs(windows$tau - target$tau[[1L]]) < 1e-10 &
      windows$m == as.integer(profile$m[[1L]]) &
      windows$washout == as.integer(profile$washout[[1L]]), , drop = FALSE
  ]
  if (!nrow(z)) stop("No staged source window for follow-up job.", call. = FALSE)
  z[1L, , drop = FALSE]
}

registry_path <- file.path(mat, "canonical_source_registry.csv")
write_job <- function(profile, target, stage, chain_id, reservoir_seed_id) {
  job <- idol_v2_make_job(
    repo, profile, target, source_for(profile, target), stage,
    registry_path, chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job <- idol_v2_apply_seeds(job)
  config_path <- file.path(mat, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, config_path)
  idol_v2_plan_row(job, config_path)
}

bind_artifact <- function(results, column, ids) {
  if (!nrow(results)) return(data.frame())
  rows <- lapply(seq_len(nrow(results)), function(i) {
    path <- results[[column]][[i]]
    if (!file.exists(path)) return(NULL)
    x <- qdesn_ssv2_read_csv(path)
    for (nm in ids) x[[nm]] <- results[[nm]][[i]]
    x
  })
  rows <- Filter(function(x) !is.null(x) && nrow(x), rows)
  if (!length(rows)) return(data.frame())
  fields <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (field in setdiff(fields, names(x))) x[[field]] <- NA
    x[, fields, drop = FALSE]
  })
  do.call(rbind, rows)
}

write_common <- function(results, prefix) {
  qdesn_ssv2_write_csv(results, file.path(out, paste0(prefix, "_point_metrics.csv")))
  ids <- c("job_id", "target_cell_id", "candidate_id", "profile_role",
           "transform_mode", "rhs_tau0", "chain_id", "reservoir_seed_id")
  qdesn_ssv2_write_csv(
    bind_artifact(results, "metric_interval_summary_path", ids),
    file.path(out, paste0(prefix, "_posterior_metric_intervals.csv"))
  )
  qdesn_ssv2_write_csv(
    bind_artifact(results, "transform_diagnostics_path", ids),
    file.path(out, paste0(prefix, "_transform_diagnostics.csv"))
  )
  qdesn_ssv2_write_csv(
    bind_artifact(results, "design_conditioning_path", ids),
    file.path(out, paste0(prefix, "_conditioning_diagnostics.csv"))
  )
}

if (phase == "discovery") {
  initial <- collect_plan("initial_replication")
  screen <- collect_plan("screen")
  write_common(initial, "initial_replication")
  write_common(screen, "screen")
  if (!all(initial$status == "SUCCESS") || !all(screen$status == "SUCCESS")) {
    stop("Discovery closeout requires all initial-replication and screen jobs.",
         call. = FALSE)
  }

  initial_decisions <- list()
  target <- target_map[["al_normal_t0p05"]]
  for (metric in idol_v2_promotion_metrics) {
    candidate_mean <- mean(initial[
      initial$profile_role == "R0_v1_tau1e09", metric
    ])
    control_mean <- mean(initial[initial$profile_role == "C0_parent", metric])
    authority <- current_value(target, metric)
    initial_decisions[[length(initial_decisions) + 1L]] <- data.frame(
      target_cell_id = target$target_cell_id, metric = metric,
      candidate_id = unique(initial$candidate_id[
        initial$profile_role == "R0_v1_tau1e09"
      ]),
      candidate_mean = candidate_mean, matched_control_mean = control_mean,
      authority_value = authority,
      improves_control = candidate_mean < control_mean - idol_v2_reconstruction_tolerance,
      improves_authority = candidate_mean < authority - idol_v2_reconstruction_tolerance,
      advances_to_confirmation =
        candidate_mean < control_mean - idol_v2_reconstruction_tolerance &&
        candidate_mean < authority - idol_v2_reconstruction_tolerance,
      stringsAsFactors = FALSE
    )
  }
  initial_decisions <- do.call(rbind, initial_decisions)
  qdesn_ssv2_write_csv(
    initial_decisions, file.path(out, "initial_replication_metric_decisions.csv")
  )

  ranking_rows <- list()
  selected_rows <- list()
  for (cell_id in targets$target_cell_id) {
    target <- target_map[[cell_id]]
    cell <- screen[
      screen$target_cell_id == cell_id & screen$status == "SUCCESS", , drop = FALSE
    ]
    for (metric in idol_v2_promotion_metrics) {
      authority <- current_value(target, metric)
      z <- cell[is.finite(cell[[metric]]), , drop = FALSE]
      z <- z[order(z[[metric]], z$candidate_id), , drop = FALSE]
      z$metric <- metric
      z$rank <- seq_len(nrow(z))
      z$authority_value <- authority
      z$delta <- z[[metric]] - authority
      z$strict_improvement <- z[[metric]] < authority -
        idol_v2_reconstruction_tolerance
      ranking_rows[[length(ranking_rows) + 1L]] <- z
      transformed <- z[z$transform_mode != "none" & z$strict_improvement,
                       , drop = FALSE]
      if (nrow(transformed)) {
        selected_rows[[length(selected_rows) + 1L]] <- transformed[1L, , drop = FALSE]
      }
    }
  }
  rankings <- do.call(rbind, ranking_rows)
  selected <- if (length(selected_rows)) do.call(rbind, selected_rows) else
    rankings[0L, , drop = FALSE]
  qdesn_ssv2_write_csv(rankings, file.path(out, "screen_cell_metric_rankings.csv"))
  qdesn_ssv2_write_csv(selected, file.path(out, "screen_replication_selection.csv"))

  selected_ids <- unique(selected$candidate_id)
  affected_cells <- unique(selected$target_cell_id)
  plan_rows <- list()
  for (candidate_id in selected_ids) {
    profile <- candidates[candidates$candidate_id == candidate_id, , drop = FALSE]
    target <- target_map[[profile$target_cell_id[[1L]]]]
    for (chain in 2:3) {
      plan_rows[[length(plan_rows) + 1L]] <- write_job(
        profile, target, "replication", chain,
        sprintf("replication_r%02d", chain)
      )
    }
  }
  for (cell_id in affected_cells) {
    profile <- candidates[
      candidates$target_cell_id == cell_id &
        candidates$selection_arm == "C0_parent", , drop = FALSE
    ]
    target <- target_map[[cell_id]]
    for (chain in 2:3) {
      plan_rows[[length(plan_rows) + 1L]] <- write_job(
        profile, target, "replication", chain,
        sprintf("replication_r%02d", chain)
      )
    }
  }
  plan <- if (length(plan_rows)) do.call(rbind, plan_rows) else {
    template <- qdesn_ssv2_read_csv(file.path(mat, "screen_plan.csv"))
    template[0L, , drop = FALSE]
  }
  qdesn_ssv2_write_csv(plan, file.path(mat, "replication_plan.csv"))
  qdesn_ssv2_write_json(list(
    schema_version = "independent_location_orthogonalized_tau0_v2_discovery_decision_v1",
    phase = phase, generated_at = as.character(Sys.time()),
    initial_replication_jobs = nrow(initial), screen_jobs = nrow(screen),
    screen_strict_metric_candidates = nrow(selected),
    adaptive_replication_jobs = nrow(plan),
    initial_confirmation_metrics = sum(initial_decisions$advances_to_confirmation),
    decision = if (nrow(plan) || any(initial_decisions$advances_to_confirmation))
      "ADVANCE_GATED_FOLLOWUP" else "NO_GAIN_CLOSE_AFTER_DISCOVERY"
  ), file.path(out, "discovery_decision.json"))
}

if (phase == "replication") {
  replication <- collect_plan("replication")
  write_common(replication, "replication")
  if (nrow(replication) && !all(replication$status == "SUCCESS")) {
    stop("Replication closeout requires all planned jobs.", call. = FALSE)
  }
  selected <- qdesn_ssv2_read_csv(file.path(out, "screen_replication_selection.csv"))
  decisions <- list()
  if (nrow(selected)) {
    for (i in seq_len(nrow(selected))) {
      candidate_id <- selected$candidate_id[[i]]
      cell_id <- selected$target_cell_id[[i]]
      metric <- selected$metric[[i]]
      target <- target_map[[cell_id]]
      candidate_mean <- mean(replication[
        replication$candidate_id == candidate_id, metric
      ])
      control_mean <- mean(replication[
        replication$target_cell_id == cell_id &
          replication$profile_role == "C0_parent", metric
      ])
      authority <- current_value(target, metric)
      decisions[[length(decisions) + 1L]] <- data.frame(
        target_cell_id = cell_id, metric = metric, candidate_id = candidate_id,
        candidate_mean = candidate_mean, matched_control_mean = control_mean,
        authority_value = authority,
        improves_control = candidate_mean < control_mean - idol_v2_reconstruction_tolerance,
        improves_authority = candidate_mean < authority - idol_v2_reconstruction_tolerance,
        advances_to_confirmation =
          candidate_mean < control_mean - idol_v2_reconstruction_tolerance &&
          candidate_mean < authority - idol_v2_reconstruction_tolerance,
        stringsAsFactors = FALSE
      )
    }
  }
  decisions <- if (length(decisions)) do.call(rbind, decisions) else
    data.frame(target_cell_id = character(), metric = character(),
               candidate_id = character(), candidate_mean = numeric(),
               matched_control_mean = numeric(), authority_value = numeric(),
               improves_control = logical(), improves_authority = logical(),
               advances_to_confirmation = logical())
  qdesn_ssv2_write_csv(decisions, file.path(out, "replication_metric_decisions.csv"))
  initial_decisions <- qdesn_ssv2_read_csv(
    file.path(out, "initial_replication_metric_decisions.csv")
  )
  advance <- rbind(
    initial_decisions[initial_decisions$advances_to_confirmation, , drop = FALSE],
    decisions[decisions$advances_to_confirmation, , drop = FALSE]
  )
  qdesn_ssv2_write_csv(advance, file.path(out, "confirmation_selection.csv"))
  selected_ids <- unique(advance$candidate_id)
  affected_cells <- unique(advance$target_cell_id)
  all_profiles <- rbind(candidates, initial_candidates)
  plan_rows <- list()
  for (candidate_id in selected_ids) {
    profile <- all_profiles[all_profiles$candidate_id == candidate_id, , drop = FALSE]
    target <- target_map[[profile$target_cell_id[[1L]]]]
    for (chain in 1:3) {
      plan_rows[[length(plan_rows) + 1L]] <- write_job(
        profile, target, "confirmation", chain,
        sprintf("confirmation_r%02d", chain)
      )
    }
  }
  for (cell_id in affected_cells) {
    profile <- candidates[
      candidates$target_cell_id == cell_id &
        candidates$selection_arm == "C0_parent", , drop = FALSE
    ]
    target <- target_map[[cell_id]]
    for (chain in 1:3) {
      plan_rows[[length(plan_rows) + 1L]] <- write_job(
        profile, target, "confirmation", chain,
        sprintf("confirmation_r%02d", chain)
      )
    }
  }
  plan <- if (length(plan_rows)) do.call(rbind, plan_rows) else {
    template <- qdesn_ssv2_read_csv(file.path(mat, "screen_plan.csv"))
    template[0L, , drop = FALSE]
  }
  qdesn_ssv2_write_csv(plan, file.path(mat, "confirmation_plan.csv"))
  qdesn_ssv2_write_json(list(
    schema_version = "independent_location_orthogonalized_tau0_v2_replication_decision_v1",
    phase = phase, generated_at = as.character(Sys.time()),
    replication_jobs = nrow(replication), advancing_metric_rows = nrow(advance),
    confirmation_jobs = nrow(plan),
    decision = if (nrow(plan)) "RUN_CANONICAL_CONFIRMATION" else
      "NO_REPLICATED_GAIN_CLOSE_CAMPAIGN"
  ), file.path(out, "replication_decision.json"))
}

if (phase == "final") {
  confirmation <- collect_plan("confirmation")
  write_common(confirmation, "confirmation")
  if (nrow(confirmation) && !all(confirmation$status == "SUCCESS")) {
    stop("Final closeout requires all planned confirmation jobs.", call. = FALSE)
  }
  selection <- qdesn_ssv2_read_csv(file.path(out, "confirmation_selection.csv"))
  promotions <- list()
  if (nrow(selection)) {
    for (i in seq_len(nrow(selection))) {
      candidate_id <- selection$candidate_id[[i]]
      cell_id <- selection$target_cell_id[[i]]
      metric <- selection$metric[[i]]
      target <- target_map[[cell_id]]
      candidate_mean <- mean(confirmation[
        confirmation$candidate_id == candidate_id, metric
      ])
      control_mean <- mean(confirmation[
        confirmation$target_cell_id == cell_id &
          confirmation$profile_role == "C0_parent", metric
      ])
      authority <- current_value(target, metric)
      promotions[[length(promotions) + 1L]] <- data.frame(
        target_cell_id = cell_id, metric = metric, candidate_id = candidate_id,
        three_chain_mean = candidate_mean, matched_control_mean = control_mean,
        authority_value = authority, delta = candidate_mean - authority,
        strict_improvement = candidate_mean < authority -
          idol_v2_reconstruction_tolerance,
        promotion_eligible = is.finite(candidate_mean) &&
          candidate_mean < authority - idol_v2_reconstruction_tolerance,
        stringsAsFactors = FALSE
      )
    }
  }
  promotions <- if (length(promotions)) do.call(rbind, promotions) else
    data.frame(target_cell_id = character(), metric = character(),
               candidate_id = character(), three_chain_mean = numeric(),
               matched_control_mean = numeric(), authority_value = numeric(),
               delta = numeric(), strict_improvement = logical(),
               promotion_eligible = logical())
  qdesn_ssv2_write_csv(promotions, file.path(out, "final_metric_promotion_ledger.csv"))
  result_root <- file.path(repo, "results", "qdesn_mcmc_validation",
                           idol_v2_stage, run_tag)
  binaries <- list.files(
    result_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  qdesn_ssv2_write_csv(data.frame(
    result_root = result_root, retained_binary_payloads = length(binaries),
    retained_binary_bytes = if (length(binaries)) sum(file.info(binaries)$size) else 0,
    storage_contract = if (!length(binaries)) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  ), file.path(out, "storage_audit.csv"))
  eligible <- sum(promotions$promotion_eligible)
  qdesn_ssv2_write_json(list(
    schema_version = "independent_location_orthogonalized_tau0_v2_final_decision_v1",
    phase = phase, generated_at = as.character(Sys.time()),
    confirmation_jobs = nrow(confirmation), promotion_eligible_metrics = eligible,
    retained_binary_payloads = length(binaries), article_update_automatic = FALSE,
    decision = if (eligible > 0L)
      "PROMOTION_CANDIDATES_READY_FOR_INTEGRATION" else
      "NO_CONFIRMED_GAIN_RETAIN_CURRENT_AUTHORITY"
  ), file.path(out, "final_decision.json"))
}

files <- setdiff(list.files(out, recursive = TRUE, full.names = TRUE),
                 file.path(out, "file_manifest.csv"))
manifest <- data.frame(
  path = normalizePath(files, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(files)$size),
  sha256 = vapply(files, qdesn_ssv2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
qdesn_ssv2_write_csv(manifest, file.path(out, "file_manifest.csv"))
cat(sprintf("CLOSEOUT phase=%s output=%s\n", phase, out))
