#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return(default)
  args[[i + 1L]]
}

action <- value_after("--action")
run_root <- value_after("--run-root")
if (is.null(action) || is.null(run_root)) {
  stop(paste0(
    "Usage: --action <materialize|replication|confirmation|pending|health|",
    "verify|closeout> --run-root PATH [--stage STAGE]"
  ), call. = FALSE)
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
run_root <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2_runtime.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_posterior_forecast_rescue_v1.R"))

if (identical(action, "materialize")) {
  out <- iqpfr_v1_materialize(repo_root, run_root)
  cat(sprintf("pilot_jobs=%d candidates=%d sources=%d\n",
              nrow(out$plan), nrow(out$candidates), nrow(out$sources)))
} else if (identical(action, "replication")) {
  protocol <- iqpfr_v1_read_protocol(repo_root)
  pilot_plan <- file.path(run_root, "plans", "posterior_screen.csv")
  pilot <- iqfr_v2_collect_results(pilot_plan, require_complete = TRUE)
  ranked <- iqpfr_v1_rank_screen(pilot)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "posterior_screen_ranking.csv")
  )
  selected <- ranked[
    ranked$selection_rank <=
      as.integer(protocol$inference$replication$finalists_per_cell),
    , drop = FALSE
  ]
  cell <- interaction(selected$family, selected$tau,
                      selected$likelihood_family, drop = TRUE)
  if (length(unique(cell)) != 17L || any(table(cell) != 3L)) {
    stop("Screening did not retain exactly three candidates in every cell.",
         call. = FALSE)
  }
  selected_path <- iqfr_v2_write_csv(
    selected,
    file.path(run_root, "manifests", "replication_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  contract <- list(
    source_offset = 8110L, train_end = 8800L, rollout_end = 9000L,
    origin_start = 8800L, origin_end = 8970L, origin_stride = 1L,
    horizon = 30L,
    estimators = "posterior_predictive_mean_readout_state",
    export_origin_lead = FALSE
  )
  plan <- iqpfr_v1_make_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    plan_stage = "replication", worker_stage = "mcmc_pilot",
    chain_ids = as.integer(protocol$inference$replication$added_chains),
    budget = protocol$inference$replication, forecast_contract = contract
  )
  expected <- as.integer(protocol$execution$expected_jobs$replication)
  if (nrow(plan) != expected) stop("Replication plan count mismatch.",
                                   call. = FALSE)
  iqfr_v2_write_json(list(
    stage = "replication", jobs = nrow(plan), cells = 17L,
    finalists_per_cell = 3L, added_chains = c(2L, 3L),
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path)
  ), file.path(run_root, "manifests", "replication_materialization.json"))
  cat(sprintf("replication_jobs=%d\n", nrow(plan)))
} else if (identical(action, "confirmation")) {
  protocol <- iqpfr_v1_read_protocol(repo_root)
  pilot <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "posterior_screen.csv"), TRUE
  )
  replication <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "replication.csv"), TRUE
  )
  finalists <- utils::read.csv(
    file.path(run_root, "manifests", "replication_finalists.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  keys <- unique(paste(finalists$family, finalists$tau,
                       finalists$likelihood_family, finalists$candidate_id,
                       sep = "|"))
  pilot_key <- paste(pilot$family, pilot$tau, pilot$likelihood_family,
                     pilot$candidate_id, sep = "|")
  validation <- rbind(pilot[pilot_key %in% keys, , drop = FALSE], replication)
  pooled <- iqpfr_v1_pool_metrics(validation)
  pooled_path <- iqfr_v2_write_csv(
    pooled,
    file.path(run_root, "summaries", "replicated_validation_metrics.csv")
  )
  selected <- iqpfr_v1_select_top(pooled, 1L)
  selected_path <- iqfr_v2_write_csv(
    selected,
    file.path(run_root, "manifests", "confirmation_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  contract <- list(
    source_offset = 8110L,
    train_end = as.integer(protocol$inference$confirmation$train_end),
    rollout_end = as.integer(protocol$inference$confirmation$rollout_end),
    origin_start = as.integer(protocol$inference$confirmation$origins$start),
    origin_end = as.integer(protocol$inference$confirmation$origins$end),
    origin_stride = as.integer(protocol$inference$confirmation$origins$stride),
    horizon = as.integer(protocol$selection$horizon),
    estimators = c(
      "posterior_predictive", "posterior_predictive_mean_readout_state"
    ),
    export_origin_lead = TRUE
  )
  plan <- iqpfr_v1_make_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    plan_stage = "confirmation", worker_stage = "mcmc_confirmation",
    chain_ids = as.integer(protocol$inference$confirmation$chains),
    budget = protocol$inference$confirmation, forecast_contract = contract
  )
  expected <- as.integer(protocol$execution$expected_jobs$confirmation)
  if (nrow(plan) != expected) stop("Confirmation plan count mismatch.",
                                   call. = FALSE)
  iqfr_v2_write_json(list(
    stage = "confirmation", jobs = nrow(plan), cells = 17L,
    finalists_per_cell = 1L, chains = c(1L, 2L, 3L),
    validation_metrics_path = pooled_path,
    validation_metrics_sha256 = iqfr_v2_sha256(pooled_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    sealed_window_first_campaign_access = TRUE,
    origins = 971L, pairs = 29130L
  ), file.path(run_root, "manifests", "confirmation_materialization.json"))
  cat(sprintf("confirmation_jobs=%d\n", nrow(plan)))
} else if (identical(action, "pending")) {
  stage <- value_after("--stage")
  if (is.null(stage)) stop("pending requires --stage.", call. = FALSE)
  plan_path <- file.path(run_root, "plans", paste0(stage, ".csv"))
  pending <- iqpfr_v1_pending_configs(plan_path)
  if (length(pending)) cat(paste0(pending, "\n"), sep = "")
} else if (identical(action, "health")) {
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  if (!length(plans)) stop("No plans found.", call. = FALSE)
  health <- do.call(rbind, lapply(plans, iqpfr_v1_stage_health))
  print(health, row.names = FALSE)
} else if (identical(action, "verify")) {
  protocol <- iqpfr_v1_read_protocol(repo_root)
  checks <- iqpfr_v1_protocol_checks(protocol)
  authority <- iqpfr_v1_verify_authorities(protocol)
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  source_pass <- vapply(sources$frozen_path, iqfr_v2_sha256,
                        character(1L)) == sources$frozen_sha256
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  health <- do.call(rbind, lapply(plans, iqpfr_v1_stage_health))
  expected <- unlist(protocol$execution$expected_jobs)
  expected <- expected[names(expected) != "total"]
  names(expected)[names(expected) == "pilot"] <- "posterior_screen"
  observed <- setNames(health$planned, health$stage)
  count_pass <- all(names(expected) %in% names(observed)) &&
    all(observed[names(expected)] == as.integer(expected))
  report <- list(
    schema_version = iqpfr_v1_schema, protocol_checks = checks,
    authority_hashes_pass = all(authority$pass),
    source_hashes_pass = all(source_pass), stage_health = health,
    stage_count_pass = count_pass,
    verification_pass = all(checks$pass) && all(authority$pass) &&
      all(source_pass) && count_pass && all(health$complete) &&
      !any(health$failed > 0L | health$invalid > 0L)
  )
  iqfr_v2_write_json(report,
                     file.path(run_root, "manifests", "verification.json"))
  print(report)
  if (!isTRUE(report$verification_pass)) quit(status = 1L)
} else if (identical(action, "closeout")) {
  out <- iqpfr_v1_closeout(repo_root, run_root)
  cat(sprintf("status=%s strict_prior_forecast_improvements=%d\n",
              out$decision$status,
              out$decision$strict_prior_forecast_improvements))
} else {
  stop("Unknown action: ", action, call. = FALSE)
}
