# Q-DESN Train-Only Transport Audit v2

- Decision: `STOP_NO_TRANSFERABLE_MECHANISM`
- Reconstructed designs: `18`
- Train-only calibration evaluations: `90`
- Transferable candidates: `0`
- Compute launched: `FALSE`
- Article update allowed: `FALSE`

The audit reconstructs every AL design from its exact request and evaluates train-only
quantile-intercept correction without refitting. No correction is promotable unless the
same arm and window beat the paired parent on both frozen sources.

Q-DESN exAL fixed-gamma/fixed-sigma diagnostics are not exposed by the package 1.0.0
readout API. exDQLM supports those controls, but that does not justify claiming an
equivalent Q-DESN exAL experiment.
