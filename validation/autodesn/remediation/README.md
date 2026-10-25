# AutoDESN remediation execution

This branch implements the approved plan in `../nonlinear_heteroscedastic/plans/REMEDIATION_PLAN.md`. The original NHS1 benchmark and audit remain immutable references. Work begins at `fea371fbfa73c425a6f98407095194c1e8098a24` on a separate feature branch.

**Current status:** implementation and training-only development. No new model is scientifically qualified and no confirmation outcomes have been generated or inspected. Passing numerical tests and running short pilots do not establish posterior convergence. See `execution.json` and actual evidence files; a script's presence is not evidence it ran.


**25 October 2026 recovery update:** Both previously active GP cohorts have now
finished. All eight exact remote numerical exports were re-imported and verified.
Native 64 evidence range 41.9723/effective replicas ≈1; additional-period 32 range
116.5187/effective replicas ≈1. Both fail stability; no new forecasts qualify.
See [RECOVERY_20261025.md](RECOVERY_20261025.md) and the independently rechecked
`references/gp_completion_20261025/` bundles. This latest record supersedes older
running-job observations below. The former uncommitted phase 12 report/audits
were unavailable after workspace loss and are not claimed recovered or published.

Latest previously committed checkpoint (25 October 2026 UTC): all four F1 RHS chains at
512,000 retained sweeps are complete. The fresh 256k/512k levels both pass
individual convergence/architecture-precision screens, all 270 common lag/scale
monitors, and all 71 registered practical/Monte Carlo comparisons. This closes
the F1 two-budget MCMC gate; independent calibration/mode review, predictive
Monte Carlo qualification and scientific promotion remain open. The latest
matching 8192-state training audit gives conditional-mean RMSE about 0.1534 and
correlation 0.9696. These are training diagnostics, not forecast scores.

Both full chronological prefix banks are verified. All six short four-chain
pilots complete but fail convergence, so there is no qualified selected mean.
The privileged known-DGP/state forecastability panel passes 100k/400k path
precision/stability checks, with conditional-risk RMSE about 0.44 at H1 and0.58
at H30 on twelve fixed training origins. Those risks are not realized heldout
scores and must not be compared numerically to models scored at other origins.
All four additional-period GP16 runs finish but still fail evidence agreement
(range 86.858 log units, effective replica count 1). Native 64 and additional-
period 32 cohorts have actual workflow observations; see their timestamped live
observation files. A duplicate same-seed launch was canceled and is never
counted as an independent cohort.

`remediation_checkpoint_023` preserves the final 512k results, new diagnostics,
all six completed pilots and their immutable executed sources. Its full replay
verifies 4369 parts and 8675 members through 22 archives; the old 006 prefix remains
explicitly incomplete. Only hash-verified redundant observation copies and
abandoned serialization fragments were pruned to stay within the 32 GiB disk;
canonical final and resumable progress states are retained. See the cleanup
receipts and archive ancestry for exact identities.


Recovery checkpoint `4f0d36c4` restores all four original joint128k RDS files,
reconstructs its missing CSV export, and reproduces its failed architecture
screen. Source and installed suites now include 478 assertions (including within-chain recovery), with zero
failures/errors/warnings and an installed run outside Git. The cold original
builder reproduces all three conditional-bank identities and the exact compact
forecast-map bytes. The original source-bank serialization hash differs because
its provenance metadata changed; it is not relabeled as the original file.

`autodesn_cache_statistics(augmented, max_bytes = 512 * 1024^2)` optionally
caches fixed unweighted cross-products within a numeric payload bound. It keeps
all architectures/periods available; uncached pairs are evaluated on demand.
It preserves the bank identity and all posterior transitions. Weighted SV
cross-products are recomputed when observation variances change. Three paired
full-bank 500-warmup/2000-retained runs reproduce all recorded states, probes,
and architecture summaries bit for bit; median elapsed time is 49.976 s without
the cache and 30.306 s with it, plus 1.859 s construction. These are short
computational benchmarks under concurrent calibration load, not whole-study
speedups or new forecasting results.

`prepare_statistics_cache.R F1 OUTPUT` reconstructs that computational cache.
`launch_fit.py ... --statistics-cache PATH` verifies its bank identity and
records the file checksum before fitting. The registered fresh256k run uses
two workers per invocation, preserving the original proposals and diagnostic
gates. All four chains and the successive-budget checks remain required.

## Implemented opt-in API

