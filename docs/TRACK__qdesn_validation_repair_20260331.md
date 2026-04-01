# TRACK: QDESN Validation Repair (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Branch checkpoint at tracker creation: `7610696c9336a01860d57ae473d9e153b5fe6748`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Turn the current QDESN validation situation into a disciplined repair program that:

1. preserves the evidence already produced;
2. isolates the main blocker before spending more compute;
3. repairs the highest-value failure mode first;
4. keeps validation reruns narrow until a real winner is demonstrated;
5. leaves a clear audit trail for future contributors.

This tracker is the operational roadmap for the next validation wave.

## 2) Executive Status

Current best read:

- the branch baseline improved materially in Phase 7 stability confirmation;
- the exact `R44` settings, rerun as `R61_r44_anchor`, are now the best stable baseline;
- the remaining fail set is down to two `smallW @ tau=0.95 exal` roots:
  one `rhs_ns`, one `ridge`;
- the current problem is no longer a broad full-surface search problem;
- the next highest-value step is a narrow `smallW` resolution screen with explicit guard rails.

Operational status:

- relaunch infrastructure has already been proven;
- the overnight kernel screen completed cleanly (`12/12` profiles completed);
- current branch package hygiene also includes the separate GIG propagation fix, but that fix does not replace the QDESN blocker analysis because QDESN MCMC uses `qdesn_fit_mcmc()` -> `exal_mcmc_fit()`.
- repair wave 1 on current `HEAD` completed cleanly (`4/4` profiles, `0` operational failures), but no candidate passed Gate B or reduced the severe fail set.
- repair wave 2 completed cleanly at the canary stage, but the new structural bridge candidate failed the canary gate and did not advance to the severe quartet.
- repair wave 3 completed cleanly at the canary stage; diagonal conditioning was effectively inactive on the hard canary and failed immediately.
- repair wave 4 completed cleanly at the canary stage; QR whitening activated exactly as intended and fixed the working-space condition number, but still failed the canary because drift worsened too much.
- Phase 6 completed cleanly and established `R44_r31_ridge_chain900_stepsout` as the practical carry-forward.
- Phase 7 completed cleanly (`12/12` Stage-1 profiles, `4/4` stability reruns, `0` timeouts, `0` runner errors).
- Phase 7 also showed that first-pass winners are not reliable by themselves; stability reruns materially changed the ordering.
- the current working baseline is therefore the exact `R61/R44` configuration, not a new descendant profile.

## 3) Read These First

If someone needs the shortest path to the current findings, read these in order:

1. `docs/REPORT__qdesn_validation_phase6_overnight_fullsix_screen_20260401.md`
2. `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`
3. `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
4. `docs/PLAN__qdesn_validation_phase7_r44_refinement_20260401.md`
5. `docs/REPORT__qdesn_validation_phase4b_phase5_20260331.md`
6. `docs/PLAN__qdesn_validation_phase6_overnight_fullsix_screen_20260331.md`
7. `docs/REPORT__qdesn_validation_phase4_split_prior_screen_20260331.md`
8. `docs/PLAN__qdesn_validation_phase4b_phase5_followup_20260331.md`
9. `docs/REPORT__qdesn_validation_phase3_family_b_screen_20260331.md`
10. `docs/PLAN__qdesn_validation_phase4_split_prior_screen_20260331.md`
11. `docs/PLAN__qdesn_validation_phase3_20260331.md`
12. `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
13. `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
14. `docs/REPORT__qdesn_validation_repair_wave4_20260331.md`
15. `docs/REPORT__qdesn_validation_repair_wave3_20260331.md`
16. `docs/PLAN__qdesn_validation_phase3_family_b_screen_20260331.md`
17. `docs/PLAN__qdesn_validation_phase2_20260331.md`
18. `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
19. `reports/qdesn_mcmc_validation/qdesn_validation_phase7_r44_refinement/qdesn-phase7-r44-refinement-20260401a__git-d3e43f7/stages/S2_stability_confirmation/screen_runs/qdesn-phase7-r44-refinement-20260401a__git-d3e43f7__S2_stability_confirmation/tables/profile_rank_summary.csv`
20. `reports/qdesn_mcmc_validation/qdesn_validation_phase6_overnight_fullsix_screen/qdesn-phase6-overnight-fullsix-20260331a__git-fc1f331/summary/family_b_screen_results.md`
21. `reports/qdesn_mcmc_validation/qdesn_validation_phase5_core_triad_screen/qdesn-phase5-coretriad-20260331a__git-cfacba5/summary/family_b_screen_results.md`
22. `reports/qdesn_mcmc_validation/qdesn_validation_phase4b_r18_fullsix/qdesn-phase4b-r18-fullsix-20260331a__git-cfacba5/stages/S1_full_six_confirmation/screen_runs/qdesn-phase4b-r18-fullsix-20260331a__git-cfacba5__S1_full_six_confirmation/tables/profile_rank_summary.csv`
23. `reports/qdesn_mcmc_validation/qdesn_validation_phase4_split_prior_screen/qdesn-phase4-splitprior-screen-20260331b__git-5f02a8a/summary/family_b_screen_results.md`
24. `reports/qdesn_mcmc_validation/qdesn_validation_phase3_family_b_screen/qdesn-phase3-familyb-screen-20260331a__git-7ef7554/summary/family_b_screen_results.md`
25. `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`

