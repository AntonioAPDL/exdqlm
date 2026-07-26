#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/",
  mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."), winslash = "/", mustWork = TRUE)

read_csv <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing input: %s", path), call. = FALSE)
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
num <- function(x) suppressWarnings(as.numeric(x))
bool_chr <- function(x) ifelse(!is.na(x) & x, "TRUE", "FALSE")

git_value <- function(args) {
  out <- system2("git", c("-C", repo_root, args), stdout = TRUE)
  if (!length(out)) NA_character_ else out[[1L]]
}

promotion_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726"
promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)

current_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_mcmc_current_best_20260723"
)
current_path <- file.path(current_root, "qdesn_dqlm_500obs_mcmc_current_best_clean_20260723.csv")

v2_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions",
  "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726"
)
v2_path <- file.path(v2_root, "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726_all_candidates.csv")

ms_run_tag <- "qdesn-tt500-mcmc-normal005-exal-msv1-full-20260726__git-98b8012"
ms_campaign <- "20260726-124857__git-98b8012"
ms_results_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_normal005_exal_multiseed_v1",
  ms_run_tag, ms_campaign
)
ms_root_dirs <- list.dirs(file.path(ms_results_root, "roots"), recursive = FALSE, full.names = TRUE)
if (length(ms_root_dirs) != 1L) stop("Expected exactly one multiseed confirmation root.", call. = FALSE)
ms_path <- file.path(ms_root_dirs[[1L]], "tables", "mcmc_seed_selection.csv")

current <- read_csv(current_path)
v2_raw <- read_csv(v2_path)
ms_raw <- read_csv(ms_path)

required_current <- c(
  "model_variant", "family", "tau", "fit_size", "candidate_id",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000", "status", "signoff_grade",
  "run_tag", "source_registry_hash_value"
)
missing_current <- setdiff(required_current, names(current))
if (length(missing_current)) {
  stop(sprintf("Current table missing columns: %s", paste(missing_current, collapse = ", ")), call. = FALSE)
}

registry_hash <- unique(current$source_registry_hash_value)
if (length(registry_hash) != 1L || !nzchar(registry_hash)) {
  stop("Current table must carry exactly one source registry hash.", call. = FALSE)
}

standard_columns <- c(
  "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "status", "signoff_grade", "comparison_eligible", "run_tag",
  "source_key", "source_path", "source_table_sha256",
  "source_registry_hash_value"
)

standardize_current <- function(x) {
  out <- data.frame(
    model_variant = x$model_variant,
    family = x$family,
    tau = num(x$tau),
    fit_size = as.integer(x$fit_size),
    candidate_id = x$candidate_id,
    spec_id = if ("spec_id" %in% names(x)) x$spec_id else NA_character_,
    fit_qtrue_rmse = num(x$fit_qtrue_rmse),
    forecast_qtrue_mae_H1000 = num(x$forecast_qtrue_mae_H1000),
    forecast_check_loss_H1000 = num(x$forecast_check_loss_H1000),
    status = x$status,
    signoff_grade = x$signoff_grade,
    comparison_eligible = as.character(x$comparison_eligible),
    run_tag = x$run_tag,
    source_key = x$source_key,
    source_path = normalizePath(current_path, winslash = "/", mustWork = TRUE),
    source_table_sha256 = sha256(current_path),
    source_registry_hash_value = x$source_registry_hash_value,
    stringsAsFactors = FALSE
  )
  out[, standard_columns, drop = FALSE]
}

