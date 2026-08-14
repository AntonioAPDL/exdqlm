# Independent exQ-DESN post-M0 legacy recheck v1

## Decision

The next independent-validation campaign will re-evaluate exact promising
historical exQ-DESN designs with the production
`M0_v_collapsed_support_logit` MCMC transition. It will not launch another
undirected structural sweep and will not treat a pre-M0 exAL MCMC result as
negative evidence about its DESN specification or `tau0`.

This correction is necessary because the same-design M0 relaunch completed
45/45 chains and improved 22 of 27 metric roles. The historical sampler and
the DESN design were therefore confounded in earlier exAL MCMC screens.

## Frozen authority

| Contract | Value |
|---|---|
| Base shared-validation commit | `f7d57b17997bea461faf6f5bfc6213c33fa2fd1e` |
| Package | `exdqlm 1.0.0` under R 4.6.0 |
| Source registry hash | `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275` |
| Fit window | source indices 8501--9000 |
| Forecast window | source indices 9001--10000 |
| Rolling protocol | maximum lead 30, origin stride 30, no refit |
| Article authority | independent-validation v6, frozen during development |

Each target freezes both the exact v6 parent request and a one-row metric
evidence record that defines its current value, comparator, original source,
and original source hash. Campaign logic therefore
does not depend on an older auxiliary worktree remaining on disk.

## Evidence classes

1. Pre-M0 exAL MCMC is sampler-confounded. Exact designs may be rechecked;
   their old failures are not an exclusion rule.
2. Pre-M0 exAL VB is valid VB evidence and a candidate prior, but is not
   negative or confirmatory evidence for M0 MCMC.
3. Post-M0 exact MCMC is the primary comparable evidence. Exact signatures
   already tested after M0 are excluded from this campaign.
4. AL evidence is unaffected by the exAL transition change and is outside this
   campaign.

The frozen history contains 9,268 source-profile occurrences but only 2,398
unique exact signatures. Candidate exclusion is based on explicit post-M0
signature coverage, not on raw historical occurrence count.

The campaign uses the fresh source identifiers `dev30`--`dev36` and the
nonoverlapping seed range 1,830,011--1,836,032. Static verification compares
every latent and observation-noise seed with all earlier tracked source-seed
contracts. An initial dev16--dev22 draft was rejected before compute because
that namespace overlapped Tier-B; its generated sources were removed and were
never used for a fit.

## Targets and candidates

The five remaining exAL gaps are:

- Laplace, 0.05, fit RMSE;
- Gaussian mixture, 0.05, fit RMSE;
- Gaussian mixture, 0.25, forecast MAE;
- Gaussian, 0.05, fit RMSE;
- Gaussian, 0.25, forecast MAE.

Each cell receives eight exact historical designs. Up to five are selected
from the older VB all-primary-win ledger using deterministic
quality-and-diversity selection. Remaining slots are filled from ranked
pre-M0 exAL MCMC designs. Every candidate must be absent from explicit
post-M0 exact-signature coverage. The exact v6 metric source is run as a
paired parent control but is not counted among the eight candidates.

No decomposition, posterior-to-prior recycling, new likelihood, or package
kernel modification is allowed. This stage isolates the sampler-era question.

## Sequential design

| Stage | Sources | Candidate policy | Jobs | Budget |
|---|---:|---|---:|---:|
| Smoke | 1 | one candidate plus parent | 2 | 4 + 4 |
| Calibration | 1 | largest candidate per cell | 5 | 200 + 500 |
| Discovery | 2 | eight candidates plus parent per cell | 90 | 1,000 + 3,000 |
| Replication | 1 fresh | top three plus parent per cell | 20 | 1,000 + 3,000 |
| Sealed | 4 fresh | top two plus parent per cell | 60 | 1,000 + 3,000 |
| Canonical confirmation | canonical | at most one finalist per target metric, three chains | at most 15 | 5,000 + 20,000 |

Discovery, replication, and sealed comparisons are paired against the current
parent on identical source and reservoir panels. Sealed eligibility requires
finite storage-light outputs, mean and median paired ratios below one, and
improvement on at least three of four sealed sources. Canonical confirmation
requires explicit human approval and is never launched by the development
pipeline.

## Operational contract

- One OS process and one numerical thread per fit.
- At most 20 workers, selected only from CPUs passing the idle-core gate.
- Minimum 64 GB available memory and 80 GB available disk.
- Thirty-minute heartbeat and stale threshold.
- Same run tag resumes completed jobs by config hash.
- Every success and failure retains compact status, metrics, logs, hashes, and
  pruning metadata.
- No `.rds`, `.rda`, or `.RData` payload remains after a job or in dry-run
  materialization.

## Promotion rule

Development gains are candidate-selection evidence only. Article v6 remains
unchanged unless a full canonical three-chain confirmation produces a finite
strict improvement for the exact metric role. Diagnostic grades remain
reported, implementation failures remain vetoes, and article publication is
handled by the integration chat rather than this scientific lane.

## Launch boundary

The first launcher performs materialization, focused tests, static
verification, the resource gate, smoke, calibration, and discovery. It then
materializes a replication handoff and stops. Replication, sealed evaluation,
canonical confirmation, promotion, and article integration are separate,
reviewed decisions. The reviewed replication and sealed stages use
`launch_qdesn_postm0_legacy_recheck_v1_stage.sh`; that launcher preserves the
same run ID and run tag, enforces the same clean/upstream/resource gates, and
maintains the 30-minute heartbeat. It cannot launch canonical confirmation.

## Prelaunch verification

The prelaunch materialization is intentionally ignored runtime evidence under:

`reports/shared_fitforecast_v2_orchestration/qdesn_postm0_legacy_recheck_v1_precommit/materialization`

It records 40 candidates, five parent controls, two smoke jobs, five
calibration jobs, and 90 discovery jobs. The static verifier passed all 22
contracts, including history counts, exact-signature exclusion, source-seed
nonoverlap, protocol windows, exact M0 dispatch, one-thread execution, tracked
hashes, frozen parent evidence, and storage policy. The focused testthat file
passed 36 expectations
under R 4.6.0 and `exdqlm` 1.0.0.

The real prelaunch smoke tag is:

`qdesn-postm0-legacy-recheck-v1-smoke-prelaunch-20260814__git-f7d57b1`

Both the historical candidate and frozen v6 parent completed successfully.
Runtime verification passed all 27 checks, and no fitted-model binary payload
remained. These four-draw smoke metrics are plumbing evidence only and must
never enter ranking, promotion, or article tables.
