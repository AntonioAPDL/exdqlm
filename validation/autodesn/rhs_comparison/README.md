# C1: Gaussian AutoDESN ridge, regularized horseshoe and AutoGP

This harness compares the original ridge readout with the independent regularized horseshoe (RHS) readout on the **same frozen C1 experiment**. It retains the existing `c1_comparison` inputs and adapters. The original experiment is not edited. RHS inference runs fresh; audited original ridge and AutoGP outputs may be imported with explicit provenance and reuse flags.

Run commands from the repository root. This harness sources the checkout directly and compiles only `src/autodesn_rhs.cpp` when the RHS C++ backend is requested. It does not require installing the full package. R, a C++ compiler, `testthat`, `jsonlite`, `digest`, `coda`, `Matrix`, `Rcpp`, `RcppArmadillo`, `RcppEigen`, `BH`, `matrixStats` and `RSpectra` should be available. Python requires NumPy, SciPy, pandas and matplotlib. Put a conda runtime's `bin` directory on `PATH` as well as calling its `Rscript`, so its compiler can be found.

## Frozen experiment

| Item | Full benchmark |
|---|---|
| Series | Existing C1, 3,000 observations; original source `f397cdcd6df66e13f012bfbd3d299417708dfc24` |
| Reservoir conditioning and washout | Observations 1–500 |
| Scored training responses | 501–2,500; exactly 2,000 rows |
| Test responses | 2,501–3,000; exactly 500 rows |
| Rolling origins | 2,500–2,970 inclusive; 471 origins |
| Forecast leads | 1–30 at each origin; 14,130 origin/lead pairs per model |
| Candidate specifications | Exact saved 456 specifications, including reservoir seeds and depth prior |
| Admission | Original initial-state washout test, maximum error ≤0.001; the original bank admits 428 |
| Feature scaling | Original bank normalization and conditioning-period preprocessing, held fixed |
| Main simulation budget | 192 joint posterior draws ×8 innovation paths =1,536 paths per origin |
| Posterior checkpoint | 384 jointly sampled draws, preserving architecture, coefficients and variance |
| Common innovations | Exact original `c1_noise` mapping, seed 1,066,020, shared by ridge and RHS |
| Refit / posterior weight update | Neither occurs after time 2,500 |

`configuration.json` pins the original input SHA256 hashes. Every runner checks them before using the inputs. The feature builder checks each saved specification, preserves the original depth-balanced prior after admission, and saves an audit of every candidate. It persists each completed candidate so that an interrupted build can resume.

### What changes with RHS

The observation model remains the homoscedastic Gaussian conditional-mean readout. The reservoir features and original feature coordinates are unchanged. The RHS prior replaces the learned common ridge precision for slopes with local shrinkage, a global shrinkage scale and a finite slab. The intercept retains its own Gaussian prior. Noise variance retains the same inverse-gamma prior. The new prior is independent of noise variance.

The frozen controls are `beta_prior="rhs"`, `rhs_control=list(tau0=1, slab_scale=2, slab_df=4)` and `model_control=list(method="mh", moves=2)`. The implementation uses collapsed architecture moves with exact Gaussian coefficient integration at the current shrinkage scales. Three chains start from dispersed architecture indices, noise variances and global scales. Initial values do not change the target prior. No control is selected using C1 test outcomes. The full sweep schedules are fixed in advance: 2,000 burn +6,000 retained, then 4,000 +16,000, then 6,000 +32,000 if a preceding attempt fails its screens. Attempts are independent new fits with distinct fixed seeds, not continuations or pooled failed runs.

### What updates at each rolling origin

All posterior draws and their model weights remain fixed. For DESN, reservoir states advance using the observations that have become available since the preceding origin. At origin `o`, a trajectory predicts targets `o+1` through `o+30`. It holds its sampled architecture, coefficients and noise variance fixed throughout that path; it feeds back its own simulated responses. It never receives the future observed responses during that forecast. `y_future_obs` is used only by the existing one-step state adapter when advancing to an already observed origin.

For GP, each trained particle's Gaussian predictive distribution is conditioned on the observed test prefix. Kernel parameters and particle weights stay fixed. Thus the comparison deliberately uses frozen mixture weights even though a full Bayesian sequential update could change those weights. The native Julia checks compare this conditioning with the authors' implementation at three origins.

## Run the contracts and smoke orchestration

```bash
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript --vanilla validation/autodesn/rhs_comparison/test_contracts.R
python -m unittest discover -s validation/autodesn/rhs_comparison -p test_contracts.py -v
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --mode smoke --method ridge
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --mode smoke --method rhs --backend cpp
python validation/autodesn/rhs_comparison/report.py --mode smoke
```

Smoke mode uses two small reservoirs, 80 training rows, three chains of 15 burn +40 retained sweeps, six origins and five leads, with 12×2 paths. It tests execution, pairing, causal state transitions, export, independent scoring and aggregation. Every smoke status and chart is explicitly unqualified. Numerical smoke scores must not be interpreted as benchmark performance, and the full aggregator rejects them.

