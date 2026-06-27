# Q-DESN TT500 VB Post-Targeted Diagnosis and Next Plan

Date: 2026-06-27

This note documents the completed TT500 Q-DESN VB targeted refinement wave and the
recommended next screening strategy. It is not an article promotion note. The
article-facing table should not consume a new Q-DESN replacement until a profile
or run-specific profile set is explicitly frozen and signed off.

## Evidence Roots

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Run tag: `qdesn-tt500-vb-targeted-refinement-full-20260626`
- Report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322`
- Results root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322`

## Completion and Audit

Strict audit command:

```sh
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement/qdesn-tt500-vb-targeted-refinement-full-20260626/20260626-142912__git-f700322 \
  --expected-roots 1080 \
  --strict \
  --require-rankings
```

Strict audit result:

- expected roots: 1080
- observed roots: 1080
- success: 1080
- running: 0
- fail: 0
- successful roots with lead metrics: 1080
- successful roots with rolling-origin paths: 1080
- successful roots passing storage-light policy: 1080
- forbidden binary payloads: 0
- generic ranking exists: true
- dominance ranking exists: true
- strict ready: true

Core tables:

- `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- `tables/qdesn_tt500_vb_dominance_cell_summary.csv`
- `tables/qdesn_tt500_vb_dominance_profile_ranking.csv`

## Main Result

The targeted refinement was successful computationally but did not solve VB
dominance:

- profiles screened: 120
- family x tau cells: 9
- global dominance-pass profiles: 0
- best global profile:
  `tt500vb_tref_d1_n30_a0p05_r0p6_m90_lag90_rl1_pw0p2_pin0p8`
- best global worst-primary ratio: 2.439980
- cells beating all primary baselines for best global profile: 2 of 9

This means the next step should not be TT500 replacement MCMC. The VB forecast
screen still needs improvement.

## Cell-Level Diagnosis

Best per-cell worst-primary ratios after the targeted wave:

| family | tau | best worst ratio | best profile | status |
|---|---:|---:|---|---|
| gausmix | 0.05 | 0.958005 | `tt500vb_tref_d2_n20_a0p3_r0p85_m90_lag90_rl0_pw0p05_pin0p3` | passes all primary metrics |
| gausmix | 0.25 | 1.115475 | `tt500vb_tref_d1_n40_a0p03_r0p5_m90_lag90_rl1_pw0p2_pin0p8` | close, forecast MAE bottleneck |
| gausmix | 0.50 | 1.163753 | `tt500vb_tref_d1_n40_a0p03_r0p5_m90_lag90_rl1_pw0p2_pin0p8` | moderate forecast MAE gap |
| laplace | 0.05 | 0.956549 | `tt500vb_tref_d1_n40_a0p4_r0p9_m90_lag90_rl0_pw0p05_pin0p3` | passes all primary metrics |
| laplace | 0.25 | 1.325098 | `tt500vb_tref_d2_n30_a0p4_r0p9_m90_lag90_rl0_pw0p05_pin0p3` | forecast MAE bottleneck |
| laplace | 0.50 | 1.607590 | `tt500vb_tref_d1_n30_a0p4_r0p9_m90_lag90_rl0_pw0p05_pin0p3` | hard forecast MAE gap |
| normal | 0.05 | 1.214399 | `tt500vb_tref_d2_n40_a0p1_r0p7_m90_lag90_rl1_pw0p2_pin0p8` | improved but not enough |
| normal | 0.25 | 1.499720 | `tt500vb_tref_d2_n30_a0p03_r0p5_m90_lag90_rl0_pw0p1_pin0p8` | hard forecast MAE gap |
| normal | 0.50 | 1.629702 | `tt500vb_tref_d2_n50_a0p05_r0p6_m90_lag90_rl1_pw0p2_pin0p8` | hard forecast MAE gap |

Compared with the earlier 72-profile dominance screen, targeted refinement helped
most for:

- normal tau 0.05: worst ratio improved from 1.475507 to 1.214399
- normal tau 0.25: worst ratio improved from 1.652076 to 1.499720
- gausmix tau 0.50: worst ratio improved from 1.212529 to 1.163753

It did not materially solve:

- normal tau 0.50
- laplace tau 0.50
- laplace tau 0.25
- normal tau 0.25

## Factor Signals

Forecast-worst ratio means across all cell-profile rows:

- D=1: 1.913
- D=2: 1.934
- n_each=50: 1.820
- n_each=30: 1.870
- n_each=20: 1.955
- n_each=40: 1.970
- n_each=60: 2.029
- alpha/rho 0.10/0.70: 1.860
- alpha/rho 0.05/0.60: 1.868
- alpha/rho 0.03/0.50: 1.870
- no reservoir lag: 1.882
- reservoir lag 1: 2.002
- sparse profile `pi_w=0.05, pi_in=0.30`: 1.847
- hybrid profile `pi_w=0.10, pi_in=0.80`: 1.917
- input-rich profile `pi_w=0.20, pi_in=0.80`: 2.002

Global averages favor sparse/no-reservoir-lag and moderate low dynamics, but
cell-level winners are heterogeneous. A single universal spec is currently a poor
optimization target.

## Diagnosis

1. The execution pipeline is healthy. The strict audit passed, all rolling-origin
   artifacts exist, and storage-light retention is clean.
2. Fit recovery is not the problem. The best profiles usually have fit RMSE and
   fit pinball ratios far below 1.
3. Forecast MAE is the dominant failure mode. Pinball is often close to 1, while
   forecast MAE is still 1.1 to 1.6 times the best DQLM/exDQLM VB baseline in
   hard cells.
4. The search has found useful structure but not dominance. We should not spend
   MCMC on this profile family yet.
5. The next search should be cell-aware and forecast-aware, not global-profile
   first. The earlier run-specific-spec design is now clearly the better path.

## Recommended Next Strategy

### Step 1: Freeze Current Wave as Evidence Only

Mark this targeted wave as completed and audited, but do not promote it to the
article-facing replacement table. It is a clean negative/diagnostic screen.

Required outputs to preserve:

- strict audit summary
- dominance profile ranking
- dominance cell summary
- generic profile ranking
- this diagnosis note

### Step 2: Create a Cell-Specific Candidate Ledger

Create a table with one row per family x tau cell containing:

- current best profile
- current best forecast MAE ratio
- current best forecast pinball ratio
- fit RMSE ratio
- fit pinball ratio
- profile metadata
- recommended local search neighborhood
- priority level

Priority cells:

1. normal tau 0.50
2. laplace tau 0.50
3. normal tau 0.25
4. laplace tau 0.25
5. normal tau 0.05
6. gausmix tau 0.50
7. gausmix tau 0.25

Low-priority monitor cells:

- gausmix tau 0.05
- laplace tau 0.05

### Step 3: Run a Smaller, Hard-Cell Focused VB Screen

Do not rerun all 9 cells equally. Use a focused screen with:

- hard cells only by default
- optional sentinel rows for the two passing cells
- 20 workers
- VB only
- no MCMC
- storage-light retention

Recommended parameter emphasis:

- keep period-90 design
- keep rolling-origin Hmax=30 and stride=30
- emphasize no reservoir lag
- emphasize sparse `pi_w=0.05, pi_in=0.30`
- keep moderate low dynamics around `(alpha, rho) = (0.03,0.50), (0.05,0.60), (0.10,0.70)`
- keep selected high-dynamics local neighborhoods only for laplace cells where they won
- prioritize n_each 30 and 50
- include D=1 and D=2
- avoid n_each 60 except as a tiny sentinel, because it is slower and worse on average

Suggested size:

- 7 hard cells x 30 to 45 profiles = 210 to 315 roots
- optional 2 sentinel cells x 5 profiles = 10 roots
- total target: 220 to 325 roots

This is more efficient than another 1080-root global screen.

### Step 4: Add Forecast-Mechanism Variants, Not Just Reservoir Variants

The current screen mostly changes reservoir geometry. Since forecast MAE is the
failure mode, the next screen should include a few controlled forecast/readout
variants:

- readout_y_lags around 60, 90, 120
- maybe m around 60, 90, 120 only if source materialization supports it cleanly
- sparse/no-lag reservoir as default
- optional direct seasonal covariate variants if already supported

This should be implemented as a new materialized stage, not by editing completed
outputs.

### Step 5: Decide the Promotion Target Before More MCMC

Two possible promotion standards:

1. Universal profile promotion: one Q-DESN VB profile must beat DQLM/exDQLM VB in
   all 9 cells. Current evidence suggests this is unlikely soon.
2. Run-specific profile promotion: one frozen profile per family x tau cell, with
   a shared protocol and source registry. This matches the run-specific-spec
   launcher design and is more scientifically honest for a tuning study.

Recommendation: use run-specific profile promotion for VB. Require every cell to
beat the best DQLM/exDQLM VB baseline before any MCMC replacement wave.

### Step 6: Only Then Consider MCMC

MCMC should be launched only after a VB candidate set satisfies the forecast
dominance gate. Until then, MCMC is too expensive and unlikely to fix a structural
forecast MAE gap.

## Next Concrete Build

Build a new hard-cell screen stage:

- stage name: `qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement`
- profile source: current dominance cell summary plus targeted registry
- run tag pattern: `qdesn-tt500-vb-hardcell-forecast-refinement-YYYYMMDD`
- expected roots: 220 to 325
- workers: 20
- required gates: materialize, prepare-only, one-root smoke, full launch, strict
  audit, dominance ranking

No article updates and no MCMC should be launched from the current targeted wave.
