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

set_campaign_common <- function(doc, campaign_name, study_id, description, vb_profile_id, results_root, reports_root) {
  doc$campaign$name <- campaign_name
  doc$campaign$results_root <- results_root
  doc$campaign$reports_root <- reports_root
  doc$study_contract$id <- study_id
  doc$study_contract$description <- description
  doc$study_contract$vb$profile_id <- vb_profile_id
  doc
}

set_lane_defaults <- function(doc, lane, workers, pilot_grid) {
  doc$execution$likelihood_families <- list(lane)
  doc$runtime$workers <- as.integer(workers)
  doc$runtime$campaign_workers <- as.integer(workers)
  doc$pilot$source_family <- as.character(pilot_grid$source_family[[1L]])
  doc$pilot$tau <- as.numeric(pilot_grid$tau[[1L]])
  doc$pilot$fit_size <- as.integer(pilot_grid$fit_size[[1L]])
  doc$pilot$effective_fit_size <- as.integer(pilot_grid$effective_fit_size[[1L]])
  doc$pilot$source_total_size <- as.integer(pilot_grid$source_total_size[[1L]])
  doc$pilot$source_window_label <- as.character(pilot_grid$source_window_label[[1L]])
  doc$pilot$beta_prior_type <- as.character(pilot_grid$beta_prior_type[[1L]])
  doc$pilot$seed <- as.integer(pilot_grid$seed[[1L]])
  doc$smoke$family <- as.character(pilot_grid$source_family[[1L]])
  doc$smoke$tau <- as.numeric(pilot_grid$tau[[1L]])
  doc$smoke$fit_sizes <- list(as.integer(pilot_grid$fit_size[[1L]]))
  doc$smoke$priors <- list(as.character(pilot_grid$beta_prior_type[[1L]]))
  doc
}

remaining_root_id <- "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge"

al_source_path <- resolve_path(
  get_arg(
    "--source-al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_grid.csv")
  ),
  must_work = TRUE
)
exal_source_path <- resolve_path(
  get_arg(
    "--source-exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_grid.csv")
  ),
  must_work = TRUE
)
pair_map_output_path <- resolve_path(
  get_arg(
    "--pair-map-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_map.csv")
  ),
  must_work = FALSE
)
al_output_path <- resolve_path(
  get_arg(
    "--al-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv")
  ),
  must_work = FALSE
)
exal_output_path <- resolve_path(
  get_arg(
    "--exal-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv")
  ),
  must_work = FALSE
)
al_defaults_output_path <- resolve_path(
  get_arg(
    "--al-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_defaults.yaml")
  ),
  must_work = FALSE
)
exal_defaults_output_path <- resolve_path(
  get_arg(
    "--exal-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_defaults.yaml")
  ),
  must_work = FALSE
)
base_rescue_defaults_path <- resolve_path(
  get_arg(
    "--base-rescue-defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_rescue_defaults.yaml")
  ),
  must_work = TRUE
)

al_grid <- utils::read.csv(al_source_path, stringsAsFactors = FALSE)
exal_grid <- utils::read.csv(exal_source_path, stringsAsFactors = FALSE)

pair_map <- data.frame(
  lane = c("al", "exal"),
  root_id = c(remaining_root_id, remaining_root_id),
  failure_cluster = c("al_precision_pair", "exal_precision_pair"),
  spec_id = c("tau_theta_precision_al_v1", "tau_theta_precision_exal_v2"),
  stringsAsFactors = FALSE
)
dir.create(dirname(pair_map_output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(pair_map, pair_map_output_path, row.names = FALSE)

al_pair_grid <- subset_and_write(al_grid, remaining_root_id, al_output_path, "remaining precision-pair AL")
exal_pair_grid <- subset_and_write(exal_grid, remaining_root_id, exal_output_path, "remaining precision-pair EXAL")

base_rescue_doc <- yaml::read_yaml(base_rescue_defaults_path)

al_doc <- set_campaign_common(
  base_rescue_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_validation",
  study_id = "tau050_remaining_precision_pair_al_v1",
  description = paste(
    "Root-specific relaunch for the single remaining AL failure.",
    "This lane targets the laplace/tau0.50/fit_size5000/ridge root with tau+theta+bounded-latent-v-rescue",
    "plus qr-whitened precision stabilization and a mild Gram ridge."
  ),
  vb_profile_id = "qdesn_ldvb_remaining_precision_pair_al_v1",
  results_root = "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_validation",
  reports_root = "reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_validation"
)
al_doc <- set_lane_defaults(al_doc, lane = "al", workers = 1L, pilot_grid = al_pair_grid)
al_doc$pipeline$inference$mcmc$conditioning <- list(
  mode = "qr_whiten",
  gram_ridge = 1e-6,
  scale_metric = "sd",
  scale_floor = 1e-8
)
al_doc$pipeline$inference$mcmc$slice$core_update_mode <- "sigma_then_gamma"

exal_doc <- set_campaign_common(
  base_rescue_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_validation",
  study_id = "tau050_remaining_precision_pair_exal_v2",
  description = paste(
    "Root-specific relaunch for the single remaining EXAL failure.",
    "This lane targets the laplace/tau0.50/fit_size5000/ridge root with tau+theta+bounded-latent-v-rescue",
    "plus stronger qr-whitened precision stabilization and gamma-sigma-gamma core updates."
  ),
  vb_profile_id = "qdesn_ldvb_remaining_precision_pair_exal_v2",
  results_root = "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_validation",
  reports_root = "reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_validation"
)
exal_doc <- set_lane_defaults(exal_doc, lane = "exal", workers = 1L, pilot_grid = exal_pair_grid)
exal_doc$pipeline$inference$mcmc$conditioning <- list(
  mode = "qr_whiten",
  gram_ridge = 1e-4,
  scale_metric = "sd",
  scale_floor = 1e-8
)
exal_doc$pipeline$inference$mcmc$slice$core_update_mode <- "gamma_sigma_gamma"

for (path in c(al_defaults_output_path, exal_defaults_output_path)) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
}
writeLines(as.yaml(al_doc), con = al_defaults_output_path)
writeLines(as.yaml(exal_doc), con = exal_defaults_output_path)

cat(sprintf("remaining_precision_pair_rows=%d\n", nrow(pair_map)))
cat(sprintf("al_rows=%d\n", nrow(al_pair_grid)))
cat(sprintf("exal_rows=%d\n", nrow(exal_pair_grid)))
cat(sprintf("al_root=%s\n", al_pair_grid$root_id[[1L]]))
cat(sprintf("exal_root=%s\n", exal_pair_grid$root_id[[1L]]))
