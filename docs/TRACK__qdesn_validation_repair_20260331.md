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

## 1.1) Follow-On Cross-Study Correction (2026-04-06)

The dynamic QDESN repair/certification program is now closed for this cycle.

The next comparison-facing program is a separate cross-worktree study.

The completed static exdqlm cross-study is now treated as a side study after a scope correction.

The intended deliverable is a **dynamic** exdqlm-aligned QDESN study, not the static analog that
was previously run.

Primary corrective assets:

- scope-correction report:
  - `docs/REPORT__qdesn_exdqlm_dynamic_scope_correction_20260406.md`
- corrected dynamic tracker:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
- corrected dynamic relaunch plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_validation_20260406.md`

Historical static side-study assets:

- tracker:
  - `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
- investigation memo:
  - `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
- plan:
  - `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`

The corrected follow-on program should instead mirror the exdqlm **dynamic** family-qspec surface
with QDESN fits under `exal/al x vb/mcmc x ridge/rhs_ns`.

Key correction findings:

- the static cross-study was run on the wrong data surface for the intended comparison study;
- the currently observed exdqlm dynamic family-qspec surface is:
  - `dlm_constV_smallW`
  - `gausmix/laplace/normal`
  - `tau in {0.05, 0.25, 0.95}`
  - `lastTT500/lastTT5000`
  - `18` observed dynamic dataset cells
- the current QDESN dynamic certification grid is also not a drop-in analog because it is
  scenario-based and uses `tau=0.50` rather than the observed family-qspec `tau=0.25`;
- the correct next move is therefore a fresh dynamic exdqlm-aligned relaunch with a new
  canonical-grid materialization path and a new dedicated external-dynamic runner.

Important boundary:

- this tracker remains the record for the dynamic QDESN repair/certification sequence;
- the static exdqlm cross-study should not be confused with the intended dynamic exdqlm-aligned
  comparison study.

## 2) Executive Status

Current best read:

- Phase 13 completed cleanly and produced the first promoted exact full-6 winner in the late-stage
  branch-facing QDESN sequence;
- Phase 14 then completed cleanly and did not produce a new winner, but it sharply narrowed the
  remaining problem from “find a better local family” to “combine the surviving local repair
  signals correctly”;
- `R512_r412_pass2_chain1000` remains the active scientific and practical baseline because no
  Phase-14 descendant beat it cleanly enough for promotion;
- the exact Phase-14 anchor rerun (`R600_r512_promoted_anchor`) is now the best raw branch-facing
  control in the `R512` neighborhood: `2 FAIL / 1 sentinel FAIL`;
- `R500_r412_provisional_anchor` should now be treated as a historical previous-anchor reference
  only, not the active comparison control for local crossover work;
- `R402_r65_balanced_control` remains the clean balanced control because it is still the cheapest
  useful balanced hedge, even though it was not competitive enough to win Phase 13;
- the `R612` ridge rescue, `R622` rhs-soft hedge, and `R616` sentinel-clean geometry clue are now
  the three surviving Phase-14 ingredients worth carrying forward;
- the `R421` trimmed descendants and the `R412 + R421` combined descendants remain retired as
  lead families; only their mild rhs-freeze lessons have already been absorbed into the surviving
  `R512` neighborhood;
- the exact `R61` family remains a runtime reference control only;
- the `R84` rhs-local family and the `R422` blockpass-led line should remain retired for
  lead-candidate purposes;
- under the final promoted `R512` result, the remaining FAIL set is still only three roots wide:
  `dlm_constV_bigW @ tau=0.05 exal ridge`,
  `dlm_constV_smallW @ tau=0.95 exal rhs_ns`,
  and `dlm_constV_smallW @ tau=0.95 exal ridge`;
- Phase 14 also showed that the current blocking issue on the exact 6-root harness is now one
  sentinel root (`dlm_constV_smallW @ tau=0.50 exal rhs_ns`) plus the still-hard
  `bigW ridge` residual, not a broad family-wide failure;
- the most useful new cross-worktree lesson is now sharper:
  once an exact winner is promoted and the next local wave fails, the correct response is not
  family reopening but a tiny crossover matrix built only from the surviving local signals;
- that sentinel-crossover matrix is now complete and non-promoting;
- the next highest-value step is one final frozen full-matrix certification rerun with `R512`,
  using the authoritative dynamic baseline campaign as the comparison reference and avoiding any
  new exploratory search wave.

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
- the earlier `R61/R44` stable result remains an important historical milestone, but the current
  branch-facing hierarchy is now `R312` provisional scientific lead, `R68` legacy exact reference,
  `R65` balanced clean control, and `R61` runtime control.
- Phase 8 completed cleanly (`14/14` Stage-1 profiles, `2/2` full-6 confirmations, `0` timeouts, `0` runner errors).
- Phase 8 showed that a focused local winner can improve the narrow screen and still fail the branch-facing full-6 confirmation step.
- Phase 8 also showed that the exact `R61` reference family did not reproduce its earlier `2 FAIL` result in that rerun.
- Phase 9 completed cleanly (`12/12` replicated full-6 profiles, `0` timeouts, `0` runner errors).
- Phase 9 showed that `R68` is the strongest replicated family, `R65` is the best runtime-balanced fallback, `R61` is no longer a clean lead baseline, and `R84` does not hold up under replication.
- Phase 10 completed cleanly (`15/15` Stage-1 profiles, `2/2` full-6 confirmations, `0` timeouts, `0` runner errors).
- Phase 10 showed that the focused local `R65` winner did not survive the exact full-6 confirmation step.
- Phase 10 also showed that exact `R68` remains stronger than that selected `R65` challenger on the real branch-facing harness.
- Phase 11 completed cleanly (`14/14` Stage-1 profiles, `6/6` Stage-2 reruns, `0` timeouts,
  `0` runner errors).
- Phase 11 showed that `R312_r68_pass1_chain950` is the new best rerun-confirmed scientific result,
  while `R301_r65_balanced_control` remains the best clean control.
- Phase 11 also showed that the remaining fail set under the best rerun-confirmed profile is now
  only three roots wide:
  `dlm_constV_bigW @ tau=0.05 exal ridge`,
  `dlm_constV_smallW @ tau=0.50 exal rhs_ns`,
  and `dlm_constV_smallW @ tau=0.95 exal rhs_ns`.
- the current branch state therefore supports a broader exact full-6 stabilization wave around
  `R312`, but not another family-reopening or reduced-screen-first program.
- Phase 12 completed cleanly (`15/15` Stage-1 profiles, `2/2` Stage-2 reruns, `1/1` Stage-3
  confirmations, `0` timeouts, `0` runner errors).
- Phase 12 showed that `R412_r312_softsigma_steps70` is the best practical rerun-confirmed local
  lead and should replace `R312` as the active search anchor.
- Phase 12 also showed that `R421_r312_rhsfreeze100_chain1100` is the strongest rhs-local upside
  signal, but still too costly and sentinel-risky for promotion.
- Phase 12 finally showed that `R422_r312_blockpass5` does not hold up cleanly enough to remain a
  lead family.
- Under the best practical Phase-12 rerun (`R412` Stage 2), the remaining FAIL roots are:
  `dlm_ar1V @ tau=0.95 exal rhs_ns`,
  `dlm_constV_bigW @ tau=0.05 exal ridge`,
  and `dlm_constV_smallW @ tau=0.95 exal ridge`.
- The current branch state therefore supports a broader but still disciplined exact full-6
  refinement wave around `R412 + R421 + R402`, not a reopening of retired families or a return to
  reduced-screen-first promotion logic.
- Phase 13 completed cleanly (`15/15` Stage-1 profiles, `7/7` Stage-2 reruns, `2/2` Stage-3
  confirmations, `0` timeouts, `0` runner errors).
- Phase 13 showed that `R512_r412_pass2_chain1000` is the first candidate in this late-stage
  sequence to survive both rerun confirmation and final zero-sentinel confirmation strongly enough
  for promotion.
- Phase 13 also showed that the Stage-1 local winner `R510_r412_chain1000` did not replicate and
  should now be treated as a local-only result rather than a lead family.
- Phase 13 further showed that the trimmed `R421` line and the narrow `R412 + R421` combined line
  do not hold up cleanly enough to remain in the main search family.
- Under the final promoted `R512` result, the remaining FAIL roots are:
  `dlm_constV_bigW @ tau=0.05 exal ridge`,
  `dlm_constV_smallW @ tau=0.95 exal rhs_ns`,
  and `dlm_constV_smallW @ tau=0.95 exal ridge`.
- The current branch state therefore supports a narrower exact full-6 residual-resolution wave
  around `R512`, not another reopening of `R421`, combined, hedge, or retired families.
- Phase 14 completed cleanly (`15/15` Stage-1 profiles, `0` timeouts, `0` runner errors).
- Phase 14 showed that no descendant beat `R512` cleanly enough to advance, but it also showed
  that the surviving local repair space is now a crossover problem, not a family problem.
- Phase 14 identified:
  - `R600` as the best broad repair pattern,
  - `R612` as the best ridge rescue,
  - `R622` as the best rhs-local hedge,
  - `R616` as the only zero-sentinel geometry clue.
- Phase 14 also showed that chain-only, pass-only, raw step-out-only, and the tested narrow
  coupled variants are not the right next lead directions.
- The current branch state therefore supports one more exact full-6 crossover wave around the
  surviving `R512` ingredients, not another one-axis sweep or family reopening.
- Phase 15 completed cleanly (`15/15` Stage-1 profiles, `7/7` Stage-2 reruns, `2/2` Stage-3
  confirmations, `0` timeouts, `0` runner errors).
- Phase 15 showed that `R702_r612_ridge_reference` was the strongest rerun-confirmed local signal,
  but it failed final confirmation by reintroducing a sentinel FAIL and therefore did not justify
  promotion over `R512`.
- The current branch state therefore supports a final frozen full-matrix certification rerun using
  `R512`, not another exploratory local repair wave.

## 3) Read These First

If someone needs the shortest path to the current findings, read these in order:

1. `docs/PLAN__qdesn_validation_final_r512_certification_20260403.md`
2. `docs/REPORT__qdesn_validation_phase15_r512_sentinel_crossover_matrix_20260403.md`
3. `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
4. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
5. `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
6. `docs/REPORT__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
7. `docs/REPORT__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
8. `docs/PLAN__qdesn_validation_phase15_r512_sentinel_crossover_matrix_20260403.md`
9. `docs/PLAN__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
10. `docs/PLAN__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
11. `docs/REPORT__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
12. `docs/PLAN__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
13. `docs/PLAN__qdesn_validation_phase11_exact_fullsix_matrix_20260402.md`
14. `docs/REPORT__qdesn_validation_phase10_replicated_ridge_resolution_20260402.md`
15. `docs/REPORT__qdesn_validation_phase9_replication_audit_20260401.md`
16. `docs/PLAN__qdesn_validation_phase10_replicated_ridge_resolution_20260401.md`
17. `docs/PLAN__qdesn_validation_phase9_replication_audit_20260401.md`
18. `docs/REPORT__qdesn_validation_phase8_smallw_resolution_20260401.md`
19. `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`
20. `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
21. `docs/REPORT__qdesn_validation_phase4b_phase5_20260331.md`
22. `docs/PLAN__qdesn_validation_phase6_overnight_fullsix_screen_20260331.md`
23. `docs/REPORT__qdesn_validation_phase4_split_prior_screen_20260331.md`
24. `docs/PLAN__qdesn_validation_phase4b_phase5_followup_20260331.md`
25. `docs/REPORT__qdesn_validation_phase3_family_b_screen_20260331.md`
26. `docs/PLAN__qdesn_validation_phase4_split_prior_screen_20260331.md`
27. `docs/PLAN__qdesn_validation_phase3_20260331.md`
28. `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
29. `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
30. `docs/REPORT__qdesn_validation_repair_wave4_20260331.md`
31. `docs/REPORT__qdesn_validation_repair_wave3_20260331.md`
32. `docs/PLAN__qdesn_validation_phase3_family_b_screen_20260331.md`
33. `docs/PLAN__qdesn_validation_phase2_20260331.md`
34. `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
35. `reports/qdesn_mcmc_validation/qdesn_validation_phase14_r512_residual_resolution/qdesn-phase14-r512-residual-resolution-20260403a__git-8ef64e1/summary/family_b_screen_results.md`
36. `reports/qdesn_mcmc_validation/qdesn_validation_phase13_r412_r421_stability_matrix/qdesn-phase13-r412-r421-stability-20260403a__git-373aa5f/summary/family_b_screen_results.md`
37. `reports/qdesn_mcmc_validation/qdesn_validation_phase13_r412_r421_stability_matrix/qdesn-phase13-r412-r421-stability-20260403a__git-373aa5f/stages/S2_rerun_confirmation/summary/stage_candidate_selection.md`
38. `reports/qdesn_mcmc_validation/qdesn_validation_phase13_r412_r421_stability_matrix/qdesn-phase13-r412-r421-stability-20260403a__git-373aa5f/stages/S3_final_sentinel_confirmation/summary/stage_candidate_selection.md`

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
- Phase 7 stability confirmation showed that the exact `R44` settings reran better than the Stage-1 leaders and temporarily localized the remaining fail set under `R61_r44_anchor`.
- Phase 7 also proved that stability reruns materially improve decision quality and should remain part of the repair program.
- Phase 8 then showed that a focused local winner can improve the narrow target set and still fail the full-6 confirmation step.
- Phase 8 also showed that the exact `R61` reference family did not cleanly reproduce its earlier best result.
- Phase 9 resolved that family-level reproducibility question enough to reopen local search and reorder the surviving families on replicated evidence.
- `R68` is now the best replicated scientific family lead:
  median `total_fail_n = 4`, median `sentinel_fail_n = 0`, and one exact replicate reached `2 FAIL / 0 sentinel FAIL`.
- `R65` is the best runtime-balanced ridge fallback:
  median `total_fail_n = 4`, median `sentinel_fail_n = 0`, median runtime inflation `0.878`.
- `R61` remains the cheapest useful reference family, but it no longer deserves to be treated as the lead search baseline because its median `sentinel_fail_n = 1`.
- `R84` is now a retired lead family: median `total_fail_n = 5`, median `sentinel_fail_n = 2`.
- Phase 10 then showed that the focused local `R65` winner did not survive exact full-6 confirmation and that the exact `R68` control remained stronger on the real branch-facing harness.
- Under the exact Phase-10 `R68` rerun, the residual FAIL roots are:
  - `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
