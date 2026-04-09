# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Wave 1 Closeout And Wave 2 Inventory

Date: 2026-04-09  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the completed-state read on the first targeted deep-DESN fail-closure wave, decide which
completed results should be promoted into the **working deep-DESN challenger baseline**, document
the related reproducibility gaps that were discovered, and define the exact residual surface that
still justifies new compute.

This report supersedes the active continuation role previously held by:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_closeout_and_fail_surface_20260409.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_20260409.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_setup_and_launch_20260409.md`

for the branch-local answer to:

- what improved,
- what still fails,
- which ideas worked best,
- which ideas did not help,
- and what the highest-expected-value continuation is.

## 2) Completed Wave 1

Completed repair wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- stage status:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e/tables/stage_execution_status.csv`
- launch/setup report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_setup_and_launch_20260409.md`

Wave 1 completion:

- `4/4` stages
- `18/18` challenger profiles
- `135/135` planned root-campaigns
- `540/540` planned fit executions

Stage outcomes:

| Stage | Recommendation | Read |
| --- | --- | --- |
| `D1_ridge_lower_tail_vb` | `PROMOTE D120_ridge_lower_vb384` | clear local ridge lower-tail winner |
| `D2_ridge_upper_tail_mixed` | `PROMOTE D250_ridge_upper_combo512_diag3400` | clear local ridge upper-tail mixed winner |
| `D3_rhs_short_mcmc` | `PROMOTE D330_rhs_short_balanced3000` | best broad short-horizon rhs_ns stage winner |
| `D4_rhs_long_mixed` | `KEEP SOURCE BASELINE` | no trustworthy stage-wide challenger promotion |

## 3) Wave 1 Reproducibility Gap

Wave 1 produced one important artifact-level gap:

- `tables/local_baseline_map.csv` in the completed wave is a zero-byte file;
- the D4 stage summary and profile metric tables are zero-byte files;
- only the first D4 challenger directory materialized, and it contains no campaign summary tables.

Observed operational evidence:

- all `6` `root_error.txt` files from Wave 1 came from:
  - `D410_rhs_long_guard256_narrow3000`
- no completed D4 challenger profile produced trustworthy campaign summary tables;
- the stage-level `KEEP_SOURCE_BASELINE` decision is therefore usable as a conservative default,
  but **not** as evidence that the D4 long-horizon rhs pocket was meaningfully explored.

Branch-local fix applied now:

- the generic dynamic fit-fail wave reader now treats zero-byte CSVs as empty data frames instead of
  hard-failing;
- the wave runner now preserves schema when writing empty `local_baseline_map` and in-flight stage
  tables, so future runs remain readable and reproducible even when a stage yields no promotable
  local baseline.

Interpretation:

- Wave 1 is still valid evidence for `D1`, `D2`, and `D3`;
- `D4` should be treated as **unresolved**, not as “fully searched and lost.”

## 4) Promotion Decision

The right branch-local rule here is:

- keep the **simple-DESN effective-w300 zero-FAIL pack** as the authoritative branch comparison
  baseline;
- promote only clearly improved results into the **working deep-DESN challenger source**;
- allow exact-root promotions when a completed nonwinning profile is demonstrably better for a
  specific residual root than the stage winner.

Promotion comparison:

| Deep-DESN Challenger State | Fit FAIL Rows | Root-Status FAILs | Compare-Any | Compare-Full | Read |
| --- | ---: | ---: | ---: | ---: | --- |
| broad deep-DESN source rerun | `69` | `2` | `30/36` | `5/36` | raw challenger source |
| `D1+D2+D3` winners, `D4` kept at source | `26` | `1` | `34/36` | `23/36` | clear improvement, but still leaves residual debt |
| current working source = stage winners plus exact-root promotions | `23` | `1` | `34/36` | `26/36` | best current deep-DESN challenger baseline |

Promoted stage winners:

- `D120_ridge_lower_vb384`
- `D250_ridge_upper_combo512_diag3400`
- `D330_rhs_short_balanced3000`

Exact-root promotions justified by completed evidence:

| Root | Promoted From Profile | Why |
| --- | --- | --- |
| `gausmix tau=0.05 fit_size=500 rhs_ns` | `D310_rhs_short_drift2600` | clears the only remaining `D3` residual FAIL on this root and leaves the root `SUCCESS` / full-ready |
| `gausmix tau=0.05 fit_size=5000 ridge` | `D140_ridge_lower_vb512` | clears the residual `D1` fail row on this root without root-status damage |
| `laplace tau=0.05 fit_size=5000 ridge` | `D140_ridge_lower_vb512` | clears the residual `D1` fail row on this root without root-status damage |

Current working deep-DESN source after those promotions:

- fit signoff:
  - `59 PASS`
  - `62 WARN`
  - `23 FAIL`
- root execution:
  - `35/36 SUCCESS`
  - `1/36 FAIL`
- root readiness:
  - `34/36` comparison-eligible-any
  - `26/36` comparison-eligible-full

## 5) What Improved

### A) The fail surface shrank materially

Improvement versus the broad deep-DESN source rerun:

| Metric | Broad Source | Current Working Deep-DESN Source | Change |
| --- | ---: | ---: | ---: |
| Fit FAIL rows | `69` | `23` | **`-46` (`-66.7%`)** |
| Root-status FAILs | `2` | `1` | **`-1` (`-50.0%`)** |
| Comparison-eligible-any roots | `30/36` | `34/36` | **`+4`** |
| Comparison-eligible-full roots | `5/36` | `26/36` | **`+21`** |

### B) Ridge repair was successful

The ridge pockets responded strongly to local tuning:

- `D1` target FAIL rows:
  - `12 -> 0` at the stage winner level
- `D2` target FAIL rows:
  - `16 -> 0`
- exact-root `D140` promotions close the last two residual `D1` ridge rows that remained under the
  lighter `D120` winner

### C) Short-horizon rhs repair mostly worked

The `D3` broad winner did not close every short-horizon rhs root, but it reduced the stage from:

- `18` target FAIL rows
- to `1`

and the remaining singleton root is already closable with completed `D310` evidence.

## 6) What Still Fails

Current residual challenger debt after the promoted working source:

- fit FAIL rows:
  - `23`
- fail-carrying roots:
  - `10`
- root-status FAILs:
  - `1`

Residual surface by cluster:

| Residual Cluster | Roots | FAIL Rows | Root FAILs | Read |
| --- | ---: | ---: | ---: | --- |
| `rhs_ns`, `fit_size=5000`, `family=gausmix` | `3` | `10` | `1` | hardest remaining pocket; includes the only root-status FAIL |
| `rhs_ns`, `fit_size=5000`, `family in {laplace, normal}` | `6` | `12` | `0` | broad long-horizon MCMC drift pocket |
| uncovered ridge singleton | `1` | `1` | `0` | `normal tau=0.25 fit_size=500 ridge mcmc_exal` |

Residual surface by prior / inference / model:

| Prior | Inference | Model | FAIL Rows |
| --- | --- | --- | ---: |
| `rhs_ns` | `mcmc` | `al` | `9` |
| `rhs_ns` | `mcmc` | `exal` | `9` |
| `rhs_ns` | `vb` | `al` | `2` |
| `rhs_ns` | `vb` | `exal` | `2` |
| `ridge` | `mcmc` | `exal` | `1` |

Residual fail mechanisms:

| Signoff Reason | Rows |
| --- | ---: |
| `high_autocorrelation` | `5` |
| `high_autocorrelation; half_chain_drift` | `4` |
| `vb_converged_false; rhs_parameter_tail_unstable` | `4` |
| `geweke_drift` | `2` |
| `geweke_drift; half_chain_drift` | `2` |
| `half_chain_drift` | `2` |
| `high_autocorrelation; geweke_drift` | `1` |
| `high_autocorrelation; geweke_drift; half_chain_drift` | `1` |
| `low_ess; high_autocorrelation; geweke_drift; half_chain_drift` | `1` |
| `missing_chain_diagnostics` | `1` |

The only remaining root-status FAIL is:

- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_rhs_ns`

