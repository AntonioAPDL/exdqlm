# Original288 V7 Metric Cluster Diagnosis

Date: 2026-04-09

This note turns the broader metric-comparison layer into a cluster-by-cluster
diagnosis. The emphasis is on comparing:

- `al` vs `exal` **within MCMC**
- `al` vs `exal` **within VB**
- `dqlm` vs `exdqlm` **within MCMC**
- `dqlm` vs `exdqlm` **within VB**

The source comparison tables come from:

- `tools/merge_reports/original288_metric_comparison_20260409/original288_static_metric_pair_comparison_20260409.csv`
- `tools/merge_reports/original288_metric_comparison_20260409/original288_dynamic_metric_pair_comparison_20260409.csv`

Cluster diagnosis outputs:

- `tools/merge_reports/original288_metric_comparison_20260409/original288_static_metric_cluster_summary_20260409.csv`
- `tools/merge_reports/original288_metric_comparison_20260409/original288_static_metric_cluster_detail_20260409.csv`
- `tools/merge_reports/original288_metric_comparison_20260409/original288_dynamic_metric_cluster_summary_20260409.csv`
- `tools/merge_reports/original288_metric_comparison_20260409/original288_dynamic_metric_cluster_by_tau_20260409.csv`
- `tools/merge_reports/original288_metric_comparison_20260409/original288_dynamic_metric_cluster_detail_20260409.csv`

Important interpretation update:

- as of `2026-04-09`, the accepted `static_shrink / rhs` branch should be read
  as a **legacy mixed-prior historical branch**, not as a clean `rhs_ns`
  result:
  [mixed-prior investigation](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_static_shrink_rhs_mixed_prior_investigation_20260409.md)

## Static Diagnosis

### Static MCMC

This is the clearest broader-study success regime for `exal`.

| Cluster | Available metric slots | Win share | Net advantage | Main read |
|---|---:|---:|---:|---|
| `static_paper / paper / mcmc` | `72` | `77.8%` | `+40` | strongest overall exAL cluster |
| `static_shrink / ridge / mcmc` | `54` | `72.2%` | `+24` | clear exAL win beyond the paper block |
| `static_shrink / rhs / mcmc` | `54` | `63.0%` | `+14` | positive historical signal, but now frozen as legacy mixed-prior |

Main MCMC takeaways:

1. `static_paper / mcmc` is the clean benchmark-aligned win:
   - `q_rmse`: exAL better in `13 / 18`
   - `CIE`: exAL better in `15 / 18`
   - `beta_rmse`: exAL better in `18 / 18`
   - coverage-gap: exAL better in `10 / 18`
2. `static_shrink / ridge / mcmc` also looks clearly favorable to `exal`.
3. `static_shrink / rhs / mcmc` is positive historically, but it should now be
   treated as a legacy mixed-prior branch pending full `rhs_ns` rebuild.

MCMC tau pattern:

| Tau | exAL better on `q_rmse` | exAL better on `beta_rmse` | exAL better on coverage gap | Main read |
|---|---:|---:|---:|---|
| `0p05` | `15 / 18` | `17 / 18` | `14 / 18` | strongest MCMC tau |
| `0p25` | `13 / 18` | `16 / 18` | `6 / 18` | still good, but coverage gains weaken |
| `0p95` | `6 / 18` | `15 / 18` | `12 / 18` | `q_rmse` gets mixed, but exAL still wins on coefficient and coverage metrics |

So for static MCMC, the main message is:

**`exal` is broadly better than `al`, and that result is not confined to the paper block.**

### Static VB

Static VB is much more mixed, but it is still not a simple loss for `exal`.

| Cluster | Available metric slots | Win share | Net advantage | Main read |
|---|---:|---:|---:|---|
| `static_paper / paper / vb` | `66` | `62.1%` | `+16` | positive overall, mainly because coverage improves a lot |
| `static_shrink / ridge / vb` | `48` | `56.3%` | `+6` | mildly positive |
| `static_shrink / rhs / vb` | `48` | `47.9%` | `-2` | weakest static cluster historically, but now frozen as legacy mixed-prior |

VB tau pattern:

| Tau | exAL better on `q_rmse` | exAL better on `beta_rmse` | exAL better on coverage gap | Main read |
|---|---:|---:|---:|---|
| `0p05` | `11 / 18` | `14 / 18` | `15 / 18` | favorable |
| `0p25` | `0 / 18` | `0 / 18` | `3 / 18` | the clear bad pocket |
| `0p95` | `8 / 18` | `12 / 18` | `18 / 18` | strongly favorable on coverage/calibration |

This is the most important static diagnosis insight:

**static VB is not uniformly bad for `exal`; it has a very specific `tau = 0.25` weakness pattern.**

That weak pocket shows up across:

- `static_paper / vb`
- `static_shrink / rhs / vb`
- `static_shrink / ridge / vb`

while `tau = 0.95` is often very favorable for `exal` in VB.

### Best Static Clusters

Most convincing static wins:

