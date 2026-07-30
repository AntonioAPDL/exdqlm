#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(required, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
fmt_tau <- function(x) exdqlm:::.qdesn_dynamic_fitforecast_tau_key(as.numeric(x))
clean_token <- function(x) {
  x <- tolower(as.character(x)[1L])
  x <- gsub("[.]", "p", x)
  x <- gsub("-", "m", x)
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}
likelihood_for <- function(x) ifelse(grepl("exal", x, fixed = TRUE), "exal", "al")
workers <- suppressWarnings(as.integer(get_arg("--workers", "16"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 16L
workers <- min(workers, 16L)
refresh_materialized <- has_flag("--refresh-materialized")

source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
date_stamp <- "20260729"
stage_base <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1"
promotion_id <- paste0("qdesn_500obs_mcmc_nested_cellwise_v1_design_", date_stamp)
promotion_root <- file.path("validation", "fitforecast_v2", "promotions", promotion_id)
parent_id <- "qdesn_tt500_mcmc_postv4_percell_closeout_20260728"
parent_root <- file.path("validation", "fitforecast_v2", "promotions", parent_id)
unresolved_path <- file.path(parent_root, paste0(parent_id, "_unresolved_cells.csv"))
parent_envelope_path <- file.path(parent_root, paste0(parent_id, "_refreshed_article_envelope.csv"))
parent_ledger_path <- file.path(parent_root, paste0(parent_id, "_combined_candidate_ledger.csv"))
base_defaults_path <- file.path(
  "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_defaults.yaml"
)

unresolved <- read_csv(unresolved_path)
parent_envelope <- read_csv(parent_envelope_path)
parent_ledger <- read_csv(parent_ledger_path)
if (nrow(unresolved) != 15L ||
    nrow(unique(unresolved[c("model_variant", "family", "tau", "fit_size")])) != 15L ||
    any(as.character(unresolved$source_registry_hash_value) != source_hash)) {
  stop("Nested cellwise v1 requires the frozen 15-cell post-v4 handoff.", call. = FALSE)
}
unresolved$likelihood_target <- likelihood_for(unresolved$model_variant)
unresolved$target_cell <- paste(
  unresolved$model_variant,
  unresolved$family,
  sprintf("%.8f", as.numeric(unresolved$tau)),
  sep = "|"
)

profile_paths <- list.files(
  file.path(repo_root, "config", "validation"),
  pattern = "^qdesn_dynamic_fitforecast_v2_tt500_.*mcmc.*profiles[.]csv$",
  full.names = TRUE
)
profile_paths <- profile_paths[!grepl("nested_cellwise_v1", basename(profile_paths), fixed = TRUE)]
profile_rows <- lapply(profile_paths, function(path) {
  d <- tryCatch(
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(...) data.frame(stringsAsFactors = FALSE)
  )
  if (nrow(d)) d$profile_source_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  d
})
history_profiles <- exdqlm:::.qdesn_validation_bind_rows(profile_rows)
profile_fields <- c(
  "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "washout", "add_bias", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "seed", "target_cells"
)
for (nm in setdiff(profile_fields, names(history_profiles))) history_profiles[[nm]] <- NA

signature <- function(d, include_target = TRUE) {
  core <- paste(
    as.integer(d$D), as.integer(d$n_each), as.integer(d$n_tilde_each),
    as.integer(d$m), sprintf("%.10g", as.numeric(d$alpha)),
    sprintf("%.10g", as.numeric(d$rho)), sprintf("%.10g", as.numeric(d$pi_w)),
    sprintf("%.10g", as.numeric(d$pi_in)), as.integer(d$readout_y_lags),
    as.integer(d$reservoir_lags), sprintf("%.10g", as.numeric(d$rhs_tau0)),
    sep = "|"
  )
  if (!isTRUE(include_target)) return(core)
  paste(as.character(d$target_cells %||% ""), core, sep = "|")
}
history_profiles$numeric_signature <- signature(history_profiles, FALSE)
history_profiles$target_signature <- signature(history_profiles, TRUE)

lookup_profile <- function(candidate_id) {
  candidate_id <- as.character(candidate_id %||% "")[1L]
  hit <- history_profiles[as.character(history_profiles$screening_profile_id) == candidate_id, , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  hit[1L, , drop = FALSE]
}
anchor_candidate_ids <- function(cell) {
  ids <- if (identical(as.character(cell$primary_remaining_gap_postv4), "fit")) {
    c(cell$fit_source_candidate_id, cell$forecast_mae_source_candidate_id)
  } else {
    c(cell$forecast_mae_source_candidate_id, cell$fit_source_candidate_id)
  }
  ids <- unique(as.character(ids[nzchar(as.character(ids))]))
  mapped <- ids[vapply(ids, function(id) !is.null(lookup_profile(id)), logical(1L))]
  if (!length(mapped)) stop(sprintf("No mapped anchor for %s.", cell$target_cell), call. = FALSE)
  c(mapped, mapped[[1L]])[seq_len(2L)]
}
profile_value <- function(x, name, default) {
  value <- suppressWarnings(as.numeric(x[[name]])[1L])
  if (is.finite(value)) value else default
}

make_designs <- function(cell) {
  ids <- anchor_candidate_ids(cell)
  a1 <- lookup_profile(ids[[1L]])
  a2 <- lookup_profile(ids[[2L]])
  get_anchor <- function(a, role) {
    data.frame(
      design_role = role,
      repeat_class = "declared_anchor_control",
      source_candidate_id = as.character(a$screening_profile_id[[1L]]),
      D = as.integer(profile_value(a, "D", 1)),
      n_each = as.integer(profile_value(a, "n_each", 6)),
      n_tilde_each = as.integer(profile_value(a, "n_tilde_each", 0)),
      m = as.integer(profile_value(a, "m", 1)),
      alpha = profile_value(a, "alpha", 0.001),
      rho = profile_value(a, "rho", 0.45),
      pi_w = profile_value(a, "pi_w", 0.0025),
      pi_in = profile_value(a, "pi_in", 0.05),
      readout_y_lags = as.integer(profile_value(a, "readout_y_lags", 1)),
      reservoir_lags = as.integer(profile_value(a, "reservoir_lags", 0)),
      rhs_tau0 = profile_value(a, "rhs_tau0", 3e-4),
      hypothesis = "exact historical cell-specific metric anchor",
      stringsAsFactors = FALSE
    )
  }
  anchors <- rbind(get_anchor(a1, "primary_anchor"), get_anchor(a2, "secondary_anchor"))
  local <- data.frame(
    design_role = c(
      "compact_lhs_01", "compact_lhs_02", "compact_lhs_03", "compact_lhs_04",
      "compact_lhs_05", "compact_lhs_06", "compact_lhs_07", "compact_lhs_08",
      "compact_lhs_09", "controlled_d2_sentinel"
    ),
    repeat_class = "novel_candidate",
    source_candidate_id = NA_character_,
    D = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 2L),
    n_each = c(5L, 7L, 9L, 11L, 13L, 16L, 5L, 9L, 12L, 5L),
    n_tilde_each = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 3L),
    m = c(1L, 2L, 3L, 5L, 8L, 1L, 5L, 8L, 30L, 8L),
    alpha = c(0.00043, 0.00067, 0.0011, 0.0019, 0.0029, 0.00082, 0.00135, 0.0023, 0.00058, 0.00155),
    rho = c(0.29, 0.41, 0.53, 0.67, 0.71, 0.36, 0.59, 0.47, 0.63, 0.55),
    pi_w = c(0.0013, 0.0037, 0.0065, 0.011, 0.016, 0.0021, 0.0085, 0.0048, 0.014, 0.0055),
    pi_in = c(0.04, 0.07, 0.13, 0.21, 0.27, 0.17, 0.09, 0.24, 0.15, 0.11),
    readout_y_lags = c(1L, 2L, 3L, 5L, 8L, 1L, 5L, 8L, 30L, 8L),
    reservoir_lags = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L),
    rhs_tau0 = c(6e-5, 1.2e-4, 1.8e-4, 2.4e-4, 4.5e-4, 7e-4, 1e-3, 8.5e-5, 3.7e-4, 5.8e-4),
    hypothesis = c(
      "minimal local memory with moderate shrinkage",
      "two-lag compact interpolation",
      "three-lag compact interpolation",
      "short-memory moderate-capacity interpolation",
      "eight-lag weak-shrinkage interpolation",
      "wider one-lag weak-shrinkage candidate",
      "small reservoir with moderate memory",
      "balanced compact memory candidate",
      "period-submultiple sentinel with moderate shrinkage",
      "controlled two-layer sentinel below the p/n cap"
    ),
    stringsAsFactors = FALSE
  )
  out <- rbind(anchors, local)
  target_token <- sprintf("%s:%s:%s", cell$family, fmt_tau(cell$tau), cell$likelihood_target)
  out$target_cells <- target_token
  out$numeric_signature <- signature(out, FALSE)
  out$target_signature <- signature(out, TRUE)
  novel <- out$repeat_class == "novel_candidate"
  duplicate <- out$target_signature %in% history_profiles$target_signature
  if (any(novel & duplicate)) {
    stop(sprintf(
      "Generated target-specific historical duplicate(s) for %s: %s",
      cell$target_cell,
      paste(out$design_role[novel & duplicate], collapse = ", ")
    ), call. = FALSE)
  }
  out
}

profile_list <- list()
assignment_list <- list()
design_audit_list <- list()
for (i in seq_len(nrow(unresolved))) {
  cell <- unresolved[i, , drop = FALSE]
  designs <- make_designs(cell)
  for (j in seq_len(nrow(designs))) {
    for (reservoir_rep in 1:2) {
      arm <- designs[j, , drop = FALSE]
      id <- sprintf(
        "ncv1_%03d_%s_%s_t%s_%s_r%02d",
        length(profile_list) + 1L,
        cell$likelihood_target,
        clean_token(cell$family),
        clean_token(sprintf("%.2f", cell$tau)),
        clean_token(arm$design_role),
        reservoir_rep
      )
      x_count <- 5L
      p_est <- as.integer(
        arm$D * arm$n_each + arm$n_tilde_each + arm$readout_y_lags +
          arm$reservoir_lags + 1L + x_count
      )
      profile_list[[length(profile_list) + 1L]] <- data.frame(
        screening_profile_id = id,
        screening_stage = "mcmc_nested_cellwise_v1_discovery",
        screening_wave = "mcmc_nested_cellwise_v1_2026_07_29",
        profile_role = arm$design_role,
        enabled = TRUE,
        D = as.integer(arm$D),
        n_each = as.integer(arm$n_each),
        n_tilde_each = as.integer(arm$n_tilde_each),
        m = as.integer(arm$m),
        alpha = as.numeric(arm$alpha),
        rho = as.numeric(arm$rho),
        pi_w = as.numeric(arm$pi_w),
        pi_in = as.numeric(arm$pi_in),
        washout = 300L,
        add_bias = TRUE,
        seed = as.integer(720000L + i * 1000L + j * 10L + reservoir_rep),
        readout_y_lags = as.integer(arm$readout_y_lags),
        reservoir_lags = as.integer(arm$reservoir_lags),
        rhs_tau0 = as.numeric(arm$rhs_tau0),
        dimension_p_estimate = p_est,
        p_over_n_tt500 = p_est / 500,
        x_feature_count = x_count,
        target_cells = arm$target_cells,
        source_screening_profile_id = arm$source_candidate_id,
        candidate_source = ifelse(
          arm$repeat_class == "declared_anchor_control",
          "historical_anchor_control",
          "nested_cellwise_novel_design"
        ),
        selection_reason = arm$hypothesis,
        reservoir_seed_rep = reservoir_rep,
        repeat_class = arm$repeat_class,
        stringsAsFactors = FALSE
      )
      assignment_list[[length(assignment_list) + 1L]] <- data.frame(
        assignment_key = paste(id, cell$family, fmt_tau(cell$tau), sep = "|"),
        assignment_id = sprintf("nested_cellwise_v1_%03d", length(assignment_list) + 1L),
        family = cell$family,
        tau = as.numeric(cell$tau),
        likelihood_target = cell$likelihood_target,
        cell_status = ifelse(
          identical(as.character(cell$primary_remaining_gap_postv4), "fit"),
          "fit_dominated",
          "forecast_dominated"
        ),
        priority_rank = i,
        target_profile_rank = j,
        screening_profile_id = id,
        source_profile = arm$source_candidate_id,
        candidate_source = ifelse(
          arm$repeat_class == "declared_anchor_control",
          "historical_anchor_control",
          "nested_cellwise_novel_design"
        ),
        selection_reason = arm$hypothesis,
        primary_gap = cell$primary_remaining_gap_postv4,
        current_worst_ratio = cell$worst_ratio_postv4,
        fit_ratio_to_external_best = cell$fit_ratio_postv4,
        forecast_mae_ratio_to_external_best = cell$forecast_mae_ratio_postv4,
        forecast_check_ratio_to_external_best = cell$forecast_check_ratio_postv4,
        bottleneck_metric = cell$primary_remaining_gap_postv4,
        launch_status = "prepared_for_nested_calibration",
        reservoir_seed_rep = reservoir_rep,
        repeat_class = arm$repeat_class,
        stringsAsFactors = FALSE
      )
      design_audit_list[[length(design_audit_list) + 1L]] <- data.frame(
        target_cell = cell$target_cell,
        screening_profile_id = id,
        design_role = arm$design_role,
        reservoir_seed_rep = reservoir_rep,
        repeat_class = arm$repeat_class,
        target_signature = arm$target_signature,
        exact_history_repeat = arm$target_signature %in% history_profiles$target_signature,
        repeat_allowed = arm$repeat_class == "declared_anchor_control",
        stringsAsFactors = FALSE
      )
    }
  }
}
profiles <- exdqlm:::.qdesn_validation_bind_rows(profile_list)
assignments <- exdqlm:::.qdesn_validation_bind_rows(assignment_list)
nonrepeat_audit <- exdqlm:::.qdesn_validation_bind_rows(design_audit_list)
profile_contract <- c(
  profile_rows = nrow(profiles) == 360L,
  assignment_rows = nrow(assignments) == 360L,
  unique_profile_ids = !anyDuplicated(profiles$screening_profile_id),
  novel_dimension_cap = !any(
    profiles$p_over_n_tt500 > 0.20 &
      profiles$repeat_class == "novel_candidate"
  ),
  exact_repeat_policy = !any(
    nonrepeat_audit$exact_history_repeat & !nonrepeat_audit$repeat_allowed
  )
)
if (!all(profile_contract)) {
  stop(
    sprintf(
      "Nested cellwise v1 profile contract failed: %s.",
      paste(names(profile_contract)[!profile_contract], collapse = ", ")
    ),
    call. = FALSE
  )
}

cell_plan <- unresolved[, c(
  "model_variant", "family", "tau", "fit_size", "likelihood_target",
  "primary_remaining_gap_postv4", "worst_ratio_postv4",
  "fit_ratio_postv4", "forecast_mae_ratio_postv4", "forecast_check_ratio_postv4"
), drop = FALSE]
cell_plan$primary_gap <- cell_plan$primary_remaining_gap_postv4
cell_plan$worst_ratio <- cell_plan$worst_ratio_postv4
cell_plan$fit_ratio <- cell_plan$fit_ratio_postv4
cell_plan$forecast_mae_ratio <- cell_plan$forecast_mae_ratio_postv4
cell_plan$forecast_check_ratio <- cell_plan$forecast_check_ratio_postv4
cell_plan$priority <- seq_len(nrow(cell_plan))
cell_plan$target_cell_id <- paste(
  cell_plan$model_variant,
  cell_plan$family,
  sprintf("%.8f", cell_plan$tau),
  sep = "|"
)
cell_plan$cell_status <- ifelse(cell_plan$primary_gap == "fit", "fit_dominated", "forecast_dominated")
cell_plan$target_profiles <- vapply(seq_len(nrow(cell_plan)), function(i) {
  paste(
    assignments$screening_profile_id[
      assignments$family == cell_plan$family[[i]] &
        abs(assignments$tau - cell_plan$tau[[i]]) < 1e-8 &
        assignments$likelihood_target == cell_plan$likelihood_target[[i]]
    ],
    collapse = ","
  )
}, character(1L))

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    generated_at = as.character(Sys.time()),
    stage = stage_base,
    promotion_id = promotion_id,
    source_registry_hash_value = source_hash,
    n_cells = 15L,
    n_designs_per_cell = 12L,
    n_reservoir_seeds_per_design = 2L,
    n_profiles = 360L
  )
)

