# TRACK: QDESN Validation Guardrail Workflow (Steps 1-4)

Date: 2026-03-20  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: simulation/verification validation only (no benchmark execution)

## Purpose

This tracker freezes the operational workflow for the current QDESN
validation cycle with two non-negotiable constraints:

1. keep RHS tau-init/collapse guardrails active;
2. keep validation input non-DLM (`raw_y_lags`, decomposition disabled).

## Fixed constraints (must hold for all new waves)

- `pipeline.readout.input_mode` must be `raw_y_lags`.
- `pipeline.decomposition.enabled` must be `false`.
- `vb.priors.beta.rhs.init_log_tau` must resolve to numeric (default `0.0`).

If any of these are violated, the wave is considered invalid for this
simulation/verification study.

## Step 1: Reconcile campaign metadata

Script:
- `scripts/reconcile_qdesn_validation_campaign_status.R`

Outputs written under report root:
- `tables/campaign_metadata_reconcile.csv`
- `tables/campaign_metadata_reconcile_summary.csv`
- `campaign_metadata_reconcile.md`
- optional `manifest/campaign_completed.json` (with `--apply`).

## Step 2: Materialize guardrailed defaults

Script:
- `scripts/materialize_qdesn_rhs_guardrail_defaults.R`

Lock file:
- `config/validation/qdesn_rhs_guardrail_lock.yaml`

Behavior:
- deep-merges base defaults with guardrail lock;
- hard-validates non-DLM + numeric RHS init semantics before writing.

## Step 3: Build postmortem pack from completed waves

Script:
- `scripts/build_qdesn_mcmc_postmortem_pack.R`

Outputs:
- campaign overview and signoff grade counts;
- failure-focused pair table;
- runtime ratio profile table;
- manifest + markdown summary.

## Step 4: Run targeted guardrail wave from source report

Script:
- `scripts/run_qdesn_mcmc_targeted_guardrail_wave.R`

What it does:
- reads `campaign_pair_summary.csv` from a completed source report;
- selects fail/ineligible roots by default (optionally includes warns);
- defaults to RHS-only targets (`--include-ridge` is opt-in);
- prepares a per-wave staging bundle:
  - selected grid
  - guardrailed defaults
  - selection tables + manifest
- runs campaign using the prepared grid/defaults;
- reconciles campaign metadata (unless `--skip-reconcile`);
- writes baseline-vs-targeted comparison under `comparisons/`.

Recommended prepare-only dry run:

```bash
Rscript scripts/run_qdesn_mcmc_targeted_guardrail_wave.R \
  --source-report-root reports/qdesn_mcmc_validation/compare_constc2_v1/20260320-084314__git-37f1bd0 \
  --selection fail_or_ineligible \
  --prepare-only \
  --no-plots
```

Recommended full targeted run:

```bash
Rscript scripts/run_qdesn_mcmc_targeted_guardrail_wave.R \
  --source-report-root reports/qdesn_mcmc_validation/compare_constc2_v1/20260320-084314__git-37f1bd0 \
  --selection fail_or_ineligible \
  --no-plots
```

## Operational note

For this validation stage, any new wave must be launched through the
guardrailed path (Step 2 + Step 4). Do not launch direct ad-hoc campaigns that
omit the lock materialization step.

## Steps 1-5 Integrated Runner (2026-03-21)

To execute the next decision loop end-to-end (freeze baseline, verify
diagnostics path, run balanced sweep, run broader confirmation, and emit
promotion decision), use:

- `scripts/run_qdesn_rhs_guardrail_steps_1_to_5.R`

Key tracked inputs:

- rescue manifest:
  - `config/validation/qdesn_rhs_guardrail_rescue_v1_manifest.yaml`
- targeted 2-root sweep grid:
  - `config/validation/qdesn_rhs_guardrail_target_grid.csv`
- balanced profile set:
  - `config/validation/qdesn_rhs_guardrail_balanced_profiles.yaml`

Example launch:

```bash
Rscript scripts/run_qdesn_rhs_guardrail_steps_1_to_5.R --no-plots
```

## Targeted Single-Failure Matrix (T0-T6)

