# REPORT: QDESN Dynamic P90 Steepertrend RHS-NS Smoke Completion And Full Launch Decision

Date: 2026-04-23
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report records the completed `rhs_ns` smoke gate for the promoted `p90`
steeper-trend dynamic relaunch and turns that result into a clean go/no-go
decision for the full `rhs_ns` surface.

This is the second staged gate in the relaunch program:

1. smoke on the promoted dataset surface
2. full `ridge` baseline
3. `rhs_ns` smoke gate
4. full `rhs_ns` surface if the smoke gate remains free of hard runtime or
   numerical failure

## 2) Executed Smoke Run

Committed-state smoke run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-smoke-20260422-211800__git-b8f8f06`

Dataset surface:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Prior:

- `rhs_ns`

Grid surface:

- [rhs_ns smoke grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_smoke_grid.csv)

Shared launch contract preserved:

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

Shared baseline policy preserved:

- `LDVB` for VB
- `slice` for MCMC
- `init_from_vb = TRUE`
- automatic `rhs_ns` tau warmup with `50L`
- light exAL `(sigma, gamma)` warmup
- no rescue overlays

## 3) Smoke Final Result

### Root-level completion

| Metric | Value |
|---|---:|
| Selected roots | `2` |
| Materialized roots | `2` |
| Successful roots | `2` |
| Running roots | `0` |
| Failed roots | `0` |
| Root completion | `100.0%` |

### Fit-level completion

| Metric | Value |
|---|---:|
| Planned fits | `8` |
| Completed fits | `8` |
| Remaining fits | `0` |
| Fit completion | `100.0%` |

### Fit-quality mix

| Signoff grade | Count | Percent |
|---|---:|---:|
| `PASS` | `4` | `50.0%` |
| `WARN` | `1` | `12.5%` |
| `FAIL` | `3` | `37.5%` |

Comparison eligibility:

| Metric | Count | Percent |
|---|---:|---:|
| comparison-eligible | `5` | `62.5%` |
| not comparison-eligible | `3` | `37.5%` |

## 4) Numerical Failure Read

### Hard-failure status

| Check | Result |
|---|---|
| Root-level runtime failures | `0` |
| Root-level `FAIL` roots | `0` |
| Completed fits with `status != SUCCESS` | `0` |
| `root_error.txt` / `fit_error.txt` / `.error` / `.fail` files | `0` found |
| Hard numerical/runtime crash evidence | **none** |

Operational conclusion:

- the normalized baseline defaults remained free of hard numerical/runtime
  failure on the staged `rhs_ns` smoke surface

## 5) Diagnostic Failure Read

The remaining issues were diagnostic rather than numerical.

| Signoff reason | Count |
|---|---:|
| `vb_converged; stable_tail` | `4` |
| `high_autocorrelation` | `3` |
| `chain_marginal_but_usable` | `1` |

Interpretation:

- the `rhs_ns` smoke result is scientifically mixed
- the main remaining weakness is still MCMC mixing/autocorrelation
- that weakness is not new and it does not indicate a runtime-breakdown problem

## 6) Decision

### Should we open the full `rhs_ns` surface now?

Yes.

Rationale:

- `ridge` completed without hard numerical/runtime failure
- `rhs_ns` smoke also completed without hard numerical/runtime failure
- the main issue pattern remains diagnostic quality, not operational stability
- this is enough evidence to proceed cleanly to the full `rhs_ns` expansion

### What should stay unchanged?

Keep the same normalized baseline defaults:

- do **not** change the shared warmup contract yet
- do **not** promote theta freeze rescue
- do **not** promote latent-state or latent `v` / `s` rescue
- do **not** promote precision rescue

The full `rhs_ns` launch should therefore be:

- committed-state
- baseline-policy-consistent
- fully documented
- launched without rescue overlays

## 7) Immediate Next Action

The correct next step is:

1. freeze this decision in the tracker and reports
2. run a committed-state `rhsns_full` prepare-only gate
3. if preflight passes, launch the full `rhs_ns` `72`-fit surface
4. capture the first live healthcheck after launch