Core code paths to inspect before changing anything:

- `R/qdesn_mcmc.R`
- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`

## 4) What We Have Learned So Far

### Main findings

- Phase-01 closeout showed `19` MCMC FAIL rows and `4` failure clusters.
- `16/19` FAIL rows are `exal`.
- Inside `exal`, failures split evenly across priors: `8 rhs_ns` and `8 ridge`.
- The dominant failure families are `half_chain_drift`, `geweke_drift`, and `low_ess`.
- The failure pattern is concentrated on `tiny_d1_n8`, not spread uniformly across reservoirs.
- The completed overnight kernel screen showed that shared-core `exal` tuning beats longer chains.
- The best overall profile was `X10_core_gamma_focus_pass1`.
- The best `rhs_ns` cleanup profile was `X8_rhsns_freeze60_multistart3`.
- No screen profile created finite/domain/collapse regressions.
- The first conditioning candidate (`R5_diag_scale_precondition`) was effectively a no-op on the canary:
  raw and working condition numbers were identical and no columns were scaled.
- The stronger conditioning candidate (`R6_qr_whiten_precondition`) activated correctly:
  raw condition number `77.60 -> 1.00`, `20` columns transformed.
- The completed Family-B broad screen showed that transformed sigma plus gamma focus is a real working
  ingredient, but not a complete fix.
- The Family-B winner (`R8_logsigma_gamma_focus`) cut the severe quartet from `3 FAIL` to `2 FAIL`,
  but tied the anchor at `5 FAIL` on the fixed 6-root harness.
- Family-B also showed that the remaining fail set is now naturally split by prior family:
  ridge and `rhs_ns` do not want the same repair profile.
- The Family-B telemetry gap (`mcmc_use_log_sigma = FALSE`) was a reporting issue, not an execution issue:
  per-fit `cfg_received.json` confirmed that transformed sigma really was enabled in the screen.
- Even with QR whitening, the hard canary still failed because:
  `ESS` fell slightly (`6.25 -> 5.49`) and `half_drift` worsened materially
  (`0.53 -> 1.08`), despite a large `Geweke` improvement (`10.74 -> 0.87`).
- Phase 6 established `R44_r31_ridge_chain900_stepsout` as the practical carry-forward profile.
- Phase 7 stability confirmation showed that the exact `R44` settings reran better than the Stage-1 leaders.
- The new stable branch baseline is `R61_r44_anchor`, not a Phase-7 descendant.
- Under that stable baseline, the remaining fail set is only:
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
- Under that same baseline, the previous broad hard ridge cluster is no longer the main branch blocker.
- The remaining `rhs_ns` fail is now a narrow rhs-side `Geweke + half_drift` problem, not a core ESS problem.
- The remaining ridge fail is now a narrow `ESS + ACF + half_drift` problem with acceptable `Geweke`.
- Phase 7 also proved that stability reruns materially improve decision quality and should remain part of the repair program.

### Main takeaways

- This is a kernel-quality problem, not an orchestration problem.
- The primary pain point is shared `exal` core mixing, especially around `gamma`.
- Conditioning is a real lever for geometry, but conditioning alone is not enough to close the hard canary.
- `rhs_ns` tau-path behavior is secondary and should be repaired after the core is healthier.
- The hard benchmark root is `dlm_constV_bigW @ tau=0.05 exal ridge`.
- Broader reruns are not justified until a narrow micro-pilot winner exists.
- The next broad wave should optimize for `zero FAIL`, not universal `PASS`.
- The current best stable baseline is `R61_r44_anchor`.
- The search space is now small enough that broad full-6 screening is wasteful as a first stage.
- The next overnight program should focus on the two remaining `smallW @ tau=0.95 exal` fail roots and protect the current `WARN` guard rails.

## 5) Pain-Cluster Map

| cluster | evidence | interpretation | priority |
|---|---|---|---|
| Shared `exal` core mixing | `16/19` FAIL rows are `exal`; top screen winners are shared-core profiles | main blocker is shared `gamma/sigma` traversal quality | `P0` |
| `gamma`-driven diagnostics | `X10` had the strongest `ESS` and `Geweke` improvements | first repair should target core geometry, not chain length | `P0` |
| `rhs_ns` residual tau-path | `X8` cleaned the sentinels better than the core-only winners | important second-stage cleanup, not first-stage repair | `P1` |
| Persistent ridge hard case | `dlm_constV_bigW @ tau=0.05 exal ridge` stayed `FAIL` under top profiles | strongest canary for a real fix | `P0` |
| Reservoir-specific stress | severe roots all sit on `tiny_d1_n8` | likely interaction between readout geometry and sampler quality | `P1` |
| Not the core issue | no finite/domain/collapse failures, no evidence of boundary collapse dominance | do not optimize around infrastructure or collapse first | `P2` |

## 5A) Repair Wave 1 Outcome

Run:

- manifest: `config/validation/qdesn_validation_repair_wave1_manifest.yaml`
- run tag: `qdesn-validation-repair-wave1-20260331__git-59e0e2a`
- summary: `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/summary/screen_results.md`

Profiles tested:

- `R0_legacy_anchor`
- `R1_promoted_x10_core`
- `R2_x3_alternate`
- `R3_x10_plus_x8_rhsns_overlay`

Outcome:

- all four profiles were operationally healthy;
- no profile produced finite/domain/collapse regressions;
- no profile passed Gate B;
- no profile reduced the severe fail set below `4`;
- the best profiles (`R1` and `R3`) only reduced the total fail count from `6` to `5`;
- the common hard ridge root still failed under every candidate;
- the `rhs_ns` overlay helped one sentinel but did not change the branch-level decision.

Interpretation:

- the earlier overnight screen signal did not reproduce strongly enough on current `HEAD` to justify promoting `X10`, `X3`, or `X8` into package defaults;
- the main blocker remains unresolved shared `exal` kernel behavior on the severe quartet, especially the persistent ridge hard case;
- the repair wave assets are worth keeping, but the candidate default promotion itself should not be adopted.

## 5C) Repair Wave 2 Outcome

Run:

- manifest: `config/validation/qdesn_validation_repair_wave2_manifest.yaml`
- supervisor: `scripts/run_qdesn_validation_repair_wave2.R`
- run tag: `qdesn-validation-repair-wave2-20260331__git-49c96b4`
- result summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/summary/repair_wave2_results.md`

