# IND Training-1000 Targeted V2: Verified Scheduler Recovery

## Decision and Scope

Resume the frozen experiment; do not redesign or repeat it. The latest audit
verified 172 successful jobs, 46 pending bridge jobs, no failed fits, no active
workers, and a dead scheduler whose RUNNING receipt was stale. There is empirical
forecast improvement worth confirming, and resources were not exhausted.

This amendment changes orchestration only. Model likelihoods, priors, DESN
designs, identity Q, seeds, source trajectories, windows, posterior budgets,
teacher forcing, recursion, scoring, nomination and promotion rules are unchanged.
No other scientific lane, package installation, Article-v2/main, shared branch,
integration branch, Overleaf, or legacy runtime artifact is modified.

The frozen scientific worker worktree remains:
`/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_training1000_targeted_v2_20261006`

Scientific HEAD: `c27fc70afd6c19366eff551d693f2bbe1d76bdbc`.
Run: `independent_qdesn_training1000_targeted_v2_20261006_060137__git-c27fc70a`.

The separate recovery worktree is:
`/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_training1000_recovery_v1_20261006`

Recovery branch:
`validation/independent-qdesn-training1000-recovery-v1-20261006`.
It starts from c27fc70, preserving the complete lane lineage rather than rebasing
the frozen run onto an independently advancing shared authority.

## Evidence and Root Cause

Audit packet within the frozen run:
`diagnostics/health_audit_20261006_192415`.
Its 180 manifests / 1,970 entries passed. All 860 metric summaries were independently
recomputed from location draws, with maximum discrepancy 7.283063e-14 (tolerance
1e-6). The audit includes a no-launch pending selector check: exactly 46 pending
bridge jobs and none of the 172 successes.

GNU du encountered an atomic status-JSON temporary file after its rename. Under
`set -euo pipefail`, the original `size=$(du ... | awk ...)` pipeline exited on
du's nonzero status, before drain/final-state handling. Existing workers continued
independently and eventually all finished. Fifteen successful workers were not
collected into the old exit journal. This is not a model, sampler, disk-space,
or RAM failure. Do not rerun or discard those verified outputs.

Source hashes include the old driver, so editing it in place would break worker
preflight. Therefore the repaired scheduler executes from the recovery worktree
while the scientific CLI, workers and configs remain pinned to the frozen one.
The recovery manifest records both source commits and hashes the driver and its
dependencies separately.

## Scientific Reasons to Continue

These are internal fold-B results, not final article scores:

| Case | Evidence | Forecast MAE | Interpretation |
| --- | --- | --- | --- |
| Gaussian AL p=.05 | All four N1000 MCMC nominees | 4.104 to 3.720 | 9.35% anchor improvement; still above DQLM 3.125 |
| Gaussian exAL p=.25 | All four N1000 MCMC nominees | 3.929 to 2.882 | 26.64% improvement; still above exDQLM 2.309 |
| Laplace AL p=.05 | Two of four N1000 MCMC nominees | 25.023 to 3.579 | Strong capacity signal, but incomplete comparison |
| Laplace exAL p=.05 | Complete fold-B VB nominees | 23.016 to 4.607 | Strong VB signal requiring its MCMC evidence |

Gaussian AL's MAE leader worsens check loss; another nominee improves check loss.
Preserve this tradeoff rather than inventing a row from unrelated best metrics.
Gaussian exAL improves both MAE and check loss against its anchor. Larger layers
help Laplace while smaller designs lead Gaussian. Tau multipliers differ between
VB and MCMC, so the existing bridge bypasses are important and must not be removed.
M0 is confirmed, although some gamma/sigma ESS remain modest. Diagnostic grades
are disclosed, not used to exclude finite strict metric improvements.

No new broad screening, global spec, intercept modification, uniform tau reduction,
training-size change, or estimator change is justified before finishing the
already-defined comparisons. The familiar final block remains non-pristine for
the research process; a later frozen fresh-DGP confirmation is still appropriate.

## Implemented Root Repairs

1. Disk telemetry is checked explicitly. Retry up to three times only when all
   errors identify disappearing atomic `*.json.tmp.<pid>` files under known
   study writer directories. Require a fresh successful scan and valid numeric
   disk/free-space aggregates. Other errors and exhausted retries stop dispatch
   and drain; no blanket `|| true`, silent stale-size reuse, or disabled strict mode.
2. EXIT/INT/TERM handling writes an explicit DRAINING/PAUSED receipt and waits for
   only the driver-owned timeout child PIDs. Successful outputs are preserved and
   accounted. No unrelated process is signaled. A normal no-gain closeout is not
   misclassified as missing future stages.
3. Effective health checks the scheduler PID's command identity, heartbeat age,
   and each RUNNING worker process. A stale RUNNING text file cannot imply progress.