Interpretation:

- almost all remaining debt is now long-horizon `rhs_ns`;
- the only non-`rhs_ns` residual is one uncovered short-horizon ridge `mcmc_exal` row that was
  never included in Wave 1;
- the next run should therefore attack **only** those two residual neighborhoods.

## 7) Which Ideas Worked Best

### A) Local ridge promotions

The best clean gains still came from local ridge promotions:

- `D120` is the right default `D1` local baseline;
- `D250` is the right `D2` local baseline;
- `D140` is better than `D120` for two specific long-horizon ridge roots, which is exactly the
  kind of narrow exact-root promotion we want to allow.

### B) Stage-local plus exact-root is better than stage-local alone

`D330` was the right broad `D3` winner, but `D310` is strictly better on the surviving
`gausmix tau=0.05 fit_size=500 rhs_ns` root. That confirms:

- broad local winners should remain the default source,
- but exact-root promotions are still the highest-value tool for leftover singleton debt.

### C) Deep-DESN still shows localized upside

The current working source is much cleaner than the raw broad rerun while keeping the richer DESN
architecture intact. That is enough evidence to justify one final residual wave on the challenger
surface before giving up on deep-DESN improvement.

## 8) Which Ideas Did Not Help

### A) `D410_rhs_long_guard256_narrow3000`

