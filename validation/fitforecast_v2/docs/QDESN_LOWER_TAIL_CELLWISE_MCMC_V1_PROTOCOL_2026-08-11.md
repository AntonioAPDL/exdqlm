# Independent Q-DESN lower-tail cellwise MCMC v1

Date: 2026-08-11

## Scope and authority

This protocol belongs only to the independent single-quantile Q-DESN/exQ-DESN
and DQLM/exDQLM simulation validation. It excludes joint-QDESN, PriceFM,
GloFAS, and all application campaigns.

The immutable article authority is promotion v6 at validation commit
`5a4e6ed210bd113d2d0459c6f6b47cde6439ffcb`. The source registry identity is
`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`, and the
package baseline is exdqlm 1.0.0. Screening evidence cannot modify the article.

## Diagnosis

The remaining objective is not a global Q-DESN specification. It is a separate
calibration problem for every likelihood, family, quantile, and metric. Earlier
work already covered depth 1--4, large state spaces, input memory through 150,
alpha through 0.999, high rho, active recurrence, and RHS scales spanning
several orders of magnitude. Another Cartesian range expansion would repeat
failed work.

Fit rankings have transferred reasonably across development origins, while
forecast rankings have not. Candidate selection therefore uses genuine MCMC,
paired source blocks, fixed reservoir panels, and an untouched canonical-source
confirmation. VB may initialize MCMC but is never the promotion estimator.

## Targets

Tier A contains six immediate targets:

1. Q-DESN AL, Gaussian, p=0.05: fit RMSE, forecast MAE, and check loss.
2. exQ-DESN exAL, Laplace, p=0.05: fit RMSE.
3. exQ-DESN exAL, Gaussian mixture, p=0.25: forecast MAE.
4. exQ-DESN exAL, Gaussian mixture, p=0.05: fit RMSE.
5. exQ-DESN exAL, Gaussian, p=0.05: fit RMSE.
6. exQ-DESN exAL, Gaussian, p=0.25: forecast MAE.

Tier B contains the four AL fit-RMSE targets for Laplace and Gaussian mixture at
p=0.05 and p=0.25. Tier B cannot launch before Tier A closes. Median cells are
outside this campaign.

## Candidate contract

Each cell has its exact v6 metric parent plus eight new profiles:

- two local RHS-scale perturbations;
- one local readout-memory perturbation;
- one local input-memory perturbation;
- two active-recurrence multiscale mechanisms;
- two deterministic maximin designs from previously untried profile space.

The last two arms include high-alpha and capacity boundaries, but only as new
effective profile fingerprints. Every profile is checked against the complete
historical profile-signature ledger. Effective readout dimension is capped at
900 columns. Source, reservoir, and MCMC seeds are separate and predeclared.

## Stages

| Stage | Evidence | Maximum roots | Budget |
|---|---|---:|---:|
| Smoke | one AL and one exAL path | 2 | 4 + 4 |
| Runtime calibration | one representative root per Tier-A cell | 6 | 200 + 500 |
| Tier-A discovery | 8 candidates + parent, 6 cells, 2 sources | 108 | 1,000 + 3,000 |
| Tier-A replication | 3 candidates + parent, 6 cells, 1 new source | 24 | 1,000 + 3,000 |
| Tier-A sealed | 2 candidates + parent, 6 cells, 4 sealed sources | 72 | 1,000 + 3,000 |
| Canonical confirmation | one candidate per eligible metric, 3 chains | at most 24 | 5,000 + 20,000 |

Discovery ranks every declared target metric. A multi-metric cell advances the
union of its metric leaders, then fills remaining slots by robust worst-ratio
score. Mean and median paired improvements are reported separately.

## Promotion and stopping rules

A metric may be promoted for any strictly positive confirmed gain when all
three full-budget chains are finite and both their mean and median beat v6.
Diagnostic grades are reported but are not metric vetoes. Implementation
failure, nonfinite evidence, contract mismatch, provenance failure, or retained
forbidden payloads are hard vetoes.

