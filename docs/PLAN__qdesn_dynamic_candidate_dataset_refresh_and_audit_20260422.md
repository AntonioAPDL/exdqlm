# Dynamic Candidate Dataset Refresh And Audit Plan

## Goal

Create a new candidate dynamic source surface in the Q-DESN validation repo that:

- preserves the current `3 x 3` family-by-tau root structure
- keeps tau-specific quantile centering with `q_true = mu`
- uses a new period-90 DGP with larger seasonal amplitude induced through `m0`
- can be regenerated deterministically from fixed seeds
- can be mirrored into the `0.4.0` validation worktree later with the same generator script
- still supports Q-DESN-specific washout materialization without changing the canonical source roots

## Design Decisions

### Canonical source layer

- stage a new candidate scenario instead of overwriting `dlm_constV_smallW`
- scenario id:
  - `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- write the canonical roots under:
  - `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/`
- generate:
  - `9` full roots
  - `18` canonical `lastTT` slices for `500` and `5000`

### DGP contract

- families:
  - `normal`, `laplace`, `gausmix`
- taus:
  - `0.05`, `0.25`, `0.50`
- total simulation length:
  - `9000`
- warmup discard:
  - `2000`
- kept main root:
  - `7000`
- state dimension:
  - `6`
- trend:
  - local linear trend
- harmonics:
  - `1` and `2`
- period:
  - `90`
- initial covariance:
  - `C0 = 0.01 * I`
- seasonal amplitude:
  - encoded through nonzero `m0`
- observation noise:
  - `normal`: `sigma = 10`
  - `laplace`: `scale = 10`
  - `gausmix`: sds `(0.5, 15)`, weights `(0.1, 0.9)`, offset `+1`

### Important stabilization choice

Use `initial_state_mode = deterministic_m0`.

Reason:
- the requested `C0 = 0.01 * I` is small overall, but it is still too large relative to the intentionally tiny slope component
- drawing the initial state from `C0` would swamp the intended small slope with random initialization noise
- keeping the initial state fixed at `m0` preserves the requested slope/seasonal design cleanly while still documenting `C0` in the model contract

### Tau/family coupling

- within a fixed family, the latent path `mu_t` is shared across tau
- tau-specific observed series are created by deterministic quantile-centering shifts on the same raw noise draw
- this preserves the old study philosophy

### Q-DESN materialization layer

- materialize Q-DESN-specific windows from the canonical roots with the existing split contract
- effective fit sizes:
  - `500`, `5000`
- materialized total sizes:
  - `813`, `5313`
- do this with the existing `qdesn_dynamic_crossstudy_materialize_source_inputs()` path so the washout contract remains unchanged

### Review surface

Generate a separate flat audit pack containing:

- `18` canonical exDQLM tail windows
- `18` Q-DESN washout windows

Keep the audit pack separate from the main root bundle so it is easy to review before any study relaunch.

## Acceptance Checks

- generator script produces `9` full roots and `18` canonical tail windows
- Q-DESN materialization produces `18` washout windows
- audit pack renders `36` flat PNGs cleanly
- all file shapes are reproducible from seeds and manifests
- helper logic is portable enough to be copied into the `0.4.0` validation worktree later
