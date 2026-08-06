`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_tfv1_stage <- function() {
  "qdesn_dynamic_fitforecast_v2_500obs_trainonly_followup_v1"
}

qdesn_tfv1_tau_key <- function(x) sprintf("%.8f", as.numeric(x))

qdesn_tfv1_bundle_contract <- function() {
  data.frame(
    bundle_id = c(
      "al_raw", "al_raw_dev04", "al_sr", "al_sr_dev04",
      "exal_gsg_matched", "exal_gsg_dense", "exal_gsg_multistart"
    ),
    experiment = c(rep("al_confirmation", 4L), rep("exal_sampler_diagnostic", 3L)),
    source_role = c(
      "frozen_article", "untouched_confirmation",
      "frozen_article", "untouched_confirmation",
      rep("development", 3L)
    ),
    likelihood_target = c(rep("al", 4L), rep("exal", 3L)),
    family = c(rep("normal", 4L), rep("gausmix", 3L)),
    tau = c(rep(0.05, 4L), rep(0.25, 3L)),
    input_mode = c(
      "raw_y_lags", "raw_y_lags", "dlm_decomp_lags", "dlm_decomp_lags",
      rep("raw_y_lags", 3L)
    ),
    arm_code = c(
      "parent_and_compact_raw", "parent_and_compact_raw",
      "compact_state_resid", "compact_state_resid",
      "gsg_matched", "gsg_dense", "gsg_multistart"
    ),
    expected_specs = c(6L, 6L, 3L, 3L, 6L, 6L, 6L),
    n_burn = c(rep(5000L, 4L), rep(1000L, 3L)),
    n_mcmc = c(rep(20000L, 4L), rep(3000L, 3L)),
    stringsAsFactors = FALSE
  )
}

qdesn_tfv1_source_contract <- function() {
  data.frame(
    source_role = c("frozen_article", "untouched_confirmation", "development", "development", "development"),
    source_replicate = c("article", "dev04", "dev01", "dev02", "dev03"),
    scenario_id = c(
      "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
      "dlm_constV_p90_trainonly_followup_dev04_TTmain10000_fitforecast",
      "dlm_constV_p90_trainonly_mech_dev01_TTmain10000_fitforecast",
      "dlm_constV_p90_trainonly_mech_dev02_TTmain10000_fitforecast",
      "dlm_constV_p90_trainonly_mech_dev03_TTmain10000_fitforecast"
    ),
    allowed_experiment = c("al_confirmation", "al_confirmation", rep("exal_sampler_diagnostic", 3L)),
    article_facing = c(TRUE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
}

.qdesn_tfv1_profile_row <- function(profile_id, arm_code, reservoir_seed, experiment,
                                    source_role) {
  is_al <- identical(experiment, "al_confirmation")
  is_parent <- identical(arm_code, "parent_exact")
  compact <- !is_parent && is_al
  n_each <- if (is_al && is_parent) 6L else if (is_al) 12L else 4L
  m <- if (is_al && is_parent) 1L else if (is_al) 3L else 2L
  data.frame(
    screening_profile_id = profile_id,
    screening_stage = "mcmc_trainonly_followup_v1",
    screening_wave = "trainonly_followup_v1_2026_08_05",
    profile_role = arm_code,
    enabled = TRUE,
    D = 1L,
    n_each = n_each,
    n_tilde_each = 0L,
    m = m,
    alpha = if (is_al && is_parent) 0.00075 else if (is_al) 0.01 else 0.001,
    rho = if (is_al && is_parent) 0.35 else if (is_al) 0.60 else 0.45,
    pi_w = if (is_al && is_parent) 0.00075 else if (is_al) 1 / 6 else 0.0025,
    pi_in = if (is_al && is_parent) 0.03 else if (is_al) 0.5 else 0.05,
    washout = 300L,
    add_bias = TRUE,
    seed = as.integer(reservoir_seed),
    readout_y_lags = if (is_al && is_parent) 1L else if (is_al) 3L else 2L,
    reservoir_lags = 0L,
    rhs_tau0 = 3e-4,
    dimension_p_estimate = as.integer(1L + m + n_each),
    p_over_n_tt500 = (1 + m + n_each) / 500,
    x_feature_count = 5L,
    target_cells = if (is_al) "normal:0.05:al" else "gausmix:0.25:exal",
    target_cell_id = if (is_al) "al_normal_t0p05" else "exal_gausmix_t0p25",
    target_role = if (is_al) "full_budget_confirmation" else "sampler_geometry_diagnostic",
    primary_target = TRUE,
    target_family = if (is_al) "normal" else "gausmix",
    target_tau = if (is_al) 0.05 else 0.25,
    likelihood_target = if (is_al) "al" else "exal",
    parent_profile_id = if (is_al) "tor1_15_mcvbc_055_al" else "tor1_23_arfc1_parent_exal_gausmix_t0p25_r01_full_3ed",
    source_role = source_role,
    bundle_id = NA_character_,
    arm_code = arm_code,
    experiment = experiment,
    reservoir_replicate = match(as.integer(reservoir_seed), c(910001L, 910002L, 910003L, 920001L, 920002L)),
    paired_reservoir_seed = as.integer(reservoir_seed),
    stringsAsFactors = FALSE
  )
}

qdesn_tfv1_build_profiles <- function() {
  rows <- list()
  for (source_role in c("frozen_article", "untouched_confirmation")) {
    source_token <- if (source_role == "frozen_article") "" else "dev04_"
    for (r in seq_along(c(910001L, 910002L, 910003L))) {
      seed <- c(910001L, 910002L, 910003L)[[r]]
      rows[[length(rows) + 1L]] <- .qdesn_tfv1_profile_row(
        sprintf("qtfv1_al_%sparent_r%02d", source_token, r),
        "parent_exact", seed, "al_confirmation", source_role
      )
      rows[[length(rows) + 1L]] <- .qdesn_tfv1_profile_row(
        sprintf("qtfv1_al_%sraw_r%02d", source_token, r),
        "compact_raw", seed, "al_confirmation", source_role
      )
      rows[[length(rows) + 1L]] <- .qdesn_tfv1_profile_row(
        sprintf("qtfv1_al_%ssr_r%02d", source_token, r),
        "compact_state_resid", seed, "al_confirmation", source_role
      )
    }
  }
  for (arm in c("gsg_matched", "gsg_dense", "gsg_multistart")) {
    for (i in seq_along(c(920001L, 920002L))) {
      rows[[length(rows) + 1L]] <- .qdesn_tfv1_profile_row(
        sprintf("qtfv1_exal_%s_r%02d", arm, i), arm, c(920001L, 920002L)[[i]],
        "exal_sampler_diagnostic", "development"
      )
    }
  }
  out <- do.call(rbind, rows)
  is_article <- out$source_role == "frozen_article"
  is_dev04 <- out$source_role == "untouched_confirmation"
  out$bundle_id[is_article & out$arm_code %in% c("parent_exact", "compact_raw")] <- "al_raw"
  out$bundle_id[is_dev04 & out$arm_code %in% c("parent_exact", "compact_raw")] <- "al_raw_dev04"
  out$bundle_id[is_article & out$arm_code == "compact_state_resid"] <- "al_sr"
  out$bundle_id[is_dev04 & out$arm_code == "compact_state_resid"] <- "al_sr_dev04"
  out$bundle_id[out$arm_code == "gsg_matched"] <- "exal_gsg_matched"
  out$bundle_id[out$arm_code == "gsg_dense"] <- "exal_gsg_dense"
  out$bundle_id[out$arm_code == "gsg_multistart"] <- "exal_gsg_multistart"
  rownames(out) <- NULL
  out
}

qdesn_tfv1_sampler_control <- function(bundle_id) {
  bundle_id <- as.character(bundle_id)[1L]
  base <- list(
    slice = list(
      core_update_mode = "sigma_then_gamma",
      width_gamma = 0.42,
      width_sigma = 0.30,
      core_extra_passes = 2L,
      max_steps_out = 100L,
      max_shrink = 360L,
      max_steps_out_sigma = 160L,
      max_shrink_sigma = 420L
    ),
    multi_start = list(enabled = FALSE)
  )
  if (bundle_id == "exal_gsg_matched") {
    base$slice$core_update_mode <- "gamma_sigma_gamma"
    base$slice$width_gamma <- 0.45
    base$slice$width_sigma <- 0.28
  } else if (bundle_id == "exal_gsg_dense") {
    base$slice$core_update_mode <- "gamma_sigma_gamma"
    base$slice$width_gamma <- 0.60
    base$slice$width_sigma <- 0.24
    base$slice$core_extra_passes <- 4L
  } else if (bundle_id == "exal_gsg_multistart") {
    base$slice$core_update_mode <- "gamma_sigma_gamma"
    base$slice$width_gamma <- 0.60
    base$slice$width_sigma <- 0.24
    base$slice$core_extra_passes <- 3L
    base$multi_start <- list(
      enabled = TRUE,
      n_starts = 4L,
      pilot_n_burn = 120L,
      pilot_n_mcmc = 160L,
      pilot_seed = 960041L,
      perturb_sd_log_tau = 0.35,
      perturb_sd_log_c2 = 0.35,
      perturb_sd_log_lambda = 0.20,
      perturb_sd_beta = 0.05
    )
  }
  base
}

qdesn_tfv1_validate_plan <- function(profiles = qdesn_tfv1_build_profiles()) {
  contract <- qdesn_tfv1_bundle_contract()
  expected_profiles <- c(
    al_raw = 6L, al_raw_dev04 = 6L, al_sr = 3L, al_sr_dev04 = 3L,
    exal_gsg_matched = 2L, exal_gsg_dense = 2L, exal_gsg_multistart = 2L
  )
  observed <- table(profiles$bundle_id)
  if (!identical(as.integer(observed[names(expected_profiles)]), as.integer(expected_profiles))) {
    stop("Follow-up profile counts differ from the frozen contract.", call. = FALSE)
  }
  if (any(profiles$D != 1L) || any(abs(profiles$rhs_tau0 - 3e-4) > 1e-12)) {
    stop("Follow-up must freeze D=1 and rhs_tau0=3e-4.", call. = FALSE)
  }
  if (sum(contract$expected_specs) != 36L) stop("Expected exactly 36 Q-DESN roots.", call. = FALSE)
  invisible(TRUE)
}

qdesn_tfv1_decomposition <- function(bundle_id) {
  if (!startsWith(bundle_id, "al_sr")) return(list(enabled = FALSE))
  list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = as.list(c("trend", "seasonal", "residual")),
    input_builder = "state_resid_y",
    trend = list(degree = 1L),
    seasonal = list(period = 90L, harmonics = as.list(1:2), auto = list(enabled = FALSE)),
    regression = list(enabled = FALSE, dynamic = FALSE),
    transfer = list(enabled = FALSE),
    input_lags_mode = "component",
    input_lags = list(trend = as.list(1:2), seasonal = as.list(1:3), residual = as.list(1:2)),
    state_resid_y = list(
      state_lags = as.list(0:1), residual_lags = as.list(0:2), y_lags = as.list(1:2),
      include_xreg = FALSE
    ),
    discount = list(trend = 0.99, seasonal = 0.99, regression = 1.0,
                    transfer_zeta = 0.99, transfer_psi = 1.0),
    variance = list(mode = "unknown_constant", l0 = 1, S0 = 1),
    forecast = list(residual_recursion = "sampled_path"),
    sim_xreg = list(policy = "repeat_last")
  )
}
