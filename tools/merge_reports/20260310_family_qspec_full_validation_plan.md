## Purpose

Run the full paper-family validation grid using the already-generated paper-style quantile-specific datasets.

This plan intentionally does **not** reopen the DGP-comparison question. The paper-style family datasets are treated as the validation source of truth for this phase.

## Dataset families in scope

### Static non-shrinkage
- root: `results/function_testing_20260309_static_paper_family_qspec`
- families:
  - `normal`
  - `laplace`
  - `gausmix`
- taus:
  - `0.05`
  - `0.25`
  - `0.50`
- fit sizes:
  - `100`
  - `1000`

### Static shrinkage
- root: `results/function_testing_20260309_static_shrinkage_family_qspec`
- families:
  - `normal`
  - `laplace`
  - `gausmix`
- taus:
  - `0.05`
  - `0.25`
  - `0.50`
- fit sizes:
  - `100`
  - `1000`
- priors:
  - `ridge`
  - `rhs`

### Dynamic non-shrinkage
- root: `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW`
- families:
  - `normal`
  - `laplace`
  - `gausmix`
- taus:
  - `0.05`
  - `0.25`
  - `0.50`
- fit sizes:
  - last `500`
  - last `5000`

## Model grid

### Static non-shrinkage
- `AL` via `VB`
- `AL` via `MCMC`
- `exAL` via `VB`
- `exAL` via `MCMC`

### Static shrinkage
- `AL` via `VB` and `MCMC` under `ridge`
- `AL` via `VB` and `MCMC` under `rhs`
- `exAL` via `VB` and `MCMC` under `ridge`
- `exAL` via `VB` and `MCMC` under `rhs`

### Dynamic non-shrinkage
- `DQLM` via `VB`
- `DQLM` via `MCMC`
- `exDQLM` via `VB`
- `exDQLM` via `MCMC`

## Execution matrix

### Static non-shrinkage
- 3 families x 3 taus x 2 fit sizes x 4 model/backend combinations = 72 fits

### Static shrinkage
- 3 families x 3 taus x 2 fit sizes x 8 model/backend/prior combinations = 144 fits

### Dynamic non-shrinkage
- 3 families x 3 taus x 2 fit sizes x 4 model/backend combinations = 72 fits

### Total planned fits
- 288 fits

## Orchestration rules

1. Keep each dataset family in its own tmux session group.
2. Keep static and dynamic campaigns separate.
3. Write one task-status TSV per fit.
4. Write one campaign-level summary CSV per session.
5. Do not live-monitor continuously; only inspect sessions on demand.
6. Use the already prepared fit-input roots only.
7. Use the current Delta-only VB implementation for all production VB runs.
8. Leave `ISVB` out of scope.

## Review order after runs finish

1. Static non-shrinkage
2. Static shrinkage
3. Dynamic non-shrinkage
4. Global cross-family summary

## Success criteria

1. Every campaign root contains:
   - fit summary
   - VB convergence summary
   - MCMC diagnostics summary
   - metrics summary
   - plots
2. Static shrinkage runs also contain:
   - coefficient recovery tables
   - group summaries
   - ridge-vs-rhs compare outputs
3. Final review tables can compare:
   - `AL` vs `exAL`
   - `VB` vs `MCMC`
   - runtime at each fit size
   - `ridge` vs `rhs`

## Preconditions before launch

- prepared fit-input subsets exist:
  - static: `tt100`, `tt1000`
  - dynamic: `lastTT500`, `lastTT5000`
- current extended-model VB path is Delta-only
- current extended-model VB runtime/signoff fix is committed
