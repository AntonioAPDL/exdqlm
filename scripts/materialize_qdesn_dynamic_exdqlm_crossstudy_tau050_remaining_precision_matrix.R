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

apply_precision_patch <- function(doc, lane, spec) {
  doc$pipeline$inference$mcmc$conditioning <- list(
    mode = spec$conditioning_mode,
    gram_ridge = spec$gram_ridge,
    scale_metric = spec$scale_metric,
    scale_floor = spec$scale_floor
  )
  doc$pipeline$inference$mcmc$transforms <- modifyList(
    doc$pipeline$inference$mcmc$transforms %||% list(),
    list(
      use_log_sigma = isTRUE(spec$use_log_sigma),
      sigma_eta_bounds = spec$sigma_eta_bounds
    )
  )
  doc$pipeline$inference$mcmc$slice <- modifyList(
    doc$pipeline$inference$mcmc$slice %||% list(),
    list(
      core_update_mode = spec$core_update_mode,
      width_gamma = spec$width_gamma,
      width_sigma = spec$width_sigma,
      core_extra_passes = as.integer(spec$core_extra_passes),
      max_steps_out = as.integer(spec$max_steps_out),
      max_shrink = as.integer(spec$max_shrink),
      max_steps_out_sigma = as.integer(spec$max_steps_out_sigma),
      max_shrink_sigma = as.integer(spec$max_shrink_sigma)
    )
  )
  if (identical(lane, "al")) {
    doc$pipeline$inference$mcmc$slice$core_update_mode <- "sigma_then_gamma"
  }
  doc
}

matrix_map_output_path <- resolve_path(
  get_arg(
    "--matrix-map-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_map.csv")
  ),
  must_work = FALSE
)
al_grid_path <- resolve_path(
  get_arg(
    "--al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv")
  ),
  must_work = TRUE
)
exal_grid_path <- resolve_path(
  get_arg(
    "--exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv")
  ),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg(
    "--base-defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_rescue_defaults.yaml")
  ),
  must_work = TRUE
)

al_grid <- utils::read.csv(al_grid_path, stringsAsFactors = FALSE)
exal_grid <- utils::read.csv(exal_grid_path, stringsAsFactors = FALSE)
base_doc <- yaml::read_yaml(base_defaults_path)

