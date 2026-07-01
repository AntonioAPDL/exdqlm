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

base_stub <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn"
rescue_stub <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_exal_mcmc_diagnostic_rescue"
base_defaults_path <- file.path("config", "validation", paste0(base_stub, "_defaults.yaml"))
base_grid_path <- file.path("config", "validation", paste0(base_stub, "_grid.csv"))
rescue_defaults_path <- file.path("config", "validation", paste0(rescue_stub, "_defaults.yaml"))
rescue_root_ids_path <- file.path("config", "validation", paste0(rescue_stub, "_root_ids.csv"))
rescue_manifest_path <- file.path("config", "validation", paste0(rescue_stub, "_materialization_manifest.json"))

base_grid <- read.csv(base_grid_path, check.names = FALSE, stringsAsFactors = FALSE)
if (nrow(base_grid) != 9L || !identical(sort(unique(base_grid$beta_prior_type)), "ridge")) {
  stop("Base ridge corrected grid must contain exactly 9 ridge rows.", call. = FALSE)
}
root_ids <- sort(unique(base_grid$root_id))

cfg <- yaml::read_yaml(base_defaults_path)
cfg$campaign$name <- rescue_stub
cfg$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", rescue_stub)
cfg$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", rescue_stub)
cfg$study_contract$id <- paste0(rescue_stub, "_2026_07_01")
cfg$study_contract$description <- paste(
  "Q-DESN TT500 ridge MCMC exAL diagnostic rescue for the corrected-DESN ridge lane.",
  "This rescue reuses the frozen 9-cell ridge grid and changes only the MCMC chain budget",
  "and slice-kernel tuning for exAL MCMC diagnostics."
)
cfg$study_contract$budget$mcmc_n_burn <- 8000L
cfg$study_contract$budget$mcmc_n_mcmc <- 40000L
cfg$study_contract$mcmc$diagnostic_rescue <- list(
  enabled = TRUE,
  source_campaign = base_stub,
  root_ids_csv = rescue_root_ids_path,
  reason = "MCMC exAL ridge high-autocorrelation and marginal-chain diagnostic debt"
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
cfg$pipeline$inference$mcmc$slice$width_gamma <- 0.62
cfg$pipeline$inference$mcmc$slice$width_sigma <- 0.38
cfg$pipeline$inference$mcmc$slice$width_rhs_lambda <- 0.22
cfg$pipeline$inference$mcmc$slice$width_rhs_tau <- 0.13
cfg$pipeline$inference$mcmc$slice$width_rhs_c2 <- 0.085
cfg$pipeline$inference$mcmc$slice$width_rhs_tau_c2_block <- 0.27
cfg$pipeline$inference$mcmc$slice$max_steps_out <- 140L
cfg$pipeline$inference$mcmc$slice$max_shrink <- 520L
cfg$pipeline$inference$mcmc$slice$max_steps_out_sigma <- 220L
cfg$pipeline$inference$mcmc$slice$max_shrink_sigma <- 620L

cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 8000L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 40000L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 50L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$core_update_mode <- "sigma_then_gamma"
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$width_gamma <- 0.62
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$width_sigma <- 0.38
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$core_extra_passes <- 4L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$max_steps_out <- 140L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$max_shrink <- 520L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$max_steps_out_sigma <- 220L
cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice$max_shrink_sigma <- 620L

dir.create(dirname(rescue_defaults_path), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(cfg, rescue_defaults_path)
write.csv(
  data.frame(
    root_id = root_ids,
    rescue_reason = "mcmc_exal_ridge_diagnostic_debt",
    stringsAsFactors = FALSE
  ),
  rescue_root_ids_path,
  row.names = FALSE
)
jsonlite::write_json(
  list(
    generated_at = as.character(Sys.time()),
    base_defaults_path = normalizePath(base_defaults_path, winslash = "/", mustWork = TRUE),
    base_grid_path = normalizePath(base_grid_path, winslash = "/", mustWork = TRUE),
    rescue_defaults_path = normalizePath(rescue_defaults_path, winslash = "/", mustWork = FALSE),
    rescue_root_ids_path = normalizePath(rescue_root_ids_path, winslash = "/", mustWork = FALSE),
    root_count = length(root_ids),
    methods = "mcmc",
    likelihoods = "exal",
    priors = "ridge",
    mcmc_n_burn = 8000L,
    mcmc_n_mcmc = 40000L,
    workers = length(root_ids),
    slice_changes = list(
      core_extra_passes = 4L,
      width_gamma = 0.62,
      width_sigma = 0.38,
      max_steps_out = 140L,
      max_shrink = 520L
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
