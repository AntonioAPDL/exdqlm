#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/freeze_independent_origin_horizon_attribution_v1_audit.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
audit_id <- "independent_origin_horizon_attribution_v1_20260826"
audit_root <- file.path(repo_root, "validation", "fitforecast_v2", "audits", audit_id)
if (dir.exists(audit_root)) {
  stop(sprintf("Audit packet already exists: %s", audit_root), call. = FALSE)
}

closeout_root <- file.path(state_root, "closeout")
decision_path <- file.path(closeout_root, "decision_manifest.json")
verification_path <- file.path(closeout_root, "closeout_verification.json")
decision <- ffv2_read_json(decision_path)
verification <- ffv2_read_json(verification_path)
if (!identical(as.character(verification$status), "PASS") ||
    !identical(as.character(decision$decision),
               "ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED") ||
    isTRUE(decision$article_update_authorized) ||
    isTRUE(decision$automatic_tau0_launch_authorized)) {
  stop("Only the verified no-promotion, no-tau0 closeout can be frozen.", call. = FALSE)
}
if (!identical(ffv2_file_sha256(decision_path),
               as.character(verification$decision_sha256))) {
  stop("Closeout verification does not match the decision manifest.", call. = FALSE)
}

asset_files <- c(
  decision = "decision_manifest.json",
  verification = "closeout_verification.json",
  verification_checks = "closeout_verification.csv",
  closeout_checks = "closeout_checks.csv",
  scientific_report = "scientific_closeout.md",
  diagnosis = "cell_mechanism_diagnosis.csv",
  variance = "pooled_variance_decomposition.csv",
  covariance_lag = "pooled_covariance_lag_summary.csv",
  path_structure = "chain_path_structure.csv",
  rhs_parameter_signal = "rhs_parameter_signal.csv",
  all_parameter_signal = "all_parameter_signal.csv",
  reconstruction = "reconstruction_audit.csv",
  cpu_assignment = "cpu_assignment_audit.csv",
  storage = "storage_audit.csv",
  lead_figure = file.path("figures", "lead_risk_profiles.pdf"),
  origin_figure = file.path("figures", "origin_risk_profiles.pdf"),
  dispersion_heatmap = file.path("figures", "origin_lead_dispersion_heatmap.pdf"),
  error_heatmap = file.path("figures", "origin_lead_error_heatmap.pdf"),
  correlation_decay_figure = file.path("figures", "origin_lead_correlation_decay.pdf")
)
decision_key <- c(
  decision = "", verification = "", verification_checks = "",
  closeout_checks = "checks", scientific_report = "report",
  diagnosis = "diagnosis", variance = "variance", covariance_lag = "covariance_lag",
  path_structure = "path_structure", rhs_parameter_signal = "parameter_signal",
  all_parameter_signal = "all_parameter_signal", reconstruction = "reconstruction",
  cpu_assignment = "cpu_assignment", storage = "storage", lead_figure = "lead_figure",
  origin_figure = "origin_figure", dispersion_heatmap = "dispersion_heatmap",
  error_heatmap = "error_heatmap",
  correlation_decay_figure = "correlation_decay_figure"
)
source_paths <- file.path(closeout_root, unname(asset_files))
if (any(!file.exists(source_paths))) {
  stop("A required closeout asset is missing.", call. = FALSE)
}

tmp_root <- tempfile(paste0(audit_id, "_"),
                     tmpdir = file.path(repo_root, "validation", "fitforecast_v2", "audits"))
dir.create(file.path(tmp_root, "figures"), recursive = TRUE, showWarnings = FALSE)
ledger_rows <- lapply(seq_along(asset_files), function(i) {
  role <- names(asset_files)[[i]]
  source <- source_paths[[i]]
  destination <- file.path(tmp_root, unname(asset_files[[i]]))
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  source_sha <- ffv2_file_sha256(source)
  key <- unname(decision_key[[role]])
  if (nzchar(key)) {
    expected <- as.character(decision$output_hashes[[key]])
    if (!identical(source_sha, expected)) {
      stop(sprintf("Decision hash mismatch for %s.", role), call. = FALSE)
    }
  }
  if (!isTRUE(file.copy(source, destination, overwrite = FALSE, copy.mode = TRUE))) {
    stop(sprintf("Could not freeze %s.", role), call. = FALSE)
  }
  destination_sha <- ffv2_file_sha256(destination)
  if (!identical(source_sha, destination_sha)) {
    stop(sprintf("Copied hash mismatch for %s.", role), call. = FALSE)
  }
  data.frame(
    role = role,
    source_relative_path = file.path("closeout", unname(asset_files[[i]])),
    portable_path = unname(asset_files[[i]]),
    sha256 = destination_sha, bytes = as.numeric(file.info(destination)$size),
    decision_hash_key = key, stringsAsFactors = FALSE
  )
})
ledger <- do.call(rbind, ledger_rows)
ledger_path <- ffv2_write_csv(ledger, file.path(tmp_root, "artifact_manifest.csv"))

readme <- c(
  "# Independent origin-horizon attribution v1 audit packet", "",
  "This compact packet freezes the completed independent Q-DESN diagnostic closeout.",
  "It is not an article promotion and contains no fitted model or posterior draw archive.", "",
  sprintf("Decision: `%s`.", decision$decision),
  sprintf("Run: `%s`.", basename(state_root)),
  "Jobs: 21/21 successful; sources: 7; retained heavy binaries: 0.",
  "All seven cells are dominated by coherent cross-origin posterior dependence.",
  "No case satisfies the predeclared tau0 causal-pilot gate.", "",
  "Use `verify_independent_origin_horizon_attribution_v1_audit.R` to verify this packet."
)
writeLines(readme, file.path(tmp_root, "README.md"))
manifest <- list(
  schema_version = imoh_v1_schema,
  audit_id = audit_id,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  source_run_id = basename(state_root),
  source_decision_sha256 = ffv2_file_sha256(decision_path),
  source_verification_sha256 = ffv2_file_sha256(verification_path),
  implementation_commit = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                                  stdout = TRUE)[[1L]],
  decision = decision$decision,
  article_update_authorized = FALSE,
  automatic_tau0_launch_authorized = FALSE,
  artifact_count = nrow(ledger),
  artifact_bytes = sum(ledger$bytes),
  artifact_manifest_sha256 = ffv2_file_sha256(ledger_path),
  readme_sha256 = ffv2_file_sha256(file.path(tmp_root, "README.md"))
)
ffv2_write_json(manifest, file.path(tmp_root, "audit_manifest.json"))
if (!isTRUE(file.rename(tmp_root, audit_root))) {
  stop("Could not atomically publish the audit packet.", call. = FALSE)
}
cat(sprintf("audit_root=%s artifacts=%d bytes=%d decision=%s\n", audit_root,
            nrow(ledger), sum(ledger$bytes), decision$decision))
