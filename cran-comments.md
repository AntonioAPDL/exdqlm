## Test environments

* Local: Ubuntu 24.04, R 4.5.1 — `R CMD check --as-cran`
* Win-builder: r-devel, r-release, r-oldrel — OK
* R-hub (GitHub Actions): `linux`, `windows`, `macos-arm64` on release R — OK

## R CMD check results

0 errors | 0 warnings | 0 notes (all platforms above)

## Notes for CRAN

* **Maintenance (hygiene) release**: small housekeeping only; **no API changes**.
* Updated examples/tests to avoid long runtimes and remove edge-case NOTE.
* Cleaned package sources (removed stray build artefacts; ensured no `doc/` in tarball).
* **Authors\@R**: added **Antonio Aguirre** as contributor (`ctb`). **Maintainer unchanged** (Raquel Barata).
* No reverse dependencies.
