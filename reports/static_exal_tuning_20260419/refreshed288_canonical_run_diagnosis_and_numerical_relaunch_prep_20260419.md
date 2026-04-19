# Refreshed288 Canonical Run Diagnosis And Numerical Relaunch Prep

Date: 2026-04-19
Repo: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
Canonical run root: `tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1`

## Purpose

Freeze the current diagnosis of the latest full canonical `288`-case run, confirm what reproducibility artifacts remain after cleanup, and define the relaunch-preparation surface for the numerical crash cohort.

## Canonical Run Outcome

Derived directly from the canonical run `row_*_status.csv` files.

| Outcome | Count |
|---|---:|
| `PASS` | `188` |
| `WARN` | `53` |
| `FAIL` | `47` |
| usable (`PASS + WARN`) | `241` |

| Terminal status | Count |
|---|---:|
| `done` | `246` |
| `failed_runtime` | `20` |
| `skipped_existing` | `22` |

## Failure Split

| Failure class | Count | Interpretation |
|---|---:|---|
| numerical/runtime crash | `20` | current relaunch target |
| non-runtime gate fail | `27` | mixing/diagnostic failures, not the current target |

The non-runtime gate fails are all static-MCMC diagnostic failures. The current relaunch focus remains only the numerical crash cohort.

## Phase Breakdown

| Phase | `PASS` | `WARN` | `FAIL` |
|---|---:|---:|---:|
| `full_static_vb` | `99` | `9` | `0` |
| `full_dynamic_vb` | `11` | `24` | `1` |
| `full_static_mcmc` | `69` | `12` | `27` |
| `full_dynamic_mcmc` | `9` | `8` | `19` |

## Important Artifact Diagnosis

### What still exists for the canonical run

The following lightweight reproducibility surfaces are still present under the canonical run root:

- `configs/`
- `rows/`
- `health/`
- `metrics/`

### What does not still exist for the canonical run

The following heavy binary outputs are no longer present under the canonical run root:

- `fits/`
- `vb_init/`
- `draws/`

Checked across all `241` usable (`PASS/WARN`) rows:

| Check over canonical `PASS/WARN` rows | Count |
|---|---:|
| usable rows total | `241` |
| candidate fit `.rds` still present | `0` |
| draws `.rds` still present | `0` |
| vb-init `.rds` still present | `0` |

So the latest canonical run is still reproducible at the audit/manifest/metric level, but not at the retained-fit-binary level.

## Preserved Legacy `.rds` Coverage

After the legacy dynamic `.rds` cleanup, the preserved keep-set does not cover all canonical usable rows.

It covers only a small dynamic subset:

| Canonical usable rows | Count |
|---|---:|
| total usable rows | `241` |
| dynamic usable rows | `52` |
| static usable rows | `189` |
| usable rows covered by preserved legacy `.rds` keep-set | `14` |

Important detail:

- the preserved legacy `.rds` coverage matches only `14` dynamic `WARN` rows
- it does not cover the full `241` canonical usable rows

So the answer for this repo is:

- we do **not** still have `.rds` for all `PASS/WARN` rows from the canonical `288` run
- we do still have the canonical audit trail and a small preserved legacy dynamic keep-set

## Frozen Numerical Crash Cohort

The exact relaunch target set for this repo is frozen in:

[LOCAL_refreshed288_numerical_runtime_failure_manifest_20260419.csv](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_numerical_runtime_failure_manifest_20260419.csv)

Frozen target count:

| Cohort | Count |
|---|---:|
| numerical/runtime crashes from canonical run | `20` |

Important note:

- for this repo/worktree, the frozen numerical crash cohort is `20`, not `23`
- if `23` refers to another branch or another study, it should not be mixed into this relaunch without an explicit separate manifest

## Numerical Crash Shape

The `20` numerical crashes are:

- `19` dynamic MCMC failures
- `1` dynamic VB failure

By model:

| Model / inference | Count |
|---|---:|
| dynamic `dqlm` `mcmc` | `9` |
| dynamic `exdqlm` `mcmc` | `10` |
| dynamic `exdqlm` `vb` | `1` |

Main failure signatures:

| Signature | Count |
|---|---:|
| `dqlm_mcmc_pre_uts ... invalid state before chi update` | `9` |
| `exdqlm_mcmc_uts ... chi has 5000 non-finite values` | `9` |
| `ldvb_q_t1 is NA` | `2` |

## Pre-Relaunch `s_t` Freeze Diagnosis

### What already exists

In dynamic MCMC, the exDQLM branch already has latent-state warmup/freeze controls that operate on the latent state path, with `default_mode = "u_st_pair"` in:

- [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R)

This means:

- exDQLM MCMC already supports freezing the `U_t / s_t` latent pair together during burn-in
- DQLM only has `U_t`, because it does not have the `s_t` latent block

### What is missing

The exDQLM LDVB initializer does not yet have an explicit `s_t` warmup/freeze scheduler analogous to the dynamic MCMC latent freeze.

This matters because the recent root-cause work showed:

- `vb_init_validation_fail` is not a false gate
- it is earlier detection of a broken exDQLM LDVB init
- the collapse is state-side, especially the `s_t` block

Relevant package surface:

- [R/exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R)
  - `update_sts()`
  - `update_uts()`
  - `ex.f / ex.q` construction
  - state-path diagnostics already added in the recent instrumentation pass

## Relaunch-Prep Conclusion

Before relaunching the numerical crash cohort, the next method-prep step should be:

1. keep the frozen relaunch target set at exactly the `20` rows in the manifest above
2. keep the current focus strictly on numerical/runtime crashes
3. do **not** mix in the `27` static gate-fail rows
4. design and implement an explicit exDQLM LDVB `s_t` warmup/freeze policy

### Why this is the right next step

- exDQLM MCMC already has a latent `U_t / s_t` warmup surface
- the upstream init failure is still happening earlier, inside the LDVB/init state path
- so the missing piece before relaunch is not another broad MCMC-only retry
- it is a better-instrumented and explicitly frozen `s_t` path in LDVB init

## Execution Checklist Before Relaunch

- [x] freeze canonical run diagnosis
- [x] freeze canonical numerical crash manifest
- [x] confirm canonical `PASS/WARN` `.rds` are not still present in the canonical run root
- [x] confirm current focus remains numerical/runtime crashes only
- [ ] define exDQLM LDVB `s_t` freeze controls
- [ ] decide warmup length and post-warmup force policy for `s_t`
- [ ] add tests for the new `s_t` freeze behavior
- [ ] serialize the resolved controls into the next relaunch contract
- [ ] relaunch only the frozen numerical crash cohort

## Bottom Line

The repo is now documented and reproducible enough to proceed, and the relaunch target set is frozen.

But the next relaunch should wait for one more method-prep step:

- explicit exDQLM LDVB `s_t` freeze / warmup design and implementation

That is the clearest missing piece before the next numerical-crash relaunch.
