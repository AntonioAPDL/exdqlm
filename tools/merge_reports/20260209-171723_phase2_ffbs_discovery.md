# Phase 2 FFBS Discovery (Plan items 2.1-2.2)

## Branch snapshot
- Branch: `integrate/v0.4.0-on-v0.3.0`
- HEAD: `bcab2c2`
- Scope: discovery only (no FFBS code edits and no phase-gate rerun in this chunk)

## Theory anchor from `main.tex`
- Source: `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`
- Section: `sec:ffbs` ("Conditional update for alpha path by FFBS")
- Equations:
  - `eq:bs_J` defines smoothing gain as \(J_t = C_t (G_{t+1}^\alpha)^T (R_{t+1}^\alpha)^{-1}\).
  - `eq:bs_alpha` uses \(a_{t+1}\) and \(R_{t+1}^\alpha\) in the backward update.
- Paraphrase: backward step for index \(t\) must use transition matrix at \(t+1\), not \(t\).

## R fallback FFBS inventory (code map)

| Algorithm path | Location | Fallback role | Current smoothing-gain term |
|---|---|---|---|
| ISVB | `R/exdqlmISVB.R:269` (`update_theta`), backward loop `R/exdqlmISVB.R:303` | R fallback used when C++ bridge is disabled/fails | `sB = C[,,t] %*% t(GG[,,t]) %*% inv.R` at `R/exdqlmISVB.R:309` |
| LDVB | `R/exdqlmLDVB.R:270` (`update_theta`), backward loop `R/exdqlmLDVB.R:304` | R fallback used when C++ bridge is disabled/fails | `sB = C[,,t] %*% t(GG[,,t]) %*% inv.R` at `R/exdqlmLDVB.R:310` |
| MCMC (smoothed return values) | `R/exdqlmMCMC.R:131` (`smoothed_theta`), backward loop `R/exdqlmMCMC.R:165` | Primary R implementation (no C++ routing here) | `sB = C[,,t] %*% t(GG[,,t]) %*% inv.R` at `R/exdqlmMCMC.R:171` |
| MCMC (exDQLM sampler) | backward loop `R/exdqlmMCMC.R:282` | Primary R implementation | `sB = C[,,t] %*% t(GG[,,t]) %*% inv.R` at `R/exdqlmMCMC.R:288`; covariance update uses `GG[,,t]` at `R/exdqlmMCMC.R:290` |
| MCMC (dQLM sampler) | backward loop `R/exdqlmMCMC.R:463` | Primary R implementation | `sB = C[,,t] %*% t(GG[,,t]) %*% inv.R` at `R/exdqlmMCMC.R:469`; covariance update uses `GG[,,t]` at `R/exdqlmMCMC.R:471` |

## C++ cross-check (reference implementation)
- File: `src/kalman.cpp:280-290`
- Backward loop uses `GG.slice(t+1)` for both transition and smoothing gain:
  - `a = GG.slice(t+1) * m.col(t)`
  - `P = GG.slice(t+1) * C.slice(t) * GG.slice(t+1).t()`
  - `sB = C.slice(t) * GG.slice(t+1).t() * R_inv`
- This matches `eq:bs_J` in `main.tex`.

## Backend routing and forcing R fallback
- Defaults set in `R/zzz.R:2-13`: `options(exdqlm.use_cpp_kf = TRUE)` on package load.
- ISVB routing in `R/exdqlmISVB.R:438-451`:
  - `use_cpp <- isTRUE(getOption("exdqlm.use_cpp_kf", FALSE))`
  - TRUE: `update_theta_bridge(...)` with `tryCatch` fallback to `update_theta(...)`
  - FALSE: direct `update_theta(...)` (R path)
- LDVB routing in `R/exdqlmLDVB.R:557-570`: same pattern as ISVB.
- MCMC path (`R/exdqlmMCMC.R`) currently runs R filtering/smoothing directly (no `exdqlm.use_cpp_kf` branch found).
- To force R fallback in ISVB/LDVB tests: `withr::local_options(exdqlm.use_cpp_kf = FALSE)`.

## Discrepancy hypothesis (indexing)
- Theory and C++ align on using transition at \(t+1\) in backward smoothing gain.
- R implementations above currently use `GG[,,t]` in smoothing gain (and MCMC covariance updates), while already using `GG[,,(t+1)]` for \(P/R\) and \(a_{t+1}\) terms.
- With R 1-based indexing and C++ 0-based indexing, the equivalent expressions are:
  - R target: `GG[,,(t+1)]`
  - C++ target: `GG.slice(t+1)`
- Likely issue: mixed indexing in R backward recursion (off-by-one in transition usage).

## Implementation sketch (for next chunk; not executed here)
1. Minimal code edits (surgical):
   - In R fallback FFBS blocks, replace smoothing gain transition term:
     - from: `t(GG[,,t])`
     - to: `t(GG[,,(t+1)])`
   - In MCMC backward covariance updates, align transition index similarly:
     - from: `sC = C[,,t] - sB %*% GG[,,t] %*% C[,,t]`
     - to: `sC = C[,,t] - sB %*% GG[,,(t+1)] %*% C[,,t]`
2. One high-signal regression test (CRAN-safe):
   - Add `tests/testthat/test-ffbs-indexing-parity.R`.
   - Build tiny model (small `TT`, `p > 1`) with time-varying, non-identity `GG[,,t]`.
   - Force R path with `withr::local_options(exdqlm.use_cpp_kf = FALSE)` and run ISVB/LDVB update path; compare against C++ path (same seed/data) on smoothed means/covariances with tolerance.
   - Pass criterion: materially reduced discrepancy after fix; deterministic runtime under CRAN limits.
3. Gate (next chunk only): run one phase gate `devtools::test()` + `devtools::check(--as-cran)` once.

## Commands used in this discovery chunk
- `rg -n "sec:ffbs|eq:bs_J|eq:bs_alpha|G_\\{t\\+1\\}|backward sampling" main.tex`
- `nl -ba main.tex | sed -n '256,298p'`
- `rg -n "sB\\s*=\\s*C\\[,,t\\]%\\*%t\\(GG\\[,,t\\]\\)%\\*%inv\\.R|for\\(t in \\(TT-1\\):1\\)\\{|update_theta<-function\\(|smoothed_theta<-function\\(" R -S`
- `nl -ba R/exdqlmISVB.R | sed -n '258,340p'`
- `nl -ba R/exdqlmLDVB.R | sed -n '260,336p'`
- `nl -ba R/exdqlmMCMC.R | sed -n '120,190p'`
- `nl -ba R/exdqlmMCMC.R | sed -n '262,304p'`
- `nl -ba R/exdqlmMCMC.R | sed -n '448,482p'`
- `nl -ba src/kalman.cpp | sed -n '274,304p'`
- `rg -n "exdqlm.use_cpp_kf|update_theta_bridge|use_cpp <-|getOption\\(" R/exdqlmISVB.R R/exdqlmLDVB.R R/exdqlmMCMC.R -S`