```r
bank <- autodesn_build_bank(y_train, candidates,
  conditioning = 30, washout = 500,
  standardize_features = TRUE, normalize_features = FALSE)
augmented <- autodesn_extend_bank(bank,
  readout_control = list(lags = 1:90, prior = "grouped"),
  seasonal_control = list(periods = 20:120, harmonics = 16))
fit <- autodesn_fit_bank(augmented,
  beta_prior = "rhs",
  rhs_control = list(tau0 = 0.001, slab_scale = 1, slab_df = 4,
                     interweave_global = TRUE),
  model_control = list(save_draws = 2048),
  variance_control = list(type = "sv"), seed = 123)
```

The example uses default illustrative inference budgets, not a qualified experiment. Direct `autodesn_fit()` accepts `readout_control`, `seasonal_control`, and `variance_control` as opt-in arguments. Existing default ridge/RHS paths are preserved.

Period and reservoir indices have proper independent prior masses. Every period remains in the declared support. The proper intercept variance is independent of observation variance. Flat RHS applies to all slopes; grouped RHS has separate lag/reservoir global scales and a proper Gaussian calendar prior. Normalized finite-slab local updates, slice updates and coefficient-collapsed architecture/period moves retain all Gaussian determinants. Frozen general-dimensional Student-t independence proposals include exact Hastings corrections; they are never priors.

`model_control$save_draws` bounds coefficient/local-scale checkpoint storage while retaining every scalar/functional trace in `fit$trace` and `fit$probes`. `fit$draws` matches saved joint coefficient states exactly. Diagnostic occupancy uses all retained draws. This avoids retaining gigabytes of full coefficient vectors. It is a storage choice, not architecture screening.

`autodesn_readout_coefficients(fit, draw_index)` transports matching draws to original predictor/response coordinates, including all intercept corrections. Its help specifies the lag, reservoir and calendar coordinates. It keeps different readout dimensions separate. Group norms and conditional group EDF are monitored in the scalar trace; conditional EDF is a Gaussian-step quantity rather than a selected-variable count.

`autodesn_extended_local_proposal()` defines an optional exact reservoir-local scale proposal. The prior component has positive mass for every architecture; all active-vector density constants and inactive prior terms are retained in its collapsed Hastings ratio. Reservoir auxiliaries and then coefficients are restored before conditioned updates. The mathematical derivation is in `MATH.md`. This computational option does not modify `tau0`, slab controls, architecture priors or the likelihood. It is disabled unless explicitly supplied and is not a qualified full-bank repair merely because its small-target tests pass.

Forecast with `forecast_paths(fit, H, draw_index = ids, inner_paths = K)`. For SV, initialize `autodesn_filter(fit, ids, particles = N)`, then use the filter explicitly. After issuing a forecast, append actual observations with `autodesn_update_history()` and update the matching conditional filter using `previous`. The new observations never reweight static parameters/architectures. Filters check static-draw identity and history prefixes. Initial filters replay the scored training block under each static draw; cloning a single terminal state is not used.

Both complete `H_all` and recovered compact `H_last` terminal-state formats are supported. A pre-forecast integration audit caught the original augmented adapter's empty-state handling for `H_last`; it was corrected before any new benchmark forecasts. Forecast-map identities are separate from conditional-posterior identities, and conditional filters check the actual selected propagation maps. `compact_templates.R` can recover exact numeric forecasting maps while dropping unused construction closures; read its actual completion/parity evidence before using an output. Its full-bank invocation requires low measured anonymous memory and must wait until the large inference job ends.

Fitted mean functions and constant-variance fixed-design predictions are available. Set `variance_control$save_state_paths=TRUE` to retain latent smoothing paths at bounded joint checkpoints and enable conditional fixed-design fitted replicates. With that option disabled, SV fitted replication is explicitly rejected rather than silently substituting filtered variances. These replicates condition on the observed training design; unconditional recursive PPC and its data-adaptive preprocessing require separate calibration. Causal recursive SV forecasting is supported.

## Execution and provenance

Use the project-local environments recorded in the parent `ENVIRONMENT.md`. Compile `src/autodesn_rhs.cpp` using `Rcpp::sourceCpp()` for source-only runs. Installed builds use the registered Rcpp wrappers. No global/system installation is needed.