The R contracts check agreement with the production recursive forecasting API under both priors, agreement of incrementally updated states with rebuilt states, invariance to unobserved future responses, paired coefficient/variance draws, origin/target alignment and common-noise nesting. The Python contracts independently check the mixture CRPS against numerical integration, sample CRPS against its pairwise definition, sequential GP conditioning, malformed score rejection and full/smoke separation.

## Full fresh RHS with audited original baselines

```bash
# Build once. The same bank is shared by ridge, RHS and training-only pilots.
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --stage build --mode full

# Optional: short, explicitly unqualified mixing/timing pilot on training data.
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --stage fit --mode pilot --method rhs --backend cpp

# Import the original audited results from an extracted C1 results directory.
python validation/autodesn/rhs_comparison/import_baselines.py --from /path/to/c1_results

# Full inference must pass the frozen gates before forecasting proceeds.
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --mode full --method rhs --backend cpp

# Optional, separate from the primary run: the original 24 MC sensitivity settings.
Rscript --vanilla validation/autodesn/rhs_comparison/sensitivity.R --method rhs

python validation/autodesn/rhs_comparison/report.py --mode full
```

The import checks the frozen source revision, original ridge convergence tables, exact score alignment, complete GP native checks and fixed-weight statuses. It hashes all used source evidence, copies the raw ridge path samples for an independent re-audit, and records `reused=true`. The original ridge sensitivity table is also retained. RHS cannot be imported by this tool. New inference refuses to overwrite an imported baseline.

Training-only pilot mode defaults to 100 burn +200 retained sweeps in each of three chains. It permits `--n-burn` and `--n-mcmc` overrides and writes to `artifacts/pilot`; these overrides are forbidden in full mode. Pilots save diagnostics, sampler counters and timing without creating benchmark forecasts. A different pilot configuration or source version requires a different `--out` directory. A pilot is not evidence that the full chain has converged.

### Optional fixed proposal based on training output

If the original prior-proposal MH chain explores the 428-model bank inefficiently, `run_with_proposal.R` can freeze a computational proposal from a completed training attempt. It uses `q = 0.1 × original prior + 0.9 × mean training occupancy`. Every architecture retains positive proposal mass, and the production sampler keeps the exact Hastings correction. This changes computation, not the prior or likelihood. Proposal probabilities are fixed before the new chain starts. The script verifies bank/candidate alignment, checks the source attempt's training interval and input hashes, and records its source file hash and proposal vector. Test outcomes and forecast scores are not used.

```bash
Rscript --vanilla validation/autodesn/rhs_comparison/run_with_proposal.R \
  --proposal-from validation/autodesn/rhs_comparison/artifacts/full/rhs/attempt_1/model_probabilities.csv \
  --method rhs --backend cpp --out validation/autodesn/rhs_comparison/artifacts/training_proposal
```

This is an explicit alternative run. Its output directory must be supplied, and source guards prevent mixing it into the original run. Failed original-chain evidence must be retained and its computational cost disclosed. The proposal provenance and comparison audit separately record completed source-attempt inference time; the new run's inference timer does not include that tuning cost or unrelated pilots. The original default runner and workflow continue to use the original prior proposal. Use the same wrapper and proposal source to resume this alternative or forecast from its checkpoint. Its full chains still have to pass all unchanged gates; a proposal improvement does not authorize lowering them.

### Fresh ridge and fresh AutoGP

Use another output directory if original baselines already exist in the default one:

```bash
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --method ridge --out validation/autodesn/rhs_comparison/artifacts/fresh
Rscript --vanilla validation/autodesn/rhs_comparison/run.R --method rhs --backend cpp --out validation/autodesn/rhs_comparison/artifacts/fresh

git clone https://github.com/probsys/AutoGP.jl /tmp/AutoGP.jl
git -C /tmp/AutoGP.jl checkout 2ad372db2b8bea176e3b32a769bfb5d6cff80866
julia --project=/tmp/AutoGP.jl -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
python validation/autodesn/rhs_comparison/run_gp.py --project /tmp/AutoGP.jl --out validation/autodesn/rhs_comparison/artifacts/fresh
python validation/autodesn/rhs_comparison/report.py --out validation/autodesn/rhs_comparison/artifacts/fresh
```

The GP launcher verifies the pinned checkout and refuses tracked source modifications. It runs the unchanged original Julia script in an isolated workspace, so the original benchmark directories are not used for outputs. It uses Julia 1.10.10, AutoGP 0.1.19, two independent eight-particle runs, native kernel grammar/priors, maximum depth four and the original frozen SMC/HMC schedule. Its original native checkpoint and noise-jitter transport correction are preserved. GP results are a finite-particle approximation; native predictive consistency checks do not establish adequate posterior exploration. Particle weights and ESS are retained for inspection.

## Qualification, resumption and evidence

Three independent DESN chains are required. A full attempt must satisfy all three screens:

- Rank-normalized folded split R-hat ≤1.01 for every sampled continuous diagnostic.
- Summed per-chain spectral ESS ≥400 for every sampled continuous diagnostic. This is the production `coda` spectral estimate, capped by the retained draw count; it is not Stan's bulk/tail ESS.
- Maximum across-chain range of any model's estimated posterior probability ≤0.05.

