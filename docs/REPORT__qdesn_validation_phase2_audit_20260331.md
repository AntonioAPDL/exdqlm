# REPORT: QDESN Validation Phase 2 Audit (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Audit output root: `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f`

## 1) Purpose

Convert the current Wave 1 repair evidence into a concrete Phase 2 decision:

1. explain the persistent hard-root failure mechanistically;
2. determine whether `tiny_d1_n8` conditioning is a primary cause or an amplifier;
3. choose the next implementation target before any new rerun.

This audit uses existing artifacts only. No new validation jobs were launched.

## 2) Inputs

Primary evidence used:

- `scripts/run_qdesn_validation_phase2_audit.R`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R0_legacy_anchor.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R1_promoted_x10_core.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R2_x3_alternate.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R3_x10_plus_x8_rhsns_overlay.csv`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- audit-generated tables in `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/`

## 3) Executive Read

The current blocker is still the shared static `exal` MCMC core, not the validation harness and not a purely `rhs_ns`-specific path.

The new Phase 2 audit sharpens that further:

- the persistent hard root is still `dlm_constV_bigW @ tau=0.05 exal ridge`;
- Wave 1 candidates changed which core diagnostic dominated, but none removed the hard-root failure;
- `tiny_d1_n8` readout geometry is clearly stressed and highly correlated, but conditioning alone does not explain the failure map;
- the next patch should target shared `gamma` / `sigma` traversal behavior under stressed geometry, not another small width/pass/freeze promotion.

## 4) Hard-Root Forensics

Target root:

- `dlm_constV_bigW @ tau=0.05 exal ridge`

Profile-level summary:

| profile | ESS | Geweke | half_drift | signoff reason | read |
|---|---:|---:|---:|---|---|
| `R0_legacy_anchor` | `6.80` | `1.30` | `0.795` | `low_ess; high_autocorrelation; half_chain_drift` | mixed failure, mostly low mixing plus sigma drift |
| `R1_promoted_x10_core` | `13.20` | `1.63` | `1.061` | `half_chain_drift` | ESS improves strongly, but drift gets worse |
| `R2_x3_alternate` | `4.31` | `0.96` | `0.541` | `low_ess; high_autocorrelation; half_chain_drift` | best-balanced drift control, but ESS still too low |
| `R3_x10_plus_x8_rhsns_overlay` | `3.48` | `4.43` | `1.021` | `low_ess; high_autocorrelation; geweke_drift; half_chain_drift` | worst gamma instability of the four |

Parameter-level read from `hard_root_chain_parameter_metrics.csv`:

- `R0`: the root fails as a mixed gamma/sigma problem.
  - gamma drives low ESS (`6.80`)
  - sigma drives the worst half-drift (`0.795`)
- `R1`: the candidate improves ESS, but the failure collapses onto gamma half-drift (`1.061`).
  - sigma becomes healthy
  - gamma is still not stationary enough between chain halves
- `R2`: the candidate suppresses drift better than the others.
  - gamma half-drift falls to `0.170`
  - sigma half-drift falls to `0.353`
  - but gamma ESS is still only `4.31`, so the root remains `FAIL`
- `R3`: the overlay makes the hard root distinctly gamma-dominated.
  - gamma ESS falls to `3.48`
  - gamma Geweke rises to `4.43`
  - gamma half-drift rises to `1.021`

Main forensic takeaway:

- the hard root is not failing for one static reason under every profile;
- the current candidates are trading off `gamma` ESS against `gamma` / `sigma` drift rather than jointly stabilizing the core;
- the strongest next hypothesis should therefore be a structural shared-core change that raises gamma mixing without reintroducing the drift seen in `R1` and `R3`.

## 5) Severe-Quartet Read

The severe quartet remained intact under every Wave 1 profile.

Useful nuance from `severe_quartet_profile_metrics.csv`:

- `R1` improved ESS substantially on some severe roots, but also added new Geweke or half-drift pressure on others.
- `R2` produced the best local balance on the hard ridge root and materially improved the `dlm_constV_smallW @ tau=0.95 exal rhs_ns` row, but still did not clear the root-level fail thresholds.
- `R3` helped the `al + rhs_ns` sentinel, but it degraded the common hard ridge root too much to be a serious forward default.

Quartet-level takeaway:

- there is no evidence that a small promoted-default family can solve the branch blocker;
- there is evidence that different candidate families contain partial ingredients worth preserving:
  - `R1`: stronger ESS lift
  - `R2`: better drift containment

## 6) `tiny_d1_n8` Conditioning Audit

The audit reconstructed the actual augmented readout design used by the 6-root harness and evaluated its training-matrix conditioning.

Key metrics by unique design key:

| scenario | raw cond | scaled cond | reservoir-only cond | max abs corr | read |
|---|---:|---:|---:|---:|---|
| `dlm_ar1V` | `851.17` | `122.38` | `39.58` | `0.992` | clearly stressed |
| `dlm_constV_bigW` | `831.94` | `121.62` | `41.34` | `0.986` | clearly stressed |
| `dlm_constV_smallW` | `884.33` | `120.58` | `46.00` | `0.992` | clearly stressed |

Important interpretation details:

- all three unique `tiny_d1_n8` designs are highly ill-conditioned and highly correlated;
- post-scaling condition numbers remain around `120`, so readout scaling helps but does not normalize the geometry;
- reservoir-only conditioning is much better (`39` to `46`), which points to the augmented readout block, not the reservoir state alone, as the main geometry stress source;
- the same design keys appear in both severe and sentinel roots:
  - `dlm_constV_smallW||123||tiny_d1_n8` appears in both a severe root and a sentinel root
  - `dlm_constV_bigW||123||tiny_d1_n8` appears in both a severe root and a sentinel root

Conditioning takeaway:

- conditioning is real and should be treated as an amplifier;
- conditioning is not sufficient by itself to explain the failure map;
- this is why a pure design-conditioning patch is not the first Phase 2 hypothesis.

## 7) Hypothesis Gate

Primary next hypothesis:

- `H1`: structural shared `gamma` / `sigma` traversal repair for the static `exal` kernel

Rationale:

- it matches the hard-root forensic evidence directly;
- it matches the shared `exal` blocker map across priors;
- it is consistent with conditioning being an amplifier rather than a complete explanation.

What `H1` should try to preserve:

- the better drift containment seen in `R2`

What `H1` should try to add:

- the stronger ESS lift seen in `R1`

Deferred fallback:

- `H2`: readout design conditioning / preconditioning change

Why `H2` is second rather than first:

- same-design severe and sentinel roots prove geometry is not the whole story;
- a geometry-only patch would risk treating the amplifier while missing the shared core failure mode.

Lower-priority fallback:

- `H3`: `rhs_ns` warm-start / initialization cleanup after shared-core progress exists

## 8) Recommended Next Steps

Do next:

1. implement one shared-core structural candidate only;
2. validate it on the single hard ridge canary first;
3. if the canary improves materially, move to the severe quartet;
4. only after that rerun the full 6-root repair harness.

Do not do next:

- do not promote `R1`, `R2`, or `R3` defaults;
- do not restart the full validation ladder;
- do not spend another round on minor width/pass/freeze sweeps as the main idea.

## 9) Canonical Audit Artifacts

- audit generator:
  `scripts/run_qdesn_validation_phase2_audit.R`
- summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`
- hard-root profiles:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/hard_root_profile_metrics.csv`
- hard-root chain parameters:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/hard_root_chain_parameter_metrics.csv`
- severe quartet:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/severe_quartet_profile_metrics.csv`
- conditioning by root:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/tiny_d1_n8_conditioning_by_root.csv`
- conditioning by design:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/tiny_d1_n8_conditioning_by_design.csv`
