# IND Q-DESN paired forecast confirmation v8

## Decision and relationship to previous work

The v7 screen completed 12/12 scientific jobs and 2/2 cost checks with zero
failures. All 741 frozen manifest entries passed a fresh read-only audit.
Two case-specific configurations improve internal forecast MAE, but neither
closes the remaining DQLM-class comparator gap. No article promotion follows.

| Case | Best v6 MAE | Best v7 MAE | Improvement | Matched comparator |
| --- | ---: | ---: | ---: | ---: |
| Normal AL p=0.05 | 4.2776758381 | 4.1068650128 | 3.9931% | DQLM 2.0502528769 |
| Normal exAL p=0.25 | 6.4954551826 | 3.2401952326 | 50.1160% | exDQLM 1.7053924720 |

The immediate question is whether these gains persist with a modestly larger
posterior forecast sample and paired Monte Carlo seeds. This is not another
architecture screen, an all-family rerun, or evidence that VB predicts MCMC
ranking. Fourfold posterior draw scaling increases cost; it does not guarantee
accurate 95% interval tails or unbiased out-of-sample performance.

Continue on a dedicated IND branch from the immutable v7 task commit
e39c46e2e6d3c547c0f49d78b48eaa596f431ea2, because this scientific continuation
depends on the not-yet-integrated v5-v7 implementation. Do not merge or modify
shared validation, integration, Article-v2 main, or Overleaf. Only use command-
line Git to commit/push the new task branch. Leave all old worktrees unchanged.

The old v2 launcher remains held with no live model workers. Its 168 unstarted
MCMC jobs are not v8 work and must not be resumed. Record this disposition
in the new run metadata; do not signal the old processes, remove old output,
or rewrite their statuses as a side effect of this campaign.

## Case-specific configurations and immutable controls

Select independently within each case from the frozen v7 comparison.csv:
the minimum-MAE new_v7 row and the minimum-MAE cached_v6 row. Full source
configs, candidate identities, initializers and hashes remain authoritative.
No configuration is reconstructed from rounded prose and no normal-VB
screening is performed.

| Finalist | Design | m | alpha | rho | Input gain | Model tau0 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| AL p=0.05 | D4, n=20;20;20;20 | 120 | 0.745878723354877 | 0.760424185339073 | 0.3 | 0.998613997947909 |
| exAL p=0.25 | D2, n=40;20 | 240 | 0.471893317068923 | 0.986627020238116 | 1 | 0.998613997947909 |

AL source design: iqcb4_normal_al_p005_3ed9396c0484.
exAL source design: iqcb4_normal_exal_p025_f52df3dcb74e.
The two best v6 controls retain their own case-specific designs and priors.
The 400-state alternative is not re-run or universally rejected; its poor
training recovery does not prove that all wider networks are unsuitable.

## Scientific invariants and estimands

- Same Normal source trajectories and oracle target paths; p=0.05 AL and
  p=0.25 exAL only. Frozen source SHA-256 checks remain mandatory.
- Fit 8501:8750 and develop 8751:9000; 45 origins 8750:8970 at stride 5;
  leads 1-30; 1350 scored pairs. Update observed history between origins;
  recursively generate unknown future inputs within an origin. No refit
  or future-observation teacher forcing within that origin's horizon.
- Preprocessing learned only on fitting observations; identity Q at every
  transition; readout intercept plus all reservoir layers, no direct lags.
- Fixed DESN, tau0, s2=1, unshrunk intercept, full-coupled quantile beta,
  frozen original normal initializer and fresh quantile RHS state.
- Same quantile-VB budget: cap 750, tolerance 1e-4, xi sample budget 400.
  Restore the initializer's fit RNG before each fit. Forecast seed is a
  separate stream. Every job verifies fitted means, covariance, expected
  precision, scale/shape and analytic point-fit scores against its source.
- Runtime remains R 4.6.0 and validation-source exdqlm 1.1.1 via pkgload,
  not an unmodified CRAN binary. The native library is copied unchanged
  from the frozen source runtime and hashed. Package defaults are not edited.

Primary score: oracle MAE of the posterior-mean conditional-location quantile
path. Retain forecast RMSE and conditional-location check loss separately
from draw-wise metrics and pooled predictive quantile check loss. The reused
DQLM/exDQLM point check loss is compared only with the conditional channel,
never the pooled channel. Do not replace the primary criterion after seeing
results. Equal-weight means of three seed-specific point scores are not
relabeled as scores of one pooled point path or independent MCMC chains.

## Preflight and exactly budgeted jobs

Focused tests cover the new config contract, JSON round-trip, replay tolerance,
paired seeds, distinct estimands, tiny positive gains, failure draining,
health counts, and actual launcher execution under the server's Bash.
Six tiny synthetic AL/exAL smokes use two different forecast seeds and a
same-seed repeat to test invariant fitted states and reproducible scores.
Tiny synthetic data are engineering evidence and never enter ranking.

The main frozen plan contains exactly 20 jobs:

| Stage | Jobs | Budget and purpose |
| --- | ---: | --- |
| Cost checks | 4 | Actual four designs, full unchanged VB fit; two origins, H30, 4 outer draws, 32 inner paths |
| Original-seed replay | 4 | Actual four designs, original 16/128, all 45 origins and H30; scores agree within 1e-6 |
| Paired confirmation | 12 | Four configs x three seeds; 64 outer draws, 128 inner paths, all origins/H30 |

This deliberately expands the earlier two-replay sketch to four so both
controls as well as both finalists reproduce the existing worker/scoring
contract. It adds roughly one parallel replay phase, not a full study refit.
Cost fits use the full budget, because fitting takes only about 4-9 seconds
for the finalists and a truncated fit would weaken the state-invariance test.

