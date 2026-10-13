# Independent Q-DESN Readout/Memory v13 Closeout

## Scientific Decision

`NO_AVERAGE_PRIMARY_FORECAST_GAIN_RETAIN_EXISTING_ARTICLE_AUTHORITY`

The approved Gaussian-mixture AL-RHS p=0.05 screening tranche completed
42/42 new logical jobs without an implementation failure. All launched work
has finished. The 72 conditional confirmation/fresh-DGP jobs are declined
without launch. They are neither failed jobs nor a remaining compute backlog.
The original review JSON remains unchanged; its `next_stage` field describes
the conditional pipeline, not authorization to continue a failed primary
contrast. A separate closeout and stop marker freeze the reviewed decision.

This closes one mechanism screen, not the entire independent validation study
or its unresolved accuracy/uncertainty objective. No article table, figure,
prose, model winner or authoritative score is replaced. Future work requires
a new user-approved design and a new dedicated branch/run.

## Completion and Verification

| Stage | Complete | Failed | Active | Launched remaining |
|---|---:|---:|---:|---:|
| Real-data technical smoke | 2/2 | 0 | 0 | 0 |
| Candidate/prefix-specific initialization | 20/20 | 0 | 0 | 0 |
| Direct quantile MCMC screening | 20/20 | 0 | 0 | 0 |
| Total launched | 42/42 | 0 | 0 | 0 |
| Conditional internal confirmation | Not launched: 24 | - | 0 | Not a backlog |
| Conditional fresh confirmation | Not launched: 48 | - | 0 | Not a backlog |

Eight matched static-Q-DESN/DQLM controls were reused after hash/contract
verification. Each Q-DESN initialization job contains normal RHS VB then
quantile VB; logical jobs must not be confused with inference-call counts.
New selection chains each use 1,500 burn-in plus 5,000 retained draws,
with 300 selected outer draws and 128 inner forecast paths.

- Source/runtime: R 4.6.0, pinned CRAN exdqlm 1.1.2 and frozen private study
  helpers. Gamma is fixed to zero; this is not an exAL M0 mixing experiment.
- Campaign verification: 51 enumerated manifests with 968 rows, plus the
  read-only imported-control closure; all verified before closeout.
- Independent reconstruction: all 28 primary surfaces, finite draw scores
  and means/type-8 95% endpoints, maximum discrepancy 5.33e-15 (tolerance 1e-6).
- Causal forecast checks: 192/192 first-step guards pass.
- Numerical diagnostics: zero coefficient-precision rescues in the 24
  Q-DESN selection/control fits; diagnostic flags are not exclusion gates.
- Focused v13 tests: 55 checks passed. Closeout validation adds 19 checks
  for incomplete work, failed audits, local-gain labels and publication scope.
- Completion timestamp: 2026-10-13T06:57:35Z. Host-level process verification
  is rerun during closeout. Scheduler ownership is protected with `flock`.

The analysis is internal rolling-origin validation: F1/F2 each have fold A
(fit 7001:8000, score 8001:8240) and B (fit 7001:8300, score 8301:8540).
Each uses eight origins, stride 30, leads 1:30 and 240 scored pairs.
Alternate origin phases +10/+20 are forecast companions, not new fitted
models. The later 9001:10000 block is not used to rank this tranche.
Teacher forcing applies between origins and recursion within each origin.
Static Q-DESN coefficients stay fixed between origins; DQLM latent states
are updated using observations available at each origin.

## Results and Retained Gains

The values below average four matched internal-cell means. Widths are
descriptive averages of native 95% intervals, not pooled posterior intervals
across independent DGP trajectories or estimates of between-DGP uncertainty.

| Arm | Fit RMSE | Forecast MAE | Forecast check loss | MAE interval width |
|---|---:|---:|---:|---:|
| DQLM | 3.1590 | 3.2962 | 1.54384 | 0.4785 |
| Static Q-DESN | 4.0120 | 3.9006 | 1.52369 | 2.5239 |
| tau_half | 4.0282 | 3.9251 | 1.52546 | 2.4744 |
| slab_quarter | 4.1338 | 4.2491 | 1.52932 | 2.7339 |
| joint_shrink | 4.1211 | 4.2570 | 1.52985 | 2.8302 |
| memory040 | 4.2438 | 4.2305 | 1.56109 | 2.0861 |
| memory099 | 6.4090 | 5.0644 | 1.63177 | 1.5745 |

No new arm improves average forecast MAE or the declared primary observed
forecast check loss over static. `tau_half` is the best new candidate, not
the overall winner. This is not a rejection based on poor MCMC mixing.

