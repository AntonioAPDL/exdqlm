#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
})

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || !length(lhs) || all(is.na(lhs))) rhs else lhs
}

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

promotion_id <- "qdesn_dqlm_500obs_mcmc_current_best_20260723"
promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)

source_paths <- list(
  qdesn_vbcandidate = file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_vb_candidate_closeout_20260723",
    "qdesn_tt500_mcmc_vb_candidate_authoritative_fit_summary_20260723.csv"
  ),
  qdesn_alrhs_recalibrated = file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702",
    "qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_summary.csv"
  ),
  qdesn_legacy_mcmc = file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_authoritative_20260701",
    "qdesn_tt500_mcmc_authoritative_summary.csv"
  ),
  exdqlm_dqlm_c13 = file.path(
    "validation", "fitforecast_v2", "promotions",
    "exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704",
    "exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704_summary.csv"
  )
)

read_csv <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) {
  unname(tools::sha256sum(normalizePath(path, winslash = "/", mustWork = TRUE)))
}

git_value <- function(args) {
  out <- tryCatch(system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}

num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
chr1 <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) return(default)
  as.character(x[[1L]])
}
bool_chr <- function(x) {
  if (is.logical(x)) return(ifelse(x, "TRUE", "FALSE"))
  toupper(trimws(as.character(x)))
}
col_or <- function(df, nm, default = NA) {
  if (nm %in% names(df)) df[[nm]] else rep(default, nrow(df))
}

