# exdqlm 1.1.1 CRAN release compatibility addendum

This additive packet maps the completed independent exDQLM 1.1.1 validation
campaign to the public CRAN 1.1.1 release without rewriting historical
provenance.

- Public software authority: CRAN `exdqlm` 1.1.1
- Canonical URL: <https://CRAN.R-project.org/package=exdqlm>
- DOI: <https://doi.org/10.32614/CRAN.package.exdqlm>
- CRAN publication date: 2026-08-28
- CRAN source-tarball SHA-256:
  `3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e`
- Historical execution-tarball SHA-256:
  `6d51bf8e745e1a45bcc111fd578561cbf56b23b07e70eab5d95bd6e561243db1`
- Decision:
  `CRAN_1P1P1_PUBLIC_AUTHORITY_HISTORICAL_EXECUTION_PROVENANCE_RETAINED`
- Scientific rerun required solely for the CRAN transition: no

The tarballs are not globally identical because the historical validation tree
contains additional Q-DESN project infrastructure. The relevant exDQLM MCMC,
structured scale-shape, and serial RNG source files are byte-identical. A
fixed-seed tiny dynamic exDQLM VB/MCMC probe produces identical result objects
under the CRAN and historical installations.

Files:

- `cran_release_manifest.json`: public and historical authority mapping;
- `relevant_source_hash_comparison.csv`: selected source-file hashes and
  interpretation;
- `behavioral_compatibility_checks.csv`: interface and fixed-seed parity gates;
- `focused_upstream_test_summary.csv`: official CRAN inference, structured
  scale-shape, and RNG test results;
- `artifact_manifest.csv`: hashes for the machine-readable packet.

The original scoped compatibility promotion remains immutable. Reader-facing
article material should cite CRAN 1.1.1; frozen campaign manifests should keep
the exact historical tarball hash and source commit.

Verify the frozen packet from the repository root with:

```bash
Rscript validation/fitforecast_v2/scripts/verify_independent_exdqlm_1p1p1_cran_release_v1.R
```
