# Independent Paired Forecast v8 Closeout

Decision: V8_COMPLETE_INTERNAL_GAINS_CONFIRMED.
Article decision: NO_ARTICLE_CHANGE_INTERNAL_VB_EVIDENCE_ONLY.

Frozen branch validation/independent-qdesn-paired-forecast-v8-20261002,
HEAD da74bb370edfb3f7e1c5c0c07332be1f9d7c220b, synchronized with its upstream.
All 20 jobs succeeded (4 cost, 4 replay, 12 paired forecast repetitions);
there are no v8 workers or sessions left. Completed October 2 at 14:21:47 PDT.

Base worktree:
`/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_paired_forecast_v8_20261002`.

Frozen evidence relative to that worktree:
`validation/fitforecast_v2/local_trackers/independent_qdesn_paired_forecast_v8_20261002__git-da74bb37`.

Final manifest SHA-256 (430 entries):
1d5d1402d56ddd9696f99c19c5f07a7a23954f1d482ec0f75f83ac8175d90182.
Combined checked manifests: 224 source + 493 input + 25 materialization +
430 final = 1,172 hash checks. All passed in the October 3 health audit.

Audit relative path:
`validation/fitforecast_v2/local_trackers/paired_forecast_v8_health_20261003_PDT`.
Its audit_file_manifest.csv SHA-256:
86be919ebcf79fbfd58e7a9ed0be194195883f2b24087d9f121a4da3587068a7.

Verification: 180 fitted-state comparisons had zero maximum error; 24 replay
scalar checks had zero maximum error. Independent recalculation of 90 origin
and 60 lead aggregate comparisons agreed within 6.6e-14. Fresh focused tests
passed 289 expectations, zero failures/warnings; six original VB smokes passed.
Logical storage 11,905,540 bytes, approximately 13 MiB allocated; no fitted
RDS/RDA/RData payloads. Worker maximum HWM about 1.54 GiB.

| Case | Control MAE | Challenger MAE | Relative Gain |
|---|---:|---:|---:|
| Normal AL p=.05 | 4.36393491098394 | 3.99373002580199 | 8.483282% |
| Normal exAL p=.25 | 6.63791280390611 | 3.27295297337092 | 50.693041% |

All three forecast seeds and all thirty lead averages improved primary MAE.
AL conditional check loss slightly regressed (1.29070226483325 versus
1.28814229069416), though pooled predictive check improved. exAL conditional
and pooled check improved. Neither challenger matches its frozen VB DQLM/
exDQLM comparator MAE (ratios about 1.95 and 1.92). Keep metric-specific
regressions and localized origin failures, rather than declaring complete wins.

These are corrected full-coupled VB fits on the internal 250-observation fitting
window. The three repetitions vary forecast sampling, not fitted posterior or
DGP data. Runtime was R 4.6.0, validation-source exdqlm 1.1.1 via pkgload,
not an unmodified CRAN binary. Do not insert these values into article MCMC
tables or infer M0 mixing improvements from VB results.

Next bounded task is the v9 direct MCMC challenger/control bridge documented
in INDEPENDENT_MCMC_BRIDGE_V9_PLAN_20261003.md. It preserves v8 priors and
designs, verifies exact VB warm starts and explicit M0, and uses corrected
forecast scoring. This closeout record changes no article assets, resumes no
legacy jobs and deletes no useful evidence. Runtime artifacts remain ignored.
The integration coordinator may preserve this validation closeout; no article
promotion is authorized by v8 alone.
