# IND Training-1000: Targeted Continuation V2

## Decision and Scientific Question

This is an authorized amendment after the completed N500/N1000 fixed-design
pilot, not a hidden relaxation of its original aggregate gate. The user reviewed
the pause and requested implementation of the evidence-based follow-up.
The question is whether case-specific DESN/prior choices can improve internal
forecast recovery under N1000, and which longer-history signals transfer to MCMC.
No improvement, excellent mixing, or article promotion is presumed.

Only this dedicated IND branch may be committed/pushed. Do not merge shared
validation, Article-v2 main, integration or Overleaf. Do not modify other lanes,
old worktrees, their workers, package libraries or archived runtime artifacts.

## Audited Starting Point

Parent HEAD: `4fe190c279049854ec395d95f1014f75752ff468`.
Parent run: `independent_qdesn_training1000_exdqlm112_v1_20261006_035315__git-4fe190c2`.
Shared authority: `5b85bb3a3894a88968e4987f330e3ec66711f9c7` at re-fetch.
The parent includes the lane's unintegrated scientific repairs above shared main;
discarding them by branching only from shared would not reproduce this pilot.

The parent finished 8 cost, 72 VB diagnosis and 8 MCMC pilot jobs: 88 successes,
zero failures/pending/running, 132 underlying fits. Its artifacts are unchanged.
95 manifests/960 rows and 440 score summaries verified; maximum independent score
recomputation discrepancy 7.638334e-14. The focused suite passed 146 expectations.

VB N1000 improves forecast MAE in 9/18 cases; median ratio is 1.00578890205817.
The half-count predicate passed, the median predicate failed. The original
imprecise gate explanation is retained in the parent; a tested helper now
reports both predicates correctly for future V1 runs.

Laplace improves in 5/6 cases (median -37.72%), Gaussian in 3/6 (-9.45%), and
Gaussian mixture in 1/6 (+7.24%). Common-last-500 Q-DESN fit RMSE improves in
15/18, so fit gains alone are not the forecasting solution.
Gaussian AL p=.05 MCMC forecast MAE worsens 7.78%; Gaussian exAL p=.25 improves
.75% but remains 1.676 times its matched baseline. These are one-chain,
32-outer/32-inner development results, not final article estimates.
Substantial lead-1 and mean-path errors persist: recursive noise and interval
width alone do not explain the gap. Laplace p=.05 historical anchors have
particularly slow initialization forgetting; this is disclosed, not silently
fixed by changing washout or suppressing valid metrics.

## Why This Amendment

Do not repeat the 88 completed jobs or launch the original 1116-job remainder.
The global VB median is not a case-specific MCMC verdict. Direct quantile VB
screens and explicit MCMC bypasses are more informative here than another large
normal-VB ranking exercise. Normal RHS VB remains the fresh initializer; it
neither excludes quantile designs nor transfers its fitted shrinkage into priors.

Reusing the frozen bank avoids inventing another unvalidated search space or
claiming new coverage while rerunning a previous identical design. Replay controls
are intentional and labeled. The new experiment changes N/fold/inference budgets
where declared, not the existing data-generating trajectories or score definitions.
Pre-M0 exAL rankings are historical suggestions, not evidence-based exclusions.

## Fixed Scientific Contract

CRAN exdqlm 1.1.2, R 4.6.0 and the verified isolated installed package are pinned.
Tarball SHA-256: `de2de1021b0160ff13ce8ec3aa09fec47274d95f9737da125a718ffc313a49b9`.
Baselines use the official namespace; DESN uses the recorded private IND extension.
Q exAL MCMC: `m0_v_collapsed_support_logit`; exDQLM: `collapsed_slice`;
AL gamma is fixed. No package upgrade or inference-kernel change is introduced.

Three families, p=.05/.25/.50, AL/exAL, and matched Q-DESN/DQLM classes remain.
N1000 is the coherent final arm; N500 is a matched internal control, not an
unlabeled alternative selected separately for displayed models.

