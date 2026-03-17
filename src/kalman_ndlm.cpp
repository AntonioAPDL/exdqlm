// [[Rcpp::plugins(cpp11)]]
// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <cmath>

using namespace Rcpp;

namespace {

arma::mat symmetrize(const arma::mat& M) {
  return 0.5 * (M + M.t());
}

arma::mat safe_solve_spd(const arma::mat& A,
                         const arma::mat& B,
                         const double jitter,
                         const std::string& label) {
  if (A.n_rows != A.n_cols) {
    stop("safe_solve_spd: matrix '%s' must be square.", label.c_str());
  }
  if (A.n_rows != B.n_rows) {
    stop("safe_solve_spd: dimension mismatch for '%s'.", label.c_str());
  }

  const int n = static_cast<int>(A.n_rows);
  const arma::mat As = symmetrize(A);
  const arma::mat I = arma::eye<arma::mat>(n, n);

  for (int k = 0; k <= 8; ++k) {
    const double eps = jitter * std::pow(10.0, static_cast<double>(k));
    arma::mat U;
    if (arma::chol(U, As + eps * I, "upper")) {
      arma::mat Y = arma::solve(arma::trimatl(U.t()), B);
      arma::mat X = arma::solve(arma::trimatu(U), Y);
      return X;
    }
  }

  stop("safe_solve_spd: failed for '%s' even after jitter.", label.c_str());
}

arma::mat make_df_mat_cpp(const arma::vec& df,
                          const arma::ivec& dim_df,
                          const int n_state) {
  if (df.n_elem != static_cast<arma::uword>(dim_df.n_elem)) {
    stop("make_df_mat_cpp: length(df) must equal length(dim_df).");
  }

  int total = 0;
  for (arma::uword j = 0; j < dim_df.n_elem; ++j) {
    if (dim_df[j] <= 0) {
      stop("make_df_mat_cpp: all entries in dim_df must be positive.");
    }
    total += dim_df[j];
  }
  if (total != n_state) {
    stop("make_df_mat_cpp: sum(dim_df) must equal n_state.");
  }

  arma::mat out(n_state, n_state, arma::fill::zeros);
  int start = 0;
  for (arma::uword j = 0; j < dim_df.n_elem; ++j) {
    const int width = dim_df[j];
    const double d = df[j];
    if (!std::isfinite(d) || d <= 0.0 || d > 1.0) {
      stop("make_df_mat_cpp: discount factors must be finite and in (0,1].");
    }
    const double mult = (1.0 - d) / d;
    out.submat(start, start, start + width - 1, start + width - 1).fill(mult);
    start += width;
  }

  return out;
}

NumericVector cube_to_time_major(const arma::cube& x) {
  const int n1 = static_cast<int>(x.n_rows);
  const int n2 = static_cast<int>(x.n_cols);
  const int T = static_cast<int>(x.n_slices);

  NumericVector out(T * n1 * n2);
  out.attr("dim") = IntegerVector::create(T, n1, n2);

  for (int t = 0; t < T; ++t) {
    for (int i = 0; i < n1; ++i) {
      for (int j = 0; j < n2; ++j) {
        out[t + T * i + T * n1 * j] = x(i, j, t);
      }
    }
  }

  return out;
}

arma::uvec validate_and_convert_idx(const arma::ivec& idx, const int n_state, const std::string& label) {
  arma::uvec out(idx.n_elem);
  for (arma::uword k = 0; k < idx.n_elem; ++k) {
    const int v = idx[k];
    if (v < 0 || v >= n_state) {
      stop("%s index out of range for n_state=%d.", label.c_str(), n_state);
    }
    out[k] = static_cast<arma::uword>(v);
  }
  return out;
}

} // namespace

