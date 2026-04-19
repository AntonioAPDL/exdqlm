#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

phase <- match.arg(
  as.character(get_arg("--phase", "full"))[1L],
  c(
    "smoke",
    "vb",
    "mcmc_ridge",
    "mcmc_rhsns_tt500",
    "mcmc_rhsns_tt5000",
    "failed_mcmc_al",
    "failed_mcmc_exal",
    "failed_mcmc_al_sfreeze",
    "failed_mcmc_exal_sfreeze",
    "failed_mcmc_al_thetafreeze",
    "failed_mcmc_exal_thetafreeze",
    "remaining_failed_mcmc_al_v2_canary",
    "remaining_failed_mcmc_exal_v2_canary",
    "remaining_failed_mcmc_al_v2_residual",
    "remaining_failed_mcmc_exal_v2_residual",
    "remaining_failed_mcmc_al_v2",
    "remaining_failed_mcmc_exal_v2",
    "remaining_failed_mcmc_al_v3_rescue_canary",
    "remaining_failed_mcmc_exal_v3_rescue_canary",
    "remaining_failed_mcmc_al_v3_rescue_residual",
    "remaining_failed_mcmc_exal_v3_rescue_residual",
    "remaining_failed_mcmc_al_v3_rescue",
    "remaining_failed_mcmc_exal_v3_rescue",
    "remaining_failed_mcmc_al_v3_rescue_extended_canary",
    "remaining_failed_mcmc_exal_v3_rescue_extended_canary",
    "remaining_failed_mcmc_al_v3_rescue_extended_residual",
    "remaining_failed_mcmc_exal_v3_rescue_extended_residual",
    "remaining_failed_mcmc_al_v3_rescue_extended",
    "remaining_failed_mcmc_exal_v3_rescue_extended",
    "remaining_failed_mcmc_exal_v3_qr_tightslice_canary",
    "remaining_failed_mcmc_exal_v3_qr_tightslice_residual",
    "remaining_failed_mcmc_exal_v3_qr_tightslice",
    "remaining_failed_mcmc_exal_v3_altcore_canary",
    "remaining_failed_mcmc_exal_v3_altcore_residual",
    "remaining_failed_mcmc_exal_v3_altcore",
    "full"
  )
)

