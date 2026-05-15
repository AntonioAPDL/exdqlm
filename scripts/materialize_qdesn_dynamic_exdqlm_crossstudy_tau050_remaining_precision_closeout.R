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

subset_and_write <- function(grid_df, root_id, output_path, label) {
  subset_grid <- grid_df[match(root_id, grid_df$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(subset_grid) != 1L) {
    stop(
      sprintf("Expected exactly one %s root for closeout, found %d", label, nrow(subset_grid)),
      call. = FALSE
    )
  }
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

apply_precision_beta_patch <- function(doc, preset) {
  doc$pipeline$inference$mcmc$precision_beta <- list(
    preset = as.character(preset),
    trace = TRUE
  )
  doc
}

remaining_root_id <- "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge"

closeout_map_output_path <- resolve_path(
  get_arg(
    "--closeout-map-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_map.csv")
  ),
  must_work = FALSE
)
al_source_grid_path <- resolve_path(
  get_arg(
    "--source-al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv")
  ),
  must_work = TRUE
)
exal_source_grid_path <- resolve_path(
  get_arg(
    "--source-exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv")
  ),
  must_work = TRUE
)
al_output_grid_path <- resolve_path(
  get_arg(
    "--al-output-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_grid.csv")
  ),
  must_work = FALSE
)
exal_output_grid_path <- resolve_path(
  get_arg(
    "--exal-output-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_grid.csv")
  ),
  must_work = FALSE
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
al_ladder_defaults_output_path <- resolve_path(
  get_arg(
    "--al-ladder-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_ladder_v2_defaults.yaml")
  ),
  must_work = FALSE
)
exal_ladder_defaults_output_path <- resolve_path(
  get_arg(
    "--exal-ladder-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_ladder_v2_defaults.yaml")
  ),
  must_work = FALSE
)
al_eigen_defaults_output_path <- resolve_path(
  get_arg(
    "--al-eigen-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_eigen_v1_defaults.yaml")
  ),
  must_work = FALSE
)
exal_eigen_defaults_output_path <- resolve_path(
  get_arg(
    "--exal-eigen-defaults-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_eigen_v1_defaults.yaml")
  ),
  must_work = FALSE
)

al_source_grid <- utils::read.csv(al_source_grid_path, stringsAsFactors = FALSE)
exal_source_grid <- utils::read.csv(exal_source_grid_path, stringsAsFactors = FALSE)
al_base_doc <- yaml::read_yaml(al_base_defaults_path)
exal_base_doc <- yaml::read_yaml(exal_base_defaults_path)

al_closeout_grid <- subset_and_write(al_source_grid, remaining_root_id, al_output_grid_path, "AL")
exal_closeout_grid <- subset_and_write(exal_source_grid, remaining_root_id, exal_output_grid_path, "EXAL")

specs <- list(
  list(
    phase = "remaining_precision_closeout_al_ladder_v2",
    lane = "al",
    role = "canonical_live",
    launch_policy = "launch",
    base_doc = al_base_doc,
    pilot_grid = al_closeout_grid,
    preset = "ladder_v2",
    description = paste(
      "Canonical closeout rerun for the final AL precision root.",
      "This promotes the winning ladder_v2 precision-beta rescue as the single live AL closeout policy."
    ),
    vb_profile_id = "qdesn_ldvb_remaining_precision_closeout_al_ladder_v2",
    defaults_output_path = al_ladder_defaults_output_path
  ),
  list(
    phase = "remaining_precision_closeout_exal_ladder_v2",
    lane = "exal",
    role = "canonical_live",
    launch_policy = "launch",
    base_doc = exal_base_doc,
    pilot_grid = exal_closeout_grid,
    preset = "ladder_v2",
    description = paste(
      "Canonical closeout rerun for the final EXAL precision root.",
      "This promotes the winning ladder_v2 precision-beta rescue as the single live EXAL closeout policy."
    ),
    vb_profile_id = "qdesn_ldvb_remaining_precision_closeout_exal_ladder_v2",
    defaults_output_path = exal_ladder_defaults_output_path
  ),
  list(
    phase = "remaining_precision_closeout_al_eigen_v1",
    lane = "al",
    role = "fallback_prepared",
    launch_policy = "prepare_only",
    base_doc = al_base_doc,
    pilot_grid = al_closeout_grid,
    preset = "eigen_v1",
    description = paste(
      "Prepared fallback closeout for the final AL precision root.",
      "Use only if the promoted ladder_v2 closeout rerun still fails."
    ),
    vb_profile_id = "qdesn_ldvb_remaining_precision_closeout_al_eigen_v1",
    defaults_output_path = al_eigen_defaults_output_path
  ),
  list(
    phase = "remaining_precision_closeout_exal_eigen_v1",
    lane = "exal",
    role = "fallback_prepared",
    launch_policy = "prepare_only",
    base_doc = exal_base_doc,
    pilot_grid = exal_closeout_grid,
    preset = "eigen_v1",
    description = paste(
      "Prepared fallback closeout for the final EXAL precision root.",
      "Use only if the promoted ladder_v2 closeout rerun still fails."
    ),
    vb_profile_id = "qdesn_ldvb_remaining_precision_closeout_exal_eigen_v1",
    defaults_output_path = exal_eigen_defaults_output_path
  )
)

closeout_map <- do.call(
  rbind,
  lapply(specs, function(spec) {
    data.frame(
      phase = spec$phase,
      lane = spec$lane,
      root_id = spec$pilot_grid$root_id[[1L]],
      precision_beta_preset = spec$preset,
      role = spec$role,
      launch_policy = spec$launch_policy,
      stringsAsFactors = FALSE
    )
  })
)
dir.create(dirname(closeout_map_output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(closeout_map, closeout_map_output_path, row.names = FALSE)

for (spec in specs) {
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
  doc <- set_lane_defaults(doc, lane = spec$lane, workers = 1L, pilot_grid = spec$pilot_grid)
  doc <- apply_precision_beta_patch(doc, preset = spec$preset)
  dir.create(dirname(spec$defaults_output_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(as.yaml(doc), con = spec$defaults_output_path)
}

cat(sprintf("remaining_precision_closeout_rows=%d\n", nrow(closeout_map)))
cat(sprintf("al_root=%s\n", al_closeout_grid$root_id[[1L]]))
cat(sprintf("exal_root=%s\n", exal_closeout_grid$root_id[[1L]]))
