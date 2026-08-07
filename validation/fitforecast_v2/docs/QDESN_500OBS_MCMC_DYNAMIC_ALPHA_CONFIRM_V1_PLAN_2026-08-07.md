# Q-DESN 500-Observation MCMC Dynamic-Alpha Confirmation V1

## Decision

Run a prospective, full-budget MCMC confirmation of six exact designs mined from
the completed dynamic-seed discovery campaign. The confirmation is limited to
the two unresolved independent-model cells:

- Q-DESN AL-RHS, Normal family, `tau = 0.25`;
- Q-DESN exAL-RHS, Normal family, `tau = 0.25`.

This is a confirmation campaign, not another broad screen. It uses the frozen
article source, prospective sampler seeds, matched same-reservoir controls, and
the article MCMC budget. No article file is changed automatically.

## Why This Is The Next Experiment

The completed discovery campaign evaluated 240 screening-budget fits over three
development sources. It identified a small number of dynamic-reservoir designs
with improvements in at least one target metric. A full-budget confirmation is
needed because:

1. screening used 1,000 burn-in plus 3,000 retained draws;
2. the article protocol uses 5,000 burn-in plus 20,000 retained draws;
3. the article source is different from the three development sources;
4. MCMC performance is not assumed to be determined by VB performance;
5. metric promotion is case- and metric-specific, not based on one global DESN
   specification.

A scan of 407 prior Normal `tau = 0.25` article-source MCMC requests found no
exact execution of these candidate designs with the required dynamic DESN seeds.
Reusing older outputs would therefore not constitute confirmation.

## Frozen Inputs

Package:

- package: `exdqlm`;
- version: `1.0.0`;
- implementation parent: `b66a9ef3da7df3df984d3deace74ed270dce1b7a`.

Authority interface:

- path: `validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v1_20260805/qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv`;
- SHA-256: `dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a`.

Discovery evidence:

- campaign tag: `qdesn-dsr1-discovery-20260807_010512__git-b832aab`;
- path: `/data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_dynamic_seedrepair_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/qdesn_mcmc_dynamic_seedrepair_v1_20260807_010512/closeout/paired_frozen_authority_metrics.csv`;
- SHA-256: `fb561c286fbb120dc4f1f4ca6ac49fd03805673f10dbcc6a3e3e6274179dcaee`.

Frozen source:

- scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`;
- family: Normal;
- quantile: `0.25`;
- source registry identity: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`;
- `TT_warmup = 2000`, `TT_main = 10000`, `TT_total = 12000`;
- training target indices: `8501:9000`;
- forecast origin: `9000`;
- forecast block: `9001:10000`;
- rolling leads: `1:30`;
- origin stride: `30`;
- no refit at rolling origins; observed lag state is updated.

## Exact Candidate Designs

All candidates freeze `D = 1`, `n_each = 6`, `m = 1`, `rho = 0.35`,
`pi_w = 0.0025`, `pi_in = 0.05`, `rhs_tau0 = 3e-4`, one response lag,
zero reservoir lags, and the exact discovery reservoir seed.

| Likelihood | Alpha | DESN seed | Role |
|---|---:|---:|---|
| AL | 0.60 | 900124 | coherent all-metric discovery nominee |
| AL | 0.50 | 900132 | forecast/check specialist |
| AL | 0.55 | 900132 | source-specific reserve |
| exAL | 0.80 | 900132 | fit/check specialist |
| exAL | 0.70 | 900126 | forecast nominee |
| exAL | 0.85 | 900126 | source-specific reserve |

The exact frozen list, including discovery ratios and selection reasons, is:

`config/validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_alpha_confirm_v1_shortlist.csv`

## Topology Interpretation

The six candidates and four matched controls all have at least one active
non-bias dynamic input edge. They also have zero recurrent edges under the exact
frozen sparse topology. Consequently:

- `alpha` changes the state update and is an active mechanism;
- `rho` cannot change a zero recurrent matrix and is inert in this design;
- this campaign confirms dynamic-alpha transport, not an alpha/rho interaction;
- if exAL remains weak, the next mechanism experiment must require active
  recurrent topology before further `rho` tuning.

This limitation is recorded in the topology audit rather than hidden after the
run.

## Paired Confirmation Design

Four distinct controls are required because likelihood and DESN seed jointly
define the parent:

- AL, seed 900124;
- AL, seed 900132;
- exAL, seed 900132;
- exAL, seed 900126.

Each candidate and each distinct parent is run under three prospectively frozen
sampler replicates. Candidates sharing a likelihood and DESN seed reuse the same
parent fit within each sampler replicate.

Counts:

- six candidate designs;
- four distinct parent designs;
- three sampler replicates;
- 18 candidate fits;
- 12 parent fits;
- 30 full-budget fits;
- 18 exact candidate-parent comparisons.

Within each pair, source, DESN seed, MCMC seed, MCMC RNG seed, VB warm-start
seed, and synthesis seed are identical. This removes avoidable Monte Carlo and
reservoir-realization confounding from the paired comparison.

## Computation

Each full fit uses:

