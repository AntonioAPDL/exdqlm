# QDESN Tau050 Remaining-Failed MCMC V3 Matrix Launch Report

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Implementation commit: `b4d99a1`

## Summary

The broad `v3` canary matrix was launched from committed revision `b4d99a1` after:

- targeted matrix tests passed
- all six canary prepare-only phases produced clean preflight artifacts
- the branch was pushed before launch so every run tag points to an exact published SHA

## Live Canary Arms

### Rescue baseline

- `remaining_failed_mcmc_al_v3_rescue_canary`
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_al_v3_rescue_canary-20260418-233728__git-b4d99a1`
  - tmux: `qdesn_dynx_0418_233728`
- `remaining_failed_mcmc_exal_v3_rescue_canary`
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v3_rescue_canary-20260418-233733__git-b4d99a1`
  - tmux: `qdesn_dynx_0418_233734`

### Rescue extended

- `remaining_failed_mcmc_al_v3_rescue_extended_canary`
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_al_v3_rescue_extended_canary-20260418-233740__git-b4d99a1`
  - tmux: `qdesn_dynx_0418_233740`
- `remaining_failed_mcmc_exal_v3_rescue_extended_canary`
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v3_rescue_extended_canary-20260418-233746__git-b4d99a1`
  - tmux: `qdesn_dynx_0418_233746`

### exAL-specific kernel arms

- `remaining_failed_mcmc_exal_v3_qr_tightslice_canary`
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v3_qr_tightslice_canary-20260418-233754__git-b4d99a1`
  - tmux: `qdesn_dynx_0418_233755`
- `remaining_failed_mcmc_exal_v3_altcore_canary`
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_failed_mcmc_exal_v3_altcore_canary-20260418-233802__git-b4d99a1`
  - tmux: `qdesn_dynx_0418_233803`

## Initial Health Snapshot

Snapshot time: approximately `2026-04-18 23:38 EDT`

| Arm | Selected roots | Materialized | Running | Success | Fail |
|---|---:|---:|---:|---:|---:|
| AL rescue canary | 2 | 2 | 2 | 0 | 0 |
| EXAL rescue canary | 4 | 2 | 2 | 0 | 0 |
| AL rescue-extended canary | 2 | 2 | 2 | 0 | 0 |
| EXAL rescue-extended canary | 4 | 2 | 2 | 0 | 0 |
| EXAL QR tight-slice canary | 4 | 2 | 2 | 0 | 0 |
| EXAL altcore canary | 4 | 2 | 2 | 0 | 0 |

Aggregate read:

- total selected canary roots across all arms: `20`
- total materialized at first snapshot: `12`
- total running at first snapshot: `12`
- total terminal successes at first snapshot: `0`
- total terminal failures at first snapshot: `0`

## Interpretation Of The First Snapshot

The first snapshot is operationally clean:

- all six tmux sessions were live
- all six campaigns were materializing roots
- no early root failures had appeared yet

That does not establish that the new arms are successful. It only establishes that:

- the matrix launched cleanly
- the arm-specific defaults are parsable in real execution
- no arm failed immediately at the wrapper or preflight level

## Reproducibility Notes

- implementation and launch were performed from committed SHA `b4d99a1`
- canary prepares were rerun from the committed tree before live launch
- each run writes to the dedicated `v3_matrix_validation` report and results roots
- each run tag encodes the implementation SHA explicitly

## Next Step

Monitor canary outcomes by arm before promoting any residual phases.

The main questions are:

1. Does rescue baseline beat the v2 unresolved surface?
2. Does rescue-extended help more than it hurts?
3. Do the exAL-specific kernel arms outperform the generic rescue arms on the hardest exAL pocket?
