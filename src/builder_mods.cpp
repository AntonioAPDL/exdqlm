#include <RcppArmadillo.h>

using namespace Rcpp;
using namespace arma;

// [[Rcpp::depends(RcppArmadillo)]]

// [[Rcpp::export]]
Rcpp::List cpp_build_polytrend_FF_GG(int order) {
  if (order < 1) {
    Rcpp::stop("order must be >= 1");
  }

  arma::mat GG(order, order, arma::fill::eye);
  if (order > 1) {
    for (int i = 0; i < order - 1; ++i) {
      GG(i, i + 1) = 1.0;
    }
  }

  arma::mat FF(order, 1, arma::fill::zeros);
  FF(0, 0) = 1.0;

  return Rcpp::List::create(
    Rcpp::Named("FF") = FF,
    Rcpp::Named("GG") = GG
  );
}

// [[Rcpp::export]]
Rcpp::List cpp_build_seas_FF_GG(double period, Rcpp::NumericVector harmonics) {
  if (!R_finite(period) || period <= 0.0) {
    Rcpp::stop("p must be a positive finite period");
  }
  if (harmonics.size() < 1) {
    Rcpp::stop("h must contain at least one harmonic");
  }

  const int nh = harmonics.size();
  arma::vec w(nh);
  for (int i = 0; i < nh; ++i) {
    if (!R_finite(harmonics[i])) {
      Rcpp::stop("h must contain only finite values");
    }
    w(i) = harmonics[i] * 2.0 * M_PI / period;
  }

  const bool has_nyquist = (w.max() == M_PI);

  arma::mat GG;
  arma::mat FF;

  if (has_nyquist) {
    const int d = 2 * nh - 1;
    GG = arma::mat(d, d, arma::fill::zeros);

    for (int i = 0; i < nh - 1; ++i) {
      const double omega = w(i);
      GG(2 * i, 2 * i)         = std::cos(omega);
      GG(2 * i, 2 * i + 1)     = std::sin(omega);
      GG(2 * i + 1, 2 * i)     = -std::sin(omega);
      GG(2 * i + 1, 2 * i + 1) = std::cos(omega);
    }

    GG(d - 1, d - 1) = -1.0;

    FF = arma::mat(d, 1, arma::fill::zeros);
    for (int i = 0; i < d; i += 2) {
      FF(i, 0) = 1.0;
    }
  } else {
    const int d = 2 * nh;
    GG = arma::mat(d, d, arma::fill::zeros);

    for (int i = 0; i < nh; ++i) {
      const double omega = w(i);
      GG(2 * i, 2 * i)         = std::cos(omega);
      GG(2 * i, 2 * i + 1)     = std::sin(omega);
      GG(2 * i + 1, 2 * i)     = -std::sin(omega);
      GG(2 * i + 1, 2 * i + 1) = std::cos(omega);
    }

    FF = arma::mat(d, 1, arma::fill::zeros);
    for (int i = 0; i < d; i += 2) {
      FF(i, 0) = 1.0;
    }
  }

  return Rcpp::List::create(
    Rcpp::Named("FF") = FF,
    Rcpp::Named("GG") = GG
  );
}
