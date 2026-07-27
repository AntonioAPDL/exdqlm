#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

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

read_csv <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing input: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
num <- function(x) suppressWarnings(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
git_value <- function(args) {
  value <- system2("git", c("-C", repo_root, args), stdout = TRUE)
  if (!length(value)) NA_character_ else value[[1L]]
}
cell_key <- function(model_variant, family, tau, fit_size) {
  paste(model_variant, family, sprintf("%.8f", num(tau)), as.integer(fit_size), sep = "\r")
}

promotion_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
previous_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726"
confirmation_id <- "qdesn_tt500_mcmc_external_coherent_confirmation_v1_closeout_20260727"
expected_run_tag <- paste0(
  "qdesn-tt500-mcmc-external-coherent-confirmation-v1-full-",
  "20260727__git-5787212"
)
expected_spec_id <- "qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0"
expected_candidate_id <- "mgv3_16_exal_local__full_5787212"

promotion_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", promotion_id
)
previous_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", previous_id
)
confirmation_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", confirmation_id
)

previous_all_path <- file.path(
  previous_root, paste0(previous_id, "_all_candidates.csv")
)
previous_envelope_path <- file.path(
  previous_root, paste0(previous_id, "_article_envelope.csv")
)
previous_manifest_path <- file.path(
  previous_root, paste0(previous_id, "_manifest.json")
)
previous_handoff_path <- file.path(
  previous_root, paste0(previous_id, "_targeted_screening_handoff.csv")
)
confirmation_candidate_path <- file.path(confirmation_root, "confirmed_candidate.csv")
confirmation_summary_path <- file.path(confirmation_root, "confirmation_summary.csv")
confirmation_metrics_path <- file.path(
  confirmation_root, "confirmation_metric_comparison.csv"
)
confirmation_manifest_path <- file.path(confirmation_root, "confirmation_manifest.json")
confirmation_hash_audit_path <- file.path(
  confirmation_root, "source_file_hash_audit.csv"
)
confirmation_file_manifest_path <- file.path(confirmation_root, "file_manifest.csv")

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Metric-envelope promotion requires the exdqlm 1.0.0 worktree.", call. = FALSE)
}

git_branch_before <- git_value(c("branch", "--show-current"))
git_commit_before <- git_value(c("rev-parse", "HEAD"))
tracked_dirty_before <- length(system2(
  "git", c("-C", repo_root, "diff", "--name-only"), stdout = TRUE
)) > 0L || length(system2(
  "git", c("-C", repo_root, "diff", "--cached", "--name-only"), stdout = TRUE
)) > 0L
untracked_before <- system2(
  "git", c("-C", repo_root, "ls-files", "--others", "--exclude-standard"),
  stdout = TRUE
)

previous_all <- read_csv(previous_all_path)
previous_envelope <- read_csv(previous_envelope_path)
confirmation_candidate <- read_csv(confirmation_candidate_path)
confirmation_summary <- read_csv(confirmation_summary_path)
confirmation_metrics <- read_csv(confirmation_metrics_path)
confirmation_hash_audit <- read_csv(confirmation_hash_audit_path)
confirmation_manifest <- jsonlite::read_json(
  confirmation_manifest_path,
  simplifyVector = TRUE
)
previous_manifest <- jsonlite::read_json(previous_manifest_path, simplifyVector = TRUE)

standard_columns <- c(
  "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "status", "signoff_grade", "comparison_eligible", "run_tag",
  "source_key", "source_path", "source_table_sha256",
  "source_registry_hash_value"
)
missing_previous <- setdiff(standard_columns, names(previous_all))
if (length(missing_previous)) {
  stop(sprintf(
    "Previous candidate ledger is missing column(s): %s",
    paste(missing_previous, collapse = ", ")
  ), call. = FALSE)
}
if (nrow(previous_all) != 128L || nrow(previous_envelope) != 36L) {
  stop("Previous metric envelope no longer has the frozen 128/36 structure.", call. = FALSE)
}

registry_hash <- unique(as.character(previous_all$source_registry_hash_value))
if (length(registry_hash) != 1L ||
    !identical(registry_hash, as.character(previous_manifest$source_registry_hash_value))) {
  stop("Previous promotion does not carry one consistent source-registry hash.", call. = FALSE)
}

