#include <boost/math/special_functions/erf.hpp>
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <limits>

// Standard normal CDF
double normal_cdf(double x) {
    return 0.5 * erfc(-x * M_SQRT1_2);
}

// Inverse CDF for the standard normal distribution
double normal_cdf_inv(double p) {
    return sqrt(2) * boost::math::erf_inv(2 * p - 1);
}

// Function to sample from a lower truncated normal distribution (truncated at 0)
double rtruncnorm(double mean, double sd) {
    double a = 0.0; // Lower bound for truncation
    if (!std::isfinite(mean) || !std::isfinite(sd) || sd <= 0.0) {
        return NA_REAL;
    }
    double alpha = (a - mean) / sd;
    double alpha_cdf = normal_cdf(alpha);
    if (!std::isfinite(alpha_cdf)) {
        return NA_REAL;
    }

    alpha_cdf = std::max(0.0, std::min(alpha_cdf, std::nextafter(1.0, 0.0)));
    if (alpha_cdf >= std::nextafter(1.0, 0.0)) {
        return a;
    }

    double U = R::runif(alpha_cdf, 1.0);
    U = std::max(std::numeric_limits<double>::min(),
                 std::min(U, std::nextafter(1.0, 0.0)));
    double sample = mean + sd * normal_cdf_inv(U);

    return sample;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix sample_truncnorm(int n_samp, int TT,
                                     Rcpp::NumericVector sts_mu,
                                     Rcpp::NumericVector sts_sig2) {
    if (sts_mu.size() != TT || sts_sig2.size() != TT) {
        Rcpp::stop("Length of sts_mu and sts_sig2 must be equal to TT");
    }
    Rcpp::NumericMatrix samples(n_samp, TT);

    // Precompute std devs once (outside any parallel region)
    std::vector<double> std_devs(TT);
    for (int t = 0; t < TT; ++t) {
        std_devs[t] = std::sqrt(sts_sig2[t]);
    }

    for (int t = 0; t < TT; ++t) {
        const double mean = sts_mu[t];
        const double sd   = std_devs[t];
        for (int i = 0; i < n_samp; ++i) {
            samples(i, t) = rtruncnorm(mean, sd);
        }
    }

    return samples;
}
