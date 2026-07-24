#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

tau_key <- function(x) sprintf("%.8f", as.numeric(x))
tau_label <- function(x) sub("0+$", "", sub("[.]$", "", sprintf("%.2f", as.numeric(x))))
slug_num <- function(x) {
  raw <- format(as.numeric(x), scientific = TRUE, digits = 8, trim = TRUE)
  raw <- gsub("\\+", "", raw)
  raw <- gsub("-", "m", raw)
  raw <- gsub("\\.", "p", raw)
  raw <- gsub("e", "e", raw)
  raw
}

md_table <- function(x, cols, max_rows = 60L) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- vapply(y[i, , drop = TRUE], function(v) {
      v <- as.character(v)
      v[is.na(v)] <- ""
      gsub("\n", " ", v, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}

stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1"
))[1L]
workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
workers <- min(workers, 24L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_defaults.yaml")
))
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
target_specs_out <- resolve_path(get_arg("--target-specs-out", file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv"))), must_work = FALSE)
manifest_out <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")), must_work = FALSE)

families <- c("gausmix", "laplace", "normal")
taus <- c(0.05, 0.25, 0.50)
scenario <- "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
source_window_label <- "effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90"
source_dir_name <- "fit_input_effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90"
staged_root <- file.path("results", "qdesn_mcmc_validation", "dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300")

targets <- data.frame(
  cell_id = c(
    "gm005x", "gm025x", "gm050a", "gm050x",
    "lp050a", "lp050x",
    "nm005a", "nm025x", "nm050a", "nm050x"
  ),
  family = c(
    "gausmix", "gausmix", "gausmix", "gausmix",
    "laplace", "laplace",
    "normal", "normal", "normal", "normal"
  ),
  tau = c(0.05, 0.25, 0.50, 0.50, 0.50, 0.50, 0.05, 0.25, 0.50, 0.50),
  likelihood_target = c("exal", "exal", "al", "exal", "al", "exal", "al", "exal", "al", "exal"),
  target_class = c(
    "current_protocol_exal_refresh",
    "missing_clean_current_exal",
    "median_forecast_gap",
    "median_forecast_gap_current_exal_refresh",
    "median_forecast_gap",
    "median_forecast_gap_current_exal_refresh",
    "tail_al_gap",
    "missing_clean_current_exal",
    "median_forecast_gap",
    "median_forecast_gap_current_exal_refresh"
  ),
  priority_rank = c(3L, 1L, 6L, 5L, 8L, 7L, 4L, 2L, 10L, 9L),
  stringsAsFactors = FALSE
)
targets <- targets[order(targets$priority_rank), , drop = FALSE]

anchor <- data.frame(
  cell_id = targets$cell_id,
  D = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  n_each = c(8L, 4L, 25L, 25L, 25L, 25L, 30L, 6L, 30L, 30L)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  m = c(1L, 2L, 15L, 15L, 30L, 30L, 15L, 1L, 15L, 15L)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  alpha = c(0.0005, 0.0010, 0.0010, 0.0010, 0.0010, 0.0010, 0.0300, 0.00075, 0.0200, 0.0200)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  rho = c(0.35, 0.45, 0.45, 0.45, 0.50, 0.50, 0.50, 0.35, 0.45, 0.45)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  pi_w = c(0.00075, 0.0025, 0.0100, 0.0100, 0.0200, 0.0200, 0.0300, 0.0025, 0.0300, 0.0300)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  pi_in = c(0.03, 0.05, 0.20, 0.20, 0.20, 0.20, 0.30, 0.05, 0.30, 0.30)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  rhs_tau0 = c(3e-7, 3e-4, 3e-4, 3e-4, 3e-4, 3e-4, 1e-4, 3e-4, 1e-4, 1e-4)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  seed = c(123L, 42083L, 43092L, 43093L, 52092L, 52093L, 123L, 62472L, 63230L, 63231L)[match(targets$cell_id, c("gm005x", "gm025x", "gm050a", "gm050x", "lp050a", "lp050x", "nm005a", "nm025x", "nm050a", "nm050x"))],
  stringsAsFactors = FALSE
)

generic_arms <- data.frame(
  arm_id = c(
    "b_d1_mem12",
    "c_d1_mem36_lowtau",
    "d_d1_mem90_highrho",
    "e_d2_mem24",
    "f_d2_mem60_lowtau",
    "g_d2_mem90_highrho",
    "h_d3_mem45_wide_lowtau"
  ),
  arm_role = c(
    "medium memory shallow stability check",
    "wider shallow low-tau memory expansion",
    "long-memory high-rho low-alpha challenge",
    "bounded depth-two medium-memory expansion",
    "depth-two longer-memory low-tau expansion",
    "depth-two long-memory high-rho challenge",
    "depth-three width/memory expansion inside p/n gate"
  ),
  D = c(1L, 1L, 1L, 2L, 2L, 2L, 3L),
  n_each = c(20L, 36L, 24L, 20L, 36L, 36L, 40L),
  m = c(12L, 36L, 90L, 24L, 60L, 90L, 45L),
  alpha = c(0.0025, 0.0075, 0.0005, 0.0025, 0.0075, 0.00075, 0.0025),
  rho = c(0.65, 0.75, 0.85, 0.65, 0.75, 0.85, 0.80),
  pi_w = c(0.0050, 0.0100, 0.0025, 0.0050, 0.0100, 0.0025, 0.0050),
  pi_in = c(0.10, 0.15, 0.05, 0.10, 0.15, 0.05, 0.10),
  rhs_tau0 = c(1e-4, 3e-5, 1e-6, 3e-5, 1e-5, 3e-6, 1e-6),
  seed_offset = seq(10L, 70L, by = 10L),
  stringsAsFactors = FALSE
)

make_profile <- function(profile_id, screening_wave, profile_role, D, n_each, m, alpha, rho, pi_w, pi_in, rhs_tau0, seed) {
  row <- exdqlm:::qdesn_dynamic_fitforecast_profile_row(
    D = D,
    n_each = n_each,
    alpha = alpha,
    rho = rho,
    screening_stage = "mcmc_rhs_targeted_repair_v1",
    screening_wave = screening_wave,
    profile_role = profile_role,
    rhs_tau0 = rhs_tau0,
    m = m,
    pi_w = pi_w,
    pi_in = pi_in,
    washout = 300L,
    add_bias = TRUE,
    seed = seed,
    readout_y_lags = m,
    reservoir_lags = 0L,
    include_tau0_suffix = TRUE
  )
  row$screening_profile_id <- profile_id
  row$x_feature_count <- 5L
  row
}

screening_wave <- paste0("mcmc_rhs_targeted_repair_v1_", format(Sys.Date(), "%Y_%m_%d"))
profile_rows <- list()
assignment_rows <- list()

for (i in seq_len(nrow(targets))) {
  cell <- targets[i, , drop = FALSE]
  anchor_i <- anchor[anchor$cell_id == cell$cell_id, , drop = FALSE]
  arm_specs <- rbind(
    data.frame(
      arm_id = "a_current_anchor",
      arm_role = paste("current compact anchor for", cell$target_class),
      D = anchor_i$D,
      n_each = anchor_i$n_each,
      m = anchor_i$m,
      alpha = anchor_i$alpha,
      rho = anchor_i$rho,
      pi_w = anchor_i$pi_w,
      pi_in = anchor_i$pi_in,
      rhs_tau0 = anchor_i$rhs_tau0,
      seed_offset = 0L,
      stringsAsFactors = FALSE
    ),
    generic_arms
  )
  for (j in seq_len(nrow(arm_specs))) {
    arm <- arm_specs[j, , drop = FALSE]
    seed <- if (arm$arm_id == "a_current_anchor") {
      as.integer(anchor_i$seed)
    } else {
      as.integer(82000L + cell$priority_rank * 100L + arm$seed_offset)
    }
    profile_id <- sprintf("mcrv1_%s_%s", cell$cell_id, arm$arm_id)
    role <- sprintf("%s__%s", cell$target_class, arm$arm_role)
    profile_rows[[length(profile_rows) + 1L]] <- make_profile(
      profile_id = profile_id,
      screening_wave = screening_wave,
      profile_role = role,
      D = arm$D,
      n_each = arm$n_each,
      m = arm$m,
      alpha = arm$alpha,
      rho = arm$rho,
      pi_w = arm$pi_w,
      pi_in = arm$pi_in,
      rhs_tau0 = arm$rhs_tau0,
      seed = seed
    )
    assignment_rows[[length(assignment_rows) + 1L]] <- data.frame(
      assignment_key = paste(profile_id, cell$family, tau_key(cell$tau), sep = "\r"),
      assignment_id = sprintf("mcrv1_%04d", length(assignment_rows) + 1L),
      family = cell$family,
      tau = cell$tau,
      likelihood_target = cell$likelihood_target,
      cell_status = cell$target_class,
      priority_rank = cell$priority_rank,
      target_profile_rank = j,
      screening_profile_id = profile_id,
      source_profile = if (arm$arm_id == "a_current_anchor") "current_best_or_failed_profile_anchor" else "new_diversified_arm",
      candidate_source = if (arm$arm_id == "a_current_anchor") "current_mcmc_evidence_anchor" else "designed_diversified_mcmc_arm",
      selection_reason = arm$arm_role,
      source_worst_ratio = NA_real_,
      vb_forecast_mae_ratio = NA_real_,
      vb_forecast_check_ratio = NA_real_,
      vb_fit_rmse_ratio = NA_real_,
      vb_fit_check_ratio = NA_real_,
      bottleneck_metric = if (grepl("median", cell$target_class)) "forecast_mae_median_gap" else "mcmc_clean_or_tail_gap",
      source_path = NA_character_,
      stringsAsFactors = FALSE
    )
  }
}

profiles <- do.call(rbind, profile_rows)
assignments <- do.call(rbind, assignment_rows)
profiles$target_cells <- vapply(profiles$screening_profile_id, function(pid) {
  rows <- assignments[assignments$screening_profile_id == pid, , drop = FALSE]
  paste(unique(paste(rows$family, tau_label(rows$tau), rows$likelihood_target, sep = ":")), collapse = ";")
}, character(1L))
profiles <- profiles[, c(
  "screening_profile_id", "screening_stage", "screening_wave", "profile_role",
  "enabled", "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "washout", "add_bias", "seed", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "x_feature_count",
  "target_cells"
), drop = FALSE]

cell_plan <- aggregate(
  list(n_profiles = assignments$screening_profile_id),
  by = list(
    family = assignments$family,
    tau = assignments$tau,
    likelihood_target = assignments$likelihood_target,
    cell_status = assignments$cell_status,
    priority_rank = assignments$priority_rank
  ),
  FUN = length
)
cell_plan <- cell_plan[order(cell_plan$priority_rank), , drop = FALSE]
cell_plan$target_profiles <- vapply(seq_len(nrow(cell_plan)), function(i) {
  rows <- assignments[
    assignments$family == cell_plan$family[[i]] &
      abs(assignments$tau - cell_plan$tau[[i]]) < 1e-8 &
      assignments$likelihood_target == cell_plan$likelihood_target[[i]],
    ,
    drop = FALSE
  ]
  paste(rows$screening_profile_id, collapse = ";")
}, character(1L))

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

base_defaults <- yaml::read_yaml(base_defaults_path)
base_defaults$source_materialization <- base_defaults$source_materialization %||% list()
base_defaults$source_materialization$families <- as.list(families)
base_defaults$source_materialization$taus <- as.list(taus)
base_defaults$source_materialization$scenarios <- scenario
base_defaults$source_materialization$staged_root <- staged_root
base_defaults$source_materialization$windows <- list(list(
  effective_fit_size = 500L,
  source_total_size = 1890L,
  source_dir_name = source_dir_name,
  label = source_window_label
))
base_defaults$reference_contract <- base_defaults$reference_contract %||% list()
base_defaults$reference_contract$scenarios <- scenario
base_defaults$reference_contract$families <- as.list(families)
base_defaults$reference_contract$taus <- as.list(taus)
base_defaults$reference_contract$fit_sizes <- 500L
base_defaults$reference_contract$expected_unique_dataset_cells <- 9L
base_defaults$screening_profiles <- base_defaults$screening_profiles %||% list()
base_defaults$screening_profiles$canonical_dataset_cell_count <- 9L
extended_base_defaults_path <- file.path(diag_manifest, "qdesn_tt500_mcmc_rhs_targeted_repair_v1_extended_base_defaults.yaml")
yaml::write_yaml(base_defaults, extended_base_defaults_path)

selected_candidates_path <- write_csv(assignments, file.path(diag_tables, "qdesn_tt500_mcmc_rhs_targeted_repair_v1_selected_assignments.csv"))
cell_plan_path <- write_csv(cell_plan, file.path(diag_tables, "qdesn_tt500_mcmc_rhs_targeted_repair_v1_cell_plan.csv"))
arm_catalog_path <- write_csv(generic_arms, file.path(diag_tables, "qdesn_tt500_mcmc_rhs_targeted_repair_v1_arm_catalog.csv"))
target_catalog_path <- write_csv(targets, file.path(diag_tables, "qdesn_tt500_mcmc_rhs_targeted_repair_v1_target_catalog.csv"))

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    stage_file = stage_file,
    selection_policy = "Targeted MCMC repair: preserve current compact anchors and add diversified, bounded DESN arms inside the frozen period90/m90/w300 source contract.",
    targets = targets,
    arm_catalog = generic_arms
  )
)

mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = extended_base_defaults_path,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  stage_stub = stage_file,
  stage_desc = "Q-DESN 500-observation targeted full-MCMC RHS repair with compact anchors plus diversified DESN arms.",
  stage = "mcmc_rhs_targeted_repair_v1",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$study_contract$id <- paste0(stage_file, "_", format(Sys.Date(), "%Y_%m_%d"))
defaults$study_contract$description <- "Full MCMC targeted repair for selected independent Q-DESN/exQ-DESN RHS cell-likelihood gaps. This is not article-facing until strict audit and explicit promotion."
defaults$study_contract$budget$posterior_metric_draws <- 200L
defaults$study_contract$budget$vb_sampling_nd_draws <- 200L
defaults$study_contract$budget$vb_synthesis_n_samp <- 200L
defaults$study_contract$budget$mcmc_n_burn <- 5000L
defaults$study_contract$budget$mcmc_n_mcmc <- 20000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$mcmc <- defaults$study_contract$mcmc %||% list()
defaults$study_contract$mcmc$require_init_from_vb <- TRUE
defaults$reference_contract$families <- as.list(families)
defaults$reference_contract$taus <- as.list(taus)
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- nrow(profiles) * 9L
defaults$reference_contract$expected_selected_qdesn_roots <- length(unique(assignments$assignment_key))
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_dataset_cell_count <- 9L
defaults$screening_profiles$canonical_qdesn_root_count <- nrow(profiles) * 9L
defaults$screening_profiles$selected_assignment_root_count <- length(unique(assignments$assignment_key))
defaults$screening_profiles$design <- sprintf(
  "Targeted RHS MCMC repair v1: %d target cell-likelihoods, %d arms each, %d selected roots.",
  nrow(cell_plan), nrow(profiles) / nrow(cell_plan), length(unique(assignments$assignment_key))
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$pilot$source_family <- as.character(assignments$family[[1L]])
defaults$pilot$tau <- as.numeric(assignments$tau[[1L]])
defaults$smoke$family <- as.character(assignments$family[[1L]])
defaults$smoke$tau <- as.numeric(assignments$tau[[1L]])
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$screening_profile_ids <- as.list(as.character(assignments$screening_profile_id[[1L]]))
defaults$smoke$max_roots <- 1L
defaults$smoke$budget <- list(
  posterior_metric_draws = 4L,
  vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L,
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
defaults$smoke$pipeline <- list(
  inference = list(
    mcmc = list(n_burn = 4L, n_mcmc = 4L, thin = 1L, progress_every = 1L, init_from_vb = TRUE)
  )
)
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "mcmc_primary_metric_table",
  prune_nonwinning_heavy_outputs = TRUE
)
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
yaml::write_yaml(defaults, defaults_out)

defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_out)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded,
  refresh_materialized = refresh_materialized,
  verbose = FALSE
)
canonical_key <- paste(
  canonical_grid$screening_profile_id,
  canonical_grid$source_family,
  tau_key(canonical_grid$tau),
  sep = "\r"
)
assignment_keys <- unique(assignments$assignment_key)
selected_mask <- canonical_key %in% assignment_keys
missing_assignment_keys <- setdiff(assignment_keys, canonical_key)
if (length(missing_assignment_keys)) {
  stop(
    sprintf("Final canonical grid is missing %d selected assignment key(s), including `%s`.", length(missing_assignment_keys), missing_assignment_keys[[1L]]),
    call. = FALSE
  )
}
grid <- canonical_grid[selected_mask, , drop = FALSE]
grid$key_for_assignment <- canonical_key[selected_mask]
grid <- grid[order(grid$source_family, grid$tau, grid$screening_profile_id), , drop = FALSE]
root_lookup <- grid[, c("key_for_assignment", "root_id"), drop = FALSE]
names(root_lookup)[[1L]] <- "assignment_key"
grid$key_for_assignment <- NULL
write_csv(grid, grid_out)

