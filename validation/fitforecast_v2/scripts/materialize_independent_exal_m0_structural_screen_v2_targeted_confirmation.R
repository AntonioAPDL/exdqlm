#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "digest")) {
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

screen_root <- normalizePath(get_arg("--screen-root"), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg("--output-root"), winslash = "/", mustWork = FALSE)
canonical_root <- normalizePath(get_arg(
  "--canonical-source-root",
  "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources"
), winslash = "/", mustWork = TRUE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

profiles_path <- file.path(screen_root, "canonical_confirmation_profiles.csv")
ranking_path <- file.path(screen_root, "sealed_closeout_ranking.csv")
profiles <- qdesn_ssv2_read_csv(profiles_path)
ranking <- qdesn_ssv2_read_csv(ranking_path)
target_ids <- c("laplace_t0p05", "normal_t0p25")
ranking <- ranking[ranking$target_cell_id %in% target_ids, , drop = FALSE]
profiles <- profiles[match(ranking$candidate_id, profiles$candidate_id), , drop = FALSE]
if (nrow(ranking) != 2L || anyNA(profiles$candidate_id) ||
    any(ranking$objective_value >= ranking$current_value)) {
  stop("The two targeted candidates do not satisfy the frozen sealed-improvement gate.",
       call. = FALSE)
}

stub <- file.path(repo_root, "config", "validation", qdesn_ssv2_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
targets$parent_request_path <- vapply(targets$parent_request_path, function(path) {
  if (grepl("^/", path)) path else file.path(repo_root, path)
}, character(1L))
targets <- targets[match(target_ids, targets$target_cell_id), , drop = FALSE]
if (anyNA(targets$target_cell_id)) stop("Target-cell contract is incomplete.", call. = FALSE)

scenario <- "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
expected_source_sha256 <- c(
  laplace_t0p05 = "5ca362d76dda664c1433efc005bf8e3c559026d45c701cb45852620ebd11ab9d",
  normal_t0p25 = "50091eee6f9df1720e72dd720329269452acb75fb33fa2de8ecae995c1e57fac"
)
source_rows <- list()
for (i in seq_len(nrow(targets))) {
  target <- targets[i, , drop = FALSE]
  family <- target$family[[1L]]
  tau_slug <- sub("[.]", "p", sprintf("%.2f", target$tau[[1L]]))
  full_dir <- file.path(canonical_root, scenario, family, paste0("tau_", tau_slug))
  full_path <- file.path(full_dir, "series_wide.csv")
  sim_path <- file.path(full_dir, "sim_output.rds")
  if (!file.exists(full_path) || !file.exists(sim_path)) {
    stop(sprintf("Canonical source is incomplete for %s.", target$target_cell_id[[1L]]),
         call. = FALSE)
  }
  full <- qdesn_ssv2_read_csv(full_path)
  if (nrow(full) != 10000L ||
      !all(c("t", "y", "mu", "q_target", "eps") %in% names(full))) {
    stop(sprintf("Canonical source schema failed for %s.", target$target_cell_id[[1L]]),
         call. = FALSE)
  }
  source_sha256 <- qdesn_ssv2_sha256(full_path)
  if (!identical(source_sha256,
                 unname(expected_source_sha256[[target$target_cell_id[[1L]]]]))) {
    stop(sprintf("Canonical source hash drifted for %s.",
                 target$target_cell_id[[1L]]), call. = FALSE)
  }
  request <- qdesn_ssv2_read_json(target$parent_request_path[[1L]])
  historical <- qdesn_ssv2_read_csv(request$root_spec$source_series_wide_path)
  if (!isTRUE(all.equal(full[8111:10000, names(historical), drop = FALSE], historical,
                        tolerance = 0, check.attributes = FALSE))) {
    stop(sprintf("Canonical source does not reproduce the article window for %s.",
                 target$target_cell_id[[1L]]), call. = FALSE)
  }
  source_rows[[i]] <- data.frame(
    source_id = "canonical_article", source_role = "canonical_confirmation",
    scenario = scenario, family = family, tau = target$tau[[1L]],
    series_wide_path = normalizePath(full_path, winslash = "/", mustWork = TRUE),
    series_wide_sha256 = source_sha256,
    sim_output_path = normalizePath(sim_path, winslash = "/", mustWork = TRUE),
    sim_output_sha256 = qdesn_ssv2_sha256(sim_path),
    historical_window_path = normalizePath(request$root_spec$source_series_wide_path,
                                           winslash = "/", mustWork = TRUE),
    historical_window_sha256 = qdesn_ssv2_sha256(request$root_spec$source_series_wide_path),
    historical_request_path = normalizePath(target$parent_request_path[[1L]],
                                            winslash = "/", mustWork = TRUE),
    historical_request_sha256 = qdesn_ssv2_sha256(target$parent_request_path[[1L]]),
    canonical_registry_hash_value = qdesn_ssv2_registry_hash,
    stringsAsFactors = FALSE
  )
}
source_registry <- do.call(rbind, source_rows)
source_registry_path <- qdesn_ssv2_write_csv(
  source_registry, file.path(output_root, "canonical_source_registry.csv")
)

plan_rows <- list(); staged_rows <- list(); k <- 0L
for (i in seq_len(nrow(profiles))) {
  profile <- profiles[i, , drop = FALSE]
  target <- targets[targets$target_cell_id == profile$target_cell_id[[1L]], , drop = FALSE]
  registry <- source_registry[source_registry$family == target$family[[1L]] &
    abs(source_registry$tau - target$tau[[1L]]) < 1e-10, , drop = FALSE]
  staged <- qdesn_ssv2_stage_source_window(
    registry, "canonical_article", profile$m[[1L]], profile$washout[[1L]],
    file.path(output_root, "canonical_windows")
  )
  staged_rows[[i]] <- staged
  for (chain_id in 1:3) {
    job <- qdesn_ssv2_make_job(repo_root, profile, target, staged, "confirmation",
                               source_registry_path, chain_id)
    job$study_contract$confirmation_scope <- "targeted_two_cell_full_budget"
    job$study_contract$selection_evidence_path <- ranking_path
    job$study_contract$selection_evidence_sha256 <- qdesn_ssv2_sha256(ranking_path)
    job$study_contract$article_promotion_automatic <- FALSE
    config_path <- file.path(output_root, "configs", paste0(job$job_id, ".json"))
    qdesn_ssv2_write_json(job, config_path)
    k <- k + 1L
    plan_rows[[k]] <- data.frame(
      job_id = job$job_id, stage = job$stage,
      target_cell_id = job$target_cell_id, candidate_id = job$candidate_id,
      chain_id = job$chain_id, source_id = job$source_id,
      source_role = job$source_role, objective_metric = job$objective_metric,
      current_value = job$current_value, comparator_value = job$comparator_value,
      config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
      config_sha256 = qdesn_ssv2_sha256(config_path),
      n_burn = job$config$inference$mcmc$n_burn,
      n_mcmc = job$config$inference$mcmc$n_mcmc,
      expected_n_burn = job$config$inference$mcmc$n_burn,
      expected_n_mcmc = job$config$inference$mcmc$n_mcmc,
      thin = job$config$inference$mcmc$thin,
      inference_method_id = job$inference_method_id,
      source_registry_hash_value = job$source_registry_hash_value,
      article_promotion_automatic = FALSE,
      stringsAsFactors = FALSE
    )
  }
}
plan <- do.call(rbind, plan_rows)
if (nrow(plan) != 6L || anyDuplicated(plan$job_id) ||
    !identical(sort(unique(plan$target_cell_id)), sort(target_ids)) ||
    any(table(plan$target_cell_id) != 3L)) {
  stop("Targeted confirmation plan must contain two cells and three chains each.",
       call. = FALSE)
}
plan_path <- qdesn_ssv2_write_csv(plan, file.path(output_root, "targeted_confirmation_plan.csv"))
windows_path <- qdesn_ssv2_write_csv(do.call(rbind, staged_rows),
                                     file.path(output_root, "canonical_window_registry.csv"))
excluded <- qdesn_ssv2_read_csv(file.path(screen_root, "sealed_closeout_ranking.csv"))
excluded <- excluded[!excluded$target_cell_id %in% target_ids, , drop = FALSE]
excluded$confirmation_decision <- "not_selected_sealed_metric_did_not_improve_current"
excluded_path <- qdesn_ssv2_write_csv(excluded,
                                      file.path(output_root, "excluded_cell_ledger.csv"))
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()), package_version = "1.0.0",
  method_id = "M0_v_collapsed_support_logit", stage = "confirmation",
  target_cells = as.list(target_ids), jobs = nrow(plan), chains_per_cell = 3L,
  n_burn = 5000L, n_mcmc = 20000L, thin = 1L,
  source_identity = "canonical_article_dgp_realization",
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
  source_registry = list(path = source_registry_path,
                         sha256 = qdesn_ssv2_sha256(source_registry_path)),
  windows = list(path = windows_path, sha256 = qdesn_ssv2_sha256(windows_path)),
  excluded_cells = list(path = excluded_path, sha256 = qdesn_ssv2_sha256(excluded_path)),
  selection_ranking = list(path = ranking_path, sha256 = qdesn_ssv2_sha256(ranking_path)),
  article_update_automatic = FALSE
), file.path(output_root, "targeted_confirmation_manifest.json"))
cat(sprintf("targeted_confirmation_jobs=%d cells=%d chains_per_cell=3\n",
            nrow(plan), length(target_ids)))