- MCMC burn-in: 5,000;
- retained MCMC iterations: 20,000;
- thinning: 1;
- posterior metric draws: 200;
- VB initialization: enabled, with its seed frozen per matched pair;
- progress message every 50 MCMC iterations.

Execution uses 20 worker processes and one compute thread per fit. The host has
64 logical CPUs, so 30 fits are scheduled in two waves without nested BLAS or
OpenMP oversubscription. The launcher selects the 20 least-used logical CPUs at
launch time and records the CPU set.

Resource gates require:

- one-minute load no greater than 40;
- at least 96 GiB available memory;
- at least 250 GiB available disk;
- 30-minute heartbeat cadence;
- seven-day per-fit timeout.

## Stages And Failure Policy

The pipeline is:

1. deterministic contract materialization;
2. 35-check contract verification;
3. prepare-only manifest generation;
4. two-fit candidate-parent smoke at 4 burn-in plus 4 retained iterations;
5. resource and CPU-selection gate;
6. 30-fit full-budget confirmation;
7. model-payload storage audit;
8. status-agnostic metric closeout;
9. terminal pipeline status.

Diagnostic `status` and `signoff_grade` are always retained and reported. They
are not metric filters. A metric is eligible only when it is finite and the
expected spec, source registry, source file, source windows, seeds, and full
budget all match. The model runner may return nonzero while leaving finite
metrics; closeout still audits those metrics rather than discarding them.

Missing metrics, mismatched provenance, mismatched seeds, mismatched budget, or
unexpected model payloads block promotion. Recovery must target only missing or
contract-invalid roots.

## Metric Promotion Rule

Promotion is a metric-wise envelope for each of the two article cells. For each
of fit RMSE, forecast MAE, and forecast check loss:

1. compare every contract-valid full-budget run, including matched controls, to
   the frozen current article value;
2. retain the strictly lower finite value using tolerance `1e-10`;
3. preserve the exact artifact path, SHA-256, run tag, spec, and diagnostic
   labels for that metric source;
4. write a promotion-ready interface preview;
5. do not edit the article automatically.

The best metric sources may differ. No global DESN specification is required.

## Storage Contract

Routine retained outputs are CSV/JSON/text metrics, manifests, statuses, logs,
and compact paths. Successful fit draws, VB initializers, and forecast objects
are not retained. The small 32 KiB staged `sim_output.rds` is a regenerable
source-adapter input, not a fitted model payload. Any `.rds`, `.rda`, or
`.RData` below the confirmation run root at closeout blocks the storage gate.

## Reproduction Commands

```bash
cd /data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_dynamic_alpha_confirm_v1_1p0p0
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_dynamic_alpha_confirm_v1.R \
  --workers 20
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/verify_qdesn_mcmc_dynamic_alpha_confirm_v1.R
bash validation/fitforecast_v2/scripts/launch_qdesn_mcmc_dynamic_alpha_confirm_v1.sh
```

Health check:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_qdesn_mcmc_dynamic_alpha_confirm_v1.R
```

## Prelaunch Verification Record

Completed under R 4.6.0 before the full launch:

- `exdqlm` 1.0.0 package load: PASS;
- deterministic materialization: PASS, all 19 campaign-file hashes unchanged;
- campaign contract verifier: PASS, 35 checks;
- campaign unit tests: 135 PASS, 0 FAIL, 0 WARN, 0 SKIP;
- full shared fit/forecast harness: 1,719 PASS, 0 FAIL, 0 WARN, one expected
  skip for an older campaign's optional materialization;
- relevant package production-path tests: 229 PASS, 0 FAIL, 0 WARN, 0 SKIP;
- shell syntax: PASS for pipeline and launcher;
- prepare-only tag: `qdesn-dacf1-precommit-prepare2-20260807`, PASS with no
  model binary payload;
- smoke tag: `qdesn-dacf1-precommit-smoke-20260807`, PASS with 2/2 exact
  requests, 2/2 finite fit-and-forecast summaries, exact source and seed
  contracts, 4+4 MCMC budget, and no retained binary payload.

The first prepare-only attempt,
`qdesn-dacf1-precommit-prepare-20260807`, stopped before inference because the
materializer had copied the DESN topology seed into both `desn_seed` and the
runner-level `seed`. The production runner correctly rejected that grid as
noncanonical. The materializer was repaired to preserve runner-level `seed =
123` while carrying the exact topology seed only in `desn_seed`; regenerated
spec IDs, the second prepare-only run, and the smoke all passed. The aborted
prepare attempt produced no model fit or binary payload.

`shellcheck` is not installed on the host, so shell validation used `bash -n`
plus the successful prepare-only and smoke executions.

The repository-wide `testthat::test_local()` command also reaches a separate,
pre-existing `benchmark_qdesn` test group with namespace-related failures. This
campaign does not modify those benchmark sources or tests. The fit/forecast
production path used here is covered by the passing shared harness, the 229
targeted package assertions, and the real smoke execution. The unrelated
benchmark failures are recorded and are not silently represented as passing.

## Launch Boundary

The implementation and generated contract are committed and pushed before
launch. Launch requires a clean worktree exactly synchronized with its upstream.
The detached pipeline is allowed to produce ignored run evidence only. Article
promotion remains a separate reviewed action after closeout.
