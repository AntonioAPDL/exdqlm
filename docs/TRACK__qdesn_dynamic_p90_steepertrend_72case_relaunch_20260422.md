# TRACK: QDESN Dynamic P90 Steepertrend 72-Case Relaunch

Date: 2026-04-22
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Mission

Run the next high-quality Q-DESN dynamic relaunch on the promoted period-90
steeper-trend dataset surface using:

- the normalized shared `0.4.0` package warmup defaults;
- the updated Q-DESN dynamic launch stack; and
- a disciplined baseline-first relaunch structure.

Primary baseline target:

- `72` fits on one prior surface

Recommended order:

1. `ridge` first
2. `rhs_ns` second if the baseline is healthy

## 2) Active Dataset

Promoted scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

Canonical source root:

- [source roots](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Q-DESN materialized root:

- [qdesn windows](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_qdesn_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Supporting docs:

- [active dataset manifest](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_active_dataset_selection.yaml)
- [selection report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_p90_steepertrend_main_dataset_selection_20260422.md)
- [relaunch prep plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_dynamic_p90_steepertrend_72case_relaunch_prep_20260422.md)

## 3) Core Baseline Policy

Shared long-budget contract to preserve:

- `vb.max_iter = 300`
- `vb.min_iter_elbo = 80`
- `vb.n_samp_xi = 1000`
- `mcmc.n_burn = 5000`
- `mcmc.n_mcmc = 20000`
- `mcmc.thin = 1`
- `posterior_metric_draws = 20000`
- `vb_sampling_nd_draws = 20000`
- `vb_synthesis_n_samp = 20000`
- `washout = 300`

Warmup policy to preserve:

- automatic tau warmup for `rhs` / `rhs_ns` with `50L`
- light exAL VB `(sigma, gamma)` warmup
- light exAL MCMC `(sigma, gamma)` warmup
- explicit `init_from_vb = TRUE` for MCMC

What stays out of the baseline:

- theta freeze rescue
- latent-state rescue
- latent `v` / latent `s` rescue
- precision rescue
- row-local replay overrides

## 4) Exact Dataset Semantics

Study geometry:

- `9` full roots
- `18` effective source windows
- one prior surface -> `72` fits
- two prior surfaces -> `144` fits

Exact effective-size semantics:

- effective sizes:
  - `500`
  - `5000`
- Q-DESN staged totals:
  - `813`
  - `5313`

These totals are required because:

- `holdout_n = 1`
- `lag_max = 12`
- `washout = 300`

## 5) Checklist

### A. Dataset freeze

- [x] promoted dataset selected
- [x] audit packs generated and reviewed
- [x] active dataset manifest written
- [x] `0.4.0` validation sync prompt written

### B. Relaunch design freeze

- [x] baseline-first relaunch policy documented
- [x] first-prior versus second-prior expansion policy documented
- [x] long-budget contract documented
- [x] baseline warmup matrix documented
- [x] final first-prior choice confirmed at implementation time

### C. Implementation prep

- [x] new relaunch defaults manifest created
- [x] new canonical full grid created from promoted dataset
- [x] audited subset grids created
- [x] launch wrapper created
- [x] healthcheck created
- [x] focused config test added

### D. Preflight gates

- [x] smoke `prepare-only` passed
- [x] full `prepare-only` passed
- [x] source totals verified as `813 / 5313`
- [x] effective-fit semantics verified as `500 / 5000`
- [x] warmup/default resolution verified

### E. Execution gates

- [x] smoke execution passed
- [x] committed-state launch tag frozen
- [x] full baseline launch started from committed state
- [x] live healthcheck captured
- [x] `rhs_ns` smoke gate executed from committed state
- [x] `rhs_ns` smoke numerical gate reviewed

### F. Post-run decision

- [x] baseline result summarized
- [x] decision made on second-prior expansion
- [x] decision made on whether any rescue overlays are needed

### G. Second-prior expansion

- [x] committed-state `rhs_ns_full` preflight passed
- [x] committed-state `rhs_ns_full` launch started
- [x] live healthcheck captured for full `rhs_ns`

### H. Interruption recovery

- [x] interrupted full `rhs_ns` run reconciled
- [x] unresolved-root continuation grid generated
- [x] committed-state continuation preflight passed
- [x] continuation wave launched
- [x] initial continuation healthcheck captured

### I. Throughput optimization

- [x] under-parallelized continuation wave stopped cleanly
- [x] runner updated for load-balanced root scheduling
- [x] optimized continuation preflight passed
- [ ] optimized continuation wave launched
- [ ] initial optimized healthcheck captured

## 6) Recommended Launch Order

1. implement the new relaunch assets on top of the promoted dataset
2. run committed-state smoke/full preflights
3. run smoke execution
4. run the first `72`-fit baseline on `ridge`
5. review results
6. only then launch the second `72`-fit `rhs_ns` expansion if justified

## 7) Historical Reference We Are Intentionally Reusing

We are reusing the parts of the previous refreshed-main relaunch that worked
well:

- explicit study contract
- deterministic per-root seeds
- phase-aware launch subsets
- committed-state preflights
- smoke-before-full discipline
- run-tag and session freeze after launch

We are intentionally **not** reusing the historical rescue-heavy defaults as
the new baseline.

## 8) Current Read

Committed-state launch tags used:

- smoke:
  - `qdesn-dynamic-p90-steepertrend-smoke-20260422-044129__git-6438b52`
- ridge baseline:
  - `qdesn-dynamic-p90-steepertrend-ridge-full-20260422-044241__git-6438b52`

Ridge baseline final operational outcome:

- `18 / 18` roots completed successfully
- `72 / 72` fits completed with `status = SUCCESS`
- hard numerical/runtime failures:
  - `0`
- root-level runtime failures:
  - `0`

Ridge baseline final fit-quality mix:

- `PASS: 42` (`58.3%`)
- `WARN: 15` (`20.8%`)
- `FAIL: 15` (`20.8%`)
- comparison-eligible:
  - `57 / 72` (`79.2%`)

Dominant diagnostic issues:

- `high_autocorrelation`
- `high_autocorrelation; half_chain_drift`
- `low_ess; high_autocorrelation; half_chain_drift`
- `vb_converged_false`
- `chain_marginal_but_usable`

Interpretation:

- the promoted dataset surface and the updated Q-DESN launch stack passed the
  first operational baseline gate
- the baseline did **not** show hard numerical breakdown
- the main remaining weakness is mixing/diagnostic quality, especially on
  `exal + mcmc`

Decision:

- proceed to the second prior surface, but **not** as a blind full launch
- next step should be a committed-state `rhs_ns` smoke gate using the same
  normalized baseline defaults
- only if that smoke gate remains free of hard numerical/runtime failures
  should the full `72`-fit `rhs_ns` expansion be launched

Rescue-overlay policy:

- do **not** change the baseline defaults yet
- do **not** promote theta/latent/precision rescue overlays into the default
  `rhs_ns` pass before seeing the `rhs_ns` smoke behavior
- if `rhs_ns` shows hard numerical problems, re-enter with a targeted rescue
  overlay plan afterward

## 9) RHS-NS Smoke Completion And Expansion Decision

Committed-state smoke run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-smoke-20260422-211800__git-b8f8f06`

RHS-NS smoke final operational outcome:

- `2 / 2` roots completed successfully
- `8 / 8` fits completed with `status = SUCCESS`
- hard numerical/runtime failures:
  - `0`
- root-level runtime failures:
  - `0`

RHS-NS smoke final fit-quality mix:

- `PASS: 4` (`50.0%`)
- `WARN: 1` (`12.5%`)
- `FAIL: 3` (`37.5%`)
- comparison-eligible:
  - `5 / 8` (`62.5%`)

Dominant diagnostic issues:

- `high_autocorrelation`
- `chain_marginal_but_usable`

Interpretation:

- the normalized baseline defaults remained operationally stable on the staged
  `rhs_ns` smoke surface
- the smoke gate showed diagnostic weakness, but **not** hard numerical/runtime
  breakdown
- the next stage should therefore be the committed-state full `rhs_ns`
  expansion, still without promoting rescue overlays into the baseline

Decision:

- proceed to the full `rhs_ns` `72`-fit stage
- keep the same normalized baseline defaults
- continue to hold theta/latent/precision rescue layers in reserve unless the
  full `rhs_ns` surface shows hard failure or materially worse degradation

## 10) Full RHS-NS Launch Start

Committed-state preflight run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-full-preflight-20260423-143700__git-20c5e35`

Committed-state full launch run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35`

Preflight status:

- focused config test passed
- `rhsns_full` prepare-only gate passed

Initial live health snapshot:

- snapshot time:
  - `2026-04-23 14:39 EDT`
- selected roots:
  - `18`
- materialized roots:
  - `0`
- successful roots:
  - `0`
- running roots:
  - `0` in summaries yet
- failed roots:
  - `0`
- launcher session:
  - `qdesn_p90_rhsns_full`
- launcher session live:
  - `TRUE`

Initial interpretation:

- the full `rhs_ns` launch opened cleanly from the frozen committed state
- workers started successfully
- no hard numerical/runtime failure evidence was present at launch time
- the next checkpoints should focus on first materialized roots and first
  completed fit summaries

## 11) Full RHS-NS Interruption And Continuation Decision

Interrupted run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-full-20260423-143900__git-20c5e35`

Observed stop condition:

- the tmux launcher session exited unexpectedly after partial progress
- the campaign reached:
  - `3` successful roots
  - `3` failed roots
  - `12` pending roots
- the failed roots were all:
  - `tau = 0.05`
  - `fit_size = 5000`
  - one each for `normal`, `laplace`, `gausmix`

Failure evidence:

- launcher-level error:
  - `3 nodes produced errors; first error: cannot open the connection`
- warning during failure handling:
  - could not open `pipeline_stdout.log`
- user-reported environment event:
  - disk filled during execution and additional space was freed afterward

Interpretation:

- this interruption is consistent with an abrupt I/O / storage exhaustion event
  during the live run
- it is **not** presently evidenced as a clean model-level numerical failure in
  the completed fits
- the correct recovery path is a continuation wave on the unresolved roots
  rather than discarding the three already-successful roots

Continuation policy:

- preserve the interrupted run as an audit artifact
- reuse the `3` successful roots
- rerun only the unresolved `15` roots:
  - `3` failed
  - `12` pending
- keep the same normalized baseline defaults for the continuation wave
- launch the continuation from a new committed-state run tag with a checked-in
  unresolved-root subset grid

## 12) RHS-NS Continuation Wave Start

Committed-state continuation preflight run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-preflight-20260423-192200__git-ae49a50`

Committed-state continuation launch run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50`

Continuation scope:

- unresolved roots only:
  - `15`
- preserved successful roots from interrupted parent run:
  - `3`

Preflight status:

- focused config test passed
- continuation-grid prepare-only gate passed

Initial live health snapshot:

- snapshot time:
  - `2026-04-23 19:19 EDT`
- selected roots:
  - `15`
- materialized roots:
  - `0`
- successful roots:
  - `0`
- running roots:
  - `0` in summaries yet
- failed roots:
  - `0`
- launcher session:
  - `qdesn_p90_rhsns_resume`
- launcher session live:
  - `TRUE`

Initial interpretation:

- the continuation wave opened cleanly from the frozen committed state
- the unresolved-root subset grid was accepted as an auditable continuation
  surface
- no hard numerical/runtime failure evidence was present at launch time

## 13) Continuation Throughput Re-Optimization

Stopped continuation run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-full-20260423-192400__git-ae49a50`

Why it was stopped:

- the continuation wave was operationally healthy but under-parallelized
- it used only `3` campaign workers on a host with substantial spare capacity
- the unresolved set contained `15` roots, but only `3` replay roots were
  active at once

Host-capacity read at stop time:

- logical CPUs:
  - `64`
- free memory:
  - more than `400 GiB` available
- free disk:
  - more than `240 GiB` available

Optimization changes:

- runner updated to support root-level scheduler selection
- new optimized scheduler:
  - `load_balanced`
- optimized worker count for continuation:
  - `15`
- unresolved-root continuation grid kept unchanged
- model defaults and warmup policy kept unchanged

Committed-state optimized preflight run tag:

- `qdesn-dynamic-p90-steepertrend-rhsns-resume-opt-preflight-20260423-202500__git-0775b5d`

Optimized preflight result:

- focused config test passed
- unresolved-root continuation preflight passed with:
  - `--workers 15`
  - `--scheduler load_balanced`

Decision:

- proceed to an optimized continuation relaunch on the same unresolved `15`
  roots
- use the same baseline inference policy
- use higher root-level concurrency and load-balanced worker scheduling
