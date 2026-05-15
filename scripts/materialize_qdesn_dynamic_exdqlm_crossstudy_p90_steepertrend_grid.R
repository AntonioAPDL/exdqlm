#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

defaults_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml"
)
full_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_full_grid.csv"
)
smoke_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_smoke_grid.csv"
)
ridge_full_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_ridge_full_grid.csv"
)
rhsns_full_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_full_grid.csv"
)
mcmc_ridge_tt500_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt500_grid.csv"
)
mcmc_ridge_tt5000_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt5000_grid.csv"
)
mcmc_rhsns_tt500_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt500_grid.csv"
)
mcmc_rhsns_tt5000_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt5000_grid.csv"
)

defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
full_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults = defaults,
  refresh_materialized = TRUE,
  verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(full_grid, defaults)

write_grid <- function(df, path, allow_subset = FALSE) {
  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(df, defaults, allow_subset = allow_subset)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
  invisible(validation)
}

pick_rows <- function(df, specs) {
  rows <- lapply(specs, function(spec) {
    hit <- subset(
      df,
      source_family == spec$family &
        abs(tau - spec$tau) < 1e-8 &
        fit_size == spec$fit_size &
        beta_prior_type == spec$beta_prior
    )
    if (!nrow(hit)) {
      stop(sprintf(
        "Failed to locate smoke row for family=%s tau=%.2f fit_size=%d prior=%s",
        spec$family, spec$tau, spec$fit_size, spec$beta_prior
      ), call. = FALSE)
    }
    hit[1L, , drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

ridge_full <- subset(full_grid, beta_prior_type == "ridge")
rhsns_full <- subset(full_grid, beta_prior_type == "rhs_ns")
mcmc_ridge_tt500 <- subset(ridge_full, fit_size == 500L)
mcmc_ridge_tt5000 <- subset(ridge_full, fit_size == 5000L)
mcmc_rhsns_tt500 <- subset(rhsns_full, fit_size == 500L)
mcmc_rhsns_tt5000 <- subset(rhsns_full, fit_size == 5000L)

smoke_specs <- list(
  list(family = "gausmix", tau = 0.25, fit_size = 500L, beta_prior = "ridge"),
  list(family = "gausmix", tau = 0.50, fit_size = 5000L, beta_prior = "ridge"),
  list(family = "laplace", tau = 0.50, fit_size = 500L, beta_prior = "ridge"),
  list(family = "laplace", tau = 0.05, fit_size = 5000L, beta_prior = "ridge"),
  list(family = "normal", tau = 0.05, fit_size = 500L, beta_prior = "ridge"),
  list(family = "normal", tau = 0.25, fit_size = 5000L, beta_prior = "ridge")
)
smoke_grid <- pick_rows(full_grid, smoke_specs)

write_grid(full_grid, full_grid_path, allow_subset = FALSE)
write_grid(smoke_grid, smoke_grid_path, allow_subset = TRUE)
write_grid(ridge_full, ridge_full_grid_path, allow_subset = TRUE)
write_grid(rhsns_full, rhsns_full_grid_path, allow_subset = TRUE)
write_grid(mcmc_ridge_tt500, mcmc_ridge_tt500_grid_path, allow_subset = TRUE)
write_grid(mcmc_ridge_tt5000, mcmc_ridge_tt5000_grid_path, allow_subset = TRUE)
write_grid(mcmc_rhsns_tt500, mcmc_rhsns_tt500_grid_path, allow_subset = TRUE)
write_grid(mcmc_rhsns_tt5000, mcmc_rhsns_tt5000_grid_path, allow_subset = TRUE)

cat(sprintf("Wrote full grid: %s\n", normalizePath(full_grid_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("Rows: %d\n", nrow(full_grid)))
cat(sprintf("Smoke rows: %d\n", nrow(smoke_grid)))
cat(sprintf("Ridge rows: %d\n", nrow(ridge_full)))
cat(sprintf("RHS-NS rows: %d\n", nrow(rhsns_full)))
