"""Independent diagnostics must recognize independent and autocorrelated draws."""
import unittest
import numpy as np
from diagnostics import diagnostics

class DiagnosticTests(unittest.TestCase):
 def test_independent(self):
  r=diagnostics(np.random.default_rng(421).normal(size=(4,12000)))
  self.assertLess(r['rhat'],1.002)
  self.assertTrue(35000<r['bulk_ess']<65000)
  self.assertGreater(r['tail_ess'],30000)
 def test_autocorrelation(self):
  rng=np.random.default_rng(422);x=np.zeros((4,22000));e=rng.normal(size=x.shape)
  for i in range(1,x.shape[1]):x[:,i]=.8*x[:,i-1]+e[:,i]
  r=diagnostics(x[:,2000:]);expected=x[:,2000:].size*(1-.8)/(1+.8)
  self.assertTrue(.7*expected<r['bulk_ess']<1.3*expected)
  self.assertLess(r['rhat'],1.005)
 def test_chain_shift(self):
  x=np.random.default_rng(423).normal(size=(4,12000));x[0]+=1
  self.assertGreater(diagnostics(x)['rhat'],1.03)

if __name__=='__main__':unittest.main()
