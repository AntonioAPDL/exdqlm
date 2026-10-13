#include <Rcpp.h>
using namespace Rcpp;

// Scalar random-walk FFBS, with an anchored state a_0 = 0.
// [[Rcpp::export]]
List idl12_ffbs_cpp(NumericVector z, NumericVector variance, double omega2) {
  int n = z.size();
  if (n < 1 || variance.size() != n || !R_finite(omega2) || omega2 <= 0)
    stop("Invalid scalar FFBS arguments");
  NumericVector m(n), C(n), a(n);
  double previous_m = 0, previous_C = 0;
  for (int t = 0; t < n; ++t) {
    if (!R_finite(z[t]) || !R_finite(variance[t]) || variance[t] <= 0)
      stop("Invalid scalar FFBS observation");
    double R = previous_C + omega2;
    double K = R / (R + variance[t]);
    m[t] = previous_m + K * (z[t] - previous_m);
    C[t] = R * variance[t] / (R + variance[t]);
    previous_m = m[t]; previous_C = C[t];
  }
  a[n - 1] = R::rnorm(m[n - 1], std::sqrt(C[n - 1]));
  for (int t = n - 2; t >= 0; --t) {
    double B = C[t] / (C[t] + omega2);
    double mean = m[t] + B * (a[t + 1] - m[t]);
    double V = C[t] * omega2 / (C[t] + omega2);
    a[t] = R::rnorm(mean, std::sqrt(V));
  }
  return List::create(_["draw"] = a, _["mean"] = m, _["variance"] = C);
}
