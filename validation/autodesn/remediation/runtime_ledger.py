"""Inventory observed process costs; concurrent process wall times are not study wall time."""
import csv,hashlib,json
from pathlib import Path
root=Path('validation/autodesn/remediation');rows=[]
for p in sorted((root/'evidence').glob('*resources.json')):
    s=json.loads(p.read_text())
    if 'command' not in s or 'elapsed_seconds' not in s:continue
    rows.append(dict(record=p.name,record_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
                     elapsed_seconds=s['elapsed_seconds'],exit_code=s.get('exit_code'),
                     cap_trigger=s.get('cap_trigger'),user_seconds=s.get('user_seconds'),
                     system_seconds=s.get('system_seconds'),
                     peak_child_rss_kib=s.get('peak_child_rss_kib'),
                     sampled_process_tree_pss_kib=s.get('sampled_peak_process_tree_pss_kib'),
                     aggregate_pss_status='corrected_recorder' if s.get('runner_sha256')=='fe75f9e2ce173f95ba06f1ffe282b55c90d1336527c8d3e10fe811227262d629' else 'consult_measurement_limits',
                     environment_anon_bytes=s.get('sampled_peak_environment_cgroup_anon_bytes'),
                     recorder_sha256=s.get('runner_sha256'),scope=s.get('scope','unrecorded')))
assert len({r['record'] for r in rows})==len(rows)
with (root/'evidence/runtime_process_ledger.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
result=dict(complete=True,observed_completed_invocations=len(rows),
            sum_process_wall_seconds=sum(r['elapsed_seconds'] for r in rows),
            sum_process_cpu_seconds=sum((r['user_seconds'] or 0)+(r['system_seconds'] or 0) for r in rows),
            nonzero_exit_invocations=sum(r['exit_code']!=0 for r in rows),
            wall_scope='Sum across observed invocations, including failures. Concurrent jobs overlap; this is not end-to-end study wall time.',
            outcome_scope='Includes intentional resource-cap fixtures and numerical checks; nonzero exits are not a model failure rate.',
            memory_scope='Per-record scope applies; early aggregate PSS limitations remain in resource_measurement_limits.json. Environment anon includes concurrent work; do not sum peaks.',
            inference_scope='Process times include imports/loading/compilation/saving. Matching chain computation records provide inference-only times; neither scope is a completed predictive comparison.',
            measurement_limits_sha256=hashlib.sha256((root/'evidence/resource_measurement_limits.json').read_bytes()).hexdigest(),
            no_new_full_rolling_forecast_time_measured=True)
(root/'evidence/runtime_process_ledger.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
