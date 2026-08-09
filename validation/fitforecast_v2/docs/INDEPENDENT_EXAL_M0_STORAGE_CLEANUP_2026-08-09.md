# Independent exAL M0 storage cleanup

## Scope

This cleanup is limited to artifacts created for the independent exAL M0
relaunch and its article promotion. It does not touch shared validation runs,
joint-QDESN work, application campaigns, or any other worktree.

Before deletion, `tmux list-sessions` and the process table showed no active
session or process for the independent exAL M0 campaign. The authoritative run
had already completed 45 of 45 chains and had been frozen in the article-v4
promotion bundle.

## Deleted artifacts

| Artifact | Classification | Allocated bytes |
|---|---|---:|
| `ind-exal-m0-v1-20260809_160714__git-0541583` result root | Non-consumable diagnostic canary | 33,476,608 |
| Three `dev-m0-worker-integration*` result roots | Regenerable development smoke output | 4,759,552 |
| Two failed article-v4 materializations | Superseded duplicate promotion attempts | 3,276,800 |
| Five article page-review PNGs | Regenerable visual-inspection output | 1,368,064 |
| **Total** |  | **42,881,024** |

The invalid canary's orchestration logs and status metadata were retained. The
failed launcher tag `ind-exal-m0-v1-20260809_160325__git-1ac48bd` had no result
payload to remove; its audit record was retained.

## Retained authority

- authoritative run tag:
  `ind-exal-m0-v1-20260809_161838__git-89d214e`;
- all full-run metrics, traces, status rows, and logs;
- frozen configs, requests, source inputs, and source registry;
- article-v4 promotion interface, manifest, source ledger, metric decisions,
  remaining-gap ledger, and all frozen compact metric sources;
- main-article and supplement compile PDFs and logs;
- package data and the six canonical shared-source `sim_output.rds` files.

The committed promotion bundle has no dependency on any deleted path. It
contains no `.rds`, `.rda`, or `.RData` payload. The cleanup changed no source
code, statistical result, article table, figure, or manuscript prose.

## Storage result

Filesystem use decreased from 313,365,385,216 to 313,322,504,192 bytes. Free
space increased by exactly 42,881,024 bytes; `/data` remained at 34% use.
