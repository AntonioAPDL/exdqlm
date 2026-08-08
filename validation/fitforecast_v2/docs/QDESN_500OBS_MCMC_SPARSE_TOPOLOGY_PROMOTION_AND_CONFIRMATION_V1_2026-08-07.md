# Q-DESN 500-Observation MCMC Sparse-Topology Promotion and Confirmation V1

Date: 2026-08-07
Package: `exdqlm` 1.0.0
Implementation branch: `validation/qdesn-mcmc-sparse-topology-confirm-v1-1.0.0`
Lane: independent single-quantile Q-DESN/DQLM validation only

## Objective

Freeze the six finite metric improvements found by the completed sparse-topology
refinement, expose them through one immutable 72-row article interface, and test
whether the exact responsible designs repeat under three fresh full-budget MCMC
replicates. This is a confirmation campaign, not another parameter screen.

The article update and the confirmation launch are deliberately separated:

1. The v3 interface records the best observed finite metric values with exact
   source hashes and diagnostic grades.
2. The confirmation campaign tests repeatability against that frozen v3
   authority.
3. Confirmation results cannot modify the article automatically.

## Completed Evidence Audit

The source campaign was:

- worktree:
  `/data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_sparse_topology_refine_v1_1p0p0`;
- branch: `validation/qdesn-mcmc-sparse-topology-refine-v1-1.0.0`;
- commit: `acfa0b4a4b989cd3722ebdde378a9f6b47401652`;
- run tag: `qdesn-strv1-full-20260807_045131__git-acfa0b4`;
- result: 168/168 complete, 144/144 exact candidate-parent pairs, zero
  failed roots, and zero retained `.rds`, `.rda`, or `.RData` payloads.

The immutable source closeout is:

`/data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_sparse_topology_refine_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/qdesn_mcmc_sparse_topology_refine_v1_20260807_045131/closeout`

No single source run improved fit RMSE, forecast MAE, and forecast check loss
simultaneously. The article uses its established case-and-metric-specific
envelope policy, so each lower finite metric is frozen independently. Diagnostic
status remains in the provenance record and is not a metric-exclusion rule.

## Immutable V3 Promotion

Promotion directory:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v3_20260807`

Authoritative interface:

`qdesn_dqlm_500obs_trainonly_article_v3_20260807_interface.csv`

Interface SHA-256:

`90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393`

Source registry identity:

`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

The six promoted Normal, `tau = 0.25`, MCMC values are:

| Model | Metric | V2 | V3 | Exact source design |
|---|---|---:|---:|---|
| Q-DESN AL-RHS | Fit RMSE | 2.182784 | 2.176359 | `strv1_al_w01_seed910020_p04` |
| Q-DESN AL-RHS | Forecast MAE | 2.481148 | 2.361033 | `strv1_al_w01_seed910020_p04` |
| Q-DESN AL-RHS | Forecast check loss | 3.314114 | 3.296627 | `strv1_al_w01_seed910010_parent` |
| Q-DESN exAL-RHS | Fit RMSE | 1.732552 | 1.709534 | `strv1_exal_w01_seed910010_parent` |
| Q-DESN exAL-RHS | Forecast MAE | 2.858278 | 2.708697 | `strv1_exal_w01_seed910010_p02` |
| Q-DESN exAL-RHS | Forecast check loss | 3.335098 | 3.332522 | `strv1_exal_w03_seed1110003_p05` |

The promotion script verifies the source closeout hashes, freezes each metric
bundle, updates exactly six cells in the 72-row interface, rewrites provenance
to the sparse-topology branch/commit/run, and produces deterministic manifests.
The independent promotion verifier passes and a second materialization was
byte-identical.

## Why the Confirmation Design Is Narrow

The 168-fit campaign already answered the broad mechanism question. Repeating
another broad screen would spend MCMC compute on designs that cannot affect the
current authority. The remaining uncertainty is sampler repeatability.

Seven unique designs are therefore sufficient:

| Target | Role | D | n | m | alpha | rho | pi_w | seed | tau0 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| AL | promoted check parent | 1 | 6 | 1 | 0.00075 | 0.35 | 1/36 | 910010 | 3e-4 |
| AL | matched parent | 1 | 6 | 1 | 0.00075 | 0.35 | 1/36 | 910020 | 3e-4 |
| AL | promoted fit/MAE candidate | 1 | 6 | 1 | 0.40 | 0.35 | 1/36 | 910020 | 3e-4 |
| exAL | promoted fit parent / p02 control | 1 | 6 | 1 | 0.00075 | 0.35 | 1/36 | 910010 | 3e-4 |
| exAL | promoted MAE candidate | 1 | 6 | 1 | 0.65 | 0.70 | 1/36 | 910010 | 3e-4 |
| exAL | matched parent | 1 | 6 | 1 | 0.00075 | 0.35 | 3/36 | 1110003 | 3e-4 |
| exAL | promoted check candidate | 1 | 6 | 1 | 0.80 | 0.70 | 3/36 | 1110003 | 3e-4 |

Each design receives three fresh sampler replicates, numbered 3, 4, and 5.
Candidate-parent pairs share the source, reservoir seed, and execution seeds
within replicate. Across replicates, MCMC, RNG, VB warm-start, and synthesis
seeds are fresh. This yields 21 fits and nine exact candidate-parent pairs.

## Frozen Statistical Protocol

