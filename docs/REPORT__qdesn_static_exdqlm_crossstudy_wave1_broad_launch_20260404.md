# REPORT: QDESN Static exdqlm Cross-Study Wave 1 Broad Launch

Date: 2026-04-04  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Scope

This report closes the first broad QDESN static exdqlm cross-study launch far enough to define the
remaining debt precisely, even though the campaign-level closeout hung before writing aggregate
tables.

Authoritative source run:

- run tag:
  - `qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- outer report root:
  - `reports/qdesn_mcmc_validation/static_exdqlm_crossstudy/qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- outer results root:
  - `results/qdesn_mcmc_validation/static_exdqlm_crossstudy/qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- authoritative root-state source:
  - `.../20260404-035055__git-06ac1c0/roots/*`

Important interpretation:

- root-level artifacts are authoritative for Wave 1;
- campaign-level aggregate closeout is not authoritative because it never finalized.

## 2) Wave 1 Outcome

Root-level status:

| metric | value |
|---|---:|
| expected roots | `72` |
| materialized roots | `72` |
| root `SUCCESS` | `66` |
| root `FAIL` | `6` |
| successful root summaries present | `66` |
| successful fit-summary rows present | `264` |

The broad static shared setup therefore worked on most of the recovered exdqlm surface.

## 3) Main Takeaways

What improved:

- the shared static QDESN setup proved broadly viable on the exdqlm dataset surface;
- all `gausmix` and `normal` roots completed successfully;
- all `static_paper` roots completed successfully;
- the broad shared setup established a usable cross-study source baseline without row-by-row tuning.

What still fails:

- exactly `6` hard root failures remain:
  - `static_shrink x laplace x tt=1000 x tau in {0.05, 0.25, 0.95} x prior in {ridge, rhs_ns}`
- a broader rhs comparison debt also remains:
  - `30` successful `rhs_ns` roots still have `root_comparison_eligible_any = FALSE`

Which ideas worked best:

- the shared `ridge` static setup is the strongest current broad baseline:
  - `33/33` successful ridge roots have `root_comparison_eligible_any = TRUE`
- the broad launch already shows that we do not need another whole-surface relaunch to make
  progress;
- the dynamic QDESN lessons still transfer:
  - use a frozen baseline;
  - compare against it explicitly;
  - keep follow-up reruns narrow;
  - require rerun-confirmed evidence before escalating a new profile.

Which ideas clearly did not work:

- rerunning the whole `72`-root surface again would waste compute;
- treating the broad cross-study debt as a family-wide failure would be incorrect;
- broad `rhs_ns` row-by-row reopening is not justified before we resolve the hard fail band and
  separate true scientific debt from diagnostics-path debt.

## 4) Precise Remaining Debt

### 4.1 Hard-Fail Roots

| root_id |
|---|
| `root__static_shrink__laplace__tau_0p05__tt_1000__qdesn_rhs_ns` |
| `root__static_shrink__laplace__tau_0p05__tt_1000__qdesn_ridge` |
| `root__static_shrink__laplace__tau_0p25__tt_1000__qdesn_rhs_ns` |
| `root__static_shrink__laplace__tau_0p25__tt_1000__qdesn_ridge` |
| `root__static_shrink__laplace__tau_0p95__tt_1000__qdesn_rhs_ns` |
| `root__static_shrink__laplace__tau_0p95__tt_1000__qdesn_ridge` |

### 4.2 Broad rhs Comparison Debt

`rhs_ns` successful-root comparison coverage:

| metric | value |
|---|---:|
| successful `rhs_ns` roots | `33` |
| `root_comparison_eligible_any = TRUE` | `3` |
| `root_comparison_eligible_any = FALSE` | `30` |
| `root_comparison_eligible_full = TRUE` | `0` |

This means the rhs problem is broader than the 6 hard root FAILs, but it is still a debt slice,
not a reason to reopen the whole validation surface.

## 5) What the Source Run Taught Us About Priors

Successful-root comparison eligibility by prior:

| prior | compare-any `TRUE` | compare-any `FALSE` | compare-full `TRUE` | compare-full `FALSE` |
|---|---:|---:|---:|---:|
| `ridge` | `33` | `0` | `9` | `24` |
| `rhs_ns` | `3` | `30` | `0` | `33` |

Fit-signoff summary from the successful roots:

| prior | model | method | strongest read |
|---|---|---|---|
| `ridge` | `al` | `vb` | usable broad baseline (`PASS/WARN`, no FAIL rows) |
| `ridge` | `al` | `mcmc` | strongest broad method (`24 PASS`, `9 WARN`) |
| `ridge` | `exal` | `vb` | usable but mostly `WARN` |
| `ridge` | `exal` | `mcmc` | main ridge scientific debt (`24 FAIL`, `8 WARN`, `1 PASS`) |
| `rhs_ns` | `al` | `vb` | broad diagnostics debt (`33 FAIL`) |
| `rhs_ns` | `exal` | `vb` | broad diagnostics debt (`33 FAIL`) |
| `rhs_ns` | `al` | `mcmc` | mixed but non-leading |
| `rhs_ns` | `exal` | `mcmc` | broad weak line, not a baseline candidate |

Main implication:

- `ridge` is the current broad cross-study baseline family;
- `rhs_ns` is currently a debt family, not a broad lead family.

## 6) Narrow Rescue Evidence Already On Disk

Wave 1 hard-root FAIL labels are not pure proof of scientific impossibility.

Static single-fit probes already showed:

- ridge hard root, `vb/al`: `PASS`
  - `results/qdesn_mcmc_validation/tmp_static_crossstudy_singlefit/probe_root/fits/vb_al/signoff_summary.csv`
- ridge hard root, `mcmc/al`: `PASS`
  - `results/qdesn_mcmc_validation/tmp_static_crossstudy_singlefit/probe_root_mcmc_al/fits/mcmc_al/signoff_summary.csv`
- rhs hard root, `vb/al`: executes, but still `FAIL` with `rhs_diagnostics_missing`
  - `results/qdesn_mcmc_validation/tmp_static_crossstudy_singlefit/probe_root_rhs_vb_al/fits/vb_al/signoff_summary.csv`

Interpretation:

- the hard root FAIL band is at least partly execution-path debt because the broad launch failed
  before the `al` half completed on those roots;
- the rhs comparison debt is at least partly diagnostics-path debt because static `rhs_ns` VB runs
  can execute and still fail only on `rhs_diagnostics_missing`.

## 7) Why Wave 2 Must Be Debt-Only

The correct next move is not another `72`-root relaunch.

The remaining high-value questions are now:

1. Can the patched PSOCK campaign path rescue the six hard root FAILs under the shared baseline?
2. Can a small set of ridge/rhs crossover profiles improve the debt slice without reopening the
   entire study surface?
3. Can any targeted rhs probe reduce `rhs_ns` comparison debt enough to justify a later, narrower
   rhs follow-up?

That is why the next program is a debt-only wave:

- Stage 1:
  - `9` roots = `6` hard-fail roots + `3` representative rhs debt probes
- Stage 2:
  - full debt set only = `36` roots
  - anchor replay + top experimental survivor

## 8) Read Next

1. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave2_debt_resolution_20260404.md`
2. `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
3. `config/validation/qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml`
4. `scripts/run_qdesn_static_exdqlm_crossstudy_debt_wave.R`
5. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_debt_wave.R`
