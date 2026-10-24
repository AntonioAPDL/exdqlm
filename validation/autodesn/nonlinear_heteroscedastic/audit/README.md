# NHS1 diagnostic audit

This is a post-hoc audit of the original comparison at `e726533322bb5625a995dc78ac6cbd09d4dcb977`. The original Bayesian results, priors, candidate bank and forecasts are unchanged. New diagnostic fits are **not** substituted for Bayesian architecture averaging, and their scores are not a new predeclared superiority benchmark.

The audit distinguishes:

1. A privileged DGP oracle, with 32,768 recursively simulated futures at every original origin, plus an independent R recursion check and Monte Carlo sensitivity.
2. Conditional expected forecast risk versus realized error on one series.
3. Original standardized coefficients and one-step fitted functions, reconstructed directly from frozen feature geometry and posterior draws.
4. Finite-bank capacity using noiseless true-mean supervision, compared with ordinary noisy training; all diagnostic selection uses training/validation only.
5. Direct-lag/seasonal-phase ridge references, selected using rolling 30-horizon validation within the original training block.
6. Independent native GP kernel reconstruction, actual tree diversity, two training-likelihood GP ablations inside the existing grammar, and an exact native-prior log-joint evaluation.
7. A one-step Gaussian moment-projection mean/variance ablation, explicitly distinct from the original posterior-mixture scores.

Period 60 and the four-lag reference are DGP-informed. The full 60/90 lag windows are generic. The oscillatory GP initialization at period 31.25 comes from the training periodogram, not held-out outcomes. No test scores select hyperparameters or the validation winner. Diagnostic families were investigated after viewing the original results; independent new seeds are required for confirmatory comparisons.

## Reproduction

Run from the repository root using the same project-local R/Julia environment documented in the parent `ENVIRONMENT.md`. Python uses NumPy, SciPy, pandas, matplotlib, reportlab and pypdf. No scikit-learn dependency is needed. Julia uses the pinned original AutoGP project.

To inspect the executed evidence and independently reaggregate its nine summary files without rerunning model fits:

```bash
python validation/autodesn/nonlinear_heteroscedastic/audit/evidence/restore_audit.py --verify-reanalysis
```

The script verifies the archive, every member and exact byte agreement of the reaggregated CSV/JSON summaries. `evidence/audit_manifest.json` records checksums, source versions, executed checks and report review. This is evidence integrity and numerical reproducibility, not a posterior convergence certificate.

On a fresh clone, first restore the original numeric evidence and rebuild the reconstructible feature bank:

```bash
python validation/autodesn/nonlinear_heteroscedastic/evidence/restore_evidence.py
mkdir -p validation/autodesn/nonlinear_heteroscedastic/artifacts
cp -a validation/autodesn/nonlinear_heteroscedastic/evidence/restored/. validation/autodesn/nonlinear_heteroscedastic/artifacts/
Rscript --vanilla validation/autodesn/nonlinear_heteroscedastic/run.R --stage build
```

Then execute:

```bash
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
python validation/autodesn/nonlinear_heteroscedastic/audit/oracle.py
Rscript --vanilla validation/autodesn/nonlinear_heteroscedastic/audit/diagnostics.R
python validation/autodesn/nonlinear_heteroscedastic/audit/lag_ablation.py
python validation/autodesn/nonlinear_heteroscedastic/audit/gp_audit.py
python validation/autodesn/nonlinear_heteroscedastic/audit/gp_quasiperiodic.py
julia --startup-file=no --project=/path/to/pinned/AutoGP.jl validation/autodesn/nonlinear_heteroscedastic/audit/native_score.jl
Rscript --vanilla validation/autodesn/nonlinear_heteroscedastic/audit/test_oracle.R
python validation/autodesn/nonlinear_heteroscedastic/audit/analyze.py
python validation/autodesn/nonlinear_heteroscedastic/audit/test_audit.py
python validation/autodesn/nonlinear_heteroscedastic/audit/report.py
python validation/autodesn/nonlinear_heteroscedastic/audit/validate_report.py
```

Inspect every rendered PDF page before recording `--confirm-visual-review`. `oracle.py` resumes per-origin caches guarded by the frozen protocol and truth checksums; use a clean output directory for changed controls. The cache is a computational convenience, not independent data.

The compact audit archive can be restored and checksum-verified with `audit/evidence/restore_audit.py`, without recomputing the experiments. Full scores, model-selection tables and diagnostics are retained. Redundant per-origin oracle CSV caches and large reconstructible original reservoir designs are excluded.

## Interpretation constraints

- Exact future one-step DGP means are not valid multi-step oracle forecasts. The oracle integrates unknown future shocks recursively.
- The irreducible fraction refers to averages of per-origin **conditional expected** risks, not a decomposition of the one realized error sample.
- Original horizon-1 forecasting uses targets 2501:2971; the separate feature-capacity audit uses all 500 targets 2501:3000. Tables label this difference.
- Coefficients are inspected in their own standardized architecture basis. Conditional intervals are not variable-inclusion probabilities. The diagonal shrinkage proxy is not a true effective parameter count.
- GP training-location smoothing uses the responses being fitted. It is separated from fixed-parameter, past-conditioned one-step fitted means; neither is a new out-of-sample experiment.
- Native prior log-joint point values use identical data scaling, coordinates and normalizing constants, and the key comparison matches ten-dimensional latent states. A point-density gap is not a Bayes factor or posterior mode probability.
- New GP fits are likelihood plug-ins; they do not certify a converged replacement Bayesian SMC posterior.
- All results concern one series. Overlapping rolling pairs, MCMC chains and oracle paths are not independent DGP replications.
