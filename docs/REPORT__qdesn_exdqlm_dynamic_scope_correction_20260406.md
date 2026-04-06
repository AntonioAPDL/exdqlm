# REPORT: QDESN vs exdqlm Dynamic Scope Correction (2026-04-06)

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
Reference repo: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

## 1) Executive Finding

The current `qdesn_static_exdqlm_crossstudy_*` program was scientifically coherent on its own
terms, but it was scoped to the wrong data surface for the intended comparison deliverable.

What was actually run:

- a QDESN analog of the **static** exdqlm signoff surface;
- root kinds:
  - `static_paper`
  - `static_shrink`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- fit sizes:
  - `100`
  - `1000`
- priors:
  - `ridge`
  - `rhs_ns`

What is actually wanted:

- a QDESN analog on the **dynamic** exdqlm validation surface so that, for the same dynamic
  dataset cell, family, tau, likelihood, and inference method, QDESN can be compared directly
  against exdqlm outputs.

## 2) What Caused The Mismatch

On 2026-04-04 the branch adopted the explicit working assumption that the next comparison-facing
program should be a static exdqlm analog rather than a dynamic exdqlm analog.

That assumption is documented in:

- `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
- `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
- `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`

The result was a complete static-only campaign that is useful as a side study, but not the final
comparison study the project actually needs.

## 3) What The Current Static Program Really Targeted

The checked-in static cross-study contract was:

- `72` QDESN roots
- `288` fit rows
- one root per:
  - `static_paper/static_shrink`
  - `gausmix/laplace/normal`
  - `tau in {0.05, 0.25, 0.95}`
  - `fit_size in {100, 1000}`
  - `beta_prior_type in {ridge, rhs_ns}`

Those assets remain valid as a completed side study and should be preserved, not deleted.

## 4) What The Intended Dynamic Comparison Surface Looks Like

Live reference evidence currently available in the exdqlm worktree shows a dynamic family-qspec
surface under:

- `results/function_testing_20260309_dynamic_dlm_family_qspec`

The current on-disk dynamic reference surface that was directly observed is:

- scenario:
  - `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- dynamic fit horizons:
  - `lastTT500`
  - `lastTT5000`

Observed dynamic reference dataset cells on disk:

- `18` unique cells total
- formula:
  - `1 scenario x 3 families x 3 taus x 2 fit horizons = 18`

Each of those exdqlm dynamic cells already carries the dynamic comparison tables needed for the
reference side:

- `pairwise_vb_vs_mcmc.csv`
- `model_pair_signoff.csv`
- `pairwise_exdqlm_vs_dqlm.csv`
- `report_summary.md`

## 5) Why The Existing QDESN Dynamic Grid Is Also Not The Same Thing

The existing QDESN dynamic certification grid in:

- `config/validation/qdesn_dynamic_family_prior_grid.csv`

is not the right analog to the exdqlm dynamic family-qspec surface either.

Current QDESN dynamic certification grid:

- scenarios:
  - `dlm_constV_smallW`
  - `dlm_constV_bigW`
  - `dlm_ar1V`
- taus:
  - `0.05`
  - `0.50`
  - `0.95`
- likelihoods:
  - `exal`
  - `al`
- priors:
  - `ridge`
  - `rhs_ns`

This grid:

- has no family axis;
- uses `tau = 0.50`, while the observed exdqlm dynamic family-qspec surface uses `0.25`;
- is a dynamic certification surface, not an exdqlm-aligned family-qspec comparison surface.

So the current branch actually has:

1. a completed static exdqlm analog study;
2. an existing QDESN dynamic certification matrix;
3. but not yet the dynamic exdqlm-aligned QDESN study that is actually wanted.

## 6) Correction Decision

The correct decision is:

1. preserve the completed static cross-study as a side study;
2. stop treating it as the primary comparison deliverable;
3. reconstruct the canonical **dynamic exdqlm comparison surface** directly from the live reference
   roots on disk;
4. build a new QDESN dynamic analog on that exact surface;
5. relaunch the validation program on that dynamic surface in batch mode;
6. only after that, decide whether any local follow-up tuning is needed.

## 7) Correct Target Grid

If the current observed dynamic exdqlm family-qspec surface is confirmed as canonical, the new
QDESN analog should be:

- `18` dynamic dataset cells
- `2` QDESN priors:
  - `ridge`
  - `rhs_ns`
- total QDESN roots:
  - `18 x 2 = 36`

Per root, run:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Expected total QDESN fit rows:

- `36 x 4 = 144`

## 8) Correct Comparison Contract

The desired comparison is:

- same dynamic dataset cell
- same family
- same tau
- same fit horizon
- same inference method
- same likelihood

Then compare:

- QDESN under `ridge` or `rhs_ns`
- against the corresponding exdqlm dynamic reference output

The QDESN prior axis is an extra comparison dimension on the QDESN side. It should be preserved,
not collapsed away.

## 9) Bottom Line

The current branch has been fitting the right model family to the wrong dataset surface for the
intended comparison study.

That does **not** mean the current work is worthless.

It does mean:

- the static cross-study is no longer the primary move-forward path;
- the next real validation program must be a new dynamic exdqlm-aligned relaunch.