- The current branch-facing question is no longer “which family survives replication,” but rather “which exact full-6 descendants of `R68` and `R65` can beat the reference without losing transfer stability.”
- Phase 11 then showed that the best rerun-confirmed scientific result is no longer raw exact `R68`,
  but `R312_r68_pass1_chain950`.
- Relative to the old exact `R68` anchor, `R312` repaired:
  - `dlm_ar1V @ tau=0.95 exal rhs_ns`: `FAIL -> WARN`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`: `FAIL -> WARN`
- Under the best rerun-confirmed Phase-11 profile (`R312`), the remaining FAIL roots are:
  - `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
- The current branch-facing question is now:
  which exact full-6 descendants of `R312` can preserve those repaired roots while clearing the
  remaining three-root residual set.
- Phase 12 then showed that the best practical rerun-confirmed result is no longer raw `R312`, but
  `R412_r312_softsigma_steps70`.
- Relative to the previous `R312` anchor, Stage-2 `R412` repaired:
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns` (`FAIL -> WARN`)
- That gain came at a cost:
  - `dlm_constV_smallW @ tau=0.95 exal ridge` regressed from `WARN -> FAIL`
- Under the best practical Phase-12 rerun-confirmed profile (`R412`), the remaining FAIL roots are:
  - `dlm_ar1V @ tau=0.95 exal rhs_ns`
  - `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