required_summary <- c(
  "run_tag", "root_id", "spec_id", "execution_ok", "source_hash_ok",
  "source_file_hashes_ok", "source_window_ok", "storage_light_ok",
  "all_external_metrics_within_1p05", "all_metrics_stable_within_1p10",
  "signoff_grade", "signoff_reason", "decision", "article_updated"
)
missing_summary <- setdiff(required_summary, names(confirmation_summary))
if (nrow(confirmation_summary) != 1L || length(missing_summary)) {
  stop("Confirmation summary violates its one-row schema.", call. = FALSE)
}
required_true <- c(
  "execution_ok", "source_hash_ok", "source_file_hashes_ok",
  "source_window_ok", "storage_light_ok",
  "all_external_metrics_within_1p05", "all_metrics_stable_within_1p10"
)
if (any(!vapply(
  confirmation_summary[required_true],
  function(value) as_bool(value[[1L]]),
  logical(1L)
)) ||
    confirmation_summary$run_tag[[1L]] != expected_run_tag ||
    confirmation_summary$spec_id[[1L]] != expected_spec_id ||
    confirmation_summary$decision[[1L]] !=
      "ELIGIBLE_FOR_SCIENTIFIC_PROMOTION_PENDING_ARTICLE_REVIEW" ||
    as_bool(confirmation_summary$article_updated[[1L]])) {
  stop("Confirmation summary does not satisfy the frozen article-promotion gate.", call. = FALSE)
}
if (!identical(as.character(confirmation_manifest$source_registry_hash), registry_hash) ||
    confirmation_manifest$run_tag != expected_run_tag ||
    confirmation_manifest$article_gate != "manual_article_review_required") {
  stop("Confirmation manifest does not match the promotion contract.", call. = FALSE)
}

confirmation_file_manifest <- read_csv(confirmation_file_manifest_path)
observed_confirmation_hashes <- unname(tools::sha256sum(
  confirmation_file_manifest$path
))
if (any(observed_confirmation_hashes != confirmation_file_manifest$sha256)) {
  stop("Confirmation closeout file manifest no longer verifies.", call. = FALSE)
}
hash_bool_columns <- c(
  "path_contract_ok", "recorded_hash_ok", "file_exists", "on_disk_hash_ok"
)
if (nrow(confirmation_hash_audit) != 3L ||
    any(!vapply(
      confirmation_hash_audit[hash_bool_columns],
      function(value) all(as_bool(value)),
      logical(1L)
    ))) {
  stop("Confirmation source-file hash audit is not fully passing.", call. = FALSE)
}

