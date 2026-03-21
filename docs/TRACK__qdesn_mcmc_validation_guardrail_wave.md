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
