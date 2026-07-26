#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
model_to_likelihood <- function(x) {
  out <- rep(NA_character_, length(x))
  out[as.character(x) == "qdesn_al_rhs_ns"] <- "al"
  out[as.character(x) == "qdesn_exal_rhs_ns"] <- "exal"
  out
}
compact_num <- function(x) {
  if (!length(x) || all(is.na(x))) return(NA_character_)
  vals <- sort(unique(num(x)))
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(NA_character_)
  paste(signif(vals, 6), collapse = ";")
}
collapse_chr <- function(x) {
  vals <- sort(unique(as.character(x)))
  vals <- vals[nzchar(vals) & !is.na(vals)]
  if (!length(vals)) return(NA_character_)
  paste(vals, collapse = ";")
}

md_table <- function(x, cols, max_rows = 40L) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- vapply(y[i, , drop = TRUE], function(v) {
      v <- as.character(v)
      v[is.na(v)] <- ""
      gsub("\n", " ", v, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}

stage_file <- as.character(get_arg("--stage-file", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2"))[1L]
stamp <- as.character(get_arg("--stamp", format(Sys.Date(), "%Y%m%d")))[1L]
closeout_root <- resolve_path(get_arg(
  "--closeout-root",
  file.path("validation", "fitforecast_v2", "promotions", "qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725")
))
out_root <- resolve_path(get_arg(
  "--out-root",
  file.path("validation", "fitforecast_v2", "promotions", paste0("qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_", stamp))
), must_work = FALSE)

profiles_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_profiles.csv")))
assignments_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv")))
defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")))
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")))
target_specs_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv")))
materialization_manifest_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")))

same_variant_path <- file.path(closeout_root, "qdesn_dqlm_500obs_mcmc_status_agnostic_same_variant_winners_20260725.csv")
all_candidates_path <- file.path(closeout_root, "qdesn_dqlm_500obs_mcmc_status_agnostic_all_candidates_20260725.csv")

profiles <- read_csv(profiles_path)
assignments <- read_csv(assignments_path)
target_specs <- read_csv(target_specs_path)
same_variant <- read_csv(same_variant_path)
all_candidates <- read_csv(all_candidates_path)
defaults <- yaml::read_yaml(defaults_path)
materialization_manifest <- jsonlite::read_json(materialization_manifest_path, simplifyVector = FALSE)

target_specs$cell_key <- paste(target_specs$family.x, tau_key(target_specs$tau.x), target_specs$likelihood_target, sep = "\r")
target_specs$profile_key <- as.character(target_specs$screening_profile_id.x)
target_specs$target_spec_order <- seq_len(nrow(target_specs))
profiles$profile_key <- as.character(profiles$screening_profile_id)
inventory <- merge(
  target_specs,
  profiles[, c(
    "profile_key", "source_screening_profile_id", "D", "n_each", "n_tilde_each",
    "m", "alpha", "rho", "pi_w", "pi_in", "readout_y_lags", "reservoir_lags",
    "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "x_feature_count",
    "profile_source_path"
  ), drop = FALSE],
  by = "profile_key",
  all.x = TRUE,
  sort = FALSE
)
inventory <- inventory[order(inventory$target_spec_order), , drop = FALSE]
inventory$cell_candidate_rank <- ave(seq_len(nrow(inventory)), inventory$cell_key, FUN = seq_along)
for (nm in c(
  "rhs_tau0", "readout_y_lags", "reservoir_lags", "dimension_p_estimate",
  "p_over_n_tt500"
)) {
  y_nm <- paste0(nm, ".y")
  x_nm <- paste0(nm, ".x")
  if (!nm %in% names(inventory)) {
    if (y_nm %in% names(inventory)) {
      inventory[[nm]] <- inventory[[y_nm]]
    } else if (x_nm %in% names(inventory)) {
      inventory[[nm]] <- inventory[[x_nm]]
    } else {
      inventory[[nm]] <- NA
    }
  }
}
inventory_out <- inventory[, c(
  "family.x", "tau.x", "likelihood_target", "cell_key", "cell_candidate_rank",
  "spec_id", "root_id", "profile_key", "source_screening_profile_id",
  "candidate_source", "selection_reason", "D", "n_each", "n_tilde_each",
  "m", "alpha", "rho", "pi_w", "pi_in", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "profile_source_path"
), drop = FALSE]
names(inventory_out)[names(inventory_out) == "family.x"] <- "family"
names(inventory_out)[names(inventory_out) == "tau.x"] <- "tau"
names(inventory_out)[names(inventory_out) == "profile_key"] <- "screening_profile_id"
inventory_out <- inventory_out[order(inventory_out$family, inventory_out$tau, inventory_out$likelihood_target, inventory_out$cell_candidate_rank), , drop = FALSE]

current <- same_variant[same_variant$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"), , drop = FALSE]
current$likelihood_target <- model_to_likelihood(current$model_variant)
current$cell_key <- paste(current$family, tau_key(current$tau), current$likelihood_target, sep = "\r")

benchmark_pool <- all_candidates[all_candidates$model_variant %in% c("dqlm_c13_mcmc", "exdqlm_c13_mcmc"), , drop = FALSE]
benchmark_pool$bench_key <- paste(benchmark_pool$family, tau_key(benchmark_pool$tau), sep = "\r")
benchmark_pool$forecast_qtrue_mae_H1000 <- num(benchmark_pool$forecast_qtrue_mae_H1000)
benchmark <- do.call(rbind, lapply(split(benchmark_pool, benchmark_pool$bench_key), function(rows) {
  rows <- rows[order(num(rows$forecast_qtrue_mae_H1000), num(rows$fit_qtrue_rmse)), , drop = FALSE]
  rows[1L, , drop = FALSE]
}))
if (is.null(benchmark) || !nrow(benchmark)) {
  benchmark <- data.frame(stringsAsFactors = FALSE)
}
benchmark <- benchmark[, c(
  "family", "tau", "model_variant", "candidate_id", "fit_qtrue_rmse",
  "fit_check_loss", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "source_promotion_id", "run_tag", "validation_run_commit"
), drop = FALSE]
names(benchmark) <- paste0("benchmark_", names(benchmark))
names(benchmark)[names(benchmark) == "benchmark_family"] <- "family"
names(benchmark)[names(benchmark) == "benchmark_tau"] <- "tau"

ledger <- merge(current, benchmark, by = c("family", "tau"), all.x = TRUE, sort = FALSE)
ledger$fit_rmse_ratio_to_best_dqlm <- num(ledger$fit_qtrue_rmse) / num(ledger$benchmark_fit_qtrue_rmse)
ledger$forecast_mae_ratio_to_best_dqlm <- num(ledger$forecast_qtrue_mae_H1000) / num(ledger$benchmark_forecast_qtrue_mae_H1000)
ledger$check_loss_ratio_to_best_dqlm <- num(ledger$forecast_check_loss_H1000) / num(ledger$benchmark_forecast_check_loss_H1000)
ledger$action <- "freeze_or_light_confirm"
ledger$action[as.character(ledger$signoff_grade) == "FAIL"] <- "tier_a_diagnostic_risk_confirmation"
needs_forecast <- is.finite(ledger$forecast_mae_ratio_to_best_dqlm) & ledger$forecast_mae_ratio_to_best_dqlm > 1.25
ledger$action[needs_forecast & ledger$action != "tier_a_diagnostic_risk_confirmation"] <- "tier_b_forecast_repair_confirmation"
needs_fit <- is.finite(ledger$fit_rmse_ratio_to_best_dqlm) & ledger$fit_rmse_ratio_to_best_dqlm > 1.25
ledger$action[needs_fit & ledger$action == "freeze_or_light_confirm"] <- "tier_b_fit_balance_confirmation"
ledger$current_disposition <- ifelse(
  ledger$action == "freeze_or_light_confirm",
  "current_same_variant_winner_is_usable_pending_light_confirmation",
  "run_percase_mcmc_candidates_before_article_promotion"
)
ledger <- ledger[order(ledger$family, ledger$tau, ledger$likelihood_target), , drop = FALSE]
ledger_out <- ledger[, c(
  "family", "tau", "model_variant", "likelihood_target", "candidate_id", "spec_id",
  "source_promotion_id", "run_tag", "signoff_grade", "status",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "benchmark_model_variant", "benchmark_candidate_id", "benchmark_fit_qtrue_rmse",
  "benchmark_forecast_qtrue_mae_H1000", "benchmark_forecast_check_loss_H1000",
  "fit_rmse_ratio_to_best_dqlm", "forecast_mae_ratio_to_best_dqlm",
  "check_loss_ratio_to_best_dqlm", "action", "current_disposition"
), drop = FALSE]

plan_rows <- do.call(rbind, lapply(split(inventory_out, inventory_out$cell_key), function(rows) {
  key <- rows$cell_key[[1L]]
  current_row <- ledger_out[paste(ledger_out$family, tau_key(ledger_out$tau), ledger_out$likelihood_target, sep = "\r") == key, , drop = FALSE]
  data.frame(
    family = rows$family[[1L]],
    tau = as.numeric(rows$tau[[1L]]),
    likelihood_target = rows$likelihood_target[[1L]],
    model_variant = if (rows$likelihood_target[[1L]] == "al") "qdesn_al_rhs_ns" else "qdesn_exal_rhs_ns",
    current_best_candidate_id = if (nrow(current_row)) current_row$candidate_id[[1L]] else NA_character_,
    current_signoff_grade = if (nrow(current_row)) current_row$signoff_grade[[1L]] else NA_character_,
    current_forecast_mae_ratio_to_best_dqlm = if (nrow(current_row)) current_row$forecast_mae_ratio_to_best_dqlm[[1L]] else NA_real_,
    current_fit_rmse_ratio_to_best_dqlm = if (nrow(current_row)) current_row$fit_rmse_ratio_to_best_dqlm[[1L]] else NA_real_,
    action = if (nrow(current_row)) current_row$action[[1L]] else "missing_current_winner",
    n_mcmc_candidate_specs = nrow(rows),
    candidate_sources = collapse_chr(rows$candidate_source),
    D_values = compact_num(rows$D),
    n_each_values = compact_num(rows$n_each),
    m_values = compact_num(rows$m),
    alpha_values = compact_num(rows$alpha),
    rho_values = compact_num(rows$rho),
    rhs_tau0_values = compact_num(rows$rhs_tau0),
    target_spec_ids = collapse_chr(rows$spec_id),
    root_ids = collapse_chr(rows$root_id),
    launch_status = "not_launched_prepared_for_mcmc_confirmation",
    stringsAsFactors = FALSE
  )
}))
plan_rows <- plan_rows[order(plan_rows$family, plan_rows$tau, plan_rows$likelihood_target), , drop = FALSE]

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
inventory_path <- write_csv(inventory_out, file.path(out_root, paste0("qdesn_tt500_mcmc_percase_rhs_v2_candidate_inventory_", stamp, ".csv")))
ledger_path <- write_csv(ledger_out, file.path(out_root, paste0("qdesn_tt500_mcmc_percase_rhs_v2_current_percase_ledger_", stamp, ".csv")))
plan_path <- write_csv(plan_rows, file.path(out_root, paste0("qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_plan_", stamp, ".csv")))

file_manifest <- data.frame(
  role = c(
    "profiles", "assignments", "defaults", "grid", "target_specs",
    "materialization_manifest", "same_variant_winners", "all_candidates",
    "inventory", "percase_ledger", "prelaunch_plan"
  ),
  path = c(
    profiles_path, assignments_path, defaults_path, grid_path, target_specs_path,
    materialization_manifest_path, same_variant_path, all_candidates_path,
    inventory_path, ledger_path, plan_path
  ),
  sha256 = NA_character_,
  stringsAsFactors = FALSE
)
file_manifest$sha256 <- vapply(file_manifest$path, sha256_file, character(1L))
file_manifest_path <- write_csv(file_manifest, file.path(out_root, "file_manifest.csv"))

summary <- data.frame(
  generated_at = as.character(Sys.time()),
  stage_file = stage_file,
  n_current_percase_cells = nrow(ledger_out),
  n_mcmc_target_specs = nrow(target_specs),
  n_mcmc_candidate_specs = nrow(inventory_out),
  n_cell_likelihoods = length(unique(inventory_out$cell_key)),
  n_unique_profile_likelihood_specs = length(unique(inventory_out$screening_profile_id)),
  n_action_freeze_or_light_confirm = sum(plan_rows$action == "freeze_or_light_confirm"),
  n_action_diagnostic_confirmation = sum(plan_rows$action == "tier_a_diagnostic_risk_confirmation"),
  n_action_forecast_repair = sum(plan_rows$action == "tier_b_forecast_repair_confirmation"),
  n_action_fit_balance = sum(plan_rows$action == "tier_b_fit_balance_confirmation"),
  mcmc_n_burn = as.integer(defaults$study_contract$budget$mcmc_n_burn %||% NA_integer_)[1L],
  mcmc_n_mcmc = as.integer(defaults$study_contract$budget$mcmc_n_mcmc %||% NA_integer_)[1L],
  progress_every = as.integer(defaults$pipeline$inference$mcmc$progress_every %||% NA_integer_)[1L],
  init_from_vb = isTRUE(defaults$pipeline$inference$mcmc$init_from_vb),
  keep_draws = isTRUE(defaults$pipeline$outputs$keep_draws),
  save_forecast_objects = isTRUE(defaults$pipeline$outputs$save_forecast_objects),
  retain_full_rds_on_failure = isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure),
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary, file.path(out_root, paste0("qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_summary_", stamp, ".csv")))

readme_lines <- c(
  "# Q-DESN 500-Observation MCMC Per-Case RHS v2 Prelaunch",
  "",
  sprintf("- generated_at: `%s`", summary$generated_at[[1L]]),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- current per-case cells: `%d`", nrow(ledger_out)),
  sprintf("- target MCMC atomic specs: `%d`", nrow(target_specs)),
  sprintf("- candidate cell-likelihoods: `%d`", length(unique(inventory_out$cell_key))),
  sprintf("- source materialization manifest: `%s`", materialization_manifest_path),
  "",
  "## Intent",
  "",
  "This is a per-case calibration handoff, not a global-specification search. Each family, quantile, and likelihood target receives its own slate of historical VB-derived candidates, and MCMC is the confirmation layer.",
  "",
  "## Current Per-Case Disposition",
  "",
  md_table(plan_rows, c(
    "family", "tau", "likelihood_target", "current_best_candidate_id",
    "current_signoff_grade", "current_forecast_mae_ratio_to_best_dqlm",
    "current_fit_rmse_ratio_to_best_dqlm", "action", "n_mcmc_candidate_specs"
  ), max_rows = 24L),
  "",
  "## Candidate Source Mix",
  "",
  md_table(as.data.frame(table(candidate_source = inventory_out$candidate_source), stringsAsFactors = FALSE), c("candidate_source", "Freq")),
  "",
  "## Launch Gate",
  "",
  "- Full MCMC confirmation uses `init_from_vb = TRUE`, `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`, `progress_every = 50`.",
  "- Outputs stay storage-light: no retained routine draws, forecast objects, or failure `.rds` payloads.",
  "- Article-facing promotion is blocked until the full run completes and a strict closeout chooses per-case winners.",
  "",
  sprintf("- candidate inventory: `%s`", inventory_path),
  sprintf("- current per-case ledger: `%s`", ledger_path),
  sprintf("- prelaunch plan: `%s`", plan_path),
  sprintf("- summary: `%s`", summary_path),
  sprintf("- file manifest: `%s`", file_manifest_path)
)
readme_path <- file.path(out_root, "README.md")
writeLines(readme_lines, readme_path, useBytes = TRUE)
readme_path <- normalizePath(readme_path, winslash = "/", mustWork = TRUE)

manifest <- list(
  generated_at = summary$generated_at[[1L]],
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  purpose = "per_case_qdesn_rhs_mcmc_confirmation_handoff",
  per_case_policy = "family_tau_likelihood_specific_candidates; no global specification winner",
  materialization_manifest_stage = materialization_manifest$stage_file %||% stage_file,
  counts = as.list(summary[1L, setdiff(names(summary), "generated_at"), drop = FALSE]),
  outputs = list(
    out_root = out_root,
    candidate_inventory = inventory_path,
    percase_ledger = ledger_path,
    prelaunch_plan = plan_path,
    summary = summary_path,
    readme = readme_path,
    file_manifest = file_manifest_path
  ),
  source_files = as.list(file_manifest[, c("role", "path", "sha256")])
)
manifest_path <- write_json(manifest, file.path(out_root, paste0("qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_manifest_", stamp, ".json")))

cat(sprintf("out_root: %s\n", out_root))
cat(sprintf("candidate_inventory: %s\n", inventory_path))
cat(sprintf("percase_ledger: %s\n", ledger_path))
cat(sprintf("prelaunch_plan: %s\n", plan_path))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_target_specs: %d\n", nrow(target_specs)))
cat(sprintf("n_cell_likelihoods: %d\n", length(unique(inventory_out$cell_key))))
