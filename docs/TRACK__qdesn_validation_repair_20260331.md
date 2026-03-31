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

- the main blocker is a shared `exal` MCMC chain-quality problem in the QDESN static readout path;
- this is most visible on the `tiny_d1_n8` reservoir profile;
- the failure is not primarily a `rhs_ns`-only problem;
- the failure is not primarily a numerical stability problem;
- longer chains alone are not the right first response.

Operational status:

- relaunch infrastructure has already been proven;
- the overnight kernel screen completed cleanly (`12/12` profiles completed);
- current branch package hygiene also includes the separate GIG propagation fix, but that fix does not replace the QDESN blocker analysis because QDESN MCMC uses `qdesn_fit_mcmc()` -> `exal_mcmc_fit()`.
- repair wave 1 on current `HEAD` completed cleanly (`4/4` profiles, `0` operational failures), but no candidate passed Gate B or reduced the severe fail set.
- repair wave 2 completed cleanly at the canary stage, but the new structural bridge candidate failed the canary gate and did not advance to the severe quartet.
- repair wave 3 completed cleanly at the canary stage; diagonal conditioning was effectively inactive on the hard canary and failed immediately.
- repair wave 4 completed cleanly at the canary stage; QR whitening activated exactly as intended and fixed the working-space condition number, but still failed the canary because drift worsened too much.

## 3) Read These First

If someone needs the shortest path to the current findings, read these in order:

1. `docs/PLAN__qdesn_validation_phase3_20260331.md`
2. `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
3. `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
4. `docs/REPORT__qdesn_validation_repair_wave4_20260331.md`
5. `docs/REPORT__qdesn_validation_repair_wave3_20260331.md`
6. `docs/PLAN__qdesn_validation_phase3_family_b_screen_20260331.md`
7. `docs/PLAN__qdesn_validation_phase2_20260331.md`
8. `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
9. `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`
10. `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave4/qdesn-validation-repair-wave4-20260331a__precommit/summary/repair_wave3_results.md`
11. `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`
12. `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`

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
- Even with QR whitening, the hard canary still failed because:
  `ESS` fell slightly (`6.25 -> 5.49`) and `half_drift` worsened materially
  (`0.53 -> 1.08`), despite a large `Geweke` improvement (`10.74 -> 0.87`).

### Main takeaways

- This is a kernel-quality problem, not an orchestration problem.
- The primary pain point is shared `exal` core mixing, especially around `gamma`.
- Conditioning is a real lever for geometry, but conditioning alone is not enough to close the hard canary.
- `rhs_ns` tau-path behavior is secondary and should be repaired after the core is healthier.
- The hard benchmark root is `dlm_constV_bigW @ tau=0.05 exal ridge`.
- Broader reruns are not justified until a narrow micro-pilot winner exists.

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
- the canary still worsened, but the more important lesson is that the first conditioning family did not actually change the working geometry;
- that justified escalating within the conditioning family to a basis-level transform rather than spending any compute on quartet/full-six reruns.

## 5E) Repair Wave 4 Outcome

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

## 5B) Phase 2 Audit Outcome

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

### Area B: blocked / reparameterized shared-core kernel

Current highest-priority repair area.

Why it is now first:

- the bridge family was too local a change;
- the conditioning family was real but insufficient;
- the hard canary still points to shared-core chain dynamics under stressed geometry.

Most plausible next directions:

- blocked `gamma/sigma` move rather than purely sequential local refreshes;
- a more explicit reparameterization that stabilizes drift without giving back all ESS;
- an implementation that can optionally reuse the QR-whitened work space without changing user-facing output scale.

### Area C: residual `rhs_ns` warmup / initialization

Secondary repair area.

Use only after Area B produces a narrow winner.

Why it remains secondary:

- the hard canary is `exal + ridge`;
- the strongest recent failures are still shared-core, not prior-specific.

### Area D: branch revalidation

Deferred area.

Trigger:

- only after a new narrow winner clears the canary, the severe quartet, and the fixed 6-root harness.

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
- `docs/PLAN__qdesn_validation_phase3_20260331.md`
- `docs/PLAN__qdesn_validation_phase2_20260331.md`
- `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`

## 12) Current Recommended Next Move

Do not promote the bridge family, diagonal conditioning, or QR whitening into package defaults from the current evidence.

The next highest-signal step is:

1. keep the repair-wave scaffolding and legacy anchor as the evaluation harness;
2. treat the bridge family and the standalone conditioning family as tested and rejected for promotion;
3. run the broad Family-B transformed-sigma screen defined in
   `docs/PLAN__qdesn_validation_phase3_family_b_screen_20260331.md`;
4. use conditioning only as an optional supporting mechanism, not the primary idea;
5. advance only the best canary survivors to the severe quartet and full 6-root harness;
6. use the resulting best Family-B candidate as the decision point for whether a deeper blocked redesign is still required.
