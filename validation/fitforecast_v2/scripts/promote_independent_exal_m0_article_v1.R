#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/",
  mustWork = TRUE
)
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] == length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809"
base_promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v3_20260807"
base_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", base_promotion_id
)
state_root <- normalizePath(
  get_arg(
    "--state-root",
    file.path(
      repo_root, "reports", "shared_fitforecast_v2_orchestration",
      "independent_exal_m0_relaunch_v1_20260809_161838"
    )
  ),
  winslash = "/",
  mustWork = TRUE
)
closeout_dir <- normalizePath(
  file.path(state_root, "closeout"),
  winslash = "/",
  mustWork = TRUE
)
output_dir <- get_arg(
  "--output-dir",
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
)

expected <- list(
  base_interface_sha256 = "90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393",
  base_manifest_sha256 = "207eb11386d1a97831f6fd12ad6fe83c238654725494febde14d05e78a5f4188",
  source_registry_hash = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  run_tag = "ind-exal-m0-v1-20260809_161838__git-89d214e",
  validation_branch = "validation/independent-exal-m0-relaunch-v1-1.0.0",
  validation_commit = "89d214e94f97a2cf0ac606f5ae424225f36ad98b",
  method_id = "M0_v_collapsed_support_logit",
  expected_chains = 45L,
  expected_anchors = 15L,
  expected_metric_roles = 27L,
  expected_promotions = 22L,
  expected_retentions = 5L,
  expected_wins_before = 10L,
  expected_wins_after = 16L,
  expected_remaining_gaps = 11L
)

