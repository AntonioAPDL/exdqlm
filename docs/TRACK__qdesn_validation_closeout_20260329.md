# TRACK: QDESN Validation Closeout (2026-03-29)

Date: 2026-03-29  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Scope

Deliver a decision-ready closeout with minimal compute:

1. freeze and audit completed baseline artifacts;
2. run zero-compute forensics;
3. run only a strict micro-pilot on failing roots;
4. expand only if hard gates pass.

No benchmark-pipeline work and no broad-grid rerun.

## 2) Baseline Freeze

- baseline run_tag: `dynamic-family-prior-20260329-053603`
- baseline root status: `36/36 SUCCESS`
- baseline results root:
  - `results/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b`
- baseline report root:
  - `reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b`

Stale runs excluded by policy:

- `dynamic-family-prior-20260329-053316`: `ABORTED_STALE`
- `stageP ridge_anchor`: `ABORTED_STALE`

## 3) Finalization Workspace

- run_tag: `closeout-20260329-074000__git-4536ccc`
- report root:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc`
- results root:
  - `results/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc`
- manifests:
  - `summary/phase01_preflight_manifest.json`
  - `summary/phase01_manifest.json`
  - `summary/phase35_manifest.json`

## 4) Gate Results

### 4.1 Gate A (Forensics) — PASS

- MCMC FAIL rows in baseline: `17`
- dominant fail groups:
  - `low_ess`: `9/17` (`52.9%`)
  - `half_chain_drift`: `4/17` (`23.5%`)
  - `high_acf`: `4/17` (`23.5%`)
- concentration (`top3_share`): `1.000`

Decision: proceed to micro-pilot.

### 4.2 Gate B (Micro-Pilot) — FAIL

Micro-pilot grid: 6 failing roots, stratified by failure mode and coverage
(`tail + median`, `exal + al`, includes `rhs_ns`).

Profiles tested:

- `P1_longer_chain`
- `P2_conservative_slice`
- `P3_blocked_adapt`

Results:

| profile | baseline FAIL | profile FAIL | fail reduction | finite/domain regression | collapse regression | median runtime inflation | Gate B |
|---|---:|---:|---:|---|---|---:|---|
| P1_longer_chain | 6 | 4 | 33.3% | none | none | +89.4% | FAIL |
| P2_conservative_slice | 6 | 5 | 16.7% | none | none | +117.5% | FAIL |
| P3_blocked_adapt | 6 | 5 | 16.7% | none | none | +143.7% | FAIL |

Hard gate required:

- `fail_reduction >= 40%`
- no new finite/domain violations
- no collapse-guardrail regressions
- median runtime inflation `<= 50%`

No profile passed all conditions.

## 5) Final Decision

1. Hold current defaults for this validation cycle.
2. Do not launch broad rerun on current tuning-only profiles.
3. Escalate to kernel-level redesign on failing MCMC roots.

Recommendation string (manifest):

- `hold defaults; escalate to kernel redesign`

## 6) Repro Commands

Phase 0-2:

```bash
Rscript scripts/run_qdesn_validation_closeout_phase01.R \
  --run-tag closeout-20260329-074000__git-4536ccc \
  --baseline-report-root reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b \
  --baseline-results-root results/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b \
  --micro-size 6
```

Phase 3-5:

```bash
Rscript scripts/run_qdesn_validation_closeout_phase35.R \
  --phase01-manifest reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase01_manifest.json \
  --workers 1 \
  --no-plots
```

## 7) Artifact Map

Primary outputs:

- phase01 summary:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase01_summary.md`
- phase35 summary:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase35_summary.md`
- micro-pilot summary table:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/tables/phase35_micro_pilot_summary.csv`
- diagnostic deltas:
  - `.../tables/phase35_micro_pilot_diag_shift.csv`
- metric deltas:
  - `.../tables/phase35_micro_pilot_metric_shift.csv`

## 8) Notes for Next Wave

This closeout establishes that tuning-only changes improved some diagnostics,
but insufficiently and with unacceptable runtime inflation. Next wave should
focus on kernel design changes, not broader chain-length inflation.
