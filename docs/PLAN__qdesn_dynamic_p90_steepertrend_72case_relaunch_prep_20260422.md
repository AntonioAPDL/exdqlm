# Dynamic P90 Steepertrend 72-Case Relaunch Prep Plan

Date: 2026-04-22

## 1) Purpose

Prepare the next Q-DESN dynamic relaunch on the promoted period-90 steeper
trend dataset surface using the normalized shared warmup defaults and the best
non-rescue baseline behavior from the recent validated runs.

This relaunch is meant to validate three things together:

- the new promoted dynamic dataset surface;
- the normalized `0.4.0`-derived package/warmup layer; and
- the current Q-DESN dynamic launch stack after the recent inference and
  warmup normalization work.

It should therefore be:

- reproducible;
- explicit about what is baseline versus rescue;
- staged from committed state; and
- easy to extend from `72` fits to `144` fits later without changing the
  dataset contract.

## 2) Big-Picture Recommendation

The cleanest launch sequence is:

1. freeze the promoted dataset as the active source-of-truth
2. implement a new relaunch surface rooted in that dataset, without rewriting
   the historical tau050 study assets in place
3. run a baseline `72`-fit study on a single prior surface
4. use only the normalized shared defaults in that baseline
5. expand to the second prior only after the baseline behaves cleanly

### Recommended first 72-case surface

Recommended first prior:

- `ridge`

Why:

- it is the cleaner prior for confirming the new dataset and the normalized
  codebase;
- it keeps the first relaunch focused on end-to-end stability rather than on
  the hardest shrinkage behavior immediately;
- it gives the cleanest signal about whether the new datasets and updated
  scripts are working.

### Recommended second 72-case surface

Second prior after the first pass:

- `rhs_ns`

Why:

- it explicitly validates the automatic tau-warmup/default-shrinkage story;
- it is the right follow-on expansion once the cleaner ridge baseline has
  confirmed the general pipeline behavior.

This keeps the rollout disciplined:

- first `72` = clean baseline
- second `72` = shrinkage stress layer
- together they reproduce the full `144`-fit comparison surface

## 3) Relaunch Scope

Primary baseline target:

- `18` effective source windows
- one prior surface
- methods:
  - `vb`
  - `mcmc`
- likelihood families:
  - `al`
  - `exal`

Total baseline:

- `72` fits

Optional expansion:

- add the second prior surface with the same source windows and fit geometry
- total becomes `144` fits

## 4) Dataset Contract

Active promoted scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Canonical roots:

- `9`

Canonical validation windows:

- `18`
  - `lastTT500`
  - `lastTT5000`

Q-DESN materialized windows:

- `18`
  - `effTT500_totalTT813`
  - `effTT5000_totalTT5313`

Important exact sizing rule:

- the user-facing effective fit sizes remain:
  - `500`
  - `5000`
- but the staged Q-DESN source totals remain:
  - `813`
  - `5313`

Reason:

`source_total_size = effective_fit_size + holdout_n + lag_max + washout`

with:

- `holdout_n = 1`
- `lag_max = 12`
- `washout = 300`

So while the intuitive shorthand is “use about `800` and `5300` so the last
`500` and `5000` remain after washout,” the exact reproducible contract is:

- `813`
- `5313`

That exact contract should be preserved in the next relaunch.

## Baseline launch policy

Use the shared normalized package defaults as the baseline:

- automatic `rhs` / `rhs_ns` tau warmup with `50L`
- light automatic exAL VB `(sigma, gamma)` warmup
- light automatic exAL MCMC `(sigma, gamma)` warmup
- `init_from_vb = TRUE` for MCMC where available

Do not start from the historical hard-rescue overlays.

Keep these out of the baseline unless failures force them back in:

- theta freeze rescue
- latent-state rescue
- Q-DESN precision rescue
- row-local repair overlays

## 5) Recommended Baseline Spec Matrix

The baseline should be case-specific in a structured way.

That does **not** mean one ad hoc spec per row. It means one explicit baseline
policy per major case family.

### 5.1 Shared study-wide budgets

Use one common long-budget contract across the whole relaunch:

- `vb.max_iter = 300`
- `vb.min_iter_elbo = 80`
- `vb.n_samp_xi = 1000`
- `mcmc.n_burn = 5000`
- `mcmc.n_mcmc = 20000`
- `mcmc.thin = 1`
- `posterior_metric_draws = 20000`
- `vb_sampling_nd_draws = 20000`
- `vb_synthesis_n_samp = 20000`
- `washout = 300`

These should be pinned explicitly in the relaunch defaults manifest even if the
package-level defaults already imply some of them, because the launch contract
needs to be reproducible from one checked-in source.

