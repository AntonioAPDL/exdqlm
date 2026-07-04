# exDQLM/DQLM and Q-DESN RHS Optimization Screening Plan

Date: 2026-07-04

Scope: shared fit+forecast validation harness only. This is a planning and
audit document; it does not authorize a new full validation launch. The core
`exdqlm` 1.0.0 package API should not be modified for this optimization lane.

## Objective

Prepare two VB-first optimization tracks for the 500-observation rolling-origin
simulation comparison:

1. Improve exDQLM so that it is at least non-inferior to DQLM, preferably
   better, before spending more MCMC compute.
2. Improve Q-DESN AL RHS and exAL RHS, under both VB and later MCMC, with
   family/quantile-specific specifications allowed when the evidence supports
   them.

Both tracks must use the shared frozen source registry, rolling-origin forecast
protocol, storage-light outputs, and article-facing promotion gates already
established in fit+forecast v2.

## Evidence Sources

Article-facing current summary:

```text
/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv
```

Validation worktree:

```text
/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
branch: validation/shared-fitforecast-v2-1.0.0
HEAD during audit: f4956ddd3dcb1193194458c9dbaab9f87829e338
```

Key validation-side records:

```text
validation/fitforecast_v2/docs/EXDQLM_DQLM_VB_CALIBRATION_SCREEN_PLAN_2026-07-02.md
validation/fitforecast_v2/docs/EXDQLM_DQLM_QDESN_VB_CURRENT_BEST_AUDIT_2026-07-03.md
validation/fitforecast_v2/docs/EXDQLM_DQLM_C13_MCMC_500OBS_REFRESH_AUDIT_2026-07-04.md
validation/fitforecast_v2/docs/QDESN_TT500_VB_DOMINANCE_SCREENING_2026-06-26.md
validation/fitforecast_v2/docs/QDESN_TT500_VB_STAGE4_REMAINING_CELLS_TRANSFER_2026-06-29.md
validation/fitforecast_v2/docs/QDESN_TT500_MCMC_AL_RHS_RECALIBRATION_2026-07-02.md
```

Current promoted/selected inputs:

```text
validation/fitforecast_v2/config/exdqlm_dqlm_vb_calibration_screen_candidates_20260702.csv
validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv
validation/fitforecast_v2/promotions/exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704/exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704_summary.csv
validation/fitforecast_v2/promotions/qdesn_tt500_al_rhs_recalibrated_candidate_20260701/qdesn_tt500_al_rhs_recalibrated_candidate_20260701_summary.csv
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_summary.csv
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_authoritative_20260701/qdesn_tt500_mcmc_authoritative_summary.csv
```

## Shared Protocol That Must Stay Fixed

- package baseline: `exdqlm` 1.0.0
- source registry hash:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- training target window for the 500-observation comparison:
  source indices `8501:9000`
- forecast block: source indices `9001:10000`
- rolling-origin protocol: no refit; observed-lag state update
- maximum lead: `Hmax = 30`
- origin stride: `30`
- no quantile synthesis
- article-facing metrics: fit RMSE/check loss, rolling forecast MAE/check loss,
  diagnostic status, provenance, and storage-light artifact hashes

## Current exDQLM/DQLM Evidence

### What Was Already Screened

The VB calibration screen varied dynamic prior and discount settings over 16
candidates. The current selected candidate for all 18 exDQLM/DQLM VB cells is:

```text
c13_trend100_season1_df0995s099
trend_C0_scale = 100
seasonal_C0_scale = 1
df_value = 0.995,0.99
dim_df = 2,4
```

The c13 VB screen fixed a large part of the old artificial weakness. The
current-best VB audit records `18/18` done/PASS cells and selected c13 in every
cell.

### Remaining VB Gaps

exDQLM is close to DQLM for most median and 0.25 cells, but it is still weaker
for low quantiles:

