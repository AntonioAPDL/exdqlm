# AutoDESN forensic audit and execution handoff — 25 October 2026

**Decision: pause long fitting in this environment. Use a persistent machine for further production computation, after a small, reproducible diagnostic check. Moving machines will address storage and resource interruptions; it will not by itself resolve the demonstrated posterior instability.**

Audited source/evidence baseline: `8dcbc7fbc7ff0ffafc92b72c208cfa828799b917`, draft PR 5. This is a review of committed code paths, saved numerical diagnostics, resource records, workflow status and the complete package-CI log. It is not a fresh full statistical validation or replay of every large archive. No new inference, forecasts or confirmation data were generated for this audit. [The machine-readable audit](references/audit_20261025.json) identifies the exact evidence/source Git blobs.

## 1. What the evidence establishes

| Question | Finding | Limit |
| --- | --- | --- |
| Is the execution environment a real problem? | Yes: an 8 GiB cgroup limit, an observed disappeared production worker with an OOM-kill increment, disk pressure and repeated automated scratch pruning. | These explain interruptions and lost unpublished work, not the instability of completed uncapped fits. |
| Is the revised main RHS sampler still failing every diagnostic? | No. Four chains at 512k retained sweeps pass the individual screen; the fresh 256k/512k pair passes the registered cross-budget and common-scale checks. | Calibration, independent mode review and predictive Monte Carlo remain open. |
| Are chronological development fits qualified? | No. Both completed F1 first production budgets fail their overall architecture screens. | Common coefficient/scale monitors pass; that does not rescue inconsistent architecture probabilities. |
| Is AutoGP merely waiting to finish? | No. All four native 64 and all four additional-period 32 jobs completed and their exact exports are committed. Both cohorts fail evidence stability. | Job success is not posterior convergence. No favorable run was selected. |
| Have revised out-of-sample forecasts demonstrated improvement? | No full qualified revised comparison has been executed. | Training diagnostics and known-DGP oracle risks cannot substitute for those forecasts. |
| Is the whole R package green? | No. The observed package check reports 152 failures, 50 warnings, 9 skips and 6548 passes, despite 830 scoped assertions passing in source and 830 outside-Git installed assertions. | Attribution to pre-existing problems versus changes needs a clean baseline check. |

Primary records: [memory failure](evidence/F1_parallel_memory_failure.json), [main 512k screen](evidence/F1_production_512000_joint128_recoverable_qualification.json), [256k/512k stability](evidence/F1_production_256000_joint128_recoverable_vs_production_512000_joint128_recoverable_stability.json), [bound fold results](evidence/fold_F1_production_32000_bound_summary.json), [all eight GP exports](references/gp_completion_20261025/index.json), [export audit](references/gp_completion_20261025/verified.json), [whole-package CI](evidence/full_package_ci_680_audit.json).

## 2. Environment failures versus statistical failures

### Confirmed execution limitations

The original full-bank production fork attempt exceeded available headroom under 8589934592 bytes. A short parallel preflight had not established long-run safety. A worker disappeared and the cgroup OOM-kill counter increased. Later policy limited large-job overlap, introduced verified matrix caches, and used bounded, exactly resumable segments.

The completed main 512k run reached 6056349 KiB process-tree PSS, about 5.78 GiB. Its recoverable records cover 12406.35 seconds of process invocation time, about 3.45 job-hours; the first invocation's exit/resource record is unavailable. This is a partial cost, not the entire fit cost or a controlled model-speed measurement. Compilation, loading and serialization are included in process times.

Early memory recording was also defective: the collector missed descendants because the expected Linux children interface was unavailable. Early aggregate process-tree PSS is explicitly invalid. A later PPid-tree collector passed a known-allocation fixture. This was a measurement bug that required correction, not evidence of low memory use. See [measurement limits](evidence/resource_measurement_limits.json) and [execution summary](evidence/F1_512000_execution_summary.json).

The 32 GiB working-storage budget led to repeated cleanup/archival work. Automated workspace maintenance subsequently removed recovery checkouts, local runtimes and uncommitted outputs. This happened again during the current audit: the newly created recovery checkout was unavailable after the pruning event. Committed GitHub files survive; scratch files and unreachable blob uploads cannot be treated as durable deliverables.

The earlier archive 006 has an explicitly incomplete historical prefix. The latest previously committed replay through 025 verified 4687 parts / 8801 members across 24 archives while still recording that incomplete prefix. Newer local 026/027 manifests and the 162-input report were not recovered with a complete upload inventory. They are excluded from claims of recovered committed work. See [recovery record](RECOVERY_20261025.md).

### Completed fits also expose a separate inference problem

