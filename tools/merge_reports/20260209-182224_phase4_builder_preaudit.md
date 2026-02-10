# Phase 4 pre-audit: builder inventory for `polytrendMod` / `seasMod` (Plan item 4.0)

## 1) Branch snapshot
- Branch: `integrate/v0.4.0-on-v0.3.0`
- HEAD at audit: `25aee9a`
- Scope: discovery/documentation only (no code edits; no test/check runs)

## 2) R builder inventory (`polytrendMod`, `seasMod`)

| Builder | Location | Return structure | Time-varying behavior |
|---|---|---|---|
| `polytrendMod` | `R/polytrendMod.R:22` | Returns list with `FF`, `GG`, `m0`, `C0`; class set to `exdqlm` at `R/polytrendMod.R:40` | `GG` is a static matrix (`order x order`), `FF` is static (`order x 1`) |
| `seasMod` | `R/seasMod.R:23` | Returns list with `FF`, `GG`, `m0`, `C0`; class set to `exdqlm` at `R/seasMod.R:69` | `GG` is static block-diagonal Fourier rotation matrix (special Nyquist branch when `max(w) == pi` at `R/seasMod.R:26`) |

### `polytrendMod` details
- `GG` initialized as identity (`R/polytrendMod.R:23`), then super-diagonal terms set for `order > 1` (`R/polytrendMod.R:25`).
- `FF` is `order x 1` with first entry one (`R/polytrendMod.R:24,26`).
- `m0` defaults to zero vector (`R/polytrendMod.R:30`), `C0` defaults to `1e3 * I` (`R/polytrendMod.R:36`).
- Input checks are local (length/dim checks only), no explicit coercion via `check_mod` inside this function.

### `seasMod` details
- Harmonic frequencies `w = h * 2*pi/p` (`R/seasMod.R:25`).
- If Nyquist harmonic present (`max(w) == pi`), dimension becomes `2*nh - 1` and final block includes `-1` (`R/seasMod.R:26-40`).
- Otherwise dimension is `2*nh` (`R/seasMod.R:42-55`).
- `FF` selects cosine rows (odd indices set to 1) (`R/seasMod.R:40,54`).
- `m0` defaults to zeros and `C0` to `1e3 * I` of matching dimension (`R/seasMod.R:56-66`).

## 3) `check_mod` invariants and validation rules
- Definition: `R/utils.R:189`.
- Required model class: must satisfy `is.exdqlm(model)` (`R/utils.R:190-192`).
- Required fields are effectively enforced upstream by `as.exdqlm` (`R/generics_etc.R:47-59`), then shape-checked here.

### Enforced invariants
- `m0`:
  - Must be vector or 1-row/1-col matrix, coerced to column matrix (`R/utils.R:196-203`).
  - State dimension `p <- nrow(model$m0)`.
- `C0`:
  - Coerced to matrix and must match `p x p` (`R/utils.R:204-207`).
  - Must be symmetric and PSD by eigenvalues (`R/utils.R:208-210`).
- `FF`:
  - Vector length `p` or matrix with one dimension equal to `p` (`R/utils.R:212-225`).
  - Coercion behavior: if matrix has `ncol == p`, it is transposed (`R/utils.R:216-218`), else retained.
- `GG`:
  - Supports matrix or array; matrix if no 3rd dim, array otherwise (`R/utils.R:227-235`).
  - First two dimensions must both match `p` (`R/utils.R:236-238`).

### Not enforced by `check_mod`
- No direct validation that `ncol(FF)` equals `dim(GG)[3]` when `GG` is time-varying.
- No explicit lower bound checks on lengths like `TT >= 1`; this is assumed by downstream fitters.

## 4) Composition/operator behavior (`+.exdqlm`)
- Definition: `R/generics_etc.R:88`.
- Both operands are normalized through `check_mod` (`R/generics_etc.R:89-90`).
- Combined state dimension is additive (`R/generics_etc.R:91`).

### Merge logic
- `FF` merge:
  - If either model has multi-column `FF`, both must have compatible column counts if both are multicolumn (`R/generics_etc.R:93-99`).
  - Otherwise concatenates vectors into `n x 1` (`R/generics_etc.R:100-102`).
- `GG` merge:
  - If either has a 3rd dim, creates array `n x n x max(TT)` and block-fills each component (`R/generics_etc.R:103-110`).
  - Otherwise uses block diagonal `magic::adiag` (`R/generics_etc.R:111`).
- `m0`, `C0` are concatenated/block-diagonal (`R/generics_etc.R:113-114`).
- Returns class `exdqlm` (`R/generics_etc.R:116`); no extra `check_mod` revalidation after merge.

## 5) C++ inventory for builder utilities

### Findings
- `src/matrix_creation.cpp` contains candidate builder functions (`generate_trend_matrices`, `generate_seasonal_matrices`, `generate_full_evolution_matrices`, etc.), but **all code is commented out** (`src/matrix_creation.cpp:1-175`).
- No active exported symbols for these builder functions in generated bindings:
  - `R/RcppExports.R` has no `generate_*` builder wrappers (contains exAL, Kalman, samplers only).
  - `src/RcppExports.cpp` has no `generate_*_matrices` entries for model builders.
- Current active C++ is focused on:
  - exAL core (`src/exAL.cpp` + `R/RcppExports.R:4-22`)
  - Kalman bridge (`src/kalman.cpp`, `update_theta_cpp` in exports)
  - sampling/post-pred utilities (`src/sampling_utils.cpp`, `src/sampling_truncnorm.cpp`).

