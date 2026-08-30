# Independent exDQLM MCMC rolling-state repair v1

This is the compact, tracked integration packet for the completed independent
single-quantile exDQLM MCMC rolling-state repair. It contains no fitted-model
binary, raw execution log, article file, or application artifact.

## Scientific decision

`READY_FOR_INTEGRATION_REPLACE_COMPLETE_EXDQLM_MCMC_BLOCK`

The historical validation bridge requested VB-only exAL fields from an MCMC
fit and silently substituted a zero forecast-error mean. The corrected bridge
uses posterior-predictive moments from paired sigma and gamma MCMC draws.
Fit RMSE and first-origin forecasts are invariant; all nine aggregate forecast
MAE and check-loss values improve.

| Family | tau | Forecast MAE | Gain | Check loss | Gain |
|---|---:|---:|---:|---:|---:|
| gausmix | 0.05 | 23.913 -> 4.054 | 83.0% | 5.857 -> 1.559 | 73.4% |
| gausmix | 0.25 | 8.940 -> 1.690 | 81.1% | 5.650 -> 4.514 | 20.1% |
| gausmix | 0.50 | 2.221 -> 1.932 | 13.0% | 5.610 -> 5.556 | 1.0% |
| laplace | 0.05 | 22.441 -> 4.069 | 81.9% | 5.154 -> 1.885 | 63.4% |
| laplace | 0.25 | 6.810 -> 1.344 | 80.3% | 5.105 -> 4.386 | 14.1% |
| laplace | 0.50 | 2.014 -> 1.337 | 33.6% | 5.206 -> 5.082 | 2.4% |
| normal | 0.05 | 16.227 -> 1.227 | 92.4% | 4.313 -> 1.066 | 75.3% |
| normal | 0.25 | 6.636 -> 1.078 | 83.8% | 4.133 -> 3.264 | 21.0% |
| normal | 0.50 | 1.659 -> 1.161 | 30.0% | 4.115 -> 4.029 | 2.1% |

## Integration contract

1. Merge this dedicated branch into the latest shared validation authority.
2. Run the packet verifier before consuming any result.
3. Replace the complete nine-cell MCMC exDQLM point block and the complete
   twenty-seven-role exDQLM interval block. Do not cherry-pick cells.
4. Preserve every DQLM, Q-DESN, VB, joint-study, and application value.
5. Regenerate all dependent tables, interval figures, rankings, prose, and
   manifests from unrounded values, then compile both manuscripts.
6. Publish Article-v2 and Overleaf only from the integration lane.

Point metrics score the fixed posterior-summary path. Interval-table means are
means of draw-level nonlinear metrics. They are separate estimands and must not
be substituted for one another.

Verification command:

```bash
Rscript validation/fitforecast_v2/scripts/verify_independent_exdqlm_mcmc_rolling_state_fix_v1_promotion.R
```