- Phase 12 also showed that `R421_r312_rhsfreeze100_chain1100` is the strongest rhs-local upside
  signal, but that its runtime/sentinel cost still blocks promotion.
- The current branch-facing question is now:
  which exact full-6 descendants of `R412` can preserve the repaired `smallW rhs_ns` behavior,
  borrow only the useful part of `R421`, and survive final sentinel confirmation.

### Main takeaways

- This is a kernel-quality problem, not an orchestration problem.
- The primary pain point is shared `exal` core mixing, especially around `gamma`.
- Conditioning is a real lever for geometry, but conditioning alone is not enough to close the hard canary.
- `rhs_ns` tau-path behavior is secondary and should be repaired after the core is healthier.
- The hard benchmark root is `dlm_constV_bigW @ tau=0.05 exal ridge`.
- Broader reruns are not justified until a narrow micro-pilot winner exists.
- The next broad wave should optimize for `zero FAIL`, not universal `PASS`.
- The current active scientific search anchor is `R512`, with `R500` as the previous-anchor
  reference, `R402` as the balanced clean control, and exact `R61` as the runtime control.
- The search space is now small enough that broad family reopening is wasteful, but a broader exact
  full-6 residual-resolution matrix inside the `R512/R500/R402` neighborhood is justified.
- The next overnight program should still use the fixed 6-root harness from Stage 1.
- Full-6 rerun confirmation remains more important than one-pass local ranking.
- The next promoted winner should be chosen from rerun-confirmed exact evidence, not a single
  profile instance.

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

