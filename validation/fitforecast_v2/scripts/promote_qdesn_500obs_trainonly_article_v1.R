#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || !length(lhs) || all(is.na(lhs))) rhs else lhs
}

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/",
  mustWork = TRUE
)
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] == length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v1_20260805"
vb_closeout_dir <- get_arg(
  "--vb-closeout-dir",
  file.path(
    repo_root,
    "reports", "shared_fitforecast_v2_orchestration",
    "qdesn_vb_trainonly_rebaseline_v1_20260805_030705", "closeout"
  )
)
mcmc_closeout_dir <- get_arg(
  "--mcmc-closeout-dir",
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_500obs_mcmc_trainonly_rebaseline_v1_closeout_20260805"
  )
)
legacy_mcmc_dir <- get_arg(
  "--structured-mcmc-dir",
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260804"
  )
)
dqlm_vb_path <- get_arg(
  "--structured-vb-csv",
  file.path(
    repo_root, "validation", "fitforecast_v2", "docs",
    "exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv"
  )
)
output_dir <- get_arg(
  "--output-dir",
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
)

paths <- list(
  vb_interface = file.path(vb_closeout_dir, "qdesn_500obs_vb_trainonly_corrected_interface.csv"),
  vb_execution = file.path(vb_closeout_dir, "execution_contract_audit.csv"),
  vb_gate = file.path(vb_closeout_dir, "vb_rebaseline_gate.json"),
  mcmc_envelope = file.path(mcmc_closeout_dir, "corrected_qdesn_metric_envelope.csv"),
  mcmc_execution = file.path(mcmc_closeout_dir, "execution_contract_audit.csv"),
  mcmc_gate = file.path(mcmc_closeout_dir, "rebaseline_gate.json"),
  structured_mcmc = file.path(
    legacy_mcmc_dir,
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260804_article_envelope.csv"
  ),
  structured_mcmc_manifest = file.path(
    legacy_mcmc_dir,
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260804_manifest.json"
  ),
  structured_vb = dqlm_vb_path
)

