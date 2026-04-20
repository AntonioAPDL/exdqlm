# QDESN Tau050 Run-Specific Remaining-Fail Program

Date: 2026-04-20  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Executive Summary

The best next move is **not** one more global warmup spec.

The best next move is a **run-specific recovery program** built around two
distinct numerical mechanisms now visible in the evidence:

1. a **latent-`v` post-thaw cluster**
2. an **EXAL ridge precision / Cholesky cluster**

This plan freezes that split, defines a concrete spec family for each cluster,
and sets a staged launch order that is:

- reproducible
- economical
- auditable
- easy to promote by cluster if the canaries succeed

Supporting postmortems:

- [sfreeze postmortem](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_failed_mcmc_sfreeze_postmortem_20260419.md)
- [representative completion wave postmortem](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_representative_completion_wave_postmortem_20260420.md)

Frozen mapping file:

- [run-specific cluster map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_run_specific_cluster_map.csv)

## 1) What We Know Now

### Remaining hard-fail surface

The current unresolved surface is the exact `15`-root remaining hard-fail set
frozen after the `sfreeze` relaunch:

- AL remaining hard fails: `7`
- EXAL remaining hard fails: `8`
- total remaining hard fails: `15`

Authoritative manifests:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv`

### Mechanism split

The evidence is no longer consistent with one universal failure story.

#### Cluster A: latent-`v` post-thaw instability

Dominant evidence from the `sfreeze` postmortem:

- remaining hard failures were still overwhelmingly:
  - `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`
- `14 / 15` were after thaw
- the surface concentrated in:
  - `fit_size = 5000`
  - `tau = 0.25 / 0.50`
  - especially `rhs_ns`, `gausmix`, and `laplace`

#### Cluster B: EXAL ridge precision / Cholesky instability

Dominant evidence from the completion gate:

- both `tau only` and `theta + tau` failed on:
  - `EXAL / laplace / tau 0.50 / 5000 / ridge`
- the exact failure was:
  - `chol.default(Prec + 1e-10 * diag(nrow(Prec)))`
  - leading minor not positive
- this happened during burn, after startup, inside the EXAL beta precision draw

That means we now need **two spec families**, not one.

## 2) Program Decision

Use the remaining `15` roots under a run-specific cluster map with:

- **one primary latent-`v` rescue spec** for the latent-`v` cluster
- **one primary EXAL ridge precision spec** for the EXAL ridge cluster
- **one fallback EXAL ridge precision spec** only if the primary precision spec
  still fails on the ridge canary

Do **not** fan out the same settings to all remaining roots.

## 3) Frozen Spec Families

### Spec A: `tau_theta_rescue_v1`

Purpose:

- primary spec for the latent-`v` cluster
- should become the default candidate for most remaining hard fails

Contract:

```yaml
vb:
  rhs:
    freeze_tau_iters: 50
    freeze_tau_warmup_iters: 50
    force_tau_after_warmup: true
  sigmagam:
    freeze_warmup_iters: 20
    force_after_warmup: true
    postwarmup_damping: 0.35
    postwarmup_damping_iters: 10
    min_postwarmup_updates: 3
mcmc:
  rhs:
    freeze_tau_burnin_iters: 500
    freeze_tau_only_during_burn: true
  theta:
    enabled: true
    freeze_burnin_iters: 50
    freeze_only_during_burn: true
    sparse_update_every: 10
    sparse_update_until_iter: 500
    force_first_postwarmup_update: true
  latent_v:
    enabled: false
    rescue_on_invalid: true
    rescue_strategy: previous_state
    rescue_max_consecutive: 1
    rescue_burn_only: false
    rescue_force_retry_next_iter: true
  latent_s:
    enabled: false
  conditioning:
    mode: none
  slice:
    core_update_mode: sigma_then_gamma
gig:
  b_vec_floor: 1e-10
```

Read:

- warmup is used to stabilize tau and theta
- the actual failure event is handled by bounded latent-`v` rescue
- no extra EXAL conditioning is mixed in

### Spec B: `tau_theta_precision_exal_v1`

Purpose:

- primary spec for the EXAL ridge precision cluster

Base:

- start from `tau_theta_rescue_v1`

Additional EXAL ridge stabilizers:

```yaml
mcmc:
  conditioning:
    mode: qr_whiten
    gram_ridge: 1e-6
    scale_metric: sd
    scale_floor: 1e-8
  slice:
    core_update_mode: sigma_then_gamma
