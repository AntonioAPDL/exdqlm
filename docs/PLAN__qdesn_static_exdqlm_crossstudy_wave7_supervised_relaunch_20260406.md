# PLAN: QDESN Static exdqlm Cross-Study Wave 7 Supervised Relaunch

Date: 2026-04-06  
Branch: `feature/qdesn-mcmc-alternative`

## 1) Objective

Recover the stalled residual-closure program without reopening solved surfaces and without forcing a
new generic tuning search.

Wave 7 keeps:

- the shared baseline as the default global baseline;
- the promoted local winners already justified by completed evidence;
- the remaining residual scientific scope only.

Wave 7 changes:

- the operational launch mode;
- health visibility of the launcher;
- the run root, so the supervised relaunch is cleanly separated from the orphaned Wave-6 attempt.

## 2) Root-cause-informed design

Root cause:

- Waves 5 and 6 both produced valid partial science and then lost the top-level runner;
- this is treated as a supervision failure, not a new model-family failure.

Operational fix:

- launch the residual wave through a detached no-TTY-safe launcher;
- write launcher metadata under `launch/launcher_session.json`;
- route launcher stdout to `launch/launcher_stdout.log`;
- extend healthcheck so it reports whether the recorded launcher pid/session is alive.

## 3) Scientific scope

Wave 7 keeps the post-`H510` residual scope exactly where it still matters.

Residual debt entering Wave 7:

- `37` promoted fit FAIL rows;
- `33` affected roots;
- `3` unresolved root-status FAIL roots, all rhs `tt=1000` hard roots.

Stage plan:

1. `S1_ridge_tt1000_remaining_ess_plus_ridge_hardroots`
   - sourced control:
     - `H510_ridge_tt1000_local_control`
   - challengers:
     - `J530_ridge_tt1000_g530_hybrid_chain1600_retry`
     - `J540_ridge_tt1000_control_chain1500`
   - root count:
     - `7`
2. `S2_rhs_tt100_remaining_mcmc`
   - sourced control:
     - `F610_rhs_tt100_conservative_block`
   - challengers:
     - `J620_rhs_tt100_hybrid_chain1250`
     - `J630_rhs_tt100_drift_guard_plus`
   - root count:
     - `12`
3. `S3_rhs_tt1000_remaining_mcmc_plus_rhs_hardroots`
   - sourced control:
     - `F640_rhs_tt1000_chain1200`
   - challengers:
     - `J650_rhs_tt1000_hybrid_block_chain1400`
     - `J660_rhs_tt1000_chain1600_focus`
   - root count:
     - `17`

Total Wave-7 unique target roots:

- `36`

Total challenger root-campaigns:

- `72`

## 4) Exclusions

Wave 7 explicitly does not:

- rerun the full `72`-root source surface;
- rerun clearly losing completed profiles like `H520`;
- search for one universal profile to solve every remaining slice;
- promote any partial profile.

## 5) Success criteria

Wave 7 is successful if it:

1. runs under durable detached supervision without orphaning the launcher;
2. resolves the long-horizon ridge Stage-1 decision cleanly;
3. completes the two rhs residual stages on the remaining fail surface only;
4. reduces remaining FAIL rows while preserving current root-success coverage.