| Fold | N | Fitting rows | Reservoir washout | Targets |
| --- | ---: | --- | --- | --- |
| A | 500 | 8001:8500 | 7501:8000 | 8501:8750 |
| A | 1000 | 7501:8500 | 7001:7500 | 8501:8750 |
| B | 500 | 8251:8750 | 7751:8250 | 8751:9000 |
| B | 1000 | 7751:8750 | 7251:7750 | 8751:9000 |
| Final | 1000 | 8001:9000 | 7501:8000 | 9001:10000 |

Keep 390 buffer observations before the 500 genuine reservoir washout rows.
Development folds: 45 origins, stride 5, leads 1-30, 1350 scored pairs each.
Final: 34 origins, stride 30, last horizon truncated to 10, 1000 scored pairs.
Observed outcomes update reservoir/lag states between origins (teacher forcing).
Unknown within-origin outcomes recurse. Static DESN coefficients do not refit
between origins; baseline states filter observations. No future smoothing.

Input is observed outcome lags; no exogenous variables. Readout is intercept
plus every reservoir layer, identity Q with no dimension reduction, tanh
reservoir activation and identity lower-state readout transformation. Fixed seed
920001, uniform weights and exact normalized fan-in remain unchanged.
Train-only input preprocessing and source-scale prior transport remain.
The intercept remains unshrunk; no new intercept prior or centering experiment.

Primary forecast object remains the inner-average conditional location after
recursion, not a mixture-distribution quantile. Plugin paths remain a companion.
Per-outer-draw oracle fit RMSE and forecast MAE/RMSE, and realized-observation
check loss are preserved, with type-8 equal-tailed 95% intervals.
Scores of the mean path are diagnostic companions, not substituted estimands.

## Cases and Candidate Construction

Priority cases: Gaussian AL p=.05, Gaussian exAL p=.25, Laplace AL/exAL p=.05.
Signals to verify: Laplace AL/exAL p=.25/.50 and Gaussian-mixture exAL p=.05.
Other cases retain predeclared anchors during development; they are not dropped
from the final four-model surface.

Per priority case: eight structures from its frozen family bank, normalized to
its OWN anchor prior scales. One exact anchor, four nearest frozen local-bank
structures, one 500-unit shallow challenge, one >=3-layer challenge containing
a 500-unit layer, and one contrasting regime. Nearest-bank designs are labeled
honestly; they need not be two-field perturbations of this specific anchor.

Each structure has tau multipliers .1/1/10 around the case's source-scale anchor:
24 design/prior pairs per case, 96 total. Existing matrix seed, input gain,
input sparsity and bound choices are preserved for each selected bank design.
Capacity challenges require shallow alpha>=.4/rho>=.9 and deep alpha>=.4/rho>=.85;
the remaining local/regime arms retain broad previously frozen alpha coverage.
This is a bounded comparison, not an assertion that high alpha/rho always wins.
Every exact structural/prior identity and parent signature is in the frozen CSV.

## Automated Stages

| Stage | Maximum jobs | Underlying fit calls | Budget/decision |
| --- | ---: | ---: | --- |
| Cost/artifact smoke | 8 | 18 | Four anchor VB, two deep Q MCMC, two baseline MCMC |
| Quantile A | 96 | 192 | All priority pairs; 750 VB iterations, 32/32 outer/inner |
| Quantile B | 48 | 78 | <=4 nominees/priority, other Q anchors, all 18 baselines |
| MCMC bridge | 66 | 93 | 48 N1000 warm-started fits plus 18 matched N500 controls |
| Final VB | 36 | 54 | All cases/classes, 900 outer/128 inner |
| Final warm | <=18 | <=36 | Only final MCMC winners differing from VB winners |
| Final MCMC | 108 | 108 | Three chains/case/class, 300 outer/128 inner per chain |
| Maximum | 380 | 579 | Conditional, not all dispatched at launch |

N1000 bridge warm initializers come from the same candidate AND fold-B fit,
with verified configuration/design hashes and fresh priors. N500 controls need
their own initialization; parent fold-A initializers are not incorrectly reused.
Bridge chains: 1000 burn and 4000 retained; outer 120/inner 128.
Final chains: 5000 burn and 20000 retained, three chains per model/case.
One predeclared Gaussian exAL p=.25 nested 128/256 inner-precision check remains.