| Inference | Family | Tau | exDQLM/DQLM fit RMSE | exDQLM/DQLM forecast MAE | exDQLM/DQLM check loss |
| --- | --- | ---: | ---: | ---: | ---: |
| VB | laplace | 0.05 | 1.85 | 2.57 | 1.15 |
| VB | normal | 0.05 | 1.14 | 2.16 | 1.07 |
| VB | gausmix | 0.05 | 1.69 | 1.79 | 1.18 |

The bad VB cells are not just long-lead problems. Lead-band diagnostics show
exDQLM/DQLM forecast MAE ratios already elevated at leads 1-5 for the low
quantile cells.

### Remaining MCMC Gaps

The c13 MCMC refresh is complete and promoted as diagnostic-qualified evidence:

```text
run tag: 20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v2
done/PASS cells: 18/18
done/PASS lead rows: 540/540
```

However, exDQLM MCMC forecast behavior is not acceptable if the scientific goal
is exDQLM non-inferiority to DQLM:

| Inference | Family | Tau | exDQLM/DQLM fit RMSE | exDQLM/DQLM forecast MAE | exDQLM/DQLM check loss |
| --- | --- | ---: | ---: | ---: | ---: |
| MCMC | gausmix | 0.05 | 0.97 | 7.96 | 3.89 |
| MCMC | normal | 0.05 | 0.64 | 4.24 | 3.91 |
| MCMC | gausmix | 0.25 | 0.29 | 3.59 | 1.24 |
| MCMC | normal | 0.25 | 0.61 | 3.00 | 1.24 |
| MCMC | laplace | 0.05 | 1.55 | 2.29 | 2.62 |

Lead-band diagnostics show the MCMC problem is already present at leads 1-5 and
is dominated by forecast bias. This argues against a pure horizon-propagation
explanation. The next exDQLM lane should test the fitted exAL latent
scale/skew terms, MCMC initialization, and rolling state-update approximation
before spending on a broad full-budget MCMC relaunch.

## Current Q-DESN RHS Evidence

### What Was Already Screened

Q-DESN VB screening moved through:

- broad period-90 dominance screen
- targeted forecast/refinement stages
- Stage 4A remaining-cell transfer
- Stage 4B gausmix tau 0.05 refinement
- AL RHS-specific recalibration

The successful compact profile family is mostly:

```text
D = 1 or 2
n_each = 20 or 30
m = 15
readout_y_lags = 15
reservoir_lags = 0
pi_w = 0.03 or 0.05
pi_in = 0.30 or 0.50
rho = 0.35 to 0.60
alpha = 0.01 to 0.05
rhs_tau0 = 1e-04
```

The unstable exploratory setting `rhs_tau0 = 3e-05` failed repeatedly and is
excluded from promoted AL RHS evidence.

### Current Gaps To Screen

Q-DESN RHS check loss is generally competitive, but some cells still have
large fit-RMSE or forecast-MAE ratios relative to DQLM/exDQLM. If the goal is a
polished comparison where Q-DESN RHS is the clear overall winner, these cells
are the priority:

| Inference | Cell | Model | Main gap |
| --- | --- | --- | --- |
| VB | gausmix 0.05 | AL RHS and exAL RHS | fit RMSE about 2.1x-2.5x best DQLM/exDQLM |
| VB | laplace 0.50 | exAL RHS | forecast MAE about 2.1x best DQLM/exDQLM |
| VB | normal 0.50 | AL RHS and exAL RHS | forecast MAE about 1.8x-2.0x best DQLM/exDQLM |
| MCMC | normal 0.50 | AL RHS and exAL RHS | forecast MAE about 3.0x-3.3x best DQLM/exDQLM |
| MCMC | gausmix 0.05 | AL RHS and exAL RHS | fit RMSE and forecast MAE still elevated |
| MCMC | laplace 0.05 | AL RHS | forecast MAE about 5.7x exAL RHS |
| MCMC | normal 0.05 | AL RHS | forecast MAE about 3.0x exAL RHS |