Profiles tested:

- `R0_legacy_anchor`
- `R4_gamma_sigma_bridge`

Structural candidate:

- new shared-core traversal mode in `R/exal_mcmc_fit.R`:
  `gamma_sigma_gamma`
- intent:
  preserve `R2`-style narrower sigma movement while adding an extra gamma refresh inside each core pass

Outcome:

- the wave was operationally healthy and stopped exactly where it should:
  `S1_canary`
- `R4_gamma_sigma_bridge` stayed `FAIL` on
  `dlm_constV_bigW @ tau=0.05 exal ridge`
- compared with the anchor on the canary:
  - `ESS`: `6.25 -> 4.06`
  - `Geweke`: `10.74 -> 1.22`
  - `half_drift`: `0.53 -> 0.98`
  - runtime: `2.452s -> 3.445s`

Interpretation:

- the bridge traversal improved one piece of the canary (`Geweke`) but moved the hard root in the wrong overall direction;
- the candidate did not produce the required “ESS up without drift blowup” behavior;
- the failure is now stronger evidence that minor traversal reshuffling around the same local kernel is not enough;
- the next repair should step away from this bridge family and move toward either:
  - a more substantive shared-core reparameterization / blocked move, or
  - an explicit readout conditioning / preconditioning intervention.

## 5D) Repair Wave 3 Outcome

Run:

- manifest: `config/validation/qdesn_validation_repair_wave3_manifest.yaml`
- supervisor: `scripts/run_qdesn_validation_repair_wave3.R`
- run tag: `qdesn-validation-repair-wave3-20260331a__precommit`
- result summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave3/qdesn-validation-repair-wave3-20260331a__precommit/summary/repair_wave3_results.md`

Profiles tested:

- `R0_legacy_anchor`
- `R5_diag_scale_precondition`

Conditioning candidate:

- new conditioning controls in `R/exal_inference_config.R`
- new conditioning path in `R/exal_mcmc_fit.R`
- candidate mode:
  `conditioning$mode = "diag_scale"`

Outcome:

- the wave was operationally healthy and stopped at `S1_canary`
- `R5_diag_scale_precondition` stayed `FAIL` on
  `dlm_constV_bigW @ tau=0.05 exal ridge`
- compared with the anchor on the canary:
  - `ESS`: `6.25 -> 3.32`
  - `Geweke`: `10.74 -> 5.41`
  - `half_drift`: `0.53 -> 1.31`
  - runtime: `2.452s -> 2.355s`
- conditioning summary showed the key diagnostic:
  - mode: `diag_scale`
  - active: `FALSE`
  - raw/work condition numbers: `77.60 -> 77.60`
  - gain ratio: `1.0`
  - scaled columns: `0`

Interpretation:

- diagonal standardization was effectively inert on the QDESN hard canary;
- this means Wave 3 was an honest negative result, not a hidden implementation failure;

## 5E) Phase 3 Family-B Outcome

Run:

- manifest: `config/validation/qdesn_validation_phase3_family_b_screen_manifest.yaml`
- supervisor: `scripts/run_qdesn_validation_phase3_family_b_screen.R`
- run tag: `qdesn-phase3-familyb-screen-20260331a__git-7ef7554`
- result summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase3_family_b_screen/qdesn-phase3-familyb-screen-20260331a__git-7ef7554/summary/family_b_screen_results.md`

Outcome:

- the broad transformed-sigma screen was operationally clean end to end;
- `S1_canary_screen` advanced three candidates:
  `R8_logsigma_gamma_focus`, `R12_logsigma_sigma_focus`, `R9_logsigma_gamma_focus_qr`;