required_sources <- normalizePath(unlist(source_paths), winslash = "/", mustWork = TRUE)
source_manifest <- data.frame(
  source_key = names(source_paths),
  path = required_sources,
  sha256 = vapply(required_sources, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)

standardize_qdesn_vbcandidate <- function(path) {
  x <- read_csv(path)
  data.frame(
    source_key = "qdesn_vbcandidate",
    source_priority = 1L,
    source_promotion_id = "qdesn_tt500_mcmc_vb_candidate_closeout_20260723",
    source_table = normalizePath(path, winslash = "/", mustWork = TRUE),
    model_group = "qdesn",
    model_family = "qdesn",
    model_variant = paste0("qdesn_", x$model, "_rhs_ns"),
    model_key = paste0("qdesn_", x$model, "_rhs_ns_mcmc"),
    qdesn_likelihood = x$model,
    inference = x$inference,
    method = x$inference,
    family = x$family,
    tau = num(x$tau),
    fit_size = int(x$fit_size),
    effective_fit_size = int(x$effective_fit_size),
    candidate_id = x$reservoir_profile,
    spec_id = x$spec_id,
    root_id = x$root_id,
    status = x$status,
    signoff_grade = x$signoff_grade,
    comparison_eligible = bool_chr(x$comparison_eligible),
    diagnostic_reason = x$signoff_reason,
    fit_qtrue_rmse = num(x$train_qtrue_rmse),
    fit_qtrue_mae = num(x$train_qtrue_mae),
    fit_check_loss = num(x$train_check_loss),
    forecast_qtrue_mae_H1000 = num(x$forecast_H1000_qtrue_mae),
    forecast_qtrue_rmse_H1000 = num(x$forecast_H1000_qtrue_rmse),
    forecast_check_loss_H1000 = num(x$forecast_H1000_check_loss),
    runtime_hours = num(x$runtime_sec) / 3600,
    n_leads = 30L,
    n_origins_scored_total = 1000L,
    train_start_source_index = 8501L,
    train_end_source_index = 9000L,
    forecast_origin_source_index = 9000L,
    forecast_block_start_source_index = 9001L,
    forecast_block_end_source_index = 10000L,
    validation_run_commit = sub("^.*__git-", "", x$preferred_run_tag),
    run_tag = x$preferred_run_tag,
    source_registry_hash_name = "sha256",
    source_registry_hash_value = NA_character_,
    stringsAsFactors = FALSE
  )
}

standardize_qdesn_handoff <- function(path, source_key, source_priority) {
  x <- read_csv(path)
  data.frame(
    source_key = source_key,
    source_priority = source_priority,
    source_promotion_id = x$promotion_id,
    source_table = normalizePath(path, winslash = "/", mustWork = TRUE),
    model_group = "qdesn",
    model_family = x$model_family,
    model_variant = x$model_key,
    model_key = paste0(x$model_key, "_mcmc"),
    qdesn_likelihood = x$qdesn_likelihood,
    inference = x$inference,
    method = x$method,
    family = x$family,
    tau = num(x$tau),
    fit_size = int(x$fit_size),
    effective_fit_size = int(x$effective_fit_size),
    candidate_id = x$screening_profile_id,
    spec_id = x$spec_id,
    root_id = x$root_id,
    status = x$status,
    signoff_grade = x$signoff_grade,
    comparison_eligible = bool_chr(x$comparison_eligible),
    diagnostic_reason = x$signoff_reason,
    fit_qtrue_rmse = num(x$fit_qtrue_rmse),
    fit_qtrue_mae = if ("fit_qtrue_mae" %in% names(x)) num(x$fit_qtrue_mae) else NA_real_,
    fit_check_loss = if ("fit_pinball_mean" %in% names(x)) num(x$fit_pinball_mean) else NA_real_,
    forecast_qtrue_mae_H1000 = num(x$forecast_qtrue_mae_lead_weighted),
    forecast_qtrue_rmse_H1000 = num(x$forecast_qtrue_rmse_lead_weighted),
    forecast_check_loss_H1000 = num(x$forecast_pinball_mean_lead_weighted),
    runtime_hours = num(x$runtime_hours),
    n_leads = int(x$n_leads),
    n_origins_scored_total = int(x$n_origins_scored_total),
    train_start_source_index = int(x$train_start_source_index),
    train_end_source_index = int(x$train_end_source_index),
    forecast_origin_source_index = int(x$forecast_origin_source_index),
    forecast_block_start_source_index = int(x$forecast_block_start_source_index),
    forecast_block_end_source_index = int(x$forecast_block_end_source_index),
    validation_run_commit = x$validation_run_commit,
    run_tag = x$source_run_tag,
    source_registry_hash_name = x$source_registry_hash_name,
    source_registry_hash_value = x$source_registry_hash_value,
    stringsAsFactors = FALSE
  )
}

standardize_dqlm <- function(path) {
  x <- read_csv(path)
  data.frame(
    source_key = "exdqlm_dqlm_c13",
    source_priority = 1L,
    source_promotion_id = x$promotion_id,
    source_table = normalizePath(path, winslash = "/", mustWork = TRUE),
    model_group = "exdqlm_dqlm",
    model_family = x$model_family,
    model_variant = x$model_key,
    model_key = x$model_key,
    qdesn_likelihood = NA_character_,
    inference = x$inference,
    method = x$method,
    family = x$family,
    tau = num(x$tau),
    fit_size = int(x$fit_size),
    effective_fit_size = int(x$effective_fit_size),
    candidate_id = x$candidate_id,
    spec_id = x$calibration_id,
    root_id = paste(x$model_key, x$family, sprintf("%.2f", num(x$tau)), sep = "__"),
    status = x$status,
    signoff_grade = ifelse(nzchar(as.character(x$health_gate)), x$health_gate, x$signoff_grade),
    comparison_eligible = bool_chr(x$comparison_eligible),
    diagnostic_reason = x$signoff_grade,
    fit_qtrue_rmse = num(x$fit_qtrue_rmse),
    fit_qtrue_mae = NA_real_,
    fit_check_loss = num(x$fit_check_loss),
    forecast_qtrue_mae_H1000 = num(x$forecast_qtrue_mae_lead_weighted),
    forecast_qtrue_rmse_H1000 = num(x$forecast_qtrue_rmse_lead_weighted),
    forecast_check_loss_H1000 = num(x$forecast_check_loss_lead_weighted),
    runtime_hours = num(x$runtime_hours),
    n_leads = int(x$n_leads),
    n_origins_scored_total = int(x$n_origins_scored_total),
    train_start_source_index = int(x$train_start_source_index),
    train_end_source_index = int(x$train_end_source_index),
    forecast_origin_source_index = int(x$forecast_origin_source_index),
    forecast_block_start_source_index = int(x$forecast_block_start_source_index),
    forecast_block_end_source_index = int(x$forecast_block_end_source_index),
    validation_run_commit = x$validation_run_commit,
    run_tag = x$run_tag,
    source_registry_hash_name = x$source_registry_hash_name,
    source_registry_hash_value = x$source_registry_hash_value,
    stringsAsFactors = FALSE
  )
}

all_candidates <- do.call(rbind, list(
  standardize_qdesn_vbcandidate(source_paths$qdesn_vbcandidate),
  standardize_qdesn_handoff(source_paths$qdesn_alrhs_recalibrated, "qdesn_alrhs_recalibrated", 2L),
  standardize_qdesn_handoff(source_paths$qdesn_legacy_mcmc, "qdesn_legacy_mcmc", 3L),
  standardize_dqlm(source_paths$exdqlm_dqlm_c13)
))

all_candidates$source_table_sha256 <- source_manifest$sha256[match(all_candidates$source_key, source_manifest$source_key)]
all_candidates$source_row_key <- paste(
  all_candidates$source_key,
  all_candidates$model_key,
  all_candidates$family,
  sprintf("%.8f", all_candidates$tau),
  all_candidates$fit_size,
  all_candidates$candidate_id,
  sep = "\r"
)

registry_hashes <- unique(na.omit(all_candidates$source_registry_hash_value[nzchar(as.character(all_candidates$source_registry_hash_value))]))
if (length(registry_hashes) > 1L) {
  stop(sprintf("Multiple source registry hashes found: %s", paste(registry_hashes, collapse = ", ")), call. = FALSE)
}
if (length(registry_hashes) == 1L) {
  missing_hash <- is.na(all_candidates$source_registry_hash_value) | !nzchar(as.character(all_candidates$source_registry_hash_value))
  all_candidates$source_registry_hash_name[missing_hash] <- "sha256"
  all_candidates$source_registry_hash_value[missing_hash] <- registry_hashes[[1L]]
}

all_candidates$decision_objective <- with(
  all_candidates,
  fit_qtrue_rmse + forecast_qtrue_rmse_H1000 + forecast_check_loss_H1000
)
all_candidates$clean_comparison_pool <- all_candidates$status %in% c("SUCCESS", "done") &
  all_candidates$comparison_eligible == "TRUE" &
  all_candidates$signoff_grade %in% c("PASS", "WARN", "")
all_candidates$signoff_tier <- match(all_candidates$signoff_grade, c("PASS", "WARN", "", "FAIL"))
all_candidates$signoff_tier[is.na(all_candidates$signoff_tier)] <- 99L

if (any(!is.finite(all_candidates$decision_objective))) {
  bad <- all_candidates[!is.finite(all_candidates$decision_objective), c("source_key", "model_key", "family", "tau"), drop = FALSE]
  stop(sprintf("Decision objective has non-finite values:\n%s", paste(utils::capture.output(print(bad, row.names = FALSE)), collapse = "\n")), call. = FALSE)
}

select_best <- function(df, clean_only = FALSE) {
  if (clean_only) df <- df[df$clean_comparison_pool, , drop = FALSE]
  if (!nrow(df)) return(df)
  df[order(df$decision_objective, df$signoff_tier, df$source_priority, df$runtime_hours), , drop = FALSE][1L, , drop = FALSE]
}

split_key <- function(df, cols) split(seq_len(nrow(df)), paste(df[, cols, drop = FALSE], collapse = "\r"))

model_variant_groups <- split(seq_len(nrow(all_candidates)), paste(
  all_candidates$model_group,
  all_candidates$model_variant,
  all_candidates$family,
  sprintf("%.8f", all_candidates$tau),
  all_candidates$fit_size,
  all_candidates$inference,
  sep = "\r"
))

current_best_clean <- do.call(rbind, lapply(model_variant_groups, function(ii) {
  select_best(all_candidates[ii, , drop = FALSE], clean_only = TRUE)
}))
if (is.null(current_best_clean) || !nrow(current_best_clean)) {
  stop("No clean current-best rows selected.", call. = FALSE)
}

diagnostic_best <- do.call(rbind, lapply(model_variant_groups, function(ii) {
  sub <- all_candidates[ii, , drop = FALSE]
  failed <- sub[!sub$clean_comparison_pool, , drop = FALSE]
  if (!nrow(failed)) return(data.frame(stringsAsFactors = FALSE))
  select_best(failed, clean_only = FALSE)
}))
diagnostic_best <- diagnostic_best[!is.na(diagnostic_best$model_key), , drop = FALSE]

cell_groups <- split(seq_len(nrow(current_best_clean)), paste(
  current_best_clean$family,
  sprintf("%.8f", current_best_clean$tau),
  current_best_clean$fit_size,
  current_best_clean$inference,
  sep = "\r"
))
cell_winners <- do.call(rbind, lapply(cell_groups, function(ii) {
  select_best(current_best_clean[ii, , drop = FALSE], clean_only = FALSE)
}))

qdesn_exal_cells <- expand.grid(
  family = sort(unique(all_candidates$family)),
  tau = sort(unique(all_candidates$tau)),
  fit_size = 500L,
  model_variant = "qdesn_exal_rhs_ns",
  stringsAsFactors = FALSE
)
missing_exal <- do.call(rbind, lapply(seq_len(nrow(qdesn_exal_cells)), function(i) {
  cell <- qdesn_exal_cells[i, , drop = FALSE]
  sub <- all_candidates[
    all_candidates$model_variant == cell$model_variant &
      all_candidates$family == cell$family &
      abs(all_candidates$tau - cell$tau) < 1e-8 &
      all_candidates$fit_size == cell$fit_size,
    ,
    drop = FALSE
  ]
  current_sub <- sub[sub$source_key == "qdesn_vbcandidate", , drop = FALSE]
  legacy_sub <- sub[sub$source_key != "qdesn_vbcandidate", , drop = FALSE]
  clean <- sub[sub$clean_comparison_pool, , drop = FALSE]
  current_clean <- current_sub[current_sub$clean_comparison_pool, , drop = FALSE]
  legacy_clean <- legacy_sub[legacy_sub$clean_comparison_pool, , drop = FALSE]
  best_failed <- if (nrow(sub[!sub$clean_comparison_pool, , drop = FALSE])) {
    select_best(sub[!sub$clean_comparison_pool, , drop = FALSE], clean_only = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  data.frame(
    family = cell$family,
    tau = cell$tau,
    fit_size = cell$fit_size,
    model_variant = cell$model_variant,
    n_candidates = nrow(sub),
    n_clean = nrow(clean),
    n_current_protocol_candidates = nrow(current_sub),
    n_current_protocol_clean = nrow(current_clean),
    n_legacy_clean = nrow(legacy_clean),
    relaunch_priority = if (nrow(current_clean)) {
      "none_current_protocol_clean_candidate_exists"
    } else if (nrow(legacy_clean) && nrow(current_sub)) {
      "optional_current_protocol_refresh_legacy_clean_fallback_exists"
    } else if (nrow(legacy_clean)) {
      "optional_current_protocol_refresh_only_legacy_clean_exists"
    } else if (nrow(sub)) {
      "targeted_mcmc_diagnostic_relaunch"
    } else {
      "missing_current_protocol_candidate"
    },
    best_failed_profile = if (nrow(best_failed)) best_failed$candidate_id[[1L]] else NA_character_,
    best_failed_reason = if (nrow(best_failed)) best_failed$diagnostic_reason[[1L]] else NA_character_,
    best_failed_objective = if (nrow(best_failed)) best_failed$decision_objective[[1L]] else NA_real_,
    stringsAsFactors = FALSE
  )
}))
relaunch_targets <- missing_exal[missing_exal$relaunch_priority != "none_current_protocol_clean_candidate_exists", , drop = FALSE]

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
all_path <- write_csv(all_candidates[order(all_candidates$model_group, all_candidates$model_variant, all_candidates$family, all_candidates$tau, all_candidates$source_priority, all_candidates$decision_objective), ], file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_current_best_all_candidates_20260723.csv"))
clean_path <- write_csv(current_best_clean[order(current_best_clean$model_group, current_best_clean$model_variant, current_best_clean$family, current_best_clean$tau), ], file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_current_best_clean_20260723.csv"))
diag_path <- write_csv(diagnostic_best[order(diagnostic_best$model_group, diagnostic_best$model_variant, diagnostic_best$family, diagnostic_best$tau), ], file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_current_best_diagnostic_nonclean_20260723.csv"))
winner_path <- write_csv(cell_winners[order(cell_winners$family, cell_winners$tau, cell_winners$model_group, cell_winners$model_variant), ], file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_current_best_cell_winners_20260723.csv"))
target_path <- write_csv(relaunch_targets[order(relaunch_targets$family, relaunch_targets$tau), ], file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_targeted_relaunch_targets_20260723.csv"))
source_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

source_files <- c(all_path, clean_path, diag_path, winner_path, target_path, source_path)
file_manifest <- data.frame(
  file_id = sub("_20260723.*$", "", basename(source_files)),
  path = source_files,
  sha256 = vapply(source_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

summary <- data.frame(
  promotion_id = promotion_id,
  n_all_candidates = nrow(all_candidates),
  n_clean_current_best = nrow(current_best_clean),
  n_diagnostic_nonclean_best = nrow(diagnostic_best),
  n_cell_winners = nrow(cell_winners),
  n_targeted_relaunch_targets = nrow(relaunch_targets),
  qdesn_clean_rows = sum(current_best_clean$model_group == "qdesn"),
  exdqlm_dqlm_clean_rows = sum(current_best_clean$model_group == "exdqlm_dqlm"),
  clean_family_tau_cells = length(unique(paste(current_best_clean$family, sprintf("%.8f", current_best_clean$tau), sep = "\r"))),
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary, file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_current_best_summary_20260723.csv"))

manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = git_value(c("branch", "--show-current")),
  git_commit = git_value(c("rev-parse", "HEAD")),
  git_dirty = length(system2("git", c("-C", repo_root, "status", "--porcelain"), stdout = TRUE)) > 0L,
  selection_rule = "Within model variant/family/tau/fit-size/inference, select comparison-eligible rows first, then minimum fit RMSE + H1000 RMSE + H1000 check loss, then PASS/WARN signoff tier, source priority, and runtime.",
  article_rule = "Use clean_current_best for clean comparison tables; keep diagnostic_nonclean for caveats and relaunch planning only.",
  source_manifest = source_manifest,
  summary = as.list(summary[1L, , drop = FALSE]),
  files = rbind(file_manifest, data.frame(file_id = "qdesn_dqlm_500obs_mcmc_current_best_summary", path = summary_path, sha256 = sha256_file(summary_path), stringsAsFactors = FALSE))
)
manifest_path <- write_json(manifest, file.path(promotion_root, "qdesn_dqlm_500obs_mcmc_current_best_manifest_20260723.json"))

readme <- c(
  "# Q-DESN/DQLM 500-Observation MCMC Current-Best Evidence",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Generated: `%s`", manifest$generated_at),
  sprintf("- Git branch: `%s`", manifest$git_branch),
  sprintf("- Git commit: `%s`", manifest$git_commit),
  "",
  "## Selection Rule",
  "",
  "Within each model variant / family / tau / fit-size / inference group:",
  "",
  "1. use only comparison-eligible rows for the clean table;",
  "2. minimize `fit RMSE + H1000 RMSE + H1000 check loss`;",
  "3. retain PASS/WARN as diagnostic labels and use them only as tie-breakers;",
  "4. use source priority and runtime after the metric and signoff tie-breakers.",
  "",
  "Non-clean rows are retained in the diagnostic table and must not be promoted as clean winners.",
  "",
  "## Outputs",
  "",
  sprintf("- All standardized candidates: `%s`", basename(all_path)),
  sprintf("- Clean current-best table: `%s`", basename(clean_path)),
  sprintf("- Diagnostic non-clean table: `%s`", basename(diag_path)),
  sprintf("- Cell winners among clean rows: `%s`", basename(winner_path)),
  sprintf("- Targeted relaunch targets: `%s`", basename(target_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path)),
  "",
  "## Counts",
  "",
  sprintf("- All candidates: `%d`", nrow(all_candidates)),
  sprintf("- Clean current-best rows: `%d`", nrow(current_best_clean)),
  sprintf("- Diagnostic non-clean best rows: `%d`", nrow(diagnostic_best)),
  sprintf("- Cell winners: `%d`", nrow(cell_winners)),
  sprintf("- Targeted relaunch targets: `%d`", nrow(relaunch_targets))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("all_candidates: %d\n", nrow(all_candidates)))
cat(sprintf("clean_current_best: %d\n", nrow(current_best_clean)))
cat(sprintf("diagnostic_nonclean_best: %d\n", nrow(diagnostic_best)))
cat(sprintf("cell_winners: %d\n", nrow(cell_winners)))
cat(sprintf("targeted_relaunch_targets: %d\n", nrow(relaunch_targets)))
