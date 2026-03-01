# Offline Collapse Audit (March 1, 2026)

## Scope
- Goal: investigate why offline RHS fits now collapse (beta -> 0, tau at lower bound), with emphasis on changes made during/around model-selection and online implementation work.
- Constraint: no core algorithm changes in this audit; evidence-first diagnosis.

## Current Status Snapshot
- Checkpoint commit created before this audit: `b43283e`.
- Remaining active run was stopped as requested: `esn_dlm_constV_bigW_defaults_offline_20260301-134710`.

## Executive Summary
1. The collapse is **real and systematic** in recent offline runs: `tau_last ~ 2.061e-09`, `log_tau_last ~ -19.99995`, `beta_l2_last = 0`, `collapse_flag=TRUE` for all quantiles/cases in available summaries.
2. The collapse is **not explained by online mode accidentally being enabled**. Logs consistently show `Effective online VB -> enabled=FALSE` in offline runs.
3. The collapse is **not primarily explained by model-selection commits**. Key offline core files changed after pre-model-selection baseline only in:
   - `2a90a43` (RHS expected precision formula change)
   - `ce411f6` (offline refactor to shared helpers, tested for batch equivalence)
   - `168499f` (pipeline online switch wiring; offline branch still calls `exal_ldvb_fit`)
4. Strongest candidate root cause: interaction between
   - very aggressive RHS global shrinkage settings (`tau0=0.001`, `s2=0.1`, bounds `[-20,20]`), and
   - exact Gaussian-moment expected-precision update introduced in `2a90a43` (`R/qdesn_rhs_prior.R`).

## What Changed Since Pre-Model-Selection Baseline
Pre-model-selection commit used for reference: parent of first MS commit `fe4b89c` is `bda3b5e`.

### File-level change history after `bda3b5e` (for relevant files)
- `2a90a43`: `R/qdesn_rhs_prior.R` updated expected precision to exact Gaussian moments.
- `ce411f6`: `R/exal_ldvb_engine.R` refactored local/beta updates to shared helpers; batch-equivalence tests added.
- `168499f`: `scripts/pipeline_sim_main.R` online toggle wiring and config plumbing.
- `b43283e`: local checkpoint commit (includes current defaults edits used for recent runs).

### Key defaults comparison
Observed from `config/defaults.yaml` history:
- Pre-model-selection / pre-online-like defaults (`bda3b5e`, `1f9a828`, `ed9d929`) had:
  - `desn.n = [1000,300,300]`, `m=180`, `alpha=[0.2,0.2,0.2]`
  - `vb.priors.beta.rhs.tau0=0.001`, `s2=0.1`
  - `freeze_tau_iters=20`, `freeze_tau_warmup_iters=20`
  - `forecast.horizon=60`, `diagnostics.fan_stride=60`
- Current workspace defaults (checkpoint `b43283e`) have:
  - `desn.'n'=[100,100,100]`, `n_tilde=[100,100]`, `m=30`
  - same RHS hyperparameters (`tau0=0.001`, `s2=0.1`) and freeze settings
  - `forecast.horizon=1`, `diagnostics.fan_stride=1`

Important: recent collapse was also observed in prior runs that used the old-style defaults (`n=[1000,300,300]`, `m=180`, `horizon=60`, `fan_stride=60`), so collapse is not solely caused by the current speed-oriented DESN/horizon edits.

## Empirical Evidence from Run Artifacts
### Offline run summaries (available `rhs_run_summary.csv` in `results/sim_suite_dlm`)
Aggregate result over all discovered rows/files:
- `git_sha = 449f2bf` only in available summaries
- `collapse_flag = TRUE` for all rows
- `near_bound_flag = TRUE` for all rows
- `tau_last = 2.061256859e-09` for all rows
- `beta_l2_last = 0` for all rows

