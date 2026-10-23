"""New-dataset score/protocol contracts; synthetic scores are never exported."""
import unittest,json,sys
from pathlib import Path
import numpy as np,pandas as pd
from scipy.stats import norm
from scipy.integrate import quad
from support import configuration,validate_scores,sha256,ROOT
sys.path.insert(0,str(ROOT.parent/'c1_comparison'))
from scoring import mixture_score,condition_one

class NHSContracts(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.cfg=configuration();y=pd.read_csv(ROOT/'input/series.csv').y.to_numpy()
  o=np.repeat(np.arange(2500,2971),30);h=np.tile(np.arange(1,31),471);target=o+h;a=y[target-1]
  lo90,lo50,hi50,hi90=norm.ppf([.05,.25,.75,.95])
  cls.rows=pd.DataFrame(dict(origin=o,horizon=h,target=target,actual=a,model='AutoDESN RHS',mean=np.zeros(len(a)),predictive_sd=np.ones(len(a)),lower90=lo90,lower50=lo50,median=0,upper50=hi50,upper90=hi90,squared_error=a*a,absolute_error=abs(a),crps=a*(2*norm.cdf(a)-1)+2*norm.pdf(a)-1/np.sqrt(np.pi),negative_log_score=.5*np.log(2*np.pi)+.5*a*a,covered50=(a>=lo50)&(a<=hi50),covered90=(a>=lo90)&(a<=hi90),width50=hi50-lo50,width90=hi90-lo90))
 def test_new_input_is_distinct_with_unchanged_candidates(self):
  self.assertEqual(self.cfg['series'],'NHS1')
  self.assertNotEqual(sha256(ROOT/'input/series.csv'),sha256(ROOT.parent/'c1_comparison/input/C1.csv'))
  self.assertEqual(sha256(ROOT/'input/specifications.rds'),sha256(ROOT.parent/'c1_comparison/input/specifications.rds'))
 def test_full_new_score_grid(self):
  x=validate_scores(self.rows,self.cfg,'AutoDESN RHS');self.assertEqual(len(x),14130)
 def test_old_C1_actuals_are_rejected(self):
  bad=self.rows.copy();old=pd.read_csv(ROOT.parent/'c1_comparison/input/C1.csv').y.to_numpy();bad.actual=old[bad.target.to_numpy()-1]
  with self.assertRaises(AssertionError):validate_scores(bad,self.cfg,'AutoDESN RHS')
 def test_missing_duplicate_and_misaligned_targets_rejected(self):
  with self.assertRaises(ValueError):validate_scores(self.rows.iloc[:-1],self.cfg,'AutoDESN RHS')
  bad=self.rows.copy();bad.loc[0,'target']+=1
  with self.assertRaises(AssertionError):validate_scores(bad,self.cfg,'AutoDESN RHS')
  bad=self.rows.copy();bad.iloc[1]=bad.iloc[0]
  with self.assertRaises(ValueError):validate_scores(bad,self.cfg,'AutoDESN RHS')
 def test_mixture_CRPS_against_independent_CDF_quadrature(self):
  mu=np.array([-.7,.2,1.1]);sd=np.array([.3,.7,1.2]);w=np.array([.2,.5,.3]);y=.63
  cdf=lambda z:float(w@norm.cdf((z-mu)/sd))
  reference=quad(lambda z:cdf(z)**2,-np.inf,y,epsabs=1e-10)[0]+quad(lambda z:(1-cdf(z))**2,y,np.inf,epsabs=1e-10)[0]
  result=mixture_score(y,mu,sd,w);self.assertAlmostEqual(result['crps'],reference,places=9)
  self.assertAlmostEqual(result['negative_log_score'],-np.log(w@norm.pdf(y,mu,sd)),places=12)
 def test_sequential_conditioning_matches_block_algebra(self):
  rng=np.random.default_rng(156);A=rng.normal(size=(7,7));C=A@A.T+np.eye(7);m=rng.normal(size=7);observed=np.array([.2,-.6,.4])
  mm=m.copy();CC=C.copy()
  for value in observed:mm,CC=condition_one(mm,CC,value)
  exact_m=m[3:]+C[3:,:3]@np.linalg.solve(C[:3,:3],observed-m[:3])
  exact_C=C[3:,3:]-C[3:,:3]@np.linalg.solve(C[:3,:3],C[:3,3:])
  np.testing.assert_allclose(mm,exact_m,atol=1e-12);np.testing.assert_allclose(CC,exact_C,atol=1e-12)
if __name__=='__main__':unittest.main()
