# VB Screen Freeze And Targeted Refinement Plan

Date: 2026-07-06

## Decision

The completed 2026-07-04 broad VB screens are technically successful but not final article-authoritative replacements.

- exDQLM/DQLM VB: complete and storage-light, but exDQLM still trails DQLM in the low-quantile `tau = 0.05` cells.
- Q-DESN RHS VB: complete and strict-ready, but no profile passes all primary fit and rolling-origin forecast dominance checks. Fit RMSE is the common bottleneck.

Therefore the next work is targeted VB-only refinement. Broad MCMC remains gated until the targeted VB evidence is complete and audited.

## Frozen Completed Evidence

Freeze script:

```bash
Rscript validation/fitforecast_v2/scripts/materialize_completed_vb_screen_freeze_20260706.R
```

Expected freeze root:

```text
validation/fitforecast_v2/promotions/vb_screen_completed_evidence_20260706
```

Inputs:

- exDQLM/DQLM run root: `validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_vb_noninferiority_screen__git-65fbf35`
- Q-DESN RHS report root: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization/qdesn-tt500-vb-rhs-optimization-full-20260704__git-65fbf35/20260704-091641__git-65fbf35`

## Targeted exDQLM/DQLM VB Refinement

Scope:

- families: `gausmix,laplace,normal`
- tau: `0.05`
- model variants: `dqlm,exdqlm`
- fit size: `500`
- inference: `VB`
- candidate registry: `validation/fitforecast_v2/config/exdqlm_dqlm_vb_tau005_refinement_candidates_20260706.csv`

Launcher:

```bash
Rscript validation/fitforecast_v2/scripts/orchestrate_exdqlm_dqlm_vb_tau005_refinement.R \
  --full \
  --workers 20
```

Expected run tag pattern:

```text
20260706_exdqlm_dqlm_vb_tau005_refinement__git-<sha>
```

Success criteria:

- all rows complete with status `done`
- healthcheck status `PASS`
- storage audit has no forbidden `.rds`, `.rda`, `.RData`, or `__design.rds` payloads
- summary identifies low-quantile winners and ratios against DQLM

## Targeted Q-DESN RHS VB Fit-Aware Refinement

Scope:

- source evidence: completed Q-DESN RHS VB optimization screen
- inference: `VB`
- likelihoods: `AL, exAL`
- prior: `rhs_ns`
- fit size: `500`
- objective: keep forecast strength while improving fit RMSE and preserving check loss

Materializer:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_rhs_fitaware_refinement.R
```

Launcher:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitaware_refinement.R \
  --full \
  --workers 20
```

Expected run tag pattern:

```text
qdesn-tt500-vb-rhs-fitaware-refinement-<timestamp>__git-<sha>
```

Success criteria:

- prepare preflight passes
- smoke passes
- full VB run finishes
- generic ranking and dominance ranking exist
- strict audit passes
- no forbidden binary payloads remain in successful roots

## Promotion Gate

Do not promote either targeted refinement into article tables until:

1. Both targeted VB runs finish.
2. The freeze pack and targeted run manifests are hashed.
3. A compact comparison table shows which cells improve and which regress.
4. We explicitly decide whether the goal is:
   - strict all-metric dominance,
   - forecast-first replacement with transparent fit caveat, or
   - model-family-specific replacement.

## MCMC Gate

Do not launch broad MCMC yet. MCMC should only be launched after the VB refinement identifies a small, stable set of candidates worth promoting.