configure_defaults <- function(path, origin, view_id, selected_specs) {
  defaults <- yaml::read_yaml(path)
  defaults$campaign$name <- paste0(stage_base, "_", view_id)
  defaults$campaign$results_root <- file.path(
    "results", "qdesn_mcmc_validation", paste0(stage_base, "_", view_id)
  )
  defaults$campaign$reports_root <- file.path(
    "reports", "qdesn_mcmc_validation", paste0(stage_base, "_", view_id)
  )
  defaults$execution$methods <- "mcmc"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$study_contract$id <- paste0(stage_base, "_", view_id, "_2026_07_29")
  defaults$study_contract$description <- paste(
    "Validation-only nested cell-specific MCMC discovery view. Candidate selection",
    "must aggregate across both calibration origins, both reservoir seeds, and both",
    "MCMC seed replicates. Raw rows are not article-facing."
  )
  defaults$study_contract$source_registry_hash_value <- source_hash
  defaults$study_contract$budget$posterior_metric_draws <- 100L
  defaults$study_contract$budget$mcmc_n_burn <- 2000L
  defaults$study_contract$budget$mcmc_n_mcmc <- 8000L
  defaults$study_contract$budget$mcmc_thin <- 1L
  defaults$study_contract$nested_cellwise_v1 <- list(
    calibration_origin = as.integer(origin),
    calibration_view = view_id,
    source_registry_hash_value = source_hash,
    target_cells = 15L,
    designs_per_cell = 12L,
    reservoir_seeds_per_design = 2L,
    mcmc_seed_reps = 2L,
    selected_roots = length(selected_specs),
    article_update_policy = "never update the article from discovery rows"
  )
  defaults$runtime$threads <- 1L
  defaults$runtime$workers <- max(1L, workers %/% 2L)
  defaults$runtime$campaign_workers <- max(1L, workers %/% 2L)
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$pipeline$inference$mcmc$n_burn <- 2000L
  defaults$pipeline$inference$mcmc$n_mcmc <- 8000L
  defaults$pipeline$inference$mcmc$thin <- 1L
  defaults$pipeline$inference$mcmc$progress_every <- 50L
  defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
  defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 2000L
  defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 8000L
  defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
  defaults$pipeline$outputs$keep_draws <- FALSE
  defaults$pipeline$outputs$save_forecast_objects <- FALSE
  defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
  defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
  defaults$multiseed <- defaults$multiseed %||% list()
  defaults$multiseed$enabled <- TRUE
  defaults$multiseed$mcmc_seed_reps <- 2L
  defaults$multiseed$parallel_seed_workers <- 1L
  defaults$multiseed$selection_metric <- "train_qtrue_rmse"
  defaults$multiseed$prune_nonwinning_heavy_outputs <- TRUE
  defaults$multiseed$prune_rel_paths <- as.list(c(
    "models/forecast_objects.rds", "models/rhs_trace.rds", "models/timing_summary.rds"
  ))
  defaults$smoke$family <- unresolved$family[[1L]]
  defaults$smoke$tau <- as.numeric(unresolved$tau[[1L]])
  defaults$smoke$fit_sizes <- 500L
  defaults$smoke$priors <- as.list("rhs_ns")
  defaults$smoke$max_roots <- 1L
  defaults$smoke$screening_profile_ids <- as.list(profiles$screening_profile_id[[1L]])
  defaults$smoke$budget$mcmc_n_burn <- 4L
  defaults$smoke$budget$mcmc_n_mcmc <- 4L
  defaults$smoke$budget$mcmc_thin <- 1L
  defaults$smoke$pipeline$inference$mcmc$n_burn <- 4L
  defaults$smoke$pipeline$inference$mcmc$n_mcmc <- 4L
  defaults$smoke$pipeline$inference$mcmc$thin <- 1L
  defaults$smoke$pipeline$inference$mcmc$progress_every <- 1L
  defaults$execution$allowed_fit_spec_ids <- as.list(selected_specs)
  yaml::write_yaml(defaults, path)
  defaults
}