- `S2_severe_quartet` selected only `R8_logsigma_gamma_focus`;
- `S3_full_six_final` found no final winner.

Main scientific read:

- transformed sigma plus gamma focus is now the strongest shared-core pattern we have;
- global sigma-focus alone is not enough;
- global QR is not enough as a whole-profile switch;
- the remaining fail set under the best Family-B candidate splits into:
  - ridge drift/geweke failures;
  - ridge ess/acf/geweke failures;
  - rhs_ns core drift/ess failures;
  - rhs_ns rhs-only geweke failures.

Interpretation:

- the screen narrowed the problem;
- it did not solve it;
- the next wave should split ridge and `rhs_ns` rather than forcing them through one global profile.

## 5F) Next Broad Wave

Next run:

- manifest:
  `config/validation/qdesn_validation_phase4_split_prior_screen_manifest.yaml`
- supervisor:
  `scripts/run_qdesn_validation_phase4_split_prior_screen.R`
- plan:
  `docs/PLAN__qdesn_validation_phase4_split_prior_screen_20260331.md`

Program:

- use the best Family-B profile as the live anchor;
- keep transformed sigma on;
- give ridge and `rhs_ns` different repair controls;
- optimize for `FAIL -> WARN`;
- stage on the severe quartet first, then the fixed 6-root harness.

## 5G) Repair Wave 4 Outcome

Run:

- manifest: `config/validation/qdesn_validation_repair_wave4_manifest.yaml`
- supervisor used: `scripts/run_qdesn_validation_repair_wave3.R`
- run tag: `qdesn-validation-repair-wave4-20260331a__precommit`
- result summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/summary/repair_wave3_results.md`

Profiles tested:

- `R0_legacy_anchor`
- `R6_qr_whiten_precondition`

Conditioning candidate:

- exact QR-whitening beta-draw preconditioning with original-scale beta outputs preserved
- candidate mode:
  `conditioning$mode = "qr_whiten"`

Outcome:

- the wave was operationally healthy and stopped at `S1_canary`
- `R6_qr_whiten_precondition` stayed `FAIL` on
  `dlm_constV_bigW @ tau=0.05 exal ridge`
- compared with the anchor on the canary:
  - `ESS`: `6.25 -> 5.49`
  - `Geweke`: `10.74 -> 0.87`
  - `half_drift`: `0.53 -> 1.08`
  - runtime: `2.452s -> 2.372s`
- conditioning summary showed the transform activated exactly as designed:
  - mode: `qr_whiten`
  - active: `TRUE`
  - raw/work condition numbers: `77.60 -> 1.00`
  - gain ratio: `77.60`
  - transformed columns: `20`

Interpretation:

- the QR-whitening candidate proved that conditioning is a real geometry lever;
- however, conditioning alone did not repair the hard canary because it traded a large `Geweke` win for a still-bad drift outcome and a small ESS drop;
- the branch now has a stronger diagnosis:
  poor working-space geometry is part of the problem, but the remaining blocker is the shared-core chain dynamics under that geometry, not geometry alone;
- this is the cleanest evidence yet that the next candidate family should be a true blocked/reparameterized shared-core move, with conditioning available only as a supporting ingredient.

## 5H) Phase 2 Audit Outcome

The Phase 2 artifact-only audit is now complete.

Primary outputs:

- audit generator:
  `scripts/run_qdesn_validation_phase2_audit.R`
- audit report:
  `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
- audit summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`
- hard-root metrics:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/hard_root_profile_metrics.csv`
- conditioning metrics:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/tables/tiny_d1_n8_conditioning_by_design.csv`

Checklist:

- [x] WP1 hard-root forensics
- [x] WP2 `tiny_d1_n8` conditioning audit
- [x] produce reusable audit tables and summary
- [x] decide whether conditioning is primary or amplifying

Main findings:

- the persistent hard root remains `dlm_constV_bigW @ tau=0.05 exal ridge`;
- current candidate families change the dominant failure mode, but do not remove the hard-root failure;
- `R1` lifts ESS on the hard root, but worsens half-drift;
- `R2` best contains hard-root drift, but still leaves ESS too low;
- `R3` degrades the hard root too much to be a serious next default;
- all unique `tiny_d1_n8` augmented readout designs are highly ill-conditioned and highly correlated;
- the same `tiny_d1_n8` design keys appear in both severe and sentinel roots, so conditioning is real but not sufficient.

Hypothesis-gate result:

- choose `H1` first:
  structural shared `gamma/sigma` traversal repair in the static `exal` core
- keep `H2` second:
  readout conditioning / preconditioning if `H1` fails
- keep `H3` third:
  `rhs_ns` residual cleanup only after shared-core progress exists

## 5I) Phase 4 Split-Prior Outcome

Run:

- manifest: `config/validation/qdesn_validation_phase4_split_prior_screen_manifest.yaml`
- supervisor: `scripts/run_qdesn_validation_phase4_split_prior_screen.R`
- run tag: `qdesn-phase4-splitprior-screen-20260331b__git-5f02a8a`
- report:
  `docs/REPORT__qdesn_validation_phase4_split_prior_screen_20260331.md`
- result summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase4_split_prior_screen/qdesn-phase4-splitprior-screen-20260331b__git-5f02a8a/summary/family_b_screen_results.md`

