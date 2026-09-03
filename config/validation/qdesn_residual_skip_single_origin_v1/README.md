# Q-DESN inter-layer residual ablation

This configuration implements a deliberately narrow comparison between:

- `plain`: the existing Q-DESN state recursion; and
- `interlayer_residual`: the same recursion with an identity skip from the
  reduced current state of layer `d - 1` into the candidate state of layer
  `d`.

The two arms reuse the same `W`, `Win`, and `Q` matrices for every paired
reservoir seed. The first layer and the readout are unchanged.

## Immutable statistical contract

- Simulated series length: 1100.
- Washout: observations 1--500.
- Validation fit: observations 501--900.
- Single validation origin: 900; targets 901--1000.
- Final fit: observations 501--1000.
- Single final origin: 1000; targets 1001--1100.
- Quantiles: 0.50, 0.75, 0.95.
- Likelihood: asymmetric Laplace (`gamma = 0`).
- Inference: existing variational Bayes implementation.
- Readout prior: existing RHS-NS implementation with `tau0 = 0.1`.
- Tuned parameters only: `D`, `n`, `m`, `alpha`, `rho`.
- No rolling origins, exAL fit, MCMC, synthesis, or external competitors.

## Run

From the repository root:

```bash
Rscript scripts/run_qdesn_residual_skip_single_origin.R \
  --input=/data/qdesn/simulated_series.csv \
  --column=y \
  --output=/data/qdesn/residual_ablation_v1
```

Use `--quick=true` for a small software smoke run. Cell-level RDS checkpoints
are written below the output directory and reused on restart.