The two latest GP cohorts completed without triggering their wall/memory caps. Native 64 final particle ESS is as low as 2.087 out of 64; additional-period 32 reaches 1.190 out of 32. Across the four independent random seeds for each fixed algorithm, evidence estimates span 41.97 and 116.52 log units. Evidence-replica ESS is about 1 in both cohorts, so pooling the estimated unnormalized measures is effectively dominated by one run.

This is evidence of severe computational instability under the tested budgets and transitions. It is not caused by an interrupted final run. These summaries alone do not identify the precise kernel mode, parameter dependence or SMC stage responsible, and are not a universal proof that all predictive means are wrong. They do fail the registered qualification requirements.

The two transition policies are kept separate. Four seeds on one observed series are computational replicas, not four independent DGP realizations. Their evidence-replica ESS is not an MCMC ESS and is not a count of independent forecast pairs.

## 3. What was implemented and what the prior means

The Gaussian ridge default remains available. The RHS implementation is the normalized Gaussian hierarchy, not the separate augmented `rhs_ns` target. For a flat RHS slope,

```
tau = tau0 * u
v_j = 1 / (1 / (tau^2 * lambda_j^2) + 1 / c2)
beta_j | u, lambda_j, c2 ~ Normal(0, v_j)
u, lambda_j ~ HalfCauchy(0,1)
c2 ~ InverseGamma(slab_df/2, slab_df*slab_scale^2/2)
```

The current experiments explicitly use `tau0=0.001`, `slab_scale=1`, `slab_df=4`, so the slab variance hyperprior is IG(2,2). The proper intercept is N(0,10); constant observation variance uses IG(3,1). Coefficient prior variances are independent of observation variance in this model. Public RHS-control defaults differ from these explicit experiment overrides; reproduction must pass the frozen controls.

Neither actual tau nor the slab standard deviation is fixed at its hyperparameter. Global multipliers, locals and slab variance are sampled. In the main 512k saved-state audit, median actual tau is 0.0045 and median slab SD is 1.0353. The fitted hierarchy must not be described as a fixed global scale of 0.001 or a fixed slab variance of 1.

The implementation uses the proper Gaussian coefficient-integrated likelihood for architecture moves and immediately restores matching coefficient draws before coefficient-conditioned updates. Changing readout dimension is handled in a fixed auxiliary space with normalized inactive priors. Architecture/period masses, proposal ratios, Gaussian determinants and finite-slab scale normalizations matter. The optional frozen proposals retain full support; they do not remove unfavorable architectures.

The source review checked these code paths and the documented [target/transition specification](MATH.md), normalized-prior references, dense observation-space Gaussian references, conditional-scale quadrature and production-chain integration tests. Some algebraic tests construct reference transitions; actual transition integration tests are needed in addition. Passing these small-target tests cannot certify the full 426-architecture posterior. This audit is not a new independent mathematical proof of every kernel.

## 4. Standardization, reservoir geometry and expressiveness

The committed [full standardization audit](evidence/full_standardization.json) passes for every one of 426 admitted reservoir readouts, 90 direct lag features, and all 101 candidate calendar periods in each of the two calendar families. Slope means are approximately zero and sample SDs are one over rows 501–2500. Maximum absolute mean is 8.76e-14 and maximum SD error is 6.66e-16. The intercept is exempt; there is no feature-dimension division. Observed reservoir input/response conditioning remains based on the first 500 observations. Chronological folds refit their readout/lag/calendar scalers within their own cutoff.

This does not mean all columns are decorrelated. Reservoir designs remain strongly collinear, with some condition numbers around 1e8. Correlated bases can support many near-equivalent coefficient/architecture combinations and complicate shrinkage and mixing. The saved coupling audit does not establish one global/local dependence as the dominant barrier.

A documentation error was corrected: these frozen deep-reservoir bridges are identities, not fitted PCA. The correction changed no executed reservoir or prior. See [plan corrections](PLAN_CORRECTIONS_20261024.md).

The original reservoir-only family was expanded to F1 with direct lags 1–90. F2/F2flat add Bayesian period averaging over 20–120 and up to 16 harmonics; SV families add conditional volatility after qualified mean selection. This substantially expanded the task. F2 can have 426 × 101 = 43026 architecture/period combinations before considering continuous scales and coefficients. More flexibility can make inference harder.

There is positive evidence that F1 can represent the nonlinear mean. On the 2000 training rows, its saved joint-state average has raw-response conditional-mean RMSE 0.1534 and correlation 0.9696 against known simulation truth. Observed-response training RMSE is 0.4754; the realized innovation RMSE is 0.4604 on those same rows. The audit code explicitly converts posterior means back to raw response units. These are encouraging in-sample diagnostics, not forecast comparisons.

