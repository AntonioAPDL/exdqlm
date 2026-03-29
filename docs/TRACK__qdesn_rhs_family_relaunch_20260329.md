# TRACK: QDESN RHS-Family Relaunch (2026-03-29)

Date: 2026-03-29  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Freeze the post-fix relaunch scope for all stale Q-DESN RHS-family validation evidence after the final `rhs_ns` and intercept-policy correction on current `HEAD`.

This relaunch is reuse-first:

1. keep the existing validation scripts and grids;
2. rerun only the branch-closeout critical path;
3. regenerate closeout from a fresh dynamic baseline;
4. treat the old closeout micro-pilot assets as templates only.

## 2) Canonical Relaunch Assets

- manifest:
  - `config/validation/qdesn_rhs_family_relaunch_manifest.yaml`
- supervisor:
  - `scripts/run_qdesn_rhs_family_relaunch.R`
- audit:
  - `REFRESH_AUDIT_QDESN_20260329.md`

Safe default:

- the supervisor runs in `prepare_only` mode unless `--execute` is supplied

## 3) Critical Path

1. `T0`: focused `rhs` vs `rhs_ns` smoke
2. `T1`: Stage-P `rhsns_full` refresh
3. `T2`: Stage-Q refresh
4. `T3`: dynamic family/prior refresh
5. `T4A`: closeout phase01 from the fresh dynamic baseline
6. `T4B`: closeout phase35 from the fresh phase01 manifest

## 4) Efficiency Rules

- Reuse the existing stage runners and validation configs.
- Skip the Stage-P ridge anchor by default.
- Keep plots off by default.
- Keep the dynamic rerun coherent as a fresh `36`-root baseline.
- Do not reuse the old March 29 micro-pilot grid as live targeting input.

## 5) Prepared Commands

Prepare the relaunch workspace only:

```bash
Rscript scripts/run_qdesn_rhs_family_relaunch.R
```

Prepare with a pinned tag:

```bash
Rscript scripts/run_qdesn_rhs_family_relaunch.R \
  --run-tag rhsfixrelaunch-20260329__git-$(git rev-parse --short HEAD)
```

Execute the full staged relaunch:

```bash
Rscript scripts/run_qdesn_rhs_family_relaunch.R --execute --no-plots
```

## 6) Stop/Go Gates

### T0

- require all methods `SUCCESS`
- require no finite/domain failures
- require no unhealthy/collapse regressions

### T1

- require `rhsns_full` root failures = `0`

### T2

- require root failures = `0`
- require no incomplete tau-set state

### T3

- require `SUCCESS` roots = expected roots
- run the dynamic-wave healthcheck before promoting the baseline

### T4

- phase01 always runs after a fresh dynamic baseline
- phase35 still runs even if Gate A fails, so the skip/recommendation state is captured canonically

## 7) Historical-Only Items

These remain useful for comparison, but they are not live relaunch inputs:

- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/configs/micro_pilot_grid.csv`
- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/configs/defaults_P1_longer_chain.yaml`
- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/configs/defaults_P2_conservative_slice.yaml`
- `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/configs/defaults_P3_blocked_adapt.yaml`

Optional historical replay:

- Stage-8 `rhs` vs `rhs_ns` benchmark remains outside the main supervisor because no canonical rerun runner was recovered during this refresh pass.

## 8) Execution Update

Fresh execution on current `HEAD` completed:

- `T0`
- `T1`
- `T2`
- `T3`
- `T4A`

`T4B` needed recovery:

- the initial `phase35` replay with `workers = 4` stalled during `P2_conservative_slice`
- serial recovery with `workers = 1` completed `P1_longer_chain` cleanly

Completed `P1` Gate-B arithmetic:

- `base_fail_n = 6`
- `prof_fail_n = 3`
- `fail_reduction = 0.50`
- `runtime_inflation_median = 0.996794`

This means `P1` improved diagnostics but still failed Gate B on runtime.

`P2` and `P3` were then pruned on efficiency grounds because their profile settings are strictly more expensive than `P1`, so they cannot satisfy the `runtime_inflation_median <= 0.50` gate once `P1` is already at `0.996794`.

Current operative recommendation:

- hold defaults
- escalate to kernel redesign

If a script-native fresh `phase35_summary.md` is required for process completeness, rerun `phase35` serially to full completion. This would be confirmatory rather than decision-changing.