Fixed quantities have undefined convergence diagnostics and are excluded only when explicitly marked `sampled=false`. Nonfinite sampled diagnostics fail the gate. Model-indicator R-hat/ESS and architecture transition counters are also retained; an unvisited model's undefined indicator diagnostic must not be read as proof of zero posterior probability. For MH, model probabilities are occupancy estimates. These screens provide evidence about mixing within the listed bank; they do not prove convergence or exploration of an architecture outside it.

An unsuccessful full attempt is saved with `qualified=false`. If all fixed attempts fail, the runner exits with an error, leaves diagnostics and chain checkpoints for inspection, and creates no qualified posterior checkpoint or forecasts. The report independently rechecks the saved gates and refuses missing, unqualified, mixed-mode or incomplete model results. It does not generate a successful comparison from unchecked chains.

The build, chains and per-origin forecasts are independently restartable. Repeat the same command to reuse completed checkpoints. Runtime-source and protocol hashes guard against silently mixing evidence from different code or settings. Documentation and test additions do not alter this guard. Deliberate source or configuration changes require another `--out` directory. `--bank-dir` can point to the matching previously built bank; incompatible bank contracts are refused. Avoid simultaneous writers to the same output directory.

`--stage fit` stops after inference and checkpoint creation. `--stage forecast` resumes forecast generation from an already qualified full checkpoint. `--stage all` performs both. Build mode does not fit a readout. The optional `sensitivity.R` evaluates 192/384 posterior draws ×4/8/16/32 innovations at origins 2,500, 2,735 and 2,970, using nested common innovations. It creates no new fit and never changes the primary 192×8 comparison.

### Files and timers

Each model directory records status, source provenance, runtime session, diagnostic tables, architecture probabilities, and score rows. Fresh DESN runs retain individual chain files, a compact posterior checkpoint, each completed origin and raw forecast paths at three fixed origins. The feature-bank directory retains candidate checkpoints, admission audit and its own timer. The `comparison` directory contains pooled and per-lead metrics, audited score rows, forecast/lead plots, an audit manifest and sensitivity summaries when present.

Timers are deliberately separated:

- Feature construction: invocation wall time and summed per-candidate compute, with the latter explicitly not parallel wall time. Reused bank load time is recorded separately.
- Inference: completed chain compute summed across every attempted schedule. C++ compilation is a separate field.
- Forecasting: state preparation and summed per-origin forecast compute. Scoring/export are excluded from the per-origin compute field.
- Fresh GP: final completed-run SMC training callbacks, native launcher wall time for the current invocation and Python conditioning/scoring time. Callback totals retain successful fits on checkpoint reuse but exclude abandoned attempts. The launcher also includes startup, exports and native validation, so its total is not an isolated fit timer.

Reused ridge results have only the original combined stage timer, covering bank construction, fitting, primary forecasts and sensitivity. Its individual phase times are reported as unavailable. Reused GP retains the original native SMC and export timing; its old Python rolling time cannot be isolated. These quantities should not be presented as equivalent end-to-end timing measurements, particularly across machines, R versions or thread counts. No runtime speedup claim follows from the reused comparison alone.

## Scores and limits of interpretation

Forecast means average the conditional means along simulated recursive histories. They are not zero-innovation plug-in trajectories. Predictive intervals use the original type-8 empirical quantiles for DESN. DESN CRPS is the original empirical-distribution V-statistic, and the log score averages conditional Gaussian densities along simulated histories. The Python audit reconstructs means, quantiles, CRPS and log scores from the exported paths at all 30 leads of three origins, independently of the R scorer. GP uses exact marginal Gaussian-mixture quantiles, CRPS and log score for the exported particles.

Pooled RMSE is the square root of the mean squared error across origin/lead pairs; it is not the mean of per-origin RMSEs. Every model must have the exact same origin/lead grid, actual responses and target timestamps. Forecast intervals, coverage, widths and squared/absolute errors are checked directly. The aggregation retains the same early/late target scopes and full per-lead curves so pooled statistics do not conceal horizon-specific behavior.

C1 was previously chosen for visual difficulty. It is one synthetic realization with switching regimes and heteroscedastic innovations. The DESN likelihood here remains homoscedastic under both priors. The 14,130 pairs overlap and depend on only 500 test outcomes; they are not 14,130 independent tests. A C1 improvement would be evidence for this particular frozen experiment, not a broad performance guarantee or a calibrated significance test. The main comparison also uses finite posterior/path budgets; the optional sensitivity table quantifies changes from increasing these Monte Carlo budgets.

## CI

`autodesn-rhs-comparison.yaml` runs contracts and smoke orchestration on relevant pull requests. Expensive full runs require manual dispatch with `run_full=true`. The full workflow fits ridge, RHS and pinned AutoGP fresh, uploads failure evidence, and runs the combined report only after all required jobs succeed. The full workflow does not depend on private local cached results.