// [[Rcpp::export]]
Rcpp::List dlm_ndlm_filter_smooth_cpp(
    const arma::vec& y,
    const arma::mat& FF,
    const arma::cube& GG,
    const arma::vec& m0,
    const arma::mat& C0,
    const arma::vec& df,
    const arma::ivec& dim_df,
    const double l0,
    const double S0,
    const bool compute_smoothed,
    const bool return_intermediates,
    const double jitter
) {
  const int T_len = static_cast<int>(y.n_elem);
  const int n_state = static_cast<int>(m0.n_elem);

  if (T_len < 2) stop("dlm_ndlm_filter_smooth_cpp: y must have length >= 2.");
  if (n_state < 1) stop("dlm_ndlm_filter_smooth_cpp: state dimension must be >= 1.");
  if (FF.n_rows != static_cast<arma::uword>(n_state) || FF.n_cols < static_cast<arma::uword>(T_len)) {
    stop("dlm_ndlm_filter_smooth_cpp: FF must be n_state x T with T >= length(y).");
  }
  if (GG.n_rows != static_cast<arma::uword>(n_state) ||
      GG.n_cols != static_cast<arma::uword>(n_state) ||
      GG.n_slices < static_cast<arma::uword>(T_len)) {
    stop("dlm_ndlm_filter_smooth_cpp: GG must be n_state x n_state x T with T >= length(y).");
  }
  if (C0.n_rows != static_cast<arma::uword>(n_state) || C0.n_cols != static_cast<arma::uword>(n_state)) {
    stop("dlm_ndlm_filter_smooth_cpp: C0 must be n_state x n_state.");
  }
  if (!std::isfinite(l0) || l0 <= 0.0 || !std::isfinite(S0) || S0 <= 0.0) {
    stop("dlm_ndlm_filter_smooth_cpp: l0 and S0 must be positive.");
  }
  if (!std::isfinite(jitter) || jitter <= 0.0) {
    stop("dlm_ndlm_filter_smooth_cpp: jitter must be positive.");
  }

  const arma::mat df_mat = make_df_mat_cpp(df, dim_df, n_state);

  arma::mat a(T_len, n_state, arma::fill::zeros);
  arma::mat fm(T_len, n_state, arma::fill::zeros);
  arma::mat K(T_len, n_state, arma::fill::zeros);
  arma::vec f(T_len, arma::fill::zeros);
  arma::vec e(T_len, arma::fill::zeros);
  arma::vec Q_unscaled(T_len, arma::fill::zeros);
  arma::vec s_seq(T_len, arma::fill::zeros);
  arma::vec n_seq(T_len, arma::fill::zeros);

  arma::cube R_unscaled(n_state, n_state, T_len, arma::fill::zeros);
  arma::cube C_unscaled(n_state, n_state, T_len, arma::fill::zeros);
  arma::cube fC_scaled(n_state, n_state, T_len, arma::fill::zeros);

  arma::vec m_prev = m0;
  arma::mat C_prev = symmetrize(C0);
  double l_prev = l0;
  double S_prev = S0;

  for (int t = 0; t < T_len; ++t) {
    const arma::mat G_t = GG.slice(t);
    const arma::vec F_t = FF.col(t);

    const arma::vec a_t = G_t * m_prev;
    const arma::mat P_t = symmetrize(G_t * C_prev * G_t.t());
    const arma::mat W_t = df_mat % P_t;
    const arma::mat R_t = symmetrize(P_t + W_t);

    double q_t = 1.0 + arma::as_scalar(F_t.t() * R_t * F_t);
    if (!std::isfinite(q_t) || q_t <= 1e-12) q_t = 1e-12;

    const arma::vec K_t = (R_t * F_t) / q_t;
    const double f_t = arma::as_scalar(F_t.t() * a_t);
    const double e_t = y[t] - f_t;

    const arma::vec m_t = a_t + K_t * e_t;
    const arma::mat C_t = symmetrize(R_t - (K_t * q_t) * K_t.t());

    const double l_t = l_prev + 1.0;
    const double S_t = (l_prev * S_prev + (e_t * e_t) / q_t) / l_t;

    a.row(t) = a_t.t();
    fm.row(t) = m_t.t();
    K.row(t) = K_t.t();
    f[t] = f_t;
    e[t] = e_t;
    Q_unscaled[t] = q_t;
    n_seq[t] = l_t;
    s_seq[t] = S_t;

    R_unscaled.slice(t) = R_t;
    C_unscaled.slice(t) = C_t;
    fC_scaled.slice(t) = S_t * C_t;

    m_prev = m_t;
    C_prev = C_t;
    l_prev = l_t;
    S_prev = S_t;
  }

  arma::mat sm;
  arma::cube sC_unscaled;
  arma::cube sC_scaled;
  if (compute_smoothed) {
    sm = fm;
    sC_unscaled = arma::cube(n_state, n_state, T_len, arma::fill::zeros);
    sC_scaled = arma::cube(n_state, n_state, T_len, arma::fill::zeros);

    sC_unscaled.slice(T_len - 1) = C_unscaled.slice(T_len - 1);

    for (int t = T_len - 2; t >= 0; --t) {
      const arma::mat R_next = R_unscaled.slice(t + 1);
      const arma::mat G_next = GG.slice(t + 1);
      const arma::mat invR_G = safe_solve_spd(
        R_next,
        G_next,
        jitter,
        "R_unscaled[t+1]"
      );

      const arma::mat B_t = C_unscaled.slice(t) * invR_G.t();

      const arma::vec sm_next = sm.row(t + 1).t();
      const arma::vec a_next = a.row(t + 1).t();
      sm.row(t) = (fm.row(t).t() + B_t * (sm_next - a_next)).t();

      const arma::mat C_s_t = C_unscaled.slice(t) +
        B_t * (sC_unscaled.slice(t + 1) - R_next) * B_t.t();
      sC_unscaled.slice(t) = symmetrize(C_s_t);
    }

    const double S_T = s_seq[T_len - 1];
    for (int t = 0; t < T_len; ++t) {
      const double denom = s_seq[t];
      if (!std::isfinite(denom) || denom <= 0.0) {
        stop("dlm_ndlm_filter_smooth_cpp: invalid scale sequence at t=%d.", t + 1);
      }
      const double ratio = S_T / denom;
      sC_scaled.slice(t) = ratio * sC_unscaled.slice(t);
    }
  }

  Rcpp::RObject sm_obj = compute_smoothed ? Rcpp::wrap(sm) : R_NilValue;
  Rcpp::RObject sC_obj = compute_smoothed ? Rcpp::wrap(cube_to_time_major(sC_scaled)) : R_NilValue;

  Rcpp::List out = Rcpp::List::create(
    Rcpp::Named("fm") = fm,
    Rcpp::Named("fC") = cube_to_time_major(fC_scaled),
    Rcpp::Named("sm") = sm_obj,
    Rcpp::Named("sC") = sC_obj,
    Rcpp::Named("s") = s_seq,
    Rcpp::Named("n") = n_seq
  );

  if (return_intermediates) {
    out["a"] = a;
    out["R_unscaled"] = cube_to_time_major(R_unscaled);
    out["C_unscaled"] = cube_to_time_major(C_unscaled);
    out["Q_unscaled"] = Q_unscaled;
    out["f"] = f;
    out["e"] = e;
    out["K"] = K;
  }

  return out;
}

