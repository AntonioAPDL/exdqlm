test_that("RHS NULL init_log_tau keeps legacy default tau initialization", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.001,
              nu = 4.0,
              s2 = 0.1,
              init_log_tau = NULL
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.50), verbose = FALSE)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "rhs", rhs = inf$beta_prior_rhs)
  st <- prior_obj$init(5L)
  expect_equal(as.numeric(st$eta_tau_hat), 0.0, tolerance = 1e-12)
})

test_that("RHS explicit init_log_tau override is preserved", {
  init_log_tau_target <- log(0.2)
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.001,
              nu = 4.0,
              s2 = 0.1,
              init_log_tau = init_log_tau_target
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.50), verbose = FALSE)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), init_log_tau_target, tolerance = 1e-12)

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "rhs", rhs = inf$beta_prior_rhs)
  st <- prior_obj$init(5L)
  expect_equal(as.numeric(st$eta_tau_hat), init_log_tau_target, tolerance = 1e-12)
})

test_that("RHS non-numeric init_log_tau override falls back to legacy default with warning", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.001,
              nu = 4.0,
              s2 = 0.1,
              init_log_tau = "not-a-number"
            )
          )
        )
      )
    )
  )

  expect_warning(
    inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.50), verbose = FALSE),
    "non-numeric"
  )
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)
})

test_that("RHS_NS settings resolve and instantiate beta prior object", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.25,
              a_zeta = 3.0,
              b_zeta = 2.0,
              s2 = 0.5,
              shrink_intercept = FALSE,
              init_log_tau = log(0.4)
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE)
  expect_identical(inf$beta_prior_type, "rhs_ns")
  expect_equal(as.numeric(inf$beta_prior_rhs$tau0), 0.25, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$a_zeta), 3.0, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$b_zeta), 2.0, tolerance = 1e-12)
  expect_true(is.finite(as.numeric(inf$beta_prior_rhs$init_tau2)))

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "rhs_ns", rhs = inf$beta_prior_rhs)
  expect_identical(prior_obj$type, "rhs_ns")
  st <- prior_obj$init(4L)
  expect_equal(length(st$lambda2), 4L)
  expect_true(all(is.finite(st$lambda2)))
  expect_true(st$tau2 > 0)
  expect_true(st$zeta2 > 0)
})

test_that("RHS_NS NULL init_log_tau keeps guardrail default log_tau=0", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.001,
              s2 = 0.1,
              init_log_tau = NULL
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_tau2), 1.0, tolerance = 1e-12)
})

test_that("RHS_NS non-numeric init_log_tau falls back to guardrail default with warning", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.001,
              s2 = 0.1,
              init_log_tau = "not-a-number"
            )
          )
        )
      )
    )
  )

  expect_warning(
    inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE),
    "non-numeric"
  )
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_tau2), 1.0, tolerance = 1e-12)
})
