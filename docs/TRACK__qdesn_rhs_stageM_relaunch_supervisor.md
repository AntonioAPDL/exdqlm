# TRACK: QDESN RHS Stage-M Supervised Relaunch

Date: 2026-03-24  
Branch: `feature/qdesn-mcmc-alternative`

## Purpose

Recover the stalled Stage-M repair wave in a reproducible way:
1. preserve the stalled run as immutable forensic evidence;
2. launch a fresh Stage-M wave under a restart-capable supervisor;
3. require clean completion artifacts before any MR2/MR3 decision.

## Baseline (Stalled)

- stalled run tag: `stageMrepair-debug-20260323-201446`
- known state at freeze time:
  - MR1 complete (`mr1_profile_matrix.csv` present)
  - MR1 winner set (`mr1_winner.json` present)
  - MR2 partial (no `campaign_completed.json`)
  - MR3 not started
  - no wave-level `stageM_repair_manifest.json`

## Supervisor

- launcher script:
  - `scripts/run_qdesn_rhs_stageM_repair_supervisor.sh`
- runner script:
  - `scripts/run_qdesn_rhs_stageM_repair_wave.R`
- manifest:
  - `config/validation/qdesn_rhs_stageM_repair_manifest.yaml`

## Required Completion Artifacts

The run is considered complete only when all are present under the new run tag:
1. `manifest/stageM_repair_manifest.json`
2. `tables/mr2_canary_summary.csv`
3. `tables/mr3_full_summary.csv` (if MR2 passes and MR3 is attempted)

## Notes

- This workflow intentionally avoids mutating the stalled run tree.
- Promotion decisions remain blocked until a supervised run writes the completion artifacts.

## Execution Metadata (Current Relaunch)

- stalled run frozen under:
  - `reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-debug-20260323-201446/forensics_stalled_20260324-162354/`
- supervised relaunch run tag:
  - `stageMrepair-supervised-20260324-162405__git-88c0369`
- tmux session:
  - `stageMrepair-super-20260324-162405`
- launch log:
  - `reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-162405__git-88c0369/logs/supervisor_launch.log`
- supervisor status csv:
  - `reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-162405__git-88c0369/logs/supervisor_attempt_status.csv`
