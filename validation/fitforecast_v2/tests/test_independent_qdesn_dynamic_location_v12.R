repo <- normalizePath(Sys.getenv("IDL12_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R", "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R", "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R", "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R", "independent_qdesn_fresh_dgp_v11.R",
    "independent_qdesn_dynamic_location_v12.R")) source(file.path(repo, "validation/fitforecast_v2/R", file))
assert <- function(condition, label) {
  stopifnot(isTRUE(condition)); cat("PASS:", label, "\n")
}
tmp <- tempfile("idl12_test_"); dir.create(tmp)
idl12_compile(repo, file.path(tmp, "cpp"))
set.seed(23)
reference <- idl12_ffbs_cpp(c(1, 2), c(.2, .3), .1)$draw
loaded <- parallel::mclapply(1:8, function(i) {
  idl12_load(file.path(tmp, "cpp"))
  set.seed(23)
  idl12_ffbs_cpp(c(1, 2), c(.2, .3), .1)$draw
}, mc.cores = 8L, mc.set.seed = FALSE)
assert(all(vapply(loaded, identical, TRUE, reference)),
  "eight concurrent read-only DLL loaders match compiled reference")

# Analytic single-observation AL updates compared with direct quadrature.
for (p in c(.05, .25, .5)) for (residual in c(-3, 0, 3)) {
  m <- .3; P <- .7; sigma <- .8
  mode <- optimize(function(a) .5*(a-m)^2/P +
    ((residual-a)*(p - ((residual-a) < 0)))/sigma, c(-10, 10))$minimum
  logf <- function(a) dnorm(a, m, sqrt(P), log = TRUE) -
    ((residual-a)*(p - ((residual-a) < 0)))/sigma
  f <- function(a) exp(logf(a) - logf(mode))
  Z <- integrate(f, -Inf, residual, rel.tol = 1e-11)$value +
    integrate(f, residual, Inf, rel.tol = 1e-11)$value
  moment <- function(k) (integrate(function(a) a^k*f(a), -Inf, residual,
    rel.tol = 1e-11)$value + integrate(function(a) a^k*f(a), residual, Inf,
    rel.tol = 1e-11)$value)/Z
  mu <- moment(1); variance <- moment(2) - mu^2
  result <- idl12_al_moments(m, P, residual, sigma, p)
  assert(max(abs(c(result$mean - mu, result$variance - variance))) < 1e-6,
    paste("AL moments quadrature", p, residual))
}
tails <- idl12_al_moments(0, 1, c(-100, 100), .01, .05)
assert(all(is.finite(c(tails$mean, tails$variance))) && all(tails$variance >= 0),
  "extreme residual moments finite")
assert(identical(idl12_al_moments(2, 0, 99, 1, .05)$mean, 2), "zero state variance")

z <- c(.4, -.2, .8, .6); V <- c(.3, .6, .2, .4); omega2 <- .1
n <- length(z); prior <- omega2 * outer(1:n, 1:n, pmin)
covariance <- solve(solve(prior) + diag(1/V))
mu <- drop(covariance %*% (z/V))
set.seed(71)
samples <- replicate(20000L, idl12_ffbs_cpp(z, V, omega2)$draw)
assert(max(abs(rowMeans(samples)-mu)) < .015, "FFBS mean vs dense Gaussian posterior")
assert(max(abs(cov(t(samples))-covariance)) < .008, "FFBS covariance vs dense Gaussian posterior")
m <- C <- 0
for (i in 1:n) {
  R <- C + omega2; K <- R/(R+V[i]); m <- m+K*(z[i]-m); C <- R*V[i]/(R+V[i])
}
last <- idl12_ffbs_cpp(z, V, omega2)
assert(max(abs(c(tail(last$mean, 1)-m, tail(last$variance, 1)-C))) < 1e-12,
  "FFBS filtering moments exact")
assert(inherits(try(idl12_ffbs_cpp(z, V, -1), silent = TRUE), "try-error"),
  "negative innovation rejected")