Before opening B, freeze up to four nominees per priority: anchor, MAE leader,
check-loss leader, and a reserved capacity bypass, filling duplicate slots
deterministically. All nominees receive MCMC, including candidates that normal
or quantile VB did not rank first. No chain grade is a metric-exclusion rule.

Finalists are selected PER CASE and separately by inference engine, ordered
by forecast MAE, check loss, fit RMSE, width, then ID. No global specification.
All nominee forecast gains are retained in a separate ledger, including check
gains on non-MAE-leading designs; these are not silently published as a
metric-wise best-of-several-model primary row.

The final trigger is any finite STRICT forecast MAE or check-loss improvement
for the selected MCMC specification against its N1000 anchor, or an N1000
signal anchor against its N500 matched control. There is no minimum percentage
gain, significance threshold, perfect-mixing requirement or fit-RMSE gate.
This is development evidence for confirmation, not final publication evidence.
If none exists, the pipeline closes development without scoring final targets.
Otherwise it freezes all 36 final case/engine winners before the final block
and estimates the entire coherent four-model surface, not just attractive rows.

## Root Fixes and Tests

Nuisance trace export now explicitly converts S3/matrix samples to numeric
vectors and validates length/finiteness before CSV construction, so labels are
sigma/gamma/intercept rather than `var1`. Existing parent files are untouched.
Gate predicates are explicit and equality at 9/18 is tested.
The shared scheduler accepts a lane-specific CLI/stage list and smaller CPU
budget; its default V1 behavior is preserved. Early no-gain completion is a
successful closed stage, not an erroneous missing-plan failure.

Focused tests cover trace matrix classes/round trips, gate boundaries, portfolio
identity/diversity/case prior transport, tiny FAIL-labeled gains, frozen B
capacity bypasses, warm starts, 48/66/36/108 stage counts, and no-gain closeout.
The existing suite covers causal teacher forcing, nominal SPD/no-jitter,
batched/reference recursion and compact/full initialization equivalence.
Run the complete package/default/serial-RNG preflight and actual eight-worker
artifact/cost smoke before dispatching the 96 expensive screens.

Implementation verification: new focused suite 64 expectations and existing
suite 146 expectations passed, zero failures/errors/warnings/skips. All 43
package/default/causal/RNG preflight checks passed. Bash syntax and
`git diff --check` passed. The initial new-suite attempt exposed a missing
synthetic candidate-ledger fixture in its no-gain test; that fixture was fixed
and the complete suites rerun. No production job had been launched at that point.

## Efficiency and Safety

At most 15 unused PHYSICAL cores, one worker/core, all BLAS/OpenMP threads=1.
Reserve 24 GiB memory and a conservative 12 GiB/worker; preserve prior disk/RSS
guards. Reduced cumulative cap: 400 worker-hours, 48h/stage; intermediate jobs
12h, final jobs 48h. Measured deep-cost projections must remain <=48h/final job.
Stopping dispatch drains active workers. Never interrupt another scientific lane.
No full fitted-model binary is required; preserve compressed selected parameters,
location draws, traces, initializers and granular score evidence for replication.
Do not clean old data or outputs while preparing this launch.

No causal claim that doubling N alone produced a gain: the longer history changes
preprocessing and reservoir start as well. No numerical comparison of internal
targets to article headline scores. Historical article N500 versus final N1000
is descriptive and must be clearly labeled by integration. The final block has
already influenced earlier research decisions and is not pristine; after freezing
the complete protocol, fresh DGP replicates remain stronger independent evidence.

## Closeout and Coordinator Handoff

Do not promote partial scores or change article tables here. Complete/no-gain
closeout retains frozen manifests, provenance, exact changed files and tests.
Final review exports all-model interval tables/figures, origin/lead profiles,
diagnostics and historical comparisons to ignored local review paths.
Integration decides whether the complete N1000 study warrants a separate panel
or article replacement. New training sizes/estimands cannot be merged into old
metric columns without disclosure, even when a finite score is smaller.
Only the coordinator merges authorities, compiles manuscripts and publishes
the article-only Overleaf snapshot. A running campaign is NOT_READY_FOR_INTEGRATION.