1. `static_paper / mcmc / laplace / tau 0.05 / TT100`
2. `static_paper / mcmc / laplace / tau 0.25 / TT100`
3. `static_paper / mcmc / normal / tau 0.95 / TT100`
4. `static_shrink / ridge / mcmc / laplace / tau 0.95 / TT100`
5. `static_shrink / rhs / mcmc / laplace / tau 0.95 / TT100`

The `static_shrink / rhs` entry above is a historical-only result until the
full `rhs_ns` rebuild is completed.

These are the rows where `exal` wins across essentially every available metric.

### Worst Static Clusters

Most concerning static pockets:

1. `static_paper / vb / tau 0.25`
2. `static_shrink / rhs / vb / tau 0.25`
3. `static_shrink / ridge / vb / tau 0.25`
4. `static_shrink / rhs / mcmc / gausmix / tau 0.95 / TT100`
5. `static_shrink / rhs / mcmc / gausmix / tau 0.25 / TT1000`

The static diagnosis therefore is:

- **MCMC:** broadly favorable to `exal`
- **VB:** favorable in several places, but clearly fragile at `tau = 0.25`

## Dynamic Diagnosis

Dynamic is much more heterogeneous than static. The right split is by inference
first and by `tau` second.

### Dynamic MCMC

| Cluster | Available metric slots | Win share | Net advantage | Main read |
|---|---:|---:|---:|---|
| `dynamic / mcmc` | `90` | `44.4%` | `-10` | overall mixed-to-negative |

Metric-by-metric within dynamic MCMC:

- `q_rmse`: exDQLM better in `3 / 18`
- `pplc`: exDQLM better in `7 / 18`
- `crps`: exDQLM better in `6 / 18`
- interval score: exDQLM better in `9 / 18`
- coverage-gap: exDQLM better in `15 / 18`

Dynamic MCMC tau pattern:

| Tau | Net advantage | Main read |
|---|---:|---|
| `0p05` | `-22` | bad cluster |
| `0p25` | `-12` | still bad, though less extreme |
| `0p95` | `+24` | very strong exDQLM cluster |

The key MCMC diagnosis is:

**dynamic MCMC is not uniformly bad for `exdqlm`; it is sharply split by tau.**

At `tau = 0.95`, exDQLM is often much better on predictive-loss metrics, even
when `q_rmse` can still look worse in some `TT500` cases.

### Dynamic VB

| Cluster | Available metric slots | Win share | Net advantage | Main read |
|---|---:|---:|---:|---|
| `dynamic / vb` | `90` | `52.2%` | `+4` | slightly positive overall, but internally conflicted |

Metric-by-metric within dynamic VB:

- `q_rmse`: exDQLM better in `7 / 18`
- `pplc`: exDQLM better in `18 / 18`
- `crps`: exDQLM better in `12 / 18`
- interval score: exDQLM better in `6 / 18`
- coverage-gap: exDQLM better in `4 / 18`

Dynamic VB tau pattern:

| Tau | Net advantage | Main read |
|---|---:|---|
| `0p05` | `-10` | bad cluster, especially coverage |
| `0p25` | `-10` | also bad, though `pplc` still improves |
| `0p95` | `+24` | very strong exDQLM cluster |

The key VB diagnosis is:

**dynamic VB improves loss-based metrics very consistently, but often damages calibration badly outside the `0p95` tail.**

### Best Dynamic Clusters

Most convincing dynamic wins:

1. all `tau = 0.95 / TT5000` clusters, for both `mcmc` and `vb`
2. `tau = 0.95 / TT500` clusters, especially on loss-based metrics

These are the dynamic scenarios where exDQLM often wins on all or nearly all
tracked metrics.

### Worst Dynamic Clusters

Most concerning dynamic pockets:

1. `mcmc / laplace / tau 0.05 / TT500`
2. `mcmc / normal / tau 0.05 / TT500`
3. `vb / gausmix / tau 0.05 / TT500`
4. `vb / laplace / tau 0.05 / TT500`
5. `vb / gausmix / tau 0.25 / TT500`
6. `vb / laplace / tau 0.25 / TT500`

These are the rows where exDQLM either:

- loses on almost every metric, or
- only wins `pplc` while losing badly on calibration and interval quality

## High-Level Diagnosis

### Static

- `exal` is **clearly stronger within MCMC**
- `exal` is **often still favorable within VB**, but not uniformly
- the main static weakness is **VB at `tau = 0.25`**

### Dynamic

- `exdqlm` is **not an overall uniform win**
- the dominant split is by **tau**
- `tau = 0.95` is the strong cluster
- `tau = 0.05` and `tau = 0.25` are the weak clusters, especially for dynamic VB calibration

## Practical Implications

1. For static work, the cluster diagnosis supports propagating the
   paper-aligned `exal` setup most confidently into:
   - paper-style MCMC
   - ridge MCMC
   - much of `0p05` static VB
2. For static VB, the first place to diagnose before any blanket propagation is:
   - `tau = 0.25`
3. For dynamic work, it is better to think in terms of:
   - **tail-focused success** at `tau = 0.95`
   - **calibration difficulty** at `tau = 0.05 / 0.25`
4. This broader metric diagnosis is materially more favorable to `exal` on the
   static side than the old gate-based reading.
