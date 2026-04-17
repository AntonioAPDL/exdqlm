# Refreshed288 Launch Readiness

Date: `2026-04-16`

## Status

The refreshed `288`-case relaunch stack is ready for a controlled smoke launch.

This note records what was checked before launch and what the next safe launch
sequence should be.

## What Was Verified

### Study definition and inputs

- full manifest built successfully
- smoke manifest built successfully
- dataset registry built successfully
- method registry built successfully
- no missing inputs in the dataset registry
- no `0.95` rows in the refreshed study
- no `qdesn` paths in the refreshed study
- explicit `LDVB` warm-start wiring is present for all `mcmc` method profiles

### Expected study counts

| artifact | result |
|---|---:|
| dataset roots | `54` |
| method profiles | `16` |
| full rows | `288` |
| smoke rows | `24` |

| phase | rows |
|---|---:|
| `full_static_vb` | `108` |
| `full_dynamic_vb` | `36` |
| `full_static_mcmc` | `108` |
| `full_dynamic_mcmc` | `36` |

| smoke phase | rows |
|---|---:|
| `smoke_static_vb` | `8` |
| `smoke_dynamic_vb` | `4` |
| `smoke_static_mcmc` | `8` |
| `smoke_dynamic_mcmc` | `4` |

### Non-launch workflow checks

The following completed successfully:

- `LOCAL_refreshed288_prepare_20260416.R`
- `LOCAL_refreshed288_evaluate_20260416.R` on `full`
- `LOCAL_refreshed288_evaluate_20260416.R` on `smoke`
- `LOCAL_refreshed288_refresh_comparison_20260416.R` on `full`
- `LOCAL_refreshed288_refresh_comparison_20260416.R` on `smoke`
- `LOCAL_refreshed288_launch_20260416.sh dry-run --manifest-kind=smoke`

Interpretation:

- prepare works
- manifest/status/report generation works
- staged smoke orchestration works without launching study rows

## Package Test Read

The relaunch-critical package-local test slice was rerun through
`testthat::test_local()` after fixing the reduced dynamic `LDVB` class return.

Result:

- critical targeted test slice: `PASS`
- expected sandbox skip count: `1`

Targeted filters exercised:

- `dlm-df-smoother-regression`
- `dqlm-reduced-paths`
- `dqlm-vb-sim-smoke`
- `dynamic-dqlm-mcmc-regression`
- `ffbs-indexing-parity`
- `mcmc-backend-routing`
- `mcmc-dynamic-strict-parity`
- `static-diagnostics`
- `static-p025-stability`
- `static-vb-mcmc-pipeline-report-smoke`
- `transfer-mcmc-wrapper`
- `vb-mcmc-convergence-controls`

The only skip was:

- `static-vb-mcmc-pipeline-report-smoke`
  reason:
  pipeline script path unavailable in the test sandbox

That skip is environmental rather than a fit-path or package regression.

## Package Fix Required For Readiness

One package inconsistency had to be corrected during readiness checking:

- reduced `dqlm.ind = TRUE` branch in `exdqlmLDVB()` was returning class
  `"exdqlm"` instead of `"exdqlmLDVB"`

This is now fixed in:

- [R/exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R)

That fix restored:

- reduced-path `LDVB` class expectations
- forecast dispatch for reduced dynamic `LDVB`

## Reproducibility

A one-command verification helper is available locally:

- `tools/merge_reports/LOCAL_refreshed288_verify_20260416.sh`

It reruns:

- prepare
- full and smoke evaluate
- full and smoke report refresh
- smoke and full dry-run launch wiring
- the targeted package-local readiness test slice

## Important Git Note

The `tools/` tree is ignored by the current repository `.gitignore`.

That means:

- the new `LOCAL_refreshed288_*` scripts and generated CSV manifests exist and
  are usable locally
- but they will not appear in ordinary `git status`
- if we want to commit them, we need `git add -f` or an ignore-rule adjustment

The report files under `reports/static_exal_tuning_20260416/` are not ignored.

## Recommended Next Launch Sequence

1. Launch the `smoke` manifest only.
2. Evaluate smoke results immediately after completion.
3. If smoke is stable, launch the full study in the staged order already wired:
   - static `vb`
   - dynamic `vb`
   - static `mcmc`
   - dynamic `mcmc`
4. Refresh comparison/report outputs after each phase boundary, not only at the end.

## Launch Commands

Smoke:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh launch --manifest-kind=smoke
```

Full:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh launch --manifest-kind=full
```

Dry-run:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh dry-run --manifest-kind=smoke --no-prepare
tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh dry-run --manifest-kind=full --no-prepare
```
