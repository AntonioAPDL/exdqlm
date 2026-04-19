# QDESN Tau050 Crash-Recovery Program

Date: 2026-04-19

## Executive Summary

The best next move is **not** another broad rerun of all failed fits.

The best next move is a **staged crash-recovery program**:

1. tighten the experiment surface so the specs are clean and comparable
2. run a **single-root probe matrix**
3. promote the best-performing spec to a **small representative triad**
4. only then spread it to the remaining failed cohort

This is the highest-quality path because it balances:

- scientific learning
- compute efficiency
- reproducibility
- clean attribution of what actually helps

This note is the canonical program plan for that path.

## What We Know Now

### Source campaign

The source campaign was the April 16, 2026 `tau050_refreshed_main` run:

- total fits: `144`
- hard failed fits: `23`
- acceptable source-run fits (`PASS` or `WARN`): `95`

The crash-repair target remains the original `23` hard MCMC numerical failures.

Canonical crash-only grids:

- [failed MCMC AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv)
- [failed MCMC EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv)

### What previous relaunches taught us

From the completed `sfreeze` rerun:

- [sfreeze postmortem](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_failed_mcmc_sfreeze_postmortem_20260419.md)

we now know:

- `8 / 23` crashed fits became `SUCCESS`
- `5 / 23` became user-acceptable `PASS` or `WARN`
- `15 / 23` still hard-failed
- all remaining hard failures are now `fit_size = 5000`
- the hard failure family is still latent-`v` invalid draws
- most remaining failures happen **after thaw**
- `rhs_ns` is materially weaker than `ridge`
- the hard surface is concentrated in `tau = 0.25 / 0.50`, especially
  `laplace` and `gausmix`

### What theta-freeze currently gives us

The theta-freeze lane is implemented and verified here:

- [thetafreeze implementation report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_failed_mcmc_thetafreeze_and_gig_floor_implementation_20260419.md)
- [thetafreeze relaunch plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_failed_mcmc_thetafreeze_relaunch_20260419.md)

Current theta-freeze lane properties:

- MCMC tau freeze: on
- MCMC theta freeze: on
- latent-`v` freeze: off
- latent-`s` freeze: off
- bounded rescue: off
- GIG floor: `1e-10`

Important nuance:

- the current theta-freeze lane does **not** explicitly pin VB tau freeze
  inside its dedicated defaults file
- that is acceptable for implementation validation, but it is **not ideal for
  the scientific probe**

So before any live theta-freeze experiment, the spec should be cleaned up to
make the VB tau policy explicit again.

## What We Want

We want a next-step program that:

1. isolates the **cause** of the remaining failures, not just the symptoms
2. minimizes wasted compute
3. produces a spec we can **promote** to the other failed runs if it works
4. preserves run-to-run comparability and auditability
5. keeps documentation, manifests, and launch wrappers clean

In other words, we do not just want a new rerun. We want a **recovery program**
that can scale from one fit to the whole failed cohort once it earns that
promotion.

## What We Have

We already have the building blocks:

- exact crash-only source manifests
- completed `sfreeze` evidence
- a working theta-freeze implementation
- a hardened GIG floor at `1e-10`
- wrapper support for failed-only relaunch phases
- structured latent-`v` failure payloads

So the missing piece is no longer infrastructure. The missing piece is a
sharper, staged experiment design.

## Recovery Program Design

### Phase 0: Spec cleanup before any live probe

Before launching anything, tighten the current theta-freeze lane.

Required cleanup:

1. explicitly add VB tau freeze back into the probe spec:
   - `freeze_tau_iters = 50`
   - `freeze_tau_warmup_iters = 50`
   - `force_tau_after_warmup = true`
2. explicitly add the same tau warm-start controls into the MCMC VB warm-start
   block
3. keep the MCMC side unchanged for the first probe:
   - tau freeze on
   - theta freeze on
   - latent-`v` off
   - latent-`s` off
   - rescue off
4. keep the current GIG floor at `1e-10`

Why:

- this removes ambiguity in the “theta + tau” story
- it gives us a clean experimental baseline before we add rescue or stronger
  floors

### Phase 1: Single-root probe

Run the single-root matrix defined here:

- [single-root crash probe matrix](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_single_root_crash_probe_matrix_20260419.md)

Primary probe fit:

- `mcmc_exal`
- `laplace`
- `tau = 0.50`
- `fit_size = 5000`
- `rhs_ns`

First-pass arms:

1. `tau only`
2. `theta + tau`
3. `s + tau`

Escalation arms only if needed:

4. `theta + tau + bounded latent-v rescue`
5. `theta + tau + stronger configurable GIG floor`