The article continues to expose its metric-source envelope and must also retain
`metric_source_mixed`. A separate coherent-cell audit records the performance
of one specification on all three metrics. Posterior output is never recycled
into an undisclosed prior; warm starts may initialize a chain without changing
its posterior target.

If no candidate survives replication and sealed evaluation for a cell, that
cell closes as a negative result. Repeated canonical transfer failure closes
the search rather than triggering another nominally broader grid.

## Execution and storage

Each fit uses one operating-system thread. The launcher may use at most 20
dynamically selected idle CPUs and waits rather than oversubscribing the host.
Progress is emitted every 50 MCMC iterations; resource heartbeat and stale
evidence are recorded every 30 minutes.

Successful jobs retain scalar fit and forecast metrics, compact rolling paths,
status, logs, configuration, and hashes. Routine `.rds`, `.rda`, and `.RData`
fit payloads are deleted immediately under the declared storage policy. Every
stage is resumable by run tag and configuration hash.

## Prelaunch qualification

The deterministic materialization contains 10 targets, 10 exact v6 parent
controls, 80 new candidates, and 9,268 excluded historical signatures. The
candidate ledger has no historical overlap. It spans depth 1--4, input memory
1--150, alpha 0.00075--0.999, rho 0.10--0.995, RHS scales approximately
`1e-8`--`1e-3`, and effective readout dimension 11--898. The seven development
source blocks use 42 distinct latent/noise seeds. Their materialized registry
SHA-256 is
`db1323f4d9a4b3d5a93c08e675e39f8a5320cf7bf2ed1c03e4f0f2210fdb9411`;
this registry is development evidence and does not replace the canonical
article source identity stated above.

The prelaunch smoke run tag is `qdesn-ltcv1-precommit-smoke-20260811`. Its AL
and explicit exAL-M0 roots both completed, emitted finite fit and rolling-origin
forecast metrics, passed all 19 runtime checks, and retained no `.rds`, `.rda`,
or `.RData` payload. The focused campaign tests and the inherited M0 dispatch,
rolling-grid/state, source registry/window, artifact, storage, stage-filtering,
and shared-interface suites passed under R 4.6.0.

The repository-wide 160-file test directory was also executed. It is not green
at the immutable base: legacy synthesized-benchmark and VB simplification-ladder
tests fail in the current host environment, and several historical-result tests
warn or skip when their old local artifacts are absent. The two failing test
files were rerun without modification in the clean base worktree at
`5a4e6ed210bd113d2d0459c6f6b47cde6439ffcb` and reproduced the same failures.
They are therefore recorded as inherited baseline debt, not waived campaign
regressions. The new campaign, its inherited inference path, and its actual AL
and exAL-M0 smoke roots remain fully green.

## Operator workflow

Launch only from the clean, synchronized campaign branch:

```bash
WORKERS=20 \
  validation/fitforecast_v2/scripts/launch_qdesn_lower_tail_cellwise_mcmc_v1.sh
```

The launcher records its tmux session, run ID, run tag, state root, and stdout
log. It waits for the resource gate, dynamically pins one thread per worker to
20 idle CPUs, runs smoke, runtime calibration, and Tier-A discovery in order,
then materializes the 24-root replication plan and stops. It does not launch
replication, sealed evaluation, canonical confirmation, Tier B, or article
promotion automatically.

For a live stage, use the run tag and plan recorded under the state root:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_qdesn_lower_tail_cellwise_mcmc_v1.R \
  --run-tag RUN_TAG \
  --plan PLAN.csv \
  --output HEALTH.csv
