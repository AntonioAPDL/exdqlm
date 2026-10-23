# Select one simulated series

This gallery is complete. Forecast-model comparisons await the user's selection.
It contains the same nine original DGP/seed combinations, extended to 3,000
observations: 500 washout, 2,000 training and 500 test days. These are simulated
observations; none of the plotted curves is a fitted forecast.

| IDs | Mechanism | Seeds |
|---|---|---|
| A1, A2, A3 | Smooth nonlinear mean and changing noise scale | 864020, 864040, 864060 |
| B1, B2, B3 | Threshold mean and asymmetric GJR volatility | 865020, 865040, 865060 |
| C1, C2, C3 | Hidden noise regimes, seasonal dynamics and delayed memory | 866020, 866040, 866060 |

`artifacts/all_nine_overview.png` shows all nine complete trajectories. Each
family sheet (`A_smooth_scale.png`, `B_threshold_gjr.png`,
`C_switching_seasonal.png`) pairs a complete trajectory with its 500-day test
close-up. Axis scales vary by panel; values are not standardized for display.

The four-page downloadable PDF also embeds a ZIP containing the numeric series,
choice table, validation, generator and original R DGP source. The PDF is
provided as a separate downloadable report.

## Data and validation

`artifacts/all_nine_series.csv.gz` freezes all 27,000 observations with their
choice IDs, original seeds, splits and generator diagnostics. Fitting uses only
the `y` column; conditional means, innovation scales and hidden regimes must
not be supplied as predictors. `series_choices.csv` maps IDs to their processes
and seeds, and `prefix_validation.csv` records each comparison with the archive.

The generator implements R-compatible Mersenne-Twister initialization and
inversion-normal input probabilities, using SciPy's inverse normal CDF. All
23,400 original saved responses, their conditional locations and innovation
scales are checked, and all saved hidden regimes match. Maximum response
discrepancy is 8.89e-15, below the 2e-11 validation tolerance. This is numerical
reproduction, not a claim of bitwise equality between R and SciPy quantiles.
The generator additionally checks exact prefix invariance between its own
2,600- and 3,000-observation runs, positive scales, finiteness and split counts.

The original R mechanism is in `../heteroscedastic/dgp.R`. RNG references:
https://github.com/wch/r-source/blob/trunk/src/main/RNG.c and
https://github.com/wch/r-source/blob/trunk/src/nmath/snorm.c.

Recreate the gallery with Python, NumPy, SciPy, pandas, Matplotlib and pypdf:

```sh
python validation/autodesn/series_gallery/generate_gallery.py
```

## Comparison after selection

Choose one ID from A1-C3. Use days 1:500 for washout and frozen preprocessing,
501:2500 for fitting, and 2501:3000 for evaluation. Daily origins 2500:2970 give
471 complete forecasts with leads 1:30. Fit once, update observed reservoir
states between origins, and feed simulated outcomes back within each issued
forecast. Preserve the selected numeric input before running any model.

The expanded 456-specification experiment remains incomplete; these plots do
not change that status. The next comparison is limited to the selected series.
