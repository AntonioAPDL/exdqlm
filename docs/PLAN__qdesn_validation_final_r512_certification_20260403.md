# PLAN: Final R512 Certification Rerun (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

This is the final certification pass for the QDESN validation program.

We are no longer searching for a better local family. We are freezing
`R512_r412_pass2_chain1000` as the tuned candidate and rerunning the full
dynamic validation matrix end to end so we can answer, in one place:

1. how many roots are healthy and successful;
2. how many method rows are `PASS`, `WARN`, and `FAIL`;
3. how many VB-vs-MCMC comparison pairs are healthy and eligible;
4. how the frozen `R512` campaign compares against the last authoritative
   full dynamic baseline campaign.

## 2) Why `R512` Is The Frozen Final Candidate

`R512` is the best validated tuned result we have produced in the late-stage
branch-facing sequence.

Why it is frozen now:

1. Phase 13 promoted it through Stage 1, rerun confirmation, and final
   zero-sentinel confirmation.
2. Phase 14 did not beat it.
3. Phase 15 found one strong local signal (`R702`) but that signal failed final
   confirmation and did not justify a new promotion.
4. The remaining problem is now too narrow for more broad search waves to be a
   good use of time.

## 3) Why A Certification Rerun Is Better Than More Tuning

The current blocker is no longer infrastructure and no longer broad-family
selection.

What remains is a final validation question:

- does the promoted tuned candidate hold up on the full dynamic matrix and how
  does it compare with the last authoritative baseline?

That makes one frozen certification rerun the highest-value next step because it:

1. closes the loop on the full dynamic matrix;
2. gives final healthy/fail counts on the actual certification surface;
3. produces direct baseline-vs-tuned comparison outputs;
4. avoids another exploratory search cycle with diminishing returns.

## 4) Certification Surface

The rerun uses the existing full dynamic validation grid:

- file:
  `config/validation/qdesn_dynamic_family_prior_grid.csv`
- matrix:
  - scenarios: `dlm_constV_smallW`, `dlm_constV_bigW`, `dlm_ar1V`
  - taus: `0.05`, `0.50`, `0.95`
  - likelihood families: `exal`, `al`
  - beta priors: `ridge`, `rhs_ns`
  - seeds: `123`
  - reservoir profile: `tiny_d1_n8`

Total certification workload:

| item | count |
|---|---:|
| roots | `36` |
| method rows (`vb` + `mcmc`) | `72` |
| pair comparisons | `36` |

## 5) Frozen Defaults

New frozen defaults file:

- `config/validation/qdesn_dynamic_family_prior_r512_certification_defaults.yaml`

Contract:

1. preserve the dynamic scenario set and full-matrix grid contract;
2. preserve the non-DLM readout contract:
   - `readout.input_mode = raw_y_lags`
   - `decomposition.enabled = false`
3. keep `threads = 1` and `postpred_threads = 1`;
4. overlay the exact promoted `R512` inference settings from the promoted
   Phase-13 config, not an approximate reconstruction.

## 6) Runner And Outputs

New orchestrator:

- `scripts/run_qdesn_validation_final_r512_certification.R`

It must do all of the following:

1. preflight baseline paths, grid shape, contract checks, resource snapshot, and
   active-QDESN process snapshot;
2. support `--prepare-only`;
3. launch the full frozen `R512` dynamic campaign;
4. run the existing dynamic healthcheck after completion;
5. generate baseline-vs-`R512` comparison tables and plots;
6. write one integrated certification summary and one machine-readable manifest.

Required outputs:

| output | purpose |
|---|---|
| campaign report root | authoritative tuned certification artifacts |
| campaign results root | authoritative tuned root outputs |
| preflight manifest and markdown | run contract, resource decision, and input validation |
| healthcheck summary | root materialization and success accounting |
| comparison tables and plots | baseline-vs-`R512` deltas |
| integrated certification summary | final closeout decision |
| certification manifest | machine-readable output registry |

## 7) Resource Policy

Server facts at planning time:

- `64` logical CPUs
- `503 GiB` RAM
- light current system load

Run policy:

1. use `threads = 1`;
2. use `postpred_threads = 1`;
3. default to `12` campaign workers when no competing QDESN jobs are active;
4. fall back to `8` workers if other heavy QDESN jobs are running;
5. never exceed `16` workers;
6. disable campaign plots during the rerun for efficiency;
7. generate comparison plots after completion.

## 8) What Defines Done

The certification workflow is done only when all of the following exist:

1. the frozen `R512` campaign completed or failed explicitly on the full matrix;
2. root status counts were written;
3. method `PASS/WARN/FAIL` counts were written;
4. pair `PASS/WARN/FAIL` counts were written;
5. healthy/comparison-eligible counts were written;
6. baseline-vs-`R512` comparison tables were written;
7. baseline-vs-`R512` plots were written;
8. one integrated summary issued one of:
   - `ACCEPT_R512_AS_CERTIFIED_BASELINE`
   - `HOLD_R512_WITH_CAVEATS`

## 9) Exact Acceptance Criteria

`R512` is accepted as the certified tuned baseline only if all of the
following are true on the final certification run:

1. all `36` roots completed with `root_status = SUCCESS`;
2. all method rows completed with `status = SUCCESS`;
3. all method rows remained finite and domain-valid;
4. no RHS collapse regressions were observed;
5. tuned MCMC `FAIL` count is not worse than the authoritative baseline;
6. tuned pair `FAIL` count is not worse than the authoritative baseline;
7. tuned healthy-pair rate is not worse than the authoritative baseline;
8. tuned comparison-eligible pair rate is not worse than the authoritative
   baseline.

If any of those checks fail, the workflow must end with:

- `HOLD_R512_WITH_CAVEATS`

and must state the failing criteria explicitly.

## 10) Guardrails

This workflow must not:

1. reopen exploratory tuning families;
2. create another broad local search matrix;
3. compare against stale or aborted runs;
4. silently hide incomplete or underperforming results;
5. leave the branch dirty after the implementation commit and push.

## 11) Intended Closeout

If the certification rerun is healthy and acceptable, the QDESN validation
effort should be considered complete for this cycle.

If it is healthy but underperforms, the program should still stop broad search,
freeze `R512` as the best known tuned baseline, and carry the caveats forward
explicitly in the certification summary.
