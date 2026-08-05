#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")),
                            call. = FALSE)
})
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "YES", "Y", "1")
}
num <- function(x) suppressWarnings(as.numeric(x))

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE,
                                            stringsAsFactors = FALSE)
write_csv <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
file_hash <- function(path) {
  if (!length(path) || is.na(path) || !file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}
read_status <- function(method_dir) {
  paths <- c(file.path(method_dir, "manifest", "fit_status.txt"),
             file.path(method_dir, "manifest", "status.txt"))
  paths <- paths[file.exists(paths)]
  if (!length(paths)) return("MISSING")
  value <- trimws(tail(readLines(paths[[1L]], warn = FALSE), 1L))
  if (nzchar(value)) value else "MISSING"
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
launch_match <- regmatches(run_tag, regexec("__git-([[:xdigit:]]{7,40})$", run_tag))[[1L]]
launch_git_short <- if (length(launch_match) >= 2L) launch_match[[2L]] else NA_character_
launch_git_commit <- if (!is.na(launch_git_short)) {
  tryCatch(trimws(system2("git", c("rev-parse", launch_git_short), stdout = TRUE)),
           error = function(e) NA_character_)
} else NA_character_
closeout_git_commit <- trimws(system("git rev-parse HEAD", intern = TRUE))
output_root <- resolve_path(get_arg("--output-root", file.path(
  "validation", "fitforecast_v2", "promotions",
  paste0("qdesn_500obs_vb_trainonly_rebaseline_v1_closeout_", format(Sys.Date(), "%Y%m%d"))
)), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_defaults.yaml")))
grid <- read_csv(paste0(stub, "_grid.csv"))
targets <- read_csv(paste0(stub, "_target_spec_ids.csv"))
profiles <- read_csv(paste0(stub, "_candidate_contract.csv"))
materialization <- jsonlite::read_json(
  resolve_path(paste0(stub, "_materialization_manifest.json")), simplifyVector = TRUE
)
expected_hash <- as.character(materialization$source_registry_hash_value)
expected_preproc_hash <- as.character(
  materialization$preprocessing$preprocessing_fit_row_indices_sha256
)
if (nrow(grid) != 18L || nrow(targets) != 18L || nrow(profiles) != 18L) {
  stop("Materialized VB rebaseline inputs are inconsistent.", call. = FALSE)
}
results_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
if (!dir.exists(results_root)) stop(sprintf("Full run root does not exist: %s", results_root),
                                    call. = FALSE)
request_paths <- list.files(results_root, pattern = "^fit_request[.]json$", recursive = TRUE,
                            full.names = TRUE)

rows <- lapply(request_paths, function(request_path) {
  request <- jsonlite::read_json(request_path, simplifyVector = TRUE)
  root <- request$root_spec %||% list()
  method_dir <- dirname(request_path)
  summary_path <- file.path(method_dir, "fit_summary_row.csv")
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  manifest_path <- file.path(method_dir, "manifest", "run_manifest.json")
  runtime_path <- file.path(method_dir, "manifest", "runtime_summary.json")
  root_manifest_path <- file.path(dirname(dirname(method_dir)), "manifest", "root_manifest.json")
  summary <- if (file.exists(summary_path)) utils::read.csv(summary_path, check.names = FALSE,
                                                            stringsAsFactors = FALSE) else data.frame()
  horizon <- if (file.exists(horizon_path)) utils::read.csv(horizon_path, check.names = FALSE,
                                                            stringsAsFactors = FALSE) else data.frame()
  manifest <- if (file.exists(manifest_path)) jsonlite::read_json(manifest_path,
                                                                  simplifyVector = TRUE) else list()
  runtime <- if (file.exists(runtime_path)) jsonlite::read_json(runtime_path,
                                                                simplifyVector = TRUE) else list()
  root_manifest <- if (file.exists(root_manifest_path)) jsonlite::read_json(
    root_manifest_path, simplifyVector = TRUE) else list()
  preprocessing <- manifest$preprocessing %||% list()
  h100 <- horizon[as.integer(horizon$horizon) == 100L, , drop = FALSE]
  h1000 <- horizon[as.integer(horizon$horizon) == 1000L, , drop = FALSE]
  profile_id <- as.character(root$screening_profile_id %||% NA_character_)
  profile_index <- match(profile_id, profiles$screening_profile_id)
  profile <- if (!is.na(profile_index)) profiles[profile_index, , drop = FALSE] else NULL
  data.frame(
    spec_id = as.character(request$spec_id %||% NA_character_),
    root_id = as.character(root$root_id %||% NA_character_),
    screening_profile_id = profile_id,
    model_variant = if (!is.null(profile)) profile$model_variant else NA_character_,
    family = as.character(root$source_family %||% NA_character_),
    tau = num(root$tau %||% NA_real_),
    likelihood_family = as.character(root$likelihood_family %||% NA_character_),
    legacy_candidate_id = if (!is.null(profile)) profile$legacy_candidate_id else NA_character_,
    legacy_run_tag = if (!is.null(profile)) profile$legacy_run_tag else NA_character_,
    legacy_fit_qtrue_rmse = if (!is.null(profile)) num(profile$legacy_fit_qtrue_rmse) else NA_real_,
    legacy_forecast_qtrue_mae_H1000 = if (!is.null(profile)) {
      num(profile$legacy_forecast_qtrue_mae_H1000)
    } else NA_real_,
    legacy_forecast_check_loss_H1000 = if (!is.null(profile)) {
      num(profile$legacy_forecast_check_loss_H1000)
    } else NA_real_,
    status = if (nrow(summary) == 1L) as.character(summary$status[[1L]] %||%
      read_status(method_dir)) else read_status(method_dir),
    signoff_grade = if (nrow(summary) == 1L) {
      as.character(summary$signoff_grade[[1L]] %||% NA_character_)
    } else NA_character_,
    fit_qtrue_rmse = if (nrow(summary) == 1L) num(summary$train_qtrue_rmse[[1L]]) else NA_real_,
    forecast_qtrue_mae_H100 = if (nrow(h100) == 1L) num(h100$qtrue_mae[[1L]]) else NA_real_,
    forecast_check_loss_H100 = if (nrow(h100) == 1L) num(h100$pinball_tau[[1L]]) else NA_real_,
    forecast_qtrue_mae_H1000 = if (nrow(h1000) == 1L) num(h1000$qtrue_mae[[1L]]) else NA_real_,
    forecast_check_loss_H1000 = if (nrow(h1000) == 1L) num(h1000$pinball_tau[[1L]]) else NA_real_,
    runtime_seconds = num(runtime$elapsed_seconds %||%
      if (nrow(summary) == 1L) summary$runtime_sec[[1L]] else NA_real_),
    preprocessing_scope = as.character(preprocessing$scope %||% NA_character_),
    preprocessing_fit_row_start = as.integer(preprocessing$fit_row_start %||% NA_integer_),
    preprocessing_fit_row_end = as.integer(preprocessing$fit_row_end %||% NA_integer_),
    preprocessing_fit_row_count = as.integer(preprocessing$fit_row_count %||% NA_integer_),
    preprocessing_fit_row_indices_sha256 = as.character(
      preprocessing$fit_row_indices_sha256 %||% NA_character_
    ),
    heldout_response_used = as_bool(preprocessing$heldout_response_used_for_scaling %||% NA),
    heldout_covariates_used = as_bool(preprocessing$heldout_covariates_used_for_scaling %||% NA),
    source_registry_hash_value = as.character(
      request$study_contract$source_registry_hash_value %||%
        root$source_registry_hash_value %||% NA_character_
    ),
    train_start_source_index = as.integer(root$train_start_source_index %||% NA_integer_),
    train_end_source_index = as.integer(root$train_end_source_index %||% NA_integer_),
    forecast_origin_source_index = 9000L,
    forecast_block_start_source_index = as.integer(root$forecast_start_source_index %||% NA_integer_),
    forecast_block_end_source_index = as.integer(root$forecast_end_source_index %||% NA_integer_),
    forecast_max_lead_configured = as.integer(request$config$forecast$horizon %||% NA_integer_),
    forecast_origin_stride = as.integer(request$config$forecast$origin_stride %||% NA_integer_),
    vb_max_iter = as.integer(request$config$inference$vb$max_iter %||% NA_integer_),
    vb_min_iter_elbo = as.integer(request$config$inference$vb$min_iter_elbo %||% NA_integer_),
    vb_n_samp_xi = as.integer(request$config$inference$vb$n_samp_xi %||% NA_integer_),
    observed_root_seed = as.integer(root$seed %||% NA_integer_),
    observed_desn_seed = as.integer(request$config$desn$seed %||% NA_integer_),
    observed_synthesis_seed = as.integer(request$config$synthesis$seed %||% NA_integer_),
    fit_summary_path = if (file.exists(summary_path)) normalizePath(summary_path, winslash = "/") else NA_character_,
    fit_summary_sha256 = file_hash(summary_path),
    forecast_horizon_path = if (file.exists(horizon_path)) normalizePath(horizon_path, winslash = "/") else NA_character_,
    forecast_horizon_sha256 = file_hash(horizon_path),
    fit_request_path = normalizePath(request_path, winslash = "/"),
    fit_request_sha256 = file_hash(request_path),
    run_manifest_path = if (file.exists(manifest_path)) normalizePath(manifest_path, winslash = "/") else NA_character_,
    run_manifest_sha256 = file_hash(manifest_path),
    validation_branch = trimws(system("git branch --show-current", intern = TRUE)),
    validation_commit = launch_git_commit,
    validation_closeout_commit = closeout_git_commit,
    package_version = "1.0.0",
    run_tag = run_tag,
    root_git_sha = as.character(root_manifest$git_sha %||% NA_character_),
    stringsAsFactors = FALSE
  )
})
observed <- if (length(rows)) do.call(rbind, rows) else data.frame()
if (nrow(observed) && anyDuplicated(observed$spec_id)) stop("Duplicate VB fit requests found.",
                                                           call. = FALSE)

expected <- targets[, c("spec_id", "root_id", "screening_profile_id", "family", "tau",
                        "likelihood_family", "desn_seed", "synthesis_seed")]
expected$seed <- grid$seed[match(expected$root_id, grid$root_id)]
if (anyNA(expected$seed)) stop("Target/grid seed join failed.", call. = FALSE)
names(expected)[names(expected) %in% c("seed", "desn_seed", "synthesis_seed")] <-
  paste0("expected_", names(expected)[names(expected) %in%
    c("seed", "desn_seed", "synthesis_seed")])
execution <- merge(expected, observed,
  by = c("spec_id", "root_id", "screening_profile_id", "family", "tau",
         "likelihood_family"), all = TRUE, sort = FALSE)
if (nrow(execution)) {
  execution$metric_complete <- with(execution, is.finite(fit_qtrue_rmse) &
    is.finite(forecast_qtrue_mae_H100) & is.finite(forecast_check_loss_H100) &
    is.finite(forecast_qtrue_mae_H1000) & is.finite(forecast_check_loss_H1000))
  execution$preprocessing_contract_match <- with(execution,
    preprocessing_scope == "train_only" & preprocessing_fit_row_start == 1L &
      preprocessing_fit_row_end == 890L & preprocessing_fit_row_count == 890L &
      preprocessing_fit_row_indices_sha256 == expected_preproc_hash &
      !heldout_response_used & !heldout_covariates_used)
  execution$source_contract_match <- with(execution,
    source_registry_hash_value == expected_hash &
      train_start_source_index == 8501L & train_end_source_index == 9000L &
      forecast_block_start_source_index == 9001L &
      forecast_block_end_source_index == 10000L &
      forecast_max_lead_configured == 30L & forecast_origin_stride == 30L)
  execution$budget_contract_match <- with(execution,
    vb_max_iter == 150L & vb_min_iter_elbo == 40L & vb_n_samp_xi == 500L)
  execution$seed_contract_match <- with(execution,
    observed_root_seed == expected_seed & observed_desn_seed == expected_desn_seed &
      observed_synthesis_seed == expected_synthesis_seed)
  execution$protocol_eligible <- with(execution, metric_complete &
    preprocessing_contract_match & source_contract_match & budget_contract_match &
    seed_contract_match)
  execution$fit_ratio_to_legacy <- execution$fit_qtrue_rmse / execution$legacy_fit_qtrue_rmse
  execution$forecast_mae_ratio_to_legacy <- execution$forecast_qtrue_mae_H1000 /
    execution$legacy_forecast_qtrue_mae_H1000
  execution$forecast_check_ratio_to_legacy <- execution$forecast_check_loss_H1000 /
    execution$legacy_forecast_check_loss_H1000
}
execution <- execution[order(execution$model_variant, execution$family, execution$tau), ]
execution_path <- write_csv(execution, file.path(output_root, "execution_contract_audit.csv"))

corrected <- execution[, c(
  "model_variant", "family", "tau", "likelihood_family", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H100", "forecast_check_loss_H100",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000", "runtime_seconds",
  "status", "signoff_grade", "protocol_eligible", "screening_profile_id", "spec_id",
  "train_start_source_index", "train_end_source_index", "forecast_origin_source_index",
  "forecast_block_start_source_index", "forecast_block_end_source_index",
  "forecast_max_lead_configured", "forecast_origin_stride", "preprocessing_scope",
  "source_registry_hash_value", "fit_summary_path", "fit_summary_sha256",
  "forecast_horizon_path", "forecast_horizon_sha256", "fit_request_path",
  "fit_request_sha256", "run_manifest_path", "run_manifest_sha256",
  "package_version", "validation_branch", "validation_commit", "run_tag"
)]
corrected$inference <- "vb"
corrected$fit_size <- 500L
corrected$effective_fit_size <- 500L
corrected$prior <- "rhs_ns"
corrected <- corrected[, c("model_variant", "likelihood_family", "inference", "prior",
  "family", "tau", "fit_size", "effective_fit_size", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H100", "forecast_check_loss_H100",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000", "runtime_seconds",
  setdiff(names(corrected), c("model_variant", "likelihood_family", "inference", "prior",
    "family", "tau", "fit_size", "effective_fit_size", "fit_qtrue_rmse",
    "forecast_qtrue_mae_H100", "forecast_check_loss_H100",
    "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000", "runtime_seconds")))]
corrected_path <- write_csv(corrected, file.path(output_root,
  "qdesn_500obs_vb_trainonly_corrected_interface.csv"))

comparison <- execution[, c("model_variant", "family", "tau", "status", "signoff_grade",
  "legacy_fit_qtrue_rmse", "fit_qtrue_rmse", "fit_ratio_to_legacy",
  "legacy_forecast_qtrue_mae_H1000", "forecast_qtrue_mae_H1000",
  "forecast_mae_ratio_to_legacy", "legacy_forecast_check_loss_H1000",
  "forecast_check_loss_H1000", "forecast_check_ratio_to_legacy", "protocol_eligible")]
comparison_path <- write_csv(comparison, file.path(output_root,
  "legacy_vb_reestimation_comparison.csv"))

expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- unique(as.character(observed$spec_id))
missing_path <- write_csv(data.frame(spec_id = setdiff(expected_ids, observed_ids)),
                          file.path(output_root, "missing_spec_ids.csv"))
unexpected_path <- write_csv(data.frame(spec_id = setdiff(observed_ids, expected_ids)),
                             file.path(output_root, "unexpected_spec_ids.csv"))
binaries <- list.files(results_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                       full.names = TRUE, ignore.case = TRUE)
storage <- if (length(binaries)) data.frame(
  path = normalizePath(binaries, winslash = "/"),
  bytes = as.numeric(file.info(binaries)$size),
  disposition = "unexpected_run_local_binary_payload"
) else data.frame(path = character(), bytes = numeric(), disposition = character())
storage_path <- write_csv(storage, file.path(output_root, "storage_audit.csv"))

complete <- nrow(execution) == 18L && setequal(expected_ids, observed_ids) &&
  all(execution$protocol_eligible %in% TRUE) && nrow(corrected) == 18L && !length(binaries)
decision <- if (complete) {
  "CORRECTED_VB_REBASELINE_COMPLETE_MANUAL_ARTICLE_REVIEW_REQUIRED"
} else "INCOMPLETE_CORRECTED_VB_REBASELINE_NO_ARTICLE_UPDATE"
outputs <- c(execution_contract_audit = execution_path,
             corrected_vb_interface = corrected_path,
             legacy_vb_reestimation_comparison = comparison_path,
             missing_spec_ids = missing_path, unexpected_spec_ids = unexpected_path,
             storage_audit = storage_path)
output_manifest <- data.frame(role = names(outputs), path = unname(outputs),
  sha256 = vapply(outputs, file_hash, character(1L)), stringsAsFactors = FALSE)
output_manifest_path <- write_csv(output_manifest, file.path(output_root,
                                                              "output_file_manifest.csv"))
gate_path <- write_json(list(
  generated_at = as.character(Sys.time()), stage = stage, run_tag = run_tag,
  git_commit = launch_git_commit, launch_git_short = launch_git_short,
  closeout_git_commit = closeout_git_commit,
  source_registry_hash_value = expected_hash, preprocessing_scope = "train_only",
  expected_specs = 18L, observed_requests = nrow(observed),
  protocol_eligible_specs = sum(execution$protocol_eligible %in% TRUE),
  corrected_interface_rows = nrow(corrected),
  unexpected_binary_payloads = length(binaries),
  diagnostic_status_counts = as.list(table(execution$status, useNA = "ifany")),
  diagnostic_signoff_counts = as.list(table(execution$signoff_grade, useNA = "ifany")),
  improves_legacy_counts = list(
    fit = sum(execution$fit_ratio_to_legacy < 1, na.rm = TRUE),
    forecast_mae = sum(execution$forecast_mae_ratio_to_legacy < 1, na.rm = TRUE),
    forecast_check = sum(execution$forecast_check_ratio_to_legacy < 1, na.rm = TRUE)
  ),
  legacy_qdesn_vb_metrics_invalidated_by_preprocessing_repair = TRUE,
  article_updated = FALSE,
  output_file_manifest = output_manifest_path,
  decision = decision
), file.path(output_root, "vb_rebaseline_gate.json"))
cat(sprintf("decision: %s\n", decision))
cat(sprintf("progress: %d/18 protocol-eligible specs; %d binaries\n",
            sum(execution$protocol_eligible %in% TRUE), length(binaries)))
cat(sprintf("gate: %s\n", gate_path))
