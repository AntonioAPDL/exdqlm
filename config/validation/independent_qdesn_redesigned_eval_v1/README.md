# Independent Q-DESN redesigned evaluation v1

This directory freezes the scientific contract for the redesigned independent
Q-DESN versus DQLM simulation study. It is a planning and preflight surface,
not permission to launch computation.

The protocol deliberately does not inherit candidate rankings or partial
metrics from `independent_mean_readout_state_forecast_v1`. That campaign is
marked `SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL`. Only its generic paired
posterior-path and mean-readout-state forecast implementation is reusable.

Before any launch, run:

```bash
Rscript validation/fitforecast_v2/scripts/verify_independent_qdesn_redesigned_eval_v1.R
```

The verifier writes only ignored local evidence. A production materializer,
scheduler, candidate ledger, and run manifest still have to be implemented and
reviewed. `launch_enabled` must remain `false` until those gates pass.
