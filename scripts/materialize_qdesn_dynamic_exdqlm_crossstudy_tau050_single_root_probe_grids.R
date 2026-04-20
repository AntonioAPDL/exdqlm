#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml")
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
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(
      file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."),
      winslash = "/",
      mustWork = TRUE
    )
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

subset_and_write <- function(grid_df, root_ids, output_path, label) {
  subset_grid <- grid_df[match(root_ids, grid_df$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(subset_grid) != length(root_ids)) {
    missing_ids <- setdiff(root_ids, as.character(subset_grid$root_id))
    stop(
      sprintf(
        "Failed to recover %d %s roots: %s",
        length(missing_ids),
        label,
        paste(missing_ids, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  subset_grid <- subset_grid[order(subset_grid$root_id), , drop = FALSE]
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(subset_grid, output_path, row.names = FALSE)
  subset_grid
}

al_source_path <- resolve_path(
  get_arg(
    "--source-al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv")
  ),
  must_work = TRUE
)
exal_source_path <- resolve_path(
  get_arg(
    "--source-exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv")
  ),
  must_work = TRUE
)

primary_exal_output_path <- resolve_path(
  get_arg(
    "--primary-exal-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_primary_exal_rhsns_grid.csv")
  ),
  must_work = FALSE
)
exal_ridge_output_path <- resolve_path(
  get_arg(
    "--exal-ridge-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_comparator_exal_ridge_grid.csv")
  ),
  must_work = FALSE
)
al_rhsns_output_path <- resolve_path(
  get_arg(
    "--al-rhsns-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_comparator_al_rhsns_grid.csv")
  ),
  must_work = FALSE
)
al_ridge_output_path <- resolve_path(
  get_arg(
    "--al-ridge-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_comparator_al_ridge_grid.csv")
  ),
  must_work = FALSE
)
triad_exal_output_path <- resolve_path(
  get_arg(
    "--triad-exal-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_triad_exal_grid.csv")
  ),
  must_work = FALSE
)
triad_al_output_path <- resolve_path(
  get_arg(
    "--triad-al-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_triad_al_grid.csv")
  ),
  must_work = FALSE
)
tau_only_defaults_output_path <- resolve_path(
  get_arg(
    "--tau-only-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_tau_only_defaults.yaml")
  ),
  must_work = FALSE
)
theta_tau_defaults_output_path <- resolve_path(
  get_arg(
    "--theta-tau-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_defaults.yaml")
  ),
  must_work = FALSE
)
stau_defaults_output_path <- resolve_path(
  get_arg(
    "--stau-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_stau_defaults.yaml")
  ),
  must_work = FALSE
)
theta_tau_rescue_defaults_output_path <- resolve_path(
  get_arg(
    "--theta-tau-rescue-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_rescue_defaults.yaml")
  ),
  must_work = FALSE
)
triad_tau_only_defaults_output_path <- resolve_path(
  get_arg(
    "--triad-tau-only-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_tau_only_defaults.yaml")
  ),
  must_work = FALSE
)
triad_theta_tau_defaults_output_path <- resolve_path(
  get_arg(
    "--triad-theta-tau-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_theta_tau_defaults.yaml")
  ),
  must_work = FALSE
)

al_grid <- utils::read.csv(al_source_path, stringsAsFactors = FALSE)
exal_grid <- utils::read.csv(exal_source_path, stringsAsFactors = FALSE)

primary_exal_rhsns_root_id <- "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns"
comparator_exal_ridge_root_id <- "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge"
comparator_al_rhsns_root_id <- "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns"
comparator_al_ridge_root_id <- "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge"

primary_exal_grid <- subset_and_write(
  exal_grid,
  primary_exal_rhsns_root_id,
  primary_exal_output_path,
  "primary EXAL probe"
)
exal_ridge_grid <- subset_and_write(
  exal_grid,
  comparator_exal_ridge_root_id,
  exal_ridge_output_path,
  "EXAL ridge comparator"
)
al_rhsns_grid <- subset_and_write(
  al_grid,
  comparator_al_rhsns_root_id,
  al_rhsns_output_path,
  "AL rhs_ns comparator"
)
al_ridge_grid <- subset_and_write(
  al_grid,
  comparator_al_ridge_root_id,
  al_ridge_output_path,
  "AL ridge comparator"
)
triad_exal_grid <- subset_and_write(
  exal_grid,
  c(primary_exal_rhsns_root_id, comparator_exal_ridge_root_id),
  triad_exal_output_path,
  "EXAL triad"
)
triad_al_grid <- subset_and_write(
  al_grid,
  comparator_al_rhsns_root_id,
  triad_al_output_path,
  "AL triad"
)