- `test.R`: independent numerical/small-target tests.
- `preflight.R F1|F2|SV`: full 426-reservoir training-only feasibility pilots, with source identities captured before loading.
- `launch_fit.py FAMILY pilot --workers 1`: immutable complete-source snapshot, four dispersed 1k-warmup/2k-retained pilot chains and a frozen full-support proposal. Do not edit or launch a live streaming R driver directly.
- `launch_fit.py FAMILY production 32000 --workers 1`: four fresh 8k-warmup/32k-retained chains using the frozen proposal. Higher declared budgets have separate directories. Use `--snapshot KEY` to resume missing complete-chain artifacts under the same immutable source contract; partial chains restart from their recorded seeds.
- `qualify.py FAMILY PHASE`: independent rank/bulk/tail and architecture/period-frequency screens; cross-budget qualification remains separate.
- `cross_budget.py FAMILY LEFT RIGHT`: independently screened successive fresh-budget comparison, fixed training-probe means/predictive SDs and major architecture/period masses. Its result alone cannot authorize forecasting.
- `gp_moves.jl`: native-target period-coordinate independence moves with full proposal corrections.
- `test_gp_moves.jl`: native trace score/update and detailed-balance checks.
- `run_process.py`: observed subprocess completion, actual exit status, runtime caps and measured resource scopes. `test_resources.py` checks aggregate descendant memory and wall-cap handling. Only one large job runs at once; four workers are allowed only with the exact matrix/augmentation cache that passed the longer four-worker memory preflight. The earlier full-bank fork failure remains recorded.
- `launch_sbc.py`: immutable fixed-design ridge/RHS calibration, with atomic per-replication checkpoints and explicit retained budgets.
- `test_sv_references.R` and `test_gp_reference.jl`: independent small-state conditional references.
- `benchmark_kernel.R` and `benchmark_forecast.R`: paired synthetic computational benchmarks, separately labeled from full fit/forecast runtime.
- `grouped_prior_integration.py`, `check_grouped_reference.py`: independent normalized-prior integration versus four full conditional fixed-local grouped-RHS chains.
- `local_prior_integration.py`, `local_reference.R`: seven-dimensional normalized-prior integration and learned-local sampler reference, including the optional exact local proposal. Check actual output before claiming agreement.
- `sv_joint_reference.py`, `sv_joint_mcmc.R`, `check_sv_joint_reference.py`: full two-response SV posterior comparison, distinct from the scalar conditional tests.
- `gp_leaf_prior_integration.py`, `launch_gp_leaf_reference.py`, `check_gp_leaf_reference.py`: complete native depth-one leaf grammar with all continuous parameters/noise learned, compared against independent normalized-prior integration. Nine quantities pass; maximum R-hat 1.00051 and minimum tail ESS 4487. This does not qualify the depth-four SMC.
- `launch_gp.py --rows 2000 --particles 16 --seed SEED --period-moves 0 --julia PATH --project PATH --depot PATH`: immutable native-moves-only full-size experiment before the separately registered `--period-moves 10` intervention. Native project/depot paths are explicit. Stage checkpoints, actual source/data identities and training-only predictive probes are saved. Successful 128-row feasibility runs are not full-size inference.
- `launch_recursive_sbc.py`, `assemble_recursive_sbc.R`: independent-prefix frozen-map generative calibration and identity-checked computational recovery. The completed constant-variance 200-case batch has one ESS-selected case recomputed at 96k; all monitored ESS values then exceed 400 (minimum 643.47) and ranks pass. The replication count remains 200. The 200-case SV batch has no conclusion until its aggregate exists.
- `score_forecast.R`, `test_scoring.R`: already-issued forecast scoring; analytically integrated current Normal innovation for means/densities/quantiles and an exact sorted-sum distinct-outer CRPS correction. Synthetic analytic/direct-pair tests pass. No production forecasting is authorized by these unit checks.
- `test_quantile_diagnostics.py`: analytic predictive-quantile and MCSE checks for the supplementary cross-budget training-probe quantiles; recursive predictive Monte Carlo qualification remains separate.
- `archive_checkpoints.py`: SHA256-verified split archives of bank-free numerical artifacts and recorded immutable source snapshots.

All fit caches include a target/source/data contract. An unchanged bank is referenced rather than copied into every checkpoint. Compact checkpoints require reattaching the deterministically reconstructed matching bank and verifying `extension_id`.

