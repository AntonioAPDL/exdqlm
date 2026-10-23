# Completed C1 standardized-readout RHS sensitivity

Execution and numerical audits completed on 23 October 2026. This is an exploratory sensitivity analysis on the previously examined selected C1 series. The 14,130 rolling-origin pairs are dependent, not independent simulation replications. Native AutoGP and original-basis results below are verified completed references, not new inference runs.

## Feature scaling and prior

The earlier AutoDESN experiment scaled the response on observations 1:500 and used H/sqrt(d); it did not z-score each readout column. The new runs reuse Q-DESN readout helpers and set `standardize_features=TRUE, normalize_features=FALSE`. Every nonconstant readout column has training sample SD 1 and mean 0 using only rows 501:2500. These transformations and any constant-column mask are frozen for forecasting. The intercept remains unscaled, with a proper prior; raw-coordinate coefficient transport includes its centering shift. All 428 admitted architectures share exactly the same raw reservoirs, definitions and training transformations across the three new cases. Maximum absolute training mean is 7.094e-14; maximum SD error is 2.221e-16; zero columns were dropped.

The requested prior is normalized RHS with `tau0=0.001`, `slab_scale=1`, `slab_df=4`: u and local scales are independent unit half-Cauchy, tau=0.001*u, c²~IG(2,2), and slope variance is (1/c²+1/(tau²*lambda_j²))^(-1). Tau is learned, not fixed at 0.001. The intercept prior is N(0,10), where 10 is the variance, and observation variance has IG(3,1). Coefficient priors are independent of observation variance. The scaling-only case uses tau0=1, slab_scale=2, slab_df=4, hence c²~IG(2,8). Ridge retains its Gaussian prior and the same standardized design.

Posterior requested tau median is 0.01111 (5%-95%: 0.002913-0.05483); slab variance median is 1.0667 (0.3969-4.7607). Global, local and slab quantities are sampled. Prior normalization, coefficient-integrated likelihoods and architecture Hastings factors are retained; normalized RHS is not the augmented rhs_ns formulation.

## Frozen forecast protocol

500 washout observations, 2,000 training observations, 500 held out. Parameters and architecture weights are fitted once at origin 2500. Origins 2500:2970 and leads 1:30 give 471 origins and 14,130 pairs per model. Observations update reservoir states between origins; simulated responses drive each recursive forecast. No future observation is used inside an issued forecast. Primary forecasts use 192 joint posterior draws and 8 innovation paths per draw. A 384-draw checkpoint supports Monte Carlo sensitivity. The response scaling and original candidate/washout definitions remain unchanged.

## Pooled scores

| Model | RMSE | MAE | CRPS | NLL | 50% coverage | 90% coverage | 50% width | 90% width |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| RHS: standardized, tau0=0.001, slab=1 | 0.628700 | 0.446741 | 0.339121 | 0.953479 | 0.645081 | 0.896391 | 0.874609 | 2.131992 |
| RHS: standardized, tau0=1, slab=2 | 0.628849 | 0.445357 | 0.339030 | 0.953214 | 0.651522 | 0.897594 | 0.880719 | 2.146171 |
| Ridge: standardized | 0.627413 | 0.445001 | 0.338207 | 0.949743 | 0.654423 | 0.901203 | 0.886292 | 2.161026 |
| Ridge: original basis | 0.647616 | 0.463250 | 0.350056 | 0.981805 | 0.653574 | 0.903255 | 0.928616 | 2.262070 |
| RHS: original basis, tau0=1, slab=2 | 0.648673 | 0.464382 | 0.350757 | 0.983525 | 0.652371 | 0.903185 | 0.930946 | 2.268396 |
| Native AutoGP | 0.617735 | 0.432304 | 0.340371 | 0.977661 | 0.712880 | 0.936093 | 1.033897 | 2.525930 |

The requested RHS RMSE is 3.08% lower than the earlier RHS run. Standardized ridge has slightly lower RMSE, CRPS and NLL than either standardized RHS run. Native AutoGP has lower RMSE and MAE here, while its CRPS/NLL are higher than those of the standardized AutoDESN fits. Coverage and widths must be considered together: all models overcover their nominal 50% intervals on this series. These are descriptive comparisons, without a statistical-superiority claim.

The two standardized RHS settings differ by only about 0.00015 pooled RMSE. Predictive-budget changes on three fixed origins induce larger shifts; these results do not establish that the requested hyperparameters improve on the scaling-only RHS case. The larger visible change is associated with the standardized feature basis.

## Actual MCMC execution and diagnostics

Three chains are used throughout. The historical prefix-scale embedding failed architecture diagnostics at every declared budget up to 10,000 burn +64,000 retained draws per chain. The initial layerwise/interwoven proposal also failed the absolute architecture-frequency gate at that final budget. Neither issued forecasts. All attempts, scalar traces, controls and costs are preserved.

The final requested fit freezes a training-only proposal q=0.2*architecture_prior+0.8*initial_attempt_4_occupancy, retains positive mass on every architecture, applies the exact Hastings ratio, and runs fresh seeds 4106021/4106022/4106023 for 10,000 burn +64,000 retained draws per chain. The same normalized RHS target, candidate bank, feature transforms and forecast settings apply. Optional layerwise scale slots and exact product-preserving global/local interweaving improve computation without changing the target. No held-out score informed these sampler decisions.