This profile is now explicitly rejected.

Observed outcome:

- all `6` Wave 1 `root_error.txt` files came from `D410`
- it produced no trustworthy campaign summary tables
- it did not generate promotable evidence

Interpretation:

- do **not** reuse `D410`
- do **not** use “narrow first” as the leading long-horizon rhs continuation

### B) Treating `D4` as solved

Wave 1 does **not** justify the claim that long-horizon rhs is unfixable. It only justifies the
much narrower statement that:

- the first `D4` profile was bad,
- and Wave 1 did not leave enough valid D4 evidence to promote a stage-wide replacement.

### C) Another blanket deep-DESN rerun

The current fail surface is already small and structured enough that another full `36`-root rerun
would be mostly wasted compute.

## 9) Highest-Expected-Value Direction

The next overnight program should:

1. keep the current promoted deep-DESN challenger source as the default,
2. split the unresolved long-horizon rhs pocket into:
   - a gausmix-heavy stage with stronger VB guards and safer diagnostic chains,
   - a laplace/normal long-horizon stage focused on MCMC drift cleanup,
3. add a tiny singleton ridge stage for the uncovered `normal tau=0.25 fit_size=500 ridge
   mcmc_exal` row,
4. exclude `D410`,
5. avoid rerunning solved `D1`, `D2`, and `D3` neighborhoods.

That continuation is broad enough to learn across the true residual space, but disciplined enough
to avoid re-paying compute on already solved or already rejected regions.

## 10) Recommendation

Promote the current Wave 1 evidence into the **working deep-DESN challenger baseline** as follows:

- stage winners:
  - `D120`
  - `D250`
  - `D330`
- exact-root promotions:
  - `D310` on `gausmix tau=0.05 fit_size=500 rhs_ns`
  - `D140` on `gausmix tau=0.05 fit_size=5000 ridge`
  - `D140` on `laplace tau=0.05 fit_size=5000 ridge`

Then launch one final residual-only deep-DESN wave focused strictly on:

- long-horizon `rhs_ns` at `fit_size=5000`
- the single uncovered `normal tau=0.25 fit_size=500 ridge mcmc_exal` row

The authoritative branch comparison baseline should remain the simple-DESN zero-FAIL effective-w300
pack until this challenger residual wave either closes cleanly or definitively stalls.
