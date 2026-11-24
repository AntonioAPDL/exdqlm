"""Run bounded observed stages from the repository root; never schedules detached work."""
import argparse,datetime,hashlib,json,os,signal,subprocess,time
from pathlib import Path
import psutil

ROOT=Path('validation/autodesn/median_small')
def run(stage,rscript,seconds=1800):
    evidence=ROOT/'evidence';evidence.mkdir(parents=True,exist_ok=True)
    record=evidence/f'{stage}_resources.json'
    attempt=1
    while record.exists():
        attempt+=1;record=evidence/f'{stage}_attempt{attempt}_resources.json'
    script='tests.R' if stage=='test' else 'profile.R' if stage=='profile' else 'study.R'
    command=[rscript,str(ROOT/script)]+([] if stage in ('test','profile') else [stage])
    env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',MAKEFLAGS='-j2')
    source_paths=list(Path('R').glob('*.R'))+[ROOT/'common.R',ROOT/script,Path(__file__)]+[Path('src')/f for f in ('sampling_utils.cpp','sampling_truncnorm.cpp','exAL.cpp')]
    sources={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths}
    log=record.with_suffix('.log');started=time.monotonic();peak=0;cap=None
    with log.open('w') as output:
        process=subprocess.Popen(command,env=env,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        while process.poll() is None:
            try:
                parent=psutil.Process(process.pid);procs=[parent]+parent.children(recursive=True)
                memory=0
                for p in procs:
                    try:memory+=getattr(p.memory_full_info(),'pss',p.memory_info().rss)
                    except psutil.Error:pass
                peak=max(peak,memory)
                if memory>3*1024**3:cap='memory'
                if time.monotonic()-started>seconds:cap='wall'
                if cap:os.killpg(process.pid,signal.SIGTERM);break
            except psutil.Error:pass
            time.sleep(.5)
        code=process.wait()
    result=dict(stage=stage,attempt=attempt,command=command,exit_code=code,cap_trigger=cap,
        elapsed_seconds=time.monotonic()-started,sampled_peak_process_tree_pss_bytes=peak,
        memory_cap_bytes=3*1024**3,wall_cap_seconds=seconds,
        source_sha256=sources[str(ROOT/script)],sources_sha256=sources,
        sources_unchanged=all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in sources.items()),
        log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),observed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    record.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='sources_sha256'}),flush=True)
    if code:raise SystemExit(code)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('stage',choices=['generate','test','profile','screen','fit','forecast']);p.add_argument('--rscript',default='Rscript');a=p.parse_args();run(a.stage,a.rscript)
