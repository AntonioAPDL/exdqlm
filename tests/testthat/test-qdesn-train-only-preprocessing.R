test_that("Q-DESN preprocessing is invariant to held-out response and covariate values", {
  y <- as.numeric(seq_len(12L))
  X <- cbind(level = y * 2, seasonal = sin(y))
  idx_use <- 3:12
  n_train <- 6L

  changed_y <- y
  changed_X <- X
  heldout_rows <- idx_use[(n_train + 1L):length(idx_use)]
  changed_y[heldout_rows] <- changed_y[heldout_rows] + 1e6
  changed_X[heldout_rows, ] <- changed_X[heldout_rows, ] - 1e6

  original <- exdqlm:::qdesn_train_only_preprocess(
    y_all = y,
    X_all = X,
    idx_use = idx_use,
    n_train = n_train
  )
  perturbed <- exdqlm:::qdesn_train_only_preprocess(
    y_all = changed_y,
    X_all = changed_X,
    idx_use = idx_use,
    n_train = n_train
  )

  fit_rows <- idx_use[seq_len(n_train)]
  expect_equal(original$y_center, perturbed$y_center)
  expect_equal(original$y_scale, perturbed$y_scale)
  expect_equal(original$X_center, perturbed$X_center)
  expect_equal(original$X_scale, perturbed$X_scale)
  expect_equal(original$y_all[fit_rows], perturbed$y_all[fit_rows])
  expect_equal(original$X_all[fit_rows, ], perturbed$X_all[fit_rows, ])
  expect_identical(original$fit_rows, fit_rows)
  expect_identical(original$provenance$scope, "train_only")
  expect_false(original$provenance$heldout_response_used_for_scaling)
  expect_false(original$provenance$heldout_covariates_used_for_scaling)
  expect_identical(
    original$provenance$fit_row_indices_sha256,
    digest::digest(fit_rows, algo = "sha256")
  )
})

test_that("model-selection real bundles use the same train-only transform", {
  skip_if_not_installed("readr")
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  base <- data.frame(
    y = seq(10, 120, by = 10),
    x1 = seq_len(12L),
    x2 = cos(seq_len(12L))
  )
  changed <- base
  changed[9:12, c("y", "x1", "x2")] <- changed[9:12, c("y", "x1", "x2")] + 1e5

  cfg <- list(
    columns = list(y = "y", x = c("x1", "x2")),
    split = list(use_last = TRUE, T_use = 10L, train_n = 6L),
    preproc = list(scale_y = TRUE, scale_x = TRUE)
  )

  readr::write_csv(base, tmp)
  bundle_a <- exdqlm:::ms_prepare_real_bundle(cfg, list(input_path = tmp))
  readr::write_csv(changed, tmp)
  bundle_b <- exdqlm:::ms_prepare_real_bundle(cfg, list(input_path = tmp))

  expect_equal(bundle_a$y_full[seq_len(6L)], bundle_b$y_full[seq_len(6L)])
  expect_equal(bundle_a$X_use[seq_len(6L), ], bundle_b$X_use[seq_len(6L), ])
  expect_equal(bundle_a$preprocessing$y_center, mean(base$y[3:8]))
  expect_equal(
    bundle_a$preprocessing$x_center,
    unname(colMeans(base[3:8, c("x1", "x2")]))
  )
  expect_identical(bundle_a$preprocessing$x_columns, c("x1", "x2"))
  expect_identical(bundle_a$preprocessing$fit_row_start, 3L)
  expect_identical(bundle_a$preprocessing$fit_row_end, 8L)
  expect_identical(bundle_a$preprocessing$heldout_row_count, 4L)
})

test_that("production real pipeline resolves the split before train-only preprocessing", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/",
    mustWork = TRUE
  )
  lines <- readLines(file.path(repo_root, "scripts", "pipeline_real_main.R"), warn = FALSE)
  split_line <- grep("SPLIT_RESOLVE", lines, fixed = TRUE)[1L]
  preprocess_line <- grep("qdesn_train_only_preprocess", lines, fixed = TRUE)[1L]
  text <- paste(lines, collapse = "\n")

  expect_true(is.finite(split_line))
  expect_true(is.finite(preprocess_line))
  expect_lt(split_line, preprocess_line)
  expect_false(grepl("y_mean <- mean(y_all", text, fixed = TRUE))
  expect_true(grepl("preprocessing = preproc_provenance", text, fixed = TRUE))
  expect_true(grepl("fit_row_indices_sha256", text, fixed = TRUE))
})

test_that("compact pipeline summaries retain train-only preprocessing provenance", {
  skip_if_not_installed("jsonlite")
  out_dir <- tempfile("qdesn-preprocessing-summary-")
  dir.create(file.path(out_dir, "manifest"), recursive = TRUE)
  writeLines("SUCCESS", file.path(out_dir, "manifest", "status.txt"))
  jsonlite::write_json(
    list(
      status = "SUCCESS",
      mode = "real",
      inference_method = "mcmc",
      likelihood_family = "al",
      beta_prior_type = "rhs_ns"
    ),
    file.path(out_dir, "manifest", "runtime_summary.json"),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    list(
      dataset = list(mode = "real"),
      preprocessing = list(
        scope = "train_only",
        fit_row_start = 1L,
        fit_row_end = 890L,
        fit_row_count = 890L,
        fit_row_indices_sha256 = "fixture-hash",
        heldout_response_used_for_scaling = FALSE,
        heldout_covariates_used_for_scaling = FALSE
      )
    ),
    file.path(out_dir, "manifest", "run_manifest.json"),
    auto_unbox = TRUE
  )

  summary <- exdqlm:::collect_pipeline_run_summary(out_dir)$summary
  expect_identical(summary$preprocessing_scope, "train_only")
  expect_identical(summary$preprocessing_fit_row_start, 1L)
  expect_identical(summary$preprocessing_fit_row_end, 890L)
  expect_identical(summary$preprocessing_fit_row_count, 890L)
  expect_identical(summary$preprocessing_fit_row_indices_sha256, "fixture-hash")
  expect_false(summary$preprocessing_heldout_response_used)
  expect_false(summary$preprocessing_heldout_covariates_used)
})
