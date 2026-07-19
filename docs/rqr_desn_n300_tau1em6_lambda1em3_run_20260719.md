# RQR-DESN n300 tau1e-6 learned-scale production run

Status: frozen launch contract; article updates blocked until the full run is
complete and audited.

## Purpose

This run tests the article-congruent RQR-DESN interval study under a larger
single-layer DESN readout and stronger RHS global shrinkage. It uses the same
train/test split, DGP families, interval scoring, and no-response-likelihood
contract as the previous article-congruent RQR-DESN lane.

## Default dynamic DESN and prior specification

The dynamic stage uses one shared DESN feature specification for all
package-side dynamic competitors:

```text
D = 1
n = 300 per layer
m = 60
alpha = 0.20
rho = 0.95
tau0 = 1e-6
```

The RQR learned-scale MCMC row uses

```text
lambda ~ Gamma(1e-3, 1e-3)
```

on the training-response-variance standardized RQR loss scale. Endpoint
forecasts and interval metrics remain on the original response scale.

## Frozen config

```text
config/rqr_desn/rqr_desn_article_congruent_n300_tau1em6_lambda1em3_20260719.R
```

The package-ready denominator remains:

```text
8040 package-ready rows
1340 external joint-QVP contract rows
9380 total manifest rows
```

The package-ready rows include the empirical interval baseline, fixed-rate
RQR-DESN continuity grid, learned-scale RQR-DESN, and independent AL Q-DESN
pair. The joint QVP row remains an external contract row in this package-side
runner.

## Launch policy

Because the machine was already under high CPU and memory load when the run was
prepared, the first production launch should use one single-threaded low
priority worker. Additional workers should be added only after checking memory,
swap, and early run stability.

The run is guarded and requires:

```text
--confirm-full-launch true
```

## Future tuning policy

Do not tune during this frozen run. Wait for the full run to finish and then
audit:

- interval score degradation versus the empirical baseline;
- empirical coverage error;
- nonfinite diagnostics;
- nonpositive interval widths;
- learned-scale lambda summaries;
- performance by DGP family and coverage level.

Only mechanisms that perform very poorly should receive follow-up tuning, and
the first follow-up axes should be `alpha` and `tau0`. Those follow-ups should
be new frozen configs, not modifications to this one.
