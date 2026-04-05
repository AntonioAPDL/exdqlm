#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_validation_campaign_assembly_helpers_20260405.R")

frozen_policy_path <- "tools/merge_reports/LOCAL_validation_campaign_frozen_policy_v1_20260405.csv"
selection_output_path <- "tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv"
reusable_output_path <- "tools/merge_reports/LOCAL_validation_campaign_reusable_inventory_v1_20260405.csv"
broad_default_output_path <- "tools/merge_reports/LOCAL_validation_campaign_broad_default_registry_v1_20260405.csv"
refresh_output_path <- "tools/merge_reports/LOCAL_validation_campaign_refresh_registry_v1_20260405.csv"

static_manifest <- read_static_manifests_20260405()
static_compact <- read_static_compacts_20260405()
summary_registry <- read_summary_registry_20260405()
policy <- read.csv(frozen_policy_path, stringsAsFactors = FALSE)

manifest_index <- static_manifest[, c(
  "case_key", "scope_label", "row_id", "root_kind", "family", "tau_label",
  "fit_size", "inference", "model", "prior_semantics", "run_root",
  "baseline_fit_path", "source_signoff_path"
)]

merge_static_meta <- function(x) {
  drop_cols <- intersect(
    names(x),
    c(
      "case_key", "root_kind", "family", "tau_label", "fit_size",
      "inference", "model", "prior_semantics", "run_root",
      "baseline_fit_path", "source_signoff_path"
    )
  )
  if (length(drop_cols)) {
    x <- x[, setdiff(names(x), drop_cols), drop = FALSE]
  }
  merged <- merge(
    x,
    manifest_index,
    by = c("scope_label", "row_id"),
    all.x = TRUE,
    sort = FALSE
  )
  if (anyNA(merged$case_key)) {
    stop("Static selection rows failed to join back to the canonical manifest.")
  }
  merged
}

stale_static <- subset(static_manifest, inference == "mcmc" & model == "exal")
historical_static <- subset(static_manifest, !(case_key %in% stale_static$case_key))

historical_static <- merge(
  historical_static,
  static_compact[, c(
    "scope_label", "row_id", "inference", "model", "state",
    "gate_overall", "healthy", "runtime_sec"
  )],
  by = c("scope_label", "row_id", "inference", "model"),
  all.x = TRUE,
  sort = FALSE
)

if (anyNA(historical_static$gate_overall)) {
  stop("Historical reusable static rows are missing compact-health joins.")
}

historical_static_selection <- data.frame(
  case_key = historical_static$case_key,
  workstream = "static_validation",
  scope_label = historical_static$scope_label,
  row_id = historical_static$row_id,
  root_kind = historical_static$root_kind,
  family = historical_static$family,
  tau_label = historical_static$tau_label,
  fit_size = historical_static$fit_size,
  inference = historical_static$inference,
  model = historical_static$model,
  selected_pool = "historical_reusable_static",
  selected_pool_group = "historical_reusable_artifacts",
  selected_candidate = "historical_base_fit",
  selected_variant_tag = "historical_base_fit",
  selected_fit_path = historical_static$baseline_fit_path,
  selected_health_path = historical_static$source_signoff_path,
  selected_summary_path = NA_character_,
  gate_overall = historical_static$gate_overall,
  healthy = historical_static$healthy,
  state = historical_static$state,
  runtime_sec = historical_static$runtime_sec,
  prior_semantics = historical_static$prior_semantics,
  provenance_source = historical_static$source_signoff_path,
  selection_reason = "Unchanged healthy static artifact outside the stale exal-mcmc debt.",
  stringsAsFactors = FALSE
)

current_refresh_path <- "tools/merge_reports/LOCAL_static_case_health_summary_static_exal_f080_sub2_s105_rhsns_current_20260403.csv"
legacy_refresh_path <- "tools/merge_reports/LOCAL_static_case_health_summary_static_exal_f080_sub2_s105_rhs_legacy_20260403.csv"