```

Relaunching the pipeline with the same run ID and run tag is the supported
resume path: completed roots with matching configuration hashes are skipped.
Every pipeline error records the active stage, nonzero exit code, and log
location in `stage_status.csv` before the tmux session exits.

## Tier-A discovery closeout and replication handoff

The discovery run
`qdesn-lower-tail-cellwise-mcmc-v1-tiera-20260811_215538__git-c050ccf`
completed 108 of 108 roots on 2026-08-12. All required metrics were finite,
all job configuration hashes matched, and all roots satisfied the storage-light
contract. The closeout generated a 24-root replication plan containing three
cell-specific candidates plus the exact parent for each of six Tier-A cells.
Replication uses the untouched `dev11` source and independent reservoir seed
panel `r02`.

The original discovery launcher emitted a false terminal failure after valid
completion because its final informational message was passed to `cat` as a
filename. The message now uses `printf`, and the replication continuation has a
focused handoff verifier plus an error trap that cannot append a second failure
after successful completion. The historical terminal row is retained as audit
evidence; it does not invalidate the discovery gate.

Replication is launched separately and remains resumable under the original
run tag:

```bash
WORKERS=20 \
  validation/fitforecast_v2/scripts/launch_qdesn_lower_tail_cellwise_mcmc_v1_replication.sh
```

The continuation verifies the 108-root discovery gate, candidate-parent sets,
source role, reservoir seed, MCMC budget, package version, rolling-origin
contract, configuration hashes, branch, clean synchronized worktree, storage
policy, and resource availability before fitting. It runs only the 24
replication roots and then materializes, but does not launch, the 72-root sealed
plan. Article promotion remains disabled until sealed evidence and canonical
confirmation satisfy their predeclared gates.

## Tier-A replication closeout and sealed handoff

The replication continuation completed 24 of 24 roots on 2026-08-12 using the
untouched `dev11` source and reservoir panel `r02`. Runtime verification passed
all 19 checks: every required metric was finite, every configuration hash
matched, and every root retained zero forbidden binary payloads. The adaptive
closeout selected two cell-specific finalists per Tier-A cell and materialized
the 72-root sealed plan with SHA-256
`858583d81515c0560cbf530ae39591bd5b71656879c4d1f6565fab8965d4b5ee`.

The campaign has two explicit provenance layers. Commit
`c050ccf5838ad4bb448f75365b7d220a5646d565` freezes the statistical design,
candidate profiles, source contract, model worker, and discovery run tag.
Commit `c237ea5757cb920f66b6c7a574f1119137ba5260` begins the verified continuation
orchestration layer; it does not change the computational kernel. The sealed
handoff records both the frozen design commit and the actual sealed execution
commit and refuses execution if any intervening change leaves the scoped
campaign documentation, launchers, verifiers, or focused test paths.

The sealed panel contains each cell's two finalists plus its exact parent on
each of `dev12`, `dev13`, `dev14`, and `dev15`, using independent reservoir
panel `r03`. The complete panel is retained even for weak replication cells:
these untouched holdouts adjudicate source reversals and provide predeclared
negative closure without post-replication pruning.

Launch the sealed-only continuation from a clean synchronized branch:

```bash
WORKERS=20 \
  validation/fitforecast_v2/scripts/launch_qdesn_lower_tail_cellwise_mcmc_v1_sealed.sh
