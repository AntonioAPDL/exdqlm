# Forecast-Gap Adaptive MCMC v1 Confirmation Recovery

## Scope and decision

This document closes the orchestration incident in the independent,
single-quantile Q-DESN/DQLM validation lane. It does not alter the estimator,
candidate specifications, source data, metric definitions, promotion rule,
article repository, JOINT validation, PriceFM, GloFAS, or any application run.

The correct action is a confirmation-only continuation. Restarting the full
campaign would repeat 354 successful MCMC jobs without adding evidence.

## Frozen parent campaign

```text
Worktree:
  /data/jaguir26/local/src/exdqlm__wt__qdesn_forecast_gap_adaptive_mcmc_v1_1p0p0
Branch:
  validation/qdesn-forecast-gap-adaptive-mcmc-v1-1.0.0
Parent commit:
  e842a6438839a7f70345dc7df1c448f887e5eeed
Run ID:
  qdesn_forecast_gap_adaptive_mcmc_v1_20260818_214229
Run tag:
  qdesn-forecast-gap-adaptive-v1-20260818_214229__git-e842a64
```

## Incident audit

| Stage | Successful | Failed | Recovery action |
|---|---:|---:|---|
| Smoke | 2/2 | 0 | Preserve and reverify |
| Calibration | 8/8 | 0 | Preserve and reverify |
| Discovery | 184/184 | 0 | Preserve and reverify |
| Replication | 64/64 | 0 | Preserve and reverify |
| Sealed holdout | 96/96 | 0 | Preserve and reverify |
| Canonical confirmation | 0/24 | 0 | Launch from frozen packet |

The sealed gate passed 96/96 jobs with finite required metrics, complete compact
artifacts, and zero fitted-model binary payloads. It nominated 11 metric roles
from eight unique cell-candidate pairs, yielding 24 deduplicated canonical
chains. Confirmation materialization and its six-check preflight passed.

The pipeline then evaluated:

```awk
END{print NR > 0 ? NR-1 : 0}
```

The installed `awk` requires the ternary expression to be parenthesized in a
`print` statement. The portable form is:

```awk
END { print (NR > 0 ? NR - 1 : 0) }
```

This was a deterministic orchestration failure after plan construction. It was
not a model failure, MCMC failure, data failure, hash failure, resource failure,
or scientific gate rejection.

## Recovery invariants

The recovery launcher must satisfy every condition below before allocating a
core:

1. The task branch is clean, pushed, and synchronized with its upstream.
2. The recovery HEAD descends from the parent commit.
3. Frozen source contracts, target and metric-role ledgers, candidate profiles,
   parent requests, estimator helper, chain worker, adaptive selector,
   confirmation materializer, and closeout code are byte-identical to the
   parent commit.
4. The run ID and run tag match `run_tags.env`.
5. All 354 completed roots re-pass runtime status, finite-metric, config-hash,
   and zero-binary checks.
6. The confirmation plan, metric map, source registry, canonical window
   registry, and sealed eligibility file match their frozen manifest hashes.
7. The plan contains exactly 24 jobs, grouped as three chains for each unique
   case-specific candidate.
8. No confirmation packet is rematerialized and no earlier scientific stage is
   rerun.

The recovery provenance JSON records the parent scientific commit, recovery
commit, immutable plan hash, preserved-job count, confirmation-job count, and
same-run-tag continuity decision.

Before the background launch, the same recovery entry point is executed with
`QDESN_FGAV1_CONFIRMATION_PREFLIGHT_ONLY=true`. This exercises the 354-root
runtime audit, immutable confirmation hash checks, package load, and focused
test suite without selecting cores or starting a confirmation worker.

## Execution and closeout

The 24 chains use 5,000 burn-in and 20,000 sampling iterations. Up to 20 idle
cores are selected, with one thread per chain, at least 64 GiB available memory,
and at least 80 GiB free disk. The launcher retains the existing 30-minute
heartbeat and stale thresholds. Matching successful roots are idempotently
skipped if continuation is needed again.

After all chains finish, runtime verification requires 24 successful jobs,
finite requested metrics, exact config hashes, and zero fitted-model binary
payloads. Closeout is metric-specific: a family, quantile, likelihood, and
metric role is promoted whenever the arithmetic mean of its three canonical
chains is strictly below its own v7 authority. There is no minimum gain.
Diagnostic mixing status is reported but is not a promotion veto.

The recovery produces the confirmation chain table, strict promotion ledger,
verification JSON, health table, closeout JSON, and an integration-ready
lineage record. Article changes remain manual and belong to the integration
coordinator only after confirmed gains are frozen.

## Failure and rollback behavior

The recovery never resets Git, deletes a completed root, or overwrites the
frozen confirmation packet. If a worker or resource gate fails, the stage ledger
records the attempt and the same recovery command can be relaunched with the
same run tag; matching successful chains are skipped by config hash. Runtime
artifacts remain excluded from Git. No article value is changed until the final
promotion ledger is reviewed and integrated.
