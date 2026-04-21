## QDESN Tau050 Recovered Main Comparison Next Steps

Date: `2026-04-21`  
Status: forward plan after the recovered 144-case tau050 main-comparison rerun

## Current State

The recovered 144-case tau050 comparison rerun is complete and should now be treated as the
authoritative post-recovery source surface.

Current state:

- original hard MCMC runtime crashes: `23`
- recovered runtime crashes: `23 / 23`
- recovered source runtime `FAIL` rows: `0`
- recovered root-status `FAIL` rows: `0`
- remaining signoff `FAIL` rows: `40`

That means the main question is no longer whether the study can be run. It can. The question is
how to interpret and present the recovered study surface cleanly.

## What The Evidence Says

### 1. Do not launch more repair waves for tau050

The runtime-failure surface is already closed out. The remaining weak cases are predominantly:

- `mcmc`
- `rhs_ns`
- signoff issues like autocorrelation and drift

Those are not the same class as the earlier hard-crash failures. Another repair-wave program would
mix two different goals:

- crash recovery
- fit-quality optimization

That would blur the story instead of improving it.

### 2. Use the recovered 144-case comparison pack as the canonical tau050 study source

The recovered comparison rerun should now be the source of truth for:

- fit inventory
- root inventory
- representative-case selection
- QDESN-vs-reference summaries on the aligned surface

This means future tau050 analysis should point to the recovered main-comparison run, not back to
the original April 16 crash-contaminated source pack.

### 3. Separate the study-facing surface from the diagnostic surface

The recovered pack naturally separates into two useful layers:

| Layer | Best use |
|---|---|
| representative surface | primary study-facing summary tables and narrative |
| full recovered fit surface | secondary diagnostic analysis and method-quality discussion |

Why:

- representative surface: `36 / 36` rows are `PASS/WARN`, `0` are `FAIL`
- full fit surface: still contains `40` signoff `FAIL` rows, mostly MCMC + `rhs_ns`

So the representative layer is the clean main-comparison surface, while the full recovered surface
should be kept for transparency and diagnostics.

### 4. Treat `rhs_ns` as a stress prior, not the canonical comparison prior

Root-level readiness is very asymmetric:

- `ridge`: `18 / 18` roots comparison-eligible-any, `15 / 18` full
- `rhs_ns`: `15 / 18` roots comparison-eligible-any, `0 / 18` full

That strongly suggests the right presentation policy is:

- `ridge` for clean comparison tables
- `rhs_ns` for stress-testing and secondary discussion

### 5. Decide whether strict tau `0.50` reference alignment is needed

The recovered QDESN surface includes tau `0.50`, but the mirrored reference pack still uses tau
`0.95`.

So there are two valid paths:

| Option | Recommendation | When to choose it |
|---|---|---|
| keep current reference pack | default | if descriptive QDESN results at tau `0.50` are acceptable |
| rerun mirrored reference under tau050 contract | optional follow-up | if strict like-for-like tau `0.50` deltas are required for the paper/report |

The evidence today supports the first path as the default, because the current recovered comparison
already answers the main operational question.

## Recommended Immediate Path

### Step 1. Freeze the recovered comparison run as the authoritative tau050 study pack

Use:

- [recovered comparison outputs report](./REPORT__qdesn_tau050_recovered_main_comparison_outputs_20260421.md)
- [recovered comparison implementation report](./REPORT__qdesn_tau050_recovered_main_comparison_implementation_20260421.md)

as the anchor documents for the tau050 post-recovery surface.

### Step 2. Build study-facing summaries from the representative layer

The best next analysis task is to produce the tau050 study-facing summary from:

- the representative fit case table
- the root-level comparison-ready subset
- the aligned QDESN-vs-reference summaries where available

That gives us the cleanest narrative because it avoids over-centering the known weak `mcmc rhs_ns`
signoff surface.

### Step 3. Keep the full recovered fit surface as a secondary diagnostic appendix

Use the full recovered 144-fit pack to document:

- where MCMC still has signoff friction
- where `rhs_ns` is harder than `ridge`
- where `vb exal` still shows tail-instability warnings

That keeps the work transparent without making those weaker cases the headline.

### Step 4. Only rerun reference if strict tau `0.50` deltas become a requirement

This should be a deliberate analysis decision, not an automatic next step.

## Recommended Next Concrete Task

The strongest immediate next task is:

- produce the tau050 post-recovery study-facing analysis pack from the representative layer

That pack should summarize:

- the recovered canonical surface
- the representative winners
- the aligned reference deltas where available
- the remaining diagnostic limitations as a secondary note

## Read

The recovery phase is complete.  
The recovered 144-case main-comparison rerun means tau050 can now move from repair engineering to
analysis and interpretation.
