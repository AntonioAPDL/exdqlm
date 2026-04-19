# QDESN Tau050 Theta-Freeze Isolated Canary Next Step

Date: 2026-04-19

## Decision Summary

Do **not** launch the full 23-crash theta-freeze wave first.

The most efficient next move is a **small isolated theta-freeze canary** on a
single coherent stress surface, then decide whether to:

1. expand theta-freeze to the full 23-crash surface
2. switch immediately to a stronger latent-`v` rescue strategy
3. combine theta-freeze with bounded latent-`v` rescue on the still-hard cases

## Why An Isolated Canary Is The Right Next Step

From the completed latent-`s` freeze relaunch:

- [sfreeze postmortem](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_failed_mcmc_sfreeze_postmortem_20260419.md)

we now know:

- only `8 / 23` originally crashed fits recovered under `sfreeze`
- the remaining hard-fail surface is now a cleaner `15`-root subset
- all remaining hard fails are `fit_size = 5000`
- the remaining hard crashes are still the same latent-`v` invalid-draw family
- most remaining hard crashes occur **after thaw**, not during warmup
- `rhs_ns` remains weaker than `ridge`
- the hardest unresolved zones are `tau = 0.25 / 0.50`, especially `laplace`
  and `gausmix`

That means the next experiment should be:

- small
- stress-heavy
- easy to interpret
- auditable against the original source campaign

## Recommended Micro-Canary

Use a **4-root factorial canary** on a single long-window stress surface:

| Lane | Family | tau | Fit size | Prior | Root ID |
|---|---|---:|---:|---|---|
| AL | `laplace` | `0.50` | `5000` | `rhs_ns` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns` |
| AL | `laplace` | `0.50` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge` |
| EXAL | `laplace` | `0.50` | `5000` | `rhs_ns` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns` |
| EXAL | `laplace` | `0.50` | `5000` | `ridge` | `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge` |

## Why This 4-Root Surface

This is the cleanest isolated next step because it gives us:

- the same family
- the same tau
- the same long-window fit size
- both priors
- both likelihood lanes

So we can answer, with minimal compute:

- does theta-freeze help at all on a genuinely hard post-thaw surface?
- does it help more in `ridge` than `rhs_ns`?
- does it help more in `al` or `exal`?
- is the new `1e-10` GIG floor enough to change the failure behavior here?

This is much more interpretable than relaunching the full 23 immediately.

## Optional Ultra-Minimal Variant

If we want an even cheaper first probe, run just the `rhs_ns` pair first:

| Lane | Family | tau | Fit size | Prior |
|---|---|---:|---:|---|
| AL | `laplace` | `0.50` | `5000` | `rhs_ns` |
| EXAL | `laplace` | `0.50` | `5000` | `rhs_ns` |

That is the cheapest high-stress comparator, but the recommended default is the
full 4-root canary because it adds the prior contrast without much extra cost.

## What To Keep Fixed

Run the canary on the **current theta-freeze lane exactly as implemented**:

- [thetafreeze defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml)

That means:

- keep the new theta scheduler
- keep the stronger tau freeze
- keep the new `1e-10` GIG floor
- do **not** add a new rescue overlay yet

Reason:

- we want to isolate whether theta-freeze plus the hardened GIG floor buys us
  anything on its own
- if we add rescue immediately, the canary becomes harder to interpret

## Launch Discipline

1. Create two tiny subset manifests from the original failed-only AL/EXAL grids.
2. Reuse the existing theta-freeze defaults.
3. Keep worker count low:
   - `1` worker per lane is enough for this canary
4. Launch AL and EXAL sequentially.
5. Monitor root manifests, not only campaign tables.

## Success Gates

Promote theta-freeze from isolated canary to larger relaunch only if we see at
least one of these:

1. `3 / 4` or `4 / 4` complete successfully
2. at least `2 / 4` reach `PASS` or `WARN`
3. the old latent-`v` hard-crash family is clearly reduced or replaced by
   softer, diagnosable signoff issues

## Failure Gates

Do **not** expand theta-freeze alone if:

1. `0 / 4` or `1 / 4` recover
2. failures still show the same latent-`v` invalid-draw family without any
   meaningful timing shift
3. both `rhs_ns` roots fail unchanged

If that happens, the next move should be:

- keep the `1e-10` GIG floor
- keep theta-freeze available
- add bounded latent-`v` rescue on top of this exact 4-root canary before any
  broader rerun

## Expansion Path If Canary Looks Good

If the 4-root canary is encouraging, expand in this order:

1. remaining `laplace` long-window hard-fail roots
2. then `normal` long-window hard-fail roots
3. then `gausmix` long-window hard-fail roots

This is intentionally the reverse of “hardest first” for broad promotion:
`laplace` at `tau = 0.50` gives us a tough but interpretable mid-point before
we spend more on the noisier `gausmix` surface.

## Bottom Line

The recommended next move is:

- **not** a full 23-fit theta-freeze rerun
- **not** another broad mixed-experiment matrix
- **yes** to a **4-root isolated theta-freeze canary** on the
  `laplace / tau = 0.50 / fit_size = 5000` surface across both priors and both
  lanes

That is the cheapest high-information experiment we can run next.
