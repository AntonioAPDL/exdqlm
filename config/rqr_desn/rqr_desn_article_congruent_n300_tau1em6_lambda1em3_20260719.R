rqr_desn_article_congruent_simulation_config <- list(
  config_id = "rqr_desn_article_congruent_n300_tau1em6_lambda1em3_20260719",
  status = "frozen_guarded_no_full_launch_n300_tau1em6_lambda1em3",
  created_at = "2026-07-19",
  package_side_only = TRUE,
  article_update_allowed = FALSE,
  production_launch_requires = "--confirm-full-launch true",
  interpretation = list(
    native_estimand = "central_prediction_interval",
    rqr_generalized_bayes = TRUE,
    rqr_response_likelihood = FALSE,
    rqr_response_predictive_draws = FALSE,
    rqr_recursive_response_sampling = FALSE,
    learned_scale_interpretation = "global inverse RQR loss scale on the training-response-variance standardized loss scale; not a response variance and not an uncertainty-calibration guarantee",
    qdesn_competitor_object = "targeted_quantile_readout_pair",
    qdesn_scalar_predictive_density_from_pair = FALSE,
    crossing_claim_for_rqr = FALSE,
    future_tuning_scope = "After this frozen run finishes, poor-performing mechanisms may be followed by targeted alpha or tau0 tuning only; no article update is authorized from this launch alone."
  ),
  split_contract = list(
    generated_length = 12000L,
    dgp_warmup = 2000L,
    effective_length = 10000L,
    desn_washout_start = 7501L,
    desn_washout_end = 8000L,
    calibration_start = 8001L,
    calibration_end = 8500L,
    final_fit_start = 8501L,
    final_fit_end = 9000L,
    test_start = 9001L,
    test_end = 10000L,
    calibration_length = 500L,
    final_fit_length = 500L,
    test_length = 1000L,
    rolling_one_step = TRUE,
    refit_during_test = FALSE,
    max_lead = 30L,
    origin_stride = 30L
  ),
  scientific_contract = list(
    coverage_levels = c(0.80, 0.90),
    quantile_grid = c(0.05, 0.10, 0.50, 0.90, 0.95),
    coverage_to_quantile_pair = list(
      c0p80 = c(0.10, 0.90),
      c0p90 = c(0.05, 0.95)
    ),
    rqr_fixed_learning_rates = c(0.50, 1.00, 1.50),
    rqr_learned_scale_prior = list(shape = 1e-3, rate = 1e-3, power = 1),
    calibration_qualification_tolerance = 0.025,
    primary_metric = "interval_score_mean",
    secondary_metric = "mean_width",
    winner_rule = "coverage-qualified first; interval score primary; width secondary; no qualified winner if all miss coverage tolerance",
    poor_performance_followup_rule = "Only after the full frozen run and promotion audit, inspect mechanisms with large interval-score degradation, large coverage error, nonpositive width, or nonfinite diagnostics; then plan targeted alpha or tau0 follow-up runs.",
    forbidden_argument_names = c("target_p", "p0")
  ),
  mcmc_control = list(
    n_burn = 1000L,
    n_mcmc = 1500L,
    thin = 1L,
    store_latent_draws = FALSE,
    precision_beta = list(strategy = "off"),
    rqr_chain_count = 3L,
    qdesn_chain_count = 2L,
    swapped_root_chain = TRUE,
    dispersed_root_chain = TRUE
  ),
  smoke_control = list(
    n_burn = 8L,
    n_mcmc = 10L,
    rqr_chain_count = 1L,
    qdesn_chain_count = 1L,
    max_scenarios = 6L
  ),
  vb_role = list(
    include_in_primary_evidence = FALSE,
    allowed_uses = c("screening", "initialization", "computational_sidecar"),
    forbidden_label = "RQR VB evidence",
    allowed_label = "Q-DESN-VB-warm-started RQR MCMC",
    learned_scale_status = "deferred until MCMC learned-scale target is validated"
  ),
  analysis_scale = list(
    rqr_loss_reference_scale = "train_response_variance",
    loss_reference_floor = 1e-8,
    interpretation = "RQR learned lambda is on the training-response-variance standardized loss scale; endpoints and metrics remain on the original response scale."
  ),
  priors = list(
    rqr_rhs_ns = list(type = "rhs_ns", tau0 = 1e-6, a_zeta = 2, b_zeta = 1, s2 = 1, n_inner = 1L, shrink_intercept = FALSE),
    qdesn_rhs_ns = list(type = "rhs_ns", tau0 = 1e-6, a_zeta = 2, b_zeta = 1, s2 = 1, n_inner = 1L, shrink_intercept = FALSE)
  ),
  stages = list(
    list(
      stage_id = "fixed_design_endpoint_recovery",
      stage_family = "fixed_design",
      purpose = "endpoint recovery and held-out interval scoring with oracle central interval endpoints",
      replicates = 100L,
      calibration_n = 500L,
      final_fit_n = 500L,
      test_n = 1000L,
      oracle_endpoints = TRUE,
      design = list(
        design_id = "sparse_correlated_linear_p20",
        design_type = "fixed_sparse_correlated",
        p = 20L,
        active = 5L,
        predictor_correlation = 0.50
      ),
      dgp_families = list(
        list(family_id = "symmetric_gaussian", innovation_family = "gaussian", params = list(mean = 0, sd = 1)),
        list(family_id = "skewed_centered_gamma", innovation_family = "centered_gamma", params = list(shape = 2, scale = 1)),
        list(family_id = "student_t5", innovation_family = "student_t", params = list(df = 5, scale = 1)),
        list(family_id = "heteroskedastic_gaussian", innovation_family = "gaussian", params = list(mean = 0, sd = 1), heteroskedastic = TRUE)
      )
    ),
    list(
      stage_id = "dynamic_rolling_one_step",
      stage_family = "dynamic_desn",
      purpose = "article-congruent rolling one-step interval forecasting with D1 n300 m60 DESN features and matched quantile-pair competitors",
      replicates = 30L,
      calibration_n = 500L,
      final_fit_n = 500L,
      test_n = 1000L,
      oracle_endpoints = TRUE,
      design = list(
        design_id = "desn_D1_n300_m60_alpha0p20_rho0p95",
        design_type = "rolling_one_step_desn",
        DESN_D = 1L,
        DESN_n = 300L,
        DESN_m = 60L,
        alpha = 0.20,
        rho = 0.95,
        act_f = "tanh",
        act_k = "identity",
        pi_w = 0.30,
        pi_in = 1.00,
        washout = 500L,
        add_bias = TRUE
      ),
      dgp_families = list(
        list(family_id = "gaussian_bridge", innovation_family = "gaussian", params = list(mean = 0, sd = 1)),
        list(family_id = "laplace_bridge", innovation_family = "laplace", params = list(location = 0, scale = 1)),
        list(family_id = "gaussian_mixture_bridge", innovation_family = "gaussian_mixture", params = list(weights = c(0.1, 0.9), means = c(0, 1), sds = c(0.5, 1.5), center = TRUE)),
        list(family_id = "student_t_heavy_tail", innovation_family = "student_t", params = list(df = 5, scale = 1)),
        list(family_id = "asymmetric_tail", innovation_family = "asymmetric_laplace", params = list(tau = 0.25, scale = 1)),
        list(family_id = "persistent_heavy_tail", innovation_family = "student_t", params = list(df = 3, scale = 1), volatility = "persistent"),
        list(family_id = "regime_shift", innovation_family = "gaussian", params = list(mean = 0, sd = 1), regime_shift = TRUE),
        list(family_id = "nonlinear_reservoir", innovation_family = "gaussian", params = list(mean = 0, sd = 1), nonlinear = TRUE),
        list(family_id = "dynamic_heteroskedastic", innovation_family = "gaussian", params = list(mean = 0, sd = 1), heteroskedastic = TRUE)
      )
    )
  ),
  competitors = list(
    list(
      method_id = "empirical_train_interval",
      method_family = "baseline",
      inference = "none",
      implemented_adapter = "empirical_interval",
      primary = TRUE,
      coverage_levels = c(0.80, 0.90),
      learning_rates = NA_real_,
      learning_rate_mode = "fixed",
      prior_type = "none",
      chain_count = 0L
    ),
    list(
      method_id = "rqr_desn_rhs_mcmc_fixed_grid",
      method_family = "rqr_desn",
      inference = "mcmc",
      implemented_adapter = "rqr_mcmc",
      primary = TRUE,
      coverage_levels = c(0.80, 0.90),
      learning_rates = c(0.50, 1.00, 1.50),
      learning_rate_mode = "fixed",
      prior_type = "rqr_rhs_ns",
      chain_count = 3L,
      adapter_note = "Fixed-rate continuity benchmark using the previous nominal grid on the training-response-variance standardized RQR loss scale."
    ),
    list(
      method_id = "rqr_desn_rhs_mcmc_learned_scale",
      method_family = "rqr_desn",
      inference = "mcmc",
      implemented_adapter = "rqr_mcmc",
      primary = TRUE,
      coverage_levels = c(0.80, 0.90),
      learning_rates = 1.00,
      learning_rate_mode = "learned_scale",
      lambda_prior = list(shape = 1e-3, rate = 1e-3, power = 1),
      prior_type = "rqr_rhs_ns",
      chain_count = 3L,
      adapter_note = "Production learned inverse RQR loss scale: Gamma(1e-3,1e-3) prior and lambda^T generalized-Bayes target on the training-response-variance standardized RQR loss scale."
    ),
    list(
      method_id = "independent_al_qdesn_rhs_mcmc",
      method_family = "independent_qdesn_pair",
      inference = "mcmc",
      implemented_adapter = "independent_al_pair",
      primary = TRUE,
      coverage_levels = c(0.80, 0.90),
      learning_rates = NA_real_,
      learning_rate_mode = "fixed",
      prior_type = "qdesn_rhs_ns",
      chain_count = 2L
    ),
    list(
      method_id = "joint_al_qdesn_qvp_rhs_mcmc",
      method_family = "joint_qdesn_pair",
      inference = "mcmc",
      implemented_adapter = "external_article_joint_qvp_required",
      primary = TRUE,
      coverage_levels = c(0.80, 0.90),
      learning_rates = NA_real_,
      learning_rate_mode = "fixed",
      prior_type = "qvp_rhs",
      chain_count = 2L,
      adapter_note = "Article-side joint QVP kernel is not an exported package API; package runner records this method as an external-adapter contract until wired."
    )
  ),
  output_contract = list(
    output_root = "reports/rqr_desn_article_congruent_simulation",
    required_files = c(
      "manifest.csv",
      "scenario_manifest.csv",
      "scenario_manifest_summary.csv",
      "dgp_manifest.csv",
      "method_manifest.csv",
      "split_contract.csv",
      "interval_metrics.csv",
      "replicate_pairwise_deltas.csv",
      "mcmc_diagnostics.csv",
      "failure_log.csv",
      "run_status.csv",
      "readiness_gates.csv",
      "closeout.md",
      "session_info.txt",
      "git_state.txt",
      "output_hashes.csv",
      "README.md"
    )
  )
)
