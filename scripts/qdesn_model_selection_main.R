#!/usr/bin/env Rscript
# scripts/qdesn_model_selection_main.R
# Command-line entry point for ESN model selection.

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(purrr)
  library(future)
  library(future.apply)
  library(tibble)
  library(exdqlm)
})

option_list <- list(
  optparse::make_option(
    c("-c", "--config"),
    type = "character",
    help = "Path to spec YAML file (must contain model_selection block).",
    metavar = "FILE"
  ),
  optparse::make_option(
    "--file_long",
    type = "character",
    default = NULL,
    help = "Path to long-format data file used by ESN pipeline (override slug-based lookup).",
    metavar = "FILE"
  ),
  optparse::make_option(
    "--file_obs",
    type = "character",
    default = NULL,
    help = "Optional observed-data file for real-data mode.",
    metavar = "FILE"
  ),
  optparse::make_option(
    "--out_root",
    type = "character",
    help = "Root directory for model-selection outputs.",
    metavar = "DIR"
  ),
  optparse::make_option(
    "--dataset_id",
    type = "character",
    default = "dataset",
    help = "Dataset identifier used for logging (default: 'dataset')."
  ),
  optparse::make_option(
    "--dataset_slug",
    type = "character",
    default = NULL,
    help = "Optional dataset slug to look up in config/datasets.yaml (e.g. 'dlm_constV_bigW')."
  ),
  optparse::make_option(
    "--datasets_yaml",
    type = "character",
    default = NULL,
    help = "Optional path to datasets registry YAML (default: <repo_root>/config/datasets.yaml).",
    metavar = "FILE"
  )
)

opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

# Basic argument check: need config + out_root + (file_long or dataset_slug)
if (is.null(opt$config) || is.null(opt$out_root) ||
    (is.null(opt$file_long) && is.null(opt$dataset_slug))) {
  optparse::print_help(opt_parser)
  stop("You must provide --config, --out_root, and either --file_long or --dataset_slug.")
}

# Detect repo root early (used for default datasets.yaml)
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) normalizePath(".", mustWork = TRUE)
)

# Load full spec YAML
cfg_all <- yaml::read_yaml(opt$config)
if (!"model_selection" %in% names(cfg_all)) {
  stop("Spec YAML must contain a top-level 'model_selection' block.")
}

# base_cfg = everything except model_selection
base_cfg <- cfg_all
base_cfg$model_selection <- NULL

ms_cfg <- list(model_selection = cfg_all$model_selection)

# ------------------------------------------------------------------
# Resolve dataset: either from slug via datasets.yaml, or direct file_long
# ------------------------------------------------------------------
dataset_id <- opt$dataset_id
file_long  <- opt$file_long

if (!is.null(opt$dataset_slug)) {
  # Find datasets.yaml
  datasets_yaml <- opt$datasets_yaml
  if (is.null(datasets_yaml)) {
    datasets_yaml <- file.path(repo_root, "config", "datasets.yaml")
  }
  if (!file.exists(datasets_yaml)) {
    stop("datasets.yaml not found at: ", datasets_yaml)
  }

  ds_cfg <- yaml::read_yaml(datasets_yaml)
  if (!"datasets" %in% names(ds_cfg)) {
    stop("datasets.yaml must contain a top-level 'datasets' field.")
  }

  idx <- vapply(
    ds_cfg$datasets,
    function(d) identical(d$slug, opt$dataset_slug),
    logical(1L)
  )
  if (!any(idx)) {
    stop("No entry with slug='", opt$dataset_slug, "' found in ", datasets_yaml)
  }
  entry <- ds_cfg$datasets[[which(idx)[1]]]

  if (is.null(entry$input_path)) {
    stop("Entry for slug='", opt$dataset_slug, "' must have an 'input_path' field.")
  }

  file_long  <- entry$input_path
  dataset_id <- opt$dataset_slug

  # Apply dataset-specific overrides onto base_cfg, if provided
  if (!is.null(entry$overrides) && length(entry$overrides)) {
    base_cfg <- utils::modifyList(base_cfg, entry$overrides)
  }

  message("[qdesn_model_selection_main] Using dataset slug: ", opt$dataset_slug)
  message("  file_long: ", file_long)
}

if (is.null(file_long)) {
  stop("Internal error: file_long is NULL after resolving dataset.")
}

res <- qdesn_model_selection(
  dataset_id = dataset_id,
  file_long  = file_long,
  file_obs   = opt$file_obs,
  base_cfg   = base_cfg,
  ms_cfg     = ms_cfg,
  out_root   = opt$out_root,
  repo_root  = repo_root,
  verbose    = TRUE
)

# Save an RDS summary for convenience
out_ms_root <- file.path(opt$out_root, "model_selection", res$tune_name)
dir.create(out_ms_root, recursive = TRUE, showWarnings = FALSE)
saveRDS(res, file = file.path(out_ms_root, "model_selection_result.rds"))
