# REPORT: QDESN Static exdqlm Cross-Study Wave 6 Root Cause and Supervised Relaunch

Date: 2026-04-06  
Branch: `feature/qdesn-mcmc-alternative`

## 1) What happened

Wave 6 did not fail because the remaining ridge `tt=1000` science became invalid.

The evidence points instead to an operational launcher/supervision failure:

- Wave 6 wrote valid partial Stage-1 science under `J530`;
- `6 / 7` Stage-1 roots reached completed root-level signoff successfully;
- the seventh root stopped after `vb_exal` and after writing `mcmc_exal/fit_request.json`;
- the top-level Wave-6 runner process disappeared;
- the runner ledger stayed stale at `RUNNING`;
- no Wave-6 master or worker process remained alive after the stall.

This is the same failure shape already seen in Wave 5:

- useful partial science was produced;
- the active worker batch was left half-open;
- the parent launcher/reporting state was never finalized.

## 2) Main root cause

The main root cause is now assessed as:

> the residual-wave runner was launched from a transient interactive command context without a
> durable detached supervisor, so the wave process could disappear while the on-disk ledger still
> showed `RUNNING`.

Why this interpretation is stronger than a model-level failure diagnosis:

- completed Wave-5 and Wave-6 roots show the model code can finish the same slice cleanly;
- the incomplete Wave-6 root failed at the orchestration boundary, not after a documented model
  exception;
- `J530` produced `25 / 25` execution-`SUCCESS` fit rows before the run died;
- all current partial FAIL rows were MCMC signoff-quality rows, not root-execution crashes;
- no new kernel/OOM evidence was found in `dmesg`;
- the runner disappeared entirely instead of recording a normal R error path.

## 3) What improved before the stall

The carried-forward scientific baseline remains valid:

- shared default:
  - `F500_anchor_patched`
- ridge `tt=100` local:
  - `G530_ridge_tt100_drift_guard_chain1300`
- ridge `tt=1000` local:
  - `H510_ridge_tt1000_local_control`
- rhs `tt=100` local:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000` local:
  - `F640_rhs_tt1000_chain1200`

The post-`H510` residual debt remains:

- `37` promoted fit FAIL rows;
- `33` affected roots;
- only `3` unresolved root-status FAIL roots remain, all on rhs `tt=1000` hard roots.

Wave-6 partial Stage-1 evidence is still useful but not promotable:

- `J530` completed `6 / 7` roots;
- no `vb` FAILs were observed in the completed partial Stage-1 output;
- current partial FAIL rows remain MCMC-side, dominated by `mcmc_exal`;
- no new Wave-6 profile is promotable because `J530` did not close cleanly.

## 4) Which ideas worked best

Best completed carry-forward ideas remain:

- `H510_ridge_tt1000_local_control` on the long-horizon ridge slice;
- `F610_rhs_tt100_conservative_block` on rhs `tt=100`;
- `F640_rhs_tt1000_chain1200` on rhs `tt=1000`.

Operationally, the highest-value new fix is not another tuning change.

The highest-value fix is a durable detached launcher:

- launch via a detached shell-backed supervisor instead of a transient interactive session;
- record launcher metadata, pid, and log path in the run tree;
- teach healthcheck to report whether the recorded launcher is still alive.

## 5) Which ideas did not help

These directions remain non-promoting or low-value:

- `H520_ridge_tt1000_g530_hybrid_chain1400`
  - clearly worse than `H510`;
- replaying sourced controls inside recovery waves
  - unnecessary once the residual launcher can score challengers against sourced control tables;
- continuing to launch long residual waves from a non-detached interactive session
  - this is now treated as an operational anti-pattern.

## 6) Highest expected-value next move

The correct next move is a supervised relaunch on the same narrow residual surface:

1. keep the post-`H510` local-baseline map;
2. keep the scientific residual scope unchanged;
3. relaunch under durable detached supervision;
4. do not rerun broad surfaces;
5. do not reopen clearly losing families.

That relaunch is formalized as Wave 7.
