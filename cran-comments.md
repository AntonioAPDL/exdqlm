## exdqlm 0.4.0

### Test environments

* Local: AlmaLinux 8.10 (x86_64), R 4.4.0 (2024-04-24), `devtools::check(args = "--as-cran", cran = TRUE)`.
* R-hub (GitHub Actions): success on linux/windows/macos-arm64 (R-devel).
  * Run: https://github.com/AntonioAPDL/exdqlm/actions/runs/21786968497
* Win-builder: success r-release and r-devel.
  * Submission script: `scripts/precran_all.R` (submits r-release and r-devel).
  * Most recent submission logs in-repo: `check-logs/20260207-130034/winbuilder-release.log`,
    `check-logs/20260207-130034/winbuilder-devel.log` (from pre-release run).

### R CMD check results

`devtools::check(args = "--as-cran", cran = TRUE)`: 0 errors | 0 warnings | 3 notes (local).

### Notes for CRAN

* This release adds `exdqlmLDVB`, a Laplace-Delta variational Bayes routine for dynamic quantile state-space fitting.
* Existing 0.3.0 behavior is preserved; release prep changes are metadata/docs/hygiene only.
* Build hygiene remains unchanged: OpenMP optional and guarded; `Makevars{,.win}` uses R macros.
* CRAN parity hygiene includes filename case normalization (`R/exal.R`) without method-output changes.
* Consolidation note: this branch is the stabilized 0.4.0 base that will be folded into the planned 0.5.0 consolidated submission branch.

### Notes from local check

* Installed size NOTE (libs ~24.7 MB) due to compiled C++ backends.
* "unable to verify current time" NOTE is an environment check-host issue.
* Non-portable compiler flags NOTE reflects system toolchain defaults (`-Werror=format-security`,
  `-Wp,-D_FORTIFY_SOURCE=2`, `-Wp,-D_GLIBCXX_ASSERTIONS`) rather than package-specific flags.

### Win-builder results 

* win-builder r-release: PASS
* win-builder r-devel: PASS
* Prior Win-builder spelling note on DESCRIPTION terms was addressed with wording cleanup in this branch.