current_refresh <- read.csv(current_refresh_path, stringsAsFactors = FALSE)
legacy_refresh <- read.csv(legacy_refresh_path, stringsAsFactors = FALSE)
current_refresh$scope_label <- "current_rhsns_refresh"
legacy_refresh$scope_label <- "legacy_rhs_refresh"

refresh_rows <- rbind(current_refresh, legacy_refresh)
refresh_rows <- subset(refresh_rows, gate_overall != "FAIL")
refresh_rows$row_id <- as.integer(refresh_rows$queue_id)
refresh_rows <- merge_static_meta(refresh_rows)

refresh_selection <- data.frame(
  case_key = refresh_rows$case_key,
  workstream = "static_validation",
  scope_label = refresh_rows$scope_label,
  row_id = refresh_rows$row_id,
  root_kind = refresh_rows$root_kind,
  family = refresh_rows$family,
  tau_label = refresh_rows$tau_label,
  fit_size = refresh_rows$fit_size,
  inference = refresh_rows$inference,
  model = refresh_rows$model,
  selected_pool = "static_refresh_nonfail",
  selected_pool_group = "static_refresh_nonfail",
  selected_candidate = "F080_sub2_s105",
  selected_variant_tag = refresh_rows$variant_tag,
  selected_fit_path = refresh_rows$candidate_path,
  selected_health_path = refresh_rows$health_csv,
  selected_summary_path = ifelse(
    refresh_rows$scope_label == "current_rhsns_refresh",
    current_refresh_path,
    legacy_refresh_path
  ),
  gate_overall = refresh_rows$gate_overall,
  healthy = refresh_rows$healthy,
  state = "done",
  runtime_sec = suppressWarnings(as.numeric(refresh_rows$runtime_sec_cand)),
  prior_semantics = refresh_rows$prior_semantics,
  provenance_source = ifelse(
    refresh_rows$scope_label == "current_rhsns_refresh",
    current_refresh_path,
    legacy_refresh_path
  ),
  selection_reason = "Refreshed stale static exal-mcmc row became directly reusable under F080_sub2_s105.",
  stringsAsFactors = FALSE
)

failband2_files <- Sys.glob("tools/merge_reports/LOCAL_static_case_checkpoint_failband2_F085_sub2_s100_exal_*.csv")
broad_all <- parse_checkpoint_pairs_20260405(failband2_files)
broad_all$case_pair_key <- paste(broad_all$scope_label, broad_all$row_id, sep = "::")
broad_all$ts_num <- suppressWarnings(as.numeric(as.POSIXct(broad_all$ts_complete, tz = "America/New_York")))
broad_all$ts_num[is.na(broad_all$ts_num)] <- -Inf
broad_all$gate_rank <- gate_rank(broad_all$gate_overall)
broad_all <- broad_all[order(broad_all$case_pair_key, broad_all$gate_rank, -broad_all$ts_num), ]
broad_all <- broad_all[!duplicated(broad_all$case_pair_key), ]

local_static_keys <- with(
  subset(policy, rule_type == "local_override" & workstream == "static_exal"),
  paste(scope_label, row_id, sep = "::")
)

broad_rows <- subset(
  broad_all,
  !(case_pair_key %in% local_static_keys) & gate_overall != "FAIL"
)
broad_rows <- merge_static_meta(broad_rows)

