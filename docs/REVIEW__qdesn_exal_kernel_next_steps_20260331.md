# QDESN exAL Kernel Forward Review

- date: `2026-03-31`
- branch: `feature/qdesn-mcmc-alternative`
- review scope: post-screen forward path after the completed overnight kernel screen
- main evidence run: `exal-kernel-screen-overnight-20260330c__git-412b379`

## Executive Read

The current blocker is not infrastructure, finite-domain stability, or generic RHS-family failure.

The main issue is a shared `exal` MCMC chain-quality bottleneck on the hard `tiny_d1_n8` cells, with `gamma` mixing and `gamma`-driven geometry looking like the primary limiter and `sigma` half-drift plus `rhs_ns` tau-path behavior looking secondary.

That read is based on three facts from the completed screen:

1. all `12/12` profiles completed cleanly, so the screen isolated model behavior rather than runner noise;
2. the best-performing profiles were the shared `exal` core profiles, not the heavier-chain profiles;
3. the best `rhs_ns` residual profile cleaned the sentinel roots but did not beat the best shared-core profiles on the severe `exal` roots.

## What The Screen Established

### Operational conclusion

- `12/12` profiles completed
- `0` timeouts
- `0` runner errors
- `0` root failures
- `0` finite/domain/collapse regressions

Conclusion:

- the overnight screen is trustworthy as a decision-making artifact

### Scientific conclusion

Anchor baseline:

- `X0_anchor_baseline`: `6` FAIL roots out of `6`

Gate-B winners:

| profile | family | fail_reduction | runtime_inflation | best use |
|---|---|---:|---:|---|
| `X10_core_gamma_focus_pass1` | shared core | `0.50` | `0.4255` | best overall |
| `X3_core_pass1_sharp` | shared core | `0.50` | `0.4271` | close alternate to X10 |
| `X8_rhsns_freeze60_multistart3` | rhs_ns residual | `0.50` | `0.4289` | best rhs_ns cleanup layer |
| `X11_core_sigma_focus_pass1` | shared core | `0.50` | `0.4844` | sigma-focused fallback |

Profiles that did not earn their cost:

| profile | fail_reduction | runtime_inflation | read |
|---|---:|---:|---|
| `X2_core_pass2_soft` | `0.00` | `1.0037` | two extra passes were wasteful |
| `X4_core_pass2_sharp` | `0.1667` | `1.0035` | sharper two-pass still too expensive |
| `X9_moderate_chain_core1` | `0.1667` | `0.9321` | longer chain helped too little |
| `X7_rhsns_multistart3_core1` | `0.00` | `0.4549` | multistart alone was not enough |

Conclusion:

- better local geometry beats longer chains
- `rhs_ns` residual handling matters, but not as the first-line fix

## Main Issue

### Primary issue

Shared `exal` core mixing is the main problem, especially around `gamma`.

Evidence:

- `X10_core_gamma_focus_pass1` ranked `#1`
- it produced the biggest median `ESS` lift (`+9.71`)
- it also had strong reductions in absolute `Geweke` (`-2.97`) and half-drift (`-0.79`)
- it improved both `exal + ridge` and `exal + rhs_ns` severe roots

Inference:

- the dominant bottleneck is likely posterior geometry / traversal quality in the shared `exal` core update, not just bad tau handling in `rhs_ns`

### Secondary issue

`rhs_ns`-specific tau-path stabilization is still real, but secondary.

Evidence:

- `X8_rhsns_freeze60_multistart3` ranked `#3`
- it cleared both sentinel roots better than the shared-core winners
- it improved the lighter `al + rhs_ns` sentinel that the core-only winners still left at `FAIL`

Inference:

- after the core issue is addressed, `rhs_ns` initialization / warmup / tau release still looks like the right second cleanup target

### What is not the main issue

- not numerical instability
- not non-finite outputs
- not domain violations
- not gross chain length shortage alone
- not a purely `rhs_ns`-only problem

## What Likely Helps Most

### Best guess 1: promote the X10-style core refresh into a real code candidate

The strongest first guess is to turn the `X10` pattern into the first implementation candidate:

- one extra shared `exal` core pass
- sharper `gamma` width around `0.45`
- slightly looser `sigma` width around `0.35`
- moderate step-out / shrink budgets rather than aggressive chain length increases

Why this is the best first move:

- it won the screen
- it improved both prior families inside `exal`
- it was materially cheaper than longer-chain alternatives

### Best guess 2: keep X3 as the immediate alternate branch