assignments_after <- merge(assignments, root_lookup, by = "assignment_key", all.x = TRUE, sort = FALSE)
if (any(!nzchar(as.character(assignments_after$root_id)))) {
  stop("Failed to attach final canonical root IDs to one or more selected assignments.", call. = FALSE)
}
assignments_after <- assignments_after[order(assignments_after$priority_rank, assignments_after$target_profile_rank), , drop = FALSE]
write_csv(assignments_after, assignments_out)

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults = defaults_loaded,
  methods = defaults_loaded$execution$methods %||% "mcmc",
  likelihood_families = defaults_loaded$execution$likelihood_families %||% c("al", "exal")
)
target_map <- assignments_after[, c("assignment_key", "root_id", "family", "tau", "likelihood_target", "screening_profile_id", "candidate_source", "selection_reason"), drop = FALSE]
target_specs <- merge(
  target_map,
  atomic,
  by.x = c("root_id", "likelihood_target"),
  by.y = c("root_id", "likelihood_family"),
  all.x = TRUE,
  sort = FALSE
)
if (any(!nzchar(as.character(target_specs$spec_id)))) {
  stop("Failed to resolve one or more target MCMC atomic spec IDs.", call. = FALSE)
}
target_specs <- target_specs[order(target_specs$family.x, target_specs$tau.x, target_specs$likelihood_target, target_specs$screening_profile_id.x), , drop = FALSE]
target_specs_out <- write_csv(target_specs, target_specs_out)
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_out)