The original bank contains large reservoir-construction environments not needed by inference. `make_inference_cache.R` and `cache_extensions.R` remove those environments without changing matrices, model masses, frozen transforms or target identifiers. Cache and original-bank checksums are verified before use. The cache intentionally cannot forecast: attach the matching original reservoir objects. Completed original and cached 32k chains 2 and 4 reproduce common traces, coefficients, locals, volatility records and fitted probes bit for bit. The four-chain cache preflight measured aggregate PSS 4,838,922 KiB and environment anonymous memory 5,633,073,152 bytes; the launcher enforces a 6.4 GB anonymous-memory cap.

Full Bayesian production qualification, recursive/SV calibration, GP higher-budget independent runs, independent confirmations, complete predictive/runtime sensitivity and the final scientific comparison remain outstanding until their outputs and gates confirm otherwise. The PDF execution report records actual progress and failures. Existing timing extrapolations are feasibility estimates, not completed budgets or running background work.

The first 200-case RHS SBC falls inside its simultaneous rank envelope, but 136 cases have spectral ESS below 400 (minimum 66.5). A completed fresh 24k-retained posterior calculation on the same 200 conditional cases resolves that computational limitation: simultaneous rank envelope passes, minimum monitored spectral ESS 1080.79, no cases below 400. Its `tau0=0.2` small conditional target is distinct from production's `tau0=0.001`. Both four-chain training pilots fail the production screen. F2 found period 60 in all four chains but exhibits severe reservoir-mode disagreement. Its launcher also failed after all four checkpoints were saved; the checkpoint validation and failed invocation record must be read together. No new accuracy or superiority claim follows from these runs.

The completed F1 baseline 32k and 128k runs and the reservoir-local 32k trial remain unqualified. At 128k the maximum R-hat is 1.00242 and minimum ESS 990, but the largest chain depth-frequency range is 0.05277. A training-only registered joint scale/local repair therefore proposes noise/global/slab scales together with architecture and reservoir locals. It retains every density factor and all candidate support. Its independent learned-local seven-dimensional reference passes all twelve functionals. Activate it only with both a frozen `joint_proposal` and local proposal and `model_control$local_scale_proposal=TRUE`; see `MATH.md`. Fresh runs, two individually qualified budgets and cross-budget stability remain necessary.

The completed joint-policy 32k run has maximum R-hat 1.00682 and minimum ESS 1033, but its major-category MCSE and chain-frequency ranges still fail. The joint policy also refreshes training-only proposals; the ESS difference does not isolate the effect of one kernel. Its fresh 128k followup uses the same immutable source and frozen proposals. Check actual resource/qualification files before inferring its status. The latest launchers use a nonblocking process-held reservation to serialize large jobs while their observing manager is alive; this is not a persistent queue and does not replace resource caps or checking for orphaned processes after failures.

All 426 compact numeric propagation maps have now been recovered and checked against the original maps in both backends; the last training-feature error is at most 1.8e-13. `load_forecast_bank.R` reattaches these verified maps to the exact inference cache. The cache alone remains invalid for forecasting. `test_forecast_bank.R` passed controlled manual recursion and observed-update checks without issuing a posterior benchmark forecast.

Forecast simulation now batches paths with a common reservoir/period, preserving their coefficient, noise and conditional-state assignments. In a synthetic reservoir-64/H30/192-outer/8-inner paired benchmark, median time changed from 2.359 s to .285 s with maximum path difference below 1e-13. This is a kernel comparison under concurrent training load, not an isolated whole-study speedup.
# Recovery of long augmented chains

`autodesn_fit_bank(..., checkpoint_control=list(path="chain-progress.rds",
every=4000L))` records all Markov variables, auxiliary scales, retained joint
draws, probes, counters and RNG state at completed sweep boundaries. The same
call with `resume=TRUE` continues the original budget and thinning schedule;
it does not restart burn-in or add independent chains. The target, transition
controls, source identity, runtime and RNG convention must match. Use one
writer per path. Checkpointing currently supports the default
Mersenne-Twister/Inversion/Rejection RNG; Box-Muller has hidden cached state
and is explicitly rejected. Legacy ridge and reservoir-only APIs retain their
existing behavior; recovery is opt-in for augmented banks.

