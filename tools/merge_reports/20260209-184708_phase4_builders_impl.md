# PHASE 4 builders implementation gate (items 4.1-4.4)

## Branch snapshot
- Branch: `integrate/v0.4.0-on-v0.3.0`
- HEAD at gate run: `2c02a9e`

## Scope completed
Implemented PHASE 4 items 4.1-4.4 only:
- Added builder backend interface (`backend = c("auto","R","cpp")`) for `polytrendMod()` and `seasMod()`.
- Added package option `exdqlm.use_cpp_builders` with default `FALSE`.
- Added new C++ builder exports (Path B) for polytrend and seasonal FF/GG construction.
- Wired R builders to C++ with required semantics:
  - `backend="R"`: always R path
  - `backend="cpp"`: C++ path, error on failure
  - `backend="auto"`: use C++ only if `getOption("exdqlm.use_cpp_builders", FALSE)` is `TRUE`, with warning + fallback to R on C++ error
- Added minimal high-signal parity tests (R vs C++) for polytrend, seasonal, and composed models.

No default switch to C++ was made in this phase.

## Commits in this phase
- `0fa4dff` `chore: add builder backend interface scaffolding`
- `2e5d5ab` `feat: add C++ builder exports for polytrend and seas`
- `ed4dd51` `feat: wire builder backend routing with safe fallback`
- `2c02a9e` `test: add builder parity checks (R vs C++)`

## Files changed
- `R/zzz.R`
- `R/polytrendMod.R`
- `R/seasMod.R`
- `man/polytrendMod.Rd`
- `man/seasMod.Rd`
- `src/builder_mods.cpp`
- `R/RcppExports.R`
- `src/RcppExports.cpp`
- `tests/testthat/test-builders-parity.R`

## Phase gate execution (single run)
- Log root: `check-logs/20260209-183403-phase4-builders`
- Command 1:
  - `R -q -e 'devtools::test()' > check-logs/20260209-183403-phase4-builders/devtools-test.log 2>&1`
  - Result: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 867 ]`
- Command 2:
  - `R -q -e 'devtools::check(args="--as-cran", cran=TRUE)' > check-logs/20260209-183403-phase4-builders/devtools-check-as-cran.log 2>&1`
  - Result: `0 errors | 0 warnings | 3 notes`
  - Notes:
    - installed package size (`libs 25.9Mb`)
    - unable to verify current time
    - non-portable toolchain flags (`-Werror=format-security`, `_FORTIFY_SOURCE`, `_GLIBCXX_ASSERTIONS`)

## Notes
- C++ builder code was implemented in a new file (`src/builder_mods.cpp`) and does not modify `src/matrix_creation.cpp`.
- m0/C0 creation remains in R wrappers to minimize semantic risk and keep outputs aligned with existing behavior.
