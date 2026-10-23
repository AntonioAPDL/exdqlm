"""Run the large-bank cases sequentially and record measured execution status.

Run with the project-local R on PATH. --wait-pid permits an already-started
first case to finish before the other cases start; it does not restart it.
"""
import argparse,json,os,subprocess,time
from pathlib import Path

HERE=Path(__file__).resolve().parent

def run(command,log,memory):
    started=time.monotonic();peak=0;group=0;samples=0;host_pid=None
    namespace=Path('/proc/self/ns/pid').stat().st_ino
    def resolve_pid(local_pid):
        # /proc may expose host IDs while subprocess.pid is namespace-local.
        for proc in Path('/proc').glob('[0-9]*'):
            try:
                if (proc/'ns/pid').stat().st_ino!=namespace:continue
                vals=dict(line.split(':',1) for line in (proc/'status').read_text().splitlines() if ':' in line)
                if int(vals.get('NSpid','0').split()[-1])==local_pid:return int(proc.name)
            except (FileNotFoundError,ProcessLookupError,PermissionError):pass
        return None
    def record(complete=False,exit_code=None):
        result=dict(complete=complete,exit_code=exit_code,invocation_wall_seconds=time.monotonic()-started,
            process_peak_rss_kib=peak or None,cgroup_max_bytes_during_observation=group,samples=samples,
            memory_note='Parent R VmHWM resolved using PID-namespace inode and NSpid; forked workers excluded. Cgroup includes file cache and other jobs.')
        tmp=memory.with_suffix(memory.suffix+'.partial');tmp.write_text(json.dumps(result,indent=2));tmp.replace(memory)
        return result
    with log.open('w') as f:
        p=subprocess.Popen(command,stdout=f,stderr=subprocess.STDOUT)
        while p.poll() is None:
            try:
                if host_pid is None:host_pid=resolve_pid(p.pid)
                if host_pid is None:time.sleep(.1);continue
                status=Path(f'/proc/{host_pid}/status').read_text()
                vals=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
                peak=max(peak,int(vals.get('VmHWM','0 kB').split()[0]))
                group=max(group,int(Path('/sys/fs/cgroup/memory.current').read_text()))
                samples+=1
                record()
            except (FileNotFoundError,ProcessLookupError):pass
            time.sleep(.5)
    return record(True,p.returncode)

def main():
    a=argparse.ArgumentParser();a.add_argument('--wait-pid',type=int);args=a.parse_args()
    base=HERE/'artifacts';base.mkdir(exist_ok=True);results={}
    if args.wait_pid:
        while Path(f'/proc/{args.wait_pid}').exists():time.sleep(1)
    for scenario in ['requested','scaling_only','ridge_standardized']:
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