All 20 strict metric-cell gains over static, including nine forecast gains,
remain in the unrounded ledger without a minimum effect threshold. In F1 B,
memory040 improves MAE by 21.880%, check loss by 3.584%, and MAE interval
width by 54.453%; its forecast gains persist under alternate origin phases.
It worsens MAE in the other three primary cells. tau_half improves MAE in
both B cells (2.993% and 0.574%) but worsens both A cells. A different winner
for each realized DGP seed/window is not a family/quantile-specific calibration.
These internal-window gains cannot replace differently evaluated article rows.

## Accuracy and Uncertainty Are Not Interchangeable

memory099 narrows the native MAE score interval by 37.616%, but worsens
MAE by 29.838% and widens pointwise quantile bands by 63.718%. Slab-only
and joint shrinkage narrow pointwise bands while widening score intervals
and worsening oracle recovery. Halving tau0 is almost neutral on average.
None of these contrasts jointly resolves the forecast/uncertainty problem.

Q-DESN shares each coefficient draw across forecast rows; the current DQLM
artifact uses latent-marginal/product coupling. Their aggregate score widths
are not equivalent joint-functional precision estimates. Native intervals
are preserved: no draw shuffling, tail truncation or silent estimand change.
Mean draw score and score of mean path remain separate diagnostics.
The forecast quantity is an inner mean of conditional location paths,
not a posterior predictive mixture quantile or an observation interval.

Static Q-DESN already has a 36.09% average MAE gap relative to DQLM at lead
one. The static intercept's marginal variance is only about 5% of average
pointwise location variance; covariance terms are retained. These findings
do not justify treating recursion alone or an unshrunk intercept as the
established dominant cause. Nor does one tested 80-step memory regime rule
out all other alpha/rho combinations.

## Evidence, Storage and Reproduction

Frozen scientific source HEAD:
`5abb3db6a5b8c0559daf5ab125a654143f398ffa`.

Worktree:
`/data/jaguir26/local/src/Article-Q-DESN/.worktrees/ind_qdesn_readout_memory_v13_20261013`.

Dedicated branch:
`validation/independent-qdesn-readout-memory-v13-20261013`.

Run:
`validation/fitforecast_v2/local_trackers/independent_qdesn_readout_memory_v13_20261013__git-5abb3db6`.

Independent completion audit:
`validation/fitforecast_v2/local_trackers/health_v13_completion_20261013`.

Compact tracked closure:
`validation/fitforecast_v2/audits/independent_qdesn_readout_memory_v13_20261013`.

The compact closure contains unrounded score/gain/covariance/origin/lead
summaries, environment and test records, the reviewed decision, and a portable
artifact manifest. Runtime manifest indexes retain absolute evidence locations
as server-only verification aids. Raw draws, source trajectories, review PDFs,
logs, compiled cache and R library remain ignored, not Git or Overleaf assets.
The pre-closeout campaign is 98.61 MiB with zero fitted RDS/RDA/RData payloads.
Imported controls, their parent run and the pinned library remain protected;
no cleanup is performed by this closeout.

```bash
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
R=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript
CLI="$REPO/validation/fitforecast_v2/scripts/close_independent_qdesn_readout_memory_v13.R"
OUTPUT="$REPO/validation/fitforecast_v2/audits/independent_qdesn_readout_memory_v13_20261013"
# Creation is one-shot, before the compact record is committed:
flock -n "$RUN/scheduler.lock" "$R" "$CLI" create "$REPO" "$RUN" "$AUDIT" "$OUTPUT"
# Verification is read-only and may be repeated after integration:
"$R" "$CLI" verify "$REPO" "$RUN" "$OUTPUT"
# Rebuild the independent score audit into a new ignored directory:
"$R" "$REPO/validation/fitforecast_v2/scripts/audit_independent_qdesn_readout_memory_v13_completed.R" \
  "$REPO" "$RUN" "$NEW_AUDIT_OUTPUT"
```

Do not rerun creation against the frozen record or remove its stop marker.
Keep original inference/scoring source hashes unchanged. The closeout tools
are additive and do not rewrite the original review JSON or posterior output.

## Integration Scope

Only the integration coordinator merges the dedicated branch into the latest
shared-validation authority. The branch carries pending IND predecessor
history in addition to v13. The handoff inventories every unique commit and
changed file, including inherited package-helper changes; it is not a claim
that the complete branch delta consists only of this closeout.

Article-safe files to publish from this campaign: **none**.
Do not merge this scientific branch directly into Article-v2, overwrite
existing article tables/figures, or publish runtime metadata to Overleaf.
Review inherited package changes and run appropriate package/shared validation
tests in an isolated integration worktree before advancing shared authority.
The final frozen handoff, created after commit/push verification, records its
full metadata HEAD separately from the scientific source HEAD above.

The next scientific direction is intentionally not implemented or authorized
here. The later-prefix sensitivity pilot is a proposal to discuss after this
handoff, not a failed primary gate being retroactively changed into a success.