Median 79.7% of standardized-effect slopes are below 0.01 training-response SD and median 5 exceed 0.1 SD. A continuous RHS prior does not create literal point-mass zeros. Small individual slopes in correlated bases do not imply a flat predicted function. The strong conditional-mean fit is evidence against the blanket explanation that shrinkage has erased all signal.

There is also an unresolved warning: descriptive training coverage of the true conditional mean by the 90% latent bands is 54.3%. These bands exclude observation noise and are not predictive intervals. This is an approximation/uncertainty diagnostic requiring investigation; the good mean correlation does not settle calibration.

## 5. Where posterior exploration actually fails

The main F1 fit uses four chains with 128k warmup and 512k retained sweeps. Maximum rank R-hat is 1.000223, the full-trace screen's minimum bulk/tail ESS is 17882.6, and maximum major-category chain-frequency range is 0.01446. The fresh 256k and 512k levels both pass the registered individual screens, 270 shared coefficient/scale monitors, and 71 practical/Monte-Carlo comparisons. The separate common 270 screen has maximum R-hat 1.000883, minimum bulk ESS 7107.7 and minimum tail ESS 6942.2. Thus it is inaccurate to call the entire RHS implementation nonconvergent. It is also inaccurate to call every scientific gate closed.

Earlier chronological folds behave differently:

| Fit cutoff | Retained/chain | Maximum R-hat | Minimum ESS | Maximum category-frequency range | Overall screen |
| --- | ---: | ---: | ---: | ---: | --- |
|1500|32000|1.05220|83.37|0.11059|Fail|
|2000|32000|1.02262|146.51|0.10006|Fail|

These fold results use only 32k retained sweeps per chain, whereas the passing main result uses 512k. This is not a matched-budget demonstration that the prefixes are intrinsically harder, or that a new kernel defect exists. It establishes that the tested fold budgets/proposals are inadequate. Both common 270 coefficient/scale screens pass, while architecture/full-trace screens fail. All six short pilots also fail convergence and are usable only as computational proposal guides. Huge indicator R-hat values in pilot records reflect constant within-chain indicators that disagree between chains; dropping those indicators would hide the failure.

The exact fold-specific mixing mechanism remains unresolved. A guide learned at final origin 2500 cannot simply be transplanted into earlier validation folds: that would use information after the fold's fitting cutoff. The next computational diagnosis must use prefix-specific data and normalized full-support proposals, preserve the frozen target, and inspect model/scale/conditional-mean movement jointly. Blindly doubling every budget or reducing candidate support is not an established repair.

## 6. Forecast difficulty and variance misspecification

The simulated series has nonlinear dynamics and heteroscedastic innovations. A fitted conditional mean need not track every observed fluctuation. A constant-variance F1 likelihood also cannot represent the time-varying observation variance by adding mean features alone. Selected-mean SV qualification is unfinished, so no successful volatility repair is claimed.

A privileged known-DGP/known-state diagnostic used twelve fixed training origins and recursive paths. Its 100k/400k path budgets passed registered precision/stability checks; conditional-risk RMSE is roughly 0.44 at H1 and 0.58 at H30. These are conditional future risks over that training-origin panel. They cannot be numerically subtracted from realized test scores at other origins, treated as a population lower bound, or counted as twelve independent series.

The current evidence therefore supports three distinct statements: there is substantial unpredictable noise; the revised mean has useful training expressiveness; and several inference/uncertainty components remain unresolved. It does not yet allocate the earlier forecast error cleanly among them.

The nonlinear NHS1 series has already been examined during method development. Causal forecasts and training-only transforms prevent within-forecast leakage, but do not undo model-development decisions made after seeing earlier test performance. A redesigned comparison on that series is development evidence; fresh independent confirmation data are required for confirmatory superiority claims. Conditional fixed-design reference tests also do not establish unconditional calibration of a workflow that estimates response-derived readout geometry.

## 7. Workflow mistakes and software risks

I should have stabilized execution and narrowed the diagnostic sequence earlier. Environment limits are not a sufficient explanation for every delay.

- The short memory preflight was overgeneralized to production concurrency.
- The first process-tree memory collector silently missed descendants.
- A PR-event-only workflow query was misread as absence of a push-triggered job, causing a redundant same-seed GP launch. It was canceled and supplies no additional independent replica.
- The pinned AutoGP API's pre-resampling evidence accumulator was initially interpreted as complete evidence. Correct evidence adds the terminal log-mean particle weight. Accounting was corrected before certified pooling or new forecasts; earlier raw statuses remain explicitly labeled.
- The PCA description did not match the executed fixed reservoir bridges.
- Uncommitted report/audit files were not made durable before scratch pruning.
- Multiple static status/report records refer to different checkpoints. “MCMC screen passed” and “scientifically qualified” must stay distinct; the latest execution record must identify what supersedes older observations.
- The study expanded to new readout families, periodic inference, SV, large calibration panels and confirmation requirements before the smaller model/algorithm diagnosis was settled. Much work is reusable, but its accumulated cost and unfinished prerequisites should have been made clearer.

