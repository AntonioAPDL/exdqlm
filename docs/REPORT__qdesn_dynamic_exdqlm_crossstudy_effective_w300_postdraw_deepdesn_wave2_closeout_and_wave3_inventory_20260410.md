# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Wave 2 Closeout And Wave 3 Inventory

Date: 2026-04-10
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the completed deep-DESN final residual wave, decide which completed results are already
strong enough to promote into the working deep-DESN challenger baseline, measure the true
post-promotion residual surface, and define the next compute step only for the remaining
long-horizon `rhs_ns` MCMC debt.

This report is intentionally about the **working deep-DESN challenger**, not the authoritative
simple-DESN zero-FAIL branch baseline.

## 2) Completed Wave

Completed wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`
- stage status:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3/tables/stage_execution_status.csv`

Wave completion:

- `3 / 3` stages completed
- `14 / 14` profiles completed
- `0` `root_error.txt` files in the relaunched completed run

Stage outcomes:

- `E1_rhs_long_gausmix_mixed -> E410_rhs_long_gausmix_guard320_balanced3200`
- `E2_rhs_long_laplace_normal_mcmc -> E520_rhs_long_general_diag3400`
- `E3_ridge_mid_singleton_mcmc_exal -> E620_ridge_mid_diag3000`

## 3) Promotions Justified By Completed Evidence

The completed wave clearly justifies promoting these stage-local winners into the working
deep-DESN challenger source:

- `E410_rhs_long_gausmix_guard320_balanced3200`
- `E520_rhs_long_general_diag3400`
- `E620_ridge_mid_diag3000`

One additional exact-root promotion is also justified by completed evidence:

- `laplace tau=0.05 fit_size=5000 rhs_ns -> E530_rhs_long_general_guard320_burn3600`

Why the exact-root promotion is justified:

- stage-wide `E520` is still the right `E2` source winner;
- but the completed `E530` root-specific result reduces the `laplace tau=0.05 rhs_ns` long-horizon
  root from `2` fit FAIL rows to `1` without introducing root-status damage;
- no other completed exact-root override across the prior `D4` wave plus the completed `E` wave
  improves the current residual source more than this one.

## 4) What Improved

Source entering Wave 2:

- `59 PASS`
- `62 WARN`
- `23 FAIL`
- `35 / 36` root `SUCCESS`
- `1 / 36` root `FAIL`
- `34 / 36` comparison-eligible-any
- `26 / 36` comparison-eligible-full

After promoting `E410`, `E520`, `E620`:

- `70 PASS`
- `59 WARN`
- `15 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

After also promoting the exact-root `E530` win:

- `71 PASS`
- `59 WARN`
- `14 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Net change versus the pre-wave challenger source:

- fit FAIL rows:
  - `23 -> 14` (`-9`, `-39.1%`)
- root-status FAILs:
  - `1 -> 0` (`-100%`)
- comparison-eligible-any roots:
  - `34 / 36 -> 36 / 36`
- comparison-eligible-full roots:
  - `26 / 36 -> 27 / 36`

Important clarification:

- the `82` challenger FAIL rows seen in the completed-wave profile inventory are **not** the
  remaining residual;
- they are the combined FAIL rows across **all** challenger profiles tried in the search;
- the actual working post-promotion residual is the `14` FAIL rows above.

## 5) What Still Fails

Current working deep-DESN challenger residual after the justified promotions:

- `14` fit FAIL rows
- `0` root-status FAILs
- `9` fail-carrying roots

Every remaining FAIL row is now in the same narrow technical pocket:

- `prior = rhs_ns`
- `fit_size = 5000`
- `method = mcmc`

There is no remaining:

- ridge residual,
- short-horizon residual,
- VB residual,
- `fit_size = 500` residual,
- or root-status execution failure.

Residual split by family/model:

| Family | `al` FAIL | `exal` FAIL | Total |
| --- | ---: | ---: | ---: |
| `gausmix` | `3` | `3` | `6` |
| `laplace` | `0` | `3` | `3` |
| `normal` | `2` | `3` | `5` |

Residual split by family/tau:

