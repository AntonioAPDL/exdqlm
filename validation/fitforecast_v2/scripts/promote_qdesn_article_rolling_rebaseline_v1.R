#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/", mustWork = TRUE
)

promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v5_rolling_rebaseline_20260811"
base_id <- "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809"
base_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", base_id
)
audit_dir <- file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration",
  "qdesn_article_rolling_rebaseline_v1_20260811"
)
output_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", promotion_id
)

expected <- list(
  implementation_commit = "c48e1b3de8703f59f57eb4a1cb92a5b3596b27b7",
  base_interface_sha256 = "3cc65a3ec8d572e91ff2b69b37f53ee47ce9ebd0fec1fe370a1e6bf24c757c23",
  base_manifest_sha256 = "71f2a24b2750c3a92505e6c0597d95f53fa55313c079ac398f51bd78f6989e70",
  base_source_ledger_sha256 = "109922b4bb8535517482a13d2719b418d5f13fe6eebd99514d5c91a192c4b53a",
  audit_manifest_sha256 = "25bf0673036ba74e7552f8d4c153395d625d50ef491c4d2b265bf62ba4b0c700",
  source_registry_hash = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  validation_branch = "validation/independent-exal-m0-structural-screen-v2-1.0.0"
)

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) {
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
copy_verified <- function(source, destination, expected_sha = sha256(source)) {
  if (!file.exists(source) || !identical(sha256(source), expected_sha)) {
    stop(sprintf("Source is missing or changed: %s", source), call. = FALSE)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, destination, overwrite = FALSE)) {
    stop(sprintf("Could not freeze source: %s", source), call. = FALSE)
  }
  if (!identical(sha256(destination), expected_sha)) {
    stop(sprintf("Frozen source hash mismatch: %s", destination), call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}
gzip_verified <- function(source, destination, expected_source_sha) {
  if (!file.exists(source) || !identical(sha256(source), expected_source_sha)) {
    stop(sprintf("Raw rolling source is missing or changed: %s", source), call. = FALSE)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  input <- file(source, open = "rb")
  output <- gzfile(destination, open = "wb", compression = 9L)
  repeat {
    buffer <- readBin(input, what = "raw", n = 1024L * 1024L)
    if (!length(buffer)) break
    writeBin(buffer, output)
  }
  close(input)
  close(output)
  gz_input <- gzfile(destination, open = "rb")
  decompressed <- readBin(gz_input, what = "raw", n = file.info(source)$size)
  close(gz_input)
  original <- readBin(source, what = "raw", n = file.info(source)$size)
  if (!identical(decompressed, original)) {
    stop(sprintf("Compressed rolling source does not round-trip: %s", source), call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}
split_list <- function(value) {
  values <- strsplit(as.character(value), ";", fixed = TRUE)[[1L]]
  values[nzchar(values)]
}

paths <- list(
  base_interface = file.path(base_dir, paste0(base_id, "_interface.csv")),
  base_manifest = file.path(base_dir, paste0(base_id, "_manifest.json")),
  base_source_ledger = file.path(base_dir, "source_ledger.csv"),
  audit_manifest = file.path(audit_dir, "rolling_metric_contract_manifest.json"),
  audit = file.path(audit_dir, "rolling_metric_contract_audit.csv"),
  rederived = file.path(audit_dir, "qdesn_rederived_rolling_metrics.csv"),
  unresolved = file.path(audit_dir, "unresolved_evidence_ledger.csv"),
  provisional = file.path(audit_dir, "provisional_rolling_rebaseline_interface.csv"),
  metric_gaps = file.path(audit_dir, "qdesn_comparator_metric_gap_ledger.csv"),
  cell_priorities = file.path(audit_dir, "qdesn_comparator_cell_priority_ledger.csv"),
  source_roots = file.path(
    repo_root, "config", "validation", "qdesn_article_rolling_rebaseline_v1_source_roots.csv"
  )
)
missing <- names(paths)[!file.exists(unlist(paths, use.names = FALSE))]
if (length(missing)) {
  stop(sprintf("Missing required promotion inputs: %s", paste(missing, collapse = ", ")), call. = FALSE)
}
if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE, no.. = TRUE))) {
  stop(sprintf("Refusing to overwrite nonempty promotion directory: %s", output_dir), call. = FALSE)
}

head_commit <- system("git rev-parse HEAD", intern = TRUE)
branch <- system("git branch --show-current", intern = TRUE)
if (!identical(head_commit, expected$implementation_commit) ||
    !identical(branch, expected$validation_branch)) {
  stop("Promotion must run from the committed rolling-contract implementation.", call. = FALSE)
}
if (!identical(sha256(paths$base_interface), expected$base_interface_sha256) ||
    !identical(sha256(paths$base_manifest), expected$base_manifest_sha256) ||
    !identical(sha256(paths$base_source_ledger), expected$base_source_ledger_sha256) ||
    !identical(sha256(paths$audit_manifest), expected$audit_manifest_sha256)) {
  stop("A pinned promotion input has changed.", call. = FALSE)
}

base <- read_csv(paths$base_interface)
provisional <- read_csv(paths$provisional)
audit <- read_csv(paths$audit)
rederived <- read_csv(paths$rederived)
unresolved <- read_csv(paths$unresolved)
metric_gaps <- read_csv(paths$metric_gaps)
cell_priorities <- read_csv(paths$cell_priorities)
audit_manifest <- jsonlite::read_json(paths$audit_manifest, simplifyVector = TRUE)
base_manifest <- jsonlite::read_json(paths$base_manifest, simplifyVector = TRUE)

if (nrow(base) != 72L || nrow(provisional) != 72L || nrow(audit) != 144L ||
    nrow(rederived) != 72L || nrow(unresolved) != 0L ||
    !identical(as.integer(audit_manifest$qdesn_raw_rolling_pass_rows), 72L) ||
    !identical(as.integer(audit_manifest$qdesn_metric_mismatches), 71L) ||
    !identical(as.integer(audit_manifest$unresolved_rows), 0L) ||
    !identical(as.character(base_manifest$source_registry_hash_value), expected$source_registry_hash) ||
    any(base$source_registry_hash_value != expected$source_registry_hash)) {
  stop("The rolling audit or base authority violates the frozen contract.", call. = FALSE)
}
for (name in c("audit", "qdesn_rederived", "unresolved", "provisional_interface",
               "metric_gap_ledger", "cell_priority_ledger")) {
  item <- audit_manifest$outputs[[name]]
  if (is.null(item) || !file.exists(item$path) || !identical(sha256(item$path), item$sha256)) {
    stop(sprintf("Rolling audit output does not verify: %s", name), call. = FALSE)
  }
}

base_columns <- names(base)
if (!all(base_columns %in% names(provisional)) ||
    !identical(base$fit_qtrue_rmse, provisional$fit_qtrue_rmse)) {
  stop("The provisional interface changed non-forecast authority.", call. = FALSE)
}
qdesn <- grepl("^qdesn_", provisional$model_variant)
if (sum(qdesn) != 36L ||
    any(provisional$forecast_metric_contract[qdesn] != "raw_rolling_origin_rederived") ||
    any(rederived$evidence_status != "RAW_ROLLING_PASS") ||
    any(rederived$raw_rolling_paths_pass != rederived$raw_rolling_paths)) {
  stop("Q-DESN rolling evidence is incomplete.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
snapshot_dir <- file.path(output_dir, "source_snapshots")
ledger_rows <- list()
add_ledger <- function(source_id, path, source_sha = sha256(path)) {
  ledger_rows[[length(ledger_rows) + 1L]] <<- data.frame(
    source_id = source_id, path = path, sha256 = source_sha,
    stringsAsFactors = FALSE
  )
}
for (name in names(paths)) {
  group <- if (startsWith(name, "base_")) "base_v4" else "rolling_audit"
  frozen <- copy_verified(paths[[name]], file.path(snapshot_dir, group, basename(paths[[name]])))
  add_ledger(paste0("snapshot_", name), frozen)
}

metric_fields <- list(
  c(path = "fit_source_path", sha = "fit_source_sha256"),
  c(path = "forecast_mae_source_path", sha = "forecast_mae_source_sha256"),
  c(path = "forecast_check_source_path", sha = "forecast_check_source_sha256")
)
article <- provisional
frozen_metric_map <- new.env(parent = emptyenv())
for (definition in metric_fields) {
  path_column <- definition[["path"]]
  sha_column <- definition[["sha"]]
  for (i in seq_len(nrow(article))) {
    source <- base[[path_column]][[i]]
    source_sha <- base[[sha_column]][[i]]
    map_key <- paste(source_sha, basename(source), sep = "::")
    if (!exists(map_key, envir = frozen_metric_map, inherits = FALSE)) {
      destination <- file.path(
        output_dir, "metric_sources", "frozen_v4", substr(source_sha, 1L, 16L), basename(source)
      )
      frozen <- copy_verified(source, destination, source_sha)
      assign(map_key, frozen, envir = frozen_metric_map)
      add_ledger(paste0("v4_metric_", substr(source_sha, 1L, 16L), "_", basename(source)),
                 frozen, source_sha)
    }
    article[[path_column]][[i]] <- get(map_key, envir = frozen_metric_map, inherits = FALSE)
    article[[sha_column]][[i]] <- source_sha
  }
}

raw_map <- new.env(parent = emptyenv())
evidence <- rederived
evidence$original_raw_rolling_path_list <- evidence$raw_rolling_path_list
evidence$original_raw_rolling_sha256_list <- evidence$raw_rolling_sha256_list
evidence$frozen_rolling_path_list <- ""
evidence$frozen_rolling_sha256_list <- ""
for (i in seq_len(nrow(evidence))) {
  source_paths <- split_list(evidence$raw_rolling_path_list[[i]])
  source_hashes <- split_list(evidence$raw_rolling_sha256_list[[i]])
  if (!length(source_paths) || length(source_paths) != length(source_hashes)) {
    stop(sprintf("Malformed raw rolling evidence row: %d", i), call. = FALSE)
  }
  frozen_paths <- character(length(source_paths))
  frozen_hashes <- character(length(source_paths))
  for (j in seq_along(source_paths)) {
    map_key <- paste(source_hashes[[j]], basename(source_paths[[j]]), sep = "::")
    if (!exists(map_key, envir = raw_map, inherits = FALSE)) {
      destination <- file.path(
        output_dir, "metric_sources", "rolling_raw",
        substr(source_hashes[[j]], 1L, 16L), paste0(basename(source_paths[[j]]), ".gz")
      )
      frozen <- gzip_verified(source_paths[[j]], destination, source_hashes[[j]])
      assign(map_key, frozen, envir = raw_map)
      add_ledger(
        paste0("rolling_raw_", substr(source_hashes[[j]], 1L, 16L)),
        frozen, sha256(frozen)
      )
    }
    frozen_paths[[j]] <- get(map_key, envir = raw_map, inherits = FALSE)
    frozen_hashes[[j]] <- sha256(frozen_paths[[j]])
  }
  evidence$frozen_rolling_path_list[[i]] <- paste(frozen_paths, collapse = ";")
  evidence$frozen_rolling_sha256_list[[i]] <- paste(frozen_hashes, collapse = ";")
}
evidence_path <- write_csv(
  evidence,
  file.path(output_dir, "metric_sources", "rolling_rebaseline",
            "qdesn_rolling_rederived_metrics.csv")
)
evidence_sha <- sha256(evidence_path)
add_ledger("rolling_rederived_metric_evidence", evidence_path, evidence_sha)

article$article_interface_id <- promotion_id
article$rolling_rebaseline_state <- "AUTHORITATIVE_ROLLING_REBASELINE_V1"
article$article_consumption_allowed <- TRUE
article$promotion_validation_branch <- expected$validation_branch
article$promotion_validation_commit <- expected$implementation_commit
article$rolling_evidence_promotion_id <- ifelse(qdesn, promotion_id, "")
article$forecast_mae_source_path[qdesn] <- evidence_path
article$forecast_mae_source_sha256[qdesn] <- evidence_sha
article$forecast_check_source_path[qdesn] <- evidence_path
article$forecast_check_source_sha256[qdesn] <- evidence_sha

expected_grid <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50), stringsAsFactors = FALSE
)
key <- with(article, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_key <- with(expected_grid, paste(inference, model_variant, family, sprintf("%.2f", tau)))
if (anyDuplicated(key) || !setequal(key, expected_key) || any(article$status != "SUCCESS") ||
    !all(as_bool(article$comparison_eligible)) || !all(as_bool(article$article_consumption_allowed)) ||
    any(!is.finite(as.numeric(unlist(article[c(
      "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
    )], use.names = FALSE)))) || any(grepl("ridge", article$model_variant))) {
  stop("The promoted article interface violates its fixed grid.", call. = FALSE)
}

interface_path <- write_csv(article, file.path(output_dir, paste0(promotion_id, "_interface.csv")))
decision_path <- write_csv(evidence, file.path(output_dir, "rolling_metric_decision_ledger.csv"))
gap_path <- write_csv(metric_gaps, file.path(output_dir, "remaining_gap_ledger.csv"))
priority_path <- write_csv(cell_priorities, file.path(output_dir, "cell_priority_ledger.csv"))

source_ledger <- unique(do.call(rbind, ledger_rows))
source_ledger <- source_ledger[order(source_ledger$source_id, source_ledger$path), , drop = FALSE]
row.names(source_ledger) <- NULL
if (anyDuplicated(source_ledger$source_id) || any(!file.exists(source_ledger$path)) ||
    !identical(unname(tools::sha256sum(source_ledger$path)), unname(source_ledger$sha256))) {
  stop("The self-contained source ledger does not verify.", call. = FALSE)
}
source_ledger_path <- write_csv(source_ledger, file.path(output_dir, "source_ledger.csv"))

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_ROLLING_ORIGIN_REBASELINE_V1",
  scientific_decision = "CORRECT_QDESN_FORECAST_METRICS_FROM_VERIFIED_RAW_ROLLING_PATHS",
  package_version = "1.0.0",
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = expected$source_registry_hash,
  expected_rows = 72L,
  observed_rows = nrow(article),
  vb_rows = sum(article$inference == "vb"),
  mcmc_rows = sum(article$inference == "mcmc"),
  ridge_rows = sum(grepl("ridge", article$model_variant)),
  ridge_policy = "EXCLUDED_UNTIL_SEPARATELY_REPLAYED_UNDER_TRAIN_ONLY_PREPROCESSING",
  base_promotion_id = base_id,
  base_interface_sha256 = expected$base_interface_sha256,
  rolling_audit_manifest_sha256 = expected$audit_manifest_sha256,
  validation_branch = expected$validation_branch,
  validation_commit = expected$implementation_commit,
  forecast_protocol = "rolling_origin_no_refit_state_update",
  forecast_max_lead_configured = 30L,
  forecast_origin_stride = 30L,
  qdesn_forecast_metric_roles = nrow(rederived),
  qdesn_corrected_metric_roles = sum(abs(rederived$absolute_difference) > 1e-8),
  unresolved_metric_roles = nrow(unresolved),
  frozen_raw_rolling_sources = length(ls(raw_map)),
  selection_policy = "protocol correction only; no model or candidate reselection",
  diagnostic_status_used_as_metric_filter = FALSE,
  storage_policy_pass = TRUE,
  binary_payload_count = 0L,
  article_interface_path = interface_path,
  article_interface_sha256 = sha256(interface_path),
  rolling_metric_decision_ledger_path = decision_path,
  rolling_metric_decision_ledger_sha256 = sha256(decision_path),
  remaining_gap_ledger_path = gap_path,
  remaining_gap_ledger_sha256 = sha256(gap_path),
  cell_priority_ledger_path = priority_path,
  cell_priority_ledger_sha256 = sha256(priority_path),
  source_ledger_path = source_ledger_path,
  source_ledger_sha256 = sha256(source_ledger_path),
  article_update_status = "READY_FOR_ARTICLE_REGENERATION",
  calibration_campaign_status = "PREPARED_NOT_APPROVED_NOT_LAUNCHED",
  invalid_or_aborted_run_tags = base_manifest$invalid_or_aborted_run_tags
)
manifest_path <- file.path(output_dir, paste0(promotion_id, "_manifest.json"))
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, na = "null")

readme <- c(
  "# Independent Q-DESN rolling-origin article promotion",
  "",
  "This immutable promotion corrects Q-DESN forecast MAE and check loss from",
  "verified lead-level rolling-origin paths. It does not select new candidates",
  "or launch calibration. Fit metrics and DQLM/exDQLM evidence remain inherited",
  "from the verified v4 authority.",
  "",
  sprintf("- Interface rows: %d", nrow(article)),
  sprintf("- Q-DESN forecast roles verified: %d", nrow(rederived)),
  sprintf("- Corrected values: %d", manifest$qdesn_corrected_metric_roles),
  sprintf("- Frozen compressed rolling sources: %d", manifest$frozen_raw_rolling_sources),
  sprintf("- Unresolved roles: %d", manifest$unresolved_metric_roles),
  sprintf("- Interface SHA-256: `%s`", manifest$article_interface_sha256),
  sprintf("- Source ledger SHA-256: `%s`", manifest$source_ledger_sha256),
  "- Binary payloads: 0",
  "",
  "The separate 84-job paired calibration campaign remains prepared but",
  "unlaunched and is not part of this article promotion."
)
writeLines(readme, file.path(output_dir, "README.md"), useBytes = TRUE)

heavy <- list.files(
  output_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
if (length(heavy)) stop("Promotion contains a forbidden binary payload.", call. = FALSE)

outputs <- sort(list.files(output_dir, recursive = TRUE, full.names = TRUE))
outputs <- outputs[!file.info(outputs)$isdir]
outputs <- outputs[basename(outputs) != "output_file_manifest.csv"]
output_manifest <- data.frame(
  path = substring(normalizePath(outputs, winslash = "/"), nchar(repo_root) + 2L),
  bytes = as.numeric(file.info(outputs)$size),
  sha256 = unname(tools::sha256sum(outputs)), stringsAsFactors = FALSE
)
write_csv(output_manifest, file.path(output_dir, "output_file_manifest.csv"))

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat(sprintf("INTERFACE=%s\n", interface_path))
cat(sprintf("INTERFACE_SHA256=%s\n", manifest$article_interface_sha256))
cat(sprintf("SOURCE_LEDGER_SHA256=%s\n", manifest$source_ledger_sha256))
cat(sprintf("QDESN_FORECAST_ROLES=%d\n", manifest$qdesn_forecast_metric_roles))
cat(sprintf("CORRECTED_ROLES=%d\n", manifest$qdesn_corrected_metric_roles))
cat(sprintf("FROZEN_ROLLING_SOURCES=%d\n", manifest$frozen_raw_rolling_sources))
cat("ARTICLE_STATUS=READY_FOR_ARTICLE_REGENERATION\n")
cat("STORAGE_POLICY=PASS\n")
