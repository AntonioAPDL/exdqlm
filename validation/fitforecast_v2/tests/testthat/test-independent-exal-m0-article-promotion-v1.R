test_that("independent exAL M0 article promotion is complete and self-contained", {
  promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809"
  root <- file.path(
    ffv2_repo_root(), "validation", "fitforecast_v2", "promotions", promotion_id
  )
  manifest_path <- file.path(root, paste0(promotion_id, "_manifest.json"))
  interface_path <- file.path(root, paste0(promotion_id, "_interface.csv"))
  decisions_path <- file.path(root, "metric_decision_ledger.csv")
  gaps_path <- file.path(root, "remaining_gap_ledger.csv")
  wins_path <- file.path(root, "article_model_wins_before_after.csv")
  source_ledger_path <- file.path(root, "source_ledger.csv")
  output_manifest_path <- file.path(root, "output_file_manifest.csv")

  expect_true(all(file.exists(c(
    manifest_path, interface_path, decisions_path, gaps_path, wins_path,
    source_ledger_path, output_manifest_path
  ))))
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  interface <- read.csv(interface_path, check.names = FALSE, stringsAsFactors = FALSE)
  decisions <- read.csv(decisions_path, check.names = FALSE, stringsAsFactors = FALSE)
  gaps <- read.csv(gaps_path, check.names = FALSE, stringsAsFactors = FALSE)
  wins <- read.csv(wins_path, check.names = FALSE, stringsAsFactors = FALSE)
  sources <- read.csv(source_ledger_path, check.names = FALSE, stringsAsFactors = FALSE)
  outputs <- read.csv(output_manifest_path, check.names = FALSE, stringsAsFactors = FALSE)

  expect_identical(nrow(interface), 72L)
  expect_identical(nrow(decisions), 27L)
  expect_identical(sum(decisions$decision == "PROMOTE_M0_STRICT_IMPROVEMENT"), 22L)
  expect_identical(sum(decisions$decision == "RETAIN_BASE_NONIMPROVEMENT"), 5L)
  expect_true(all(
    decisions$selected_value <= decisions$base_value + 1e-12 * pmax(1, decisions$base_value)
  ))
  expect_true(all(!decisions$diagnostic_status_used_as_metric_filter))
  expect_identical(nrow(gaps), 11L)
  expect_true(all(gaps$ratio_to_best_after > 1))

  exal <- wins[wins$model_variant == "qdesn_exal_rhs_ns", , drop = FALSE]
  expect_identical(nrow(exal), 1L)
  expect_identical(exal$wins_before[[1L]], 10L)
  expect_identical(exal$wins_after[[1L]], 16L)
  expect_identical(manifest$run_tag, "ind-exal-m0-v1-20260809_161838__git-89d214e")
  expect_identical(manifest$inference_method_id, "M0_v_collapsed_support_logit")
  expect_identical(manifest$successful_chains, 45L)
  expect_identical(manifest$promoted_metric_roles, 22L)
  expect_identical(manifest$retained_metric_roles, 5L)
  expect_true(isTRUE(manifest$storage_policy_pass))
  expect_identical(manifest$binary_payload_count, 0L)

  expect_true(all(file.exists(sources$path)))
  expect_identical(
    unname(tools::sha256sum(sources$path)),
    unname(sources$sha256)
  )
  output_paths <- file.path(ffv2_repo_root(), outputs$path)
  expect_true(all(file.exists(output_paths)))
  expect_identical(
    unname(tools::sha256sum(output_paths)),
    unname(outputs$sha256)
  )
  expect_identical(
    unname(tools::sha256sum(interface_path)[[1L]]),
    manifest$article_interface_sha256
  )

  heavy <- list.files(
    root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  expect_length(heavy, 0L)
  expect_false(any(grepl(
    "/home/jaguir26/local/src",
    unlist(interface, use.names = FALSE),
    fixed = TRUE
  )))
  expect_identical(
    unique(interface$source_registry_hash_value),
    "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  )
})

test_that("M0 promotion changes only exAL MCMC metrics and provenance", {
  promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809"
  promotion_root <- file.path(
    ffv2_repo_root(), "validation", "fitforecast_v2", "promotions", promotion_id
  )
  base_root <- file.path(
    ffv2_repo_root(), "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v3_20260807"
  )
  current <- read.csv(
    file.path(promotion_root, paste0(promotion_id, "_interface.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  base <- read.csv(
    file.path(
      base_root,
      "qdesn_dqlm_500obs_trainonly_article_v3_20260807_interface.csv"
    ),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  metrics <- c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000"
  )
  key <- function(x) with(x, paste(inference, model_variant, family, sprintf("%.2f", tau)))
  current <- current[match(key(base), key(current)), , drop = FALSE]
  expect_identical(key(current), key(base))

  target <- base$inference == "mcmc" & base$model_variant == "qdesn_exal_rhs_ns"
  expect_identical(
    unname(as.matrix(current[!target, metrics])),
    unname(as.matrix(base[!target, metrics]))
  )
  changed <- abs(as.matrix(current[target, metrics]) - as.matrix(base[target, metrics])) > 1e-12
  expect_identical(sum(changed), 22L)
  expect_true(all(as.matrix(current[target, metrics])[changed] < as.matrix(base[target, metrics])[changed]))
})
