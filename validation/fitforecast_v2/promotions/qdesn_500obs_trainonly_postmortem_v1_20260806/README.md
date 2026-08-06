# Q-DESN Train-Only Mechanistic Postmortem v1

- Decision: `STOP_REASSESS_MODEL_OR_SAMPLER`
- Model compute launched: `FALSE`
- Article update allowed: `FALSE`
- Candidate rows: `0`

## Central finding

The compact AL mechanisms do not transfer across sources. The frozen article source
degrades in every lead and origin band, whereas the untouched confirmation source
contains a development-only improvement, strongest for the state-residual arm.
The discrepancy is therefore not a long-horizon-only failure and does not authorize
another scalar hyperparameter screen.

## Overall median ratios

            arm_code mae_ratio check_ratio win_fraction_mae
         compact_raw  1.091716    1.026465            0.039
 compact_state_resid  1.159394    1.046380            0.015

            arm_code mae_ratio check_ratio win_fraction_mae
         compact_raw 0.9784069   0.9984268            0.581
 compact_state_resid 0.9443005   0.9939099            0.766

The exAL geometry gate also remains closed because all tested arms retain excessive
lag-one autocorrelation. Reparameterization or a different package-supported update
must be justified before further exAL MCMC compute.