## 5Q) Phase 8 Outcome

Run:

- plan doc:
  `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
- result report:
  `docs/REPORT__qdesn_validation_phase8_smallw_resolution_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase8_smallw_resolution_manifest.yaml`
- run tag:
  `qdesn-phase8-smallw-resolution-20260401a__git-4852ec8`

Outcome:

- the full Phase-8 program completed cleanly:
  `14/14` Stage-1 profiles, `2/2` full-6 confirmations, `0` timeouts, `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- the strongest local winner was `R84_r61_rhs_freeze100_blockpass5`;
- `R84` reduced the focused 5-root screen to:
  - `total_fail_n = 2`
  - `severe_fail_n = 2`
  - `sentinel_fail_n = 0`
- but `R84` then failed the full-6 confirmation:
  - `total_fail_n = 6`
  - `severe_fail_n = 4`
  - `sentinel_fail_n = 2`
- the exact `R61` reference family reran at:
  - `total_fail_n = 5`
  - `severe_fail_n = 4`
  - `sentinel_fail_n = 1`

Interpretation:

- the focused Stage-1 screen is still scientifically useful;
- but local winners cannot be promoted without full-6 confirmation;
- Phase 8 did not produce a new promotable baseline;
- the branch now needs a replication-first decision layer before more local tuning.

## 5R) Phase 9 Direction

Next wave:

- plan doc:
  `docs/PLAN__qdesn_validation_phase9_replication_audit_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase9_replication_audit_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase9_replication_audit.R`

Design choice:

- stop broad local searching for one wave;
- rerun only the still-plausible families on the fixed 6-root harness;
- repeat each family exactly `3` times;
- summarize results at the family level as well as the profile-instance level.

Families included:

- exact `R61` reference family
- exact `R84` rhs-local winner family
- exact `R68` clean ridge-signal family
- exact `R65` stronger ridge-chain family

What Phase 9 explicitly avoids:

- rerunning weak Phase-8 descendants as lead ideas;
- reopening broad local search before replication is understood;
- treating a single lucky profile instance as enough evidence for promotion.

## 5S) Phase 9 Outcome

Run:

- plan doc:
  `docs/PLAN__qdesn_validation_phase9_replication_audit_20260401.md`
- result report:
  `docs/REPORT__qdesn_validation_phase9_replication_audit_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase9_replication_audit_manifest.yaml`
- run tag:
  `qdesn-phase9-replication-audit-20260401a__git-e31ec94`

Outcome:

- the full Phase-9 program completed cleanly:
  `12/12` replicated full-6 profiles, `0` timeouts, `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- the replicated family ordering is now clear enough to guide the next search wave:
  - `r68_ridge_signal`: best overall family signal;
  - `r65_ridge_chain_stepsout`: best runtime-balanced ridge fallback;
  - `r61_stable_anchor`: still useful as a runtime reference, but no longer a clean baseline leader;
  - `r84_rhs_blockpass5`: retired as a lead idea.

Phase-9 family ranking:

| family | median_total_fail_n | median_sentinel_fail_n | min_total_fail_n | zero_sentinel_runs_n | median_runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `r68_ridge_signal` | `4` | `0` | `2` | `2/3` | `1.1174` |
| `r65_ridge_chain_stepsout` | `4` | `0` | `3` | `2/3` | `0.8785` |
| `r61_stable_anchor` | `4` | `1` | `4` | `0/3` | `0.7117` |
| `r84_rhs_blockpass5` | `5` | `2` | `4` | `0/3` | `0.7982` |

Interpretation:

- `R68` is the new active scientific lead because it produced the best replicated sentinel behavior and
  the only replicated `2 FAIL / 0 sentinel FAIL` outcome (`R122`);
- `R65` is worth carrying forward because it preserves the ridge-led improvement direction with much
  lower runtime inflation than `R68`;
- `R61` should now be retained as a runtime reference control, not as the main search anchor;
- `R84` should no longer be used as a lead family.

What the best replicated runs actually improved:

- `R122_r68_rep3` repaired:
  - `dlm_constV_bigW @ tau=0.05 exal ridge` (`FAIL -> WARN`)
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns` (`FAIL -> WARN`)
  - `dlm_constV_smallW @ tau=0.50 exal rhs_ns` (`FAIL -> WARN`)
  - `dlm_constV_bigW @ tau=0.95 al rhs_ns` (`FAIL -> WARN`)
- `R131_r65_rep2` showed the best balanced ridge-chain fallback:
  - `total_fail_n = 3`
  - `sentinel_fail_n = 0`
  - runtime inflation `0.8785`

What still fails:

- the remaining difficult surface is now ridge-led, not rhs-led;
- the most persistent unresolved roots are:
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
  - `dlm_ar1V @ tau=0.95 exal rhs_ns`
- `R68` reduces the ridge-dominant fail set best, but still needs guard-rail stabilization around the rhs side;
- `R65` is more runtime-disciplined, but does not yet match `R68` on best-case fail reduction.

## 5T) Phase 10 Direction

Next wave:

- plan doc:
  `docs/PLAN__qdesn_validation_phase10_replicated_ridge_resolution_20260401.md`
- manifest:
  `config/validation/qdesn_validation_phase10_replicated_ridge_resolution_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase10_replicated_ridge_resolution.R`

Design choice:

- promote the exact `R68` family to the active search anchor for the next overnight wave;
- keep exact `R65` as the balanced ridge fallback control;
- keep exact `R61` as the cheaper runtime reference control;
- stop using `R84` as a lead candidate family;
- search only the remaining live ridge-led space:
  - `R68` ridge-local descendants;
  - `R68` plus mild rhs guard descendants;
  - `R65` balanced descendants that blend ridge and mild rhs guard ideas;
