# Q-DESN Train-Only Follow-up v1 Preflight

## Verdict

The 40-root follow-up is ready to launch from the dedicated validation branch
after commit and push. The campaign contains 36 Q-DESN roots and four matched
DQLM/exDQLM comparator roots. It does not modify the exdqlm 1.0.0 package
source, the article repository, or any 5,000-observation campaign.

## Corrected Execution Architecture

The first materialization placed the frozen article source and the untouched
`dev04` source in the same AL execution bundle. That representation was invalid
for the existing runner: before reading a checked-in grid, the runner rebuilds
and validates a canonical grid from one `dynamic_root`. The checked-in mixed
grid therefore could not equal its one-root canonical grid.

The scientific design was preserved and the execution contract was corrected:

| Experiment | Bundle | Source scope | Roots | Budget |
|---|---|---|---:|---:|
| AL confirmation | `al_raw` | frozen article | 6 | 5,000 + 20,000 |
| AL confirmation | `al_raw_dev04` | untouched `dev04` | 6 | 5,000 + 20,000 |
| AL confirmation | `al_sr` | frozen article | 3 | 5,000 + 20,000 |
| AL confirmation | `al_sr_dev04` | untouched `dev04` | 3 | 5,000 + 20,000 |
| exAL diagnostic | `exal_gsg_matched` | development `dev01`--`dev03` | 6 | 1,000 + 3,000 |
| exAL diagnostic | `exal_gsg_dense` | development `dev01`--`dev03` | 6 | 1,000 + 3,000 |
| exAL diagnostic | `exal_gsg_multistart` | development `dev01`--`dev03` | 6 | 1,000 + 3,000 |
| structured comparator | article + `dev04` | DQLM and exDQLM | 4 | 5,000 + 20,000 |

The AL closeout still pairs candidates and parents by source scenario and
reservoir seed, then aggregates six paired replicates per candidate arm. The
source split changes execution topology only.

## Frozen Source Contract

- Package source: exdqlm 1.0.0 loaded from this worktree.
- `TT_warmup = 2000`, `TT_main = 10000`, and `TT_total = 12000`.
- Training source indices: 8501--9000.
- Forecast origin: source index 9000.
- Forecast block: source indices 9001--10000.
- Maximum rolling lead: 30; origin stride: 30; no refit per origin.
- Frozen article registry identity:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.
- Untouched `dev04` registry SHA-256:
  `487a7f2d238df7d5e49a56b1e9d257d785e40e6f7fc98fc1ddddec78dad1934a`.
- Completed development registry SHA-256:
  `af83f8704ca330a7d0fb7296c2cd8c4f9bf42b09c79851e2c75303de88a8b1e9`.

The verifier recomputed the source-file hashes for all five scenario rows. No
active campaign path uses `/home/jaguir26/local/src`; that string appears only
inside the explicit stale-path rejection guard.

## Preflight Evidence

All checks used `/data/jaguir26/local/opt/R/4.6.0/bin/Rscript`.

| Check | Result |
|---|---|
| Source package load | PASS; R 4.6.0, exdqlm 1.0.0 |
| Materialized contract verifier | PASS; 7 bundles, 36 Q-DESN roots, 5 source rows |
| Dedicated follow-up test file | PASS |
| Complete `validation/fitforecast_v2` testthat directory | PASS |
| Shell syntax for pipeline and launcher | PASS |
| Q-DESN prepare-only | PASS, 7/7 bundles |
| Q-DESN smoke | PASS, 7/7 bundles |
| Structured comparator dry run | PASS, 4/4 rows |
| Structured comparator smoke | PASS, DQLM and exDQLM on both sources, 4/4 metrics |
| Forbidden fitted-model payloads in smoke output | PASS, 0 files |
| Article update | DISABLED |

The complete validation testthat directory covers the artifact schema, atomic
specification IDs, rolling grid, forecast horizon API, source registry and
window contracts, stage filtering, shared interface schema, storage policy,
telemetry, and the follow-up-specific contract. Package-wide historical tests
contain inherited baseline debt unrelated to this campaign; the launch gate is
the source-loaded package check plus the complete validation harness, and no
package source was changed to mask that debt.

Exact primary commands:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_trainonly_followup_v1.R \
  --no-source-refresh

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_trainonly_followup_v1.R

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'testthat::test_dir("validation/fitforecast_v2/tests/testthat", reporter="summary")'
```

Prepare-only and smoke evidence is under:

`reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_followup_v1/preflight_20260805/`

## Storage and Failure Semantics

Prepare and smoke outputs contain no `.rds`, `.rda`, `.RData`, or
`.ffv2handoff` fitted-model payloads. Three `.rds` files remain under the
campaign source tree, totaling 487,984 bytes; these are the declared `dev04`
source bundle and its staged source windows, not model fits. They are required
for source reproducibility and are retained.

The full pipeline records stage transitions, 30-minute heartbeats, child logs,
per-root statuses, progress every 50 MCMC iterations, missing roots, metric
completeness, source and artifact hashes, and a final storage audit. Finite
metrics and diagnostic status are retained independently. Any child failure
produces `COMPLETED_WITH_FAILURES`; it cannot silently promote a candidate.

## Launch and Closeout Gates

The launcher requires the exact branch
`validation/qdesn-trainonly-followup-v1-1.0.0`, a clean worktree, an upstream,
and zero ahead/behind divergence. It allocates at most 28 single-threaded
workers across disjoint CPU sets. It reruns contract verification,
prepare-only, all Q-DESN smokes, both DQLM/exDQLM smokes, and resource gates
before entering full compute.

The closeout can identify an AL confirmation candidate, but article updates
remain disabled. The exAL sampler experiment is diagnostic only and requires a
later full-budget confirmation before any article-facing decision.