### 5.2 VB baseline

For all VB fits:

- use `LDVB`
- use the long common iteration budget above
- keep the normalized default warmup surface active

For exAL VB specifically:

- keep the light automatic `(sigma, gamma)` warmup active
- do not start from the stronger tau/theta/latent rescue variants

For `rhs_ns` VB specifically:

- keep automatic tau warmup active with `50L`
- do not elevate to rescue-specific tau/theta combinations unless failures
  force that later

### 5.3 MCMC baseline

For all MCMC fits:

- use `slice`
- require `init_from_vb = TRUE`
- ban `rw`
- ban `laplace_rw`
- keep the long common burn/keep budget above

For exAL MCMC specifically:

- keep the light automatic `(sigma, gamma)` warmup active
- keep the VB warm-start path explicit and auditable

For `rhs_ns` MCMC specifically:

- keep automatic tau warmup active with `50L`
- keep `force_tau_after_warmup = TRUE`
- do not start from theta-freeze or latent-rescue overlays in the baseline

### 5.4 What stays out of baseline

These remain escalation-only:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue (`ladder_v2`, `eigen_v1`)
- row-local replay overrides

That separation is crucial because this relaunch is meant to test the new
dataset and the normalized package layer first, not to start from the old
failure-driven repair stack.

## 6) Phase Structure

Borrow the parts of the refreshed tau050 relaunch that aged well:

- explicit phase subsets
- committed-state preflights
- smoke-before-full execution
- run-tag and healthcheck discipline

### Stage A: source-grid rewrite

- rewrite the next dynamic relaunch grid to point at the promoted source
  scenario
- keep the historical tau050 refreshed-main grid untouched
- generate a fresh relaunch surface as a new campaign namespace

Recommended checked-in assets:

- one baseline defaults manifest
- one canonical full grid
- audited subset grids for:
  - smoke
  - VB full lane
  - MCMC fit-size `500`
  - MCMC fit-size `5000`
- one materializer
- one launch wrapper
- one healthcheck

### Stage B: committed-state preflight

Run `prepare-only` from committed state for:

- smoke subset
- full baseline surface

These preflights must confirm:

- promoted dataset paths resolve correctly
- `813 / 5313` source totals are preserved
- the effective-fit semantics are still `500 / 5000`
- default warmup resolution is visible and correct
- outputs/report roots are created cleanly

### Stage B: smoke / canary

- run a small smoke slice first
- verify:
  - source path correctness
  - warmup default resolution
  - VB and MCMC launch behavior
  - output/report plumbing

Recommended smoke coverage:

- all three families
- both fit sizes
- both likelihood families
- both methods
- the first-prior surface selected for the baseline

### Stage C: full baseline execution

- run VB lane first if the implementation makes that easy to monitor
- then run the full MCMC baseline lane
- keep healthchecks phase-aware

This phasing is especially useful because it lets us separate:

- optimizer-side instability
- MCMC-side instability
- long-window (`5000`) runtime pressure

### Stage D: post-baseline decision

After the first `72` completes:

- if the baseline is clean enough, freeze it as the canonical first-pass study
- then decide whether to expand to the second prior surface
- only after that consider rescue overlays on targeted failures

## 7) Why this is the right baseline

The recent normalization work already encoded the best package-level lessons:

- users should not need to hand-tune warmup by default
- tau warmup should happen automatically for shrinkage priors
- light exAL sigmagam warmup should happen automatically
- aggressive rescue logic should stay in reserve rather than polluting the main
  study path

That makes the next relaunch a cleaner validation of the updated codebase:

- new shared warmup defaults
- new normalized package layer
- new promoted dynamic dataset

The most important scientific/engineering choice here is:

- use the best recent successful baseline as the default study contract
- but do **not** preload the old row-specific rescue machinery into the new
  dataset surface

That is the cleanest validation of whether the updated code and the new
datasets are healthy.

## 8) Required Prep Artifacts

- new relaunch grid rooted in the promoted scenario
- new relaunch defaults manifest rooted in the shared package defaults
- a new branch-local tracker with explicit gates
- a short relaunch plan/report tying the new run to the promoted dataset
- a clear mapping from `72`-fit baseline to optional `144`-fit expansion

## 9) Success Criteria

The relaunch is ready to implement when:

1. the promoted dataset selection is frozen and documented
2. the `0.4.0` validation worktree has a clear sync prompt to reproduce the
   same canonical datasets
3. the first-prior baseline has an explicit, auditable defaults manifest
4. the canonical grid and subset grids are generated from the promoted source
5. committed-state `prepare-only` passes on both smoke and full surfaces
6. the smoke run lands without early execution failures
7. the branch has a live tracker for post-launch monitoring and expansion
