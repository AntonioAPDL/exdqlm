# QDESN tau050 Remaining-Failure Investigation

Date: 2026-04-18

## Scope

This note investigates the remaining failed cases after the first targeted
failed-only rerun of the refreshed-main tau050 campaign.

Source full campaign:
- `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`

First failed-only rerun:
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955`

The rerun used the stronger warmup contract that was added after the source
campaign:
- VB warm start `min_iter_elbo: 80` instead of `20`
- VB RHS-NS tau freeze `50` instead of `10`
- MCMC RHS-NS tau freeze burn-in `500` instead of `250`/`400`
- new VB `sigmagam` warmup:
  - `freeze_warmup_iters: 10`
  - `postwarmup_damping: 0.5`
  - `postwarmup_damping_iters: 3`
- new MCMC `sigmagam` freeze:
  - `freeze_burnin_iters: 50`

Important control read:
- the rerun changed warmup behavior, but it did **not** change the slice-kernel
  widths or core update mode relative to the source run for the same lane
  families.

## Outcome

The targeted rerun completed all `23/23` cases.

| Lane | Total | Recovered | Failed Again | Recovery Rate |
|---|---:|---:|---:|---:|
| `mcmc_al` | 9 | 2 | 7 | 22.2% |
| `mcmc_exal` | 14 | 3 | 11 | 21.4% |
| Overall | 23 | 5 | 18 | 21.7% |

Recovered cases:
- `mcmc_al`
  - `normal / tau=0.05 / TT5000 / ridge`
  - `laplace / tau=0.25 / TT5000 / rhs_ns`
- `mcmc_exal`
  - `gausmix / tau=0.05 / TT5000 / rhs_ns`
  - `laplace / tau=0.50 / TT5000 / ridge`
  - `normal / tau=0.05 / TT500 / rhs_ns`

Important nuance:
- only `1/5` recovered cases came back with a clean `PASS` signoff
- `4/5` recovered cases still finished with `WARN` or `FAIL` signoff because of
  `high_autocorrelation`, `geweke_drift`, or `chain_marginal_but_usable`

So the rerun materially improved operational completion for some cases, but did
not broadly restore clean scientific health.

## Remaining-Failure Pattern

### 1. The repeat failures are still the same hard numerical crash

All `18/18` repeat failures still show the same log signature:
- `exal_mcmc_fit::latent_v returned ... invalid draws ... value=NA`

This means the rerun did **not** uncover a new dominant failure mode. The
remaining surface is still the original latent-`v` numerical instability.

### 2. Recovery is strongly concentrated at lower tau

| tau | Success | Total | Recovery Rate |
|---|---:|---:|---:|
| `0.05` | 3 | 5 | 60.0% |
| `0.25` | 1 | 7 | 14.3% |
| `0.50` | 1 | 11 | 9.1% |

Read:
- the rerun helped much more at `tau=0.05`
- the remaining hard surface is concentrated at `tau=0.25` and especially
  `tau=0.50`

### 3. `gausmix` remains the hardest family

| Family | Success | Total | Recovery Rate |
|---|---:|---:|---:|
| `gausmix` | 1 | 10 | 10.0% |
| `laplace` | 2 | 6 | 33.3% |
| `normal` | 2 | 7 | 28.6% |

Read:
- `gausmix` is still the main hotspot
- the rerun did help one `gausmix` case, but the broader `gausmix` surface
  remains unstable

### 4. Prior does not separate the remaining failures cleanly

| Prior | Success | Total | Recovery Rate |
|---|---:|---:|---:|
| `rhs_ns` | 3 | 13 | 23.1% |
| `ridge` | 2 | 10 | 20.0% |

Read:
- `rhs_ns` and `ridge` behave similarly on the rerun surface
- this is important because it means the remaining problem is **not** just an
  RHS-NS tau issue
- tau policy still matters for `rhs_ns`, but it is not sufficient to explain
  the full remaining failure surface

### 5. The failures split into early and late crashes

The repeat failures are not all startup failures.

`mcmc_al`:
- very early: `2`
- mid burn-in: `2`
- late keep-phase: `3`

`mcmc_exal`:
- very early: `2`
- mid burn-in: `3`
- late keep-phase: `6`

Overall:
- early or burn-only failures: `9`
- late keep-phase failures: `9`

Read:
- stronger warmup is still a reasonable lever for the early and burn-phase
  crashes
- but warmup alone is unlikely to fully solve the late keep-phase crashes,
  because those chains are surviving well past the initial thaw and then
  destabilizing later

### 6. The warmup changes often bought more runtime, but not enough

For the repeat-failure subset only, the rerun-to-source runtime ratio had:
- minimum: `0.01x`
- median: `0.87x`
- maximum: `6.10x`

Examples where the rerun survived much longer but still failed:
- `mcmc_exal / gausmix / tau=0.25 / TT5000 / rhs_ns`: `6.10x`
- `mcmc_exal / gausmix / tau=0.25 / TT5000 / ridge`: `4.26x`
- `mcmc_al / normal / tau=0.50 / TT5000 / ridge`: `2.14x`

Examples where the rerun failed much earlier:
- `mcmc_exal / gausmix / tau=0.50 / TT5000 / ridge`: `0.01x`
- `mcmc_exal / gausmix / tau=0.50 / TT5000 / rhs_ns`: `0.16x`
- `mcmc_al / gausmix / tau=0.50 / TT5000 / rhs_ns`: `0.04x`

Read:
- the stronger warmup was not a no-op
- it often moved the crash boundary, and in some cases moved it far enough to
  recover the fit
- but the remaining surface is heterogeneous, so a single undifferentiated
  “more warmup” spec is unlikely to be the full answer

## What The Current Rerun Actually Tested

The first failed-only rerun was primarily a **warmup-spec test**:
- stronger VB tau freeze
- stronger MCMC tau freeze
- new VB `sigmagam` warmup
- new MCMC `sigmagam` freeze

What it did **not** test:
- a different slice `core_update_mode`
- a different `core_extra_passes`
- enabled RHS width adaptation
- any matrix conditioning mode
- any `multi_start` strategy

That matters because the remaining failures are still latent-`v` crashes, and
half of them are now late keep-phase failures. That suggests the next relaunch
should not be framed as “repeat the same rerun but a bit longer.”

## Reasonable Next Options

### Option A: Stronger warmup-v2 only

Reasonable if the immediate goal is to push further in the same direction with
minimal kernel change.

Recommended warmup-v2 pilot:
- keep VB tau freeze at `50`
- keep MCMC tau freeze burn-in at `500`
- raise VB `sigmagam.freeze_warmup_iters` from `10` to `20`
- raise VB `sigmagam.postwarmup_damping_iters` from `3` to `10`
- reduce VB `sigmagam.postwarmup_damping` from `0.5` to around `0.35` or `0.40`
- raise VB `sigmagam.min_postwarmup_updates` from `1` to `3`
- raise VB warm-start `max_iter` from `300` to `500`
- raise MCMC `sigmagam.freeze_burnin_iters` from `50` to `500` so the sigma/gamma
  thaw is aligned with the existing tau thaw

Why this makes sense:
- the rerun already showed that stronger warmup can rescue some cases
- a smoother and longer VB thaw is the highest-leverage next warmup change
- aligning the MCMC `sigmagam` freeze with the existing tau freeze makes the
  early burn-in contract more coherent

Limitation:
- because half of the remaining failures happen late in the keep phase,
  warmup-v2 alone is unlikely to be the final answer for all `18` cases

### Option B: Warmup-v2 plus targeted kernel-v1 pilot

Reasonable if the goal is to address the late-crash subset instead of just the
 early-crash subset.

Most reasonable kernel-v1 knobs already available in the current repo:
- for `exal` only, pilot `core_update_mode = "gamma_sigma_gamma"`
- keep `core_extra_passes = 2` initially; do not move this first unless the
  new pilot is still unstable
- enable RHS width adaptation during burn-in for `rhs_ns` cases
  - this is currently present but disabled
  - it is more evidence-backed than manually changing all slice widths at once
- consider `mcmc_control$conditioning$mode = "qr_whiten"` for the unstable
  late-phase subset, because the readout matrices can still be poorly
  conditioned and current successful chains report `conditioning_mode = none`

Why this makes sense:
- the first rerun changed warmup but left the slice kernel materially unchanged
- the remaining failures are not just startup failures, so a kernel lever is now
  justified

### Option C: RHS-NS-only extras for the `rhs_ns` subset

Reasonable, but narrower in scope.

Currently available:
- `multi_start` for RHS-enabled fits

Why this is secondary:
- it does not cover `ridge`
- `ridge` still fails at a similar rate, so this cannot be the primary
  explanation of the remaining surface

### Option D: Better failure instrumentation before the next full remaining-18 rerun

This is strongly recommended.

Right now we know the remaining failures are still latent-`v` crashes, but we
do not persist enough failure-state detail to distinguish:
- a bad `psi_v` / `chi_v` regime
- a repeated state-space corner involving `sigma`, `gamma`, `tau`, and `beta`
- a Devroye/GIG numerical breakdown on otherwise borderline-valid inputs

Recommended instrumentation targets before the next full rerun:
- record the iteration index at failure
- record whether failure occurs in burn or keep phase
- record `sigma`, `gamma`, and, when present, `tau` / `c2`
- record summaries of `chi_v` and `psi_v`
- save those values into the fit-level failure summary so they survive `Execution halted`

This is the most valuable non-launch code change before a large remaining-18 rerun.

## What Not To Prioritize First

These are not the first knobs to turn:
- `max_steps_out` / `max_shrink`

Reason:
- the logs do not show slice sampler exhaustion
- the remaining failures are latent-`v` invalid-draw crashes, not
  `slice sampler exceeded max_shrink`

These are acceptable only after stronger evidence:
- large manual changes to all slice widths at once
- a full remaining-18 rerun under one completely new compound spec without a canary

## Recommended Next Strategy

1. Keep the remaining failures split and reproducible.
2. Materialize exact remaining-failure grids from the completed rerun:
   - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv`
   - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv`
3. Add latent-`v` failure instrumentation before the next large relaunch.
4. Run a small canary on the remaining-failure surface under **warmup-v2 only**.
5. If warmup-v2 helps early crashes but not late crashes, branch:
   - use warmup-v2 for the early/mid-burn subset
   - use warmup-v2 plus kernel-v1 for the late subset
6. Only after that, launch the full remaining-18 rerun.

## Reproducibility Assets

Current source and rerun documentation:
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_relaunch_launch_20260418.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_relaunch_execution_20260418.md`
- `docs/PROPOSAL__qdesn_sigmagam_warmup_design_20260417.md`
- `docs/PROPOSAL__qdesn_exal_mcmc_kernel_redesign_20260329.md`

Remaining-failure inventory materializer:
- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_grids.R`

This note should be treated as the decision log for planning the next relaunch
of the remaining `18` failed fits.
