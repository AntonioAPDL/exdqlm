#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
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

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
file_hash <- function(path) {
  if (!length(path) || is.na(path) || !file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}
read_status <- function(method_dir) {
  paths <- c(
    file.path(method_dir, "manifest", "fit_status.txt"),
    file.path(method_dir, "manifest", "status.txt")
  )
  paths <- paths[file.exists(paths)]
  if (!length(paths)) return("MISSING")
  value <- trimws(tail(readLines(paths[[1L]], warn = FALSE), 1L))
  if (nzchar(value)) value else "MISSING"
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
launch_git_match <- regmatches(
  run_tag,
  regexec("__git-([[:xdigit:]]{7,40})$", run_tag, perl = TRUE)
)[[1L]]
launch_git_short <- if (length(launch_git_match) >= 2L) {
  launch_git_match[[2L]]
} else NA_character_
launch_git_commit <- if (!is.na(launch_git_short)) {
  tryCatch(
    trimws(system2("git", c("rev-parse", launch_git_short), stdout = TRUE)),
    error = function(e) NA_character_
  )
} else NA_character_
closeout_git_commit <- trimws(system("git rev-parse HEAD", intern = TRUE))
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    paste0("qdesn_500obs_mcmc_trainonly_rebaseline_v1_closeout_", format(Sys.Date(), "%Y%m%d"))
  )
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_defaults.yaml")))
grid <- read_csv(paste0(stub, "_grid.csv"))
targets <- read_csv(paste0(stub, "_target_spec_ids.csv"))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
legacy_contract <- read_csv(paste0(stub, "_legacy_metric_contract.csv"))
materialization <- jsonlite::read_json(
  resolve_path(paste0(stub, "_materialization_manifest.json")),
  simplifyVector = TRUE
)
expected_count <- as.integer(materialization$counts$full_specs)
expected_hash <- as.character(materialization$source_registry_hash_value)
expected_preproc_hash <- as.character(
  materialization$preprocessing$preprocessing_fit_row_indices_sha256
)
if (expected_count < 18L || nrow(grid) != expected_count ||
    nrow(targets) != expected_count || nrow(profiles) != expected_count ||
    nrow(legacy_contract) != 54L) {
  stop("Materialized rebaseline inputs are internally inconsistent.", call. = FALSE)
}

results_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
if (!dir.exists(results_root)) {
  stop(sprintf("Full run root does not exist: %s", results_root), call. = FALSE)
}
request_paths <- list.files(
  results_root, pattern = "^fit_request[.]json$", recursive = TRUE, full.names = TRUE
)

rows <- lapply(request_paths, function(request_path) {
  request <- jsonlite::read_json(request_path, simplifyVector = TRUE)
  root <- request$root_spec %||% list()
  method_dir <- dirname(request_path)
  fit_summary_path <- file.path(method_dir, "fit_summary_row.csv")
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  run_manifest_path <- file.path(method_dir, "manifest", "run_manifest.json")
  runtime_path <- file.path(method_dir, "manifest", "runtime_summary.json")
  root_manifest_path <- file.path(dirname(dirname(method_dir)), "manifest", "root_manifest.json")
  summary <- if (file.exists(fit_summary_path)) {
    utils::read.csv(fit_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
  } else data.frame()
  horizon <- if (file.exists(horizon_path)) {
    utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE)
  } else data.frame()
  run_manifest <- if (file.exists(run_manifest_path)) {
    jsonlite::read_json(run_manifest_path, simplifyVector = TRUE)
  } else list()
  runtime <- if (file.exists(runtime_path)) {
    jsonlite::read_json(runtime_path, simplifyVector = TRUE)
  } else list()
  root_manifest <- if (file.exists(root_manifest_path)) {
    jsonlite::read_json(root_manifest_path, simplifyVector = TRUE)
  } else list()
  preprocessing <- run_manifest$preprocessing %||% list()
  study_contract <- request$study_contract %||% list()
  h100 <- horizon[as.integer(horizon$horizon) == 100L, , drop = FALSE]
  h1000 <- horizon[as.integer(horizon$horizon) == 1000L, , drop = FALSE]
  profile_id <- as.character(root$screening_profile_id %||% NA_character_)
  profile_index <- match(profile_id, profiles$screening_profile_id)
  profile <- if (!is.na(profile_index)) profiles[profile_index, , drop = FALSE] else NULL
  data.frame(
    spec_id = as.character(request$spec_id %||% NA_character_),
    root_id = as.character(root$root_id %||% NA_character_),
    screening_profile_id = profile_id,
    candidate_key = if (!is.null(profile)) profile$candidate_key else NA_character_,
    model_variant = if (!is.null(profile)) profile$model_variant else NA_character_,
    family = as.character(root$source_family %||% NA_character_),
    tau = num(root$tau %||% NA_real_),
    likelihood_family = as.character(root$likelihood_family %||% NA_character_),
    legacy_candidate_id = if (!is.null(profile)) profile$legacy_candidate_id else NA_character_,
    legacy_run_tag = if (!is.null(profile)) profile$legacy_run_tag else NA_character_,
    status = if (nrow(summary) == 1L) {
      as.character(summary$status[[1L]] %||% read_status(method_dir))
    } else read_status(method_dir),
    signoff_grade = if (nrow(summary) == 1L) {
      as.character(summary$signoff_grade[[1L]] %||% NA_character_)
    } else NA_character_,
    fit_qtrue_rmse = if (nrow(summary) == 1L) {
      num(summary$train_qtrue_rmse[[1L]] %||% NA_real_)
    } else NA_real_,
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
    heldout_response_used = as_bool(
      preprocessing$heldout_response_used_for_scaling %||% NA
    ),
    heldout_covariates_used = as_bool(
      preprocessing$heldout_covariates_used_for_scaling %||% NA
    ),
    source_registry_hash = as.character(
      study_contract$source_registry_hash_value %||%
        root$source_registry_hash_value %||% NA_character_
    ),
    train_start_source_index = as.integer(root$train_start_source_index %||% NA_integer_),
    train_end_source_index = as.integer(root$train_end_source_index %||% NA_integer_),
    forecast_start_source_index = as.integer(root$forecast_start_source_index %||% NA_integer_),
    forecast_end_source_index = as.integer(root$forecast_end_source_index %||% NA_integer_),
    mcmc_n_burn = as.integer(request$config$inference$mcmc$n_burn %||% NA_integer_),
    mcmc_n_mcmc = as.integer(request$config$inference$mcmc$n_mcmc %||% NA_integer_),
    observed_desn_seed = as.integer(request$config$desn$seed %||% NA_integer_),
    observed_mcmc_seed = as.integer(
      request$config$inference$mcmc$control$seed %||% NA_integer_
    ),
    observed_mcmc_rng_seed = as.integer(
      request$config$inference$mcmc$control$rng_seed %||% NA_integer_
    ),
    observed_vb_warm_start_seed = as.integer(
      request$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_
    ),
    observed_synthesis_seed = as.integer(request$config$synthesis$seed %||% NA_integer_),
    fit_summary_path = if (file.exists(fit_summary_path)) {
      normalizePath(fit_summary_path, winslash = "/", mustWork = TRUE)
    } else NA_character_,
    fit_summary_sha256 = file_hash(fit_summary_path),
    forecast_horizon_path = if (file.exists(horizon_path)) {
      normalizePath(horizon_path, winslash = "/", mustWork = TRUE)
    } else NA_character_,
    forecast_horizon_sha256 = file_hash(horizon_path),
    fit_request_path = normalizePath(request_path, winslash = "/", mustWork = TRUE),
    fit_request_sha256 = file_hash(request_path),
    run_manifest_path = if (file.exists(run_manifest_path)) {
      normalizePath(run_manifest_path, winslash = "/", mustWork = TRUE)
    } else NA_character_,
    run_manifest_sha256 = file_hash(run_manifest_path),
    root_git_sha = as.character(root_manifest$git_sha %||% NA_character_),
    stringsAsFactors = FALSE
  )
})
observed <- if (length(rows)) do.call(rbind, rows) else data.frame()
if (nrow(observed) && anyDuplicated(observed$spec_id)) {
  stop("Full run contains duplicate fit requests for one spec_id.", call. = FALSE)
}

expected <- targets[, c(
  "spec_id", "root_id", "screening_profile_id", "family", "tau",
  "likelihood_family", "desn_seed", "mcmc_seed", "mcmc_rng_seed",
  "vb_warm_start_seed", "synthesis_seed"
), drop = FALSE]
names(expected)[names(expected) %in% c(
  "desn_seed", "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed"
)] <- paste0("expected_", names(expected)[names(expected) %in% c(
  "desn_seed", "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed"
)])
execution <- merge(
  expected, observed,
  by = c("spec_id", "root_id", "screening_profile_id", "family", "tau", "likelihood_family"),
  all = TRUE, sort = FALSE
)
if (nrow(execution)) {
  execution$metric_complete <- with(execution, is.finite(fit_qtrue_rmse) &
    is.finite(forecast_qtrue_mae_H100) & is.finite(forecast_check_loss_H100) &
    is.finite(forecast_qtrue_mae_H1000) & is.finite(forecast_check_loss_H1000))
  execution$preprocessing_contract_match <- with(execution,
    preprocessing_scope == "train_only" &
      preprocessing_fit_row_start == 1L & preprocessing_fit_row_end == 890L &
      preprocessing_fit_row_count == 890L &
      preprocessing_fit_row_indices_sha256 == expected_preproc_hash &
      !heldout_response_used & !heldout_covariates_used)
  execution$source_contract_match <- with(execution,
    !is.na(source_registry_hash) & source_registry_hash == expected_hash &
      train_start_source_index == 8501L & train_end_source_index == 9000L &
      forecast_start_source_index == 9001L & forecast_end_source_index == 10000L)
  execution$budget_contract_match <- with(execution,
    mcmc_n_burn == 5000L & mcmc_n_mcmc == 20000L)
  execution$seed_contract_match <- with(execution,
    observed_desn_seed == expected_desn_seed &
      observed_mcmc_seed == expected_mcmc_seed &
      observed_mcmc_rng_seed == expected_mcmc_rng_seed &
      observed_vb_warm_start_seed == expected_vb_warm_start_seed &
      observed_synthesis_seed == expected_synthesis_seed)
  execution$protocol_eligible <- with(execution,
    metric_complete & preprocessing_contract_match & source_contract_match &
      budget_contract_match & seed_contract_match)
}
execution_path <- write_csv(execution, file.path(output_root, "execution_contract_audit.csv"))

expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(observed)) unique(as.character(observed$spec_id)) else character()
missing_path <- write_csv(
  data.frame(spec_id = setdiff(expected_ids, observed_ids)),
  file.path(output_root, "missing_spec_ids.csv")
)
unexpected_path <- write_csv(
  data.frame(spec_id = setdiff(observed_ids, expected_ids)),
  file.path(output_root, "unexpected_spec_ids.csv")
)