view_rows <- list()
tracked_paths <- character(0)
for (origin in c(7000L, 8000L)) {
  view_id <- paste0("origin", origin)
  stage <- paste0(stage_base, "_", view_id)
  base_view_path <- file.path("config", "validation", paste0(stage, "_base_defaults.yaml"))
  defaults_out <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
  profiles_out <- file.path("config", "validation", paste0(stage, "_profiles.csv"))
  assignments_out <- file.path("config", "validation", paste0(stage, "_cell_assignments.csv"))
  grid_out <- file.path("config", "validation", paste0(stage, "_grid.csv"))
  target_specs_out <- file.path("config", "validation", paste0(stage, "_target_spec_ids.csv"))

  base <- yaml::read_yaml(base_defaults_path)
  base$source_materialization$staged_root <- file.path(
    "results", "qdesn_mcmc_validation",
    paste0("dynamic_fitforecast_v2_qdesn_sources_nested_origin", origin, "_period90_m90_w300")
  )
  base$source_materialization$train_end_source_index <- origin
  base$source_materialization$forecast_origin_source_index <- origin
  label <- sprintf("effTT500_totalTT1890_trainEnd%d_H1000_m90_w300_period90", origin)
  base$source_materialization$windows[[1L]]$source_dir_name <- paste0("fit_input_", label)
  base$source_materialization$windows[[1L]]$label <- label
  yaml::write_yaml(base, base_view_path)

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_view_path,
    profiles_out = profiles_out,
    assignments_out = assignments_out,
    defaults_out = defaults_out,
    grid_out = grid_out,
    workers = max(1L, workers %/% 2L),
    refresh_grid = TRUE,
    refresh_materialized = refresh_materialized,
    stage_stub = stage,
    stage_desc = sprintf(
      "Q-DESN/exQ-DESN 500-observation nested cellwise MCMC calibration view at origin %d.",
      origin
    ),
    stage = "mcmc_nested_cellwise_v1_discovery",
    priors = "rhs_ns"
  )
  defaults <- yaml::read_yaml(defaults_out)
  grid <- read_csv(grid_out)
  if (nrow(grid) != 360L ||
      any(as.integer(grid$train_end_source_index) != origin) ||
      any(as.integer(grid$forecast_start_source_index) != origin + 1L) ||
      any(as.integer(grid$forecast_end_source_index) != origin + 1000L)) {
    stop(sprintf("Calibration view %s failed source-window materialization.", view_id), call. = FALSE)
  }
  spec_grid <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    grid,
    defaults,
    methods = "mcmc",
    likelihood_families = c("al", "exal")
  )
  assignments_local <- read_csv(assignments_out)
  assignments_local$target_key <- paste(
    assignments_local$screening_profile_id,
    assignments_local$family,
    fmt_tau(assignments_local$tau),
    assignments_local$likelihood_target,
    sep = "|"
  )
  spec_grid$target_key <- paste(
    spec_grid$screening_profile_id,
    spec_grid$family,
    fmt_tau(spec_grid$tau),
    spec_grid$likelihood_family,
    sep = "|"
  )
  target_specs <- merge(assignments_local, spec_grid, by = "target_key", all.x = TRUE, sort = FALSE)
  if (nrow(target_specs) != 360L || any(is.na(target_specs$spec_id)) || anyDuplicated(target_specs$spec_id)) {
    stop(sprintf("Calibration view %s did not produce 360 unique atomic specs.", view_id), call. = FALSE)
  }
  defaults <- configure_defaults(defaults_out, origin, view_id, as.character(target_specs$spec_id))
  target_specs_path <- write_csv(target_specs, target_specs_out)
  view_rows[[length(view_rows) + 1L]] <- data.frame(
    view_id = view_id,
    calibration_origin_source_index = origin,
    train_start_source_index = origin - 499L,
    train_end_source_index = origin,
    forecast_start_source_index = origin + 1L,
    forecast_end_source_index = origin + 1000L,
    selected_roots = nrow(target_specs),
    mcmc_seed_reps = 2L,
    defaults_path = resolve_path(defaults_out),
    grid_path = resolve_path(grid_out),
    target_specs_path = resolve_path(target_specs_out),
    stringsAsFactors = FALSE
  )
  tracked_paths <- c(
    tracked_paths,
    base_view_path, defaults_out, profiles_out, assignments_out, grid_out, target_specs_out
  )
}
view_registry <- exdqlm:::.qdesn_validation_bind_rows(view_rows)

