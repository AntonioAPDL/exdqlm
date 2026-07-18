# RQR-DESN Article-Congruent Simulation Lane

Date: 2026-07-18

This note records the package-side implementation of the redesigned RQR-DESN
simulation lane for the Q-DESN article. It converts the external design brief
into a frozen, guarded, reproducible workflow. The lane is intentionally not an
article-results update: it prepares the run, validates smoke slices, and defines
the promotion audit that must pass before manuscript tables are rebuilt.

## Scientific Contract

The target is central interval prediction with the two-root RQR loss. RQR-DESN
is treated as a generalized-Bayes interval readout, not as a response likelihood.
Accordingly, this lane does not draw posterior predictive responses from an RQR
likelihood, does not use recursive response sampling as a primary validation
object, and does not claim that RQR reduces quantile crossing.

For the Q-DESN competitors, the object is a matched pair of targeted quantile
readouts at the interval endpoints. The package-side runner does not convert
those paired readouts into a scalar predictive density. Article-side joint-QVP
rows are included in the design denominator, but they are marked as an external
adapter contract until the article kernel is wired explicitly.

The frozen decision rule is:

- qualify methods only if absolute empirical coverage error is at most 0.025;
- among qualified methods, rank by mean interval score;
- use mean width as the secondary ranking metric;
- record a no-qualified-winner cell when all methods miss the coverage gate;
- keep every prespecified method in the denominator, including failed or
  external-adapter rows.

## Frozen Design

Config:

```bash
config/rqr_desn/rqr_desn_article_congruent_simulation_20260718.R
```

Default manifest denominator:

- total scenario rows: 8040;
- package-adapter rows: 6700;
- external article joint-QVP adapter rows: 1340;
- fixed-design rows: 4800;
- dynamic rolling one-step rows: 3240.

Fixed-design endpoint recovery:

- calibration sample: 500;
- final-fit sample: 500;
- held-out test sample: 1000;
- replicates: 100;
- DGPs: symmetric Gaussian, skewed centered Gamma, Student-t5, and
  heteroskedastic Gaussian;
- design: sparse correlated predictors with 20 predictors and 5 active
  coefficients;
- oracle endpoints: computed from the RQR coverage and first-moment balance
  equations.

Dynamic rolling one-step study:

- generated length: 12000;
- DGP warmup: 2000;
- effective length: 10000;
- DESN washout: 7501-8000;
- calibration window: 8001-8500;
- final-fit window: 8501-9000;
- held-out test window: 9001-10000;
- replicates: 30;
- DGPs: nine article-style dynamic mechanisms;
- feature contract: fixed causal DESN features with one-step held-out interval
  scoring.

Default competitors:

- empirical training interval baseline;
- RQR-DESN RHS MCMC, learning rates 0.50, 1.00, and 1.50;
- independent AL Q-DESN RHS MCMC quantile pair;
- joint AL Q-DESN QVP-RHS MCMC, declared as an external article adapter.

The optional direct-horizon supplement is recorded in the config but disabled by
default. It should be implemented and promoted separately if needed.

## Implemented Files

- `R/rqr_oracle.R`: oracle root and endpoint helpers for centered innovation
  laws.
- `config/rqr_desn/rqr_desn_article_congruent_simulation_20260718.R`: frozen
  guarded design.
- `scripts/materialize_rqr_desn_article_congruent_manifest.R`: manifest
  materializer and denominator preflight.
- `scripts/run_rqr_desn_article_congruent_simulation.R`: guarded smoke/full
  runner for package-ready adapters.
- `scripts/launch_rqr_desn_article_congruent_production.R`: guarded tmux
  launcher that shards package-ready scenarios across low-priority
  single-threaded workers.
- `scripts/collect_rqr_desn_article_congruent_shards.R`: collector for shard
  outputs followed by the promotion audit.
- `scripts/audit_rqr_desn_article_congruent_results.R`: results audit,
  calibration-qualified winner table, failure table, and article claim
  contract.
- `tests/testthat/test-rqr-desn-article-congruent-simulation.R`: focused
  end-to-end tests for oracle roots, manifest denominator, launch guard, smoke
  runs, and audit outputs.

## Smoke Validation

Manifest smoke:

```bash
Rscript scripts/materialize_rqr_desn_article_congruent_manifest.R \
  --output-dir /tmp/rqr_article_manifest_smoke
```

