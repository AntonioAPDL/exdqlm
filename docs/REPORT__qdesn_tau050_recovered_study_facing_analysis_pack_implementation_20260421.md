## QDESN Tau050 Recovered Study-Facing Analysis Pack Implementation

Date: `2026-04-21`  
Status: implementation package for the study-facing analysis layer built on the recovered tau050 main-comparison root

## Purpose

The recovered 144-case tau050 main-comparison rerun established the authoritative post-recovery
source surface. This implementation package adds a second-layer analysis pack that is explicitly
study-facing:

- primary surface: representative layer
- secondary surface: full recovered diagnostics

The goal is to move tau050 from repair engineering into presentation-ready analysis without
rebuilding the recovered source state again.

## What Was Added

### 1. Internal study-facing analysis module

Added:

- [R/qdesn_dynamic_exdqlm_crossstudy_study_facing_analysis.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_dynamic_exdqlm_crossstudy_study_facing_analysis.R)

This module provides:

- manifest loading
- recovered comparison-root loading
- expected-state checking
- representative-layer summaries
- reference-alignment summaries
- diagnostic fail summaries
- markdown and CSV output writing

### 2. Generic runner

Added:

- [scripts/run_qdesn_dynamic_exdqlm_crossstudy_study_facing_analysis.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_study_facing_analysis.R)

This follows the same manifest-driven pattern as the existing main-comparison runner:

- `--manifest`
- `--prepare-only`
- preflight markdown
- run metadata JSON
- completion metadata JSON

### 3. Tau050 wrapper

Added:

- [scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis.R)

This is the canonical entrypoint for the tau050 study-facing pack.

### 4. Tau050 manifest

Added:

- [config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis_manifest.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis_manifest.yaml)

The manifest pins:

- the canonical recovered comparison run root
- the study-facing report root
- the expected recovered-source counts

### 5. Focused regression coverage

Added:

- [tests/testthat/test-qdesn-dynamic-tau050-recovered-study-facing-analysis-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-recovered-study-facing-analysis-config.R)

The test confirms that the pack can be reproduced directly from the canonical recovered comparison
root and that the headline study-facing counts match expectations.

## Study-Facing Output Design

The new pack writes:

- overview table
- representative case table
- representative summaries by prior/model, family/prior, and fit size/prior
- root readiness by prior
- representative reference alignment summary
- representative reference gap inventory
- diagnostic fail summaries
- study-facing markdown summary
- representative-case markdown

## Verification

Focused validation passed:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-recovered-study-facing-analysis-config", reporter = "summary")'
```

Prepare-only validation also passed:

```bash
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis.R --prepare-only
```

## Read

This implementation package does not change the recovered tau050 source state. It adds a clean,
reproducible presentation layer that makes the recovered study easier to analyze and communicate.