history_inventory <- data.frame(
  profile_catalog_path = normalizePath(profile_paths, winslash = "/", mustWork = TRUE),
  profile_catalog_sha256 = vapply(profile_paths, sha256, character(1L)),
  profile_rows = vapply(profile_rows, nrow, integer(1L)),
  stringsAsFactors = FALSE
)
history_summary <- data.frame(
  catalog_count = length(profile_paths),
  catalog_rows = nrow(history_profiles),
  unique_numeric_designs = length(unique(history_profiles$numeric_signature)),
  current_candidate_ledger_rows = nrow(parent_ledger),
  current_envelope_rows = nrow(parent_envelope),
  current_qdesn_envelope_rows = sum(grepl("^qdesn_", parent_envelope$model_variant)),
  current_qdesn_mixed_metric_rows = sum(
    grepl("^qdesn_", parent_envelope$model_variant) & parent_envelope$metric_source_mixed
  ),
  stringsAsFactors = FALSE
)
design_summary <- data.frame(
  promotion_id = promotion_id,
  stage_base = stage_base,
  branch = trimws(system("git branch --show-current", intern = TRUE)),
  materialization_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_registry_hash_value = source_hash,
  target_cells = 15L,
  designs_per_cell = 12L,
  reservoir_seeds_per_design = 2L,
  calibration_origins = 2L,
  selected_roots_total = sum(view_registry$selected_roots),
  mcmc_seed_reps_per_root = 2L,
  planned_chain_fits = sum(view_registry$selected_roots) * 2L,
  mcmc_n_burn = 2000L,
  mcmc_n_mcmc = 8000L,
  workers_total_cap = workers,
  launch_status = "materialized_pending_prepare_smoke_full",
  article_update_policy = "no raw discovery result is article-facing",
  stringsAsFactors = FALSE
)

