#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

manifest_path <- resolve_path(
  get_arg(
    "--manifest",
    file.path(
      "config",
      "validation",
      "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_manifest.yaml"
    )
  ),
  must_work = TRUE
)
manifest <- exdqlm:::qdesn_dynamic_crossstudy_rowfaithful_load_manifest(manifest_path, repo_root = repo_root)
manifest$meta <- modifyList(manifest$meta %||% list(), list(manifest_path = manifest_path))

resolved <- exdqlm:::qdesn_dynamic_crossstudy_rowfaithful_resolve(manifest, repo_root = repo_root)

defaults_out_path <- resolve_path(
  get_arg("--defaults-out", (manifest$resolved_outputs %||% list())$defaults_path %||% file.path(
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_defaults.yaml"
  )),
  must_work = FALSE
)
inventory_out_path <- resolve_path(
  get_arg("--inventory-out", (manifest$resolved_outputs %||% list())$inventory_path %||% file.path(
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_inventory.csv"
  )),
  must_work = FALSE
)
summary_out_path <- resolve_path(
  get_arg("--summary-out", (manifest$resolved_outputs %||% list())$summary_path %||% file.path(
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_materialization_summary.md"
  )),
  must_work = FALSE
)
canary_grid_out_path <- resolve_path(
  get_arg("--canary-grid-out", (manifest$resolved_outputs %||% list())$canary_grid_path %||% file.path(
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_canary_grid.csv"
  )),
  must_work = FALSE
)

exdqlm:::qdesn_dynamic_crossstudy_rowfaithful_write_materialized(
  resolved = resolved,
  defaults_out_path = defaults_out_path,
  inventory_out_path = inventory_out_path,
  summary_out_path = if (isTRUE(has_flag("--no-summary"))) NULL else summary_out_path,
  canary_grid_out_path = if (isTRUE(has_flag("--no-canary-grid"))) NULL else canary_grid_out_path
)

cat(sprintf("Manifest: %s\n", manifest_path))
cat(sprintf("Defaults: %s\n", defaults_out_path))
cat(sprintf("Inventory: %s\n", inventory_out_path))
if (!isTRUE(has_flag("--no-summary"))) cat(sprintf("Summary: %s\n", summary_out_path))
if (!isTRUE(has_flag("--no-canary-grid"))) cat(sprintf("Canary grid: %s\n", canary_grid_out_path))
