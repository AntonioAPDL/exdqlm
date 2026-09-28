# Independent Fixed-Comparator Forecast Recovery v1

## Scope

This recovery belongs only to the independent single-quantile Q-DESN/DQLM
validation lane. It does not modify Article-v2, shared-validation authority,
Overleaf, joint Q-DESN validation, PriceFM, or GloFAS.

The failed source run is:

```text
validation/fitforecast_v2/local_trackers/
independent_qdesn_fixed_comparator_stride1_v1_20260927_172549__git-cc25f5a98
```

## Audited state and root cause

The source run completed all 54 MCMC fits at 25,000/25,000 iterations and
wrote 54 fit handoffs. Their manifests cover the exact two-model, three-family,
three-quantile, three-chain lattice. The handoffs total about 32.716 GiB.

Every row then failed at the first rolling-origin state update because the
validation harness called `make_df_mat()` as though it were exported. In CRAN
exdqlm 1.1.1 the helper is present but internal. Earlier `pkgload::load_all()`
execution exposed it globally and masked the defect. This is a validation
namespace-integration failure, not a failed fit, failed sampler, changed DGP,
or scientific-model failure.

The source run is preserved unchanged. No refit is scientifically justified.

## Recovery contract

The recovery:

1. calls the helper explicitly through `asNamespace("exdqlm")` and fails with
   a named error if the helper is unavailable;
2. verifies all source configs, statuses, 25,000-iteration completion events,
   handoff roles, byte sizes, and SHA-256 payload hashes before materializing;
3. writes a new provenance-clean run root and fresh output paths;
4. references the source handoffs read-only and sets
   `prune_fit_on_success = FALSE`;
5. preserves all data, DGPs, model specifications, priors, fit draws, chain
   seeds, origins, horizons, score definitions, and metric-draw counts;
6. runs only `forecast-only` work for 54 rows on 15 one-thread workers;
7. retains CRAN exdqlm 1.1.1 with tarball SHA-256
   `3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e`;
8. leaves Article-v2, shared validation, and Overleaf untouched.

## Efficiency decision

The historical rolling implementation recomputed teacher-forced filtering from
the training endpoint at every origin. The recovery advances the filtered state
only through observations newly available between adjacent origins. This is
the same teacher-forced, no-refit estimand. A zero-tolerance equivalence test
compares incremental advancement with full recomputation, and the installed-
namespace smoke repeats that comparison on a production fit before launch.

This change removes repeated state-update work without reducing the 971 full
origins, 30 leads, 29,130 scored pairs, or 300 metric draws per chain.

## Gates

The pipeline must pass, in order:

1. clean and synchronized dedicated branch;
2. resource gate and exact CRAN package installation;
3. full 54-handoff source audit with payload hashes;
4. DQLM and exDQLM installed-namespace smoke tests, including origin 9970 and
   horizon 30;
5. 54-row forecast-only launcher dry run;
6. 54-row parallel forecast recovery;
7. 54/54 health completion with concrete `failed_*` statuses counted as
   failures;
8. matched four-model closeout and diagnostic PDF generation;
9. storage audit confirming no recovery-owned model binaries and all 54 source
   handoffs retained.

Partial output is never promoted. Cleanup of the 54 source handoffs is only a
post-closeout candidate and remains deferred until complete outputs, manifests,
and diagnostics have been independently verified.

## Scientific decision after completion

The closeout compares DQLM and exDQLM against the already completed Q-DESN AL
and exAL results on the exact stride-one lattice. Metric and interval changes
are reported separately from sampler diagnostics. The recovery itself does not
authorize article promotion; it prepares a frozen scientific-review packet for
the integration coordinator.
