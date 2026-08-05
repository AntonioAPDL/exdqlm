#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_train_only_rebaseline_v1.R"
))

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
write_csv <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "YES", "Y", "1")
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("VB train-only rebaseline requires exdqlm 1.0.0.", call. = FALSE)
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected_scenario <- "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
workers <- suppressWarnings(as.integer(get_arg("--workers", "18")))
if (!is.finite(workers) || workers < 1L || workers > 24L) {
  stop("`--workers` must be between 1 and 24.", call. = FALSE)
}

shared_root <- normalizePath(
  get_arg("--shared-root", "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0"),
  winslash = "/", mustWork = TRUE
)
al_summary_path <- file.path(
  shared_root, "validation", "fitforecast_v2", "promotions",
  "qdesn_tt500_al_rhs_recalibrated_candidate_20260701",
  "qdesn_tt500_al_rhs_recalibrated_candidate_20260701_summary.csv"
)
exal_sources <- list(
  stage3 = list(
    results_root = file.path(
      shared_root, "results", "qdesn_mcmc_validation",
      "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue",
      "qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628",
      "20260628-114648__git-203f47a"
    ),
    run_tag = "qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628"
  ),
  stage4a = list(
    results_root = file.path(
      shared_root, "results", "qdesn_mcmc_validation",
      "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer",
      "qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631",
      "20260629-035305__git-a59c631"
    ),
    run_tag = "qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631"
  ),
  stage4b = list(
    results_root = file.path(
      shared_root, "results", "qdesn_mcmc_validation",
      "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4b_gausmix005_pinball_refinement",
      "qdesn-tt500-vb-stage4b-gausmix005-pinball-full-20260629__git-52a1821",
      "20260629-040813__git-52a1821"
    ),
    run_tag = "qdesn-tt500-vb-stage4b-gausmix005-pinball-full-20260629__git-52a1821"
  )
)
exal_selection <- data.frame(
  source_stage = c("stage3", "stage3", "stage3", "stage4b", "stage4a",
                   "stage4a", "stage4a", "stage4a", "stage4a"),
  family = c("gausmix", "normal", "normal", "gausmix", "gausmix",
             "laplace", "laplace", "laplace", "normal"),
  tau = c(0.25, 0.25, 0.50, 0.05, 0.50, 0.05, 0.25, 0.50, 0.05),
  screening_profile_id = c(
    rep("tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3", 3L),
    "tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3",
    rep("tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3", 4L)
  ),
  stringsAsFactors = FALSE
)

required_inputs <- c(al_summary_path, vapply(exal_sources, `[[`, character(1L), "results_root"))
if (!file.exists(al_summary_path) || any(!dir.exists(required_inputs[-1L]))) {
  stop("One or more historical VB evidence roots are missing.", call. = FALSE)
}

