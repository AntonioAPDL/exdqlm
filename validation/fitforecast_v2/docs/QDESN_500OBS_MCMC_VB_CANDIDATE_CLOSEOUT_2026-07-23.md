# Q-DESN 500-Observation MCMC VB-Candidate Closeout

Date: 2026-07-23

This note closes the Q-DESN RHS MCMC confirmation campaign seeded from VB candidate screens. It is scoped only to the independent Q-DESN/DQLM validation workstream.

## Scope

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Closeout commit at materialization time: `935b7e15879483387c51408ae612391686aac010`
- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation`
- Original full run tag: `qdesn-tt500-mcmc-vbcandidate-full-20260716-025532__git-abe3439`
- Remainder manager tag: `qdesn-tt500-mcmc-vbcandidate-remainder-20260718-202000__git-935b7e1`
- Promotion id: `qdesn_tt500_mcmc_vb_candidate_closeout_20260723`

## Closeout Decision

The campaign is computationally complete.

- Planned scientific roots: `72`
- Preferred successful roots after retry reconciliation: `72 / 72`
- Raw non-smoke attempts: `73`
- Superseded attempts: `1`
- Superseded stale RUNNING attempts: `1`
- Remaining roots to run: `0`

The stale original RUNNING marker is retained as evidence and superseded by the successful retry for the same root. It must not be treated as active work.

## Diagnostic Status

Strict MCMC signoff is mixed.

| status | count |
|---|---:|
| PASS | 9 |
| WARN | 30 |
| FAIL | 33 |
| comparison eligible | 39 |
| comparison ineligible | 33 |

Rows with `comparison_eligible == TRUE` form the clean MCMC comparison pool. Rows with `signoff_grade == FAIL` are computationally complete, finite, and domain-valid where recorded, but should not be promoted as clean winners without an explicit diagnostic caveat.

## Promotion Rule

For article-facing or benchmark-facing promotion:

1. Prefer a successful retry over a stale or non-successful original attempt for the same root.
2. Keep all attempts in the attempt inventory.
3. Use `qdesn_tt500_mcmc_vb_candidate_authoritative_fit_summary_20260723.csv` as the reconciled 72-root evidence table.
4. Use `comparison_eligible == TRUE` for clean MCMC comparisons.
5. Use `qdesn_tt500_mcmc_vb_candidate_strict_signoff_failures_20260723.csv` to audit completed-but-diagnostic-failed rows.
6. Do not relaunch blindly from this closeout. Any relaunch should target specific diagnostic failures or scientific gaps.

## Evidence Paths

Promotion directory:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_vb_candidate_closeout_20260723`

Key files:

- `qdesn_tt500_mcmc_vb_candidate_authoritative_fit_summary_20260723.csv`
- `qdesn_tt500_mcmc_vb_candidate_cell_model_summary_20260723.csv`
- `qdesn_tt500_mcmc_vb_candidate_strict_signoff_failures_20260723.csv`
- `qdesn_tt500_mcmc_vb_candidate_superseded_attempts_20260723.csv`
- `qdesn_tt500_mcmc_vb_candidate_attempt_inventory_20260723.csv`
- `qdesn_tt500_mcmc_vb_candidate_storage_audit_20260723.csv`
- `qdesn_tt500_mcmc_vb_candidate_closeout_manifest_20260723.json`
- `file_manifest.csv`
- `README.md`

Rerun command:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript validation/fitforecast_v2/scripts/materialize_qdesn_tt500_mcmc_vb_candidate_closeout.R
```

## Cell-Level Diagnostic Pattern

The clean eligible pool is uneven by likelihood and cell. AL has comparison-eligible candidates in every family/tau cell represented here. exAL has clean eligible candidates for some cells, but several exAL cells have no comparison-eligible MCMC candidate under this campaign:

- gausmix, tau 0.05, exAL: `0 / 7` eligible
- gausmix, tau 0.25, exAL: `0 / 5` eligible
- normal, tau 0.25, exAL: `0 / 5` eligible

The normal, tau 0.05, exAL retry completed successfully but remains strict-signoff failed due high autocorrelation. Its fit and forecast metrics are therefore evidence for computational completion, not clean MCMC dominance.

## Storage-Light Status

The closeout storage audit found no retained `.rds`, `.rda`, `.RData`, `.qs`, `.fst`, or files larger than 20 MB under the campaign results root.

## Next Move

Do not wait for this campaign; it is complete.

The next rigorous step is to decide how to use the closeout:

- For a conservative benchmark table, promote only the 39 comparison-eligible rows and keep diagnostic failures out of winner claims.
- For a complete diagnostic appendix, include all 72 completed roots with explicit signoff labels.
- For further calibration, target only the failed exAL/RHS cells and the specific high-autocorrelation failures. Do not relaunch the whole 72-root campaign.