loc <- matrix(.2, 20L, 4L); y <- seq(-.1, .3, length.out = 20L)
filter <- idl12_filter(y, loc, rep(.2, 4), .02, rep(0, 4), .05, 13)
again <- idl12_filter(y, loc, rep(.2, 4), .02, rep(0, 4), .05, 13)
changed <- y; changed[11:20] <- 100
causal <- idl12_filter(changed, loc, rep(.2, 4), .02, rep(0, 4), .05, 13)
assert(identical(filter, again), "filter RNG repeatability")
assert(identical(filter$particles[1:11, ], causal$particles[1:11, ]),
  "filter cannot use future observations")
assert(all(filter$variances >= 0) && !identical(filter$particles, filter$means),
  "state uncertainty retained rather than deterministic correction")

for (fold in c("A", "B", "C", "FINAL")) {
  w <- idl12_window(fold); g <- iqt12_grid(w)
  count <- if (fold == "FINAL") 1000L else 240L
  assert(nrow(g) == count && !anyDuplicated(g$target) &&
    max(w$train) < min(g$target) && length(w$washout) == 500L,
    paste("training and forecast grid", fold))
  for (shift in c(10L, 20L)) assert(nrow(iqt12_grid(idl12_phase_window(w, shift))) == count-shift,
    paste("phase clipping", fold, shift))
}
parent <- paste0("/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_fresh_dgp_v11_20261012/",
  "validation/fitforecast_v2/local_trackers/independent_qdesn_fresh_dgp_v11_20261012__git-770d5761")
state <- iqt12_read(file.path(parent, "campaign.json"))
state$repo <- repo; state$run <- tmp
cfg <- idl12_config(state, "static", "F1", "A", "smoke")
roundtrip <- iqt12_json(cfg, file.path(tmp, "cfg.json"))
assert(identical(iqt12_read(roundtrip)$window$train, 7001:8000), "JSON index contract")
assert(cfg$layer2_scale == .25 && cfg$omega_scaled == 0 && cfg$likelihood == "al",
  "frozen retained representation and likelihood")
original_fit <- iqt12_quantile
iqt12_quantile <- function(e, cx, cfg) list(exact_static_dispatch = TRUE)
assert(isTRUE(idl12_fit(NULL, NULL, cfg)$exact_static_dispatch), "omega=0 exact static kernel dispatch")
iqt12_quantile <- original_fit

e <- ifd11_runtime(repo, state$library)
assert(as.character(packageVersion("exdqlm")) == "1.1.2", "CRAN exdqlm version")
source <- read.csv(state$sources$F1$path)
cx <- ilr10_design_hook(e, cfg, source, cfg$window$end)
altered <- source; altered$q_target <- -9999; altered$y[8001:10000] <- 9999
cy <- ilr10_design_hook(e, cfg, altered, cfg$window$end)
assert(identical(cx$object$X, cy$object$X) && identical(cx$object$y_fit, cy$object$y_fit),
  "training design excludes oracle and future observations")
assert(all(cx$object$reservoir$Q_is_identity) && ncol(cx$object$X) == 351L,
  "identity Q and full reservoir-only readout")

draws <- list(beta = matrix(0, 4, ncol(cx$object$X)), sigma = rep(.03, 4), gamma = rep(0, 4))
draws$beta[, 1] <- mean(cx$object$y_fit)
zero <- matrix(0, 2, 4); noise <- list(v = zero, z = zero, s = zero)
local <- 8000L-cx$first+1L
a <- idl12_particle(e, cx$object, cx$y, local, 2L, draws, noise,
  cx$conditioning, cx$readout_multiplier, rep(0, 4), zero)
b <- ilr10_particle_paths(e, cx$object, cx$y, local, 2L, draws, noise,
  cx$conditioning, cx$readout_multiplier)
assert(max(abs(a$mu_draws-b$mu_draws)) < 1e-12, "omega=0 forecast readout matches frozen particle backend")
fit <- list(beta = draws$beta, sigma = draws$sigma, gamma = draws$gamma,
  offset = matrix(0, nrow(cx$object$X), 4))
forecast_cfg <- cfg; forecast_cfg$outer <- 4L; forecast_cfg$omega_scaled <- .005
fa <- idl12_forecast(e, cx, forecast_cfg, fit)
fb <- idl12_forecast(e, cy, forecast_cfg, fit)
assert(identical(fa$primary, fb$primary) && all(fa$guards$pass),
  "fixed-origin forecast excludes future observations and oracle")

