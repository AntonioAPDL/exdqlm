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
