repo <- normalizePath(Sys.getenv("ITM6_REVIEW_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training_size_mechanism_v6_review.R"))

run <- tempfile("itm6_review_run_")
output <- tempfile("itm6_review_output_")
dir.create(file.path(run, "plans"), recursive = TRUE)
dir.create(file.path(run, "status"))
dir.create(file.path(run, "evidence"))
dir.create(file.path(run, "summaries"))
iqt12_json(list(head = "campaign-head", contract = list(
  article_holdout = "not_used")), file.path(run, "campaign.json"))

bank <- data.frame(cell = "normal__exal__p005",
  candidate_id = c("candidate_a", "candidate_b"),
  structure_id = c("structure_a", "structure_b"),
  role = c("stable", "large"), D = c(2L, 4L), n = c("50;50", "400;400"),
  total_states = c(100L, 800L), m = c(120L, 500L), alpha = c(.5, .4),
  rho = c(.9, .995), input_gain = 1, input_fanin = 20,
  recurrent_indegree = 10, interlayer_fanin = 10,
  center_scale = "mean_sd", input_bound = "none", effective_p0 = 2,
  readout_dimension = c(101L, 801L), stringsAsFactors = FALSE)
iqt12_csv(bank, file.path(run, "candidate_bank.csv"))

plan <- expand.grid(N = c(500L, 1000L), fold = c("S1", "S3"),
  structure_id = c("structure_a", "structure_b"), stringsAsFactors = FALSE)
plan$tau_multiplier <- 1
plan$cell <- "normal__exal__p005"
plan$id <- paste0("job_", seq_len(nrow(plan)))
plan$config_path <- file.path(run, "configs", paste0(plan$id, ".json"))
plan$status_path <- file.path(run, "status", paste0(plan$id, ".json"))
plan$rolling_window <- 0L
plan$model <- "qdesn"
plan$stage <- "quantile"
plan$candidate_id <- ifelse(plan$structure_id == "structure_a", "a", "b")
plan$engine <- "vb"
plan$chain <- 1L
plan$timeout <- 60L
dir.create(file.path(run, "configs"))
for (i in seq_len(nrow(plan))) {
  evidence <- file.path(run, "evidence", plan$id[i])
  dir.create(evidence)
  value <- if (plan$structure_id[i] == "structure_a")
    if (plan$N[i] == 500L) 4 else 2 else 1000
  summary <- data.frame(id = plan$id[i], cell = plan$cell[i],
    candidate_id = plan$candidate_id[i], model = "qdesn", engine = "vb",
    family = "normal", p = .05, N = plan$N[i], fold = plan$fold[i],
    chain = 1L, normal_observed_mae = NA_real_, metric = "forecast_mae",
    mean = value, lower = value * .9, upper = value * 1.1)
  iqt12_csv(summary, file.path(evidence, "summary.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = NA_character_),
    plan$status_path[i])
}
iqt12_csv(plan, file.path(run, "plans", "quantile.csv"))
representation <- data.frame(cell = "normal__exal__p005",
  N = c(500L, 1000L), structure_id = "structure_a",
  oracle_teacher_mae = c(2, 1), oracle_recursive_mae = c(2, 1.5),
  gaussian_recursive_mae = c(5, 3), normal_rhs_observed_mae = c(8, 7),
  composite = c(.2, .1))
iqt12_csv(representation,
  file.path(run, "summaries", "representation_scores.csv"))

result <- itm6r_audit(repo, run, output, mode = "interim",
  verify_hashes = FALSE)
stopifnot(nrow(result$tables$quantile_completed_rank) == 4L,
  nrow(result$tables$quantile_best_by_cell_N) == 2L,
  result$tables$quantile_best_by_cell_N$mean[1L] == 4,
  result$tables$quantile_best_by_cell_N$mean[2L] == 2,
  result$tables$quantile_role_stability$over_100[
    result$tables$quantile_role_stability$role == "large"] == 4L,
  file.exists(file.path(output, "campaign_review.md")),
  file.exists(file.path(output, "review_manifest.csv")))
failed_final <- tryCatch({
  itm6r_audit(repo, run, tempfile("itm6_final_"), mode = "final",
    verify_hashes = FALSE)
  FALSE
}, error = function(error) TRUE)
stopifnot(failed_final)
unlink(c(run, output), recursive = TRUE)
cat("independent_qdesn_training_size_mechanism_v6_review: PASS\n")
