# Q-DESN 500-Observation Train-Only MCMC Mechanism Calibration v1

## Decision

The next experiment is a small paired mechanism study, not another broad search
over reservoir size and scalar hyperparameters. Historical screens already span
depths 1--4, widths into the hundreds, lags through 150, broad alpha/rho ranges,
and regularized-horseshoe scales from roughly `2e-8` to `1e-3`. Repeating that
surface is not an efficient use of MCMC compute.

The corrected train-only audit also showed that the selected compact parents can
have no realized recurrent or input connections. This campaign therefore tests
active topology and decomposition-aware readout inputs while holding each
case-specific parent contract fixed.

## Scope

This work belongs only to the independent single-quantile Q-DESN/DQLM
fit-and-forecast validation lane. It does not modify or consume joint-QDESN,
GloFAS, PriceFM, or application code. It uses exdqlm `1.0.0` without changing
the package's inference kernels.

Priority cells:

| Cell | Corrected parent | Reason |
|---|---|---|
| AL, normal, `p=0.05` | `tor1_15_mcvbc_055_al` | fit and forecast gap |
| exAL, Gaussian mixture, `p=0.25` | `tor1_23_arfc1_parent_exal_gausmix_t0p25_r01_full_3ed` | fit and forecast gap |

Negative control:

| Cell | Corrected parent | Reason |
|---|---|---|
| exAL, Laplace, `p=0.25` | `tor1_28_mcvbc_045_exal` | already within the desired comparison range |

Selection is per family, quantile, and likelihood. There is no global reservoir
winner and no requirement that one specification work across cells.

## Experimental Design

Three new deterministic source trajectories are generated with the same DGP
contract as the article study but with new latent/noise seeds. They are
development evidence only. The frozen article trajectory is not touched and is
reserved for confirmation.

Each candidate is paired with its parent by:

- target cell;
- source trajectory;
- reservoir seed (`910001` or `910002`);
- MCMC/VB initialization policy;
- train-only preprocessing and rolling-origin forecast protocol.

The four bundles are:

| Bundle | Arms | Target cells | Specs |
|---|---|---:|---:|
| `raw` | parent, parent with active topology, compact active raw readout | 2 priority + parent-only control | 42 |
| `c12` | compact active component-lag decomposition, harmonics 1--2 | 2 priority + control | 18 |
| `c123` | compact active component-lag decomposition, harmonics 1--3 | 2 priority + control | 18 |
| `sr` | compact active state/residual/y-lag decomposition | 2 priority | 12 |
| **Total** |  |  | **90** |

The compact active design is `D=1`, `n=12`, `m=3`, `alpha=0.01`, `rho=0.60`,
with expected recurrent and input indegrees of two. The parent topology-repair
arm preserves each parent's `D/n/m/alpha/rho/tau0` while changing only
connectivity probabilities to expected indegrees of two.

## Protocol

- `TT_warmup = 2000`, `TT_main = 10000`, `TT_total = 12000`.
- Effective training target window: source indices `8501:9000`.
- Forecast origin: source index `9000`.
- Forecast block: source indices `9001:10000`.
- Rolling-origin maximum lead: 30; origin stride: 30; no refit per origin.
- Preprocessing scope: training rows only; no held-out responses or covariates
  enter scaling.
- Likelihood and prior: exact target likelihood (`AL` or `exAL`) with `RHS`.
- MCMC discovery budget: 1000 burn-in + 3000 retained draws, progress every 50.
- MCMC initialization: VB, maximum 150 iterations.
- Posterior metric draws: 100.

## Selection Gate

For every candidate, ratios are calculated against the same-cell, same-source,
same-reservoir parent. A full-budget confirmation candidate must have all six
paired metric triples and satisfy:

1. at least one median metric ratio no greater than `0.98`;
2. no median fit-RMSE, forecast-MAE, or forecast-check-loss ratio above `1.05`;
3. no worst metric q90 ratio above `1.10`;
4. stable negative-control behavior;
5. no unexpected binary payloads.

Diagnostic status is retained and reported. Finite metrics are not silently
discarded because a chain is marked `WARN` or `FAIL`, but diagnostic grades are
never hidden.

Discovery evidence cannot update the article. A surviving per-cell candidate
must be rerun with 5000 burn-in + 20000 retained draws on both the frozen article
source and one untouched fresh source, with matched DQLM/exDQLM comparators,
before article promotion.

## Reproducibility Surfaces