For the next wave after the first broader gate, run the targeted failing-root
matrix first, then broader reconfirmation through the same runner:

- targeted failing-root grid:
  - `config/validation/qdesn_rhs_guardrail_failing_root_grid.csv`
- targeted profiles:
  - `config/validation/qdesn_rhs_guardrail_targeted_profiles_t0_t6.yaml`

Launch:

```bash
Rscript scripts/run_qdesn_rhs_guardrail_steps_1_to_5.R \
  --target-grid config/validation/qdesn_rhs_guardrail_failing_root_grid.csv \
  --profiles config/validation/qdesn_rhs_guardrail_targeted_profiles_t0_t6.yaml \
  --no-plots
```

## Drift-Rescue Wave (A-D + Broader Reconfirmation)

This wave is the direct follow-up after the `T0-T6` matrix where the only
remaining blocker is `sin_asym_small, tau=0.25, rhs` with MCMC
`geweke_drift`.

Workflow:

1. Stage A: chain-length ladder on the single failing root.
2. Stage B: RHS geometry sweep at Stage-A winner chain length.
3. Stage C: global block-update sweep at Stage-B winner.
4. Stage D: 3-seed replicate robustness on the failing root.
5. Stage E: broader 8-root reconfirmation.
6. Final gate: promote only if Stage D and Stage E both pass.

Config + runner:

- `config/validation/qdesn_rhs_drift_rescue_wave.yaml`
- `scripts/run_qdesn_rhs_drift_rescue_wave.R`

Launch:

```bash
Rscript scripts/run_qdesn_rhs_drift_rescue_wave.R --no-plots
```

Monitor (example):

```bash
ls -1dt reports/qdesn_mcmc_validation/rhs_drift_rescue_wave/* | head -n 1
```

Live health snapshot (compact table):

```bash
Rscript scripts/monitor_qdesn_rhs_drift_rescue_wave.R \
  --analysis-root reports/qdesn_mcmc_validation/rhs_drift_rescue_wave/<run_tag> \
  --once
```

## Stage-I Blocker Isolation (Phase1/Phase2)

Purpose:
- isolate whether the remaining blocker is resolved by chain-length/burn-in only (Phase1),
  or requires targeted kernel escalation (Phase2) on the same blocker grid.

Config + runner:
- `config/validation/qdesn_rhs_stageI_manifest.yaml`
- `config/validation/qdesn_rhs_stageI_phase1_profiles.yaml`
- `config/validation/qdesn_rhs_stageI_phase2_profiles.yaml`
- `config/validation/qdesn_rhs_stageI_blocker_grid.csv`
- `scripts/run_qdesn_rhs_stageI_phase1_phase2_wave.R`

Launch:

```bash
Rscript scripts/run_qdesn_rhs_stageI_phase1_phase2_wave.R --no-plots
```

## Stage-J/K/L/M Confirmation Workflow

Purpose:
- Stage-J: broader reconfirmation using Stage-I candidate defaults.
- Stage-K: failed-root-only rescue matrix if Stage-J fails.
- Stage-L: broader reconfirmation from Stage-K winner, then promotion decision.
- Stage-M: expansion scaffold artifacts (grid + defaults template) for the next wave.

Config + runner:
- `config/validation/qdesn_rhs_stageJ_K_manifest.yaml`
- `config/validation/qdesn_rhs_stageK_profiles.yaml`
- `scripts/run_qdesn_rhs_stageJ_K_L_M_wave.R`

Launch:

```bash
Rscript scripts/run_qdesn_rhs_stageJ_K_L_M_wave.R --no-plots
```

## Latest Status And Relaunch Order (2026-03-23)

Current status:
- Stage-J/K/L/M wave completed at
  `reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369`.
- Stage-J strict broader gate failed (`2/8 FAIL`) due to MCMC drift diagnostics.
- Stage-K failed-root rescue matrix passed; winner profile:
  `K4_failed_roots_taufreeze_plus_adapt`.
- Stage-L broader reconfirmation passed (`0 FAIL`, `8 eligible`).
- Promoted defaults written:
  `config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`.
- Stage-M artifacts were generated (scaffold only), but Stage-M campaign was not launched yet.

