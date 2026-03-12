#!/usr/bin/env Rscript

root <- "."
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run from the exdqlm repository root.")
}

tau_to_tag <- function(x) gsub("\\.", "p", sprintf("%.2f", as.numeric(x)))
fmt_tau <- function(x) sprintf("%.2f", as.numeric(x))

families <- c("normal", "laplace", "gausmix")
taus <- c("0.05", "0.25", "0.50")
static_tts <- c(100L, 1000L)
dynamic_tts <- c(500L, 5000L)
priors <- c("ridge", "rhs")

make_key <- function(kind, family, tau, tt, prior = "") {
  sprintf("%s|%s|%s|%s|%s", kind, family, fmt_tau(tau), as.integer(tt), prior)
}

build_grid <- function() {
  rows <- list()

  for (fam in families) {
    for (tau in taus) {
      for (tt in static_tts) {
        tau_tag <- tau_to_tag(tau)
        prep <- file.path(
          "results/function_testing_20260309_static_paper_family_qspec",
          fam,
          paste0("tau_", tau_tag),
          sprintf("fit_input_subsample_tt%d_x01_sorted", tt)
        )
        run <- file.path(prep, sprintf("validation_paper_tt%d", tt))
        rows[[length(rows) + 1L]] <- data.frame(
          key = make_key("static_paper", fam, tau, tt, ""),
          kind = "static_paper",
          family = fam,
          tau = fmt_tau(tau),
          tt = tt,
          prior = "none",
          prepared_root = prep,
          run_root = run,
          batch_label = sprintf("static_paper_tt%d", tt),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  for (fam in families) {
    for (tau in taus) {
      for (tt in static_tts) {
        for (prior in priors) {
          tau_tag <- tau_to_tag(tau)
          prep <- file.path(
            "results/function_testing_20260309_static_shrinkage_family_qspec",
            fam,
            paste0("tau_", tau_tag),
            sprintf("fit_input_subsample_tt%d_x01_sorted", tt)
          )
          run <- file.path(prep, sprintf("validation_shrink_%s_tt%d", prior, tt))
          rows[[length(rows) + 1L]] <- data.frame(
            key = make_key("static_shrink", fam, tau, tt, prior),
            kind = "static_shrink",
            family = fam,
            tau = fmt_tau(tau),
            tt = tt,
            prior = prior,
            prepared_root = prep,
            run_root = run,
            batch_label = sprintf("static_shrink_%s_tt%d", prior, tt),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  for (fam in families) {
    for (tau in taus) {
      for (tt in dynamic_tts) {
        tau_tag <- tau_to_tag(tau)
        prep <- file.path(
          "results/function_testing_20260309_dynamic_dlm_family_qspec",
          "dlm_constV_smallW",
          fam,
          paste0("tau_", tau_tag),
          sprintf("fit_input_lastTT%d", tt)
        )
        run <- file.path(prep, sprintf("validation_dynamic_tt%d", tt))
        rows[[length(rows) + 1L]] <- data.frame(
          key = make_key("dynamic", fam, tau, tt, ""),
          kind = "dynamic",
          family = fam,
          tau = fmt_tau(tau),
          tt = tt,
          prior = "none",
          prepared_root = prep,
          run_root = run,
          batch_label = sprintf("dynamic_tt%d", tt),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  out <- do.call(rbind, rows)
  if (nrow(out) != 72L) {
    stop("Expected 72 roots, got ", nrow(out))
  }
  out
}

read_lines_maybe <- function(path) {
  if (!file.exists(path)) {
    return(character())
  }
  readLines(path, warn = FALSE)
}

read_current_key <- function(log_path) {
  lines <- read_lines_maybe(log_path)
  if (!length(lines)) {
    return("")
  }
  active <- character()
  for (line in lines) {
    if (grepl("^CASE start key=", line)) {
      key <- sub("^CASE start key=([^ ]+).*$", "\\1", line)
      active <- c(active, key)
    } else if (grepl("^CASE done key=", line)) {
      key <- sub("^CASE done key=([^ ]+).*$", "\\1", line)
      idx <- match(key, active)
      if (!is.na(idx)) {
        active <- active[-idx]
      }
    }
  }
  if (!length(active)) {
    return("")
  }
  active[[length(active)]]
}

read_done_keys <- function(batch_tsv) {
  if (!file.exists(batch_tsv)) {
    return(character())
  }
  dat <- tryCatch(
    read.delim(batch_tsv, sep = "\t", stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(dat) || !nrow(dat) || !("key" %in% names(dat))) {
    return(character())
  }
  unique(dat$key)
}

read_run_root_from_resume_log <- function(log_path) {
  lines <- read_lines_maybe(log_path)
  if (!length(lines)) {
    return("")
  }
  hit <- grep("run_root=", lines, value = TRUE)
  if (!length(hit)) {
    return("")
  }
  sub("^.*run_root=([^ ]+).*$", "\\1", hit[[1]])
}

is_complete_muscat <- function(kind, run_root, tau, prior = "") {
  tau_tag <- tau_to_tag(tau)
  if (kind %in% c("static_paper", "static_shrink")) {
    vb_al <- file.path(run_root, "fits", "vb", sprintf("vb_al_tau_%s_fit.rds", tau_tag))
    vb_ex <- file.path(run_root, "fits", "vb", sprintf("vb_exal_tau_%s_fit.rds", tau_tag))
    mc_al <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_al_tau_%s_fit.rds", tau_tag))
    mc_ex <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit.rds", tau_tag))
    metrics <- file.path(run_root, "tables", "metrics_summary.csv")
    return(all(file.exists(c(vb_al, vb_ex, mc_al, mc_ex, metrics))))
  }
  vb_d <- file.path(run_root, "fits", "vb", sprintf("vb_dqlm_tau_%s_fit.rds", tau_tag))
  vb_x <- file.path(run_root, "fits", "vb", sprintf("vb_exdqlm_tau_%s_fit.rds", tau_tag))
  mc_d <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_dqlm_tau_%s_fit.rds", tau_tag))
  mc_x <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_exdqlm_tau_%s_fit.rds", tau_tag))
  metrics <- file.path(run_root, "tables", "metrics_summary.csv")
  all(file.exists(c(vb_d, vb_x, mc_d, mc_x, metrics)))
}

status <- build_grid()

jerez_complete <- c(
  make_key("static_paper", "gausmix", "0.05", 100, ""),
  make_key("static_paper", "gausmix", "0.05", 1000, ""),
  make_key("static_shrink", "gausmix", "0.05", 100, "ridge"),
  make_key("static_shrink", "gausmix", "0.05", 1000, "ridge"),
  make_key("static_shrink", "gausmix", "0.05", 100, "rhs"),
  make_key("static_shrink", "gausmix", "0.05", 1000, "rhs"),
  make_key("dynamic", "gausmix", "0.05", 500, ""),
  make_key("dynamic", "gausmix", "0.25", 500, ""),
  make_key("dynamic", "gausmix", "0.50", 500, "")
)

rehome_tsv <- file.path("tools", "merge_reports", "20260312_jerez_gausmix_partial_roots_to_muscat.tsv")
if (!file.exists(rehome_tsv)) {
  stop("Missing rehome manifest: ", rehome_tsv)
}
rehome <- read.delim(rehome_tsv, sep = "\t", stringsAsFactors = FALSE)
rehome$key <- mapply(
  make_key,
  rehome$kind,
  rehome$family,
  rehome$tau,
  rehome$tt,
  ifelse(rehome$prior == "none", "", rehome$prior),
  USE.NAMES = FALSE
)

status$legacy_jerez_state <- "not_launched_on_jerez"
status$legacy_jerez_state[status$key %in% jerez_complete] <- "complete_on_jerez"
status$legacy_jerez_state[status$key %in% rehome$key] <- "running_on_jerez_before_rehome"
status$legacy_jerez_session <- ""

complete_session_map <- c(
  "static_paper|gausmix|0.05|100|" = "",
  "static_paper|gausmix|0.05|1000|" = "",
  "static_shrink|gausmix|0.05|100|ridge" = "",
  "static_shrink|gausmix|0.05|1000|ridge" = "",
  "static_shrink|gausmix|0.05|100|rhs" = "",
  "static_shrink|gausmix|0.05|1000|rhs" = "",
  "dynamic|gausmix|0.05|500|" = "",
  "dynamic|gausmix|0.25|500|" = "",
  "dynamic|gausmix|0.50|500|" = ""
)
running_session_map <- setNames(rehome$session, rehome$key)
all_session_map <- c(complete_session_map, running_session_map)
idx <- match(status$key, names(all_session_map), nomatch = 0L)
status$legacy_jerez_session[idx > 0] <- unname(all_session_map[idx])

status$rehomed_from_jerez <- status$key %in% rehome$key
status$rehomed_from_jerez_session <- ""
rehome_idx <- match(status$key, rehome$key, nomatch = 0L)
status$rehomed_from_jerez_session[rehome_idx > 0] <- rehome$session[rehome_idx[rehome_idx > 0]]

status$prepared_exists <- dir.exists(status$prepared_root)
status$run_root_exists <- dir.exists(status$run_root)
status$run_config_exists <- file.exists(file.path(status$run_root, "tables", "run_config.rds"))
status$muscat_complete <- mapply(
  is_complete_muscat,
  status$kind,
  status$run_root,
  status$tau,
  status$prior,
  USE.NAMES = FALSE
)

status$wave_assigned <- !(status$key %in% c(jerez_complete, rehome$key))
status$wave_batch_done <- FALSE
status$wave_batch_current <- FALSE
status$wave_batch_session <- ""
status$rehomed_muscat_session <- ""
status$current_session <- ""
status$current_stage <- ""

tmux_sessions <- tryCatch(
  suppressWarnings(system("tmux list-sessions -F '#S' 2>/dev/null", intern = TRUE)),
  error = function(e) character()
)

wave_sessions <- grep("^mqsp_(?!jr_)", tmux_sessions, perl = TRUE, value = TRUE)
for (sess in wave_sessions) {
  batch <- sub("^mqsp_(.*)_[0-9]{8}_[0-9]{6}$", "\\1", sess, perl = TRUE)
  stamp <- sub("^mqsp_.*_([0-9]{8}_[0-9]{6})$", "\\1", sess, perl = TRUE)
  log_path <- file.path("tools", "merge_reports", sprintf("20260312_muscat_%s_%s.log", batch, stamp))
  batch_tsv <- file.path("tools", "merge_reports", sprintf("20260312_muscat_batch_%s_%s.tsv", batch, stamp))

  done_keys <- read_done_keys(batch_tsv)
  if (length(done_keys)) {
    status$wave_batch_done[status$key %in% done_keys] <- TRUE
  }

  current_key <- read_current_key(log_path)
  if (nzchar(current_key)) {
    idx <- which(status$key == current_key)
    if (length(idx) == 1L) {
      status$wave_batch_current[idx] <- TRUE
      status$wave_batch_session[idx] <- sess
      status$current_session[idx] <- sess
      status$current_stage[idx] <- "active_on_muscat_backlog_wave"
    }
  }
}

rehomed_sessions <- grep("^mqsp_jr_", tmux_sessions, perl = TRUE, value = TRUE)
for (sess in rehomed_sessions) {
  log_path <- file.path("tools", "merge_reports", sprintf("%s.log", sess))
  run_root <- read_run_root_from_resume_log(log_path)
  if (!nzchar(run_root)) {
    next
  }
  idx <- which(status$run_root == run_root)
  if (length(idx) != 1L) {
    next
  }
  status$rehomed_muscat_session[idx] <- sess
  status$current_session[idx] <- sess
  status$current_stage[idx] <- "active_on_muscat_rehomed_resume"
}

status$current_unified_state <- "unknown"
status$current_unified_state[status$key %in% jerez_complete] <- "complete_on_jerez_pending_sync"
status$current_unified_state[status$current_unified_state == "unknown" & status$muscat_complete] <- "complete_on_muscat"
status$current_unified_state[status$current_unified_state == "unknown" & nzchar(status$rehomed_muscat_session)] <- "active_on_muscat_rehomed_resume"
status$current_unified_state[status$current_unified_state == "unknown" & status$wave_batch_current] <- "active_on_muscat_backlog_wave"
status$current_unified_state[status$current_unified_state == "unknown" & status$wave_assigned] <- "queued_on_muscat"
status$current_unified_state[status$current_unified_state == "unknown" & status$rehomed_from_jerez] <- "rehomed_on_muscat_partial"

status$sync_pending_from_jerez <- status$current_unified_state == "complete_on_jerez_pending_sync"

status$current_stage[status$current_unified_state == "complete_on_jerez_pending_sync"] <- "complete_on_jerez_pending_exact_sync"
status$current_stage[status$current_unified_state == "complete_on_muscat"] <- "complete_on_muscat"
status$current_stage[status$current_unified_state == "queued_on_muscat"] <- "queued_on_muscat_backlog_wave"
status$current_stage[status$current_unified_state == "rehomed_on_muscat_partial"] <- "rehomed_on_muscat_partial"

status <- status[order(status$kind, status$family, status$tau, status$tt, status$prior), ]

out_dir <- file.path("tools", "merge_reports")
unified_tsv <- file.path(out_dir, "20260312_family_qspec_unified_root_status.tsv")
write.table(status, file = unified_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

cat("Wrote:\n")
cat(" - ", unified_tsv, "\n", sep = "")
cat("\nCurrent unified counts:\n")
print(table(status$current_unified_state))