`X3` was nearly tied with `X10`, but its improvement pattern is slightly different:

- it cleaned `dlm_constV_smallW exal rhs_ns tau=0.95`
- it cleaned `dlm_constV_smallW exal ridge tau=0.95`
- it did not solve `dlm_ar1V exal rhs_ns tau=0.95`

Read:

- if an `X10`-like code patch underperforms after implementation, `X3` is the right same-family alternate, not a broader chain-length retry

### Best guess 3: after the core patch, add the X8-style rhs_ns cleanup layer

The best residual-layer guess is:

- keep the shared core improvement
- add `rhs_ns` `freeze_tau_burnin_iters = 60`
- add `rhs_ns` multistart with `3` pilot starts

Why this is a good second move:

- `X8` was the best sentinel cleaner
- it helped the `al + rhs_ns` root that remained stubborn under `X10` and `X3`
- it did not require longer chains

## Root-Level Pattern

### X10 helped these roots

- `dlm_ar1V @ tau=0.95 exal rhs_ns`: `FAIL -> WARN`
- `dlm_constV_smallW @ tau=0.95 exal ridge`: `FAIL -> WARN`
- `dlm_constV_smallW @ tau=0.50 exal rhs_ns`: `FAIL -> WARN`

### X10 still failed these roots

- `dlm_constV_bigW @ tau=0.05 exal ridge`
- `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
- `dlm_constV_bigW @ tau=0.95 al rhs_ns`

### X8 helped these roots

- `dlm_ar1V @ tau=0.95 exal rhs_ns`: `FAIL -> WARN`
- `dlm_constV_smallW @ tau=0.50 exal rhs_ns`: `FAIL -> WARN`
- `dlm_constV_bigW @ tau=0.95 al rhs_ns`: `FAIL -> WARN`

### X8 still failed these roots

- `dlm_constV_smallW @ tau=0.95 exal ridge`
- `dlm_constV_bigW @ tau=0.05 exal ridge`
- `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

Interpretation:

- the stubborn common root is `dlm_constV_bigW @ tau=0.05 exal ridge`
- that cell should be treated as the main hard benchmark for the next code patch
- `X10` and `X8` are complementary rather than redundant

## Recommended Forward Path

### Step 1: implement one shared-core code candidate only

Implement an `X10`-style core refresh first.

Target behavior:

- shared `exal` improvement across `ridge` and `rhs_ns`
- no chain-length inflation
- no redesign of the validation harness

This should be the first code candidate because it best matches the observed dominant failure mode.

### Step 2: rerun only the 6-root harness against the new code

Do not jump back to branch-wide `T0 -> T4`.

Rerun:

- the exact 6-root harness already used by the overnight screen
- anchor baseline
- code candidate A: `X10`-style core refresh
- code candidate B: `X3`-style alternate if needed

Decision rule:

- if candidate A reduces the severe fail set below `3` while keeping runtime inflation below `0.50`, keep moving with A
- if candidate A misses badly on `dlm_ar1V exal rhs_ns`, move immediately to the X3 alternate

### Step 3: only after a winning core patch, test the rhs_ns residual layer

If the best core candidate still leaves the `al + rhs_ns` sentinel or one `rhs_ns` severe root behind, then add the `X8` layer:

- `freeze_tau_burnin_iters = 60`
- `multistart = 3`

This should be tested on top of the winning core candidate, not as a separate first-line solution.

### Step 4: only then escalate back toward broad validation

Broad reruns should wait until:

- the 6-root harness shows a clear winner
- the persistent hard root `dlm_constV_bigW @ tau=0.05 exal ridge` is at least improved from `FAIL`

After that:

1. rerun the closeout micro-pilot
2. if the micro-pilot holds, rerun the dynamic branch baseline
3. only then re-close the branch

## Concrete Recommendation

If I were choosing the next implementation sequence today, I would do this:

1. implement an `X10`-style shared `exal` core refresh
2. validate on the same 6 roots
3. if needed, compare against the `X3` alternate
4. layer `X8`-style `rhs_ns` freeze-plus-multistart on top of the winning core patch
5. only after that spend more compute on broader reruns

This is the most likely path to real improvement because it follows the strongest signal from the completed screen rather than the earlier pre-screen intuition.

## Evidence

- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/profile_rank_summary.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_micro_pilot_summary.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_micro_pilot_diag_shift.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X10_core_gamma_focus_pass1.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X3_core_pass1_sharp.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X8_rhsns_freeze60_multistart3.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X11_core_sigma_focus_pass1.csv`