theta_base_path <- resolve_path(
  file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml"),
  must_work = TRUE
)
stau_base_path <- resolve_path(
  file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_defaults.yaml"),
  must_work = TRUE
)

primary_probe_seed <- suppressWarnings(as.integer(primary_exal_grid$seed[[1L]]))

set_campaign_common <- function(doc, campaign_name, study_id, description, vb_profile_id) {
  doc$campaign$name <- campaign_name
  doc$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", campaign_name)
  doc$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", campaign_name)
  doc$study_contract$id <- study_id
  doc$study_contract$description <- description
  doc$study_contract$vb$profile_id <- vb_profile_id
  doc$execution$methods <- c("vb", "mcmc")
  doc$execution$likelihood_families <- c("exal", "al")
  doc$runtime$campaign_workers <- 1L
  doc$runtime$workers <- 1L
  doc$pipeline$inference$vb$rhs <- doc$pipeline$inference$vb$rhs %||% list()
  doc$pipeline$inference$vb$rhs$freeze_tau_iters <- 50L
  doc$pipeline$inference$vb$rhs$freeze_tau_warmup_iters <- 50L
  doc$pipeline$inference$vb$rhs$tau_local_tol <- 5.0e-4
  doc$pipeline$inference$vb$rhs$min_tau_updates <- 2L
  doc$pipeline$inference$vb$rhs$force_tau_after_warmup <- TRUE
  doc$pipeline$inference$vb$prior_overrides <- doc$pipeline$inference$vb$prior_overrides %||% list()
  doc$pipeline$inference$vb$prior_overrides$rhs_ns <- doc$pipeline$inference$vb$prior_overrides$rhs_ns %||% list()
  doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs <- doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs %||% list()
  doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs$freeze_tau_iters <- 50L
  doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs$freeze_tau_warmup_iters <- 50L
  doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs$tau_local_tol <- 5.0e-4
  doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs$min_tau_updates <- 2L
  doc$pipeline$inference$vb$prior_overrides$rhs_ns$rhs$force_tau_after_warmup <- TRUE
  doc$pipeline$inference$mcmc$vb_warm_start_control <- doc$pipeline$inference$mcmc$vb_warm_start_control %||% list()
  doc$pipeline$inference$mcmc$vb_warm_start_control$rhs <- doc$pipeline$inference$mcmc$vb_warm_start_control$rhs %||% list()
  doc$pipeline$inference$mcmc$vb_warm_start_control$rhs$freeze_tau_iters <- 50L
  doc$pipeline$inference$mcmc$vb_warm_start_control$rhs$freeze_tau_warmup_iters <- 50L
  doc$pipeline$inference$mcmc$vb_warm_start_control$rhs$tau_local_tol <- 5.0e-4
  doc$pipeline$inference$mcmc$vb_warm_start_control$rhs$min_tau_updates <- 2L
  doc$pipeline$inference$mcmc$vb_warm_start_control$rhs$force_tau_after_warmup <- TRUE
  doc$pilot$source_family <- "laplace"
  doc$pilot$tau <- 0.50
  doc$pilot$fit_size <- 5000L
  doc$pilot$effective_fit_size <- 5000L
  doc$pilot$source_total_size <- 5313L
  doc$pilot$source_window_label <- "effTT5000_totalTT5313"
  doc$pilot$beta_prior_type <- "rhs_ns"
  doc$pilot$seed <- primary_probe_seed
  doc$smoke$family <- "laplace"
  doc$smoke$tau <- 0.50
  doc$smoke$fit_sizes <- list(5000L)
  doc$smoke$priors <- list("rhs_ns")
  doc
}

write_yaml_doc <- function(doc, output_path) {
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(doc, output_path)
  invisible(output_path)
}

