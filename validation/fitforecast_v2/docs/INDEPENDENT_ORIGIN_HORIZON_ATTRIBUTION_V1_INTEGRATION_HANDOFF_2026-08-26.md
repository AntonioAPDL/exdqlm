# Independent Origin-Horizon Attribution V1 Integration Handoff

Date: 2026-08-26

Final lane status: `READY_FOR_INTEGRATION`.

## Lane identity

- Scientific lane: independent single-quantile Q-DESN/DQLM validation only.
- Transcript:
  `/home/jaguir26/.codex/sessions/2026/05/15/rollout-2026-05-15T18-06-50-019e2dad-9160-7421-a3ae-4c5b3b1410ca.jsonl`.
- Worktree:
  `/data/jaguir26/local/src/exdqlm__wt__independent_origin_horizon_attribution_v1_1p0p0`.
- Branch: `validation/independent-origin-horizon-attribution-v1-1.0.0`.
- Upstream: `origin/validation/independent-origin-horizon-attribution-v1-1.0.0`.
- Implementation closeout commit:
  `dd202b5de684bb0b15302401db239839e2aafbf2`.
- Compact audit freeze commit:
  `242a325c53c3c2340c71c109133713d583ad9ca4`.
- The final branch tip is the commit containing this handoff and must be read
  from the upstream branch after fetch.

## Base and merge relationship

At the final pre-handoff fetch, the remote shared-validation branch was
`origin/validation/shared-fitforecast-v2-1.0.0` at
`e18ed1160a6a576d2c9df452f0b77491459dba4b`. Before adding this handoff, the task
branch was 0 commits behind and 7 commits ahead of that reference. Its unique
commits, in order, were:

1. `4243487` Add Q-DESN interval dispersion diagnostic campaign.
2. `db5cb1d` Correct dispersion control replay identities.
3. `4ce4e03` Wire dispersion diagnostics through real pipeline.
4. `5885f6f` Add independent origin-horizon interval attribution.
5. `57014e9` Reuse verified origin-horizon pilot evidence.
6. `dd202b5` Close out origin-horizon attribution diagnostics.
7. `242a325` Freeze origin-horizon diagnostic audit packet.

There is an authority discrepancy that the integration coordinator must resolve
without resetting history: the earlier 2026-08-13 coordinator handoff cited
`f7d57b17997bea461faf6f5bfc6213c33fa2fd1e` as shared authority, but the current
remote shared branch resolves to `e18ed11`. Commit `f7d57b1` remains available on
`origin/integration/qdesn-tierb-cellwise-mcmc-v1-20260813`. The scientific lane
did not merge, reset, or move either reference. The coordinator should first
establish the intended latest shared authority, preserve both histories, and
then explicitly merge this task branch.

## Run closeout

| Stage | Planned | Successful | Failed | Remaining |
|---|---:|---:|---:|---:|
| Pilot | 6 | 6 | 0 | 0 |
| Full plan, including reused pilot jobs | 21 | 21 | 0 | 0 |
| Newly executed full-phase jobs | 15 | 15 | 0 | 0 |
| Unique scientific jobs | 21 | 21 | 0 | 0 |

Full run id:
`independent_origin_horizon_attribution_v1_full_20260826_021943`.

Full state root:
`/data/jaguir26/local/src/exdqlm__wt__independent_origin_horizon_attribution_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/independent_origin_horizon_attribution_v1_full_20260826_021943`.

Full result root:
`/data/jaguir26/local/src/exdqlm__wt__independent_origin_horizon_attribution_v1_1p0p0/results/qdesn_mcmc_validation/qdesn_500obs_origin_horizon_attribution_v1/independent_origin_horizon_attribution_v1_full_20260826_021943`.

Final decision:
`ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED`.

The authoritative 1,000-target metric and posterior-predictive recursion were
not changed. The balanced 990-target rectangle is diagnostic sensitivity only.
This campaign authorizes neither article metric replacement nor automatic
hyperparameter launch.

## Scientific conclusion

- All seven cells are dominated by coherent posterior dependence across origins
  and leads. Origin covariance accounts for 93.1% to 96.1% of aggregate
  forecast-MAE variance.
- Late/early MAE ratios are 0.970 to 1.087. Long-horizon escalation is not the
  main cause.
