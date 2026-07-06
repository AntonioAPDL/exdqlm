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

### Launch Record

Active launched run:

```text
run_tag: 20260706_exdqlm_dqlm_vb_tau005_refinement__git-0d22ebc
tmux: ffv2_exdqlm_tau005_refine_20260706_0d22ebc
run_root: validation/fitforecast_v2/runs/20260706_exdqlm_dqlm_vb_tau005_refinement__git-0d22ebc
orchestrator_root: validation/fitforecast_v2/runs/20260706_exdqlm_dqlm_vb_tau005_refinement__git-0d22ebc/orchestrator/exdqlm-dqlm-vb-tau005-refinement-orchestrator-20260706__git-0d22ebc
```

Launch notes as of `2026-07-06 02:43 EDT`:

- prepare completed successfully
- smoke completed `4/4` rows with `PASS`
- full run started with `120` planned rows and first `20` rows active
- no forbidden `.rds`, `.rda`, `.RData`, or `__design.rds` payloads observed in the active run root at launch audit time

Invalid aborted run tag, do not consume:

```text
20260706_exdqlm_dqlm_vb_tau005_refinement__git-42c2727
```

This earlier launch stopped during prepare because the orchestrator created a log-only run root before the prepare helper checked for existing run roots. Commit `0d22ebc` fixed the guard so prepare refuses an existing prepared manifest, not a log-only directory.

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

### Launch Record

Active launched run:

```text
run_tag: qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727
tmux: ffv2_qdesn_rhs_fitaware_20260706_42c2727
orchestrator_root: reports/qdesn_mcmc_validation/qdesn_tt500_vb_rhs_fitaware_refinement/qdesn-tt500-vb-rhs-fitaware-refinement-orchestrator-20260706__git-42c2727
full_report_root: reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement/qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727
full_results_root: results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement/qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727
```

Launch notes as of `2026-07-06 02:43 EDT`:

- materialized fit-aware profile/grid artifacts were committed in `42c2727`
- prepare preflight passed
- smoke completed successfully
- full run started with `20` parallel workers
- first wave has `20` root status files marked `RUNNING`
- no forbidden `.rds`, `.rda`, `.RData`, or `__design.rds` payloads observed in the active Q-DESN run root at launch audit time

Provenance nuance:

- the run tag intentionally records the launch commit `42c2727`
- the nested full campaign timestamp path includes `20260706-024112__git-0d22ebc` because the full stage began after the exDQLM-only run-root guard fix was committed
- commit `0d22ebc` does not alter the Q-DESN fit-aware grid or Q-DESN computation path

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
