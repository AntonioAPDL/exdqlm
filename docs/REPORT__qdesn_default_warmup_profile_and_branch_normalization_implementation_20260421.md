# Default Warmup Profile and Branch Normalization

Date: 2026-04-21

## Scope

This implementation completed two related stages:

1. establish a package-native default warmup profile in the shared `0.4.0`
   base so ordinary users do not need to hand-tune advanced warmup lists for
   common exAL / exdqlm use; and
2. propagate and normalize that shared package layer across the `0.4.0`
   validation-study branch and the qdesn validation-study branch.

The design goal was to reduce user burden while keeping advanced controls
available for hard numerical cases and rescue workflows.

## Baseline policy implemented

The shared baseline is intentionally conservative:

- `rhs` / `rhs_ns` priors keep automatic tau warmup with
  `freeze_tau_warmup_iters = 50L`.
- exAL VB gets a light default `(sigma, gamma)` warmup profile.
- exAL MCMC gets a light default `(sigma, gamma)` warmup profile.
- explicit `vb_control` / `mcmc_control` overrides remain available and win
  cleanly.
- stronger theta / latent-state / precision rescue layers remain available, but
  they are not part of the universal default profile.

The default profile is applied at the package entrypoint layer rather than by
forcing all users through large nested warmup lists.

## Stage 1 implementation

The shared `0.4.0` package layer was updated so:

- default sigmagam warmup profiles are applied automatically in:
  - `exalStaticLDVB()`
  - `exalStaticMCMC()`
  - `exdqlmLDVB()`
  - `exdqlmMCMC()`
- effective warmup is clamped to the available `max_iter` / `n_burn` budget
  rather than silently increasing runtime
- docs and README guidance now present the automatic profile as the normal path
  and manual warmup tweaking as the advanced path
- focused regression tests cover default resolution, override precedence, and
  clamp behavior

## Late API-quality fix

During propagation, a subtle builder issue surfaced:

- `exal_make_vb_control(control = ...)`
- `exal_make_mcmc_control(control = ...)`

could still clobber an incoming `control` list because scalar defaults were
being reapplied too eagerly.

This was fixed in the shared base by changing the builders to:

- preserve an existing `control=` list
- fill only missing defaults
- let explicitly supplied arguments override the inherited control values
- normalize any carried-forward nested warmup blocks before returning

This change was then propagated to the two validation branches so the shared
package layer behaves consistently everywhere.

## Stage 2 normalization

After the shared base was stabilized, the package-layer normalization was
completed across the three branches:

1. `0.4.0` package branch:
   the shared package base
2. `0.4.0` validation-study branch:
   the shared package base plus validation-study machinery
3. qdesn validation-study branch:
   the same shared package base plus validation-study machinery plus qdesn-only
   rescue and readout-specific controls

The qdesn branch kept its richer inference-control superset, but the shared
package-facing files that should be identical now match the `0.4.0` base.

## Shared-file normalization result

The following package-layer files were checked after propagation and matched
across the branches where they should be shared:

- `R/exalStaticLDVB.R`
- `R/exalStaticMCMC.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `R/exdqlm-package.R`
- `README.Rmd`
- `README.md`
- `NEWS.md`

Intentional remaining qdesn divergence is concentrated in the richer qdesn
inference-control layer and qdesn-specific tests.

## Verification

Verification covered:

- `roxygen2::roxygenise()` where needed
- `pkgload::load_all(".", quiet = TRUE)`
- focused regression slices for:
  - warmup builder normalization
  - static / dynamic warmup defaults
  - clamp behavior
  - static diagnostics
  - qdesn-specific wrapper and inference-control behavior

One non-fatal roxygen note remained during regeneration:

- in topic `exdqlmMCMC`, `@inheritParams` reports that all parameters are
  already documented and none remain to be inherited

This did not block documentation generation or test verification.

## Outcome

The resulting package story is cleaner:

- users get a sensible default warmup profile automatically
- manual warmup tweaking is still available as an advanced last-resort path
- the shared package layer is normalized across the three branches
- qdesn keeps the extra rescue machinery that should remain qdesn-specific
