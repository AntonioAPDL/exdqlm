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
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml")),
  must_work = TRUE
)
output_path <- resolve_path(
  get_arg("--output", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv")),
  must_work = FALSE
)
defaults <- exdqlm:::qdesn_static_crossstudy_load_defaults(defaults_path)
grid_df <- exdqlm:::qdesn_static_crossstudy_build_grid_from_reference(defaults)
validation <- exdqlm:::qdesn_static_crossstudy_validate_grid(grid_df, defaults)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(grid_df, output_path, row.names = FALSE)
cat(sprintf("Wrote grid: %s\n", output_path))
cat(sprintf("Rows: %d\n", nrow(grid_df)))
cat(sprintf("Unique dataset cells: %d\n", validation$unique_dataset_cells))
