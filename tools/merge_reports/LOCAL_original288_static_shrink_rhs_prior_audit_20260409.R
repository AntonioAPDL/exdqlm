#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

ensure_dir_rhs_audit <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

safe_share <- function(x, total) {
  ifelse(total > 0, x / total, NA_real_)
}

root_dir <- "."
selection_path <- file.path(
  root_dir,
  "tools",
  "merge_reports",
  "LOCAL_original288_carryforward_selection_v7_20260407.csv"
)
output_dir <- file.path(
  root_dir,
  "tools",
  "merge_reports",
  "original288_static_shrink_rhs_prior_audit_20260409"
)
ensure_dir_rhs_audit(output_dir)

selection <- utils::read.csv(selection_path, stringsAsFactors = FALSE)
rhs_rows <- subset(selection, block == "static_shrink" & prior_semantics == "rhs")

signature <- paste(
  rhs_rows$selected_candidate,
  rhs_rows$selected_source_subtype,
  rhs_rows$selected_variant_tag,
  rhs_rows$selected_fit_path
)

rhs_rows$evidence_bucket <- ifelse(
  grepl("rhsns", signature, ignore.case = TRUE),
  "rhsns_explicit",
  ifelse(
    grepl("rhs_legacy|legacy_rhs", signature, ignore.case = TRUE),
    "rhs_legacy_explicit",
    ifelse(
      rhs_rows$selected_source_subtype == "baseline_original",
      "baseline_ambiguous",
      "repaired_ambiguous_nonrhsns"
    )
  )
)

rhs_rows$bucket_reason <- ifelse(
  rhs_rows$evidence_bucket == "rhsns_explicit",
  "selected artifact explicitly names rhsns; keep as historical evidence only because the accepted branch label is mixed",
  ifelse(
    rhs_rows$evidence_bucket == "rhs_legacy_explicit",
    "selected artifact explicitly names legacy rhs; incompatible with rhs_ns-only governance",
    ifelse(
      rhs_rows$evidence_bucket == "baseline_ambiguous",
      "selected baseline artifact lives under validation_shrink_rhs with no explicit rhs_ns marker",
      "selected repaired artifact is not explicit rhs_ns, so it remains ambiguous under strict rhs_ns-only governance"
    )
  )
)

rhs_rows$legacy_freeze_required <- TRUE
rhs_rows$rebuild_required <- TRUE
rhs_rows$target_prior_semantics <- "rhs_ns"
rhs_rows$target_root_id <- sub("__rhs$", "__rhs_ns", rhs_rows$root_id)
rhs_rows$target_original_scenario_key <- sub("::rhs$", "::rhs_ns", rhs_rows$original_scenario_key)
rhs_rows$target_original_case_key <- sub("::rhs::", "::rhs_ns::", rhs_rows$original_case_key, fixed = TRUE)
rhs_rows$baseline_fit_exists_now <- file.exists(rhs_rows$baseline_fit_path)
rhs_rows$selected_fit_exists_now <- file.exists(rhs_rows$selected_fit_path)
rhs_rows$rebuild_scope <- "static_shrink_rhsns_full_rebuild"
rhs_rows$audit_date <- "2026-04-09"

row_audit <- rhs_rows[
  order(
    rhs_rows$inference,
    rhs_rows$model,
    rhs_rows$family,
    rhs_rows$tau,
    rhs_rows$fit_size
  ),
  c(
    "block",
    "family",
    "tau",
    "fit_size",
    "prior_semantics",
    "model",
    "inference",
    "method",
    "root_id",
    "target_root_id",
    "original_scenario_key",
    "target_original_scenario_key",
    "original_case_key",
    "target_original_case_key",
    "selected_source_type",
    "selected_source_subtype",
    "selected_candidate",
    "selected_variant_tag",
    "selected_fit_path",
    "selected_fit_exists_now",
    "baseline_fit_path",
    "baseline_fit_exists_now",
    "evidence_bucket",
    "bucket_reason",
    "legacy_freeze_required",
    "rebuild_required",
    "target_prior_semantics",
    "rebuild_scope",
    "audit_date"
  )
]

bucket_summary <- aggregate(
  count ~ evidence_bucket,
  data = transform(row_audit, count = 1L),
  FUN = sum
)
bucket_summary$share_of_72 <- bucket_summary$count / sum(bucket_summary$count)
bucket_summary <- bucket_summary[order(bucket_summary$count, decreasing = TRUE), , drop = FALSE]

bucket_by_inference <- aggregate(
  count ~ evidence_bucket + model + inference,
  data = transform(row_audit, count = 1L),
  FUN = sum
)
bucket_by_inference <- bucket_by_inference[
  order(bucket_by_inference$evidence_bucket, bucket_by_inference$inference, bucket_by_inference$model),
  ,
  drop = FALSE
]

rebuild_inventory <- row_audit[
  ,
  c(
    "rebuild_scope",
    "block",
    "family",
    "tau",
    "fit_size",
    "target_prior_semantics",
    "model",
    "inference",
    "target_root_id",
    "target_original_scenario_key",
    "target_original_case_key",
    "evidence_bucket",
    "selected_source_subtype",
    "selected_candidate",
    "selected_variant_tag",
    "legacy_freeze_required",
    "rebuild_required",
    "audit_date"
  )
]

utils::write.csv(
  row_audit,
  file.path(output_dir, "original288_static_shrink_rhs_row_audit_20260409.csv"),
  row.names = FALSE
)
utils::write.csv(
  bucket_summary,
  file.path(output_dir, "original288_static_shrink_rhs_bucket_summary_20260409.csv"),
  row.names = FALSE
)
utils::write.csv(
  bucket_by_inference,
  file.path(output_dir, "original288_static_shrink_rhs_bucket_by_inference_20260409.csv"),
  row.names = FALSE
)
utils::write.csv(
  rebuild_inventory,
  file.path(output_dir, "original288_static_shrink_rhsns_rebuild_inventory_20260409.csv"),
  row.names = FALSE
)

cat(sprintf("rhs_rows=%d\n", nrow(row_audit)))
cat(sprintf("mcmc_rows=%d\n", sum(row_audit$inference == "mcmc")))
cat(sprintf("vb_rows=%d\n", sum(row_audit$inference == "vb")))
print(bucket_summary)