required_candidate <- c(
  "spec_id", "family", "tau", "fit_size", "status", "finite_ok", "domain_ok",
  "signoff_grade", "screening_profile_id", "train_qtrue_rmse",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
missing_candidate <- setdiff(required_candidate, names(confirmation_candidate))
if (nrow(confirmation_candidate) != 1L || length(missing_candidate) ||
    confirmation_candidate$spec_id[[1L]] != expected_spec_id ||
    confirmation_candidate$family[[1L]] != "laplace" ||
    abs(num(confirmation_candidate$tau[[1L]]) - 0.25) > 1e-12 ||
    as.integer(confirmation_candidate$fit_size[[1L]]) != 500L ||
    confirmation_candidate$status[[1L]] != "SUCCESS" ||
    !as_bool(confirmation_candidate$finite_ok[[1L]]) ||
    !as_bool(confirmation_candidate$domain_ok[[1L]])) {
  stop("Confirmed candidate is not the exact successful Laplace/0.25 target.", call. = FALSE)
}

metric_names <- c(
  fit_qtrue_rmse = "fit",
  forecast_qtrue_mae_H1000 = "forecast_mae",
  forecast_check_loss_H1000 = "forecast_check"
)
if (!setequal(confirmation_metrics$metric, names(metric_names)) ||
    any(!as_bool(confirmation_metrics$external_gate)) ||
    any(!as_bool(confirmation_metrics$screening_stability_gate)) ||
    any(!as_bool(confirmation_metrics$finite_gate))) {
  stop("Confirmation metric gates are incomplete or non-passing.", call. = FALSE)
}
metric_value <- function(metric) {
  value <- confirmation_metrics$confirmation_value[
    confirmation_metrics$metric == metric
  ]
  if (length(value) != 1L || !is.finite(num(value))) {
    stop(sprintf("Missing finite confirmation metric: %s", metric), call. = FALSE)
  }
  num(value)
}

confirmed <- data.frame(
  model_variant = "qdesn_exal_rhs_ns",
  family = "laplace",
  tau = 0.25,
  fit_size = 500L,
  candidate_id = expected_candidate_id,
  spec_id = expected_spec_id,
  fit_qtrue_rmse = metric_value("fit_qtrue_rmse"),
  forecast_qtrue_mae_H1000 = metric_value("forecast_qtrue_mae_H1000"),
  forecast_check_loss_H1000 = metric_value("forecast_check_loss_H1000"),
  status = "SUCCESS",
  signoff_grade = as.character(confirmation_summary$signoff_grade[[1L]]),
  comparison_eligible = "TRUE",
  run_tag = expected_run_tag,
  source_key = "qdesn_external_coherent_confirmation_v1",
  source_path = normalizePath(
    confirmation_candidate_path,
    winslash = "/",
    mustWork = TRUE
  ),
  source_table_sha256 = sha256(confirmation_candidate_path),
  source_registry_hash_value = registry_hash,
  stringsAsFactors = FALSE
)
if (abs(confirmed$fit_qtrue_rmse - num(confirmation_candidate$train_qtrue_rmse[[1L]])) >
      1e-12 ||
    abs(confirmed$forecast_qtrue_mae_H1000 -
      num(confirmation_candidate$forecast_qtrue_mae_H1000[[1L]])) > 1e-12 ||
    abs(confirmed$forecast_check_loss_H1000 -
      num(confirmation_candidate$forecast_check_loss_H1000[[1L]])) > 1e-12) {
  stop("Normalized confirmation metrics do not match the confirmed candidate row.", call. = FALSE)
}

all_candidates <- rbind(
  previous_all[, standard_columns, drop = FALSE],
  confirmed[, standard_columns, drop = FALSE]
)
confirmation_rows <- (
  all_candidates$candidate_id == expected_candidate_id &
    all_candidates$run_tag == expected_run_tag &
    all_candidates$spec_id == expected_spec_id
)
if (nrow(all_candidates) != 129L ||
    sum(confirmation_rows) != 1L ||
    sum(all_candidates$candidate_id == expected_candidate_id) != 1L ||
    sum(all_candidates$run_tag == expected_run_tag) != 1L) {
  stop("Refreshed candidate ledger does not add exactly one unique confirmation.", call. = FALSE)
}

keys <- cell_key(
  all_candidates$model_variant,
  all_candidates$family,
  all_candidates$tau,
  all_candidates$fit_size
)
metric_rows <- list()
for (key in sort(unique(keys))) {
  block <- all_candidates[keys == key, , drop = FALSE]
  for (metric in names(metric_names)) {
    order_index <- order(
      num(block[[metric]]), block$run_tag, block$candidate_id, na.last = TRUE
    )
    winner <- block[order_index[[1L]], , drop = FALSE]
    winner$metric_name <- metric
    winner$metric_role <- metric_names[[metric]]
    winner$metric_value <- num(winner[[metric]])
    metric_rows[[length(metric_rows) + 1L]] <- winner
  }
}
metric_winners <- do.call(rbind, metric_rows)
if (any(metric_winners$candidate_id == expected_candidate_id)) {
  stop("Confirmation unexpectedly replaced a lower metric-envelope minimum.", call. = FALSE)
}

winner_keys <- cell_key(
  metric_winners$model_variant,
  metric_winners$family,
  metric_winners$tau,
  metric_winners$fit_size
)
envelope_rows <- lapply(sort(unique(winner_keys)), function(key) {
  block <- metric_winners[winner_keys == key, , drop = FALSE]
  pick <- function(metric) {
    block[block$metric_name == metric, , drop = FALSE][1L, , drop = FALSE]
  }
  fit <- pick("fit_qtrue_rmse")
  mae <- pick("forecast_qtrue_mae_H1000")
  check <- pick("forecast_check_loss_H1000")
  grades <- c(fit$signoff_grade, mae$signoff_grade, check$signoff_grade)
  grade <- if ("FAIL" %in% grades) "FAIL" else if ("WARN" %in% grades) "WARN" else "PASS"
  mixed <- length(unique(c(fit$candidate_id, mae$candidate_id, check$candidate_id))) > 1L
  data.frame(
    model_variant = fit$model_variant,
    family = fit$family,
    tau = fit$tau,
    fit_size = fit$fit_size,
    comparison_eligible = "STATUS_AGNOSTIC",
    status = "SUCCESS",
    signoff_grade = grade,
    metric_source_mixed = ifelse(mixed, "TRUE", "FALSE"),
    fit_qtrue_rmse = fit$metric_value,
    forecast_qtrue_mae_H1000 = mae$metric_value,
    forecast_check_loss_H1000 = check$metric_value,
    fit_source_candidate_id = fit$candidate_id,
    fit_source_run_tag = fit$run_tag,
    fit_source_signoff_grade = fit$signoff_grade,
    fit_source_status = fit$status,
    fit_source_path = fit$source_path,
    fit_source_sha256 = fit$source_table_sha256,
    forecast_mae_source_candidate_id = mae$candidate_id,
    forecast_mae_source_run_tag = mae$run_tag,
    forecast_mae_source_signoff_grade = mae$signoff_grade,
    forecast_mae_source_status = mae$status,
    forecast_mae_source_path = mae$source_path,
    forecast_mae_source_sha256 = mae$source_table_sha256,
    forecast_check_source_candidate_id = check$candidate_id,
    forecast_check_source_run_tag = check$run_tag,
    forecast_check_source_signoff_grade = check$signoff_grade,
    forecast_check_source_status = check$status,
    forecast_check_source_path = check$source_path,
    forecast_check_source_sha256 = check$source_table_sha256,
    source_key = "status_agnostic_metricwise_calibrated_envelope",
    source_promotion_id = promotion_id,
    source_table_sha256 = paste(sort(unique(c(
      fit$source_table_sha256,
      mae$source_table_sha256,
      check$source_table_sha256
    ))), collapse = ";"),
    source_registry_hash_value = registry_hash,
    stringsAsFactors = FALSE
  )
})
envelope <- do.call(rbind, envelope_rows)
envelope <- envelope[
  order(envelope$model_variant, envelope$family, envelope$tau),
  ,
  drop = FALSE
]
if (nrow(envelope) != 36L) {
  stop("Refreshed metric envelope is not complete.", call. = FALSE)
}

previous_order <- order(
  previous_envelope$model_variant,
  previous_envelope$family,
  previous_envelope$tau
)
previous_envelope <- previous_envelope[previous_order, , drop = FALSE]
comparison_columns <- c(
  "model_variant", "family", "tau", "fit_size", "signoff_grade",
  "metric_source_mixed", "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000", "fit_source_candidate_id",
  "fit_source_run_tag", "forecast_mae_source_candidate_id",
  "forecast_mae_source_run_tag", "forecast_check_source_candidate_id",
  "forecast_check_source_run_tag", "source_registry_hash_value"
)
character_columns <- setdiff(
  comparison_columns,
  c("tau", "fit_size", "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000")
)
if (any(vapply(character_columns, function(column) {
  !identical(as.character(previous_envelope[[column]]), as.character(envelope[[column]]))
}, logical(1L))) ||
    any(abs(num(previous_envelope$tau) - num(envelope$tau)) > 1e-12) ||
    any(as.integer(previous_envelope$fit_size) != as.integer(envelope$fit_size)) ||
    any(abs(num(previous_envelope$fit_qtrue_rmse) - num(envelope$fit_qtrue_rmse)) > 1e-12) ||
    any(abs(num(previous_envelope$forecast_qtrue_mae_H1000) -
      num(envelope$forecast_qtrue_mae_H1000)) > 1e-12) ||
    any(abs(num(previous_envelope$forecast_check_loss_H1000) -
      num(envelope$forecast_check_loss_H1000)) > 1e-12)) {
  stop("Coherent confirmation unexpectedly changed the displayed metric envelope.", call. = FALSE)
}

metric_comparison <- do.call(rbind, lapply(seq_len(nrow(envelope)), function(index) {
  current <- envelope[index, , drop = FALSE]
  previous <- previous_envelope[index, , drop = FALSE]
  data.frame(
    model_variant = current$model_variant,
    family = current$family,
    tau = current$tau,
    fit_size = current$fit_size,
    metric = names(metric_names),
    previous_value = c(
      previous$fit_qtrue_rmse,
      previous$forecast_qtrue_mae_H1000,
      previous$forecast_check_loss_H1000
    ),
    refreshed_value = c(
      current$fit_qtrue_rmse,
      current$forecast_qtrue_mae_H1000,
      current$forecast_check_loss_H1000
    ),
    changed = FALSE,
    stringsAsFactors = FALSE
  )
}))
metric_promotions <- metric_comparison[metric_comparison$changed, , drop = FALSE]

target_envelope <- envelope[
  envelope$model_variant == "qdesn_exal_rhs_ns" &
    envelope$family == "laplace" &
    abs(num(envelope$tau) - 0.25) <= 1e-12,
  ,
  drop = FALSE
]
if (nrow(target_envelope) != 1L) {
  stop("Could not resolve the Laplace/0.25 exAL-RHS envelope row.", call. = FALSE)
}
coherent_confirmation <- data.frame(
  candidate_id = expected_candidate_id,
  model_variant = "qdesn_exal_rhs_ns",
  family = "laplace",
  tau = 0.25,
  fit_size = 500L,
  spec_id = expected_spec_id,
  run_tag = expected_run_tag,
  fit_qtrue_rmse = confirmed$fit_qtrue_rmse,
  forecast_qtrue_mae_H1000 = confirmed$forecast_qtrue_mae_H1000,
  forecast_check_loss_H1000 = confirmed$forecast_check_loss_H1000,
  envelope_fit_qtrue_rmse = target_envelope$fit_qtrue_rmse,
  envelope_forecast_qtrue_mae_H1000 = target_envelope$forecast_qtrue_mae_H1000,
  envelope_forecast_check_loss_H1000 =
    target_envelope$forecast_check_loss_H1000,
  fit_envelope_winner = FALSE,
  forecast_mae_envelope_winner = FALSE,
  forecast_check_envelope_winner = FALSE,
  all_external_metrics_within_1p05 = TRUE,
  all_metrics_stable_within_1p10 = TRUE,
  signoff_grade = confirmation_summary$signoff_grade,
  signoff_reason = confirmation_summary$signoff_reason,
  decision = confirmation_summary$decision,
  source_registry_hash_value = registry_hash,
  source_path = normalizePath(
    confirmation_manifest_path,
    winslash = "/",
    mustWork = TRUE
  ),
  source_sha256 = sha256(confirmation_manifest_path),
  stringsAsFactors = FALSE
)

handoff <- read_csv(previous_handoff_path)
handoff$promotion_refresh_id <- promotion_id
handoff$coherent_confirmation_added <- (
  handoff$model_variant == "qdesn_exal_rhs_ns" &
    handoff$family == "laplace" &
    abs(num(handoff$tau) - 0.25) <= 1e-12
)
handoff$displayed_envelope_changed <- FALSE

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
all_path <- write_csv(
  all_candidates,
  file.path(promotion_root, paste0(promotion_id, "_all_candidates.csv"))
)
winners_path <- write_csv(
  metric_winners,
  file.path(promotion_root, paste0(promotion_id, "_metric_winners.csv"))
)
comparison_path <- write_csv(
  metric_comparison,
  file.path(promotion_root, paste0(promotion_id, "_vs_previous_envelope.csv"))
)
promotions_path <- write_csv(
  metric_promotions,
  file.path(promotion_root, paste0(promotion_id, "_metric_promotions.csv"))
)
envelope_path <- write_csv(
  envelope,
  file.path(promotion_root, paste0(promotion_id, "_article_envelope.csv"))
)
confirmation_path <- write_csv(
  coherent_confirmation,
  file.path(promotion_root, paste0(promotion_id, "_coherent_confirmation.csv"))
)
handoff_path <- write_csv(
  handoff,
  file.path(promotion_root, paste0(promotion_id, "_targeted_screening_handoff.csv"))
)

source_paths <- c(
  previous_candidates = previous_all_path,
  previous_envelope = previous_envelope_path,
  previous_manifest = previous_manifest_path,
  confirmation_candidate = confirmation_candidate_path,
  confirmation_summary = confirmation_summary_path,
  confirmation_metrics = confirmation_metrics_path,
  confirmation_manifest = confirmation_manifest_path,
  confirmation_hash_audit = confirmation_hash_audit_path,
  confirmation_file_manifest = confirmation_file_manifest_path
)
source_manifest <- data.frame(
  source_id = names(source_paths),
  path = vapply(source_paths, normalizePath, character(1L), winslash = "/", mustWork = TRUE),
  sha256 = vapply(source_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest,
  file.path(promotion_root, "source_manifest.csv")
)

outputs <- c(
  all_path, winners_path, comparison_path, promotions_path, envelope_path,
  confirmation_path, handoff_path, source_manifest_path
)
file_manifest <- data.frame(
  path = outputs,
  sha256 = vapply(outputs, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(
  file_manifest,
  file.path(promotion_root, "file_manifest.csv")
)

manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  validation_branch = git_branch_before,
  validation_commit_at_materialization = git_commit_before,
  tracked_source_dirty_before_materialization = tracked_dirty_before,
  untracked_before_materialization = unname(untracked_before),
  package_version = "1.0.0",
  source_registry_hash_name = "sha256",
  source_registry_hash_value = registry_hash,
  parent_promotion_id = previous_id,
  confirmation_id = confirmation_id,
  confirmation_run_tag = expected_run_tag,
  confirmation_spec_id = expected_spec_id,
  confirmation_decision =
    "ELIGIBLE_FOR_SCIENTIFIC_PROMOTION_PENDING_ARTICLE_REVIEW",
  confirmation_signoff_grade = as.character(confirmation_summary$signoff_grade[[1L]]),
  coherent_confirmation_rows = nrow(coherent_confirmation),
  n_candidates = nrow(all_candidates),
  n_envelope_rows = nrow(envelope),
  n_metric_promotions = nrow(metric_promotions),
  displayed_envelope_changed = FALSE,
  article_integration_status = "ready_for_surgical_article_promotion",
  selection_unit = "model_variant x family x tau x metric",
  selection_rule = paste(
    "minimum observed finite metric; coherent full-budget confirmations remain",
    "in the candidate ledger even when they do not replace a lower metric minimum"
  ),
  interpretation = paste(
    "calibrated metric-wise envelope plus a separately identified coherent",
    "full-budget confirmation"
  ),
  source_manifest = source_manifest,
  files = lapply(
    seq_len(nrow(file_manifest)),
    function(index) as.list(file_manifest[index, , drop = FALSE])
  )
)
manifest_path <- file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
jsonlite::write_json(
  manifest,
  manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)

readme <- c(
  "# Q-DESN/DQLM 500-Observation MCMC Metric Envelope, 2026-07-27",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Parent promotion: `%s`", previous_id),
  sprintf("- Validation branch: `%s`", git_branch_before),
  sprintf("- Materialization commit: `%s`", git_commit_before),
  sprintf("- Source registry SHA-256: `%s`", registry_hash),
  sprintf("- Candidate rows audited: `%d`", nrow(all_candidates)),
  sprintf("- Complete article cells: `%d/36`", nrow(envelope)),
  "- Displayed metric-envelope changes: `0`",
  "- Coherent full-budget confirmations added: `1`",
  "",
  "## Decision",
  "",
  "The Laplace, p=0.25, exAL-RHS full-budget confirmation passes every",
  "prespecified external-benchmark, stability, source, and storage gate.",
  "Its three metrics are slightly above the existing case-specific metric",
  "minima, so it is retained as coherent confirmation evidence without",
  "overwriting lower displayed envelope values.",
  "",
  "## Article Contract",
  "",
  "The article may point to this refreshed promotion and report the coherent",
  "confirmation separately. Numeric table entries remain unchanged because",
  "the declared article selection rule is metric-wise minimum evidence.",
  "Diagnostic grade WARN (chain_marginal_but_usable) remains explicit.",
  "",
  sprintf("- Article envelope: `%s`", basename(envelope_path)),
  sprintf("- Coherent confirmation: `%s`", basename(confirmation_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("candidate_rows: %d\n", nrow(all_candidates)))
cat(sprintf("envelope_rows: %d\n", nrow(envelope)))
cat(sprintf("metric_promotions: %d\n", nrow(metric_promotions)))
cat(sprintf("coherent_confirmations: %d\n", nrow(coherent_confirmation)))
