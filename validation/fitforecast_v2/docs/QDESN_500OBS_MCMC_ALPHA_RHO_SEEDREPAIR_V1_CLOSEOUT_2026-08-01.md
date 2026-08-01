# Q-DESN 500-Observation MCMC Alpha/Rho Seed-Repair v1 Closeout

## Final State

The seed-repair campaign completed cleanly. It repaired the reservoir-seed propagation
defect without rerunning the 270-root coarse screen, executed the intended second
reservoir for 11 mechanically valid candidates and five exact parents, and combined
those results with the immutable paired seed-123 evidence.

| Check | Result |
|---|---:|
| Prepare-only | PASS |
| Two-seed executable smoke | PASS |
| Full roots | 48/48 SUCCESS |
| Executed seed contracts | 48/48 PASS |
| Missing / unexpected specs | 0 / 0 |
| Candidate-source-reservoir pairs | 66/66 complete |
| Retained `.rds`, `.rda`, `.RData` | 0 |
| Final decision | `FULL_BUDGET_HANDOFF_PREPARED` |
| Article update allowed | No |

## Reproducibility

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__qdesn_alpha_rho_cellwise_v2_1p0p0`
- Branch: `validation/qdesn-alpha-rho-cellwise-v2-1.0.0`
- Package version: `1.0.0`
- Seed-propagation implementation commit: `b56240bb798376ae39bece81a7cd53bfa42ff8f4`
- Launch commit: `da7212c0a6c98e9c8a67234fc2f124f20c49612c`
- Run ID: `qdesn_alpha_rho_seedrepair_v1_20260801_192732`
- Full run tag: `qdesn-arsr1-full-20260801_192732__git-da7212c`
- Workers: 12, with one computational thread per worker
- Source registry SHA-256:
  `07e5f3b11cccd01c5c69ba8ff4794d4d28f583b9c5e8aba8b9dbc953fe862444`
- Orchestration state:
  `reports/shared_fitforecast_v2_orchestration/qdesn_alpha_rho_seedrepair_v1_20260801_192732`
- Audit gate:
  `reports/shared_fitforecast_v2_orchestration/qdesn_alpha_rho_seedrepair_v1_20260801_192732/audit/seedrepair_gate.json`

The materialized grid contains 48 atomic specs. Candidate and exact-parent runs share
MCMC, RNG, VB warm-start, and synthesis seeds within each cell/source pair; reservoir
seeds differ only across the two declared reservoir replicates. The executable audit
verified the expected and observed seed values from every `fit_request.json`.

## Candidate Audit

Ratios below compare each candidate with its exact parent over six paired
source-reservoir evaluations. Values below one favor the candidate. The 90th-percentile
column is the worst of the three metric-specific 90th-percentile ratios.

| Cell / candidate | Median fit | Median forecast MAE | Median forecast check | Worst q90 | Decision |
|---|---:|---:|---:|---:|---|
| AL Gaussian-mixture .05 / input-alpha .05 | 0.996 | 0.993 | 0.996 | 1.201 | no material gain |
| AL Gaussian-mixture .05 / input-alpha .02 | 1.012 | 0.981 | 0.988 | 1.056 | fit regression |
| AL Gaussian-mixture .05 / full alpha-rho .05 | 1.006 | 1.014 | 1.007 | 1.140 | dominated |
| AL Normal .05 / safeguard .04 | 0.961 | 0.948 | 0.999 | 2.399 | unstable forecast tail |
| AL Normal .05 / safeguard .05 | 0.991 | 0.966 | 1.009 | 1.774 | unstable forecast tail |
| exAL Gaussian-mixture .25 / full alpha-rho .02 | 0.980 | 0.925 | 0.987 | 1.192 | **handoff** |
| exAL Gaussian-mixture .25 / full alpha-rho .06 | 0.982 | 0.976 | 0.995 | 1.027 | misses 2% fit gate |
| exAL Gaussian-mixture .25 / input-alpha .09 | 1.060 | 0.982 | 0.993 | 1.096 | fit regression |
| exAL Laplace .05 / parent-alpha .01 | 0.980 | 1.001 | 0.986 | 1.154 | **handoff** |
| exAL Laplace .05 / parent-alpha .04 | 1.004 | 0.972 | 0.991 | 1.073 | misses fit objective |
| exAL Laplace .25 / input-alpha .05 | 1.007 | 0.998 | 0.999 | 1.100 | negative control only |

The exAL/Gaussian-mixture candidate has median absolute metrics of 2.572 fit RMSE,
4.419 forecast MAE, and 4.872 forecast check loss, versus 2.581, 5.296, and 4.959 for
its exact parent. The exAL/Laplace candidate has corresponding medians of 5.014,
5.193, and 1.692, versus 5.120, 5.338, and 1.732. Ratio medians, rather than ratios of
these displayed absolute medians, govern the frozen gate.

## Interpretation

The repair confirms that reservoir realization matters. Several favorable seed-123
coarse results weakened under the intended second reservoir. Most importantly, the
AL/Normal apparent median improvement is accompanied by a corrected replicate whose
forecast-MAE ratio is 2.399, so it is not robust enough for confirmation.

Both retained exAL candidates have diagnostic WARN/FAIL rows even though every root
completed and produced finite, domain-valid metrics. Diagnostic grades are retained as
metadata and were not used as a metric-exclusion rule in this development screen. They
are a reason to require the full-budget confirmation, not a basis for article promotion.

## Tests And Residual Risk

The focused seed-repair tests passed 28 expectations. Existing alpha/rho, launcher,
source-registry, source-window, forecast-horizon, artifact-schema, storage-policy,
stage-filtering, and shared-interface tests also passed. The pipeline self-test passed
with 12 workers, and the executable smoke proved that distinct declared reservoir seeds
produce distinct reservoir and compact fit-path hashes.

A repository-wide `testthat::test_local()` run still reports 64 failures in pre-existing
benchmark and VB-simplification fixtures. Those failures arise in unrelated historical
subprocess/fixture tests and do not exercise the changed grid-seed propagation path.
They remain a repository-level maintenance item and are not silently classified as
passing.

## Next Gate

The adjacent `qdesn_500obs_mcmc_alpha_rho_seedrepair_v1_full_budget_handoff_20260801.csv`
is the only approved input to a later confirmation materializer. That confirmation must
use 5,000 burn-in and 20,000 retained draws on the frozen article-protocol source at
forecast origin 9000. It must run candidate and exact parent with paired sampler seeds,
retain no routine binary payloads, and complete a strict metric and diagnostic closeout.
No confirmation compute was launched in this closeout.

The authoritative article remains unchanged. A later article update is permitted only
if full-budget evidence improves the current authoritative metric for the same exact
cell without a material regression in the other reported metrics.