promotion_paths <- c(
  summary = write_csv(
    design_summary,
    file.path(promotion_root, paste0(promotion_id, "_summary.csv"))
  ),
  view_registry = write_csv(
    view_registry,
    file.path(promotion_root, paste0(promotion_id, "_calibration_view_registry.csv"))
  ),
  profiles = write_csv(
    profiles,
    file.path(promotion_root, paste0(promotion_id, "_candidate_profiles.csv"))
  ),
  assignments = write_csv(
    assignments,
    file.path(promotion_root, paste0(promotion_id, "_candidate_assignments.csv"))
  ),
  nonrepeat = write_csv(
    nonrepeat_audit,
    file.path(promotion_root, paste0(promotion_id, "_exact_repeat_audit.csv"))
  ),
  history_inventory = write_csv(
    history_inventory,
    file.path(promotion_root, paste0(promotion_id, "_history_catalog_inventory.csv"))
  ),
  history_summary = write_csv(
    history_summary,
    file.path(promotion_root, paste0(promotion_id, "_history_summary.csv"))
  ),
  unresolved = write_csv(
    unresolved,
    file.path(promotion_root, paste0(promotion_id, "_target_cells.csv"))
  )
)

doc_path <- file.path(
  "validation", "fitforecast_v2", "docs",
  "QDESN_500OBS_MCMC_NESTED_CELLWISE_V1_PLAN_2026-07-29.md"
)
doc <- c(
  "# Q-DESN 500-Observation Nested Cellwise MCMC Calibration v1",
  "",
  sprintf("- Stage base: `%s`", stage_base),
  sprintf("- Source registry SHA-256: `%s`", source_hash),
  "- Scope: independent Q-DESN/exQ-DESN RHS validation only.",
  "- Calibration unit: model variant x family x quantile x likelihood.",
  "- Article policy: no raw discovery result is article-facing.",
  "",
  "## Design",
  "",
  "- 15 unresolved cells.",
  "- 12 cell-specific designs per cell: 2 declared anchors and 10 novel compact designs.",
  "- 2 reservoir-topology seeds per design.",
  "- 2 MCMC seed replicates per root.",
  paste(
    "- The unmodified 1.0.0 multiseed adapter changes DESN and MCMC RNG seeds",
    "together; these are coupled stochastic replicates, not a factorial variance decomposition."
  ),
  "- Calibration origins 7000 and 8000; final origin 9000 is excluded from discovery.",
  "- MCMC budget: 2,000 burn-in plus 8,000 retained iterations.",
  "- Full planned discovery workload: 720 roots and 1,440 chain fits.",
  "",
  "## Automatic gates",
  "",
  "1. Frozen source hash and source-window verification.",
  "2. Target-aware exact-repeat audit; repeats allowed only for declared anchors.",
  "3. Prepare-only manifests for both calibration origins.",
  "4. One-root smoke for each calibration origin.",
  "5. Detached full launches with a combined outer-worker cap of 16.",
  "6. Closeout must aggregate both origins and all seed replicates.",
  "7. Final-origin confirmation is a separate, gated stage.",
  "",
  "## Promotion",
  "",
  "- Discovery candidates are compared with declared anchors rerun on the same calibration views.",
  "- Final-origin parent metrics are provenance context, not discovery-stage denominators.",
  "- Fit RMSE requires at least 3% replicated improvement.",
  "- Forecast MAE requires at least 5% replicated improvement.",
  "- Check loss requires at least 1% replicated improvement.",
  "- Metric-wise envelopes remain diagnostic.",
  "- Article rows require one coherent confirmed specification.",
  "",
  "## Storage",
  "",
  "- Keep scalar metrics, compact paths, manifests, logs, status, and seed summaries.",
  "- Do not retain routine successful `.rds`, `.rda`, or `.RData` payloads.",
  "",
  "## Commands",
  "",
  "```bash",
  "Rscript validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_nested_cellwise_v1_20260729.R --workers 16",
  "Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_cellwise_v1.R --prepare-only --smoke --skip-materialize --workers 16",
  "Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_cellwise_v1.R --full --launch-approved --skip-materialize --skip-prepare --skip-smoke --workers 16",
  "```",
  "",
  "After both full campaigns are terminal, run the closeout with their exact run tags:",
  "",
  "```bash",
  "Rscript scripts/closeout_qdesn_500obs_mcmc_nested_cellwise_v1.R \\",
  "  --origin7000-run-tag <origin7000-run-tag> \\",
  "  --origin8000-run-tag <origin8000-run-tag>",
  "```"
)
dir.create(dirname(doc_path), recursive = TRUE, showWarnings = FALSE)
writeLines(doc, doc_path, useBytes = TRUE)
implementation_paths <- c(
  "validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_nested_cellwise_v1_20260729.R",
  "scripts/orchestrate_qdesn_500obs_mcmc_nested_cellwise_v1.R",
  "scripts/closeout_qdesn_500obs_mcmc_nested_cellwise_v1.R",
  "validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-nested-cellwise-v1-design.R"
)
invisible(lapply(implementation_paths, resolve_path, must_work = TRUE))
tracked_paths <- c(tracked_paths, doc_path, implementation_paths)

