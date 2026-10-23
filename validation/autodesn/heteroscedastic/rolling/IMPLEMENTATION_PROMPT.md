# Rolling-origin correction

Make rolling-origin H=30 the primary experiment, following the repository's
corrected Q-DESN protocol: fit/select once on rows 501:2500 after 500 washout
observations; freeze preprocessing, posterior and model probabilities; update
states with actual observations between origins; use simulated feedback only
within every 30-step forecast. Use all 71 complete origins 2500:2570 inside the
same 100-observation test block. Keep the existing 100-step fixed-origin and
one-step diagnostics as separate, accurately labeled experiments.

Reuse the exact final sampler seeds and diagnostic-selected durations already
recorded, and verify posterior/first-origin replay. Save compact posterior
checkpoints so forecasts can be rerun without repeating inference. Use the
shared Normal transition for state updates and recursive forecasts. With this
identity-bridge/all-layer identity readout, recover each updated layer state
from a single teacher-forced design row; assert this supported contract and
check against the shared builder. No data-dependent bridge or preprocessing
reestimation is allowed. Never advance the next origin using a simulated path's
terminal state.

Use 192 outer draws and 16 innovations per draw (3072 paths), with a prespecified
K=8/16/32 sensitivity at the first origin. Score every origin/lead separately;
never pool forecasts issued at different origins into one predictive interval.
Compare the same seven models, with no refitting for any comparator. Test
future replacement, observed-state timing, single-origin equivalence, serial
and parallel origin replay, fixed draws/scales and complete target indices.
Export compressed raw scores, all leads, origin/replication summaries, selected
rolling fans, source manifests and diagnostic/replay evidence. Parallelize only
independent R processes/origins within the memory budget. Preserve earlier
results and publish the completed primary rolling comparison on the existing
isolated branch/draft PR without merging.