standardize_v2 <- function(x) {
  out <- data.frame(
    model_variant = ifelse(x$likelihood_family == "al", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
    family = x$family,
    tau = num(x$tau),
    fit_size = as.integer(x$fit_size),
    candidate_id = x$screening_profile_id,
    spec_id = x$spec_id,
    fit_qtrue_rmse = num(x$fit_qtrue_rmse),
    forecast_qtrue_mae_H1000 = num(x$forecast_qtrue_mae_H1000),
    forecast_check_loss_H1000 = num(x$forecast_check_loss_H1000),
    status = x$status,
    signoff_grade = x$signoff_grade,
    comparison_eligible = as.character(x$comparison_eligible),
    run_tag = "qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c",
    source_key = "qdesn_percase_rhs_v2",
    source_path = normalizePath(v2_path, winslash = "/", mustWork = TRUE),
    source_table_sha256 = sha256(v2_path),
    source_registry_hash_value = registry_hash,
    stringsAsFactors = FALSE
  )
  out[, standard_columns, drop = FALSE]
}

standardize_multiseed <- function(x) {
  horizon <- lapply(seq_len(nrow(x)), function(i) {
    path <- file.path(x$seed_method_dir[[i]], "tables", "forecast_horizon_summary.csv")
    tab <- read_csv(path)
    row <- tab[tab$horizon == 1000L, , drop = FALSE]
    if (nrow(row) != 1L) stop(sprintf("Expected one H=1000 row: %s", path), call. = FALSE)
    row
  })
  out <- data.frame(
    model_variant = "qdesn_exal_rhs_ns",
    family = x$family,
    tau = num(x$tau),
    fit_size = as.integer(x$fit_size),
    candidate_id = paste0(x$screening_profile_id, "__seed_", sprintf("%02d", x$seed_rep)),
    spec_id = x$spec_id,
    fit_qtrue_rmse = num(x$train_qtrue_rmse),
    forecast_qtrue_mae_H1000 = vapply(horizon, function(z) num(z$qtrue_mae[[1L]]), numeric(1L)),
    forecast_check_loss_H1000 = vapply(horizon, function(z) num(z$pinball_tau[[1L]]), numeric(1L)),
    status = x$status,
    signoff_grade = x$signoff_grade,
    comparison_eligible = as.character(x$comparison_eligible),
    run_tag = ms_run_tag,
    source_key = "qdesn_normal005_exal_multiseed_v1",
    source_path = normalizePath(ms_path, winslash = "/", mustWork = TRUE),
    source_table_sha256 = sha256(ms_path),
    source_registry_hash_value = registry_hash,
    stringsAsFactors = FALSE
  )
  out[, standard_columns, drop = FALSE]
}

all_candidates <- rbind(
  standardize_current(current),
  standardize_v2(v2_raw),
  standardize_multiseed(ms_raw)
)
all_candidates <- all_candidates[
  all_candidates$fit_size == 500L &
    is.finite(all_candidates$fit_qtrue_rmse) &
    is.finite(all_candidates$forecast_qtrue_mae_H1000) &
    is.finite(all_candidates$forecast_check_loss_H1000),
  ,
  drop = FALSE
]

key <- paste(
  all_candidates$model_variant, all_candidates$family,
  sprintf("%.8f", all_candidates$tau), all_candidates$fit_size,
  sep = "\r"
)
metric_names <- c(
  fit_qtrue_rmse = "fit",
  forecast_qtrue_mae_H1000 = "forecast_mae",
  forecast_check_loss_H1000 = "forecast_check"
)

metric_rows <- list()
for (cell_key in sort(unique(key))) {
  block <- all_candidates[key == cell_key, , drop = FALSE]
  for (metric in names(metric_names)) {
    ord <- order(num(block[[metric]]), block$run_tag, block$candidate_id, na.last = TRUE)
    winner <- block[ord[[1L]], , drop = FALSE]
    winner$metric_name <- metric
    winner$metric_role <- metric_names[[metric]]
    winner$metric_value <- num(winner[[metric]])
    metric_rows[[length(metric_rows) + 1L]] <- winner
  }
}
metric_winners <- do.call(rbind, metric_rows)

current_std <- standardize_current(current)
current_key <- paste(
  current_std$model_variant, current_std$family,
  sprintf("%.8f", current_std$tau), current_std$fit_size,
  sep = "\r"
)
comparison_rows <- lapply(seq_len(nrow(metric_winners)), function(i) {
  row <- metric_winners[i, , drop = FALSE]
  k <- paste(row$model_variant, row$family, sprintf("%.8f", row$tau), row$fit_size, sep = "\r")
  old <- current_std[current_key == k, , drop = FALSE]
  old_value <- if (nrow(old)) num(old[[row$metric_name]][[1L]]) else NA_real_
  data.frame(
    model_variant = row$model_variant,
    family = row$family,
    tau = row$tau,
    fit_size = row$fit_size,
    metric_name = row$metric_name,
    previous_value = old_value,
    promoted_value = row$metric_value,
    absolute_improvement = old_value - row$metric_value,
    relative_improvement = (old_value - row$metric_value) / old_value,
    promoted_candidate_id = row$candidate_id,
    promoted_run_tag = row$run_tag,
    promoted_status = row$status,
    promoted_signoff_grade = row$signoff_grade,
    changed_from_article_baseline = bool_chr(!is.finite(old_value) || row$metric_value < old_value - 1e-10),
    stringsAsFactors = FALSE
  )
})
metric_comparison <- do.call(rbind, comparison_rows)
metric_promotions <- metric_comparison[metric_comparison$changed_from_article_baseline == "TRUE", , drop = FALSE]

winner_key <- paste(
  metric_winners$model_variant, metric_winners$family,
  sprintf("%.8f", metric_winners$tau), metric_winners$fit_size,
  sep = "\r"
)
cells <- sort(unique(winner_key))
envelope_rows <- lapply(cells, function(k) {
  block <- metric_winners[winner_key == k, , drop = FALSE]
  pick <- function(metric) block[block$metric_name == metric, , drop = FALSE][1L, , drop = FALSE]
  fit <- pick("fit_qtrue_rmse")
  mae <- pick("forecast_qtrue_mae_H1000")
  check <- pick("forecast_check_loss_H1000")
  grades <- c(fit$signoff_grade, mae$signoff_grade, check$signoff_grade)
  grade <- if ("FAIL" %in% grades) "FAIL" else if ("WARN" %in% grades) "WARN" else "PASS"
  mixed <- length(unique(c(fit$candidate_id, mae$candidate_id, check$candidate_id))) > 1L
  data.frame(
    model_variant = fit$model_variant,
    family = fit$family,
    tau = fit$tau,
    fit_size = fit$fit_size,
    comparison_eligible = "STATUS_AGNOSTIC",
    status = "SUCCESS",
    signoff_grade = grade,
    metric_source_mixed = bool_chr(mixed),
    fit_qtrue_rmse = fit$metric_value,
    forecast_qtrue_mae_H1000 = mae$metric_value,
    forecast_check_loss_H1000 = check$metric_value,
    fit_source_candidate_id = fit$candidate_id,
    fit_source_run_tag = fit$run_tag,
    fit_source_signoff_grade = fit$signoff_grade,
    fit_source_status = fit$status,
    fit_source_path = fit$source_path,
    fit_source_sha256 = fit$source_table_sha256,
    forecast_mae_source_candidate_id = mae$candidate_id,
    forecast_mae_source_run_tag = mae$run_tag,
    forecast_mae_source_signoff_grade = mae$signoff_grade,
    forecast_mae_source_status = mae$status,
    forecast_mae_source_path = mae$source_path,
    forecast_mae_source_sha256 = mae$source_table_sha256,
    forecast_check_source_candidate_id = check$candidate_id,
    forecast_check_source_run_tag = check$run_tag,
    forecast_check_source_signoff_grade = check$signoff_grade,
    forecast_check_source_status = check$status,
    forecast_check_source_path = check$source_path,
    forecast_check_source_sha256 = check$source_table_sha256,
    source_key = "status_agnostic_metricwise_calibrated_envelope",
    source_promotion_id = promotion_id,
    source_table_sha256 = paste(sort(unique(c(fit$source_table_sha256, mae$source_table_sha256, check$source_table_sha256))), collapse = ";"),
    source_registry_hash_value = registry_hash,
    stringsAsFactors = FALSE
  )
})
envelope <- do.call(rbind, envelope_rows)
envelope <- envelope[order(envelope$model_variant, envelope$family, envelope$tau), , drop = FALSE]

expected <- expand.grid(
  model_variant = c("dqlm_c13_mcmc", "exdqlm_c13_mcmc", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50),
  stringsAsFactors = FALSE
)
observed_keys <- paste(envelope$model_variant, envelope$family, sprintf("%.2f", envelope$tau))
expected_keys <- paste(expected$model_variant, expected$family, sprintf("%.2f", expected$tau))
if (nrow(envelope) != 36L || !setequal(observed_keys, expected_keys)) {
  stop("Metric envelope does not cover the expected 36 model/family/quantile cells.", call. = FALSE)
}

followup <- envelope[envelope$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"), , drop = FALSE]
external <- envelope[envelope$model_variant %in% c("dqlm_c13_mcmc", "exdqlm_c13_mcmc"), , drop = FALSE]
external_key <- paste(external$family, sprintf("%.8f", external$tau), external$fit_size, sep = "\r")
followup_key <- paste(followup$family, sprintf("%.8f", followup$tau), followup$fit_size, sep = "\r")
followup$external_best_fit_rmse <- vapply(followup_key, function(k) {
  min(external$fit_qtrue_rmse[external_key == k], na.rm = TRUE)
}, numeric(1L))
followup$external_best_forecast_mae <- vapply(followup_key, function(k) {
  min(external$forecast_qtrue_mae_H1000[external_key == k], na.rm = TRUE)
}, numeric(1L))
followup$external_best_forecast_check <- vapply(followup_key, function(k) {
  min(external$forecast_check_loss_H1000[external_key == k], na.rm = TRUE)
}, numeric(1L))
followup$fit_ratio_to_external_best <- followup$fit_qtrue_rmse / followup$external_best_fit_rmse
followup$forecast_mae_ratio_to_external_best <- followup$forecast_qtrue_mae_H1000 / followup$external_best_forecast_mae
followup$forecast_check_ratio_to_external_best <- followup$forecast_check_loss_H1000 / followup$external_best_forecast_check
followup$worst_ratio_to_external_best <- apply(
  followup[, c(
    "fit_ratio_to_external_best", "forecast_mae_ratio_to_external_best",
    "forecast_check_ratio_to_external_best"
  )],
  1L,
  function(z) max(num(z), na.rm = TRUE)
)
followup$target_screen_role <- "case_specific_mcmc_metric_envelope_improvement"
followup$primary_gap <- apply(
  followup[, c(
    "fit_ratio_to_external_best", "forecast_mae_ratio_to_external_best",
    "forecast_check_ratio_to_external_best"
  )],
  1L,
  function(z) sub("_ratio_to_external_best$", "", names(z)[which.max(num(z))])
)
followup$recommended_screen_axis <- ifelse(
  followup$primary_gap == "fit",
  "increase nonlinear feature capacity while tightening RHS global shrinkage",
  ifelse(
    followup$primary_gap == "forecast_mae",
    "case-specific memory/rho/alpha/reservoir-width screen with fixed rolling-origin protocol",
    "likelihood-scale and RHS tau0 refinement around the current metric source"
  )
)
followup$promotion_target <- "reduce the named metric without regressing either other metric beyond its current envelope value"
followup$launch_status <- "prepared_not_launched"
followup <- followup[
  order(-followup$worst_ratio_to_external_best, followup$family, followup$tau, followup$model_variant),
  ,
  drop = FALSE
]
followup$priority <- seq_len(nrow(followup))

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
all_path <- write_csv(all_candidates, file.path(promotion_root, paste0(promotion_id, "_all_candidates.csv")))
winners_path <- write_csv(metric_winners, file.path(promotion_root, paste0(promotion_id, "_metric_winners.csv")))
comparison_path <- write_csv(metric_comparison, file.path(promotion_root, paste0(promotion_id, "_vs_article_baseline.csv")))
promotions_path <- write_csv(metric_promotions, file.path(promotion_root, paste0(promotion_id, "_promotions.csv")))
envelope_path <- write_csv(envelope, file.path(promotion_root, paste0(promotion_id, "_article_envelope.csv")))
followup_path <- write_csv(followup, file.path(promotion_root, paste0(promotion_id, "_targeted_screening_handoff.csv")))

source_manifest <- data.frame(
  source_id = c("article_current_best", "percase_rhs_v2", "normal005_exal_multiseed_v1"),
  path = normalizePath(c(current_path, v2_path, ms_path), winslash = "/", mustWork = TRUE),
  sha256 = vapply(c(current_path, v2_path, ms_path), sha256, character(1L)),
  role = c("article_baseline", "broad_percase_candidates", "targeted_multiseed_confirmation"),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

outputs <- c(all_path, winners_path, comparison_path, promotions_path, envelope_path, followup_path, source_manifest_path)
file_manifest <- data.frame(
  path = outputs,
  sha256 = vapply(outputs, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

manifest_path <- file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  validation_branch = git_value(c("branch", "--show-current")),
  validation_commit_at_materialization = git_value(c("rev-parse", "HEAD")),
  source_registry_hash_name = "sha256",
  source_registry_hash_value = registry_hash,
  status_policy = "status_agnostic_as_explicitly_requested; diagnostic status retained per metric",
  selection_unit = "model_variant x family x tau x metric",
  selection_rule = "minimum observed finite metric; no mixing within a metric; separate provenance retained for each metric",
  interpretation = "calibrated metric-wise envelope; displayed metrics may originate from different candidate specifications or seeds",
  n_candidates = nrow(all_candidates),
  n_envelope_rows = nrow(envelope),
  n_metric_promotions = nrow(metric_promotions),
  files = lapply(seq_len(nrow(file_manifest)), function(i) as.list(file_manifest[i, , drop = FALSE]))
)
json_text <- jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE, na = "null")
writeLines(json_text, manifest_path, useBytes = TRUE)

readme <- c(
  "# Q-DESN/DQLM 500-Observation MCMC Metric Envelope",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Validation branch: `%s`", manifest$validation_branch),
  sprintf("- Materialization commit: `%s`", manifest$validation_commit_at_materialization),
  sprintf("- Source registry SHA-256: `%s`", registry_hash),
  sprintf("- Candidate rows audited: `%d`", nrow(all_candidates)),
  sprintf("- Complete article cells: `%d/36`", nrow(envelope)),
  sprintf("- Metrics improved relative to the prior article baseline: `%d`", nrow(metric_promotions)),
  "",
  "## Policy",
  "",
  "This artifact implements the explicitly requested status-agnostic promotion policy.",
  "Diagnostic status is never discarded: each displayed metric retains its own candidate,",
  "run tag, source path, source hash, status, and signoff grade.",
  "",
  "The envelope is metric-wise. A row may combine the best fit RMSE, forecast MAE, and",
  "forecast check loss from different calibrated candidates. It must therefore be described",
  "as a calibrated metric envelope, not as the output of one common fitted specification.",
  "",
  "## Outputs",
  "",
  sprintf("- Article envelope: `%s`", basename(envelope_path)),
  sprintf("- Metric promotions: `%s`", basename(promotions_path)),
  sprintf("- Metric winners with provenance: `%s`", basename(winners_path)),
  sprintf("- Next-screen handoff: `%s`", basename(followup_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("candidate_rows: %d\n", nrow(all_candidates)))
cat(sprintf("envelope_rows: %d\n", nrow(envelope)))
cat(sprintf("metric_promotions: %d\n", nrow(metric_promotions)))
