# Family-QSpec Second-Wave Decision

## Accepted Policy

- Adopt the moderate MCMC rescue policy only.
- Do not adopt the aggressive policy-only rescue thresholds.
- Do not relax VB thresholds.
- Keep hard numerical failures excluded from scientific comparison.

## Action Summary

| action | count |
|---|---:|
| newly_eligible_under_second_wave_policy | 0 |
| hold_out_aggressive_policy_only | 25 |
| rerun_with_deeper_mcmc | 19 |
| debug_vb_then_targeted_refit | 5 |
| debug_model_then_resample | 21 |
| exclude_until_numerical_fix | 6 |
