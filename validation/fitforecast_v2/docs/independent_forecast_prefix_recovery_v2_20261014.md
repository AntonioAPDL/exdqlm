# Independent Forecast Prefix Recovery

The stopped selected-source reconstruction at
`07e18bfe6f76c0f13d60d7dcf8ae3cb31888f135` contains 24 complete exports,
11 complete native fits/forecasts whose wrapper export failed, and 97 unstarted
chain tasks. The native scorer supports both `source_index` and `t`; the wrapper
previously supported only the first schema. This follow-up repairs that
contract without altering inference, priors, seeds, forecast origins, readout
dependence, or article selection.

The recovery branch is
`validation/independent-forecast-prefix-recovery-v2-20261014`.
Only dedicated IND task branches may be committed or pushed. Main, shared
validation, integration, and Overleaf are outside this scientific lane.

## Recovery Contract

The new 132-row effective ledger references the 24 verified original completed
jobs, exports the 11 cached native forecasts into new directories, and permits
inference only for the 97 unstarted tasks. Original failed states and retained
payloads remain unchanged. The complete input, runtime, retained-output, and
code manifests are checked before launch. All 78 Q-DESN task inputs must pass
explicit index/origin/target validation before any expensive work.
Native clock precedence is preserved: use absolute `source_index` when present,
otherwise `t`. Fifteen Q-DESN inputs have both columns, with `t` a local counter;
these must not be rejected merely because the clocks differ. The secondary
clock relationship is recorded in preflight metadata. Prefix summaries also
update their pair counts, origin counts, final targets and metric-window labels.

The cache-only adapter parses only four hash-pinned historical scale/draw helper
declarations. It does not load, compile, fit, or forecast a package. It records
zero fit and forecast calls, checks original native score agreement at 1e-6,
and verifies payload hashes before and after rescoring. Differences from the
older historical posterior realization are retained, never used to filter or
retry unfavorable chains. Completed fitted payloads are referenced rather than
copied or deleted.

The original Q-DESN/M0 source snapshots, CRAN 1.1.1 exDQLM private library,
corrected rolling state update, chain budgets and draw-selection rules remain
pinned. The globally installed package is not substituted. This is historical
evidence reconstruction, not an inference upgrade or another screening.

## Forecast Windows and Uncertainty

Training remains 8501:9000. Full forecasts score targets 9001:10000 using
34 origins at stride 30 and maximum horizon 30. The first 500 targets use
17 origins ending at lead 20; the first 300 use ten complete origins. A single
joint forecast per chain provides all cutoffs. Q-DESN retains native shared
readout draw IDs across origins; the dynamic comparators retain historical
latent Gaussian product coupling. This difference affects aggregate metric
uncertainty and must remain disclosed.

Completion requires 132 exports, 44 balanced three-chain sources and 216
metric/window display cells. The existing renderer creates an eight-page
full/500/300 review PDF with frozen article style and matched axes. This is
review-only; no automatic article replacement is performed.

## Reproduction

Use R 4.6.0 and start from the clean committed dedicated branch. Let `ORIGINAL`
be the stopped reconstruction bundle and `OUTPUT` a new ignored local tracker.

```sh
Rscript validation/fitforecast_v2/scripts/test_forecast_prefix_recovery_v2.R
Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_recovery_v2.R \
  --mode prepare --original "$ORIGINAL" --output "$OUTPUT"
Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_recovery_v2.R \
  --mode rescore --output "$OUTPUT"
Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_recovery_v2.R \
  --mode controller --output "$OUTPUT" --workers 15 \
  --cpus 32,33,34,35,36,37,38,39,40,41,42,43,44,45,46
Rscript validation/fitforecast_v2/scripts/run_forecast_prefix_recovery_v2.R \
  --mode health --output "$OUTPUT"
```

Run the controller detached in tmux after checking live CPU availability.
The selected CPUs are logical SMT threads, not 15 extra physical cores.
All numeric libraries are restricted to one thread. Each task launch requires
64 GiB available RAM and 80 GiB free disk. Scheduling stops on an implementation
failure and active jobs drain before the controller exits. Existing completed
states are verified; other existing states prohibit implicit retries.

Focused tests cover both index schemas, local/absolute clock precedence and invalid indices, target
coverage, identity/affine transforms, missing origins and draws, zero-fit cached
recovery, original-state preservation, native-score verification, historical
draw-ID ordering and nonidentity disclosure, and effective-ledger ownership.
Test outputs, detailed plan, fitted models, retained joint paths, logs and review
PDFs belong under ignored `validation/fitforecast_v2/local_trackers/`.

Final integration remains blocked until all required outputs, focused tests,
manifests, and rendered figure inspection pass. The coordinator receives a
frozen handoff and publishes any article changes; this lane does not merge or
push authoritative branches.
