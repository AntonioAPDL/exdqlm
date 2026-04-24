# REPORT: QDESN Dynamic P90 Steepertrend RHS-NS Resume Throughput Optimization

Date: 2026-04-23
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report records the deliberate stop-and-relaunch optimization applied to
the `rhs_ns` continuation wave after the disk-full recovery restart proved too
conservative in its root-level parallelism.

The goal is to keep the same unresolved-root science and the same baseline
defaults, while using the machine much more effectively.

## 2) Stopped Continuation Wave

Stopped run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50`

Why it was stopped:

- the wave was operationally healthy
- there were no current numerical failures
- but it was using only `3` campaign workers
- those `3` workers were monopolized by the three replayed
  `tau = 0.05`, `fit_size = 5000` roots

Operational state at stop time:

| Metric | Value |
|---|---:|
| continuation roots | `15` |
| running roots | `3` |
| successful continuation roots | `0` |
| failed continuation roots | `0` |

## 3) Host-Capacity Rationale

Measured host capacity at decision time:

| Resource | Observed |
|---|---:|
| logical CPUs | `64` |
| available memory | about `420 GiB` |
| free disk | about `248 GiB` |

Other active load was present, but the host still had substantial headroom.

Conclusion:

- continuing at only `3` root workers would underuse the available machine
  capacity

## 4) Optimization Implemented

### Code change

The dynamic crossstudy runner was updated so root-level parallel execution can
use a selected scheduler:

- `static`
- `load_balanced`

The campaign manifest now records:

- effective worker count
- root scheduler

### Runtime policy for the optimized continuation

Keep unchanged:

- unresolved-root continuation grid
- baseline inference policy
- baseline warmup/default policy
- seeds and per-root contracts

Change only:

- root-level worker count
- root-level scheduling strategy

Optimized continuation settings:

| Setting | Value |
|---|---:|
| unresolved roots | `15` |
| workers | `15` |
| scheduler | `load_balanced` |
| internal threads per root | unchanged |

## 5) Verification

Focused config test passed:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-dynamic-p90-steepertrend-config.R", reporter = testthat::StopReporter$new())'
```

Optimized continuation preflight passed:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R \
  --phase rhsns_full \
  --grid config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_resume_after_diskfull_grid.csv \
  --allow-grid-subset \
  --workers 15 \
  --scheduler load_balanced \
  --prepare-only \
  --run-tag qdesn-dynamic-p90-steepertrend-rhsns-resume-opt-preflight-20260423-202500__git-0775b5d
```

Preflight artifacts:

- [optimized preflight report root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation/qdesn-dynamic-p90-steepertrend-rhsns-resume-opt-preflight-20260423-202500__git-0775b5d)

## 6) Relaunch Decision

The correct next step is:

1. commit the scheduling optimization
2. relaunch the same unresolved `15`-root continuation surface
3. use `15` workers with `load_balanced` scheduling
4. monitor the first root-materialization burst to confirm the machine is now
   being used more effectively
