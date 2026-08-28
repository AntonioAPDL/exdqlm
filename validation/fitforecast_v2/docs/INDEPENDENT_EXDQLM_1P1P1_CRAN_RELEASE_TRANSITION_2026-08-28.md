# Independent exDQLM 1.1.1 CRAN release transition

## Decision

CRAN `exdqlm` 1.1.1 is the canonical public package version for installation,
citation, article prose, and future independent-validation work. Development
branch names are not reader-facing software references.

The completed 1.1.1 compatibility campaign is not relabeled. It ran with a
locally built 1.1.1 tarball whose SHA-256 is
`6d51bf8e745e1a45bcc111fd578561cbf56b23b07e70eab5d95bd6e561243db1`.
The CRAN source tarball has SHA-256
`3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e`.
Those archives are not byte-identical because the historical tree contains
additional project-specific Q-DESN infrastructure and development metadata.
Changing the frozen campaign record to the CRAN hash would therefore be
incorrect.

The compatibility evidence supports a clean separation:

1. CRAN 1.1.1 is the public software authority.
2. The local tarball hash remains the exact historical execution authority.
3. The relevant exDQLM inference paths are compatible, so a new scientific
   rerun is not required merely to adopt the CRAN citation.

## Evidence

The audit installs the CRAN source tarball in an isolated R library and compares
it with the frozen campaign library and tarball. It verifies:

- version 1.1.1 and the CRAN repository field;
- `collapsed_slice` as the first/default dynamic and static exAL MCMC proposal;
- structured `q(gamma) q(sigma | gamma)` as the VB default;
- a 151-node structured gamma grid;
- byte identity of the dynamic and static exAL MCMC engines, structured
  scale-shape implementation, static exAL VB implementation, and serial RNG
  helper sources;
- exact equality of fixed-seed tiny exDQLM VB and MCMC result objects; and
- the focused CRAN test files for inference configuration, structured
  scale-shape inference, and RNG repeatability.

The only audited dynamic-VB source difference is a duplicated `max_iter`
assignment in the historical tree. The fixed-seed parity check confirms that
it does not change the tested result. The larger historical inference-config
file supplies additional Q-DESN controls; it does not replace the public
`exdqlm` defaults checked here.

Machine-readable evidence is frozen under:

`validation/fitforecast_v2/promotions/independent_exdqlm_1p1p1_cran_release_addendum_20260828/`

The audit can be reproduced with:

```bash
Rscript validation/fitforecast_v2/scripts/audit_independent_exdqlm_1p1p1_cran_release_v1.R \
  --cran-tarball /path/to/exdqlm_1.1.1.tar.gz \
  --historical-tarball validation/fitforecast_v2/local_trackers/independent_qdesn_exdqlm_1p1p1_rerun_20260827/package/exdqlm_1.1.1.tar.gz \
  --cran-library /path/to/cran/1.1.1/library \
  --historical-library validation/fitforecast_v2/local_trackers/independent_qdesn_exdqlm_1p1p1_rerun_20260827/Rlib \
  --output-dir validation/fitforecast_v2/promotions/independent_exdqlm_1p1p1_cran_release_addendum_20260828
```

The CRAN source should be installed with `R CMD INSTALL` into the isolated
library before running the audit. The historical library is read-only.

## Article contract

The article should:

- cite `exdqlm` version 1.1.1 from
  <https://CRAN.R-project.org/package=exdqlm>;
- use DOI <https://doi.org/10.32614/CRAN.package.exdqlm>;
- describe DQLM/exDQLM comparators as using the inference implementation
  released in CRAN 1.1.1; and
- avoid development-branch or repository-commit language in reader-facing
  prose.

The compact reproducibility record may retain the local tarball SHA and source
commit because those fields identify the exact campaign environment. This is
not a conflict with using CRAN as the public software authority.

## Future runs

New independent-validation campaigns should install or pin CRAN `exdqlm`
1.1.1 directly and record the CRAN source-tarball hash, R version, compiler,
BLAS/LAPACK, and thread controls. They should not inherit the historical
development-branch requirement. Existing frozen manifests remain immutable.
