## Summary

This report records the live launch of the remaining precision-stabilization matrix for the final unresolved tau050 precision pair.

The matrix was launched from clean git SHA:

- `3af6bac` — `Add remaining precision matrix relaunch suite`

All seven lanes were launched successfully. Each lane targets the exact same remaining unresolved root under either the `al` or `exal` likelihood family, with one worker per lane so the matrix runs broadly in parallel while keeping per-lane resource use bounded.

## Live phases

| Phase | Lane | Run tag | tmux |
|---|---|---|---|
| `remaining_precision_matrix_al_qr_v1` | `al` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_al_qr_v1-20260420-172323__git-3af6bac` | `qdesn_dynx_0420_172323` |
| `remaining_precision_matrix_al_qr_v2` | `al` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_al_qr_v2-20260420-172329__git-3af6bac` | `qdesn_dynx_0420_172329` |
| `remaining_precision_matrix_al_diag_v1` | `al` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_al_diag_v1-20260420-172334__git-3af6bac` | `qdesn_dynx_0420_172334` |
| `remaining_precision_matrix_exal_qr_v1` | `exal` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_exal_qr_v1-20260420-172336__git-3af6bac` | `qdesn_dynx_0420_172337` |
| `remaining_precision_matrix_exal_qr_v2` | `exal` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_exal_qr_v2-20260420-172341__git-3af6bac` | `qdesn_dynx_0420_172342` |
| `remaining_precision_matrix_exal_qr_sig_v1` | `exal` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_exal_qr_sig_v1-20260420-172343__git-3af6bac` | `qdesn_dynx_0420_172344` |
| `remaining_precision_matrix_exal_diag_v1` | `exal` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_precision_matrix_exal_diag_v1-20260420-172348__git-3af6bac` | `qdesn_dynx_0420_172349` |

## Initial live snapshot

Snapshot time: `2026-04-20 17:24 EDT` approximately.

| Phase | Selected roots | Materialized | Running | Success | Fail | Started % |
|---|---:|---:|---:|---:|---:|---:|
| `remaining_precision_matrix_al_qr_v1` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_matrix_al_qr_v2` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_matrix_al_diag_v1` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_matrix_exal_qr_v1` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_matrix_exal_qr_v2` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_matrix_exal_qr_sig_v1` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| `remaining_precision_matrix_exal_diag_v1` | 1 | 1 | 1 | 0 | 0 | 100.0% |
| **Overall** | **7** | **7** | **7** | **0** | **0** | **100.0%** |

## Operational notes

- Launches were staggered by a few seconds to avoid tmux timestamp/session collisions while still yielding full parallel compute once detached.
- Each lane was launched with `1` worker, so the matrix uses `7` workers total.
- Root-status manifests confirm that all seven lanes had materialized and entered `RUNNING` state at the first health snapshot.

## Read

This matrix is intentionally broad in mechanism space but narrow in root space. It is the cleanest way to screen the remaining promising precision-stability variants against the exact final unresolved root pair without mixing that decision into a broader cohort rerun.