Interpretation: Q-DESN RHS is not broken, but AL RHS and exAL RHS should not be
treated as fully optimized. The strongest next move is another VB-first,
cell-specific refinement, then only promote winners to MCMC.

## Optimization Track A: exDQLM/DQLM

### Scientific Gate

Use DQLM as the required non-inferiority baseline for exDQLM. For every
family/tau cell, a candidate should satisfy:

- forecast check loss <= `1.05x` DQLM, preferably lower
- forecast MAE <= `1.10x` DQLM, preferably lower
- fit RMSE <= `1.10x` DQLM unless forecast metrics clearly improve
- no large lead-1 to lead-5 forecast bias
- no failed/stopped VB convergence status for promoted VB rows

### Stage A1: VB Diagnostic Expansion

Target first:

```text
gausmix tau 0.05
normal tau 0.05
laplace tau 0.05
gausmix tau 0.25
normal tau 0.25
laplace tau 0.25
```

Keep DQLM paired in the manifest so every exDQLM candidate is compared to a
matched DQLM row under the same model prior and discount settings.

Candidate axes:

- C0 around c13: trend `50, 100, 200, 400`; seasonal `0.5, 1, 2, 5`
- trend discount: `0.99, 0.995, 0.9975`
- seasonal discount: `0.98, 0.99, 0.995`
- VB budget ladder: `max_iter = 300, 600`; tighter tolerance only for
  low-quantile finalists
- optional validation-harness-only forecast diagnostic variants:
  - current plugin state update
  - no observed-lag state update after training, diagnostic only
  - capped/damped exAL pseudo-observation update, diagnostic only

Do not screen period or harmonics in the first pass. The DGP metadata and model
builder already agree on period `90` and harmonics `1,2`.

### Stage A2: VB Fit-Only Then Forecast

The harness supports `--validation-stage fit-only` and `forecast-only`. Use
that to avoid forecasting every poor fit:

1. Run fit-only for all A1 candidates.
2. Keep candidates that pass fit gates and have no convergence pathologies.
3. Forecast only the finalists.
4. Select by forecast check loss, with forecast MAE and fit RMSE as tie
   breakers.

### Stage A3: Short MCMC Confirmation

Run MCMC only for VB finalists. Do not start with another 18-cell full-budget
MCMC run.

Recommended first MCMC confirmation:

- cells: only finalists from A2
- burn-in: `1000`
- retained: `3000` to `5000`
- one core per root
- reuse VB initialization handoffs; do not recompute VB inline when a matching
  VB handoff exists
- audit lead-1 to lead-5 bias before considering full-budget promotion

### Stage A4: Full MCMC Promotion

Only launch full MCMC when short MCMC confirms non-inferiority:

- burn-in: `5000`
- retained: `20000`
- thin: `1`
- storage-light successful rows
- article-facing promotion only after strict audit and manifest hashes

## Optimization Track B: Q-DESN AL RHS and exAL RHS

### Scientific Gate

Q-DESN RHS candidates should be ranked cell-specifically against both:

1. the best current Q-DESN RHS row for the same likelihood/inference, and
2. the best DQLM/exDQLM row for the same family/tau/inference.

Promotion should require:

- forecast check loss <= best comparator, or <= `1.02x` with materially better
  forecast MAE
- forecast MAE <= best comparator whenever possible
- fit RMSE not catastrophically worse, with explicit flag if fit RMSE is traded
  for forecast dominance
- no failed RHS prior geometry
- `rhs_tau0 = 3e-05` excluded unless a separate diagnostic rescue explicitly
  proves it safe

### Stage B1: VB Broad-But-Local Screen

Run VB only. Screen AL RHS and exAL RHS separately but with a shared candidate
grammar.

Priority cells:

```text
gausmix tau 0.05
laplace tau 0.50
normal tau 0.50
normal tau 0.05
laplace tau 0.05
gausmix tau 0.25
```

Candidate grammar:

- depth: `D = 1, 2`; `D = 3` sentinel only
- width: `n_each = 20, 30, 40, 50, 70`
- memory/readout: `m = 10, 15, 20, 30`; `readout_y_lags = m`
- reservoir lags: `0` first; `1` only for unresolved cells
- dynamics: `alpha = 0.005, 0.01, 0.02, 0.03, 0.05, 0.08`
- spectral radius: `rho = 0.25, 0.35, 0.45, 0.50, 0.60, 0.70`
- sparsity: `pi_w = 0.02, 0.03, 0.05`; `pi_in = 0.30, 0.50, 0.80`
- RHS scale: `rhs_tau0 = 1e-04, 3e-04, 1e-03`
- seeds: start with `123`; rerun finalists with at least one alternate seed
  before MCMC

Keep `p_over_n_tt500 <= 0.30` for the broad screen. Allow a few sentinel
profiles up to `0.50` only if compact candidates fail.

### Stage B2: VB Cell-Specific Refinement

After B1, choose the top 3-5 candidates per unresolved family/tau/likelihood
cell. Refine locally:

- around the winning `alpha/rho`
- around the winning `m/readout_y_lags`
- around `rhs_tau0`
- with at least two reservoir seeds

The output should be a candidate ledger with one selected VB winner per
family/tau/likelihood cell, not one global profile forced across all cells.

### Stage B3: MCMC Short Confirmation

Use B2 winners to run short MCMC:

- one root per family/tau/likelihood winner
- one core per root
- burn-in `1000`
- retained `3000` to `5000`
- strict progress telemetry
- compare short-MCMC forecast check/MAE against the corresponding VB winner and
  best DQLM/exDQLM row

### Stage B4: Full MCMC Promotion

Only promote to full MCMC when B3 is clean:

- burn-in `5000`
- retained `20000`
- thin `1`
- keep compact summaries and diagnostics
- no successful heavy `.rds`, `.rda`, `.RData` retention
- article table update only from a promotion handoff

## Implementation Plan

### Build 01: Audit Materializer

Add a reproducible audit script that writes:

```text
validation/fitforecast_v2/docs/validation_optimization_gap_audit_20260704.csv
```

Required rows:

- exDQLM/DQLM VB ratios
- exDQLM/DQLM MCMC ratios
- Q-DESN AL RHS and exAL RHS ratios versus best DQLM/exDQLM
- Q-DESN AL RHS versus exAL RHS internal ratios
- lead-band ratios for exDQLM/DQLM low-quantile cells

### Build 02: Candidate Registries

Create tracked candidate registries:

```text
validation/fitforecast_v2/config/exdqlm_dqlm_vb_noninferiority_screen_candidates_20260704.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_profiles_20260704.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_cell_assignments_20260704.csv
```

### Build 03: Dry-Run/Smoke

Before any broad screen:

- source verification
- prepare-only
- no stale `/home/jaguir26/local/src` paths
- one hard-cell smoke for each track
- storage policy check
- schema check for lead metrics

### Build 04: VB Screens

Run in the background only after dry-run/smoke pass:

- exDQLM/DQLM VB non-inferiority screen: start with 12-20 workers
- Q-DESN RHS VB optimization screen: start with 20 workers

### Build 05: Promotion Audit

Do not update Article directly from exploratory outputs. Promotion requires:

- strict audit
- candidate ledger
- source hash verification
- interface/schema hashes
- exact run tags
- diagnostic qualification
- storage-light audit

### Build 06: MCMC Confirmation

After VB promotion only:

- short MCMC confirmation
- full MCMC only after short MCMC is scientifically clean and explicitly
  approved

## Immediate Recommendation

Do not launch full MCMC now. The next optimal action is to implement Build 01
and Build 02, then run dry-run/smoke. The exDQLM MCMC issue is too strong and
too early-horizon-biased to justify another full c13 MCMC launch without a
diagnostic screen. Q-DESN RHS is promising, but the article table will be
stronger if AL RHS and exAL RHS receive a final VB-first targeted optimization
before any expensive MCMC refresh.
