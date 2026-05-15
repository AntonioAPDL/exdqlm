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

cluster_map_path <- resolve_path(
  get_arg(
    "--cluster-map",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_run_specific_cluster_map.csv")
  ),
  must_work = TRUE
)
al_source_path <- resolve_path(
  get_arg(
    "--source-al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv")
  ),
  must_work = TRUE
)
exal_source_path <- resolve_path(
  get_arg(
    "--source-exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv")
  ),
  must_work = TRUE
)
latent_v_al_output_path <- resolve_path(
  get_arg(
    "--latent-v-al-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_grid.csv")
  ),
  must_work = FALSE
)
latent_v_exal_output_path <- resolve_path(
  get_arg(
    "--latent-v-exal-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_grid.csv")
  ),
  must_work = FALSE
)
exal_ridge_output_path <- resolve_path(
  get_arg(
    "--exal-ridge-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_grid.csv")
  ),
  must_work = FALSE
)
latent_v_al_defaults_output_path <- resolve_path(
  get_arg(
    "--latent-v-al-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_defaults.yaml")
  ),
  must_work = FALSE
)
latent_v_exal_defaults_output_path <- resolve_path(
  get_arg(
    "--latent-v-exal-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_defaults.yaml")
  ),
  must_work = FALSE
)
exal_ridge_v1_defaults_output_path <- resolve_path(
  get_arg(
    "--exal-ridge-v1-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_defaults.yaml")
  ),
  must_work = FALSE
)
exal_ridge_v2_defaults_output_path <- resolve_path(
  get_arg(
    "--exal-ridge-v2-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v2_defaults.yaml")
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

cluster_map <- utils::read.csv(cluster_map_path, stringsAsFactors = FALSE)
al_grid <- utils::read.csv(al_source_path, stringsAsFactors = FALSE)
exal_grid <- utils::read.csv(exal_source_path, stringsAsFactors = FALSE)

required_cluster_cols <- c("lane", "root_id", "failure_cluster")
missing_cluster_cols <- setdiff(required_cluster_cols, names(cluster_map))
if (length(missing_cluster_cols)) {
  stop(sprintf("Cluster map is missing required columns: %s", paste(missing_cluster_cols, collapse = ", ")), call. = FALSE)
}

latent_v_al_root_ids <- as.character(cluster_map$root_id[cluster_map$failure_cluster == "latent_v_postthaw" & cluster_map$lane == "al"])
latent_v_exal_root_ids <- as.character(cluster_map$root_id[cluster_map$failure_cluster == "latent_v_postthaw" & cluster_map$lane == "exal"])
exal_ridge_root_ids <- as.character(cluster_map$root_id[cluster_map$failure_cluster == "exal_ridge_precision" & cluster_map$lane == "exal"])

latent_v_al_grid <- subset_and_write(al_grid, latent_v_al_root_ids, latent_v_al_output_path, "latent-v AL cluster")
latent_v_exal_grid <- subset_and_write(exal_grid, latent_v_exal_root_ids, latent_v_exal_output_path, "latent-v EXAL cluster")
exal_ridge_grid <- subset_and_write(exal_grid, exal_ridge_root_ids, exal_ridge_output_path, "EXAL ridge cluster")

base_rescue_doc <- yaml::read_yaml(base_rescue_defaults_path)

latent_v_al_doc <- set_campaign_common(
  base_rescue_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation",
  study_id = "tau050_remaining_hard_fail_latent_v_al",
  description = paste(
    "Run-specific remaining hard-fail relaunch for the AL latent-v post-thaw cluster.",
    "This lane promotes the tau+theta+bounded-latent-v-rescue spec onto the AL subset",
    "of the remaining fit_size=5000 hard-fail surface."
  ),
  vb_profile_id = "qdesn_ldvb_remaining_hard_fail_latent_v_al",
  results_root = "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation",
  reports_root = "reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation"
)
latent_v_al_doc <- set_lane_defaults(latent_v_al_doc, lane = "al", workers = 3L, pilot_grid = latent_v_al_grid)

latent_v_exal_doc <- set_campaign_common(
  base_rescue_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_validation",
  study_id = "tau050_remaining_hard_fail_latent_v_exal",
  description = paste(
    "Run-specific remaining hard-fail relaunch for the EXAL latent-v post-thaw cluster.",
    "This lane promotes the tau+theta+bounded-latent-v-rescue spec onto the EXAL rhs_ns-like",
    "subset of the remaining fit_size=5000 hard-fail surface."
  ),
  vb_profile_id = "qdesn_ldvb_remaining_hard_fail_latent_v_exal",
  results_root = "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_validation",
  reports_root = "reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_validation"
)
latent_v_exal_doc <- set_lane_defaults(latent_v_exal_doc, lane = "exal", workers = 2L, pilot_grid = latent_v_exal_grid)

exal_ridge_v1_doc <- set_campaign_common(
  base_rescue_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation",
  study_id = "tau050_remaining_hard_fail_exal_ridge_precision_v1",
  description = paste(
    "Run-specific remaining hard-fail relaunch for the EXAL ridge precision cluster.",
    "This primary lane combines tau+theta+bounded-latent-v-rescue with EXAL qr-whitened",
    "beta conditioning and a mild Gram ridge to stabilize the Cholesky failure pocket."
  ),
  vb_profile_id = "qdesn_ldvb_remaining_hard_fail_exal_ridge_precision_v1",
  results_root = "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation",
  reports_root = "reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation"
)
exal_ridge_v1_doc <- set_lane_defaults(exal_ridge_v1_doc, lane = "exal", workers = 2L, pilot_grid = exal_ridge_grid)
exal_ridge_v1_doc$pipeline$inference$mcmc$conditioning <- list(
  mode = "qr_whiten",
  gram_ridge = 1e-6,
  scale_metric = "sd",
  scale_floor = 1e-8
)
exal_ridge_v1_doc$pipeline$inference$mcmc$slice$core_update_mode <- "sigma_then_gamma"

exal_ridge_v2_doc <- set_campaign_common(
  exal_ridge_v1_doc,
  campaign_name = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v2_validation",
  study_id = "tau050_remaining_hard_fail_exal_ridge_precision_v2",
  description = paste(
    "Fallback run-specific relaunch for the EXAL ridge precision cluster.",
    "This lane strengthens EXAL ridge stabilization with a larger Gram ridge and",
    "gamma-sigma-gamma core updates for roots that still fail under precision v1."
  ),
  vb_profile_id = "qdesn_ldvb_remaining_hard_fail_exal_ridge_precision_v2",
  results_root = "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v2_validation",
  reports_root = "reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v2_validation"
)
exal_ridge_v2_doc <- set_lane_defaults(exal_ridge_v2_doc, lane = "exal", workers = 2L, pilot_grid = exal_ridge_grid)
exal_ridge_v2_doc$pipeline$inference$mcmc$conditioning$gram_ridge <- 1e-4
exal_ridge_v2_doc$pipeline$inference$mcmc$slice$core_update_mode <- "gamma_sigma_gamma"

for (path in c(
  latent_v_al_defaults_output_path,
  latent_v_exal_defaults_output_path,
  exal_ridge_v1_defaults_output_path,
  exal_ridge_v2_defaults_output_path
)) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
}

