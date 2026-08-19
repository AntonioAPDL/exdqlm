# Independent Q-DESN forecast-gap adaptive MCMC v1: v8 closeout plan

## Scope

This closeout belongs only to the independent single-quantile Q-DESN/DQLM
validation lane. It does not authorize changes to joint Q-DESN, PriceFM,
GloFAS, application code, article `main`, or the direct Overleaf remote. The
Article Q-DESN integration lane owns the eventual merge and publication.

## Audited starting point

The adaptive campaign preserved and reverified 354 completed smoke,
calibration, discovery, replication, and sealed jobs. Its initial pipeline
stopped before confirmation because the host `awk` rejected a nonportable
conditional expression. The scientific design and all 354 completed results
were intact. A confirmation-only recovery fixed that orchestration defect,
verified immutable lineage and byte-identical scientific inputs, and launched
only the 24 missing full-budget canonical chains.

The completed campaign has the following fixed counts:

| Stage | Successful | Failed |
|---|---:|---:|
| Smoke | 2 | 0 |
| Calibration | 8 | 0 |
| Discovery | 184 | 0 |
| Replication | 64 | 0 |
| Sealed holdout | 96 | 0 |
| Canonical confirmation | 24 | 0 |
| **Total** | **378** | **0** |

Each confirmation chain used 5,000 burn-in iterations and 20,000 retained
iterations. exAL chains used exact M0
`M0_v_collapsed_support_logit`; AL chains retained the established
`sigma_then_gamma` transition. All workers used one computational thread and
the rolling-origin forecast contract with leads 1--30 and origin stride 30.

## Scientific promotion rule

The authority is case- and metric-specific. No global DESN specification is
required. For each frozen family, quantile, likelihood, and forecast metric,
promote the arithmetic mean of three canonical chains if and only if:

1. all three jobs completed successfully;
2. all three metric values are finite;
3. the three-chain arithmetic mean is strictly below the frozen v7 value.

Diagnostic grades remain visible provenance but are not a promotion veto.
Fit RMSE is not part of this forecast-first promotion and must remain inherited
from v7. Every nonwinning metric role must remain byte-for-byte numerically
unchanged in the v8 interface.

## Confirmed result

Three of eleven evaluated forecast roles meet the rule:

| Cell | Metric | v7 | Three-chain mean | Gain |
|---|---|---:|---:|---:|
| Q-DESN AL--RHS, Gaussian mixture, p=0.50 | Forecast oracle-quantile MAE | 2.367920628 | 0.907368829 | 61.68% |
| Q-DESN AL--RHS, Gaussian mixture, p=0.50 | Forecast check loss | 5.585104931 | 5.441483448 | 2.57% |
| Q-DESN AL--RHS, Gaussian, p=0.05 | Forecast check loss | 1.263697821 | 1.220899633 | 3.39% |

All three chains improved for each promoted role. The remaining eight roles
retain v7. No confirmed exAL role improved in this campaign.

The closeout initially displayed `MISSING` diagnostic grades because it read a
legacy `overall_status` field while current signoff files expose
`signoff_grade`. This is a deterministic metadata-parser defect, not missing
diagnostic evidence. The repair accepts both schemas and must be applied before
the immutable promotion packet is built.

## Reproducible closeout sequence

1. Repair and test diagnostic-grade parsing.
2. Re-run only the deterministic confirmation closeout; never refit a model.
3. Verify exactly 24 successful confirmation jobs, 11 metric roles, three
   strict gains, and zero fitted-model binary payloads.
4. Build a storage-light v8 authority by inheriting all 72 v7 rows and changing
   exactly the three approved forecast roles.
5. Freeze compact controls, canonical inputs, configs, statuses, signoffs,
   summaries, lead metrics, manifests, and hashes for all 24 chains. Exclude
   traces, fitted models, and serialized R payloads.
6. Generate a portable source ledger, output manifest, remaining-gap ledger,
   and an article delta ledger.
7. Verify the v8 package independently from its tracked frozen evidence.
8. Commit and push only this lane's branch, leave it clean and synchronized,
   and hand it to the integration lane as `READY_FOR_INTEGRATION`.

## Article integration consequence

The read-only article audit found that the currently rendered independent table
still uses the v6 interface. Therefore the integration packet must not describe
only the three v8-over-v7 changes. It must also include the two previously
confirmed v7 exQ-DESN Gaussian-mixture p=0.25 forecast gains. The complete v8
interface differs from the rendered v6 authority in exactly five numeric
forecast roles. The integration lane should consume the full v8 interface and
regenerate the article assets once, rather than applying ad hoc edits.

## Stop conditions

Do not publish the package if any hash changes, a configuration is not
full-budget, an exAL configuration is not exact M0, a promoted role is not a
strict three-chain mean improvement, any fit metric changes, any nonapproved
forecast metric changes, or a serialized model payload enters the packet.
