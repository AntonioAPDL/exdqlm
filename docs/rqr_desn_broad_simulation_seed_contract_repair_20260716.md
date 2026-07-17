# RQR-DESN Broad Simulation Seed Contract Repair

Date: 2026-07-16

Status: configuration repair only. This does not authorize launch, fitting, or
article updates.

## Summary

The original frozen broad simulation config remains the record of the scientific
surface, but its literal seed rule was under-specified for scenario expansion.
When expanded over stage, family, replicate, design, backend, prior, coverage,
and learning-rate axes, the rule produced only `540` unique seeds for `3312`
planned rows.

The repaired config is:

```text
config/rqr_desn/rqr_desn_broad_simulation_frozen_20260716_v2.R
```

The repair preserves the scientific surface and changes only the randomization
contract and config identity. The broad manifest materializer now uses the
canonical deterministic scenario order and assigns:

```text
seed = seed_base + scenario_index
```

This yields `3312` unique seeds for `3312` planned rows.

## What Did Not Change

- stages;
- DGP families;
- replicate counts;
- DESN designs;
- backends;
- priors;
- MCMC controls;
- VB controls;
- scoring contract;
- no-launch flag;
- no-article flag.

## Next Gate

Before any broad run, the no-fit preflight must materialize:

```text
reports/rqr_desn_broad_simulation/<preflight_tag>/scenario_manifest.csv
```

and verify exact row counts, unique scenario IDs, unique scenario hashes, unique
seeds, unique output paths, and the RQR no-response-likelihood contract.
