# QDESN exAL Kernel Relaunch Plan

- date: `2026-03-30`
- branch: `feature/qdesn-mcmc-alternative`
- prior stuck run: `exal-kernel-screen-overnight-20260329__git-412b379`
- recommended manifest: `config/validation/qdesn_exal_kernel_screen_manifest.yaml`
- fallback manifest: `config/validation/qdesn_exal_kernel_screen_manifest_core_serial.yaml`

## What Worked

The original redesign harness itself was good:

- the fresh 6-root micro-pilot selection is still the right test bed
- `X0_anchor_baseline` completed cleanly with `6/6` root success
- the profile families were directionally correct:
  - shared exAL core controls
  - rhs_ns-specific residual probes
  - one modest chain confirmation profile

The current failure anatomy also gives a clear design target rather than random noise:

- phase-01 fail-cluster mix:
  - `half_chain_drift = 9/19`
  - `geweke_drift = 4/19`
  - `low_ess = 4/19`
  - `high_acf = 2/19`
- `16/19` FAIL rows are `exal`
- inside the `exal` FAIL set, the split is balanced:
  - `exal + rhs_ns = 8`
  - `exal + ridge = 8`

That means the first overnight screen should focus on the shared exAL core, not rhs_ns alone.

## What Did Not Work

The weak point was orchestration, not the fits.

- the old screen runner delegated the whole profile ladder to one `phase35` process
- logging was too quiet to diagnose stalls in real time
- there was no per-profile checkpoint, no per-profile timeout, and no resume at the profile level
- the stuck run halted after the first root of `X1`, even though that root's MCMC fit completed successfully
- the partial root stayed at `root_status = RUNNING` and never wrote a completed method summary, so the issue was post-fit bookkeeping / campaign aggregation, not a sampler crash

## Failure Patterns That Shape The New Grid

The fresh anchor run gives a sharper picture of which parameters are actually failing:

- `exal + rhs_ns` severe root `dlm_ar1V @ tau=0.95`:
  - `gamma ESS = 3.28`, `gamma Geweke = 5.49`, `gamma half_drift = 1.66`
  - `sigma ESS = 13.55`, `sigma Geweke = 3.74`, `sigma half_drift = 1.39`
- `exal + ridge` severe root `dlm_constV_bigW @ tau=0.05`:
  - mostly `gamma` low-ESS/high-ACF
- `exal + rhs_ns` severe root `dlm_constV_smallW @ tau=0.95`:
  - again dominated by `gamma`
- `exal + ridge` severe root `dlm_constV_smallW @ tau=0.95`:
  - `gamma` Geweke plus `sigma` half-drift
- `al + rhs_ns` sentinel `dlm_constV_bigW @ tau=0.95`:
  - not a core `gamma/sigma` failure
  - mostly `tau` drift / Geweke

So the redesigned screen should do two things:

1. separate shared exAL `gamma` stabilization from shared exAL `sigma` stabilization
2. keep rhs_ns residual probes as a second batch, because the `al + rhs_ns` sentinel still needs tau-side attention

## New Runner Design

The new `scripts/run_qdesn_exal_kernel_screen.R` replaces the fragile one-shot orchestration with:

- sequential profile execution
- one child campaign process per profile
- hard per-profile wall-clock timeout via `timeout`
- per-profile log file and exact command file
- automatic reconciliation pass after each profile
- resume of already completed profiles
- cumulative status table after each profile
- batch-aware stop rules
- no dependency on the old `phase35` monolith for execution control

New healthcheck helper:

- `scripts/healthcheck_qdesn_exal_kernel_screen.R`

## New Experiment Ladder

### Batch `B0_anchor_core`

This is the main overnight information-gain batch and should run first.

- `X0_anchor_baseline`
- `X1_core_pass1_soft`
- `X10_core_gamma_focus_pass1`
- `X11_core_sigma_focus_pass1`
- `X3_core_pass1_sharp`
- `X2_core_pass2_soft`
- `X4_core_pass2_sharp`
- `X9_moderate_chain_core1`