// [[Rcpp::export]]
Rcpp::List dlm_ndlm_structured_forecast_cpp(
    const arma::cube& GG,
    const arma::mat& FF,
    const arma::vec& state_origin,
    const arma::ivec& idx_trend,
    const arma::ivec& idx_seasonal,
    const int origin_index,
    const int H
) {
  if (H < 1) stop("dlm_ndlm_structured_forecast_cpp: H must be >= 1.");
  if (origin_index < 1) stop("dlm_ndlm_structured_forecast_cpp: origin_index must be >= 1.");

  const int n_state = static_cast<int>(state_origin.n_elem);
  if (n_state < 1) stop("dlm_ndlm_structured_forecast_cpp: state dimension must be >= 1.");
  if (FF.n_rows != static_cast<arma::uword>(n_state)) {
    stop("dlm_ndlm_structured_forecast_cpp: FF rows must equal state dimension.");
  }
  if (GG.n_rows != static_cast<arma::uword>(n_state) || GG.n_cols != static_cast<arma::uword>(n_state)) {
    stop("dlm_ndlm_structured_forecast_cpp: GG must be n_state x n_state x T.");
  }
  if (FF.n_cols < 1 || GG.n_slices < 1) {
    stop("dlm_ndlm_structured_forecast_cpp: FF/GG must have at least one time slice.");
  }

  const arma::uvec idx_tr = validate_and_convert_idx(idx_trend, n_state, "idx_trend");
  const arma::uvec idx_se = validate_and_convert_idx(idx_seasonal, n_state, "idx_seasonal");

  arma::vec state_now = state_origin;
  arma::vec trend(H, arma::fill::zeros);
  arma::vec seasonal(H, arma::fill::zeros);
  arma::vec structured(H, arma::fill::zeros);

  const int g_tmax = static_cast<int>(GG.n_slices);
  const int f_tmax = static_cast<int>(FF.n_cols);

  for (int h = 0; h < H; ++h) {
    const int t_abs = origin_index + (h + 1);
    const int g_idx = std::min(std::max(t_abs, 1), g_tmax) - 1;
    const int f_idx = std::min(std::max(t_abs, 1), f_tmax) - 1;

    state_now = GG.slice(g_idx) * state_now;
    const arma::vec F_t = FF.col(f_idx);

    double tr = 0.0;
    for (arma::uword k = 0; k < idx_tr.n_elem; ++k) {
      const arma::uword i = idx_tr[k];
      tr += F_t[i] * state_now[i];
    }

    double se = 0.0;
    for (arma::uword k = 0; k < idx_se.n_elem; ++k) {
      const arma::uword i = idx_se[k];
      se += F_t[i] * state_now[i];
    }

    trend[h] = tr;
    seasonal[h] = se;
    structured[h] = tr + se;
  }

  return Rcpp::List::create(
    Rcpp::Named("trend") = trend,
    Rcpp::Named("seasonal") = seasonal,
    Rcpp::Named("structured") = structured,
    Rcpp::Named("state_last") = state_now
  );
}
