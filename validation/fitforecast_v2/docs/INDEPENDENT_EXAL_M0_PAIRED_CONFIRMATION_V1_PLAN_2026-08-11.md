# Independent exQ-DESN M0 paired confirmation v1

## Decision

The completed paired calibration campaign is closed. Only two candidates advance
to canonical full-budget MCMC confirmation. The confirmation is deliberately
small: six chains total, run as one process and one CPU thread per chain.

This stage does not update the article automatically. It produces a compact,
hash-addressed metric patch for manual scientific review after all six chains
finish.

## Frozen calibration evidence

- Source run tag:
  `ind-exal-m0-paired-rolling-repair-v1-calibration-20260811_overnight_v1`
- Calibration result: 84/84 successful jobs, 42/42 complete paired blocks,
  21 metric cells audited, 3 metric cells eligible, and no retained routine
  `.rds`, `.rda`, or `.RData` payloads.
- Tracked handoff:
  `validation/fitforecast_v2/promotions/independent_exal_m0_paired_rolling_repair_v1_closeout_20260811`
- Handoff manifest SHA-256:
  `b90b1ddee33eb76bdcb5fdfa6be79c6450b024a411ccb9ac956c9a31f959cfc0`
- Candidate-profile SHA-256:
  `8ac0708f4d22ee78fd6237e96f5e27a3b8ec06aa163e7d1945273df19839c51a`
- Metric-selection SHA-256:
  `ffc0868c865cd74ea79f9903e45d31a954d108147735119b2fafd7ebbc6506bf`
- Frozen article-metric baseline SHA-256:
  `874fdf3579ef986ede274672785de647a87e195fb9d2849fe33e5073d91287e0`

The paired eligibility rule required six complete anchor/finalist blocks,
negative mean and median paired deltas, at least four finalist wins, and no
minimum effect-size threshold. This selected two cells and excluded the other
five cells without spending full MCMC compute.

## Selected candidates

| Cell | Candidate | Frozen design | Calibration evidence |
|---|---|---|---|
| Normal, `p=0.05` | `ssv2_normal_t0p05_broad_06_368dcfeb88` | `D=3`, `n=18;17;17`, `m=120`, `alpha=0.0212437;0.0412437;0.0612437`, `rho=0.1;0.1;0.1`, `tau0=7.587648e-08` | Fit RMSE improved in 4/6 paired blocks; mean paired gain 11.72%. |
| Normal, `p=0.50` | `ssv2_normal_t0p50_adaptive_02_2c1ce72dbd` | `D=3`, `n=12;13;13`, `m=150`, `alpha=0.0005;0.001;0.021`, `rho=0.8710369` at every layer, `tau0=1.206018e-08` | Forecast MAE improved in 5/6 blocks (10.23% mean gain); forecast check loss improved in 4/6 blocks (0.73% mean gain). |

Each candidate uses one fixed reservoir realization across its three MCMC
chains. MCMC, RNG, and VB warm-start seeds are independent by chain. The two
candidates do not share a reservoir seed.

## Canonical source contract

- Source registry identity:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Scenario:
  `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`
- Source root:
  `/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources`
- Normal `p=0.05` series SHA-256:
  `e2bdae3052bff71e0f8bbce4c8b2228e4294363e7e0e2a6f097e3ac95051a1f3`
- Normal `p=0.50` series SHA-256:
  `4c5d84fe51a509703fa484e82a94a58407d1833e1a4f5a505e056170a6fcc2a2`

The effective training target window is source indices `8501:9000`. Forecasts
are scored over `9001:10000`, with maximum lead 30, origin stride 30, and no
model refit at each origin. The materializer verifies that each canonical source
exactly reproduces its frozen historical article window before it builds a new
candidate-specific lag/washout window.

## MCMC and execution contract

- Package: exdqlm 1.0.0.
- Branch: `validation/independent-exal-m0-structural-screen-v2-1.0.0`.
- exAL update: `M0_v_collapsed_support_logit`.
- Smoke: one chain per candidate, 4 burn-in and 4 retained iterations.
- Confirmation: three chains per candidate, 5,000 burn-in and 20,000 retained
  iterations, thin 1.
- Parallelism: at most six workers, one CPU thread per worker.
- MCMC progress cadence: every 50 iterations.
- Pipeline heartbeat and stale threshold: 1,800 seconds.
- Same-tag restart: matching successful jobs are skipped; missing or failed jobs
  are rerun. No reset, stash, or destructive rollback is used.

## Metric and promotion contract

Every chain exports all three article metrics:

1. `fit_qtrue_rmse`;
2. `forecast_qtrue_mae_H1000`;
3. `forecast_check_loss_H1000`.