For compiled recovery, pass a SHA256 `source_id` for externally verified C++
source. The immutable experiment launcher does this using its recorded source
manifest. Checkpoint identity additionally hashes the R algorithm, the full
budget, runtime and thread settings. Payload checksums detect accidental
corruption, and same-directory renames publish complete files on POSIX.
Temporary files are not recovery inputs. A bounded `stop_after` is an absolute
sweep and raises `autodesn_checkpoint_pause`, never a completed fit. The
experiment launcher records such a segment as exit-zero but posterior
incomplete, with no forecast authorization. Segment resource records, including
failed/interrupted invocations, remain separate; saved sampler elapsed time
cannot account for work lost after its last checkpoint.

The fresh-process recovery check exercises learned grouped RHS scales, joint
local/scale proposals, seasonal SV and C++ in separate operating-system
processes. It compares every recorded state with an uninterrupted run. These
are reproducibility checks, not posterior convergence evidence.

The latest training-only audit verifies centering and unit sample SD in the
actual inference Gram matrices for all 426 readouts and all calendar variants.
The first individually passing F1 256k level also passes all 270 common lag
coefficient/log-local/log-prior-variance monitors. Its descriptive true-mean
training RMSE is 0.1534, versus realized innovation RMSE 0.4604. Latent-mean
90% bands cover only 54.35% of the known training mean, so remaining mean
discrepancy must still be investigated. None of these checks qualifies forecasts.

All four full-size native GP16 runs are verified complete. They fail the
mode/budget review: corrected log-evidence estimates span 365 log units and
their evidence-weighted effective replica count is essentially one. Native
AutoGP at the pinned revision reports only the pre-resampling accumulator via
`log_marginal_likelihood_estimate`; use `gp_evidence.jl` to add the final
log-mean particle weight, matching `Gen.log_ml_estimate`. The registered pooling
addendum documents the correction before any forecasts. Independent QMC versus
64 SMC replicas per arm passes all ten small-target unnormalized-measure checks;
it does not qualify depth-four production SMC. See the updated checkpoint PDF
and `execution.json` for completed work and remaining gates.


`autodesn_cache_calendar_blocks(bank, max_bytes=128*1024^2)` is an optional
shared-statistics cache for the calendar models. All architecture/period pairs
retain support. In three alternating-order short full-bank runs, median sampler
time was21.671s direct and13.546s with blocks, plus4.897s cache preparation.
These are computational trials under concurrent load. The first strict
component-relative trajectory comparison failed and is retained. Thirty-eight
same-hyperparameter Gaussian laws, including independent dense likelihoods,
agree to the recorded tolerances; reordered sums do not promise bit-identical
trajectories. Exact recovery now binds the actual cache contents. Identical
partial-cache grouped-RHS/seasonal-SV/C++ recovery passes across four fresh
processes. Source and outside-Git installed scoped suites each pass800 assertions.
The older source snapshots remain necessary to resume their original contracts.

The two large derived block-cache files have identical SHA256 in independent
processes. They are excluded from the bank-free archives; if needed, recreate
one with `Rscript validation/autodesn/remediation/restore_calendar_cache_derived.R 1`
after restoring/rebuilding the original inference-bank inputs. Its SHA256 is
checked before publication. Fitted benchmark states and executed sources are
archived separately.

`launch_prefix_bank.py 1500` and `launch_prefix_bank.py 2000` rebuild every
original candidate from the corresponding response prefix, refit readout
scalers, verify compact transitions/terminal features and save full-support
inference/forecast inputs. They require the large-job reservation. Preflight is
complete; the full fold banks have not yet been executed at this checkpoint.
Their narrow reference contains only seeded maps and first500 input transforms,
without the original terminal states or response history.

The completed chronological-prefix preparations are recorded in
`evidence/prefix_bank_1500.json` and `evidence/prefix_bank_2000.json`. They retain
all426 admitted architectures, use the frozen NHS washout tolerance0.001, and
refit readout/lag/calendar scalers inside each training boundary. The failed
first adapter attempt used the helper default0.00001 and was rejected before
inference; its audits, failure and cleanup inventories remain available.
Preparation is reproducible with `launch_prefix_bank.py CUTOFF`. Large derived
matrix caches are excluded from the bank-free checkpoint archives; their exact
file and conditional-target hashes, original builder and complete numeric map
reference are retained. Raw construction and serialization intermediates can be
removed after final bank/map/cache hash checks. No posterior checkpoint is
removed by these cleanup helpers.

`launch_fit.py --prefix-manifest PATH` isolates each fold's fits and frozen
proposals under `artifacts/fold_fits/cutoffCUTOFF`. The ordinary pilot/production
budgets and sampler are unchanged. `--input-preflight FRESH_JSON` validates the
full inputs without running inference. Both completed full-bank input preflights
and both426-model forecast-map binding checks are recorded separately; these
are not completed fold fits or validation forecasts.

