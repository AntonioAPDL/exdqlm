# REPORT: QDESN Dynamic Tau-0.50 Refreshed Main Setup And Launch

Date: 2026-04-16
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`
Committed implementation state: `15fe674`

## 1) Purpose

Record the committed-state preflight confirmation and the authoritative opening launch metadata for
the refreshed dynamic-only tau-`0.50` QDESN main relaunch.

This is the first live run on the new canonical study contract:

- dynamic-only data surface;
- taus `0.05 / 0.25 / 0.50`;
- `VB = LDVB`;
- `MCMC = slice`;
- explicit `LDVB` warm start for `MCMC`;
- `ridge` and `rhs_ns`;
- no core-lane `init_from_isvb`, `rw`, or `laplace_rw`.

## 2) Committed-State Preflight

Committed-state `prepare-only` preflights both passed under commit `15fe674`.

Smoke preflight:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-smoke-20260416-212634__git-15fe674`
- result:
  - pass
- scope:
  - audited subset covering all major refreshed axes

Full preflight:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212633__git-15fe674`
- result:
  - pass
- scope:
  - full `36`-root refreshed relaunch surface

## 3) Live Launch

Authoritative full launch:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`
- detached session:
  - `qdesn_dynx_0416_212700`
- launch metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/launch/launcher_session.json`
- launch log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/launch/launcher_stdout.log`

Opening log read:

- worker pool:
  - `3`
- first roots launched:
  - `gausmix tau=0.05 fit_size=500 ridge`
  - `laplace tau=0.05 fit_size=500 ridge`
  - `normal tau=0.05 fit_size=500 ridge`
- first active fit lane:
  - `exal / vb`

## 4) Opening Health Snapshot

Snapshot time:

- `2026-04-16 21:27:22 EDT`

Opening health:

- selected roots:
  - `36`
- materialized roots:
  - `3 / 36`
  - `8.3%`
- root status:
  - `3 RUNNING`
  - `0 SUCCESS`
  - `0 FAIL`
- fit summary rows written:
  - `0`
- pair summary rows written:
  - `0`
- seed-selection rows written:
  - `0`
- completed manifest:
  - absent, as expected at launch
- launcher session live:
  - `TRUE`

Interpretation:

- the refreshed relaunch started cleanly from committed state;
- the worker pool is active;
- roots are materializing normally;
- there is no early execution-failure signal.

## 5) Operational Read

This launch is the right branch-local continuation point because it is:

- committed-state;
- tied to the refreshed tau-`0.50` surface;
- aligned with the synced `0.4.0` package core;
- aligned with the canonical `LDVB + slice` policy; and
- free of the earlier replay-contract ambiguity.

## 6) Next Step

Continue monitoring the live relaunch and evaluate the refreshed main comparison outputs only after
the full `36`-root surface completes.