Outcome:

- the split-prior wave completed cleanly and stopped at `S1_severe_quartet_broad`;
- no candidate met the quartet advance gate;
- `R18_split_prior_rhsns_overlay` was the only profile that produced a real scientific improvement;
- `R18` reduced the severe quartet from `4 FAIL` to `3 FAIL` at low runtime inflation (`0.2019`);
- the repaired root was `dlm_ar1V @ tau=0.95 exal rhs_ns`, which moved from `FAIL` to `WARN`.

Interpretation:

- the `rhs_ns` overlay embedded in `R18` is worth carrying forward;
- Phase 4 did not produce a final winner, but it clearly narrowed the problem;
- the unresolved pain cluster is now:
  - `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

## 5J) Follow-Up Program After Phase 4

Plan:

- plan doc:
  `docs/PLAN__qdesn_validation_phase4b_phase5_followup_20260331.md`
- Phase 4B manifest:
  `config/validation/qdesn_validation_phase4b_r18_fullsix_manifest.yaml`
- Phase 5 manifest:
  `config/validation/qdesn_validation_phase5_core_triad_screen_manifest.yaml`
- generic staged runner:
  `scripts/run_qdesn_validation_phase3_family_b_screen.R`
- thin wrappers:
  `scripts/run_qdesn_validation_phase4b_r18_fullsix.R`
  `scripts/run_qdesn_validation_phase5_core_triad_screen.R`

Program:

1. `Phase 4B`: carry `R18_split_prior_rhsns_overlay` into the fixed 6-root harness against the current anchor.
2. `Phase 5`: keep `R18` as the local baseline and screen only the unresolved 3-root core triad.
3. advance to a full-6 follow-up only for triad survivors.

Why this is the right next move:

- it preserves the one Phase 4 improvement that clearly worked;
- it stops replaying dead QR, multistart, and chain-led families;
- it aligns the gate with the actual objective: remove `FAIL`, accept `WARN`;
- it narrows compute to the exact remaining blocker roots.

## 5K) Phase 4B + Phase 5 Outcome

Run evidence:

- report:
  `docs/REPORT__qdesn_validation_phase4b_phase5_20260331.md`
- Phase 4B manifest:
  `config/validation/qdesn_validation_phase4b_r18_fullsix_manifest.yaml`
- Phase 5 manifest:
  `config/validation/qdesn_validation_phase5_core_triad_screen_manifest.yaml`

Main results:

- `R18_split_prior_rhsns_overlay` improved the full fixed 6-root harness from `6 FAIL -> 5 FAIL`;
- `R31_r18_rhsns_pass2` then improved the unresolved triad from `3 FAIL -> 1 FAIL`;
- `R31_r18_rhsns_pass2` also improved the full fixed 6-root harness from `5 FAIL -> 3 FAIL`;
- `R31` removed all sentinel fails on the full-6 harness;
- the remaining fail set under `R31` is now:
  - `dlm_ar1V @ tau=0.95 exal rhs_ns`
  - `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`

Interpretation:

- `R31` is the current best profile and the right new anchor;
- the old broad split-prior question is now answered;
- the unresolved rhs issue is no longer broad instability, but a narrow drift problem;
- the dominant remaining blocker is now the ridge pair, both on `tiny_d1_n8`, and both centered on
  ESS plus half-drift.

## 5L) Phase 6 Overnight Direction

Next wave:

- plan doc:
  `docs/PLAN__qdesn_validation_phase6_overnight_fullsix_screen_20260331.md`
- manifest:
  `config/validation/qdesn_validation_phase6_overnight_fullsix_screen_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase6_overnight_fullsix_screen.R`

Design choice:

- use a single broad full-6 overnight screen rooted at `R31`;
- do not stage-gate on the triad again, because that question is already answered;
- do not rerun dead QR-led, conditioning-led, bridge-led, or old split-prior families;
- screen only targeted `R31` descendants that attack:
  - rhs drift stabilization;
  - ridge ESS plus half-drift recovery;
  - combined descendants of those two levers.

Success definition:

- `WARN` is acceptable;
- the next meaningful milestone is `total_fail_n <= 2` on the full fixed 6-root harness;
- preferred additional conditions are:
  - `sentinel_fail_n = 0`
  - `fail_reduction >= 0.30`
  - `runtime_inflation <= 1.25`

Why this is the right overnight wave:

- the fixed 6-root harness is now cheap enough to run broadly overnight;
- `R31` has already removed the nonessential search space;
- the remaining blocker set is small, explicit, and mechanically interpretable.

## 5M) Phase 6 Overnight Outcome

Run:

- plan doc:
  `docs/PLAN__qdesn_validation_phase6_overnight_fullsix_screen_20260331.md`
- result report:
  `docs/REPORT__qdesn_validation_phase6_overnight_fullsix_screen_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase6_overnight_fullsix_screen_manifest.yaml`
- run tag:
  `qdesn-phase6-overnight-fullsix-20260331a__git-fc1f331`

Outcome:

- the overnight screen completed cleanly with `12/12` profiles, `0` timeouts, and `0` runner errors;
- no profile created finite, domain, collapse, or unhealthy regressions;
- the stage stopped correctly with `selected_n = 0`;
- the nominal rank-1 profile was `R51_r31_rhssoft_ridgepass1_chain1200`, but it reintroduced `2` sentinel FAILs and
  was too expensive to treat as the next practical baseline;
- the best practical profile was `R44_r31_ridge_chain900_stepsout`.

Why `R44` is the practical carry-forward:

- `R44` reduced the fixed 6-root harness from `4 FAIL -> 3 FAIL` on the rerun baseline used in Phase 6;
- `R44` kept `sentinel_fail_n = 0`;
- `R44` had materially lower runtime inflation than the more aggressive combined winners;
- `R44` is the cleanest signal that moderate ridge chain extension plus wider step-out budgets are helping.

Exact remaining fail set under `R44`:

- `dlm_ar1V @ tau=0.95 exal rhs_ns`
  - `geweke_drift; half_chain_drift`
- `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `low_ess; high_autocorrelation; half_chain_drift`
- `dlm_constV_smallW @ tau=0.95 exal ridge`
  - `low_ess; high_autocorrelation; half_chain_drift`

