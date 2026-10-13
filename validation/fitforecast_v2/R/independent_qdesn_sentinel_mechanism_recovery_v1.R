ism1r_schema <- "independent_qdesn_sentinel_mechanism_recovery_v1"
ism1r_source_stages <- c("smoke", "normal_screen", "quantile_screen")
ism1r_run_stages <- c("quantile_screen", "online_pilot", "short_mcmc",
  "full_mcmc", "controls_vb", "controls_mcmc")

ism1r_status <- function(path) {
  if (!file.exists(path)) return("PENDING")
  as.character(iqt12_read(path)$status)
}

ism1r_source_audit <- function(source_run) {
  required <- c("campaign.json", "environment.json", "candidate_bank.csv",
    "source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
    "frozen_hashes.csv")
  stopifnot(dir.exists(source_run), all(file.exists(file.path(source_run, required))))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv")) iqt12_verify(file.path(source_run, name))
  plans <- lapply(ism1r_source_stages, function(stage) {
    hash <- file.path(source_run, "plans", paste0(stage, "_hashes.csv"))
    iqt12_verify(hash)
    z <- read.csv(file.path(source_run, "plans", paste0(stage, ".csv")),
      stringsAsFactors = FALSE)
    z$source_stage <- stage
    z$source_status <- vapply(z$status_path, ism1r_status, "")
    z
  })
  jobs <- do.call(rbind, plans)
  stopifnot(nrow(jobs) == 690L, sum(jobs$source_status == "SUCCESS") == 529L,
    sum(jobs$source_status == "FAILED_IMPLEMENTATION") == 6L,
    sum(jobs$source_status == "PENDING") == 155L,
    all(jobs$source_status[jobs$source_stage != "quantile_screen"] == "SUCCESS"),
    !anyDuplicated(jobs$id))
  success <- jobs[jobs$source_status == "SUCCESS", ]
  for (path in success$status_path) iqt12_verify(iqt12_read(path)$manifest)
  jobs
}

ism1r_import_record <- function(row) {
  status <- iqt12_read(row$status_path)
  cfg <- iqt12_read(row$config_path)
  data.frame(stage = row$source_stage, id = row$id,
    candidate_id = row$candidate_id, fold = row$fold,
    source_config_path = normalizePath(row$config_path, mustWork = TRUE),
    source_config_sha256 = unname(tools::sha256sum(row$config_path)),
    source_status_path = normalizePath(row$status_path, mustWork = TRUE),
    source_status_sha256 = unname(tools::sha256sum(row$status_path)),
    source_evidence_path = normalizePath(cfg$evidence, mustWork = TRUE),
    source_evidence_manifest = normalizePath(status$manifest, mustWork = TRUE),
    source_evidence_manifest_sha256 = unname(tools::sha256sum(status$manifest)),
    stringsAsFactors = FALSE)
}

ism1r_verify_imports <- function(run) {
  imports <- read.csv(file.path(run, "manifests/imported_successes.csv"),
    stringsAsFactors = FALSE)
  stopifnot(nrow(imports) == 529L,
    all(file.exists(imports$source_config_path)),
    all(file.exists(imports$source_status_path)),
    all(file.exists(imports$source_evidence_manifest)),
    identical(unname(tools::sha256sum(imports$source_config_path)),
      imports$source_config_sha256),
    identical(unname(tools::sha256sum(imports$source_status_path)),
      imports$source_status_sha256),
    identical(unname(tools::sha256sum(imports$source_evidence_manifest)),
      imports$source_evidence_manifest_sha256))
  for (path in imports$source_evidence_manifest) iqt12_verify(path)
  invisible(TRUE)
}

ism1r_clone_config <- function(row, state, source_status) {
  original <- iqt12_read(row$config_path)
  original$parent_config_path <- normalizePath(row$config_path, mustWork = TRUE)
  original$parent_config_sha256 <- unname(tools::sha256sum(row$config_path))
  original$parent_worker_status <- source_status
  original$recovery_schema <- ism1r_schema
  original$run <- state$run
  original$repo <- state$repo
  original$library <- state$library
  original$path <- file.path(state$run, "configs", paste0(original$id, ".json"))
  original$status_path <- file.path(state$run, "status", paste0(original$id, ".json"))
  original$evidence <- file.path(state$run, "evidence", original$id)
  original
}

