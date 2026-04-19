# PLAN: QDESN Tau050 Remaining Hard-Fail Rescue Relaunch

Date: 2026-04-19  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Decision Context

This plan follows the completed latent-`s` crash-only rerun of the original
`23` hard numerical MCMC failures from the April 16, 2026 `tau050` source
campaign.

Authoritative source campaign:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674`

Completed `sfreeze` rerun tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_sfreeze-20260419-031755__git-e44a56a`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_sfreeze-20260419-031810__git-e44a56a`

Primary postmortem note:

- `docs/REPORT__qdesn_tau050_failed_mcmc_sfreeze_postmortem_20260419.md`

Reproducible remaining hard-fail manifests:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv`

## 2) What The Evidence Says

The latent-`s` freeze direction was useful but incomplete:

| Surface | Total | SUCCESS | FAIL | PASS/WARN acceptable |
|---|---:|---:|---:|---:|
| AL | 9 | 2 | 7 | 2 |
| EXAL | 14 | 6 | 8 | 3 |
| Overall | 23 | 8 | 15 | 5 |

Most important structural findings:

1. The unresolved hard-crash surface is now the `15` remaining hard `FAIL`
   cases only.
2. Every remaining hard failure is now on `fit_size = 5000`.
3. The dominant failure family is unchanged:
   - `QDESN_LATENT_V_FAILURE_JSON=...`
   - `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`
4. The remaining hard failures are **not** mainly warmup-window failures:
   - `5 / 15` in `burn`
   - `10 / 15` in `keep`
   - only `1 / 15` while `latent_v_warmup_active = TRUE`
5. `rhs_ns` remains materially weaker than `ridge`:
   - `rhs_ns: 10 FAIL, 3 SUCCESS, 0 PASS/WARN`
   - `ridge: 5 FAIL, 5 SUCCESS, 5 PASS/WARN`

This means the next relaunch should **not** be another “more warmup only”
wave. The remaining crash surface is now mostly a post-thaw latent-`v`
instability problem.

## 3) Recommended Next Lever

Use a **bounded latent-`v` rescue relaunch** on the exact remaining `15`
hard-fail cases.

Reasoning:

- the crash event itself is still latent `v`
- the repo already supports a direct latent-`v` rescue path in the MCMC engine
- the current `sfreeze` results imply that broader latent warmup helped reduce
  incidence, but did not remove the post-thaw failure event
- the next rational step is therefore to intervene at the failure event itself
  instead of only moving the warmup boundary again

The recommended next wave is:

- **keep** the full current `sfreeze` baseline:
  - strengthened VB tau freeze
  - strengthened MCMC tau freeze
  - `sigmagam` warmup/freeze
  - latent-`v` warmup
  - latent-`s` freeze
- **add** bounded latent-`v` rescue
- **do not** broaden to the earlier `23` again
- **do not** broaden to the `SUCCESS` but signoff-`FAIL` cases yet

## 4) Proposed Rescue Spec

Recommended initial rescue contract:

```yaml
pipeline:
  inference:
    mcmc:
      latent_v:
        rescue_on_invalid: true
        rescue_strategy: previous_state
        rescue_max_consecutive: 1
        rescue_burn_only: false
        rescue_force_retry_next_iter: true
```

Interpretation:

- if a latent-`v` draw becomes invalid, do not hard-fail immediately
- carry forward the previous valid latent-`v` state once
- mark the iteration as rescued
- force a real retry on the next iteration
- if the problem repeats past the allowed rescue budget, then fail normally

Why this specific contract:

- `previous_state` is already the supported strategy in package code
- `rescue_burn_only = false` is necessary because most remaining failures are in
  the `keep` phase
- `rescue_max_consecutive = 1` keeps the intervention conservative and easier
  to interpret scientifically

## 5) What Not To Do Next

The next wave should **not** primarily do any of the following:

1. **Do not** only make warmup windows longer.
   The failure timing already shows this is not mainly a warmup-window problem.

2. **Do not** immediately rerun all `23` original crashes.
   The `8` cases that now complete should stay separated from the unresolved
   `15` hard-fail surface.

3. **Do not** immediately reopen the `PASS/WARN` source-run surface.
   The user-acceptable source-run surface is preserved and should remain
   untouched for now.

4. **Do not** jump straight to a broad kernel redesign before the bounded
   rescue test.
   The rescue lever is narrower, cheaper, and directly tied to the failing
   event.

## 6) Exact Relaunch Surface

Use the checked-in remaining hard-fail manifests only:

- AL: `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_al_grid.csv`
- EXAL: `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_remaining_hard_fail_exal_grid.csv`

