# Static exAL Tail-Bias Audit (`T5`)

## Scope

This note completes `T5` of the static `exAL` tail-bias audit:

- map the audited theory objects to their exact implementation points
- classify each nontrivial expression as exact, exact-up-to-constant, approximate, or helper-only
- convert the audit findings into a concrete patch list

Artifacts generated for `T5`:

- `results/sim_suite_static/audits/static_exal_tail_bias_t5_20260305/t5_theory_code_concordance.csv`
- `results/sim_suite_static/audits/static_exal_tail_bias_t5_20260305/t5_patch_list.csv`

## Concordance Summary

The concordance map covers:

- `R/utils.R`
- `R/exal_static_LDVB.R`
- `R/exal_static_mcmc.R`
- `R/static_fit_normalization.R`
- static reporting/pipeline helpers that consume these objects

Main conclusions:

1. The core shared posterior ingredients are aligned.
   - `A(gamma)`, `B(gamma)`, `C(gamma)`, `lambda(gamma)`, the bounded `gamma` support, and the `eta` transform are consistent across `VB`, `MCMC`, and helper code.
2. The core static `VB` and exact static `MCMC` kernels do not show an obvious algebraic mismatch.
   - This is consistent with `T3` and `T4`.
3. The remaining technical risk is concentrated in approximation layers, not in already-audited exact kernels.
   - `VB`: `xi` Monte Carlo expectations and the LD local Gaussian approximation
   - `MCMC`: the optional `laplace_local` branch, which is not exact
4. The current reporting/signoff layer is missing one important control.
   - it does not currently surface whether the `gamma` kernel used for a saved `MCMC` run is exact or approximate

## Patch-Ready Findings

High-priority patch items:

| ID | Title | Why it matters now |
|---|---|---|
| `P1` | add static `exAL` derivation to theory repo `main.tex` | closes the current theory-doc gap from `T2` |
| `P2` | add exact-kernel signoff guard for static `MCMC` gamma updates | prevents `laplace_local` runs from being treated as signoff-equivalent |
| `P3` | add deterministic/replicated `xi` evaluation mode for static `LDVB` | directly targets the strongest unresolved `VB` approximation risk |

Medium-priority patch item:

| ID | Title | Why it matters |
|---|---|---|
| `P4` | add LD mode-quality diagnostics to normalized outputs and reports | makes future tail-debugging evidence available without an external audit script |

## Practical Interpretation

After `T1-T5`, the static `exAL` tail issue is narrowed to:

- not an obvious theory-to-code sign error in the already audited formulas
- not an obvious wrong posterior target in the frozen rich static `MCMC` run
- more plausibly:
  - a theory-document gap that still needs to be fixed in `main.tex`
  - an approximation-quality issue in the static `VB` LD block
  - or genuine model mismatch on the current simulated DGP

The next implementation work should therefore be driven by the concrete patch list, not by another broad tuning loop.
