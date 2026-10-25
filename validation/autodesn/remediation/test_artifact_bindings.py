"""Independent failure fixtures for the posterior artifact identity gates."""
import hashlib,importlib.util,json,tempfile
from pathlib import Path
r=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('stability',r/'cross_budget.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checks=0
with tempfile.TemporaryDirectory(prefix='posterior-binding-') as temporary:
 d=Path(temporary);names=['contract.rds','configuration.json','model_metadata.csv']
 names += [f'{stem}_{k}{suffix}' for k in range(1,5) for stem,suffix in [('chain','.rds'),('chain','_status.json'),('trace','.csv')]]
 for name in names:(d/name).write_bytes(b'isolated identity fixture; never a fitted posterior')
 files={name:hashlib.sha256((d/name).read_bytes()).hexdigest() for name in names}
 m.verify_validation_inputs(d,dict(input_files_sha256=files));checks+=1
 for name in names:
  p=d/name;original=p.read_bytes();p.write_bytes(original+b'!')
  try:m.verify_validation_inputs(d,dict(input_files_sha256=files))
  except AssertionError:checks+=1
  else:raise AssertionError('Missed content mutation '+name)
  p.write_bytes(original)
  partial=files.copy();del partial[name]
  try:m.verify_validation_inputs(d,dict(input_files_sha256=partial))
  except AssertionError:checks+=1
  else:raise AssertionError('Missed required identity '+name)
 bad=files|{'../outside':hashlib.sha256(b'x').hexdigest()}
 try:m.verify_validation_inputs(d,dict(input_files_sha256=bad))
 except AssertionError:checks+=1
 else:raise AssertionError('Accepted a noncanonical input path')
 missing=m.common_rhs_screen('absent','not-a-target','F2',d,d)
 assert not missing['available'] and not missing['screen_passed'];checks+=1
status=json.loads((r/'artifacts/common_rhs_monitors/F2/pilot/status.json').read_text())
screen=m.common_rhs_screen('pilot',status['source_checkpoints'][0]['target_id'],'F2',r/'artifacts',r/'evidence/generalized_common_fixture')
assert screen['available'] and not screen['screen_passed'];checks+=1
left=json.loads((r/'evidence/F1_pilot_default_path_qualification.json').read_text())
right=json.loads((r/'evidence/F1_pilot_explicit_directory_qualification.json').read_text())
assert left==right and not left['screen_passed'];checks+=1
record=dict(complete=True,checks=checks,all_passed=True,source_sha256=hashlib.sha256((r/'cross_budget.py').read_bytes()).hexdigest(),test_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Hash completeness, all-file mutation rejection, path confinement, missing/failed common-coordinate gate, and exact default/explicit-directory diagnostic agreement. Temporary bytes are identity fixtures, never MCMC evidence or a posterior convergence test.')
(r/'evidence/artifact_binding_fixtures.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
