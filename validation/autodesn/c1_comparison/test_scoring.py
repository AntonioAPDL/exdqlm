import unittest,json,tomllib,hashlib
from pathlib import Path
import numpy as np
from scipy.integrate import quad
from scipy.special import ndtr
from scoring import condition_one,mixture_score
ROOT=Path(__file__).resolve().parent
class Contracts(unittest.TestCase):
    def test_frozen_input_and_configuration(self):
        j=json.loads((ROOT/'configuration.json').read_text());t=tomllib.loads((ROOT/'configuration.toml').read_text())
        for key,value in t.items(): self.assertEqual(value,j[key])
        for name,digest in j['input_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/'input'/name).read_bytes()).hexdigest(),digest)
    def test_conditioning_all_prefixes_and_future_invariance(self):
        rng=np.random.default_rng(81);a=rng.normal(size=(15,15));c=a@a.T+np.eye(15);mu=rng.normal(size=15);y=rng.normal(size=15)
        m=mu.copy();v=c.copy()
        for n in range(14):
            if n:
                expected=mu[n:]+c[n:,:n]@np.linalg.solve(c[:n,:n],y[:n]-mu[:n])
                ec=c[n:,n:]-c[n:,:n]@np.linalg.solve(c[:n,:n],c[:n,n:])
                np.testing.assert_allclose(m,expected,atol=1e-11);np.testing.assert_allclose(v,ec,atol=1e-11)
            altered=y.copy();altered[n+1:]+=1e9
            m2,v2=condition_one(m,v,altered[n]);m,v=condition_one(m,v,y[n])
            np.testing.assert_array_equal(m,m2);np.testing.assert_array_equal(v,v2)
    def test_crps_against_cdf_integral_and_normal_identity(self):
        mu=np.array([-1.,2.]);sd=np.array([.5,1.3]);w=np.array([.2,.8]);y=.7
        x=mixture_score(y,mu,sd,w)
        cdf=lambda t:float(w@ndtr((t-mu)/sd))
        integral=quad(lambda t:cdf(t)**2,-np.inf,y)[0]+quad(lambda t:(1-cdf(t))**2,y,np.inf)[0]
        self.assertAlmostEqual(x['crps'],integral,places=9)
        n=mixture_score(0,[0],[1],[1]);self.assertAlmostEqual(n['crps'],(np.sqrt(2)-1)/np.sqrt(np.pi),places=12)
        self.assertAlmostEqual(n['negative_log_score'],.5*np.log(2*np.pi),places=12)
        duplicate=mixture_score(0,[0,0],[1,1],[.5,.5])
        for k in n:self.assertAlmostEqual(n[k],duplicate[k],places=10)
if __name__=='__main__':unittest.main()