| Family | Tau | FAIL rows |
| --- | ---: | ---: |
| `gausmix` | `0.05` | `2` |
| `gausmix` | `0.25` | `2` |
| `gausmix` | `0.95` | `2` |
| `laplace` | `0.05` | `1` |
| `laplace` | `0.25` | `1` |
| `laplace` | `0.95` | `1` |
| `normal` | `0.05` | `2` |
| `normal` | `0.25` | `2` |
| `normal` | `0.95` | `1` |

Residual signoff reasons:

| Signoff reason | Rows |
| --- | ---: |
| `high_autocorrelation; geweke_drift; half_chain_drift` | `6` |
| `geweke_drift` | `3` |
| `high_autocorrelation; half_chain_drift` | `3` |
| `half_chain_drift` | `1` |
| `high_autocorrelation` | `1` |

Interpretation:

- the remaining debt is now a pure long-horizon MCMC mixing / diagnostics problem;
- it is no longer a mixed execution-plus-scientific failure surface.

## 6) Which Ideas Worked Best

The strongest successful ideas from the completed wave were:

1. stage-local promotion rather than one universal winner
- `E410`, `E520`, and `E620` each improved their own targeted residual pocket;
- the residual surface continued to reward local tuning rather than a global rescue profile.

2. safe gausmix replacement over aggressive gausmix escalation
- `E410` matched the best gausmix target reduction while avoiding the guard-set damage seen in
  more aggressive shapes;
- that made it the right default source winner for the gausmix stage.

3. diagnostics-oriented general long profile for the mixed laplace/normal stage
- `E520` outperformed the cheaper balanced profile and the more aggressive guard-heavy diagnostics
  profiles at the stage level;
- that made it the right `E2` source winner.

4. exact-root promotions on top of stage-local winners
- `E530` gave one additional clean row reduction that the stage-wide winner did not capture;
- this is strong evidence that stage-level and exact-root promotion should continue to coexist.

5. singleton diagnostics repair for ridge
- `E620` closed the uncovered ridge residual cleanly, which means the remaining search should not
  spend any more time on ridge.

## 7) Which Ideas Did Not Help

The completed evidence is now strong enough to reject or deprioritize these directions:

1. repeating the same gausmix guard/length ladder
- `E410`, `E420`, `E440`, and `E450` all landed at the same `6` target FAIL rows for the gausmix
  stage;
- simply pushing more guard or more chain depth inside the same retained gausmix neighborhood did
  not improve the target surface.

2. the strongest general guard-heavy profiles as full-stage defaults
- `E540` and `E550` did not improve the `E2` target surface relative to `E520`;
- they are low-value repeats if used unchanged.

3. unsafe or root-damaging geometry
- `E430` tied the gausmix target FAIL count but reintroduced root-status damage;
- earlier `D410` narrow-first geometry was already unsafe and should stay retired.

4. broad residual reruns
- every remaining FAIL row is now in the same long-horizon rhs MCMC pocket;
- a broad mirrored rerun would be low-value compute.

## 8) Highest-Expected-Value Directions

The highest-value continuation is now clear:

1. split the remaining long-horizon rhs MCMC debt by family
- `gausmix`, `laplace`, and `normal` now behave differently enough that one mixed stage is too
  blunt.

2. split the `normal` band by tau regime
- the completed evidence already hints at a lower-tau vs upper-tau difference:
  - `E510` is the best current root-level source for `normal tau in {0.05, 0.25}`;
  - `E520` is the best current root-level source for `normal tau = 0.95`.

3. search new MCMC geometry, not a re-run of the same retained ladder
- the next wave should move to a new set of long-horizon rhs MCMC shapes:
  - recentered core widths,
  - burn-plus-diagnostics hybrids,
  - deeper transformed block passes,
  - and family-specific rather than generic stage grouping.

4. carry forward the E530 exact-root gain immediately
- it is already justified;
- there is no reason to make the next wave relearn it.

## 9) Recommendation

Promote into the working deep-DESN challenger source now:

- `E410`
- `E520`
- `E620`
- exact-root `E530` on `laplace tau=0.05 fit_size=5000 rhs_ns`

Then launch one more **strictly residual** wave with the source above and search only inside:

- `gausmix rhs_ns fit_size=5000 mcmc`
- `laplace rhs_ns fit_size=5000 mcmc`
- `normal rhs_ns fit_size=5000 mcmc`, split into lower-tau and upper-tau sub-bands

That is now the highest-value path to eliminate the last deep-DESN FAIL rows.
