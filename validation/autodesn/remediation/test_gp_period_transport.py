"""Exercise real exporter/decoder paths without claiming a fitted GP."""
import contextlib,gzip,hashlib,io,json,os,subprocess,tempfile
from pathlib import Path
import remote_gp_budget
from import_gp_log import decode

repository=Path.cwd();root=Path('validation/autodesn/remediation')
commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
results=[]
with tempfile.TemporaryDirectory(prefix='period-export-',dir=root/'artifacts') as temporary:
    base=Path(temporary).resolve();os.chdir(base)
    try:
        for moves,seed in [(0,9999960),(10,9999961)]:
            label=f'gp_n2000_p16_s{seed}'+('_native' if moves==0 else '')
            d=root/'artifacts'/label;d.mkdir(parents=True)
            (d/'status.toml').write_text('complete = false\n')
            (d/'numeric.csv').write_text('x\n1.5\n')
            (d/'ignored.partial').write_text('must not be exported')
            payload=b'controlled inference log\n';(d/'inference.log.gz').write_bytes(gzip.compress(payload,mtime=0))
            output=io.StringIO()
            with contextlib.redirect_stdout(output):remote_gp_budget.export(seed,16,period_moves=moves)
            destination=base/f'replay_{moves}';result=decode(output.getvalue(),seed,commit,destination)
            manifest=json.loads((destination/'remote_execution_manifest.json').read_text())
            assert manifest['period_moves_per_particle_per_stage']==moves
            assert not any(m['path'].endswith('.partial') for m in manifest['members'])
            assert gzip.decompress((destination/d/'inference.log.gz').read_bytes())==payload
            assert (destination/d/'status.toml').read_text()=='complete = false\n'
            results.append(dict(period_moves=moves,verified_members=result['members'],bundle_sha256=result['bundle_sha256'],incomplete_fit_remains_incomplete=True))
    finally:os.chdir(repository)
record=dict(complete=True,checks=results,new_forecasts_issued=False,source_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'remote_gp_budget.py',root/'import_gp_log.py',Path(__file__)]},scope='Actual period0/10 exporter/decoder fixtures, incomplete-status preservation, gzip CRC/content and partial-file exclusion. No GP fit executed.')
(root/'evidence/gp_period_transport_checks.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k!='source_sha256'}))
