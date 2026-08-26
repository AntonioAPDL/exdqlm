# Independent Q-DESN origin-horizon attribution closeout

Decision: `ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED`

Phase: `full`; jobs: 21/21; sources: 7.
Verified pilot jobs reused: 6; newly executed full-phase jobs: 15.
The authoritative 1,000-target metric and posterior-predictive recursion are unchanged.
The balanced 990-target rectangle is diagnostic sensitivity evidence only.
No article promotion or automatic tau0 launch is authorized by this script.

## Main findings

- All 7 cells are covariance-dominant across forecast origins; the origin covariance fraction ranges from 0.931 to 0.961.
- Late/early lead-MAE ratios range from 0.970 to 1.087, so long-horizon escalation is not the primary mechanism.
- Removing the truncated final origin changes posterior mean MAE by at most 1.21% and interval width by at most 1.04%.
- RHS-scale median Spearman associations range from 0.018 to 0.077 in absolute value; no cell satisfies the predeclared tau0 causal gate.
- Error modes: mixed_location_and_dispersion=1, posterior_dispersion_dominant=4, posterior_location_error_dominant=2.

## Cell diagnoses

- `imi_v1_source_055` (laplace, AL-RHS, p=0.05): global_cross_origin_posterior_dependence; late/early MAE ratio = 1.087; origin covariance fraction = 0.931; error mode = posterior_dispersion_dominant; tau0 causal pilot eligible = FALSE; next action = `retain_tau0_and_audit_common_mode_uncertainty`.
- `imi_v1_source_073` (normal, AL-RHS, p=0.05): global_cross_origin_posterior_dependence; late/early MAE ratio = 0.970; origin covariance fraction = 0.961; error mode = posterior_location_error_dominant; tau0 causal pilot eligible = FALSE; next action = `target_case_specific_location_and_design_bias`.
- `imi_v1_source_075` (normal, exAL-RHS, p=0.05): global_cross_origin_posterior_dependence; late/early MAE ratio = 1.003; origin covariance fraction = 0.957; error mode = posterior_location_error_dominant; tau0 causal pilot eligible = FALSE; next action = `target_case_specific_location_and_design_bias`.
- `imi_v1_source_078` (laplace, AL-RHS, p=0.5): global_cross_origin_posterior_dependence; late/early MAE ratio = 1.051; origin covariance fraction = 0.953; error mode = posterior_dispersion_dominant; tau0 causal pilot eligible = FALSE; next action = `retain_tau0_and_audit_common_mode_uncertainty`.
- `imi_v1_source_080` (laplace, exAL-RHS, p=0.5): global_cross_origin_posterior_dependence; late/early MAE ratio = 1.031; origin covariance fraction = 0.953; error mode = posterior_dispersion_dominant; tau0 causal pilot eligible = FALSE; next action = `retain_tau0_and_audit_common_mode_uncertainty`.
- `imi_v1_source_082` (gausmix, exAL-RHS, p=0.05): global_cross_origin_posterior_dependence; late/early MAE ratio = 1.020; origin covariance fraction = 0.961; error mode = mixed_location_and_dispersion; tau0 causal pilot eligible = FALSE; next action = `retain_tau0_and_audit_common_mode_uncertainty`.
- `imi_v1_source_083` (gausmix, exAL-RHS, p=0.25): global_cross_origin_posterior_dependence; late/early MAE ratio = 0.981; origin covariance fraction = 0.957; error mode = posterior_dispersion_dominant; tau0 causal pilot eligible = FALSE; next action = `retain_tau0_and_audit_common_mode_uncertainty`.
