"""Reproduce the fixed first-ladder fold summary from bound completed artifacts."""
from pathlib import Path
import argparse,datetime,hashlib,json
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('validation/autodesn/remediation/evidence/fold_F1_production_32000_bound_summary.json'));a=p.parse_args()
r=Path('validation/autodesn/remediation');rows=[];inputs={}
for cutoff in [1500,2000]:
 e=r/f'evidence/fold_fits/cutoff{cutoff}/F1';d=r/f'artifacts/fold_fits/cutoff{cutoff}/F1/production_32000_pilotguide'
 paths=[e/'F1_production_32000_pilotguide_qualification.json',e/'F1_production_32000_pilotguide_common_rhs_diagnostics.json',r/f'evidence/fold{cutoff}_F1_production_32000_pilotguide_checkpoint_validation.json',r/f'evidence/fold{cutoff}_F1_production_32000_pilotguide_resources.json']
 q,c,v,res=[json.loads(x.read_text()) for x in paths]
 assert v['complete'] and len(v['input_files_sha256'])==15 and res['exit_code']==0 and res['cap_trigger'] is None
 for name,sha in v['input_files_sha256'].items():assert hashlib.file_digest((d/name).open('rb'),'sha256').hexdigest()==sha
 assert q['target_id']==v['target_id'] and all(q['trace_sha256'][f'trace_{k}.csv']==v['input_files_sha256'][f'trace_{k}.csv'] for k in range(1,5))
 for path in paths:inputs[str(path)]=hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
 rows.append(dict(cutoff=cutoff,family='F1',warmup_per_chain=8000,retained_per_chain=32000,chains=4,raw_identities_verified=True,screen_passed=q['screen_passed'],maximum_rhat=q['maximum_rhat'],minimum_ess=min(q['minimum_bulk_ess'],q['minimum_tail_ess']),maximum_category_frequency_range=max(q['frequency_ranges'].values()),common270_passed=c['screen_passed'],common_maximum_rhat=c['maximum_rhat'],common_minimum_ess=min(c['minimum_bulk_ess'],c['minimum_tail_ess']),process_wall_seconds=res['elapsed_seconds'],peak_process_tree_pss_kib=res['sampled_peak_process_tree_pss_kib'],target_id=v['target_id'],qualified=False,forecast_allowed=False))
record=dict(complete=True,observed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),rows=rows,input_sha256=inputs,producer_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Both first-ladder chronological F1 budgets complete and all15 raw identities bind at each cutoff. Common270 coefficients/scales pass, architecture/full-trace screens fail. No selected mean or forecast promotion. Process wall includes startup/checkpointing, distinct from sampler-only time.')
assert not a.output.exists(),'Preserve completed derived summaries; choose a fresh output path'
a.output.write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(rows))
