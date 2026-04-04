#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")

current_path <- file.path(out_dir, "LOCAL_static_case_health_summary_static_exal_f080_sub2_s105_rhsns_current_20260403.csv")
legacy_path <- file.path(out_dir, "LOCAL_static_case_health_summary_static_exal_f080_sub2_s105_rhs_legacy_20260403.csv")

for (path in c(current_path, legacy_path)) {
  if (!file.exists(path)) stop(sprintf("summary not found: %s", path))
}

current <- utils::read.csv(current_path, stringsAsFactors = FALSE, check.names = FALSE)
legacy <- utils::read.csv(legacy_path, stringsAsFactors = FALSE, check.names = FALSE)

current_fail <- transform(
  current[current$gate_overall == "FAIL", c("queue_id", "family_scope", "family", "tt", "tau")],
  scope = "current_rhsns"
)
legacy_fail <- transform(
  legacy[legacy$gate_overall == "FAIL", c("queue_id", "family_scope", "family", "tt", "tau")],
  scope = "legacy_rhs"
)
names(current_fail)[1] <- "row_id"
names(legacy_fail)[1] <- "row_id"

all_fail <- rbind(current_fail, legacy_fail)
all_fail <- all_fail[order(all_fail$family, all_fail$tau, all_fail$tt, all_fail$scope, all_fail$row_id), , drop = FALSE]

fail_patterns <- aggregate(scope ~ family + tau + tt, data = all_fail, FUN = length)
names(fail_patterns)[4] <- "fail_scope_cases"
fail_patterns <- fail_patterns[order(-fail_patterns$fail_scope_cases, fail_patterns$family, fail_patterns$tau, fail_patterns$tt), , drop = FALSE]

inventory_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv")
patterns_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_fail_patterns_20260403.csv")

utils::write.csv(all_fail, inventory_path, row.names = FALSE)
utils::write.csv(fail_patterns, patterns_path, row.names = FALSE)

cat(sprintf("inventory: %s\n", inventory_path))
cat(sprintf("patterns: %s\n", patterns_path))
cat(sprintf("fail_scope_cases=%d unique_patterns=%d\n", nrow(all_fail), nrow(fail_patterns)))
