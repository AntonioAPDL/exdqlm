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
    "Usage: --action <materialize|adaptive|full|quantile|mcmc_pilot|",
    "mcmc_confirmation|pending|health|verify|closeout> --run-root <path>"
  ),
       call. = FALSE)
}
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
run_root <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2_runtime.R"
))

if (identical(action, "materialize")) {
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                    stdout = TRUE)
  status <- system2("git", c("-C", repo_root, "status", "--porcelain"),
                    stdout = TRUE)
  if (!identical(branch, iqfr_v2_expected_branch) || length(status)) {
    stop("Materialization requires the clean dedicated validation branch.",
         call. = FALSE)
  }
  out <- iqfr_v2_materialize_initial(repo_root, run_root)
  cat(sprintf("materialized=%d run_root=%s\n", nrow(out$plan), run_root))
} else if (identical(action, "adaptive")) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  initial_plan <- file.path(run_root, "plans", "normal_initial.csv")
  initial_results <- iqfr_v2_collect_results(initial_plan, require_complete = TRUE)
  ranked <- iqfr_v2_rank_normal(initial_results)
  iqfr_v2_write_csv(ranked, file.path(
    run_root, "summaries", "normal_initial_ranking.csv"
  ))
  initial_candidates <- utils::read.csv(file.path(
    run_root, "manifests", "initial_candidates.csv"
  ), check.names = FALSE, stringsAsFactors = FALSE)
  adaptive <- do.call(rbind, lapply(iqfr_v2_families, function(family) {
    iqfr_v2_generate_adaptive_candidates(
      protocol, family, ranked, initial_candidates
    )
  }))
  candidate_path <- iqfr_v2_write_csv(adaptive, file.path(
    run_root, "manifests", "adaptive_candidates.csv"
  ))
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqfr_v2_materialize_normal_jobs(
    repo_root, run_root, protocol, adaptive, sources,
    stage = "normal_adaptive", budget = protocol$inference$normal_rhs$screen
  )
  iqfr_v2_write_json(list(
    stage = "normal_adaptive", candidate_path = candidate_path,
    candidate_sha256 = iqfr_v2_sha256(candidate_path), jobs = nrow(plan),
    source_initial_ranking_sha256 = iqfr_v2_sha256(file.path(
      run_root, "summaries", "normal_initial_ranking.csv"
    ))
  ), file.path(run_root, "manifests", "normal_adaptive_materialization.json"))
  cat(sprintf("adaptive_jobs=%d\n", nrow(plan)))
} else if (identical(action, "full")) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  initial <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "normal_initial.csv"), TRUE
  )
  adaptive <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "normal_adaptive.csv"), TRUE
  )
  ranked <- iqfr_v2_rank_normal(rbind(initial, adaptive))
  ranking_path <- iqfr_v2_write_csv(ranked, file.path(
    run_root, "summaries", "normal_combined_ranking.csv"
  ))
  initial_candidates <- utils::read.csv(file.path(
    run_root, "manifests", "initial_candidates.csv"
  ), check.names = FALSE, stringsAsFactors = FALSE)
  adaptive_candidates <- utils::read.csv(file.path(
    run_root, "manifests", "adaptive_candidates.csv"
  ), check.names = FALSE, stringsAsFactors = FALSE)
  selected <- iqfr_v2_select_diverse_normal(
    ranked, rbind(initial_candidates, adaptive_candidates),
    k = as.integer(protocol$search$full_budget_top_k_per_family)
  )
  selected_path <- iqfr_v2_write_csv(selected, file.path(
    run_root, "manifests", "normal_full_candidates.csv"
  ))
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  plan <- iqfr_v2_materialize_normal_jobs(
    repo_root, run_root, protocol, selected, sources,
    stage = "normal_full", budget = protocol$inference$normal_rhs$full
  )
  iqfr_v2_write_json(list(
    stage = "normal_full", jobs = nrow(plan),
    ranking_path = ranking_path, ranking_sha256 = iqfr_v2_sha256(ranking_path),
    candidate_path = selected_path,
    candidate_sha256 = iqfr_v2_sha256(selected_path)
  ), file.path(run_root, "manifests", "normal_full_materialization.json"))
  cat(sprintf("normal_full_jobs=%d\n", nrow(plan)))
} else if (identical(action, "quantile")) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  full <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "normal_full.csv"), TRUE
  )
  ranked <- iqfr_v2_rank_normal(full)
  ranking_path <- iqfr_v2_write_csv(ranked, file.path(
    run_root, "summaries", "normal_full_ranking.csv"
  ))
  candidates <- utils::read.csv(file.path(
    run_root, "manifests", "normal_full_candidates.csv"
  ), check.names = FALSE, stringsAsFactors = FALSE)
  candidates <- candidates[match(ranked$candidate_id, candidates$candidate_id),
                           , drop = FALSE]
  candidates <- candidates[!duplicated(candidates$candidate_id), , drop = FALSE]
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  configs <- file.path(run_root, "configs", "quantile_vb")
  dir.create(configs, recursive = TRUE, showWarnings = FALSE)
  rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    family_sources <- sources[sources$family == candidate$family[[1L]],
                              , drop = FALSE]
    family_sources <- family_sources[order(family_sources$tau), , drop = FALSE]
    if (nrow(family_sources) != 3L) stop("Incomplete family source set.")
    job_id <- paste0("quantile_vb__", candidate$candidate_id[[1L]])
    config_path <- file.path(configs, paste0(job_id, ".json"))
    result_path <- file.path(run_root, "results", "quantile_vb",
                             paste0(job_id, ".csv"))
    status_path <- file.path(run_root, "status", "quantile_vb",
                             paste0(job_id, ".json"))
    config <- list(
      schema_version = iqfr_v2_schema, protocol_id = protocol$protocol$id,
      stage = "quantile_vb", job_id = job_id, repo_root = repo_root,
      run_root = run_root,
      protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                 iqfr_v2_protocol_relpath)),
      sources = family_sources, candidate = as.list(candidate),
      result_path = result_path, status_path = status_path,
      seed = iqfr_v2_seed(job_id, "quantile_vb"),
      budget = protocol$inference$quantile_vb
    )
    iqfr_v2_write_json(config, config_path)
    rows[[i]] <- data.frame(
      stage = "quantile_vb", job_id = job_id,
      family = candidate$family[[1L]],
      candidate_id = candidate$candidate_id[[1L]],
      config_path = config_path, config_sha256 = iqfr_v2_sha256(config_path),
      result_path = result_path, status_path = status_path,
      stringsAsFactors = FALSE
    )
  }
  plan <- do.call(rbind, rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans", "quantile_vb.csv"))
  iqfr_v2_write_json(list(
    stage = "quantile_vb", jobs = nrow(plan), expected_result_rows = 6L * nrow(plan),
    normal_full_ranking_path = ranking_path,
    normal_full_ranking_sha256 = iqfr_v2_sha256(ranking_path),
    beta_covariance = "diagonal_screening_approximation",
    exal_sigmagam = "structured_default_grid_151"
  ), file.path(run_root, "manifests", "quantile_vb_materialization.json"))
  cat(sprintf("quantile_vb_jobs=%d expected_rows=%d\n",
              nrow(plan), 6L * nrow(plan)))
} else if (identical(action, "mcmc_pilot")) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  quantile <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "quantile_vb.csv"), TRUE
  )
  ranked <- iqfr_v2_rank_quantile(quantile)
  ranking_path <- iqfr_v2_write_csv(
    ranked, file.path(run_root, "summaries", "quantile_vb_ranking.csv")
  )
  selected <- iqfr_v2_select_cell_finalists(
    ranked,
    n_per_cell = as.integer(protocol$inference$mcmc$pilot$finalists_per_cell)
  )
  selected_path <- iqfr_v2_write_csv(
    selected, file.path(run_root, "manifests", "mcmc_pilot_finalists.csv")
  )
  candidates <- utils::read.csv(file.path(
    run_root, "manifests", "normal_full_candidates.csv"
  ), check.names = FALSE, stringsAsFactors = FALSE)
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  materialized <- iqfr_v2_materialize_mcmc_jobs(
    repo_root, run_root, protocol, selected, candidates, sources,
    stage = "mcmc_pilot"
  )
  iqfr_v2_write_json(list(
    stage = "mcmc_pilot", jobs = nrow(materialized$plan),
    cells = 18L,
    finalists_per_cell = as.integer(
      protocol$inference$mcmc$pilot$finalists_per_cell
    ),
    source_ranking_path = ranking_path,
    source_ranking_sha256 = iqfr_v2_sha256(ranking_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    exal_method_id = protocol$inference$mcmc$exal_method_id
  ), file.path(run_root, "manifests", "mcmc_pilot_materialization.json"))
  cat(sprintf("mcmc_pilot_jobs=%d cells=18\n",
              nrow(materialized$plan)))
} else if (identical(action, "mcmc_confirmation")) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  pilot <- iqfr_v2_collect_results(
    file.path(run_root, "plans", "mcmc_pilot.csv"), TRUE
  )
  pilot_path <- iqfr_v2_write_csv(
    pilot, file.path(run_root, "summaries", "mcmc_pilot_results.csv")
  )
  primary <- pilot[pilot$estimator == "path_recursive", , drop = FALSE]
  selected <- iqfr_v2_select_cell_finalists(
    primary,
    n_per_cell = as.integer(
      protocol$inference$mcmc$confirmation$finalists_per_cell
    ),
    metric_suffix = "_mean"
  )
  selected_path <- iqfr_v2_write_csv(
    selected,
    file.path(run_root, "manifests", "mcmc_confirmation_finalists.csv")
  )
  candidates <- utils::read.csv(file.path(
    run_root, "manifests", "normal_full_candidates.csv"
  ), check.names = FALSE, stringsAsFactors = FALSE)
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  materialized <- iqfr_v2_materialize_mcmc_jobs(
    repo_root, run_root, protocol, selected, candidates, sources,
    stage = "mcmc_confirmation"
  )
  iqfr_v2_write_json(list(
    stage = "mcmc_confirmation", jobs = nrow(materialized$plan),
    cells = 18L,
    finalists_per_cell = as.integer(
      protocol$inference$mcmc$confirmation$finalists_per_cell
    ),
    chains = as.integer(protocol$inference$mcmc$confirmation$chains),
    source_pilot_path = pilot_path,
    source_pilot_sha256 = iqfr_v2_sha256(pilot_path),
    finalists_path = selected_path,
    finalists_sha256 = iqfr_v2_sha256(selected_path),
    selection_estimator = "path_recursive",
    final_window_first_access = TRUE,
    final_origin_count = 971L, final_pair_count = 29130L
  ), file.path(run_root, "manifests",
               "mcmc_confirmation_materialization.json"))
  cat(sprintf("mcmc_confirmation_jobs=%d cells=18 chains=%d\n",
              nrow(materialized$plan),
              as.integer(protocol$inference$mcmc$confirmation$chains)))
} else if (identical(action, "pending")) {
  stage <- value_after("--stage")
  if (is.null(stage) || !nzchar(stage)) {
    stop("pending requires --stage <stage>", call. = FALSE)
  }
  plan_path <- file.path(run_root, "plans", paste0(stage, ".csv"))
  if (!file.exists(plan_path)) stop("Missing stage plan: ", plan_path,
                                    call. = FALSE)
  pending <- iqfr_v2_pending_configs(plan_path)
  if (length(pending)) cat(paste0(pending, "\n"), sep = "")
} else if (identical(action, "health")) {
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  if (!length(plans)) stop("No stage plans found.", call. = FALSE)
  health <- do.call(rbind, lapply(plans, iqfr_v2_stage_health))
  print(health, row.names = FALSE)
} else if (identical(action, "verify")) {
  protocol <- iqfr_v2_read_protocol(repo_root)
  checks <- iqfr_v2_protocol_checks(protocol)
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  sources$hash_pass <- vapply(sources$frozen_path, iqfr_v2_sha256,
                              character(1L)) == sources$frozen_sha256
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  health <- do.call(rbind, lapply(plans, iqfr_v2_stage_health))
  report <- list(
    protocol_checks = checks, source_hashes_pass = all(sources$hash_pass),
    stage_health = health,
    verification_pass = all(checks$pass) && all(sources$hash_pass) &&
      !any(health$failed > 0L | health$invalid > 0L)
  )
  iqfr_v2_write_json(report, file.path(
    run_root, "manifests", "live_verification.json"
  ))
  print(report)
  if (!isTRUE(report$verification_pass)) quit(status = 1L)
} else if (identical(action, "closeout")) {
  result <- iqfr_v2_closeout(repo_root, run_root)
  cat(sprintf("status=%s selected_cells=%d paired_rows=%d\n",
              result$status$status, nrow(result$winners),
              nrow(result$selected_metrics)))
} else {
  stop("Unknown management action: ", action, call. = FALSE)
}
