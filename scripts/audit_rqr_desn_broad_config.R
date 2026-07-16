#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) {
      stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    }
    key <- sub("^--", "", key)
    value <- "true"
    if (ii < length(args) && !startsWith(args[[ii + 1L]], "--")) {
      value <- args[[ii + 1L]]
      ii <- ii + 1L
    }
    out[[key]] <- value
    ii <- ii + 1L
  }
  out
}

git_value <- function(repo_root, ...) {
  value <- tryCatch(
    system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  paste(value, collapse = "\n")
}

write_csv <- function(x, path) {
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

config_error <- function(...) {
  stop(paste(..., collapse = ""), call. = FALSE)
}

recursive_name_hits <- function(x, forbidden, path = "config") {
  hits <- character(0)
  if (is.list(x)) {
    nms <- names(x) %||% character(0)
    bad <- intersect(nms, forbidden)
    if (length(bad)) {
      hits <- c(hits, paste0(path, "$", bad))
    }
    for (nm in nms) {
      hits <- c(hits, recursive_name_hits(x[[nm]], forbidden, paste0(path, "$", nm)))
    }
  }
  hits
}

vector_len <- function(x) {
  if (length(x) == 1L && is.na(x)) 1L else length(x)
}

design_count <- function(backend, designs) {
  design_ids <- backend$design_ids %||% "none"
  if (identical(design_ids, "none")) return(1L)
  if (identical(design_ids, "all")) return(length(designs))
  length(design_ids)
}

expand_backend_rows <- function(stage, stage_index) {
  out <- list()
  kk <- 0L
  family_ids <- vapply(stage$dgp_families, function(x) x$family_id, character(1))
  design_ids_all <- vapply(stage$designs, function(x) x$design_id, character(1))
  for (backend_index in seq_along(stage$backends)) {
    backend <- stage$backends[[backend_index]]
    design_ids <- backend$design_ids %||% "none"
    if (identical(design_ids, "none")) {
      selected_designs <- "none"
    } else if (identical(design_ids, "all")) {
      selected_designs <- design_ids_all
    } else {
      selected_designs <- as.character(design_ids)
    }
    missing_designs <- setdiff(selected_designs, c("none", design_ids_all))
    if (length(missing_designs)) {
      config_error("Backend ", backend$backend_id, " references unknown design(s): ", paste(missing_designs, collapse = ", "))
    }
    row_count <- length(family_ids) *
      as.integer(stage$replicates) *
      length(selected_designs) *
      vector_len(backend$priors) *
      vector_len(backend$coverage_levels) *
      vector_len(backend$learning_rates)
    kk <- kk + 1L
    out[[kk]] <- data.frame(
      stage_id = stage$stage_id,
      stage_index = stage_index,
      backend_id = backend$backend_id,
      backend_index = backend_index,
      inference = backend$inference,
      primary = isTRUE(backend$primary),
      dgp_families = length(family_ids),
      replicates = as.integer(stage$replicates),
      designs = length(selected_designs),
      priors = vector_len(backend$priors),
      coverage_levels = vector_len(backend$coverage_levels),
      learning_rates = vector_len(backend$learning_rates),
      expected_rows = row_count,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, out)
}

flatten_dgps <- function(config) {
  rows <- list()
  kk <- 0L
  for (stage in config$stages) {
    for (fam in stage$dgp_families) {
      kk <- kk + 1L
      rows[[kk]] <- data.frame(
        stage_id = stage$stage_id,
        family_id = fam$family_id,
        noise = fam$noise %||% NA_character_,
        oracle_endpoints = isTRUE(fam$oracle_endpoints),
        replicates = as.integer(stage$replicates),
        n_train = as.integer(stage$n_train),
        n_test = as.integer(stage$n_test),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

flatten_designs <- function(config) {
  rows <- list()
  kk <- 0L
  for (stage in config$stages) {
    for (des in stage$designs) {
      kk <- kk + 1L
      rows[[kk]] <- data.frame(
        stage_id = stage$stage_id,
        design_id = des$design_id,
        design_type = des$design_type,
        DESN_D = des$DESN_D %||% NA_integer_,
        DESN_n = des$DESN_n %||% NA_integer_,
        DESN_m = des$DESN_m %||% NA_integer_,
        washout = des$washout %||% NA_integer_,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

args <- parse_cli(commandArgs(trailingOnly = TRUE))
repo_root <- args[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
if (!nzchar(repo_root)) repo_root <- getwd()
repo_root <- normalizePath(repo_root, mustWork = TRUE)
config_path <- args[["config"]] %||% file.path(repo_root, "config", "rqr_desn", "rqr_desn_broad_simulation_frozen_20260716.R")
config_path <- normalizePath(config_path, mustWork = TRUE)
env <- new.env(parent = baseenv())
sys.source(config_path, envir = env)
config <- get("rqr_desn_broad_simulation_config", envir = env)

short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
output_dir <- args[["output-dir"]] %||% file.path(
  repo_root,
  "reports",
  "rqr_desn_broad_config_audit",
  sprintf("rqr_desn_broad_config_audit_%s_git_%s", stamp, short_sha)
)
output_dir <- normalizePath(output_dir, mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

checks <- list()
add_check <- function(check_id, passed, detail) {
  checks[[length(checks) + 1L]] <<- data.frame(
    check_id = check_id,
    passed = isTRUE(passed),
    detail = as.character(detail),
    stringsAsFactors = FALSE
  )
}

add_check("status_frozen_no_launch", identical(config$status, "frozen_no_launch"), config$status)
add_check("launch_not_authorized", identical(config$launch_authorized, FALSE), config$launch_authorized)
add_check("article_update_not_allowed", identical(config$article_update_allowed, FALSE), config$article_update_allowed)
add_check("package_side_only", isTRUE(config$package_side_only), config$package_side_only)
add_check("bridge_commit_recorded", nzchar(config$implementation_pin$bridge_commit %||% ""), config$implementation_pin$bridge_commit %||% "")
add_check("pilot_go_for_broad_spec", isTRUE(config$implementation_pin$pilot_go_for_broad_spec), config$implementation_pin$pilot_go_for_broad_spec)
add_check("response_likelihood_false", identical(config$scientific_contract$response_likelihood, FALSE), config$scientific_contract$response_likelihood)
add_check("response_predictive_draws_false", identical(config$scientific_contract$response_predictive_draws, FALSE), config$scientific_contract$response_predictive_draws)
add_check("recursive_response_sampling_false", identical(config$scientific_contract$recursive_response_sampling, FALSE), config$scientific_contract$recursive_response_sampling)
add_check("vb_uncertainty_uncalibrated", identical(config$scientific_contract$vb_uncertainty_calibrated, FALSE), config$scientific_contract$vb_uncertainty_calibrated)
add_check("coverage_levels_valid", all(config$scientific_contract$coverage_levels > 0 & config$scientific_contract$coverage_levels < 1), paste(config$scientific_contract$coverage_levels, collapse = ","))
add_check("learning_rates_positive", all(config$scientific_contract$learning_rates > 0), paste(config$scientific_contract$learning_rates, collapse = ","))
forbidden_hits <- recursive_name_hits(
  config$stages,
  config$scientific_contract$forbidden_argument_names %||% c("target_p", "p0"),
  path = "config$stages"
)
add_check("no_forbidden_target_argument_names_in_stages", length(forbidden_hits) == 0L, paste(forbidden_hits, collapse = ";"))
add_check("has_required_output_files", all(c("manifest.csv", "scenario_manifest.csv", "interval_metrics.csv", "failure_log.csv") %in% config$output_contract$required_files), paste(config$output_contract$required_files, collapse = ","))
add_check("has_stages", length(config$stages) >= 2L, length(config$stages))

backend_rows <- do.call(rbind, lapply(seq_along(config$stages), function(ii) {
  expand_backend_rows(config$stages[[ii]], stage_index = ii)
}))
dgp_rows <- flatten_dgps(config)
design_rows <- flatten_designs(config)
total_expected_rows <- sum(backend_rows$expected_rows)
mcmc_expected_rows <- sum(backend_rows$expected_rows[backend_rows$inference == "mcmc"])
vb_expected_rows <- sum(backend_rows$expected_rows[backend_rows$inference == "vb"])
baseline_expected_rows <- sum(backend_rows$expected_rows[backend_rows$inference == "baseline"])

add_check("expected_rows_positive", total_expected_rows > 0, total_expected_rows)
add_check("mcmc_rows_present", mcmc_expected_rows > 0, mcmc_expected_rows)
add_check("vb_sidecar_rows_present", vb_expected_rows > 0, vb_expected_rows)
add_check("baseline_rows_present", baseline_expected_rows > 0, baseline_expected_rows)
add_check("dynamic_desn_designs_present", any(design_rows$design_type == "teacher_forced_desn"), paste(unique(design_rows$design_type), collapse = ","))
add_check("fixed_designs_present", any(design_rows$design_type == "fixed_design"), paste(unique(design_rows$design_type), collapse = ","))

checks_df <- do.call(rbind, checks)
all_passed <- all(checks_df$passed)
if (!all_passed) {
  failed <- checks_df$check_id[!checks_df$passed]
  write_csv(checks_df, file.path(output_dir, "config_checks.csv"))
  config_error("Frozen broad config failed audit checks: ", paste(failed, collapse = ", "))
}

manifest_df <- data.frame(
  key = c(
    "artifact_kind",
    "config_id",
    "config_status",
    "repo_root",
    "config_path",
    "git_commit",
    "git_branch",
    "bridge_commit",
    "readiness_artifact",
    "pilot_artifact",
    "total_expected_rows",
    "mcmc_expected_rows",
    "vb_expected_rows",
    "baseline_expected_rows",
    "launch_authorized",
    "article_update_allowed",
    "created_at"
  ),
  value = c(
    "rqr_desn_broad_config_audit",
    config$config_id,
    config$status,
    repo_root,
    config_path,
    git_value(repo_root, "rev-parse", "HEAD"),
    git_value(repo_root, "branch", "--show-current"),
    config$implementation_pin$bridge_commit,
    config$implementation_pin$readiness_artifact,
    config$implementation_pin$pilot_artifact,
    as.character(total_expected_rows),
    as.character(mcmc_expected_rows),
    as.character(vb_expected_rows),
    as.character(baseline_expected_rows),
    as.character(config$launch_authorized),
    as.character(config$article_update_allowed),
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  ),
  stringsAsFactors = FALSE
)

write_csv(manifest_df, file.path(output_dir, "manifest.csv"))
write_csv(checks_df, file.path(output_dir, "config_checks.csv"))
write_csv(backend_rows, file.path(output_dir, "expected_workload_by_backend.csv"))
write_csv(dgp_rows, file.path(output_dir, "dgp_grid.csv"))
write_csv(design_rows, file.path(output_dir, "design_grid.csv"))

readme <- c(
  "# RQR-DESN Broad Config Audit",
  "",
  "This is a no-launch audit of the frozen RQR-DESN broad simulation config.",
  "It validates config structure, no-article/no-launch flags, model-contract",
  "guards, and expected workload counts. It does not fit models.",
  "",
  sprintf("Config id: `%s`", config$config_id),
  sprintf("Expected rows: %s", total_expected_rows),
  sprintf("MCMC rows: %s", mcmc_expected_rows),
  sprintf("VB sidecar rows: %s", vb_expected_rows)
)
writeLines(readme, file.path(output_dir, "README.md"))
writeLines(capture.output(str(config, max.level = 3)), file.path(output_dir, "config_structure.txt"))
writeLines(
  c(
    "$ git status --short --branch",
    git_value(repo_root, "status", "--short", "--branch"),
    "",
    "$ git log --oneline -5",
    git_value(repo_root, "log", "--oneline", "-5")
  ),
  file.path(output_dir, "git_state.txt")
)

artifact_files <- list.files(output_dir, full.names = TRUE)
artifact_files <- artifact_files[basename(artifact_files) != "output_hashes.csv"]
hash_df <- data.frame(
  file = basename(artifact_files),
  md5 = unname(tools::md5sum(artifact_files)),
  stringsAsFactors = FALSE
)
write_csv(hash_df, file.path(output_dir, "output_hashes.csv"))

message(sprintf(
  "Frozen RQR-DESN broad config audit passed: %s expected rows (%s MCMC, %s VB sidecar, %s baseline); output=%s",
  total_expected_rows,
  mcmc_expected_rows,
  vb_expected_rows,
  baseline_expected_rows,
  output_dir
))
