ifbv3_schema <- "independent_qdesn_mcmc_finalist_bridge_v3"
ifbv3_all_candidates <- c("23eb3c867723c85379f2", "3a7a6653cb244f49813c",
  "1b071df459e29d74d20f")
ifbv3_new_candidates <- setdiff(ifbv3_all_candidates,
  "3a7a6653cb244f49813c")

ifbv3_files <- function(path) {
  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  files[file.exists(files) & !file.info(files)$isdir]
}

ifbv3_status <- function(path) {
  if (!file.exists(path)) return("PENDING")
  as.character(iqt12_read(path)$status)
}

ifbv3_verify_status_manifest <- function(path) {
  status <- iqt12_read(path)
  stopifnot(identical(status$status, "SUCCESS"), file.exists(status$manifest),
    iqt12_verify(status$manifest))
  invisible(status)
}

ifbv3_verify_parent <- function(parent_run) {
  stopifnot(dir.exists(parent_run))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv", "closeout_manifest.csv"))
    iqt12_verify(file.path(parent_run, name))
  closeout <- iqt12_read(file.path(parent_run, "closeout.json"))
  stopifnot(closeout$status == "COMPLETE_REVIEW_REQUIRED",
    closeout$scientific_decision ==
      "CAUSAL_READOUT_ADAPTATION_SUPPORTED_GAP_REMAINS",
    closeout$active_jobs == 0L, closeout$bridge_jobs == 12L)
  health <- icav2_health(parent_run)
  stopifnot(health$total == 36L, health$complete == 36L,
    health$running == 0L, health$pending == 0L, health$failed == 0L)
  statuses <- list.files(file.path(parent_run, "status"), pattern = "[.]json$",
    full.names = TRUE)
  stopifnot(length(statuses) == 36L)
  for (path in statuses) ifbv3_verify_status_manifest(path)
  icav2_verify_imports(parent_run)
  invisible(list(closeout = closeout, health = health))
}

ifbv3_parent_bridge_import <- function(parent_run) {
  plan <- read.csv(file.path(parent_run, "plans", "mcmc_bridge.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(plan) == 12L,
    unique(plan$candidate_id) == "3a7a6653cb244f49813c")
  do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    status <- ifbv3_verify_status_manifest(plan$status_path[i])
    data.frame(candidate_id = cfg$candidate$id, fold = cfg$window$fold,
      offset = cfg$bridge_offset, origin = cfg$refit_origin, chain = cfg$chain,
      config_path = normalizePath(plan$config_path[i], mustWork = TRUE),
      config_sha256 = unname(tools::sha256sum(plan$config_path[i])),
      status_path = normalizePath(plan$status_path[i], mustWork = TRUE),
      status_sha256 = unname(tools::sha256sum(plan$status_path[i])),
      evidence = normalizePath(cfg$evidence, mustWork = TRUE),
      evidence_manifest = normalizePath(status$manifest, mustWork = TRUE),
      evidence_manifest_sha256 = unname(tools::sha256sum(status$manifest)),
      stringsAsFactors = FALSE)
  }))
}

ifbv3_verify_imports <- function(run) {
  base <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(base) == 72L,
    identical(unname(tools::sha256sum(base$config_path)), base$config_sha256),
    identical(unname(tools::sha256sum(base$status_path)), base$status_sha256),
    identical(unname(tools::sha256sum(base$evidence_manifest)),
      base$evidence_manifest_sha256))
  bridge <- read.csv(file.path(run, "manifests", "v2_bridge_imports.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(bridge) == 12L,
    identical(unname(tools::sha256sum(bridge$config_path)), bridge$config_sha256),
    identical(unname(tools::sha256sum(bridge$status_path)), bridge$status_sha256),
    identical(unname(tools::sha256sum(bridge$evidence_manifest)),
      bridge$evidence_manifest_sha256))
  for (path in unique(c(base$evidence_manifest, bridge$evidence_manifest)))
    iqt12_verify(path)
  invisible(TRUE)
}

