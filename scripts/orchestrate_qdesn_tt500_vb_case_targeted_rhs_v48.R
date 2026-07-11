#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
has_arg <- function(flag) any(args == flag)
add_default <- function(extra, flag, value) {
  if (has_arg(flag)) return(extra)
  c(extra, flag, value)
}

default_source_report <- file.path(
  "reports", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v47",
  "qdesn-vb-case-targeted-rhs-v47-full-20260711__git-508a685",
  "20260711-022419__git-508a685"
)

extra <- character(0)
extra <- add_default(extra, "--screen-mode", "fitrmse_v48")
extra <- add_default(extra, "--stage-file", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v48")
extra <- add_default(extra, "--source-report-root", default_source_report)
extra <- add_default(extra, "--base-defaults", "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v47_defaults.yaml")
extra <- add_default(extra, "--doc-out", "validation/fitforecast_v2/docs/QDESN_500OBS_VB_CASE_TARGETED_RHS_V48_PLAN_2026-07-11.md")
extra <- add_default(extra, "--max-profiles-per-cell", "48")
extra <- add_default(extra, "--workers", "32")

cmd_args <- c(file.path("scripts", "orchestrate_qdesn_tt500_vb_case_specific_rhs_screen.R"), extra, args)
status <- system2("Rscript", cmd_args)
quit(status = as.integer(status), save = "no")