al <- utils::read.csv(al_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
if (nrow(al) != 9L || !all(al$inference == "vb") ||
    !all(al$qdesn_likelihood == "al") || !all(al$model_variant == "rhs_ns")) {
  stop("AL promotion summary is not the expected nine-cell VB contract.", call. = FALSE)
}
al_candidates <- data.frame(
  model_variant = "qdesn_al_rhs_ns",
  family = al$family,
  tau = as.numeric(al$tau),
  likelihood_target = "al",
  legacy_candidate_id = al$root_id,
  legacy_run_tag = al$source_run_tag,
  legacy_profile_id = al$screening_profile_id,
  source_stage = "al_rhs_recalibrated_20260701",
  source_results_root = al$source_results_root,
  source_root_id = al$root_id,
  legacy_fit_qtrue_rmse = as.numeric(al$fit_qtrue_rmse),
  legacy_forecast_qtrue_mae_H1000 = as.numeric(al$forecast_qtrue_mae_lead_weighted),
  legacy_forecast_check_loss_H1000 = as.numeric(al$forecast_pinball_mean_lead_weighted),
  legacy_status = al$status,
  legacy_signoff_grade = al$signoff_grade,
  stringsAsFactors = FALSE
)

exal_candidates <- do.call(rbind, lapply(seq_len(nrow(exal_selection)), function(i) {
  selection <- exal_selection[i, , drop = FALSE]
  source <- exal_sources[[selection$source_stage]]
  report_summary <- sub(
    paste0("^", shared_root, "/results/"),
    paste0(shared_root, "/reports/"),
    file.path(source$results_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")
  )
  if (!file.exists(report_summary)) {
    stop(sprintf("Historical exAL summary is missing: %s", report_summary), call. = FALSE)
  }
  table <- utils::read.csv(report_summary, check.names = FALSE, stringsAsFactors = FALSE)
  selected <- table[
    table$family == selection$family &
      abs(as.numeric(table$tau) - selection$tau) <= 1e-12 &
      table$screening_profile_id == selection$screening_profile_id &
      table$likelihood_family == "exal" & table$method == "vb",
    , drop = FALSE
  ]
  if (nrow(selected) != 1L) {
    stop(sprintf("Expected one exAL source row for %s tau %.2f; found %d.",
                 selection$family, selection$tau, nrow(selected)), call. = FALSE)
  }
  data.frame(
    model_variant = "qdesn_exal_rhs_ns",
    family = selected$family,
    tau = as.numeric(selected$tau),
    likelihood_target = "exal",
    legacy_candidate_id = selected$root_id,
    legacy_run_tag = source$run_tag,
    legacy_profile_id = selected$screening_profile_id,
    source_stage = selection$source_stage,
    source_results_root = source$results_root,
    source_root_id = selected$root_id,
    legacy_fit_qtrue_rmse = as.numeric(selected$train_qtrue_rmse),
    legacy_forecast_qtrue_mae_H1000 = as.numeric(selected$forecast_all_qtrue_mae),
    legacy_forecast_check_loss_H1000 = as.numeric(selected$forecast_all_pinball_mean),
    legacy_status = selected$status,
    legacy_signoff_grade = selected$signoff_grade,
    stringsAsFactors = FALSE
  )
}))

candidates <- rbind(al_candidates, exal_candidates)
candidates <- candidates[order(candidates$model_variant, candidates$family, candidates$tau), ]
rownames(candidates) <- NULL
candidates$candidate_key <- paste(
  candidates$model_variant, candidates$family,
  sprintf("%.8f", candidates$tau), sep = "\r"
)
if (nrow(candidates) != 18L || anyDuplicated(candidates$candidate_key) ||
    !setequal(candidates$model_variant, c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")) ||
    any(!is.finite(candidates$legacy_fit_qtrue_rmse)) ||
    any(!is.finite(candidates$legacy_forecast_qtrue_mae_H1000)) ||
    any(!is.finite(candidates$legacy_forecast_check_loss_H1000))) {
  stop("The 18-cell historical VB candidate contract is incomplete.", call. = FALSE)
}

candidate_rows <- lapply(seq_len(nrow(candidates)), function(i) {
  candidate <- candidates[i, , drop = FALSE]
  request_path <- file.path(
    candidate$source_results_root, "roots", candidate$source_root_id,
    "fits", paste0("vb_", candidate$likelihood_target), "fit_request.json"
  )
  if (!file.exists(request_path)) {
    stop(sprintf("Historical fit request is missing: %s", request_path), call. = FALSE)
  }
  request_path <- normalizePath(request_path, winslash = "/", mustWork = TRUE)
  request <- jsonlite::read_json(request_path, simplifyVector = TRUE)
  cfg <- request$config
  root <- request$root_spec
  if (!("vb" %in% as.character(request$execution$methods)) ||
      !identical(as.character(root$source_family), as.character(candidate$family)) ||
      abs(as.numeric(root$tau) - candidate$tau) > 1e-12 ||
      !identical(as.character(root$likelihood_family),
                 as.character(candidate$likelihood_target)) ||
      as.integer(cfg$split$T_use) != 1890L || as.integer(cfg$split$train_n) != 890L ||
      as.integer(cfg$forecast$horizon) != 30L ||
      as.integer(cfg$forecast$origin_stride) != 30L ||
      isTRUE(cfg$forecast$refit_per_origin %||% FALSE) ||
      as.integer(cfg$inference$vb$max_iter) != 150L ||
      as.integer(cfg$inference$vb$min_iter_elbo) != 40L ||
      as.integer(cfg$inference$vb$n_samp_xi) != 500L) {
    stop(sprintf("Historical VB request violates the replay contract: %s", request_path),
         call. = FALSE)
  }
  D <- as.integer(cfg$desn$D)
  n_each <- qdesn_tor1_scalar_layer_value(cfg$desn$n, "desn.n")
  n_tilde_each <- qdesn_tor1_scalar_layer_value(
    cfg$desn$n_tilde, "desn.n_tilde", allow_empty = D == 1L
  )
  alpha <- qdesn_tor1_scalar_layer_value(cfg$desn$alpha, "desn.alpha")
  rho <- qdesn_tor1_scalar_layer_value(cfg$desn$rho, "desn.rho")
  pi_w <- qdesn_tor1_scalar_layer_value(cfg$desn$pi_w, "desn.pi_w")
  pi_in <- qdesn_tor1_scalar_layer_value(cfg$desn$pi_in, "desn.pi_in")
  rhs_tau0 <- as.numeric(cfg$inference$vb$priors$beta$rhs_ns$tau0 %||% root$rhs_tau0)
  dimension <- as.integer(root$dimension_p_estimate %||%
    (1L + as.integer(cfg$lags$m_y) + D * as.integer(n_each)))
  data.frame(
    candidate,
    screening_profile_id = sprintf(
      "vbtor1_%02d_%s", i, qdesn_tor1_safe_token(candidate$legacy_profile_id)
    ),
    screening_stage = "vb_train_only_preprocessing_rebaseline_v1",
    screening_wave = "vb_train_only_preprocessing_rebaseline_2026_08_05",
    profile_role = "exact_current_article_vb_design_rebaseline",
    enabled = TRUE,
    D = D,
    n_each = as.integer(n_each),
    n_tilde_each = as.integer(n_tilde_each),
    m = as.integer(cfg$desn$m),
    alpha = alpha,
    rho = rho,
    pi_w = pi_w,
    pi_in = pi_in,
    washout = as.integer(cfg$desn$washout),
    add_bias = isTRUE(cfg$desn$add_bias),
    seed = as.integer(cfg$desn$seed),
    readout_y_lags = as.integer(cfg$lags$m_y),
    reservoir_lags = as.integer(cfg$readout$reservoir_lags),
    rhs_tau0 = rhs_tau0,
    dimension_p_estimate = dimension,
    p_over_n_tt500 = dimension / 500,
    x_feature_count = 5L,
    target_cells = sprintf("%s:%s:%s", candidate$family,
                           format(candidate$tau, trim = TRUE),
                           candidate$likelihood_target),
    source_fit_request_path = request_path,
    source_fit_request_sha256 = unname(tools::sha256sum(request_path)),
    source_effective_desn_seed = as.integer(cfg$desn$seed),
    source_root_seed = as.integer(root$seed %||% NA_integer_),
    source_vb_max_iter = as.integer(cfg$inference$vb$max_iter),
    source_vb_min_iter_elbo = as.integer(cfg$inference$vb$min_iter_elbo),
    source_vb_n_samp_xi = as.integer(cfg$inference$vb$n_samp_xi),
    source_synthesis_seed = as.integer(root$synthesis_seed %||% cfg$synthesis$seed),
    source_registry_hash_value = expected_registry_hash,
    stringsAsFactors = FALSE
  )
})
profiles <- do.call(rbind, candidate_rows)
if (anyDuplicated(profiles$screening_profile_id) ||
    any(profiles$source_vb_max_iter != 150L) ||
    any(profiles$source_vb_min_iter_elbo != 40L) ||
    any(profiles$source_vb_n_samp_xi != 500L)) {
  stop("Extracted VB profiles violate uniqueness or budget invariants.", call. = FALSE)
}

profile_columns <- c(
  "screening_profile_id", "screening_stage", "screening_wave", "profile_role",
  "enabled", "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "washout", "add_bias", "seed", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "x_feature_count",
  "target_cells", "model_variant", "family", "tau", "likelihood_target",
  "legacy_candidate_id", "legacy_run_tag", "legacy_profile_id", "source_stage",
  "source_fit_request_path", "source_fit_request_sha256", "source_effective_desn_seed",
  "source_root_seed", "source_vb_max_iter", "source_vb_min_iter_elbo",
  "source_vb_n_samp_xi", "source_synthesis_seed", "source_registry_hash_value",
  "candidate_key"
)
profiles_path <- write_csv(profiles[, profile_columns], paste0(stub, "_profiles.csv"))
candidates_path <- write_csv(profiles, paste0(stub, "_candidate_contract.csv"))

assignments <- data.frame(
  assignment_key = profiles$candidate_key,
  assignment_id = sprintf("vbtor1_%03d", seq_len(nrow(profiles))),
  family = profiles$family,
  tau = profiles$tau,
  likelihood_target = profiles$likelihood_target,
  cell_status = "exact_article_vb_design_rebaseline",
  priority_rank = 1L,
  target_profile_rank = 1L,
  screening_profile_id = profiles$screening_profile_id,
  source_profile = profiles$legacy_profile_id,
  candidate_source = profiles$source_stage,
  selection_reason = "exact_design_supplies_current_article_rhs_vb_cell",
  source_path = profiles$source_fit_request_path,
  root_id = NA_character_,
  stringsAsFactors = FALSE
)

canonical_registry_path <- file.path(
  shared_root, "validation", "fitforecast_v2", "runs",
  "20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2",
  "manifests", "source_registry.csv"
)
canonical_registry <- utils::read.csv(
  canonical_registry_path, check.names = FALSE, stringsAsFactors = FALSE
)
registry <- canonical_registry[
  canonical_registry$scenario_id == expected_scenario &
    canonical_registry$fit_size == 500L &
    canonical_registry$family %in% c("gausmix", "laplace", "normal") &
    as.numeric(canonical_registry$tau) %in% c(0.05, 0.25, 0.50),
  , drop = FALSE
]
if (nrow(registry) != 9L || any(!as_bool(registry$source_present)) ||
    any(as.integer(registry$TT_warmup) != 2000L) ||
    any(as.integer(registry$TT_main) != 10000L) ||
    any(as.integer(registry$TT_total) != 12000L) ||
    any(as.integer(registry$train_start_source_index) != 8501L) ||
    any(as.integer(registry$train_end_source_index) != 9000L) ||
    any(as.integer(registry$forecast_origin_source_index) != 9000L) ||
    any(as.integer(registry$forecast_start_source_index) != 9001L) ||
    any(as.integer(registry$forecast_end_source_index) != 10000L) ||
    any(as.integer(registry$max_lead_configured) != 30L) ||
    any(as.integer(registry$origin_stride) != 30L) ||
    any(as_bool(registry$refit_per_origin))) {
  stop("Canonical source registry violates the VB replay protocol.", call. = FALSE)
}

source_roles <- c("series_wide", "true_quantile_grid", "sim_output", "meta")
source_audit <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  do.call(rbind, lapply(source_roles, function(role) {
    path <- as.character(registry[[paste0(role, "_path")]][[i]])
    expected <- as.character(registry[[paste0(role, "_sha256")]][[i]])
    data.frame(
      source_cell_id = registry$source_cell_id[[i]], role = role, path = path,
      expected_sha256 = expected, file_exists = file.exists(path),
      observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
      stringsAsFactors = FALSE
    )
  }))
}))
source_audit$hash_match <- with(
  source_audit, file_exists & expected_sha256 == observed_sha256
)
if (!all(source_audit$hash_match)) stop("Frozen source hash verification failed.", call. = FALSE)
source_registry_path <- write_csv(registry, paste0(stub, "_source_registry.csv"))
source_audit_path <- write_csv(source_audit, paste0(stub, "_source_file_hash_audit.csv"))