ism1r_write_plan <- function(state, stage, source_rows) {
  rows <- vector("list", nrow(source_rows))
  for (i in seq_len(nrow(source_rows))) {
    row <- source_rows[i, ]
    if (row$source_status == "SUCCESS") {
      rows[[i]] <- row[names(row) %in% c("id", "stage", "cell", "model",
        "engine", "N", "fold", "candidate_id", "columns", "config_path",
        "config_sha", "status_path", "timeout")]
    } else {
      stopifnot(stage == "quantile_screen",
        row$source_status %in% c("PENDING", "FAILED_IMPLEMENTATION"))
      cfg <- ism1r_clone_config(row, state, row$source_status)
      iqt12_json(cfg, cfg$path)
      out <- row[names(row) %in% c("id", "stage", "cell", "model", "engine",
        "N", "fold", "candidate_id", "columns", "timeout")]
      out$config_path <- cfg$path
      out$config_sha <- unname(tools::sha256sum(cfg$path))
      out$status_path <- cfg$status_path
      out <- out[c("id", "stage", "cell", "model", "engine", "N", "fold",
        "candidate_id", "columns", "config_path", "config_sha", "status_path",
        "timeout")]
      rows[[i]] <- out
    }
  }
  plan <- do.call(rbind, rows)
  stopifnot(nrow(plan) == nrow(source_rows), !anyDuplicated(plan$id))
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  iqt12_csv(plan, path)
  iqt12_hash(c(path, plan$config_path),
    file.path(state$run, "plans", paste0(stage, "_hashes.csv")))
  plan
}

ism1r_partial_window_audit <- function(jobs, output_dir) {
  selected <- jobs[jobs$source_stage == "quantile_screen" &
    jobs$source_status == "SUCCESS" & jobs$model == "qdesn", ]
  rows <- lapply(seq_len(nrow(selected)), function(i) {
    cfg <- iqt12_read(selected$config_path[i])
    z <- read.csv(file.path(cfg$evidence, "summary.csv"), stringsAsFactors = FALSE)
    z$config_path <- selected$config_path[i]
    z$evidence <- cfg$evidence
    z
  })
  result <- do.call(rbind, rows)
  complete_ids <- names(which(table(result$candidate_id[result$metric ==
    "forecast_mae"]) == length(ism1_folds)))
  stopifnot(length(complete_ids) >= 1L)
  rank <- do.call(rbind, lapply(complete_ids, function(id) {
    z <- result[result$candidate_id == id, ]
    cfg <- iqt12_read(z$config_path[1L])
    value <- function(metric, fun = median) fun(z$mean[z$metric == metric])
    data.frame(candidate_id = id, median_forecast_mae = value("forecast_mae"),
      max_forecast_mae = value("forecast_mae", max),
      median_check_loss = value("forecast_check_loss"),
      fit_rmse = value("fit_rmse"), readout_dimension = cfg$candidate$readout_dimension,
      stringsAsFactors = FALSE)
  }))
  rank <- rank[order(rank$median_forecast_mae, rank$median_check_loss,
    rank$max_forecast_mae, rank$readout_dimension, rank$candidate_id), ]
  leader <- rank$candidate_id[1L]
  evidence <- unique(result$evidence[result$candidate_id == leader])
  profile <- do.call(rbind, lapply(evidence, function(path) {
    x <- read.csv(gzfile(file.path(path, "origin_lead.csv.gz")),
      stringsAsFactors = FALSE)
    cfg <- iqt12_read(result$config_path[result$evidence == path][1L])
    x$fold <- cfg$window$fold
    x
  }))
  origin <- aggregate(cbind(mae, check_loss, bias) ~ fold + origin, profile, mean)
  origin <- origin[order(origin$fold, origin$origin), ]
  origin$origin_index <- ave(origin$origin, origin$fold,
    FUN = function(z) rank(z, ties.method = "first"))
  origin$origin_count <- ave(origin$origin, origin$fold, FUN = length)
  origin$origin_bin <- with(origin, ifelse(origin_index <= ceiling(origin_count / 3),
    "early", ifelse(origin_index > floor(2 * origin_count / 3), "late", "middle")))
  origin_bin <- aggregate(cbind(mae, check_loss, bias) ~ origin_bin, origin, mean)
  lead <- aggregate(cbind(mae, check_loss, bias) ~ lead, profile, mean)
  lead$lead_band <- cut(lead$lead, c(0, 5, 10, 20, 30),
    labels = c("1-5", "6-10", "11-20", "21-30"))
  lead_band <- aggregate(cbind(mae, check_loss, bias) ~ lead_band, lead, mean)
  slopes <- do.call(rbind, lapply(split(origin, origin$fold), function(z)
    data.frame(fold = z$fold[1L], origins = nrow(z),
      mae_slope_per_origin = unname(coef(lm(mae ~ origin_index, z))[2L]),
      check_slope_per_origin = unname(coef(lm(check_loss ~ origin_index, z))[2L]),
      early_mae = mean(z$mae[z$origin_bin == "early"]),
      late_mae = mean(z$mae[z$origin_bin == "late"]))))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  iqt12_csv(rank, file.path(output_dir, "partial_quantile_rank.csv"))
  iqt12_csv(origin, file.path(output_dir, "leader_origin_profile.csv"))
  iqt12_csv(origin_bin, file.path(output_dir, "leader_origin_bin_summary.csv"))
  iqt12_csv(lead, file.path(output_dir, "leader_lead_profile.csv"))
  iqt12_csv(lead_band, file.path(output_dir, "leader_lead_band_summary.csv"))
  iqt12_csv(slopes, file.path(output_dir, "leader_origin_slopes.csv"))
  iqt12_json(list(status = "PARTIAL_PRE_RECOVERY_DIAGNOSTIC_ONLY",
    leader_candidate_id = leader, complete_candidates = nrow(rank),
    primary_window_decision = "RETAIN_FULL_WINDOW",
    rationale = paste("No monotone material deterioration across origin thirds",
      "or 30 recursive leads; teacher forcing resets the observed history at every origin.")),
    file.path(output_dir, "forecast_window_decision.json"))
  invisible(list(rank = rank, origin_bin = origin_bin, lead_band = lead_band))
}

