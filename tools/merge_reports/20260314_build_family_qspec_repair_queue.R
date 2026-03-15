#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) normalizePath(args[[1]], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)
state_dir <- if (length(args) >= 2L) normalizePath(args[[2]], mustWork = FALSE) else "/home/jaguir26/local/state/exdqlm/family_qspec_repair_v1"

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

unhealthy_targets <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_unhealthy_targets.tsv"))
model_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_model_path_scheduler_manifest.tsv"))
post_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_postprocess_manifest.tsv"))
signoff_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_signoff_manifest.tsv"))
root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
comparison_barriers <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_comparison_barriers.tsv"))
dependency_edges <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_dependency_edges.tsv"))

events_path <- file.path(state_dir, "task_events.tsv")
locks_dir <- file.path(state_dir, "locks")
dir.create(state_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(locks_dir, recursive = TRUE, showWarnings = FALSE)

read_events <- function(path) {
  if (!file.exists(path)) {
    return(data.frame(
      task_id = character(0),
      last_event = character(0),
      last_note = character(0),
      done_count = integer(0),
      failed_count = integer(0),
      start_count = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  ev <- fq_read_tsv(path)
  if (!nrow(ev)) {
    return(data.frame(
      task_id = character(0),
      last_event = character(0),
      last_note = character(0),
      done_count = integer(0),
      failed_count = integer(0),
      start_count = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  split_ev <- split(ev, ev$task_id)
  rows <- lapply(split_ev, function(df) {
    last_idx <- nrow(df)
    data.frame(
      task_id = df$task_id[[1]],
      last_event = as.character(df$event[[last_idx]]),
      last_note = as.character(df$note[[last_idx]]),
      done_count = sum(df$event == "DONE", na.rm = TRUE),
      failed_count = sum(df$event == "FAILED", na.rm = TRUE),
      start_count = sum(df$event == "START", na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

event_status <- read_events(events_path)
lock_task_ids <- if (dir.exists(locks_dir)) basename(list.dirs(locks_dir, full.names = FALSE, recursive = FALSE)) else character(0)

scalar_chr <- function(x, default = NA_character_) {
  if (!length(x) || all(is.na(x))) {
    return(default)
  }
  val <- x[[1]]
  if (is.null(val) || !length(val) || is.na(val) || !nzchar(as.character(val))) {
    return(default)
  }
  as.character(val)
}

scalar_int <- function(x, default = NA_integer_) {
  if (!length(x) || all(is.na(x))) {
    return(default)
  }
  val <- suppressWarnings(as.integer(x[[1]]))
  if (!length(val) || is.na(val)) {
    return(default)
  }
  val
}

lookup_value <- function(df, key_col, key, value_col, default = NA_character_) {
  idx <- match(key, df[[key_col]])
  if (is.na(idx)) {
    return(default)
  }
  val <- df[[value_col]][idx]
  if (!length(val)) {
    return(default)
  }
  val[[1]]
}

ensure_unique_task_ids <- function(df, name) {
  if (!nrow(df)) {
    return(invisible(NULL))
  }
  dup <- unique(df$task_id[duplicated(df$task_id)])
  if (length(dup)) {
    stop(sprintf("Duplicate task_id values found in %s: %s", name, paste(dup, collapse = ", ")), call. = FALSE)
  }
  invisible(NULL)
}

wave_task_state <- function(task_id) {
  if (task_id %in% lock_task_ids) {
    return("running")
  }
  idx <- match(task_id, event_status$task_id)
  if (is.na(idx)) {
    return("not_started")
  }
  last_event <- event_status$last_event[[idx]]
  if (identical(last_event, "DONE")) {
    return("wave_complete")
  }
  if (identical(last_event, "FAILED")) {
    return("failed")
  }
  if (identical(last_event, "START")) {
    return("interrupted")
  }
  "not_started"
}

attempt_count <- function(task_id) {
  idx <- match(task_id, event_status$task_id)
  if (is.na(idx)) {
    return(0L)
  }
  as.integer(event_status$done_count[[idx]] + event_status$failed_count[[idx]])
}

join_unique <- function(x) {
  x <- unique(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) {
    return(NA_character_)
  }
  paste(x, collapse = "; ")
}

action_rank <- function(x) {
  ifelse(x == "fresh_vb_then_mcmc", 2L,
         ifelse(x == "rerun_mcmc_from_existing_vb", 1L, 0L))
}

task_from_target <- merge(
  unhealthy_targets,
  model_manifest[, c(
    "task_id", "root_id", "root_kind", "family", "tau", "fit_size", "prior",
    "model", "slot_cost", "pipeline_script", "run_root", "priority_band",
    "priority_reason", "root_postprocess_task_id", "root_review_task_id"
  )],
  by = c("root_id", "root_kind", "family", "tau", "fit_size", "prior", "model"),
  all.x = FALSE,
  all.y = FALSE,
  sort = FALSE
)

if (!nrow(task_from_target)) {
  stop("No model_path manifest rows matched unhealthy targets.", call. = FALSE)
}

task_from_target$run_root_manifest <- ifelse(
  !is.na(task_from_target$run_root.y) & nzchar(task_from_target$run_root.y),
  task_from_target$run_root.y,
  task_from_target$run_root.x
)

split_targets <- split(task_from_target, task_from_target$task_id)
model_plan <- do.call(rbind, lapply(split_targets, function(df) {
  strongest_rank <- max(action_rank(df$suggested_action), na.rm = TRUE)
  launch_mode <- if (strongest_rank >= 2L) "fresh_vb_then_mcmc" else "resume_mcmc_from_vb"
  base_priority <- scalar_int(df$priority_band, default = 99L)
  if (!is.finite(base_priority)) base_priority <- 99L
  priority <- if (identical(launch_mode, "fresh_vb_then_mcmc")) base_priority else 10L + base_priority
  root_id <- scalar_chr(df$root_id)
  prepared_root <- lookup_value(root_catalog, "root_id", root_id, "prepared_root", default = NA_character_)
  data.frame(
    task_id = scalar_chr(df$task_id),
    unit_type = "model_path",
    root_id = root_id,
    barrier_id = NA_character_,
    root_kind = scalar_chr(df$root_kind),
    family = scalar_chr(df$family),
    tau = scalar_chr(df$tau),
    fit_size = scalar_int(df$fit_size),
    prior = scalar_chr(df$prior),
    model = scalar_chr(df$model),
    state = wave_task_state(scalar_chr(df$task_id)),
    launch_ready = FALSE,
    launch_mode = launch_mode,
    slot_cost = scalar_int(df$slot_cost, default = 1L),
    priority = as.integer(priority),
    prepared_root = prepared_root,
    run_root = scalar_chr(df$run_root_manifest),
    script_ref = scalar_chr(df$pipeline_script),
    notes = paste(
      sprintf("repair_reasons=%s", join_unique(df$signoff_reason)),
      sprintf("targeted_inference=%s", join_unique(df$inference)),
      sprintf("attempt_count=%d", attempt_count(scalar_chr(df$task_id))),
      sep = " | "
    ),
    stringsAsFactors = FALSE
  )
}))
rownames(model_plan) <- NULL
ensure_unique_task_ids(model_plan, "model_plan")
model_plan$launch_ready <- model_plan$state %in% c("not_started", "failed", "interrupted")

model_target_ids <- model_plan$task_id
impacted_root_ids <- unique(model_plan$root_id)

dependency_ready <- function(parent_task_id, targeted_child_ids) {
  child_ids <- dependency_edges$child_task_id[dependency_edges$parent_task_id == parent_task_id]
  if (!length(child_ids)) {
    return(TRUE)
  }
  targeted <- child_ids[child_ids %in% targeted_child_ids]
  if (!length(targeted)) {
    return(TRUE)
  }
  all(vapply(targeted, function(id) identical(wave_task_state(id), "wave_complete"), logical(1)))
}

build_wave_rows <- function(task_ids, unit_type, launch_mode, priority, manifest_lookup, prepared_lookup = NULL, run_lookup = NULL, script_lookup = NULL, dependency_task_ids = character(0), note_prefix = "repair_required") {
  rows <- lapply(task_ids, function(task_id) {
    state <- wave_task_state(task_id)
    launch_ready <- state %in% c("not_started", "failed", "interrupted") && dependency_ready(task_id, dependency_task_ids)
    root_id <- scalar_chr(lookup_value(manifest_lookup, "task_id", task_id, "root_id", default = NA_character_))
    root_kind <- scalar_chr(lookup_value(manifest_lookup, "task_id", task_id, "root_kind", default = NA_character_))
    family <- scalar_chr(lookup_value(manifest_lookup, "task_id", task_id, "family", default = NA_character_))
    tau <- scalar_chr(lookup_value(manifest_lookup, "task_id", task_id, "tau", default = NA_character_))
    fit_size <- scalar_int(list(lookup_value(manifest_lookup, "task_id", task_id, "fit_size", default = NA_integer_)))
    prior <- scalar_chr(lookup_value(manifest_lookup, "task_id", task_id, "prior", default = NA_character_))
    data.frame(
      task_id = task_id,
      unit_type = unit_type,
      root_id = root_id,
      barrier_id = if (unit_type %in% c("prior_compare", "campaign_review", "global_summary")) task_id else NA_character_,
      root_kind = root_kind,
      family = family,
      tau = tau,
      fit_size = fit_size,
      prior = prior,
      model = NA_character_,
      state = state,
      launch_ready = launch_ready,
      launch_mode = launch_mode,
      slot_cost = 1L,
      priority = as.integer(priority),
      prepared_root = if (is.null(prepared_lookup)) NA_character_ else scalar_chr(prepared_lookup[[task_id]]),
      run_root = if (is.null(run_lookup)) NA_character_ else scalar_chr(run_lookup[[task_id]]),
      script_ref = if (is.null(script_lookup)) NA_character_ else scalar_chr(script_lookup[[task_id]]),
      notes = paste(
        note_prefix,
        sprintf("attempt_count=%d", attempt_count(task_id)),
        sep = " | "
      ),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  ensure_unique_task_ids(out, unit_type)
  out
}

post_lookup <- merge(post_manifest, root_catalog[, c("root_id", "prepared_root", "run_root")], by = "root_id", all.x = TRUE, sort = FALSE)
post_targets <- post_lookup[post_lookup$root_id %in% impacted_root_ids, , drop = FALSE]
post_prepared <- setNames(post_targets$prepared_root, post_targets$task_id)
post_run <- setNames(post_targets$run_root, post_targets$task_id)
post_script <- setNames(post_targets$postprocess_script, post_targets$task_id)
post_plan <- build_wave_rows(
  task_ids = post_targets$task_id,
  unit_type = "root_postprocess",
  launch_mode = "rerun_root_postprocess",
  priority = 30L,
  manifest_lookup = transform(post_targets, prior = as.character(prior)),
  prepared_lookup = post_prepared,
  run_lookup = post_run,
  script_lookup = post_script,
  dependency_task_ids = model_target_ids,
  note_prefix = "upstream_model_repair"
)

signoff_lookup <- merge(signoff_manifest, root_catalog[, c("root_id", "prepared_root", "run_root")], by = "root_id", all.x = TRUE, sort = FALSE)
signoff_targets <- signoff_lookup[signoff_lookup$root_id %in% impacted_root_ids, , drop = FALSE]
signoff_prepared <- setNames(signoff_targets$prepared_root, signoff_targets$task_id)
signoff_run <- setNames(signoff_targets$run_root, signoff_targets$task_id)
signoff_script <- setNames(signoff_targets$signoff_script, signoff_targets$task_id)
signoff_plan <- build_wave_rows(
  task_ids = signoff_targets$task_id,
  unit_type = "root_signoff",
  launch_mode = "rerun_root_signoff",
  priority = 31L,
  manifest_lookup = transform(signoff_targets, prior = as.character(prior)),
  prepared_lookup = signoff_prepared,
  run_lookup = signoff_run,
  script_lookup = signoff_script,
  dependency_task_ids = post_plan$task_id,
  note_prefix = "upstream_postprocess_repair"
)

review_lookup <- root_catalog[, c("review_task_id", "root_id", "root_kind", "family", "tau", "fit_size", "prior", "prepared_root", "run_root"), drop = FALSE]
names(review_lookup)[names(review_lookup) == "review_task_id"] <- "task_id"
review_targets <- review_lookup[review_lookup$root_id %in% impacted_root_ids, , drop = FALSE]
review_prepared <- setNames(review_targets$prepared_root, review_targets$task_id)
review_run <- setNames(review_targets$run_root, review_targets$task_id)
review_script <- setNames(ifelse(
  review_targets$root_kind == "dynamic",
  "tools/merge_reports/20260314_dynamic_vb_mcmc_report.R",
  "tools/merge_reports/20260305_static_vb_mcmc_report.R"
), review_targets$task_id)
review_plan <- build_wave_rows(
  task_ids = review_targets$task_id,
  unit_type = "root_review",
  launch_mode = "rerun_root_review",
  priority = 32L,
  manifest_lookup = review_targets,
  prepared_lookup = review_prepared,
  run_lookup = review_run,
  script_lookup = review_script,
  dependency_task_ids = signoff_plan$task_id,
  note_prefix = "upstream_signoff_repair"
)

prior_lookup <- comparison_barriers[comparison_barriers$barrier_type == "prior_compare", , drop = FALSE]
prior_target_ids <- unique(dependency_edges$parent_task_id[
  dependency_edges$parent_task_type == "prior_compare" &
    dependency_edges$child_task_id %in% review_plan$task_id
])
prior_targets <- prior_lookup[prior_lookup$barrier_id %in% prior_target_ids, , drop = FALSE]
prior_manifest <- data.frame(
  task_id = prior_targets$barrier_id,
  root_id = NA_character_,
  root_kind = prior_targets$root_kind,
  family = prior_targets$family,
  tau = prior_targets$tau,
  fit_size = prior_targets$fit_size,
  prior = "ridge_vs_rhs",
  prepared_root = prior_targets$prepared_root,
  run_root = prior_targets$compare_root,
  implementation_script = prior_targets$implementation_script,
  stringsAsFactors = FALSE
)
prior_prepared <- setNames(prior_manifest$prepared_root, prior_manifest$task_id)
prior_run <- setNames(prior_manifest$run_root, prior_manifest$task_id)
prior_script <- setNames(prior_manifest$implementation_script, prior_manifest$task_id)
prior_plan <- build_wave_rows(
  task_ids = prior_manifest$task_id,
  unit_type = "prior_compare",
  launch_mode = "rerun_prior_compare",
  priority = 40L,
  manifest_lookup = prior_manifest,
  prepared_lookup = prior_prepared,
  run_lookup = prior_run,
  script_lookup = prior_script,
  dependency_task_ids = review_plan$task_id,
  note_prefix = "upstream_root_review_repair"
)

campaign_lookup <- comparison_barriers[comparison_barriers$barrier_type == "campaign_review", , drop = FALSE]
campaign_target_ids <- unique(dependency_edges$parent_task_id[
  dependency_edges$parent_task_type == "campaign_review" &
    (dependency_edges$child_task_id %in% review_plan$task_id | dependency_edges$child_task_id %in% prior_plan$task_id)
])
campaign_targets <- campaign_lookup[campaign_lookup$barrier_id %in% campaign_target_ids, , drop = FALSE]
campaign_manifest <- data.frame(
  task_id = campaign_targets$barrier_id,
  root_id = NA_character_,
  root_kind = campaign_targets$root_kind,
  family = campaign_targets$family,
  tau = campaign_targets$tau,
  fit_size = campaign_targets$fit_size,
  prior = NA_character_,
  prepared_root = NA_character_,
  run_root = vapply(campaign_targets$barrier_id, fq_barrier_output_root, character(1), repo_root = repo_root),
  implementation_script = campaign_targets$implementation_script,
  stringsAsFactors = FALSE
)
campaign_run <- setNames(campaign_manifest$run_root, campaign_manifest$task_id)
campaign_script <- setNames(campaign_manifest$implementation_script, campaign_manifest$task_id)
campaign_plan <- build_wave_rows(
  task_ids = campaign_manifest$task_id,
  unit_type = "campaign_review",
  launch_mode = "rerun_campaign_review",
  priority = 50L,
  manifest_lookup = campaign_manifest,
  run_lookup = campaign_run,
  script_lookup = campaign_script,
  dependency_task_ids = c(review_plan$task_id, prior_plan$task_id),
  note_prefix = "upstream_review_compare_repair"
)

global_lookup <- comparison_barriers[comparison_barriers$barrier_type == "global_summary", , drop = FALSE]
global_target_ids <- unique(dependency_edges$parent_task_id[
  dependency_edges$parent_task_type == "global_summary" &
    dependency_edges$child_task_id %in% campaign_plan$task_id
])
global_targets <- global_lookup[global_lookup$barrier_id %in% global_target_ids, , drop = FALSE]
global_manifest <- data.frame(
  task_id = global_targets$barrier_id,
  root_id = NA_character_,
  root_kind = global_targets$root_kind,
  family = global_targets$family,
  tau = global_targets$tau,
  fit_size = global_targets$fit_size,
  prior = NA_character_,
  prepared_root = NA_character_,
  run_root = vapply(global_targets$barrier_id, fq_barrier_output_root, character(1), repo_root = repo_root),
  implementation_script = global_targets$implementation_script,
  stringsAsFactors = FALSE
)
global_run <- setNames(global_manifest$run_root, global_manifest$task_id)
global_script <- setNames(global_manifest$implementation_script, global_manifest$task_id)
global_plan <- build_wave_rows(
  task_ids = global_manifest$task_id,
  unit_type = "global_summary",
  launch_mode = "rerun_global_summary",
  priority = 60L,
  manifest_lookup = global_manifest,
  run_lookup = global_run,
  script_lookup = global_script,
  dependency_task_ids = campaign_plan$task_id,
  note_prefix = "upstream_campaign_repair"
)

queue <- rbind(
  model_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")],
  post_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")],
  signoff_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")],
  review_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")],
  prior_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")],
  campaign_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")],
  global_plan[, c("task_id", "unit_type", "root_id", "barrier_id", "root_kind", "family", "tau", "fit_size", "prior", "model", "state", "launch_ready", "launch_mode", "slot_cost", "priority", "prepared_root", "run_root", "script_ref", "notes")]
)

queue <- queue[order(-as.integer(queue$launch_ready), queue$priority, queue$unit_type, queue$root_kind, queue$family, queue$tau, queue$fit_size, queue$prior, queue$model), , drop = FALSE]
rownames(queue) <- NULL

ensure_unique_task_ids(queue, "repair_queue")

summary_df <- as.data.frame(table(
  unit_type = queue$unit_type,
  state = queue$state,
  launch_ready = queue$launch_ready
), stringsAsFactors = FALSE)
names(summary_df)[names(summary_df) == "Freq"] <- "count"
summary_df <- summary_df[summary_df$count > 0, , drop = FALSE]
summary_df <- summary_df[order(summary_df$unit_type, summary_df$state, summary_df$launch_ready), , drop = FALSE]

repair_plan_summary <- data.frame(
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  unhealthy_method_rows = nrow(unhealthy_targets),
  targeted_model_path_tasks = nrow(model_plan),
  impacted_root_count = length(impacted_root_ids),
  targeted_root_postprocess_tasks = nrow(post_plan),
  targeted_root_signoff_tasks = nrow(signoff_plan),
  targeted_root_review_tasks = nrow(review_plan),
  targeted_prior_compare_tasks = nrow(prior_plan),
  targeted_campaign_review_tasks = nrow(campaign_plan),
  targeted_global_summary_tasks = nrow(global_plan),
  launch_ready_now = sum(queue$launch_ready, na.rm = TRUE),
  stringsAsFactors = FALSE
)

out_dir <- file.path(state_dir, "queue")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
queue_path <- file.path(out_dir, "20260314_family_qspec_repair_queue.tsv")
queue_summary_path <- file.path(out_dir, "20260314_family_qspec_repair_queue_summary.tsv")
plan_summary_path <- file.path(out_dir, "20260314_family_qspec_repair_plan_summary.tsv")
fq_write_tsv(queue, queue_path)
fq_write_tsv(summary_df, queue_summary_path)
fq_write_tsv(repair_plan_summary, plan_summary_path)

cat("Wrote:\n")
cat(queue_path, "\n")
cat(queue_summary_path, "\n")
cat(plan_summary_path, "\n")