missing <- names(paths)[!file.exists(unlist(paths, use.names = FALSE))]
if (length(missing)) {
  stop(sprintf("Missing source artifact(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
}

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
worst_grade <- function(...) {
  values <- toupper(c(...))
  values <- values[!is.na(values) & nzchar(values)]
  if ("FAIL" %in% values) return("FAIL")
  if ("WARN" %in% values) return("WARN")
  if ("PASS" %in% values) return("PASS")
  "UNKNOWN"
}
model_label <- function(model_variant) {
  labels <- c(
    dqlm = "DQLM",
    exdqlm = "exDQLM",
    qdesn_al_rhs_ns = "Q-DESN AL-RHS",
    qdesn_exal_rhs_ns = "Q-DESN exAL-RHS"
  )
  unname(labels[as.character(model_variant)])
}
empty_value <- function(n) rep(NA_character_, n)

expected_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected_families <- c("gausmix", "laplace", "normal")
expected_taus <- c(0.05, 0.25, 0.50)

vb_qdesn <- read_csv(paths$vb_interface)
vb_execution <- read_csv(paths$vb_execution)
mcmc_qdesn <- read_csv(paths$mcmc_envelope)
mcmc_execution <- read_csv(paths$mcmc_execution)
mcmc_structured_all <- read_csv(paths$structured_mcmc)
vb_structured <- read_csv(paths$structured_vb)
mcmc_gate <- jsonlite::read_json(paths$mcmc_gate, simplifyVector = TRUE)
vb_gate <- jsonlite::read_json(paths$vb_gate, simplifyVector = TRUE)
mcmc_structured_manifest <- jsonlite::read_json(
  paths$structured_mcmc_manifest,
  simplifyVector = TRUE
)

assert_grid <- function(x, variants, label) {
  expected <- expand.grid(
    model_variant = variants,
    family = expected_families,
    tau = expected_taus,
    stringsAsFactors = FALSE
  )
  observed_key <- paste(x$model_variant, x$family, sprintf("%.2f", as.numeric(x$tau)))
  expected_key <- paste(expected$model_variant, expected$family, sprintf("%.2f", expected$tau))
  if (nrow(x) != nrow(expected) || anyDuplicated(observed_key) ||
      !setequal(observed_key, expected_key)) {
    stop(sprintf("%s does not contain the exact expected cell grid.", label), call. = FALSE)
  }
}

assert_grid(vb_qdesn, c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"), "Q-DESN VB source")
assert_grid(mcmc_qdesn, c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"), "Q-DESN MCMC source")
assert_grid(vb_structured, c("dqlm", "exdqlm"), "DQLM/exDQLM VB source")

mcmc_structured <- mcmc_structured_all[
  mcmc_structured_all$model_variant %in% c("dqlm_c13_mcmc", "exdqlm_c13_mcmc"),
  ,
  drop = FALSE
]
mcmc_structured$model_variant <- sub("_c13_mcmc$", "", mcmc_structured$model_variant)
assert_grid(mcmc_structured, c("dqlm", "exdqlm"), "DQLM/exDQLM MCMC source")

if (!all(as_bool(vb_qdesn$protocol_eligible)) ||
    !all(vb_qdesn$preprocessing_scope == "train_only") ||
    !all(vb_qdesn$source_registry_hash_value == expected_hash) ||
    !all(vb_execution$protocol_eligible) ||
    !identical(as.integer(vb_gate$protocol_eligible_specs), 18L)) {
  stop("Q-DESN VB closeout violates the corrected protocol gate.", call. = FALSE)
}
if (!all(mcmc_qdesn$preprocessing_scope == "train_only") ||
    !all(mcmc_qdesn$source_registry_hash_value == expected_hash) ||
    !all(mcmc_execution$protocol_eligible) ||
    !identical(as.integer(mcmc_gate$protocol_eligible_specs), 37L)) {
  stop("Q-DESN MCMC closeout violates the corrected protocol gate.", call. = FALSE)
}
if (!all(vb_structured$source_registry_hash_value == expected_hash) ||
    !all(mcmc_structured$source_registry_hash_value == expected_hash)) {
  stop("Structured baselines do not use the frozen source registry.", call. = FALSE)
}

make_common <- function(model_variant, inference, family, tau) {
  data.frame(
    article_interface_id = promotion_id,
    inference = inference,
    model_variant = model_variant,
    model_label = model_label(model_variant),
    family = family,
    tau = as.numeric(tau),
    fit_size = 500L,
    effective_fit_size = 500L,
    comparison_eligible = TRUE,
    status = "SUCCESS",
    signoff_grade = "PASS",
    metric_source_mixed = FALSE,
    fit_qtrue_rmse = NA_real_,
    forecast_qtrue_mae_H1000 = NA_real_,
    forecast_check_loss_H1000 = NA_real_,
    fit_source_candidate_id = empty_value(length(family)),
    fit_source_run_tag = empty_value(length(family)),
    fit_source_signoff_grade = empty_value(length(family)),
    fit_source_status = empty_value(length(family)),
    fit_source_path = empty_value(length(family)),
    fit_source_sha256 = empty_value(length(family)),
    forecast_mae_source_candidate_id = empty_value(length(family)),
    forecast_mae_source_run_tag = empty_value(length(family)),
    forecast_mae_source_signoff_grade = empty_value(length(family)),
    forecast_mae_source_status = empty_value(length(family)),
    forecast_mae_source_path = empty_value(length(family)),
    forecast_mae_source_sha256 = empty_value(length(family)),
    forecast_check_source_candidate_id = empty_value(length(family)),
    forecast_check_source_run_tag = empty_value(length(family)),
    forecast_check_source_signoff_grade = empty_value(length(family)),
    forecast_check_source_status = empty_value(length(family)),
    forecast_check_source_path = empty_value(length(family)),
    forecast_check_source_sha256 = empty_value(length(family)),
    source_registry_hash_value = expected_hash,
    preprocessing_scope = "model_internal_no_shared_scaling",
    train_start_source_index = 8501L,
    train_end_source_index = 9000L,
    forecast_origin_source_index = 9000L,
    forecast_block_start_source_index = 9001L,
    forecast_block_end_source_index = 10000L,
    forecast_max_lead_configured = 30L,
    forecast_origin_stride = 30L,
    package_version = "1.0.0",
    validation_branch = empty_value(length(family)),
    validation_commit = empty_value(length(family)),
    validation_closeout_commit = empty_value(length(family)),
    source_promotion_id = empty_value(length(family)),
    stringsAsFactors = FALSE
  )
}

vb_structured_rows <- lapply(seq_len(nrow(vb_structured)), function(i) {
  src <- vb_structured[i, , drop = FALSE]
  out <- make_common(src$model_variant, "vb", src$family, src$tau)
  out$fit_qtrue_rmse <- as.numeric(src$fit_qtrue_rmse)
  out$forecast_qtrue_mae_H1000 <- as.numeric(src$forecast_qtrue_mae)
  out$forecast_check_loss_H1000 <- as.numeric(src$forecast_check)
  out$fit_source_candidate_id <- as.character(src$candidate_id)
  out$fit_source_run_tag <- as.character(src$run_tag)
  out$fit_source_signoff_grade <- "PASS"
  out$fit_source_status <- "SUCCESS"
  out$fit_source_path <- normalizePath(paths$structured_vb, winslash = "/", mustWork = TRUE)
  out$fit_source_sha256 <- sha256(paths$structured_vb)
  out$forecast_mae_source_candidate_id <- out$fit_source_candidate_id
  out$forecast_mae_source_run_tag <- out$fit_source_run_tag
  out$forecast_mae_source_signoff_grade <- "PASS"
  out$forecast_mae_source_status <- "SUCCESS"
  out$forecast_mae_source_path <- out$fit_source_path
  out$forecast_mae_source_sha256 <- out$fit_source_sha256
  out$forecast_check_source_candidate_id <- out$fit_source_candidate_id
  out$forecast_check_source_run_tag <- out$fit_source_run_tag
  out$forecast_check_source_signoff_grade <- "PASS"
  out$forecast_check_source_status <- "SUCCESS"
  out$forecast_check_source_path <- out$fit_source_path
  out$forecast_check_source_sha256 <- out$fit_source_sha256
  out$validation_branch <- as.character(src$validation_branch)
  out$validation_commit <- as.character(src$validation_commit)
  out$source_promotion_id <- "exdqlm_dqlm_vb_current_best_c13_20260703"
  out
})

vb_qdesn_rows <- lapply(seq_len(nrow(vb_qdesn)), function(i) {
  src <- vb_qdesn[i, , drop = FALSE]
  out <- make_common(src$model_variant, "vb", src$family, src$tau)
  out$status <- as.character(src$status)
  out$signoff_grade <- as.character(src$signoff_grade)
  out$fit_qtrue_rmse <- as.numeric(src$fit_qtrue_rmse)
  out$forecast_qtrue_mae_H1000 <- as.numeric(src$forecast_qtrue_mae_H1000)
  out$forecast_check_loss_H1000 <- as.numeric(src$forecast_check_loss_H1000)
  out$fit_source_candidate_id <- as.character(src$spec_id)
  out$fit_source_run_tag <- as.character(src$run_tag)
  out$fit_source_signoff_grade <- as.character(src$signoff_grade)
  out$fit_source_status <- as.character(src$status)
  out$fit_source_path <- as.character(src$fit_summary_path)
  out$fit_source_sha256 <- as.character(src$fit_summary_sha256)
  out$forecast_mae_source_candidate_id <- as.character(src$spec_id)
  out$forecast_mae_source_run_tag <- as.character(src$run_tag)
  out$forecast_mae_source_signoff_grade <- as.character(src$signoff_grade)
  out$forecast_mae_source_status <- as.character(src$status)
  out$forecast_mae_source_path <- as.character(src$forecast_horizon_path)
  out$forecast_mae_source_sha256 <- as.character(src$forecast_horizon_sha256)
  out$forecast_check_source_candidate_id <- as.character(src$spec_id)
  out$forecast_check_source_run_tag <- as.character(src$run_tag)
  out$forecast_check_source_signoff_grade <- as.character(src$signoff_grade)
  out$forecast_check_source_status <- as.character(src$status)
  out$forecast_check_source_path <- as.character(src$forecast_horizon_path)
  out$forecast_check_source_sha256 <- as.character(src$forecast_horizon_sha256)
  out$preprocessing_scope <- "train_only"
  out$validation_branch <- as.character(src$validation_branch)
  out$validation_commit <- as.character(src$validation_commit)
  out$validation_closeout_commit <- as.character(src$validation_closeout_commit)
  out$source_promotion_id <- "qdesn_500obs_vb_trainonly_rebaseline_v1_closeout_20260805"
  out
})

mcmc_structured_commit <- as.character(
  mcmc_structured_manifest$validation_commit_at_materialization %||%
    mcmc_structured_manifest$validation_commit %||% NA_character_
)
mcmc_structured_branch <- as.character(
  mcmc_structured_manifest$validation_branch %||%
    "validation/shared-fitforecast-v2-1.0.0"
)
mcmc_structured_rows <- lapply(seq_len(nrow(mcmc_structured)), function(i) {
  src <- mcmc_structured[i, , drop = FALSE]
  out <- make_common(src$model_variant, "mcmc", src$family, src$tau)
  out$status <- as.character(src$status)
  out$signoff_grade <- as.character(src$signoff_grade)
  out$metric_source_mixed <- as_bool(src$metric_source_mixed)
  out$fit_qtrue_rmse <- as.numeric(src$fit_qtrue_rmse)
  out$forecast_qtrue_mae_H1000 <- as.numeric(src$forecast_qtrue_mae_H1000)
  out$forecast_check_loss_H1000 <- as.numeric(src$forecast_check_loss_H1000)
  copy_names <- c(
    "fit_source_candidate_id", "fit_source_run_tag", "fit_source_signoff_grade",
    "fit_source_status", "fit_source_path", "fit_source_sha256",
    "forecast_mae_source_candidate_id", "forecast_mae_source_run_tag",
    "forecast_mae_source_signoff_grade", "forecast_mae_source_status",
    "forecast_mae_source_path", "forecast_mae_source_sha256",
    "forecast_check_source_candidate_id", "forecast_check_source_run_tag",
    "forecast_check_source_signoff_grade", "forecast_check_source_status",
    "forecast_check_source_path", "forecast_check_source_sha256"
  )
  for (nm in copy_names) out[[nm]] <- as.character(src[[nm]])
  out$validation_branch <- mcmc_structured_branch
  out$validation_commit <- mcmc_structured_commit
  out$source_promotion_id <- as.character(src$source_promotion_id)
  out
})

mcmc_qdesn_rows <- lapply(seq_len(nrow(mcmc_qdesn)), function(i) {
  src <- mcmc_qdesn[i, , drop = FALSE]
  out <- make_common(src$model_variant, "mcmc", src$family, src$tau)
  grades <- c(
    as.character(src$fit_qtrue_rmse_source_signoff_grade),
    as.character(src$forecast_qtrue_mae_H1000_source_signoff_grade),
    as.character(src$forecast_check_loss_H1000_source_signoff_grade)
  )
  statuses <- c(
    as.character(src$fit_qtrue_rmse_source_status),
    as.character(src$forecast_qtrue_mae_H1000_source_status),
    as.character(src$forecast_check_loss_H1000_source_status)
  )
  out$status <- if (all(statuses == "SUCCESS")) "SUCCESS" else paste(unique(statuses), collapse = ";")
  out$signoff_grade <- worst_grade(grades)
  out$metric_source_mixed <- length(unique(c(
    as.character(src$fit_qtrue_rmse_source_spec_id),
    as.character(src$forecast_qtrue_mae_H1000_source_spec_id),
    as.character(src$forecast_check_loss_H1000_source_spec_id)
  ))) > 1L
  out$fit_qtrue_rmse <- as.numeric(src$fit_qtrue_rmse)
  out$forecast_qtrue_mae_H1000 <- as.numeric(src$forecast_qtrue_mae_H1000)
  out$forecast_check_loss_H1000 <- as.numeric(src$forecast_check_loss_H1000)
  out$fit_source_candidate_id <- as.character(src$fit_qtrue_rmse_source_spec_id)
  out$fit_source_run_tag <- as.character(src$run_tag)
  out$fit_source_signoff_grade <- as.character(src$fit_qtrue_rmse_source_signoff_grade)
  out$fit_source_status <- as.character(src$fit_qtrue_rmse_source_status)
  out$fit_source_path <- as.character(src$fit_qtrue_rmse_source_path)
  out$fit_source_sha256 <- as.character(src$fit_qtrue_rmse_source_sha256)
  out$forecast_mae_source_candidate_id <- as.character(src$forecast_qtrue_mae_H1000_source_spec_id)
  out$forecast_mae_source_run_tag <- as.character(src$run_tag)
  out$forecast_mae_source_signoff_grade <- as.character(src$forecast_qtrue_mae_H1000_source_signoff_grade)
  out$forecast_mae_source_status <- as.character(src$forecast_qtrue_mae_H1000_source_status)
  out$forecast_mae_source_path <- as.character(src$forecast_qtrue_mae_H1000_source_path)
  out$forecast_mae_source_sha256 <- as.character(src$forecast_qtrue_mae_H1000_source_sha256)
  out$forecast_check_source_candidate_id <- as.character(src$forecast_check_loss_H1000_source_spec_id)
  out$forecast_check_source_run_tag <- as.character(src$run_tag)
  out$forecast_check_source_signoff_grade <- as.character(src$forecast_check_loss_H1000_source_signoff_grade)
  out$forecast_check_source_status <- as.character(src$forecast_check_loss_H1000_source_status)
  out$forecast_check_source_path <- as.character(src$forecast_check_loss_H1000_source_path)
  out$forecast_check_source_sha256 <- as.character(src$forecast_check_loss_H1000_source_sha256)
  out$preprocessing_scope <- "train_only"
  out$validation_branch <- "validation/qdesn-trainonly-transport-v1-1.0.0"
  out$validation_commit <- as.character(mcmc_gate$git_commit)
  out$validation_closeout_commit <- as.character(mcmc_gate$closeout_git_commit %||% NA_character_)
  out$source_promotion_id <- "qdesn_500obs_mcmc_trainonly_rebaseline_v1_closeout_20260805"
  out
})

article <- do.call(rbind, c(
  vb_structured_rows,
  vb_qdesn_rows,
  mcmc_structured_rows,
  mcmc_qdesn_rows
))
article <- article[order(
  match(article$inference, c("vb", "mcmc")),
  match(article$family, c("normal", "laplace", "gausmix")),
  match(article$model_variant, c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")),
  article$tau
), , drop = FALSE]
row.names(article) <- NULL

expected_article <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = expected_families,
  tau = expected_taus,
  stringsAsFactors = FALSE
)
article_key <- with(article, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_key <- with(expected_article, paste(inference, model_variant, family, sprintf("%.2f", tau)))
metric_cols <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")
if (nrow(article) != 72L || anyDuplicated(article_key) || !setequal(article_key, expected_key) ||
    any(!is.finite(as.numeric(unlist(article[metric_cols], use.names = FALSE)))) ||
    any(article$source_registry_hash_value != expected_hash)) {
  stop("Materialized article interface violates its 72-cell metric contract.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
vb_copy_dir <- file.path(output_dir, "vb_closeout")
dir.create(vb_copy_dir, recursive = TRUE, showWarnings = FALSE)
vb_closeout_files <- list.files(vb_closeout_dir, full.names = TRUE)
vb_closeout_files <- vb_closeout_files[file.info(vb_closeout_files)$isdir %in% FALSE]
copied <- file.copy(vb_closeout_files, vb_copy_dir, overwrite = TRUE)
if (!all(copied)) stop("Could not freeze all VB closeout files.", call. = FALSE)

article_path <- write_csv(article, file.path(output_dir, paste0(promotion_id, "_interface.csv")))

old_qdesn <- mcmc_structured_all[
  mcmc_structured_all$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  c("model_variant", "family", "tau", metric_cols),
  drop = FALSE
]
new_qdesn <- article[
  article$inference == "mcmc" & grepl("^qdesn_", article$model_variant),
  c("model_variant", "family", "tau", metric_cols),
  drop = FALSE
]
comparison <- merge(
  old_qdesn,
  new_qdesn,
  by = c("model_variant", "family", "tau"),
  suffixes = c("_pre_repair", "_train_only"),
  sort = FALSE
)
for (metric in metric_cols) {
  comparison[[paste0(metric, "_ratio_trainonly_to_pre_repair")]] <-
    comparison[[paste0(metric, "_train_only")]] /
    comparison[[paste0(metric, "_pre_repair")]]
}
comparison_path <- write_csv(
  comparison,
  file.path(output_dir, "qdesn_mcmc_pre_repair_vs_trainonly.csv")
)

source_ledger <- data.frame(
  source_id = names(paths),
  path = normalizePath(unlist(paths, use.names = FALSE), winslash = "/", mustWork = TRUE),
  sha256 = vapply(unlist(paths, use.names = FALSE), sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_ledger_path <- write_csv(source_ledger, file.path(output_dir, "source_ledger.csv"))

output_files <- c(
  article_interface = article_path,
  comparison = comparison_path,
  source_ledger = source_ledger_path
)
output_hashes <- vapply(output_files, sha256, character(1L))
manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_CORRECTED_PROTOCOL_ARTICLE_HANDOFF",
  scientific_decision = "REPLACE_PRE_REPAIR_QDESN_ROWS_AND_EXCLUDE_UNCORRECTED_RIDGE",
  generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  package_version = "1.0.0",
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = expected_hash,
  fit_size = 500L,
  train_start_source_index = 8501L,
  train_end_source_index = 9000L,
  forecast_origin_source_index = 9000L,
  forecast_block_start_source_index = 9001L,
  forecast_block_end_source_index = 10000L,
  max_lead_configured = 30L,
  origin_stride = 30L,
  forecast_protocol = "rolling_origin_no_refit_state_update",
  expected_rows = 72L,
  observed_rows = nrow(article),
  vb_rows = sum(article$inference == "vb"),
  mcmc_rows = sum(article$inference == "mcmc"),
  qdesn_train_only_rows = sum(grepl("^qdesn_", article$model_variant) & article$preprocessing_scope == "train_only"),
  structured_baseline_rows = sum(article$model_variant %in% c("dqlm", "exdqlm")),
  ridge_rows = sum(grepl("ridge", article$model_variant)),
  status_counts = as.list(table(article$status)),
  signoff_counts = as.list(table(article$signoff_grade)),
  article_interface_path = article_path,
  article_interface_sha256 = unname(output_hashes[["article_interface"]]),
  comparison_path = comparison_path,
  comparison_sha256 = unname(output_hashes[["comparison"]]),
  source_ledger_path = source_ledger_path,
  source_ledger_sha256 = unname(output_hashes[["source_ledger"]]),
  vb_gate_decision = as.character(vb_gate$decision),
  mcmc_gate_decision = as.character(mcmc_gate$decision),
  ridge_policy = "EXCLUDED_UNTIL_SEPARATELY_REPLAYED_UNDER_TRAIN_ONLY_PREPROCESSING",
  invalid_or_aborted_run_tags = c(
    "qdesn_vb_trainonly_rebaseline_v1_20260805_025413",
    "qdesn_vb_trainonly_rebaseline_v1_20260805_030205"
  )
)
manifest_path <- file.path(output_dir, paste0(promotion_id, "_manifest.json"))
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, na = "null")

readme <- c(
  "# Corrected 500-Observation Article Handoff",
  "",
  "This promotion is the immutable article-facing interface for the independent",
  "single-quantile 500-observation comparison. It contains 72 rows: four models,",
  "three innovation families, three quantile levels, and two inference methods.",
  "",
  "Q-DESN and exQ-DESN rows use the exact train-only preprocessing replay. DQLM",
  "and exDQLM rows retain their validated structured-model baselines. Historical",
  "ridge rows are excluded because they have not been replayed under the corrected",
  "preprocessing contract.",
  "",
  sprintf("- Interface: `%s`", basename(article_path)),
  sprintf("- Interface SHA-256: `%s`", sha256(article_path)),
  sprintf("- Source registry SHA-256: `%s`", expected_hash),
  "- Forecast protocol: rolling origin, no refit, state update, leads 1-30, stride 30",
  "- Training source indices: 8501-9000",
  "- Forecast source indices: 9001-10000",
  "",
  "The two aborted VB orchestration IDs listed in the manifest are non-consumable."
)
writeLines(readme, file.path(output_dir, "README.md"), useBytes = TRUE)

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat(sprintf("INTERFACE=%s\n", article_path))
cat(sprintf("INTERFACE_SHA256=%s\n", sha256(article_path)))
cat(sprintf("ROWS=%d\n", nrow(article)))
cat(sprintf("SIGNOFF=%s\n", paste(names(table(article$signoff_grade)), table(article$signoff_grade), collapse = ",")))
