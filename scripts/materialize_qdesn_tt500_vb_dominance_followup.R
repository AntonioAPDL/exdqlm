#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
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
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}

stage <- match.arg(as.character(get_arg("--stage", "refinement"))[1L], c("refinement", "seed_stability", "replacement"))
stage_file <- switch(
  stage,
  refinement = "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement",
  seed_stability = "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability",
  replacement = "qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen"
)
default_profiles <- file.path("config", "validation", paste0(stage_file, "_profiles.csv"))
default_defaults <- file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))
default_grid <- file.path("config", "validation", paste0(stage_file, "_grid.csv"))

ranking_path <- resolve_path(get_arg("--ranking", ""), must_work = TRUE)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_profiles.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_defaults.yaml")),
  must_work = TRUE
)
profiles_out <- resolve_path(get_arg("--profiles-out", default_profiles), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", default_defaults), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", default_grid), must_work = FALSE)
top_n <- int_arg("--top-n", if (identical(stage, "replacement")) 1L else 12L)
workers <- int_arg("--workers", 20L)
seed_value <- get_arg("--seed", NULL)
seed_value <- if (is.null(seed_value)) NULL else suppressWarnings(as.integer(seed_value)[1L])
require_dominance_pass <- has_flag("--require-dominance-pass")
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

if (identical(stage, "replacement") && has_flag("--from-frozen-profile")) {
  frozen_path <- resolve_path(get_arg("--from-frozen-profile", ""), must_work = TRUE)
  profiles <- utils::read.csv(frozen_path, stringsAsFactors = FALSE, check.names = FALSE)
} else {
  profiles <- exdqlm:::qdesn_dynamic_fitforecast_profiles_from_ranking(
    ranking_path = ranking_path,
    source_profiles_path = source_profiles_path,
    top_n = top_n,
    screening_stage = switch(
      stage,
      refinement = "dominance_refinement",
      seed_stability = "dominance_seed_stability",
      replacement = "tt500_vb_replacement_frozen"
    ),
    screening_wave = paste0(stage, "_", format(Sys.Date(), "%Y_%m_%d")),
    profile_role = switch(
      stage,
      refinement = "refinement_top",
      seed_stability = "seed_stability_top",
      replacement = "frozen_global"
    ),
    seed = seed_value,
    require_dominance_pass = require_dominance_pass
  )
}

out <- exdqlm:::qdesn_dynamic_fitforecast_materialize_followup_stage(
  stage = stage,
  profiles = profiles,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized
)

cat(sprintf("stage: %s\n", out$stage))
cat(sprintf("profiles: %s\n", out$profiles_path))
cat(sprintf("defaults: %s\n", out$defaults_path))
cat(sprintf("grid: %s\n", out$grid_path))
cat(sprintf("n_profiles: %d\n", as.integer(out$n_profiles)))
cat(sprintf("n_grid_rows: %d\n", as.integer(out$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(out$expected_qdesn_roots)))
