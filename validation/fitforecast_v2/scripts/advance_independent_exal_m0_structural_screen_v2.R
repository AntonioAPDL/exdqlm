#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite", "rpart")) {
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
                 "independent_exal_m0_structural_screen_v2.R"))

from_stage <- get_arg("--from")
run_tag <- get_arg("--run-tag")
materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg("--output-root"), winslash = "/", mustWork = FALSE)
if (is.null(from_stage) || !from_stage %in% c("wave1", "wave2", "wave3", "sealed") ||
    is.null(run_tag) || !nzchar(run_tag)) {
  stop("--from {wave1|wave2|wave3|sealed}, --run-tag, --materialization-root, and --output-root are required.")
}
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

stub <- file.path(repo_root, "config", "validation", qdesn_ssv2_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
targets$parent_request_path <- vapply(targets$parent_request_path, function(path) {
  if (grepl("^/", path)) path else file.path(repo_root, path)
}, character(1L))
parents <- qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
wave1_profiles <- qdesn_ssv2_read_csv(paste0(stub, "_wave1_profiles.csv"))
history <- qdesn_ssv2_read_csv(paste0(stub, "_history_signature_ledger.csv"))
universe <- qdesn_ssv2_read_csv(file.path(materialization_root, "virtual_candidate_universe.csv"))
source_roots <- qdesn_ssv2_read_csv(file.path(materialization_root, "source_root_registry.csv"))
source_registry_path <- file.path(materialization_root, "source_root_registry.csv")
target_map <- split(targets, targets$target_cell_id)

plan_path <- function(stage) {
  initial <- file.path(materialization_root, paste0(stage, "_plan.csv"))
  adaptive <- file.path(output_root, paste0(stage, "_plan.csv"))
  if (file.exists(adaptive)) adaptive else initial
}

collect_stage <- function(stage) {
  plan <- qdesn_ssv2_read_csv(plan_path(stage))
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else list(status = "MISSING")
    value <- qdesn_ssv2_metric_value(root, plan$objective_metric[[i]])
    data.frame(
      stage = stage, job_id = plan$job_id[[i]], target_cell_id = plan$target_cell_id[[i]],
      candidate_id = plan$candidate_id[[i]], source_id = plan$source_id[[i]],
      source_role = plan$source_role[[i]], status = as.character(status$status %||% "MISSING"),
      objective_metric = plan$objective_metric[[i]], objective_value = value,
      current_value = plan$current_value[[i]], comparator_value = plan$comparator_value[[i]],
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
      binary_payloads_remaining = as.integer(status$binary_payloads_remaining %||% NA_integer_),
      config_path = plan$config_path[[i]], stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

current <- collect_stage(from_stage)
current_path <- qdesn_ssv2_write_csv(current, file.path(output_root,
                                                         paste0(from_stage, "_collected_results.csv")))
artifact_ok <- current$status == "SUCCESS" & is.finite(current$objective_value) &
  current$binary_payloads_remaining == 0L
gate <- data.frame(
  stage = from_stage, expected_jobs = nrow(current), successful_jobs = sum(current$status == "SUCCESS"),
  finite_metric_jobs = sum(is.finite(current$objective_value)),
  storage_clean_jobs = sum(current$binary_payloads_remaining == 0L, na.rm = TRUE),
  complete_artifact_jobs = sum(artifact_ok), failed_jobs = sum(current$status == "FAIL"),
  missing_jobs = sum(current$status == "MISSING"), gate_pass = all(artifact_ok),
  stringsAsFactors = FALSE
)
gate_path <- qdesn_ssv2_write_csv(gate, file.path(output_root, paste0(from_stage, "_gate.csv")))
if (!all(artifact_ok)) {
  stop(sprintf("%s advancement gate failed: %d/%d complete finite storage-light jobs.",
               from_stage, sum(artifact_ok), length(artifact_ok)), call. = FALSE)
}

profile_from_config <- function(path) {
  job <- qdesn_ssv2_read_json(path)
  x <- as.data.frame(job$profile, stringsAsFactors = FALSE)
  x$candidate_id <- job$candidate_id
  x$target_cell_id <- job$target_cell_id
  x
}

aggregate_results <- function(stages) {
  x <- do.call(rbind, lapply(stages, collect_stage))
  x <- x[is.finite(x$objective_value), , drop = FALSE]
  stats::aggregate(
    cbind(objective_value, elapsed_seconds) ~ target_cell_id + candidate_id +
      objective_metric + current_value + comparator_value,
    data = x, FUN = mean
  )
}

window_cache <- new.env(parent = emptyenv())
window_rows <- list()
resolve_window <- function(profile, target, source_id) {
  key <- paste(source_id, target$family[[1L]], sprintf("%.2f", target$tau[[1L]]),
               profile$m[[1L]], profile$washout[[1L]], sep = "|")
  if (exists(key, envir = window_cache, inherits = FALSE)) return(get(key, envir = window_cache))
  root <- source_roots[
    source_roots$source_id == source_id & source_roots$family == target$family[[1L]] &
      abs(source_roots$tau - target$tau[[1L]]) < 1e-10, , drop = FALSE
  ]
  if (nrow(root) != 1L) stop(sprintf("Missing source root: %s", key), call. = FALSE)
  staged <- qdesn_ssv2_stage_source_window(
    root, source_id, profile$m[[1L]], profile$washout[[1L]],
    file.path(repo_root, "results", "qdesn_mcmc_validation", qdesn_ssv2_stage,
              "staged_source_windows")
  )
  assign(key, staged, envir = window_cache)
  window_rows[[length(window_rows) + 1L]] <<- staged
  staged
}

write_job <- function(profile, target, source_id, stage, chain_id = 1L) {
  source <- resolve_window(profile, target, source_id)
  job <- qdesn_ssv2_make_job(repo_root, profile, target, source, stage,
                             source_registry_path, chain_id)
  path <- file.path(output_root, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  data.frame(
    job_id = job$job_id, stage = stage, target_cell_id = job$target_cell_id,
    candidate_id = job$candidate_id, chain_id = job$chain_id, source_id = job$source_id,
    source_role = job$source_role, objective_metric = job$objective_metric,
    current_value = job$current_value, comparator_value = job$comparator_value,
    config_path = path, config_sha256 = qdesn_ssv2_sha256(path),
    expected_n_burn = job$config$inference$mcmc$n_burn,
    expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
    stringsAsFactors = FALSE
  )
}

profile_lookup <- function(candidate_ids, stage) {
  plan <- qdesn_ssv2_read_csv(plan_path(stage))
  do.call(rbind, lapply(candidate_ids, function(id) {
    path <- plan$config_path[match(id, plan$candidate_id)]
    profile_from_config(path)
  }))
}

write_plan <- function(profiles, stage, source_ids, include_parents = FALSE) {
  rows <- list(); k <- 0L
  for (i in seq_len(nrow(profiles))) {
    target <- target_map[[profiles$target_cell_id[[i]]]]
    for (source_id in source_ids) {
      k <- k + 1L
      rows[[k]] <- write_job(profiles[i, , drop = FALSE], target, source_id, stage)
    }
  }
  if (include_parents) {
    for (i in seq_len(nrow(parents))) {
      target <- target_map[[parents$target_cell_id[[i]]]]
      for (source_id in source_ids) {
        k <- k + 1L
        rows[[k]] <- write_job(parents[i, , drop = FALSE], target, source_id, stage)
      }
    }
  }
  plan <- do.call(rbind, rows)
  qdesn_ssv2_write_csv(plan, file.path(output_root, paste0(stage, "_plan.csv")))
  plan
}

if (from_stage == "wave1") {
  summary <- aggregate_results("wave1")
  survivors <- do.call(rbind, lapply(split(summary, summary$target_cell_id), function(cell) {
    target <- target_map[[cell$target_cell_id[[1L]]]]
    cell <- cell[!grepl("_parent$", cell$candidate_id), , drop = FALSE]
    cell <- cell[order(cell$objective_value, cell$candidate_id), , drop = FALSE]
    utils::head(cell, target$survivors_wave2[[1L]])
  }))
  profiles <- profile_lookup(survivors$candidate_id, "wave1")
  qdesn_ssv2_write_csv(survivors, file.path(output_root, "wave2_survivor_ranking.csv"))
  qdesn_ssv2_write_csv(profiles, file.path(output_root, "wave2_survivor_profiles.csv"))
  plan <- write_plan(profiles, "wave2", c("dev09", "dev10", "dev11"), include_parents = TRUE)
  if (nrow(plan) != 165L) stop("Wave-2 plan must contain 165 jobs.", call. = FALSE)
} else if (from_stage == "wave2") {
  summary <- aggregate_results(c("wave1", "wave2"))
  tested_profiles <- do.call(rbind, lapply(unique(summary$candidate_id), function(id) {
    stage <- if (id %in% qdesn_ssv2_read_csv(plan_path("wave2"))$candidate_id) "wave2" else "wave1"
    profile_lookup(id, stage)
  }))
  adaptive <- list(); k <- 0L
  for (cell_id in targets$target_cell_id) {
    target <- target_map[[cell_id]]
    y <- summary[summary$target_cell_id == cell_id & !grepl("_parent$", summary$candidate_id), , drop = FALSE]
    x <- tested_profiles[tested_profiles$target_cell_id == cell_id, , drop = FALSE]
    x <- x[x$candidate_id %in% y$candidate_id, , drop = FALSE]
    y <- y[match(x$candidate_id, y$candidate_id), , drop = FALSE]
    train <- cbind(.qdesn_ssv2_features(x), objective_ratio = y$objective_value / y$current_value)
    fit <- tryCatch(rpart::rpart(
      objective_ratio ~ ., data = train, method = "anova",
      control = rpart::rpart.control(cp = 0.001, minsplit = 4L, maxdepth = 4L)
    ), error = function(e) NULL)
    pool <- universe[
      !universe$profile_signature %in% c(history$profile_signature, tested_profiles$profile_signature),
      , drop = FALSE
    ]
    prediction <- if (is.null(fit)) rep(mean(train$objective_ratio), nrow(pool)) else
      as.numeric(stats::predict(fit, newdata = .qdesn_ssv2_features(pool)))
    pool$predicted_objective_ratio <- prediction
    cutoff <- stats::quantile(prediction, .15, na.rm = TRUE)
    promising <- pool[is.finite(prediction) & prediction <= cutoff, , drop = FALSE]
    n_pick <- target$adaptive_wave3[[1L]]
    picked <- .qdesn_ssv2_maximin(promising, x, n_pick,
                                  offset = qdesn_ssv2_seed(cell_id, "wave3") %% nrow(promising))
    picked$target_cell_id <- cell_id; picked$family <- target$family[[1L]]
    picked$tau <- target$tau[[1L]]; picked$priority <- target$priority[[1L]]
    picked$objective_metric <- target$objective_metric[[1L]]
    picked$current_value <- target$current_value[[1L]]
    picked$comparator_value <- target$comparator_value[[1L]]
    picked$parent_anchor_id <- target$parent_anchor_id[[1L]]
    picked$selection_arm <- "adaptive_rpart_maximin"
    picked$design_role <- "new_surrogate_guided_structural_candidate"
    picked$candidate_id <- sprintf(
      "ssv2_%s_adaptive_%02d_%s", qdesn_ssv2_safe(cell_id), seq_len(nrow(picked)),
      substr(vapply(picked$profile_signature, digest::digest, character(1L),
                    algo = "sha256", serialize = FALSE), 1L, 10L)
    )
    picked$screening_profile_id <- picked$candidate_id
    k <- k + 1L; adaptive[[k]] <- picked
  }
  profiles <- do.call(rbind, adaptive)
  qdesn_ssv2_write_csv(profiles, file.path(output_root, "wave3_adaptive_profiles.csv"))
  plan <- write_plan(profiles, "wave3", c("dev09", "dev10", "dev11"), include_parents = FALSE)
  if (nrow(plan) != 72L) stop("Wave-3 plan must contain 72 jobs.", call. = FALSE)
} else if (from_stage == "wave3") {
  summary <- aggregate_results(c("wave2", "wave3"))
  finalists <- do.call(rbind, lapply(split(summary, summary$target_cell_id), function(cell) {
    target <- target_map[[cell$target_cell_id[[1L]]]]
    cell <- cell[!grepl("_parent$", cell$candidate_id), , drop = FALSE]
    cell <- cell[order(cell$objective_value, cell$candidate_id), , drop = FALSE]
    utils::head(cell, target$finalists_sealed[[1L]])
  }))
  wave2_ids <- qdesn_ssv2_read_csv(plan_path("wave2"))$candidate_id
  profiles <- do.call(rbind, lapply(finalists$candidate_id, function(id) {
    profile_lookup(id, if (id %in% wave2_ids) "wave2" else "wave3")
  }))
  qdesn_ssv2_write_csv(finalists, file.path(output_root, "sealed_finalist_ranking.csv"))
  qdesn_ssv2_write_csv(profiles, file.path(output_root, "sealed_finalist_profiles.csv"))
  plan <- write_plan(profiles, "sealed", c("dev09", "dev10", "dev11", "dev12"),
                     include_parents = TRUE)
  if (nrow(plan) != 76L) stop("Sealed plan must contain 76 jobs.", call. = FALSE)
} else {
  summary <- aggregate_results("sealed")
  finalists <- do.call(rbind, lapply(split(summary, summary$target_cell_id), function(cell) {
    cell <- cell[!grepl("_parent$", cell$candidate_id), , drop = FALSE]
    cell[order(cell$objective_value, cell$candidate_id), , drop = FALSE][1L, , drop = FALSE]
  }))
  sealed_profiles <- qdesn_ssv2_read_csv(file.path(output_root, "sealed_finalist_profiles.csv"))
  profiles <- sealed_profiles[match(finalists$candidate_id, sealed_profiles$candidate_id), , drop = FALSE]
  confirmation <- do.call(rbind, lapply(seq_len(nrow(profiles)), function(i) {
    do.call(rbind, lapply(1:3, function(chain) data.frame(
      target_cell_id = profiles$target_cell_id[[i]], candidate_id = profiles$candidate_id[[i]],
      chain_id = chain, canonical_source_registry_hash_value = qdesn_ssv2_registry_hash,
      n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
      inference_method_id = "M0_v_collapsed_support_logit",
      launch_approved = FALSE,
      blocking_gate = "explicit_human_approval_and_canonical_source_materialization",
      stringsAsFactors = FALSE
    )))
  }))
  qdesn_ssv2_write_csv(finalists, file.path(output_root, "sealed_closeout_ranking.csv"))
  qdesn_ssv2_write_csv(profiles, file.path(output_root, "canonical_confirmation_profiles.csv"))
  qdesn_ssv2_write_csv(confirmation, file.path(output_root, "canonical_confirmation_plan.csv"))
  if (nrow(confirmation) != 21L) stop("Expected one cell winner times three chains (21 jobs).")
}

if (length(window_rows)) {
  qdesn_ssv2_write_csv(unique(do.call(rbind, window_rows)),
                       file.path(output_root, paste0("windows_materialized_after_", from_stage, ".csv")))
}
manifest <- list(
  generated_at = as.character(Sys.time()), from_stage = from_stage,
  run_tag = run_tag, input_results_path = current_path, gate_path = gate_path,
  input_results_sha256 = qdesn_ssv2_sha256(current_path), gate_sha256 = qdesn_ssv2_sha256(gate_path),
  decision = if (from_stage == "sealed") "confirmation_manifest_only_wait_for_human_approval" else
    paste0("advance_to_", switch(from_stage, wave1 = "wave2", wave2 = "wave3", wave3 = "sealed")),
  article_state = "unchanged"
)
qdesn_ssv2_write_json(manifest, file.path(output_root, paste0("advance_after_", from_stage, ".json")))
cat(sprintf("advance_after=%s complete_artifacts=%d/%d\n", from_stage,
            sum(artifact_ok), length(artifact_ok)))
