# TRACK: QDESN Dynamic Family/Prior Validation Relaunch

Date: 2026-03-29  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1.1) Static Cross-Study Follow-On (2026-04-04)

This tracker remains the canonical record for the dynamic family/prior matrix and the final frozen
`R512` certification pass.

The next apples-to-apples comparison program is separate:

- tracker:
  - `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
- investigation:
  - `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
- plan:
  - `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`

That follow-on program mirrors the exdqlm static `gausmix / normal / laplace` dataset surface.

Static cross-study update:

- the initial broad shared-setup launch established the source baseline at `66/72` successful
  roots;
- Wave-2 Stage 1 then completed and showed that the original hard-fail probe roots are rescueable;
- the remaining static debt is now split into fit-fail buckets rather than one generic debt set:
  - `66` `rhs_ns` VB diagnostics-path FAIL rows,
  - `24` ridge `exal/mcmc` FAIL rows,
  - `40` `rhs_ns mcmc` FAIL rows;
- the active follow-up is now a local fit-fail closure static wave, not another broad static relaunch:
  - `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave1_broad_launch_20260404.md`
  - `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave2_stage1_closeout_20260404.md`
  - `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closure_20260404.md`
  - `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`

Important boundary:

- the dynamic matrix here is complete and certified;
- the new cross-study is static-only in its first launch and explicitly excludes dynamic row-15.

## 1) Mission

Relaunch the qdesn simulation/validation workflow with a coherent 2x2x2 matrix:

- likelihood family: `exal`, `al`
- beta prior: `ridge`, `rhs_ns`
- inference method: `vb`, `mcmc`

on dynamic simulation cases aligned with the broader validation style, while preserving:

- non-DLM readout contract (`readout.input_mode=raw_y_lags`, `decomposition.enabled=false`)
- existing `exal` behavior
- existing `rhs` and `rhs_ns` guardrails and diagnostics

## 2) Discovery Gate Report (Mandatory)

Status: **GO**

### 2.1 Branch Hygiene Snapshot

- working branch: `feature/qdesn-mcmc-alternative`
- HEAD at discovery start: `2641e6b8dd5ccbc50d8e53473e0c0c7df5dc32c4`
- local worktree was already dirty with active qdesn validation assets (preserved)

### 2.2 Capability Decision

**Decision:** no new model classes required.  
The required model kernels already exist. Remaining work is integration/routing + diagnostics/reporting parity.

### 2.3 Capability Matrix (Evidence-Based)

| likelihood_family | beta_prior_type | method | status in this branch | evidence |
|---|---|---|---|---|
| `exal` | `ridge` | `vb` | supported | `R/exal_ldvb_engine.R`, `R/exal_ldvb_fit.R` |
| `exal` | `ridge` | `mcmc` | supported | `R/exal_mcmc_fit.R` |
| `exal` | `rhs_ns` | `vb` | supported | `R/exal_ldvb_engine.R`, `R/qdesn_rhs_ns_prior.R` |
| `exal` | `rhs_ns` | `mcmc` | supported | `R/exal_mcmc_fit.R`, `R/qdesn_rhs_ns_prior.R` |
| `al` | `ridge` | `vb` | now routed as first-class | `R/exal_inference_config.R`, `R/exal_ldvb_fit.R`, `R/exal_ldvb_engine.R` |
| `al` | `ridge` | `mcmc` | now routed as first-class | `R/exal_mcmc_fit.R`, `R/qdesn_mcmc.R` |
| `al` | `rhs_ns` | `vb` | now routed as first-class | `R/exal_ldvb_engine.R`, `R/qdesn_vb.R` |
| `al` | `rhs_ns` | `mcmc` | now routed as first-class | `R/exal_mcmc_fit.R`, `R/qdesn_mcmc_validation.R` |

Legacy optional row:

- `likelihood_family in {exal, al}`, `beta_prior_type = rhs`, `method in {vb,mcmc}` remains available for backward compatibility.

### 2.4 Synthesis Policy Decision

Reference dynamic workflow alignment check did not provide an active synthesis-first dynamic contract.  
For this relaunch, synthesis is intentionally disabled by running single-tau roots (no `validation_p_vec` override), matching dynamic-style per-quantile validation and avoiding cross-quantile synthesis confounding.

## 3) Implementation Scope Completed

### 3.1 Integration

1. Added/confirmed first-class `likelihood_family` routing through:
   - inference config resolution
   - quantile fit spec resolution
   - VB and MCMC wrappers/engines
2. Kept `rhs` and `rhs_ns` additive paths intact.
3. Extended validation root identity and grouping to include `likelihood_family`.

### 3.2 Dynamic Scenario Support

`qdesn_validation_generate_toy_series()` now supports dynamic DLM scenarios via:

- `dlm_constV_smallW`
- `dlm_constV_bigW`
- `dlm_ar1V`

using `simulate_ts_mc_quantiles()` as the source generator for `y` + true quantiles.

### 3.3 AL Output Guardrails

Pipeline plotting was hardened so AL runs do not emit misleading gamma-specific posterior/trace artifacts.

## 4) Relaunch Assets

### 4.1 Defaults + Grid

- defaults:
  - `config/validation/qdesn_dynamic_family_prior_defaults.yaml`
- grid:
  - `config/validation/qdesn_dynamic_family_prior_grid.csv`
  - size: `36 roots = 3 scenarios x 3 taus x 2 families x 2 priors x 1 seed`

### 4.2 Run + Healthcheck Scripts

