# Independent exAL M0 structural screen v2 targeted confirmation

## Decision

The 430-job structural campaign is complete. Only two cell-specific candidates
improved their current metric after the four-source sealed average:

| Cell | Metric | Sealed improvement | Comparator gap | Source robustness |
|---|---|---:|---:|---|
| Laplace, 0.05 | fit quantile RMSE | 28.8% | 24.6% | improves current on 4/4 sources |
| Gaussian, 0.25 | forecast quantile MAE | 15.3% | 3.9% | improves current on 3/4 sources |

The other five cells are closed as non-winners for this search. Running their
15 full-budget chains would not answer the promotion question and is therefore
excluded from the targeted confirmation.

## Canonical-source diagnosis

The untouched `dev13` source remains a sealed reserve, but it is not the source
on which the current article metrics were computed. A promotion comparison must
use the original article DGP realization
`dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`.
The materializer reads its canonical 10,000-row files under
`/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources`, then
proves that rows 8111--10000 reproduce the historical 1,890-row article source
exactly before creating candidate-specific raw windows.

## Confirmation contract

- two independently selected cell-specific candidates;
- three independently seeded chains per candidate;
- exdqlm 1.0.0 and `M0_v_collapsed_support_logit`;
- 5,000 burn-in and 20,000 retained iterations per chain;
- canonical train targets 8501--9000 and forecast block 9001--10000;
- rolling-origin leads 1--30, stride 30, without refitting by origin;
- one operating-system thread per chain;
- six dynamically selected idle CPUs, with one concurrent chain per CPU;
- a 30-minute resource heartbeat and 30-minute stale-evidence threshold;
- scalar metrics, compact paths, status, logs, configs, and hashes only;
- no retained `.rds`, `.rda`, or `.RData` fit payloads;
- no automatic article promotion.

The closeout reports every chain and a three-chain mean. A cell becomes eligible
for manual metric-specific article promotion only when all three chains finish
with finite storage-light artifacts and their mean objective improves the
current article value. Diagnostics are reported but are not silently discarded.

## Launch

```bash
WORKERS=6 \
  validation/fitforecast_v2/scripts/launch_independent_exal_m0_structural_screen_v2_targeted_confirmation.sh
```

The pipeline requires a clean synchronized validation branch and records a
static verification before starting any full-budget chain. If resources are not
yet safe, it waits and records the resource gate instead of oversubscribing the
host. Article changes are deferred until the completed closeout is reviewed.
