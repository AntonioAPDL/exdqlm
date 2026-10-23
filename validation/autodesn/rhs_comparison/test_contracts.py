"""Small contracts for alignment, score definitions, and qualification handling."""
import sys
import unittest

import numpy as np
import pandas as pd
from scipy.integrate import quad
from scipy.special import ndtr

from support import LEGACY, configuration, sample_score, validate_scores, validate_native_checks
from report import check_status

sys.path.insert(0, str(LEGACY))
from scoring import condition_one, mixture_score


class Contracts(unittest.TestCase):
    def test_frozen_protocol(self):
        cfg = configuration()
        self.assertEqual((cfg["fit_start"], cfg["fit_end"], cfg["first_origin"], cfg["last_origin"], cfg["H"]),
            (501, 2500, 2500, 2970, 30))
        self.assertEqual(cfg["origins"] * cfg["H"], 14130)
        self.assertEqual(cfg["rhs_control"], dict(tau0=1, slab_scale=2, slab_df=4))

    def test_gaussian_conditioning_all_prefixes_without_future_peeking(self):
        rng = np.random.default_rng(81)
        a = rng.normal(size=(15, 15)); c = a @ a.T + np.eye(15)
        mu = rng.normal(size=15); y = rng.normal(size=15); m = mu.copy(); v = c.copy()
        for n in range(14):
            if n:
                expected = mu[n:] + c[n:, :n] @ np.linalg.solve(c[:n, :n], y[:n] - mu[:n])
                covariance = c[n:, n:] - c[n:, :n] @ np.linalg.solve(c[:n, :n], c[:n, n:])
                np.testing.assert_allclose(m, expected, atol=1e-11)
                np.testing.assert_allclose(v, covariance, atol=1e-11)
            altered = y.copy(); altered[n + 1:] += 1e9
            m2, v2 = condition_one(m, v, altered[n]); m, v = condition_one(m, v, y[n])
            np.testing.assert_array_equal(m, m2); np.testing.assert_array_equal(v, v2)

    def test_exact_mixture_crps_and_sample_crps_definitions(self):
        mu = np.array([-1., 2.]); sd = np.array([.5, 1.3]); w = np.array([.2, .8]); y = .7
        score = mixture_score(y, mu, sd, w)
        cdf = lambda x: float(w @ ndtr((x - mu) / sd))
        integral = quad(lambda x: cdf(x)**2, -np.inf, y)[0] + quad(lambda x: (1 - cdf(x))**2, y, np.inf)[0]
        self.assertAlmostEqual(score["crps"], integral, places=9)
        x = np.array([-2., -.1, 1., 4.])
        sample = pd.DataFrame(dict(yrep=x, mu=x / 2, sd=np.ones(4)))
        self.assertAlmostEqual(sample_score(y, sample)[1],
            np.mean(abs(x - y)) - np.mean(abs(x[:, None] - x[None, :])) / 2, places=12)

    def test_alignment_rejects_wrong_target_or_missing_pair(self):
        cfg = configuration("smoke"); y = pd.read_csv(LEGACY / "input/C1.csv").y.to_numpy(); rows = []
        for o in range(110, 116):
            for h in range(1, 6):
                actual = y[o + h - 1]
                row = mixture_score(actual, [0], [1], [1])
                row.update(origin=o, horizon=h, target=o + h, actual=actual, model="AutoGP"); rows.append(row)
        scores = pd.DataFrame(rows); validate_scores(scores, cfg, "AutoGP")
        bad = scores.copy(); bad.loc[0, "target"] += 1
        with self.assertRaises(AssertionError):
            validate_scores(bad, cfg, "AutoGP")
        with self.assertRaises(ValueError):
            validate_scores(scores.iloc[1:], cfg, "AutoGP")

    def test_smoke_and_unqualified_runs_cannot_enter_full_comparison(self):
        status = dict(complete=True, mode="smoke", qualified=False, benchmark_complete=False,
            posterior_updates=False, model_weight_updates=False, innovation_seed=1066020,
            model="AutoDESN RHS", fit_rows=80, origins=6, score_pairs=30, outer_draws=12, inner_paths=2)
        check_status(status, "rhs", configuration("smoke"), None)
        with self.assertRaises(ValueError):
            check_status(status, "rhs", configuration(), None)
        bad = dict(status, qualified=True)
        with self.assertRaises(ValueError):
            check_status(bad, "rhs", configuration("smoke"), None)
        bad = dict(status, mode="full")
        with self.assertRaises(ValueError):
            check_status(bad, "rhs", configuration(), None)

    def test_gp_native_evidence_cannot_pass_with_missing_or_nan_checks(self):
        frame = pd.DataFrame([(o, j, 0., 0.) for o in (2500, 2735, 2970) for j in range(1, 9)],
            columns=["origin", "component", "mean_max_error", "covariance_max_error"])
        np.testing.assert_array_equal(validate_native_checks(frame), [0., 0.])
        with self.assertRaises(ValueError):
            validate_native_checks(frame.iloc[0:0])
        with self.assertRaises(ValueError):
            validate_native_checks(frame.iloc[1:])
        bad = frame.copy(); bad["mean_max_error"] = np.nan
        with self.assertRaises(ValueError):
            validate_native_checks(bad)


if __name__ == "__main__":
    unittest.main()
