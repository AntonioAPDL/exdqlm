# Independent frozen preprocessing repair and forecast reevaluation

## Objective and evidence

Correct the verified override-overwrite defect before interpreting reservoir
capacity or promoting any current forecast gain. In v9 all six audited designs
changed their training feature prefix when extended through the development
block. The supplied training preprocessing was overwritten despite metadata
claiming it was frozen. This is distinct from gamma mixing or model capacity.

The root fix preserves explicit lag preprocessing in `qdesn_fit_vb`, including
the Normal wrapper, and initializes decomposition runtime independently of
override presence. Behavior without overrides remains unchanged. Tests must
exercise actual feature construction, including future-response perturbation,
not merely helper calculations or provenance flags.

## Scope and boundaries

Use a new IND worktree based on v9 HEAD
`054df26fb252c028147bfabbfb698b9578d1ee1b`. Do not edit the running v9 worktree,
stop jobs, alter other lanes, merge shared validation, modify Article-v2, or
publish Overleaf. The current shared remote authority was read-only verified
at `5b85bb3a3894a88968e4987f330e3ec66711f9c7`; this repair deliberately extends
the unintegrated scientific source rather than discarding its fixes.

## Stage 1 root repair and behavioral verification

1. Preserve overrides through the actual reservoir factory.
2. Test mean/SD, median/MAD, bounded/unbounded inputs, scalar/vector overrides,
   Normal and quantile wrappers, unchanged default behavior, identity Q, and
   exact training-prefix and origin-state invariance.
3. Exercise saved designs and verify their hashes. Effective metadata, response
   transport, seeds, priors, alpha/rho, memory, layers and widths stay frozen.
4. Test nested recursive forecast behavior and score reconstruction.

## Stage 2 compatibility replay without MCMC refitting

Freeze the ACTUAL historical training basis, estimated from observations
available through the original fitting endpoint including its warmup context.
This is explicitly `saved_training_basis`, not a claim of a newly refitted
training-window-only design. Reconstruct saved MCMC beta/sigma/gamma draws
from compact parameter CSVs and reproduce the original draw-index selection
and training quantile paths within 1e-6. No MCMC engine may run in this stage.

For VB, sigma/gamma distribution objects were not retained, so replay only the
four already-selected VB fits to reconstruct them. Use the exact saved basis,
initializer, full coupled solver, and priors. Verify means, covariance,
sigma/gamma means and fitted draw paths against retained evidence within 1e-6.
This cheap deterministic VB reconstruction is not a new screen. Fail closed
if its posterior cannot be reproduced rather than inventing scale/skew draws.

Recompute forecasts using the same origins, H=30, outer/inner draw budgets and
noise seeds. Teacher forcing updates observed histories between origins;
within each origin all unavailable future outcomes remain recursively drawn.
Store point scores and per-draw score means/95% ranges separately, along with
origin/lead profiles, quantile paths, preprocessing checks and input hashes.

Start with bounded smoke forecasts; compare original draw paths and analytical
H1 projections before the complete forecasts. Replay four VB selected rows,
four MCMC pilots, and the six selected exAL confirmation chains only after each
source job completes and its hashes validate. Do not rerun historical screens
or DQLM comparators. Use at most six single-thread workers on CPU 25-30 after
the current v9 jobs release those cores. Source failures block only explicitly
dependent jobs; missing evidence is not success. No fitted-model binaries.

## Stage 3 comparative closeout

Create old-versus-repaired scores by case, likelihood, inference and estimator.
Retain every finite gain or regression; never apply a mixing-quality veto.
Compare likelihood-matched DQLM baselines only under matched windows and score
aggregation, labeling the currently retained comparator evidence as VB.
Report H1 and H1-30 separately to distinguish estimation and recursive growth.
Show point means and posterior score ranges without confusing them.

Prepare an ignored diagnostic PDF and a machine-readable closeout with hashes,
test results, job counts, storage and any remaining gap. Do not automatically
replace article-v14 results: its external window and posterior-score estimand
are different. The coordinator owns any later integration/publication.

