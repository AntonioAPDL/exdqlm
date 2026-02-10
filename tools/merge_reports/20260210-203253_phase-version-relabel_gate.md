# Phase Version-Relabel Gate Report (0.6.0 -> 0.4.0)

- Date (UTC): 2026-02-10 20:32:53
- Branch: `cransub/0.4.0`
- HEAD (pre-report): `db38ecb`
- Gate logs:
  - `check-logs/20260210-201925-phase-version-relabel/devtools-test.log`
  - `check-logs/20260210-201925-phase-version-relabel/devtools-check-as-cran.log`

## Scope in this chunk

- Release relabel only: no inference or backend semantic changes.
- Consolidated feature set retained on current HEAD; CRAN-facing version label changed to `0.4.0`.
- Metadata updated for consistency:
  - `DESCRIPTION` version
  - `NEWS.md` top release section
  - `cran-comments.md` submission narrative

## Packaging hygiene confirmation

- `.Rbuildignore` includes:
  - `^Plan\\.txt$`
  - `^check-logs$`
  - `^tools$`
- Internal evidence folders (`check-logs/`, `tools/merge_reports/`) and local tracker (`Plan.txt`) are excluded from source build.

## Gate results

- `devtools::test()`:
  - `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 892 ]`
- `devtools::check(args = "--as-cran", cran = TRUE)`:
  - `0 errors | 0 warnings | 3 notes`

### NOTE texts (exact)

1) Installed package size

- `installed size is 26.7Mb`
- `sub-directories of 1Mb or more:`
- `libs  25.9Mb`

2) Future file timestamps

- `unable to verify current time`

3) Compilation flags

- `Compilation used the following non-portable flag(s):`
- `-Werror=format-security`
- `-Wp,-D_FORTIFY_SOURCE=2`
- `-Wp,-D_GLIBCXX_ASSERTIONS`