source_manifest <- data.frame(
  role = c("parent_unresolved", "parent_envelope", "parent_candidate_ledger", "base_defaults"),
  path = normalizePath(
    c(unresolved_path, parent_envelope_path, parent_ledger_path, base_defaults_path),
    winslash = "/",
    mustWork = TRUE
  ),
  stringsAsFactors = FALSE
)
source_manifest$sha256 <- vapply(source_manifest$path, sha256, character(1L))
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

file_paths <- normalizePath(
  c(tracked_paths, unname(promotion_paths), source_manifest_path, doc_path),
  winslash = "/",
  mustWork = TRUE
)
file_manifest <- data.frame(
  path = unique(file_paths),
  size_bytes = file.info(unique(file_paths))$size,
  sha256 = vapply(unique(file_paths), sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  promotion_id = promotion_id,
  stage_base = stage_base,
  source_registry_hash_value = source_hash,
  target_cells = 15L,
  profiles = nrow(profiles),
  calibration_views = nrow(view_registry),
  selected_roots_total = sum(view_registry$selected_roots),
  planned_chain_fits = sum(view_registry$selected_roots) * 2L,
  workers_total_cap = workers,
  source_manifest = source_manifest_path,
  file_manifest = file_manifest_path,
  documentation = resolve_path(doc_path),
  article_update_policy = "no raw discovery result is article-facing"
)
manifest_path <- write_json(
  manifest,
  file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
)

heavy <- system(
  sprintf(
    "find %s %s -type f \\( -name '*.rds' -o -name '*.rda' -o -name '*.RData' -o -name '__design.rds' \\) -print",
    shQuote(resolve_path(promotion_root)),
    paste(shQuote(vapply(view_registry$defaults_path, dirname, character(1L))), collapse = " ")
  ),
  intern = TRUE
)
if (length(heavy)) {
  stop(sprintf("Forbidden heavy artifacts detected in tracked design roots: %s", paste(heavy, collapse = ", ")), call. = FALSE)
}

cat(sprintf("promotion_root: %s\n", resolve_path(promotion_root)))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("profiles: %d\n", nrow(profiles)))
cat(sprintf("selected_roots_total: %d\n", sum(view_registry$selected_roots)))
cat(sprintf("planned_chain_fits: %d\n", sum(view_registry$selected_roots) * 2L))