### Active vs inactive summary
- Builder C++ utilities: **inactive (commented stubs only)**.
- Builder C++ routing in R: **none found**.

## 6) Backend routing pattern and option style
- Package option defaults set in `.onLoad`: `R/zzz.R:2-13`.
  - `exdqlm.use_cpp_kf = TRUE`
  - `exdqlm.use_cpp_samplers = FALSE`
  - `exdqlm.use_cpp_postpred = FALSE`
  - `exdqlm.compute_elbo`, `exdqlm.tol_elbo`
- Routing style in ISVB/LDVB (`R/exdqlmISVB.R`, `R/exdqlmLDVB.R`):
  - `use_cpp <- isTRUE(getOption("...", FALSE))`
  - if TRUE: call bridge in `tryCatch`, on error `warning(...)` and fallback to R.
  - else: use R path directly.
- Builder-specific option like `exdqlm.use_cpp_builders` is **not present**.

### Recommended Phase-4 routing interface (consistent with existing style)
- Add builder argument: `backend = c("auto", "R", "cpp")` in `polytrendMod` and `seasMod`.
- Add package option: `exdqlm.use_cpp_builders` (default `FALSE` initially to avoid behavior change pre-parity).
- Behavior:
  - `backend = "auto"`: uses option; if C++ selected and fails, warn and fallback to R.
  - `backend = "cpp"`: error on C++ failure (no silent fallback).
  - `backend = "R"`: deterministic R path.

## 7) Implementation-ready recommendation (Path A vs Path B)

### Recommendation based on findings: **Path B**
- Rationale: no active/exported C++ builder utilities currently exist; `matrix_creation.cpp` is commented and not wired.

### Path A (reuse existing utilities) feasibility
- Not feasible without first resurrecting/comment-unwinding `matrix_creation.cpp` and re-exporting APIs.
- Risk: large diff surface and uncertain parity with existing R builders.

### Path B (minimal new builder functions) touch list
- R layer:
  - `R/polytrendMod.R`
  - `R/seasMod.R`
  - `R/zzz.R` (option default for builders)
  - optional small helper file (e.g., `R/builder_backend.R`) for backend normalization.
- C++ layer:
  - add new focused builder source (`src/builder_mods.cpp`) or activate minimal subset in `src/matrix_creation.cpp`.
  - regenerate exports (`R/RcppExports.R`, `src/RcppExports.cpp`) with `Rcpp::compileAttributes()`.
- Docs/tests:
  - update minimal Rd usage if function signatures gain `backend` arg.
  - add one parity test file for builders.

## 8) Minimal Phase 4.4 parity test plan (CRAN-safe)
- File target: `tests/testthat/test-builders-equivalence.R`.
- Keep to 2-3 cases, no grids/benchmarks.

### Case 1: polytrend only
- Inputs: `order = 2`, simple `m0`, `C0`.
- Compare R vs C++ outputs for `FF`, `GG`, `m0`, `C0`.
- Assertions:
  - exact dimension checks,
  - `all.equal(..., tolerance = 0)` preferred for deterministic matrices.

### Case 2: seasonal only
- Inputs: `p = 12`, `h = 1` (single harmonic).
- Compare `FF`, `GG`, `m0`, `C0` R vs C++.
- Assertions:
  - dims exact,
  - `all.equal(..., tolerance = 1e-12)` if trig construction introduces tiny floating differences.

### Case 3: combined model
- Compose `polytrendMod(...) + seasMod(...)` using same backend selection.
- Assertions:
  - combined dims (state size and optional `TT` behavior) match,
  - block structure numerically equivalent (`FF`, `GG`, `m0`, `C0`).

### Forcing backend in tests
- If `backend` arg is implemented: call each builder explicitly with `backend = "R"` and `backend = "cpp"`.
- If only option exists initially: use `withr::local_options(exdqlm.use_cpp_builders = FALSE/TRUE)` in paired calls.
- Keep runtime tiny (<1s for builder tests) and deterministic.

## Commands used for this pre-audit
- `git status -sb`
- `git branch --show-current`
- `git rev-parse --short HEAD`
- `rg -n "polytrendMod\b|seasMod\b|season|harmonic|polytrend|build_.*Mod|make_.*Mod" R -S`
- `rg -n "check_mod\b|checkMod\b|validate_mod|stopifnot\(|inherits\(|is\.matrix|is\.array" R -S`
- `rg -n "\+\.exdqlm\b|Ops\.exdqlm\b|combineMods\b|compose|bind" R -S`
- `nl -ba R/polytrendMod.R | sed -n '1,220p'`
- `nl -ba R/seasMod.R | sed -n '1,260p'`
- `nl -ba R/utils.R | sed -n '160,280p'`
- `nl -ba R/generics_etc.R | sed -n '1,180p'`
- `rg -n "polytrend|seas|season|harmonic|builder|build|FF\b|GG\b|m0\b|C0\b|arma::cube|Rcpp::export" src -S`
- `rg -n "RcppExports|// \[\[Rcpp::export\]\]" src -S`
- `nl -ba src/matrix_creation.cpp | sed -n '1,260p'`
- `nl -ba R/RcppExports.R | sed -n '1,260p'`
- `nl -ba src/RcppExports.cpp | sed -n '1,220p'`
- `rg -n "use_cpp|options\(|getOption\(" R -S`
- `nl -ba R/zzz.R | sed -n '1,160p'`
