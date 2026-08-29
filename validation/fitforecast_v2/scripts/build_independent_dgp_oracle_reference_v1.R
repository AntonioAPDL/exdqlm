#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/build_independent_dgp_oracle_reference_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
source_root <- args$`source-root` %||% idor_v1_default_source_root()
output_root <- args$`output-root` %||% file.path(
  repo_root,
  "validation",
  "fitforecast_v2",
  "promotions",
  "independent_dgp_oracle_reference_v1_20260828"
)
output_root <- normalizePath(output_root, winslash = "/", mustWork = FALSE)
ffv2_ensure_dir(output_root)
ffv2_ensure_dir(file.path(output_root, "article_assets"))

result <- idor_v1_build(source_root)
if (!all(result$checks$pass)) {
  stop(sprintf(
    "Oracle-reference checks failed: %s",
    paste(result$checks$check_id[!result$checks$pass], collapse = ", ")
  ), call. = FALSE)
}

paths <- c(
  source_registry = file.path(output_root, "source_registry.csv"),
  reference_ledger = file.path(output_root, "oracle_reference_ledger.csv"),
  check_loss_audit = file.path(output_root, "oracle_check_loss_audit.csv"),
  forecast_grid = file.path(output_root, "forecast_grid.csv"),
  checks = file.path(output_root, "checks.csv"),
  article_asset = file.path(
    output_root,
    "article_assets",
    "qdesn_validation_500obs_dgp_oracle_reference_v1.csv"
  )
)
ffv2_write_csv(result$source_registry, paths[["source_registry"]])
ffv2_write_csv(result$reference_ledger, paths[["reference_ledger"]])
ffv2_write_csv(
  result$source_registry[c(
    "family", "tau", "raw_quantile_shift", "cdf_at_raw_quantile",
    "expected_oracle_check_loss", "numerical_oracle_check_loss",
    "analytic_numerical_abs_error", "realized_oracle_check_loss",
    "realized_minus_expected", "source_series_sha256"
  )],
  paths[["check_loss_audit"]]
)
ffv2_write_csv(result$forecast_grid, paths[["forecast_grid"]])
ffv2_write_csv(result$checks, paths[["checks"]])
ffv2_write_csv(
  result$reference_ledger[c(
    "family", "tau", "metric_role", "metric_name", "plot_reference_type",
    "plot_reference_value", "expected_reference_value",
    "realized_reference_value", "formula", "source_series_sha256",
    "forecast_origins", "forecast_pairs"
  )],
  paths[["article_asset"]]
)

source_head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
code_paths <- c(
  module = file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_dgp_oracle_reference_v1.R"
  ),
  builder = file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "build_independent_dgp_oracle_reference_v1.R"
  ),
  verifier = file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "verify_independent_dgp_oracle_reference_v1.R"
  )
)
if (!all(file.exists(code_paths))) {
  stop("Oracle-reference code surface is incomplete.", call. = FALSE)
}
manifest_path <- file.path(output_root, "manifest.json")
manifest <- list(
  schema_version = idor_v1_schema,
  recorded_date = "2026-08-28",
  scientific_lane = "IND QDESN VAL",
  scenario_id = idor_v1_scenario,
  source_git_head = source_head,
  source_root = paste0(
    "external-workspace://shared_dynamic_fit_forecast_validation/sources/",
    idor_v1_scenario
  ),
  protocol = list(
    train_indices = c(8501L, 9000L),
    forecast_indices = c(9001L, 10000L),
    maximum_lead = 30L,
    origin_stride = 30L,
    forecast_origins = 34L,
    forecast_pairs = 1000L
  ),
  oracle_policy = list(
    fit_rmse = "exact zero at the true conditional-quantile path",
    forecast_mae = "exact zero at the true conditional-quantile path",
    forecast_check = "population expected check loss at the true conditional quantile",
    realized_check = "retained as a same-sample diagnostic, not the plotted population reference"
  ),
  model_refits_required = FALSE,
  article_metric_values_changed = FALSE,
  checks_passed = sum(result$checks$pass),
  checks_total = nrow(result$checks),
  code_paths = as.list(vapply(code_paths, imi_v1_relpath, character(1L), repo_root = repo_root)),
  code_sha256 = as.list(vapply(code_paths, ffv2_file_sha256, character(1L))),
  artifact_paths = as.list(vapply(paths, imi_v1_relpath, character(1L), repo_root = repo_root)),
  artifact_sha256 = as.list(vapply(paths, ffv2_file_sha256, character(1L)))
)
ffv2_write_json(manifest, manifest_path)

artifact_paths <- c(paths, manifest = manifest_path)
artifact_manifest <- data.frame(
  artifact_id = names(artifact_paths),
  path = vapply(artifact_paths, imi_v1_relpath, character(1L), repo_root = repo_root),
  sha256 = vapply(artifact_paths, ffv2_file_sha256, character(1L)),
  bytes = as.numeric(file.info(artifact_paths)$size),
  stringsAsFactors = FALSE
)
ffv2_write_csv(artifact_manifest, file.path(output_root, "artifact_manifest.csv"))

cat(sprintf("Oracle reference: %d/%d checks passed\n", sum(result$checks$pass), nrow(result$checks)))
cat(sprintf("Output root: %s\n", output_root))
cat(sprintf("Expected check-loss range: %.6f to %.6f\n",
            min(result$source_registry$expected_oracle_check_loss),
            max(result$source_registry$expected_oracle_check_loss)))