staged_source_root <- file.path(
  shared_root, "results", "qdesn_mcmc_validation",
  "dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300"
)
base_defaults_path <- file.path(
  "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration_defaults.yaml"
)
defaults <- yaml::read_yaml(resolve_path(base_defaults_path))
defaults$campaign <- list(
  name = stage,
  results_root = file.path("results", "qdesn_mcmc_validation", stage),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage)
)
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- c("al", "exal")
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "deterministic_per_root", base_seed = 860000L)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$source_materialization$staged_root <- staged_source_root
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- 18L * 9L
defaults$reference_contract$expected_selected_qdesn_roots <- 18L
defaults$reference_contract$expected_priors <- "rhs_ns"
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = sub(paste0("^", repo_root, "/?"), "", profiles_path),
  cell_assignments_csv = sub(paste0("^", repo_root, "/?"), "", paste0(stub, "_cell_assignments.csv")),
  priors = "rhs_ns",
  design = paste(
    "18 exact article-facing RHS VB designs re-estimated under training-only",
    "preprocessing with fresh deterministic execution seeds."
  ),
  execution_grid_policy = "exact_article_vb_design_subset",
  canonical_profile_count = 18L,
  canonical_dataset_cell_count = 9L,
  canonical_qdesn_root_count = 162L,
  selected_assignment_root_count = 18L,
  dimension_gate = list(primary_p_over_n_max = 1.0, exploratory_p_over_n_max = 1.0)
)
defaults$multiseed <- list(enabled = FALSE, mcmc_seed_reps = 1L,
                           parallel_seed_workers = 1L,
                           prune_nonwinning_heavy_outputs = TRUE)
