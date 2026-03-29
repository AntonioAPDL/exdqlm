# TRACK: QDESN Stage-P rhs_ns Full Relaunch Wave

Date: 2026-03-27  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (`readout.input_mode=raw_y_lags`, `decomposition.enabled=false`)

## 1) Purpose

Run a full refit wave with `rhs_ns` as the default RHS-family prior for the qdesn validation cases, preserving the VB->MCMC warm-start flow (`init_from_vb=true`), and produce a healthy/fail map under current signoff gates.

In parallel, run a ridge anchor sweep to keep continuity with prior validation baselines.

## 2) Stage-P Assets

- Defaults:
  - `config/validation/qdesn_mcmc_compare_rhsns_stageP_defaults.yaml`
- Full rhs_ns grid (main wave):
  - `config/validation/qdesn_rhsns_stageP_expansion_grid.csv`
  - size: 36 roots (`4 scenarios x 3 taus x 3 seeds x rhs_ns`)
- Ridge anchor grid (secondary wave):
  - `config/validation/qdesn_ridge_stageP_anchor_grid.csv`
  - size: 12 roots (`4 scenarios x 3 taus x 1 seed x ridge`)
- Launcher:
  - `scripts/run_qdesn_rhsns_stageP_wave.R`

## 3) Execution Contract

1. Main decision surface comes from the 36-root `rhs_ns` wave.
2. Ridge is treated as an anchor/control, not the promoted sparse prior target.
3. Guardrails remain active (including tau-init semantics and collapse diagnostics).
4. No benchmark pipeline work in this wave.

## 4) Outputs To Watch

Per-arm campaign outputs are written under:

- `results/qdesn_mcmc_validation/rhsns_stageP_wave/<run_tag>/...`
- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/<run_tag>/...`

Wave-level summary outputs:

- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/<run_tag>/summary/stageP_wave_summary.csv`
- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/<run_tag>/summary/stageP_wave_summary.md`
- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/<run_tag>/summary/stageP_wave_manifest.json`

## 5) Promotion Read

Stage-P is considered successful if:

1. `rhs_ns` 36-root run completes with no execution failures,
2. collapse flags remain zero or isolated and explainable,
3. comparison-eligible coverage is at least comparable to prior RHS wave,
4. remaining failures are localized enough for targeted repair (not diffuse instability).

## 6) Live Execution Snapshot (2026-03-27)

Launched command:

- `Rscript scripts/run_qdesn_rhsns_stageP_wave.R --workers-full 12 --workers-ridge 8 --no-plots`
- run tag:
  - `stageP-20260327-181230__git-2641e6b`

Current arm status:

1. `rhsns_full` (36 roots):
   - `36/36 SUCCESS` completed.
2. `ridge_anchor` (12 roots):
   - first parallel batch (`8` roots) is running/in finalization;
   - `2` roots already have complete MCMC health summaries;
   - remaining roots are still marked `RUNNING`.

Live output roots:

- `results/qdesn_mcmc_validation/rhsns_stageP_wave/stageP-20260327-181230__git-2641e6b/rhsns_full/20260327-181231__git-2641e6b`
- `results/qdesn_mcmc_validation/rhsns_stageP_wave/stageP-20260327-181230__git-2641e6b/ridge_anchor/20260327-182020__git-2641e6b`

## 7) Health Check Snapshot (2026-03-28)

### 7.1 rhs_ns full arm (completed)

Artifact root:

- `reports/qdesn_mcmc_validation/rhsns_stageP_wave/stageP-20260327-181230__git-2641e6b/rhsns_full/20260327-181231__git-2641e6b`

Campaign status:

- roots: `36`
- root success: `36`
- root fail: `0`
- method rows: `72` (`36 vb`, `36 mcmc`)

Method signoff:

- `vb`: `PASS 13`, `WARN 23`, `FAIL 0`, eligible `36/36`
- `mcmc`: `PASS 1`, `WARN 33`, `FAIL 2`, eligible `34/36`

Health/collapse:

- `unhealthy_true = 0`
- `rhs_collapse_flag_true = 0`

Pair-level comparability:

- pair rows: `36`
- both success: `36`
- comparison-eligible pairs: `34`
- pair signoff: `PASS 1`, `WARN 33`, `FAIL 2`
- non-eligible pairs are both at `tau=0.50` with `mcmc_signoff_reason=geweke_drift`.

Scoring coverage:

- pinball/qhat metrics are present;
- synthesis metrics (`CRPS`, `S`) are `NA` in this run because each root is single-quantile.

### 7.2 ridge anchor arm (incomplete)

Artifact root:

- `results/qdesn_mcmc_validation/rhsns_stageP_wave/stageP-20260327-181230__git-2641e6b/ridge_anchor/20260327-182020__git-2641e6b`

Current state:

- `8` roots materialized, all still marked `RUNNING`;
- `vb` summaries exist for all `8`;
- `mcmc` summaries exist for `2/8`;
- parent Stage-P process exited before producing ridge campaign summary tables.
