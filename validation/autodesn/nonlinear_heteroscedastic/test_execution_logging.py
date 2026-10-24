"""Actual subprocess/file checks for lost-session log preservation."""
import json,sys,tempfile,unittest,subprocess
from pathlib import Path
from execution_logging import run_measured
class Measured:
 @staticmethod
 def run(command,log,memory):
  with log.open('w') as f:r=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT)
  out=dict(complete=True,exit_code=r.returncode,invocation_wall_seconds=.01)
  memory.write_text(json.dumps(out));return out
class ExecutionLogContracts(unittest.TestCase):
 def test_orphaned_timing_and_stdout_survive_two_new_jobs(self):
  with tempfile.TemporaryDirectory() as t:
   b=Path(t);state=b/'status.json';records={}
   (b/'fit.log').write_text('original interrupted output\n')
   old=dict(complete=False,exit_code=None,invocation_wall_seconds=123.45)
   (b/'fit_memory.json').write_text(json.dumps(old))
   run_measured(Measured,records,state,b,'fit',[sys.executable,'-c',"print('new failure');raise SystemExit(2)"])
   self.assertEqual((b/'fit_previous_1.log').read_text(),'original interrupted output\n')
   self.assertEqual(records['fit_previous_1']['invocation_wall_seconds'],123.45)
   records=json.loads(state.read_text())
   run_measured(Measured,records,state,b,'fit',[sys.executable,'-c',"print('new success')"])
   self.assertEqual((b/'fit_previous_2.log').read_text(),'new failure\n')
   self.assertEqual(records['fit_previous_2']['exit_code'],2)
   self.assertEqual(records['fit']['exit_code'],0)
 def test_live_observation_overrides_stale_coordinator_status(self):
  with tempfile.TemporaryDirectory() as t:
   b=Path(t);records={'fit':dict(complete=True,invocation_wall_seconds=100)}
   (b/'fit_memory.json').write_text(json.dumps(dict(complete=False,invocation_wall_seconds=7.25)))
   (b/'fit.log').write_text('latest unfinished output\n')
   run_measured(Measured,records,b/'status.json',b,'fit',[sys.executable,'-c','pass'])
   self.assertFalse(records['fit_previous_1']['complete'])
   self.assertEqual(records['fit_previous_1']['invocation_wall_seconds'],7.25)
if __name__=='__main__':unittest.main()
