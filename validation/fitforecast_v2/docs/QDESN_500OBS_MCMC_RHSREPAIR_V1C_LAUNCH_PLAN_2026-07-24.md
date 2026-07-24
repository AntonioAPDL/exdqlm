# Q-DESN 500-Observation MCMC RHS Repair v1c Launch Plan

Status: prepared for gated launch on the independent Q-DESN/DQLM validation
branch only.

## Scope

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Stage file: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c`
- Model scope: independent Q-DESN and exQ-DESN RHS MCMC repair cells only.
- Article policy: non-authoritative until the run completes, strict audit passes,
  and winners are explicitly promoted.
- Out-of-scope: Article repository edits, GloFAS, PriceFM, joint-QVP, and
  non-validation application work.

## Why v1c Is the Right Next Step

The v1b MCMC repair campaign completed, but it did not produce a clean wholesale
replacement set. It gave useful evidence:

- 130/130 roots reached terminal state.
- 110 succeeded and 20 failed.
- 50 were clean comparison rows.
- 80 were non-promotable because of root failures or strict MCMC diagnostics.
- The main operational failure mode was concentrated in unstable low-`tau0`
  repair arms, recorded as missing chain diagnostics.

The v1c launch keeps the scientific focus narrow: only the 10 hard
family/quantile/model cells from the v1b closeout are rerun. It avoids spending
MCMC compute on cells already solved by the current table, and it avoids
relaunching the low-`tau0` surfaces that were already shown to be fragile.

## Target Cell-Likelihoods

The v1c materialization contains 10 hard cell-likelihood targets:

| Priority | Family | Tau | Model | Reason |
| --- | --- | --- | --- | --- |
| 1 | gausmix | 0.25 | exQ-DESN RHS | no clean v1b candidate |
| 2 | normal | 0.25 | exQ-DESN RHS | no clean v1b candidate |
| 3 | gausmix | 0.05 | exQ-DESN RHS | v1b did not improve current best |
| 4 | normal | 0.05 | Q-DESN RHS | tail AL gap |
| 5 | gausmix | 0.50 | exQ-DESN RHS | median forecast gap |
| 6 | gausmix | 0.50 | Q-DESN RHS | median forecast gap |
| 7 | laplace | 0.50 | exQ-DESN RHS | reference-gap confirmation |
| 8 | laplace | 0.50 | Q-DESN RHS | reference-gap confirmation |
| 9 | normal | 0.50 | exQ-DESN RHS | reference-gap confirmation |
| 10 | normal | 0.50 | Q-DESN RHS | reference-gap confirmation |

## Design

Each target receives 11 profiles: one cell-specific anchor plus 10 repaired
exploration arms. New arms use `rhs_tau0 >= 1e-4`, with one relaxed dense bridge
at `3e-4`. The design spans:

- shallow memory confirmation: `D = 1`, `m = 12, 36, 90`;
- depth-two bridges: `D = 2`, `m = 24, 36, 60, 90`;
- guarded deeper capacity: `D = 3, 4`;
- high-rho persistence: `rho = 0.80, 0.85, 0.90`;
- bounded source contract: maximum `m = 90`, no new source registry extension.

Total planned full MCMC target specs: 110.

## Gates

1. Materialize and inspect config files.
2. Run the v1c materialization regression test.
3. Run prepare-only for all 110 target specs.
4. Run one smoke root from a previously no-clean stability cell.
5. Launch the full background run only if the previous gates pass.

Full MCMC settings:

- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`
- `progress_every = 50`
- `init_from_vb = TRUE`
- workers: 20

## Reproducibility Commands

Materialize:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript scripts/materialize_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c \
  --workers 20
```

Regression test:

```bash
Rscript -e 'testthat::test_file("validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-rhsrepair-v1c-materialization.R")'
```

Gated full launch:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_rhs_targeted_repair_v1.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c \
  --workers 20 \
  --skip-materialize \
  --full \
  --launch-approved
```

## Monitoring

After launch, monitor only the v1c validation session and paths:

```bash
tmux list-sessions | grep qdesn_tt500_mcmc_rhsrepair_v1c
tail -n 80 reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c/orchestration/*/logs/30_full_detached.log
find reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c -name '*status*.csv' -o -name '*progress*.csv' | sort
```

## Storage Policy

The stage remains storage-light:

- keep scalar fit and forecast metrics;
- keep compact path summaries, manifests, logs, configs, and statuses;
- do not retain successful `.rds`, `.rda`, or `.RData` payloads;
- retain heavy artifacts only if an explicit failure-debug subset is generated
  by the runner.

## Expected Closeout

When complete, close out with a strict audit before article promotion:

- root terminal counts;
- success/failure ledger;
- MCMC diagnostics and comparison eligibility;
- improvement relative to current Q-DESN/exQ-DESN RHS MCMC table rows;
- storage audit;
- explicit list of winners, non-winners, and failed roots.
