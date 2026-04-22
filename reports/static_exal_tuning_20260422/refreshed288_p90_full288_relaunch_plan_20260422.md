# Refreshed288 Full Relaunch Plan on P90 Dynamic Datasets

Date: `2026-04-22`

## Purpose

This note defines the recommended full relaunch plan for the refreshed
validation study after synchronizing the dynamic source layer to the promoted
period-90 steeper-trend dataset scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

The relaunch should validate three things together:

1. the updated `0.4.0` shared package surface,
2. the promoted local canonical dynamic datasets, and
3. the refreshed `288`-case validation-study orchestration on this branch.

## Important Correction

This worktree does **not** contain Q-DESN-specific model functions, and that is
intentional.

So the relaunch should use:

- the current `0.4.0` package models in this branch, and
- the Q-DESN-derived warmup/default behavior that was normalized into the
  shared package layer,

not Q-DESN-only wrappers or rescue-specific machinery.

That means:

- dynamic VB uses `exdqlmLDVB()`,
- dynamic MCMC uses `exdqlmMCMC()`,
- static VB uses `exalStaticLDVB()`,
- static MCMC uses `exalStaticMCMC()`,
- and Q-DESN-only rescue overlays remain escalation-only rather than baseline.

## Study Geometry

The relaunched study should keep the same refreshed288 structure:

| block | count | formula |
|---|---:|---|
| dynamic | `72` | `3 families x 3 taus x 2 sizes x 2 models x 2 inference` |
| static paper | `72` | `3 families x 3 taus x 2 sizes x 2 models x 2 inference` |
| static shrink | `144` | `3 families x 3 taus x 2 sizes x 2 priors x 2 models x 2 inference` |
| total | `288` | `72 + 72 + 144` |

Using the current synchronized dataset registry:

- total dataset entries: `54`
- dynamic dataset entries: `18`
- static dataset entries: `36`
- method profiles: `16`

This confirms that the full relaunch is still a `288`-run study.

## Active Dataset Surface

### Dynamic source layer

Active dynamic scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Local canonical source root:

- [dlm_constV_p90_m0amp_highnoise_steepertrend_v1](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Dynamic contract:

- `9` canonical roots
- `18` canonical validation windows
- effective dynamic fit sizes:
  - `500`
  - `5000`

Important rule:

- only canonical `lastTT500` / `lastTT5000` windows belong in this validation
  repo’s canonical source layer;
- Q-DESN-only washout-materialized windows do not.

### Static source layer

Static datasets stay on the same refreshed source families used in the last big
relaunch:

- static paper sizes: `100`, `1000`
- static shrink sizes: `100`, `1000`
- shrinkage priors:
  - `ridge`
  - `rhs_ns`

Plain `rhs` remains excluded from the refreshed study.

## Common Study-Wide Runtime Contract

These should be pinned explicitly in the next relaunch surface.

### Shared posterior-scale normalization

- `mcmc.n_mcmc = 20000`
- `posterior_metric_draws = 20000`
- `vb_sampling_nd_draws = 20000`
- `vb_synthesis_n_samp = 20000`

Interpretation:

- both VB and MCMC outputs are normalized to the same `20k` posterior-draw
  scale for downstream metrics and comparisons.

### Shared long-budget core settings

- `vb.max_iter = 300`
- `vb.min_iter_elbo = 80`
- `vb.tol = 0.03`
- `static.vb.n_samp_xi = 1000`
- `dynamic.vb.n_samp = 20000`
- `mcmc.n_burn = 5000`
- `mcmc.n_mcmc = 20000`
- `mcmc.thin = 1`
- `mcmc.init_from_vb = TRUE`
- `mcmc.mh_proposal = "slice"`

These settings intentionally mirror the successful normalized refreshed288
budget shape, updated to the current package/default layer.

## Baseline Warmup Policy

The baseline should start from the normalized shared package defaults, not from
the old rescue stack.

### Shared package-default warmup expected at launch

#### Static and exAL-family VB

- light `(sigma, gamma)` VB warmup
- expected shared default profile:
  - `freeze_warmup_iters = 10`
  - `force_after_warmup = TRUE`
  - `postwarmup_damping = 0.6`
  - `postwarmup_damping_iters = 5`
  - `min_postwarmup_updates = 1`

#### Static and exAL-family MCMC

- light `(sigma, gamma)` MCMC warmup
- expected shared default profile:
  - `freeze_burnin_iters = 25`
  - `freeze_only_during_burn = TRUE`
  - `force_after_warmup = TRUE`
  - `delay_adapt_until_after_warmup = TRUE`
  - `delay_laplace_refresh_until_after_warmup = TRUE`

#### Static shrinkage prior

- automatic `rhs` / `rhs_ns` tau warmup
- expected shared default profile:
  - `freeze_tau_warmup_iters = 50`
  - `force_tau_after_warmup = TRUE`

### Baseline policy boundary

Keep these out of the baseline:

- Q-DESN-only rescue functions
- theta-freeze rescue
- latent-state rescue
- precision rescue
- row-local repair overlays

Those remain escalation tools, not starting defaults.

## Case-Specific Baseline Profiles

“Case-specific” here should mean **profile-specific**, not one ad hoc spec per
row. The right unit is the launch method profile.

That means:

- the dynamic lane uses distinct profiles for `dqlm` vs `exdqlm`, and for `vb`
  vs `mcmc`;
- the static paper lane uses separate `al` / `exal` and `vb` / `mcmc`
  profiles;
- the static shrink lane uses separate `ridge` and `rhs_ns` profiles, again by
  model and inference class.

The tracked method-profile matrix for this plan is:

- [refreshed288_p90_full288_method_profiles_20260422.csv](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/config/validation/refreshed288_p90_full288_method_profiles_20260422.csv)

### Key case-specific distinctions

#### Dynamic cases

- dynamic fit sizes stay `500` and `5000`
- dynamic VB:
  - `LDVB`
  - `max_iter = 300`
  - `min_iter_elbo = 80`
  - `n.samp = 20000`
- dynamic MCMC:
  - `slice`
  - `init_from_vb = TRUE`
  - `n_burn = 5000`
  - `n_mcmc = 20000`
  - `thin = 1`
- dynamic slice width:
  - `0.1`

Baseline dynamic launch policy:

- use shared package defaults first;
- do **not** preload theta / latent rescue into the baseline;
- keep those as predeclared retry overlays for the risky dynamic MCMC cases.

#### Static paper cases

- static paper sizes stay `100` and `1000`
- `paper` semantics continue to map to the ridge-style paper baseline
- static paper slice width:
  - `0.01`

#### Static shrink cases

- static shrink sizes stay `100` and `1000`
- shrinkage priors:
  - `ridge`
  - `rhs_ns`
- static shrink slice width:
  - `0.1`

For `rhs_ns`:

- rely on the shared automatic tau warmup baseline first
- do not start by restoring the old explicit heavy tau-freeze overlays

## Planned Full Relaunch Phases

The relaunch should reuse the phase structure that worked well in the recent
refreshed study.

### Phase 0: committed-state preflight

Before any launch:

1. regenerate manifests from committed state
2. verify dataset paths
3. verify method-profile resolution
4. write a fresh run contract
5. freeze the exact run tag

### Phase 1: smoke subset

Recommended smoke subset goal:

- cover all major profile families
- cover both dynamic fit sizes
- cover both static size levels
- cover both priors in the shrink lane
- cover both `vb` and `mcmc`
- cover both model families in each block

Recommended smoke size:

- `48` rows

Suggested composition:

- dynamic: `24`
- static paper: `8`
- static shrink ridge: `8`
- static shrink rhs_ns: `8`

This is large enough to test the full wiring but still small enough to inspect
manually.

### Phase 2: full static VB

- `108` rows

Purpose:

- confirm the static source layer and the new shared warmup defaults cleanly
  before touching long MCMC chains broadly.

### Phase 3: full dynamic VB

- `36` rows

Purpose:

- validate the new dynamic datasets and LDVB behavior separately from MCMC.

### Phase 4: full static MCMC

- `108` rows

Purpose:

- validate long-chain static behavior with the normalized `20k` posterior-scale
  contract.

### Phase 5: full dynamic MCMC

- `36` rows

Purpose:

- validate the new p90 dynamic datasets under the longest and riskiest lane.

## Escalation Policy

The baseline is intentionally clean. But the tracker should predeclare the
first retry overlays for known risk families so reruns remain disciplined.

### Dynamic exDQLM MCMC

If a `TT5000` dynamic `exdqlm` MCMC row fails under the baseline:

first retry overlay:

- theta-state warmup:
  - `freeze_burnin_iters = 100`
- latent-state warmup:
  - `freeze_burnin_iters = 100`
  - `mode = "u_st_pair"`

### Dynamic DQLM MCMC

If a `TT5000` dynamic `dqlm` MCMC row fails under the baseline:

first retry overlay:

- sigma-only DQLM warmup:
  - `freeze_burnin_iters = 50`

### Dynamic exDQLM VB

If a dynamic `exdqlm` VB row shows early latent instability:

first retry overlay:

- `sts` warmup:
  - `freeze_warmup_iters = 20`
  - `force_after_warmup = TRUE`

### Static `rhs_ns`

If a static `rhs_ns` row shows tau-instability under the shared baseline:

first retry overlay:

- VB:
  - extend tau warmup and increase minimum active iterations
- MCMC:
  - extend tau warmup beyond the shared `50`-iteration baseline

Important:

- these are **retry overlays**, not baseline settings.

## Run Naming And Tracking

Recommended run tag:

- `20260422_p90_full288_baseline_v1`

Recommended plan/tracker artifacts:

- [refreshed288_p90_full288_relaunch_tracker_20260422.yaml](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/config/validation/refreshed288_p90_full288_relaunch_tracker_20260422.yaml)
- [refreshed288_p90_full288_method_profiles_20260422.csv](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/config/validation/refreshed288_p90_full288_method_profiles_20260422.csv)

The prepare-only step should next produce:

- a fresh dataset registry keyed to the new dynamic source layer
- a fresh method registry under the new relaunch tag
- a fresh full manifest
- a fresh run contract
- smoke and phase-specific subset manifests

## Big Picture

The best next relaunch is:

- still the full refreshed `288`-case study,
- using the new local p90 dynamic datasets,
- using the current normalized `0.4.0` package layer,
- using the shared `20k` posterior-scale contract,
- and using explicit method-profile defaults rather than one universal blind
  spec.

That gives the cleanest test of the new datasets and the updated `0.4.0`
models, while still leaving room for disciplined retries if the new dynamic
surface behaves differently from the older one.