```

The launcher verifies the replication gate, sealed source isolation,
candidate-parent sets, observed-data and configuration hashes, dual provenance,
MCMC and rolling-origin contracts, explicit exAL M0 dispatch, one-thread
execution, storage policy, and resources. It runs only the 72 sealed roots,
then computes metric-specific eligibility and writes a blocked canonical
confirmation manifest. It never launches canonical confirmation, Tier B, or
article promotion.

The frozen source-generation directories retain their declared `sim_output.rds`
archives as reproducibility inputs. Sealed jobs consume only the hashed staged
CSV windows. The storage-light prohibition applies to routine fitted-model and
forecast payloads under job roots; source archives are never classified as
disposable model output.

A sealed metric is eligible only when its paired mean and median ratios are
both below one and at least three of four sealed sources improve on the exact
parent. At most one candidate per cell and metric enters confirmation. The
confirmation manifest remains capped at 24 chains, uses 5,000 burn-in plus
20,000 retained iterations, records `launch_approved = FALSE`, and requires
explicit human approval plus canonical-source materialization.

## Tier-A sealed closeout

The sealed continuation completed 72 of 72 roots on 2026-08-12. Together with
smoke, runtime calibration, discovery, and replication, the campaign completed
212 of 212 pre-confirmation roots with no implementation failure. All 72 sealed
roots emitted finite required metrics, matched their configuration hashes, and
retained zero fitted-model `.rds`, `.rda`, or `.RData` payloads. The sealed
runtime verifier passed all 19 checks. The 72 roots consumed 26,831.8 aggregate
worker-seconds; elapsed time per root ranged from 222.5 to 534.5 seconds, with a
363.0-second median.

Only two metric-specific candidates met the predeclared sealed rule:

| Cell | Candidate | Metric | Mean ratio | Median ratio | Sources improved |
|---|---|---|---:|---:|---:|
| exAL, Laplace, p=0.05 | `ltcv1_exal_laplace_t0p05_04_bf3258e079` | fit RMSE | 0.999011 | 0.981572 | 3/4 |
| exAL, Gaussian, p=0.25 | `ltcv1_exal_normal_t0p25_01_cc39679de2` | forecast MAE | 0.937345 | 0.989068 | 3/4 |

The Laplace candidate is a shallow local input-memory design (`D=1`, `n=12`,
`m=15`, `alpha=0.0035`, `rho=0.45`, and `tau0=3e-4`). Its mean gain is only
0.099 percent and its worst source ratio is 1.0584, so it is eligible but
fragile. The Gaussian p=0.25 candidate is a shallow local RHS-scale design
(`D=1`, `n=6`, `m=1`, `alpha=0.65`, `rho=0.70`, and `tau0=3e-5`). Its mean
forecast-MAE gain is 6.27 percent, although its median gain is 1.09 percent and
its worst source ratio is 1.0227. The other six target metrics produced no
sealed-eligible candidate. In particular, neither Gaussian-mixture forecast
candidate transferred: their mean paired ratios were 1.5394 and 1.1508.

This is a negative closure for broad Tier-A screening, not evidence for another
unbounded search. Most discovery and replication leaders did not transfer to
four untouched sources, and larger or more complex reservoir arms did not
generalize reliably. The two surviving metric candidates proceed only to the
small canonical confirmation gate; all other Tier-A searches stop.

The closeout generated exactly six disabled confirmation rows: three chains for
each surviving metric candidate, each with 5,000 burn-in and 20,000 retained
iterations. The manifest records `launch_approved = FALSE` and
`explicit_human_approval_and_canonical_source_materialization`; no confirmation
chain has been launched. Promotion v6 and the article therefore remain frozen.

Authoritative closeout evidence is under:

```text
reports/shared_fitforecast_v2_orchestration/
  qdesn_lower_tail_cellwise_mcmc_v1_tiera_20260811_215538/
```

The principal evidence hashes are:

| Artifact | SHA-256 |
|---|---|
| `adaptive/tier_a_sealed_eligible_metrics.csv` | `e7e88a212bf4a31dee7660c0f0edb02da012cca85e79fb3114eec51a4041be20` |
| `adaptive/tier_a_confirmation_manifest.csv` | `d3ba5c2ec08cb448ff805717953606fd3cff22fc06a8eb453c82d0b73c1d0d29` |
| `tier_a_sealed_verification.json` | `1150940a1319d9722365894de9ecff5fc12a00d8fbabb8204f37e4b5084ccb1b` |
| `adaptive/advance_after_tier_a_sealed.json` | `a1fa4f7429cf6247ba0aab473440b672ebccdcd6c6f528442ecf1061ff58a3d5` |

The run used frozen design commit
`c050ccf5838ad4bb448f75365b7d220a5646d565` and sealed execution commit
`6e30319f73a82832241d1b52c8b9e910bdfc985d`. Its job roots contain no
forbidden binary payloads. The 126 `sim_output.rds` files under
`source_replicates/` are hashed source-generation archives, not fitted-model
outputs; they remain required for source provenance and must not be pruned as
routine campaign payloads.
