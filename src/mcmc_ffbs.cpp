/*
 * C++ FFBS kernels for dynamic MCMC state updates in exdqlm.
 *
 * Exports:
 * - mcmc_ffbs_smooth_cpp(...): forward filter + backward smoother moments.
 * - mcmc_ffbs_sample_cpp(...): forward filter + backward simulation draw.
 *
 * Contract:
 * - Implements the same FFBS algebra used by the legacy R MCMC helpers.
 * - Output field names intentionally match R-side consumers.
 *
 * Numerical policy:
 * - Covariance matrices are symmetrized after each update.
 * - SVD-based inversion is used for forecast covariance stabilization.
 * - Invalid/non-positive scalar forecast variances are floored at 1e-12.
 */

#include <RcppArmadillo.h>
#include <cmath>

// [[Rcpp::depends(RcppArmadillo)]]

namespace {

// Enforce exact symmetry after floating-point matrix algebra.
arma::mat symmetrize(const arma::mat& M) {
  return 0.5 * (M + M.t());
}

// Robust inverse via SVD with a singular-value floor.
arma::mat svd_inv(const arma::mat& M, double tol = 1e-12) {
  arma::mat U, V;
  arma::vec s;
  arma::svd(U, s, V, M);
  arma::vec s_inv = s;
  for (arma::uword i = 0; i < s_inv.n_elem; ++i) {
    if (!std::isfinite(s_inv(i)) || s_inv(i) <= tol) {
      s_inv(i) = tol;
    }
    s_inv(i) = 1.0 / s_inv(i);
  }
  return U * arma::diagmat(s_inv) * U.t();
}

// Draw N(mean, cov) using SVD on the symmetrized covariance.
arma::vec mvn_svd_draw(const arma::vec& mean, const arma::mat& cov, double tol = 0.0) {
  arma::mat S = symmetrize(cov);
  arma::mat U, V;
  arma::vec s;
  arma::svd(U, s, V, S);
  for (arma::uword i = 0; i < s.n_elem; ++i) {
    if (!std::isfinite(s(i)) || s(i) < tol) {
      s(i) = tol;
    }
  }
  arma::vec z(mean.n_elem);
  for (arma::uword i = 0; i < mean.n_elem; ++i) {
    z(i) = R::rnorm(0.0, 1.0);
  }
  return mean + U * arma::diagmat(arma::sqrt(s)) * z;
}

} // namespace

// Deterministic FFBS pass: returns filtered and smoothed state moments.
// [[Rcpp::export]]
Rcpp::List mcmc_ffbs_smooth_cpp(const arma::cube& GG,
                                const arma::vec& m0,
                                const arma::mat& C0,
                                const arma::mat& FF,
                                const arma::vec& y,
                                const arma::vec& ex_f,
                                const arma::vec& ex_q,
                                const arma::mat& df_mat) {
  const int p = GG.n_rows;
  const int TT = GG.n_slices;
  if (GG.n_cols != (unsigned)p || FF.n_rows != (unsigned)p || FF.n_cols != (unsigned)TT ||
      y.n_elem != (unsigned)TT || ex_f.n_elem != (unsigned)TT || ex_q.n_elem != (unsigned)TT) {
    Rcpp::stop("Dimension mismatch in mcmc_ffbs_smooth_cpp inputs.");
  }

  arma::mat m(p, TT, arma::fill::zeros);
  arma::cube C(p, p, TT, arma::fill::zeros);
  arma::mat sm(p, TT, arma::fill::zeros);
  arma::cube sC(p, p, TT, arma::fill::zeros);
  arma::vec sfe(TT, arma::fill::zeros);

  // Forward filtering recursion.
  for (int t = 0; t < TT; ++t) {
    arma::vec a;
    arma::mat P;
    if (t == 0) {
      a = GG.slice(0) * m0;
      P = GG.slice(0) * C0 * GG.slice(0).t();
    } else {
      a = GG.slice(t) * m.col(t - 1);
      P = GG.slice(t) * C.slice(t - 1) * GG.slice(t).t();
    }
    arma::mat R = symmetrize(P + (df_mat % P));
    double f = arma::as_scalar(FF.col(t).t() * a) + ex_f(t);
    arma::rowvec fB = FF.col(t).t() * R;
    double q = arma::as_scalar(fB * FF.col(t)) + ex_q(t);
    if (!std::isfinite(q) || q <= 0.0) {
      q = 1e-12;
    }

    m.col(t) = a + R * FF.col(t) * ((y(t) - f) / q);
    C.slice(t) = symmetrize(R - (R * FF.col(t) * FF.col(t).t() * R) / q);
    sfe(t) = (y(t) - f) / std::sqrt(q);
  }

  // Backward smoothing recursion (Rauch-Tung-Striebel form).
  sm.col(TT - 1) = m.col(TT - 1);
  sC.slice(TT - 1) = C.slice(TT - 1);
  for (int t = TT - 2; t >= 0; --t) {
    arma::mat P = GG.slice(t + 1) * C.slice(t) * GG.slice(t + 1).t();
    arma::mat R = symmetrize(P + (df_mat % P));
    arma::mat invR = svd_inv(R);
    arma::mat sB = C.slice(t) * GG.slice(t + 1).t() * invR;
    sm.col(t) = m.col(t) + sB * (sm.col(t + 1) - GG.slice(t + 1) * m.col(t));
    sC.slice(t) = symmetrize(C.slice(t) + sB * (sC.slice(t + 1) - R) * sB.t());
  }

  return Rcpp::List::create(
    Rcpp::Named("standard.forecast.errors") = sfe,
    Rcpp::Named("sm") = sm,
    Rcpp::Named("sC") = sC,
    Rcpp::Named("fm") = m,
    Rcpp::Named("fC") = C
  );
}

