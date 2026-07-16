rqr_desn_broad_simulation_config <- list(
  config_id = "rqr_desn_broad_v1_20260716",
  status = "frozen_no_launch",
  launch_authorized = FALSE,
  article_update_allowed = FALSE,
  package_side_only = TRUE,
  created_at = "2026-07-16",
  implementation_pin = list(
    branch = "feature/rqr-desn-readout-20260716",
    bridge_commit = "bd17d8d61a595bf39f84db5f40476c0fa2aa21b7",
    bridge_commit_message = "Add RQR-DESN pilot bridge gates",
    readiness_artifact = "reports/rqr_desn_pre_simulation_readiness/rqr_desn_readiness_20260716-141012_git_bd17d8d61a59",
    pilot_artifact = "reports/rqr_desn_pilot/rqr_desn_pilot_20260716-140837_git_bd17d8d61a59",
    pilot_go_for_broad_spec = TRUE
  ),
  scientific_contract = list(
    native_estimand = "central_prediction_interval",
    coverage_levels = c(0.80, 0.90),
    learning_rates = c(0.50, 1.00, 1.50),
    forbidden_argument_names = c("target_p", "p0"),
    response_likelihood = FALSE,
    response_predictive_draws = FALSE,
    recursive_response_sampling = FALSE,
    vb_uncertainty_calibrated = FALSE,
    primary_backend = "mcmc",
    vb_role = "sidecar_screening_only",
    article_claims_allowed = FALSE
  ),
  output_contract = list(
    output_root = "reports/rqr_desn_broad_simulation",
    required_files = c(
      "manifest.csv",
      "scenario_manifest.csv",
      "interval_metrics.csv",
      "fit_summary.csv",
      "mcmc_diagnostics.csv",
      "vb_diagnostics.csv",
      "failure_log.csv",
      "closeout.md",
      "session_info.txt",
      "git_state.txt",
      "output_hashes.csv",
      "README.md"
    ),
    required_manifest_fields = c(
      "config_id",
      "implementation_commit",
      "branch",
      "remote_branch",
      "R_binary",
      "package_library",
      "scenario_id",
      "scenario_family",
      "replicate_id",
      "seed",
      "coverage_level",
      "learning_rate",
      "prior_type",
      "prior_hyperparameters",
      "design_id",
      "DESN_D",
      "DESN_n",
      "DESN_m",
      "washout",
      "backend",
      "inference",
      "mcmc_control",
      "vb_control",
      "output_file",
      "output_hash"
    )
  ),
  randomization = list(
    seed_base = 9130000L,
    seed_rule = "seed_base + stage_index*1000000 + family_index*100000 + replicate_id*1000 + design_index*100 + backend_index",
    deterministic_grid_order = TRUE
  ),
  scoring = list(
    primary = c("interval_score_mean", "empirical_coverage", "mean_width"),
    secondary = c("midpoint_mae", "endpoint_mae", "finite_lower", "finite_upper", "ordered_intervals", "positive_mean_width"),
    promotion_gate = list(
      finite_ordered_positive_width = TRUE,
      failure_rows_allowed = 0L,
      compare_against_empirical_interval = TRUE,
      compare_against_fixed_design_rqr_where_available = TRUE,
      no_article_promotion_from_broad_config_only = TRUE
    )
  ),
  mcmc_control = list(
    n_burn = 600L,
    n_mcmc = 900L,
    thin = 1L,
    store_latent_draws = FALSE,
    precision_beta = list(strategy = "off"),
    chain_count = 1L,
    sentinel_long_chain = list(
      enabled = TRUE,
      replicate_ids = c(1L, 12L, 24L),
      n_burn = 1200L,
      n_mcmc = 1800L,
      purpose = "sensitivity only; not primary scoring"
    )
  ),
  vb_control = list(
    max_iter = 500L,
    tol = 1e-5,
    n_draws = 1000L,
    calibrated_uncertainty = FALSE
  ),
  priors = list(
    ridge = list(type = "ridge", tau2 = 8),
    rhs_ns = list(
      type = "rhs_ns",
      tau0 = 0.5,
      a_zeta = 2,
      b_zeta = 1,
      s2 = 1,
      n_inner = 1L,
      shrink_intercept = FALSE
    )
  ),
  stages = list(
    list(
      stage_id = "fixed_design_calibration",
      purpose = "calibrate RQR interval behavior on DGPs with fixed design and oracle endpoints",
      replicates = 24L,
      n_train = 160L,
      n_test = 80L,
      dgp_families = list(
        list(family_id = "symmetric_linear", noise = "normal", oracle_endpoints = TRUE),
        list(family_id = "skewed_linear", noise = "centered_exponential", oracle_endpoints = TRUE),
        list(family_id = "heavy_tail_linear", noise = "student_t_df3", oracle_endpoints = TRUE),
        list(family_id = "heteroskedastic_linear", noise = "state_dependent_normal", oracle_endpoints = TRUE)
      ),
      designs = list(
        list(
          design_id = "fixed_linear_true_features",
          design_type = "fixed_design",
          feature_description = "intercept plus observed scalar covariate",
          DESN_D = NA_integer_,
          DESN_n = NA_integer_,
          DESN_m = NA_integer_,
          washout = NA_integer_
        )
      ),
      backends = list(
        list(
          backend_id = "empirical_train_interval",
          inference = "baseline",
          primary = FALSE,
          priors = "none",
          coverage_levels = c(0.80, 0.90),
          learning_rates = NA_real_,
          design_ids = "none"
        ),
        list(
          backend_id = "rqr_fixed_design_mcmc",
          inference = "mcmc",
          primary = TRUE,
          priors = c("ridge", "rhs_ns"),
          coverage_levels = c(0.80, 0.90),
          learning_rates = c(0.50, 1.00, 1.50),
          design_ids = "all"
        ),
        list(
          backend_id = "rqr_fixed_design_vb",
          inference = "vb",
          primary = FALSE,
          priors = "ridge",
          coverage_levels = 0.80,
          learning_rates = 1.00,
          design_ids = "all",
          note = "sidecar only; uncertainty not calibrated"
        )
      )
    ),
    list(
      stage_id = "teacher_forced_desn_dynamic",
      purpose = "evaluate RQR-DESN readouts on explicit teacher-forced reservoir designs without recursive response sampling",
      replicates = 18L,
      n_train = 240L,
      n_test = 120L,
      dgp_families = list(
        list(family_id = "nonlinear_dynamic", noise = "normal", oracle_endpoints = FALSE),
        list(family_id = "regime_shift_dynamic", noise = "normal_with_shift", oracle_endpoints = FALSE)
      ),
      designs = list(
        list(design_id = "desn_D1_n16_m3", design_type = "teacher_forced_desn", DESN_D = 1L, DESN_n = 16L, DESN_m = 3L, alpha = 0.25, rho = 0.75, act_f = "tanh", act_k = "identity", pi_w = 0.30, pi_in = 1.00, washout = 40L, add_bias = TRUE),
        list(design_id = "desn_D1_n32_m5", design_type = "teacher_forced_desn", DESN_D = 1L, DESN_n = 32L, DESN_m = 5L, alpha = 0.25, rho = 0.80, act_f = "tanh", act_k = "identity", pi_w = 0.30, pi_in = 1.00, washout = 50L, add_bias = TRUE),
        list(design_id = "desn_D2_n16_m3", design_type = "teacher_forced_desn", DESN_D = 2L, DESN_n = 16L, DESN_m = 3L, alpha = 0.20, rho = 0.75, act_f = "tanh", act_k = "identity", pi_w = 0.25, pi_in = 1.00, washout = 50L, add_bias = TRUE),
        list(design_id = "desn_D2_n24_m5", design_type = "teacher_forced_desn", DESN_D = 2L, DESN_n = 24L, DESN_m = 5L, alpha = 0.20, rho = 0.80, act_f = "tanh", act_k = "identity", pi_w = 0.25, pi_in = 1.00, washout = 60L, add_bias = TRUE)
      ),
      backends = list(
        list(
          backend_id = "empirical_train_interval",
          inference = "baseline",
          primary = FALSE,
          priors = "none",
          coverage_levels = c(0.80, 0.90),
          learning_rates = NA_real_,
          design_ids = "none"
        ),
        list(
          backend_id = "rqr_desn_teacher_forced_mcmc",
          inference = "mcmc",
          primary = TRUE,
          priors = c("ridge", "rhs_ns"),
          coverage_levels = c(0.80, 0.90),
          learning_rates = c(0.50, 1.00, 1.50),
          design_ids = "all"
        ),
        list(
          backend_id = "rqr_desn_teacher_forced_vb",
          inference = "vb",
          primary = FALSE,
          priors = "ridge",
          coverage_levels = 0.80,
          learning_rates = 1.00,
          design_ids = c("desn_D1_n32_m5", "desn_D2_n24_m5"),
          note = "representative sidecar only; uncertainty not calibrated"
        )
      )
    )
  )
)