### Example collapse signatures
From:
- `results/sim_suite_dlm/dlm_ar1V/runs/20260227-112027__git-449f2bf__spec-defaults_offline__cfg-b98c4cd9/models/rhs_run_summary.csv`
- `results/sim_suite_dlm/dlm_constV_bigW/runs/20260227-112027__git-449f2bf__spec-defaults_offline__cfg-b98c4cd9/models/rhs_run_summary.csv`
- `results/sim_suite_dlm/dlm_constV_smallW/runs/20260227-112027__git-449f2bf__spec-defaults_offline__cfg-b98c4cd9/models/rhs_run_summary.csv`

All show the same terminal state above.

## Controlled Cross-Version Experiments (Synthetic, Fixed Seed)
Artifacts:
- `/tmp/exdqlm_audit_rhs_compare2_head.csv`
- `/tmp/exdqlm_audit_rhs_compare2_preonline.csv`
- `/tmp/exdqlm_audit_rhs_compare2_pre_exactmom.csv`
- `/tmp/exdqlm_audit_ridge_compare_head.csv`
- `/tmp/exdqlm_audit_ridge_compare_preonline.csv`

### Findings
1. `HEAD` vs `preonline` (`ed9d929`) under RHS settings:
   - both collapse similarly (`tau~2e-09`, `beta_l2=0`).
   - implication: online wiring itself is not the differentiator.

2. `pre_exactmom` (`1ed4734`, before `2a90a43`) under milder RHS (`tau0=0.1`, `s2=1`):
   - non-collapsed (`tau~0.174`, `beta_l2~2.16`, converged).

3. Same setting at `HEAD`/`preonline` (`tau0=0.1`, `s2=1`):
   - collapsed (`tau~2e-09`, `beta_l2=0`).

4. Ridge control at `HEAD` and `preonline`:
   - stable and nearly identical (`beta_l2~2.21`, converged both).

Interpretation: strongest inflection is the RHS precision behavior around/after `2a90a43`, not generic offline solver breakage.

## What This Suggests About Root Cause
### Most likely
- **RHS shrinkage dynamics are currently too aggressive** under present expected-precision computation and constraints, pushing `eta_tau` to lower bound and forcing global collapse.

### Less likely
- Pure online plumbing regression in offline path.
  - Offline branch remains explicit in pipeline (`if online enabled -> exal_online_fit else exal_ldvb_fit`).
  - Batch-equivalence tests for refactored helper path pass.

### Possible contributing factors
- Current workspace DESN reduction (`n=[100,100,100], m=30`) changes feature geometry; however collapse also occurred with old pre-MS defaults.
- Tight tau bounds (`-20` lower log bound) plus forced updates may make collapse sticky once entered.

## Answers to Your Specific Questions
### "Did we have defaults with horizon=60 and fan_stride=60 that worked?"
- Yes, such defaults existed pre-model-selection (`bda3b5e`/`1f9a828`/`ed9d929`).
- In the available recent artifacts at current code level, collapse still occurs even when using those old horizon/fan and old DESN defaults (`cfg-b98c4cd9`).

### "Could this be scaling?"
- Available summaries show post-readout scaling SDs are not degenerate (`post_scale_sd_min/med/max = 1` in recent collapsed runs).
- Scaling alone is not the strongest explanation from current evidence.

## No-Core-Change Recommendations (Next Diagnostic Iteration)
1. Run a **frozen-code A/B matrix** at current HEAD, single case (`dlm_constV_smallW`), varying only RHS hyperparameters:
   - A: (`tau0=0.001`, `s2=0.1`) [current]
   - B: (`tau0=0.1`, `s2=1`)
   - C: (`tau0=1`, `s2=1`)
   Keep all else fixed.
2. Capture `rhs_trace.rds` and `rhs_run_summary.csv` for each, compare `log_tau` trajectory and `beta_l2` decay timing.
3. Repeat one run with **RHS exact moments disabled (legacy approximation) in a sandbox branch/worktree** only for diagnosis to isolate `2a90a43` effect definitively.
4. Keep `online.enabled=FALSE` throughout diagnostic runs.

## Audit Integrity Notes
- This audit intentionally avoided algorithmic edits.
- One running job was manually stopped on user request; completed runs remain preserved under `results/sim_suite_dlm/...`.