// Stochastic FFBS pass: returns one backward-sampled state trajectory.
// [[Rcpp::export]]
Rcpp::List mcmc_ffbs_sample_cpp(const arma::cube& GG,
                                const arma::vec& m0,
                                const arma::mat& C0,
                                const arma::mat& FF,
                                const arma::vec& y,
                                const arma::vec& ex_f,
                                const arma::vec& ex_q,
                                const arma::mat& df_mat) {
  const int p = GG.n_rows;
  const int TT = GG.n_slices;
  if (GG.n_cols != (unsigned)p || FF.n_rows != (unsigned)p || FF.n_cols != (unsigned)TT ||
      y.n_elem != (unsigned)TT || ex_f.n_elem != (unsigned)TT || ex_q.n_elem != (unsigned)TT) {
    Rcpp::stop("Dimension mismatch in mcmc_ffbs_sample_cpp inputs.");
  }

  arma::mat m(p, TT, arma::fill::zeros);
  arma::cube C(p, p, TT, arma::fill::zeros);
  arma::mat sam_theta(p, TT, arma::fill::zeros);
  arma::vec sfe(TT, arma::fill::zeros);

  // Forward filtering recursion.
  for (int t = 0; t < TT; ++t) {
    arma::vec a;
    arma::mat P;
    if (t == 0) {
      a = GG.slice(0) * m0;
      P = GG.slice(0) * C0 * GG.slice(0).t();
    } else {
      a = GG.slice(t) * m.col(t - 1);
      P = GG.slice(t) * C.slice(t - 1) * GG.slice(t).t();
    }
    arma::mat R = symmetrize(P + (df_mat % P));
    double f = arma::as_scalar(FF.col(t).t() * a) + ex_f(t);
    arma::rowvec fB = FF.col(t).t() * R;
    double q = arma::as_scalar(fB * FF.col(t)) + ex_q(t);
    if (!std::isfinite(q) || q <= 0.0) {
      q = 1e-12;
    }

    m.col(t) = a + R * FF.col(t) * ((y(t) - f) / q);
    C.slice(t) = symmetrize(R - (R * FF.col(t) * FF.col(t).t() * R) / q);
    sfe(t) = (y(t) - f) / std::sqrt(q);
  }

  // Backward simulation recursion.
  sam_theta.col(TT - 1) = mvn_svd_draw(m.col(TT - 1), C.slice(TT - 1), 0.0);
  for (int t = TT - 2; t >= 0; --t) {
    arma::mat P = GG.slice(t + 1) * C.slice(t) * GG.slice(t + 1).t();
    arma::mat R = symmetrize(P + (df_mat % P));
    arma::mat invR = svd_inv(R);
    arma::mat sB = C.slice(t) * GG.slice(t + 1).t() * invR;
    arma::vec sm_t = m.col(t) + sB * (sam_theta.col(t + 1) - GG.slice(t + 1) * m.col(t));
    arma::mat sC_t = symmetrize(C.slice(t) - sB * GG.slice(t + 1) * C.slice(t));
    sam_theta.col(t) = mvn_svd_draw(sm_t, sC_t, 0.0);
  }

  return Rcpp::List::create(
    Rcpp::Named("standard.forecast.errors") = sfe,
    Rcpp::Named("sam.theta") = sam_theta,
    Rcpp::Named("fm") = m,
    Rcpp::Named("fC") = C
  );
}
