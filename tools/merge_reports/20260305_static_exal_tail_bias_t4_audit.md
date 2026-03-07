# Static exAL Tail-Bias Audit (`T4`)

## Scope

This note completes `T4` of the static `exAL` tail-bias audit:

- cross-check the static `MCMC` implementation against the same quantile-fixed GAL / `exAL` hierarchy used in `T2`
- compare the static `MCMC` target against the static `VB` target at the level of shared posterior ingredients
- distinguish exact posterior kernels from approximation-only branches in the current code

Inputs:

- frozen review run:
  - `results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734`
- theory source:
  - `/data/muscat_data/jaguir26/DQLM-and-BQR---Theory/exAL_Original.pdf`
- code under audit:
  - `R/exal_static_mcmc.R`
  - `R/exal_static_LDVB.R`
  - `R/utils.R`

Generated `T4` artifacts:

- `results/sim_suite_static/audits/static_exal_tail_bias_t4_20260305/t4_mcmc_vb_consistency.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t4_20260305/t4_kernel_equivalence_checks.csv`

## Main Result

For the frozen rich static run, the static `MCMC` implementation is targeting the same posterior object as the audited static `VB` implementation **when the gamma kernel is `rw` or `laplace_rw`**.

The current frozen run uses:

| Tau | Gamma kernel used in run | Exact posterior kernel? |
|---|---|---|
| `0.05` | `rw` | `TRUE` |
| `0.95` | `rw` | `TRUE` |

Therefore, for the run that motivated the tail-bias concern, the `MCMC` tail shift is **not** explained by an obviously wrong `gamma` transition kernel.

## Consistency Summary

| Component | Update type | Verdict | Comment |
|---|---|---|---|
| Latent augmentation hierarchy | shared hierarchy | `consistent` | static `MCMC` uses the same quantile-fixed GAL / `exAL` augmentation as the original paper |
| `beta` conditional | exact Gibbs | `consistent` | matches the original paper's Normal update |
| `v` conditional | exact Gibbs | `consistent` | matches the original paper's GIG update |
| `s` conditional | exact Gibbs | `consistent` | matches the original paper's truncated-Normal update |
| `sigma` conditional | exact Gibbs | `consistent` | matches the original paper's GIG update |
| gamma support / transform | shared transform | `consistent` | same bounded `gamma` support and `eta` logit transform |
| `gamma` with `rw` / `laplace_rw` | exact MWG | `consistent_when_using_rw_or_laplace_rw` | these kernels target the exact conditional through MH accept-reject |
| `gamma` with `laplace_local` | approximate draw | `not_exact_posterior_kernel` | this branch is not exact MCMC and should not be used for signoff |
| shared `A/B/C/lambda` map | shared posterior ingredients | `consistent` | `VB` and `MCMC` use the same quantile-fixed GAL parameterization |
| shared priors | shared priors | `consistent` | no prior mismatch found between static `VB` and static `MCMC` |

## Numeric Kernel Checks

The following checks were run on frozen kept draws (`draw_index = 500`) at both tail quantiles.

For each case, I compared two mathematically equivalent representations of the same conditional kernel and measured the maximum centered log-kernel difference on a deterministic grid.

| Tau | `v` kernel diff | `s` kernel diff | `sigma` kernel diff | `gamma` kernel diff |
|---|---:|---:|---:|---:|
| `0.05` | `1.78e-15` | `1.07e-14` | `0` | `1.86e-09` |
| `0.95` | `1.33e-15` | `3.41e-13` | `0` | `4.66e-10` |

Interpretation:

- the static `MCMC` code matches the expected conditional kernels to numerical precision on frozen tail states
- no algebraic mismatch was found in the `MCMC` full conditional structure for:
  - `v`
  - `s`
  - `sigma`
  - `gamma | rest`

## Consequence for the Tail-Bias Investigation

`T4` changes the diagnosis in an important way:

- the current rich static run is not suffering from a clearly wrong `MCMC` target
- both the current `VB` audit (`T3`) and the current `MCMC` audit (`T4`) point away from a blatant posterior-target mismatch
- therefore the remaining static `exAL` tail issue is more likely to be one of:
  - a shared problem outside the already audited core formulas
  - approximation quality in `VB`
  - model mismatch for the current simulated DGP

## Important Caveat

The function still exposes `mh.proposal = "laplace_local"`.

That branch:

- samples `eta` from a local Gaussian approximation centered at the mode
- does **not** apply an MH acceptance correction
- therefore does **not** preserve the exact posterior target

This did **not** affect the frozen rich static run because that run used `rw`, but it remains an important implementation caveat for future runs and signoff decisions.
