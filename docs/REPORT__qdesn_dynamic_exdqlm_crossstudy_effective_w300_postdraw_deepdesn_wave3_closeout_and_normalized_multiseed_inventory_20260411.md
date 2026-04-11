# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Wave 3 Closeout And Normalized Multiseed Inventory

Date: 2026-04-11
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Close out the completed deep-DESN rhs-long MCMC wave, decide whether its completed results should
be promoted into the working deep-DESN challenger source, record the true post-promotion residual
surface, and investigate whether a normalized multiseed relaunch is really the right next move.

This report is about the **working deep-DESN challenger line**, not the authoritative simple-DESN
zero-FAIL branch-local comparison baseline.

## 2) Completed Wave

Completed wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`
- stage status:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523/tables/stage_execution_status.csv`

Wave completion:

- `4 / 4` stages completed
- `15 / 15` profiles completed
- `0` `root_error.txt` files

Stage outcomes:

- `F1_rhs_long_gausmix_mcmc -> KEEP_SOURCE_BASELINE`
- `F2_rhs_long_laplace_exal -> KEEP_SOURCE_BASELINE`
- `F3_rhs_long_normal_lower_mcmc -> F630_rhs_long_normal_lower_guard320_recenter4000`
- `F4_rhs_long_normal_upper_exal -> KEEP_SOURCE_BASELINE`

## 3) Promotion Decision

Only one completed `F`-wave result is strong enough to promote into the working deep-DESN
challenger source:

- `F630_rhs_long_normal_lower_guard320_recenter4000`

Why `F630` is justified:

- it is the only completed `F`-wave profile that reduces target fit FAIL rows versus the incoming
  promoted source;
- it does so without introducing root-status failures;
- the stage-local winner is explicit in the completed `F3` stage outputs.

Why the rest should **not** be promoted:

1. `F1` did not beat the source baseline
- the completed gausmix long-horizon MCMC ladder did not improve the targeted fail surface;
- the stage recommendation is therefore correctly `KEEP_SOURCE_BASELINE`.

2. `F2` did not produce a clean source replacement
- the completed laplace exAL ladder did not beat the source stage-wide;
- tempting root-level changes would only move fail pressure around or introduce new risk.

3. `F4` did not beat the source
- the singleton upper-tail exAL stage completed cleanly, but did not justify an override.

## 4) What Improved

Working deep-DESN challenger source entering Wave 3:

- `71 PASS`
- `59 WARN`
- `14 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Working deep-DESN challenger source after promoting `F630`:

- `71 PASS`
- `60 WARN`
- `13 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Net change versus the pre-`F` promoted challenger source:

- fit FAIL rows:
  - `14 -> 13` (`-1`, `-7.1%`)
- WARN rows:
  - `59 -> 60` (`+1`)
- root-status FAILs:
  - `0 -> 0`
- comparison readiness:
  - unchanged at `36 / 36` comparison-eligible-any and `27 / 36` comparison-eligible-full

Interpretation:

- this wave did **not** broadly reopen the surface;
- it delivered one clean residual reduction and three evidence-backed keep-source decisions;
- that is a disciplined success, not a weak outcome.

## 5) What Still Fails

Current working deep-DESN challenger residual after promoting `F630`:

- `13` fit FAIL rows
- `0` root-status FAILs
- every remaining FAIL row is:
  - `prior = rhs_ns`
  - `fit_size = 5000`
  - `method = mcmc`

Residual split by family and model:

| Family | `al` FAIL | `exal` FAIL | Total |
| --- | ---: | ---: | ---: |
| `gausmix` | `3` | `3` | `6` |
| `laplace` | `0` | `3` | `3` |
| `normal` | `2` | `2` | `4` |

Residual split by family and tau:

| Family | Tau | FAIL rows |
| --- | ---: | ---: |
| `gausmix` | `0.05` | `2` |
| `gausmix` | `0.25` | `2` |
| `gausmix` | `0.95` | `2` |
| `laplace` | `0.05` | `1` |
| `laplace` | `0.25` | `1` |
| `laplace` | `0.95` | `1` |
| `normal` | `0.05` | `1` |
| `normal` | `0.25` | `2` |
| `normal` | `0.95` | `1` |

Residual signoff reasons:

| Signoff reason | Rows |
| --- | ---: |
| `high_autocorrelation; geweke_drift; half_chain_drift` | `5` |
| `high_autocorrelation; half_chain_drift` | `3` |
| `geweke_drift` | `2` |
| `high_autocorrelation` | `2` |
| `half_chain_drift` | `1` |

