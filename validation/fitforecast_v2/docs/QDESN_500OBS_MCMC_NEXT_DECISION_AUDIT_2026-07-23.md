# Q-DESN 500-Observation MCMC Next Decision Audit

Date: 2026-07-23

This audit decides what to do after closing the Q-DESN RHS MCMC VB-candidate campaign. It is scoped only to the independent Q-DESN/DQLM validation study.

## Inputs

Validation worktree:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Validation branch and closeout baseline:

- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Closeout commit before this note: `b3fd67acb51d0acfe299c9ae7bae2f9c04b82131`

Primary closeout evidence:

- `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_vb_candidate_closeout_20260723/qdesn_tt500_mcmc_vb_candidate_authoritative_fit_summary_20260723.csv`
- `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_vb_candidate_closeout_20260723/qdesn_tt500_mcmc_vb_candidate_cell_model_summary_20260723.csv`
- `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_vb_candidate_closeout_20260723/qdesn_tt500_mcmc_vb_candidate_strict_signoff_failures_20260723.csv`

Comparison evidence:

- `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_summary.csv`
- `validation/fitforecast_v2/promotions/exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704/exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704_summary.csv`

## Current Completion State

The VB-candidate MCMC campaign is complete and does not need more waiting.

| quantity | value |
|---|---:|
| planned scientific roots | 72 |
| preferred successful roots | 72 |
| remaining roots | 0 |
| superseded stale RUNNING attempts | 1 |
| PASS | 9 |
| WARN | 30 |
| FAIL | 33 |
| comparison eligible | 39 |
| comparison ineligible | 33 |

The stale original RUNNING attempt is superseded by a successful retry and must not be treated as active work.

## Objective Used For Decision Audit

For this audit only, candidate ranking uses:

`objective = fit RMSE + forecast H1000 RMSE + forecast H1000 check loss`

This is not a new official article metric. It is a practical decision score for identifying whether a candidate is strong enough to promote or whether more calibration is justified. All final tables should still report the component metrics.

## Best Current Comparison-Eligible Evidence By Cell

| family | tau | current best eligible model | source | profile / candidate | signoff | objective | fit RMSE | H1000 RMSE | H1000 check |
|---|---:|---|---|---|---|---:|---:|---:|---:|
| gausmix | 0.05 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 7.604 | 2.623 | 3.476 | 1.505 |
| gausmix | 0.25 | Q-DESN AL RHS MCMC | VB-candidate closeout | mcvbc_017_al | PASS | 8.948 | 2.236 | 2.186 | 4.526 |
| gausmix | 0.50 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 10.209 | 2.226 | 2.427 | 5.556 |
| laplace | 0.05 | Q-DESN exAL RHS MCMC | VB-candidate closeout | mcvbc_036_exal | WARN | 11.932 | 6.971 | 3.126 | 1.835 |
| laplace | 0.25 | Q-DESN exAL RHS MCMC | VB-candidate closeout | mcvbc_046_exal | WARN | 7.903 | 1.802 | 1.723 | 4.378 |
| laplace | 0.50 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 8.545 | 1.774 | 1.689 | 5.082 |
| normal | 0.05 | Q-DESN exAL RHS MCMC | VB-candidate closeout | mcvbc_044_exal | WARN | 8.184 | 3.232 | 3.853 | 1.100 |
| normal | 0.25 | Q-DESN AL RHS MCMC | VB-candidate closeout | mcvbc_060_al | PASS | 8.950 | 2.238 | 3.369 | 3.343 |
| normal | 0.50 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 7.997 | 2.590 | 1.378 | 4.029 |

## Diagnosis

The evidence does not support a full blind relaunch.

Several cells already have strong Q-DESN comparison-eligible candidates:

- gausmix, tau 0.25: Q-DESN AL RHS is better than DQLM/exDQLM by the decision objective.
- laplace, tau 0.05: Q-DESN exAL RHS is better than DQLM/exDQLM by the decision objective, although WARN rather than PASS.
- laplace, tau 0.25: Q-DESN exAL RHS is best by the decision objective, although WARN rather than PASS.
- normal, tau 0.05: Q-DESN exAL RHS is essentially tied with DQLM by objective and has much better check loss.
- normal, tau 0.25: Q-DESN AL RHS is better than DQLM/exDQLM by the decision objective.

The remaining weaknesses are targeted rather than global:

1. Median cells are still mostly represented by older AL-only evidence, not by the new VB-candidate campaign.
2. Several exAL MCMC groups have no comparison-eligible candidate:
   - gausmix, tau 0.05, exAL: `0 / 7`
   - gausmix, tau 0.25, exAL: `0 / 5`
   - normal, tau 0.25, exAL: `0 / 5`
