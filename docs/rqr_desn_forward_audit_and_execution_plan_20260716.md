# RQR-DESN Forward Audit, Diagnosis, And Execution Plan

Date: 2026-07-16

Repository: `/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

Branch: `feature/rqr-desn-readout-20260716`

Current readiness commit before this phase:
`aeeb241ff0ea689de4058ca8499c493541a476b1`.

## 1. Scope Decision

This phase is package-side RQR-DESN infrastructure only. It must not modify:

- article repositories;
- PriceFM scripts or evidence;
- GloFAS scripts or evidence;
- joint Q-DESN validation scripts or evidence;
- promoted article figures, tables, or PDFs.

The goal is to decide whether the RQR-DESN backend is ready for a later broad
simulation campaign, then implement the smallest reproducible bridge needed to
make that decision auditable.

## 2. Diagnosis Of The Previous Plan

The previous plan was directionally correct but too coarse. It said to run a
clean readiness archive and then a small pilot before broad simulation. The
missing details were:

1. Package hygiene was identified but not fixed: `.Rbuildignore` ignored
   `results/` but not `reports/`, even though `reports/` is large and noisy.
2. The readiness harness existed, but there was no persistent local archive
   convention for its outputs.
3. The broad simulation template existed, but there was no executable pilot
   runner that could test the proposed output contract.
4. There was no pilot closeout artifact to make the go/no-go decision
   reproducible.

Therefore the optimal next step is not the broad simulation. The optimal next
step is a bridge phase:

```text
package hygiene
  -> installed clean readiness archive
  -> executable pilot runner
  -> pilot closeout report
  -> documented go/no-go decision
```

## 3. Audit Findings

### 3.1 Git State

The branch was synced with origin at `aeeb241` before this phase. The only
untracked file was:

```text
docs/QDESN_REPOSITORY_THEORY_IMPLEMENTATION_HANDOFF_20260716.md
```

That file is outside this phase and remains untouched.

### 3.2 Package Hygiene

The local worktree contains large historical outputs:

```text
reports/: 921M
results/:  2.0G
src/:      100M
```

`results/` was already excluded from source builds, but `reports/` was not.
Because readiness and pilot outputs naturally live under `reports/`, this phase
adds:

```text
^reports($|/)
```

to `.Rbuildignore`, and ignores local RQR readiness/pilot report directories in
`.gitignore`.

### 3.3 Methodological Contract

The RQR-DESN model remains a generalized-Bayes interval readout, not a response
predictive likelihood. The pilot must therefore evaluate:

- finite ordered lower/upper intervals;
- empirical coverage;
- interval width;
- interval score;
- midpoint accuracy when meaningful;
- failure modes and nondegenerate design checks.

The pilot must not:

- sample future responses from the pseudo-AL augmentation;
- call `coverage_level` a quantile level;
- treat VB intervals as calibrated;
- write article-facing tables or figures.

## 4. Implemented Bridge Assets

This phase adds an executable pilot runner:

```text
scripts/rqr_desn_pilot_simulation.R
```

The runner writes:

```text
manifest.csv
scenario_manifest.csv
interval_metrics.csv
fit_summary.csv
failure_log.csv
pilot_closeout.md
session_info.txt
git_state.txt
output_hashes.csv
README.md
```

The runner intentionally uses small deterministic scenarios:

| Scenario family | Purpose |
|---|---|
| symmetric fixed design | checks basic interval calibration and oracle endpoints |
| skewed fixed design | checks asymmetric-noise behavior |
| nonlinear teacher-forced DESN design | checks reservoir/design integration without recursive response sampling |

MCMC is primary. VB is included only as an explicitly uncalibrated sidecar for
fixed-design checks.

## 5. Go/No-Go Criteria

The bridge phase passes if:

1. temporary package install succeeds;
2. focused RQR installed-namespace tests pass;
3. clean readiness archive runs with `--install-package true`;
4. pilot script runs to completion;
5. all non-baseline model intervals are finite and ordered;
6. no failure rows are present or failures are explicitly documented;
7. the pilot closeout says `go_for_broad_spec = yes`.

The bridge phase does not authorize article integration. It only authorizes
writing a frozen broad simulation launch spec.

## 6. Expected Decision

If the bridge gates pass, the next step is to freeze a broad simulation config
with:

- MCMC as reference backend;
- VB as sidecar only;
- coverage levels `0.80` and `0.90`;
- learning-rate grid including `0.50` and `1.00`;
- ridge and RHS_NS priors, with RHS_NS included only after pilot stability;
- interval-compatible baselines.

If the bridge gates fail, the next step is to fix the smallest failing layer and
rerun the bridge before considering any broad simulation.

## 7. Implementation Status

Completed by this phase:

- [x] add package/source hygiene ignore rules;
- [x] add executable pilot runner;
- [x] run clean installed-package readiness archive;
- [x] run pilot;
- [x] inspect pilot closeout;
- [x] commit and push the package-side assets.

## 8. Reproducible Commands

Run the focused package-side gates from the repository root:

```bash
R_BIN=/data/jaguir26/local/opt/R/4.6.0/bin/R
RSCRIPT=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript

rm -rf /tmp/exdqlm-rqr-lib
mkdir -p /tmp/exdqlm-rqr-lib
"$R_BIN" CMD INSTALL --library=/tmp/exdqlm-rqr-lib \
  --no-multiarch --with-keep.source .

"$R_BIN" --vanilla -q -e '.libPaths(c("/tmp/exdqlm-rqr-lib", .libPaths())); files <- c("tests/testthat/test-rqr-algebra.R", "tests/testthat/test-rqr-mcmc-fixed-design.R", "tests/testthat/test-rqr-desn-design-parity.R", "tests/testthat/test-rqr-rhs-ns.R", "tests/testthat/test-rqr-vb-fixed-design.R", "tests/testthat/test-rqr-forecast-contract.R", "tests/testthat/test-rqr-contracts.R"); for (f in files) testthat::test_file(f, reporter = "summary")'

"$RSCRIPT" scripts/rqr_desn_pre_simulation_readiness.R \
  --install-package true

"$RSCRIPT" scripts/rqr_desn_pilot_simulation.R \
  --install-package false \
  --lib-path /tmp/exdqlm-rqr-lib
```

The readiness and pilot outputs are local report artifacts and are intentionally
ignored by git:

```text
reports/rqr_desn_pre_simulation_readiness/
reports/rqr_desn_pilot/
```

## 9. Bridge Gate Result

The bridge gate passed during implementation:

- temporary package install: passed;
- focused installed-namespace RQR tests: passed;
- clean readiness archive: passed with `install_package=TRUE`;
- pilot: passed with 44 metric rows, 0 failure rows, and
  `go_for_broad_spec=yes`.

This result authorizes preparing a frozen broad-simulation configuration. It
does not authorize article integration or broad scientific claims.