Counts:

- AL remaining hard-fail roots: `7`
- EXAL remaining hard-fail roots: `8`
- total remaining hard-fail roots: `15`

Priority pockets inside that surface:

1. `fit_size = 5000` only
2. `tau = 0.25` and `tau = 0.50`
3. `gausmix` and `laplace`
4. `rhs_ns`

## 7) Required Code And Documentation Work Before Relaunch

### A. Confirm and preserve rescue config wiring

Primary files:

- `R/exal_inference_config.R`
- `R/exal_mcmc_fit.R`

Checklist:

- verify latent-`v` rescue normalization remains stable
- verify current defaults do **not** silently change non-rescue study surfaces
- keep rescue behavior off by default at package level
- enable it only through a dedicated relaunch config

### B. Improve failed-fit persistence

Primary file:

- `R/qdesn_mcmc_validation.R`

Checklist:

- make sure failed fit summaries retain `mcmc_failure_*` fields when present
- ensure root-level health summaries preserve the latent failure payload
- reduce dependence on manual log scraping for the next postmortem

This is important because the current postmortem still depended on scraping
`pipeline_stdout.log` for the persisted latent-`v` JSON.

### C. Add a dedicated rescue defaults file

Recommended new config surface:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_rescue_defaults.yaml`

Design rule:

- clone the stable `sfreeze` relaunch surface
- add latent-`v` rescue explicitly
- do not mutate the existing `sfreeze` defaults file in place

### D. Add a reproducible materializer test gate

Existing relevant tests:

- `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-relaunch.R`
- `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-sfreeze-config.R`
- `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-sfreeze-postmortem.R`

Recommended additions:

- a rescue-config test that confirms the dedicated rescue defaults file resolves
  the intended latent-`v` rescue fields
- a validation-export test confirming failed summaries persist the
  `mcmc_failure_*` payload

## 8) Recommended Launch Order

### Phase 1: code + test completion

Checklist:

- [ ] finalize rescue config defaults
- [ ] finalize failed-fit persistence fix
- [ ] add/extend targeted tests
- [ ] pass focused test battery

### Phase 2: prepare-only

Checklist:

- [ ] prepare-only AL remaining-hard-fail rescue wave
- [ ] prepare-only EXAL remaining-hard-fail rescue wave
- [ ] confirm generated fit requests contain rescue controls
- [ ] confirm run tags and manifests are documented

### Phase 3: canary

Use a small canary before the full `15`.

Recommended canary composition:

- at least one AL remaining hard-fail root
- at least one EXAL remaining hard-fail root
- include `gausmix` or `laplace`
- prioritize `tau = 0.50`
- include at least one `rhs_ns` root

Checklist:

- [ ] launch rescue canary
- [ ] confirm no infrastructure contamination
- [ ] confirm failed-fit summaries retain `mcmc_failure_*`
- [ ] inspect whether invalid latent-`v` draws are rescued instead of hard-failing
- [ ] inspect whether rescued cases remain scientifically usable

### Phase 4: full remaining-hard-fail relaunch

Only proceed if the canary is scientifically interpretable and does not show a
clear regression.

Checklist:

- [ ] launch AL remaining-hard-fail rescue wave
- [ ] launch EXAL remaining-hard-fail rescue wave
- [ ] monitor by root manifest and persisted failure payload
- [ ] write full postmortem after terminal completion

## 9) Success Criteria

Primary success criteria:

- reduce the remaining hard-fail count below `15`
- recover more than the current `5 / 23` acceptable `PASS/WARN` cases from the
  `sfreeze` wave
- demonstrate that hard failures are being converted into either:
  - `SUCCESS + PASS/WARN`, or
  - `SUCCESS + interpretable diagnostics`, instead of terminal hard crash

Secondary success criteria:

- failed-fit summaries now persist machine-readable `mcmc_failure_*` context
- the relaunch remains storage-stable and reproducible
- AL and EXAL both remain interpretable without contamination from unrelated
  infrastructure failures

## 10) Decision Recommendation

The next relaunch should be:

- **narrow**: exact remaining `15` hard failures only
- **coherent**: keep the proven `sfreeze` baseline intact
- **targeted**: add bounded latent-`v` rescue
- **instrumented**: improve failed-fit persistence before launch
- **staged**: prepare-only, then canary, then full remaining-hard-fail wave

This is the most evidence-aligned next step because it responds directly to the
actual current failure pattern:

- still latent-`v`
- mostly after thaw
- concentrated in long-window hard cases
- no longer well explained by “needs more warmup” alone
