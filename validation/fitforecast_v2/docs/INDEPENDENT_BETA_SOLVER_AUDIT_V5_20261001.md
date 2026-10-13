# Independent Q-DESN beta-solver audit v5

This campaign closes v4 as diagnostic evidence and compares the existing
full quantile-VB coefficient solve with its explicitly selected diagonal
approximation. It does not change package defaults or article authority.

## Audit and decision

The v4 screening worker explicitly selected diagonal precision for the
quantile-VB beta update. For precision P = X'WX + Lambda and natural vector
g, it uses g_j/P_jj rather than solving P m = g. This changes the coefficient
means, not just the storage of uncertainty. Correlated reservoir features
make that distinction consequential. Full Gaussian-block VB is already
available; v5 uses it without changing the package default or removing the
historical approximation.

At the last pre-closeout check, v4 had 287 successful broad jobs and one
active worker. The verified dispatcher and final worker were terminated
after preserving process identity and the original worker status. Completed
outputs and original statuses are retained. The separate closeout ledger
labels the intentional interruption, rather than silently turning it into a
scientific failure. Eighteen comparator and six smoke jobs also completed.
The old pipeline may record FAILED from its shell trap; this is an expected
operational consequence of cancellation, not an inference diagnosis.

The previous numerical probes establish a coefficient-update discrepancy;
they do not prove that fixing it resolves every forecast failure. No
screening result is promoted, no authoritative article table is changed,
and no claim is made that the CRAN 1.1.1 default or MCMC transition is broken.

## Frozen experiment

Select exactly two existing v4 reference-tau candidates by their recorded
identity, not by a newly optimized metric:

| Family | Likelihood | Quantile | Structure source | Maximum readout dimension |
| --- | --- | --- | --- | ---: |
| Normal | AL | 0.05 | corrected_v3_cell_winner | 100 |
| Normal | exAL | 0.25 | corrected_v3_cell_winner | 100 |

For each, run diagonal and full covariance using the exact same original
candidate, data file/hash, reservoir seed, initialization, tau0, RHS slab,
intercept treatment, leakage, spectral radius, memory, architecture,
preprocessing, inference budget, posterior seed, and forecast noise seed.
The frozen plan records the actual candidate IDs and source-config hashes.
The AL case uses D=2, n=(40,20), m=240 and a 61-column readout.
Its candidate ID is iqcb4_normal_al_p005_36b501b2c57e. The exAL case is
iqcb4_normal_exal_p025_4e36250372e6, D=1, n=20, m=30, a 21-column readout.
Both use model-scale tau0 = 0.00332871332649303; their original source-scale
transport and complete settings remain in the baseline configs.
The materializer rejects missing, ambiguous, unfinished or oversized cases.

The allowed scientific difference between each pair is solely the explicit
beta_covariance approximation. Full versus diagonal affects both means and
covariances; frozen-moment algebra tests isolate the mean-update mechanism.
All other configuration fields in the science contract must be identical.
Operational paths, job labels and diagnostic output requests may differ.

This is four jobs, not another broad search. Diagonal replays provide an
instrumented control and a 1e-6 reproducibility test against stored v4 scores.
No DQLM/exDQLM refit, new reservoir screen, tau tuning, or MCMC is scheduled.

## Evaluation and metrics

- Internal fit window: 8501:8750; development: 8751:9000.
- Origins: 8750:8970 every five observations; horizon 30, 1,350 pairs.
- Observed history is used between origins; horizons recurse within origin.
- Response transformations are fitted internally and inverted before scoring.
- Q matrices remain identity; readout contains intercept and all reservoir
  layers, without direct output-lag features.
- Original VB limit: 750 iterations; original tolerance and xi budget kept.
- Original screening summaries: 16 outer draws and 128 inner paths.
- Primary: oracle MAE of the mean conditional location path.
- Secondary: realized check loss of the pooled predictive quantile.
- Fit reporting keeps analytic coefficient-mean-path RMSE, sampled-mean-path
  RMSE and mean draw-level RMSE distinct. Scalar mean draw RMSE cannot
  reconstruct point-path RMSE.

Posterior-draw metric intervals and origin-block intervals describe different
uncertainties and stay separately labeled. Sixteen outer draws are for this
controlled screening comparison, not publication-quality tail certification.
The historical external block remains untouched; it is not a pristine test
set for the overall research history.

## Implementation and gates

1. Freeze v4 into an append-only closeout packet. Preserve original hashes
   and add final observed hashes for operational logs changed after the old
   manifest was written. Retain scientific artifacts; delete nothing.
