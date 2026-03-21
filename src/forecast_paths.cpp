#include <RcppArmadillo.h>
#include <algorithm>
#include <cmath>
// [[Rcpp::depends(RcppArmadillo)]]

using namespace Rcpp;

inline void apply_act_inplace(arma::vec &v, int code) {
  if (code == 0) {
    return;
  }
  if (code == 1) {
    v = arma::tanh(v);
    return;
  }
  if (code == 2) {
    v.transform([](double x) { return x > 0.0 ? x : 0.0; });
    return;
  }
  stop("forecast_paths_cpp: unknown activation code.");
}

inline double act_scalar(double x, int code) {
  if (code == 0) return x;
  if (code == 1) return std::tanh(x);
  if (code == 2) return x > 0.0 ? x : 0.0;
  stop("forecast_paths_cpp: unknown activation code.");
  return x;
}

inline void shift_insert(std::vector<double> &buf, double value) {
  if (buf.empty()) return;
  for (int i = static_cast<int>(buf.size()) - 1; i >= 1; --i) {
    buf[i] = buf[i - 1];
  }
  buf[0] = value;
}

// [[Rcpp::export]]
Rcpp::List forecast_paths_cpp(
  Rcpp::List W_list,
  Rcpp::List Win_list,
  Rcpp::List Q_list,
  Rcpp::NumericVector alpha,
  int D,
  bool add_bias,
  Rcpp::NumericVector y_hist0,
  Rcpp::IntegerVector y_lags,
  Rcpp::List x_blocks,
  Rcpp::NumericMatrix beta,
  Rcpp::NumericVector sigma,
  Rcpp::NumericVector A_d,
  Rcpp::NumericVector B_d,
  Rcpp::NumericVector lam_d,
  Rcpp::NumericVector y_obs_vec,
  int H,
  int m_res,
  int p_res,
  bool standardize_inputs,
  Rcpp::NumericVector lag_center,
  Rcpp::NumericVector lag_scale,
  Rcpp::NumericVector win_scale_lags,
  std::string input_bound,
  double win_scale_global,
  double win_scale_bias,
  Rcpp::List scale_info,
  int act_f_code,
  int act_k_code,
  Rcpp::List origin_state,
  int res_lags,
  Rcpp::Nullable<Rcpp::NumericMatrix> res_lag_init = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericMatrix> s_draws = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericMatrix> v_draws = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericMatrix> z_draws = R_NilValue,
  bool use_omp = false,
  Rcpp::Nullable<Rcpp::LogicalVector> Q_is_identity = R_NilValue,
  bool decomp_mode = false,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_trend = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_seasonal = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_regression = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_transfer = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_structured = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_trend_init = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_seasonal_init = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_regression_init = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_transfer_init = R_NilValue,
  Rcpp::Nullable<Rcpp::NumericVector> decomp_residual_init = R_NilValue,
  Rcpp::Nullable<Rcpp::IntegerVector> decomp_component_codes = R_NilValue,
  int decomp_residual_mode = 0
) {
  int nd = beta.nrow();
  int p = beta.ncol();

  if (alpha.size() != D) stop("forecast_paths_cpp: alpha length must equal D.");
  if (sigma.size() != nd || A_d.size() != nd || B_d.size() != nd || lam_d.size() != nd) {
    stop("forecast_paths_cpp: draw lengths do not match beta rows.");
  }
  if (y_obs_vec.size() != H) stop("forecast_paths_cpp: y_obs_vec must have length H.");
  if (x_blocks.size() != H) stop("forecast_paths_cpp: x_blocks must have length H.");
  if (origin_state.size() != D) stop("forecast_paths_cpp: origin_state length must equal D.");
  if (W_list.size() != D || Win_list.size() != D) stop("forecast_paths_cpp: W/Win list length must equal D.");
  if (D >= 2 && Q_list.size() != D - 1) stop("forecast_paths_cpp: Q list length must equal D-1.");

  std::vector<arma::mat> W(D);
  std::vector<arma::mat> Win(D);
  for (int d = 0; d < D; ++d) {
    W[d] = as<arma::mat>(W_list[d]);
    Win[d] = as<arma::mat>(Win_list[d]);
  }

  std::vector<arma::mat> Q(std::max(0, D - 1));
  if (D >= 2) {
    for (int d = 0; d < D - 1; ++d) {
      Q[d] = as<arma::mat>(Q_list[d]);
    }
  }

  std::vector<int> Q_is_id(std::max(0, D - 1), 0);
  if (!Q_is_identity.isNull()) {
    LogicalVector qid = as<LogicalVector>(Q_is_identity);
    if (qid.size() != std::max(0, D - 1)) {
      stop("forecast_paths_cpp: Q_is_identity length must equal D-1.");
    }
    for (int d = 0; d < D - 1; ++d) {
      if (LogicalVector::is_na(qid[d])) {
        stop("forecast_paths_cpp: Q_is_identity contains NA.");
      }
      Q_is_id[d] = qid[d] ? 1 : 0;
    }
  }

  std::vector<arma::vec> h0(D);
  for (int d = 0; d < D; ++d) {
    h0[d] = as<arma::vec>(origin_state[d]);
  }

  std::vector<Rcpp::NumericVector> xblk(H);
  for (int h = 0; h < H; ++h) {
    xblk[h] = x_blocks[h];
  }

  std::vector<int> ylags(y_lags.size());
  for (int i = 0; i < y_lags.size(); ++i) ylags[i] = y_lags[i];

  int max_y_lag = y_hist0.size();

  std::vector<double> decomp_trend_vec;
  std::vector<double> decomp_seasonal_vec;
  std::vector<double> decomp_regression_vec;
  std::vector<double> decomp_transfer_vec;
  std::vector<double> decomp_structured_vec;
  std::vector<double> decomp_trend_buf_init;
  std::vector<double> decomp_seasonal_buf_init;
  std::vector<double> decomp_regression_buf_init;
  std::vector<double> decomp_transfer_buf_init;
  std::vector<double> decomp_residual_buf_init;
  std::vector<int> decomp_codes;

  if (decomp_mode) {
    if (decomp_structured.isNull()) {
      stop("forecast_paths_cpp: decomposition mode requires structured trajectory.");
    }
    if (decomp_component_codes.isNull()) {
      stop("forecast_paths_cpp: decomposition mode requires component code ordering.");
    }

    NumericVector trend_in;
    NumericVector seas_in;
    NumericVector reg_in;
    NumericVector tf_in;
    if (!decomp_trend.isNull()) trend_in = as<NumericVector>(decomp_trend);
    if (!decomp_seasonal.isNull()) seas_in = as<NumericVector>(decomp_seasonal);
    if (!decomp_regression.isNull()) reg_in = as<NumericVector>(decomp_regression);
    if (!decomp_transfer.isNull()) tf_in = as<NumericVector>(decomp_transfer);
    NumericVector struct_in = as<NumericVector>(decomp_structured);
    if (struct_in.size() != H) {
      stop("forecast_paths_cpp: structured trajectory must have length H.");
    }
    if ((!decomp_trend.isNull() && trend_in.size() != H) ||
        (!decomp_seasonal.isNull() && seas_in.size() != H) ||
        (!decomp_regression.isNull() && reg_in.size() != H) ||
        (!decomp_transfer.isNull() && tf_in.size() != H)) {
      stop("forecast_paths_cpp: decomposition component trajectories must have length H when supplied.");
    }
    if (!decomp_trend.isNull()) decomp_trend_vec.assign(trend_in.begin(), trend_in.end());
    if (!decomp_seasonal.isNull()) decomp_seasonal_vec.assign(seas_in.begin(), seas_in.end());
    if (!decomp_regression.isNull()) decomp_regression_vec.assign(reg_in.begin(), reg_in.end());
    if (!decomp_transfer.isNull()) decomp_transfer_vec.assign(tf_in.begin(), tf_in.end());
    decomp_structured_vec.assign(struct_in.begin(), struct_in.end());

    if (!decomp_trend_init.isNull()) {
      NumericVector v = as<NumericVector>(decomp_trend_init);
      decomp_trend_buf_init.assign(v.begin(), v.end());
    }
    if (!decomp_seasonal_init.isNull()) {
      NumericVector v = as<NumericVector>(decomp_seasonal_init);
      decomp_seasonal_buf_init.assign(v.begin(), v.end());
    }
    if (!decomp_regression_init.isNull()) {
      NumericVector v = as<NumericVector>(decomp_regression_init);
      decomp_regression_buf_init.assign(v.begin(), v.end());
    }
    if (!decomp_transfer_init.isNull()) {
      NumericVector v = as<NumericVector>(decomp_transfer_init);
      decomp_transfer_buf_init.assign(v.begin(), v.end());
    }
    if (!decomp_residual_init.isNull()) {
      NumericVector v = as<NumericVector>(decomp_residual_init);
      decomp_residual_buf_init.assign(v.begin(), v.end());
    }

    IntegerVector codes = as<IntegerVector>(decomp_component_codes);
    decomp_codes.reserve(codes.size());
    for (int i = 0; i < codes.size(); ++i) {
      int code = codes[i];
      if (code < 1 || code > 5) {
        stop("forecast_paths_cpp: decomposition component codes must be in {1,2,3,4,5}.");
      }
      decomp_codes.push_back(code);
    }

    const auto check_component_present = [&](int code, const std::vector<double> &traj, const std::vector<double> &init, const char *label) {
      bool used = std::find(decomp_codes.begin(), decomp_codes.end(), code) != decomp_codes.end();
      if (!used) return;
      if (traj.size() != static_cast<size_t>(H)) {
        stop("forecast_paths_cpp: %s trajectory is required with length H when its code is active.", label);
      }
      if (init.empty()) {
        stop("forecast_paths_cpp: %s lag buffer init is required when its code is active.", label);
      }
    };
    check_component_present(1, decomp_trend_vec, decomp_trend_buf_init, "trend");
    check_component_present(2, decomp_seasonal_vec, decomp_seasonal_buf_init, "seasonal");
    check_component_present(3, decomp_regression_vec, decomp_regression_buf_init, "regression");
    check_component_present(4, decomp_transfer_vec, decomp_transfer_buf_init, "transfer");
    if (std::find(decomp_codes.begin(), decomp_codes.end(), 5) != decomp_codes.end() &&
        decomp_residual_buf_init.empty()) {
      stop("forecast_paths_cpp: residual lag buffer init is required when residual code is active.");
    }

    int m_expected = 0;
    for (int code : decomp_codes) {
      if (code == 1) m_expected += static_cast<int>(decomp_trend_buf_init.size());
      if (code == 2) m_expected += static_cast<int>(decomp_seasonal_buf_init.size());
      if (code == 3) m_expected += static_cast<int>(decomp_regression_buf_init.size());
      if (code == 4) m_expected += static_cast<int>(decomp_transfer_buf_init.size());
      if (code == 5) m_expected += static_cast<int>(decomp_residual_buf_init.size());
    }
    if (m_expected != m_res) {
      stop("forecast_paths_cpp: decomposition lag width mismatch (m_res).");
    }
    if (!(decomp_residual_mode == 0 || decomp_residual_mode == 1)) {
      stop("forecast_paths_cpp: decomp_residual_mode must be 0(sampled_path) or 1(deterministic_plugin).");
    }
  }

  if (res_lags < 0) stop("forecast_paths_cpp: res_lags must be >= 0.");
  int z_dim = add_bias ? (p_res - 1) : p_res;
  int res_lag_len = res_lags * z_dim;
  std::vector<double> res_init;
  if (res_lags > 0) {
    if (z_dim <= 0) stop("forecast_paths_cpp: invalid reservoir feature dimension for lags.");
    if (res_lag_init.isNull()) stop("forecast_paths_cpp: res_lag_init required when res_lags > 0.");
    NumericMatrix res_mat = as<NumericMatrix>(res_lag_init);
    if (res_mat.nrow() != res_lags || res_mat.ncol() != z_dim) {
      stop("forecast_paths_cpp: res_lag_init must be L x p_res(no-bias).");
    }
    res_init.assign(res_lag_len, 0.0);
    for (int r = 0; r < res_lags; ++r) {
      for (int c = 0; c < z_dim; ++c) {
        res_init[r * z_dim + c] = res_mat(r, c);
      }
    }
  }

  bool scaled = false;
  bool center_applied = false;
  bool scale_applied = false;
  std::vector<int> idx0;
  std::vector<double> center_vec;
  std::vector<double> scale_vec;

  if (scale_info.size() > 0) {
    if (scale_info.containsElementNamed("scaled")) {
      scaled = as<bool>(scale_info["scaled"]);
    }
    if (scaled && scale_info.containsElementNamed("idx")) {
      IntegerVector idx = scale_info["idx"];
      idx0.reserve(idx.size());
      for (int k = 0; k < idx.size(); ++k) {
        idx0.push_back(idx[k] - 1);
      }
    }
    if (scaled && scale_info.containsElementNamed("center")) {
      NumericVector mu = scale_info["center"];
      center_vec.assign(mu.begin(), mu.end());
    }
    if (scaled && scale_info.containsElementNamed("scale")) {
      NumericVector sd = scale_info["scale"];
      scale_vec.assign(sd.begin(), sd.end());
    }
    if (scaled && scale_info.containsElementNamed("center_applied")) {
      center_applied = as<bool>(scale_info["center_applied"]);
    }
    if (scaled && scale_info.containsElementNamed("scale_applied")) {
      scale_applied = as<bool>(scale_info["scale_applied"]);
    }
  }

  if (scaled && idx0.size() > 0) {
    if (center_vec.size() != idx0.size() || scale_vec.size() != idx0.size()) {
      stop("forecast_paths_cpp: scale_info center/scale length mismatch.");
    }
  }

  bool has_winscale = win_scale_lags.size() > 0;
  if (has_winscale && win_scale_lags.size() != m_res) {
    stop("forecast_paths_cpp: win_scale_lags length must equal m_res.");
  }

  std::vector<double> lag_center_vec;
  std::vector<double> lag_scale_vec;
  if (standardize_inputs && m_res > 0) {
    lag_center_vec.assign(m_res, 0.0);
    lag_scale_vec.assign(m_res, 1.0);

    if (lag_center.size() == 1) {
      std::fill(lag_center_vec.begin(), lag_center_vec.end(), lag_center[0]);
    } else if (lag_center.size() == m_res) {
      lag_center_vec.assign(lag_center.begin(), lag_center.end());
    } else if (lag_center.size() != 0) {
      stop("forecast_paths_cpp: lag_center length must be 1 or m_res.");
    }

    if (lag_scale.size() == 1) {
      std::fill(lag_scale_vec.begin(), lag_scale_vec.end(), lag_scale[0]);
    } else if (lag_scale.size() == m_res) {
      lag_scale_vec.assign(lag_scale.begin(), lag_scale.end());
    } else if (lag_scale.size() != 0) {
      stop("forecast_paths_cpp: lag_scale length must be 1 or m_res.");
    }

    for (int k = 0; k < m_res; ++k) {
      if (!std::isfinite(lag_center_vec[k])) {
        stop("forecast_paths_cpp: lag_center contains non-finite values.");
      }
      if (!std::isfinite(lag_scale_vec[k]) || lag_scale_vec[k] <= 0.0) {
        stop("forecast_paths_cpp: lag_scale must be finite and > 0.");
      }
    }
  }

  bool has_pre = !s_draws.isNull() && !v_draws.isNull() && !z_draws.isNull();
  if (use_omp && !has_pre) {
    stop("forecast_paths_cpp: use_omp=TRUE requires precomputed s/v/z draws.");
  }

  NumericMatrix s_mat, v_mat, z_mat;
  if (has_pre) {
    s_mat = as<NumericMatrix>(s_draws);
    v_mat = as<NumericMatrix>(v_draws);
    z_mat = as<NumericMatrix>(z_draws);
    if (s_mat.nrow() != H || s_mat.ncol() != nd ||
        v_mat.nrow() != H || v_mat.ncol() != nd ||
        z_mat.nrow() != H || z_mat.ncol() != nd) {
      stop("forecast_paths_cpp: precomputed draws must be H x nd.");
    }
  }

  NumericMatrix yrep(H, nd);
  NumericMatrix mu_draws(H, nd);

  double *yrep_ptr = yrep.begin();
  double *mu_ptr = mu_draws.begin();

  bool bound_tanh = (input_bound == "tanh");

  std::vector<double> y_obs(H);
  std::vector<int> y_obs_is_na(H, 1);
  for (int h = 0; h < H; ++h) {
    double v = y_obs_vec[h];
    y_obs[h] = v;
    y_obs_is_na[h] = Rcpp::NumericVector::is_na(v) ? 1 : 0;
  }

  std::vector<std::vector<double>> xblk_cpp(H);
  for (int h = 0; h < H; ++h) {
    NumericVector xb = xblk[h];
    xblk_cpp[h].assign(xb.begin(), xb.end());
  }

  arma::mat beta_mat(beta.begin(), nd, p, false);
  std::vector<double> sigma_v(sigma.begin(), sigma.end());
  std::vector<double> A_v(A_d.begin(), A_d.end());
  std::vector<double> B_v(B_d.begin(), B_d.end());
  std::vector<double> lam_v(lam_d.begin(), lam_d.end());

  double *s_ptr = nullptr;
  double *v_ptr = nullptr;
  double *z_ptr = nullptr;
  if (has_pre) {
    s_ptr = s_mat.begin();
    v_ptr = v_mat.begin();
    z_ptr = z_mat.begin();
  }

#ifdef _OPENMP
  if (use_omp) {
#pragma omp parallel for
    for (int j = 0; j < nd; ++j) {
      std::vector<double> y_hist(max_y_lag);
      for (int i = 0; i < max_y_lag; ++i) y_hist[i] = y_hist0[i];
      std::vector<arma::vec> h_now = h0;
      std::vector<double> res_buf = res_init;
      std::vector<double> decomp_trend_buf = decomp_trend_buf_init;
      std::vector<double> decomp_seasonal_buf = decomp_seasonal_buf_init;
      std::vector<double> decomp_regression_buf = decomp_regression_buf_init;
      std::vector<double> decomp_transfer_buf = decomp_transfer_buf_init;
      std::vector<double> decomp_residual_buf = decomp_residual_buf_init;

      for (int h = 0; h < H; ++h) {
        std::vector<double> nb;
        if (m_res > 0) {
          nb.reserve(m_res);
          if (decomp_mode) {
            for (int code : decomp_codes) {
              if (code == 1) {
                nb.insert(nb.end(), decomp_trend_buf.begin(), decomp_trend_buf.end());
              } else if (code == 2) {
                nb.insert(nb.end(), decomp_seasonal_buf.begin(), decomp_seasonal_buf.end());
              } else if (code == 3) {
                nb.insert(nb.end(), decomp_regression_buf.begin(), decomp_regression_buf.end());
              } else if (code == 4) {
                nb.insert(nb.end(), decomp_transfer_buf.begin(), decomp_transfer_buf.end());
              } else if (code == 5) {
                nb.insert(nb.end(), decomp_residual_buf.begin(), decomp_residual_buf.end());
              }
            }
          } else {
            nb.resize(m_res);
            for (int k = 0; k < m_res; ++k) {
              nb[k] = y_hist[max_y_lag - 1 - k];
            }
          }
          if (standardize_inputs) {
            for (int k = 0; k < m_res; ++k) nb[k] = (nb[k] - lag_center_vec[k]) / lag_scale_vec[k];
          }
          if (has_winscale) {
            for (int k = 0; k < m_res; ++k) nb[k] = nb[k] * win_scale_lags[k];
          }
          if (bound_tanh) {
            for (int k = 0; k < m_res; ++k) nb[k] = std::tanh(nb[k]);
          }
        }

        arma::vec u_vec(1 + m_res);
        u_vec[0] = 1.0 * win_scale_bias;
        for (int k = 0; k < m_res; ++k) {
          u_vec[k + 1] = nb[k] * win_scale_global;
        }

        std::vector<arma::vec> h_new(D);
        std::vector<arma::vec> htil(std::max(0, D - 1));

        arma::vec pre1 = W[0] * h_now[0] + Win[0] * u_vec;
        apply_act_inplace(pre1, act_f_code);
        arma::vec h1 = (1.0 - alpha[0]) * h_now[0] + alpha[0] * pre1;
        h_new[0] = h1;
        if (D >= 2) {
          if (Q_is_id[0]) {
            htil[0] = h1;
          } else {
            htil[0] = Q[0] * h1;
          }
        }

        if (D >= 2) {
          for (int d = 1; d < D; ++d) {
            arma::vec pre = W[d] * h_now[d] + Win[d] * htil[d - 1];
            apply_act_inplace(pre, act_f_code);
            arma::vec hd = (1.0 - alpha[d]) * h_now[d] + alpha[d] * pre;
            h_new[d] = hd;
            if (d < D - 1) {
              if (Q_is_id[d]) {
                htil[d] = hd;
              } else {
                htil[d] = Q[d] * hd;
              }
            }
          }
        }

        std::vector<double> x_res;
        if (D == 1) {
          x_res.assign(h_new[0].begin(), h_new[0].end());
        } else {
          x_res.assign(h_new[D - 1].begin(), h_new[D - 1].end());
          for (int d = 0; d < D - 1; ++d) {
            arma::vec htmp = htil[d];
            for (arma::uword ii = 0; ii < htmp.n_elem; ++ii) {
              x_res.push_back(act_scalar(htmp[ii], act_k_code));
            }
          }
        }

        if (add_bias) {
          x_res.insert(x_res.begin(), 1.0);
        }

        h_now = h_new;

        if (h == 0 && (int)x_res.size() != p_res) {
          stop("forecast_paths_cpp: readout feature length mismatch (p_res).");
        }

        std::vector<double> y_lag_vec;
        if (!ylags.empty()) {
          y_lag_vec.reserve(ylags.size());
          int n = y_hist.size();
          for (size_t ii = 0; ii < ylags.size(); ++ii) {
            int L = ylags[ii];
            y_lag_vec.push_back(y_hist[n - L]);
          }
        }

        const std::vector<double> &xb = xblk_cpp[h];
        int x_block_len = static_cast<int>(xb.size());
        int total_len = x_res.size() + y_lag_vec.size() + x_block_len + res_lag_len;
        std::vector<double> x_row(total_len);
        int pos = 0;
        for (size_t ii = 0; ii < x_res.size(); ++ii) x_row[pos++] = x_res[ii];
        for (size_t ii = 0; ii < y_lag_vec.size(); ++ii) x_row[pos++] = y_lag_vec[ii];
        for (int ii = 0; ii < x_block_len; ++ii) x_row[pos++] = xb[ii];
        for (int ii = 0; ii < res_lag_len; ++ii) x_row[pos++] = res_buf[ii];

        if (h == 0 && (int)x_row.size() != p) {
          stop("forecast_paths_cpp: readout length mismatch (beta columns).");
        }

        if (scaled && idx0.size() > 0) {
          for (size_t kk = 0; kk < idx0.size(); ++kk) {
            int idx = idx0[kk];
            if (center_applied) x_row[idx] -= center_vec[kk];
            if (scale_applied)  x_row[idx] /= scale_vec[kk];
          }
        }

        double mu_h = 0.0;
        for (int c = 0; c < p; ++c) {
          mu_h += x_row[c] * beta_mat(j, c);
        }
        mu_ptr[h + H * j] = mu_h;

        double y_h;
        if (!y_obs_is_na[h]) {
          y_h = y_obs[h];
        } else {
          double s_val = s_ptr[h + H * j];
          double v_val = v_ptr[h + H * j];
          double z_val = z_ptr[h + H * j];
          y_h = mu_h + (lam_v[j] * sigma_v[j]) * s_val +
            A_v[j] * v_val + std::sqrt(B_v[j] * sigma_v[j] * v_val) * z_val;
        }

        yrep_ptr[h + H * j] = y_h;

        if (max_y_lag > 0) {
          for (int k = 0; k < max_y_lag - 1; ++k) {
            y_hist[k] = y_hist[k + 1];
          }
          y_hist[max_y_lag - 1] = y_h;
        }
        if (decomp_mode) {
          double structured_h = decomp_structured_vec[h];
          double residual_h;
          if (!y_obs_is_na[h]) {
            residual_h = y_obs[h] - structured_h;
          } else if (decomp_residual_mode == 1) {
            residual_h = mu_h - structured_h;
          } else {
            residual_h = y_h - structured_h;
          }
          if (!decomp_trend_vec.empty()) shift_insert(decomp_trend_buf, decomp_trend_vec[h]);
          if (!decomp_seasonal_vec.empty()) shift_insert(decomp_seasonal_buf, decomp_seasonal_vec[h]);
          if (!decomp_regression_vec.empty()) shift_insert(decomp_regression_buf, decomp_regression_vec[h]);
          if (!decomp_transfer_vec.empty()) shift_insert(decomp_transfer_buf, decomp_transfer_vec[h]);
          shift_insert(decomp_residual_buf, residual_h);
        }
        if (res_lags > 0) {
          int offset = add_bias ? 1 : 0;
          for (int i = res_lags - 1; i >= 1; --i) {
            for (int c = 0; c < z_dim; ++c) {
              res_buf[i * z_dim + c] = res_buf[(i - 1) * z_dim + c];
            }
          }
          for (int c = 0; c < z_dim; ++c) {
            res_buf[c] = x_res[c + offset];
          }
        }
      }
    }
  } else {
#endif
    Rcpp::RNGScope scope;
    for (int j = 0; j < nd; ++j) {
      if (j % 50 == 0) Rcpp::checkUserInterrupt();
      std::vector<double> y_hist(max_y_lag);
      for (int i = 0; i < max_y_lag; ++i) y_hist[i] = y_hist0[i];
      std::vector<arma::vec> h_now = h0;
      std::vector<double> res_buf = res_init;
      std::vector<double> decomp_trend_buf = decomp_trend_buf_init;
      std::vector<double> decomp_seasonal_buf = decomp_seasonal_buf_init;
      std::vector<double> decomp_regression_buf = decomp_regression_buf_init;
      std::vector<double> decomp_transfer_buf = decomp_transfer_buf_init;
      std::vector<double> decomp_residual_buf = decomp_residual_buf_init;

      std::vector<double> s_vec(H), v_vec(H), z_vec(H);
      if (!has_pre) {
        for (int h = 0; h < H; ++h) {
          s_vec[h] = std::fabs(R::rnorm(0.0, 1.0));
        }
        for (int h = 0; h < H; ++h) {
          v_vec[h] = R::rexp(sigma[j]);
        }
        for (int h = 0; h < H; ++h) {
          z_vec[h] = R::rnorm(0.0, 1.0);
        }
      }

      for (int h = 0; h < H; ++h) {
        std::vector<double> nb;
        if (m_res > 0) {
          nb.reserve(m_res);
          if (decomp_mode) {
            for (int code : decomp_codes) {
              if (code == 1) {
                nb.insert(nb.end(), decomp_trend_buf.begin(), decomp_trend_buf.end());
              } else if (code == 2) {
                nb.insert(nb.end(), decomp_seasonal_buf.begin(), decomp_seasonal_buf.end());
              } else if (code == 3) {
                nb.insert(nb.end(), decomp_regression_buf.begin(), decomp_regression_buf.end());
              } else if (code == 4) {
                nb.insert(nb.end(), decomp_transfer_buf.begin(), decomp_transfer_buf.end());
              } else if (code == 5) {
                nb.insert(nb.end(), decomp_residual_buf.begin(), decomp_residual_buf.end());
              }
            }
          } else {
            nb.resize(m_res);
            for (int k = 0; k < m_res; ++k) {
              nb[k] = y_hist[max_y_lag - 1 - k];
            }
          }
          if (standardize_inputs) {
            for (int k = 0; k < m_res; ++k) nb[k] = (nb[k] - lag_center_vec[k]) / lag_scale_vec[k];
          }
          if (has_winscale) {
            for (int k = 0; k < m_res; ++k) nb[k] = nb[k] * win_scale_lags[k];
          }
          if (bound_tanh) {
            for (int k = 0; k < m_res; ++k) nb[k] = std::tanh(nb[k]);
          }
        }

        arma::vec u_vec(1 + m_res);
        u_vec[0] = 1.0 * win_scale_bias;
        for (int k = 0; k < m_res; ++k) {
          u_vec[k + 1] = nb[k] * win_scale_global;
        }

        std::vector<arma::vec> h_new(D);
        std::vector<arma::vec> htil(std::max(0, D - 1));

        arma::vec pre1 = W[0] * h_now[0] + Win[0] * u_vec;
        apply_act_inplace(pre1, act_f_code);
        arma::vec h1 = (1.0 - alpha[0]) * h_now[0] + alpha[0] * pre1;
        h_new[0] = h1;
        if (D >= 2) {
          if (Q_is_id[0]) {
            htil[0] = h1;
          } else {
            htil[0] = Q[0] * h1;
          }
        }

        if (D >= 2) {
          for (int d = 1; d < D; ++d) {
            arma::vec pre = W[d] * h_now[d] + Win[d] * htil[d - 1];
            apply_act_inplace(pre, act_f_code);
            arma::vec hd = (1.0 - alpha[d]) * h_now[d] + alpha[d] * pre;
            h_new[d] = hd;
            if (d < D - 1) {
              if (Q_is_id[d]) {
                htil[d] = hd;
              } else {
                htil[d] = Q[d] * hd;
              }
            }
          }
        }

        std::vector<double> x_res;
        if (D == 1) {
          x_res.assign(h_new[0].begin(), h_new[0].end());
        } else {
          x_res.assign(h_new[D - 1].begin(), h_new[D - 1].end());
          for (int d = 0; d < D - 1; ++d) {
            arma::vec htmp = htil[d];
            for (arma::uword ii = 0; ii < htmp.n_elem; ++ii) {
              x_res.push_back(act_scalar(htmp[ii], act_k_code));
            }
          }
        }

        if (add_bias) {
          x_res.insert(x_res.begin(), 1.0);
        }

        h_now = h_new;

        if (h == 0 && (int)x_res.size() != p_res) {
          stop("forecast_paths_cpp: readout feature length mismatch (p_res).");
        }

        std::vector<double> y_lag_vec;
        if (!ylags.empty()) {
          y_lag_vec.reserve(ylags.size());
          int n = y_hist.size();
          for (size_t ii = 0; ii < ylags.size(); ++ii) {
            int L = ylags[ii];
            y_lag_vec.push_back(y_hist[n - L]);
          }
        }

        NumericVector xb = xblk[h];
        int x_block_len = xb.size();
        int total_len = x_res.size() + y_lag_vec.size() + x_block_len + res_lag_len;
        std::vector<double> x_row(total_len);
        int pos = 0;
        for (size_t ii = 0; ii < x_res.size(); ++ii) x_row[pos++] = x_res[ii];
        for (size_t ii = 0; ii < y_lag_vec.size(); ++ii) x_row[pos++] = y_lag_vec[ii];
        for (int ii = 0; ii < x_block_len; ++ii) x_row[pos++] = xb[ii];
        for (int ii = 0; ii < res_lag_len; ++ii) x_row[pos++] = res_buf[ii];

        if (h == 0 && (int)x_row.size() != p) {
          stop("forecast_paths_cpp: readout length mismatch (beta columns).");
        }

        if (scaled && idx0.size() > 0) {
          for (size_t kk = 0; kk < idx0.size(); ++kk) {
            int idx = idx0[kk];
            if (center_applied) x_row[idx] -= center_vec[kk];
            if (scale_applied)  x_row[idx] /= scale_vec[kk];
          }
        }

        double mu_h = 0.0;
        for (int c = 0; c < p; ++c) {
          mu_h += x_row[c] * beta(j, c);
        }
        mu_draws(h, j) = mu_h;

        double y_h;
        if (!Rcpp::NumericVector::is_na(y_obs_vec[h])) {
          y_h = y_obs_vec[h];
        } else {
          double s_val = has_pre ? s_mat(h, j) : s_vec[h];
          double v_val = has_pre ? v_mat(h, j) : v_vec[h];
          double z_val = has_pre ? z_mat(h, j) : z_vec[h];
          y_h = mu_h + (lam_d[j] * sigma[j]) * s_val +
            A_d[j] * v_val + std::sqrt(B_d[j] * sigma[j] * v_val) * z_val;
        }

        yrep(h, j) = y_h;

        if (max_y_lag > 0) {
          for (int k = 0; k < max_y_lag - 1; ++k) {
            y_hist[k] = y_hist[k + 1];
          }
          y_hist[max_y_lag - 1] = y_h;
        }
        if (decomp_mode) {
          double structured_h = decomp_structured_vec[h];
          double residual_h;
          if (!Rcpp::NumericVector::is_na(y_obs_vec[h])) {
            residual_h = y_obs_vec[h] - structured_h;
          } else if (decomp_residual_mode == 1) {
            residual_h = mu_h - structured_h;
          } else {
            residual_h = y_h - structured_h;
          }
          if (!decomp_trend_vec.empty()) shift_insert(decomp_trend_buf, decomp_trend_vec[h]);
          if (!decomp_seasonal_vec.empty()) shift_insert(decomp_seasonal_buf, decomp_seasonal_vec[h]);
          if (!decomp_regression_vec.empty()) shift_insert(decomp_regression_buf, decomp_regression_vec[h]);
          if (!decomp_transfer_vec.empty()) shift_insert(decomp_transfer_buf, decomp_transfer_vec[h]);
          shift_insert(decomp_residual_buf, residual_h);
        }
        if (res_lags > 0) {
          int offset = add_bias ? 1 : 0;
          for (int i = res_lags - 1; i >= 1; --i) {
            for (int c = 0; c < z_dim; ++c) {
              res_buf[i * z_dim + c] = res_buf[(i - 1) * z_dim + c];
            }
          }
          for (int c = 0; c < z_dim; ++c) {
            res_buf[c] = x_res[c + offset];
          }
        }
      }
    }
#ifdef _OPENMP
  }
#endif

  return List::create(
    _["yrep"] = yrep,
    _["mu_draws"] = mu_draws
  );
}
