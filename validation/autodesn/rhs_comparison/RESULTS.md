# Executed C1 RHS comparison

The complete 471-origin, 30-horizon comparison finished on October 22, 2026.
Each model has 14,130 overlapping, dependent forecast pairs on the exact
selected C1 series. No general superiority claim is supported by one series.

| Model | RMSE | MAE | CRPS | NLL | 50% coverage | 90% coverage | 90% width |
|---|---:|---:|---:|---:|---:|---:|---:|
| AutoDESN ridge | 0.647616 | 0.463250 | 0.350056 | 0.981805 | 0.653574 | 0.903255 | 2.262070 |
| AutoDESN RHS | 0.648673 | 0.464382 | 0.350757 | 0.983525 | 0.652371 | 0.903185 | 2.268396 |
| Native AutoGP | 0.617735 | 0.432304 | 0.340371 | 0.977661 | 0.712880 | 0.936093 | 2.525930 |

## Implementation and inference

The implementation uses the normalized RHS density, including coefficient
normalizers, a proper independent intercept, half-Cauchy global/local scales
and an inverse-gamma slab. It preserves Gaussian likelihoods, the ridge
default, Bayesian architecture averaging and the shared recursive forecasts.

Both DESN priors use the same 428 admitted reservoirs from the original 456
specifications, frozen scaling, 500 conditioning observations, 2,000 training
responses and 500 held-out observations. Priors are fixed before test scoring.

Ridge passed at three chains of 2,000 burn +6,000 retained draws. The selected
RHS attempt uses three chains of 6,000 burn +32,000 retained draws. Earlier
6,000- and 16,000-retained attempts failed unchanged diagnostic thresholds.
A fixed full-support proposal uses 10% original prior and 90% occupancy from
a completed training-only attempt, with exact Hastings correction.

RHS maximum continuous R-hat is 1.002121; minimum spectral ESS is 1,148.61;
maximum model-probability difference across chains is 0.027656. The leading
architecture has probability 0.807500 (ridge 0.806097). Independent rank
bulk/tail ESS checks also pass, including indicators for models with at least
1% posterior mass. Minimum RHS bulk ESS is 883.09. These are convergence
screens, not proofs.

Forecasts use 192 joint parameter/model draws and eight innovation paths per
draw, with simulated responses fed back within each path. Both priors also
completed the 24-setting predictive sensitivity grid: three origins, outer
draws 192/384 and inner paths 4/8/16/32. Individual local-scale traces were
not retained; aggregate shrinkage and leading-model coefficients are exported.

## Validation and actual runtimes

Installed focused tests: 611 passing expectations, zero failures/warnings.
One DLL-unavailable test is skipped when the DLL is loaded; source-only tests
cover that case. R study contracts pass 73 expectations; Python passes six
contracts. All 32 independent posterior-integration comparisons pass, with
quadrature-order changes in architecture probability below 2.86e-6.

Fresh ridge reproduces original forecast scores within 1.57e-12 absolute
error. Native AutoGP inference is reused from the completed pinned Julia
runs, revision 2ad372db2b8bea176e3b32a769bfb5d6cff80866: two independent runs
of eight particles. Its rolling conditioning/scoring/export was rerun and
matched the original results within 1e-11. Native checks and SMC evidence
remain in the archive.

Recovered shared reservoir-build invocation: 128.704 s. Ridge inference:
95.243 s; RHS inference over all three completed attempts: 357.729 s
(selected attempt 207.656 s), plus 44.695 s for the proposal-source attempt.
Forecast compute sums are 158.979 s (ridge) and 153.814 s (RHS), excluding
scoring and state preparation. AutoGP reused SMC training sums to 1,470.063 s;
fresh conditioning/scoring/export takes 22.295 s. Budgets differ, so these
are not matched-cost speed comparisons.

Additional recovered prior-proposal exploration totals 422.197 s, including
the 44.695 s source attempt, and a recovered proposal pilot takes 40.123 s.
An overlapping invocation was killed by the 8 GB limit. Its measured 242.640 s
includes completed checkpointed work and must not be added wholesale to
inference sums. Sequential resumption completed successfully. Peak child RSS
is approximately 4.05 GiB for ridge and 3.98 GiB for resumed RHS.

Fresh paired R/C++ reference speed ratios are 3.0 for Gaussian scoring, 50.5
for exact local updates and 2.44 for the complete small-bank fit.

## Package status and deliverables

The package installs, and compiled-code checks pass. Scoped R CMD check
(examples/tests/vignettes disabled; implementation tests run separately)
reports 1 ERROR, 3 WARNINGs and 2 NOTEs from inherited nonportable validation
filenames, legacy non-ASCII code and legacy documentation. The new RHS help
cross-reference warning was corrected. No CI-clean package release is claimed.

- [Full report](evidence/AutoDESN_RHS_C1_Report.pdf): forecasts, horizon/pooled
  metrics, architecture, shrinkage, convergence, sensitivity and runtimes.
- Numeric evidence is committed in two archive parts. Run
  python validation/autodesn/rhs_comparison/evidence/restore_evidence.py
  to reconstruct the ZIP and verify every internal SHA256 entry. It contains
  raw scores, all retained scalar traces, independent reference checks,
  failed attempts, diagnostics, provenance, budgets, timings and logs.
- Prediction checkpoints retain 384 joint forecast draws and only their
  selected reservoirs. Both replay every path/location/scale at origins
  2500, 2735 and 2970 with zero error. They are not full MCMC-chain backups.
- Large feature matrices, compiler caches and full coefficient-chain objects
  are rebuilt by the frozen scripts rather than committed. All numerical
  runs have finished; no unfinished computation is running in the background.

Execution code matches implementation commit
f5eaed3dea2b894b29463077d2d4a183a824e74c (equivalent local commit 00b8c92).
The final production-source edit only quotes a roxygen expression; executable
expressions were checked to be identical. Exact source and input hashes are
retained in the archived provenance.
