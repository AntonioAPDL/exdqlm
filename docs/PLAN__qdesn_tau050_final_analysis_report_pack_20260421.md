## QDESN Tau050 Final Analysis Report Pack

Date: `2026-04-21`  
Status: planned final post-recovery report layer built on the canonical tau050 study-facing pack

## Objective

The recovery work is complete and the recovered 144-fit tau050 study has already been rebuilt into a
clean study-facing pack. The next step is to promote that study-facing pack into a final
analysis/report layer that is:

- presentation-ready
- reproducible from pinned upstream outputs
- explicit about what is primary narrative versus appendix diagnostics
- explicit about why strict mirrored-reference tau `0.50` alignment is **not** being launched now

## Scope

### 1. Canonical primary surface

Use the recovered tau050 study-facing pack as the canonical presentation source.

This final layer should not:

- recompute the recovered 144-fit surface
- revisit repair-wave logic
- launch any new recovery compute

### 2. Final study/report outputs

Build a final report pack with:

- a headline narrative markdown
- main study tables from the representative layer
- a compact figure set for the representative surface
- a diagnostic appendix sourced from the full recovered 144-fit surface

### 3. Diagnostic appendix stays explicit

The final pack should keep the full recovered fit inventory visible, but only as appendix context for:

- residual `mcmc rhs_ns` signoff softness
- any remaining `vb exal` tail warnings
- root/prior/model diagnostic patterns

### 4. Strict reference alignment stays decision-gated

The current study-facing state already established:

- representative aligned rows: `24`
- representative gap rows: `12`
- all gap rows are tau `0.50`

So this final layer should:

- document the alignment gap clearly
- record a machine-readable decision not to launch strict mirrored-reference alignment now
- preserve the launch trigger if a manuscript later needs like-for-like tau `0.50` deltas

## Planned Outputs

### Summary markdown

- `qdesn_tau050_final_analysis_report.md`
- `qdesn_tau050_final_main_tables.md`
- `qdesn_tau050_final_diagnostic_appendix.md`
- `qdesn_tau050_strict_reference_alignment_decision.md`

### Tables

- final surface scorecard
- representative scorecard
- representative condensed case table
- reference alignment by tau
- strict-alignment decision table
- appendix fit scorecard
- appendix fail inventory
- figure index

### Figures

- representative grade mix by prior/model
- representative performance by prior/model
- reference alignment by tau
- diagnostic fail rate by method/prior

## Implementation Shape

### R layer

Add a dedicated final-pack analysis module that:

- loads the canonical study-facing pack
- resolves the recovered comparison root from the study-facing manifest
- builds the final summary tables
- builds the appendix tables
- writes a small, stable figure set
- writes the strict-alignment decision record

### Scripts

Add:

- a generic manifest-driven final analysis pack runner
- a tau050-specific wrapper

### Config

Add a tau050 final-pack manifest that pins:

- the canonical study-facing run tag
- the expected recovered counts
- the strict-alignment decision policy

### Tests

Add a focused regression test that:

- loads the canonical tau050 study-facing run
- writes the final pack to a temporary root
- checks the key outputs and decision record

## Success Criteria

This layer is successful if it:

- cleanly promotes the representative layer into the canonical study/report surface
- keeps the full recovered 144-fit surface as a bounded appendix
- records a clear no-launch decision for strict tau `0.50` reference alignment
- produces a single reproducible final pack that can drive the next reporting step without new compute
