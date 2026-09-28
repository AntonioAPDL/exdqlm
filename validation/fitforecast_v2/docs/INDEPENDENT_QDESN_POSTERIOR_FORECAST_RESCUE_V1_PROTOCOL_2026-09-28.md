# Independent Q-DESN posterior-forecast rescue v1

## Scientific decision

The matched stride-one comparison is complete and no related computation is
still running. Mean-readout-state recursion improves 53 of 54 Q-DESN forecast
comparisons, but generally by too little to close the DQLM/exDQLM gap. The gap
is already visible at lead one and at nearly every origin, so another forecast-
state postprocessing change is not the primary remedy.

The completed v2.1 redesign explored 5,472 Normal-RHS structure-by-`tau0`
combinations and carried 50 diverse candidates per family into quantile VB.
Its promotion path nevertheless optimized a different estimand: VB point
forecasts selected four MCMC pilots per cell, and path-recursive MCMC scores
selected confirmation finalists. Across the 72 historical pilots, VB and
mean-state MCMC forecast rankings were weak or negative in most cells. This is
the actionable selection mismatch.

This campaign therefore does not repeat the 5,952-job redesign and does not
refit DQLM or exDQLM. It directly screens Q-DESN posterior forecast metrics
under short MCMC, using exAL M0 wherever gamma is unrestricted.

## Protected selection protocol

Candidate selection uses only observations 8501--9000. Fits use 8501--8800,
and forecasts use all 171 origins 8800--8970 with 30 recursive leads, giving
5,130 origin-lead pairs. The model is teacher forced between origins and
recursive within each horizon. The primary estimator is
`mean_readout_state_recursive`; path recursion is retained only in final
confirmation.

The 9001--10000 block is not used while screening or replication. It is opened
only after one candidate is frozen independently in each unresolved cell.
This guard is essential because the final block has already been inspected in
diagnostic work and must not become the optimization surface.

The current AL-Laplace, p=0.05 success is frozen. The campaign targets all nine
exAL cells and the other eight AL cells. Every cell may select a different
DESN architecture and `tau0`; a global specification is forbidden.

## Candidate design

Each family receives 60 candidates:

1. all 50 frozen v2.1 full-budget candidates, including their exact reservoir
   seeds and `tau0` values;
2. six deterministic exploitation candidates close to the best historical
   mean-state MCMC neighborhoods;
3. four deterministic maximin candidates in previously uncovered regions,
   with each family forced to retain both low-`tau0` (at most 0.03) and
   high-`tau0` (at least 10) designs jointly with low/high `alpha` or `rho`.

Novel proposals use the original broad design support: depth 1--4, widths up
to 300 per layer, total state dimension up to 800 for this rescue, response
memory up to 150, broad `alpha` and `rho`, both training-only scaling rules,
both input-bounding rules, multiple input gains, exact fan-in sparsity, and
`tau0` from 0.01 to 30. Novel signatures are rejected against every one of the
5,472 historical candidates. Candidate generation is deterministic and its
source ledgers are hash pinned.

## Stage graph

### Stage A: direct posterior screen

Run 1,020 one-chain MCMC jobs: 60 candidates in each of 17 unresolved cells.
Each job uses 1,000 burn-in iterations, 4,000 retained iterations, and 120
evenly selected posterior draws. Internal VB is initialization only, not a
promotion gate. Pilot jobs export compact metric draws and omit large
origin-by-lead payloads.

Candidates are ordered forecast first: posterior mean oracle-quantile MAE,
forecast check loss, MAE interval width, and fit oracle-quantile RMSE. Interval
width is a diagnostic/tiebreaker, not a reason to prefer a materially worse
forecast mean.

### Stage B: replicated validation

The top three candidates per cell receive two additional independently seeded
chains, yielding 102 jobs and three chains per candidate when pooled with the
screening chain. One candidate per cell is then frozen from pooled validation
metrics. Chain diagnostics are disclosed but do not veto a finite strict score
improvement; nonfinite output or a broken design contract remains fatal.

### Stage C: sealed confirmation

The 17 frozen finalists receive three full chains with 5,000 burn-in and
20,000 retained iterations. Confirmation uses all 971 origins and 30 leads on
9001--10000, exports 300 posterior metric draws per chain, and retains both
mean-state and path-recursive estimators plus origin/lead summaries.

Closeout compares each finalist with the frozen matched DQLM/exDQLM surface and
with the previous Q-DESN authority. Every finite strict per-cell forecast
improvement is eligible for integration review, however small. No article,
shared-validation, or Overleaf write is automatic.

## Reproducibility and storage

The protocol pins the completed redesign and comparator ledgers by SHA-256.
Materialization copies and rehashes the nine source trajectories. Every config
records candidate, source, protocol, package, Git, and seed provenance.
Workers are process parallel and single threaded. Status files are atomic and
the pipeline is resumable. Fitted model binaries are never retained.

The campaign uses 15 one-core workers. It owns only its dedicated branch,
worktree, and ignored run root. Article-v2, Overleaf, shared validation, joint
Q-DESN, PriceFM, GloFAS, and unrelated runtime artifacts remain untouched.
