"""Freeze the complete normalizer reference closure before either calculation."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
r=Path('validation/autodesn/remediation')
names=['gp_evidence.jl','gp_smc_normalizer_reference.jl','gp_smc_normalizer_reference.py','gp_leaf_prior_integration.py','launch_gp_normalizer_reference.py']
manifest={n:hashlib.sha256((r/n).read_bytes()).hexdigest() for n in names}
key=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()
snapshot=r/'artifacts/gp_normalizer_sources'/key;snapshot.mkdir(parents=True,exist_ok=True)
for n,sha in manifest.items():
    p=snapshot/n
    if p.exists():assert hashlib.sha256(p.read_bytes()).hexdigest()==sha
    else:shutil.copyfile(r/n,p);p.chmod(0o444)
(snapshot/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
registration=r/'evidence/gp_smc_normalizer_registration.json'
assert not registration.exists()
registration.write_text(json.dumps(dict(snapshot=key,source_sha256=manifest,registered_before_execution=True,replicas=64,particles=128,seeds=[7466501,7466564,7467501,7467564],schedule=[1,2,4],arms=dict(no_rejuvenation=[0,0],native_rejuvenation=[2,1]),reference=dict(powers=[16,18],scrambles=8,seeds=[7466101,7466108]),tolerance='6 combined Monte Carlo SE + 2 QMC refinement difference + 0.2% reference magnitude',posterior_qualified=False),indent=2)+'\n')
commands=[['/workspace/scratch/9cf6195923f9/runtime/julia_native/julia-1.10.10/bin/julia','--project=/workspace/scratch/9cf6195923f9/runtime/AutoGP.jl',str(snapshot/'gp_smc_normalizer_reference.jl')],[os.environ['AUTODESN_SCIENTIFIC_PYTHON'],str(snapshot/'gp_smc_normalizer_reference.py')]]
for name,cmd in zip(['native','qmc'],commands):
    code=subprocess.call([sys.executable,str(r/'run_process.py'),'--record',str(r/'evidence'/f'gp_smc_normalizer_{name}_resources.json'),'--log',str(r/'artifacts'/f'gp_smc_normalizer_{name}_attempt1.log'),'--max-seconds','1800','--max-cgroup-anon-bytes','6400000000']+cmd)
    if code:raise SystemExit(code)