- Top-20% origin loss shares are 0.249 to 0.327. No small temporal block is the
  main cause.
- Removing the truncated final origin changes mean MAE by at most 1.21% and
  interval width by at most 1.04%.
- The strongest RHS-scale median Spearman associations have absolute magnitude
  0.018 to 0.077. No cell satisfies the predeclared `tau0` causal gate.
- Cells `073` and `075`, the Gaussian lower-tail AL-RHS and exAL-RHS cases, are
  location/design-bias dominant. Four cells are posterior-dispersion dominant;
  cell `082` is mixed.
- The proper next scientific action is case-specific location/design diagnosis
  for `073` and `075`, and common-mode intercept/scale/latent propagation audit
  for the other cells. Smaller `tau0` must not be used merely to narrow bands.

## Evidence and hashes

Portable tracked audit packet:
`validation/fitforecast_v2/audits/independent_origin_horizon_attribution_v1_20260826`.

| Evidence | SHA-256 or result |
|---|---|
| Runtime decision manifest | `eba0858a57215d81923475d9bb2f616ea959c6f7e66202c17478677066acb3d8` |
| Runtime closeout-verification JSON | `2f4b3438cd99b455220f27030f740083b3e568163d97a06d6b7969b2c02bc3b4` |
| Plan-verification JSON | `c79fb6c535eb9923493731ded1b993221c0a0728cbb4a7b26dbe769369c10c8b` |
| Runtime core-reassignment ledger | `99b59b41b627ae566615991f766a09486fc11e4a883759cba0435f663f92929e` |
| Portable artifact manifest | `41c61692201bab3c9150f82f0610f2b0470c0879e1f8f5c2c10de599fd06b652` |
| Portable README | `65cea318d0413d4a8d867e082e0c67e0e1e592767e2cee4cc306d4d09481da49` |
| Plan verification | 15/15 PASS |
| Closeout verification | 16/16 PASS |
| Portable packet verification | 9/9 PASS |

The compact packet freezes 19 scientific assets totaling 769,859 bytes. Its
artifact manifest gives the exact path, role, size, and hash for each member.

## Storage and runtime state

- Compact scientific job artifacts: 778,321,080 bytes across 21 jobs.
- Maximum compact job: 38,189,481 bytes, below the 100 MiB gate.
- Retained `.rds`, `.rda`, or `.RData` files: 0.
- Active task processes or tmux sessions: 0 at closeout.
- Pilot result root: approximately 210 MiB and protected because its six jobs
  are hash-reused constituents of the full closeout.
- Full new-result root: approximately 536 MiB.
- Runtime `reports/` and `results/` paths remain ignored and must not be merged
  as Git payloads. The portable audit packet is the durable compact evidence.

## Operational corrections

The launch exposed a reused-row CPU-indexing bug. Three source-083 process trees
were moved live from duplicate cores 35--37 to free cores 41--43 without restart.
The runtime ledger and compact CPU audit preserve that fact. Materialization now
allocates one unique core per newly executed job and verifies effective cores.

Health reporting now uses 5,000 burn-in plus 20,000 retained iterations, for a
25,000-iteration target, and falls back to the live Q-DESN log. The final health
packet reports 21/21 chains at 25,000/25,000.

The pooled summarizer was changed from repeated full-table scans to replay-block
grouping. The optimized 3,948-row summary was compared with the original output;
the maximum absolute difference across every numeric field was exactly zero.
The closeout verifier preserves its first verified timestamp, so repeated
verification leaves its JSON hash unchanged; this was confirmed by two
consecutive PASS runs with hash `2f4b3438...bc3b4`.

## Verification performed

Environment: R 4.6.0.

The following focused `testthat` files passed:

- `test-independent-origin-horizon-attribution-v1.R`
- `test-independent-metric-intervals-v1.R`
- `test-independent-metric-interval-coupling-audit-v1.R`
- `test-independent-interval-dispersion-diagnostic-v1.R`
- `test-storage-policy.R`

Additional checks passed:

- Modified R scripts and tests parsed successfully.
- `git diff --check` passed.
- Plan verifier passed 15/15.
- Runtime closeout verifier passed 16/16.
- Portable audit verifier passed 9/9.
- Five diagnostic PDFs have valid PDF headers and one page each.
- All declared closeout and audit-member hashes match.

## Article contract

Article-safe files authorized for publication: none.