theta_tau_doc <- yaml::read_yaml(theta_base_path)
theta_tau_doc <- set_campaign_common(
  theta_tau_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_validation",
  study_id = "tau050_single_root_probe_theta_tau",
  description = paste(
    "Single-root probe lane for the tau050 crash-recovery program.",
    "This arm isolates a theta-plus-tau stabilization strategy on the",
    "primary EXAL laplace tau=0.50 fit_size=5000 rhs_ns crash probe."
  ),
  vb_profile_id = "qdesn_ldvb_single_root_probe_theta_tau"
)

tau_only_doc <- yaml::read_yaml(theta_base_path)
tau_only_doc <- set_campaign_common(
  tau_only_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_tau_only_validation",
  study_id = "tau050_single_root_probe_tau_only",
  description = paste(
    "Single-root probe lane for the tau050 crash-recovery program.",
    "This arm keeps tau stabilization but disables theta, latent-v, and",
    "latent-s scheduler overlays so we can measure a clean tau-only baseline."
  ),
  vb_profile_id = "qdesn_ldvb_single_root_probe_tau_only"
)
tau_only_doc$study_contract$mcmc$theta$enabled <- FALSE
tau_only_doc$study_contract$mcmc$theta$freeze_burnin_iters <- 0L
tau_only_doc$study_contract$mcmc$theta$sparse_update_every <- 1L
tau_only_doc$study_contract$mcmc$theta$sparse_update_until_iter <- 0L
tau_only_doc$study_contract$mcmc$theta$force_first_postwarmup_update <- FALSE
tau_only_doc$pipeline$inference$mcmc$theta$enabled <- FALSE
tau_only_doc$pipeline$inference$mcmc$theta$freeze_burnin_iters <- 0L
tau_only_doc$pipeline$inference$mcmc$theta$sparse_update_every <- 1L
tau_only_doc$pipeline$inference$mcmc$theta$sparse_update_until_iter <- 0L
tau_only_doc$pipeline$inference$mcmc$theta$force_first_postwarmup_update <- FALSE

stau_doc <- yaml::read_yaml(stau_base_path)
stau_doc <- set_campaign_common(
  stau_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_stau_validation",
  study_id = "tau050_single_root_probe_stau",
  description = paste(
    "Single-root probe lane for the tau050 crash-recovery program.",
    "This arm keeps tau stabilization and re-enables latent-v plus latent-s",
    "freeze / sparse-update scheduling for comparison against theta-freeze."
  ),
  vb_profile_id = "qdesn_ldvb_single_root_probe_stau"
)
stau_doc$study_contract$mcmc$sigmagam$freeze_burnin_iters <- 0L
stau_doc$study_contract$mcmc$sigmagam$force_after_warmup <- FALSE
stau_doc$study_contract$mcmc$sigmagam$delay_adapt_until_after_warmup <- FALSE
stau_doc$study_contract$mcmc$sigmagam$delay_laplace_refresh_until_after_warmup <- FALSE
stau_doc$pipeline$inference$mcmc$sigmagam$freeze_burnin_iters <- 0L
stau_doc$pipeline$inference$mcmc$sigmagam$force_after_warmup <- FALSE
stau_doc$pipeline$inference$mcmc$sigmagam$delay_adapt_until_after_warmup <- FALSE
stau_doc$pipeline$inference$mcmc$sigmagam$delay_laplace_refresh_until_after_warmup <- FALSE
stau_doc$study_contract$mcmc$theta <- list(
  enabled = FALSE,
  freeze_burnin_iters = 0L,
  freeze_only_during_burn = TRUE,
  sparse_update_every = 1L,
  sparse_update_until_iter = 0L,
  force_first_postwarmup_update = FALSE,
  trace = TRUE
)
stau_doc$pipeline$inference$mcmc$theta <- stau_doc$study_contract$mcmc$theta

