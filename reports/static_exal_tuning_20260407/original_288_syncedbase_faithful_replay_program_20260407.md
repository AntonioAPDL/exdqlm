# Original-288 Synced-Base Faithful Replay Program

Date: 2026-04-07

## Purpose

This program replaces the deprecated broad synced-base rerun from
`2026-04-06`.

The deprecated rerun proved scientifically hard to interpret because its MCMC
replay was not faithful to the accepted historical reference state:

- original `static_shrink::rhs` rows were inconsistently replayed as `rhs`
  instead of the current intended `rhs_ns`
- static MCMC rows were replayed without several accepted tuning controls
- baseline-kept MCMC rows were effectively treated like fresh runs rather than
  accepted-reference replays
- some dynamic MCMC rows inherited source-config proposal defaults instead of
  the accepted historical proposal family

This replacement program is designed to be a reference-grade replay of the
accepted healthy original-`288` study state on the synced `0.4.0` base.

## Reference Target

Accepted carry-forward reference:

- source file:
  `tools/merge_reports/LOCAL_original288_carryforward_selection_v4_20260406.csv`
- accepted healthy rows:
  `282`
- accepted unresolved rows excluded from this replay:
  `6`

Reference healthy target:

- `PASS = 195`
- `WARN = 87`
- `FAIL = 0`
- `healthy = 282`

The unresolved `6` dynamic `exdqlm :: mcmc` tail remains a separate repair
problem and is intentionally excluded from this fidelity campaign.

## Replay Rules

1. Replay only the accepted healthy `282` rows.
2. Treat the predecessor worktree as read-only historical evidence only.
3. Use the accepted reference fit path as the replay source for every row.
4. For MCMC rows, warm-start from the accepted companion VB fit path.
5. For all original `static_shrink::rhs` rows, force the actual replay prior to
   `rhs_ns`.
6. Let accepted-fit MCMC controls override source-config defaults, including:
   proposal family, joint vs non-joint sampling, slice settings, gamma
   substeps, global eta jump settings, and Laplace refresh settings.

## Phases

| phase | rows | purpose |
|---|---:|---|
| `phase1_vb_all` | `144` | rerun all accepted healthy VB rows first |
| `phase2_static_paper_mcmc` | `36` | faithful replay of paper-static MCMC |
| `phase3_static_shrink_ridge_mcmc` | `36` | faithful replay of shrink ridge MCMC |
| `phase4_static_shrink_rhsns_mcmc` | `36` | faithful replay of shrink rhs rows under forced `rhs_ns` |
| `phase5_dynamic_mcmc` | `30` | faithful replay of accepted healthy dynamic MCMC |

Total rows:

- `282`

## Validated Inputs

The prepared manifest confirms:

- all `282` accepted healthy rows are present
- `0` missing reference fit paths
- `0` missing companion VB reference fit paths for MCMC rows
- all `72` original `static_shrink::rhs` rows now replay with
  `prior_override = rhs_ns`

Representative spot checks confirm the intended replay precedence:

- static repaired MCMC rows recover accepted `laplace_rw`, gamma substeps,
  global eta jump, and Laplace refresh controls
- representative dynamic repaired rows recover accepted `slice` proposal,
  `joint_sample`, and slice stepping controls

## Operational Notes

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- branch:
  `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- predecessor evidence worktree:
  `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

This program supersedes:

- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_program_20260406.md`
