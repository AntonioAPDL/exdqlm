# Q-DESN 500-Observation MCMC Post-v4 Per-cell Launch

Date: 2026-07-27

## Scope

This launch is only for the independent Q-DESN/exQ-DESN versus DQLM/exDQLM
fit-and-forecast validation worktree:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

It does not modify article repositories, PriceFM, GloFAS, joint-QDESN, or any
other application workflow.

## Stage

- stage file: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell`
- source hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- unresolved cells: 15
- MCMC candidates per unresolved cell: 6
- target MCMC specifications: 90
- families: `gausmix`, `laplace`, `normal`
- quantiles: `0.05`, `0.25`, `0.50`
- likelihood rows: Q-DESN AL-RHS and exQ-DESN exAL-RHS

The design is cell-specific. It is not a global DESN specification search.

## MCMC Budget

- screening burn-in: 2000
- screening retained iterations: 8000
- thin: 1
- progress cadence: every 50 iterations
- VB warm start: required
- later confirmation budget recorded but not launched here: 5000 burn-in and
  20000 retained iterations for one promoted candidate per cell

## Storage Policy

The launch is storage-light:

- no retained routine MCMC draws
- no retained VB warm-start payloads
- no retained forecast objects
- scalar fit and forecast metrics only
- compact path summaries, logs, manifests, and status evidence retained

## Commands

Materialize:

```bash
Rscript scripts/materialize_qdesn_tt500_mcmc_postv4_percell_screen.R --workers 16
```

Run regression checks:

```bash
Rscript -e "testthat::test_file('validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-postv4-percell-prelaunch.R')"
Rscript -e "testthat::test_file('validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-postv4-percell-design.R')"
Rscript -e "testthat::test_file('validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-metricgap-v4-closeout.R')"
Rscript -e "testthat::test_file('validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-metric-envelope.R')"
```

Launch after commit:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_postv4_percell_screen.R \
  --full \
  --launch-approved \
  --skip-materialize \
  --workers 16
```

The full command performs prepare and one smoke MCMC root first, then starts the
90-spec screen in a detached tmux session only after the committed worktree is
clean.

## Article Policy

No article table is updated from this launch directly. Article-facing promotion
requires a closeout audit, metric comparison against the current envelope, and a
separate confirmation decision.