4. Budget reconstruction uses each unique successful job's maximum of recorded
   elapsed time, actual CPU time, original collected wall duration, and any recovery
   receipt. It rounds conservatively and writes a separate immutable ledger. The
   old exit journal is preserved. Failed/unresolved statuses block unattended resume.
5. The original 400-worker-hour ceiling, 48-hour stage deadlines, existing job
   timeouts, 12-GiB worker RSS guard, 24-GiB reserve / dispatch-memory guard, 40-GiB
   run ceiling, and at least 20-GiB disk-free requirement remain. The bridge start
   is not reset. Later stage clocks derive from creation time of their frozen plan.
6. Preflight protects all initial successful status hashes, verifies source,
   package, data and plan hashes, and freezes the pending bridge queue. Resume
   starts at bridge, never replays the completed cost/A/B advancement.

## Verification and Launch Sequence

Pre-launch regression results: recovery 66 expectations, original training1000
146, targeted continuation 64; total 276 passed, zero failures/errors/warnings/
skips. The first broad test attempt lacked the new worktree's library symlink
and skipped four inference tests. After linking the unchanged verified library,
that entire suite was rerun with all 146 expectations passing and zero skips.
The initial test receipt exporter also needed its list-valued result column
excluded before CSV serialization; no scientific code or test assertion changed.
Bash syntax and staged Git whitespace checks passed.

- Run focused recovery tests, including known-race retries, invalid telemetry,
  fail-closed drain, deadline and compute-budget expiry, PID identity, duplicate
  accounting protection, and TERM handling of synthetic workers only.
- Run the existing targeted and training1000 suites using the already-pinned
  CRAN 1.1.2 library; avoid dependency-driven skips by a read-only library symlink.
- Check bash syntax and Git whitespace. Commit/push only this dedicated branch.
- Freeze a recovery context under `<original run>/recovery/<recovery tag>` after
  verifying both worktrees' exact clean commits, source hashes and old successes.
- Confirm the pending queue excludes all completed IDs, has 46 rows, and that a
  successful real disk scan meets the unchanged bounds. No model smoke refit is
  needed: model code and environment are unchanged and previously verified.
- Recheck host worker absence and use the original unused-PHYSICAL-core selector.
  Launch the corrected driver detached in tmux with at most 15 workers, one CPU
  affinity and all BLAS/OpenMP variables set to 1 per worker.
- Verify effective live health, actual worker CPU affinity/thread variables,
  progress/exit receipts, protected successes and driver/source hashes after launch.

Reproducible commands (absolute paths recorded in the recovery context):

```bash
Rscript <driver>/validation/fitforecast_v2/scripts/independent_qdesn_training1000_recovery_v1.R prepare <driver> <control> <science> <run>
bash <driver>/validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_recovery_v1.sh <driver> <science> <run> <control>
Rscript <driver>/validation/fitforecast_v2/scripts/independent_qdesn_training1000_recovery_v1.R health <driver> <control>
```

Production uses `/data/jaguir26/local/opt/R/4.6.0/bin/Rscript`, not an arbitrary
system R. The context and driver manifests must verify before the launch command.
The shell's RSCRIPT override exists for synthetic tests, not production upgrades.

## Counts and Scientific Gates

46 bridge jobs are required to finish the current materialized queue. If the
unchanged forecast decision warrants confirmation, up to 162 jobs follow: 36
final VB, at most 18 warm initializers, and 108 three-chain final MCMC. Thus at
recovery launch there are up to 208 remaining jobs; 380 maximum for this campaign.
Do not claim a final completion percentage using this conditional maximum.

After all 66 bridge jobs have verified artifacts and finite metrics, apply the
original strict-forecast-gain decision, case by case and separately by engine.
No minimum gain percentage, fit-RMSE veto, or perfect-mixing requirement is added.
If triggered, freeze all final winners before scoring the complete coherent final
four-model N1000 surface. If not triggered, close development without opening
final targets. Never advance from partial results or publish only attractive rows.

## Reporting, Storage and Handoff

Retain compressed location/parameter draws, nuisance traces, metric/origin/lead
summaries, warm initializers, manifests and logs. No fitted-model binary is needed.
Do not clean any legacy data during recovery. New driver code/tests/docs are
tracked; contexts, original model outputs, health and test receipts are ignored.

The original frozen scientific tree stays at c27fc70 and clean. Only the new
recovery branch is committed/pushed with Git, with no merges into an authority.
After full closeout, prepare all-model interval tables/figures, explicit N1000
versus historical-N500 comparisons and the integration handoff. The coordinator
alone may merge authorities, decide article replacements, compile and publish
Overleaf. A live campaign is NOT_READY_FOR_INTEGRATION.
