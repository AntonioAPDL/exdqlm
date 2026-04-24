# QDESN Dynamic P90 Steeper-Trend N300/M50 Relaunch Setup

Date: 2026-04-24
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Scope

This relaunch reuses the promoted period-90 steeper-trend dynamic dataset
surface and changes only the QDESN reservoir/readout capacity.

The finished p90 baseline remains preserved under its original `n100/m30`
configuration. This relaunch uses a new named configuration so that the
larger reservoir is auditable and comparable.

## New Configuration

Defaults:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_defaults.yaml`

Full grid:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_full_grid.csv`

Campaign roots:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation`
- `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation`

## DESN Profile

Profile name:

- `deep_d3_n300x3_skip100_w300_m50`

| Field | Value |
|---|---:|
| Layers `D` | `3` |
| Neurons per layer `n` | `300, 300, 300` |
| Bridge widths `n_tilde` | `300, 300` |
| Random features `m` | `50` |
| Alpha per layer | `0.25, 0.25, 0.25` |
| Rho per layer | `0.95, 0.95, 0.95` |
| State activation `act_f` | `tanh, tanh, tanh` |
| Bridge activation `act_k` | `identity, identity, identity` |
| Recurrent sparsity `pi_w` | `0.1, 0.1, 0.1` |
| Input sparsity `pi_in` | `1.0, 1.0, 1.0` |
| Washout | `300` |
| Bias | `TRUE` |
| DESN seed | `123` |

The profile name intentionally uses `n300` and `m50` so it matches the actual
architecture. This avoids carrying a misleading `n100/m30` label into the new
validation outputs.

## Inference And Storage Policy

The inference policy is unchanged from the closed p90 baseline:

- VB uses LDVB with `max_iter = 300`
- MCMC uses slice sampling with `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`
- MCMC still uses `init_from_vb = TRUE`
- RHS/RHS-NS tau warmup remains enabled
- EXAL `(sigma, gamma)` warmup remains enabled

The storage policy keeps the new leaner MCMC warm-start behavior:

- `outputs.keep_mcmc_vb_init = FALSE`

This means the VB warm start is used in memory to initialize MCMC, but VB-init
fit artifacts are not persisted inside saved MCMC forecast objects.

## Launch Policy

Host capacity at setup:

- logical CPUs: `64`
- available memory: about `435 GiB`
- `/home` free space: about `351 GiB`

Chosen launch policy:

- full `144`-fit launch
- no smoke execution, per user instruction
- full preflight before detached launch
- `16` load-balanced root workers
- one computational thread per worker

Grid scope:

- roots: `36`
- expanded fits: `144`
- datasets: `18` source windows
- priors: `ridge`, `rhs_ns`
- methods: `vb`, `mcmc`
- likelihoods: `al`, `exal`

## Verification Before Launch

Required gates:

- defaults parse
- full grid validates against defaults
- focused config test passes
- full `prepare-only` preflight passes
- branch committed before detached launch
