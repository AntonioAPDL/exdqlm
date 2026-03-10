# exAL VB Runtime Audit And Rollout Plan

Date: 2026-03-09

Repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
Branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`

## Purpose

This note records the runtime-debugging context for the static `exAL` `VB` implementation after the LD-block stabilization/signoff fix.

The immediate goal is:

1. keep the algorithm **Delta-only**
2. ensure `exAL VB` **converges**
3. ensure `exAL VB` has **comparable fit quality** to `exAL MCMC`
4. ensure `exAL VB` is **materially faster** than `exAL MCMC`

If the final item fails, the `VB` approximation is not operationally justified.

This note also defines the rollout plan to make sure the same runtime standards are checked across all relevant `VB` paths in the package.

## Scope

### In scope

- static `AL` reduced-path `VB`
- static `exAL` `VB`
- dynamic `DQLM` `LDVB`
- dynamic `exDQLM` `LDVB`

### Explicitly out of scope

- `ISVB`

Reason:
- `ISVB` is a different algorithmic family
- the current runtime bottleneck was found inside the static `exAL` Laplace-Delta block
- the user explicitly asked not to change `ISVB`

## Frozen benchmark used for runtime debugging

### Benchmark design

- static, non-shrinkage
- `tau = 0.05`
- reduced debug size `n = 100`
- paper-style dense lower-tail stress case
- source simulation:
  - `results/sim_suite_static/audits/exal_vb_ld_stabilization_20260309/sim_output_n100.rds`

### Runtime study script

- [20260309_exal_vb_runtime_study.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260309_exal_vb_runtime_study.R)

### Runtime audit roots

- baseline:
  - `results/sim_suite_static/audits/exal_runtime_microbenchmark_20260309`
- Delta-only:
  - `results/sim_suite_static/audits/exal_runtime_microbenchmark_delta_20260309`
- Delta-only with cache fix:
  - `results/sim_suite_static/audits/exal_runtime_microbenchmark_delta_cache_20260309`

## What was observed

### Before Delta-only runtime cleanup

On the reduced benchmark:

| Case | Time (s) | Converged | Iter | Quantile RMSE |
|---|---:|---|---:|---:|
| `VB AL` | `0.214` | yes | `155` | `1.9314` |
| `VB exAL default + trace` | `87.731` | no | `300` | `0.9933` |
| `VB exAL default no trace` | `83.958` | no | `300` | `0.9965` |
| `VB exAL delta-fallback` | `45.863` | no | `300` | `0.9943` |
| `MCMC AL` | `1.333` | — | — | `1.8079` |
| `MCMC exAL` | `7.193` | — | — | `0.7756` |

Immediate interpretation:

- static `exAL VB` was far too slow
- trace construction was not the main bottleneck
- the major cost was already concentrated inside the LD path

### Delta-only stabilization variants

The first Delta-only runtime sweep showed:

| Case | Time (s) | Converged | Iter | Quantile RMSE |
|---|---:|---|---:|---:|
| `vb_exal_delta_default_notrace` | `23.713` | no | `300` | `0.9943` |
| `vb_exal_delta_stride25_lightchecks` | `13.627` | yes | `347` | `0.9955` |
| `vb_exal_delta_stride50_fastrelease` | `14.384` | yes | `325` | `0.9952` |
| `mcmc_exal_ref` | `6.468` | — | — | `0.6201` |

Interpretation:

- the Delta-only stabilization path fixed convergence on the reduced benchmark
- but `VB exAL` was still slower than `MCMC exAL`

### Root bottleneck before the cache fix

Timing breakdown showed the largest cost was still:

- `ld_mode`

This meant the remaining issue was inside the LD objective and optimizer path, not traces or postprocessing.

## Root runtime bottleneck identified

The main root bottleneck was repeated recomputation of fixed quantities inside the LD objective at every optimizer evaluation.

Specifically, the objective was repeatedly rebuilding terms based on:

- `X %*% beta`
- `diag(X V_beta X')`
- related fixed sums

Those quantities are fixed within a single outer `VB` iteration and should not be recomputed on every inner optimizer evaluation.

## Runtime fix implemented

### Code

- [R/exal_static_LDVB.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/R/exal_static_LDVB.R)

### Main change

Added an `ld_cache` path to the LD objective so each outer `VB` iteration precomputes sufficient-statistic summaries once, then reuses them throughout the inner LD mode search.

### Related harness update

- [20260309_exal_vb_runtime_study.R](/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/tools/merge_reports/20260309_exal_vb_runtime_study.R)

Added variant filtering so focused reruns can target the exact runtime cases of interest.

## Result after the cache fix

From `exal_runtime_microbenchmark_delta_cache_20260309`:

| Case | Time (s) | Converged | Iter | Quantile RMSE |
|---|---:|---|---:|---:|
| `VB AL` | `0.208` | yes | `155` | `1.9314` |
| `VB exAL delta_stride25_lightchecks` | `4.913` | yes | `625` | `0.9927` |
| `VB exAL delta_stride50_fastrelease` | `10.243` | yes | `272` | `0.9954` |
| `MCMC AL` | `1.332` | — | — | `1.9312` |
| `MCMC exAL` | `6.578` | — | — | `0.9486` |

This is the key operational result:

- the best Delta-only `exAL VB` variant is now **faster** than `exAL MCMC`
- it also still converges

### Best current reduced benchmark configuration

Current best runtime variant:

- `vb_exal_delta_stride25_lightchecks`

Reason:

- converged
- substantially faster than `MCMC exAL`
- fit quality remained in the same regime

## Current timing breakdown after cache fix

For `vb_exal_delta_stride25_lightchecks`:

| Component | Time (s) | Share |
|---|---:|---:|
| `ld_mode` | `1.619` | `33%` |
| `xi_eval` | `0.284` | `6%` |
| `ld_mode_quality_candidate` | `0.215` | `4%` |
| `other` | `1.651` | `34%` |

Interpretation:

- the old LD-objective bottleneck was materially reduced
- the runtime problem is no longer dominated by a single pathological objective-evaluation hotspot

## Current conclusion

The runtime problem is now in a much better state:

1. static Delta-only `exAL VB` can converge on the frozen benchmark
2. it can now be faster than `exAL MCMC`
3. the root runtime bottleneck was identified and fixed in a principled way

This means the right next step is no longer broad profiling. It is controlled validation and rollout.

## Rollout checklist

### RTA1. Freeze the reduced benchmark

- [x] Freeze the reduced `n=100` paper-style stress benchmark.
- [x] Keep the benchmark script and output roots as the runtime reference.

### RTA2. Validate the best Delta-only settings on the large reference case

Goal:
- confirm that the runtime win does not break the already-fixed `n=10000` reference benchmark

Checklist:
- [ ] run the large `n=10000`, `tau=0.05` paper-style dense benchmark with the current best Delta-only settings
- [ ] confirm `VB exAL` converges
- [ ] confirm fit quality stays comparable to the current stabilized reference
- [ ] compare `VB exAL` runtime against `MCMC exAL` on the same benchmark

Decision:
- if `VB exAL` remains faster and scientifically comparable, freeze that configuration
- otherwise, continue targeted runtime calibration before rollout

### RTA3. Propagate the runtime fix carefully

Goal:
- carry only the proven runtime improvements into all relevant VB models

Target paths:
- [ ] static `exAL VB`
- [ ] static reduced `AL VB`
- [ ] dynamic `exdqlmLDVB`
- [ ] dynamic reduced `DQLM LDVB`

Guard:
- [ ] do not touch `ISVB`

Propagation rule:
- only propagate:
  - objective caching
  - signoff-check throttling if already justified
  - stable deterministic Delta-only controls

### RTA4. Benchmark every VB model in scope

Goal:
- make sure the package-level VB runtime story is coherent

Checklist:
- [ ] static `AL VB` reduced benchmark
- [ ] static `exAL VB` reduced benchmark
- [ ] dynamic `DQLM LDVB` reduced benchmark
- [ ] dynamic `exDQLM LDVB` reduced benchmark
- [ ] one realistic larger benchmark for each family

Report for each:
- runtime
- convergence status
- iteration count
- fit quality against matching `MCMC`

### RTA5. Release-quality cleanup

- [ ] add a concise runtime note to the main tracker
- [ ] document the chosen Delta-only runtime controls if they are user-facing
- [ ] confirm code style and comments remain consistent with package standards
- [ ] commit and push only after large-case validation succeeds

## Decision rule

We only declare the runtime problem solved if all are true:

1. `VB exAL` converges on the reduced and large reference cases
2. `VB exAL` fit quality remains comparable to `MCMC exAL`
3. `VB exAL` runtime is materially better than `MCMC exAL`
4. the same fix can be applied cleanly across the other LDVB models

If any of these fail, continue debugging before broader validation reruns.

