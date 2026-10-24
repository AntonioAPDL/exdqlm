"""Exercise PID translation, aggregate fork memory, and explicit wall caps."""
import hashlib,json,subprocess,sys,tempfile
from pathlib import Path
root=Path('validation/autodesn/remediation');runner=root/'run_process.py'
with tempfile.TemporaryDirectory(dir=root/'artifacts') as directory:
 d=Path(directory);record=d/'memory.json';log=d/'memory.log'
 child='import time; x=b"x"*(128*1024*1024); time.sleep(2)'
 parent=f'import subprocess,sys; subprocess.run([sys.executable,"-c",{child!r}],check=True)'
 subprocess.run([sys.executable,str(runner),'--record',str(record),'--log',str(log),sys.executable,'-c',parent],check=True)
 m=json.loads(record.read_text());assert m['sampled_peak_process_tree_pss_kib']>120*1024,m
 cap=d/'cap.json'
 result=subprocess.run([sys.executable,str(runner),'--record',str(cap),'--log',str(d/'cap.log'),'--max-seconds','1',sys.executable,'-c','import time; time.sleep(10)'])
 c=json.loads(cap.read_text());assert c['cap_trigger']=='wall_time_cap' and result.returncode!=0 and c['elapsed_seconds']<5,c
out=dict(complete=True,aggregate_child_memory_passed=True,wall_cap_passed=True,observed_test_tree_pss_kib=m['sampled_peak_process_tree_pss_kib'],runner_sha256=hashlib.sha256(runner.read_bytes()).hexdigest(),scope='Controlled subprocess-tree fixture, not production peak memory')
(root/'evidence/resource_selftest.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