ifbv3_config <- function(state, candidate_id, fold, offset, stage, chain = 1L) {
  selected <- list(candidate_id = candidate_id, mode = "matched_exact_refit")
  cfg <- icav2_bridge_config(state, selected, fold, offset)
  cfg$schema <- ifbv3_schema; cfg$stage <- stage; cfg$chain <- as.integer(chain)
  cfg$adaptation_mode <- "matched_exact_refit"
  cfg$id <- paste(stage, cfg$cell, cfg$model, cfg$engine, fold,
    candidate_id, paste0("o", cfg$refit_origin), paste0("chain", chain), sep = "__")
  cfg$seed <- ism1_seed(cfg$id)
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg
}

ifbv3_materialize <- function(repo, run, parent_run, library) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(parent_run),
    dir.exists(library))
  ifbv3_verify_parent(parent_run)
  parent <- iqt12_read(file.path(parent_run, "campaign.json"))
  head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = ifbv3_schema,
    repo = normalizePath(repo, mustWork = TRUE),
    run = normalizePath(run, mustWork = TRUE),
    library = normalizePath(library, mustWork = TRUE), head = head,
    parent_run = normalizePath(parent_run, mustWork = TRUE),
    parent_head = parent$head, references = parent$references,
    bank = parent$bank, candidate_ids = ifbv3_all_candidates,
    new_candidate_ids = ifbv3_new_candidates, folds = ism1_folds,
    bridge_offsets = icav2_bridge_offsets,
    contract = list(selection_block = "internal_training_only_S1_to_S4",
      sealed_block = "source_indices_9001_to_10000_unopened",
      teacher_forced_between_origins = TRUE,
      recursive_within_origin = TRUE,
      preprocessing_frozen_at_fold_training_end = TRUE,
      primary_metric = "forecast_mae",
      secondary_metric = "forecast_check_loss",
      mcmc_method = "m0_v_collapsed_support_logit",
      first_pass_chains = 1L, confirmation_chains = 3L,
      article_promotion = FALSE))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(read.csv(file.path(parent_run, "candidate_bank.csv"),
    stringsAsFactors = FALSE), file.path(run, "candidate_bank.csv"))
  base_imports <- read.csv(file.path(parent_run, "manifests",
    "parent_imports.csv"), stringsAsFactors = FALSE)
  iqt12_csv(base_imports, file.path(run, "manifests", "parent_imports.csv"))
  iqt12_csv(ifbv3_parent_bridge_import(parent_run),
    file.path(run, "manifests", "v2_bridge_imports.csv"))
  env <- list(schema = ifbv3_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    package_path = find.package("exdqlm", lib.loc = library),
    session = capture.output(sessionInfo()),
    threads = list(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1,
      MKL_NUM_THREADS = 1, RCPP_PARALLEL_NUM_THREADS = 1), source_head = head)
  iqt12_json(env, file.path(run, "environment.json"))
  configs <- list()
  for (candidate_id in ifbv3_new_candidates) for (fold in ism1_folds)
    for (offset in icav2_bridge_offsets)
      configs[[length(configs) + 1L]] <- ifbv3_config(state, candidate_id,
        fold, offset, "candidate_bridge", 1L)
  iqt12_plan(state, configs, "candidate_bridge")
  e <- ism1_runtime(repo, library)
  code <- unique(c(e$iqt12_loaded_files, file.path(repo, "R/exal_online_vbld.R"),
    file.path(repo, "validation/fitforecast_v2/R", c(
      "independent_qdesn_training1000_runtime_v1.R",
      "independent_qdesn_training1000_campaign_v1.R",
      "independent_qdesn_sentinel_mechanism_v1.R",
      "independent_qdesn_sentinel_mechanism_recovery_v1.R",
      "independent_qdesn_causal_adaptation_v2.R",
      "independent_qdesn_mcmc_finalist_bridge_v3.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_mcmc_finalist_bridge_v3.R",
      "run_independent_qdesn_mcmc_finalist_bridge_v3.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_MCMC_FINALIST_BRIDGE_V3_20261009.md"),
    file.path(repo, "validation/fitforecast_v2/tests",
      "test_independent_qdesn_mcmc_finalist_bridge_v3.R")))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(ifbv3_files(file.path(library, "exdqlm")),
    file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "manifests/parent_imports.csv",
    "manifests/v2_bridge_imports.csv")),
    file.path(parent_run, c("source_hashes.csv", "input_hashes.csv",
      "package_hashes.csv", "frozen_hashes.csv", "closeout.json",
      "closeout_manifest.csv"))), file.path(run, "input_hashes.csv"))
  preflight <- list(schema = ifbv3_schema, status = "READY_TO_LAUNCH",
    imported_v2_bridge_jobs = 12L, new_candidate_bridge_jobs = length(configs),
    possible_confirmation_jobs = 24L, sealed_block_opened = FALSE,
    article_changed = FALSE)
  iqt12_json(preflight, file.path(run, "preflight.json"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "preflight.json",
    "manifests/parent_imports.csv", "manifests/v2_bridge_imports.csv")),
    list.files(file.path(run, "plans"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  ifbv3_verify_imports(run)
  invisible(preflight)
}

ifbv3_local_results <- function(run, stage) {
  plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")),
    stringsAsFactors = FALSE)
  stopifnot(all(vapply(plan$status_path, ifbv3_status, "") == "SUCCESS"))
  do.call(rbind, lapply(plan$config_path, function(path) {
    cfg <- iqt12_read(path)
    read.csv(file.path(cfg$evidence, "summary.csv"), stringsAsFactors = FALSE)
  }))
}

