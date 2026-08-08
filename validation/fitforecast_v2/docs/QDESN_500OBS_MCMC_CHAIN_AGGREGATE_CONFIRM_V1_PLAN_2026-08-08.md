# Q-DESN 500-Observation MCMC Chain-Aggregate Confirmation V1

Date: 2026-08-08
Package: `exdqlm` 1.0.0
Lane: independent single-quantile Q-DESN/DQLM validation only

## Decision Problem

The sparse-topology screen found lower individual-chain metric values, but its
21-fit confirmation showed that none of the six promoted minima replicated
under the predeclared two-of-three plus median rule. The completed fits are not
failed fits; they reveal material Monte Carlo variability in the posterior point
paths. Repeating the same alpha/rho screen would search the same noisy lower
envelope and is therefore not the next experiment.

This stage asks a different, predeclared question: can independent-chain point
paths be combined into a stable estimator that improves the current Normal,
`tau = 0.25`, MCMC authority? It first mines all 168 discovery chains and 21
confirmation chains. It then launches fresh chains only for promising designs
that currently have two chains.

## Estimator Contract

The estimator is named
`median_of_chain_posterior_point_paths_v1`. At each aligned training index it
takes the coordinatewise median of the chain-specific posterior point estimate
`q_pred`. At each aligned rolling-origin `(origin, lead, target)` tuple it takes
the coordinatewise median of chain-specific `qhat`. Fit RMSE, forecast MAE
against the true quantile, and forecast check loss against the observation are
then recomputed from these combined paths.

This estimator is not concatenation of retained posterior draws, because the
storage-light campaigns intentionally did not retain those draws. It must not
be described as exact posterior pooling. A two-chain aggregate is discovery
evidence only; at least five independent chains are required for confirmation
eligibility.

## Frozen Inputs

The source contract and exact hashes are in
`config/validation/qdesn_mcmc_chain_aggregate_v1.yaml`. Inputs are limited to:

1. the complete 168-chain sparse-topology discovery closeout;
2. the complete 21-chain sparse-topology confirmation closeout;
3. the immutable v3 72-row article interface;
4. the frozen source registry hash
   `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.

All source metric files, fit paths, and rolling-origin forecast paths are hashed.
Path alignment, source windows, finite values, and design invariants are hard
failures. Diagnostic PASS/WARN/FAIL grades remain reported but do not select
finite metrics.

## Selection and Confirmation

The audit computes all 84 exact design aggregates and their Pareto status within
likelihood. A design with only two chains can enter a follow-up only when it is
Pareto-nondominated and improves at least two of the three current authority
metrics. At most two designs per likelihood are selected. Three fresh chains
are then added so every selected design is evaluated by five independent chains.

Fresh-chain confirmation keeps the original statistical protocol: Normal,
`tau = 0.25`, training indices 8501--9000, forecast block 9001--10000, leads
1--30, stride 30, no refit, regularized horseshoe prior, 5,000 burn-in draws,
20,000 retained iterations, 200 metric draws, and one CPU thread per fit.

No article update is automatic. Promotion requires a complete five-chain
aggregate, strict improvement over the frozen authority for the affected
metric, exact provenance, and a separate article-safe review.

## Completed Historical Audit

The reproducible audit at
`reports/qdesn_mcmc_chain_aggregate_v1/audit_20260808` read 189 complete source
chains spanning 84 exact designs. It found seven designs with five chains and
77 designs with two chains. All source paths aligned exactly; all 189 execution
contracts passed; and the source campaigns retained no forbidden model
payloads.

The existing five-chain evidence confirms that chain aggregation is materially
different from selecting a single-chain minimum. The exAL design
`strv1_exal_w01_seed910010_p02`, for example, has aggregate fit RMSE 1.3710,
forecast MAE 2.5151, and forecast check loss 3.3225, improving all three frozen
exAL authority metrics. Existing AL five-chain designs improve fit RMSE but not
the current forecast authority, which is why fresh work remains focused on the
four two-chain Pareto designs below.

| Likelihood | Exact design | Selection role | Two-chain fit RMSE | Forecast MAE | Forecast check |
|---|---|---|---:|---:|---:|
| AL | `strv1_al_w03_seed1110003_parent` | forecast-MAE anchor | 2.0156 | 2.2163 | 3.3018 |
| AL | `strv1_al_w02_seed1010003_p04` | fit-RMSE anchor | 1.9871 | 2.2761 | 3.3066 |
| exAL | `strv1_exal_w03_seed1110003_p06` | forecast-MAE anchor | 1.4349 | 2.3127 | 3.3054 |
| exAL | `strv1_exal_w02_seed1010003_p06` | fit-RMSE anchor | 1.3331 | 2.4769 | 3.3181 |

The final closeout evaluates an 11-design envelope: the seven already complete
five-chain designs plus these four designs after their three fresh chains. This
prevents a new result from displacing a stronger existing robust aggregate.

## Implemented Execution Contract

The materialized stage is
`qdesn_dynamic_fitforecast_v2_500obs_mcmc_chain_aggregate_confirm_v1`.
It contains 12 full-budget specs, one per fresh chain, and uses 12 workers with
one thread per fit. Fresh sampler replicates are numbered 3--5 and use unique
MCMC, RNG, VB warm-start, and synthesis seeds. The two historical chains remain
read-only and are referenced by exact hashes.

Prelaunch verification completed on 2026-08-08:

- historical aggregate audit: 189 chains, 84 designs, four-design follow-up;
- deterministic materialization: byte-identical across two runs;
- static contract verifier: 35/35 checks pass;
- dedicated chain-aggregate tests: 47 expectations pass;
- prepare-only: 12 selected specs and no model payloads;
- executable smoke: 2/2 AL/exAL fits with finite fit and H=1000 metrics;
- smoke retained `.rds`, `.rda`, or `.RData` payloads: 0;
- article update: not performed.

## Storage and Failure Policy

The audit retains CSV/JSON summaries, source hashes, and compact path
provenance. Follow-up fits retain scalar metrics, compact paths, logs, manifests,
status, and telemetry. Routine `.rds`, `.rda`, and `.RData` payloads are
forbidden after each successful or failed root. Existing source paths are read
in place and are never copied or modified.
