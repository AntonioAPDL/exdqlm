#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
schedule_src <- file.path(out_dir, "LOCAL_static_exal_wave8_transfer_schedule_20260403.csv")

if (!file.exists(schedule_src)) {
  stop(sprintf("wave8 schedule not found: %s", schedule_src))
}

wave8 <- utils::read.csv(schedule_src, stringsAsFactors = FALSE, check.names = FALSE)
if (!nrow(wave8)) {
  stop("wave8 schedule is empty")
}

row_map <- unique(wave8[wave8$row_id %in% c(75L, 119L),
  c("row_id", "run_root", "root_kind", "family", "tt", "tau_label"),
  drop = FALSE
])
row_map <- row_map[order(row_map$row_id), , drop = FALSE]

if (!all(c(75L, 119L) %in% row_map$row_id)) {
  stop("expected row75 and row119 metadata in wave8 schedule")
}

row75 <- row_map[row_map$row_id == 75L, , drop = FALSE]
row119 <- row_map[row_map$row_id == 119L, , drop = FALSE]

schedule <- rbind(
  data.frame(
    stage = "fail_only_bridge",
    candidate_id = "F075_sub2_s100",
    variant_tag = "failonly_F075_sub2_s100",
    row_id = 119L,
    run_root = row119$run_root,
    root_kind = row119$root_kind,
    family = row119$family,
    tt = row119$tt,
    tau_label = row119$tau_label,
    gamma_substeps = 2L,
    p_global_eta_jump = 0.075,
    global_eta_jump_scale = 1.00,
    seed = 2026043119L,
    why_included = "Bridge the repeated F075 row119 FAIL between s095 FAIL and s105 WARN",
    stringsAsFactors = FALSE
  ),
  data.frame(
    stage = "fail_only_bridge",
    candidate_id = "F080_sub2_s0975",
    variant_tag = "failonly_F080_sub2_s0975",
    row_id = 75L,
    run_root = row75$run_root,
    root_kind = row75$root_kind,
    family = row75$family,
    tt = row75$tt,
    tau_label = row75$tau_label,
    gamma_substeps = 2L,
    p_global_eta_jump = 0.080,
    global_eta_jump_scale = 0.975,
    seed = 2026043275L,
    why_included = "Bridge the F080 row75 FAIL between s095 FAIL and s100/s105 PASS",
    stringsAsFactors = FALSE
  ),
  data.frame(
    stage = "fail_only_bridge",
    candidate_id = "F080_sub2_s0975",
    variant_tag = "failonly_F080_sub2_s0975",
    row_id = 119L,
    run_root = row119$run_root,
    root_kind = row119$root_kind,
    family = row119$family,
    tt = row119$tt,
    tau_label = row119$tau_label,
    gamma_substeps = 2L,
    p_global_eta_jump = 0.080,
    global_eta_jump_scale = 0.975,
    seed = 2026043319L,
    why_included = "Ensure the F080 bridge candidate stays acceptable on the known sensitive row119",
    stringsAsFactors = FALSE
  )
)

schedule <- schedule[order(schedule$candidate_id, schedule$row_id), , drop = FALSE]

config <- unique(schedule[, c(
  "candidate_id", "variant_tag", "gamma_substeps",
  "p_global_eta_jump", "global_eta_jump_scale", "why_included"
), drop = FALSE])

schedule_path <- file.path(out_dir, "LOCAL_static_exal_fail_only_schedule_20260403.csv")
config_path <- file.path(out_dir, "LOCAL_static_exal_fail_only_config_20260403.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_fail_only_rows_20260403.tsv")

utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.csv(config, config_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "row_id", "run_root", "root_kind", "family", "tt",
    "tau_label", "variant_tag", "gamma_substeps", "p_global_eta_jump",
    "global_eta_jump_scale", "seed"
  )],
  rows_tsv,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)

cat(sprintf("config: %s\n", config_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