This is the cheapest experiment that can still distinguish:

- whether theta adds value beyond tau
- whether the previous best `sfreeze` behavior still dominates
- whether rescue is needed immediately

### Phase 2: Representative triad

Do **not** promote directly from one fit to all remaining failures.

If Phase 1 looks promising, promote to a 3-root representative set:

1. the original primary probe:
   - `laplace / tau 0.50 / 5000 / rhs_ns / exal`
2. a prior comparator:
   - `laplace / tau 0.50 / 5000 / ridge / exal`
3. a lane comparator:
   - `laplace / tau 0.50 / 5000 / rhs_ns / al`

Why:

- this tells us whether the winning Phase 1 spec generalizes across
  `rhs_ns` vs `ridge`
- and whether it generalizes across `exal` vs `al`

This triad is the smallest coherent “spread” test before a cohort rerun.

### Phase 3: Promotion to clustered cohorts

Only after the representative triad performs well should we spread to the other
failed roots.

Promotion order:

1. `laplace` long-window hard-fail cohort
2. `normal` long-window hard-fail cohort
3. `gausmix` long-window hard-fail cohort

Why this order:

- `laplace` is hard but interpretable
- `normal` checks whether the spec generalizes to a less pathological family
- `gausmix` is the noisiest and should be last

### Phase 4: Full remaining failed cohort

Only if the promoted cohort behavior is stable should we rerun the remaining
hard-fail surface broadly.

At that point, use the exact frozen manifests for the remaining hard-fail roots,
not regenerated ad hoc selections.

## Recommended Experiment Families

This is the improved hierarchy over the current single-root note.

### Family A: Clean structural comparisons

These are the first experiments to run.

- `tau only`
- `theta + tau`
- `s + tau`

These answer the most important structural question:

- which stabilization direction is strongest before rescue logic enters?

### Family B: Rescue-enhanced comparisons

These only come after Family A.

- `theta + tau + bounded latent-v rescue`
- optionally `tau only + bounded latent-v rescue`

These answer:

- is the remaining post-thaw crash surface best handled by rescue rather than
  more freeze?

### Family C: GIG-floor sensitivity

These are third-line experiments, not first-line ones.

- current floor: `1e-10`
- stronger floor: `1e-8`

These only matter if:

- Family A and B still leave the same tiny-`chi_v` crash regime

## What “Ready To Implement” Means

The next implementation package should produce isolated assets, not mutate the
main relaunch lanes in place.

Recommended assets:

### Configs

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_tau_only_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_stau_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_rescue_defaults.yaml`
- optional configurable-floor variants if we promote Group C

### Grids

- one-row primary probe grid
- optional one-row comparator grids
- later a triad grid

### Wrappers

Extend the existing wrappers with clearly named probe phases:

- `single_root_probe_exal_tau_only`
- `single_root_probe_exal_theta_tau`
- `single_root_probe_exal_stau`
- `single_root_probe_exal_theta_tau_rescue`
- later triad phases

### Documentation

For each phase:

1. implementation report
2. prepare-only report
3. launch report
4. comparison/postmortem report

## Success Gates

### Promote from Phase 1 to Phase 2 only if:

- one arm clearly outperforms the others
- and either:
  - completes successfully
  - reaches keep phase where the others do not
  - or materially shifts failure timing / regime

### Promote from Phase 2 to Phase 3 only if:

- the same winning arm remains best across:
  - `rhs_ns` vs `ridge`
  - `exal` vs `al`

### Promote from Phase 3 to broad rerun only if:

- the winning spec produces acceptable behavior on more than one family group
- and does not regress badly on `ridge`

## Failure Gates

Stop and redesign if:

- `tau only`, `theta + tau`, and `s + tau` all fail in nearly identical ways
- bounded rescue does not materially extend the chain
- stronger GIG floor does not change the failure regime

If that happens, the next step is no longer more scheduler tuning. It becomes a
deeper sampler redesign problem.

## Best Current Recommendation

The strongest plan we can make today is:

1. clean up the theta-freeze probe spec by explicitly restoring VB tau freeze
2. implement the isolated single-root matrix
3. run the first three structural arms only
4. add rescue only if the first three do not separate
5. promote to a representative triad before any broader rerun

That is stronger than the current single-root note because it is:

- more staged
- more comparable
- safer to spread
- and already structured for cohort promotion if one spec wins

## Bottom Line

Yes, we can do better than “just run one root and see.”

The best next move is a **staged crash-recovery program**:

- clean theta-freeze spec
- single-root probe
- representative triad
- clustered cohort promotion
- full remaining-cohort rerun only at the end

That is the most informed, efficient, and reproducible path forward.
