# RQR-DESN Reference Source Inventory

Date: 2026-07-16

Purpose: record the local reference-paper cache used to plan and validate the
RQR-DESN implementation before the broad simulation study. The PDFs are kept in
the article literature cache rather than duplicated in this package worktree.

Primary cache:

```text
/data/jaguir26/local/src/Article-Q-DESN---Version-2/literature/pdfs
```

Primary manifest:

```text
/data/jaguir26/local/src/Article-Q-DESN---Version-2/literature/citation_audits/rqr_desn_reference_pdf_manifest_20260716.tsv
```

## Core RQR And Generalized Bayes References

| Role | Local file | Status |
|---|---|---|
| RQR interval-loss construction | `PouplinEtAl2024RQR__relaxed-quantile-regression-prediction-intervals-asymmetric-noise.pdf` | present in manifest |
| General Bayes update | `BissiriHolmesWalker2016GeneralBayes__general-framework-updating-belief-distributions.pdf` | present in PDF cache |
| MCMC/estimating-function uncertainty calibration | `Shaby2014OpenFacedSandwich__mcmc-estimating-functions.pdf` | present in manifest |
| General-posterior learning-rate calibration | `SyringMartin2019GeneralPosteriorCalibration__calibrating-general-posterior-credible-regions.pdf` | present in manifest |

## VB And Approximation References

| Role | Local file | Status |
|---|---|---|
| Variational inference review | `BleiKucukelbirMcAuliffe2017VIReview__variational-inference-review-statisticians.pdf` | present in manifest |
| ADVI reference | `KucukelbirEtAl2017ADVI__automatic-differentiation-variational-inference.pdf` | present in manifest |
| Structured Gaussian VB reference | `TanNott2018GaussianVA__sparse-precision-variational-gaussian-approximation.pdf` | present in manifest |

## Reservoir And Interval Forecasting Context

| Role | Local file | Status |
|---|---|---|
| Quantile-regression ESN intervals | `LvZhaoLiuWang2016QRESNE__quantile-regression-esn-ensemble-prediction-intervals.pdf` | present in PDF cache |
| Calibrated deep ESN interval forecasts | `BonasWikleCastruccio2024CalibratedDeepESN__calibrated-forecasts-deep-esn-penalized-qr.pdf` | present in PDF cache |

## Implementation Decision

No heavy PDFs are committed in this package worktree for this readiness step.
The package repo records the reference paths and the article cache stores the
actual files plus hashes. This avoids duplicate large artifacts while keeping
the implementation and simulation plans auditable.
