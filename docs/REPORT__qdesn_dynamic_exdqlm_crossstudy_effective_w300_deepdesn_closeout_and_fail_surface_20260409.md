# REPORT: QDESN Dynamic Effective-W300 Deep-DESN Closeout And Fail Surface

Date: 2026-04-09  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the completed-state read on the broad deep-DESN rerun, compare it to the current
authoritative simple-DESN effective-w300 baseline, and isolate the remaining high-value repair
surface before launching any additional work.

## 2) Source Run

Completed deep-DESN broad rerun:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a`
- campaign summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a/20260408-211634__git-8527b4a/summary/qdesn_dynamic_crossstudy_summary.md`
- fit table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a/20260408-211634__git-8527b4a/tables/campaign_fit_summary.csv`
- root signoff table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a/20260408-211634__git-8527b4a/tables/campaign_root_signoff_summary.csv`

Source-state totals:

- roots:
  - `36/36` materialized
  - `34/36 SUCCESS`
  - `2/36 FAIL`
- fit rows:
  - `144/144`
- fit signoff mix:
  - `27 PASS`
  - `48 WARN`
  - `69 FAIL`
- root comparison readiness:
  - `30/36` comparison-eligible-any
  - `5/36` comparison-eligible-full

Current failed roots:

- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_rhs_ns`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_ridge`

Important interpretation:

- this is not a broad execution-collapse event;
- all `144` fit summaries and all `36` root summaries materialized;
- the remaining debt is primarily scientific signoff debt, plus two localized root-status FAILs in
  the long-horizon `gausmix tau=0.95` pocket.

## 3) Comparison Against The Current Authoritative Baseline