Three seeds per case are frozen before launch: the original common case
seed plus offsets 100003 and 200003, identically assigned to challenger and
control. Data and reservoir seeds never change. Pairing seeds does not imply
that different fitted posterior distributions produce identical samples.

Four cost jobs run first. Project forecast/artifact time by
(45/2)*(64/4)*(128/32)=1440 and add measured full-fit time. Require twice the
projected time to fit a six-hour per-production-job cap. This is a conservative
engineering projection, not a runtime guarantee. Record measured results and
do not silently reduce the scientific budget or omit a control after failure.
Only after all four full replays pass may the 12 confirmation jobs start.

No costly serialized-posterior cache is added: forecast/artifact work was
98.58% of measured v7 runtime, and repeating a few-second fixed VB fit through
the tested worker is simpler than introducing a new posterior interchange.
No fitted-model binary files are written. Keep compact fitted moments,
covariance, traces, draw/path summaries, granular scores and provenance.

## Parallel execution, failure safety and reproducibility

Verify six idle host CPUs immediately before launching. Pin one CPU per
worker; set OpenMP, BLAS and other numerical threading to one. Use dynamic
slot refilling rather than fixed waves. Cost and replay phases use at most
four CPUs; the main phase uses six. Preserve other lanes and their CPU jobs.

The run has an exclusive flock, per-job timeout wrappers and exit-code
records. A worker failure stops new scheduling while active workers drain.
The launcher signals only its recorded child timeout PIDs on interruption.
Do not use pkill, killall, force-push, resets, or broad runtime cleanup.

Commit/push the dedicated task branch after tests/smokes and before freezing
the run. The environment binds HEAD, source/native/config/input hashes,
sessionInfo, compiler, BLAS/LAPACK and thread environment. Each worker validates
these before work. Successful status additionally hashes fit/replay contract
checks and timing, so resume does not accept a compute success with a failed
reproducibility check. Completed hash-valid jobs can be reused; append launcher
attempt exits and use the most recent per-job exit for health.

Write terminal COMPLETE before the final artifact manifest. Keep runtime
under ignored validation/fitforecast_v2/local_trackers. Do not modify a
worktree's source or HEAD while its frozen jobs are running. Launch detached
in tmux; verify the main phase really starts, not just that tmux exists.

## Closeout and evidence-dependent next stages

Automatic closeout writes confirmation_scores.csv, paired_seed_gains.csv,
repeated_seed_summary.csv, observed_strict_gain_ledger.csv and lead/origin
profiles. Cost and replay jobs are excluded from every scientific ranking.
Also write matched per-seed origin/lead gains and equal-weight repeated-seed
granular summaries; joins must not silently drop a missing origin or lead.
Record diagnostic grades and numerical fit checks without imposing a perfect
VB convergence or MCMC mixing gate. Numeric/data/hash contract failures remain
invalid evidence until repaired, distinct from nonideal diagnostic grades.

Keep every finite strict gain, however small. The 1e-6 replay tolerance is NOT
a promotion threshold. Preserve favorable seed-specific results even if the
equal-weight repeated-seed average reverses; disclose that distinction and
do not present a cherry-picked seed as a stable three-seed confirmation.
Only the matched repeated-seed comparison motivates the next case-specific
MCMC proposal; other finite gains remain in the candidate record.

If gains persist, prepare a small direct MCMC comparison for the two cases,
with explicit exact M0 for exAL where supported, frozen AL transition and
declared chain/estimator budgets. Do not require VB to close every comparator
gap before evaluating MCMC. MCMC budget/dispatch preflight and article-protocol
evaluation are a later evidence-dependent launch, not an automatically
scheduled expensive campaign in this implementation.

If rankings reverse or gaps persist, report exactly which seed, origin and
lead groups differ; then propose sparse case-specific design/dynamics/input
gain/tau refinements rather than another huge Cartesian screen. Historical
pre-M0 exAL failures and historical diagonal-beta failures are proposal
history, not reliable exclusion evidence under a corrected inference operator.

These are internal development results, not article MCMC replacements.
Adaptive block reuse and overlapping origins remain disclosed. Fresh DGP
replication after protocol freezing provides stronger unbiased confirmation.
No automatic article update, integration/main merge, Overleaf push, other-cell
expansion, baseline refit, or legacy artifact deletion is performed. The
coordinator alone promotes article-safe files through a frozen handoff.

## Reproduction commands

Use /data/jaguir26/local/opt/R/4.6.0/bin/Rscript --vanilla. From this worktree:

```bash
Rscript --vanilla validation/fitforecast_v2/scripts/test_independent_qdesn_paired_forecast_v8.R "$PWD" "$TEST_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/smoke_independent_qdesn_paired_forecast_v8.R "$PWD" "$SMOKE_ROOT"
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_paired_forecast_v8.R "$PWD" materialize "$RUN_ROOT" "$V7_RUN" "$TEST_ROOT/test_results.csv" "$SMOKE_ROOT/smoke_summary.csv"
REPO_ROOT="$PWD" RUN_ROOT="$RUN_ROOT" CPU_LIST="$VERIFIED_CPU_LIST" bash validation/fitforecast_v2/scripts/run_independent_qdesn_paired_forecast_v8.sh
Rscript --vanilla validation/fitforecast_v2/scripts/independent_qdesn_paired_forecast_v8.R "$PWD" health "$RUN_ROOT"
```

Run tags preserve their UTC/host-date identifiers; user-facing status reports
use America/Los_Angeles dates and times. None of the scientific follow-up
stages should be called complete while the main confirmation pool is active.