ifbv3_imported_bridge_results <- function(run) {
  imports <- read.csv(file.path(run, "manifests", "v2_bridge_imports.csv"),
    stringsAsFactors = FALSE)
  do.call(rbind, lapply(imports$evidence, function(path)
    read.csv(file.path(path, "summary.csv"), stringsAsFactors = FALSE)))
}

ifbv3_parent_metric <- function(run, role, candidate_id, fold, origin) {
  imports <- read.csv(file.path(run, "manifests", "parent_imports.csv"),
    stringsAsFactors = FALSE)
  icav2_parent_origin_metric(imports, role, candidate_id, fold, origin)
}

ifbv3_compare <- function(run, results) {
  mae <- results[results$metric == "forecast_mae", ]
  check <- results[results$metric == "forecast_check_loss", ]
  stopifnot(nrow(mae) == nrow(check))
  rows <- lapply(seq_len(nrow(mae)), function(i) {
    candidate_id <- mae$candidate_id[i]; fold <- mae$fold[i]
    origin <- mae$refit_origin[i]
    static <- ifbv3_parent_metric(run, "qdesn_mcmc", candidate_id, fold, origin)
    baseline <- ifbv3_parent_metric(run, "baseline_mcmc", NULL, fold, origin)
    check_value <- check$mean[check$candidate_id == candidate_id &
      check$fold == fold & check$refit_origin == origin]
    stopifnot(length(check_value) == 1L)
    data.frame(candidate_id = candidate_id, fold = fold, origin = origin,
      offset = origin - c(S1 = 8000L, S2 = 8250L, S3 = 8500L,
        S4 = 8750L)[fold], adapted_mae = mae$mean[i],
      static_mae = static[1L], baseline_mae = baseline[1L],
      adapted_check_loss = check_value, static_check_loss = static[2L],
      baseline_check_loss = baseline[2L],
      adapted_static_mae_ratio = mae$mean[i] / static[1L],
      adapted_baseline_mae_ratio = mae$mean[i] / baseline[1L],
      adapted_static_check_ratio = check_value / static[2L],
      adapted_baseline_check_ratio = check_value / baseline[2L])
  })
  do.call(rbind, rows)
}

