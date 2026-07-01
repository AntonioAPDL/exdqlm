# Q-DESN TT500 MCMC Authoritative Handoff

Status: promoted for article-facing TT500 comparison as diagnostic-qualified
MCMC evidence.

This decision supersedes the earlier post-MCMC broad-screening note that kept
the June 30, 2026 MCMC outputs as diagnostic evidence only. The revised rule is
narrower: the completed June 30 confirmation/rescue outputs are now the
authoritative Q-DESN exAL RHS MCMC rows for TT500 tables, but they must be
reported as diagnostic-qualified rather than diagnostic-clean.

## Promotion Artifact

- Promotion ID: `qdesn_tt500_mcmc_authoritative_20260701`
- Promotion directory:
  `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_authoritative_20260701`
- Summary CSV:
  `qdesn_tt500_mcmc_authoritative_summary.csv`
- Summary SHA-256:
  `3272c426c4844afc188099f8e63c3d4f442729ee851a0c2347afe7fdff70025d`
- Source CSV:
  `qdesn_tt500_mcmc_authoritative_sources.csv`
- Source CSV SHA-256:
  `7622a04e02ea3192079bf6d4c1528d26083a22d76a6ca91830c0b2f64a6cae5a`
- Manifest:
  `qdesn_tt500_mcmc_authoritative_manifest.json`
- Manifest SHA-256:
  `479e4f59b5d6c8eafcadc06a01eaa6951ab44852e40ab6b17f97be8a172cf8a4`

## Source Runs

Base confirmation run:

- Run tag:
  `qdesn-tt500-mcmc-vb-winner-confirmation-full-20260630__git-c051364`
- Campaign stamp: `20260630-101419__git-c051364`
- Fit summary SHA-256:
  `2da9c6101c863c757719c3f067f256ea2695b79308bc41b62ab1403799006b73`
- Audit summary SHA-256:
  `da9b0f8675d611d9514b7edea44730e5c42effa5bcc31722dda4bbac6bed210b`
- Root audit SHA-256:
  `c36d7cc4a4b84b2ca5ed5dbe14263ba42c7c6dcfb8a0eb27668de61d070fe2f2`
- Healthcheck SHA-256:
  `0250af830689748c2180a948934357f4708dc42690721a3482643c0e39bfe181`

Five-root rescue run:

- Run tag:
  `qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364`
- Campaign stamp: `20260630-112709__git-c051364`
- Fit summary SHA-256:
  `c0a31eed6e7f01b37aacd314def97d014a814a4c5e6b864aa603f4c46f8b96df`
- Audit summary SHA-256:
  `91cf1d07364cc7681b16a3897af039aa0e0c7f5a5031a4cb8860254c757f0c1e`
- Root audit SHA-256:
  `e784a48315b7c2feeb1a28698c0941f73d9a2cc7a03923d0beccd08bb93530fc`
- Healthcheck SHA-256:
  `a885ccfde7f0339c1f9943dea4fee093de1df01409c37e8cddb7822f872d042d`

The promoted row set uses rescue rows where available and base confirmation
rows otherwise. The final selected set contains 9 TT500 Q-DESN exAL RHS MCMC
rows: 5 from rescue and 4 from base.

## Diagnostic Qualification

The promotion is intentionally not diagnostic-clean.

- Selected rows: 9
- Successful rows: 9
- Diagnostic signoff counts: `WARN=7`, `FAIL=2`, `PASS=0`
- Remaining `FAIL` rows:
  - `normal`, `tau=0.25`, reason `high_autocorrelation`
  - `gausmix`, `tau=0.25`, reason `high_autocorrelation`
- `WARN` rows use reason `chain_marginal_but_usable`.

These rows are acceptable for the article table only if the table manifest and
manuscript text preserve this diagnostic qualification. They must not be
described as strict diagnostic-clean MCMC.

## Contract

- exdqlm package baseline: `1.0.0`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Materialization HEAD:
  `e99ccdb9ac583e7f494a61879d89a480758638f7`
- Source registry hash name: `000__bundle_manifest.json.sha256`
- Source registry hash value:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Fit size: `500`
- Training target source window: `8501:9000`
- Forecast block: `9001:10000`
- Forecast origin source index: `9000`
- Rolling-origin max lead: `30`
- Origin stride: `30`
- Protocol: `rolling_origin_no_refit_state_update`
- Quantile synthesis: disabled
- Scored lead rows per cell: `30`
- Scored origin-target pairs per cell: `1000`

## Article-Facing Rule

Article-Q-DESN may consume this promotion artifact to replace only the
`qdesn_exal_rhs_ns` MCMC TT500 rows in the final validation tables. It must not
replace:

- Q-DESN VB rows
- Q-DESN AL rows
- Q-DESN ridge rows
- DQLM or exDQLM rows
- TT5000 rows
- exploratory screening outputs

The article table builder must verify the promotion summary hash and manifest
hash before replacement, and it must fail if any active path points at
`/home/jaguir26/local/src`.

## Non-Goals

- No new compute is launched by this promotion.
- No TT5000 claim is made.
- No MCMC diagnostic-clean claim is made.
- No successful heavy `.rds`, `.rda`, or `.RData` payload is retained as part
  of the article-facing handoff.
