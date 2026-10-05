frozen_input_design <- function(y, method="mean_sd", center=3, scale=2,
                                bound="none", factory=qdesn_fit_vb) {
  do.call(factory, list(y=y,p0=.25,D=2L,n=c(8L,6L),n_tilde=8L,
    m=7L,alpha=.5,rho=c(.7,.8),act_f="tanh",act_k="identity",
    standardize_inputs=TRUE,input_center_scale=method,input_bound=bound,
    lag_center_override=center,lag_scale_override=scale,washout=10L,
    add_bias=TRUE,pi_w=.8,pi_in=.8,seed=83L,fit_readout=FALSE))
}

test_that("explicit input overrides survive raw-input construction", {
  y <- sin(seq_len(80)/3)+seq_len(80)/15
  for (method in c("mean_sd","median_mad")) for (bound in c("none","tanh")) {
    a <- frozen_input_design(y[1:40],method,bound=bound)
    b <- frozen_input_design(y,method,bound=bound)
    expect_equal(a$meta$lag_center,rep(3,7))
    expect_equal(a$meta$lag_scale,rep(2,7))
    expect_true(a$meta$preprocessing_frozen_from_override)
    expect_equal(a$X,b$X[seq_len(nrow(a$X)),,drop=FALSE],tolerance=1e-12)
    for (d in 1:2) {
      expect_equal(a$states$H_all[[d]],b$states$H_all[[d]][1:40,,drop=FALSE],tolerance=1e-12)
      expect_equal(a$reservoir$W[[d]],b$reservoir$W[[d]])
      expect_equal(a$reservoir$Win[[d]],b$reservoir$Win[[d]])
    }
    expect_true(all(a$reservoir$Q_is_identity))
  }
})

test_that("future response changes cannot alter earlier frozen features", {
  y <- sin(seq_len(80)/3)+seq_len(80)/15
  changed <- y;changed[41:80] <- changed[41:80]+1e5
  for (factory in list(qdesn_fit_vb,qdesn_fit_normal)) {
    a <- frozen_input_design(y,factory=factory)
    b <- frozen_input_design(changed,factory=factory)
    expect_equal(a$X[1:30,],b$X[1:30,],tolerance=1e-12)
    expect_equal(a$meta$lag_center,b$meta$lag_center)
    expect_equal(a$meta$lag_scale,b$meta$lag_scale)
    expect_null(a$fit)
  }
})

test_that("per-lag overrides and malformed overrides are handled explicitly", {
  y <- sin(seq_len(40))
  a <- frozen_input_design(y,center=seq_len(7),scale=seq_len(7)+1)
  expect_equal(a$meta$lag_center,seq_len(7))
  expect_equal(a$meta$lag_scale,seq_len(7)+1)
  expect_error(frozen_input_design(y,scale=NULL),"supplied together")
  expect_error(frozen_input_design(y,scale=0),"positive")
  expect_error(frozen_input_design(y,center=NA_real_),"finite")
  expect_error(frozen_input_design(y,center=c(1,2)),"length mismatch")
})

test_that("automatic preprocessing remains unchanged without overrides", {
  y <- sin(seq_len(40))+seq_len(40)/20
  for (method in c("mean_sd","median_mad")) {
    a <- qdesn_fit_vb(y,p0=.25,D=1,n=10,m=5,rho=.8,seed=71,
      standardize_inputs=TRUE,input_center_scale=method,fit_readout=FALSE,washout=10)
    center <- if(method=="mean_sd")mean(y) else median(y)
    scale <- if(method=="mean_sd")sd(y) else mad(y,center=center,constant=1.4826)
    expect_equal(a$meta$lag_center,rep(center,5))
    expect_equal(a$meta$lag_scale,rep(scale,5))
    expect_false(a$meta$preprocessing_frozen_from_override)
  }
})

test_that("decomposition runtime is initialized with explicit preprocessing", {
  y <- 2+seq_len(80)/100+sin(2*pi*seq_len(80)/12)
  cfg <- list(enabled=TRUE,backend="r",state_estimate="filtered",
    components=c("trend","seasonal","residual"),trend=list(degree=1L),
    seasonal=list(period=12,harmonics=c(1L,2L)),
    input_lags=list(trend=3L,seasonal=2L,residual=4L))
  fit <- qdesn_fit_vb(y,p0=.25,D=1L,n=8L,m=4L,rho=.8,seed=71,
    washout=10L,fit_readout=FALSE,standardize_inputs=TRUE,
    input_mode="dlm_decomp_lags",decomposition=cfg,
    lag_center_override=3,lag_scale_override=2)
  expect_equal(fit$meta$m_input,9L)
  expect_equal(fit$meta$lag_center,rep(3,9))
  expect_equal(fit$meta$lag_scale,rep(2,9))
  expect_false(is.null(fit$states$decomposition))
  expect_true(all(is.finite(fit$X)))
})