3. Strict failures are dominated by MCMC autocorrelation:
   - exAL high autocorrelation: 19 failures
   - exAL high autocorrelation plus half-chain drift: 3 failures
   - exAL Geweke drift: 3 failures
   - AL failures are fewer and more isolated.

This points to sampler quality and exAL geometry more than to a universal bad DESN reservoir class.

## Optimal Current Root

The best current authoritative root is not one physical run directory. It is a reconciled evidence root:

`validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_vb_candidate_closeout_20260723`

For immediate article-facing or benchmark-facing use:

- Use `qdesn_tt500_mcmc_vb_candidate_authoritative_fit_summary_20260723.csv` as the 72-root completed campaign evidence.
- Use only `comparison_eligible == TRUE` rows for clean MCMC winner claims.
- Use `qdesn_tt500_mcmc_vb_candidate_strict_signoff_failures_20260723.csv` to document completed but non-clean rows.

For current best MCMC comparison tables:

- Blend the new VB-candidate closeout with prior authoritative promotions only through an explicit promotion combiner.
- Do not hand-edit table rows.
- Do not silently replace a PASS older row with a FAIL newer row.

## Recommended Next Plan

### Step 1: Build a Promotion Combiner

Create a small, reproducible combiner that reads:

1. Q-DESN VB-candidate MCMC closeout, 2026-07-23.
2. Q-DESN AL RHS recalibrated authoritative promotion, 2026-07-02.
3. exDQLM/DQLM C13 MCMC authoritative promotion, 2026-07-04.

It should write a single current-best candidate table with:

- one row per model family / variant / family / tau / inference,
- metric provenance,
- signoff labels,
- comparison eligibility,
- source promotion id,
- source row path/hash,
- decision objective components.

Selection rules:

1. If multiple Q-DESN candidates exist for the same variant/cell, prefer `comparison_eligible == TRUE`.
2. Among eligible rows, minimize the decision objective.
3. If no eligible row exists, retain the best failed row only in a diagnostic table, not in the clean winner table.
4. Preserve tau 0.50 evidence from older authoritative promotions until a current-protocol tau 0.50 MCMC refresh exists.

### Step 2: Update the Validation Documentation

Add a short current-best note that separates:

- complete campaign evidence,
- clean comparison evidence,
- diagnostic failed evidence,
- cells that might justify targeted relaunch.

This prevents future confusion between “completed” and “promotable.”

### Step 3: Do Not Relaunch The Whole Campaign

A full relaunch is not optimal because:

- the campaign already completed 72/72 roots;
- many cells have clean eligible winners;
- the failure mode is concentrated in exAL MCMC autocorrelation;
- a full relaunch would spend most compute repeating known-good rows.

### Step 4: If Relaunching, Relaunch Only Targeted Cells

Relaunch only if the scientific objective requires cleaner Q-DESN exAL MCMC evidence in the weak cells. Target:

1. gausmix, tau 0.05, exAL
2. gausmix, tau 0.25, exAL
3. normal, tau 0.25, exAL
4. optionally normal, tau 0.05, exAL, because the best eligible row is WARN and the best raw row is FAIL but slightly better by objective.
5. tau 0.50 Q-DESN current-protocol refresh only if median MCMC claims must be updated beyond the older AL RHS promotion.

Relaunch strategy:

- Use the existing best VB/design candidates as initialization.
- Do not broaden reservoir search first.
- Change the MCMC strategy before changing the reservoir:
  - longer chain only for the specific failed cell;
  - stronger thinning or retained-draw policy if supported by current scripts;
  - more conservative RHS scale for exAL;
  - repeat seeds for one or two best designs rather than many new designs;
  - strict heartbeat and storage-light output.

### Step 5: Article Decision

Before article update:

- generate the current-best combined promotion table;
- check whether article tables should use clean-only rows or include diagnostic labels;
- avoid presenting failed-signoff MCMC rows as winners.

Recommended article stance:

- Promote clean Q-DESN wins/ties where eligible.
- Use diagnostic caveats for WARN rows.
- Keep FAIL rows out of headline comparison tables unless explicitly labeled.

## Bottom Line

The optimal move is not to relaunch everything. The optimal move is:

1. build a current-best promotion combiner;
2. update validation docs from that combiner;
3. use the clean eligible pool for article-facing tables;
4. plan a narrow exAL MCMC diagnostic relaunch only for cells with zero eligible exAL candidates or important near-ties.
