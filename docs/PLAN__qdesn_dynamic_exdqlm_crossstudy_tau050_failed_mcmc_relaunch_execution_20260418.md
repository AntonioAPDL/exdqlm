# PLAN: QDESN Dynamic exDQLM Cross-Study Tau050 Failed-MCMC Relaunch Execution

Date: 2026-04-18  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Current State

Authoritative source run:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`

Terminal outcome:

- roots:
  - `36 / 36` terminal
  - `20` success
  - `16` fail
- fits:
  - `144 / 144` terminal
  - `121` success
  - `23` fail

Lane split:

- `vb_al`: `36 / 36` success
- `vb_exal`: `36 / 36` success
- `mcmc_al`: `27` success, `9` fail
- `mcmc_exal`: `22` success, `14` fail

Failure interpretation:

- failures are hard runtime failures, not merely weak signoff
- dominant signature:
  - `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`

What is already done:

- stronger warmup / freeze policy is implemented on this branch
- failed-only subset grids are checked in
- failed-only wrapper phases are wired
- prepare-only passed for both failed-only relaunch lanes

What has **not** happened yet:

- no live failed-only rerun has been launched
- no repaired result surface exists yet

## 2) Relaunch Objective

Relaunch the failed MCMC surface only, using the current strengthened warmup policy, while keeping
the process:

- auditable
- reproducible
- well documented
- well tested
- isolated from the completed source run

This is a repair continuation, not a replay of the full 144-fit campaign.

## 3) Scope To Relaunch

The failed-only relaunch is split into two exact phases:

### Phase A: `failed_mcmc_al`

- methods per root:
  - `mcmc`
- likelihoods per root:
  - `al`
- selected roots:
  - `9`
- fit sizes:
  - `5000`
- checked-in grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv`

### Phase B: `failed_mcmc_exal`

- methods per root:
  - `mcmc`
- likelihoods per root:
  - `exal`
- selected roots:
  - `14`
- fit sizes:
  - `500, 5000`
- checked-in grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv`

This exact split is more efficient than rerunning all MCMC fits on all `16` failed roots.

## 4) Policy Contract For The Relaunch

The rerun should execute under the current warmed-up policy, not the old source-run policy.

Current intended policy from:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`

Forward relaunch contract:

- VB:
  - `min_iter_elbo = 80`
  - `rhs_ns` tau freeze / warmup `50`
  - `sigmagam.freeze_warmup_iters = 10`
  - `sigmagam.force_after_warmup = true`
  - `sigmagam.postwarmup_damping = 0.5`
  - `sigmagam.postwarmup_damping_iters = 3`
- MCMC:
  - `rhs_ns` tau freeze burn-in `500`
  - `sigmagam.freeze_burnin_iters = 50`
  - `sigmagam.freeze_only_during_burn = true`
  - `sigmagam.force_after_warmup = true`

Interpretation:

- the relaunch is scientifically justified because it uses a materially different startup /
  stabilization policy than the completed failing run
- the relaunch is still a test of a hypothesis until executed

## 5) Execution Principles

1. Do not touch the completed source run.
2. Do not relaunch successful VB fits.
3. Do not relaunch successful MCMC fits outside the failed surface.
4. Launch only from committed state.
5. Keep run tags explicit and unique.
6. Preserve all preflight artifacts and healthcheck outputs.
7. Make the relaunch sequential and gated rather than blind.

## 6) Recommended Launch Order

Recommended order:

1. `failed_mcmc_al`
2. `failed_mcmc_exal`

Reasoning:

- `failed_mcmc_al` is the smaller and simpler lane:
  - `9` roots
  - all at `fit_size = 5000`
- it gives a lower-risk first proof that the repaired warmup path is at least not regressing the
  broader MCMC execution surface
- `failed_mcmc_exal` is the main failure pocket and should follow immediately after the first lane
  passes early health checks

This is a sequential execution recommendation, not a hard technical requirement.

## 7) Pre-Launch Checklist

Before any live relaunch:

1. Confirm the working tree is in the intended state.
2. Commit the relaunch surface or otherwise record the exact launch SHA.
3. Regenerate the failed-only grids from the completed source run.
4. Diff the regenerated failed-only grids against the checked-in grids.
5. Re-run the targeted regression tests.
6. Re-run prepare-only for both failed phases.
7. Record the launch commands in the execution log before starting.

Recommended commands:

```bash
git status --short
```

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R
```

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-refreshed-main-config|qdesn-dynamic-tau050-failed-mcmc-relaunch", reporter = "summary")'
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --prepare-only \
  --no-plots
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --prepare-only \
  --no-plots
```

## 8) Live Launch Commands

### Launch A: `failed_mcmc_al`

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --no-plots
```

### Launch B: `failed_mcmc_exal`

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --no-plots
```

If strict provenance is needed, pass explicit run tags:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --no-plots \
  --run-tag <explicit_run_tag>
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --no-plots \
  --run-tag <explicit_run_tag>
```

## 9) Healthcheck Cadence

Healthchecks should be run at three moments:

1. immediately after launch to confirm the session and manifests exist
2. early runtime to confirm fits are actually starting and not immediately repeating the same crash
3. completion to reconcile recovered versus still-failing roots

Commands:

```bash
Rscript scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --run-tag <failed_mcmc_al_run_tag>
```

```bash
Rscript scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --run-tag <failed_mcmc_exal_run_tag>
```

Recommended early checks:

- after prepare-only:
  - preflight manifest exists
  - selected grid matches intended failed surface
- after live launch:
  - detached session exists
  - root directories are materializing
  - failed fit logs are not instantly reproducing the old `latent_v` error

## 10) Success Criteria

### Minimum success

- relaunch starts cleanly
- failed-only fits materialize under the new policy
- the same immediate `latent_v` hard-failure family does not dominate the first wave

### Full success

- all `23` previously failed fits finish in terminal state
- recovered fits produce diagnostics and no longer fail with `missing_chain_diagnostics`
- recovered roots can be reconciled into a repaired post-source-run interpretation

### Partial success

- some failed fits recover while others still fail
- this is still useful if the relaunch changes the failure surface in a traceable way

## 11) Failure Response

If the rerun still fails:

1. do not overwrite or reinterpret the source run
2. snapshot the new failed-only run tags and logs
3. compare old versus new failure signatures
4. decide whether the warmup changed:
   - failure count
   - failure timing
   - failure lane concentration
   - affected roots
5. only then choose the next repair step

This keeps the relaunch informative even if it is not fully curative.

## 12) Documentation Outputs To Keep

Minimum artifacts to preserve:

- launch command used
- git SHA used
- prepare-only preflight markdown and JSON
- selected failed-only grids
- healthcheck outputs
- final repaired health summary
- root-by-root recovered / unresolved inventory

Recommended writeups:

1. execution report:
   - launch tags
   - worker counts
   - healthcheck snapshots
2. outcome report:
   - recovered fits
   - still-failing fits
   - any new failure signatures
3. reconciliation note:
   - how the failed-only rerun should be interpreted relative to the original full run

## 13) Recommended Next Action

The repo is already at the point where the next real action should be:

1. commit the intended relaunch surface
2. rerun the targeted tests
3. rerun prepare-only for both failed phases
4. launch `failed_mcmc_al`
5. healthcheck it early
6. if early health is acceptable, launch `failed_mcmc_exal`

This is the highest-signal, lowest-waste next execution plan from the current state.
