# Q-DESN 500-Observation MCMC VB-Candidate Remainder Resume

## Decision

The full Q-DESN RHS MCMC VB-candidate confirmation run should be resumed with a two-root remainder launch, not restarted. The original campaign completed 70 of 72 planned roots and then aborted at the PSOCK orchestration layer. Restarting all 72 roots would waste completed MCMC evidence and increase the chance of another resource-level failure.

## Evidence

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Commit: `abe3439976708e8480fd20bc300fe70c8d75f508`
- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation`
- Original full run tag: `qdesn-tt500-mcmc-vbcandidate-full-20260716-025532__git-abe3439`
- Original run stamp: `20260716-025547__git-abe3439`
- Original log: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation/orchestration/qdesn-tt500-mcmc-vbcandidate-orch-20260716-025532__git-abe3439/logs/30_full.log`
- Original failure: `Error in unserialize(socklist[[n]]) : error reading from connection`

Observed state at audit:

| State | Count |
| --- | ---: |
| Planned roots | 72 |
| Successful roots | 70 |
| Explicit failed roots | 0 |
| Stale RUNNING roots | 1 |
| Not-created roots | 1 |
| Final campaign completion manifest | absent |
| Forbidden heavy payloads under original run root | 0 |

## Missing Roots

| Action | Family | Tau | Likelihood | Profile | Spec ID | Reason |
| --- | --- | ---: | --- | --- | --- | --- |
| rerun in fresh run tag | normal | 0.05 | exAL | `mcvbc_058_exal` | `qdesn__normal__0p05__tt500__rhs_ns__mcmc__exal__c2c2db8dd29f9e` | stale `RUNNING`; child log stopped at MCMC iteration 17300/25000 |
| run in fresh run tag | normal | 0.25 | AL | `mcvbc_015_al` | `qdesn__normal__0p25__tt500__rhs_ns__mcmc__al__f4b36d511fd66d` | root directory was never created before orchestration abort |

## Resume Policy

- Do not edit, delete, or overwrite the original partial run.
- Use fresh run tags for the two missing roots.
- Use `--workers 1` and `--scheduler static` for each root to avoid PSOCK worker connection loss.
- Run the small `normal/tau=0.25/AL` root first.
- Gate the large `normal/tau=0.05/exAL` root on machine health because the live audit showed high memory pressure.
- Keep storage-light outputs only.
- After both roots finish, run a closeout collector/audit that combines the 70 original successful roots with the 2 remainder roots.

## Launcher

Launcher:

```bash
bash scripts/launch_qdesn_tt500_mcmc_vb_candidate_remainder_resume.sh
```

Default resource gate before the large root:

- `QDESN_REMAINDER_LARGE_MEM_GATE_GIB=80`
- `QDESN_REMAINDER_LARGE_LOAD_GATE=60`
- `QDESN_REMAINDER_GATE_SLEEP_SECONDS=1800`

Dry-run command:

```bash
QDESN_REMAINDER_DRY_RUN=true bash scripts/launch_qdesn_tt500_mcmc_vb_candidate_remainder_resume.sh
```

## Closeout After Remainder Completion

The stage is not article-facing until:

1. Both remainder roots complete or fail explicitly in their own run tags.
2. A combined closeout table is built from the 70 original successes plus the remainder run outputs.
3. The combined run has explicit success/failure accounting for all 72 target specs.
4. Storage-light checks confirm no routine `.rds`, `.rda`, `.RData`, or `__design.rds` payload retention.
5. Ranking/audit scripts identify whether any MCMC candidate should replace current article-facing rows.
