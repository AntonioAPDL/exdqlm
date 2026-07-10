#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
has_arg <- function(flag) any(args == flag)
add_default <- function(extra, flag, value) {
  if (has_arg(flag)) return(extra)
  c(extra, flag, value)
}

default_source_report <- file.path(
  "reports", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v4",
  "qdesn-vb-case-targeted-rhs-v4-full-20260709__git-8ee4a20",
  "20260709-201700__git-8ee4a20"
)

extra <- character(0)
extra <- add_default(extra, "--screen-mode", "fitrmse_v45")
extra <- add_default(extra, "--stage-file", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v45")
extra <- add_default(extra, "--source-report-root", default_source_report)
extra <- add_default(extra, "--base-defaults", "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v4_defaults.yaml")
extra <- add_default(extra, "--doc-out", "validation/fitforecast_v2/docs/QDESN_500OBS_VB_CASE_TARGETED_RHS_V45_PLAN_2026-07-10.md")
extra <- add_default(extra, "--max-profiles-per-cell", "36")
extra <- add_default(extra, "--workers", "32")

cmd_args <- c(file.path("scripts", "materialize_qdesn_tt500_vb_case_specific_rhs_screen.R"), extra, args)
status <- system2("Rscript", cmd_args)
quit(status = as.integer(status), save = "no")
