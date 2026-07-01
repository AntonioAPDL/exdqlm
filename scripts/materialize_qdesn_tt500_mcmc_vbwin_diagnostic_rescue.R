#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

base_stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
rescue_stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_rescue_fail5"
base_defaults_path <- file.path("config", "validation", paste0(base_stub, "_defaults.yaml"))
rescue_defaults_path <- file.path("config", "validation", paste0(rescue_stub, "_defaults.yaml"))
rescue_root_ids_path <- file.path("config", "validation", paste0(rescue_stub, "_root_ids.csv"))
rescue_manifest_path <- file.path("config", "validation", paste0(rescue_stub, "_materialization_manifest.json"))

root_ids <- c(
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__normal__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__normal__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3"
)

cfg <- yaml::read_yaml(base_defaults_path)
cfg$campaign$name <- rescue_stub
cfg$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", rescue_stub)
cfg$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", rescue_stub)
cfg$study_contract$id <- paste0(rescue_stub, "_2026_06_30")
cfg$study_contract$description <- paste(
  "Q-DESN TT500 MCMC diagnostic rescue for the five VB-winner confirmation cells",
  "whose completed chains failed signoff because of high autocorrelation or Geweke drift.",
  "This lane reuses the frozen per-cell winner specs, keeps the same source registry,",
  "and changes only the MCMC chain budget and slice-kernel tuning."
)
cfg$study_contract$budget$mcmc_n_burn <- 8000L
cfg$study_contract$budget$mcmc_n_mcmc <- 40000L
cfg$study_contract$mcmc$diagnostic_rescue <- list(
  enabled = TRUE,
  source_campaign = base_stub,
  root_ids_csv = rescue_root_ids_path,
  reason = "strict signoff FAIL in completed TT500 MCMC confirmation"
)
cfg$reference_contract$expected_selected_qdesn_roots <- length(root_ids)
cfg$runtime$campaign_workers <- length(root_ids)
cfg$runtime$workers <- length(root_ids)

cfg$pipeline$inference$mcmc$n_burn <- 8000L
cfg$pipeline$inference$mcmc$n_mcmc <- 40000L
cfg$pipeline$inference$mcmc$progress_every <- 50L
cfg$pipeline$inference$mcmc$rhs$freeze_tau_burnin_iters <- 1000L
cfg$pipeline$inference$mcmc$sigmagam$freeze_burnin_iters <- 100L
cfg$pipeline$inference$mcmc$slice$core_extra_passes <- 4L
cfg$pipeline$inference$mcmc$slice$rhs_transformed_block_passes <- 4L
cfg$pipeline$inference$mcmc$slice$width_gamma <- 0.75
cfg$pipeline$inference$mcmc$slice$width_sigma <- 0.45
cfg$pipeline$inference$mcmc$slice$width_rhs_lambda <- 0.24
cfg$pipeline$inference$mcmc$slice$width_rhs_tau <- 0.14
cfg$pipeline$inference$mcmc$slice$width_rhs_c2 <- 0.09
cfg$pipeline$inference$mcmc$slice$width_rhs_tau_c2_block <- 0.28
cfg$pipeline$inference$mcmc$slice$max_steps_out <- 140L
cfg$pipeline$inference$mcmc$slice$max_shrink <- 520L
cfg$pipeline$inference$mcmc$slice$max_steps_out_sigma <- 220L
cfg$pipeline$inference$mcmc$slice$max_shrink_sigma <- 620L

cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 8000L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 40000L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$freeze_tau_burnin_iters <- 1000L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$core_extra_passes <- 4L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$rhs_transformed_block_passes <- 4L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$width_gamma <- 0.72
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$width_sigma <- 0.48
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$width_rhs_lambda <- 0.22
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$width_rhs_tau <- 0.13
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$width_rhs_c2 <- 0.085
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$width_rhs_tau_c2_block <- 0.27
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$max_steps_out <- 150L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$max_shrink <- 560L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$max_steps_out_sigma <- 240L
cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice$max_shrink_sigma <- 660L

dir.create(dirname(rescue_defaults_path), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(cfg, rescue_defaults_path)
utils::write.csv(
  data.frame(root_id = root_ids, rescue_reason = "completed_chain_signoff_fail", stringsAsFactors = FALSE),
  rescue_root_ids_path,
  row.names = FALSE
)
jsonlite::write_json(
  list(
    generated_at = as.character(Sys.time()),
    base_defaults_path = normalizePath(base_defaults_path, winslash = "/", mustWork = TRUE),
    rescue_defaults_path = normalizePath(rescue_defaults_path, winslash = "/", mustWork = FALSE),
    rescue_root_ids_path = normalizePath(rescue_root_ids_path, winslash = "/", mustWork = FALSE),
    root_count = length(root_ids),
    mcmc_n_burn = 8000L,
    mcmc_n_mcmc = 40000L,
    workers = length(root_ids),
    slice_changes = list(
      core_extra_passes = 4L,
      rhs_transformed_block_passes = 4L,
      width_gamma = 0.72,
      width_sigma = 0.48,
      max_steps_out = 150L,
      max_shrink = 560L
    )
  ),
  rescue_manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("rescue_defaults: %s\n", rescue_defaults_path))
cat(sprintf("rescue_root_ids: %s\n", rescue_root_ids_path))
cat(sprintf("rescue_manifest: %s\n", rescue_manifest_path))