defaults$preproc <- list(scale_y = TRUE, scale_x = TRUE, fit_scope = "train_only")
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_vb_trainonly_rebaseline"
defaults$pipeline$inference$vb$max_iter <- 150L
defaults$pipeline$inference$vb$min_iter_elbo <- 40L
defaults$pipeline$inference$vb$n_samp_xi <- 500L
defaults$pipeline$inference$vb$progress_every <- 50L
defaults$pipeline$inference$vb$diagnostics$rhs_trace <- FALSE
defaults$pipeline$inference$vb$diagnostics$rhs_deep <- FALSE
defaults$pipeline$inference$vb$prior_overrides$rhs_ns$max_iter <- 150L
defaults$pipeline$inference$vb$prior_overrides$rhs_ns$min_iter_elbo <- 40L
defaults$pipeline$inference$vb$prior_overrides$rhs_ns$n_samp_xi <- 500L
defaults$pipeline$sampling$nd_draws <- 200L
defaults$pipeline$synthesis$n_samp <- 200L
defaults$metrics$posterior_metric_draws <- 200L
defaults$paths$rewrite_home_local_src_to_repo_root <- FALSE
defaults$study_contract <- list(
  core_lane = TRUE,
  id = paste0(stage, "_2026_08_05"),
  description = paste(
    "Exact-design VB replay of the 18 article-facing Q-DESN RHS cells under",
    "training-only preprocessing. No hyperparameter reselection occurs."
  ),
  package_version = "1.0.0",
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  source_registry_path = source_registry_path,
  source_registry_sha256 = sha256(source_registry_path),
  preprocessing = list(
    scope = "train_only", analysis_input_rows = c(1L, 1890L),
    preprocessing_fit_rows = c(1L, 890L),
    preprocessing_fit_row_indices_sha256 = digest::digest(1:890, algo = "sha256"),
    corresponding_source_rows = c(8111L, 9000L),
    effective_target_fit_window = c(8501L, 9000L),
    forecast_block = c(9001L, 10000L),
    heldout_response_used_for_scaling = FALSE,
    heldout_covariates_used_for_scaling = FALSE
  ),
  budget = list(posterior_metric_draws = 200L, vb_max_iter = 150L,
                vb_min_iter_elbo = 40L, vb_n_samp_xi = 500L),
  selection_policy = list(
    unit = "one_exact_design_per_model_family_quantile_cell",
    historical_cells = 18L, exact_designs = 18L,
    article_update_automatic = FALSE,
    legacy_qdesn_vb_metrics_valid_after_repair = FALSE,
    corrected_complete_rebaseline_required = TRUE
  )
)

