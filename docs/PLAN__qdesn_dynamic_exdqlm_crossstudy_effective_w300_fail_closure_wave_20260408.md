# PLAN: QDESN Dynamic Effective-W300 Scientific Fail Closure Wave

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Launch one broad but disciplined overnight repair wave for the remaining scientific FAIL surface on
the repaired effective-w300 posterior-draw study.

This wave is intentionally:

- targeted, not broad-rerun,
- local, not one-profile-fits-all,
- reproducible from committed manifests and wrappers,
- conservative about preserving the repaired broad source as the default baseline.

## 2) Source State

Source baseline for this wave:

- broad repaired effective-w300 rerun:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`
- repaired root overlays:
  - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`

Source collection rule:

- use `source.mode = dynamic_campaign`
- read the broad effective-w300 campaign as source
- apply the `6` repaired root-level overlays last

Expected source fail surface:

- `35` FAIL rows
- `20` fail-carrying roots

## 3) Stage Design

| Stage | Roots | Target FAIL Rows | Why this stage exists |
|---|---:|---:|---|
| `W1_ridge_lower_tail_short` | `3` | `6` | isolate lower-tail ridge VB fails on short horizon |
| `W2_ridge_lower_tail_long` | `3` | `6` | same ridge VB problem on long horizon |
| `W3_ridge_upper_tail_short` | `3` | `7` | ridge VB upper-tail fails plus one ridge mcmc_exal drift row |
| `W4_ridge_upper_tail_long` | `3` | `7` | highest-value ridge upper-tail long pocket |
| `W5_rhs_short_exal_drift` | `3` | `3` | short-horizon rhs_ns mcmc_exal drift only |
| `W6_rhs_long_exal_residual` | `5` | `6` | long-horizon rhs_ns mixed vb_exal + mcmc_exal residual band |

Total targeted roots:

- `20`

Total targeted FAIL rows:

- `35`

Validated prepare-only stage plan:

- `6` stages
- `24` stage-profile evaluations
- `80` planned root-campaigns

## 4) Candidate Schedule

### Ridge VB ladder

Used where the fail reason is dominated by:

- `vb_converged_false`
- `elbo_tail_unstable`
- `core_parameter_tail_unstable`

Profiles:

- `N710_ridge_vb_guard160`
- `N720_ridge_vb_guard192`
- `N730_ridge_vb_guard224`
- `N740_ridge_vb_guard256`

Reason for inclusion:

- they form a monotone ladder in VB stabilization strength;
- they do not disturb healthy rhs or `al`/`mcmc_al` branches;
- they are the highest-value first response for the dominant fail bucket.

### Ridge upper-tail combo branch

Used only on upper-tail ridge stages where the fail surface includes small `mcmc_exal` drift debt.

Profiles:

- `N750_ridge_tail_combo2200`
- `N760_ridge_tail_combo2400`

Reason for inclusion:

- they preserve the ridge VB guard strategy,
- but add only a small ridge-only MCMC softening/deepening branch where the source evidence
  actually warrants it.

### RHS short-horizon exAL drift branch

Profiles:

- `N810_rhs_short_drift2200`
- `N820_rhs_short_freeze145_2400`
- `N830_rhs_short_narrow2400`
- `N840_rhs_short_burnheavy2600`

Reason for inclusion:

- all short-horizon rhs FAIL rows are `mcmc_exal` drift rows,
- so this stage keeps VB at baseline and tests only rhs MCMC burn / depth / geometry choices.

### RHS long-horizon mixed exAL branch

Profiles:

- `N910_rhs_long_guard160_drift2200`
- `N920_rhs_long_guard192_narrow2400`
- `N930_rhs_long_guard224_burnheavy2600`
- `N940_rhs_long_guard224_diag2600`

Reason for inclusion:

- this is the only pocket where rhs VB and rhs MCMC exAL failures coexist on overlapping roots;
- profiles therefore adjust rhs VB and rhs MCMC together, while keeping ridge unchanged.

## 5) Selection Rule

Primary stage ranking metric:

- `target_fit_fail_n`

Tie-break order:

1. fewer target fail roots
2. fewer root-status FAILs
3. fewer noneligible roots
4. more comparison-ready roots
5. fewer total FAIL rows
6. more PASS rows
7. lower median runtime

Promotion rule:

- keep `SOURCE_BASELINE` unless a challenger is clearly better under the existing wave-ranking
  logic;
- promote only stage-local winners after the wave completes.

## 6) Execution Plan

Implementation assets:

- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave_manifest.yaml`
- runner wrapper:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave.R`
- launcher wrapper:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave.R`
- healthcheck wrapper:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave.R`

Defaults and grid inherited from:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.csv`

Worker policy:

- default workers:
  - `6`
- active-job workers:
  - `4`
- hard cap:
  - `6`

## 7) Success Criteria

Primary:

- reduce the `35` remaining scientific FAIL rows materially,
- reduce fail-carrying roots below `20`,
- improve comparison-eligible-any and comparison-eligible-full root counts.

Secondary:

- avoid creating any new root execution failures,
- keep repairs local and explainable,
- preserve a clean baseline-versus-stage-winner provenance trail.

## 8) Post-Wave Follow-Through

After the wave completes:

1. inspect stage results and local winner evidence,
2. promote only clear local improvements,
3. update trackers and reports,
4. regenerate the effective-w300 comparison-analysis pack from the merged repaired source,
5. use that regenerated pack as the new authoritative branch-local comparison source.