paths <- list(
  base_interface = file.path(
    base_dir, paste0(base_promotion_id, "_interface.csv")
  ),
  base_manifest = file.path(
    base_dir, paste0(base_promotion_id, "_manifest.json")
  ),
  base_source_ledger = file.path(base_dir, "source_ledger.csv"),
  closeout_gate = file.path(closeout_dir, "closeout_gate.json"),
  full_verification = file.path(state_root, "full_verification.json"),
  metric_comparison = file.path(closeout_dir, "metric_comparison.csv"),
  pooled_anchor_metrics = file.path(closeout_dir, "pooled_anchor_metrics.csv"),
  cross_chain_diagnostics = file.path(closeout_dir, "cross_chain_diagnostics.csv"),
  chain_path_agreement = file.path(closeout_dir, "chain_path_agreement.csv"),
  full_runtime_audit = file.path(closeout_dir, "full_runtime_audit.csv"),
  storage_audit = file.path(closeout_dir, "storage_audit.csv"),
  closeout_file_manifest = file.path(closeout_dir, "file_manifest.csv")
)
missing <- names(paths)[!file.exists(unlist(paths, use.names = FALSE))]
if (length(missing)) {
  stop(sprintf("Missing required source(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
}
if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE, no.. = TRUE))) {
  stop(sprintf("Refusing to overwrite nonempty promotion directory: %s", output_dir), call. = FALSE)
}

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
numeric_equal <- function(lhs, rhs, tolerance = 1e-10) {
  is.finite(lhs) && is.finite(rhs) && abs(lhs - rhs) <= tolerance * max(1, abs(rhs))
}
worst_grade <- function(values) {
  values <- toupper(as.character(values))
  if ("FAIL" %in% values) return("FAIL")
  if ("WARN" %in% values) return("WARN")
  if ("PASS" %in% values) return("PASS")
  "UNKNOWN"
}
copy_verified <- function(source, destination, expected_sha = sha256(source)) {
  if (!identical(sha256(source), expected_sha)) {
    stop(sprintf("Source hash mismatch: %s", source), call. = FALSE)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(destination) && !file.copy(source, destination, overwrite = FALSE)) {
    stop(sprintf("Could not freeze source: %s", source), call. = FALSE)
  }
  if (!identical(sha256(destination), expected_sha)) {
    stop(sprintf("Frozen source hash mismatch: %s", destination), call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

if (!identical(sha256(paths$base_interface), expected$base_interface_sha256) ||
    !identical(sha256(paths$base_manifest), expected$base_manifest_sha256)) {
  stop("The frozen article authority differs from the predeclared v3 baseline.", call. = FALSE)
}

base <- read_csv(paths$base_interface)
base_manifest <- jsonlite::read_json(paths$base_manifest, simplifyVector = TRUE)
gate <- jsonlite::read_json(paths$closeout_gate, simplifyVector = TRUE)
verification <- jsonlite::read_json(paths$full_verification, simplifyVector = TRUE)
comparison <- read_csv(paths$metric_comparison)
pooled <- read_csv(paths$pooled_anchor_metrics)
diagnostics <- read_csv(paths$cross_chain_diagnostics)
path_agreement <- read_csv(paths$chain_path_agreement)
storage <- read_csv(paths$storage_audit)

metric_defs <- list(
  fit_qtrue_rmse = c(
    candidate = "fit_source_candidate_id", run_tag = "fit_source_run_tag",
    grade = "fit_source_signoff_grade", status = "fit_source_status",
    path = "fit_source_path", sha = "fit_source_sha256"
  ),
  forecast_qtrue_mae_H1000 = c(
    candidate = "forecast_mae_source_candidate_id", run_tag = "forecast_mae_source_run_tag",
    grade = "forecast_mae_source_signoff_grade", status = "forecast_mae_source_status",
    path = "forecast_mae_source_path", sha = "forecast_mae_source_sha256"
  ),
  forecast_check_loss_H1000 = c(
    candidate = "forecast_check_source_candidate_id", run_tag = "forecast_check_source_run_tag",
    grade = "forecast_check_source_signoff_grade", status = "forecast_check_source_status",
    path = "forecast_check_source_path", sha = "forecast_check_source_sha256"
  )
)
metric_cols <- names(metric_defs)

base_key <- with(base, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_grid <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50),
  stringsAsFactors = FALSE
)
expected_key <- with(
  expected_grid,
  paste(inference, model_variant, family, sprintf("%.2f", tau))
)
if (nrow(base) != 72L || anyDuplicated(base_key) || !setequal(base_key, expected_key) ||
    any(base$source_registry_hash_value != expected$source_registry_hash) ||
    !identical(base_manifest$article_interface_sha256, expected$base_interface_sha256)) {
  stop("The v3 article authority violates its fixed 72-row contract.", call. = FALSE)
}

source_fields <- list(
  c(path = "fit_source_path", sha = "fit_source_sha256"),
  c(path = "forecast_mae_source_path", sha = "forecast_mae_source_sha256"),
  c(path = "forecast_check_source_path", sha = "forecast_check_source_sha256")
)
for (definition in source_fields) {
  source_paths <- base[[definition[["path"]]]]
  source_hashes <- base[[definition[["sha"]]]]
  if (any(!file.exists(source_paths)) ||
      !identical(unname(tools::sha256sum(source_paths)), unname(source_hashes))) {
    stop("A v3 metric source is missing or has changed.", call. = FALSE)
  }
}

gate_ok <- identical(gate$run_tag, expected$run_tag) &&
  identical(as.integer(gate$expected_chains), expected$expected_chains) &&
  identical(as.integer(gate$successful_chains), expected$expected_chains) &&
  identical(as.integer(gate$anchors), expected$expected_anchors) &&
  identical(as.integer(gate$metric_occurrences), expected$expected_metric_roles) &&
  identical(as.integer(gate$metrics_improved), expected$expected_promotions) &&
  isTRUE(gate$storage_policy_pass) &&
  identical(gate$decision, "COMPLETE_REVIEW_REQUIRED")
verification_ok <- isTRUE(verification$static_contract_pass) &&
  isTRUE(verification$runtime_contract_pass) &&
  identical(as.integer(verification$runtime$successful_jobs), expected$expected_chains) &&
  identical(as.integer(verification$runtime$failed_jobs), 0L) &&
  identical(as.integer(verification$runtime$binary_payloads), 0L) &&
  identical(verification$decision, "PASS")
if (!gate_ok || !verification_ok || nrow(comparison) != expected$expected_metric_roles ||
    nrow(pooled) != expected$expected_anchors ||
    sum(as_bool(comparison$metric_improves_current)) != expected$expected_promotions ||
    sum(!as_bool(comparison$metric_improves_current)) != expected$expected_retentions ||
    !all(as_bool(storage$storage_policy_pass)) ||
    any(as.integer(storage$binary_payload_count) != 0L)) {
  stop("The completed M0 campaign does not satisfy the promotion preconditions.", call. = FALSE)
}
heavy <- list.files(
  state_root,
  pattern = "[.](rds|rda|RData)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(heavy)) stop("The M0 state root contains a forbidden binary payload.", call. = FALSE)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
snapshot_dir <- file.path(output_dir, "source_snapshots")
m0_snapshot_dir <- file.path(snapshot_dir, "m0_closeout")
base_snapshot_dir <- file.path(snapshot_dir, "base_authority")
dir.create(m0_snapshot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(base_snapshot_dir, recursive = TRUE, showWarnings = FALSE)

snapshot_rows <- list()
freeze_snapshot <- function(source_id, source, destination) {
  frozen <- copy_verified(source, destination)
  snapshot_rows[[length(snapshot_rows) + 1L]] <<- data.frame(
    source_id = source_id,
    path = frozen,
    sha256 = sha256(frozen),
    stringsAsFactors = FALSE
  )
  frozen
}
freeze_snapshot("base_interface", paths$base_interface, file.path(base_snapshot_dir, basename(paths$base_interface)))
freeze_snapshot("base_manifest", paths$base_manifest, file.path(base_snapshot_dir, basename(paths$base_manifest)))
freeze_snapshot("base_source_ledger", paths$base_source_ledger, file.path(base_snapshot_dir, basename(paths$base_source_ledger)))
for (name in setdiff(names(paths), c("base_interface", "base_manifest", "base_source_ledger"))) {
  freeze_snapshot(name, paths[[name]], file.path(m0_snapshot_dir, basename(paths[[name]])))
}

article <- base
article$article_interface_id <- promotion_id

frozen_base_rows <- list()
for (definition in source_fields) {
  path_col <- definition[["path"]]
  sha_col <- definition[["sha"]]
  for (i in seq_len(nrow(article))) {
    source <- base[[path_col]][[i]]
    source_sha <- base[[sha_col]][[i]]
    destination <- file.path(
      output_dir, "metric_sources", "frozen_base", substr(source_sha, 1L, 16L), basename(source)
    )
    frozen <- copy_verified(source, destination, source_sha)
    article[[path_col]][[i]] <- frozen
    frozen_base_rows[[length(frozen_base_rows) + 1L]] <- data.frame(
      source_id = paste0("base_metric_", substr(source_sha, 1L, 16L), "_", basename(source)),
      path = frozen,
      sha256 = source_sha,
      stringsAsFactors = FALSE
    )
  }
}
frozen_base_ledger <- unique(do.call(rbind, frozen_base_rows))

promoted_anchors <- unique(comparison$anchor_id[as_bool(comparison$metric_improves_current)])
m0_metric_rows <- list()
for (anchor_id in promoted_anchors) {
  anchor_dir <- file.path(output_dir, "metric_sources", "m0", anchor_id)
  pooled_row <- pooled[pooled$anchor_id == anchor_id, , drop = FALSE]
  diagnostic_rows <- diagnostics[diagnostics$anchor_id == anchor_id, , drop = FALSE]
  agreement_rows <- path_agreement[path_agreement$anchor_id == anchor_id, , drop = FALSE]
  if (nrow(pooled_row) != 1L || !nrow(diagnostic_rows) || nrow(agreement_rows) != 2L) {
    stop(sprintf("Incomplete compact M0 evidence for anchor %s.", anchor_id), call. = FALSE)
  }
  pooled_path <- write_csv(pooled_row, file.path(anchor_dir, "pooled_anchor_metrics_row.csv"))
  diagnostic_path <- write_csv(diagnostic_rows, file.path(anchor_dir, "cross_chain_diagnostics.csv"))
  agreement_path <- write_csv(agreement_rows, file.path(anchor_dir, "chain_path_agreement.csv"))
  m0_metric_rows[[anchor_id]] <- list(
    pooled = pooled_path,
    pooled_sha = sha256(pooled_path),
    diagnostic = diagnostic_path,
    diagnostic_sha = sha256(diagnostic_path),
    agreement = agreement_path,
    agreement_sha = sha256(agreement_path)
  )
}

decision_rows <- list()
target_indices <- integer()
for (i in seq_len(nrow(comparison))) {
  source <- comparison[i, , drop = FALSE]
  metric <- as.character(source$metric_role)
  if (!metric %in% metric_cols) stop("Unknown M0 metric role.", call. = FALSE)
  idx <- which(
    article$inference == "mcmc" &
      article$model_variant == "qdesn_exal_rhs_ns" &
      article$family == source$family &
      abs(article$tau - as.numeric(source$tau)) < 1e-12
  )
  if (length(idx) != 1L ||
      !numeric_equal(as.numeric(base[[metric]][[idx]]), as.numeric(source$current_value))) {
    stop(sprintf("M0 comparison does not align with v3 authority: row %d.", i), call. = FALSE)
  }
  pooled_row <- pooled[pooled$anchor_id == source$anchor_id, , drop = FALSE]
  if (nrow(pooled_row) != 1L ||
      !numeric_equal(as.numeric(pooled_row[[metric]]), as.numeric(source$m0_value))) {
    stop(sprintf("M0 pooled metric mismatch: row %d.", i), call. = FALSE)
  }
  improve <- as_bool(source$metric_improves_current)
  if (!identical(improve, as.numeric(source$m0_value) < as.numeric(source$current_value))) {
    stop(sprintf("Non-strict M0 decision at row %d.", i), call. = FALSE)
  }
  definition <- metric_defs[[metric]]
  if (improve) {
    evidence <- m0_metric_rows[[as.character(source$anchor_id)]]
    article[[metric]][[idx]] <- as.numeric(source$m0_value)
    article[[definition[["candidate"]]]][[idx]] <- as.character(source$candidate_id)
    article[[definition[["run_tag"]]]][[idx]] <- expected$run_tag
    article[[definition[["grade"]]]][[idx]] <- as.character(source$diagnostic_grade)
    article[[definition[["status"]]]][[idx]] <- "SUCCESS"
    article[[definition[["path"]]]][[idx]] <- evidence$pooled
    article[[definition[["sha"]]]][[idx]] <- evidence$pooled_sha
  }
  target_indices <- c(target_indices, idx)
  decision_rows[[i]] <- data.frame(
    family = as.character(source$family),
    tau = as.numeric(source$tau),
    metric_role = metric,
    anchor_id = as.character(source$anchor_id),
    candidate_id = as.character(source$candidate_id),
    base_value = as.numeric(source$current_value),
    m0_value = as.numeric(source$m0_value),
    selected_value = as.numeric(article[[metric]][[idx]]),
    ratio_m0_to_base = as.numeric(source$m0_value) / as.numeric(source$current_value),
    improvement_percent = 100 * (1 - as.numeric(article[[metric]][[idx]]) / as.numeric(source$current_value)),
    decision = if (improve) "PROMOTE_M0_STRICT_IMPROVEMENT" else "RETAIN_BASE_NONIMPROVEMENT",
    selected_candidate_id = as.character(article[[definition[["candidate"]]]][[idx]]),
    selected_run_tag = as.character(article[[definition[["run_tag"]]]][[idx]]),
    selected_signoff_grade = as.character(article[[definition[["grade"]]]][[idx]]),
    selected_source_path = as.character(article[[definition[["path"]]]][[idx]]),
    selected_source_sha256 = as.character(article[[definition[["sha"]]]][[idx]]),
    diagnostic_status_used_as_metric_filter = FALSE,
    stringsAsFactors = FALSE
  )
}
decisions <- do.call(rbind, decision_rows)
decisions$was_winner_before <- FALSE
decisions$is_winner_after <- FALSE
decisions$best_model_after <- NA_character_
decisions$best_value_after <- NA_real_
decisions$ratio_to_best_after <- NA_real_
decisions$gap_percent_after <- NA_real_

for (idx in unique(target_indices)) {
  grades <- vapply(metric_defs, function(definition) article[[definition[["grade"]]]][[idx]], character(1L))
  statuses <- vapply(metric_defs, function(definition) article[[definition[["status"]]]][[idx]], character(1L))
  candidates <- vapply(metric_defs, function(definition) article[[definition[["candidate"]]]][[idx]], character(1L))
  article$signoff_grade[[idx]] <- worst_grade(grades)
  article$status[[idx]] <- if (all(statuses == "SUCCESS")) "SUCCESS" else paste(unique(statuses), collapse = ";")
  article$metric_source_mixed[[idx]] <- length(unique(candidates)) > 1L
  article$validation_branch[[idx]] <- expected$validation_branch
  article$validation_commit[[idx]] <- expected$validation_commit
  article$validation_closeout_commit[[idx]] <- expected$validation_commit
  article$source_promotion_id[[idx]] <- promotion_id
}

model_label <- c(
  dqlm = "DQLM", exdqlm = "exDQLM",
  qdesn_al_rhs_ns = "Q-DESN AL-RHS", qdesn_exal_rhs_ns = "Q-DESN exAL-RHS"
)
for (i in seq_len(nrow(decisions))) {
  metric <- decisions$metric_role[[i]]
  family <- decisions$family[[i]]
  tau <- decisions$tau[[i]]
  before_block <- base[
    base$inference == "mcmc" & base$family == family & abs(base$tau - tau) < 1e-12,
    , drop = FALSE
  ]
  after_block <- article[
    article$inference == "mcmc" & article$family == family & abs(article$tau - tau) < 1e-12,
    , drop = FALSE
  ]
  before_best <- min(as.numeric(before_block[[metric]]))
  after_values <- as.numeric(after_block[[metric]])
  after_best <- min(after_values)
  best_models <- paste(model_label[after_block$model_variant[abs(after_values - after_best) < 1e-10]], collapse = "|")
  decisions$was_winner_before[[i]] <- abs(decisions$base_value[[i]] - before_best) < 1e-10
  decisions$is_winner_after[[i]] <- abs(decisions$selected_value[[i]] - after_best) < 1e-10
  decisions$best_model_after[[i]] <- best_models
  decisions$best_value_after[[i]] <- after_best
  decisions$ratio_to_best_after[[i]] <- decisions$selected_value[[i]] / after_best
  decisions$gap_percent_after[[i]] <- 100 * (decisions$selected_value[[i]] / after_best - 1)
}

wins_before <- sum(decisions$was_winner_before)
wins_after <- sum(decisions$is_winner_after)
remaining <- decisions[!decisions$is_winner_after, , drop = FALSE]
remaining$priority <- ifelse(
  remaining$tau %in% c(0.05, 0.25), "PRIMARY_LOWER_QUANTILE", "SECONDARY_MEDIAN"
)
if (sum(decisions$decision == "PROMOTE_M0_STRICT_IMPROVEMENT") != expected$expected_promotions ||
    sum(decisions$decision == "RETAIN_BASE_NONIMPROVEMENT") != expected$expected_retentions ||
    wins_before != expected$expected_wins_before || wins_after != expected$expected_wins_after ||
    nrow(remaining) != expected$expected_remaining_gaps) {
  stop("The metric-wise promotion outcome differs from the audited decision contract.", call. = FALSE)
}

models <- unique(article$model_variant[article$inference == "mcmc"])
win_counts <- do.call(rbind, lapply(models, function(model) {
  count_wins <- function(data) {
    count <- 0L
    for (family in c("normal", "laplace", "gausmix")) {
      for (tau in c(0.05, 0.25, 0.50)) {
        block <- data[data$inference == "mcmc" & data$family == family & abs(data$tau - tau) < 1e-12, , drop = FALSE]
        row <- block[block$model_variant == model, , drop = FALSE]
        for (metric in metric_cols) count <- count + as.integer(abs(row[[metric]] - min(block[[metric]])) < 1e-10)
      }
    }
    count
  }
  data.frame(
    model_variant = model,
    model_label = model_label[[model]],
    wins_before = count_wins(base),
    wins_after = count_wins(article),
    change = count_wins(article) - count_wins(base),
    stringsAsFactors = FALSE
  )
}))

interface_path <- write_csv(article, file.path(output_dir, paste0(promotion_id, "_interface.csv")))
decision_path <- write_csv(decisions, file.path(output_dir, "metric_decision_ledger.csv"))
remaining_path <- write_csv(remaining, file.path(output_dir, "remaining_gap_ledger.csv"))
wins_path <- write_csv(win_counts, file.path(output_dir, "article_model_wins_before_after.csv"))

m0_support_rows <- do.call(rbind, lapply(names(m0_metric_rows), function(anchor_id) {
  evidence <- m0_metric_rows[[anchor_id]]
  data.frame(
    source_id = c(
      paste0("m0_pooled_", anchor_id),
      paste0("m0_diagnostics_", anchor_id),
      paste0("m0_path_agreement_", anchor_id)
    ),
    path = c(evidence$pooled, evidence$diagnostic, evidence$agreement),
    sha256 = c(evidence$pooled_sha, evidence$diagnostic_sha, evidence$agreement_sha),
    stringsAsFactors = FALSE
  )
}))
source_ledger <- unique(rbind(
  do.call(rbind, snapshot_rows),
  frozen_base_ledger,
  m0_support_rows
))
source_ledger <- source_ledger[order(source_ledger$source_id, source_ledger$path), , drop = FALSE]
row.names(source_ledger) <- NULL
if (any(!file.exists(source_ledger$path)) ||
    !identical(unname(tools::sha256sum(source_ledger$path)), unname(source_ledger$sha256))) {
  stop("The self-contained source ledger does not verify.", call. = FALSE)
}
source_ledger_path <- write_csv(source_ledger, file.path(output_dir, "source_ledger.csv"))

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_METRIC_WISE_EXAL_M0_ARTICLE_HANDOFF",
  scientific_decision = "PROMOTE_STRICTLY_IMPROVING_M0_METRICS_AND_RETAIN_NONIMPROVING_AUTHORITY",
  materialized_from_closeout_time = as.character(gate$generated_at),
  package_version = "1.0.0",
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = expected$source_registry_hash,
  expected_rows = 72L,
  observed_rows = nrow(article),
  vb_rows = sum(article$inference == "vb"),
  mcmc_rows = sum(article$inference == "mcmc"),
  ridge_rows = sum(grepl("ridge", article$model_variant)),
  ridge_policy = "EXCLUDED_UNTIL_SEPARATELY_REPLAYED_UNDER_TRAIN_ONLY_PREPROCESSING",
  base_promotion_id = base_promotion_id,
  base_interface_sha256 = expected$base_interface_sha256,
  run_tag = expected$run_tag,
  validation_branch = expected$validation_branch,
  validation_commit = expected$validation_commit,
  inference_method_id = expected$method_id,
  expected_chains = expected$expected_chains,
  successful_chains = as.integer(gate$successful_chains),
  anchors = as.integer(gate$anchors),
  retained_draws_per_anchor = 60000L,
  metric_roles = nrow(decisions),
  promoted_metric_roles = sum(decisions$decision == "PROMOTE_M0_STRICT_IMPROVEMENT"),
  retained_metric_roles = sum(decisions$decision == "RETAIN_BASE_NONIMPROVEMENT"),
  exal_wins_before = wins_before,
  exal_wins_after = wins_after,
  remaining_nonwinning_roles = nrow(remaining),
  diagnostic_grade_counts = as.list(table(pooled$diagnostic_grade)),
  diagnostic_status_used_as_metric_filter = FALSE,
  selection_policy = "strict lower-is-better per family, quantile, model, inference, and metric; diagnostic grade preserved but not filtered",
  storage_policy_pass = TRUE,
  binary_payload_count = 0L,
  article_interface_path = interface_path,
  article_interface_sha256 = sha256(interface_path),
  metric_decision_ledger_path = decision_path,
  metric_decision_ledger_sha256 = sha256(decision_path),
  remaining_gap_ledger_path = remaining_path,
  remaining_gap_ledger_sha256 = sha256(remaining_path),
  model_win_summary_path = wins_path,
  model_win_summary_sha256 = sha256(wins_path),
  source_ledger_path = source_ledger_path,
  source_ledger_sha256 = sha256(source_ledger_path),
  article_update_status = "READY_FOR_ARTICLE_REGENERATION",
  invalid_or_aborted_run_tags = c(
    "ind-exal-m0-v1-20260809_160325__git-1ac48bd",
    "ind-exal-m0-v1-20260809_160714__git-0541583"
  )
)
manifest_path <- file.path(output_dir, paste0(promotion_id, "_manifest.json"))
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, na = "null")

readme <- c(
  "# Independent exAL M0 article promotion",
  "",
  "This immutable, self-contained promotion updates only the independent Q-DESN",
  "exAL-RHS MCMC metric envelope. It applies a strict lower-is-better rule to the",
  "27 family-by-quantile-by-metric roles in the completed three-chain M0 campaign.",
  "Diagnostic grades remain visible but are not used as metric filters.",
  "",
  sprintf("- Authoritative run: `%s`", expected$run_tag),
  sprintf("- Exact method: `%s`", expected$method_id),
  sprintf("- Completed chains: %d/%d", gate$successful_chains, gate$expected_chains),
  sprintf("- Promoted metric roles: %d/27", manifest$promoted_metric_roles),
  sprintf("- Retained non-improving roles: %d/27", manifest$retained_metric_roles),
  sprintf("- exAL-RHS within-table wins: %d -> %d of 27", wins_before, wins_after),
  sprintf("- Remaining nonwinning roles: %d", nrow(remaining)),
  sprintf("- Interface SHA-256: `%s`", sha256(interface_path)),
  sprintf("- Source registry SHA-256: `%s`", expected$source_registry_hash),
  "- Binary payloads: 0",
  "",
  "The bundle freezes all compact metric sources used by the inherited v3",
  "authority and all compact M0 pooled metrics, chain diagnostics, path-agreement",
  "rows, runtime checks, and storage checks needed to reproduce the decisions.",
  "The two invalid run tags in the manifest are non-consumable."
)
writeLines(readme, file.path(output_dir, "README.md"), useBytes = TRUE)

all_outputs <- sort(list.files(output_dir, recursive = TRUE, full.names = TRUE))
all_outputs <- all_outputs[file.info(all_outputs)$isdir %in% FALSE]
all_outputs <- all_outputs[basename(all_outputs) != "output_file_manifest.csv"]
output_manifest <- data.frame(
  path = substring(normalizePath(all_outputs, winslash = "/"), nchar(repo_root) + 2L),
  bytes = as.numeric(file.info(all_outputs)$size),
  sha256 = unname(tools::sha256sum(all_outputs)),
  stringsAsFactors = FALSE
)
write_csv(output_manifest, file.path(output_dir, "output_file_manifest.csv"))

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat(sprintf("INTERFACE=%s\n", interface_path))
cat(sprintf("INTERFACE_SHA256=%s\n", sha256(interface_path)))
cat(sprintf("PROMOTED=%d\n", manifest$promoted_metric_roles))
cat(sprintf("RETAINED=%d\n", manifest$retained_metric_roles))
cat(sprintf("EXAL_WINS=%d->%d\n", wins_before, wins_after))
cat(sprintf("REMAINING_GAPS=%d\n", nrow(remaining)))
cat(sprintf("SOURCE_FILES=%d\n", nrow(source_ledger)))
cat("STORAGE_POLICY=PASS\n")