# A joint AL target smoke with a changing location, not an ordinary mean correction.
set.seed(131)
p <- .25; n <- 80L; true_q <- seq(0, 1.4, length.out = n)
A <- (1-2*p)/(p*(1-p)); B <- 2/(p*(1-p)); v <- rexp(n, rate = 1/.04)
ys <- true_q + A*v + sqrt(B*.04*v)*rnorm(n)
X <- cbind(1, sin(seq_len(n)/9))
fake <- list(scale = 1, design_hash = "synthetic", object = list(X = X, y_fit = ys))
small <- cfg; small$p <- p; small$omega_scaled <- .06
small$burn <- 1000L; small$retained <- 2000L; small$outer <- 100L
small$warm_path <- file.path(tmp, "warm.json")
iqt12_json(list(design_hash = "synthetic", initial = list(beta = c(0, 0), sigma = .04,
  v = rep(.04, n))), small$warm_path)
small$warm_sha <- unname(tools::sha256sum(small$warm_path))
sample <- idl12_fit(e, fake, small)
old_omp <- Sys.getenv("OMP_NUM_THREADS")
Sys.setenv(OMP_NUM_THREADS = "2")
repeat_sample <- idl12_fit(e, fake, small)
Sys.setenv(OMP_NUM_THREADS = old_omp)
assert(identical(sample$beta, repeat_sample$beta) && identical(sample$trace, repeat_sample$trace),
  "joint sampler R-RNG repeatability under changed OMP setting (serial helper)")
recovered <- rowMeans(X %*% t(sample$beta) + sample$offset)
assert(mean(abs(recovered-true_q)) < .2 && tail(recovered, 1) > head(recovered, 1) + .6,
  "joint AL sampler recovers a changing quantile location")
assert(all(is.finite(sample$trace)) && all(sample$gamma == 0) && nrow(sample$beta) == 100L,
  "joint draws finite and aligned with retained state and sigma")

# Synthetic orchestration exercises budgets, strict tiny gains and manifest tampering.
fixture <- file.path(tmp, "fixture"); dir.create(file.path(fixture, "review"), recursive = TRUE)
expected <- list(smoke = 2L, selection_warm = 8L, selection = 20L,
  confirmation_warm = 4L, confirmation = 18L, fresh_warm = 8L, fresh = 36L)
iqt12_json(list(expected_jobs = expected), file.path(fixture, "campaign.json"))
h <- idl12_health(fixture)
assert(sum(h$planned_maximum) == 96L && sum(h$gated) == 96L, "named JSON conditional budgets")
assert(all(file.exists(idl12_sources(repo, e))), "source closure complete")
sentinel <- iqt12_json(list(test = TRUE), file.path(tmp, "sentinel.json"))
manifest <- iqt12_hash(sentinel, file.path(tmp, "hash.csv")); iqt12_verify(manifest)
iqt12_json(list(test = FALSE), sentinel)
assert(inherits(try(iqt12_verify(manifest), silent = TRUE), "try-error"), "hash tampering rejected")

# Execute selection, both review gates, pooled summaries and PDF closeout with fake scores.
fixture <- file.path(tmp, "pipeline")
for (dir in c("review", "plans", "configs", "status", "evidence"))
  dir.create(file.path(fixture, dir), recursive = TRUE)
fixture_state <- state; fixture_state$run <- fixture
fixture_state$synthetic_test_only <- TRUE
fixture_state$expected_jobs <- expected; fixture_state$sources <- list()
fake_source <- data.frame(t = 1:10000, y = .3, q_target = 0)
for (replica in c("F1", "F2")) {
  sp <- iqt12_csv(fake_source, file.path(fixture, paste0(replica, ".csv")))
  fixture_state$sources[[replica]] <- list(path = sp, sha256 = unname(tools::sha256sum(sp)))
}
fixture_state$fresh_seeds <- list(N1 = c(81411001L, 81411002L), N2 = c(81412001L, 81412002L),
  N3 = c(81413001L, 81413002L), N4 = c(81414001L, 81414002L))