Additional important read:

- `R44` preserved the repaired sentinel behavior;
- `R51` showed that heavier combined tuning can fix both ridge roots, but it does so by destabilizing rhs and sentinel roots;
- the Phase 6 rerun also showed that exact `R31` behavior is not perfectly stable across waves, so the next program should
  include an explicit stability check rather than assuming single-run rankings are exact.

## 5N) Phase 7 Direction

Next wave:

- plan doc:
  `docs/PLAN__qdesn_validation_phase7_r44_refinement_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase7_r44_refinement_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase7_r44_refinement.R`

Design choice:

- use `R44_r31_ridge_chain900_stepsout` as the new anchor;
- keep `R31` as a control profile, not the main baseline;
- search only the remaining useful space around:
  - mild rhs drift stabilization on top of `R44`;
  - ridge ESS plus half-drift refinement on top of `R44`;
  - a few combined descendants of those two levers;
- add a second-stage rerun of the top Stage-1 survivors to measure stability and filter out single-run winners.

What Phase 7 should explicitly avoid:

- replaying the full Phase 6 family unchanged;
- carrying `R51` forward as the main baseline;
- treating sentinel-breaking candidates as acceptable just because they improve severe roots;
- reopening broader closeout reruns before this local screen settles.

## 5O) Phase 7 Outcome

Run:

- plan doc:
  `docs/PLAN__qdesn_validation_phase7_r44_refinement_20260401.md`
- result report:
  `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase7_r44_refinement_manifest.yaml`
- run tag:
  `qdesn-phase7-r44-refinement-20260401a__git-d3e43f7`

Outcome:

- the full Phase 7 program completed cleanly:
  `12/12` Stage-1 profiles, `4/4` Stage-2 reruns, `0` timeouts, `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- the Stage-1 leaderboard was not stable:
  `R66` led the first-pass ranking but weakened materially on rerun;
- the exact `R44` settings reran best as `R61_r44_anchor`;
- `R61` improved to the best stable baseline currently observed:
  - `total_fail_n = 2`
  - `severe_fail_n = 2`
  - `sentinel_fail_n = 0`
  - `runtime_inflation = 0.7038`

Remaining fail set under `R61_r44_anchor`:

- `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
  - `geweke_drift; half_chain_drift`
- `dlm_constV_smallW @ tau=0.95 exal ridge`
  - `low_ess; high_autocorrelation; half_chain_drift`

Guard-rail `WARN` roots under `R61_r44_anchor`:

- `dlm_ar1V @ tau=0.95 exal rhs_ns`
- `dlm_constV_bigW @ tau=0.05 exal ridge`
- `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
- `dlm_constV_bigW @ tau=0.95 al rhs_ns`

Interpretation:

- the branch baseline improved, but by stabilizing the existing `R44` settings rather than promoting a new descendant;
- the remaining problem is now tightly localized to the `smallW @ tau=0.95 exal` pair;
- the `rhs_ns` residual is now a narrow rhs-side drift/Geweke problem;
- the ridge residual is now a narrow ESS/ACF/half-drift problem;
- stability reruns are now mandatory for decision-quality, not optional polish.

## 5P) Phase 8 Direction

Next wave:

- plan doc:
  `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase8_smallw_resolution_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase8_smallw_resolution.R`

Design choice:

- use the exact `R61/R44` settings as the new stable anchor;
- stop treating the current problem as a broad full-6 search;
- run a focused Stage-1 screen on the two remaining fail roots plus the most informative guard rails;
- carry only the best survivors into full-6 confirmation;
- require a final exact rerun before promoting any new winner.

Candidate families included:

- stable controls:
  `R80`, `R81`, `R82`
- rhs local repair descendants:
  `R83` to `R86`
- ridge local repair descendants:
  `R87` to `R90`
- disciplined combined descendants:
  `R91` to `R93`

What Phase 8 explicitly avoids:

- replaying the broad Phase-7 full-6 screen as the primary search surface;
- reopening QR-only, bridge-only, conditioning-only, or old transformed-sigma families;
- rerunning weak Phase-7 descendants such as `R62`, `R64`, `R67`, `R69`, `R70`, or `R71` as lead ideas;
- spending full-6 compute on every broad candidate before local evidence exists.

## 6) Candidate Improvement Areas

### Area A: conditioning / preconditioning family

Status:

- tested
- informative
- not promotable as a standalone fix

What we now know:

- diagonal scaling (`R5`) was effectively inert on the QDESN hard canary;
- QR whitening (`R6`) dramatically improved working-space conditioning and Geweke;
- neither candidate fixed the canary because drift remained too poor and ESS did not recover enough.

Interpretation:

- geometry matters;
- conditioning alone does not close the current blocker;
- any future use of conditioning should be as a supporting ingredient for a stronger shared-core repair, not as the main hypothesis.

### Area B: local `smallW rhs_ns` residual repair

Current co-primary repair area.

Why it is now active:

- the remaining `rhs_ns` fail under the stable baseline is localized to one root;
- the failure signature is now rhs-side `Geweke + half_drift`, not broad core ESS weakness;
- Phase 7 retained a credible rhs-local signal (`R63`) that can be reused in a disciplined way.

Most plausible directions:

- slightly deeper tau freeze during burn-in;
- softer transformed tau/c2 movement;
- one extra transformed-block refresh pass;
- modest keep-size increase only when paired with softer movement.

### Area C: local `smallW ridge` residual repair

Current co-primary repair area.

Why it is now active:

- the remaining ridge fail is also localized to one root;
- the failure signature is now `ESS + ACF + half_drift` with acceptable `Geweke`;
- Phase 7 retained credible ridge-local signals (`R68`, `R65`) even though the Stage-1 leader did not replicate.

Most plausible directions:

- one extra ridge core pass;
- slightly softer sigma movement;
- mild step-out expansion;
- modest ridge-only keep-size increase without reopening the heavy Phase-6 chain regime.

### Area D: branch revalidation

Deferred area.

Trigger:

- only after a new narrow winner clears:
  - the focused `smallW` resolution screen,
  - the fixed 6-root confirmation harness,
  - and the final stability rerun.

## 7) Repair Strategy

### Work Package 0: Evidence freeze and discipline

Checklist:

- [x] freeze the completed closeout findings
- [x] freeze the completed overnight kernel screen
- [x] separate the qdesn blocker map from the unrelated GIG propagation work
- [x] keep this tracker updated after every decision-changing change

Rules:

- do not launch broad validation reruns yet;
- do not compare across changing root sets;
- always include the anchor baseline in narrow reruns;
- always preserve run tags, manifests, and per-stage summaries.

### Work Package 1: Conditioning family completed

Scope:

- Candidate A1: `R5_diag_scale_precondition`
- Candidate A2: `R6_qr_whiten_precondition`

Checklist:

- [x] add conditioning control plumbing to config resolution
- [x] add root-level conditioning metadata to validation summaries
- [x] implement diagonal-scale conditioning candidate
- [x] run diagonal-scale candidate through the staged canary
- [x] confirm whether diagonal scaling is actually active on the canary
- [x] implement QR-whitening candidate
- [x] run QR-whitening candidate through the staged canary
- [x] document the family as informative but insufficient

Outcome:

- Family A is complete.
- Family A should not be promoted into defaults.
- Family A can be reused later as a supporting option, not as the primary standalone fix.

### Work Package 2: Structural shared-core family B

Target:

- one true blocked or reparameterized shared-core `gamma/sigma` candidate

Primary code files:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`
- `R/qdesn_mcmc.R`
- `tests/testthat/test-exal-mcmc.R`

Checklist:

- [ ] choose one Family-B hypothesis only
- [ ] keep the patch attributable to a single mechanism
- [ ] decide whether conditioning support is required or optional
- [ ] add config controls only for the chosen Family-B candidate
- [ ] add targeted invariance tests for the new core move
- [ ] keep the candidate off defaults unless it wins the staged funnel

Success intent:

- improve the hard canary in the overall intended direction;
- recover meaningful ESS without recreating drift blowup;
- remain operationally clean and runtime-disciplined.

### Work Package 3: Narrow validation funnel for Family B

Scope:

- anchor baseline
- one new Family-B candidate only

Checklist:

- [ ] run `V0` targeted unit and smoke invariants
- [ ] run `V1` hard canary
- [ ] capture root transitions, diag deltas, runtime inflation, and condition metrics
- [ ] advance to the severe quartet only if the canary really improves
- [ ] advance to the full 6-root harness only if the quartet improves

Hard gates:

- no new finite/domain failures
- no collapse regressions
- candidate must improve the hard canary overall, not just one metric
- runtime increase remains moderate
- severe fail count below current narrow-wave baseline before broader reruns

### Work Package 4: Residual `rhs_ns` overlay

Scope:

- winning Family-B candidate plus residual `rhs_ns` cleanup

Checklist:

- [ ] revisit moderate tau freeze only after a shared-core winner exists
- [ ] revisit multistart pilot screening only after a shared-core winner exists
- [ ] keep overlay evaluation separate from the core candidate proof

Success intent:

- clean residual `rhs_ns` sentinels after the main blocker is already improved.

### Work Package 5: Broader validation only after a narrow winner exists

Checklist:

- [ ] rerun refreshed closeout micro-pilot
- [ ] rerun dynamic family/prior baseline only after the micro-pilot holds
- [ ] regenerate closeout only after the dynamic baseline is fresh

This remains the first point where branch-level re-closeout becomes worth the compute.

### Work Package 6: Phase 8 `smallW` resolution program

Target:

- resolve the two remaining `smallW @ tau=0.95 exal` fail roots under the stable `R61` baseline;
- protect the current `WARN` guard rails while doing so.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`
- `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `config/validation/qdesn_validation_phase8_smallw_resolution_manifest.yaml`
- `scripts/run_qdesn_validation_phase8_smallw_resolution.R`

Checklist:

- [x] freeze the Phase-7 stability outcome as the new baseline
- [x] document the remaining fail pair and guard-rail set
- [x] define a 3-stage focused screen (`smallW resolution -> full-6 confirmation -> stability rerun`)
- [x] include only still-useful controls and local descendants
- [x] run prepare-only validation on the Phase-8 manifest
- [ ] launch the overnight Phase-8 program
- [ ] update the tracker with the first Phase-8 health/result checkpoint

Success intent:

- best case: `0 FAIL` on full-6 confirmation and rerun;
- meaningful win: `1 FAIL` with `0` sentinel FAIL that reproduces;
- minimum win: clear improvement on the two remaining fail roots without guard-rail regression.

## 8) Stop Conditions

Stop narrow repair and escalate to deeper redesign if any of these happen:

- the common hard root remains `FAIL` after the bridge family, the conditioning family, and at least one serious Family-B blocked/reparameterized candidate;
- a candidate improves one dimension but repeatedly reproduces the same drift blowup pattern;
- a candidate only wins by chain-length inflation close to the rejected `X2/X4/X9` regime;
- a candidate needs multiple unrelated mechanisms mixed together just to match the anchor.

## 9) Debugging and Documentation Standards

Every future candidate should satisfy these standards:

- use a unique run tag;
- preserve the fixed 6-root harness;
- record exact parameter changes from defaults;
- record root-level `FAIL -> WARN/PASS` transitions;
- record runtime inflation;
- record `ESS`, `Geweke`, and `half_drift` deltas;
- record whether conditioning support was active and how much it changed the working geometry;
- update this tracker with the outcome before moving to the next candidate;
- keep code changes attributable to a single hypothesis whenever possible.

## 10) What Not To Do

- do not rerun the full branch validation ladder before a narrow winner exists;
- do not spend more time on pure chain-length inflation as the first move;
- do not retry the bridge family as the main idea;
- do not retry conditioning alone as the main idea;
- do not treat this as a purely `rhs_ns`-only repair problem;
- do not mix multiple unrelated hypotheses into one candidate patch.

## 11) Main Docs To Watch Going Forward

### Main findings and takeaways

- `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`
- `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `docs/REPORT__qdesn_validation_phase6_overnight_fullsix_screen_20260401.md`
- `docs/PLAN__qdesn_validation_phase7_r44_refinement_20260401.md`
- `docs/PLAN__qdesn_validation_phase3_20260331.md`
- `docs/PLAN__qdesn_validation_phase3_family_b_screen_20260331.md`
- `docs/PLAN__qdesn_validation_phase2_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave1_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave3_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave4_20260331.md`
- `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/summary/repair_wave2_results.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave3/qdesn-validation-repair-wave3-20260331a__precommit/summary/repair_wave3_results.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/summary/repair_wave3_results.md`

### Root-level evidence

- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X10_core_gamma_focus_pass1.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X8_rhsns_freeze60_multistart3.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R3_x10_plus_x8_rhsns_overlay.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave3/qdesn-validation-repair-wave3-20260331a__precommit/stages/S1_canary/screen_runs/qdesn-validation-repair-wave3-20260331a__precommit__S1_canary/tables/phase35_transitions_R5_diag_scale_precondition.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/stages/S1_canary/screen_runs/qdesn-validation-repair-wave4-20260331a__precommit__S1_canary/tables/phase35_transitions_R6_qr_whiten_precondition.csv`

### Operational roadmap

- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `docs/PLAN__qdesn_validation_phase7_r44_refinement_20260401.md`
- `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`

## 12) Current Recommended Next Move

Do not reopen broad Phase-7-style full-6 screening as the primary search surface.

The next highest-signal step is:

1. treat `R61_r44_anchor` as the live stable baseline;
2. run the focused Phase-8 `smallW` resolution screen defined in
   `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`;
3. use the 5-root Stage-1 screen to compare rhs-local, ridge-local, and disciplined combined descendants efficiently;
4. carry only the strongest survivors into the fixed 6-root confirmation harness;
5. require a final exact rerun before promoting any new baseline;
6. reopen broader branch validation only if Phase 8 produces a stable winner.
