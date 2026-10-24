#include <RcppArmadillo.h>
#include <cmath>
#include <limits>
// [[Rcpp::depends(RcppArmadillo)]]

namespace {
double rhs_logadd(double a, double b) {
  if (a == -std::numeric_limits<double>::infinity()) return b;
  if (b == -std::numeric_limits<double>::infinity()) return a;
  return std::max(a, b) + std::log1p(std::exp(-std::abs(a - b)));
}
}

// Exact coefficient integral, retaining the original feature basis.
// [[Rcpp::export]]
Rcpp::List autodesn_rhs_gaussian_cpp(const arma::mat& XtX,
    const arma::vec& Xty, double yty, double variance,
    const arma::vec& log_prior_variance, const arma::mat& X,
    const arma::vec& y) {
  const arma::uword p = Xty.n_elem;
  if (p == 0 || XtX.n_rows != p || XtX.n_cols != p ||
      log_prior_variance.n_elem != p || X.n_cols != p || X.n_rows != y.n_elem ||
      !std::isfinite(variance) || variance <= 0 || !log_prior_variance.is_finite())
    Rcpp::stop("Invalid RHS Gaussian dimensions or variance.");
  arma::vec sd = arma::exp(0.5 * log_prior_variance);
  if (!sd.is_finite()) Rcpp::stop("RHS prior SD overflow; inspect scale draws.");
  arma::mat K = (XtX % (sd * sd.t())) / variance;
  K.diag() += 1.0;
  if (!K.is_finite()) Rcpp::stop("RHS Gaussian system overflow; inspect scales.");
  arma::mat U;
  if (!arma::chol(U, K)) Rcpp::stop("RHS Gaussian Cholesky failed.");
  arma::vec rhs = sd % Xty / variance;
  arma::vec whitened = arma::solve(arma::trimatu(U),
    arma::solve(arma::trimatl(U.t()), rhs,
      arma::solve_opts::fast + arma::solve_opts::no_approx),
    arma::solve_opts::fast + arma::solve_opts::no_approx);
  arma::vec mu = sd % whitened;
  double cross = arma::dot(mu, Xty);
  double fit2 = arma::dot(mu, XtX * mu);
  double rss = yty - 2.0 * cross + fit2;
  double cancellation = 128.0 * std::numeric_limits<double>::epsilon() *
    (std::abs(yty) + 2.0 * std::abs(cross) + std::abs(fit2));
  if (!std::isfinite(rss) || rss <= cancellation) {
    arma::vec residual = y - X * mu;
    rss = arma::dot(residual, residual);
  }
  double quadratic = rss / variance + arma::dot(whitened, whitened);
  double log_evidence = -0.5 * (static_cast<double>(y.n_elem) *
    (std::log(2.0 * M_PI) + std::log(variance)) +
    2.0 * arma::sum(arma::log(U.diag())) + quadratic);
  if (!std::isfinite(log_evidence) || !mu.is_finite())
    Rcpp::stop("Nonfinite RHS Gaussian integral; no candidate was silently discarded.");
  return Rcpp::List::create(Rcpp::Named("log_evidence") = log_evidence,
    Rcpp::Named("mean") = Rcpp::NumericVector(mu.begin(), mu.end()),
    Rcpp::Named("chol") = U,
    Rcpp::Named("sqrt_prior") = Rcpp::NumericVector(sd.begin(), sd.end()));
}

// The mixture envelope gives acceptance >= 1/sqrt(2). All scales are stored
// on log coordinates; no tail truncation, clipping or finite eta bounds.
// [[Rcpp::export]]
Rcpp::List autodesn_rhs_local_cpp(Rcpp::NumericVector log_local,
    Rcpp::NumericVector log_aux, Rcpp::NumericVector beta,
    double log_tau, double log_slab, int max_attempts) {
  const R_xlen_t p = beta.size();
  if (log_local.size() != p || log_aux.size() != p || max_attempts < 1)
    Rcpp::stop("Local RHS update has inconsistent dimensions or budget.");
  Rcpp::NumericVector local = Rcpp::clone(log_local);
  Rcpp::NumericVector aux = Rcpp::clone(log_aux);
  Rcpp::IntegerVector attempts(p);
  for (R_xlen_t j = 0; j < p; ++j) {
    double log_quad = beta[j] == 0.0 ? -std::numeric_limits<double>::infinity() :
      2.0 * std::log(std::abs(beta[j])) - std::log(2.0) - 2.0 * log_tau;
    double log_b = rhs_logadd(-aux[j], log_quad);
    double log_A = -log_slab, log_B = -2.0 * log_tau;
    double log_w1 = 0.5 * log_A + 0.5 * std::log(M_PI) - 0.5 * log_b;
    double log_w2 = 0.5 * log_B - log_b;
    double mixture = R::plogis(log_w1 - log_w2, 0.0, 1.0, true, false);
    bool accepted = false;
    double log_x = NA_REAL;
    for (int k = 1; k <= max_attempts; ++k) {
      double shape = R::runif(0.0, 1.0) < mixture ? 0.5 : 1.0;
      double gamma = R::rgamma(shape, 1.0);
      if (!std::isfinite(gamma) || gamma <= 0.0)
        Rcpp::stop("Numerically invalid gamma variate in RHS local update.");
      log_x = log_b - std::log(gamma);
      double ratio = std::exp(-0.5 * std::abs(log_A - (log_B - log_x)));
      double log_accept = 0.5 * std::log1p(ratio * ratio) - std::log1p(ratio);
      if (std::log(R::runif(0.0, 1.0)) <= log_accept) {
        accepted = true; attempts[j] = k; break;
      }
    }
    if (!accepted) Rcpp::stop("Exact RHS local rejection sampler exhausted its budget.");
    local[j] = 0.5 * log_x;
    double gamma = R::rgamma(1.0, 1.0);
    if (!std::isfinite(gamma) || gamma <= 0.0)
      Rcpp::stop("Numerically invalid gamma variate in RHS auxiliary update.");
    aux[j] = rhs_logadd(0.0, -log_x) - std::log(gamma);
  }
  return Rcpp::List::create(Rcpp::Named("log_local") = local,
    Rcpp::Named("log_aux") = aux, Rcpp::Named("attempts") = attempts);
}

// Gaussian integral with heterogeneous diagonal observation covariance.
// No weighted sufficient statistics survive a change of covariance state.
// [[Rcpp::export]]
Rcpp::List autodesn_weighted_gaussian_cpp(const arma::mat& X,
    const arma::vec& y, const arma::vec& log_observation_variance,
    const arma::vec& log_prior_variance) {
  if (X.n_rows != y.n_elem || y.n_elem != log_observation_variance.n_elem ||
      !X.is_finite() || !y.is_finite() || !log_observation_variance.is_finite())
    Rcpp::stop("Invalid weighted Gaussian observations or design.");
  arma::vec sw=arma::exp(-0.5*log_observation_variance);
  if(!sw.is_finite() || arma::any(sw<=0)) Rcpp::stop("Weighted Gaussian scale overflow or underflow.");
  arma::mat W=X.each_col()%sw;
  arma::vec z=y%sw;
  Rcpp::List out=autodesn_rhs_gaussian_cpp(W.t()*W,W.t()*z,arma::dot(z,z),1.,log_prior_variance,W,z);
  double value=Rcpp::as<double>(out["log_evidence"])-0.5*arma::sum(log_observation_variance);
  if(!std::isfinite(value))Rcpp::stop("Nonfinite weighted Gaussian evidence.");
  out["log_evidence"]=value;
  return out;
}