ism1r_materialize <- function(repo, run, source_run, library) {
  stopifnot(!dir.exists(run), dir.exists(repo), dir.exists(source_run),
    dir.exists(library))
  jobs <- ism1r_source_audit(source_run)
  parent <- iqt12_read(file.path(source_run, "campaign.json"))
  head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  state <- parent
  state$schema <- ism1r_schema
  state$repo <- normalizePath(repo, mustWork = TRUE)
  state$run <- normalizePath(dirname(run), mustWork = TRUE)
  state$run <- file.path(state$run, basename(run))
  state$library <- normalizePath(library, mustWork = TRUE)
  state$head <- head
  state$recovery <- list(parent_run = normalizePath(source_run, mustWork = TRUE),
    parent_head = parent$head, imported_successes = 529L,
    reexecuted_quantile_jobs = 161L, scientific_contract_changed = FALSE,
    implementation_change = "scale_aware_first_step_identity_guard")
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  for (name in c("control", "configs", "status", "evidence", "plans",
      "summaries", "selections", "review", "manifests"))
    dir.create(file.path(run, name), recursive = TRUE, showWarnings = FALSE)
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_csv(read.csv(file.path(source_run, "candidate_bank.csv"),
    stringsAsFactors = FALSE), file.path(run, "candidate_bank.csv"))
  env <- list(schema = ism1r_schema,
    exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    package_path = find.package("exdqlm", lib.loc = library),
    session = capture.output(sessionInfo()),
    threads = list(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1,
      MKL_NUM_THREADS = 1, RCPP_PARALLEL_NUM_THREADS = 1),
    source_head = head, parent_head = parent$head)
  iqt12_json(env, file.path(run, "environment.json"))

  success <- jobs[jobs$source_status == "SUCCESS", ]
  imports <- do.call(rbind, lapply(seq_len(nrow(success)), function(i)
    ism1r_import_record(success[i, ])))
  iqt12_csv(imports, file.path(run, "manifests/imported_successes.csv"))
  recovery <- jobs[jobs$source_status != "SUCCESS", c("source_stage", "id",
    "candidate_id", "fold", "source_status", "config_path", "status_path")]
  iqt12_csv(recovery, file.path(run, "manifests/recovery_jobs.csv"))
  for (stage in ism1r_source_stages)
    ism1r_write_plan(state, stage, jobs[jobs$source_stage == stage, ])
  ism1r_partial_window_audit(jobs, file.path(run, "review/pre_recovery_window_audit"))

  code <- c(file.path(repo, "validation/fitforecast_v2/R", c(
    "independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_sentinel_mechanism_recovery_v1.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_sentinel_mechanism_v1.R",
      "run_independent_qdesn_sentinel_mechanism_recovery_v1.sh")),
    file.path(repo, "validation/fitforecast_v2/docs",
      "INDEPENDENT_QDESN_SENTINEL_MECHANISM_RECOVERY_V1_20261008.md"))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  sources <- vapply(state$references, `[[`, "", "source_path")
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "manifests/imported_successes.csv",
    "manifests/recovery_jobs.csv")), sources,
    file.path(source_run, c("source_hashes.csv", "input_hashes.csv",
      "package_hashes.csv", "frozen_hashes.csv"))), file.path(run, "input_hashes.csv"))
  audit <- list(schema = ism1r_schema, status = "READY_TO_RESUME",
    parent_run = normalizePath(source_run, mustWork = TRUE),
    parent_head = parent$head, recovery_head = head,
    imported_successes = nrow(imports), recovery_jobs = nrow(recovery),
    failed_recovered = sum(recovery$source_status == "FAILED_IMPLEMENTATION"),
    pending_recovered = sum(recovery$source_status == "PENDING"),
    stages_to_execute = ism1r_run_stages, article_changed = FALSE)
  iqt12_json(audit, file.path(run, "recovery_preflight.json"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv",
    "package_hashes.csv", "manifests/imported_successes.csv",
    "manifests/recovery_jobs.csv", "recovery_preflight.json")), sources,
    list.files(file.path(run, "plans"), full.names = TRUE),
    list.files(file.path(run, "review/pre_recovery_window_audit"), full.names = TRUE)),
    file.path(run, "frozen_hashes.csv"))
  ism1r_verify_imports(run)
  invisible(audit)
}

ism1r_health <- function(run) {
  ism1r_verify_imports(run)
  h <- ism1_health(run)
  imports <- read.csv(file.path(run, "manifests/imported_successes.csv"),
    stringsAsFactors = FALSE)
  cbind(h, imported_successes = nrow(imports),
    recovery_successes = h$complete - nrow(imports))
}
