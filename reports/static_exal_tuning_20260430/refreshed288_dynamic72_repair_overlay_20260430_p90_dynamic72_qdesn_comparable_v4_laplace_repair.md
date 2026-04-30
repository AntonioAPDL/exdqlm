# Dynamic 72 Repair Overlay

- Generated: `2026-04-30 19:33:24 EDT`
- Run tag: `20260430_p90_dynamic72_qdesn_comparable_v4_laplace_repair`
- Variant tag: `p90_dynamic72_qdesn_comparable_v4_laplace_repair`
- Overlay id: `dynamic_exdqlm_mcmc_tt500_laplace_rw_refresh_repair_v2`
- Overlay profile: `laplace_rw_refresh_v2`
- Dry run: `FALSE`

## Why This Overlay Exists

The v2 source-index smoke completed all dynamic rows without runtime crashes or manual stops. However, the three `TT500` exDQLM MCMC smoke rows failed sigma/gamma sampler-health gates with very low ESS per 1k and high autocorrelation. The v3 repair keeps the corrected Q-DESN-comparable tail-window contract and applies a localized repair only to `dynamic + exdqlm + mcmc + TT500` rows.

## Repair Contract

| Setting | Value |
| --- | --- |
| Target rows | `dynamic exdqlm mcmc TT500` |
| MCMC burn-in | `10000` |
| MCMC retained draws | `20000` |
| MH proposal | `laplace_rw` |
| Joint sigma/gamma sample | `TRUE` |
| Slice width | `0.25` |
| Slice max steps | `Inf` |
| Laplace refresh interval | `10` |
| Laplace refresh start | `50` |
| Laplace refresh weight | `0.9` |
| sigmagam freeze burn-in | `250` |
| theta freeze burn-in | `250` |
| latent freeze burn-in | `250` |
| latent freeze mode | `u_st_pair` |
| OMP/OpenBLAS/MKL threads | `1` per worker via launcher |

## Applied Rows

| Manifest | Rows |
| --- | ---: |
| smoke | 3 |
| full | 9 |

CSV detail:

`/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260430/refreshed288_dynamic72_repair_overlay_20260430_p90_dynamic72_qdesn_comparable_v4_laplace_repair.csv`
