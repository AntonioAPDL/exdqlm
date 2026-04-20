# QDESN Tau050 Remaining Precision Code Matrix Launch

Date: `2026-04-20`

## Summary

The pair-only code-level precision rescue matrix has now been launched against the exact final unresolved tau050 pair.

The intended matrix is:

- `remaining_precision_code_al_ladder_v1`
- `remaining_precision_code_al_ladder_v2`
- `remaining_precision_code_al_eigen_v1`
- `remaining_precision_code_exal_ladder_v1`
- `remaining_precision_code_exal_ladder_v2`
- `remaining_precision_code_exal_eigen_v1`

Each phase uses:

- exact root scope: `1` root
- method: `mcmc`
- workers: `1`

## Launch sequence

### First launch wave

The first broad parallel launch was started from implementation commit:

- `2978709` = `Implement precision-beta rescue code matrix`

Two EXAL lanes launched cleanly:

- `remaining_precision_code_exal_ladder_v1`
- `remaining_precision_code_exal_eigen_v1`

Four lanes failed to launch, but not for scientific reasons. The failure was operational:

- the detached dynamic launcher was still generating tmux session names with second-level resolution only
- multiple parallel launches in the same second collided on session naming

### Launcher hardening

I fixed the detached launcher in:

- [scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R)

The new session-name policy:

- uses millisecond-resolution timestamps
- includes a PID-derived suffix
- checks for pre-existing session collisions before launch

That fix was committed and pushed as:

- `b0d5800` = `Harden dynamic tmux session naming`

### Second launch wave

After the launcher hardening, the remaining four phases were relaunched successfully from `b0d5800`.

## Live lanes

| Phase | Run tag | SHA | tmux session |
|---|---|---|---|
| `remaining_precision_code_al_ladder_v1` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_code_al_ladder_v1-20260420-183527__git-b0d5800` | `b0d5800` | `qdesn_dynx_0420183527454_98638` |
| `remaining_precision_code_al_ladder_v2` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_code_al_ladder_v2-20260420-183527__git-b0d5800` | `b0d5800` | `qdesn_dynx_0420183527545_98650` |
| `remaining_precision_code_al_eigen_v1` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_code_al_eigen_v1-20260420-183527__git-b0d5800` | `b0d5800` | `qdesn_dynx_0420183527575_98648` |
| `remaining_precision_code_exal_ladder_v1` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_code_exal_ladder_v1-20260420-183412__git-2978709` | `2978709` | `qdesn_dynx_0420_183413` |
| `remaining_precision_code_exal_ladder_v2` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_code_exal_ladder_v2-20260420-183527__git-b0d5800` | `b0d5800` | `qdesn_dynx_0420183527596_98664` |
| `remaining_precision_code_exal_eigen_v1` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_code_exal_eigen_v1-20260420-183412__git-2978709` | `2978709` | `qdesn_dynx_0420_183412` |

Note:

- the EXAL `ladder_v1` and `eigen_v1` lanes remain on `2978709`
- the only code change between `2978709` and `b0d5800` was the launcher session-name hardening
- the scientific sampler/config content for those two EXAL lanes is unchanged

## Initial health snapshot

Snapshot time: `2026-04-20 18:36:59 EDT`

| Phase | Selected | Materialized | Running | Success | Fail | Read |
|---|---:|---:|---:|---:|---:|---|
| `remaining_precision_code_al_ladder_v1` | 1 | 1 | 1 | 0 | 0 | alive |
| `remaining_precision_code_al_ladder_v2` | 1 | 1 | 1 | 0 | 0 | alive |
| `remaining_precision_code_al_eigen_v1` | 1 | 1 | 1 | 0 | 0 | alive |
| `remaining_precision_code_exal_ladder_v1` | 1 | 1 | 1 | 0 | 0 | alive |
| `remaining_precision_code_exal_ladder_v2` | 1 | 1 | 1 | 0 | 0 | alive |
| `remaining_precision_code_exal_eigen_v1` | 1 | 1 | 1 | 0 | 0 | alive |
| Overall | 6 | 6 | 6 | 0 | 0 | clean startup |

## Current interpretation

The code-level matrix is now operationally clean:

- all six lanes are live
- all six have materialized their exact single root
- all six are running
- no early failures have appeared yet

That means the next useful question is now scientific rather than operational:

- whether any precision rescue policy actually stabilizes the final unresolved AL/EXAL ridge pair
