"""Foreground execution with observed completion and measured Linux resources."""
import argparse,hashlib,json,os,signal,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--record',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--max-seconds',type=float);p.add_argument('--max-cgroup-anon-bytes',type=int);p.add_argument('command',nargs=argparse.REMAINDER);a=p.parse_args()
a.log.parent.mkdir(parents=True,exist_ok=True);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest();t=time.monotonic();peak_pss=peak_cgroup_anon=0;cap_trigger=None

def host_pid(local_pid):
 # The runner has a private PID namespace, while /proc exposes host PIDs.
 namespace=os.readlink('/proc/self/ns/pid')
 for entry in Path('/proc').iterdir():
  if not entry.name.isdigit():continue
  try:
   if os.readlink(entry/'ns/pid')!=namespace:continue
   for line in (entry/'status').read_text().splitlines():
    if line.startswith('NSpid:') and int(line.split()[-1])==local_pid:return int(entry.name)
  except (FileNotFoundError,PermissionError,ProcessLookupError):pass
 return None

def descendants(pid):
 # /proc/task/*/children is absent on this kernel. Reconstruct the tree from
 # host-mounted PPid fields, restricted to this runner's PID namespace.
 namespace=os.readlink('/proc/self/ns/pid');records=[];mapping={}
 for entry in Path('/proc').iterdir():
  if not entry.name.isdigit():continue
  try:
   if os.readlink(entry/'ns/pid')!=namespace:continue
   values={line.split(':',1)[0]:line.split(':',1)[1].strip() for line in (entry/'status').read_text().splitlines() if ':' in line}
   host=int(entry.name);mapping[int(values['NSpid'].split()[-1])]=host
   records.append((host,int(values['PPid'])))
  except (FileNotFoundError,PermissionError,ProcessLookupError,KeyError):pass
 hosts={host for host,parent in records};result={pid};changed=True
 while changed:
  changed=False
  for host,parent in records:
   translated=parent if parent in hosts else mapping.get(parent)
   if host not in result and translated in result:result.add(host);changed=True
 return result

def tree_pss(pid):
 total=0
 for child in descendants(pid):
  try:
   for line in Path(f'/proc/{child}/smaps_rollup').read_text().splitlines():
    if line.startswith('Pss:'):total+=int(line.split()[1]);break
  except (FileNotFoundError,PermissionError,ProcessLookupError):pass
 return total

with a.log.open('w') as log:
 proc=subprocess.Popen(a.command,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 host=host_pid(proc.pid)
 while True:
  pid,status,usage=os.wait4(proc.pid,os.WNOHANG)
  if pid:break
  peak_pss=max(peak_pss,tree_pss(host) if host is not None else 0)
  try:
   for line in Path('/sys/fs/cgroup/memory.stat').read_text().splitlines():
    if line.startswith('anon '):
     anon=int(line.split()[1]);peak_cgroup_anon=max(peak_cgroup_anon,anon)
     if a.max_cgroup_anon_bytes and anon>a.max_cgroup_anon_bytes:cap_trigger='environment_cgroup_anon_cap'
     break
  except FileNotFoundError:pass
  if a.max_seconds and time.monotonic()-t>a.max_seconds:cap_trigger='wall_time_cap'
  if cap_trigger:os.killpg(proc.pid,signal.SIGTERM)
  time.sleep(.5)
 proc.returncode=os.waitstatus_to_exitcode(status)
r=dict(command=a.command,cap_trigger=cap_trigger,max_seconds=a.max_seconds,max_cgroup_anon_bytes=a.max_cgroup_anon_bytes,exit_code=proc.returncode,elapsed_seconds=time.monotonic()-t,peak_child_rss_kib=usage.ru_maxrss,sampled_peak_process_tree_pss_kib=peak_pss,sampled_peak_environment_cgroup_anon_bytes=peak_cgroup_anon,user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,runner_sha256=runner_hash,scope='Observed Linux wait4 child completion; host-PID-resolved process-tree PSS sampled every 0.5s; cgroup anon includes other active jobs')
a.record.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r));raise SystemExit(proc.returncode)