broad_selection <- data.frame(
  case_key = broad_rows$case_key,
  workstream = "static_validation",
  scope_label = broad_rows$scope_label,
  row_id = broad_rows$row_id,
  root_kind = broad_rows$root_kind,
  family = broad_rows$family,
  tau_label = broad_rows$tau_label,
  fit_size = broad_rows$fit_size,
  inference = broad_rows$inference,
  model = broad_rows$model,
  selected_pool = "static_residual_broad_default",
  selected_pool_group = "static_residual_broad_default",
  selected_candidate = "F085_sub2_s100",
  selected_variant_tag = broad_rows$variant_tag,
  selected_fit_path = broad_rows$candidate_path,
  selected_health_path = broad_rows$health_csv,
  selected_summary_path = broad_rows$checkpoint_file,
  gate_overall = broad_rows$gate_overall,
  healthy = broad_rows$healthy,
  state = "done",
  runtime_sec = broad_rows$runtime_sec,
  prior_semantics = broad_rows$prior_semantics,
  provenance_source = broad_rows$checkpoint_file,
  selection_reason = "Residual-band static case kept on the broad F085_sub2_s100 default without a local override.",
  stringsAsFactors = FALSE
)

local_static_policy <- subset(policy, rule_type == "local_override" & workstream == "static_exal")
local_static_policy$row_id <- as.integer(local_static_policy$row_id)
local_static_rows <- merge_static_meta(local_static_policy)
local_static_rows$runtime_sec_local <- NA_real_
for (i in seq_len(nrow(local_static_rows))) {
  reg_match <- subset(
    summary_registry,
    file == local_static_rows$selected_summary_path[i] &
      row_id == local_static_rows$row_id[i]
  )
  if (nrow(reg_match)) {
    local_static_rows$runtime_sec_local[i] <- reg_match$runtime_sec[1]
  }
}

local_static_selection <- data.frame(
  case_key = local_static_rows$case_key,
  workstream = "static_validation",
  scope_label = local_static_rows$scope_label,
  row_id = local_static_rows$row_id,
  root_kind = local_static_rows$root_kind,
  family = local_static_rows$family,
  tau_label = local_static_rows$tau_label,
  fit_size = local_static_rows$fit_size,
  inference = local_static_rows$inference,
  model = local_static_rows$model,
  selected_pool = "static_local_override",
  selected_pool_group = "static_local_override",
  selected_candidate = local_static_rows$preferred_candidate,
  selected_variant_tag = local_static_rows$selected_variant_tag,
  selected_fit_path = local_static_rows$selected_fit_path,
  selected_health_path = local_static_rows$selected_health_path,
  selected_summary_path = local_static_rows$selected_summary_path,
  gate_overall = local_static_rows$selected_gate_overall,
  healthy = local_static_rows$selected_healthy,
  state = "done",
  runtime_sec = local_static_rows$runtime_sec_local,
  prior_semantics = local_static_rows$prior_semantics,
  provenance_source = local_static_rows$selected_summary_path,
  selection_reason = local_static_rows$evidence_note,
  stringsAsFactors = FALSE
)

dynamic_hist <- read_dynamic_fixed_rows_20260405()
dynamic_hist_selection <- data.frame(
  case_key = paste("dynamic_tail_cppgig_refresh_20260331", dynamic_hist$row_id, sep = "::"),
  workstream = "dynamic_tail_cppgig_refresh_20260331",
  scope_label = dynamic_hist$scope_label,
  row_id = dynamic_hist$row_id,
  root_kind = dynamic_hist$root_kind,
  family = dynamic_hist$family,
  tau_label = dynamic_hist$tau_label,
  fit_size = dynamic_hist$fit_size,
  inference = dynamic_hist$inference,
  model = dynamic_hist$model,
  selected_pool = "dynamic_historical_reusable",
  selected_pool_group = "historical_reusable_artifacts",
  selected_candidate = dynamic_hist$selected_variant_tag,
  selected_variant_tag = dynamic_hist$selected_variant_tag,
  selected_fit_path = dynamic_hist$selected_fit_path,
  selected_health_path = dynamic_hist$selected_health_path,
  selected_summary_path = NA_character_,
  gate_overall = dynamic_hist$gate_overall,
  healthy = dynamic_hist$healthy,
  state = dynamic_hist$state,
  runtime_sec = dynamic_hist$runtime_sec,
  prior_semantics = NA_character_,
  provenance_source = dynamic_hist$provenance_source,
  selection_reason = "Existing healthy dynamic-tail artifact reused without repair.",
  stringsAsFactors = FALSE
)