phase_defaults_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  mcmc_ridge = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  failed_mcmc_al = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  failed_mcmc_exal = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  failed_mcmc_al_sfreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_defaults.yaml"),
  failed_mcmc_exal_sfreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_defaults.yaml"),
  failed_mcmc_al_thetafreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml"),
  failed_mcmc_exal_thetafreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml"),
  remaining_failed_mcmc_al_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_exal_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_al_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_exal_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_al_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_exal_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_al_v3_rescue_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_rescue_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"),
  remaining_failed_mcmc_al_v3_rescue_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_rescue_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"),
  remaining_failed_mcmc_al_v3_rescue = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_rescue = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"),
  remaining_failed_mcmc_al_v3_rescue_extended_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_rescue_extended_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml"),
  remaining_failed_mcmc_al_v3_rescue_extended_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_rescue_extended_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml"),
  remaining_failed_mcmc_al_v3_rescue_extended = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_rescue_extended = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_qr_tightslice_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_qr_tightslice_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_qr_tightslice = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_altcore_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_altcore_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml"),
  remaining_failed_mcmc_exal_v3_altcore = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml")
)
phase_grid_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_smoke_grid.csv"),
  vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"),
  mcmc_ridge = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_ridge_grid.csv"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt500_grid.csv"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt5000_grid.csv"),
  failed_mcmc_al = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv"),
  failed_mcmc_exal = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"),
  failed_mcmc_al_sfreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv"),
  failed_mcmc_exal_sfreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"),
  failed_mcmc_al_thetafreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv"),
  failed_mcmc_exal_thetafreeze = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"),
  remaining_failed_mcmc_al_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_canary_grid.csv"),
  remaining_failed_mcmc_exal_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_canary_grid.csv"),
  remaining_failed_mcmc_al_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_residual_grid.csv"),
  remaining_failed_mcmc_exal_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_residual_grid.csv"),
  remaining_failed_mcmc_al_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_grid.csv"),
  remaining_failed_mcmc_exal_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_grid.csv"),
  remaining_failed_mcmc_al_v3_rescue_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv"),
  remaining_failed_mcmc_exal_v3_rescue_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv"),
  remaining_failed_mcmc_al_v3_rescue_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv"),
  remaining_failed_mcmc_exal_v3_rescue_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv"),
  remaining_failed_mcmc_al_v3_rescue = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv"),
  remaining_failed_mcmc_exal_v3_rescue = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv"),
  remaining_failed_mcmc_al_v3_rescue_extended_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv"),
  remaining_failed_mcmc_exal_v3_rescue_extended_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv"),
  remaining_failed_mcmc_al_v3_rescue_extended_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv"),
  remaining_failed_mcmc_exal_v3_rescue_extended_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv"),
  remaining_failed_mcmc_al_v3_rescue_extended = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv"),
  remaining_failed_mcmc_exal_v3_rescue_extended = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv"),
  remaining_failed_mcmc_exal_v3_qr_tightslice_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv"),
  remaining_failed_mcmc_exal_v3_qr_tightslice_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv"),
  remaining_failed_mcmc_exal_v3_qr_tightslice = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv"),
  remaining_failed_mcmc_exal_v3_altcore_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv"),
  remaining_failed_mcmc_exal_v3_altcore_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv"),
  remaining_failed_mcmc_exal_v3_altcore = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv")
)
phase_likelihoods_map <- list(
  smoke = NULL,
  vb = NULL,
  mcmc_ridge = NULL,
  mcmc_rhsns_tt500 = NULL,
  mcmc_rhsns_tt5000 = NULL,
  failed_mcmc_al = "al",
  failed_mcmc_exal = "exal",
  failed_mcmc_al_sfreeze = "al",
  failed_mcmc_exal_sfreeze = "exal",
  remaining_failed_mcmc_al_v2_canary = "al",
  remaining_failed_mcmc_exal_v2_canary = "exal",
  remaining_failed_mcmc_al_v2_residual = "al",
  remaining_failed_mcmc_exal_v2_residual = "exal",
  remaining_failed_mcmc_al_v2 = "al",
  remaining_failed_mcmc_exal_v2 = "exal",
  remaining_failed_mcmc_al_v3_rescue_canary = "al",
  remaining_failed_mcmc_exal_v3_rescue_canary = "exal",
  remaining_failed_mcmc_al_v3_rescue_residual = "al",
  remaining_failed_mcmc_exal_v3_rescue_residual = "exal",
  remaining_failed_mcmc_al_v3_rescue = "al",
  remaining_failed_mcmc_exal_v3_rescue = "exal",
  remaining_failed_mcmc_al_v3_rescue_extended_canary = "al",
  remaining_failed_mcmc_exal_v3_rescue_extended_canary = "exal",
  remaining_failed_mcmc_al_v3_rescue_extended_residual = "al",
  remaining_failed_mcmc_exal_v3_rescue_extended_residual = "exal",
  remaining_failed_mcmc_al_v3_rescue_extended = "al",
  remaining_failed_mcmc_exal_v3_rescue_extended = "exal",
  remaining_failed_mcmc_exal_v3_qr_tightslice_canary = "exal",
  remaining_failed_mcmc_exal_v3_qr_tightslice_residual = "exal",
  remaining_failed_mcmc_exal_v3_qr_tightslice = "exal",
  remaining_failed_mcmc_exal_v3_altcore_canary = "exal",
  remaining_failed_mcmc_exal_v3_altcore_residual = "exal",
  remaining_failed_mcmc_exal_v3_altcore = "exal",
  full = NULL
)

pass_args <- character(0)
skip_next <- FALSE
for (i in seq_along(args)) {
  if (isTRUE(skip_next)) {
    skip_next <- FALSE
    next
  }
  if (identical(args[[i]], "--phase")) {
    skip_next <- TRUE
    next
  }
  pass_args <- c(pass_args, args[[i]])
}
has_arg <- function(flag, values) {
  any(values == flag)
}
likelihoods_arg <- phase_likelihoods_map[[phase]]
if (nzchar(trimws(as.character(likelihoods_arg %||% "")[1L])) && !has_arg("--likelihoods", pass_args)) {
  pass_args <- c(pass_args, "--likelihoods", as.character(likelihoods_arg)[1L])
}

status <- system2(
  "Rscript",
  c(
    file.path("scripts", "healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults",
    phase_defaults_map[[phase]],
    "--grid",
    phase_grid_map[[phase]],
    pass_args
  ),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")
