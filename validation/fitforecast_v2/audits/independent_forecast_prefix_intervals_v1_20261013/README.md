# Frozen prefix-interval recovery audit

Scientific status: `RECOVERY_INCOMPLETE_NO_REFITS_LAUNCHED`.
This is validation tooling and a recovery audit, not an article promotion.

The final audit was run from source commit
`c7b4b34b788b247f5685b95d2643f87ef1294f1e`, based on shared validation
`aeb9532422e1cc5bdf371b6de566815f5040eccc`.

| Surface | Verified coverage |
| --- | --- |
| Full 1,000-target article interval summaries | 72/72 |
| First 500 targets | 0/72 |
| First 300 targets | 2/72 |
| Missing shorter-window criterion cells | 142 |
| Unique selected source identities / chains | 44 / 132 |
| Focused test expectations | 63 passed; no failures or warnings |
| Fits / forecasts launched | 0 / 0 |

The full-window article checks have maximum absolute error below `1e-6`.
Three surviving origin-group draw files recover first-300 MAE and check-loss
intervals for Gaussian AL-RHS at p=0.05. Their complete-window draws match
the retained metric draws within `6.93e-14`. A 500-target cutoff slices an
origin, so its interval cannot be reconstructed from whole-origin means.

The investigator confirmed there is no additional backup. The pending
reconstruction manifest therefore lists the existing selected specifications,
but every row has `refit_authorized = FALSE`. A separately approved refit
campaign must preserve the original model/design specifications and retain
forecast-capable posterior capsules. It must distinguish a new posterior
realization from exact reproduction of the original samples. No screening,
article replacement, integration merge, or publication is authorized here.

The compact manifest hashes these retained audit files. Implementation source
hashes separately pin the five code/document/test files. Original paths remain
as provenance locators, not claims that pruned payloads still exist.

Large payloads and PDFs are excluded. The final local run and verified partial
review PDF are under the ignored lane-owned directory:

`validation/fitforecast_v2/local_trackers/independent_forecast_prefix_intervals_v1_20261013/run_final/`

See `docs/INDEPENDENT_FORECAST_PREFIX_INTERVALS_V1_20261013.md` for the commands,
scientific scoring contract, recovery limits, and required next stage.
