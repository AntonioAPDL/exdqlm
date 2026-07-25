#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
})

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

date_stamp <- "20260725"
stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c"
run_tag <- "qdesn-tt500-mcmc-rhsrepair-v1c-full-20260724-194917__git-79931ca"
campaign_stamp <- "20260724-195157__git-79931ca"
promotion_id <- paste0("qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_", date_stamp)

results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", stage, run_tag, campaign_stamp)
report_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", stage, run_tag, campaign_stamp)
campaign_fit_path <- file.path(report_root, "tables", "campaign_fit_summary.csv")
previous_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", "qdesn_dqlm_500obs_mcmc_current_best_20260723")
previous_all_path <- file.path(previous_root, "qdesn_dqlm_500obs_mcmc_current_best_all_candidates_20260723.csv")
previous_cell_winners_path <- file.path(previous_root, "qdesn_dqlm_500obs_mcmc_current_best_cell_winners_20260723.csv")
promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)

num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
bool_chr <- function(x) {
  if (is.logical(x)) return(ifelse(x, "TRUE", "FALSE"))
  toupper(trimws(as.character(x)))
}
col_or <- function(x, nm, default = NA) {
  if (nm %in% names(x)) x[[nm]] else rep(default, nrow(x))
}
fmt <- function(x, digits = 3L) {
  x <- num(x)
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, trim = TRUE, scientific = FALSE))
}
read_csv <- function(path) {
  utils::read.csv(normalizePath(path, winslash = "/", mustWork = TRUE), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) {
  unname(tools::sha256sum(normalizePath(path, winslash = "/", mustWork = TRUE)))
}
git_value <- function(args) {
  out <- tryCatch(system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}
objective <- function(fit_rmse, forecast_rmse, forecast_check) {
  num(fit_rmse) + num(forecast_rmse) + num(forecast_check)
}
best_by_objective <- function(x) {
  if (!nrow(x)) return(x)
  generation_rank <- if ("source_generation" %in% names(x)) {
    ifelse(as.character(x$source_generation) == "v1c_20260725", 1L, 0L)
  } else {
    rep(0L, nrow(x))
  }
  x[order(
    round(num(x$decision_objective), 8L),
    round(num(x$forecast_qtrue_mae_H1000), 8L),
    round(num(x$fit_qtrue_rmse), 8L),
    generation_rank,
    x$candidate_id
  ), , drop = FALSE][1L, , drop = FALSE]
}
split_best <- function(x, key) {
  if (!nrow(x)) return(x[FALSE, , drop = FALSE])
  do.call(rbind, lapply(split(seq_len(nrow(x)), key), function(ii) best_by_objective(x[ii, , drop = FALSE])))
}
metric_ratio <- function(lhs, rhs) {
  out <- num(lhs) / num(rhs)
  out[!is.finite(out)] <- NA_real_
  out
}
metric_delta <- function(lhs, rhs) {
  out <- num(lhs) - num(rhs)
  out[!is.finite(out)] <- NA_real_
  out
}

for (path in c(results_root, report_root, campaign_fit_path, previous_all_path, previous_cell_winners_path)) {
  if (!file.exists(path)) {
    stop(sprintf("Required v1c closeout input missing: %s", path), call. = FALSE)
  }
}

previous_all <- read_csv(previous_all_path)
previous_cell_winners <- read_csv(previous_cell_winners_path)
campaign_fit <- read_csv(campaign_fit_path)
if (nrow(campaign_fit) != 110L) {
  stop(sprintf("Expected 110 v1c campaign rows, observed %d.", nrow(campaign_fit)), call. = FALSE)
}
if (!all(file.exists(campaign_fit$forecast_lead_metrics_path))) {
  missing <- campaign_fit$forecast_lead_metrics_path[!file.exists(campaign_fit$forecast_lead_metrics_path)]
  stop(sprintf("Missing forecast lead metric file(s): %s", paste(utils::head(missing, 3L), collapse = "; ")), call. = FALSE)
}

registry_hashes <- unique(na.omit(previous_all$source_registry_hash_value[nzchar(as.character(previous_all$source_registry_hash_value))]))
if (length(registry_hashes) != 1L) {
  stop("Previous current-best table does not expose exactly one source registry hash.", call. = FALSE)
}
registry_hash <- registry_hashes[[1L]]

extract_horizon <- function(path, horizon) {
  hpath <- sub("forecast_lead_metrics[.]csv$", "forecast_horizon_summary.csv", path)
  if (!file.exists(hpath)) {
    stop(sprintf("Missing forecast horizon summary: %s", hpath), call. = FALSE)
  }
  x <- read_csv(hpath)
  y <- x[num(x$horizon) == horizon, , drop = FALSE]
  if (nrow(y) != 1L) {
    stop(sprintf("Expected one horizon %s row in %s; observed %d.", horizon, hpath, nrow(y)), call. = FALSE)
  }
  y$forecast_horizon_summary_path <- normalizePath(hpath, winslash = "/", mustWork = TRUE)
  y
}

lead_meta <- function(path) {
  x <- read_csv(path)
  data.frame(
    n_leads = length(unique(int(x$forecast_lead))),
    n_origins_scored_total = sum(int(x$n_origins_scored), na.rm = TRUE),
    origin_stride = paste(sort(unique(int(x$origin_stride))), collapse = ";"),
    max_lead_configured = paste(sort(unique(int(x$max_lead_configured))), collapse = ";"),
    forecast_protocol = paste(sort(unique(as.character(x$forecast_protocol))), collapse = ";"),
    state_update_method = paste(sort(unique(as.character(x$state_update_method))), collapse = ";"),
    stringsAsFactors = FALSE
  )
}

h100 <- do.call(rbind, lapply(campaign_fit$forecast_lead_metrics_path, extract_horizon, horizon = 100L))
h1000 <- do.call(rbind, lapply(campaign_fit$forecast_lead_metrics_path, extract_horizon, horizon = 1000L))
lead <- do.call(rbind, lapply(campaign_fit$forecast_lead_metrics_path, lead_meta))

v1c <- data.frame(
  source_key = "qdesn_rhsrepair_v1c_status_agnostic",
  source_priority = 0L,
  source_promotion_id = promotion_id,
  source_table = normalizePath(campaign_fit_path, winslash = "/", mustWork = TRUE),
  model_group = "qdesn",
  model_family = "qdesn",
  model_variant = paste0("qdesn_", campaign_fit$likelihood_family, "_rhs_ns"),
  model_key = paste0("qdesn_", campaign_fit$likelihood_family, "_rhs_ns_mcmc"),
  qdesn_likelihood = campaign_fit$likelihood_family,
  inference = campaign_fit$inference,
  method = campaign_fit$method,
  family = campaign_fit$family,
  tau = num(campaign_fit$tau),
  fit_size = int(campaign_fit$fit_size),
  effective_fit_size = int(campaign_fit$effective_fit_size),
  candidate_id = campaign_fit$screening_profile_id,
  spec_id = campaign_fit$spec_id,
  root_id = campaign_fit$root_id,
  status = campaign_fit$status,
  signoff_grade = campaign_fit$signoff_grade,
  comparison_eligible = bool_chr(campaign_fit$comparison_eligible),
  diagnostic_reason = campaign_fit$signoff_reason,
  fit_qtrue_rmse = num(campaign_fit$train_qtrue_rmse),
  fit_qtrue_mae = num(campaign_fit$train_qtrue_mae),
  fit_check_loss = num(campaign_fit$train_pinball_tau),
  forecast_qtrue_mae_H1000 = num(h1000$qtrue_mae),
  forecast_qtrue_rmse_H1000 = num(h1000$qtrue_rmse),
  forecast_check_loss_H1000 = num(h1000$pinball_tau),
  runtime_hours = num(campaign_fit$runtime_sec) / 3600,
  n_leads = int(lead$n_leads),
  n_origins_scored_total = int(h1000$n_eval),
  train_start_source_index = 8501L,
  train_end_source_index = 9000L,
  forecast_origin_source_index = 9000L,
  forecast_block_start_source_index = 9001L,
  forecast_block_end_source_index = 10000L,
  validation_run_commit = sub("^.*__git-", "", run_tag),
  run_tag = run_tag,
  source_registry_hash_name = "sha256",
  source_registry_hash_value = registry_hash,
  source_table_sha256 = sha256_file(campaign_fit_path),
  stringsAsFactors = FALSE
)
v1c$source_row_key <- paste(v1c$source_key, v1c$model_key, v1c$family, sprintf("%.8f", v1c$tau), v1c$fit_size, v1c$candidate_id, sep = "\r")
v1c$decision_objective <- objective(v1c$fit_qtrue_rmse, v1c$forecast_qtrue_rmse_H1000, v1c$forecast_check_loss_H1000)
v1c$clean_comparison_pool <- bool_chr(v1c$status == "SUCCESS" & v1c$signoff_grade %in% c("PASS", "WARN") & v1c$comparison_eligible == "TRUE")
v1c$signoff_tier <- ifelse(v1c$signoff_grade %in% c("PASS", "WARN"), paste0("diagnostic_", tolower(v1c$signoff_grade)), "diagnostic_fail_status_ignored")

schema <- names(previous_all)
missing_v1c <- setdiff(schema, names(v1c))
if (length(missing_v1c)) {
  stop(sprintf("Internal error: standardized v1c table missing columns: %s", paste(missing_v1c, collapse = ", ")), call. = FALSE)
}
v1c <- v1c[, schema, drop = FALSE]

previous_all$source_generation <- "previous_20260723"
v1c$source_generation <- "v1c_20260725"
all_status_agnostic <- rbind(previous_all[, names(v1c), drop = FALSE], v1c)
all_status_agnostic$source_generation <- c(previous_all$source_generation, v1c$source_generation)

same_key <- function(x) paste(x$model_variant, x$family, sprintf("%.8f", num(x$tau)), x$fit_size, sep = "__")
cell_key <- function(x) paste(x$family, sprintf("%.8f", num(x$tau)), x$fit_size, sep = "__")

prev_same <- split_best(previous_all, same_key(previous_all))
v1c_same <- split_best(v1c, same_key(v1c))
new_same <- split_best(all_status_agnostic, same_key(all_status_agnostic))
prev_global <- split_best(previous_all, cell_key(previous_all))
new_global <- split_best(all_status_agnostic, cell_key(all_status_agnostic))

compare <- merge(
  v1c_same,
  prev_same,
  by.x = c("model_variant", "family", "tau", "fit_size"),
  by.y = c("model_variant", "family", "tau", "fit_size"),
  suffixes = c("_v1c", "_previous"),
  all.x = TRUE
)
compare$objective_delta <- metric_delta(compare$decision_objective_v1c, compare$decision_objective_previous)
compare$fit_rmse_delta <- metric_delta(compare$fit_qtrue_rmse_v1c, compare$fit_qtrue_rmse_previous)
compare$forecast_mae_delta <- metric_delta(compare$forecast_qtrue_mae_H1000_v1c, compare$forecast_qtrue_mae_H1000_previous)
compare$forecast_check_delta <- metric_delta(compare$forecast_check_loss_H1000_v1c, compare$forecast_check_loss_H1000_previous)
compare$objective_ratio <- metric_ratio(compare$decision_objective_v1c, compare$decision_objective_previous)
compare$fit_rmse_ratio <- metric_ratio(compare$fit_qtrue_rmse_v1c, compare$fit_qtrue_rmse_previous)
compare$forecast_mae_ratio <- metric_ratio(compare$forecast_qtrue_mae_H1000_v1c, compare$forecast_qtrue_mae_H1000_previous)
compare$forecast_check_ratio <- metric_ratio(compare$forecast_check_loss_H1000_v1c, compare$forecast_check_loss_H1000_previous)
compare$objective_improved <- compare$objective_delta < -1e-8
compare$fit_rmse_improved <- compare$fit_rmse_delta < -1e-8
compare$forecast_mae_improved <- compare$forecast_mae_delta < -1e-8
compare$forecast_check_improved <- compare$forecast_check_delta < -1e-8
compare$any_registered_metric_improved <- compare$objective_improved |
  compare$fit_rmse_improved | compare$forecast_mae_improved | compare$forecast_check_improved
compare$all_primary_metrics_improved <- compare$fit_rmse_improved & compare$forecast_mae_improved & compare$forecast_check_improved
compare$promotion_class <- ifelse(
  compare$objective_improved,
  "status_agnostic_objective_improved",
  ifelse(compare$any_registered_metric_improved, "status_agnostic_metric_only_improved", "no_status_agnostic_improvement")
)
compare$status_agnostic_promote <- bool_chr(compare$any_registered_metric_improved)
compare <- compare[order(compare$family, compare$tau, compare$model_variant), , drop = FALSE]

metric_promotions <- compare[compare$any_registered_metric_improved, , drop = FALSE]
objective_promotions <- compare[compare$objective_improved, , drop = FALSE]

new_same$status_agnostic_selected_from_v1c <- bool_chr(new_same$source_key == "qdesn_rhsrepair_v1c_status_agnostic")
new_same$status_agnostic_selection_policy <- "min_registered_objective_ignoring_signoff_status"
new_global$status_agnostic_selected_from_v1c <- bool_chr(new_global$source_key == "qdesn_rhsrepair_v1c_status_agnostic")
new_global$status_agnostic_selection_policy <- "min_registered_objective_by_family_tau_ignoring_signoff_status"

article_cells <- sort(unique(cell_key(all_status_agnostic)))
article_rows <- do.call(rbind, lapply(article_cells, function(k) {
  sub <- all_status_agnostic[cell_key(all_status_agnostic) == k, , drop = FALSE]
  best <- best_by_objective(sub)
  pick <- function(variant, metric) {
    y <- sub[sub$model_variant == variant, , drop = FALSE]
    if (!nrow(y)) return(NA_real_)
    y <- best_by_objective(y)
    if (metric %in% names(y)) return(y[[metric]][[1L]])
    NA
  }
  pick_chr <- function(variant, field) {
    y <- sub[sub$model_variant == variant, , drop = FALSE]
    if (!nrow(y)) return(NA_character_)
    y <- best_by_objective(y)
    as.character(y[[field]][[1L]])
  }
  data.frame(
    family = best$family,
    tau = best$tau,
    fit_size = best$fit_size,
    global_winner_model_variant = best$model_variant,
    global_winner_source_generation = best$source_generation,
    global_winner_signoff_grade = best$signoff_grade,
    dqlm_objective = pick("dqlm_c13_mcmc", "decision_objective"),
    exdqlm_objective = pick("exdqlm_c13_mcmc", "decision_objective"),
    qdesn_al_objective = pick("qdesn_al_rhs_ns", "decision_objective"),
    qdesn_exal_objective = pick("qdesn_exal_rhs_ns", "decision_objective"),
    qdesn_al_fit_rmse = pick("qdesn_al_rhs_ns", "fit_qtrue_rmse"),
    qdesn_al_forecast_mae = pick("qdesn_al_rhs_ns", "forecast_qtrue_mae_H1000"),
    qdesn_al_check = pick("qdesn_al_rhs_ns", "forecast_check_loss_H1000"),
    qdesn_al_status = pick_chr("qdesn_al_rhs_ns", "signoff_grade"),
    qdesn_exal_fit_rmse = pick("qdesn_exal_rhs_ns", "fit_qtrue_rmse"),
    qdesn_exal_forecast_mae = pick("qdesn_exal_rhs_ns", "forecast_qtrue_mae_H1000"),
    qdesn_exal_check = pick("qdesn_exal_rhs_ns", "forecast_check_loss_H1000"),
    qdesn_exal_status = pick_chr("qdesn_exal_rhs_ns", "signoff_grade"),
    stringsAsFactors = FALSE
  )
}))
article_rows <- article_rows[order(article_rows$family, article_rows$tau), , drop = FALSE]

qdesn_same <- new_same[new_same$model_group == "qdesn", , drop = FALSE]
target_plan <- merge(
  qdesn_same,
  new_global[, c("family", "tau", "fit_size", "model_variant", "decision_objective", "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000", "signoff_grade"), drop = FALSE],
  by = c("family", "tau", "fit_size"),
  suffixes = c("", "_cell_winner"),
  all.x = TRUE
)
target_plan$objective_gap_vs_cell_winner <- metric_delta(target_plan$decision_objective, target_plan$decision_objective_cell_winner)
target_plan$fit_rmse_ratio_vs_cell_winner <- metric_ratio(target_plan$fit_qtrue_rmse, target_plan$fit_qtrue_rmse_cell_winner)
target_plan$forecast_mae_ratio_vs_cell_winner <- metric_ratio(target_plan$forecast_qtrue_mae_H1000, target_plan$forecast_qtrue_mae_H1000_cell_winner)
target_plan$forecast_check_ratio_vs_cell_winner <- metric_ratio(target_plan$forecast_check_loss_H1000, target_plan$forecast_check_loss_H1000_cell_winner)
target_plan$largest_blocker <- apply(
  target_plan[, c("fit_rmse_ratio_vs_cell_winner", "forecast_mae_ratio_vs_cell_winner", "forecast_check_ratio_vs_cell_winner"), drop = FALSE],
  1L,
  function(z) c("fit_rmse", "forecast_mae", "forecast_check")[which.max(num(z))]
)
target_plan$needs_followup <- bool_chr(
  target_plan$model_variant != target_plan$model_variant_cell_winner |
    target_plan$signoff_grade == "FAIL" |
    target_plan$objective_gap_vs_cell_winner > 0.05
)
target_plan$proposed_followup_family <- ifelse(
  target_plan$signoff_grade == "FAIL",
  "mcmc_mixing_confirmation_for_metric_winner",
  ifelse(
    target_plan$largest_blocker == "fit_rmse",
    "fit_rmse_oriented_compact_rhs_screen",
    ifelse(target_plan$largest_blocker == "forecast_mae", "forecast_mae_oriented_memory_rho_screen", "forecast_check_oriented_likelihood_tau0_screen")
  )
)
target_plan$proposed_first_step <- ifelse(
  target_plan$signoff_grade == "FAIL",
  "rerun_current_metric_winner_with_multiseed_longer_chain_before_new_structure",
  "small_case_specific_vb_or_short_mcmc_screen_around_current_best"
)
target_plan$launch_status <- "not_launched_prepared_only"
target_plan <- target_plan[target_plan$needs_followup == "TRUE", , drop = FALSE]
target_plan <- target_plan[order(-target_plan$objective_gap_vs_cell_winner, target_plan$family, target_plan$tau, target_plan$model_variant), , drop = FALSE]
target_plan$priority <- seq_len(nrow(target_plan))

binary_patterns <- c("\\.rds$", "\\.rda$", "\\.RData$", "\\.qs$", "\\.fst$")
all_files <- list.files(results_root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
all_files <- all_files[file.exists(all_files) & !file.info(all_files)$isdir]
heavy_files <- all_files[
  grepl(paste(binary_patterns, collapse = "|"), all_files, ignore.case = TRUE) |
    file.info(all_files)$size > 20 * 1024^2
]
storage_audit <- if (length(heavy_files)) {
  data.frame(
    path = normalizePath(heavy_files, winslash = "/", mustWork = TRUE),
    size_bytes = as.numeric(file.info(heavy_files)$size),
    classification = "unexpected_heavy_or_binary_campaign_artifact",
    action = "defer_keep",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(path = character(0), size_bytes = numeric(0), classification = character(0), action = character(0), stringsAsFactors = FALSE)
}

summary <- data.frame(
  promotion_id = promotion_id,
  n_v1c_roots = nrow(v1c),
  n_v1c_success = sum(v1c$status == "SUCCESS"),
  n_v1c_pass = sum(v1c$signoff_grade == "PASS"),
  n_v1c_warn = sum(v1c$signoff_grade == "WARN"),
  n_v1c_fail = sum(v1c$signoff_grade == "FAIL"),
  n_v1c_same_variant_cells = nrow(v1c_same),
  n_metric_promotions = nrow(metric_promotions),
  n_objective_promotions = nrow(objective_promotions),
  n_all_primary_promotions = sum(metric_promotions$all_primary_metrics_improved),
  n_new_same_variant_winners_from_v1c = sum(new_same$status_agnostic_selected_from_v1c == "TRUE"),
  n_new_global_cell_winners_from_v1c = sum(new_global$status_agnostic_selected_from_v1c == "TRUE"),
  n_targeted_followup_rows = nrow(target_plan),
  n_storage_heavy_or_binary = nrow(storage_audit),
  stringsAsFactors = FALSE
)

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
v1c_path <- write_csv(v1c[order(v1c$family, v1c$tau, v1c$model_variant, v1c$candidate_id), ], file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_standardized_candidates_", date_stamp, ".csv")))
comparison_path <- write_csv(compare, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_vs_previous_status_agnostic_", date_stamp, ".csv")))
metric_path <- write_csv(metric_promotions, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_metric_promotions_status_agnostic_", date_stamp, ".csv")))
objective_path <- write_csv(objective_promotions, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_objective_promotions_status_agnostic_", date_stamp, ".csv")))
all_candidates_path <- write_csv(all_status_agnostic[order(all_status_agnostic$model_group, all_status_agnostic$model_variant, all_status_agnostic$family, all_status_agnostic$tau, all_status_agnostic$decision_objective), ], file.path(promotion_root, paste0("qdesn_dqlm_500obs_mcmc_status_agnostic_all_candidates_", date_stamp, ".csv")))
same_winners_path <- write_csv(new_same[order(new_same$model_group, new_same$model_variant, new_same$family, new_same$tau), ], file.path(promotion_root, paste0("qdesn_dqlm_500obs_mcmc_status_agnostic_same_variant_winners_", date_stamp, ".csv")))
cell_winners_path <- write_csv(new_global[order(new_global$family, new_global$tau), ], file.path(promotion_root, paste0("qdesn_dqlm_500obs_mcmc_status_agnostic_cell_winners_", date_stamp, ".csv")))
article_path <- write_csv(article_rows, file.path(promotion_root, paste0("qdesn_dqlm_500obs_mcmc_status_agnostic_article_table_snapshot_", date_stamp, ".csv")))
target_path <- write_csv(target_plan, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_targeted_followup_plan_", date_stamp, ".csv")))
storage_path <- write_csv(storage_audit, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_storage_audit_", date_stamp, ".csv")))
summary_path <- write_csv(summary, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_summary_", date_stamp, ".csv")))

source_manifest <- data.frame(
  source_key = c("v1c_results_root", "v1c_report_root", "v1c_campaign_fit_summary", "previous_all_candidates", "previous_cell_winners"),
  path = normalizePath(c(results_root, report_root, campaign_fit_path, previous_all_path, previous_cell_winners_path), winslash = "/", mustWork = TRUE),
  sha256 = c(NA_character_, NA_character_, sha256_file(campaign_fit_path), sha256_file(previous_all_path), sha256_file(previous_cell_winners_path)),
  role = c("campaign_results", "campaign_report", "v1c_candidates", "previous_baseline", "previous_cell_winners"),
  stringsAsFactors = FALSE
)
source_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

source_files <- c(
  v1c_path, comparison_path, metric_path, objective_path, all_candidates_path,
  same_winners_path, cell_winners_path, article_path, target_path,
  storage_path, summary_path, source_path
)
file_manifest <- data.frame(
  file_id = sub(paste0("_", date_stamp, ".*$"), "", basename(source_files)),
  path = source_files,
  sha256 = vapply(source_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = git_value(c("branch", "--show-current")),
  git_commit = git_value(c("rev-parse", "HEAD")),
  git_dirty = length(system2("git", c("-C", repo_root, "status", "--porcelain"), stdout = TRUE)) > 0L,
  stage = stage,
  run_tag = run_tag,
  campaign_stamp = campaign_stamp,
  results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
  report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
  previous_all_candidates_path = normalizePath(previous_all_path, winslash = "/", mustWork = TRUE),
  source_registry_hash_name = "sha256",
  source_registry_hash_value = registry_hash,
  status_policy = "status_agnostic_metric_promotion_requested_by_user",
  status_policy_note = "The metric-promotion table intentionally ignores signoff as a hard exclusion. Signoff remains retained as diagnostic metadata and must be disclosed before article use.",
  objective_definition = "fit_qtrue_rmse + forecast_qtrue_rmse_H1000 + forecast_check_loss_H1000",
  metric_promotion_rule = "v1c best same-variant candidate improves at least one of objective, fit RMSE, H1000 forecast MAE, or H1000 forecast check loss relative to the previous same family/tau/model_variant best.",
  current_best_rule = "status-agnostic same-variant and cell winners select the minimum registered objective after appending v1c candidates to the previous all-candidate inventory.",
  summary = as.list(summary[1L, , drop = FALSE]),
  files = file_manifest
)
manifest_path <- write_json(manifest, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_manifest_", date_stamp, ".json")))

md_table <- function(x, cols, max_rows = 30L) {
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

metric_readme <- metric_promotions
if (nrow(metric_readme)) {
  metric_readme$tau <- fmt(metric_readme$tau)
  metric_readme$objective_delta <- fmt(metric_readme$objective_delta)
  metric_readme$fit_rmse_delta <- fmt(metric_readme$fit_rmse_delta)
  metric_readme$forecast_mae_delta <- fmt(metric_readme$forecast_mae_delta)
  metric_readme$forecast_check_delta <- fmt(metric_readme$forecast_check_delta)
}
target_readme <- target_plan
if (nrow(target_readme)) {
  target_readme$tau <- fmt(target_readme$tau)
  target_readme$objective_gap_vs_cell_winner <- fmt(target_readme$objective_gap_vs_cell_winner)
  target_readme$fit_rmse_ratio_vs_cell_winner <- fmt(target_readme$fit_rmse_ratio_vs_cell_winner)
  target_readme$forecast_mae_ratio_vs_cell_winner <- fmt(target_readme$forecast_mae_ratio_vs_cell_winner)
  target_readme$forecast_check_ratio_vs_cell_winner <- fmt(target_readme$forecast_check_ratio_vs_cell_winner)
}

readme <- c(
  "# Q-DESN 500-Observation MCMC RHS Repair v1c Status-Agnostic Closeout",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Generated: `%s`", manifest$generated_at),
  sprintf("- Validation branch: `%s`", manifest$git_branch),
  sprintf("- Validation commit: `%s`", manifest$git_commit),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Campaign stamp: `%s`", campaign_stamp),
  sprintf("- Source registry hash: `%s`", registry_hash),
  "",
  "## Policy",
  "",
  "This closeout follows the requested status-agnostic diagnostic policy: signoff is not used as a hard exclusion for metric-promotion evidence. The signoff grade and reason are retained in every output table, and diagnostic failures are not hidden.",
  "",
  "Two promotion concepts are recorded:",
  "",
  "1. Metric promotions: v1c best same-variant rows that improve at least one registered metric relative to the previous same family/tau/model variant best.",
  "2. Status-agnostic current-best rows: winners after appending v1c candidates and selecting by the registered objective.",
  "",
  "## Summary",
  "",
  sprintf("- v1c roots: `%d`", summary$n_v1c_roots),
  sprintf("- v1c successful roots: `%d`", summary$n_v1c_success),
  sprintf("- v1c signoff mix: PASS `%d`, WARN `%d`, FAIL `%d`", summary$n_v1c_pass, summary$n_v1c_warn, summary$n_v1c_fail),
  sprintf("- Same-variant cells checked: `%d`", summary$n_v1c_same_variant_cells),
  sprintf("- Metric promotions: `%d`", summary$n_metric_promotions),
  sprintf("- Objective promotions: `%d`", summary$n_objective_promotions),
  sprintf("- All-primary metric promotions: `%d`", summary$n_all_primary_promotions),
  sprintf("- New same-variant winners from v1c: `%d`", summary$n_new_same_variant_winners_from_v1c),
  sprintf("- New global cell winners from v1c: `%d`", summary$n_new_global_cell_winners_from_v1c),
  sprintf("- Targeted follow-up rows prepared: `%d`", summary$n_targeted_followup_rows),
  sprintf("- Heavy/binary artifacts retained: `%d`", summary$n_storage_heavy_or_binary),
  "",
  "## Status-Agnostic Metric Promotions",
  "",
  md_table(
    metric_readme,
    c(
      "family", "tau", "model_variant", "candidate_id_v1c", "signoff_grade_v1c",
      "promotion_class", "objective_delta", "fit_rmse_delta",
      "forecast_mae_delta", "forecast_check_delta"
    )
  ),
  "",
  "## Targeted Follow-Up Prepared",
  "",
  md_table(
    target_readme,
    c(
      "priority", "family", "tau", "model_variant", "signoff_grade",
      "largest_blocker", "objective_gap_vs_cell_winner",
      "proposed_followup_family", "proposed_first_step", "launch_status"
    )
  ),
  "",
  "## Files",
  "",
  sprintf("- Standardized v1c candidates: `%s`", basename(v1c_path)),
  sprintf("- v1c vs previous comparison: `%s`", basename(comparison_path)),
  sprintf("- Status-agnostic metric promotions: `%s`", basename(metric_path)),
  sprintf("- Status-agnostic objective promotions: `%s`", basename(objective_path)),
  sprintf("- Status-agnostic all candidates: `%s`", basename(all_candidates_path)),
  sprintf("- Same-variant current-best winners: `%s`", basename(same_winners_path)),
  sprintf("- Global cell winners: `%s`", basename(cell_winners_path)),
  sprintf("- Article-table snapshot: `%s`", basename(article_path)),
  sprintf("- Targeted follow-up plan: `%s`", basename(target_path)),
  sprintf("- Storage audit: `%s`", basename(storage_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("v1c_roots=%d success=%d warn=%d fail=%d\n", summary$n_v1c_roots, summary$n_v1c_success, summary$n_v1c_warn, summary$n_v1c_fail))
cat(sprintf("metric_promotions=%d objective_promotions=%d all_primary=%d\n", summary$n_metric_promotions, summary$n_objective_promotions, summary$n_all_primary_promotions))
cat(sprintf("new_same_variant_winners_from_v1c=%d new_global_cell_winners_from_v1c=%d\n", summary$n_new_same_variant_winners_from_v1c, summary$n_new_global_cell_winners_from_v1c))
cat(sprintf("targeted_followup_rows=%d storage_heavy_or_binary=%d\n", summary$n_targeted_followup_rows, summary$n_storage_heavy_or_binary))
