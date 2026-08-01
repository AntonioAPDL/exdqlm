# Q-DESN 500-Observation MCMC Alpha/Rho Seed-Repair v1

## Decision

The completed alpha/rho cellwise v2 campaign is retained as immutable evidence and
classified as `COMPLETE_WITH_REFINEMENT_SEED_CONTRACT_FAILURE`. All 309 scientific
roots completed, but the executable grids omitted the screening profile's reservoir
seed. The fit-config resolver consequently used the shared pilot seed `123` for every
reservoir, including rows labeled as the second reservoir replicate.

The 270-root coarse phase remains interpretable as a paired seed-123 screen because
each candidate and its frozen parent were evaluated on the same source and realized
reservoir seed. The 39-root refinement phase does not establish a second-reservoir
replication and cannot support promotion.

## Repair Scope

The repair does not rerun the broad screen. It carries forward the 13 coarse-selected
candidate designs and applies a mechanical topology gate at the seed that actually ran.
Two exAL/Laplace, `p=0.25`, parent-alpha candidates are excluded because both input and
recurrent connectivity are zero at seed 123. The remaining design is:

| Unit | Count |
|---|---:|
| Mechanically valid candidate designs | 11 |
| Exact parent controls, one per target cell | 5 |
| Corrected profiles on the intended second reservoir | 16 |
| Frozen development source trajectories per profile | 3 |
| Full repair roots | **48** |

This is the minimum experiment that can restore a genuine two-reservoir comparison:
three existing paired source results at actual seed 123 plus three newly paired source
results at the declared second reservoir seed.

## Seed Contract

The validation harness separates four sources of stochasticity:

1. `seed` is the run-level grid seed and remains stable for launch reproducibility.
2. `desn_seed` must equal `screening_profiles.seed` and alone identifies the realized
   reservoir weights and masks.
3. `mcmc_seed`, `mcmc_rng_seed`, and `vb_warm_start_seed` are fixed within each
   target-cell/source pair, so a candidate and its exact parent use common run-level
   random numbers.
4. `synthesis_seed` is also paired even though single-quantile synthesis is disabled.

Materialization must fail if a profile cannot be resolved, `desn_seed` differs from the
profile seed, any run-level seed is missing, or candidate and parent run-level seeds are
not identical within a source pair.

## Executable Stages

1. Materialize profiles, assignments, grids, atomic spec IDs, topology evidence,
   historical request forensics, and SHA-256 provenance.
2. Run prepare-only for all 48 full roots.
3. Run a two-root tiny-budget smoke using the same AL candidate under its declared first
   and second reservoir seeds.
4. Require the smoke requests to show distinct `config.desn.seed`, paired MCMC and VB
   warm-start seeds, distinct reservoir hashes, distinct compact fit-path hashes, and no
   binary payloads.
5. Pass CPU, memory, and disk resource gates.
6. Run the 48-root corrected second-reservoir campaign with one thread per root.
7. Require 48 complete metric records, 48 executed seed-contract passes, zero unexpected
   roots, and zero `.rds`, `.rda`, or `.RData` payloads.
8. Combine corrected pairs with the immutable seed-123 coarse pairs and compute six-pair
   cell-specific summaries. No global specification is selected.
9. Prepare, but do not automatically launch, a full-budget handoff for candidates that
   improve the cell's primary deficiency without material regression.

## Selection and Promotion

Development candidates require six complete source-reservoir pairs, two distinct
reservoirs, worst median ratio no greater than `1.03`, worst 90th-percentile ratio no
greater than `1.25`, and at least one median metric improvement of 2% or more relative
to the exact parent. Full-budget handoff is stricter and follows the target-cell role:

- fit-gap cells must improve median fit RMSE by at least 2%;
- joint fit/forecast-gap cells must improve fit RMSE and at least one forecast metric by
  at least 2%;
- the already-resolved exAL/Laplace `p=0.25` cell remains a robustness control and is not
  promoted merely for another small gain.

The handoff budget is 5,000 burn-in and 20,000 retained MCMC iterations on the frozen
article-protocol source at forecast origin 9000. No article table or figure is changed
from this development repair. Article promotion requires a later full-budget closeout.

## Storage and Failure Policy

Successful roots retain scalar fit and rolling-origin forecast metrics, compact path
tables, fit requests, manifests, progress traces, status rows, and logs. Routine binary
model objects are forbidden. A failed stage stops the pipeline and preserves its status,
logs, manifests, and compact evidence. Existing historical outputs are not modified or
deleted.

## Reproducibility Evidence

- Historical orchestration:
  `reports/shared_fitforecast_v2_orchestration/qdesn_alpha_rho_cellwise_v2_20260801_011245`
- Repair configuration prefix:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_seedrepair_v1`
- Materializer:
  `validation/fitforecast_v2/scripts/materialize_qdesn_alpha_rho_seedrepair_v1.R`
- Pipeline:
  `validation/fitforecast_v2/scripts/run_qdesn_alpha_rho_seedrepair_v1_pipeline.sh`
- Executable smoke verifier:
  `validation/fitforecast_v2/scripts/verify_qdesn_alpha_rho_seedrepair_smoke.R`
- Final repair auditor:
  `validation/fitforecast_v2/scripts/audit_qdesn_alpha_rho_seedrepair_v1.R`

All generated manifests record the package version, branch, commit, source-registry
hash, input hashes, expected counts, and exact evidence paths.

## Executed Outcome

Run `qdesn_alpha_rho_seedrepair_v1_20260801_192732` completed on 2026-08-01.
Prepare-only, the executable two-seed smoke, the resource gate, all 48 full roots, the
post-run storage gate, and the final audit completed successfully. The audit observed
48 complete metric specifications, 48 executed seed-contract passes, no missing or
unexpected specifications, and no retained binary payloads.

The decision is `FULL_BUDGET_HANDOFF_PREPARED`. Two cell-specific candidates satisfy
the development handoff rules, but neither is article-authoritative:

- exAL/Gaussian-mixture at `p=0.25`, candidate
  `arv2_exal_gausmix_t0p25_full_alpha_rho_p02`;
- exAL/Laplace at `p=0.05`, candidate
  `arv2_exal_laplace_t0p05_parent_alpha_p01`.

The exact closeout, evidence hashes, and confirmation handoff are recorded in
`QDESN_500OBS_MCMC_ALPHA_RHO_SEEDREPAIR_V1_CLOSEOUT_2026-08-01.md` and its adjacent
machine-readable files. The 5,000-burn-in/20,000-retained confirmation was deliberately
not launched, and no article table or figure was changed.