- Source contract:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_source_replicates.yaml`
- Overall manifest:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_materialization_manifest.json`
- Bundle index:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_bundle_index.csv`
- Parent freeze:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_parent_profiles.csv`
- Topology audit:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_topology_audit.csv`
- Non-repeat ledger:
  `config/validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_nonrepeat_ledger.csv`
- Contract verifier:
  `validation/fitforecast_v2/scripts/verify_qdesn_trainonly_mechanism_v1.R`
- Healthcheck:
  `validation/fitforecast_v2/scripts/healthcheck_qdesn_trainonly_mechanism_v1.R`
- Closeout scorer:
  `validation/fitforecast_v2/scripts/audit_qdesn_trainonly_mechanism_v1.R`

## Launch and Failure Policy

The launcher refuses a dirty, unpushed, behind, or wrong-branch worktree and
refuses a duplicate campaign session. It executes contract verification,
prepare-only, one tiny smoke per mechanism, a resource gate, then the four full
bundles concurrently on 16 dedicated cores. Heartbeats are written every 30
minutes; MCMC progress is emitted every 50 iterations.

Every bundle has its own log, run tag, exit code, storage audit, and status row.
One bundle failure does not terminate already-running sibling bundles. Closeout
runs after all bundle processes return and remains failure-explicit.

No automatic heavy-object retention is allowed. The campaign keeps scalar fit
and forecast metrics, compact path summaries, statuses, logs, configs, and
manifests. No article update or full-budget confirmation is launched
automatically.

## Implementation and Preflight Evidence

The campaign was materialized as 90 discovery specifications across the four
bundles. The frozen development-source registry is:

`reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1/materialization/source_registry.csv`

Its SHA-256 digest is
`af83f8704ca330a7d0fb7296c2cd8c4f9bf42b09c79851e2c75303de88a8b1e9`.
The checked-in contract verifier passed 79 of 79 assertions. All 24 new active
topology profiles passed the realized-topology gate; all six exact parent
realizations had zero active topology, which is the mechanism defect this study
is designed to isolate.

Preflight used R 4.6.0 and source-loaded exdqlm 1.0.0 from this worktree.
Package load passed through the same `pkgload::load_all(repo_root)` route used
by every campaign child. The focused testthat file and the complete 33-file
fitforecast-v2 test directory passed, and shell syntax checks passed for all
campaign scripts. Prepare-only and one-root smoke checks passed for every
bundle under these pre-commit tags:

- `qdesn-tmv1-raw-precommit-prepare-20260805` and
  `qdesn-tmv1-raw-precommit-smoke-20260805`;
- `qdesn-tmv1-c12-precommit-prepare-20260805` and
  `qdesn-tmv1-c12-precommit-smoke-20260805`;
- `qdesn-tmv1-c123-precommit-prepare-20260805` and
  `qdesn-tmv1-c123-precommit-smoke-20260805`;
- `qdesn-tmv1-sr-precommit-prepare-20260805` and
  `qdesn-tmv1-sr-precommit-smoke-20260805`.

Each smoke produced a successful status, fit summary, and rolling-origin
forecast summary without retaining model binary payloads. A closeout test over
those four roots returned `BLOCK_INCOMPLETE` at 4 of 90 specifications, which
is the expected failure-explicit result for an intentionally partial smoke.
The binary audit found exactly 54 declared source/window `sim_output.rds` files
(8,803,525 bytes) and zero fitted-model payloads.

## Scoped Legacy Cleanup

Before launch, a guarded dry run identified duplicate dense path/progress CSVs
only in the superseded origin-7000 and origin-8000 development campaigns. No
active process referenced either root. The exact hashed candidate set contained
7,946 files and 5,322,171,042 bytes (4.957 GiB); execution removed that exact
set and a postcondition check found zero eligible files remaining.

The cleanup retained source objects, final origin-9000 evidence, scalar fit and
forecast metrics, lead summaries, chain diagnostics, final progress traces,
statuses, failures, logs, manifests, promotion records, and every current
campaign artifact. The old roots still retain 2,166 fit summaries, 1,444
forecast-horizon summaries, 1,444 lead-metric tables, 2,166 chain summaries,
and 1,444 run manifests. Further deletion was deferred because it would remove
reproducibility evidence rather than redundant bulk output.

The classification, exact dry-run manifest, exact removal ledger, and summary
are tracked under:

`validation/fitforecast_v2/docs/qdesn_trainonly_mechanism_v1_cleanup_20260805/`

After cleanup, `/data` reported 600 GiB available and 31 percent utilization.
