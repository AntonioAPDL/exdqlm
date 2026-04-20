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

apply_precision_code_patch <- function(doc, spec) {
  doc$pipeline$inference$mcmc$precision_beta <- list(
    enabled = TRUE,
    symmetrize = isTRUE(spec$symmetrize),
    jitter_ladder = as.numeric(spec$jitter_ladder),
    eigen_fallback = isTRUE(spec$eigen_fallback),
    eigen_floor_abs = as.numeric(spec$eigen_floor_abs),
    eigen_floor_rel = as.numeric(spec$eigen_floor_rel),
    trace = TRUE
  )
  doc
}

matrix_map_output_path <- resolve_path(
  get_arg(
    "--matrix-map-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix_map.csv")
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
al_base_defaults_path <- resolve_path(
  get_arg(
    "--al-base-defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_defaults.yaml")
  ),
  must_work = TRUE
)
exal_base_defaults_path <- resolve_path(
  get_arg(
    "--exal-base-defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_defaults.yaml")
  ),
  must_work = TRUE
)

al_grid <- utils::read.csv(al_grid_path, stringsAsFactors = FALSE)
exal_grid <- utils::read.csv(exal_grid_path, stringsAsFactors = FALSE)
al_base_doc <- yaml::read_yaml(al_base_defaults_path)
exal_base_doc <- yaml::read_yaml(exal_base_defaults_path)

specs <- list(
  list(
    phase = "remaining_precision_code_al_ladder_v1",
    lane = "al",
    workers = 1L,
    base_doc = al_base_doc,
    description = "AL code-level precision rescue with symmetric adaptive jitter ladder up to 1e-4 on top of the validated AL precision-pair baseline.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_code_al_ladder_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v1_defaults.yaml"),
    symmetrize = TRUE,
    jitter_ladder = c(0, 1e-10, 1e-8, 1e-6, 1e-4),
    eigen_fallback = FALSE,
    eigen_floor_abs = 1e-6,
    eigen_floor_rel = 1e-8
  ),
  list(
    phase = "remaining_precision_code_al_ladder_v2",
    lane = "al",
    workers = 1L,
    base_doc = al_base_doc,
    description = "AL code-level precision rescue with stronger symmetric adaptive jitter ladder up to 1e-2 on the validated AL precision-pair baseline.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_code_al_ladder_v2",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v2_defaults.yaml"),
    symmetrize = TRUE,
    jitter_ladder = c(0, 1e-10, 1e-8, 1e-6, 1e-4, 1e-2),
    eigen_fallback = FALSE,
    eigen_floor_abs = 1e-6,
    eigen_floor_rel = 1e-8
  ),
  list(
    phase = "remaining_precision_code_al_eigen_v1",
    lane = "al",
    workers = 1L,
    base_doc = al_base_doc,
    description = "AL code-level precision rescue with symmetric ladder plus eigenvalue-floored SPD fallback on the validated AL precision-pair baseline.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_code_al_eigen_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_eigen_v1_defaults.yaml"),
    symmetrize = TRUE,
    jitter_ladder = c(0, 1e-10, 1e-8, 1e-6),
    eigen_fallback = TRUE,
    eigen_floor_abs = 1e-6,
    eigen_floor_rel = 1e-8
  ),
  list(
    phase = "remaining_precision_code_exal_ladder_v1",
    lane = "exal",
    workers = 1L,
    base_doc = exal_base_doc,
    description = "EXAL code-level precision rescue with symmetric adaptive jitter ladder up to 1e-4 on top of the validated EXAL precision-pair baseline.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_code_exal_ladder_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_ladder_v1_defaults.yaml"),
    symmetrize = TRUE,
    jitter_ladder = c(0, 1e-10, 1e-8, 1e-6, 1e-4),
    eigen_fallback = FALSE,
    eigen_floor_abs = 1e-6,
    eigen_floor_rel = 1e-8
  ),
  list(
    phase = "remaining_precision_code_exal_ladder_v2",
    lane = "exal",
    workers = 1L,
    base_doc = exal_base_doc,
    description = "EXAL code-level precision rescue with stronger symmetric adaptive jitter ladder up to 1e-2 on the validated EXAL precision-pair baseline.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_code_exal_ladder_v2",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_ladder_v2_defaults.yaml"),
    symmetrize = TRUE,
    jitter_ladder = c(0, 1e-10, 1e-8, 1e-6, 1e-4, 1e-2),
    eigen_fallback = FALSE,
    eigen_floor_abs = 1e-6,
    eigen_floor_rel = 1e-8
  ),
  list(
    phase = "remaining_precision_code_exal_eigen_v1",
    lane = "exal",
    workers = 1L,
    base_doc = exal_base_doc,
    description = "EXAL code-level precision rescue with symmetric ladder plus eigenvalue-floored SPD fallback on the validated EXAL precision-pair baseline.",
    vb_profile_id = "qdesn_ldvb_remaining_precision_code_exal_eigen_v1",
    defaults_file = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_eigen_v1_defaults.yaml"),
    symmetrize = TRUE,
    jitter_ladder = c(0, 1e-10, 1e-8, 1e-6),
    eigen_fallback = TRUE,
    eigen_floor_abs = 1e-6,
    eigen_floor_rel = 1e-8
  )
)

matrix_map <- do.call(
  rbind,
  lapply(specs, function(spec) {
    data.frame(
      phase = spec$phase,
      lane = spec$lane,
      root_id = if (identical(spec$lane, "al")) al_grid$root_id[[1L]] else exal_grid$root_id[[1L]],
      symmetrize = isTRUE(spec$symmetrize),
      jitter_ladder_max = max(spec$jitter_ladder),
      eigen_fallback = isTRUE(spec$eigen_fallback),
      eigen_floor_abs = spec$eigen_floor_abs,
      eigen_floor_rel = spec$eigen_floor_rel,
      stringsAsFactors = FALSE
    )
  })
)
dir.create(dirname(matrix_map_output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(matrix_map, matrix_map_output_path, row.names = FALSE)

for (spec in specs) {
  grid <- if (identical(spec$lane, "al")) al_grid else exal_grid
  doc <- spec$base_doc
  doc <- set_campaign_common(
    doc,
    campaign_name = sprintf("qdesn_dynamic_exdqlm_crossstudy_tau050_%s_validation", spec$phase),
    study_id = sprintf("tau050_%s", spec$phase),
    description = spec$description,
    vb_profile_id = spec$vb_profile_id,
    results_root = sprintf("results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_%s_validation", spec$phase),
    reports_root = sprintf("reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_%s_validation", spec$phase)
  )
  doc <- set_lane_defaults(doc, lane = spec$lane, workers = spec$workers, pilot_grid = grid)
  doc <- apply_precision_code_patch(doc, spec = spec)
  defaults_path <- resolve_path(spec$defaults_file, must_work = FALSE)
  dir.create(dirname(defaults_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(as.yaml(doc), con = defaults_path)
}

cat(sprintf("remaining_precision_code_matrix_rows=%d\n", nrow(matrix_map)))
cat(sprintf("al_root=%s\n", al_grid$root_id[[1L]]))
cat(sprintf("exal_root=%s\n", exal_grid$root_id[[1L]]))
