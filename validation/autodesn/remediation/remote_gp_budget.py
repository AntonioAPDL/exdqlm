"""Export an explicitly named native GP budget, including its compressed log."""
import argparse,base64,hashlib,io,json,os,platform,subprocess,zipfile
from pathlib import Path
from remote_gp import sha

r=Path('validation/autodesn/remediation')
def export(seed,particles,rows=2000,output=None):
 label=f'gp_n{rows}_p{particles}_s{seed}_native'
 paths=list((r/'artifacts'/label).glob('*'))+list((r/'evidence').glob(label+'_resources.json'))
 paths+=list((r/'artifacts/gp_sources').glob('*/manifest.json'))
 paths+=[p for p in (r/'artifacts/gp_sources').glob('*/*') if p.suffix in ('.jl','.py','.toml')]
 paths=sorted(set(p for p in paths if p.is_file() and not p.name.endswith(('.partial','.writing','.tmp'))))
 assert sum(p.stat().st_size for p in paths)<=20_000_000
 manifest=dict(seed=seed,particles=particles,rows=rows,native_pin='2ad372db2b8bea176e3b32a769bfb5d6cff80866',
  checkout_sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
  host=dict(platform=platform.platform(),cpu_count=os.cpu_count(),cpu_model=next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')),'unknown')),
  members=[dict(path=str(p),bytes=p.stat().st_size,sha256=sha(p)) for p in paths],posterior_qualified=False,
  complete_fit_status_present=(r/'artifacts'/label/'status.toml').exists(),hardware_comparison_controlled=False)
 b=io.BytesIO()
 with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as z:
  for p in paths:z.write(p,str(p))
  z.writestr('remote_execution_manifest.json',json.dumps(manifest,indent=2)+'\n')
 data=b.getvalue();digest=hashlib.sha256(data).hexdigest();encoded=base64.b64encode(data).decode()
 if output:output.write_bytes(data)
 print(f'AUTODESN_GP_EXPORT_BEGIN {seed} {len(data)} {digest}',flush=True)
 for i,start in enumerate(range(0,len(encoded),12000)):print(f'AUTODESN_GP_EXPORT_PART {seed} {i} {encoded[start:start+12000]}',flush=True)
 print(f'AUTODESN_GP_EXPORT_END {seed} {digest}',flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--seed',type=int,required=True);p.add_argument('--particles',type=int,choices=[16,32,64],required=True);p.add_argument('--output',type=Path);a=p.parse_args()
 assert a.seed>0
 export(a.seed,a.particles,output=a.output)