assignments_path <- write_csv(assignments, paste0(stub, "_cell_assignments.csv"))
defaults_path <- resolve_path(paste0(stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)
loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  loaded, refresh_materialized = FALSE, verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, loaded)

grid_key <- paste(canonical_grid$screening_profile_id,
                  canonical_grid$source_family, tau_key(canonical_grid$tau), sep = "\r")
target_key <- paste(profiles$screening_profile_id,
                    profiles$family, tau_key(profiles$tau), sep = "\r")
grid <- canonical_grid[grid_key %in% target_key &
                         canonical_grid$source_scenario == expected_scenario, , drop = FALSE]
index <- match(grid$screening_profile_id, profiles$screening_profile_id)
if (anyNA(index)) stop("Grid/profile join failed.", call. = FALSE)
# Retain the deterministic root seed assigned by the canonical grid builder.
# Changing it after construction would invalidate subset provenance.
grid$desn_seed <- as.integer(profiles$source_effective_desn_seed[index])
grid$synthesis_seed <- 870000L + index
grid$legacy_candidate_id <- profiles$legacy_candidate_id[index]
grid$legacy_run_tag <- profiles$legacy_run_tag[index]
grid$source_fit_request_path <- profiles$source_fit_request_path[index]
grid$source_fit_request_sha256 <- profiles$source_fit_request_sha256[index]
grid$model_variant <- profiles$model_variant[index]
grid$likelihood_target <- profiles$likelihood_target[index]
grid$source_registry_hash_value <- expected_registry_hash
grid <- grid[grid$likelihood_target == ifelse(
  grid$model_variant == "qdesn_al_rhs_ns", "al", "exal"
), , drop = FALSE]
grid <- grid[order(grid$model_variant, grid$source_family, grid$tau), , drop = FALSE]
if (nrow(grid) != 18L || anyDuplicated(grid$root_id) ||
    any(as.integer(grid$train_start_source_index) != 8501L) ||
    any(as.integer(grid$train_end_source_index) != 9000L) ||
    any(as.integer(grid$forecast_start_source_index) != 9001L) ||
    any(as.integer(grid$forecast_end_source_index) != 10000L)) {
  stop(sprintf("Expected 18 exact VB roots; found %d.", nrow(grid)), call. = FALSE)
}