dynamic_override_policy <- subset(policy, rule_type == "local_override" & workstream == "dynamic_tail_cppgig_refresh_20260331")
dynamic_override_policy$row_id <- as.integer(dynamic_override_policy$row_id)
dynamic_registry <- subset(
  summary_registry,
  workstream == "dynamic_tail_cppgig_refresh_20260331" &
    row_id == dynamic_override_policy$row_id[1] &
    file == dynamic_override_policy$selected_summary_path[1]
)

if (nrow(dynamic_registry) != 1L) {
  stop("Dynamic row-15 promoted override did not resolve to exactly one summary row.")
}

dynamic_override_selection <- data.frame(
  case_key = paste("dynamic_tail_cppgig_refresh_20260331", dynamic_override_policy$row_id, sep = "::"),
  workstream = "dynamic_tail_cppgig_refresh_20260331",
  scope_label = "dynamic_tail_cppgig_refresh_20260331",
  row_id = dynamic_override_policy$row_id,
  root_kind = "dynamic",
  family = dynamic_registry$family,
  tau_label = dynamic_registry$tau,
  fit_size = dynamic_registry$tt,
  inference = "mcmc",
  model = dynamic_registry$model,
  selected_pool = "dynamic_local_override",
  selected_pool_group = "dynamic_local_override",
  selected_candidate = dynamic_override_policy$preferred_candidate,
  selected_variant_tag = dynamic_override_policy$selected_variant_tag,
  selected_fit_path = dynamic_override_policy$selected_fit_path,
  selected_health_path = dynamic_override_policy$selected_health_path,
  selected_summary_path = dynamic_override_policy$selected_summary_path,
  gate_overall = dynamic_override_policy$selected_gate_overall,
  healthy = dynamic_override_policy$selected_healthy,
  state = "done",
  runtime_sec = dynamic_registry$runtime_sec,
  prior_semantics = NA_character_,
  provenance_source = dynamic_override_policy$selected_summary_path,
  selection_reason = dynamic_override_policy$evidence_note,
  stringsAsFactors = FALSE
)

selection <- rbind(
  historical_static_selection,
  refresh_selection,
  broad_selection,
  local_static_selection,
  dynamic_hist_selection,
  dynamic_override_selection
)

selection <- selection[order(selection$workstream, selection$scope_label, selection$row_id, selection$inference, selection$model), ]
selection <- selection[!duplicated(selection$case_key), ]

expected_pool_counts <- c(
  historical_reusable_static = 216L,
  static_refresh_nonfail = 42L,
  static_residual_broad_default = 21L,
  static_local_override = 9L,
  dynamic_historical_reusable = 2L,
  dynamic_local_override = 1L
)

observed_pool_counts <- table(selection$selected_pool)
for (nm in names(expected_pool_counts)) {
  got <- if (nm %in% names(observed_pool_counts)) unname(observed_pool_counts[[nm]]) else 0L
  if (got != expected_pool_counts[[nm]]) {
    stop(sprintf("Pool %s expected %d rows but found %d", nm, expected_pool_counts[[nm]], got))
  }
}

if (nrow(selection) != 291L) {
  stop(sprintf("Final merged selection table must contain 291 rows, found %d", nrow(selection)))
}

write.csv(selection, selection_output_path, row.names = FALSE, na = "")
write.csv(
  subset(selection, selected_pool_group == "historical_reusable_artifacts"),
  reusable_output_path,
  row.names = FALSE,
  na = ""
)
write.csv(broad_selection, broad_default_output_path, row.names = FALSE, na = "")
write.csv(refresh_selection, refresh_output_path, row.names = FALSE, na = "")

cat(sprintf("Wrote final selection table to %s\n", selection_output_path))
cat(sprintf("Rows: %d total (%s)\n", nrow(selection), paste(names(observed_pool_counts), observed_pool_counts, sep = "=", collapse = ", ")))