## Stage 4 scientific continuation after repaired evidence

The INTENDED training-window-only basis differs from the saved basis. Its
coefficients cannot be copied from old fits. A selected-model refit on that
basis must have a fresh design hash and initialization, unchanged priors and
explicit exAL M0. Gate this decision on the repaired forecast closeout rather
than spending on new chains before the isolated defect is measured.

If forecast deficits persist, retain richer identity-Q architectures, including
larger layers, with case-specific alpha/rho, scaling, sparsity, memory and tau0.
Use training-only rolling-origin forecasts, not training fit alone or oracle
truth readouts, to select candidates. Large truth-trained reservoirs showed
better H1 capacity, but actual noisy-data learning did not realize it. Do not
assume more neurons or smaller tau0 is sufficient. No broad screen is part of
this repair launch.

## Reproducibility and acceptance

Freeze source/config/input hashes, compiled-library identity, environment,
posterior row indices and inference runtime label. Runtime is the pinned
exdqlm 1.1.1 validation source plus this repair, not an unmodified CRAN binary.
Keep source worktrees and outputs immutable. All scientific comparisons use
explicit source/config IDs and a 1e-6 numerical reproduction tolerance.
Readiness requires root tests, preserved saved designs, finite complete replay
scores, clean manifests and explicit limitations. Background running is not a
completed scientific phase and does not authorize article promotion.

## Operational wiring and root-cause limits

The executable entry point is
`validation/fitforecast_v2/scripts/independent_qdesn_frozen_preprocessing_v10.R`
with `preflight`, `materialize`, `worker` and `closeout` commands.
The detached shell launcher reads `REPO_ROOT`, `RUN_ROOT`,
`LEGACY_RUN_ROOT`, `RSCRIPT` and `CPU_LIST=25,26,27,28,29,30`.
It waits for v9 COMPLETE and a fresh physical-core/sibling idle check before
starting workers. It drains already-active workers if any replay fails and
never starts another MCMC engine. A stopped or failed source campaign blocks
the replay; source incompleteness must not be bypassed.

The preflight tests selected VB and MCMC cases with two origins, H=2, four
outer draws and four inner paths. The main replay retains all original
scientific budgets. The seven-suite regression runner checks the factory,
Normal wrapper, recursion, mean-readout implementation, replay, scoring and
coupled solver. Its closeout fixture verifies output generation, separates
score-of-mean from mean-of-scores, and rejects a changed input/output hash.

Materialization verifies retained comparator configurations and all 1,350
origin/lead pairs against the identical response and oracle values. The
comparator values are reconstructed from their retained point paths. Closeout
writes `old_vs_repaired.csv`, `H1_vs_H30.csv`,
`retained_VB_comparator_gaps.csv`, `posterior_score_intervals.csv`,
`repaired_point_scores.csv` and `old_vs_repaired_review.pdf`.
These are ignored diagnostics, not article replacements.

The prior audit found six prefix discrepancies, with maximum feature errors
between 0.027 and 0.200. Keeping W/Win identical and changing only effective
preprocessing restored every audited training prefix. One-step scores moved
in both directions under the repair; this is not evidence that all forecast
deficits are explained by scaling. Truth-trained OLS reservoirs answer a
capacity question, not noisy-observation learning or deployable forecasting.
They cannot be promoted as fitted candidates or used to declare superiority
over DQLM. Wider architectures remain a possible later experiment, not the
assumed remedy before this compatibility replay finishes.

No conclusion about older article-v14 factory behavior is made by this
v3-v9 repair alone. Article v14 uses a different fitting window, external
evaluation block and score estimand. It needs an explicit provenance audit
before any retrospective implementation claim or metric replacement.

## Unified recovery after the October 4 audit

The v9 source campaign completed fourteen selected jobs without a model failure:
four cost smokes, four pilots and six exAL confirmation chains. Six AL
confirmation rows were not selected and are not unfinished work. The first v10
attempt failed before starting a worker. Its RUNNING_REPLAY marker is stale.
Do not wait for that attempt or repeat the expensive MCMC campaign.