staged_roles <- c("source_series_wide", "source_selection_indices", "source_sim")
staged_audit <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  do.call(rbind, lapply(staged_roles, function(role) {
    path <- as.character(grid[[paste0(role, "_path")]][[i]])
    expected <- as.character(grid[[paste0(role, "_sha256")]][[i]])
    data.frame(root_id = grid$root_id[[i]], role = role, path = path,
               expected_sha256 = expected, file_exists = file.exists(path),
               observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
               stringsAsFactors = FALSE)
  }))
}))
staged_audit$hash_match <- with(staged_audit, file_exists & expected_sha256 == observed_sha256)
if (!all(staged_audit$hash_match)) stop("Staged source hash verification failed.", call. = FALSE)

assignments$root_id <- grid$root_id[match(assignments$screening_profile_id,
                                          grid$screening_profile_id)]
assignments_path <- write_csv(assignments, paste0(stub, "_cell_assignments.csv"))
grid_path <- write_csv(grid, paste0(stub, "_grid.csv"))
staged_audit_path <- write_csv(staged_audit, paste0(stub, "_staged_source_hash_audit.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid, defaults = loaded, methods = "vb", likelihood_families = c("al", "exal")
)
atomic_index <- match(atomic$root_id, grid$root_id)
for (field in c("legacy_candidate_id", "legacy_run_tag", "model_variant",
                "likelihood_target", "source_fit_request_path",
                "source_fit_request_sha256", "desn_seed", "synthesis_seed",
                "source_registry_hash_value")) {
  atomic[[field]] <- grid[[field]][atomic_index]
}
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(target_specs$model_variant, target_specs$family,
                                   target_specs$tau), , drop = FALSE]
if (nrow(target_specs) != 18L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected 18 unique VB target specs; found %d.", nrow(target_specs)),
       call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_target_spec_ids.csv"))
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_path)