Guard check:

```bash
Rscript scripts/run_rqr_desn_article_congruent_simulation.R \
  --output-dir /tmp/rqr_article_guard_smoke \
  --stage-id fixed_design_endpoint_recovery \
  --family-id symmetric_gaussian \
  --method-id empirical_train_interval \
  --max-scenarios 1
```

Expected result: nonzero exit with a message requiring
`--confirm-full-launch true`.

Adapter-ready smoke:

```bash
Rscript scripts/run_rqr_desn_article_congruent_simulation.R \
  --smoke true \
  --output-dir /tmp/rqr_article_run_smoke \
  --scenario-id rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__empirical_train_interval__cov0p8__lrna,rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__rqr_desn_rhs_mcmc__cov0p8__lr0p5,rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__independent_al_qdesn_rhs_mcmc__cov0p8__lrna \
  --chains 1 \
  --mcmc-burn 3 \
  --mcmc-keep 4
```

Audit smoke:

```bash
Rscript scripts/audit_rqr_desn_article_congruent_results.R \
  --run-dir /tmp/rqr_article_run_smoke \
  --output-dir /tmp/rqr_article_audit_smoke
```

Detached launcher smoke:

```bash
Rscript scripts/launch_rqr_desn_article_congruent_production.R \
  --confirm-full-launch true \
  --workers 2 \
  --max-scenarios 3 \
  --output-root /tmp/rqr_article_launcher_tiny_smoke \
  --stamp tinysmoke \
  --tmux-session rqr_article_tinysmoke_20260718 \
  --chains 1 \
  --mcmc-burn 3 \
  --mcmc-keep 4
```

Focused test:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-rqr-desn-article-congruent-simulation.R")'
```

## Production Commands

Full production is deliberately guarded. Do not run these commands unless the
article owner explicitly authorizes the full launch.

Manifest:

```bash
Rscript scripts/materialize_rqr_desn_article_congruent_manifest.R \
  --config config/rqr_desn/rqr_desn_article_congruent_simulation_20260718.R \
  --output-dir reports/rqr_desn_article_congruent_simulation/manifest_article_congruent_20260718
```

Package-ready fixed-design run:

```bash
Rscript scripts/run_rqr_desn_article_congruent_simulation.R \
  --config config/rqr_desn/rqr_desn_article_congruent_simulation_20260718.R \
  --output-dir reports/rqr_desn_article_congruent_simulation/run_fixed_article_congruent_20260718 \
  --stage-id fixed_design_endpoint_recovery \
  --implemented-adapter empirical_interval,rqr_mcmc,independent_al_pair \
  --confirm-full-launch true
```

Package-ready dynamic one-step run:

```bash
Rscript scripts/run_rqr_desn_article_congruent_simulation.R \
  --config config/rqr_desn/rqr_desn_article_congruent_simulation_20260718.R \
  --output-dir reports/rqr_desn_article_congruent_simulation/run_dynamic_one_step_article_congruent_20260718 \
  --stage-id dynamic_rolling_one_step \
  --implemented-adapter empirical_interval,rqr_mcmc,independent_al_pair \
  --confirm-full-launch true
```

Detached package-ready full launch:

```bash
Rscript scripts/launch_rqr_desn_article_congruent_production.R \
  --config config/rqr_desn/rqr_desn_article_congruent_simulation_20260718.R \
  --workers 6 \
  --implemented-adapter empirical_interval,rqr_mcmc,independent_al_pair \
  --confirm-full-launch true
```

Results audit:

```bash
Rscript scripts/audit_rqr_desn_article_congruent_results.R \
  --run-dir <RUN_DIR> \
  --output-dir <RUN_DIR>/results_audit_20260718
```

The joint-QVP article adapter should be wired and audited separately before
those rows are used in article-facing comparison tables.

## Promotion Boundary

The article should not be updated from this lane until a completed results audit
exists. The promotion audit must provide:

- method summary by stage, DGP, coverage, and method;
- calibration-qualified winner table;
- failed or missing method table;
- baseline deltas;
- MCMC diagnostic presence for completed MCMC methods;
- article claim contract stating what the run supports and what it does not
  support.

Until those outputs exist, the current broad run and smoke artifacts are
implementation evidence only.