- family: Normal;
- quantile: 0.25;
- effective training size: 500;
- training source indices: 8501--9000;
- forecast origin: 9000;
- forecast block: 9001--10000;
- maximum lead: 30;
- origin stride: 30;
- no refit at rolling origins;
- observed lag-state updates enabled;
- prior: regularized horseshoe (`rhs_ns`);
- burn-in: 5,000;
- retained MCMC iterations: 20,000;
- metric draws: 200;
- progress cadence: 50 iterations;
- workers: 20;
- threads per fit: 1.

## Replication Decision Rule

For each of the six promoted model-metric-design combinations:

1. all three fresh metric values must be finite and contract-valid;
2. at least two of the three must be strictly lower than the frozen v3 value;
3. the median of the three must also be strictly lower than the frozen v3
   value.

This rule is intentionally stronger than observing one new minimum. Signoff and
diagnostic grades are reported but never remove finite values from the metric
comparison. Any article update remains a separate, manual, hash-verified
promotion.

## Staged Execution

The launcher enforces:

1. clean branch with matching upstream;
2. deterministic contract rematerialization with no git drift;
3. static contract verification;
4. prepare-only run with a forbidden-binary audit;
5. three-fit executable smoke with source/seed/budget checks;
6. resource gate;
7. 21-fit full confirmation on 20 idle CPUs;
8. progress-trace compaction;
9. storage audit;
10. closeout with execution, pair, replication, and promotion evidence.

Launch command:

```bash
validation/fitforecast_v2/scripts/launch_qdesn_mcmc_sparse_topology_confirm_v1.sh \
  /data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_sparse_topology_confirm_v1_1p0p0
```

Health command:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript --vanilla \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_mcmc_sparse_topology_confirm_v1.R
```

## Storage and Failure Policy

Successful roots retain scalar fit metrics, scalar rolling-origin forecast
metrics, compact path summaries, manifests, status, telemetry, and logs. They do
not retain routine model objects or draws. Failed roots also use
`retain_full_rds_on_failure = false`; enough status and log evidence is retained
for root-specific diagnosis and relaunch. A restart must target only missing or
contract-invalid specs.

## Article Integration

The authoritative article repository is
`/data/jaguir26/local/src/Article-Q-DESN---Version-2`. Integration is performed
from an isolated clean worktree and changes only article-safe config, generated
tables, the independent-validation figure, and manifests. The article builder
reports 72 rows, 36 VB rows, 36 MCMC rows, and nine tables. The article checker
passes, and the documented `pdflatex -> bibtex -> pdflatex x3` build completes
without undefined citations/references, fatal errors, overfull boxes, or rerun
warnings.

The confirmation campaign does not modify the article while it runs.

## Prelaunch Verification

Completed before the implementation commit:

- deterministic rematerialization: pass;
- static confirmation verifier: 35/35 checks pass;
- generated specs: 21/21;
- exact candidate-parent pairs: 9/9;
- prepare-only selected roots: 21/21;
- prepare-only fitted-model binary payloads: 0;
- executable smoke: 3/3 requests, fit summaries, and H=1000 summaries;
- executable smoke finite metric rows: 3/3;
- executable smoke retained binary payloads: 0;
- dedicated confirmation `testthat` expectations: pass;
- source-window, forecast-horizon, interface-schema, storage-policy,
  launcher-filter, topology, and external-confirmation regression tests: pass;
- article builder and checker: pass;
- article PDF build: pass with no unresolved citation/reference, fatal,
  overfull-box, or rerun warning.

## Terminal Closeout

The full confirmation completed on 2026-08-07 under run tag
`qdesn-strc1-full-20260807_182431__git-ea9d7ce`. The original pipeline reached
all 21 successful roots but its reporting step stopped before writing the gate
because it sourced a helper file that had never existed. No fit, metric, path,
or provenance artifact was missing. Commit `ffbc709` had already corrected the
progress telemetry; the subsequent closeout repair removes only that dead
import and adds an executable import regression.

Canonical post-hoc closeout evidence is stored under:

`reports/shared_fitforecast_v2_orchestration/qdesn_mcmc_sparse_topology_confirm_v1_20260807_182431/closeout`

The validated terminal counts are:

| Contract | Result |
|---|---:|
| Full-budget roots | 21/21 |
| Successful roots | 21 |
| Failed roots | 0 |
| Complete fit and forecast metric bundles | 21/21 |
| Execution-contract passes | 21/21 |
| Complete candidate-parent pairs | 9/9 |
| Replicated promoted metrics | 0/6 |
| New article metric winners | 0 |
| Retained `.rds`, `.rda`, or `.RData` payloads | 0 |

The terminal gate is
`CONFIRMATION_COMPLETE_PARTIAL_OR_NO_PROMOTED_METRIC_REPLICATION`. Fresh
replicate medians were 1.3--18.4 percent above the corresponding frozen v3
metric minima, and no promoted metric met the two-of-three plus median
replication rule. Accordingly, this campaign is closed, no roots should be
rerun, and no direct article update is justified from its individual-chain
results.

The completed evidence also motivates a separate follow-up question: whether a
predeclared robust multi-chain point estimator reduces the Monte Carlo
variability that produced the unstable single-chain lower envelope. That
question must be implemented and versioned independently; it cannot alter this
immutable closeout or silently replace the article estimator.
