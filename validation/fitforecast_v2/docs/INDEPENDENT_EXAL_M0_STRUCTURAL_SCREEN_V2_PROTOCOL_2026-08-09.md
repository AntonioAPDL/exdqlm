# Independent exQ-DESN M0 Structural Screen v2

## Decision target

This campaign searches only the seven independent exQ-DESN--RHS MCMC cells that
remain behind the best displayed DQLM or exDQLM comparator after the 2026-08-09
M0 promotion. It does not modify package inference, joint-QDESN work, article
tables, or the frozen article source registry.

The scientific objective is case-specific. A different reservoir and RHS
configuration may win for each family, quantile, and metric. There is no global
specification objective.

## Why this search differs from earlier screens

Earlier scalar grids covered broad nominal ranges but usually generated nearly
empty recurrence: 94.36% of audited designs had expected recurrent degree below
one, and 38.46% had more than a 0.5 probability of an entirely zero recurrent
matrix. Consequently, many alpha and rho changes did not alter the realized
reservoir. This campaign samples realized-capacity controls jointly:

- depth `D = 1:4`, favoring `D = 2:3`;
- constant, tapered, expanding, and bottleneck layer shapes;
- 20--600 total states;
- input memory `m` through 150 and explicit readout/reservoir lag choices;
- layer-specific alpha and rho, including alpha from 0.001 through 0.999;
- expected recurrent degree 2, 4, 8, or 16, converted to layer-specific
  connectivity probabilities;
- capacity-conditioned RHS `tau0` between approximately `1e-8` and `3e-4`.

The 50,000-row virtual universe performs no fitting. A fixed-seed, history-aware
maximin selector chooses 96 initial designs: 80 across five primary lower-tail
cells and 16 across two secondary median cells. Exact historical repeats are
excluded except for declared transfer and parent controls.

## Frozen fit/forecast contract

- package version: exdqlm 1.0.0;
- inference: independent exQ-DESN under exAL--RHS;
- exAL kernel: `M0_v_collapsed_support_logit`;
- effective training target window: source indices 8501--9000;
- forecast block: source indices 9001--10000;
- rolling-origin leads: 1--30;
- origin stride: 30;
- no refit at each forecast origin;
- preprocessing fit on training rows only;
- one operating-system thread per fit;
- the scheduler waits for 20 genuinely idle cores before selecting its CPU set;
- no routine retained `.rds`, `.rda`, or `.RData` model payloads.

Candidate-specific raw windows add exactly `m + washout` pre-training rows, so
every design retains 500 effective training targets even when `m = 150` and
`washout = 450`.

## Stages and gates

| Stage | Contract | Maximum roots | Automatic action |
|---|---|---:|---|
| Smoke | two tiny vector/deep configurations | 2 | must pass schema, M0, rolling-origin, and storage checks |
| Runtime calibration | representative light/heavy subset | 12 | stop on implementation failure, storage violation, or unsafe resource estimate |
| Wave 1 | 96 designs plus seven matched parents on `dev09` | 103 | rank within each cell and metric |
| Wave 2 | 48 survivors on three discovery blocks plus controls | 165 | aggregate paired-block evidence |
| Wave 3 | 24 new rpart-guided/maximin designs on three discovery blocks | 72 | select predeclared finalists |
| Sealed | 12 finalists on four blocks plus controls | 76 | opens `dev12`; `dev13` remains sealed reserve |
| Full confirmation | one cell winner on three canonical-source chains | 21 | materialize only; launch requires explicit human approval |

The exploratory maximum is 428 roots, excluding the two smoke jobs. Diagnostic
signoff is reported but is not a metric-exclusion rule. Non-finite metrics,
provenance failure, implementation failure, or retained forbidden payloads do
block advancement.

## Promotion rule

Development and sealed-source scores are candidate-selection evidence only.
They cannot update the article. A candidate must improve the current metric,
survive paired development blocks and the sealed holdout, and then improve the
same metric under full-budget canonical-source confirmation. Article promotion
is manual and metric-specific.

## Storage and failure policy

Each job retains scalar fit metrics, H=100/H=1000 forecast summaries, compact
rolling-origin paths, progress/status rows, configuration, and hashes. The
worker deletes transient binary model payloads immediately and records a prune
manifest. Source-generation objects are classified separately as frozen DGP
inputs and are never mistaken for successful fitted-model payloads.

Every stage is resumable by run tag. A completed job is skipped only when its
configuration hash matches. Failed or missing jobs can be relaunched without
rerunning successful roots.
