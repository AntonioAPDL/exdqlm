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

stage <- match.arg(
  as.character(get_arg("--stage", "confirmation"))[1L],
  c("confirmation", "broad", "stability")
)
base_defaults <- get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml")
)
base_defaults_path <- exdqlm:::.qdesn_validation_resolve_path(base_defaults, must_work = TRUE)
stage_stub <- switch(
  stage,
  confirmation = "qdesn_dynamic_fitforecast_v2_tt500_vb_confirm",
  broad = "qdesn_dynamic_fitforecast_v2_tt500_vb_broad",
  stability = "qdesn_dynamic_fitforecast_v2_tt500_vb_stability"
)
profiles_rel <- get_arg(
  "--profiles-out",
  file.path("config", "validation", paste0(stage_stub, "_profiles.csv"))
)
defaults_rel <- get_arg(
  "--defaults-out",
  file.path("config", "validation", paste0(stage_stub, "_defaults.yaml"))
)
grid_rel <- get_arg(
  "--grid-out",
  file.path("config", "validation", paste0(stage_stub, "_grid.csv"))
)
profiles_path <- exdqlm:::.qdesn_validation_resolve_path(profiles_rel, must_work = FALSE)
defaults_path <- exdqlm:::.qdesn_validation_resolve_path(defaults_rel, must_work = FALSE)
grid_path <- exdqlm:::.qdesn_validation_resolve_path(grid_rel, must_work = FALSE)
wave <- as.character(get_arg("--wave", paste0(stage, "_2026_06_25")))[1L]

profiles <- switch(
  stage,
  confirmation = exdqlm:::qdesn_dynamic_fitforecast_confirmation_profiles(screening_wave = wave),
  broad = exdqlm:::qdesn_dynamic_fitforecast_broad_profiles(screening_wave = wave),
  stability = {
    ranking_path <- get_arg("--ranking", "")
    if (!nzchar(trimws(ranking_path))) {
      stop("--ranking is required for --stage stability.", call. = FALSE)
    }
    top_n <- suppressWarnings(as.integer(get_arg("--top-n", "5"))[1L])
    if (!is.finite(top_n) || top_n < 1L) top_n <- 5L
    seed <- suppressWarnings(as.integer(get_arg("--seed", "456"))[1L])
    if (!is.finite(seed)) seed <- 456L
    exdqlm:::qdesn_dynamic_fitforecast_top_profiles_from_ranking(
      ranking_path = ranking_path,
      top_n = top_n,
      screening_wave = wave,
      seed = seed
    )
  }
)

defaults <- yaml::read_yaml(base_defaults_path)
defaults$campaign <- defaults$campaign %||% list()
defaults$campaign$name <- stage_stub
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_stub)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub)
defaults$study_contract <- defaults$study_contract %||% list()
defaults$study_contract$id <- paste0(stage_stub, "_2026_06_25")
defaults$study_contract$description <- switch(
  stage,
  confirmation = paste(
    "All-quantile TT500 Q-DESN VB confirmation lane for the top ten",
    "median-scout candidates and family guards. This screen is tuning evidence only and is not",
    "an article-facing final table."
  ),
  broad = paste(
    "Adaptive broad TT500 Q-DESN VB screen over compact reservoirs with fixed",
    "RHS-NS tau0. This screen explores nearby DESN dynamics after the median",
    "scout showed compact reservoirs dominate."
  ),
  stability = paste(
    "Seed-stability TT500 Q-DESN VB check for top ranked profiles from a",
    "completed screen. This lane guards against picking a lucky reservoir seed."
  )
)
defaults$screening_profiles <- defaults$screening_profiles %||% list()
defaults$screening_profiles$enabled <- TRUE
defaults$screening_profiles$csv <- profiles_rel
defaults$screening_profiles$priors <- "rhs_ns"
defaults$screening_profiles$design <- switch(
  stage,
  confirmation = "Top ten median-scout candidates and family guards, all families, all validation quantiles, fixed RHS-NS tau0 = 1e-4.",
  broad = "Fifty-five compact profiles: D in {1,2,3}, per-layer n <= 70, alpha/rho ladder {(0.05,0.60),(0.10,0.70),(0.20,0.80),(0.30,0.85),(0.50,0.95)}, fixed RHS-NS tau0 = 1e-4.",
  stability = "Top ranked profiles rematerialized with an alternate reservoir seed."
)
defaults$reference_contract <- defaults$reference_contract %||% list()
defaults$source_materialization <- defaults$source_materialization %||% list()
if (identical(stage, "broad")) {
  defaults$reference_contract$taus <- c(0.05, 0.50)
  defaults$source_materialization$taus <- c(0.05, 0.50)
} else {
  defaults$reference_contract$taus <- c(0.05, 0.25, 0.50)
  defaults$source_materialization$taus <- c(0.05, 0.25, 0.50)
}
families <- as.character(defaults$reference_contract$families %||% c("gausmix", "laplace", "normal"))
taus <- as.numeric(defaults$reference_contract$taus)
defaults$reference_contract$expected_unique_dataset_cells <- length(families) * length(taus)
defaults$reference_contract$expected_qdesn_roots <- length(families) * length(taus) * nrow(profiles)
defaults$runtime <- defaults$runtime %||% list()
defaults$runtime$campaign_workers <- 20L
defaults$runtime$workers <- 20L
defaults$runtime$root_scheduler <- "load_balanced"

dir.create(dirname(profiles_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(profiles, profiles_path, row.names = FALSE)
dir.create(dirname(defaults_path), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(defaults, defaults_path)

if (has_flag("--refresh-grid")) {
  loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
    defaults = loaded,
    refresh_materialized = has_flag("--refresh-materialized"),
    verbose = !has_flag("--quiet")
  )
  dir.create(dirname(grid_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(grid, grid_path, row.names = FALSE)
  cat(sprintf("grid: %s\n", grid_path))
  cat(sprintf("grid_rows: %d\n", nrow(grid)))
}

cat(sprintf("stage: %s\n", stage))
cat(sprintf("profiles: %s\n", profiles_path))
cat(sprintf("profiles_rows: %d\n", nrow(profiles)))
cat(sprintf("defaults: %s\n", defaults_path))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(defaults$reference_contract$expected_qdesn_roots)))
