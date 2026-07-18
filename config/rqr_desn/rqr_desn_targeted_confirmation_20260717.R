rqr_desn_broad_simulation_config <- list(
  config_id = "rqr_desn_targeted_confirmation_20260717",
  status = "frozen_targeted_confirmation_no_article_update",
  launch_authorized = TRUE,
  article_update_allowed = FALSE,
  package_side_only = TRUE,
  created_at = "2026-07-17",
  implementation_pin = list(
    branch = "feature/rqr-desn-readout-20260716",
    broad_run = "reports/rqr_desn_broad_simulation/rqr_desn_broad_run_20260716-232550_git_3280ad377f99",
    broad_audit = "reports/rqr_desn_broad_simulation/results_audit_promotion_20260717",
    broad_audit_commit = "c910304",
    recommendation = "promote_to_targeted_confirmation"
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
    vb_role = "excluded_from_targeted_confirmation",
    article_claims_allowed = FALSE
  ),
  targeted_confirmation = list(
    candidate_grid = "reports/rqr_desn_broad_simulation/results_audit_promotion_20260717/targeted_confirmation_candidate_grid.csv",
    fixed_design_replicates = 24L,
    dynamic_replicates = 18L,
    seed_base = 10170000L,
    include_empirical_baseline = TRUE,
    include_vb = FALSE,
    candidate_roles = c("winner", "nearest_nominal_coverage", "score_runner_up"),
    purpose = "independent-seed confirmation of broad-audit MCMC winners and calibration neighbors"
  ),
  output_contract = list(
    output_root = "reports/rqr_desn_broad_simulation",
    required_files = c(
      "manifest.csv",
      "scenario_manifest.csv",
      "scenario_manifest_summary.csv",
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
    )
  ),
  randomization = list(
    seed_base = 10170000L,
    seed_rule = "fresh targeted-confirmation seed_base + canonical scenario_index",
    scenario_order = c(
      "stage_index",
      "family_index",
      "replicate_id",
      "coverage_index",
      "design_index",
      "backend_index",
      "prior_index",
      "learning_rate_index",
      "targeted_candidate_index"
    ),
    seed_collision_policy = "fail",
    deterministic_grid_order = TRUE
  ),
  scoring = list(
    primary = c("interval_score_mean", "empirical_coverage", "mean_width"),
    secondary = c("midpoint_mae", "endpoint_mae", "finite_lower", "finite_upper", "ordered_intervals", "positive_mean_width"),
    promotion_gate = list(
      finite_ordered_positive_width = TRUE,
      failure_rows_allowed = 0L,
      compare_against_empirical_interval = TRUE,
      no_article_promotion_from_confirmation_only = TRUE,
      confirmation_required_before_article_update = TRUE
    )
  ),
  mcmc_control = list(
    n_burn = 600L,
    n_mcmc = 900L,
    thin = 1L,
    store_latent_draws = FALSE,
    precision_beta = list(strategy = "off"),
    chain_count = 1L
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
      purpose = "confirm RQR interval behavior on independent fixed-design DGP seeds with oracle endpoints",
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
      )
    ),
    list(
      stage_id = "teacher_forced_desn_dynamic",
      purpose = "confirm teacher-forced RQR-DESN interval readouts on independent dynamic DGP seeds",
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
      )
    )
  )
)
