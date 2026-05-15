# Forecast Horizon Fix

Date: 2026-05-15

Branch:

`validation/fit-forecast-shared-dynamic-0.5.0`

## Purpose

The shared dynamic fit+forecast validation study needs exDQLM/DQLM forecasts
from models trained on 500 or 5000 observations and evaluated over a 1000-step
held-out block. The package forecast API already documents this use case:
`exdqlmForecast()` accepts future state vectors `fFF` with one or `k` columns
and future evolution matrices `fGG` as either a constant `p x p` matrix or a
time-varying `p x p x k` array.

## Problem Fixed

The old implementation validated a time-varying `fGG` array against forecast
horizon `k`, but then reshaped it with fitted training length `TT`:

```r
fGG = array(fGG, c(p, p, TT))
```

That made long held-out forecasts unsafe. In particular, the planned
TT500/H1000 validation case has `k > TT`, so the forecast loop could access
future evolution slices that were not present and fail with `subscript out of
bounds`.

This contradicted the documented contract:

- `fGG`: `p x p` or `p x p x k`
- `fR`: `p x p x k`
- `ff` and `fQ`: length `k`
- `samp.fore`: `k x n.samp`

## Change

`exdqlmForecast()` now normalizes forecast inputs to the forecast horizon:

- inside-sample `fFF`/`fGG` extraction preserves dimensions with `drop = FALSE`;
- constant `p x p` `fGG` is expanded to `p x p x k`;
- time-varying `p x p x k` `fGG` is retained as depth `k`;
- bad `fGG` dimensions or depth get explicit errors;
- `ff` and `fQ` are initialized as length `k`.

## Verification

Use R 4.6.0 or newer for package validation and the shared fit+forecast study.
On Muscat as of 2026-05-15, plain `R` and `Rscript` should resolve through
`~/.local/bin` to `/data/jaguir26/local/opt/R/4.6.0/bin/{R,Rscript}`. Do not
invoke `/usr/bin/Rscript` for this validation work, because it resolves to older
system R 4.5.3 on this server.

Focused checks run:

```sh
Rscript -e 'cat(R.version.string, "\n"); stopifnot(getRversion() >= "4.6.0")'
Rscript -e 'parse("R/exdqlmForecast.R"); parse("tests/testthat/test-dqlm-reduced-paths.R"); cat("parse_ok\n")'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-dqlm-reduced-paths.R")'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-forecast-diagnostics.R")'
```

All focused tests passed.

The full package testthat suite also passed:

```text
[ FAIL 0 | WARN 0 | SKIP 1 | PASS 1982 ]
```

An additional synthetic validation-study regression was run with `TT = 500` and
`k = 1000`, using future `fFF` and `fGG` arrays. It verified:

- `dim(fR) == c(1, 1, 1000)`
- `length(ff) == 1000`
- `length(fQ) == 1000`
- `dim(samp.fore) == c(1000, 8)`
- all forecast summaries and draws are finite

Result:

```text
tt500_h1000_forecast_regression_ok
```

## Relevance To The Validation Study

This fix removes the package-level forecast-horizon blocker for the planned
shared dynamic fit+forecast validation benchmark. The validation launcher still
needs separate source-registry, storage-light, and staged-launch implementation
work before any full compute launch.