ifbv3_rank <- function(comparison) {
  do.call(rbind, lapply(split(comparison, comparison$candidate_id), function(z)
    data.frame(candidate_id = z$candidate_id[1L], cells = nrow(z),
      median_adapted_mae = median(z$adapted_mae),
      median_static_mae_ratio = median(z$adapted_static_mae_ratio),
      static_mae_wins = sum(z$adapted_static_mae_ratio < 1),
      median_baseline_mae_ratio = median(z$adapted_baseline_mae_ratio),
      baseline_mae_wins = sum(z$adapted_baseline_mae_ratio < 1),
      worst_baseline_mae_ratio = max(z$adapted_baseline_mae_ratio),
      median_baseline_check_ratio = median(z$adapted_baseline_check_ratio),
      baseline_check_wins = sum(z$adapted_baseline_check_ratio < 1),
      adaptation_supported = median(z$adapted_static_mae_ratio) < 1 &&
        sum(z$adapted_static_mae_ratio < 1) >= 8L,
      closes_baseline_gap = median(z$adapted_baseline_mae_ratio) < 1 &&
        sum(z$adapted_baseline_mae_ratio < 1) >= 7L,
      stringsAsFactors = FALSE)))
}

ifbv3_order_rank <- function(rank) rank[order(rank$median_baseline_mae_ratio,
  -rank$baseline_mae_wins, rank$median_baseline_check_ratio,
  rank$worst_baseline_mae_ratio, rank$candidate_id), ]

ifbv3_make_confirmation <- function(run, selected) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  configs <- list()
  for (fold in ism1_folds) for (offset in icav2_bridge_offsets)
    for (chain in 2:3)
      configs[[length(configs) + 1L]] <- ifbv3_config(state,
        selected$candidate_id, fold, offset, "confirmation", chain)
  iqt12_plan(state, configs, "confirmation")
}

ifbv3_evidence_manifests <- function(run) {
  statuses <- list.files(file.path(run, "status"), pattern = "[.]json$",
    full.names = TRUE)
  manifests <- vapply(statuses, function(path) {
    status <- iqt12_read(path)
    if (status$status == "SUCCESS") status$manifest else NA_character_
  }, "")
  unique(manifests[!is.na(manifests)])
}

ifbv3_closeout <- function(run, decision, details) {
  closeout <- c(list(status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = decision, article_changed = FALSE, active_jobs = 0L,
    fitted_model_binary_payloads = 0L), details)
  iqt12_json(closeout, file.path(run, "closeout.json"))
  payloads <- list.files(run, recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  stopifnot(!length(payloads))
  files <- c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "frozen_hashes.csv", "preflight.json",
    "closeout.json")), ifbv3_files(file.path(run, "manifests")),
    ifbv3_files(file.path(run, "plans")),
    ifbv3_files(file.path(run, "configs")),
    ifbv3_files(file.path(run, "status")),
    ifbv3_files(file.path(run, "selections")),
    ifbv3_files(file.path(run, "summaries")),
    ifbv3_files(file.path(run, "review")), ifbv3_evidence_manifests(run))
  iqt12_hash(files, file.path(run, "closeout_manifest.csv"))
  stopifnot(iqt12_verify(file.path(run, "closeout_manifest.csv")))
  "COMPLETE_REVIEW_REQUIRED"
}

ifbv3_chain1_results <- function(run) rbind(ifbv3_imported_bridge_results(run),
  ifbv3_local_results(run, "candidate_bridge"))

ifbv3_advance_candidate <- function(run) {
  results <- ifbv3_chain1_results(run)
  stopifnot(length(unique(results$candidate_id)) == 3L)
  comparison <- ifbv3_compare(run, results)
  rank <- ifbv3_order_rank(ifbv3_rank(comparison))
  iqt12_csv(results, file.path(run, "summaries", "all_finalist_chain1_metrics.csv"))
  iqt12_csv(comparison, file.path(run, "review", "all_finalist_chain1_comparison.csv"))
  iqt12_csv(rank, file.path(run, "review", "all_finalist_chain1_rank.csv"))
  selected <- rank[1L, ]
  iqt12_json(as.list(selected), file.path(run, "selections",
    "chain1_selected.json"))
  if (!isTRUE(selected$closes_baseline_gap))
    return(ifbv3_closeout(run,
      "NO_EXACT_MCMC_FINALIST_CLOSES_GAP_DYNAMIC_READOUT_SCOPE_REQUIRED",
      list(candidate_bridge_jobs = 24L, confirmation_jobs = 0L,
        selected_candidate_id = selected$candidate_id,
        selected_median_baseline_mae_ratio = selected$median_baseline_mae_ratio,
        selected_baseline_mae_wins = selected$baseline_mae_wins,
        next_action = "design_local_rolling_readout_update_without_more_static_DESN_screening")))
  ifbv3_make_confirmation(run, selected)
  "confirmation"
}