- launcher:
  - `scripts/run_qdesn_dynamic_family_prior_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_family_prior_wave.R`

## 5) Run Commands

Launch:

```bash
Rscript scripts/run_qdesn_dynamic_family_prior_wave.R \
  --workers 8 \
  --no-plots \
  --run-tag dynamic-family-prior-<timestamp>__git-<sha>
```

Health check:

```bash
Rscript scripts/healthcheck_qdesn_dynamic_family_prior_wave.R \
  --run-tag dynamic-family-prior-<timestamp>__git-<sha>
```

## 5.1) Live Relaunch Status (2026-03-29)

- active run_tag: `dynamic-family-prior-20260329-053603`
- run root:
  - `results/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b`
- launch mode:
  - `workers=8`
  - `no_plots=true`

Initial health snapshot right after launch:

| checkpoint | value |
|---|---:|
| expected_roots | 36 |
| materialized_roots | 8 (22.2%) |
| success_roots | 0 (0.0%) |
| running_roots | 8 |
| vb_health_files | 0 |
| mcmc_health_files | 0 |

Notes:

- This is expected early-run behavior (first batch of roots materialized and in-flight).
- Final campaign summary/group tables are generated only after root completion.

## 6) Promotion Gate

Primary comparison conclusions must use healthy fits only:

1. `status=SUCCESS`, `finite_ok=TRUE`, `domain_ok=TRUE`
2. signoff gate not `FAIL`
3. for RHS-family roots, diagnostics present and no collapse flags

Secondary tables still report all fits for transparency.

## 7) Risks / Blockers / Rollback

### Risks

1. AL paths can appear numerically stable but still fail MCMC drift diagnostics on harder roots.
2. Dynamic DLM cases can be runtime-heavy under MCMC at low-resource reservoir settings.

### Blockers

- No blocker for launch; all required model kernels exist.

### Rollback

- Keep existing static validation defaults untouched.
- Relaunch is isolated in new defaults/grid/scripts and separate report/result roots.

## 8) Baseline Completion Snapshot (2026-03-29)

The main dynamic relaunch baseline is complete and frozen:

- run_tag: `dynamic-family-prior-20260329-053603`
- roots: `36/36` successful
- results root:
  - `results/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b`
- reports root:
  - `reports/qdesn_mcmc_validation/dynamic_family_prior_rerun/dynamic-family-prior-20260329-053603/20260329-053636__git-2641e6b`

Stale histories remain preserved and excluded from promotion decisions:

- `dynamic-family-prior-20260329-053316` -> `ABORTED_STALE`
- `stageP ridge_anchor` arm -> `ABORTED_STALE`

## 9) Finalization Closeout (2026-03-29)

Finalization wave executed with zero broad-grid recompute and strict gates:

- closeout tag:
  - `closeout-20260329-074000__git-4536ccc`
- workspace:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc`
  - `results/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc`

### 9.1 Gate A

- `PASS`
- MCMC FAIL rows in baseline: `17`
- dominant clusters: `low_ess`, `half_chain_drift`, `high_acf`
- concentration: top-3 clusters explain `100%` of MCMC FAIL rows

### 9.2 Micro-Pilot (Gate B) Outcome

Profiles tested on 6 stratified failing roots:

- `P1_longer_chain`
- `P2_conservative_slice`
- `P3_blocked_adapt`

Hard-gate result:

- `Gate B = FAIL` (no profile satisfied all promotion criteria)
- best fail reduction: `33.3%` (`P1`), below required `>=40%`
- finite/domain safety: preserved in all profiles
- collapse guardrail regressions: none
- runtime inflation (median): `+89%`, `+117%`, `+144%` (all above `<=50%` gate)

### 9.3 Final Recommendation

- **Hold current MCMC defaults**
- **Escalate to kernel-level redesign** for MCMC failure roots
- **No conditional expansion run launched**, by design after Gate B fail

Authoritative outputs:

- phase01 summary:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase01_summary.md`
- phase35 summary:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase35_summary.md`
- phase35 manifest:
  - `reports/qdesn_mcmc_validation/finalization_closeout-20260329-074000__git-4536ccc/summary/phase35_manifest.json`

## 10) Final R512 Certification Update (2026-04-03)

This tracker remains the canonical record for the full dynamic matrix itself.

The late-stage QDESN repair sequence has now produced a promoted tuned candidate:

- `R512_r412_pass2_chain1000`

That candidate was not beaten cleanly by Phase 14 or Phase 15. The right final
move is therefore not more tuning, but one frozen certification rerun of this
same dynamic matrix.

New certification assets:

- frozen defaults:
  - `config/validation/qdesn_dynamic_family_prior_r512_certification_defaults.yaml`
- final orchestrator:
  - `scripts/run_qdesn_validation_final_r512_certification.R`
- certification plan:
  - `docs/PLAN__qdesn_validation_final_r512_certification_20260403.md`
- Phase-15 closeout:
  - `docs/REPORT__qdesn_validation_phase15_r512_sentinel_crossover_matrix_20260403.md`

Certification intent:

1. rerun the full `36`-root dynamic matrix once with frozen `R512`;
2. summarize root health, method signoff, and pair signoff end to end;
3. compare the rerun against the authoritative baseline campaign:
   - `dynamic-family-prior-20260329-053603`
4. finish with either:
   - `ACCEPT_R512_AS_CERTIFIED_BASELINE`, or
   - `HOLD_R512_WITH_CAVEATS`.
