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
    "Usage: --action <materialize|rhs|rhs_refinement|quantile_bridge|",
    "quantile_refinement|mcmc_pilot|replication|confirmation|pending|",
    "health|verify|closeout> --run-root PATH [--stage STAGE]"
  ), call. = FALSE)
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
run_root <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_representation_screen_v1.R",
  "independent_qdesn_representation_screen_v1_runtime.R",
  "independent_qdesn_cellwise_refinement_v2.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))

protocol <- iqcr_v2_read_protocol(repo_root)
expected_jobs <- function(stage) {
  as.integer(protocol$execution$expected_jobs[[stage]])
}

write_stage_manifest <- function(stage, payload) {
  iqfr_v2_write_json(
    c(list(stage = stage, generated_at = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%S%z"
    )), payload),
    file.path(run_root, "manifests", paste0(stage, "_materialization.json"))
  )
}

if (identical(action, "materialize")) {
  out <- iqcr_v2_materialize(repo_root, run_root)
  cat(sprintf(
    "ridge_jobs=%d structures=%d imported=%d novel=%d sources=%d\n",
    nrow(out$plan), nrow(out$structures),
    sum(out$structures$generation == "stage1_import"),
    sum(out$structures$generation == "family_targeted_v2_new"),
    nrow(out$sources)
  ))
} else if (identical(action, "rhs")) {
  targeted_ridge <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "ridge_screen.csv"), TRUE
  )
  targeted_ranked <- iqrs_v1_aggregate_normal(targeted_ridge)
  targeted_path <- iqfr_v2_write_csv(
    targeted_ranked,
    file.path(run_root, "summaries", "targeted_ridge_robust_ranking.csv")
  )
  structures <- utils::read.csv(
    file.path(run_root, "manifests", "structure_catalog.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_materialize_normal_plan(
    repo_root, run_root, protocol, structures, sources, "rhs_screen"
  )
  if (nrow(plan) != expected_jobs("rhs_screen")) {
    stop("RHS bridge plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("rhs_screen", list(
    jobs = nrow(plan), structures = nrow(structures),
    coarse_tau0 = as.numeric(protocol$inference$normal_rhs$coarse_tau0),
    targeted_ridge_ranking_path = targeted_path,
    targeted_ridge_ranking_sha256 = iqfr_v2_sha256(targeted_path)
  ))
  cat(sprintf("rhs_jobs=%d structures=%d\n", nrow(plan), nrow(structures)))
} else if (identical(action, "rhs_refinement")) {
  coarse <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "rhs_screen.csv"), TRUE
  )
  coarse_ranked <- iqrs_v1_aggregate_normal(coarse)
  coarse_path <- iqfr_v2_write_csv(
    coarse_ranked,
    file.path(run_root, "summaries", "rhs_coarse_robust_ranking.csv")
  )
  coarse_best <- iqrs_v1_best_scale_per_structure(coarse_ranked)
  coarse_best_path <- iqfr_v2_write_csv(
    coarse_best,
    file.path(run_root, "manifests", "rhs_coarse_best_per_structure.csv")
  )
  structures <- utils::read.csv(
    file.path(run_root, "manifests", "structure_catalog.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_materialize_rhs_refinement_plan(
    repo_root, run_root, protocol, structures, sources, coarse_best
  )
  if (nrow(plan) != expected_jobs("rhs_refinement")) {
    stop("RHS refinement plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("rhs_refinement", list(
    jobs = nrow(plan), structures = nrow(structures),
    coarse_ranking_path = coarse_path,
    coarse_ranking_sha256 = iqfr_v2_sha256(coarse_path),
    coarse_best_path = coarse_best_path,
    coarse_best_sha256 = iqfr_v2_sha256(coarse_best_path),
    local_multipliers = as.numeric(
      protocol$inference$normal_rhs$local_multipliers
    )
  ))
  cat(sprintf("rhs_refinement_jobs=%d\n", nrow(plan)))
} else if (identical(action, "quantile_bridge")) {
  coarse <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "rhs_screen.csv"), TRUE
  )
  refined <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "rhs_refinement.csv"), TRUE
  )
  combined <- rbind(coarse, refined)
  key <- paste(combined$family, combined$structure_id, combined$fold_id,
               combined$prior_scale, sep = "|")
  combined <- combined[!duplicated(key), , drop = FALSE]
  ranked <- iqrs_v1_aggregate_normal(combined)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "rhs_combined_robust_ranking.csv")
  )
  structures <- utils::read.csv(
    file.path(run_root, "manifests", "structure_catalog.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  all_best <- iqrs_v1_best_scale_per_structure(ranked)
  candidates <- iqcr_v2_finalize_rhs_candidates(all_best, structures)
  candidate_path <- iqfr_v2_write_csv(
    candidates, file.path(run_root, "manifests", "candidate_pool.csv")
  )
  selected <- iqcr_v2_select_family_counts(
    ranked, protocol$search$bridge_per_family
  )
  selected <- candidates[match(selected$structure_id,
                               candidates$structure_id), , drop = FALSE]
  selected$bridge_selection_rank <- ave(
    seq_len(nrow(selected)), selected$family, FUN = seq_along
  )
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "quantile_bridge_candidates.csv")
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_materialize_quantile_plan(
    repo_root, run_root, protocol, selected, sources, "quantile_bridge"
  )
  if (nrow(plan) != expected_jobs("quantile_bridge")) {
    stop("Quantile bridge plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("quantile_bridge", list(
    jobs = nrow(plan), candidates = nrow(selected),
    expected_result_rows = 12L * nrow(plan),
    rhs_ranking_path = ranking_path,
    rhs_ranking_sha256 = iqfr_v2_sha256(ranking_path),
    candidate_pool_path = candidate_path,
    candidate_pool_sha256 = iqfr_v2_sha256(candidate_path),
    selected_path = selected_path,
    selected_sha256 = iqfr_v2_sha256(selected_path)
  ))
  cat(sprintf("quantile_bridge_jobs=%d expected_rows=%d\n",
              nrow(plan), 12L * nrow(plan)))
} else if (identical(action, "quantile_refinement")) {
  bridge <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "quantile_bridge.csv"), TRUE
  )
  bridge_ranked <- iqrs_v1_rank_quantile(bridge)
  ranking_path <- iqfr_v2_write_csv(
    bridge_ranked,
    file.path(run_root, "summaries", "quantile_bridge_robust_ranking.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  bridge_candidates <- utils::read.csv(
    file.path(run_root, "manifests", "quantile_bridge_candidates.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  refinement <- iqcr_v2_select_refinement(
    bridge_ranked, candidates, bridge_candidates$candidate_id, protocol
  )
  selected_path <- iqfr_v2_write_csv(
    refinement$candidates,
    file.path(run_root, "manifests", "quantile_refinement_candidates.csv")
  )
  assignment_path <- iqfr_v2_write_csv(
    refinement$assignments,
    file.path(run_root, "manifests", "quantile_refinement_assignments.csv")
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_materialize_quantile_plan(
    repo_root, run_root, protocol, refinement$candidates, sources,
    "quantile_refinement"
  )
  if (nrow(plan) != expected_jobs("quantile_refinement")) {
    stop("Quantile refinement plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("quantile_refinement", list(
    jobs = nrow(plan), candidates = nrow(refinement$candidates),
    expected_result_rows = 12L * nrow(plan),
    target_assignments = nrow(refinement$assignments),
    bridge_ranking_path = ranking_path,
    bridge_ranking_sha256 = iqfr_v2_sha256(ranking_path),
    selected_path = selected_path,
    selected_sha256 = iqfr_v2_sha256(selected_path),
    assignment_path = assignment_path,
    assignment_sha256 = iqfr_v2_sha256(assignment_path)
  ))
  cat(sprintf("quantile_refinement_jobs=%d assignments=%d\n",
              nrow(plan), nrow(refinement$assignments)))
} else if (identical(action, "mcmc_pilot")) {
  bridge <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "quantile_bridge.csv"), TRUE
  )
  refinement <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "quantile_refinement.csv"), TRUE
  )
  combined <- rbind(bridge, refinement)
  ranked <- iqrs_v1_rank_quantile(combined)
  ranking_path <- iqfr_v2_write_csv(
    ranked,
    file.path(run_root, "summaries", "quantile_combined_robust_ranking.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  selected <- iqcr_v2_select_mcmc_pilot(ranked, candidates, protocol)
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "mcmc_pilot_finalists.csv")
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_make_mcmc_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    "mcmc_pilot", 1L, protocol$inference$mcmc$pilot, FALSE
  )
  if (nrow(plan) != expected_jobs("mcmc_pilot")) {
    stop("MCMC pilot plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("mcmc_pilot", list(
    jobs = nrow(plan), target_cells = 17L,
    finalists_per_cell = 10L,
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    exal_method_id = protocol$inference$mcmc$exal_method_id
  ))
  cat(sprintf("mcmc_pilot_jobs=%d\n", nrow(plan)))
} else if (identical(action, "replication")) {
  pilot <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "mcmc_pilot.csv"), TRUE
  )
  ranked <- iqrs_v1_rank_mcmc(pilot)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "mcmc_pilot_ranking.csv")
  )
  cell <- interaction(ranked$family, ranked$tau,
                      ranked$likelihood_family, drop = TRUE)
  selected <- do.call(rbind, lapply(split(ranked, cell), function(x) {
    x <- x[order(x$selection_rank, x$forecast_qtrue_mae_mean), , drop = FALSE]
    utils::head(x, 3L)
  }))
  rownames(selected) <- NULL
  if (nrow(selected) != 51L) stop("Replication finalist count mismatch.")
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "replication_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_make_mcmc_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    "replication",
    as.integer(protocol$inference$mcmc$replication$added_chains),
    protocol$inference$mcmc$replication, FALSE
  )
  if (nrow(plan) != expected_jobs("replication")) {
    stop("Replication plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("replication", list(
    jobs = nrow(plan), target_cells = 17L, finalists_per_cell = 3L,
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path)
  ))
  cat(sprintf("replication_jobs=%d\n", nrow(plan)))
} else if (identical(action, "confirmation")) {
  pilot <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "mcmc_pilot.csv"), TRUE
  )
  replication <- iqcr_v2_collect_results(
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
  cell <- interaction(ranked$family, ranked$tau,
                      ranked$likelihood_family, drop = TRUE)
  selected <- do.call(rbind, lapply(split(ranked, cell), function(x) {
    x <- x[order(x$selection_rank, x$forecast_qtrue_mae_mean), , drop = FALSE]
    x[1L, , drop = FALSE]
  }))
  rownames(selected) <- NULL
  if (nrow(selected) != 17L || any(selected$chains != 3L)) {
    stop("Confirmation finalist contract failed.", call. = FALSE)
  }
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "confirmation_finalists.csv")
  )
  candidates <- utils::read.csv(
    file.path(run_root, "manifests", "candidate_pool.csv"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  sources <- utils::read.csv(
    file.path(run_root, "source_manifest.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  plan <- iqcr_v2_make_mcmc_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    "confirmation",
    as.integer(protocol$inference$mcmc$confirmation$chains),
    protocol$inference$mcmc$confirmation, TRUE
  )
  if (nrow(plan) != expected_jobs("confirmation")) {
    stop("Confirmation plan count mismatch.", call. = FALSE)
  }
  write_stage_manifest("confirmation", list(
    jobs = nrow(plan), target_cells = 17L, chains_per_cell = 3L,
    final_origins = 971L, final_pairs_per_chain = 29130L,
    ranking_path = ranking_path,
    ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    final_window_first_access = TRUE
  ))
  cat(sprintf("confirmation_jobs=%d\n", nrow(plan)))
} else if (identical(action, "pending")) {
  stage <- value_after("--stage")
  if (is.null(stage)) stop("pending requires --stage.", call. = FALSE)
  pending <- iqcr_v2_pending_configs(
    file.path(run_root, "plans", paste0(stage, ".csv"))
  )
  if (length(pending)) cat(paste0(pending, "\n"), sep = "")
} else if (identical(action, "health")) {
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  if (!length(plans)) {
    cat("No materialized stages.\n")
  } else {
    health <- do.call(rbind, lapply(plans, iqfr_v2_stage_health))
    order_index <- match(health$stage, c(
      "ridge_screen", "rhs_screen", "rhs_refinement", "quantile_bridge",
      "quantile_refinement", "mcmc_pilot", "replication", "confirmation"
    ))
    health <- health[order(order_index), , drop = FALSE]
    print(health, row.names = FALSE)
    cat(sprintf(
      paste0(
        "overall_materialized=%d overall_success=%d overall_running=%d ",
        "overall_failed=%d overall_pending=%d overall_invalid=%d ",
        "campaign_maximum=%d unmaterialized=%d\n"
      ),
      sum(health$planned), sum(health$success), sum(health$running),
      sum(health$failed), sum(health$pending), sum(health$invalid),
      expected_jobs("total"), expected_jobs("total") - sum(health$planned)
    ))
  }
} else if (identical(action, "verify")) {
  complete <- identical(value_after("--complete", "false"), "true")
  report <- iqcr_v2_verify(repo_root, run_root, require_complete = complete)
  print(report)
  if (!isTRUE(report$verification_pass)) quit(status = 1L)
} else if (identical(action, "closeout")) {
  verification <- iqcr_v2_verify(repo_root, run_root, require_complete = TRUE)
  if (!isTRUE(verification$verification_pass)) {
    stop("Complete verification failed; closeout is forbidden.", call. = FALSE)
  }
  confirmation <- iqcr_v2_collect_results(
    file.path(run_root, "plans", "confirmation.csv"), TRUE
  )
  draws <- iqfr_v2_read_metric_draws(confirmation)
  pooled <- iqfr_v2_pool_confirmation_metrics(draws)
  pooled_path <- iqfr_v2_write_csv(
    pooled, file.path(run_root, "summaries", "confirmation_metric_intervals.csv")
  )
  mean_state <- pooled[
    pooled$estimator == "mean_readout_state_recursive", , drop = FALSE
  ]
  metric_names <- c(
    "fit_qtrue_rmse", "fit_qtrue_mae", "fit_check_loss",
    "forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss"
  )
  long <- do.call(rbind, lapply(seq_len(nrow(mean_state)), function(i) {
    do.call(rbind, lapply(metric_names, function(metric) data.frame(
      model_variant = if (mean_state$likelihood_family[[i]] == "al") {
        "qdesn_al_rhs"
      } else "qdesn_exal_rhs",
      family = mean_state$family[[i]], tau = mean_state$tau[[i]],
      likelihood_family = mean_state$likelihood_family[[i]],
      candidate_id = mean_state$candidate_id[[i]], metric = metric,
      posterior_mean = mean_state[[paste0(metric, "_mean")]][[i]],
      cri_lower = mean_state[[paste0(metric, "_lower")]][[i]],
      cri_upper = mean_state[[paste0(metric, "_upper")]][[i]],
      n_draws = mean_state$pooled_draws[[i]],
      n_chains = mean_state$chains[[i]],
      estimator = mean_state$estimator[[i]], stringsAsFactors = FALSE
    )))
  }))
  authority <- utils::read.csv(
    file.path(repo_root, protocol$authorities$current_authority_comparison),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  key <- function(x) paste(x$model_variant, x$family, sprintf("%.2f", x$tau),
                           x$metric, sep = "|")
  matched <- authority[match(key(long), key(authority)), , drop = FALSE]
  long$current_authority_mean <- matched$posterior_mean
  long$comparator_model <- matched$comparator_model
  long$comparator_mean <- matched$comparator_mean
  long$new_minus_current <- long$posterior_mean - long$current_authority_mean
  long$new_minus_comparator <- long$posterior_mean - long$comparator_mean
  long$strict_current_improvement <- is.finite(long$current_authority_mean) &
    long$new_minus_current < 0
  long$comparator_ratio <- long$posterior_mean / long$comparator_mean
  long$parity_class <- ifelse(
    long$comparator_ratio <= protocol$decision$parity_ratio, "parity_or_win",
    ifelse(
      long$comparator_ratio <= protocol$decision$near_parity_ratio,
      "near_parity",
      ifelse(long$comparator_ratio <= protocol$decision$unresolved_ratio,
             "improved_but_unresolved", "unresolved")
    )
  )
  comparison_path <- iqfr_v2_write_csv(
    long, file.path(run_root, "summaries", "authority_comparison.csv")
  )
  forecast <- long[long$metric == "forecast_qtrue_mae", , drop = FALSE]
  evidence_files <- unique(c(
    list.files(file.path(run_root, "plans"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(run_root, "manifests"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(run_root, "summaries"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(run_root, "status"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(run_root, "results"), recursive = TRUE,
               full.names = TRUE),
    file.path(run_root, c("source_manifest.csv", "launch_environment.txt"))
  ))
  evidence_files <- evidence_files[file.exists(evidence_files)]
  evidence_files <- evidence_files[
    basename(evidence_files) != "artifact_manifest.csv"
  ]
  relative <- substring(evidence_files, nchar(run_root) + 2L)
  info <- file.info(evidence_files)
  artifact_manifest <- data.frame(
    relative_path = relative,
    artifact_class = sub("/.*$", "", relative),
    bytes = as.numeric(info$size),
    sha256 = vapply(evidence_files, iqfr_v2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  artifact_manifest <- artifact_manifest[
    order(artifact_manifest$artifact_class, artifact_manifest$relative_path),
    , drop = FALSE
  ]
  artifact_manifest_path <- iqfr_v2_write_csv(
    artifact_manifest,
    file.path(run_root, "manifests", "artifact_manifest.csv")
  )
  binary_pattern <- "[.](rds|rda|rdata)$"
  binary_rows <- grepl(binary_pattern, artifact_manifest$relative_path,
                       ignore.case = TRUE)
  large_rows <- artifact_manifest$bytes >= 100 * 1024^2
  decision <- list(
    schema_version = iqcr_v2_schema,
    status = if (any(forecast$strict_current_improvement)) {
      "READY_FOR_INTEGRATION"
    } else "READY_NO_ARTICLE_CHANGE",
    completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    completed_cells = nrow(forecast),
    strict_forecast_improvements = sum(forecast$strict_current_improvement),
    parity_or_win_cells = sum(forecast$parity_class == "parity_or_win"),
    near_parity_cells = sum(forecast$parity_class == "near_parity"),
    unresolved_above_1p5 = sum(forecast$comparator_ratio > 1.50),
    broad_screen_stop_rule_triggered = any(forecast$comparator_ratio > 1.50),
    article_write_performed = FALSE,
    shared_validation_merge_performed = FALSE,
    overleaf_write_performed = FALSE,
    fitted_model_binaries = sum(binary_rows),
    unexpected_files_at_least_100mb = sum(large_rows),
    evidence_files = nrow(artifact_manifest),
    evidence_bytes = sum(artifact_manifest$bytes),
    artifact_manifest_path = artifact_manifest_path,
    artifact_manifest_sha256 = iqfr_v2_sha256(artifact_manifest_path),
    pooled_path = pooled_path,
    pooled_sha256 = iqfr_v2_sha256(pooled_path),
    comparison_path = comparison_path,
    comparison_sha256 = iqfr_v2_sha256(comparison_path)
  )
  closeout_path <- iqfr_v2_write_json(
    decision, file.path(run_root, "manifests", "closeout.json")
  )
  handoff <- c(
    "# Independent Q-DESN cellwise refinement v2 handoff",
    "",
    paste0("- Status: `", decision$status, "`"),
    paste0("- Branch: `", system2(
      "git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE
    ), "`"),
    paste0("- HEAD: `", system2(
      "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
    ), "`"),
    paste0("- Run root: `", run_root, "`"),
    paste0("- Completed cells: ", decision$completed_cells),
    paste0("- Strict forecast improvements: ",
           decision$strict_forecast_improvements),
    paste0("- Parity/win cells: ", decision$parity_or_win_cells),
    paste0("- Near-parity cells: ", decision$near_parity_cells),
    paste0("- Cells above comparator ratio 1.5: ",
           decision$unresolved_above_1p5),
    paste0("- Fitted-model binaries: ", decision$fitted_model_binaries),
    paste0("- Artifact manifest: `", artifact_manifest_path, "`"),
    "- Article, shared-validation, and Overleaf writes: none",
    "- Integration requires a separate frozen promotion commit."
  )
  writeLines(handoff, file.path(run_root, "manifests", "integration_handoff.md"))
  cat(sprintf("status=%s cells=%d improvements=%d closeout=%s\n",
              decision$status, decision$completed_cells,
              decision$strict_forecast_improvements, closeout_path))
} else {
  stop("Unknown action: ", action, call. = FALSE)
}
