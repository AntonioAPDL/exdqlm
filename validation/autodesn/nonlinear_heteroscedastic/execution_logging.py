"""Measured invocations whose incomplete records survive a lost session."""
from pathlib import Path
import json,shutil

def save_records(path,records):
 path=Path(path);tmp=path.with_name(path.name+'.partial')
 tmp.write_text(json.dumps(records,indent=2));tmp.replace(path)
 if tmp.exists():tmp.unlink()

def run_measured(measured,records,record_path,base,name,command):
 base=Path(base);memory=base/(name+'_memory.json');log=base/(name+'.log')
 if name in records or memory.exists() or log.exists():
  i=1
  while (f'{name}_previous_{i}' in records or
         (base/f'{name}_previous_{i}.log').exists() or
         (base/f'{name}_previous_{i}_memory.json').exists()):i+=1
  previous=f'{name}_previous_{i}'
  # The live memory file may be newer than the coordinator's last status.
  old=json.loads(memory.read_text()) if memory.exists() else records.get(name,{})
  records[previous]=dict(old,recovered_invocation=True)
  for source,suffix in [(log,'.log'),(memory,'_memory.json')]:
   if source.exists():shutil.copyfile(source,base/(previous+suffix))
 # Persist the rotation before starting new work, so another loss cannot
 # overwrite the earlier backup or count an old completed invocation twice.
 records[name]=dict(complete=False,exit_code=None,invocation_wall_seconds=0,
  observation_pending=True,note='No timing sample recorded yet; inspect live memory file after interruption.')
 save_records(record_path,records)
 if memory.exists():memory.unlink()
 result=measured.run(command,log,memory);records[name]=result
 save_records(record_path,records)
 return result