Current authoritative branch baseline remains:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
- report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`

That source is still:

- `68 PASS`
- `76 WARN`
- `0 FAIL`
- `0/36` root-status FAILs
- `36/36` comparison-eligible-any
- `36/36` comparison-eligible-full

Promotion decision from the completed broad deep-DESN rerun:

- whole-root promotions:
  - `0`
- reason:
  - no deep-DESN root achieved a clean whole-root dominance pattern against the current
    authoritative simple-DESN source under the branch-local promotion rule
  - promotion rule used here:
    - all four fit rows must be non-FAIL,
    - no fit row may worsen signoff versus source,
    - and at least two fit rows must clearly improve on both `train_qtrue_mae` and
      `train_pinball_tau`

Observed local deep-DESN upside that is **not yet promotable**:

- clear fit-level improvements versus the current authoritative source:
  - `18` fit rows
  - on `11` roots
- all of those are:
  - `rhs_ns`
  - `vb`
  - `WARN` versus source `WARN`
- model split:
  - `9` `al`
  - `9` `exal`

Interpretation:

- the deep-DESN architecture is showing real localized signal in the `rhs_ns/vb` region,
- but it is not yet coherent enough at the whole-root level to justify promoting broad or root-wide
  deep-DESN results into the authoritative branch baseline.

## 4) What Improved

Compared with the deep-DESN launch expectation, the broad rerun did deliver useful progress:

- the new deeper reservoir executed end to end on the full `36`-root lattice;
- broad execution remained mostly healthy:
  - `34/36` roots finished `SUCCESS`;
- there was no broad implementation-failure cascade analogous to the earlier latent-sampler issue;
- the richer architecture produced fit-level metric wins on `18` rows / `11` roots without
  worsening signoff grade on those rows;
- the clearest localized wins landed in `rhs_ns/vb`, suggesting the richer reservoir can help
  oracle quantile recovery in selected sparse-heavy regions.

## 5) What Still Fails

Current residual scientific debt:

- fit FAIL rows:
  - `69`
- fail-carrying roots:
  - `31`
- root-status FAILs:
  - `2`
- successful but noneligible roots:
  - `4`

### 5.1 Mechanism Inventory

Dominant fail mechanisms:

- `ridge_vb_core_tail`:
  - `24`
  - signature:
    - `vb_converged_false; elbo_tail_unstable; core_parameter_tail_unstable`
- `rhs_vb_rhs_tail`:
  - `4`
  - signature:
    - `vb_converged_false; rhs_parameter_tail_unstable`
- `rhs_ns mcmc mix_drift`:
  - `35`
  - signatures:
    - `high_autocorrelation`
    - `geweke_drift`
    - `half_chain_drift`
    - `low_ess`
- `mcmc_missing_diag`:
  - `2`
  - both in `gausmix tau=0.95 fit_size=5000`
- `ridge mcmc mix_drift`:
  - `4`
  - concentrated in the ridge upper-tail band

### 5.2 Structured Fail Surface

The row-level debt is broad, but the practical repair surface is concentrated into four repeat
clusters:

1. Ridge lower-tail VB failures
- source rows:
  - `12`
- roots:
  - `6`
- exact slice:
  - `prior = ridge`
  - `inference = vb`
  - `tau = 0.05`
  - `fit_size = 500 or 5000`

2. Ridge upper-tail mixed failures
- source rows:
  - `16`
- roots:
  - `6`
- exact slice:
  - `prior = ridge`
  - `tau = 0.95`
  - mostly ridge VB core-tail failures
  - plus a small ridge MCMC diagnostic pocket

3. RHS short-horizon MCMC failures
- source rows:
  - `18`
- roots:
  - `9`
- exact slice:
  - `prior = rhs_ns`
  - `inference = mcmc`
  - `fit_size = 500`
  - all families and taus

4. RHS long-horizon mixed failures
- source rows:
  - `22`
- roots:
  - `9`
- exact slice:
  - `prior = rhs_ns`
  - `fit_size = 5000`
  - broad long-horizon MCMC debt
  - plus the small `gausmix` VB tail pocket

### 5.3 Root Fail Pocket

The two current root FAILs are:

- `gausmix`, `tau=0.95`, `fit_size=5000`, `rhs_ns`
  - one failed `mcmc_al` fit with `missing_chain_diagnostics`
  - plus three noneligible fit rows
- `gausmix`, `tau=0.95`, `fit_size=5000`, `ridge`
  - one failed `mcmc_exal` fit with `missing_chain_diagnostics`
  - plus two ridge VB tail-fail rows

These are therefore not generic branch problems. They are the sharpest point of the long-horizon
upper-tail deep-DESN fail surface.

## 6) Which Ideas Worked Best

The strongest lessons from the completed broad rerun are:

1. The richer DESN can help selected `rhs_ns/vb` rows.
- this is the only area where the deep-DESN challenger repeatedly improved `qtrue` and pinball
  versus the authoritative source without worsening signoff.

2. The fail surface is mechanism-stable.
- nearly all FAIL rows collapse into the same four repeat neighborhoods listed above.
- this makes a stage-based repair wave much higher value than another broad rerun.

3. Local tuning is still the right strategy.
- the completed source shows no evidence that one generic global tuning change will repair all
  deep-DESN debt.
- the same local-tuning principle that worked in the earlier effective-w300 repair cycle remains
  the right approach here.

## 7) Which Ideas Did Not Help

The completed broad rerun also clarified several low-value directions:

1. Swapping to the richer DESN while keeping the simple-DESN inference defaults was not enough.
- the architecture changed substantially, but the ridge VB and rhs_ns MCMC defaults were not strong
  enough for the new geometry.

2. Broad promotion is not justified yet.
- there are fit-level wins, but no whole-root deep-DESN result that is clean enough to replace the
  authoritative branch baseline.

3. Generic search across already-healthy rows is low value.
- the rows that stayed `PASS/WARN` under the broad rerun do not justify another blanket rerun.
- the repair program should only touch the four residual mechanisms above.

## 8) Highest-Expected-Value Directions

The highest-value retained directions are:

1. Stronger ridge VB guards for the lower-tail and upper-tail ridge bands.
- rationale:
  - `24/69` FAIL rows are ridge VB core-tail failures
  - they are highly uniform and likely responsive to more VB Monte Carlo budget plus longer ELBO
    stabilization

2. Coupled ridge upper-tail VB plus MCMC retuning.
- rationale:
  - the ridge upper-tail band mixes ridge VB failures with a small ridge MCMC diagnostic pocket
  - a coupled stage is more efficient than treating those rows independently

3. Dedicated rhs_ns short-horizon MCMC retuning.
- rationale:
  - every short-horizon rhs_ns MCMC row is failing
  - the corresponding VB rows are already usable
  - this is a pure MCMC geometry/warmup problem and should not spend compute on unrelated VB changes

4. Dedicated rhs_ns long-horizon mixed retuning.
- rationale:
  - this is the most expensive but highest-value remaining cluster
  - it contains the two root FAILs and the broad long-horizon rhs_ns debt

## 9) Recommendation

Do **not** replace the authoritative branch baseline yet.

Instead:

- keep the current simple-DESN zero-FAIL effective-w300 pack as the authoritative branch baseline;
- treat the completed broad deep-DESN rerun as the source state for a localized fail-closure wave;
- promote only clear stage winners from that localized wave if they beat the deep-DESN source on
  the intended guard sets.
