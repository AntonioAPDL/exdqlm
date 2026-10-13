# IND v13 shared-validation reconciliation

Frozen source: `2903bd67e51acb2a170d7338ec53777c3b62ca4a`.
Pre-integration shared target: `5b85bb3a3894a88968e4987f330e3ec66711f9c7`.
The explicit ancestry-preserving merge is
`9d9801b1631583d4c1e9ac4ae21e22f371998d7b`.

The handoff inventories authenticate 68 pending source commits and 283 changed
files. All original source files, compact evidence, runtime manifests and the
scientific decision remain unchanged. Release main, Article-v2, its results
and Overleaf are not integration targets.

## Necessary shared-loader repair

The combined tree's previous alphabetical `ffv2_source_all()` fails in a fresh
R process: `ifu8_cell <- igc7_cell` is evaluated before the predecessor module
defines `igc7_cell`. Other modules likewise bind preceding constants/functions
at source time. The individual campaign drivers already source their declared
prerequisites explicitly; their frozen execution source is not changed.

The coordinator repair orders six prerequisite modules before the remaining
alphabetical modules. Each appears exactly once per loader call. This matters
because the sentinel module captures the original runtime, design and prior,
then registers its hooks; re-sourcing the base runtime afterwards would erase
those hooks. No module body, inference update, prior, scoring law, campaign
configuration, saved result or test tolerance is changed.

The new regression runs in a fresh R process, loads the shared modules twice,
checks predecessor constants, and verifies the captured base function bodies
and final hook identities against the original runtime module. The supplemental
integration manifest records only this repair's files and frozen antecedents.

## Test scope and remaining historical boundaries

The actual combined-tree v13 replay passes 53 checks with evidence-output
variables unset, as required to avoid rewriting frozen receipts. The two
additional conditional report-writing checks account for the frozen handoff's
55-check receipt; they are not counted as newly executed. The closeout passes
19 checks. Frozen compact/runtime verification passes, including 21 compact
artifacts, 51 runtime manifests/968 rows and the 81-entry runtime closeout.
Predecessor v8–v12 direct regression files pass; v12 reports 54 assertions.

The isolated package checks exercise fourteen relevant files: 638 assertions
pass, and one existing assertion fails. Repeating that unchanged test on the
original shared target reproduces the same failure and coefficients. It is
the hybrid/full exAL RHS coefficient comparison in
`tests/testthat/test-qdesn-vb-batching-modes.R:204`, with approximately
2e-9 absolute differences under a relative tolerance of 1e-8. Its tolerance is
not relaxed and no package math is altered to manufacture a pass. This is a
documented pre-existing numerical-test limitation, not a clean full-suite pass.

Seven shared-adapter files pass 202 assertions against the repaired loader;
one historical metric-reporting block explicitly skips an unavailable pilot
record. Sixteen additional bounded protocol files are checked without launching
campaign workers. Two historical checks initially fail because a fresh
integration worktree has no September runtime at their relative paths. The
complete nine-block comparator test subsequently passes 41 assertions when
the current functions/test body receive the authentic September archive as
their explicit read-only evidence root. No fixture is copied or synthesized.
The reconciled bounded protocol scope has 898 passing assertions; the initial
path-discovery errors are retained in the receipt, not relabelled as passes.

A targeted-v11 worker-execution test is not run as a campaign. The coordinator
receipt lists actual file/expectation results and the fresh-loader and adapter
checks separately. Both loader calls preserve the source-time base function
bodies, final hooks and isolated package namespace. Integration acceptance is
scoped to the frozen lane, inherited affected helpers, and absence of new
regressions versus the prior shared target; it does not claim that every
historical package test passes or hide the unchanged batching assertion.

Scientific status remains
`NO_AVERAGE_PRIMARY_FORECAST_GAIN_RETAIN_EXISTING_ARTICLE_AUTHORITY`:
42 completed jobs, zero remaining launched jobs, 72 optional jobs declined,
all 20 local gains retained, and no article replacement authorized. Runtime
evidence and `STOP_NEW_SCHEDULING` are retained. No new scientific campaign
jobs or article-publication operations are part of this integration.
