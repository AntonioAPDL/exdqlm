# Inter-layer residual Q-DESN ablation

## Scope

This implementation compares exactly two reservoir structures:

1. the existing plain Q-DESN; and
2. an inter-layer residual Q-DESN.

Both use the existing asymmetric-Laplace variational readout and RHS-NS prior.
The global RHS scale is fixed at `tau0 = 0.1`. No exAL shape estimation, MCMC,
quantile synthesis, rolling origins, or external competitive models enter the
study.

## Residual equation

For layer `d >= 2`, the ordinary candidate state is

```text
omega[t,d] = f(W[d] h[t-1,d] + Win[d] htilde[t,d-1]).
```

The residual candidate is

```text
omega_res[t,d] = f(W[d] h_res[t-1,d] + Win[d] htilde_res[t,d-1])
                 + P[d] htilde_res[t,d-1].
```

The leaky update is unchanged. `P[d]` is identity when dimensions agree and a
deterministic rectangular identity otherwise. The focused experiment uses
equal widths and identity reducers, so every scientific comparison uses a
literal identity skip. The skip multiplier is fixed at one and is not tuned.

## Pairing contract

For each candidate and reservoir seed, the ordinary reservoir is generated once
by the current `qdesn_fit_vb(..., fit_readout = FALSE)` implementation. The
residual states are rerolled with the returned `W`, `Win`, and `Q`. Their hashes
are stored with both arms. The ordinary state reroll is checked against the
legacy design to a maximum absolute tolerance of `1e-10`.

## Data contract

The simulated series must have at least 1100 observations. Only the first 1100
are used.

| Stage | Observed history | Washout | Readout fit | Origin | Scored targets |
|---|---:|---:|---:|---:|---:|
| Validation | 1--900 | 1--500 | 501--900 | 900 | 901--1000 |
| Final | 1--1000 | 1--500 | 501--1000 | 1000 | 1001--1100 |

Each stage uses one recursive 100-step forecast. Future observations are never
teacher-forced.

## Selected and fixed quantities

Selected: `D`, `n`, `m`, `alpha`, `rho`.

Fixed: AL likelihood, VB, `tau0 = 0.1`, identity residual strength, `pi_w = 0.1`,
`pi_in = 1`, `tanh`, identity reduced-state activation, identity reducers,
training-only input/readout scaling, and an unshrunk intercept.

## Execution

```bash
Rscript scripts/run_qdesn_residual_skip_single_origin.R \
  --input=/data/qdesn/simulated_series.csv \
  --column=y \
  --output=/data/qdesn/residual_ablation_v1
```

Use `--quick=true` only to validate wiring. The complete run writes cell-level
checkpoints, rankings, final paired tables, three compact figures, and a single
RDS result object.
