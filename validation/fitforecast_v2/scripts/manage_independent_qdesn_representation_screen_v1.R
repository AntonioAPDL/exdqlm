#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  index <- match(flag, args)
  if (is.na(index) || index == length(args)) return(default)
  args[[index + 1L]]
}

action <- value_after("--action")
run_root <- value_after("--run-root")
if (is.null(action) || is.null(run_root)) {
  stop(paste0(
    "Usage: --action <materialize|rhs|quantile|mcmc_pilot|replication|",
    "confirmation|pending|health|verify|closeout> --run-root PATH",
    " [--stage STAGE]"
  ), call. = FALSE)
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
run_root <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2_runtime.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_representation_screen_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_representation_screen_v1_runtime.R"))

protocol <- iqrs_v1_read_protocol(repo_root)

if (identical(action, "materialize")) {
  out <- iqrs_v1_materialize(repo_root, run_root)
  cat(sprintf("ridge_jobs=%d structures=%d sources=%d\n",
              nrow(out$plan), nrow(out$structures), nrow(out$sources)))
} else if (identical(action, "rhs")) {
  ridge <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "ridge_screen.csv"), TRUE
  )
  ranked <- iqrs_v1_aggregate_normal(ridge)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "ridge_robust_ranking.csv")
  )
  selected <- iqrs_v1_select_diverse(
    ranked, as.integer(protocol$search$ridge_shortlist_per_family)
  )
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "ridge_shortlist.csv")
  )
  structures <- utils::read.csv(
    file.path(run_root, "manifests", "structure_catalog.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  structures <- structures[match(selected$structure_id,
                                 structures$structure_id), , drop = FALSE]
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqrs_v1_materialize_normal_plan(
    repo_root, run_root, protocol, structures, sources, "rhs_screen"
  )
  expected <- as.integer(protocol$execution$expected_jobs$rhs_screen)
  if (nrow(plan) != expected) stop("RHS plan count mismatch.", call. = FALSE)
  iqfr_v2_write_json(list(
    stage = "rhs_screen", jobs = nrow(plan), structures = nrow(selected),
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    shortlist_path = selected_path,
    shortlist_sha256 = iqfr_v2_sha256(selected_path)
  ), file.path(run_root, "manifests", "rhs_materialization.json"))
  cat(sprintf("rhs_jobs=%d structures=%d\n", nrow(plan), nrow(selected)))
} else if (identical(action, "quantile")) {
  rhs <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "rhs_screen.csv"), TRUE
  )
  ranked <- iqrs_v1_aggregate_normal(rhs)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "rhs_robust_ranking.csv")
  )
  selected <- iqrs_v1_select_diverse(
    ranked, as.integer(protocol$search$rhs_shortlist_per_family)
  )
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "rhs_shortlist.csv")
  )
  structures <- utils::read.csv(
    file.path(run_root, "manifests", "structure_catalog.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  candidates <- iqrs_v1_finalize_rhs_candidates(selected, structures)
  candidate_path <- iqfr_v2_write_csv(
    candidates, file.path(run_root, "manifests", "candidate_pool.csv")
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqrs_v1_materialize_quantile_plan(
    repo_root, run_root, protocol, candidates, sources
  )
  expected <- as.integer(protocol$execution$expected_jobs$quantile_vb)
  if (nrow(plan) != expected) stop("Quantile plan count mismatch.", call. = FALSE)
  iqfr_v2_write_json(list(
    stage = "quantile_vb", jobs = nrow(plan),
    expected_result_rows = 12L * nrow(plan),
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    shortlist_path = selected_path,
    shortlist_sha256 = iqfr_v2_sha256(selected_path),
    candidate_path = candidate_path,
    candidate_sha256 = iqfr_v2_sha256(candidate_path)
  ), file.path(run_root, "manifests", "quantile_materialization.json"))
  cat(sprintf("quantile_jobs=%d expected_rows=%d\n",
              nrow(plan), 12L * nrow(plan)))
} else if (identical(action, "mcmc_pilot")) {
  quantile <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "quantile_vb.csv"), TRUE
  )
  ranked <- iqrs_v1_rank_quantile(quantile)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "quantile_vb_robust_ranking.csv")
  )
  selected <- ranked[
    ranked$selection_rank <=
      as.integer(protocol$inference$mcmc$pilot$finalists_per_cell),
    , drop = FALSE
  ]
  cells <- interaction(selected$family, selected$tau,
                       selected$likelihood_family, drop = TRUE)
  if (length(unique(cells)) != 18L || any(table(cells) != 8L)) {
    stop("MCMC pilot finalist coverage failed.", call. = FALSE)
  }
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "mcmc_pilot_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqrs_v1_make_mcmc_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    plan_stage = "mcmc_pilot", chain_ids = 1L,
    budget = protocol$inference$mcmc$pilot, confirmation = FALSE
  )
  if (nrow(plan) != as.integer(protocol$execution$expected_jobs$mcmc_pilot)) {
    stop("MCMC pilot plan count mismatch.", call. = FALSE)
  }
  iqfr_v2_write_json(list(
    stage = "mcmc_pilot", jobs = nrow(plan), cells = 18L,
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    exal_method_id = protocol$inference$mcmc$exal_method_id
  ), file.path(run_root, "manifests", "mcmc_pilot_materialization.json"))
  cat(sprintf("mcmc_pilot_jobs=%d\n", nrow(plan)))
} else if (identical(action, "replication")) {
  pilot <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "mcmc_pilot.csv"), TRUE
  )
  ranked <- iqrs_v1_rank_mcmc(pilot)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "mcmc_pilot_ranking.csv")
  )
  selected <- ranked[
    ranked$selection_rank <=
      as.integer(protocol$inference$mcmc$replication$finalists_per_cell),
    , drop = FALSE
  ]
  cells <- interaction(selected$family, selected$tau,
                       selected$likelihood_family, drop = TRUE)
  if (length(unique(cells)) != 18L || any(table(cells) != 3L)) {
    stop("Replication finalist coverage failed.", call. = FALSE)
  }
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "replication_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqrs_v1_make_mcmc_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    plan_stage = "replication",
    chain_ids = as.integer(protocol$inference$mcmc$replication$added_chains),
    budget = protocol$inference$mcmc$replication, confirmation = FALSE
  )
  if (nrow(plan) != as.integer(protocol$execution$expected_jobs$replication)) {
    stop("Replication plan count mismatch.", call. = FALSE)
  }
  iqfr_v2_write_json(list(
    stage = "replication", jobs = nrow(plan), cells = 18L,
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path)
  ), file.path(run_root, "manifests", "replication_materialization.json"))
  cat(sprintf("replication_jobs=%d\n", nrow(plan)))
} else if (identical(action, "confirmation")) {
  pilot <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "mcmc_pilot.csv"), TRUE
  )
  replication <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "replication.csv"), TRUE
  )
  finalists <- utils::read.csv(
    file.path(run_root, "manifests", "replication_finalists.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  keys <- paste(finalists$family, finalists$tau,
                finalists$likelihood_family, finalists$candidate_id, sep = "|")
  pilot_key <- paste(pilot$family, pilot$tau, pilot$likelihood_family,
                     pilot$candidate_id, sep = "|")
  validation <- rbind(pilot[pilot_key %in% keys, , drop = FALSE], replication)
  ranked <- iqrs_v1_rank_mcmc(validation)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "replicated_mcmc_ranking.csv")
  )
  selected <- ranked[ranked$selection_rank == 1L, , drop = FALSE]
  cells <- interaction(selected$family, selected$tau,
                       selected$likelihood_family, drop = TRUE)
  if (nrow(selected) != 18L || length(unique(cells)) != 18L ||
      any(selected$chains != 3L)) {
    stop("Confirmation finalist coverage failed.", call. = FALSE)
  }
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "confirmation_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqrs_v1_make_mcmc_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    plan_stage = "confirmation",
    chain_ids = as.integer(protocol$inference$mcmc$confirmation$chains),
    budget = protocol$inference$mcmc$confirmation, confirmation = TRUE
  )
  if (nrow(plan) != as.integer(protocol$execution$expected_jobs$confirmation)) {
    stop("Confirmation plan count mismatch.", call. = FALSE)
  }
  iqfr_v2_write_json(list(
    stage = "confirmation", jobs = nrow(plan), cells = 18L,
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    final_window_first_access = TRUE, final_origins = 971L,
    final_pairs_per_chain = 29130L
  ), file.path(run_root, "manifests", "confirmation_materialization.json"))
  cat(sprintf("confirmation_jobs=%d\n", nrow(plan)))
} else if (identical(action, "pending")) {
  stage <- value_after("--stage")
  if (is.null(stage)) stop("pending requires --stage.", call. = FALSE)
  pending <- iqrs_v1_pending_configs(
    file.path(run_root, "plans", paste0(stage, ".csv"))
  )
  if (length(pending)) cat(paste0(pending, "\n"), sep = "")
} else if (identical(action, "health")) {
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  health <- do.call(rbind, lapply(plans, iqrs_v1_stage_health))
  print(health, row.names = FALSE)
} else if (identical(action, "verify")) {
  complete <- identical(value_after("--complete", "false"), "true")
  report <- iqrs_v1_verify(repo_root, run_root, require_complete = complete)
  print(report)
  if (!isTRUE(report$verification_pass)) quit(status = 1L)
} else if (identical(action, "closeout")) {
  confirmation <- iqrs_v1_collect_results(
    file.path(run_root, "plans", "confirmation.csv"), TRUE
  )
  ranked <- iqrs_v1_rank_mcmc(confirmation)
  winners <- ranked[ranked$selection_rank == 1L, , drop = FALSE]
  winner_path <- iqfr_v2_write_csv(
    winners, file.path(run_root, "summaries", "confirmation_winners.csv")
  )
  authority <- utils::read.csv(protocol$authorities$rescue_comparison,
                               check.names = FALSE, stringsAsFactors = FALSE)
  forecast <- authority[authority$metric == "forecast_qtrue_mae", , drop = FALSE]
  authority$key <- paste(authority$model_variant, authority$family,
                         authority$tau, authority$metric, sep = "|")
  winners$model_variant <- ifelse(
    winners$likelihood_family == "al", "qdesn_al_rhs", "qdesn_exal_rhs"
  )
  winners$key <- paste(winners$model_variant, winners$family, winners$tau,
                       "forecast_qtrue_mae", sep = "|")
  matched <- authority[match(winners$key, authority$key), , drop = FALSE]
  winners$prior_authority_mean <- matched$prior_qdesn_mean
  winners$new_minus_prior <- winners$forecast_qtrue_mae_mean -
    winners$prior_authority_mean
  winners$strict_prior_improvement <- is.finite(winners$prior_authority_mean) &
    winners$new_minus_prior < 0
  comparison_path <- iqfr_v2_write_csv(
    winners, file.path(run_root, "summaries", "authority_comparison.csv")
  )
  decision <- list(
    schema_version = iqrs_v1_schema,
    status = if (any(winners$strict_prior_improvement, na.rm = TRUE)) {
      "READY_FOR_INTEGRATION"
    } else "READY_NO_ARTICLE_CHANGE",
    completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    completed_cells = nrow(winners),
    strict_prior_forecast_improvements = sum(
      winners$strict_prior_improvement, na.rm = TRUE
    ),
    article_write_performed = FALSE,
    shared_validation_merge_performed = FALSE,
    overleaf_write_performed = FALSE,
    winner_path = winner_path, winner_sha256 = iqfr_v2_sha256(winner_path),
    comparison_path = comparison_path,
    comparison_sha256 = iqfr_v2_sha256(comparison_path)
  )
  closeout_path <- iqfr_v2_write_json(
    decision, file.path(run_root, "manifests", "closeout.json")
  )
  cat(sprintf("status=%s cells=%d improvements=%d closeout=%s\n",
              decision$status, nrow(winners),
              decision$strict_prior_forecast_improvements, closeout_path))
} else {
  stop("Unknown action: ", action, call. = FALSE)
}
