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

## 3) Read These First

If someone needs the shortest path to the current findings, read these in order:

1. `docs/PLAN__qdesn_validation_phase2_20260331.md`
2. `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`
3. `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
4. `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
5. `reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f/summary/phase2_audit_summary.md`
6. `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/summary/repair_wave2_results.md`
7. `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`
8. `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`

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

### Main takeaways

- This is a kernel-quality problem, not an orchestration problem.
- The primary pain point is shared `exal` core mixing, especially around `gamma`.
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

### Area A: shared `exal` core refresh

Highest-confidence repair area.

Best-supported direction from the completed screen:

- one extra core pass;
- gamma-focused sharpening;
- moderate runtime overhead;
- no broad chain-length inflation.

Reference screen candidates:

- `X10_core_gamma_focus_pass1`
- `X3_core_pass1_sharp`

### Area B: `rhs_ns` residual warmup / initialization

Secondary repair area.

Most promising direction from the completed screen:

- moderate `freeze_tau_burnin_iters`;
- multistart pilot screening.

Reference screen candidate:

- `X8_rhsns_freeze60_multistart3`

### Area C: design-conditioning audit on hard roots

Supporting analysis area.

Reason to include:

- the pain is concentrated in `tiny_d1_n8`;
- even strong sampler tuning leaves one ridge hard root behind;
- we should verify whether X scaling / conditioning is amplifying the kernel issue.

This is not the first code patch, but it is a worthwhile sidecar diagnostic.

### Area D: structural kernel redesign

Escalation area only if Areas A and B fail.

Trigger:

- two serious shared-core candidates fail to improve the common hard root enough;
- or a candidate only trades one fail cluster for another.

## 7) Repair Strategy

### Work Package 0: Evidence freeze and discipline

Checklist:

- [x] freeze the completed closeout findings
- [x] freeze the completed overnight kernel screen
- [x] separate the qdesn blocker map from the unrelated GIG propagation work
- [ ] keep this tracker updated after every decision-changing change

Rules:

- do not launch broad validation reruns yet;
- do not compare across changing root sets;
- always include the anchor baseline in narrow reruns;
- always preserve run tags and manifests.

### Work Package 1: Implement candidate A only

Target:

- shared `exal` core repair based on the `X10` signal

Code files:

- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`

Checklist:

- [x] implement one shared-core structural candidate
- [x] keep the change minimal and attributable
- [x] avoid mixing in `rhs_ns`-only changes here
- [x] keep the candidate off package defaults unless it proves itself on validation

Success intent:

- improve both `exal + ridge` and `exal + rhs_ns`
- no chain-length inflation as the main mechanism

### Work Package 2: Narrow rerun on the fixed 6-root harness

Scope:

- anchor baseline
- candidate A only

Checklist:

- [x] implement and run the staged canary gate first
- [x] capture root transitions, diag deltas, and runtime inflation
- [x] compare against the same baseline used by the completed screen
- [ ] advance the new candidate to the severe quartet
- [ ] advance the new candidate to the full 6-root harness

Hard gates:

- no new finite/domain failures
- no collapse regressions
- median runtime inflation `<= 0.50`
- severe fail count below `3`
- visible improvement on `dlm_constV_bigW @ tau=0.05 exal ridge`

### Work Package 3: Immediate alternate if candidate A is mixed

Scope:

- shared-core alternate only

Candidate:

- `X3`-style alternate

Checklist:

- [x] launch only if candidate A misses key severe roots
- [x] keep the comparison apples-to-apples on the same 6 roots
- [x] do not move to longer-chain profiles before this comparison is complete

### Work Package 4: Residual `rhs_ns` overlay

Scope:

- winning shared-core candidate + `X8` residual layer

Checklist:

- [x] add moderate tau freeze
- [x] add multistart pilot screening
- [x] test only after the shared-core winner is known
- [x] record that the overlay helped only one sentinel and still failed Gate B

Success intent:

- clean the `al + rhs_ns` sentinel
- improve residual `rhs_ns` severe rows without degrading the shared-core gains

### Work Package 5: Broader validation only after a narrow winner exists

Checklist:

- [ ] rerun refreshed closeout micro-pilot
- [ ] rerun dynamic family/prior baseline only after the micro-pilot holds
- [ ] regenerate closeout only after the dynamic baseline is fresh

This is the first point where branch-level re-closeout becomes worth the compute.

## 8) Stop Conditions

Stop narrow tuning and escalate to structural redesign if any of these happen:

- the common hard root remains `FAIL` after two serious shared-core candidates;
- a candidate improves one cluster but introduces new finite/domain/collapse issues;
- a candidate only wins by chain-length inflation close to the rejected `X2/X4/X9` regime;
- the `rhs_ns` overlay helps sentinels but leaves the shared-core ridge hard case unchanged.

## 9) Debugging and Documentation Standards

Every future candidate should satisfy these standards:

- use a unique run tag;
- preserve the fixed 6-root harness;
- record exact parameter changes from defaults;
- record root-level `FAIL -> WARN/PASS` transitions;
- record runtime inflation;
- record `ESS`, `Geweke`, and `half_drift` deltas;
- update this tracker with the outcome before moving to the next candidate;
- keep code changes attributable to a single hypothesis whenever possible.

## 10) What Not To Do

- do not rerun the full branch validation ladder before a narrow winner exists;
- do not spend more time on pure chain-length inflation as the first move;
- do not treat this as a purely `rhs_ns`-only repair problem;
- do not mix multiple new hypotheses into one candidate patch;
- do not use the old legacy `exdqlmMCMC()` path as the truth source for qdesn blocker resolution.

## 11) Main Docs To Watch Going Forward

### Main findings and takeaways

- `docs/PLAN__qdesn_validation_phase2_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave1_20260331.md`
- `docs/REPORT__qdesn_validation_repair_wave2_20260331.md`
- `docs/REVIEW__qdesn_exal_kernel_next_steps_20260331.md`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/summary/phase01_summary.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/summary/screen_results.md`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/summary/repair_wave2_results.md`

### Root-level evidence

- `reports/qdesn_mcmc_validation/finalization_closeout-rhsfixrelaunch-20260329b__git-6ac4727/tables/phase01_mcmc_fail_forensics.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X10_core_gamma_focus_pass1.csv`
- `reports/qdesn_mcmc_validation/exal_kernel_screen/exal-kernel-screen-overnight-20260330c__git-412b379/tables/phase35_transitions_X8_rhsns_freeze60_multistart3.csv`
- `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave1/qdesn-validation-repair-wave1-20260331__git-59e0e2a/tables/phase35_transitions_R3_x10_plus_x8_rhsns_overlay.csv`

### Operational roadmap

- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/PLAN__qdesn_validation_phase2_20260331.md`
- `docs/REPORT__qdesn_validation_phase2_audit_20260331.md`

## 12) Current Recommended Next Move

Do not promote `X10`, `X3`, or the `X8` overlay into package defaults from the current evidence.

The next highest-signal step is:

1. keep the repair-wave scaffolding and legacy anchor as the evaluation harness;
2. treat the `gamma_sigma_gamma` bridge candidate as tested and rejected for promotion;
3. implement the next candidate from a new family, not another small bridge/width reshuffle;
4. prioritize either:
   - a more substantive shared-core reparameterization / blocked move, or
   - a readout conditioning / preconditioning repair targeted at `tiny_d1_n8`;
5. validate that next candidate on the hard ridge canary first;
6. only if the canary improves materially, move to the severe quartet and then the full 6-root harness.