A metric is promotion-ready only when all three chains finish successfully, all
three values are finite, rolling artifacts pass for forecast metrics, no binary
payload remains, and both the chain mean and chain median are strictly lower
than the frozen article value. There is no minimum gain threshold. Signoff and
mixing diagnostics remain visible but are not used as an additional
metric-exclusion rule.

The closeout writes `article_metric_patch_review.csv`; it does not edit an
article repository. Article promotion requires a separate manual review after
completion.

## Storage and failure policy

Routine draws, VB initialization objects, and forecast objects are not retained.
Each worker keeps scalar fit and rolling-origin metrics, compact paths, config,
status, progress, signoff, logs, and hashes. Any transient binary payload made
by a worker is recorded in a prune manifest and removed before job success is
declared. The runtime verifier and final storage audit require zero remaining
`.rds`, `.rda`, or `.RData` files.

Failures are explicit in `job_status.json`, `stage_status.csv`, worker logs, and
the runtime verification report. A nonzero worker result stops closeout. The
same run tag can then be relaunched to compute only unfinished or failed jobs.

## Reproducible commands

Materialize and statically verify:

```bash
R=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript
$R validation/fitforecast_v2/scripts/materialize_independent_exal_m0_paired_confirmation_v1.R \
  --repo-root "$PWD" \
  --output-root "$PWD/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_confirmation_v1_materialization"
$R validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_confirmation_v1.R \
  --repo-root "$PWD" \
  --materialization-root "$PWD/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_confirmation_v1_materialization" \
  --plan confirmation_plan.csv \
  --output /tmp/independent_exal_m0_paired_confirmation_v1_static.json
```

Run the foreground smoke:

```bash
bash validation/fitforecast_v2/scripts/run_independent_exal_m0_paired_confirmation_v1.sh \
  "$PWD" smoke <smoke-run-id> <smoke-run-tag>
```

Launch the full confirmation after the smoke passes and the implementation
commit is pushed:

```bash
PAIRED_CONFIRMATION_APPROVED=true WORKERS=6 \
  bash validation/fitforecast_v2/scripts/launch_independent_exal_m0_paired_confirmation_v1.sh \
  "$PWD" confirmation <confirmation-run-id> <confirmation-run-tag>
```

Health check:

```bash
R=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript
$R validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_structural_screen_v2.R \
  --repo-root "$PWD" --run-tag <confirmation-run-tag> \
  --plan <state-root>/materialization/confirmation_plan.csv \
  --stale-seconds 1800 --output <state-root>/manual_health.csv
```

## Implemented preflight evidence

- Implementation commit: `e0f61cb906a0d71316b437f42382cc7b2be300a8`.
- Implementation branch was clean and synchronized with its upstream before
  compute.
- R runtime: 4.6.0; package version: 1.0.0.
- Focused campaign suite: pass.
- Related M0, progress, source-window, horizon, no-leakage, storage, and
  rolling-lead-export tests: pass.
- Static smoke manifest: 2/2 jobs pass.
- Static confirmation manifest: 6/6 jobs pass.

Canonical smoke evidence:

- Run ID:
  `independent_exal_m0_paired_confirmation_v1_smoke_20260811_e0f61cb`
- Run tag:
  `ind-exal-m0-paired-confirm-v1-smoke-20260811__git-e0f61cb`
- State root:
  `reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_confirmation_v1_smoke_20260811_e0f61cb`
- Result: 2/2 successful jobs, 6/6 finite metric rows, 2/2 rolling artifact
  audits passed, and zero retained binary payloads.
- Median worker elapsed time: 50.62 seconds.
- Pipeline result: complete with exit code zero.

The 4+4 smoke estimates are implementation diagnostics only. They are not
eligible for scientific comparison or article promotion.

## Full confirmation launch

- Launch commit: `0f0634e40b5d1e320b61ad7af1464beb56546fb3`.
- Run ID:
  `independent_exal_m0_paired_confirmation_v1_full_20260811_0f0634e`
- Run tag:
  `ind-exal-m0-paired-confirm-v1-full-20260811__git-0f0634e`
- tmux session:
  `ffv2_ind_exal_m0_paired_confirm_v1_full_20260811`
- State root:
  `reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_confirmation_v1_full_20260811_0f0634e`
- Result root:
  `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2/ind-exal-m0-paired-confirm-v1-full-20260811__git-0f0634e`
- Workers: six, with one thread per chain.
- Startup CPU set: `21,22,23,24,32,33`.
- Startup health: 6/6 chains progressing, 0 complete, 0 failed.
- The pipeline will run runtime verification, storage audit, and the manual-gate
  closeout automatically after all workers succeed.

The article remains unchanged while this run is active. Only the completed
closeout under `<state-root>/closeout` may be considered for a later article
promotion.
