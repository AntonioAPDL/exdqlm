"""Run the large-bank cases sequentially and record measured execution status.

Run with the project-local R on PATH. --wait-pid permits an already-started
first case to finish before the other cases start; it does not restart it.
"""
import argparse,json,os,subprocess,time
from pathlib import Path

HERE=Path(__file__).resolve().parent

def run(command,log,memory):
    started=time.monotonic();peak=0;group=0;samples=0
    with log.open('w') as f:
        p=subprocess.Popen(command,stdout=f,stderr=subprocess.STDOUT)
        while p.poll() is None:
            try:
                status=Path(f'/proc/{p.pid}/status').read_text()
                vals=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
                peak=max(peak,int(vals.get('VmHWM','0 kB').split()[0]))
                group=max(group,int(Path('/sys/fs/cgroup/memory.current').read_text()))
                samples+=1
            except (FileNotFoundError,ProcessLookupError):pass
            time.sleep(.5)
    result=dict(complete=True,exit_code=p.returncode,invocation_wall_seconds=time.monotonic()-started,
                process_peak_rss_kib=peak,cgroup_max_bytes_during_observation=group,samples=samples,
                memory_note='Parent R VmHWM; forked workers excluded. Cgroup samples include file cache and concurrent setup.')
    memory.write_text(json.dumps(result,indent=2));return result

def main():
    a=argparse.ArgumentParser();a.add_argument('--wait-pid',type=int);args=a.parse_args()
    base=HERE/'artifacts';base.mkdir(exist_ok=True);results={}
    if args.wait_pid:
        while Path(f'/proc/{args.wait_pid}').exists():time.sleep(1)
    for scenario in ['scaling_only','ridge_standardized']:
        d=base/scenario;d.mkdir(exist_ok=True)
        results[scenario]=run(['Rscript','--vanilla',str(HERE/'run.R'),'--scenario',scenario],
                            d/'execution.log',d/'process_memory.json')
        (base/'execution_status.json').write_text(json.dumps(results,indent=2))
    for scenario,method in [('requested','rhs'),('scaling_only','rhs'),('ridge_standardized','ridge')]:
        d=base/scenario/method;path=d/'status.json'
        if not path.exists() or not json.loads(path.read_text()).get('complete'):continue
        results[scenario+'_sensitivity']=run(['Rscript','--vanilla',str(HERE.parent/'rhs_comparison/sensitivity.R'),
            '--method',method,'--out',str(base/scenario)],d/'sensitivity.log',d/'sensitivity_memory.json')
        (base/'execution_status.json').write_text(json.dumps(results,indent=2))
    for name,cmd in [('export',['Rscript','--vanilla',str(HERE/'export.R')]),
                     ('analysis',['python',str(HERE/'analysis.py')])]:
        results[name]=run(cmd,base/(name+'.log'),base/(name+'_memory.json'))
        (base/'execution_status.json').write_text(json.dumps(results,indent=2))
    if any(v['exit_code'] for v in results.values()):raise SystemExit('Some stages failed; inspect execution_status.json and logs')

if __name__=='__main__':main()