Why this is better than the earlier plan:

- keeps the original good profiles
- adds separate gamma-focused and sigma-focused probes
- orders lower-cost core profiles before higher-cost two-pass and chain-extension profiles

### Batch `B1_rhsns_residual`

This stays broad enough to answer the rhs_ns residual question without rebuilding the whole validation ladder.

- `X5_rhsns_freeze60_core1`
- `X6_rhsns_freeze80_core1`
- `X7_rhsns_multistart3_core1`
- `X8_rhsns_freeze60_multistart3`

## Safety / Robustness Rules

These are now encoded in the manifest / runner:

- `campaign_workers = 1`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 45`
- `timeout_kill_after_seconds = 30`
- `resume_completed_profiles = true`
- `create_plots = false`
- `stop_on_anchor_operational_failure = true`
- stop after `2` timed-out profiles
- stop after `3` incomplete/error profiles

The important operational change is this:

- one bad profile should no longer cost the whole night
- a hard hang can no longer sit there until morning

## Recommended Relaunch Sequence

### 1. Preserve and stop the old stuck run

```bash
pkill -f 'exal-kernel-screen-overnight-20260329__git-412b379|run_qdesn_mcmc_validation_campaign.R.*exal-kernel-screen-overnight-20260329__git-412b379'
pgrep -af 'exal-kernel-screen-overnight-20260329__git-412b379|run_qdesn_mcmc_validation_campaign.R.*exal-kernel-screen-overnight-20260329__git-412b379'
```

Expected:

- no matching processes

### 2. Prepare the new run

```bash
Rscript scripts/run_qdesn_exal_kernel_screen.R \
  --manifest config/validation/qdesn_exal_kernel_screen_manifest.yaml \
  --run-tag exal-kernel-screen-overnight-20260330b__git-412b379 \
  --prepare-only
```

Verify:

- `summary/screen_plan.md`
- `tables/screen_profiles.csv`
- `tables/screen_batches.csv`

### 3. Launch detached

```bash
mkdir -p reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330b__git-412b379

setsid bash -lc '
  stdbuf -oL -eL Rscript scripts/run_qdesn_exal_kernel_screen.R \
    --manifest config/validation/qdesn_exal_kernel_screen_manifest.yaml \
    --run-tag exal-kernel-screen-overnight-20260330b__git-412b379 \
    --execute \
    > /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330b__git-412b379/launcher.log 2>&1
' </dev/null >/dev/null 2>&1 & echo $!
```

## Before Leaving It Overnight

### Check A: the top-level runner is alive

```bash
pgrep -af 'run_qdesn_exal_kernel_screen.R.*exal-kernel-screen-overnight-20260330b__git-412b379'
```

### Check B: the new runner state exists

```bash
cat reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330b__git-412b379/status/runner_state.json
```

### Check C: anchor profile command and log exist

```bash
ls reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330b__git-412b379/logs/X0_anchor_baseline.cmd.sh
tail -n 40 reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330b__git-412b379/logs/X0_anchor_baseline.log
```

### Check D: healthcheck is readable

```bash
Rscript scripts/healthcheck_qdesn_exal_kernel_screen.R \
  --run-tag exal-kernel-screen-overnight-20260330b__git-412b379
```

## Tomorrow Morning Readout

Open these first:

1. `summary/screen_results.md`
2. `tables/profile_execution_status.csv`
3. `tables/profile_rank_summary.csv`
4. `tables/phase35_micro_pilot_summary.csv`

If a profile timed out or reconciled, inspect:

1. `logs/<profile>.log`
2. `logs/<profile>__reconcile.log`

## When To Use The Fallback Manifest Instead

Use `config/validation/qdesn_exal_kernel_screen_manifest_core_serial.yaml` only if:

- you want the safest possible reduced scope
- or the comprehensive batch still shows runner-level instability

That fallback keeps only the anchor and shared exAL core batch.