frozen <- iqt12_json(fixture_state, file.path(fixture, "campaign.json"))
for (name in c("source", "package", "input", "frozen"))
  iqt12_hash(frozen, file.path(fixture, paste0(name, "_hashes.csv")))
fake_success <- function(configs, stage) {
  ifd11_plan(fixture_state, stage, configs)
  for (config in configs) {
    dir.create(config$evidence, recursive = TRUE)
    w <- config$window; nd <- 4L
    set.seed(config$seed)
    fd <- matrix(rnorm(length(w$train)*nd, sd = .05), length(w$train))
    q <- matrix(rnorm(nrow(iqt12_grid(w))*nd, sd = .05), nrow(iqt12_grid(w)))
    z <- ifd11_score_companions(fd, q, fake_source, w, config$p)$summary
    z$mean[z$metric == "forecast_check_loss"] <-
      if (config$arm == "omega005") 1-1e-10 else if (config$arm == "static") 1 else 2
    iqt12_csv(z, file.path(config$evidence, "summary.csv"))
    iqt12_csv(cbind(source_index = w$train, fd), file.path(config$evidence, "fit_location_draws.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(w), q), file.path(config$evidence, "forecast_location_draws.csv.gz"))
    iqt12_csv(data.frame(sigma = abs(rnorm(20))+1), file.path(config$evidence, "nuisance_trace.csv.gz"))
    iqt12_json(list(initial = "synthetic_not_scientific"), file.path(config$evidence, "mcmc_initializer.json"))
    mf <- iqt12_hash(list.files(config$evidence, full.names = TRUE), file.path(config$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
  }
}
smokes <- lapply(c("dqlm", "omega005"), function(arm)
  idl12_config(fixture_state, arm, "F1", "A", "smoke"))
fake_success(smokes, "smoke")
idl12_advance(fixture, "smoke")
warm_plan <- ifd11_plan_status(fixture, "selection_warm")
assert(nrow(warm_plan) == 8L, "first advancement creates exactly eight warm starts")
for (cp in warm_plan$config_path) {
  config <- iqt12_read(cp); dir.create(config$evidence, recursive = TRUE)
  ip <- iqt12_json(list(synthetic = TRUE), file.path(config$evidence, "mcmc_initializer.json"))
  mf <- iqt12_hash(ip, file.path(config$evidence, "manifest.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
}
idl12_advance(fixture, "selection_warm")
selection <- ifd11_plan_status(fixture, "selection")
assert(nrow(selection) == 20L && all(table(selection$arm) == 4L), "five-arm matched selection budget")
for (i in seq_len(nrow(selection))) {
  config <- iqt12_read(selection$config_path[i]); dir.create(config$evidence, recursive = TRUE)
  z <- data.frame(metric = "forecast_check_loss", mean = if (config$arm == "omega005")
    1-1e-10 else if (config$arm == "static") 1 else 2, lower = 0, upper = 3)
  ip <- iqt12_csv(z, file.path(config$evidence, "summary.csv"))
  mf <- iqt12_hash(ip, file.path(config$evidence, "manifest.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
}
idl12_advance(fixture, "selection")
decision <- iqt12_read(file.path(fixture, "selection_review.json"))
assert(decision$selected == "omega005" && decision$strict_check_gain_over_static &&
  !file.exists(file.path(fixture, "plans/confirmation_warm.csv")),
  "tiny strict gain retained with explicit scientific review gate")
idl12_continue(fixture, "confirmation_warm")
warm_plan <- ifd11_plan_status(fixture, "confirmation_warm")
for (cp in warm_plan$config_path) {
  config <- iqt12_read(cp); dir.create(config$evidence, recursive = TRUE)
  ip <- iqt12_json(list(synthetic = TRUE), file.path(config$evidence, "mcmc_initializer.json"))
  mf <- iqt12_hash(ip, file.path(config$evidence, "manifest.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
}
idl12_advance(fixture, "confirmation_warm")
plan <- ifd11_plan_status(fixture, "confirmation")
assert(nrow(plan) == 18L && all(table(plan$arm) == 6L), "locked internal three-chain budget")
for (cp in plan$config_path) {
  config <- iqt12_read(cp); dir.create(config$evidence, recursive = TRUE)
  w <- config$window
  fd <- matrix(.1, length(w$train), 4L); q <- matrix(.1, nrow(iqt12_grid(w)), 4L)
  if (config$arm == "omega005") q <- q-1e-10
  if (config$arm == "static") q <- q+.01
  iqt12_csv(cbind(source_index = w$train, fd), file.path(config$evidence, "fit_location_draws.csv.gz"))
  iqt12_csv(cbind(iqt12_grid(w), q), file.path(config$evidence, "forecast_location_draws.csv.gz"))
  set.seed(config$seed)
  iqt12_csv(data.frame(sigma = abs(rnorm(20))+1), file.path(config$evidence, "nuisance_trace.csv.gz"))
  mf <- iqt12_hash(list.files(config$evidence, full.names = TRUE), file.path(config$evidence, "manifest.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
}
idl12_advance(fixture, "confirmation")
assert(file.exists(file.path(fixture, "review/confirmation_dynamic_location_review.pdf")),
  "pooled score, diagnostics and multipage PDF closeout")
confirmation <- iqt12_read(file.path(fixture, "confirmation_review.json"))
assert(!confirmation$strict_check_gain_over_static &&
  inherits(try(idl12_continue(fixture, "fresh_warm"), silent = TRUE), "try-error"),
  "no-gain confirmation prevents expensive fresh scheduling")
idl12_verify(fixture)
# This override is confined to the explicitly synthetic fixture, to exercise
# the successful continuation path without claiming a scientific gain.
confirmation$strict_check_gain_over_static <- TRUE
confirmation$synthetic_gate_override <- TRUE
iqt12_json(confirmation, file.path(fixture, "confirmation_review.json"))
iqt12_hash(c(file.path(fixture, "confirmation_review.json"),
  list.files(file.path(fixture, "review"), full.names = TRUE)),
  file.path(fixture, "confirmation_review_hashes.csv"))
idl12_continue(fixture, "fresh_warm")
warm_plan <- ifd11_plan_status(fixture, "fresh_warm")
assert(nrow(warm_plan) == 8L && all(table(warm_plan$replica) == 2L),
  "fresh seeds materialized only after reviewed continuation")
for (cp in warm_plan$config_path) {
  config <- iqt12_read(cp); dir.create(config$evidence, recursive = TRUE)
  ip <- iqt12_json(list(synthetic = TRUE), file.path(config$evidence, "mcmc_initializer.json"))
  mf <- iqt12_hash(ip, file.path(config$evidence, "manifest.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
}
idl12_advance(fixture, "fresh_warm")
plan <- ifd11_plan_status(fixture, "fresh")
assert(nrow(plan) == 36L && all(table(plan$replica) == 9L), "fresh stage exact 36-job budget")
for (cp in plan$config_path) {
  config <- iqt12_read(cp); dir.create(config$evidence, recursive = TRUE)
  w <- config$window
  fd <- matrix(.1, length(w$train), 4L); q <- matrix(.1, nrow(iqt12_grid(w)), 4L)
  iqt12_csv(cbind(source_index = w$train, fd), file.path(config$evidence, "fit_location_draws.csv.gz"))
  iqt12_csv(cbind(iqt12_grid(w), q), file.path(config$evidence, "forecast_location_draws.csv.gz"))
  set.seed(config$seed)
  iqt12_csv(data.frame(sigma = abs(rnorm(20))+1), file.path(config$evidence, "nuisance_trace.csv.gz"))
  mf <- iqt12_hash(list.files(config$evidence, full.names = TRUE), file.path(config$evidence, "manifest.csv"))
  iqt12_json(list(status = "SUCCESS", manifest = mf), config$status_path)
}
idl12_advance(fixture, "fresh")
idl12_verify(fixture)
assert(sum(idl12_health(fixture)$complete) == 96L &&
  file.exists(file.path(fixture, "review/fresh_dynamic_location_review.pdf")),
  "all stages and fresh PDF/hash closeout tested without scientific jobs")
cat("ALL DYNAMIC LOCATION V12 PREFLIGHT TESTS PASSED\n")
