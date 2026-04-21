## QDESN Tau050 Recovered Study-Facing Analysis Pack

Date: `2026-04-21`  
Status: planned analysis layer on top of the recovered 144-case tau050 main-comparison rerun

## Objective

The failed-run recovery and recovered 144-case main-comparison rerun are complete. The next step is
to produce a clean, study-facing pack that uses the recovered comparison root as its source of
truth but presents the strongest recovered layer as the primary narrative surface.

That means:

- no new repair-wave logic
- no new fit reruns
- no recomputation of the recovered source surface

Instead, this pack should sit on top of the canonical recovered main-comparison outputs and extract
the clearest, most defensible analysis surface for study presentation.

## Core Design

### 1. Representative layer is primary

The primary study-facing surface should be the 36-row representative layer because it gives:

- one selected fit per root
- `PASS/WARN` only
- `0` representative `FAIL` rows

This is the cleanest way to present the recovered study after the repair program.

### 2. Full recovered surface stays available as diagnostics

The full 144-row recovered fit inventory remains valuable, but mainly for:

- diagnosing where MCMC still has signoff softness
- showing where `rhs_ns` remains harder than `ridge`
- documenting residual `vb exal` tail-instability warnings

This should be kept as a secondary diagnostic appendix, not the headline surface.

### 3. Reference alignment stays explicit

The study-facing pack should keep the same reference-contract caveat already established:

- mirrored reference covers tau `0.05`, `0.25`, `0.95`
- recovered tau050 QDESN surface covers tau `0.05`, `0.25`, `0.50`

So the study-facing pack should:

- show aligned reference summaries where available
- explicitly inventory the representative rows that remain unaligned because of tau `0.50`

## Planned Outputs

### Summary markdown

- one compact study-facing summary markdown
- one representative-case-table markdown

### Tables

- analysis overview
- representative case table
- representative selection counts
- representative summaries by:
  - prior + model
  - family + prior
  - fit size + prior
- root readiness by prior
- representative reference alignment summary
- representative reference gap inventory
- diagnostic fail summaries:
  - fail axis summary
  - fail reason summary

## Implementation Shape

### R layer

Add a dedicated internal analysis module that:

- loads the recovered main-comparison root
- verifies the expected recovered-source counts
- computes the study-facing summaries
- writes the study-facing outputs

### Scripts

Add:

- a generic manifest-driven study-facing analysis runner
- a tau050-specific wrapper for the canonical recovered comparison root

### Config

Add a tau050-specific manifest that points to the canonical recovered main-comparison run and pins
the expected recovered counts.

### Tests

Add a focused regression test that:

- loads the canonical recovered comparison root
- writes a temporary study-facing pack
- verifies the key expected counts

## Success Criteria

The pack is successful if it shows, reproducibly, that:

- there are no remaining runtime failures in the recovered source surface
- the representative layer is clean enough to serve as the study-facing surface
- the remaining weakness is diagnostic and localized, not operational
- reference alignment gaps are explicitly documented instead of hidden

## Intended Read

This pack is the bridge from recovery engineering to analysis. It should let tau050 move forward
without mixing crash-recovery detail into the primary study narrative.
