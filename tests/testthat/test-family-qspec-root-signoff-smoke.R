test_that("family-qspec root signoff script writes complete bundles for representative roots", {
  repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
  source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

  catalog_path <- file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv")
  script_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_root_signoff.R")
  skip_if_not(file.exists(catalog_path), "root catalog unavailable")
  skip_if_not(file.exists(script_path), "root signoff script unavailable")

  catalog <- fq_read_tsv(catalog_path)
  static_row <- catalog[catalog$root_kind == "static_paper", , drop = FALSE][1, , drop = FALSE]
  dynamic_row <- catalog[catalog$root_kind == "dynamic", , drop = FALSE][1, , drop = FALSE]

  for (root_row in list(static_row, dynamic_row)) {
    run_root <- file.path(repo_root, root_row$run_root)
    skip_if_not(dir.exists(run_root), paste("run root missing:", run_root))

    out <- system2(
      "Rscript",
      c(shQuote(script_path), shQuote(run_root), shQuote(repo_root)),
      stdout = TRUE,
      stderr = TRUE
    )
    status <- attr(out, "status")
    expect_true(is.null(status), info = paste(out, collapse = "\n"))

    required <- fq_required_signoff_files(root_row, repo_root)
    expect_true(all(file.exists(required)), info = paste(required[!file.exists(required)], collapse = "\n"))

    method_df <- utils::read.csv(file.path(run_root, "tables", "method_signoff_long.csv"), stringsAsFactors = FALSE)
    alg_df <- utils::read.csv(file.path(run_root, "tables", "algorithm_pair_signoff.csv"), stringsAsFactors = FALSE)
    model_df <- utils::read.csv(file.path(run_root, "tables", "model_pair_signoff.csv"), stringsAsFactors = FALSE)
    root_df <- utils::read.csv(file.path(run_root, "tables", "root_signoff_summary.csv"), stringsAsFactors = FALSE)

    expect_true(all(c("inference", "model", "signoff_grade", "comparison_eligible", "signoff_reason") %in% names(method_df)))
    expect_true(all(c("model", "pair_signoff_grade", "pair_comparison_eligible") %in% names(alg_df)))
    expect_true(all(c("inference", "baseline_model", "extended_model", "pair_signoff_grade") %in% names(model_df)))
    expect_true(all(c("root_id", "n_methods", "n_signoff_pass", "root_comparison_eligible_full") %in% names(root_df)))
    expect_equal(nrow(root_df), 1L)
  }
})