2. Add optional solver selection and diagnostics to the existing worker.
   Default legacy behavior remains diagonal when the new field is absent.
3. Test coupled means, covariance and predictive quadratic forms against
   direct solutions with duplicate/correlated columns, unequal precisions,
   unshrunk intercept, nonuniform weights and p greater than n. Tolerance
   1e-6. Test score estimands and immutable scientific configuration.
4. Exercise the diagnostic hook with a tiny synthetic AL/exAL smoke before
   the four original-budget jobs. This smoke is not evidence of improvement.
5. Freeze source/config/environment manifests before launch. Verify them
   inside every worker. Reuse the compiled library; prohibit concurrent
   compilation in worker processes.
6. Run four parallel single-thread jobs with exclusive launcher lock and a
   two-hour per-job timeout. Keep exact exit codes, progress phases, logs,
   success/error status and per-artifact hashes. Resume only hash-valid
   completed jobs; never count an incomplete row as success.
7. On completion, compare pairs and the original diagonal control within
   1e-6. Verify reconstructed design and response hashes agree between arms.
   Record forecast/fit changes and uncertainty separately from convergence.
   A changed terminal latent state means its residual is a diagnostic, not
   a requirement that the final sequential VB state solve an exact fixed
   point. The full frozen-moment solver is tested independently.
8. Finalize artifact hashes after final worker logs and pipeline status are
   closed. Do not repeat the earlier telemetry-hash ordering problem.

## Outputs and retention

Per job: original forecast metric draws, point scores, origin/lead profiles,
origin-block intervals, fit quantile draws, fit-path summaries, coefficient
means/SDs/expected prior precisions, full compact covariance, ELBO and
gamma/sigma/RHS traces, frozen-moment solver diagnostics, and config/hash
provenance. Only CSV, compressed CSV, JSON and text are retained; no fitted
R model binaries. The small coefficient covariance supports later checks
without a model-object archive.

Campaign outputs include comparison.csv, paired_comparison.csv,
decision.json, launcher_exit_codes.csv, environment.json, source_hashes.csv,
materialization_hashes.csv and final_artifact_manifest.csv. Environment
records that this is the validation worktree's 1.1.1 source runtime, not an
unmodified CRAN installed binary. A package version alone is insufficient
to identify this experiment.

## Conditional next stage

If reproducibility or numerical checks fail, hold and diagnose. If full
fits improve scores, benchmark one wide identity-Q design before proposing
corrected replay. If no improvement occurs, inspect latent moments and RHS
feedback before changing architecture. No automated next-stage scheduling
is allowed. No perfect-mixing or arbitrary minimum-gain rule is introduced.
Do not use suspect diagonal rankings alone to discard specifications.

## Commands

Use R 4.6.0 and single-thread BLAS/OpenMP. From the v5 worktree:

```bash
Rscript --vanilla validation/fitforecast_v2/scripts/test_independent_qdesn_beta_solver_v5.R "$PWD" "$TEST_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/smoke_independent_qdesn_beta_solver_v5.R "$PWD" "$SMOKE_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_beta_solver_v5.R "$PWD" freeze "$CLOSEOUT" "$V4_RUN"
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_beta_solver_v5.R "$PWD" materialize "$RUN_ROOT" "$V4_RUN"
REPO_ROOT="$PWD" RUN_ROOT="$RUN_ROOT" CPU_LIST="48,49,50,51" bash validation/fitforecast_v2/scripts/run_independent_qdesn_beta_solver_v5.sh
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_beta_solver_v5.R "$PWD" audit "$RUN_ROOT"
```

Verify core availability before launch; the example does not reserve them.
Freeze requires preserved stop evidence. Runtime outputs live under ignored
validation/fitforecast_v2/local_trackers. Only dedicated IND task branches
may be committed or pushed. Shared validation, Article-v2, Overleaf and
integration branches remain coordinator-owned.

## Initial closeout evidence

The stopped v4 screen's final observed manifest contains 2,970 files, all
rehashed successfully after stopping. Manifest SHA-256:
28fcc1de71ff9f86ac613edf5200aa16586ebd2a539d68c48dab1548e3a2cf3e.
Evidence is in the v5 worktree under
validation/fitforecast_v2/local_trackers/beta_solver_v5_closeout_20261001.
Its closeout.json records 311 completed jobs (287 broad, 18 comparators,
6 smoke), one interrupted job, no queued cancellations and no prior
execution failures. The original artifacts and raw statuses were preserved.
