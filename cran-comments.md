## Test environments
- Local Ubuntu 24.04, R 4.5.1: R CMD check --as-cran
- GitHub Actions: ubuntu-latest, macOS-latest, windows-latest (release/devel)

## R CMD check results
0 errors | 0 warnings | 0 notes

## Notes
Small hygiene release: remove S3 NOTE by renaming an internal helper,
refresh docs metadata, add a minimal test, and enable CI. No API changes.
Maintainer remains Raquel Barata.
