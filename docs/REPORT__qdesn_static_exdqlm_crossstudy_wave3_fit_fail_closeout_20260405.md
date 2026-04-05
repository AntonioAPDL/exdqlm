# REPORT: QDESN Static exdqlm Cross-Study Wave 3 Fit-Fail Closure Closeout

Date: 2026-04-05  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Scope

Wave 3 was the targeted fit-fail closure run launched from:

- source broad baseline:
  - `qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- Wave 3 run:
  - `qdesn-static-exdqlm-crossstudy-fitfail-20260404b__git-2aa809c`

Its purpose was not to find one universal rescue profile. The purpose was to:

1. keep the shared static defaults as the default baseline;
2. close the `rhs_ns` VB diagnostics-path false-FAIL bucket under that shared baseline;
3. promote local slice winners only where the shared baseline clearly lost;
4. reduce the real remaining MCMC FAIL surface before any finer follow-up.

## 2) Main Improvements

### 2.1 Shared default improvement

The shared baseline now includes the validated `rhs_trace.rds` diagnostics fallback. That change
was confirmed in Wave 3 Stage 1 rather than left as a smoke-only inference.

| Stage | Source broad baseline | Wave-3 winner | Change |
| --- | ---: | ---: | ---: |
| `S1 rhs_ns VB diagnostics` `rhs_vb_fail_n` | `66` | `0` | `-66` |
| `S1` fit FAIL rows on the full target set | `106` | `35` | `-71` |
| `S1` roots with any usable comparison | `3 / 33` | `33 / 33` | `+30` |
| `S1` roots fully comparison-ready | `0 / 33` | `8 / 33` | `+8` |

### 2.2 Local winners that clearly beat the previous baseline

| Slice | Previous baseline control | Winner | Outcome |
| --- | --- | --- | --- |
| Ridge `exal/mcmc` closure | `F500_anchor_patched` | `F510_ridge_rescue_reference` | promoted local ridge baseline |
| `rhs_ns mcmc @ tt=100` closure | `F500_anchor_patched` | `F610_rhs_tt100_conservative_block` | promoted local rhs `tt=100` baseline |
| `rhs_ns mcmc @ tt=1000` closure | `F500_anchor_patched` | `F640_rhs_tt1000_chain1200` | promoted local rhs `tt=1000` baseline |

## 3) What Worked Best

| Direction | Read |
| --- | --- |
| Shared baseline + diagnostics fallback | fixed the old `rhs_ns` VB false-FAIL bucket cleanly |
| `F510_ridge_rescue_reference` | best ridge-local rescue; reduced ridge fit FAILs from `24` to `15` and increased full-comparison-ready roots from `0` to `9` |
| `F610_rhs_tt100_conservative_block` | best short-horizon rhs rescue; reduced rhs `tt=100` fit FAILs from `56` to `12` |
| `F640_rhs_tt1000_chain1200` | best long-horizon rhs rescue; reduced rhs `tt=1000` fit FAILs from `44` to `14` |

## 4) What Did Not Help

| Profile | Why it did not help |
| --- | --- |
| `F520_ridge_chain1200_laplace_focus` | extra chain inflation did not beat `F510` on the ridge slice |
| `F620_rhs_tt100_chain1200` | chain-only inflation was weaker than the conservative transformed-block geometry on the rhs `tt=100` slice |
| `F630_rhs_tt1000_conservative_block` | geometry-only tightening was weaker than the chain-led `F640` long-horizon rhs profile |

## 5) Current Post-Promotion Baseline Map

Wave 3 changed the effective baseline map.

| Scope | Baseline after Wave 3 |
| --- | --- |
| shared default | `F500_anchor_patched` |
| ridge local slice | `F510_ridge_rescue_reference` |
| rhs local `tt=100` slice | `F610_rhs_tt100_conservative_block` |
| rhs local `tt=1000` slice | `F640_rhs_tt1000_chain1200` |

## 6) What Still Fails

The promoted Wave-3 baseline map is materially better, but it is not fully closed.

### 6.1 Promoted residual fit FAIL surface

After overlaying the promoted local winners onto the original broad source baseline, the remaining
successful-surface FAIL inventory is:

| Metric | Count |
| --- | ---: |
| promoted fit rows on successful roots | `264` |
| promoted FAIL rows | `45` |
| promoted WARN rows | `150` |
| promoted PASS rows | `69` |
| roots with any remaining fit FAIL | `41` |
| successful roots with any usable comparison | `66 / 66` |
| successful roots fully comparison-ready | `25 / 66` |

Important structure:

- all `45` remaining fit FAIL rows are `mcmc`;
- `41 / 45` are `exal`;
- `4 / 45` are `al`;
- residual reasons are now dominated by:
  - `half_chain_drift`
  - `low_ess + high_autocorrelation`
  - `geweke_drift + half_chain_drift`

### 6.2 Unresolved hard-root FAIL debt

Wave 3 did **not** revalidate the original Wave-1 hard-root FAIL band inside the promoted baseline
map. Those roots were only rescued in the stopped Wave-2 Stage-1 probe, not in a completed
follow-up wave.

Remaining unresolved hard-root FAIL roots:

1. `root__static_shrink__laplace__tau_0p05__tt_1000__qdesn_rhs_ns`
2. `root__static_shrink__laplace__tau_0p05__tt_1000__qdesn_ridge`
3. `root__static_shrink__laplace__tau_0p25__tt_1000__qdesn_rhs_ns`
4. `root__static_shrink__laplace__tau_0p25__tt_1000__qdesn_ridge`
5. `root__static_shrink__laplace__tau_0p95__tt_1000__qdesn_rhs_ns`
6. `root__static_shrink__laplace__tau_0p95__tt_1000__qdesn_ridge`

## 7) Highest-Value Remaining Directions

The remaining problem is now small enough to split by failure mode rather than by broad family.

| Remaining slice | Current read | Highest-value direction |
| --- | --- | --- |
| ridge `tt=100` residuals | only `3` roots remain and they are drift-heavy | tighten the F510 geometry and add only modest extra keep length |
| ridge `tt=1000` residuals | mostly `exal` ESS/autocorrelation debt on gausmix/normal, plus the unresolved hard-root laplace band | keep the F510 geometry but add a moderate chain extension; do not reopen the old chain-only ridge branch |
| rhs `tt=100` residuals | conservative geometry beat chain-only inflation in Wave 3 | stay geometry-first and test hybrid chain + geometry, not another loose chain-only rhs profile |
| rhs `tt=1000` residuals | chain-led rescue beat geometry-only in Wave 3 | test F640-style deeper persistence and one F640/F630 hybrid rather than rerunning F630-like geometry-only variants |

## 8) Closeout Read

Wave 3 was a real improvement wave, not just a clean execution wave.

The branch should now treat:

- `F500_anchor_patched` as the shared default;
- `F510` as the current ridge-local baseline;
- `F610` as the current rhs `tt=100` baseline;
- `F640` as the current rhs `tt=1000` baseline.

But the cross-study program is **not finished** yet, because:

1. `45` promoted residual fit FAIL rows still remain on successful roots; and
2. the original `6` Wave-1 hard-root FAILs still need explicit revalidation under the promoted map.

That means the next wave should be a residual MCMC closure wave anchored to the promoted local
baseline map, not another broad relaunch and not another search for one generic profile.