Relaunch order (guardrail-first):

1. Materialize guardrailed Stage-M defaults:
   - base:
     `config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`
   - lock:
     `config/validation/qdesn_rhs_guardrail_lock.yaml`
   - output:
     `config/validation/qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml`
2. Run canary Stage-M on 12 roots (seed `123` only):
   - grid:
     `config/validation/qdesn_rhs_stageM_seed123_grid.csv`
3. Gate canary:
   - require `FAIL=0`, all comparison-eligible, all finite/domain true, no trace-unavailable.
4. If canary passes, run full Stage-M expansion:
   - grid:
     `config/validation/qdesn_rhs_stageM_expansion_grid.csv` (36 roots)
5. If expansion fails, run failed-root-only targeted repair (Stage-K style) and recheck on broader grid.

This keeps compute focused while preserving the RHS collapse guardrails and
non-DLM validation contract.

Single-run orchestrator (M0+M1+M2 auto-gated):

- `scripts/run_qdesn_rhs_stageM_wave.R`

Example:

## Latest Pause Snapshot (2026-03-27)

Current active stage at pause:
- Stage-O (`stageO-20260326-081449__git-d81c311`)

Summary at pause:
- O1 complete (`3/3`), O2 skipped by policy, O3 complete (`6/6`).
- O4 launched (`6` roots in parallel) but stalled with no new artifact writes
  after `2026-03-26 09:21:39 EDT`.
- Processes were explicitly stopped on `2026-03-27` to avoid burning compute
  while RHS-prior model changes are prepared.

Handoff tracker:
- `docs/TRACK__qdesn_rhs_stageO_wave.md`

Resume policy from here:
1. Make RHS-prior model changes.
2. Relaunch Stage-O with a fresh run tag.
3. Keep guardrails/non-DLM constraints unchanged.

```bash
Rscript scripts/run_qdesn_rhs_stageM_wave.R --no-plots
```

Current live run (started 2026-03-23):
- `reports/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369`

## Latest Status (2026-03-25) — Supersedes The 2026-03-23 Note

Stage-M was relaunched under supervised guardrails and completed:

- run_tag:
  `stageMrepair-supervised-20260324-172932__git-d81c311`
- tracker:
  `docs/TRACK__qdesn_rhs_stageM_repair_wave.md`
- MR1 winner:
  `MR1_longer_chain_plus_adapt`
- MR2 canary:
  `PASS` (`0 FAIL`, `12/12 eligible`)
- MR3 full (36 roots):
  execution complete, but strict gate `FAIL`
  (`n_pair_fail=2`, `n_pair_eligible=34/36`, finite/domain all true).

Operational implication:
- pipeline stability/collapse guardrails are working as intended;
- remaining blocker is targeted MCMC Geweke drift on two MR3 roots;
- next step is a failed-root-only Stage-N targeted drift-repair matrix,
  then one full 36-root reconfirmation with the Stage-N winner.

## Latest Status (2026-03-26) — Supersedes The 2026-03-25 Note

Stage-N completed with strong execution health and one remaining strict
signoff blocker:

- run_tag:
  `stageNrepair-20260325-150856__git-d81c311`
- tracker:
  `docs/TRACK__qdesn_rhs_stageN_wave.md`
- execution status:
  `SUCCESS 46/46`, `0 execution FAIL`
- MR3 strict gate:
  `FAIL` (`pair PASS/WARN/FAIL = 2/33/1`, `eligible=35/36`)
- remaining blocker:
  `scenario-sin_asym_small__tau-0p05__prior-rhs__seed-231__res-tiny_d1_n8`
  with `geweke_drift`.

Operational implication:
- collapse/finiteness is stable;
- remaining work is narrow RHS MCMC drift closure.

Next step:
- run Stage-O optimal drift-closure workflow (single-root racing, then narrow
  stress reconfirm, then one full reconfirm):
  `docs/TRACK__qdesn_rhs_stageO_plan.md`.

Current execution:
- Stage-O launched on 2026-03-26 with run_tag
  `stageO-20260326-071246__git-d81c311`
  under `reports/qdesn_mcmc_validation/rhs_stageO_wave/`.