metric_names <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
comparison <- legacy_contract
candidate_index <- match(comparison$candidate_key, execution$candidate_key)
comparison$rebaseline_spec_id <- execution$spec_id[candidate_index]
comparison$rebaseline_status <- execution$status[candidate_index]
comparison$rebaseline_signoff_grade <- execution$signoff_grade[candidate_index]
comparison$rebaseline_protocol_eligible <- execution$protocol_eligible[candidate_index]
comparison$rebaseline_metric_value <- vapply(seq_len(nrow(comparison)), function(i) {
  index <- candidate_index[[i]]
  if (is.na(index)) return(NA_real_)
  num(execution[[comparison$metric_name[[i]]]][[index]])
}, numeric(1L))
comparison$ratio_to_legacy <- comparison$rebaseline_metric_value / comparison$legacy_metric_value
comparison$improves_legacy <- comparison$ratio_to_legacy < 1
comparison_path <- write_csv(
  comparison, file.path(output_root, "legacy_source_reestimation_comparison.csv")
)

eligible <- execution[execution$protocol_eligible %in% TRUE, , drop = FALSE]
cell_keys <- unique(profiles[, c("model_variant", "target_family", "target_tau"), drop = FALSE])
names(cell_keys) <- c("model_variant", "family", "tau")
cell_keys <- cell_keys[order(cell_keys$model_variant, cell_keys$family, cell_keys$tau), , drop = FALSE]
envelope_rows <- lapply(seq_len(nrow(cell_keys)), function(i) {
  key <- cell_keys[i, , drop = FALSE]
  candidates <- eligible[
    eligible$model_variant == key$model_variant &
      eligible$family == key$family & abs(eligible$tau - key$tau) <= 1e-12,
    , drop = FALSE
  ]
  out <- key
  out$candidate_count <- nrow(candidates)
  for (metric in metric_names) {
    index <- if (nrow(candidates)) which.min(candidates[[metric]]) else integer(0)
    winner <- if (length(index)) candidates[index[[1L]], , drop = FALSE] else NULL
    out[[metric]] <- if (!is.null(winner)) winner[[metric]] else NA_real_
    out[[paste0(metric, "_source_profile_id")]] <- if (!is.null(winner)) {
      winner$screening_profile_id
    } else NA_character_
    out[[paste0(metric, "_source_spec_id")]] <- if (!is.null(winner)) {
      winner$spec_id
    } else NA_character_
    out[[paste0(metric, "_source_status")]] <- if (!is.null(winner)) {
      winner$status
    } else NA_character_
    out[[paste0(metric, "_source_signoff_grade")]] <- if (!is.null(winner)) {
      winner$signoff_grade
    } else NA_character_
    out[[paste0(metric, "_source_path")]] <- if (!is.null(winner)) {
      if (metric == "fit_qtrue_rmse") winner$fit_summary_path else winner$forecast_horizon_path
    } else NA_character_
    out[[paste0(metric, "_source_sha256")]] <- if (!is.null(winner)) {
      if (metric == "fit_qtrue_rmse") winner$fit_summary_sha256 else winner$forecast_horizon_sha256
    } else NA_character_
  }
  out$source_registry_hash_value <- expected_hash
  out$preprocessing_scope <- "train_only"
  out$run_tag <- run_tag
  out
})
corrected_envelope <- do.call(rbind, envelope_rows)
corrected_envelope_path <- write_csv(
  corrected_envelope, file.path(output_root, "corrected_qdesn_metric_envelope.csv")
)

