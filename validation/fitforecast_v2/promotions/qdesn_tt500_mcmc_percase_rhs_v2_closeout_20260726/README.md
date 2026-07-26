# Q-DESN 500-Observation MCMC Per-Case RHS v2 Closeout

- Promotion ID: `qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726`
- Source run tag: `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c`
- Validation commit at materialization: `7df241c92e3c2d1a45e7e1241645c448423b51ab`
- Scope: independent Q-DESN/exQ-DESN RHS validation only.
- Status: complete evidence package; article gate remains closed.

## Completion

- Planned/completed roots: `90/90`.
- Signoff mix: PASS `17`, WARN `44`, FAIL `29`.
- Comparison-eligible candidates: `61`.
- Eligible all-primary candidate rows: `12` across `5` cells.
- Current-ledger replacements proposed: `9`.
- Unexpected heavy/binary artifacts: `0`.

## Decision Rules

All rankings use the dedicated `forecast_horizon_summary.csv` H=1000 rows.
Legacy campaign-level forecast fields are intentionally ignored because they
are not populated by the rolling-origin protocol. A candidate is comparison
eligible only when execution succeeded, finite/domain checks passed, and the
MCMC signoff is PASS or WARN.

A current Q-DESN cell is replaced only when the eligible candidate improves
the frozen minimax benchmark ratio by at least 0.5%, or replaces a failed
current row while remaining within 1% of its minimax value.

## Remaining Gate

The Normal, tau=0.05, exQ-DESN candidate `mcvbc_060_exal` beats DQLM on all
three primary metrics but has gamma autocorrelation 0.983 and is therefore
diagnostic-only. It receives one four-seed confirmation stage. Article-facing
tables remain unchanged until that confirmation is closed out.

## Files

- Artifact manifest: `file_manifest.csv`
- Source manifest: `source_manifest.csv`
- Closeout manifest: `qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726_manifest.json`