- stage the program:
  - broad 5-root ridge-resolution plus rhs-guard screen;
  - full fixed 6-root confirmation for survivors;
  - exact stability rerun of the confirmation survivors.

What Phase 10 explicitly avoids:

- any new `R84`-style blockpass-5 family as a lead idea;
- replaying QR-only, bridge-only, conditioning-only, or old transformed-sigma families;
- heavy ridge widening (`R67`-style) and other descendants already shown to be weak;
- spending full-6 confirmation compute on every broad candidate before the targeted screen filters them.

## 5U) Phase 10 Outcome

Run:

- plan doc:
  `docs/PLAN__qdesn_validation_phase10_replicated_ridge_resolution_20260401.md`
- result report:
  `docs/REPORT__qdesn_validation_phase10_replicated_ridge_resolution_20260402.md`
- manifest:
  `config/validation/qdesn_validation_phase10_replicated_ridge_resolution_manifest.yaml`
- run tag:
  `qdesn-phase10-ridge-resolution-20260401a__git-227e125`

Outcome:

- the full Phase-10 program completed cleanly:
  `15/15` Stage-1 profiles, `2/2` Stage-2 profiles, `0` timeouts, `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- Stage 1 selected only `R201_r65_balanced_control`;
- Stage 2 then showed that the exact `R68` anchor still outperformed that selected `R65` local winner on the real full-6 harness;
- no candidate advanced out of Stage 2;
- Phase 10 therefore did not produce a promotable new baseline.

Phase-10 decision-quality read:

| view | profile | total_fail_n | sentinel_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---|
| Stage-1 winner | `R201_r65_balanced_control` | `3` | `0` | `0.904` | best reduced-screen local result |
| strongest severe improver | `R222_r68_pass1_chain1000` | `3` | `1` | `1.079` | strong ridge-local science, but sentinel blocked it |
| Stage-2 exact reference | `R200_r68_replicated_anchor` | `4` | `1` | `1.072` | better full-6 result |
| Stage-2 selected survivor | `R201_r65_balanced_control` | `5` | `1` | `0.853` | local win did not transfer |

Interpretation:

- exact `R68` remains the strongest branch-facing reference family;
- exact `R65` remains worth keeping as a challenger control, but not as a promoted replacement;
- the main Phase-10 lesson is now the same as the one emerging in the long static-exAL work:
  reduced-screen winners still need explicit exact-harness transfer proof before promotion.

## 5V) Phase 11 Outcome

Run:

- plan doc:
  `docs/PLAN__qdesn_validation_phase11_exact_fullsix_matrix_20260402.md`
- result report:
  `docs/REPORT__qdesn_validation_phase11_exact_fullsix_matrix_20260403.md`
- manifest:
  `config/validation/qdesn_validation_phase11_exact_fullsix_matrix_manifest.yaml`
- run tag:
  `qdesn-phase11-exact-fullsix-20260402a__git-5b72d20`

Outcome:

- the full Phase-11 program completed cleanly:
  `14/14` Stage-1 profiles, `6/6` Stage-2 reruns, `0` timeouts, `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- Stage 1 again found several viable exact candidates;
- the strongest local Stage-1 winner was `R323_r65_pass1_stepsout_chain1100`;
- Stage 2 then reordered the field and showed that `R312_r68_pass1_chain950` is the best
  rerun-confirmed scientific result;
- no candidate passed the stricter rerun gate, so Phase 11 did not produce a promotable new
  baseline.

Phase-11 decision-quality read:

| view | profile | total_fail_n | sentinel_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---|
| best Stage-1 local winner | `R323_r65_pass1_stepsout_chain1100` | `3` | `1` | `1.072` | strong one-pass local winner |
| best rerun-confirmed scientific result | `R312_r68_pass1_chain950` | `3` | `1` | `1.095` | new provisional scientific lead |
| clean rerun control | `R301_r65_balanced_control` | `4` | `0` | `0.824` | best sentinel-clean control |
| old exact reference | `R300_r68_exact_anchor` | `5` | `1` | `1.105` | now weaker than `R312` |

Interpretation:

- `R312` is the new active scientific search anchor because it beat the old exact `R68` anchor on
  rerun;
- `R301` remains valuable as the clean balanced control;
- `R323` should now be treated as a local-only winner that did not survive rerun confirmation.

## 5W) Phase 12 Outcome

Run:

- result report:
  `docs/REPORT__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- plan doc:
  `docs/PLAN__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- manifest:
  `config/validation/qdesn_validation_phase12_r312_stabilization_matrix_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase12_r312_stabilization_matrix.R`
- run tag:
  `qdesn-phase12-r312-stabilization-20260403a__git-1af9e79`

Outcome:

- the full Phase-12 program completed cleanly:
  `15/15` Stage-1 profiles, `2/2` Stage-2 reruns, `1/1` Stage-3 confirmations, `0` timeouts,
  `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- Stage 1 found two real local winners:
  `R412_r312_softsigma_steps70` and `R421_r312_rhsfreeze100_chain1100`;
- Stage 2 then showed that `R412` is the best practical rerun-confirmed result;
- Stage 3 finally showed that `R412` still regresses under final sentinel confirmation;
- Phase 12 therefore did not produce a promotable new baseline.

Phase-12 decision-quality read:

| view | profile | total_fail_n | sentinel_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---|
| best Stage-1 local result | `R421_r312_rhsfreeze100_chain1100` | `2` | `1` | `1.291` | strongest local scientific improver |
| best Stage-1 practical survivor | `R412_r312_softsigma_steps70` | `3` | `0` | `1.094` | best balanced local winner |
| best rerun-confirmed practical result | `R412_r312_softsigma_steps70` | `3` | `0` | `1.072` | new provisional scientific/practical lead |
| previous anchor | `R400_r312_provisional_anchor` | `3` | `0` | `1.214` | now weaker control |
| clean control | `R402_r65_balanced_control` | `4` | `0` | `0.944` | best stable clean control |

Interpretation:

- `R412` should now replace `R312` as the active search anchor;
- `R421` should be retained as the high-upside rhs reference, not treated as auto-promotable;
- `R422` should not remain a lead family after rerun;
- the wave again confirmed the same promotion lesson seen in the long static-exAL work:
  exact local winners must still beat the reference on rerun and final confirmation before
  promotion.

## 5X) Phase 13 Outcome

Run:

- result report:
  `docs/REPORT__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