| Scenario | Retained per chain | Max independent rank R-hat | Min bulk ESS | Min tail/frequency ESS |
|---|---:|---:|---:|---:|
| requested | 64000 | 1.005387 | 816.5 | 1394.2 |
| scaling_only | 64000 | 1.002675 | 940.8 | 974.5 |
| ridge_standardized | 6000 | 1.002692 | 1259.5 | 2493.3 |

The independent screen includes continuous quantities and architecture indicators with posterior mass >=1%. Binary-indicator ESS is frequency ESS, displayed in both ESS columns; constant binary tail quantiles are not treated as an informative tail ESS. The R checks also gate spectral ESS and between-chain model-frequency ranges. Passing these monitored diagnostics supports these fits but does not prove convergence or accurate rare-model probabilities.

Requested leading architecture masses: broad_378 (ID423, depth4, widths50/35/24/17) 0.30236; broad_282 (ID346, depth3, widths50/35/24) 0.25812; broad_026 (ID98, depth1, width50) 0.18784. Full 428-model probabilities and chain exploration are archived. Three requested chains visited 13, 13 and 14 architectures and made 15,841, 15,429 and 15,640 retained-iteration switches.

## Validation, cost and limitations

- 639 installed focused regression assertions passed, with zero failures/errors/warnings and one loaded-DLL context skip; 76 separate source-only assertions passed without a skip. 77 R study contracts, 6 Python forecasting/scoring contracts, 4 independent diagnostic tests and 32 independent small-posterior reference checks passed. The 25 exact mixing-update checks and historical default-draw parity checks passed. These tests are separate from large-chain convergence evidence.
- All full score tables pass protocol/causality/provenance checks. Independent score reconstruction from paths at three origins per new case agrees within 1.25e-14. All nine replay windows using archived compact checkpoints agree within 5.11e-15. Frozen scaling, coefficient/intercept transport, future-data perturbation and recursive causality are checked.
- Two direct compressed trace exports were truncated despite zero R exit status; the original RDS chains were intact. Re-export now publishes gzip files atomically from closed regular CSVs; all 14 trace streams passed full EOF/integrity checks.
- Shared reservoir construction took 145.45s wall time; frozen design preparation took 18.12s. Qualified requested inference used 690.73s completed-chain compute; full forecast compute 90.16s plus 2.99s state preparation, excluding scoring/export. Complete requested fit wall 772.27s; serial forecast invocation wall 116.19s; observed parent peak 4.89GiB. Additional failed initial-layerwise training cost 1354.04s plus 25.44s pilots; failed prefix development cost 1239.80s plus 28.08s pilots. Interrupted partial work remains in wall-time logs and is excluded from completed-chain totals.
- Scaling-only inference including failed budgets used 1085.36s plus 23.27s pilots; forecast compute 114.27s. Its initial RSS sample was invalid due to PID namespaces and is explicitly NA. Ridge inference 81.02s; forecast compute 146.08s. Its observed 4.25GiB parent peak includes a failed fork resume (255.02s wasted wall time); saved fits/checkpoints allowed serial completion without refitting.
- The short computational R/C++ benchmark (200 rows, four designs, up to 64 slopes) took median 1.414s versus 0.864s (1.64x); coupled draw error <=4.96e-12 and identical architecture paths. These short runs are not convergence evidence.
- Native AutoGP reference training summed 1470.06s for two 8-particle runs; later rolling replay 22.29s includes conditioning/scoring/export, and its native training peak memory is unavailable. Different timer scopes prevent a clean end-to-end speedup claim.
- Monte Carlo sensitivity covers all 24 origin/budget combinations per new model: three origins, 192/384 joint draws, and 4/8/16/32 paths. It does not replace the full primary forecast comparison. Inference conditions on frozen estimated preprocessing; preprocessing uncertainty is not jointly inferred.
- The package remains draft: the inherited scoped R CMD check recorded one nonportable-path error, three existing documentation/non-ASCII warnings and two notes. A clean repository-wide release check is not claimed. No merge was performed.
- This work completes the requested selected-C1 sensitivity; it adds no independent multi-series replications. A confirmatory assessment should freeze prior controls and use fresh independently generated series. More predictive draws are appropriate before interpreting differences at the fourth decimal place.

## Deliverables

`evidence/AutoDESN_Standardized_RHS_C1_Report.pdf` contains plots, tables, diagnostics, runtimes and limitations. `evidence/Standardized_C1_numeric_evidence.zip.part-*` with `archive_manifest.json` and `restore_evidence.py` restores all numeric evidence with inner/outer SHA256 checks. Compact 384-draw joint forecast checkpoints and frozen feature geometry are committed separately. Huge reservoir designs and full per-iteration coefficient vectors are reconstructed from scripts/seeds rather than included; all monitored scalar traces, controls and full primary score tables are archived. Original comparison evidence remains unchanged. See README.md for reproduction and hash-guarded checkpoint rules.