No performance metric changed, so the Article-v2 repository, article tables,
figures, prose, GitHub snapshot, and direct Overleaf remote must remain unchanged
for this campaign. The integration coordinator should merge only the validation
implementation, documentation, tests, and compact diagnostic audit packet.

## Exact changed paths

Relative to the fetched shared-validation base, this branch changes the
following paths, plus this handoff file:

```text
R/exal_mcmc_fit.R
R/qdesn_validation_interval_dispersion.R
R/qdesn_validation_metric_intervals.R
R/qdesn_validation_origin_horizon_attribution.R
R/qdesn_vb.R
config/validation/independent_interval_dispersion_diagnostic_v1/sentinel_sources.csv
config/validation/independent_origin_horizon_attribution_v1/sentinel_sources.csv
scripts/pipeline_real_main.R
scripts/pipeline_sim_main.R
tests/testthat/test-qdesn-forecast-recursion-diagnostic.R
validation/fitforecast_v2/R/independent_interval_dispersion_diagnostic_v1.R
validation/fitforecast_v2/R/independent_origin_horizon_attribution_v1.R
validation/fitforecast_v2/R/telemetry.R
validation/fitforecast_v2/audits/independent_origin_horizon_attribution_v1_20260826/*
validation/fitforecast_v2/docs/INDEPENDENT_ORIGIN_HORIZON_ATTRIBUTION_V1_INTEGRATION_HANDOFF_2026-08-26.md
validation/fitforecast_v2/docs/INDEPENDENT_ORIGIN_HORIZON_ATTRIBUTION_V1_PLAN_2026-08-26.md
validation/fitforecast_v2/docs/INDEPENDENT_QDESN_METRIC_INTERVAL_DISPERSION_DIAGNOSTIC_V1_PLAN_2026-08-25.md
validation/fitforecast_v2/scripts/closeout_independent_interval_dispersion_diagnostic_v1.R
validation/fitforecast_v2/scripts/closeout_independent_origin_horizon_attribution_v1.R
validation/fitforecast_v2/scripts/freeze_independent_origin_horizon_attribution_v1_audit.R
validation/fitforecast_v2/scripts/healthcheck_independent_metric_intervals_v1.R
validation/fitforecast_v2/scripts/materialize_independent_interval_dispersion_diagnostic_v1.R
validation/fitforecast_v2/scripts/materialize_independent_origin_horizon_attribution_v1.R
validation/fitforecast_v2/scripts/orchestrate_independent_metric_intervals_v1.R
validation/fitforecast_v2/scripts/run_independent_interval_dispersion_diagnostic_v1_pipeline.sh
validation/fitforecast_v2/scripts/run_independent_metric_intervals_v1_job.R
validation/fitforecast_v2/scripts/run_independent_origin_horizon_attribution_v1_pipeline.sh
validation/fitforecast_v2/scripts/verify_independent_interval_dispersion_diagnostic_v1_plan.R
validation/fitforecast_v2/scripts/verify_independent_origin_horizon_attribution_v1_audit.R
validation/fitforecast_v2/scripts/verify_independent_origin_horizon_attribution_v1_closeout.R
validation/fitforecast_v2/scripts/verify_independent_origin_horizon_attribution_v1_plan.R
validation/fitforecast_v2/tests/testthat/test-independent-interval-dispersion-diagnostic-v1.R
validation/fitforecast_v2/tests/testthat/test-independent-origin-horizon-attribution-v1.R
```

The exact 22-file contents of the audit directory, including 19 hashed evidence
members and its three packet-control files, are enumerated by
`artifact_manifest.csv` and the Git tree.

## Coordinator merge procedure

1. Fetch all exdqlm remotes and resolve the `e18ed11` versus `f7d57b1` shared
   authority discrepancy without force-push or history loss.
2. Verify this task branch is clean and exactly synchronized with its upstream.
3. Merge the complete task branch through an explicit merge commit into the
   chosen latest shared-validation authority. Do not cherry-pick only the final
   two commits; the seven pre-handoff commits form one dependent scientific lane.
4. Run the five focused test files and the portable audit verifier.
5. Preserve the task branch and runtime roots until integration verification is
   complete.
6. Do not update Article-v2 or Overleaf for this campaign.

Final status: `READY_FOR_INTEGRATION`.