smoke_profile_ids <- vapply(c("al", "exal"), function(likelihood) {
  subset <- profiles[profiles$likelihood_target == likelihood, , drop = FALSE]
  subset$screening_profile_id[[which.max(subset$dimension_p_estimate)]]
}, character(1L))
smoke_grid <- grid[grid$screening_profile_id %in% smoke_profile_ids, , drop = FALSE]
smoke_specs <- target_specs[target_specs$screening_profile_id %in% smoke_profile_ids, , drop = FALSE]
if (nrow(smoke_grid) != 2L || nrow(smoke_specs) != 2L ||
    !setequal(smoke_specs$likelihood_family, c("al", "exal"))) {
  stop("Smoke contract must contain one AL and one exAL VB root.", call. = FALSE)
}
smoke_defaults <- defaults
smoke_defaults$campaign$name <- paste0(stage, "_smoke")
smoke_defaults$campaign$results_root <- file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke")
)
smoke_defaults$campaign$reports_root <- file.path(
  "reports", "qdesn_mcmc_validation", paste0(stage, "_smoke")
)
smoke_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(smoke_specs$spec_id))
smoke_defaults$runtime$campaign_workers <- 2L
smoke_defaults$runtime$workers <- 2L
smoke_defaults$reference_contract$expected_selected_qdesn_roots <- 2L
smoke_defaults$screening_profiles$selected_assignment_root_count <- 2L
smoke_defaults$pipeline$inference$vb$max_iter <- 5L
smoke_defaults$pipeline$inference$vb$min_iter_elbo <- 2L
smoke_defaults$pipeline$inference$vb$n_samp_xi <- 20L
smoke_defaults$pipeline$inference$vb$progress_every <- 1L
smoke_defaults$pipeline$inference$vb$diagnostics$rhs_trace <- FALSE
smoke_defaults$pipeline$inference$vb$diagnostics$rhs_deep <- FALSE
smoke_defaults$pipeline$inference$vb$prior_overrides$rhs_ns$max_iter <- 5L
smoke_defaults$pipeline$inference$vb$prior_overrides$rhs_ns$min_iter_elbo <- 2L
smoke_defaults$pipeline$inference$vb$prior_overrides$rhs_ns$n_samp_xi <- 20L
smoke_defaults$pipeline$sampling$nd_draws <- 4L
smoke_defaults$pipeline$synthesis$n_samp <- 4L
smoke_defaults$metrics$posterior_metric_draws <- 4L
smoke_defaults$study_contract$budget <- list(
  posterior_metric_draws = 4L, vb_max_iter = 5L,
  vb_min_iter_elbo = 2L, vb_n_samp_xi = 20L
)
smoke_defaults$study_contract$selection_policy$stage <- "executable_smoke"
smoke_defaults_path <- resolve_path(paste0(stub, "_smoke_defaults.yaml"), FALSE)
yaml::write_yaml(smoke_defaults, smoke_defaults_path)
smoke_grid_path <- write_csv(smoke_grid, paste0(stub, "_smoke_grid.csv"))
smoke_specs_path <- write_csv(smoke_specs, paste0(stub, "_smoke_target_spec_ids.csv"))

request_audit <- profiles[, c("screening_profile_id", "model_variant", "family",
                              "tau", "legacy_run_tag", "source_fit_request_path",
                              "source_fit_request_sha256")]
request_audit$file_exists <- file.exists(request_audit$source_fit_request_path)
request_audit$observed_sha256 <- vapply(request_audit$source_fit_request_path,
  function(path) if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
  character(1L))
request_audit$hash_match <- with(
  request_audit, file_exists & source_fit_request_sha256 == observed_sha256
)
if (!all(request_audit$hash_match)) stop("Source fit-request audit failed.", call. = FALSE)
request_audit_path <- write_csv(request_audit, paste0(stub, "_source_fit_request_audit.csv"))

generated_files <- c(
  profiles = profiles_path, assignments = assignments_path,
  candidate_contract = candidates_path, defaults = defaults_path,
  grid = grid_path, target_specs = target_specs_path,
  smoke_defaults = smoke_defaults_path, smoke_grid = smoke_grid_path,
  smoke_specs = smoke_specs_path, source_registry = source_registry_path,
  source_file_audit = source_audit_path, staged_source_audit = staged_audit_path,
  source_fit_request_audit = request_audit_path
)
generated_manifest <- data.frame(
  role = names(generated_files), path = unname(generated_files),
  sha256 = vapply(generated_files, sha256, character(1L)), stringsAsFactors = FALSE
)
generated_manifest_path <- write_csv(
  generated_manifest, paste0(stub, "_generated_file_manifest.csv")
)
manifest <- list(
  generated_at = as.character(Sys.time()), stage = stage,
  package_version = as.character(description[1L, "Version"]),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  canonical_registry_path = canonical_registry_path,
  canonical_registry_file_sha256 = unname(tools::sha256sum(canonical_registry_path)),
  source_files_verified = all(source_audit$hash_match),
  staged_source_files_verified = all(staged_audit$hash_match),
  source_fit_requests_verified = all(request_audit$hash_match),
  preprocessing = defaults$study_contract$preprocessing,
  counts = list(historical_vb_cells = 18L, full_specs = 18L, smoke_specs = 2L),
  budget = defaults$study_contract$budget,
  storage_policy = list(
    retention_profile = "storage_light_vb_trainonly_rebaseline",
    successful_binary_payloads_allowed = FALSE,
    failure_binary_payloads_allowed = FALSE
  ),
  article_update_automatic = FALSE,
  launch_status = "materialized_not_launched",
  generated_file_manifest_path = generated_manifest_path
)
manifest_path <- write_json(manifest, paste0(stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Frozen registry identity: %s\n", expected_registry_hash))
cat("Exact historical VB designs: 18\n")
cat("Executable smoke specs: 2\n")