- plan doc:
  `docs/PLAN__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
- manifest:
  `config/validation/qdesn_validation_phase13_r412_r421_stability_matrix_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase13_r412_r421_stability_matrix.R`
- run tag:
  `qdesn-phase13-r412-r421-stability-20260403a__git-373aa5f`

Outcome:

- the full Phase-13 program completed cleanly:
  `15/15` Stage-1 profiles, `7/7` Stage-2 reruns, `2/2` Stage-3 confirmations, `0` timeouts,
  `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- Stage 1 found a real local winner in `R510_r412_chain1000`, but rerun confirmation reversed that
  ordering;
- Stage 2 showed that `R512_r412_pass2_chain1000` is the only rerun-confirmed survivor;
- Stage 3 then showed that `R512` beats the prior anchor cleanly with `3 FAIL / 0 sentinel FAIL`
  versus the anchor's `4 FAIL / 1 sentinel FAIL`;
- Phase 13 therefore produced a promotable new baseline.

Phase-13 decision-quality read:

| view | profile | total_fail_n | sentinel_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---|
| final promoted winner | `R512_r412_pass2_chain1000` | `3` | `0` | `1.106` | best final result and new baseline |
| rerun-confirmed winner | `R512_r412_pass2_chain1000` | `3` | `0` | `1.076` | only Stage-2 survivor |
| Stage-1 local winner | `R510_r412_chain1000` | `2` | `0` | `1.046` | did not survive rerun |
| previous anchor | `R500_r412_provisional_anchor` | `4` | `1` | `1.060` | now weaker final reference |
| clean control | `R402_r65_balanced_control` | `5` | `1` | `0.975` | useful benchmark, not competitive |

Interpretation:

- `R512` should now replace `R412` as the active search anchor and promoted baseline;
- `R500` should be retained as the previous-anchor control;
- `R402` should remain the clean balanced control;
- `R421` and the combined `R412 + R421` line should be retired as lead families after rerun;
- the wave again confirmed the core promotion lesson:
  exact Stage-1 winners are not enough; rerun and final sentinel confirmation materially improve
  decision quality.

## 5Y) Phase 14 Outcome

Run:

- result report:
  `docs/REPORT__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
- plan doc:
  `docs/PLAN__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
- manifest:
  `config/validation/qdesn_validation_phase14_r512_residual_resolution_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase14_r512_residual_resolution.R`
- run tag:
  `qdesn-phase14-r512-residual-resolution-20260403a__git-8ef64e1`

Outcome:

- the full Phase-14 program completed cleanly:
  `15/15` Stage-1 profiles, `0` timeouts, `0` runner errors;
- no completed profile introduced finite, domain, collapse, or unhealthy regressions;
- the exact `R512` anchor rerun (`R600`) was the best raw result with `2 FAIL / 1 sentinel FAIL`;
- no candidate advanced because the wave split into two incomplete success modes:
  low-fail profiles with `1` sentinel FAIL and one zero-sentinel geometry clue (`R616`) that still
  had too many total FAILs;
- Phase 14 therefore produced no new baseline, but it did identify the surviving local repair
  ingredients clearly enough to justify one more exact crossover wave.

Phase-14 signal-quality read:

| view | profile | total_fail_n | sentinel_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---|
| best raw rerun | `R600_r512_promoted_anchor` | `2` | `1` | `1.115` | strongest broad repair pattern |
| best ridge rescue | `R612_r512_burn550_chain1100` | `3` | `1` | `1.031` | repaired `bigW ridge`, but not sentinel-clean |
| best rhs hedge | `R622_r512_rhssoft_freeze90` | `3` | `1` | `1.086` | strongest rhs-local hedge |
| only zero-sentinel clue | `R616_r512_softgamma_steps80` | `4` | `0` | `1.138` | useful sentinel clue, not a winner |
| clean balanced control | `R602_r402_balanced_control` | `3` | `1` | `0.890` | best runtime-balanced benchmark |

Interpretation:

- `R512` remains the active promoted baseline;
- `R600`, `R612`, `R622`, and `R616` are now the only local signals worth carrying forward;
- Phase 14 changed the next-step question from “which local axis wins” to “can the surviving local
  signals be combined into a low-fail, zero-sentinel exact winner.”

## 5Z) Phase 15 Outcome

Completed wave:

- plan doc:
  `docs/PLAN__qdesn_validation_phase15_r512_sentinel_crossover_matrix_20260403.md`
- manifest:
  `config/validation/qdesn_validation_phase15_r512_sentinel_crossover_matrix_manifest.yaml`
- thin wrapper:
  `scripts/run_qdesn_validation_phase15_r512_sentinel_crossover_matrix.R`

Final read:

- keep `R512` as the promoted scientific and practical baseline;
- keep `R402` as the clean balanced control and `R700` as the direct anchor control;
- note that `R702_r612_ridge_reference` was the true rerun-confirmed scientific winner of the
  wave, but it failed final residual confirmation by reintroducing a sentinel FAIL;
- record that no candidate beat `R512` cleanly enough for promotion.

What Phase 15 established:

- broad crossover search inside the surviving `R512` ingredients is now exhausted enough;
- the best remaining signal is still ridge-led, not broad-family-led;
- the next step should be final certification, not another exploratory search wave.

