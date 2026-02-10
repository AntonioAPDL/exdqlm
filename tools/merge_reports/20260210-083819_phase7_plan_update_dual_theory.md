# Phase 7 Plan Update: Dual Theory Repositories

- Date (UTC): 2026-02-10 08:38:19
- Branch: `integrate/v0.6.0-on-v0.5.0`
- Scope: local `Plan.txt` tracker update (untracked) + committed record for audit traceability.

## What Changed In `Plan.txt`

### Header reference block
- Replaced single theory reference with two canonical references:
  - Static regression theory: `/data/muscat_data/jaguir26/exAL---Regression/main.tex`
  - Dynamic exDQLM theory: `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`

### Global non-negotiable `G1`
- Updated wording from single-`main.tex` validation to dual-theory validation across static and dynamic kernels.

### PHASE 7 restructuring
- Replaced monolithic `PHASE 7` with:
  - `PHASE 7A — Static exAL theory cross-check`
  - `PHASE 7B — Dynamic exDQLM theory cross-check`
- Added explicit per-subphase deliverables, resolution rules (align vs mapping notes), and gate condition (“run gates only if package code changes”).

### Theory checklist section
- Replaced generic checklist with explicit static vs dynamic checklist bullets, each anchored to the corresponding canonical repository.

## Canonical Theory Sources

- Static: `/data/muscat_data/jaguir26/exAL---Regression/main.tex`
- Dynamic: `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`

## New Phase 7 Deliverable Scope

- **7A (Static)**: verify and map `regMod` + static VB/MCMC/LDVB/ELBO implementation against static manuscript equations and conventions.
- **7B (Dynamic)**: verify and map `exdqlmISVB`/`exdqlmLDVB`/`exdqlmMCMC` + KF/FFBS/LDVB/ELBO implementation against dynamic manuscript equations and conventions.
- Both subphases permit minimal fixes only when a correctness bug is proven; otherwise use explicit mapping notes.

## Notes

- `Plan.txt` remains local and ignored; this report is the committed source-of-record for the scope correction.
