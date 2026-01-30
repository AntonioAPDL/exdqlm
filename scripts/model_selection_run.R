#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  req <- c("yaml","jsonlite","digest","fs","tools","withr","readr","dplyr","tibble")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

# Resolve repo root
args_all   <- commandArgs(trailingOnly = FALSE)
script_idx <- grep("^--file=", args_all)
script_file <- if (length(script_idx)) sub("^--file=", "", args_all[script_idx]) else ""
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) {
    if (length(script_file) && nzchar(script_file)) {
      normalizePath(dirname(script_file), mustWork = FALSE)
    } else {
      normalizePath(".", mustWork = FALSE)
    }
  }
)
setwd(repo_root)

devtools::load_all(repo_root)

# CLI args
args <- commandArgs(trailingOnly = TRUE)
get_arg  <- function(flag, default=NULL) { i <- which(args == flag); if (length(i) && i < length(args)) args[i+1] else default }
has_flag <- function(flag) any(args == flag)
slug      <- get_arg("--slug")
spec_name <- get_arg("--spec")
out_dir   <- get_arg("--out_dir")
overwrite <- has_flag("--overwrite")
dry_run   <- has_flag("--dry_run") || has_flag("--dry-run")
stopifnot(nzchar(slug), nzchar(spec_name))

# Load defaults + spec
ms_defaults <- ms_read_yaml("config/model_selection/defaults.yaml")
ms_spec_path <- file.path("config/model_selection/specs", paste0(spec_name, ".yaml"))
if (!file.exists(ms_spec_path)) stop("Spec file not found: ", ms_spec_path)
ms_spec <- ms_read_yaml(ms_spec_path)

cfg_ms <- ms_deep_merge(ms_defaults, ms_spec)

# Base cfg
base_cfg_source <- cfg_ms$base_cfg_source %||% "config/defaults.yaml"
base_cfg <- ms_read_yaml(base_cfg_source)
base_cfg <- ms_fix_cfg_keys(base_cfg)
base_cfg <- ms_deep_merge(base_cfg, cfg_ms$base_cfg_overrides %||% list())

# Dataset registry
datasets_file <- cfg_ms$datasets_file %||% "config/datasets.yaml"
if (!file.exists(datasets_file)) stop("Datasets file not found: ", datasets_file)

datasets_yaml <- ms_read_yaml(datasets_file)
if (!is.null(datasets_yaml$datasets_source)) {
  src_path <- file.path(dirname(datasets_file), datasets_yaml$datasets_source)
  datasets_yaml <- ms_read_yaml(src_path)
}

if (is.null(datasets_yaml$datasets)) stop("datasets list not found in datasets file")

ds <- NULL
for (d in datasets_yaml$datasets) if (identical(d$slug, slug)) { ds <- d; break }
if (is.null(ds)) stop("Dataset slug not found: ", slug)

mode_ds <- tolower(ds$mode %||% base_cfg$pipeline$mode %||% "sim")

# Merge dataset config into base cfg
input_path <- ds$input_path
if (is.null(input_path) || !file.exists(input_path)) stop("Input file not found: ", input_path)

# Remove meta keys before merge
clean_ds <- ds
clean_ds$slug <- NULL
clean_ds$input_path <- NULL
clean_ds$mode <- NULL

cfg <- ms_deep_merge(base_cfg, clean_ds)

# Ensure cfg keys normalized
cfg <- ms_fix_cfg_keys(cfg)

# Enforce mode + origin
cfg$pipeline$mode <- mode_ds
cfg$forecast$mode <- cfg_ms$model_selection$forecast_mode %||% "origin"

# Attach model_selection block
cfg$model_selection <- cfg_ms$model_selection %||% list()

# Run directory
if (is.null(out_dir) || !nzchar(out_dir)) {
  results_root <- cfg_ms$results_root %||% "results"
  results_subdir <- cfg_ms$results_subdir %||% "model_selection"
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(...) "nogit")
  run_id <- sprintf("%s__git-%s__spec-%s", stamp, sha, spec_name)
  out_dir <- file.path(results_root, results_subdir, mode_ds, slug, "runs", run_id)
}

if (file.exists(out_dir) && !overwrite) stop("Output directory exists: ", out_dir)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

dir.create(file.path(out_dir, "logs"), recursive = TRUE, showWarnings = FALSE)

dir.create(file.path(out_dir, "manifest"), recursive = TRUE, showWarnings = FALSE)

dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)

cfg_effective_path <- file.path(out_dir, "manifest", "cfg_effective.yaml")
ms_write_yaml(cfg, cfg_effective_path)

manifest <- list(
  run_id = basename(out_dir),
  slug = slug,
  mode = mode_ds,
  spec = spec_name,
  input_path = input_path,
  created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
)
writeLines(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
           file.path(out_dir, "manifest", "run_manifest.json"))

if (isTRUE(dry_run)) {
  cat("DRY RUN: config written to", cfg_effective_path, "\n")
  quit(status = 0)
}

# Attach dataset path to cfg for downstream
cfg$input_path <- input_path

# Run model selection v2
res <- run_model_selection_v2(cfg, ds, out_dir)

cat("Model selection v2 finished. Output dir:", out_dir, "\n")
