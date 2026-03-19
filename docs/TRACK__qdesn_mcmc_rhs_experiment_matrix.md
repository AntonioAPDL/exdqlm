# QDESN RHS MCMC Experiment Matrix (Gated)

Date: 2026-03-19  
Branch: `feature/qdesn-mcmc-alternative`

## Goal

Run a controlled, phase-gated matrix to isolate the dominant RHS-MCMC failure mode after runtime confounds were removed.  
Primary target is reducing multichain root failures caused by elevated split-Rhat in RHS blocks.

## Latest Execution Status (Updated 2026-03-19)

### Const `rhs_c2` wave completion

- wave run:
  - `rhs_const_c2_wave/20260318-182919__git-a034805__const-c2-wave`
- phase-A matrix:
  - completed (`5/5`);
  - winner: `B4`;
  - winner metrics:
    - `max_split_rhat=1.0286`
    - `min_ess_rhs=195.15`
    - `winner_n_root_fail=0`
- phase-B two-root reconfirm:
  - completed roots: `2`
  - root grades:
    - `const_small | tau=0.05 | rhs`: `PASS` (`max_split_rhat=1.0113`)
    - `level_shift_small | tau=0.25 | rhs`: `PASS` (`max_split_rhat=1.0385`)
  - reconfirm totals: `PASS=2`, `WARN=0`, `FAIL=0`
  - wave summary gate: `reconfirm_wave_pass=TRUE`
  - defaults promotion: `promoted_defaults=TRUE`

### Promotion output

- promoted candidate path:
  - `config/validation/qdesn_mcmc_compare_rhs_structural_reparam_constc2_candidate.yaml`
- frozen v1 baseline path:
  - `config/validation/qdesn_mcmc_compare_rhs_structural_reparam_constc2_v1.yaml`

### Implementation note

- wave finalization now writes both:
  - `manifest/wave_manifest.json`
  - `manifest/wave_completed.json`
  in `scripts/run_qdesn_mcmc_rhs_const_c2_wave.R`.
- promotion and broader-confirmation writers now sanitize YAML boolean-key
  coercion so reservoir width is emitted as `'n'` in promoted defaults.

## Latest Execution Status (Updated 2026-03-18 16:21 EDT)

### Completed matrix runs

- preflight:
  - `20260317-201834__git-15b388e__preflight`
  - completed with `dry_run=true`, `n_planned_experiments=14`.
- full matrix relaunch:
  - `20260317-201850__git-15b388e__relaunch_full`
  - completed with `12/12` experiments.

### Full matrix outcome

- phase winners:
  - phase 1: `E00`
  - phase 2: `E07`
  - phase 3: `E11`
  - phase 4: `SKIPPED_BY_TRIGGER` (trigger condition on `E11` was not met).
- final matrix decision:
  - winner `E11`
  - `max_split_rhat=1.0347`
  - `min_ess_rhs=130.76`
  - `final_completed_phase=phase3_chain_length_seed`.

### Remaining failure set and active continuation

The full matrix still left two `FAIL` roots that were extracted and relaunched
as a failed-only repair continuation:

- `level_shift_small | tau=0.25 | rhs`
- `const_small | tau=0.05 | rhs`

Active continuation run:

- `rhs_exp_failed_repair/20260318-152303__git-15b388e__failed-repair`

Live progress at this update:

- first root started;
- first-root chains completed: `2/4`;
- second root not started yet.

Repair acceptance rule for this continuation:

- `PASS` or `WARN` is acceptable for now;
- only unresolved `FAIL` requires another targeted follow-up.

## Const `rhs_c2` Follow-up Wave (Implemented)

Because failed-only continuation finished with:

- `level_shift_small | tau=0.25 | rhs`: `WARN`
- `const_small | tau=0.05 | rhs`: `FAIL` (`split_rhat_high` on `rhs_c2`)

the next implemented wave is a focused const-root micro-matrix plus two-root
reconfirm:

- phase-A matrix:
  - `config/validation/qdesn_mcmc_rhs_const_c2_matrix/matrix.yaml`
- const-only grid:
  - `config/validation/qdesn_mcmc_multichain_rhs_const_fail_grid.csv`
- phase-B reconfirm grid:
  - `config/validation/qdesn_mcmc_multichain_rhs_runtime_isolation_grid.csv`
- orchestrator:
  - `scripts/run_qdesn_mcmc_rhs_const_c2_wave.R`

Promotion rule:

- write provisional defaults only when reconfirm has `FAIL=0`;
- otherwise keep defaults unchanged and emit a kernel-escalation next-step note.

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
