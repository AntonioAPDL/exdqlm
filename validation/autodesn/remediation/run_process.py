"""Run a foreground checkpointed command and preserve actual Linux child usage."""
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--record',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('command',nargs=argparse.REMAINDER);a=p.parse_args()
a.log.parent.mkdir(parents=True,exist_ok=True);t=time.monotonic()
with a.log.open('w') as log:
 proc=subprocess.Popen(a.command,stdout=log,stderr=subprocess.STDOUT)
 _,status,usage=os.wait4(proc.pid,0);proc.returncode=os.waitstatus_to_exitcode(status)
r=dict(command=a.command,exit_code=proc.returncode,elapsed_seconds=time.monotonic()-t,peak_child_rss_kib=usage.ru_maxrss,user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,scope='Linux wait4 foreground child; completion observed, not a background claim')
a.record.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r));raise SystemExit(proc.returncode)
