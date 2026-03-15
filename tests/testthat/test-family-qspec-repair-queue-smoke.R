test_that("family-qspec repair queue builder and supervisor dry-run stay consistent", {
  repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)

  builder_path <- file.path(repo_root, "tools", "merge_reports", "20260314_build_family_qspec_repair_queue.R")
  supervisor_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_repair_supervisor.sh")
  queue_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_repair_queue.tsv")
  queue_summary_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_repair_queue_summary.tsv")
  plan_summary_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_repair_plan_summary.tsv")

  skip_if_not(file.exists(builder_path), "repair queue builder unavailable")
  skip_if_not(file.exists(supervisor_path), "repair supervisor unavailable")

  state_dir <- file.path(tempdir(), paste0("family_qspec_repair_smoke_", Sys.getpid()))
  dir.create(state_dir, recursive = TRUE, showWarnings = FALSE)

  build_out <- system2(
    "Rscript",
    c(shQuote(builder_path), shQuote(repo_root), shQuote(state_dir)),
    stdout = TRUE,
    stderr = TRUE
  )
  build_status <- attr(build_out, "status")
  expect_true(is.null(build_status), info = paste(build_out, collapse = "\n"))
  expect_true(file.exists(queue_path))
  expect_true(file.exists(queue_summary_path))
  expect_true(file.exists(plan_summary_path))

  queue <- utils::read.delim(queue_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
  queue_summary <- utils::read.delim(queue_summary_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
  plan_summary <- utils::read.delim(plan_summary_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)

  expect_identical(anyDuplicated(queue$task_id), 0L)
  expect_true(all(c("model_path", "root_postprocess", "root_signoff", "root_review", "prior_compare", "campaign_review", "global_summary") %in% unique(queue$unit_type)))
  expect_gt(sum(queue$unit_type == "model_path" & queue$launch_ready), 0L)
  expect_true(all(!queue$launch_ready[queue$unit_type != "model_path"]))
  expect_equal(plan_summary$launch_ready_now[[1]], sum(queue$launch_ready))

  dry_out <- system2(
    supervisor_path,
    c("--repo-root", shQuote(repo_root), "--state-dir", shQuote(state_dir), "--dry-run"),
    stdout = TRUE,
    stderr = TRUE
  )
  dry_status <- attr(dry_out, "status")
  expect_true(is.null(dry_status), info = paste(dry_out, collapse = "\n"))
  expect_true(any(grepl("^queue_summary=", dry_out)))
  expect_true(any(grepl("model_path[[:space:]]+not_started[[:space:]]+TRUE", dry_out)))
})