specs <- list(
  list(
    phase = "remaining_precision_matrix_al_qr_v1",
    lane = "al",
    workers = 1L,
    description = "AL precision retry with qr-whiten, gram_ridge=1e-4, log-sigma, and one extra core pass.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_al_qr_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_qr_v1_defaults.yaml"),
    conditioning_mode = "qr_whiten",
    gram_ridge = 1e-4,
    scale_metric = "sd",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "sigma_then_gamma",
    width_gamma = 0.53,
    width_sigma = 0.22,
    core_extra_passes = 1L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  ),
  list(
    phase = "remaining_precision_matrix_al_qr_v2",
    lane = "al",
    workers = 1L,
    description = "AL precision retry with stronger qr-whiten ridge, log-sigma, and two extra core passes.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_al_qr_v2",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_qr_v2_defaults.yaml"),
    conditioning_mode = "qr_whiten",
    gram_ridge = 1e-2,
    scale_metric = "sd",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "sigma_then_gamma",
    width_gamma = 0.53,
    width_sigma = 0.20,
    core_extra_passes = 2L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  ),
  list(
    phase = "remaining_precision_matrix_al_diag_v1",
    lane = "al",
    workers = 1L,
    description = "AL precision retry with diagonal scaling instead of qr-whiten, plus log-sigma and one extra core pass.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_al_diag_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_diag_v1_defaults.yaml"),
    conditioning_mode = "diag_scale",
    gram_ridge = 1e-8,
    scale_metric = "rms",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "sigma_then_gamma",
    width_gamma = 0.53,
    width_sigma = 0.22,
    core_extra_passes = 1L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  ),
  list(
    phase = "remaining_precision_matrix_exal_qr_v1",
    lane = "exal",
    workers = 1L,
    description = "EXAL precision retry with qr-whiten, gram_ridge=1e-3, gamma-sigma-gamma, and log-sigma.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_exal_qr_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_v1_defaults.yaml"),
    conditioning_mode = "qr_whiten",
    gram_ridge = 1e-3,
    scale_metric = "sd",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "gamma_sigma_gamma",
    width_gamma = 0.53,
    width_sigma = 0.22,
    core_extra_passes = 1L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  ),
  list(
    phase = "remaining_precision_matrix_exal_qr_v2",
    lane = "exal",
    workers = 1L,
    description = "EXAL precision retry with stronger qr-whiten ridge, gamma-sigma-gamma, log-sigma, and two extra core passes.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_exal_qr_v2",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_v2_defaults.yaml"),
    conditioning_mode = "qr_whiten",
    gram_ridge = 1e-2,
    scale_metric = "sd",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "gamma_sigma_gamma",
    width_gamma = 0.53,
    width_sigma = 0.20,
    core_extra_passes = 2L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  ),
  list(
    phase = "remaining_precision_matrix_exal_qr_sig_v1",
    lane = "exal",
    workers = 1L,
    description = "EXAL precision retry with stronger qr-whiten ridge, sigma-then-gamma order, log-sigma, and two extra core passes.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_exal_qr_sig_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_sig_v1_defaults.yaml"),
    conditioning_mode = "qr_whiten",
    gram_ridge = 1e-2,
    scale_metric = "sd",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "sigma_then_gamma",
    width_gamma = 0.53,
    width_sigma = 0.20,
    core_extra_passes = 2L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  ),
  list(
    phase = "remaining_precision_matrix_exal_diag_v1",
    lane = "exal",
    workers = 1L,
    description = "EXAL precision retry with diagonal scaling, gamma-sigma-gamma, and log-sigma to test a non-QR conditioning path.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_matrix_exal_diag_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_diag_v1_defaults.yaml"),
    conditioning_mode = "diag_scale",
    gram_ridge = 1e-8,
    scale_metric = "rms",
    scale_floor = 1e-8,
    use_log_sigma = TRUE,
    sigma_eta_bounds = c(-8, 8),
    core_update_mode = "gamma_sigma_gamma",
    width_gamma = 0.53,
    width_sigma = 0.22,
    core_extra_passes = 1L,
    max_steps_out = 80L,
    max_shrink = 320L,
    max_steps_out_sigma = 160L,
    max_shrink_sigma = 420L
  )
)

matrix_map <- do.call(
  rbind,
  lapply(specs, function(spec) {
    data.frame(
      phase = spec$phase,
      lane = spec$lane,
      root_id = if (identical(spec$lane, "al")) al_grid$root_id[[1L]] else exal_grid$root_id[[1L]],
      conditioning_mode = spec$conditioning_mode,
      gram_ridge = spec$gram_ridge,
      scale_metric = spec$scale_metric,
      use_log_sigma = spec$use_log_sigma,
      width_gamma = spec$width_gamma,
      width_sigma = spec$width_sigma,
      core_update_mode = spec$core_update_mode,
      core_extra_passes = spec$core_extra_passes,
      stringsAsFactors = FALSE
    )
  })
)
dir.create(dirname(matrix_map_output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(matrix_map, matrix_map_output_path, row.names = FALSE)

for (spec in specs) {
  grid <- if (identical(spec$lane, "al")) al_grid else exal_grid
  doc <- set_campaign_common(
    base_doc,
    campaign_name = sprintf("qdesn_dynamic_exdqlm_crossstudy_tau050_%s_validation", spec$phase),
    study_id = sprintf("tau050_%s", spec$phase),
    description = spec$description,
    vb_profile_id = spec$vb_profile_id,
    results_root = sprintf("results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_%s_validation", spec$phase),
    reports_root = sprintf("reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_%s_validation", spec$phase)
  )
  doc <- set_lane_defaults(doc, lane = spec$lane, workers = spec$workers, pilot_grid = grid)
  doc <- apply_precision_patch(doc, lane = spec$lane, spec = spec)
  defaults_path <- resolve_path(spec$defaults_file, must_work = FALSE)
  dir.create(dirname(defaults_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(as.yaml(doc), con = defaults_path)
}

cat(sprintf("remaining_precision_matrix_rows=%d\n", nrow(matrix_map)))
cat(sprintf("al_root=%s\n", al_grid$root_id[[1L]]))
cat(sprintf("exal_root=%s\n", exal_grid$root_id[[1L]]))
