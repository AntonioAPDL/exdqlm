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
    help = "Optional dataset slug to look up in the model-selection dataset registry (e.g. 'dlm_constV_bigW')."
  ),
  optparse::make_option(
    "--datasets_yaml",
    type = "character",
    default = NULL,
    help = "Optional path to datasets registry YAML (default: <repo_root>/config/model_selection/datasets.yaml).",
    metavar = "FILE"
  ),
  optparse::make_option(
    "--defaults_config",
    type = "character",
    default = NULL,
    help = "Optional v2 defaults YAML (default: <repo_root>/config/model_selection/defaults.yaml).",
    metavar = "FILE"
  ),
  optparse::make_option(
    "--engine",
    type = "character",
    default = "auto",
    help = "Model-selection engine: auto, v2, or legacy (default: auto)."
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

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

deep_merge <- function(a, b) {
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)
  if (is.list(a) && is.list(b)) {
    na <- names(a)
    nb <- names(b)
    if (is.null(na) || is.null(nb) || !length(na) || !length(nb)) return(b)
    keys <- unique(c(na, nb))
    out <- lapply(keys, function(k) deep_merge(a[[k]], b[[k]]))
    names(out) <- keys
    out
  } else {
    b
  }
}

repo_file <- function(path, base = repo_root) {
  if (is.null(path)) return(NULL)
  path <- as.character(path)
  if (grepl("^/", path)) path else file.path(base, path)
}

detect_engine <- function(engine, cfg) {
  engine <- tolower(as.character(engine %||% "auto")[1L])
  if (!engine %in% c("auto", "v2", "legacy")) {
    stop("--engine must be one of auto, v2, legacy.")
  }
  if (engine != "auto") return(engine)
  ms <- cfg$model_selection %||% list()
  if (!is.null(ms$stages)) return("v2")
  if (!is.null(ms$esn_space)) return("legacy")
  stop("Could not infer model-selection engine from model_selection block.")
}

read_dataset_registry <- function(path) {
  path <- repo_file(path)
  if (!file.exists(path)) stop("datasets.yaml not found at: ", path)
  reg <- yaml::read_yaml(path)
  if (!is.null(reg$datasets_source)) {
    source_path <- repo_file(reg$datasets_source, base = dirname(path))
    if (!file.exists(source_path)) stop("datasets_source not found at: ", source_path)
    reg <- yaml::read_yaml(source_path)
  }
  if (!"datasets" %in% names(reg)) {
    stop("datasets registry must contain a top-level 'datasets' field.")
  }
  reg
}

resolve_dataset <- function(dataset_slug, datasets_yaml, fallback_mode = "sim") {
  if (is.null(dataset_slug)) return(NULL)
  reg <- read_dataset_registry(datasets_yaml)
  idx <- vapply(
    reg$datasets,
    function(d) identical(d$slug, dataset_slug),
    logical(1L)
  )
  if (!any(idx)) {
    stop("No entry with slug='", dataset_slug, "' found in ", repo_file(datasets_yaml))
  }
  entry <- reg$datasets[[which(idx)[1]]]
  if (is.null(entry$input_path)) {
    stop("Entry for slug='", dataset_slug, "' must have an 'input_path' field.")
  }
  entry$input_path <- repo_file(entry$input_path)
  entry$mode <- entry$mode %||% fallback_mode
  entry
}

build_v2_cfg <- function(spec_cfg, defaults_config) {
  defaults_path <- repo_file(defaults_config %||% file.path("config", "model_selection", "defaults.yaml"))
  if (!file.exists(defaults_path)) stop("v2 defaults config not found at: ", defaults_path)
  defaults <- yaml::read_yaml(defaults_path)

  base_source <- defaults$base_cfg_source %||% file.path("config", "defaults.yaml")
  base_path <- repo_file(base_source)
  if (!file.exists(base_path)) stop("base_cfg_source not found at: ", base_path)

  cfg <- yaml::read_yaml(base_path)
  cfg <- deep_merge(cfg, defaults$base_cfg_overrides %||% list())
  cfg <- deep_merge(cfg, list(model_selection = defaults$model_selection %||% list()))

  spec_direct <- spec_cfg
  spec_direct$base_cfg_overrides <- NULL
  cfg <- deep_merge(cfg, spec_cfg$base_cfg_overrides %||% list())
  cfg <- deep_merge(cfg, spec_direct)
  exdqlm:::ms_fix_cfg_keys(cfg)
}

# Load full spec YAML
cfg_all <- yaml::read_yaml(opt$config)
if (!"model_selection" %in% names(cfg_all)) {
  stop("Spec YAML must contain a top-level 'model_selection' block.")
}
engine <- detect_engine(opt$engine, cfg_all)

# base_cfg = everything except model_selection
base_cfg <- cfg_all
base_cfg$model_selection <- NULL

ms_cfg <- list(model_selection = cfg_all$model_selection)

# ------------------------------------------------------------------
# Resolve dataset: either from slug via datasets.yaml, or direct file_long
# ------------------------------------------------------------------
dataset_id <- opt$dataset_id
file_long  <- opt$file_long
dataset_entry <- NULL

if (!is.null(opt$dataset_slug)) {
  datasets_yaml <- opt$datasets_yaml %||% file.path("config", "model_selection", "datasets.yaml")
  dataset_entry <- resolve_dataset(
    opt$dataset_slug,
    datasets_yaml = datasets_yaml,
    fallback_mode = cfg_all$pipeline$mode %||% "sim"
  )
  file_long  <- dataset_entry$input_path
  dataset_id <- opt$dataset_slug

  if (!is.null(dataset_entry$overrides) && length(dataset_entry$overrides)) {
    message("[qdesn_model_selection_main] dataset 'overrides' is deprecated and will be ignored.")
  }

  message("[qdesn_model_selection_main] Using dataset slug: ", opt$dataset_slug)
  message("  file_long: ", file_long)
}

if (is.null(file_long)) {
  stop("Internal error: file_long is NULL after resolving dataset.")
}

if (engine == "v2") {
  cfg_v2 <- build_v2_cfg(cfg_all, opt$defaults_config)
  if (is.null(dataset_entry)) {
    dataset_entry <- list(
      slug = dataset_id,
      mode = cfg_v2$pipeline$mode %||% "sim",
      input_path = repo_file(file_long)
    )
  }
  run_name <- cfg_v2$model_selection$tune_name %||% dataset_id
  out_ms_root <- file.path(opt$out_root, "model_selection", run_name)
  res <- qdesn_model_selection(
    dataset_id = dataset_id,
    cfg        = cfg_v2,
    ds         = dataset_entry,
    run_dir    = out_ms_root,
    engine     = "v2",
    verbose    = TRUE
  )
  dir.create(out_ms_root, recursive = TRUE, showWarnings = FALSE)
  saveRDS(res, file = file.path(out_ms_root, "model_selection_result.rds"))
} else {
  res <- qdesn_model_selection(
    dataset_id = dataset_id,
    file_long  = file_long,
    file_obs   = opt$file_obs,
    base_cfg   = base_cfg,
    ms_cfg     = ms_cfg,
    out_root   = opt$out_root,
    repo_root  = repo_root,
    verbose    = TRUE,
    engine     = "legacy"
  )

  # Save an RDS summary for convenience
  out_ms_root <- file.path(opt$out_root, "model_selection", res$tune_name)
  dir.create(out_ms_root, recursive = TRUE, showWarnings = FALSE)
  saveRDS(res, file = file.path(out_ms_root, "model_selection_result.rds"))
}
