# Phase 3 CRAN hygiene gate (items 3.1-3.4)

## Branch snapshot
- Branch: `integrate/v0.4.0-on-v0.3.0`
- HEAD at report write: `4a45363`

## What changed
- `DESCRIPTION`: minimal wording cleanup in the Description field to address Win-builder spelling flags without adding a new spelling framework.
- `README.md` and `README.Rmd`: corrected backend default statements to match runtime defaults in `R/zzz.R` (C++ KF default TRUE, samplers default FALSE).
- `cran-comments.md`: added one-line consolidation breadcrumb for the later 0.5.0 combined submission and updated stale spelling-note wording.

## Spelling approach used (3.1)
- Existing spelling mechanism discovery found no `inst/WORDLIST` or equivalent whitelist file.
- Per phase rule, no new spelling framework was introduced.
- Implemented minimal `DESCRIPTION` text edits to avoid the flagged terms while preserving meaning.

## README/runtime alignment (3.2)
- Runtime defaults from `R/zzz.R`:
  - `exdqlm.use_cpp_kf = TRUE`
  - `exdqlm.use_cpp_samplers = FALSE`
- README lines that stated KF default FALSE were corrected (no API/behavior changes).

## Consolidation narrative prep (3.3)
- Added a short note in `cran-comments.md` that this branch is a stabilized 0.4.0 base intended to fold into a consolidated 0.5.0 submission branch.

## Phase gate results (single run)
- Log root: `check-logs/20260209-180120-phase3-hygiene`
- `devtools::test()`:
  - Result: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 847 ]`
  - Log: `check-logs/20260209-180120-phase3-hygiene/devtools-test.log`
- `devtools::check(args = "--as-cran", cran = TRUE)`:
  - Result: `0 errors | 0 warnings | 3 notes`
  - Log: `check-logs/20260209-180120-phase3-hygiene/devtools-check-as-cran.log`
  - Notes: installed size, unable to verify current time, system toolchain non-portable flags.

## Commits in this phase chunk
- `71dd46b` — `docs: fix DESCRIPTION spelling notes (ELBO/Kalman/variational)`
- `c783521` — `docs: align README backend defaults with runtime options`
- `4a45363` — `docs: add consolidation breadcrumb in cran-comments`