The host Bash 4.4 shell rejected an uninitialized associative-array length under
nounset. This lane's syntax-only scheduler check missed that operational error.
Recovery explicitly initializes arrays, uses an EXIT handler for truthful
terminal status, records the launcher PID and each worker exit, and preserves
already-running workers when dispatch stops. Reap every completed peer before
dispatching replacements so a failed peer cannot be hidden behind successful
completions. Verify plan extraction directly rather than in process substitution.

### Evidence preservation

The failed attempt remains untouched. Before source edits, its 223 frozen source
files and incident evidence were copied and SHA-256 verified under the ignored
`local_trackers/v10_launcher_recovery_20261004/failed_attempt_archive` directory.
The archive maps original paths to immutable copies. Live source paths can
legitimately change during repair, so the original attempt's source hashes must
be checked against that archive after editing, not silently rewritten. The
archive is about 31 MB and contains source, not fitted-model payloads.

### Mandatory gates and ordering

1. Run real Bash mock-worker tests for startup, the final worker, multiple waves,
   failure stopping dispatch, draining, duplicate locks, source failure, corrupt
   or empty plans, extraction failure, fatal exits and interrupted draining.
   Also test that reusing an attempt cannot overwrite its status or exit ledger.
2. Run all eight focused test files and all eight numerical saved-basis preflights.
   Keep test artifacts even when a development test fails. Scientific settings
   and saved posterior reproduction tolerance remain unchanged at 1e-6.
3. Materialize a fresh attempt with all fourteen original selected references,
   new source hashes and unchanged scientific budgets. The launcher verifies
   source/materialization manifests, fourteen unique configs and absent outputs.
   It verifies the completed v9 closeout/final manifest before spending CPU.
4. Exercise two bounded real workers in a separate ignored I/O smoke directory:
   saved AL MCMC and reconstructed exAL VB, two origins, H=2, four outer draws
   and four inner paths. These supplement the eight numerical preflights by
   exercising status, output and artifact-manifest wiring. Smoke outputs carry
   execution_kind=io_smoke and cannot enter production closeout.
5. Only after the gates pass, detach the fresh production launcher in tmux. Use
   six single-thread workers on cores 25-30, after checking those cores and
   siblings. Resource waiting is bounded at one hour; no other lane is stopped.
6. Check actual worker PIDs and status files immediately after launch. The new
   health command verifies manifests and distinguishes successful, running,
   pending, failed-before-status, stale-running and invalid-evidence rows. A
   stale pipeline marker does not count as scientific progress.
7. After fourteen successes, automatically verify artifacts, build comparative
   tables/intervals/profiles and the review PDF, then publish COMPLETE only
   after the final scientific manifest is written. Mutable pipeline status and
   the open orchestrator log are excluded from that final artifact manifest.

### Decisions that remain scientific rather than automatic

Gaussian exAL p=0.25 improved all five criteria in all three paired chains before
repair. Its oracle MAE fell from 7.437851 to 3.247206 relative to the Q-DESN
control, but the retained exDQLM reference is VB and scores 1.705392. This is not
a matched MCMC superiority result. The AL p=0.05 pilot did not show that gain.
The repaired forecast can move in either direction; there is no promise of
improvement and no diagnostic-quality veto or minimum practical-gain threshold.

Do not decide the next broad screen until corrected H1 and H1-30 results exist.
Weak H1 suggests conditional learning/representation; deterioration mainly at
long leads suggests recursion. Good point paths with wide score ranges require
separating parameter uncertainty from origin/lead heterogeneity. Case-specific
larger identity-Q designs and tau0 exploration remain possible later stages,
selected with causal internal forecasting rather than fit-only Normal-VB scores.

Keep point-path scores separate from means and 95% ranges of per-draw scores.
The selected compatibility replay is not an external article confirmation and
does not establish calibrated uncertainty bands. No Article-v2, Overleaf,
shared-validation or integration branch is edited or merged by this recovery.
Commit/push and coordinator handoff are separate from an active background run.
