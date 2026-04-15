# Original288 Dynamic TT5000 Post-Fix Smoke Program

## Purpose

Run a small representative post-fix smoke over the hard dynamic `TT5000` pocket
before resuming the narrow repair lane.

This smoke is intentionally isolated from the main repair outputs. Its job is
to answer a runtime-stability question, not the scientific repair question:

1. are the package-level dynamic fixes present in the validation checkout,
2. do representative `TT5000` rows now complete without the old immediate
   `computationally singular` / `chi has non-finite values` runtime crashes,
3. is it safe to resume the full `36`-row dynamic `TT5000` repair lane.

## Representative Coverage

The smoke targets one fixed seed for each of these representative unresolved
case types:

- `dynamic::gausmix::0p05::5000::default::dqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::dqlm::vb`
- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::exdqlm::vb`
- `dynamic::normal::0p25::5000::default::dqlm::mcmc`
- `dynamic::normal::0p25::5000::default::dqlm::vb`
- `dynamic::normal::0p25::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p25::5000::default::exdqlm::vb`

## Smoke Budgets

These are runtime-validation budgets only:

- MCMC: `n.burn = 10`, `n.mcmc = 5`
- VB: `max_iter = 40`, `n_samp = 300`

All row-local specs otherwise remain on their exact selected configs.

## Success Criterion

The smoke is considered stable enough to resume the narrow repair lane if:

- all smoke rows reach `status = done`
- no row ends in `failed_runtime`
- no row reproduces the old immediate singular / non-finite crash signatures

Scientific `PASS/WARN/FAIL` gates are not the decision criterion for this smoke.