## 5ZA) Final Certification Direction

Next step:

- plan doc:
  `docs/PLAN__qdesn_validation_final_r512_certification_20260403.md`
- frozen defaults:
  `config/validation/qdesn_dynamic_family_prior_r512_certification_defaults.yaml`
- orchestrator:
  `scripts/run_qdesn_validation_final_r512_certification.R`

Design choice:

- freeze `R512_r412_pass2_chain1000` as the tuned certification candidate;
- rerun the full dynamic `36`-root matrix once from start to finish;
- compare the rerun against the authoritative dynamic baseline campaign;
- finish the sequence with either:
  - `ACCEPT_R512_AS_CERTIFIED_BASELINE`, or
  - `HOLD_R512_WITH_CAVEATS`.

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
- [x] launch the overnight Phase-8 program
- [x] update the tracker with the Phase-8 outcome

Success intent:

- best case: `0 FAIL` on full-6 confirmation and rerun;
- meaningful win: `1 FAIL` with `0` sentinel FAIL that reproduces;
- minimum win: clear improvement on the two remaining fail roots without guard-rail regression.

### Work Package 7: Phase 9 replicated family audit

Target:

- quantify family-level rerun stability on the fixed 6-root harness before promoting any new baseline;
- decide whether the next repair move should stay rhs-local, ridge-local, or remain baseline-centered.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `docs/PLAN__qdesn_validation_phase9_replication_audit_20260401.md`
- `config/validation/qdesn_validation_phase9_replication_audit_manifest.yaml`
- `scripts/run_qdesn_validation_phase9_replication_audit.R`

Checklist:

- [x] freeze the Phase-8 outcome as a scientific but non-promoting result
- [x] define the still-plausible family set (`R61`, `R84`, `R68`, `R65`)
- [x] add family-level ranking output to the replication runner
- [x] run prepare-only validation on the Phase-9 manifest
- [x] launch the overnight Phase-9 replication audit
- [x] update the tracker with the first Phase-9 health/result checkpoint

Success intent:

- identify the best family by median full-6 fail count, sentinel stability, and runtime;
- promote only a family that is stable across reruns, not just best on one instance.

### Work Package 8: Phase 10 exact ridge resolution

Target:

- test whether a focused local ridge/balanced screen could beat the replicated `R68` family on the
  real branch-facing harness.

Primary outcome:

- complete;
- the local `R65` winner did not survive exact full-6 confirmation;
- exact `R68` remained stronger than the selected `R65` challenger on full-6.

### Work Package 9: Phase 11 exact full-6 matrix

Target:

- search the surviving `R68/R65/R61` neighborhood on the exact full-6 harness from Stage 1 onward;
- rerun survivors before any promotion call.

Primary outcome:

- complete;
- `R312_r68_pass1_chain950` became the new provisional scientific lead;
- `R301_r65_balanced_control` remained the clean rerun control;
- no candidate cleared the rerun promotion gate.

### Work Package 10: Phase 12 `R312` stabilization matrix

Target:

- preserve `R312`'s repaired roots while removing the remaining three-root residual FAIL set;
- do so without reopening dominated families.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- `config/validation/qdesn_validation_phase12_r312_stabilization_matrix_manifest.yaml`
- `scripts/run_qdesn_validation_phase12_r312_stabilization_matrix.R`

Checklist:

- [x] freeze the Phase-11 outcome as a scientific but non-promoting result
- [x] document the `R312` residual fail set and control hierarchy
- [x] define a 3-stage exact full-6 stabilization matrix
- [x] keep the candidate space inside the `R312/R68/R65/R61` neighborhood
- [x] run prepare-only validation on the Phase-12 manifest
- [x] launch the overnight Phase-12 program
- [x] update the tracker with the Phase-12 outcome

Primary outcome:

- complete;
- `R412_r312_softsigma_steps70` became the new provisional scientific/practical lead;
- `R421_r312_rhsfreeze100_chain1100` became the new rhs-local upside reference;
- `R422_r312_blockpass5` did not hold up as a lead family;
- no candidate cleared final sentinel confirmation strongly enough for promotion.

### Work Package 11: Phase 13 `R412/R421` stability matrix

Target:

- stabilize the new `R412` lead while borrowing only the useful rhs-local upside from `R421`;
- do so without reopening retired families or reduced-screen-first logic.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
- `config/validation/qdesn_validation_phase13_r412_r421_stability_matrix_manifest.yaml`
- `scripts/run_qdesn_validation_phase13_r412_r421_stability_matrix.R`

Checklist:

- [x] freeze the Phase-12 outcome as a scientific but non-promoting result
- [x] document the `R412` residual fail set and control hierarchy
- [x] define a 3-stage exact full-6 refinement matrix around `R412 + R421 + R402`
- [x] keep the candidate space inside the `R412/R400/R402/R421` neighborhood
- [x] run prepare-only validation on the Phase-13 manifest
- [x] launch the overnight Phase-13 program
- [x] update the tracker with the final Phase-13 outcome

Primary outcome:

- complete;
- `R512_r412_pass2_chain1000` became the new promoted baseline;
- `R500_r412_provisional_anchor` is now the previous-anchor control;
- `R421` and combined descendants did not hold up as lead families;
- Phase 13 is the first late-stage wave in this sequence to end with a promoted exact full-6 winner.

### Work Package 12: Phase 14 `R512` residual-resolution matrix

Target:

- preserve the two rhs repairs achieved by `R512`;
- resolve the remaining three-root residual fail cluster without reopening dominated families;
- do so with only narrow local ridge/rhs descendants of the promoted `R512` baseline.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
- `docs/PLAN__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
- `config/validation/qdesn_validation_phase14_r512_residual_resolution_manifest.yaml`
- `scripts/run_qdesn_validation_phase14_r512_residual_resolution.R`

Checklist:

- [x] freeze the Phase-13 outcome as a promoted baseline
- [x] document the `R512` residual fail set and control hierarchy
- [x] define a 3-stage exact full-6 residual-resolution matrix around `R512 + R500 + R402`
- [x] keep the candidate space inside the `R512/R500/R402` neighborhood
- [x] run prepare-only validation on the Phase-14 manifest
- [x] launch the overnight Phase-14 program
- [x] update the tracker with the final Phase-14 outcome

Primary outcome:

- complete;
- no candidate advanced beyond Stage 1;
- `R600` remained the strongest broad repair pattern;
- `R612` became the best ridge rescue reference;
- `R622` became the best rhs-local hedge;
- `R616` became the only zero-sentinel geometry clue;
- Phase 14 justified one final crossover wave, not a family reopening.

### Work Package 13: Phase 15 `R512` sentinel-crossover matrix

Target:

- combine the surviving `R600/R612/R622/R616` local signals without reopening dead families;
- find a candidate that preserves low-fail behavior and removes the remaining sentinel failure;
- require rerun-confirmed zero-sentinel behavior before any new promotion call.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase14_r512_residual_resolution_20260403.md`
- `docs/PLAN__qdesn_validation_phase15_r512_sentinel_crossover_matrix_20260403.md`
- `config/validation/qdesn_validation_phase15_r512_sentinel_crossover_matrix_manifest.yaml`
- `scripts/run_qdesn_validation_phase15_r512_sentinel_crossover_matrix.R`

Checklist:

- [x] freeze the Phase-14 outcome as a scientific but non-promoting result
- [x] document the `R600/R612/R622/R616` crossover read and control hierarchy
- [x] define a 3-stage exact full-6 crossover matrix around the surviving `R512` ingredients
- [x] keep the candidate space inside the `R512/R612/R622/R616/R402` neighborhood
- [x] run prepare-only validation on the Phase-15 manifest
- [x] launch the overnight Phase-15 program
- [x] update the tracker with the final Phase-15 outcome

Primary outcome:

- complete;
- `R702_r612_ridge_reference` was the only Stage-2 survivor and the best local signal of the wave;
- `R702` failed final residual confirmation by reintroducing a sentinel FAIL;
- `R512` remains the active promoted baseline;
- Phase 15 is a non-promoting exploratory closeout wave.

### Work Package 14: Final frozen-`R512` certification rerun

Target:

- stop exploratory tuning cleanly;
- rerun the full dynamic `36`-root matrix with frozen `R512`;
- compare the rerun against the authoritative dynamic baseline campaign;
- issue a single final certification recommendation.

Primary artifacts:

- `docs/REPORT__qdesn_validation_phase15_r512_sentinel_crossover_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_final_r512_certification_20260403.md`
- `config/validation/qdesn_dynamic_family_prior_r512_certification_defaults.yaml`
- `scripts/run_qdesn_validation_final_r512_certification.R`

Checklist:

- [x] close Phase 15 as a completed non-promoting wave
- [x] freeze `R512` as the certification candidate
- [x] define the final certification acceptance criteria
- [x] add the frozen certification defaults
- [x] add the final certification orchestrator
- [x] run prepare-only validation on the certification workflow
- [ ] commit and push the certification workflow
- [ ] launch the final full certification rerun
- [ ] close the full validation cycle with the final recommendation

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

- `docs/REPORT__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
- `docs/REPORT__qdesn_validation_phase11_exact_fullsix_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase11_exact_fullsix_matrix_20260402.md`
- `docs/REPORT__qdesn_validation_phase10_replicated_ridge_resolution_20260402.md`
- `docs/REPORT__qdesn_validation_phase9_replication_audit_20260401.md`
- `docs/PLAN__qdesn_validation_phase10_replicated_ridge_resolution_20260401.md`
- `docs/REPORT__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `docs/PLAN__qdesn_validation_phase9_replication_audit_20260401.md`
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
- `docs/PLAN__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`
- `docs/REPORT__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase12_r312_stabilization_matrix_20260403.md`
- `docs/REPORT__qdesn_validation_phase11_exact_fullsix_matrix_20260403.md`
- `docs/PLAN__qdesn_validation_phase11_exact_fullsix_matrix_20260402.md`
- `docs/REPORT__qdesn_validation_phase10_replicated_ridge_resolution_20260402.md`
- `docs/PLAN__qdesn_validation_phase10_replicated_ridge_resolution_20260401.md`
- `docs/REPORT__qdesn_validation_phase9_replication_audit_20260401.md`
- `docs/PLAN__qdesn_validation_phase9_replication_audit_20260401.md`
- `docs/REPORT__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `docs/PLAN__qdesn_validation_phase8_smallw_resolution_20260401.md`
- `docs/PLAN__qdesn_validation_phase7_r44_refinement_20260401.md`
- `docs/REPORT__qdesn_validation_phase7_r44_refinement_20260401.md`

## 12) Current Recommended Next Move

Do not reopen broad family searching outside the exact `R412/R400/R402/R421` neighborhood.

The next highest-signal step is:

1. use `R412` as the provisional scientific search anchor in every stage;
2. keep `R400` as the previous-anchor reference control;
3. keep `R402` as the balanced clean control;
4. keep `R421` as the high-upside rhs reference control;
5. run the exact full-6 refinement matrix defined in
   `docs/PLAN__qdesn_validation_phase13_r412_r421_stability_matrix_20260403.md`;
6. search only the remaining live space:
   - `R412` stability descendants,
   - trimmed `R421` rhs descendants,
   - a very small combined `R412 + R421` neighborhood,
   - one narrow `R402` hedge,
   - no reopened dead families;
7. rerun selected survivors before carrying any new winner forward;
8. require `0` sentinel FAIL only at the final confirmation stage, not before.
