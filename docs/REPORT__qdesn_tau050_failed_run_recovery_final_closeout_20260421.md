# QDESN Tau050 Failed-Run Recovery Final Closeout

Date: `2026-04-21`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Executive Summary

The tau050 failed-run recovery program is now closed out successfully.

Final result:

| Surface | Count | Percent |
|---|---:|---:|
| Original source campaign fits | 144 | 100.0% |
| Original hard MCMC crashes | 23 | 16.0% |
| Hard crashes recovered now | 23 | 100.0% of crash surface |
| Remaining unresolved hard crashes | 0 | 0.0% |

The final closeout rerun recovered the last unresolved precision pair under the promoted `precision_beta = "ladder_v2"` policy:

| Lane | Root | Final state | Signoff |
|---|---|---|---|
| `AL` | `laplace / tau=0.50 / fit_size=5000 / ridge` | `SUCCESS` | `PASS` |
| `EXAL` | `laplace / tau=0.50 / fit_size=5000 / ridge` | `SUCCESS` | `PASS` |

## Recovery Timeline

### Stage 0: Source run

The refreshed tau050 main campaign produced:

- `144` total fits
- `23` hard MCMC numerical crashes

That crash surface was the authoritative recovery target throughout this effort.

### Stage 1: Early failed-only reruns

The first recovery waves improved the surface but did not solve it broadly. These stages established that:

- latent-state scheduling mattered
- the failure surface was heterogeneous
- warmup-only broad reruns were not enough

### Stage 2: Run-specific relaunch

The breakthrough came from splitting the remaining hard fails by mechanism.

Observed result:

| Run-specific relaunch surface | Success | Fail | Success rate |
|---|---:|---:|---:|
| Remaining hard fails | 13 | 2 | 86.7% |

This established the main strategic lesson:

- mechanism-specific relaunches work much better than one global spec

### Stage 3: Precision pair narrowing

After the run-specific relaunch, the unresolved surface shrank to a single hardest root under two lanes:

- `AL / laplace / tau=0.50 / fit_size=5000 / ridge`
- `EXAL / laplace / tau=0.50 / fit_size=5000 / ridge`

At that point, the failure family had changed:

- no longer the old latent-`v` invalid-draw crash
- now a beta-precision / Cholesky instability

### Stage 4: Config-only precision search

The broad precision config matrix went:

| Precision config matrix | Success | Fail | Success rate |
|---|---:|---:|---:|
| 7-arm config search | 0 | 7 | 0.0% |

This was still useful because it closed out the config-only search space and showed that the remaining issue needed code-level stabilization.

### Stage 5: Code-level precision rescue

The code-level precision matrix introduced structured `precision_beta` rescue policies:

- `ladder_v1`
- `ladder_v2`
- `eigen_v1`

Observed result on the final AL/EXAL pair:

| Strategy family | Arms | Success | Fail | Success rate |
|---|---:|---:|---:|---:|
| `ladder_v1` | 2 | 0 | 2 | 0.0% |
| `ladder_v2` | 2 | 2 | 0 | 100.0% |
| `eigen_v1` | 2 | 2 | 0 | 100.0% |

That result made the closeout policy decision clear:

- retire `ladder_v1`
- promote `ladder_v2`
- keep `eigen_v1` as fallback

### Stage 6: Canonical closeout rerun

The final closeout wave launched only the promoted `ladder_v2` pair and kept `eigen_v1` prepared only.

Observed outcome:

| Canonical closeout rerun | Success | Fail | Success rate |
|---|---:|---:|---:|
| `AL + EXAL` final pair | 2 | 0 | 100.0% |

This completed the recovery program.

## What We Learned

### 1. The failed-run surface was heterogeneous

The biggest early mistake would have been treating the `23` failed runs as one problem. The recovery only accelerated once the remaining failures were separated by mechanism.

### 2. Most earlier failures were latent-`v` problems

The first large tranche of recoveries came from:

- stronger tau/theta scheduling
- latent-state rescue logic
- GIG hardening
- run-specific relaunch logic

### 3. The final edge cases were a different numerical problem

The last unresolved pair was not failing in the old latent-`v` path anymore. It had become a precision-kernel stability problem centered on the beta precision Cholesky path.

### 4. Config tuning was not enough for the final pair

The `7 / 7` precision config failure result was decisive. It showed that the last pair needed code-level rescue rather than more warmup or conditioning search.

### 5. Stronger precision rescue was enough

The final closeout establishes:

- `ladder_v2` is strong enough to recover the final pair
- `eigen_v1` is also viable
- `ladder_v1` is too weak

## Productized Outcome

The winning rescue strategies are now available as a public API via:

- [exal_make_precision_beta_control()](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)
- [qdesn_fit_mcmc()](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc.R)

Recommended usage:

```r
qdesn_fit_mcmc(..., mcmc_args = list(precision_beta = "ladder_v2"))
```

Escalation usage:

```r
qdesn_fit_mcmc(..., mcmc_args = list(precision_beta = "eigen_v1"))
```

The productized precision-beta API is documented in:

- [precision-beta API productization report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_precision_beta_api_productization_20260420.md)

## Wiring/Operational Closeout

The final closeout also cleaned up the operational surface:

- canonical closeout materializer added
- closeout launcher and healthcheck phases added
- fallback closeout phases frozen in `prepare-only`
- dynamic healthcheck script hardened to tolerate empty or placeholder campaign CSVs after run completion

That means the final state is:

- documented
- reproducible
- phase-addressable
- compatible with the existing validation workflow

## Final Read

This recovery was successful in both scientific and engineering terms.

Scientific outcome:

- `23 / 23` original hard MCMC crashes were recovered

Engineering outcome:

- the winning precision rescue is now productized
- the closeout package is fully scripted and reproducible
- the fallback path is preserved

The tau050 failed-run recovery program is now complete.
