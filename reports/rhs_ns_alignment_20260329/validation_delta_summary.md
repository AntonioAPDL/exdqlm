# Wave 4 Cross-Branch Validation Delta Summary (2026-03-29)

## 1) Branch Snapshot

- `origin/cransub/0.4.0`: `a95ee8c`
- `origin/validation/rerun-after-0.4.0-sync`: `9a7d05e`
- `origin/feature/qdesn-mcmc-alternative`: `6ac4727`

Divergence:

- `origin/cransub/0.4.0...origin/validation/rerun-after-0.4.0-sync` -> `0 left / 70 right`.
- `origin/cransub/0.4.0...origin/feature/qdesn-mcmc-alternative` -> `160 left / 248 right`.

Interpretation:

- The `0.4.0` integration line is cleanly based on the current CRAN-submission branch tip and carries the Wave 2 static RHS-NS port.
- The qdesn branch remains a long-lived divergent line by commit ancestry; reconciliation for this initiative is therefore validated by scoped behavior/parity evidence rather than full-history rebasing.

## 2) Scope Reconciliation Evidence

### 2.1 Wave 2 (`0.4.0` static line)

Wave 2 commit:

- `bc77e34` (`validation/rerun-after-0.4.0-sync`)

Key files:

- `R/static_beta_prior.R`
- `R/exal_static_mcmc.R`
- `tests/testthat/test-static-beta-prior-rhs.R`
- `tests/testthat/helper-static-fit-normalization.R`

Audit check:

- No qdesn files changed on `0.4.0` line relative to `origin/cransub/0.4.0`.

### 2.2 Wave 3 (qdesn line)

Wave 3 commit:

- `6ac4727` (`feature/qdesn-mcmc-alternative`)

Key files:

- `R/qdesn_mcmc.R`
- `R/qdesn_vb.R`
- `R/exal_inference_config.R`
- `R/priors_beta.R`
- `R/qdesn_rhs_prior.R`
- `R/qdesn_rhs_ns_prior.R`
- `R/qdesn_mcmc_validation.R`
- `tests/testthat/test-qdesn-prior-defaults.R`

Audit check:

- Default qdesn prior route is RHS-NS in VB and MCMC.
- Q-DESN RHS-family intercept shrinkage is hard-enforced as `FALSE`.

## 3) Wave 4 Checklist Resolution

- W4.1 (`0.4.0` on latest base): satisfied by merge-base and divergence check (`0 behind`, `70 ahead`) against `origin/cransub/0.4.0`.
- W4.2 (conflicts): no conflicts required resolution during this wave because no merge/rebase conflicts were introduced by scoped updates.
- W4.3/W4.4 (propagation + relation): satisfied at the initiative scope via targeted parity checks and direct qdesn behavior tests; full ancestry unification was not performed in this wave.
- W4.5 (commit map/topology evidence): captured in this file plus `branch_topology.md` and referenced commit IDs.
- W4.6 (sync both worktrees): both worktrees fetched and `pull --ff-only` returned `Already up to date`.

## 4) Residual Structural Delta (Non-Blocking for Current Scope)

- The qdesn branch is still history-divergent from `cransub/0.4.0` (`160/248`).
- This is a known branch-management debt, not a mathematical/algorithmic blocker for the RHS-NS initiative criteria completed here.
- A full lineage unification (`0.4.0 + qdesn` by ancestry) should be scheduled as a dedicated branch-hygiene operation outside this wave’s scoped code objectives.
