test_that("row fitter recycles scalar discount factor across dynamic component blocks", {
  config <- list(models = list(df_value = 0.98, dim_df = c(2L, 4L)))
  data <- list(train = data.frame(y = rnorm(8), stringsAsFactors = FALSE))
  model <- list()

  captured <- NULL
  local_mocked_bindings(
    exal_make_vb_control = function(...) list(),
    exdqlmLDVB = function(..., df, dim.df) {
      captured <<- list(df = df, dim.df = dim.df)
      list(theta.out = list(fm = matrix(0, nrow = sum(dim.df), ncol = nrow(data$train))))
    },
    .env = environment(ffv2_fit_row)
  )

  config$inference <- "vb"
  ffv2_fit_row(config, data, model)
  expect_equal(captured$df, c(0.98, 0.98))
  expect_equal(captured$dim.df, c(2L, 4L))
})
