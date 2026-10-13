repo <- normalizePath(Sys.getenv("IRM13_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R", "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R", "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R", "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R", "independent_qdesn_fresh_dgp_v11.R",
    "independent_qdesn_dynamic_location_v12.R", "independent_qdesn_readout_memory_v13.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))
count <- 0L
assert <- function(condition, label) {
  stopifnot(isTRUE(condition)); count <<- count + 1L; cat("PASS:", label, "\n")
}
parent <- paste0("/data/jaguir26/local/src/Article-Q-DESN/.worktrees/",
  "ind_qdesn_dynamic_location_v12_20261013/validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_dynamic_location_v12_20261013__recovered")
state <- iqt12_read(file.path(parent, "campaign.json"))
tmp <- tempfile("irm13_tests_"); dir.create(tmp)
state$run <- tmp; state$repo <- repo; state$parent <- parent; state$arms <- irm13_arms
state$schema <- irm13_schema
state$expected_jobs <- list(smoke = 2L, selection_warm = 20L, selection = 20L,
  confirmation_warm = 6L, confirmation = 18L, fresh_warm = 12L, fresh = 36L)
assert(sum(unlist(state$expected_jobs)[1:3]) == 42L &&
  sum(unlist(state$expected_jobs)[4:7]) == 72L, "logical job budgets 42 plus conditional 72")
configs <- lapply(c("static", irm13_arms), function(arm)
  irm13_config(state, arm, "F1", "A", "smoke"))
names(configs) <- c("static", irm13_arms)
ref <- configs$static
for (arm in irm13_arms) {
  cfg <- configs[[arm]]
  assert(cfg$omega_scaled == 0 && cfg$likelihood == "al" && cfg$model == "qdesn",
    paste("static AL dispatch", arm))
  assert(cfg$candidate$n == "141;119;90" && cfg$candidate$m == 360L &&
    cfg$layer2_scale == .25, paste("architecture and layer scaling retained", arm))
  assert(identical(cfg$spec_signature, irm13_signature(cfg)) &&
    is.null(cfg$candidate$structure_signature) && is.null(cfg$candidate$rhs_tau0),
    paste("identity from executed fields not stale textual labels", arm))
}
assert(configs$tau_half$candidate$tau_source == ref$candidate$tau_source*.5 &&
  configs$tau_half$candidate$slab_source == ref$candidate$slab_source,
  "tau-only changes global prior scale")
assert(configs$slab_quarter$candidate$slab_source == ref$candidate$slab_source*.25 &&
  configs$slab_quarter$candidate$tau_source == ref$candidate$tau_source,
  "slab-only changes variance prior scale")
assert(configs$joint_shrink$candidate$tau_source == ref$candidate$tau_source*.5 &&
  configs$joint_shrink$candidate$slab_source == ref$candidate$slab_source*.25,
  "joint prior contrast")
for (arm in c("memory040", "memory099")) {
  cfg <- configs[[arm]]; radius <- 1-cfg$candidate$alpha+cfg$candidate$alpha*cfg$candidate$rho
  assert(abs(log(.5)/log(radius)-80) < 1e-9 &&
    cfg$candidate$tau_source == ref$candidate$tau_source &&
    cfg$candidate$slab_source == ref$candidate$slab_source, paste("reference memory target only", arm))
}
for (fold in c("A", "B", "C", "FINAL")) {
  w <- idl12_window(fold)
  assert(length(w$washout) == 500L && nrow(iqt12_grid(w)) ==
    if (fold == "FINAL") 1000L else 240L, paste("unmodified causal grid", fold))
}
old <- iqt12_read(file.path(parent, "configs/selection__F1__A__static__c1.json"))
changed <- old; changed$candidate$structure_signature <- "deliberately_stale"
changed$candidate$structure_id <- "different_obsolete_label"
assert(identical(irm13_signature(old, TRUE), irm13_signature(changed, TRUE)),
  "labels never define scientific reuse")
changed$source_sha <- "not_same_data"
assert(irm13_signature(old, TRUE) != irm13_signature(changed, TRUE), "reuse checks source hash")
changed <- old; changed$seed <- old$seed+1L
assert(irm13_signature(old, TRUE) != irm13_signature(changed, TRUE), "reuse checks chain seed")
changed <- old; changed$inner <- 256L
assert(irm13_signature(old, TRUE) != irm13_signature(changed, TRUE), "reuse checks forecast budget")
base <- iqt12_read(file.path(parent, "configs/selection__F1__A__dqlm__c1.json"))
changed <- base; changed$baseline$TT_warmup <- changed$baseline$TT_warmup+1L
assert(irm13_signature(base, TRUE) != irm13_signature(changed, TRUE), "reuse checks baseline latent clock warmup")
changed <- base; changed$baseline$level0 <- changed$baseline$level0+1
assert(irm13_signature(base, TRUE) != irm13_signature(changed, TRUE), "reuse checks baseline initial location")
controls <- irm13_import_controls(state)
assert(nrow(controls) == 8L && all(controls$status == "SUCCESS"), "eight hash-audited matched controls reused")
bad <- state; bad$sources$F1$sha256 <- "bad_data_hash"
assert(inherits(try(irm13_import_controls(bad), silent = TRUE), "try-error"),
  "control reuse rejects different data")

e <- ifd11_runtime(repo, state$library)
assert(as.character(packageVersion("exdqlm")) == "1.1.2" &&
  packageDescription("exdqlm")$Repository == "CRAN", "pinned CRAN 1.1.2")
source <- read.csv(state$sources$F1$path)
cx <- ilr10_design_hook(e, ref, source, ref$window$end)
priors <- lapply(configs, function(cfg) iqt12_prior(e, cfg, cx$scale))
assert(priors$tau_half$rhs$tau0 == priors$static$rhs$tau0*.5 &&
  priors$slab_quarter$rhs$b_zeta == priors$static$rhs$b_zeta*.25,
  "scaled executed prior matches source-unit multipliers")
assert(all(vapply(priors, function(z) !z$rhs$shrink_intercept && z$rhs$a_zeta == 2 &&
  z$rhs$intercept_prec == 1e-16*cx$scale^2 &&
  identical(z$sigma, priors$static$sigma), TRUE)), "intercept and sigma priors unchanged")
altered <- source; altered$q_target <- -9999; altered$y[8001:10000] <- 9999
cy <- ilr10_design_hook(e, ref, altered, ref$window$end)
assert(identical(cx$object$X, cy$object$X) && identical(cx$object$y_fit, cy$object$y_fit),
  "design never fits oracle or future outcomes")
assert(all(cx$object$reservoir$Q_is_identity) && ncol(cx$object$X) == 351L,
  "identity layer transitions full states no raw inputs")
cm <- ilr10_design_hook(e, configs$memory099, source, configs$memory099$window$end)
assert(cm$design_hash != cx$design_hash && cm$initialization_dependence < cx$initialization_dependence,
  "memory contrast changes actual design and measured initialization dependence")
assert(identical(cm$object$reservoir$Win, cx$object$reservoir$Win),
  "memory contrast keeps actual input and interlayer weights fixed")
ratio <- configs$memory099$candidate$rho/ref$candidate$rho
assert(max(vapply(seq_len(3), function(d) max(abs(cm$object$reservoir$W[[d]] -
  ratio*cx$object$reservoir$W[[d]])), 0)) < 1e-10,
  "memory contrast preserves recurrent topology and only rescales W")
actual <- irm13_memory_diagnostics(cm)
assert(nrow(actual) == 3L && all(is.finite(actual$linear_reference_radius)) &&
  !any(actual$nonlinear_forgetting_bound), "actual eigenvalues recorded without nonlinear theorem claim")
draws <- list(beta = matrix(0, 4, ncol(cx$object$X)), sigma = rep(.03, 4), gamma = rep(0, 4))
draws$beta[, 1] <- mean(cx$object$y_fit)
tiny <- ref; tiny$outer <- 4L; tiny$inner <- 4L
fa <- ilr10_qforecast_hook(e, cx, tiny, NULL, draws)
fb <- ilr10_qforecast_hook(e, cy, tiny, NULL, draws)
assert(identical(fa$primary, fb$primary) && all(fa$first_step_guard$pass),
  "forecast excludes future observations first-step teacher-forcing guard passes")

# Stage wiring is tested without extra scientific fits or fresh DGP draws.
dir.create(file.path(tmp, "plans")); dir.create(file.path(tmp, "review"))
iqt12_json(state, file.path(tmp, "campaign.json"))
smokes <- lapply(c("joint_shrink", "memory099"), function(arm) irm13_config(state, arm, "F1", "A", "smoke"))
ifd11_plan(state, "smoke", smokes)
for (cfg in smokes) iqt12_json(list(status = "SUCCESS"), cfg$status_path)
verify_original <- irm13_verify; irm13_verify <- function(run) invisible(TRUE)
irm13_advance(tmp, "smoke")
p <- ifd11_plan_status(tmp, "selection_warm")
assert(nrow(p) == 20L && all(p$status == "PENDING"), "five candidates four prefixes warm plan")
for (path in p$config_path) {
  cfg <- iqt12_read(path)
  iqt12_json(list(design_hash = "fixture", initial = list()), file.path(cfg$evidence, "mcmc_initializer.json"))
  iqt12_json(list(status = "SUCCESS"), cfg$status_path)
}
irm13_advance(tmp, "selection_warm")
p <- ifd11_plan_status(tmp, "selection")
assert(nrow(p) == 20L && all(vapply(p$config_path, function(path) {
  cfg <- iqt12_read(path); grepl(cfg$arm, cfg$warm_path, fixed = TRUE) && cfg$burn == 1500L &&
    cfg$retained == 5000L && cfg$inner == 128L
}, TRUE)), "selection fits use candidate-specific hashed initializers and exact budgets")
iqt12_json(list(selected = "tau_half", strict_check_gain_over_static = FALSE), file.path(tmp, "selection_review.json"))
assert(inherits(try(irm13_continue(tmp, "confirmation_warm"), silent = TRUE), "try-error"),
  "no automatic costly confirmation after failed primary contrast")
iqt12_json(list(selected = "tau_half", strict_check_gain_over_static = TRUE), file.path(tmp, "selection_review.json"))
irm13_continue(tmp, "confirmation_warm")
p <- ifd11_plan_status(tmp, "confirmation_warm")
assert(nrow(p) == 6L && all(vapply(p$config_path, function(path)
  max(iqt12_read(path)$window$train) == 8600L, TRUE)), "disjoint C confirmation three separate warm arms")
for (path in p$config_path) {
  cfg <- iqt12_read(path)
  iqt12_json(list(design_hash = "fixture", initial = list()), file.path(cfg$evidence, "mcmc_initializer.json"))
  iqt12_json(list(status = "SUCCESS"), cfg$status_path)
}
irm13_advance(tmp, "confirmation_warm")
p <- ifd11_plan_status(tmp, "confirmation")
assert(nrow(p) == 18L && all(vapply(p$config_path, function(path) {
  cfg <- iqt12_read(path); cfg$retained == 10000L && cfg$burn == 3000L
}, TRUE)), "full three-chain conditional confirmation plan")
extension <- state
extension$synthetic_test_only <- TRUE
for (replica in paste0("N", 1:4)) extension$sources[[replica]] <- state$sources$F1
iqt12_json(extension, file.path(tmp, "fresh_extension.json"))
iqt12_json(list(selected = "tau_half", strict_check_gain_over_static = TRUE),
  file.path(tmp, "confirmation_review.json"))
irm13_continue(tmp, "fresh_warm")
p <- ifd11_plan_status(tmp, "fresh_warm")
assert(nrow(p) == 12L && length(unique(p$replica)) == 4L,
  "fresh stage four replicas with distinct three-arm initializers")
for (path in p$config_path) {
  cfg <- iqt12_read(path)
  iqt12_json(list(design_hash = "fixture", initial = list()), file.path(cfg$evidence, "mcmc_initializer.json"))
  iqt12_json(list(status = "SUCCESS"), cfg$status_path)
}
irm13_advance(tmp, "fresh_warm")
p <- ifd11_plan_status(tmp, "fresh")
assert(nrow(p) == 36L && all(vapply(p$config_path, function(path) {
  cfg <- iqt12_read(path); cfg$window$N == 2000L && nrow(iqt12_grid(cfg$window)) == 1000L
}, TRUE)), "fresh full pipeline keeps 2000 training and 1000 forecast targets")
irm13_verify <- verify_original

summary <- data.frame(replica = rep(c("F1_A", "F2_A"), each = 7),
  arm = rep(c("dqlm", "static", irm13_arms), 2), metric = "forecast_check_loss",
  mean = rep(c(1, 2, 2-1e-12, 3, 4, 5, 6), 2), lower = 0, upper = 10)
rank <- irm13_rank(summary, irm13_arms)
assert(rank$selected == "tau_half" && rank$strict_check_gain_over_static,
  "no minimum improvement threshold and no diagnostic exclusions")
summary$metric <- "forecast_mae"; summary$mean_path_score <- summary$mean
irm13_pdf(tmp, "synthetic_test_only", list(summary = summary))
assert(file.info(file.path(tmp, "review/synthetic_test_only_all_arms_metrics.pdf"))$size > 0,
  "seven-arm review PDF renders")
assert(all(file.exists(irm13_own_sources(repo))), "all protocol sources present")
if (nzchar(Sys.getenv("IRM13_TEST_EVIDENCE")))
  iqt12_json(list(status = "PASS", checks = count, package_version = as.character(packageVersion("exdqlm")),
    session = capture.output(sessionInfo()), source_hashes = data.frame(
      path = irm13_own_sources(repo), sha256 = unname(tools::sha256sum(irm13_own_sources(repo))))),
    Sys.getenv("IRM13_TEST_EVIDENCE"))
if (nzchar(Sys.getenv("IRM13_TEST_EVIDENCE"))) {
  assert(isTRUE(irm13_verify_tests(repo, Sys.getenv("IRM13_TEST_EVIDENCE"))),
    "preflight JSON row-array hashes round-trip and match all current sources")
  bad_report <- iqt12_read(Sys.getenv("IRM13_TEST_EVIDENCE")); bad_report$status <- "FAILED"
  iqt12_json(bad_report, file.path(tmp, "bad_report.json"))
  assert(inherits(try(irm13_verify_tests(repo, file.path(tmp, "bad_report.json")), silent = TRUE), "try-error"),
    "failed test report cannot authorize materialization")
  report <- iqt12_read(Sys.getenv("IRM13_TEST_EVIDENCE")); report$checks <- count
  iqt12_json(report, Sys.getenv("IRM13_TEST_EVIDENCE"))
}
cat("TOTAL:", count, "checks passed\n")
