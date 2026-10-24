"""Prepare bounded-size Git checkpoint objects without dropping predictive draws."""
from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent

def main():
 e=HERE/'evidence';study=json.loads((HERE/'study.json').read_text());items=[]
 ignore=HERE/'.gitignore';rules=ignore.read_text().splitlines()
 for case in study['scenarios']:
  name=case['id']+'_forecast_checkpoint.rds';p=e/name
  assert p.exists(),f'Missing completed predictive checkpoint: {p}'
  data=p.read_bytes();size=len(data);sha=hashlib.sha256(data).hexdigest()
  entry=dict(name=name,bytes=size,sha256=sha,mode='whole',parts=[])
  for old in e.glob(name+'.part-*'):old.unlink()
  if size>9_000_000:
   entry['mode']='parts'
   for k,start in enumerate(range(0,size,7_000_000),1):
    part=e/f'{name}.part-{k:02}';chunk=data[start:start+7_000_000];part.write_bytes(chunk)
    entry['parts'].append(dict(name=part.name,bytes=len(chunk),sha256=hashlib.sha256(chunk).hexdigest()))
   rule='evidence/'+name
   if rule not in rules:rules.append(rule)
  items.append(entry)
 ignore.write_text('\n'.join(rules)+'\n')
 (e/'checkpoint_parts.json').write_text(json.dumps(dict(complete=True,part_bytes=7_000_000,files=items),indent=2))
 print('Prepared predictive checkpoint delivery:',[(x['name'],x['mode'],len(x['parts'])) for x in items])
if __name__=='__main__':main()
