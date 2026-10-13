# Independent forecast prefix interval recovery

This validation-only tool computes draw-wise forecast MAE and check-loss
means and equal-tailed 95% intervals over the first 300/500/full 1,000 held-out
targets. It preserves the article v14 selected sources, not the later
unpromoted redesigned studies. It never fits a model, changes priors, runs
screening, or publishes article/Overleaf files.

## Implementation and recovery decision

The complete source registry contains 44 source identities, three chains
each: 132 unique forecast tasks supplying 72 displayed criterion cells.
The first 300 targets use 10 origins; first 500 uses 17 origins and only
20 leads from its last origin; full 1,000 uses 34 origins and 10 leads from
its last origin. Forecast horizons and draws are generated on the original
grid before any score truncation.

The audit found no surviving configured forecast/posterior capsule for these
sources in the checked job roots and directly source-request-linked locations.
The identified portable archive has 1,278 members and no matching fitted or
joint forecast payload. Undocumented external backups have not been audited;
their location would be needed before claiming exhaustive absence.

Three surviving Gaussian AL-RHS p=0.05 origin-group draw files provide a
verified no-fit/no-forecast recovery of its first-300 interval. Their complete
origin-weighted scores match the exact full-window metric draws within
6.93e-14. The metric table's `source_draw_index` is a forecast-column index,
whereas the origin table records parent coefficient indices. Alignment is
by chain/draw ID, checked against both complete draw-wise scores; both index
namespaces remain explicit in the recovery export.

Whole-origin averages cannot recover the 20-lead fragment needed at target
500. No unverified covariance assumptions or old interval endpoints are used
to fill that gap. Current coverage is 72/72 full-window cells, 2/72 first-300
cells, and 0/72 first-500 cells. The complete comparison therefore remains
`RECOVERY_INCOMPLETE_NO_REFITS_LAUNCHED`, not ready for article integration.

## Commands

Run from a dedicated IND validation worktree. Supply paths to the existing
frozen review and identified evidence bundle; all outputs must be new,
lane-owned paths, normally under ignored `local_trackers`.

```bash
Rscript validation/fitforecast_v2/scripts/run_independent_forecast_prefix_intervals_v1.R \
  --mode audit-rescore \
  --review-root /path/to/article_forecast_prefix_review_20261013 \
  --bundle-root /path/to/metric_intervals_v10_evidence_bundle_v1_20260824 \
  --output validation/fitforecast_v2/local_trackers/prefix_intervals/run_01

Rscript validation/fitforecast_v2/scripts/render_independent_forecast_prefix_intervals_v1.R \
  --run validation/fitforecast_v2/local_trackers/prefix_intervals/run_01
```

The renderer produces a clearly labeled partial packet until all 216
window/criterion cells exist. With complete coverage, also supply `--style`
pointing to the frozen article `qdesn_evaluation_figure_style.R`; it produces
six matched article-style pages with common panel scales across windows.

## Forecast-only capsules

A recovered RDS capsule must have schema
`independent_forecast_prefix_capsule_v1`, source/chain identifiers matching the
task registry, the actual fitted object, canonical grid and original y/oracle
vectors, retained draw identifiers, exact original RNG kind/seed, original
package version, and pinned forecast code paths/hashes. Its loaded forecast
function must match `forecast_function_sha256`, computed from formals/body.
Do not infer posterior samples from coefficient means or marginal bands.

The `qdesn_lattice_v14` adapter requires original `forecast_args`, all 34
`local_origins`, preserved `draw_columns`, and explicit `location_center` and
`location_scale`. It uses conditional `mu_by_origin`, not response draws.
The `dqlm_rolling_v14` adapter requires original config/data, hashed
`helper_sources`, and original response-draw budget. It retains the historical
state-update strategy and latent `ff/fQ` product coupling. Its seed is the
original rolling-forecast seed (row-runner fit seed plus one), not the fit seed.
The replay retains observations through each origin and never conditions its
within-origin horizon on actual future observations or oracle quantiles.

```bash
Rscript validation/fitforecast_v2/scripts/run_independent_forecast_prefix_intervals_v1.R \
  --mode forecast-only --registry /path/to/task_registry.csv \
  --task-id SOURCE_ID__c01 --capsule /path/to/recovered_capsule.rds \
  --capsule-sha256 EXPECTED_SHA256 --output /new/lane-owned/task-output
```

No capsule producer is claimed to have reconstructed missing samples. A
capsule is eligible only after a sufficiency audit of genuinely recovered
evidence. The worker rejects missing/mismatched samples and validates its
complete draw-wise scores against the stored article draw table at 1e-6.
It preserves input hashes and RNG state and never calls the historical
fit-and-prune worker or deletes recovered artifacts.

For recovered capsules passing representative pilots, `--mode forecast-pool`
accepts `--registry`, `--capsule-registry`, `--workers`, and `--output`.
The capsule CSV has `task_id,capsule_path,capsule_sha256`. Default concurrency
is one; the explicit ceiling is 15, one thread per process. Confirm unused
cores and pilot RSS before increasing it. Verified outputs are hash-checked
and reused; incomplete tasks use disjoint directories and locks. No pool was
launched during this recovery audit.

Re-run `audit-rescore` with `--verified-pool-root` to incorporate completed
forecast evidence into role-matched summaries. A partial chain set cannot
be represented as the original three-chain article summary.

## Evidence and exclusions

Retain task/display registries, locator probes, source-linked candidate and
archive inventories, draw-level prefix snapshots, origin-group reconstruction
checks, full-window article checks, available/missing cell inventories, health
JSON, tests, and hash manifests. Prefix snapshots retain draw-level sums and
counts at requested thresholds and every whole-origin boundary. They support
later recorded cutoffs, not arbitrary unrecorded within-origin thresholds.

Raw fitted payloads, recovered capsules, runtime artifacts, and review PDFs
remain ignored. The coordinator receives validation code and compact evidence
only. This branch must not merge or push shared validation, article main, or
Overleaf. No score changes or official-window shortening are authorized by
this diagnostic; chain diagnostic grades remain disclosed, not exclusions.

Both adapters have synthetic no-fit/RNG-preservation tests. The real adapters
cannot be claimed validated on historical posterior capsules until such
capsules are recovered and full-window replay checks pass. The DQLM adapter
likewise remains awaiting a genuine recovered-posterior pilot.

## No backup and the required next stage

The investigator stated that no additional backup is available. Complete
interval recovery therefore requires a separately approved reconstruction of
the existing 44 selected sources (up to 132 chains), not another screening.
The three sources with origin summaries still need their posterior restored
to recover the partial-origin 500 cutoff. Retain the new forecast-capable
capsules and all required prefix snapshots; do not prune them automatically.

Freeze source-specific configurations, priors, design realization, method IDs,
initialization and seeds, and the historical environment before reconstruction.
New posterior samples are not automatically the identical original realization.
The current worker is intentionally an exact-recovered-posterior replay tool:
it rejects full-window draw differences above 1e-6. Do not loosen that check
to conceal a refit. A reconstruction campaign needs a distinct provenance
contract, all three windows scored from its own common posterior draws, and
an explicit comparison with the retained article baseline. Current article
figures stay unchanged until the complete results are reviewed. No refits
were launched in response to the investigator's clarification question.