Interpretation:

- the residual is now a pure long-horizon MCMC diagnostics / mixing problem;
- there is no remaining execution debt;
- there is no remaining ridge debt;
- there is no remaining short-horizon debt;
- there is no remaining VB-specific fail surface.

## 6) Which Ideas Worked Best

The strongest ideas across the recent `D` + `E` + `F` sequence are still:

1. stage-local promotion over one universal replacement
- `E410`, `E520`, `E620`, and now `F630` all helped in their own pockets;
- the recent evidence continues to reward local tuning.

2. exact-root carry-forward only when it is strictly cleaner
- the prior `E530` exact-root carry-forward was worth keeping;
- the same standard prevented weak `F2`-style exact-root temptations from entering the source.

3. moderate normal lower-tau strengthening can help
- `F630` reduced the lower-tau normal long-horizon MCMC fail surface from `4` to `3`;
- the milder guard-and-recenter shape beat both the lighter and more aggressive neighbors.

4. disciplined keep-source decisions save compute and stability
- `F1`, `F2`, and `F4` did not justify overrides;
- closing those stages with `KEEP_SOURCE_BASELINE` is part of the scientific result.

## 7) Which Ideas Did Not Help

The completed evidence is now strong enough to reject or deprioritize:

1. another gausmix replay of the same long-horizon MCMC ladder
- `F1` completed and still kept source;
- more of the same geometry would be low-value.

2. another laplace exAL replay in the same neighborhood
- `F2` did not beat the source cleanly;
- the residual laplace pocket remains diagnostics-heavy and does not justify reusing the same
  family ladder unchanged.

3. another singleton upper-tail exAL replay
- `F4` validated the existing source rather than improving it.

4. a blind replay of the whole `F`-wave geometry family
- one profile helped;
- three stage families did not;
- the next move should be based on a changed contract, not a repeated ladder.

## 8) Is A Normalized Multiseed Relaunch Really The Right Next Move?

Short answer:

- **yes, conditionally**
- **no, not as an immediate blind relaunch**

Why the direction is justified:

1. the remaining debt is homogeneous
- after `F630`, all residual FAIL rows are long-horizon `rhs_ns` MCMC at `fit_size = 5000`;
- that is exactly the kind of surface where standardized MCMC settings plus seed robustness are
  more coherent than another ad hoc ladder.

2. recent local geometry search is mostly exhausted
- `F1`, `F2`, and `F4` all said keep source;
- more family-local tuning in the same geometry neighborhood is unlikely to have strong expected
  value.

3. the branch already has precedent for replicated evaluation
- benchmark-side `seed_set` pooling and selection by CRPS already exists;
- multichain follow-up utilities already define a clean `PASS > WARN > FAIL` grading score and
  deterministic seed generation;
- the new design can reuse these ideas rather than inventing a brand-new logic family.

Why the direction is **not** launch-ready yet:

1. dynamic validation does not yet have a first-class multiseed layer
- the current dynamic fit-fail wave machinery selects profiles and exact-root overrides, but not
  per-profile seed winners.

2. MCMC RNG seeding is not yet exposed the way this plan needs
- the dynamic pipeline currently carries root seed into DESN config;
- real MCMC replicate control must flow through `mcmc_control$rng_seed` or `mcmc_control$seed`,
  and likely `vb_warm_start_seed` as well.

3. `nd_draws = 20000` is **not** enough to guarantee `20000` true stored MCMC posteriors
- the current posterior draw helper can resample from a smaller saved chain;
- if the intent is literal stored MCMC posterior draws, `n_mcmc` itself must be raised.

4. storage pressure is already a real branch constraint
- this branch already hit `/home` storage exhaustion from heavy raw artifacts;
- a four-seed, `20000`-draw relaunch needs an explicit compact-output or pruning policy for
  non-winning seeds before launch.

## 9) Recommendation

The right next move is:

1. freeze the working deep-DESN challenger source at the post-`F630` state
- `71 PASS / 60 WARN / 13 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`

2. do **not** launch another geometry-only residual wave by default
- the recent evidence does not support it.

3. investigate and plan a normalized multiseed relaunch before touching new compute
- standardize long MCMC settings,
- make seed control explicit and reproducible,
- define the seed-selection rule in code and docs,
- and add a storage-safe output contract before launch.

That is the right path if we want the next batch to be scientifically cleaner, operationally
safer, and easier to maintain than another narrow geometry replay.