binary_paths <- list.files(
  results_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
storage_audit <- if (length(binary_paths)) {
  data.frame(
    path = normalizePath(binary_paths, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(file.info(binary_paths)$size),
    disposition = "unexpected_run_local_binary_payload",
    stringsAsFactors = FALSE
  )
} else data.frame(path = character(), bytes = numeric(), disposition = character())
storage_path <- write_csv(storage_audit, file.path(output_root, "storage_audit.csv"))

complete <- nrow(execution) == expected_count && setequal(expected_ids, observed_ids) &&
  all(execution$protocol_eligible %in% TRUE) && nrow(corrected_envelope) == 18L &&
  all(rowSums(is.na(corrected_envelope[, metric_names, drop = FALSE])) == 0L) &&
  !length(binary_paths)
decision <- if (complete) {
  "CORRECTED_REBASELINE_COMPLETE_MANUAL_ARTICLE_REVIEW_REQUIRED"
} else {
  "INCOMPLETE_CORRECTED_REBASELINE_NO_ARTICLE_UPDATE"
}

outputs <- c(
  execution_contract_audit = execution_path,
  missing_spec_ids = missing_path,
  unexpected_spec_ids = unexpected_path,
  legacy_source_reestimation_comparison = comparison_path,
  corrected_qdesn_metric_envelope = corrected_envelope_path,
  storage_audit = storage_path
)
output_manifest <- data.frame(
  role = names(outputs), path = unname(outputs),
  sha256 = vapply(outputs, file_hash, character(1L)), stringsAsFactors = FALSE
)
output_manifest_path <- write_csv(
  output_manifest, file.path(output_root, "output_file_manifest.csv")
)
gate_path <- write_json(list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  git_commit = launch_git_commit,
  launch_git_short = launch_git_short,
  closeout_git_commit = closeout_git_commit,
  observed_root_git_sha_counts = as.list(table(execution$root_git_sha, useNA = "ifany")),
  source_registry_hash_value = expected_hash,
  preprocessing_scope = "train_only",
  expected_specs = expected_count,
  observed_requests = nrow(observed),
  protocol_eligible_specs = if (nrow(execution)) sum(execution$protocol_eligible %in% TRUE) else 0L,
  corrected_envelope_rows = nrow(corrected_envelope),
  unexpected_binary_payloads = length(binary_paths),
  diagnostic_status_counts = as.list(table(execution$status, useNA = "ifany")),
  diagnostic_signoff_counts = as.list(table(execution$signoff_grade, useNA = "ifany")),
  legacy_qdesn_metrics_invalidated_by_preprocessing_repair = TRUE,
  article_updated = FALSE,
  article_update_policy = paste(
    "No automatic article write. Review the complete corrected envelope against",
    "DQLM/exDQLM evidence before an explicit article-safe promotion."
  ),
  output_file_manifest = output_manifest_path,
  decision = decision
), file.path(output_root, "rebaseline_gate.json"))

cat(sprintf("decision: %s\n", decision))
cat(sprintf(
  "progress: %d/%d protocol-eligible specs; %d/18 corrected envelope rows; %d binaries\n",
  if (nrow(execution)) sum(execution$protocol_eligible %in% TRUE) else 0L,
  expected_count, nrow(corrected_envelope), length(binary_paths)
))
cat(sprintf("gate: %s\n", gate_path))