summary_path <- file.path(diag_summary, "qdesn_tt500_mcmc_rhs_targeted_repair_v1.md")
summary_lines <- c(
  "# Q-DESN 500-Observation MCMC RHS Targeted Repair v1",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- extended_base_defaults_path: `%s`", normalizePath(extended_base_defaults_path, winslash = "/", mustWork = TRUE)),
  sprintf("- workers: `%d`", workers),
  sprintf("- target_cell_likelihoods: `%d`", nrow(cell_plan)),
  sprintf("- arms_per_target: `%d`", nrow(profiles) / nrow(cell_plan)),
  sprintf("- selected_roots: `%d`", length(unique(assignments_after$root_id))),
  sprintf("- target_mcmc_atomic_specs: `%d`", nrow(target_specs)),
  "",
  "## Design Rationale",
  "",
  "This stage keeps the current compact anchor for each target cell-likelihood and adds bounded new arms that explore depth, width, memory, low-alpha/high-rho persistence, and tighter RHS tau0 values. The design intentionally stays within the frozen period90/m90/w300 source contract; m/readout lags above 90 require a separate source-registry extension and are not mixed into this run.",
  "",
  "## Target Cell-Likelihoods",
  "",
  md_table(cell_plan, c("family", "tau", "likelihood_target", "cell_status", "priority_rank", "n_profiles"), max_rows = 20L),
  "",
  "## Arm Catalog",
  "",
  md_table(rbind(
    data.frame(arm_id = "a_current_anchor", arm_role = "cell-specific current compact anchor", D = NA, n_each = NA, m = NA, alpha = NA, rho = NA, rhs_tau0 = NA, stringsAsFactors = FALSE),
    generic_arms[, c("arm_id", "arm_role", "D", "n_each", "m", "alpha", "rho", "rhs_tau0"), drop = FALSE]
  ), c("arm_id", "arm_role", "D", "n_each", "m", "alpha", "rho", "rhs_tau0"), max_rows = 12L),
  "",
  "## Gates",
  "",
  "- Full MCMC: `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`, `progress_every = 50`.",
  "- MCMC initialization: `init_from_vb = TRUE` and `require_init_from_vb = TRUE`.",
  "- Storage policy: no successful draw/forecast-object retention; compact fit paths and scalar metrics only.",
  "- Article policy: not article-facing until completion, strict audit, and explicit promotion.",
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- target_specs: `%s`", target_specs_out)
)
writeLines(summary_lines, summary_path, useBytes = TRUE)
summary_path <- normalizePath(summary_path, winslash = "/", mustWork = TRUE)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  design_contract = list(
    source_contract = "period90/m90/w300 frozen source inputs",
    m_max = max(profiles$m),
    workers = workers,
    mcmc_n_burn = 5000L,
    mcmc_n_mcmc = 20000L,
    mcmc_progress_every = 50L,
    init_from_vb = TRUE,
    storage_light = TRUE
  ),
  counts = list(
    target_cell_likelihoods = nrow(cell_plan),
    arms_per_target = nrow(profiles) / nrow(cell_plan),
    profiles = nrow(profiles),
    assignments = nrow(assignments_after),
    selected_roots = length(unique(assignments_after$root_id)),
    target_mcmc_atomic_specs = nrow(target_specs),
    canonical_grid_rows = nrow(canonical_grid),
    selected_grid_rows = nrow(grid)
  ),
  outputs = list(
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    target_specs = target_specs_out,
    selected_assignments = selected_candidates_path,
    cell_plan = cell_plan_path,
    arm_catalog = arm_catalog_path,
    target_catalog = target_catalog_path,
    summary = summary_path,
    diagnostics = diagnostic_out
  ),
  materializer_return = mat
)
manifest_written <- write_json(manifest, manifest_out)
cat(sprintf("materialization_manifest: %s\n", manifest_written))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("target_specs: %s\n", target_specs_out))
cat(sprintf("target_mcmc_atomic_specs: %d\n", nrow(target_specs)))
