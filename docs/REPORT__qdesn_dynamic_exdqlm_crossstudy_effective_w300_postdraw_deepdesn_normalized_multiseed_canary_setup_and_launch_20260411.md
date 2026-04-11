# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Normalized Multiseed Canary Setup And Launch

Date: 2026-04-11
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Launch the first live execution run of the new normalized multiseed deep-DESN surface on a small
representative canary before any full relaunch.

This canary exists to validate:

- root-level 4-seed MCMC execution
- seed winner selection and artifact promotion
- heavy non-winner artifact pruning
- normalized posterior-draw / burn-in contract under live compute
- wrapper behavior from committed branch state

## 2) Launch Inputs

Code state:

- implementation commit:
  - `fd274f0`
  - `validation: implement normalized multiseed deepdesn relaunch`

Defaults:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_defaults.yaml`

Canary grid:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_grid.csv`

Wrapper:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`

## 3) Pre-Launch Validation

Validated before launch:

- package load:
  - passes
- helper checks:
  - passes
- staged-source reuse:
  - passes
- canary `prepare-only`:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-preflight-20260411`
  - passes
- full `prepare-only`:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-full-preflight-20260411`
  - passes
- wrapper path-resolution proof from a different cwd:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-cwdproof-20260411`
  - passes

## 4) Live Launch

Live canary run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-20260411-181806__git-fd274f0`
- detached session:
  - `qdesn_dynx_0411_181807`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-20260411-181806__git-fd274f0/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-20260411-181806__git-fd274f0/launch/launcher_stdout.log`

## 5) Opening Health Snapshot

Snapshot time:

- `2026-04-11 18:18:25 EDT`

Initial health read:

- selected roots:
  - `6`
- materialized roots:
  - `1 / 6`
- root status:
  - `1 RUNNING`
  - `0 SUCCESS`
  - `0 FAIL`
- campaign summary tables:
  - not written yet
- MCMC seed-selection tables:
  - not written yet
- root execution errors:
  - `0`

Current opening location:

- first root:
  - `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_500__qdesn_ridge`
- first method observed in launcher log:
  - `exal | vb`

Interpretation:

- launch is clean
- detached session is live
- the canary is compute-active
- no execution faults are visible in the opening state

## 6) Expected Decision Rule

If the canary completes cleanly and confirms:

- seed selection tables write correctly
- selected-seed canonical fit directories are readable by existing downstream collectors
- pruning behaves as expected
- storage growth is controlled

then the next step should be the full normalized multiseed relaunch from the same committed code
state pattern.