```

Read:

- keep the successful tau + theta + rescue baseline
- add explicit beta-draw conditioning for the EXAL ridge pocket
- keep the first precision spec conservative

### Spec C: `tau_theta_precision_exal_v2`

Purpose:

- fallback precision spec only if `v1` still fails on the EXAL ridge canary

Base:

- start from `tau_theta_precision_exal_v1`

Additional changes:

```yaml
mcmc:
  conditioning:
    gram_ridge: 1e-4
  slice:
    core_update_mode: gamma_sigma_gamma
```

Read:

- stronger numerical regularization
- more invasive EXAL core update order
- reserved for the hard precision pocket only

## 4) Cluster Assignment

The run-specific cluster map divides the remaining `15` roots into:

### Cluster A: `latent_v_postthaw`

Primary spec:

- `tau_theta_rescue_v1`

Fallback:

- `tau_theta_precision_exal_v1` for EXAL ridge roots only
- otherwise, rerun under the same spec with additional targeted inspection

Members:

- all AL remaining hard fails
- all EXAL remaining hard fails **except** the EXAL ridge subset

### Cluster B: `exal_ridge_precision`

Primary spec:

- `tau_theta_precision_exal_v1`

Fallback:

- `tau_theta_precision_exal_v2`

Members:

- `EXAL / gausmix / tau 0.25 / 5000 / ridge`
- `EXAL / laplace / tau 0.50 / 5000 / ridge`
- `EXAL / normal / tau 0.05 / 5000 / ridge`

## 5) Recommended Launch Order

### Phase 0: freeze map and documentation

Checklist:

- [x] freeze the mechanism split in a committed cluster map
- [x] document the completion-wave precision failure separately from the
      earlier latent-`v` surface
- [x] define named spec families rather than vague “more warmup”

### Phase 1: latent-`v` cluster canary

Launch `tau_theta_rescue_v1` on a small mixed latent-`v` subset:

1. `AL / gausmix / tau 0.25 / 5000 / rhs_ns`
2. `AL / laplace / tau 0.50 / 5000 / rhs_ns`
3. `EXAL / gausmix / tau 0.25 / 5000 / rhs_ns`
4. `EXAL / normal / tau 0.50 / 5000 / rhs_ns`

Why:

- covers both lanes
- covers both `gausmix` and `laplace`-style hard surfaces
- covers the `rhs_ns` pocket where latent-`v` instability remains strongest

Gate:

- if `3 / 4` or better avoid terminal hard crash, promote to the rest of
  Cluster A

### Phase 2: EXAL ridge precision canary

Launch `tau_theta_precision_exal_v1` on:

1. `EXAL / laplace / tau 0.50 / 5000 / ridge`
2. `EXAL / gausmix / tau 0.25 / 5000 / ridge`

Gate:

- if both complete or become at least non-crash interpretable, promote `v1` to
  the third ridge root
- if either still hits the Cholesky failure family, immediately test
  `tau_theta_precision_exal_v2` only on the failing root

### Phase 3: cluster promotion

If both cluster canaries pass their gates:

1. promote `tau_theta_rescue_v1` to the rest of Cluster A
2. promote `tau_theta_precision_exal_v1` to the full EXAL ridge cluster
3. use `v2` only as a surgical fallback, not as the new default

## 6) Resource Plan

Use **4 cores** for the first real wave:

- latent-`v` canary:
  - `4` independent single-worker lanes
- EXAL ridge precision canary:
  - run after or alongside with at most `2` additional single-worker lanes if
    the machine is otherwise idle

Preferred default:

- start with the `4`-lane latent-`v` canary
- then run the `2`-lane ridge canary

This keeps the wave efficient without recreating the earlier storage and
wrapper risks of broad parallel launches.

## 7) Why This Is Better Than Another Global Warmup Wave

This program is better because it:

- respects the actual mechanism split now visible in the logs
- keeps the winning `theta + tau` signal where it helped
- adds rescue where the remaining latent-`v` event still matters
- adds conditioning only where the precision draw actually failed
- avoids spending compute on one-size-fits-all retries that mix incompatible
  failure surfaces

## 8) Immediate Next Step

Implement this as a run-specific launch surface:

1. add a dedicated cluster-map materializer or checked-in assignment map
2. add dedicated defaults files for:
   - `tau_theta_rescue_v1`
   - `tau_theta_precision_exal_v1`
   - `tau_theta_precision_exal_v2`
3. add wrapper phases for the two canary waves
4. run `prepare-only`
5. launch the canaries

That is the highest-signal and lowest-waste path forward from the current
evidence.
