# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Row-Faithful Multiseed Setup And Launch

Date: 2026-04-12
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Launch the corrected full row-faithful multiseed replay from committed state after the corrected
implementation, materialization, and committed-state preflights all passed.

This launch follows the corrected rule:

- preserve each row's accepted exact spec
- standardize only burn / kept chain / posterior export size / 4-seed MCMC replay

## 2) Launch Inputs

Code state:

- implementation commit:
  - `7144048`
  - `validation: implement row-faithful deepdesn multiseed replay`

Corrected plan and implementation report:

- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_20260412.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_implementation_and_preflight_20260412.md`

Resolved replay inputs:

- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_manifest.yaml`
- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_defaults.yaml`
- inventory:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_inventory.csv`

Wrapper:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation.R`

## 3) Pre-Launch Validation

Completed before launch:

- `pkgload::load_all(...)`
- accepted-chain replay assertions
- outside-repo materializer invocation
- committed-state canary preflight:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-canary-preflight-20260412`
- committed-state full preflight:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-full-preflight-20260412`

## 4) Live Launch

Detached full replay:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-20260412-124648__git-7144048`
- detached session:
  - `qdesn_dynx_0412_124649`

Launch artifacts:

- launcher session:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-20260412-124648__git-7144048/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-20260412-124648__git-7144048/launch/launcher_stdout.log`

## 5) Initial Health Snapshot

Snapshot taken immediately after launch:

- timestamp:
  - `2026-04-12 12:47 EDT`
- selected roots:
  - `36`
- materialized roots:
  - `1 / 36`
- root status:
  - `1 RUNNING`
  - `0 SUCCESS`
  - `0 FAIL`
- campaign summary tables:
  - not yet written
- launcher session:
  - live

Initial interpretation:

- the corrected replay started cleanly
- the detached session is alive
- the first root is running
- no execution errors are visible yet