yaml::write_yaml(latent_v_al_doc, latent_v_al_defaults_output_path)
yaml::write_yaml(latent_v_exal_doc, latent_v_exal_defaults_output_path)
yaml::write_yaml(exal_ridge_v1_doc, exal_ridge_v1_defaults_output_path)
yaml::write_yaml(exal_ridge_v2_doc, exal_ridge_v2_defaults_output_path)

cat(sprintf("cluster_map=%s\n", cluster_map_path))
cat(sprintf("latent_v_al_output=%s\n", latent_v_al_output_path))
cat(sprintf("latent_v_al_roots=%d\n", nrow(latent_v_al_grid)))
cat(sprintf("latent_v_exal_output=%s\n", latent_v_exal_output_path))
cat(sprintf("latent_v_exal_roots=%d\n", nrow(latent_v_exal_grid)))
cat(sprintf("exal_ridge_output=%s\n", exal_ridge_output_path))
cat(sprintf("exal_ridge_roots=%d\n", nrow(exal_ridge_grid)))
cat(sprintf("latent_v_al_defaults=%s\n", latent_v_al_defaults_output_path))
cat(sprintf("latent_v_exal_defaults=%s\n", latent_v_exal_defaults_output_path))
cat(sprintf("exal_ridge_v1_defaults=%s\n", exal_ridge_v1_defaults_output_path))
cat(sprintf("exal_ridge_v2_defaults=%s\n", exal_ridge_v2_defaults_output_path))