ifbv3_aggregate_confirmation <- function(chain1, added, candidate_id) {
  z <- rbind(chain1[chain1$candidate_id == candidate_id, ], added)
  keys <- c("candidate_id", "fold", "refit_origin", "metric")
  counts <- aggregate(z$mean, z[keys], length)
  stopifnot(nrow(counts) == 12L * length(unique(z$metric)), all(counts$x == 3L))
  mean_rows <- aggregate(z$mean, z[keys], mean)
  names(mean_rows)[names(mean_rows) == "x"] <- "mean"
  spread <- aggregate(z$mean, z[keys], function(x) max(x) - min(x))
  names(spread)[names(spread) == "x"] <- "chain_range"
  list(mean = mean_rows, spread = spread, raw = z)
}

ifbv3_advance_confirmation <- function(run) {
  selected <- iqt12_read(file.path(run, "selections", "chain1_selected.json"))
  aggregated <- ifbv3_aggregate_confirmation(ifbv3_chain1_results(run),
    ifbv3_local_results(run, "confirmation"), selected$candidate_id)
  comparison <- ifbv3_compare(run, aggregated$mean)
  rank <- ifbv3_order_rank(ifbv3_rank(comparison))
  iqt12_csv(aggregated$raw,
    file.path(run, "summaries", "selected_three_chain_metrics.csv"))
  iqt12_csv(aggregated$spread,
    file.path(run, "review", "selected_three_chain_metric_spread.csv"))
  iqt12_csv(comparison,
    file.path(run, "review", "selected_three_chain_comparison.csv"))
  iqt12_csv(rank, file.path(run, "review", "selected_three_chain_rank.csv"))
  confirmed <- isTRUE(rank$closes_baseline_gap[1L])
  decision <- if (confirmed)
    "EXACT_MCMC_FINALIST_CLOSES_GAP_FRESH_DGP_PROTOCOL_CONFIRMATION_REQUIRED" else
    "CHAIN1_GAIN_NOT_CONFIRMED_DYNAMIC_READOUT_SCOPE_REQUIRED"
  ifbv3_closeout(run, decision,
    list(candidate_bridge_jobs = 24L, confirmation_jobs = 24L,
      selected_candidate_id = rank$candidate_id[1L],
      selected_median_baseline_mae_ratio = rank$median_baseline_mae_ratio[1L],
      selected_baseline_mae_wins = rank$baseline_mae_wins[1L],
      three_chain_confirmed = confirmed,
      next_action = if (confirmed) "freeze_protocol_then_fresh_DGP_confirmation" else
        "design_local_rolling_readout_update_without_more_static_DESN_screening"))
}

ifbv3_advance <- function(run, stage) {
  ifbv3_verify_imports(run)
  if (stage == "candidate_bridge") return(ifbv3_advance_candidate(run))
  if (stage == "confirmation") return(ifbv3_advance_confirmation(run))
  stop("Unsupported finalist-bridge stage: ", stage)
}

ifbv3_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "[.]csv$",
    full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  z <- do.call(rbind, lapply(plans, read.csv, stringsAsFactors = FALSE))
  status <- vapply(z$status_path, ifbv3_status, "")
  data.frame(total = nrow(z), complete = sum(status == "SUCCESS"),
    running = sum(status == "RUNNING"), pending = sum(status == "PENDING"),
    failed = sum(grepl("FAILED", status)), stages = length(unique(z$stage)))
}
