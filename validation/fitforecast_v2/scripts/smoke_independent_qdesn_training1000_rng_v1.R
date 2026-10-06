args <- commandArgs(trailingOnly = TRUE); repo <- normalizePath(args[1]); out <- args[2]
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
e <- iqt12_runtime(repo, file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib"))
base_path <- paste0("/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_corrected_broad_v4_20261001/",
  "validation/fitforecast_v2/local_trackers/independent_qdesn_corrected_broad_v4_20261001_021752__git-af1b60b3bd/",
  "manifests/comparator_source_configs/exdqlm__normal__p025.json")
baseline <- iqt12_read(base_path)
source <- read.csv(baseline$series_wide_path)
w <- iqt12_window("A", 500L); w$N <- 80L; w$train <- 8421:8500
w$origins <- c(8500L, 8505L); w$horizon <- 2L; w$end <- 8507L
cfg <- list(baseline = baseline, window = w, p = .25, likelihood = "exal",
  engine = "mcmc", seed = 5151L, vb_iter = 25L, outer = 8L, burn = 20L, retained = 40L)
fit <- iqt12_baseline_fit(e, cfg, source)
stopifnot(fit$mh.diagnostics$proposal == "collapsed_slice")
warm <- iqt12_baseline_fit(e, modifyList(cfg, list(engine = "vb")), source)
vb_forecast <- iqt12_baseline_forecast(e, modifyList(cfg, list(engine = "vb")), source, warm)
stopifnot(all(is.finite(vb_forecast)))
payload <- list(sig.out = warm$sig.out, gammasig.out = warm$gammasig.out,
  vts.out = list(E.uts = warm$vts.out$E.uts), sts.out = list(E.sts = warm$sts.out$E.sts),
  theta.out = list(sm = unname(warm$theta.out$sm)))
warm_path <- file.path(dirname(out), paste0("warm_", Sys.getenv("OMP_NUM_THREADS"), ".json"))
iqt12_json(list(initial = payload), warm_path)
cfg$warm_path <- warm_path; cfg$warm_sha <- unname(tools::sha256sum(warm_path))
replay <- iqt12_baseline_fit(e, cfg, source)
add <- max(abs(fit$samp.sigma - replay$samp.sigma))
stopifnot(add <= 1e-6)
q <- iqt12_baseline_forecast(e, cfg, source, fit)
stopifnot(all(is.finite(q)))
cfg$likelihood <- "al"
cfg$warm_path <- NULL; cfg$warm_sha <- NULL
al <- iqt12_baseline_fit(e, cfg, source)
stopifnot(is.null(al$samp.gamma) || all(al$samp.gamma == 0))
stopifnot(all(is.finite(iqt12_baseline_forecast(e, cfg, source, al))))
al_vb <- iqt12_baseline_fit(e, modifyList(cfg, list(engine = "vb")), source)
stopifnot(all(is.finite(iqt12_baseline_forecast(e, modifyList(cfg, list(engine = "vb")), source, al_vb))))
iqt12_json(list(hash = digest::digest(list(fit$samp.sigma, fit$samp.gamma,
  fit$samp.theta), algo = "sha256"), proposal = fit$mh.diagnostics$proposal,
  warm_replay_error = add, finite_forecast = TRUE, AL_gamma_fixed = TRUE,
  threads = Sys.getenv("OMP_NUM_THREADS"), session = capture.output(sessionInfo())), out)
