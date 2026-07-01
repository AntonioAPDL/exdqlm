# Q-DESN TT500 Post-MCMC Broad Screening Decision

Status: decision recorded; no launch from this document.

## Decision

Do not spend more compute on the current TT500 MCMC diagnostic rescue path now.
Keep the promoted Q-DESN VB lane as the authoritative Article-facing Q-DESN
validation path, and treat the completed MCMC confirmation/rescue outputs as
diagnostic sensitivity evidence only.

The next exploration workstream should be VB-only broad Q-DESN screening.

## Evidence

- Base TT500 MCMC confirmation run:
  `qdesn-tt500-mcmc-vb-winner-confirmation-full-20260630__git-c051364`.
- Base TT500 MCMC artifact audit:
  `observed=9 success=9 running=0 fail=0 strict_ready=TRUE`.
- Five-root MCMC diagnostic rescue run:
  `qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364`.
- Rescue artifact audit:
  `observed=5 success=5 running=0 fail=0 strict_ready=TRUE`.
- Rescue storage-light result:
  retained heavy artifact bytes `0`.
- Rescue MCMC diagnostic signoff:
  `WARN=3`, `FAIL=2`, `PASS=0`.
- Remaining diagnostic-fail cells:
  `gausmix tau=0.25` and `normal tau=0.25`, both with
  `high_autocorrelation`.

Interpretation: the MCMC pipeline is operational and storage-light, but the
current MCMC route is not diagnostic-clean enough to replace or supersede the
VB results. Additional MCMC rescue would be narrower, slower, and less aligned
with the current scientific priority than exploring better Q-DESN VB specs.

## Article-Facing Rule

- Do not promote the MCMC rescue outputs as final diagnostic-clean Article
  replacement rows.
- Keep the current promoted TT500 Q-DESN VB rows authoritative until a new
  strict-audited VB screening lane is explicitly promoted.
- MCMC rows may be discussed only as sensitivity/diagnostic evidence, with the
  unresolved autocorrelation status attached.

## Next Workstream

Use VB-only broad screening to search for Q-DESN specifications that improve
fit and rolling-origin forecast performance across all families and quantiles.

Preserve the shared validation contract:

- exdqlm package baseline: `1.0.0`
- source registry: shared fit+forecast v2 frozen sources
- TT500 target train window: source indices `8501:9000`
- forecast block: source indices `9001:10000`
- rolling-origin protocol: no refit, observed-lag state update
- `Hmax = 30`
- origin stride `30`
- no quantile synthesis
- storage-light outputs only

Primary screening objective:

- identify VB Q-DESN specs that dominate or materially improve the current
  promoted Q-DESN VB table and the DQLM/exDQLM VB baselines on fit recovery and
  rolling-origin forecast metrics.

Recommended screening shape:

- method: `vb`
- likelihood: `exal`
- prior: `rhs_ns`
- families: `gausmix`, `laplace`, `normal`
- taus: `0.05`, `0.25`, `0.50`
- fit size: TT500
- initial workers: enough to keep the machine busy without interfering with
  Article application jobs; prefer root-level parallelism with thread caps.

## Launch Gates For The Next Broad Screen

1. Freeze a candidate profile grid in config.
2. Run prepare-only and verify source hashes, selected roots, and no stale
   `/home/jaguir26/local/src` paths.
3. Run a tiny smoke on at least one hard cell.
4. Launch the VB broad screen only after prepare/smoke are clean.
5. Run strict artifact/storage audit.
6. Rank against current Q-DESN VB and DQLM/exDQLM VB baselines.
7. Promote nothing to Article until a promotion manifest records the exact
   report roots, result roots, source hashes, branch, commit, run tag, and
   schema.

## Non-Goals

- No TT5000 launch.
- No additional MCMC rescue unless explicitly reopened.
- No Article table replacement directly from exploratory screening outputs.
- No routine retention of successful `.rds`, `.rda`, or `.RData` payloads.
