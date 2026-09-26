# Independent Q-DESN redesign v2.1 audit and relaunch record

## Scope and decision

This record belongs only to the independent single-quantile Q-DESN/DQLM
validation lane. It authorizes no Article-v2, Overleaf, shared-validation,
joint-QDESN, PriceFM, or GloFAS change.

The original v2 run root is retained under ignored local tracking as a compact
diagnostic snapshot. It completed 1,151 of 1,152 initial Normal-RHS jobs and
then stopped fail-closed. No adaptive, full-budget, quantile-VB, or MCMC stage
was launched. It contains no `.rds`, `.rda`, or `.RData` payload and must not be
promoted or resumed with revised code.

The v2.1 decision is to launch a fresh immutable run root after two root-cause
repairs: validated support-preserving spectral normalization and a paired
structure-by-`tau0` search. Every other accepted scientific contract remains
fixed.

## Root-cause evidence

The failed v2 candidate had two layers of widths 150 and 300, recurrent fan-in
20, `alpha = 0.470584459965098`, `rho = 0.969479367788519`, and matrix seed
97278416. RSpectra returned a spurious leaky-map radius of 1.1263 with a
relative eigenpair residual near 1.04. Dense eigenvalues gave 0.1044. The old
guard then added nonzero diagonal entries to 279 rows of layer 2, changing
fan-in from 20 to 21. This was an implementation failure, not a scientifically
unstable reservoir.

Across the other successful 300-unit cases, topology remained intact and exact
leaky radii were below one. Dense eigendecomposition at width 300 is cheap on
Muscat, so v2.1 uses exact eigenvalues through width 512. Approximate results
above that threshold require a verified relative residual and otherwise fall
back to the exact calculation. Stabilization, if ever needed, multiplies the
whole recurrent matrix by a positive scalar and cannot create edges.

The 1,151 completed v2 rows also showed that one randomly assigned `tau0` per
structure could not separate architecture from shrinkage. Laplace performance
improved sharply when a disposable sensitivity check moved from 0.1 to 1-10,
whereas the tested Normal and Gaussian-mixture structures were comparatively
flat. This is evidence for joint, family-specific exploration, not for one
larger global `tau0`.

## Frozen v2.1 design

The initial design contains 256 structures per family crossed with actual
`tau0` values 0.03, 0.1, 0.3, 1, 3, and 10. Structure identity excludes
`tau0`; candidate identity includes it. Matrix seeds are invariant across the
six arms. This produces 4,608 auditable initial jobs.

The adaptive design selects forecast-first parent pairs, creates 96 new
structures per family, and assigns each three local scales at parent/3, parent,
and 3*parent, clipped to 0.01-30. This produces 864 jobs. Tau-response ledgers
report within-structure winners and top-25 boundary occupancy before the next
stage. The full-budget selector retains 50 pairs per family and no more than
two scales for one structure.

Selection remains forecast first. Normal-RHS uses oracle-location forecast MAE
as its primary score; AL/exAL VB and MCMC use oracle-quantile forecast MAE,
then check loss and fit RMSE. Family, quantile, likelihood, DESN structure, and
`tau0` remain case specific. Diagnostics are disclosed but do not veto finite
score improvements; dimensional, nonfinite, leakage, topology, and provenance
failures remain hard stops.

## Unchanged scientific contract

- Families: Gaussian, Laplace, and Gaussian mixture.
- Quantiles: 0.05, 0.25, and 0.50.
- Fit window: 8501-9000; sealed held-out window: 9001-10000.
- Selection fit/validation split: 8501-8800 and 8801-9000.
- Final origins: 9000-9970 at stride one, with 30 recursive leads.
- Observations teacher-force the reservoir between origins; forecasts recurse
  within an origin.
- Readout: intercept plus all current reservoir layers only.
- Lower-layer projections: exact identities.
- Reservoir activation: tanh; lower-state readout transform: identity.
- Q-DESN estimators: path-recursive and mean-readout-state recursive.
- exAL inference: structured LDVB and exact M0 collapsed-slice MCMC.
- Parallelism: 15 worker processes and one thread per worker.
- Storage: compact CSV/JSON/GZIP evidence; no fitted-model binaries.

## Stage gates

1. Materialization must prove the six-arm pairing, stable matrix seed, unique
   identities, source hashes, clean dedicated branch, and exdqlm 1.1.1.
2. Preflight must replay matrix seed 97278416 and pass exact fan-in, spectral,
   nested AL/exAL VB, exact-M0 MCMC, and paired-estimator canaries.
3. Every completed Normal stage must match its candidate manifest exactly and
   pass finite, spectral-target, leaky-radius, and support-scale checks.
4. Tau-response audits are written before adaptive and full-budget selection.
5. The final held-out block remains unavailable until confirmation.
6. Partial stages are diagnostic only. Article promotion remains manual and
   requires fixed DQLM/exDQLM replay on the same stride-one lattice.

## Execution and rollback

The fresh run root must contain `v2_1` in its tag and be created only from a
clean branch synchronized with its upstream. The old v2 root is labeled
`STOPPED_INITIAL_STAGE_EIGENSOLVER_AND_TAU_RANGE` and remains excluded from
selection. Atomic statuses make each stage resumable without repeating
successful jobs. A failed stage stops the controller before downstream
materialization. Rolling back means stopping only the v2.1 tmux controller and
retaining the compact root for audit; it never requires resetting another
worktree or deleting another lane's artifacts.

The only supported background entry point is:

```bash
validation/fitforecast_v2/scripts/launch_independent_qdesn_full_redesign_v2_1.sh
```

It creates a unique ignored run root, a sibling controller log and launch
receipt, and one uniquely named tmux controller. The controller enforces 15
workers, one thread per worker, branch/upstream synchronization, package
version 1.1.1, load/memory/disk gates, preflight, stage completeness, and
fail-closed downstream materialization.

## Checkpoint recovery after the adaptive stage

The launched v2.1 campaign completed all 4,608 initial and 864 adaptive
Normal-RHS jobs with no worker failure. It then stopped before full-budget
materialization because the adaptive candidate ledger contains the additional
provenance field `adaptive_tau_center`, while the initial ledger does not.
Base `rbind()` rejected the 30-column and 31-column metadata frames. Result
schemas, model fits, source data, topology checks, and numerical outputs were
unaffected.

Recovery must not rerun the 5,472 completed jobs or silently weaken the frozen
HEAD assertion. The repair therefore aligns only the declared optional field,
fails on every other schema difference, and requires an explicit checkpoint
authorization before a different committed HEAD can execute workers. The
authorization hashes every completed config, result, status, log, source,
plan, summary, and manifest; records the base and repair commits and their
exact diff; requires a clean synchronized branch; and rejects scientific or
protocol file changes. New job statuses record their execution HEAD and
whether they used the authorized checkpoint path.

The only supported recovery entry point is:

```bash
validation/fitforecast_v2/scripts/resume_independent_qdesn_full_redesign_v2_1.sh \
  --run-root <existing-v2.1-run-root>
```

It rechecks the two completed stages, writes the ignored authorization packet,
and resumes the same atomic stage graph with 15 one-thread workers. The
original materialization and environment manifests remain immutable, so the
mixed-HEAD transition is explicit rather than overwritten.
