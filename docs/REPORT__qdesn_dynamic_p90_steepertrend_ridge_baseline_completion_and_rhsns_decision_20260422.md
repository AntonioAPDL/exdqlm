# REPORT: QDESN Dynamic P90 Steepertrend Ridge Baseline Completion And RHS-NS Decision

Date: 2026-04-22
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

This report records the completed first-prior baseline result for the promoted
`p90` steeper-trend dynamic relaunch and turns that result into a clear
decision about the next `rhs_ns` step.

The baseline was intentionally launched first on `ridge` so we could evaluate:

- the new promoted dataset surface;
- the normalized shared warmup/default layer; and
- the current Q-DESN dynamic relaunch stack

before opening the shrinkage-stress second prior.

## 2) Executed Runs

Committed-state run tags:

- smoke:
  - `qdesn-dynamic-p90-steepertrend-smoke-20260422-044129__git-6438b52`
- ridge baseline:
  - `qdesn-dynamic-p90-steepertrend-ridge-full-20260422-044241__git-6438b52`

Dataset surface:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Baseline prior:

- `ridge`

Shared long-budget contract used:

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

Shared baseline policy used:

- `LDVB` for VB
- `slice` for MCMC
- `init_from_vb = TRUE`
- normalized baseline warmup only
- no rescue overlays

## 3) Ridge Baseline Final Result

### Root-level completion

| Metric | Value |
|---|---:|
| Selected roots | `18` |
| Materialized roots | `18` |
| Successful roots | `18` |
| Running roots | `0` |
| Failed roots | `0` |
| Root completion | `100.0%` |

### Fit-level completion

| Metric | Value |
|---|---:|
| Planned fits | `72` |
| Completed fits | `72` |
| Remaining fits | `0` |
| Fit completion | `100.0%` |

### Fit-quality mix

| Signoff grade | Count | Percent |
|---|---:|---:|
| `PASS` | `42` | `58.3%` |
| `WARN` | `15` | `20.8%` |
| `FAIL` | `15` | `20.8%` |

Comparison eligibility:

| Metric | Count | Percent |
|---|---:|---:|
| comparison-eligible | `57` | `79.2%` |
| not comparison-eligible | `15` | `20.8%` |

## 4) Numerical Failure Read

### Hard-failure status

| Check | Result |
|---|---|
| Root-level runtime failures | `0` |
| Root-level `FAIL` roots | `0` |
| Completed fits with `status != SUCCESS` | `0` |
| `root_error.txt` / `fit_error.txt` / `.error` / `.fail` files | `0` found |
| Hard numerical/runtime crash evidence | **none** |

This is the most important operational conclusion from the ridge baseline:

- the new promoted dataset surface did **not** produce hard runtime or numerical
  breakdown in the first-prior Q-DESN baseline

## 5) Diagnostic Failure Read

The remaining problems were diagnostic rather than numerical.

| Signoff reason | Count |
|---|---:|
| `vb_converged; stable_tail` | `30` |
| `adequate_chain_length; acceptable_ess_acf_geweke_drift` | `12` |
| `chain_marginal_but_usable` | `9` |
| `vb_converged_false` | `6` |
| `high_autocorrelation` | `13` |
| `high_autocorrelation; half_chain_drift` | `1` |
| `low_ess; high_autocorrelation; half_chain_drift` | `1` |

Interpretation:

- the baseline stack is operationally stable
- the main remaining weakness is MCMC mixing quality, especially in the
  `exal + mcmc` region
- this is a scientific/diagnostic issue, not a crash issue

## 6) Gate Decision

### Should we open the `rhs_ns` surface now?

Yes, but in a staged way.

Recommended next step:

1. run a committed-state `rhs_ns` smoke gate using the same normalized baseline
   defaults
2. if that smoke gate remains free of hard numerical/runtime failures, launch
   the full `72`-fit `rhs_ns` expansion

### Why not jump straight to full `rhs_ns`?

Because the ridge baseline passed the operational gate but not the full
scientific-quality gate.

That means:

- we have enough evidence to keep following the planned rollout
- but not enough evidence to skip the shrinkage-side smoke gate

So the correct decision is:

- **yes to `rhs_ns` next**
- **no to a blind immediate full `rhs_ns` launch**

## 7) Rescue Overlay Decision

Do **not** change the baseline defaults yet.

Specifically, do **not** promote these into the next pass before we see the
`rhs_ns` smoke result:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue
- row-local replay overrides

The baseline defaults were good enough to avoid hard breakdown on the ridge
surface. The next clean experiment is to see how far those same normalized
defaults go on `rhs_ns`.

If `rhs_ns` smoke shows hard failure, then we can re-open targeted rescue
overlays with a much clearer signal.

## 8) Recommended Immediate Next Action

The correct next action is:

- update the tracker and reports with the completed ridge result
- prepare and launch a committed-state `rhs_ns` smoke gate
- only after that decide whether to promote the full `rhs_ns` `72`-fit surface