The complete observed package-CI log has 152 failures and one check error. Parsed failure/error records name other Q-DESN/pipeline test files rather than the AutoDESN test-file names. That is useful triage, not proof that all failures are pre-existing or harmless. A same-environment baseline comparison is still needed. The source/installed 830 checks do not resolve package-wide CI.

## 8. What to retain and what not to rerun blindly

Retain the main four-chain 512k fit and its 256k comparator, source snapshots, reservoir definitions/scalers, failed fold fits, every GP replica, exact input/probe/particle files, and failed-check logs. The eight latest GP numerical bundles are already in Git. Their standard-library audit checks hashes, CRCs, target/configuration metadata, exported full-Gen evidence and CSV weights. It does not newly deserialize Julia states; the independent `gp_cohort_evidence.jl` audit is a separate step.

Do not restart the entire benchmark, choose the best GP seed, change tau0 from test outcomes, replace architecture averaging with screening, or interpret the original historical scores as scores from the revised method. No independent confirmation series has been generated. The 471 × 30 forecast pairs are dependent and remain a forecast evaluation design, not 14130 independent replications.

The unpublished phase12 target-binding/Decimal checks and newer PDF need recovery or reproduction before they can be cited as committed verified deliverables. The existing 21-page PDF is an execution checkpoint, not the final scientific report.

## 9. Practical local/persistent-machine handoff

A persistent Linux machine is the simplest fit for the current Linux process/resource wrappers. Based on observed peaks, 16 GiB RAM is a reasonable starting point for one existing large fit at a time; 32 GiB offers more headroom. Reserve 50–100 GiB of persistent working storage for Git history, restored banks, traces, build/dependency caches and checkpoints. These are planning estimates, not benchmarked minimum requirements or permission to run four large fits concurrently. Benchmark memory on the destination before increasing concurrency. No GPU is used by these implementations.

Known runtime references are R 4.5.3 and Julia 1.10.10. AutoGP is pinned at `2ad372db2b8bea176e3b32a769bfb5d6cff80866`, with committed Julia Project/Manifest files. A complete portable R dependency lock and cross-machine resume test are still needed; the former scratch runtimes are not part of the Git checkout.

A safe first local step is only recovery/verification:

```sh
git clone --single-branch --branch feature/autodesn-remediation-20261023 \
  https://github.com/AntonioAPDL/exdqlm.git exdqlm
cd exdqlm
git rev-parse HEAD
python3 validation/autodesn/remediation/verify_gp_completion_exports.py \
  validation/autodesn/remediation/references/gp_completion_20261025/index.json \
  /tmp/gp_export_verification_fresh.json
```

The audit source baseline is 8dcbc7f; record the actual checkout SHA. The verifier requires Python 3.11+ and a previously nonexistent output path. The clone contains multi-gigabyte historical checkpoint payloads; avoid simultaneous duplicate clones/extractions on limited storage.

This is not yet a one-command complete-study handoff. Before a long local run:

1. Install dependencies project-locally and record R/compiler/BLAS/package versions. Re-run the scoped source/installed tests and reproduce the package-CI failure classification against the base branch.
2. Restore archives with their manifests and checksums. Keep the incomplete 006 prefix explicitly incomplete. Do not overwrite immutable sources or original evidence with new invocation outputs.
3. Resolve archived absolute path references and source/cache/RNG contracts through a documented relocation layer. Demonstrate fresh-process continuation parity before claiming exact continuation on another host/version.
4. Give each new run its own persistent output root and immediate durable checkpoint publication. Some existing test/audit drivers have fixed output paths; they require care to avoid replacing the original evidence. The 7,200-second R and 6.4GB-anon launcher caps also remain explicit even on a larger host; any resource-policy change must be recorded.
5. Reproduce a small target and one completed diagnostic first, then investigate one failing chronological-fold/GP mixing case at a time. Inspect structural movement, scales and training predictive quantities before selecting a fixed larger production budget.
6. Only after mean/variance inference and predictive Monte Carlo qualify, run the complete frozen forecast evaluation and then independent confirmation/stress studies.

Long fits are paused here. No full benchmark, new posterior superiority claim or final scientific PDF is represented as complete.