New SV runs require `--mean-selection CERTIFICATE`. The certificate must bind
both qualified chronological development folds and their unchanged input hashes.
The selected F1/F2/F2flat readout is retained. In particular, F1 with seasonal
volatility uses `autodesn_seasonal_control(periods=20:120, harmonics=0)`:
periods are averaged for the four variance harmonics without adding any mean
calendar coefficients. The normalized period prior integrates to one when its
mean likelihood is period-independent. The830-assertion source and outside-Git
installed regressions,30 variance-only checks and separate certificate fixtures
pass; no production SV selection or fit has been completed.

The four completed native32-particle AutoGP outputs are imported with checked
member hashes and gzip CRCs. The complete serialized-state evidence audit agrees
with `Gen.log_ml_estimate` and finds a222.4485 log-evidence range and effective
number of evidence-weighted replicas1. This budget fails computational
qualification. The64-particle control is explicitly registered in
`remote_gp_requests/budget64.json`; check the actual workflow/status records
before asserting that it started or completed. Its14400-second process cap is
registered before64-particle outcomes. The additional invariant-period cohort
remains a separate algorithm policy and is never pooled with native controls.

The postprocessing helpers accept isolated fold directories and evidence roots.
`launch_checkpoint_validation.py` freezes its R validator before checking every
RDS/status/contract identity, exported scalar trace and fitted probe, and joint
coefficient/local-state index. `cross_budget.py` requires the complete input hash
set again, including architecture metadata. Existing smaller audit records can
be extended non-destructively with `supplement_metadata_binding.R`; the original
record is retained and hashed. The35 mutation/path/missing-gate fixtures pass,
and explicit/default-directory diagnostics agree exactly on the old F1 pilot.
The common 270-coordinate monitor now applies to every RHS mean family with the
same90-lag block. On the existing F2 pilot it correctly fails the convergence
screen (minimum ESS about11); it does not promote that pilot. Early pilot files
without response-SD display metadata retain their fitted response units, a
fixed positive rescaling that cannot change rank R-hat or ESS. SV cross-budget
latent-variance checks remain unresolved and cannot be replaced by constant-noise
predictive checks.

`launch_oracle_forecastability.py` executes a separate privileged known-DGP,
known-origin-state audit on12 frozen training origins. It simulates responses
recursively without observed futures. The100k/400k independent-path budgets
pass the registered individual MCSE and successive-budget checks;25k fails its
precision screen. Scalar continuation, future perturbation and analytic horizon1
checks pass. The oracle conditional RMSE floor over this panel is about0.44 at
horizon1 and0.58 at horizon30. These are conditional expected risks, not realized
held-out scores or independent series replications; they cannot be numerically
compared with candidate RMSE at different origins. No model prior or
hyperparameter is changed. The DGP's GJR leverage is also more specific than the
current independent-innovation log-SV family; seasonal SV should be assessed as
an approximation, not described as the exact DGP variance mechanism.


Workflow observation must include push events. The connected
`fetch_commit_workflow_runs` wrapper filters to pull-request events and cannot
establish absence of a push-triggered calculation. Use the full Actions run
collection with the exact head SHA, or inspect a known run ID. See
`gp32_period10_duplicate_cancellation.json` for the corrected observation and
the exact canceled duplicate; identical seeds are never extra replications.


The first production fold budgets are also preserved: cutoff 1500 and cutoff 2000
F1, each with four chains, 8k warmup and 32k retained. Both raw checkpoint
validations and common 270 screens pass, while overall architecture/full-trace
screens fail (minimum ESS 83.37/146.51; max R-hat 1.0522/1.0226). Reproduce their
bound summary from the repository root with
`python3 validation/autodesn/remediation/summarize_fold_budget.py --output NEW_JSON`.
No selected-mean certificate or new forecast is implied.

Archives 024/025 add those two complete budgets, all prefix common-coordinate
monitors and two verified native 64 replicas. Latest full replay verifies 4687
parts and 8801 members through 24 archives, including the one old incomplete
prefix. Native 64 seeds 7366322/7366323 are imported; two other native 64 jobs and
all four additional-period 32 jobs were observed fitting. Check the timestamped
observation files. Completed local inference invocations have observed exit-zero
records; no local MCMC job is represented as continuing.
