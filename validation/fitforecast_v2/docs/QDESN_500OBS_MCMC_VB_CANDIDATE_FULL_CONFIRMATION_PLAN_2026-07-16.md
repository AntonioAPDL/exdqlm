# Q-DESN 500-Observation MCMC VB-Candidate Full Confirmation Plan

## Decision

VB is a candidate generator, not a hard gate for MCMC. The next Q-DESN RHS calibration step is therefore a full MCMC confirmation slate initialized from VB for a deliberately diverse set of candidates:

- qvbm1 mechanism-first cell winners, because these improved parts of the fit/forecast tradeoff but were not promoted under the VB-only gate.
- older broad-screen all-primary VB winners, because they are the strongest historical VB dominance designs.
- v51 case-targeted metric specialists, because they represent recent lower-tail targeted candidates.
- qvbm3 low-tau/capacity winners, because larger/capacity designs may behave differently under MCMC even when VB was not decisive.

The stage is not article-facing until it completes, passes strict audit, and is explicitly promoted.

## Scope

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation`
- Families: `normal`, `laplace`, `gausmix`
- Quantiles: `0.05`, `0.25`
- Likelihoods: `al`, `exal`
- Prior: `rhs_ns`
- Fit window: 500 observations under the frozen shared source registry
- Forecast protocol: rolling-origin no-refit state-update, max lead 30, stride 30
- Candidate cap: at most seven candidates per family/quantile/likelihood cell, so the lower-tail cells can retain qvbm1, qvbm3, historical, and v51 candidates together.

## MCMC Contract

- `init_from_vb = TRUE`
- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`
- `progress_every = 50`
- one root worker per candidate root
- storage-light outputs only
- no routine successful `.rds`, `.rda`, or `.RData` retention

## Files

- Materializer: `scripts/materialize_qdesn_tt500_mcmc_vb_candidate_full_confirmation.R`
- Orchestrator: `scripts/orchestrate_qdesn_tt500_mcmc_vb_candidate_full_confirmation.R`
- Test: `tests/testthat/test-qdesn-tt500-mcmc-vb-candidate-full-confirmation.R`
- Config prefix: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation_*`
- Diagnostics prefix: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation/materialization_diagnostics`

## Launch Gate

The full launch must run through:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_vb_candidate_full_confirmation.R \
  --workers 12 \
  --smoke \
  --full \
  --launch-approved
```

The orchestrator materializes the slate, runs prepare-only, runs a small smoke with the smoke budget, and then launches the full MCMC stage only when `--full --launch-approved` is present.