theta_tau_rescue_doc <- yaml::read_yaml(theta_base_path)
theta_tau_rescue_doc <- set_campaign_common(
  theta_tau_rescue_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_rescue_validation",
  study_id = "tau050_single_root_probe_theta_tau_rescue",
  description = paste(
    "Single-root probe lane for the tau050 crash-recovery program.",
    "This arm extends theta-plus-tau stabilization with bounded latent-v",
    "rescue so we can test whether rescue changes the post-thaw crash regime."
  ),
  vb_profile_id = "qdesn_ldvb_single_root_probe_theta_tau_rescue"
)
theta_tau_rescue_doc$study_contract$mcmc$latent_v$rescue_on_invalid <- TRUE
theta_tau_rescue_doc$study_contract$mcmc$latent_v$rescue_strategy <- "previous_state"
theta_tau_rescue_doc$study_contract$mcmc$latent_v$rescue_max_consecutive <- 1L
theta_tau_rescue_doc$study_contract$mcmc$latent_v$rescue_burn_only <- FALSE
theta_tau_rescue_doc$pipeline$inference$mcmc$latent_v$rescue_on_invalid <- TRUE
theta_tau_rescue_doc$pipeline$inference$mcmc$latent_v$rescue_strategy <- "previous_state"
theta_tau_rescue_doc$pipeline$inference$mcmc$latent_v$rescue_max_consecutive <- 1L
theta_tau_rescue_doc$pipeline$inference$mcmc$latent_v$rescue_burn_only <- FALSE

write_yaml_doc(tau_only_doc, tau_only_defaults_output_path)
write_yaml_doc(theta_tau_doc, theta_tau_defaults_output_path)
write_yaml_doc(stau_doc, stau_defaults_output_path)
write_yaml_doc(theta_tau_rescue_doc, theta_tau_rescue_defaults_output_path)

triad_tau_only_doc <- tau_only_doc
triad_tau_only_doc <- set_campaign_common(
  triad_tau_only_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_tau_only_validation",
  study_id = "tau050_representative_triad_tau_only",
  description = paste(
    "Representative-triad promotion lane for the tau050 crash-recovery program.",
    "This arm promotes the tau-only stabilization baseline onto the EXAL prior",
    "comparator pair plus the AL rhs_ns comparator."
  ),
  vb_profile_id = "qdesn_ldvb_representative_triad_tau_only"
)

triad_theta_tau_doc <- theta_tau_doc
triad_theta_tau_doc <- set_campaign_common(
  triad_theta_tau_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_theta_tau_validation",
  study_id = "tau050_representative_triad_theta_tau",
  description = paste(
    "Representative-triad promotion lane for the tau050 crash-recovery program.",
    "This arm promotes the theta-plus-tau stabilization candidate onto the",
    "EXAL prior comparator pair plus the AL rhs_ns comparator."
  ),
  vb_profile_id = "qdesn_ldvb_representative_triad_theta_tau"
)

write_yaml_doc(triad_tau_only_doc, triad_tau_only_defaults_output_path)
write_yaml_doc(triad_theta_tau_doc, triad_theta_tau_defaults_output_path)

cat(sprintf("source_al_grid=%s\n", al_source_path))
cat(sprintf("source_exal_grid=%s\n", exal_source_path))
cat(sprintf("primary_exal_output=%s\n", primary_exal_output_path))
cat(sprintf("primary_exal_roots=%d\n", nrow(primary_exal_grid)))
cat(sprintf("exal_ridge_output=%s\n", exal_ridge_output_path))
cat(sprintf("exal_ridge_roots=%d\n", nrow(exal_ridge_grid)))
cat(sprintf("al_rhsns_output=%s\n", al_rhsns_output_path))
cat(sprintf("al_rhsns_roots=%d\n", nrow(al_rhsns_grid)))
cat(sprintf("al_ridge_output=%s\n", al_ridge_output_path))
cat(sprintf("al_ridge_roots=%d\n", nrow(al_ridge_grid)))
cat(sprintf("triad_exal_output=%s\n", triad_exal_output_path))
cat(sprintf("triad_exal_roots=%d\n", nrow(triad_exal_grid)))
cat(sprintf("triad_al_output=%s\n", triad_al_output_path))
cat(sprintf("triad_al_roots=%d\n", nrow(triad_al_grid)))
cat(sprintf("tau_only_defaults_output=%s\n", tau_only_defaults_output_path))
cat(sprintf("theta_tau_defaults_output=%s\n", theta_tau_defaults_output_path))
cat(sprintf("stau_defaults_output=%s\n", stau_defaults_output_path))
cat(sprintf("theta_tau_rescue_defaults_output=%s\n", theta_tau_rescue_defaults_output_path))
cat(sprintf("triad_tau_only_defaults_output=%s\n", triad_tau_only_defaults_output_path))
cat(sprintf("triad_theta_tau_defaults_output=%s\n", triad_theta_tau_defaults_output_path))
