# QDESN Tau050 Remaining Precision Closeout Launch

Date: `2026-04-20`

## Summary

The canonical closeout wave has been launched on the exact final precision pair using the promoted `ladder_v2` rescue policy.

Live phases:

- `remaining_precision_closeout_al_ladder_v2`
- `remaining_precision_closeout_exal_ladder_v2`

Prepared-only fallback phases:

- `remaining_precision_closeout_al_eigen_v1`
- `remaining_precision_closeout_exal_eigen_v1`

The closeout launch runs from clean implementation commit:

- `2c7e975` = `Implement precision closeout ladder_v2 promotion`

## Live lanes

| Phase | Run tag | tmux session | Status |
|---|---|---|---|
| `remaining_precision_closeout_al_ladder_v2` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_closeout_al_ladder_v2-20260421-000540__git-2c7e975` | `qdesn_dynx_0421000540922_31797` | running |
| `remaining_precision_closeout_exal_ladder_v2` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_closeout_exal_ladder_v2-20260421-000540__git-2c7e975` | `qdesn_dynx_0421000541041_31805` | running |

## Fallback preparation

All fallback phases prepared successfully during implementation validation:

| Phase | Mode | Prepared |
|---|---|---|
| `remaining_precision_closeout_al_eigen_v1` | `prepare-only` | yes |
| `remaining_precision_closeout_exal_eigen_v1` | `prepare-only` | yes |

That means the escalation path is already frozen and reproducible, but it is not consuming live compute unless the promoted `ladder_v2` closeout rerun fails.

## Initial health snapshot

Snapshot time: `2026-04-21 00:06 EDT`

| Phase | Selected | Materialized | Running | Success | Fail | Read |
|---|---:|---:|---:|---:|---:|---|
| `remaining_precision_closeout_al_ladder_v2` | 1 | 1 | 1 | 0 | 0 | clean startup |
| `remaining_precision_closeout_exal_ladder_v2` | 1 | 1 | 1 | 0 | 0 | clean startup |
| Overall | 2 | 2 | 2 | 0 | 0 | both lanes live |

Operational read:

- both final roots materialized successfully
- both launcher sessions are alive
- no early failures have appeared
- no fallback compute has been launched

## Why This Is The Right Closeout Form

This launch intentionally avoids reopening the search:

- `ladder_v1` is retired
- `ladder_v2` is the promoted default
- `eigen_v1` is the explicit fallback
- the live rerun surface is only the final pair

That gives us the cleanest final story:

1. exploratory matrix established the viable code-level rescues
2. `ladder_v2` was promoted as the default
3. a minimal canonical rerun now tests that promoted policy directly

## Forward decision rule

| Outcome | Next move |
|---|---|
| both closeout lanes succeed | freeze `ladder_v2` as the default precision rescue and write the final recovery closeout |
| one closeout lane fails | rerun only the failed lane with prepared `eigen_v1` |
| both closeout lanes fail | escalate both to `eigen_v1` and reassess whether deeper precision-kernel work is still needed |
