# QDESN Tau050 Fit Plot Comparison Pack Outputs

## Canonical Output Root

- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_fit_plot_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-fitplotpack-20260421-035404__git-1011450`
- summary markdown:
  - `summary/qdesn_tau050_fit_plot_comparison_pack.md`

The pack was finalized from the completed rerun root using the post-launch
`--assemble-only` path so the markdown/report layer could be rebuilt without
rerunning the fits.

## Validation And Reassembly

The finalized pack was validated with:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-fit-plot-pack-config", reporter = "summary")'
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack.R --assemble-only --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-fitplotpack-20260421-035404__git-1011450
```

## Selected Cases

The pack intentionally stays small and visual:

1. `clean_ridge_short`
   - `gausmix / tau 0.25 / fit_size 500 / ridge`
   - purpose: stable ridge benchmark

2. `stress_rhs_short`
   - `laplace / tau 0.25 / fit_size 500 / rhs_ns`
   - purpose: harder rhs benchmark where diagnostic weakness should become visually obvious

Each case contains four last-100 train-window overlays:

- `VB / AL`
- `VB / EXAL`
- `MCMC / AL`
- `MCMC / EXAL`

## Main Visual Takeaways

### Clean ridge benchmark

The clean ridge case separates `AL` and `EXAL` more strongly than it separates
`VB` and `MCMC`.

- `VB / AL` tracks the last-100 series closely with the best recovered holdout MAE
  on this case (`37.88`)
- `VB / EXAL` is visibly level-biased low over the whole window with an extremely
  wide band, matching its much weaker holdout score (`298.31`)
- both `MCMC` variants track the observed series reasonably well, but at much
  higher runtime cost than `VB`
- `MCMC / EXAL` looks slightly tighter than `MCMC / AL`, consistent with its better
  recovered holdout MAE (`77.69` vs `96.31`), but it still carries a weaker overall
  study-facing profile than `VB / AL`

### Stress rhs benchmark

The stressed rhs case is the most visually informative.

- `VB / AL` follows the trend and turning points well and stays study-usable
- `VB / EXAL` collapses into a clearly misspecified low-level fit with a broad band,
  visually confirming that `EXAL` is the weak side of the `VB` comparison on this case
- both `MCMC` fits visually follow the short-window trend much better than
  `VB / EXAL`
- despite that visually reasonable train-window fit, both `MCMC` variants remain
  source-run signoff `FAIL`, which is exactly the contrast this pack was meant to surface:
  short-window fit appearance does not override broader diagnostic weakness

## Study-Facing Interpretation

Across these selected windows, the clearest practical read is:

- `AL` is the safer default readout than `EXAL`
- `VB` provides the strongest stability-to-runtime tradeoff
- `MCMC` can still look visually competitive on a short train window, especially on
  harder rhs cases, but that should be interpreted together with the recovered
  signoff tables rather than in isolation

So the fit-plot pack supports the same study-facing direction as the broader
recovered analysis:

- default study surface: `VB`
- default readout family: `AL`
- use `EXAL` and `MCMC` as challenger surfaces, not as the primary presentation path

## Final Deliverables Present

- selected case table
- source fit scorecard
- rerun status
- figure index
- case contrast summary
- markdown image report
- copied train-window comparison plots for both selected roots
