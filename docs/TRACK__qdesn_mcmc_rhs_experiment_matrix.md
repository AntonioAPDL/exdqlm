# QDESN RHS MCMC Experiment Matrix (Gated)

Date: 2026-03-17  
Branch: `feature/qdesn-mcmc-alternative`

## Goal

Run a controlled, phase-gated matrix to isolate the dominant RHS-MCMC failure mode after runtime confounds were removed.  
Primary target is reducing multichain root failures caused by elevated split-Rhat in RHS blocks.

## Fixed Baseline

Base defaults:

- `config/validation/qdesn_mcmc_compare_rhs_structural_reparam_gateB_tauwarm25.yaml`
- grid: `config/validation/qdesn_mcmc_multichain_rhs_runtime_isolation_grid.csv`

Fixed baseline properties:

- 4 chains, `chain_seed_base=500000`
- RHS MCMC: `n_burn=1500`, `n_mcmc=3000`, `init_from_vb=true`
- RHS warmup freeze: `freeze_tau_burnin_iters=25`
- directional `tau-c2` global block update

## Matrix Definition

Matrix YAML:

- `config/validation/qdesn_mcmc_rhs_exp_matrix/matrix.yaml`

Patch files:

- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E00_control.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E01_no_init_from_vb.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E02_strong_vb_init.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E03_strong_vb_init_tauwarm0.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E04_strong_vb_init_tauwarm50.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E05_coordinate_global_update.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E06_narrow_rhs_widths.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E07_wide_rhs_widths.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E08_narrow_widths_high_step_budget.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E09_long_chain.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E10_very_long_chain.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E11_very_long_chain_alt_seedbase.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E12_rhs_prior_tau0_0p02_s2_1.yaml`
- `config/validation/qdesn_mcmc_rhs_exp_matrix/patches/E13_rhs_prior_nu6_s2_0p75.yaml`

## Run Order

1. **Phase 1 (`E00..E04`)**
   - isolate initialization and tau-warmup effects.
2. **Phase 2 (`E05..E08`)**
   - run only from phase-1 winner defaults.
3. **Phase 3 (`E09..E11`)**
   - run only from phase-2 winner defaults.
4. **Phase 4 (`E12..E13`)**
   - run only if trigger is active:
   - source=`E11`, metric=`max_split_rhat`, condition=`> 1.10`.

## Selection Logic

Within each phase, experiments are ranked by:

1. `status` (`COMPLETED` preferred),
2. `n_missing_diag` (lower is better),
3. `n_pipeline_fail` (lower is better),
4. `n_chain_fail` (lower is better),
5. `n_root_fail` (lower is better),
6. `max_split_rhat` (lower is better),
7. `min_ess_rhs` (higher is better),
8. `wall_minutes` (lower is better).

Top-2 are recorded; rank-1 is promoted as next phase base.

## Orchestrator

Run script:

- `scripts/run_qdesn_mcmc_rhs_experiment_matrix.R`

Primary command:

```bash
Rscript scripts/run_qdesn_mcmc_rhs_experiment_matrix.R --no-plots
```

Dry-run (plan only):

```bash
Rscript scripts/run_qdesn_mcmc_rhs_experiment_matrix.R --dry-run
```

Resume mode:

```bash
Rscript scripts/run_qdesn_mcmc_rhs_experiment_matrix.R --resume --no-plots
```

## Outputs

Per matrix run root:

- `reports/qdesn_mcmc_validation/rhs_exp_matrix/<timestamp__git-sha>/`
- `results/qdesn_mcmc_validation/rhs_exp_matrix/<timestamp__git-sha>/`

Key report tables:

- `tables/experiment_summary.csv`
- `tables/phase_winners.csv`
- `tables/phase_triggers.csv`
- `tables/phase_topk.csv`
- `decision/matrix_decision.csv`

