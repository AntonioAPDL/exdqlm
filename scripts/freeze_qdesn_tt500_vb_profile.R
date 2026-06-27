#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
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

ranking_path <- resolve_path(get_arg("--ranking", ""), must_work = TRUE)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_profiles.csv")),
  must_work = TRUE
)
out_profile_path <- resolve_path(
  get_arg("--out-profile", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen_profiles.csv")),
  must_work = FALSE
)
out_manifest_path <- resolve_path(
  get_arg("--out-manifest", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen_profile_manifest.json")),
  must_work = FALSE
)
max_p_over_n <- suppressWarnings(as.numeric(get_arg("--max-p-over-n", "0.50"))[1L])
if (!is.finite(max_p_over_n)) max_p_over_n <- 0.50

out <- exdqlm:::qdesn_dynamic_fitforecast_freeze_profile(
  ranking_path = ranking_path,
  source_profiles_path = source_profiles_path,
  out_profile_path = out_profile_path,
  out_manifest_path = out_manifest_path,
  allow_best_available = !has_flag("--require-dominance-pass"),
  max_p_over_n = max_p_over_n
)

cat(sprintf("selected_profile_id: %s\n", out$manifest$selected_profile_id))
cat(sprintf("dominance_pass: %s\n", as.character(out$manifest$dominance_pass)))
cat(sprintf("profile: %s\n", out_profile_path))
cat(sprintf("manifest: %s\n", out_manifest_path))
