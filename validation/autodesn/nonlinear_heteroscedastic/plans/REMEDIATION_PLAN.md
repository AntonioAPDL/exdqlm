---
title: "AutoDESN forecast remediation"
subtitle: "Statistical specification, implementation sequence, and independent review gates"
author: "Planning document for Toni"
date: "23 October 2026"
lang: en-US
---

# Decision and status

**Planning only. No model implementation, new fit, simulation study, or benchmark is authorized by this document.** The user requested a comprehensive plan before further implementation. Proposed controls below become an execution protocol only after the mathematical specification, feasibility assessment, and development decisions are recorded. They are not completed experiments.

The recommended sequence is: preserve the audited baseline; improve the mean representation; repair AutoGP exploration under its existing posterior; add conditional volatility through a separately validated model; and then evaluate frozen methods on independent series. Increasing every reservoir or weakening all shrinkage at once would obscure attribution and consume the available resources without resolving the known computational issues.

The plan is designed to withstand adversarial statistical and software review. It cannot guarantee a particular improvement, global posterior convergence, or immunity from criticism. It makes assumptions, targets, failure criteria, and remaining uncertainty explicit. A scientifically valid negative result is an acceptable outcome; an unqualified superiority claim is not.

The starting revision is `4916600928337f1ef179fda6100f54c20723bd9a` in `AntonioAPDL/exdqlm`, branch `feature/autodesn-nonlinear-heteroscedastic-20261023`, draft PR 4. The original benchmark was completed at `e726533322bb5625a995dc78ac6cbd09d4dcb977`. The audit added diagnostic evidence without changing original forecasts or model code. The native AutoGP source is pinned at `2ad372db2b8bea176e3b32a769bfb5d6cff80866`, version 0.1.19.

The immediate engineering target is an opt-in, backward-compatible Gaussian AutoDESN whose readout can retain direct lag information and represent nonsinusoidal seasonality. The default ridge and RHS behavior must remain reproducible. Bayesian averaging over the full declared reservoir bank remains central. New period states, coefficient groups, and variance states must have proper, normalized priors and correct posterior transitions.

Three different notions of success must be reported separately:

1. **Correctness:** the implemented sampler targets the written conditional model and causal forecasting law.
2. **Computational adequacy:** independent runs, diagnostics, reference calculations, and budget sensitivity support the reported quantities.
3. **Predictive improvement:** independent DGP realizations support practically meaningful improvements with quantified uncertainty.

Correctness does not imply convergence, and convergence does not imply a useful model. Predictive performance cannot retroactively validate an incorrect sampler. This separation follows the Bayesian workflow perspective [R11] and is a requirement throughout the plan.

\newpage

# Evidence ledger and working hypotheses

These are completed audit findings, not future performance promises. All RMSE values below are pooled over the original 471 origins and 30 horizons unless otherwise stated.

| Observation | Verified evidence | Planning implication |
|---|---|---|
| Nontrivial irreducible uncertainty | Oracle RMSE 0.51685; requested RHS 0.57887 | Evaluate avoidable mean error relative to an information-matched oracle |
| Remaining mean error | Requested RHS oracle-mean RMSE 0.28844; about 78.0% of conditional expected MSE is irreducible | Useful signal remains, but visual tracking of every spike is not a valid goal |
| RHS is active | Median 50 slopes; 18.8% below absolute 0.01; about 19.5 above 0.1 | Investigate prior geometry and representation rather than assume an all-zero model |
| Strong feature dependence | Leading reservoir participation rank 7.15 of 50 | Standardization is necessary but insufficient for identification |
| Direct predictors help | Generic AR90 RMSE 0.55584; validation-selected AR90 plus known phase 0.54966 | Direct-lag readout connections are the first controlled change |
| Native GP exploration is limited | Two/four canonical structures; in-grammar diagnostic GP RMSE 0.58178 | Repair search before claiming GP incapacity or expanding depth |
| High-density GP region was missed | Equal-dimensional native log-joint point gap 450.72 nats | Add valid proposals and independent-run stress tests; do not interpret the gap as a Bayes factor |
| Volatility is misspecified | Nominal one-step 90% RHS coverage 96.8% in low volatility and 83.0% in high volatility | A separate variance model is warranted |

The privileged true-mean capacity audit has 500 test targets, whereas the original horizon-1 forecast comparison has 471. Requested RHS true-mean RMSE is 0.18117 on the former. Noiseless-supervised validation-selected reservoir RMSE is 0.15136; adding explicit phase to the leading reservoir gives 0.1138. These comparisons reveal headroom but do not uniquely decompose representation, estimation, and regularization effects.

The weaker RHS control gives only a small score improvement. It does not identify optimal hyperparameters. A continuous shrinkage prior normally has no exact zero coefficients; exact-zero counts are not an adequate sparsity diagnostic.

The new GP and lag results are post-hoc plug-ins, and period 60 is privileged in their seasonal components. They are mechanism probes, not converged replacement Bayesian models. The native GP covariance reconstruction agrees with exported means to approximately 4.43e-14, which argues against the specific forecast-export discrepancy tested, not against every possible implementation error.

**Hypotheses to distinguish:** H1, useful raw lags are compressed by the reservoir/readout; H2, prior mass is poorly aligned with correlated feature directions; H3, AutoGP has inadequate mode exploration; H4, constant variance causes regime-dependent miscalibration; H5, future innovations explain much of the remaining error. Multiple hypotheses can be true simultaneously.

\newpage

# Nonnegotiable contracts and information flow

Retain the 500 washout / 2,000 training / 500 test split, fit once at origin 2500, origins 2500:2970, and horizons 1:30. This produces 14,130 dependent forecast pairs per model. Models receive observed time and response only. Truth files remain restricted to diagnostic and scoring code.

Preserve the existing response/input preprocessing convention from the conditioning prefix. Fit every readout transformation on the applicable scored training rows only. Nonconstant readout features have training mean zero and sample SD one. The intercept remains unscaled with its separate proper prior. Keep dimension normalization disabled in this comparison. Raw coefficients must include the intercept correction when transported back from standardized coordinates.

Retain the existing normalized independent RHS convention:

$$
\beta_j\mid\tau,\lambda_j,c^2\sim N(0,v_j),\qquad
v_j=\left\{(\tau^2\lambda_j^2)^{-1}+(c^2)^{-1}\right\}^{-1}.
$$

The coefficient prior is independent of observation variance. Do not silently introduce multiplication by that variance. Keep `tau0=0.001`, `slab_scale=1`, and `slab_df=4` as the requested reference. Global/local/slab scales remain sampled unless an experiment explicitly identifies a fixed-scale ablation. The distinction between normalized RHS and the separate `rhs_ns` formulation remains documented [R1; existing code].

Every forecast samples a joint posterior architecture and its matching parameters. Architecture, coefficients, and static scales remain fixed along a simulated future path. Simulated responses update lags and reservoir states within that path. Observations update states only between issued forecasts. No averaging of incompatible coefficient vectors or premature substitution of a mean architecture is allowed.

Keep full-support Bayesian architecture moves. Training-informed proposals may improve exploration with exact Hastings corrections. They cannot discard candidates because a proxy fit or held-out score is poor. Model admission must follow a declared numerical/washout rule, with an audit of exclusions and the resulting prior.

Maintain two information tracks. The **automatic track** receives no true period, true conditional mean, latent variance, or DGP-specific lag set. The **known-calendar track** supplies period information explicitly and is labeled as privileged unless it would be externally known in an application. Its results cannot establish automatic seasonal discovery.

At later origins, the primary frozen-fit protocol keeps parameter and architecture weights fixed. Updating a latent state is permitted. Fully reweighting parameters using new observations is a different sequential Bayesian protocol and must be evaluated separately. Fixed component weights in GP conditioning require the same explicit interpretation.

\newpage

# Gate G0: freeze inputs, targets, and development rules

Before implementation, create a read-only evidence inventory from the starting revision. Verify original score hashes, original/audit archive manifests, feature geometry, model-prior masses, and native GP configurations. Restore the saved numeric evidence rather than infer completion from scripts or filenames. Preserve all failed inference attempts and provenance.

Record a model identity containing source hashes, data hashes, response transforms, feature transforms, active columns, feature ordering, period convention, normalized prior specification, architecture masses, latent-state initialization, and forecasting policy. A cache is reusable only when every target-defining field matches. State-filter caches need separate state and parameter identifiers.

Treat NHS1 seed 1766021 as development data: its test outcomes have already been examined. New experiments on that series are explanatory, regardless of whether new parameters are selected using training data only. Independent confirmation requires new seeds after method choices are frozen.

Use two chronological development checks within the original training window. Proposed cutoffs are 1500 and 2000, each followed by 500 validation observations. Each cutoff yields 471 validation origins and 30 horizons. Fit once at the cutoff; update observed states between validation origins. At cutoff 1500 the scored training rows are 501:1500, and at cutoff 2000 they are 501:2000. Rebuild data-dependent PCA/projections and readout scalers at each cutoff. Reusing the full-2500 transformation would leak validation information.

Choose among a small declared set of feature/prior families by average validation CRPS, with RMSE, NLL, and calibration as secondary diagnostics. If differences are smaller than their assessed computational uncertainty, prefer the simpler qualified family. Do not describe this empirical family choice as Bayesian posterior model probability. Reservoir architectures inside each chosen family still receive full posterior averaging.

Architecture admission, feature-dimension limits, calendar conventions, the finite period support, and computational recovery rules must be frozen before confirmation. Development can revise them with a dated rationale; each revision creates a new target identifier. Confirmatory scores must not trigger a change to those choices.

**G0 exit:** verified evidence inventory, an unambiguous model identity, declared information tracks, development splits, a bounded candidate list, and a written registry of proposed primary comparisons. No inference or forecast result is promoted if provenance is ambiguous. A protected scoring interface is an operational separation, not a claim that already viewed outcomes become unseen again.

\newpage

# Gate G1: retain useful mean predictors

For reservoir architecture $m$, propose the causal readout

$$
\mu_{m,t}=\alpha+L_t^\top b+S_t(P)^\top d+H_{m,t}^\top\beta_m.
$$

Here $L_t=(y_{t-1},\ldots,y_{t-90})$ is a generic lag window, $S_t(P)$ is an explicitly defined calendar basis, and $H_{m,t}$ is the existing Q-DESN reservoir feature vector. The residual DESN still supplies nonlinear dynamic features; direct lags avoid requiring a random compression to preserve every useful linear direction. Reuse the reservoir construction [R2] rather than train recurrent weights in this first extension.

Implement three opt-in feature families in sequence: F0, current reservoir only; F1, reservoir plus direct lags 1:90; F2, F1 plus calendar terms. First retain the exact original 426 admitted reservoirs, seeds, and architecture prior. No new reservoir search is needed to identify the effect of adding predictors. If admission changes because of a builder alteration, stop and explain it.

For the automatic F2 model, use a proper discrete period prior on integers 20:120. Proposed Fourier basis order is $K(P)=\min\{16,\lfloor(P-1)/2\rfloor\}$, excluding the Nyquist term. Include sine/cosine pairs and no seasonal intercept. This supports much richer shapes than one sinusoid. Posterior averaging includes $P$, with alias/multiple-period diagnostics. Period support and order are modeling assumptions, not universal defaults. The known-calendar ablation fixes $P=60$ and is reported separately.

The joint state is $(m,P)$ with prior $p(m)p(P)$, rather than a list whose duplication accidentally changes reservoir mass. Storage may share the common lag/calendar blocks; the inference target must remain the full declared Cartesian support. Period proposals may mix a uniform component with a training-only periodogram proposal, with exact forward/reverse probabilities. Predictions use the posterior period draw and absolute timestamps, with the original phase convention.

Scale each block using training rows, store semantic feature names, remove only explicitly constant columns, and report condition numbers, singular values, effective rank, and reservoir saturation. Inspect memory retention using training-only perturbations and Jacobian/lag-response probes. These characterize representation; they do not screen architectures out of the posterior.

**G1 exit:** identical F0 predictions under disabled options; exact causal reconstruction for F1/F2; correct raw-coordinate transport; documented dimensions; and independently checked posterior averaging over both architecture and period.

\newpage

# Gate G1: normalized priors and exact Gaussian algebra

Start with an isolation experiment: apply the existing scalar RHS controls to all added slopes. This changes the feature map while keeping the shrinkage mechanism recognizable. Then compare a separate grouped-prior family. Use independent $u_g\sim C^+(0,1)$ for lag and reservoir groups, $\tau_g=\tau_{0g}u_g$, independent $\lambda_j\sim C^+(0,1)$, and a shared slab variance

$$
c^2\sim\operatorname{IG}(\nu/2,\nu s^2/2),\qquad
v_j=\left\{(\tau_{g(j)}^2\lambda_j^2)^{-1}+(c^2)^{-1}\right\}^{-1}.
$$

Proposed grouped reference values are $\tau_{0g}=0.001$, $s=1$, $\nu=4$. This isolates separate learned group scales before changing prior multipliers. For the grouped calendar component, propose proper Gaussian Fourier coefficients with variance $0.5^2/[1+(k/4)^4]$ for harmonic $k$. This is a new model, distinct from flat RHS. Its effect on the original response scale must be inspected under training-only prior predictive simulation before freezing it. These proposed values are not claimed optimal.

Keep $\alpha\sim N(0,10)$ and $\sigma^2\sim\operatorname{IG}(3,1)$ unless the recovered executed controls show an explicit override. IG denotes density $b^a x^{-a-1}\exp(-b/x)/\Gamma(a)$. Never infer actual fit controls from a stale configuration file when saved provenance differs.

Let $X$ include the intercept and all active blocks, $V$ be the full proper prior covariance, and $D$ the observation covariance. For a zero-centered coefficient prior,

$$
A=V^{-1}+X^\top D^{-1}X,\qquad r=X^\top D^{-1}y,\qquad
\theta\mid\cdots\sim N(A^{-1}r,A^{-1}).
$$

The required coefficient-integrated log likelihood is

$$
\ell=-\frac n2\log(2\pi)-\frac12\left[
\log|D|+\log|V|+\log|A|+y^\top D^{-1}y-r^\top A^{-1}r\right].
$$

This includes intercept, calendar, and slope normalizers at every dimension. Implement the equivalent prior-whitened Cholesky system and stable residual-plus-prior quadratic; use the $n$-dimensional covariance $D+XVX^\top$ as an independent small-problem reference. No explicit inverse is needed in production.

\newpage

# Gate G1: architecture moves and prior geometry

For a proposal between states $a=(m,P)$ and $a'$, holding common scale/auxiliary states $z$ fixed, the acceptance log ratio is

$$
\begin{aligned}
\log R={}&\ell(a',z)-\ell(a,z)+\log p(a')-\log p(a)\\
&+\log q(a\mid a',z)-\log q(a'\mid a,z).
\end{aligned}
$$

Joint scale/architecture moves additionally include every transformed scale-prior density, proposal density, and Jacobian. Generalizing the existing three-dimensional proposal to grouped scales requires a new written derivation and tests; simply appending coordinates is insufficient.

Embed local scales in a fixed product space with explicit feature-family indices. Every model must select distinct active slots, and inactive scales must have normalized proper priors. Their integrals are one. A valid embedding can share auxiliary coordinates across mutually exclusive models; that affects mixing, not the intended per-model marginal prior. Lag/calendar/reservoir identities must not be accidentally remapped by a readout-order change. Preserve old layout options for old fits.

After a coefficient-collapsed architecture/period move, redraw the corresponding coefficient vector before any update that conditions on it. This is essential partial-collapse ordering. Retain a full-support component in proposal mixtures. Do not replace a failed transition by a silent rejection if the failure signals a numerical implementation defect.

Scale conditionals must retain the normalized Gaussian terms $-\tfrac12\sum_j[\log v_j+\theta_j^2/v_j]$. The finite slab generally prevents the naive inverse-gamma updates used for an unregularized horseshoe. Reuse the exact local rejection and log-scale slice logic only after verifying its assumptions for groups and covariance blocks. The `rhs_ns` target cannot be substituted without rederiving architecture-dependent normalization.

For geometry diagnostics compute the conditional effective degrees of freedom

$$
\mathrm{edf}=\operatorname{tr}\!\left(XA^{-1}X^\top D^{-1}\right),
$$

and labeled group contributions, conditional prior-to-likelihood scales, fitted-function variation, and posterior shrinkage along identifiable directions. This is a conditional linear-smoother quantity, not the total degrees of freedom of an adaptive Bayesian fit. Do not call a diagonal shrinkage proxy a selected-variable count.

A QR or SVD factorization may stabilize linear algebra without changing the prior if the full transformed covariance and Jacobian are respected. Assigning independent RHS coefficients after a rotation or whitening changes the prior. Retain such an alternative only as a separately named sensitivity model. Do not insert an ad hoc time-series effective sample size into the orthogonal-design horseshoe calibration formula as though it were exact.

\newpage

# Gate G2: repair AutoGP under the same posterior

The first AutoGP intervention is computational: preserve native data transforms, grammar, depth four, priors, noise convention, and target density. Use the pinned native Julia implementation [R12]. Keep the eight-particle original run as a reference, not as evidence that the repaired posterior has converged.

Add diagnostics before new moves: canonical tree classes for reporting, predictive functions on fixed training probes, period/harmonic summaries, ancestor diversity, log-joint traces, stage-wise incremental weights, HMC acceptance and movement, structural acceptance, rejection runs, and independent-run predictive differences. Record parameter and noise HMC separately. A high acceptance rate with negligible movement is not sufficient.

Canonicalization is a reporting operation. The native prior is on syntactic trees: equivalent sums/products can have multiple representations and prior multiplicities. Do not merge particle states into equivalence classes for sampling or evidence calculations unless the induced prior mass and proposal law have been derived. Large pointwise log-joint gaps are stress-test evidence, not posterior odds.

First increase particles and rejuvenation under native valid moves. Proposed ladder: original 8 particles; then 16, 32, and 64 particles, four independent runs at each repair level. Preserve the original data schedule initially. Tune HMC movement using training pilots, then freeze controls before production. Bound expected runtime and memory before launching each level.

If these runs still miss relevant period regions, introduce a training-informed independence proposal in native latent coordinates, mixed with an existing full-support proposal. For latent state $x$, require

$$
\log R=\log\pi(x'\mid y)-\log\pi(x\mid y)
+\log q(x\mid x',y)-\log q(x'\mid x,y).
$$

Data-dependent proposals are valid when their full density is evaluated; data-dependent changes to the target are different. Deterministically inserting optimized particles with ordinary prior-initialization weights is invalid. Either generate correctly weighted particles from an evaluable mixture proposal or use optimized states only as initial states of valid invariant transitions, with independent prior-started production checks. Structural proposals need native trace address, selection, inverse-move, and Jacobian accounting.

Use the known high-density diagnostic configuration as a development stress test. Demonstrating access to it does not establish its posterior mass. Inspect whether parameter/structure transitions also leave the region and whether independent starts give consistent predictive summaries. Maintain Bayesian kernel averaging; the maximum-likelihood kernel is a diagnostic reference.

\newpage

# Gate G2: target changes, fairness, and exit criteria

If a broader period prior is studied, label it a new AutoGP model. Define the prior in raw observation-time units and transform it explicitly to native coordinates, including normalization and Jacobians. A truncated log-uniform or mixture prior needs its finite support and normalization recorded. Changing time scale without transforming the prior changes the model.

Do not change the period prior, maximum depth, proposal, particle count, and forecast policy simultaneously. The ordered contrasts are: native target/native budget; native target/larger budget; native target/new valid proposal; and only then a separately identified new prior. Depth expansion is conditional on evidence that a well-explored existing grammar still fails.

The automatic comparison supplies time and observations only. Training periodogram information can inform proposals with exact correction. A known-period comparison must identify which information and model constraints each method receives; a DESN supplied period 60 cannot establish superior automatic seasonal discovery against an uninformed GP.

The mathematical gate is exact agreement of native and independent covariance/conditional calculations, latent-to-raw parameter transforms, and proposal ratios on small cases. Compare reduced finite-tree posterior probabilities against exhaustive or high-accuracy reference integration. Test native score constants, jitter, syntactic multiplicities, and proposal support.

The computational gate requires four independent runs and two successive budget levels with stable predictive quantities. Proposed tolerances: training-probe predictive means within 0.02 training-response SD; predictive SDs and key quantiles within 3%; canonical-structure masses within 0.03 for substantial categories, with reported run uncertainty; and no persistent large unexplained separation of log-joint/predictive regions by initialization. These are engineering thresholds to freeze before confirmation, not mathematical convergence guarantees.

If equivalent kernels produce different syntactic-tree occupancies, investigate their common predictive function before declaring failure. Conversely, stable predictions do not validate unstable architecture probabilities: publish only the quantities adequately resolved. Particle ESS is not an MCMC ESS or a mode-exploration certificate. Between-run dispersion is the primary uncertainty assessment for finite SMC output. SMC sampler theory motivates correct weighting and invariant rejuvenation, not a blanket empirical guarantee [R3].

Report both accuracy-oriented results after qualification and compute-matched frontiers. Equal iterations do not mean equal cost, and equal cost does not mean equal posterior accuracy. Record failures at capped budgets. If the posterior remains unresolved under the resource cap, the correct conclusion is that the comparison is computationally unresolved, not that the GP family lacks expressiveness.

\newpage

# Gate G3: a compatible conditional-volatility model

Introduce volatility only after the mean extension and its conditional Gaussian algebra are independently verified. Prefer a latent-volatility model whose variance is independent of the mean coefficients conditional on its latent state. This preserves a tractable coefficient conditional and a valid collapsed architecture target.

A proposed first model is

$$
y_t\mid\theta,m,P,\sigma^2,\gamma,u_t,\omega
\sim N\!\left(X_{m,P,t}\theta,\sigma^2\exp(w_t^\top\gamma+\omega u_t)\right),
$$

$$
u_1\sim N(0,1),\qquad
u_t=\phi u_{t-1}+\sqrt{1-\phi^2}\,\xi_t,\qquad \xi_t\sim N(0,1).
$$

Here the initial subscript denotes the first scored training row, not the first retained DGP observation. Use stationary initialization there. Set $(\phi+1)/2\sim\operatorname{Beta}(10,1.5)$ and $\omega\sim\operatorname{HalfNormal}(0,0.5^2)$ as proposed development priors. Parameterizing by stationary log-volatility SD $\omega$ avoids forcing that marginal SD to diverge as persistence approaches one. This is a design proposal to validate, not an optimal prior inferred from the held-out data.

Retain $\sigma^2\sim\operatorname{IG}(3,1)$. Begin with $w_t^\top\gamma=0$. A separate seasonal-volatility ablation may add centered Fourier terms, with a proper Gaussian prior and the period convention declared. No duplicate variance intercept is allowed. The Gaussian mean priors remain independent of $\sigma^2$. The exact homoscedastic configuration fixes $\omega=0$ and $\gamma=0$ and must recover the original target. A continuous prior at zero is not a posterior point mass on that submodel.

For that optional ablation, propose four Fourier harmonics at the mean model's period, with independent variance coefficients $\gamma_{k,\sin},\gamma_{k,\cos}\sim N(0,0.25^2/[1+(k/2)^4])$. Center the deterministic columns using training timestamps and hold those centers fixed. A period move changes the variance design as well as the mean design, so its likelihood must recompute both. These controls undergo prior-predictive checking and are frozen before the ablation is fitted.

This model intentionally does not reproduce the NHS1 GJR mechanism exactly. It may capture persistence but miss shock-sign asymmetry and state-dependent volatility. Assess both matched SV simulations and misspecified GJR simulations. If leverage remains important after mean repair, a later GJR/leverage extension needs a new derivation and independent validation; it is not a tuning adjustment to this model.

Given volatility, set $D=\sigma^2\operatorname{diag}\{\exp(w_t^\top\gamma+\omega u_t)\}$ and use the Gaussian formulas in G1. In contrast, residual-based GARCH makes $D$ depend on $\theta$. Then the stated Gaussian coefficient conditional and integrated likelihood generally do not apply. A residual plug-in volatility estimate is not a joint Bayesian implementation.

\newpage

# Gate G3: inference, computation, and state forecasting

A valid first sampler alternates: conditional collapsed architecture/period moves; an immediate matching Gaussian coefficient draw; conditional volatility-state updates; scale/persistence updates; and normalized RHS updates. Write the exact ordering and conditionals before coding. Given mean coefficients and volatility effects,

$$
\sigma^2\mid\cdots\sim\operatorname{IG}\left(3+n/2,
1+\tfrac12\sum_t(y_t-X_t\theta)^2\exp(-w_t^\top\gamma-\omega u_t)\right).
$$

Elliptical slice sampling provides an exact candidate update for the Gaussian-prior vector $u$ conditional on $\phi$ [R4]. Draw its auxiliary AR(1) Gaussian path in linear time. Include normalized AR(1) transition/initial densities and parameter-transform Jacobians when updating $\phi$ or changing parameterization. Centered/noncentered interweaving is a later validated efficiency option, not an assumed speedup [R5]. Approximate log-squared-residual mixture updates require their approximation status or an exact correction to be stated.

**Important bottleneck:** changing volatility invalidates the fixed $X^\top X$ sufficient statistics used by the current homoscedastic sampler. Profile weighted products and solves on a small and then full bank. Only immutable design blocks may be cached. A covariance-state version must invalidate weighted caches. Consider C++ weighted BLAS and validated block updates if measured costs justify them; do not reuse stale cross-products or prune the bank to make an expensive fit appear feasible.

At origin $o$, preserve the agreed static posterior $\pi_{2500}(m,P,\theta,\text{scales})$ and update the conditional volatility filter for each outer parameter state. Formally, use this frozen outer posterior mixed with $p(u_o\mid y_{501:o},m,P,\theta,\text{scales})$. It is an operational frozen-parameter forecast, not the fully updated joint posterior at $o$.

The static draw includes $\phi$, $\omega$, $\gamma$, noise, shrinkage scales, architecture and period jointly; these components must not be sampled independently from their marginal summaries. Filter normalization is conditional on that complete static draw and does not change its outer weight.

Initialize that conditional filter consistently at 2500. Cloning one sampled terminal volatility state into many particles does not recover its conditional uncertainty. A valid proposed implementation replays a conditional particle filter over the scored training observations for each selected static draw, using the written stationary initial law. Compare against independent state samplers on small cases. Proposed filter-size sensitivity is 256/1,024/4,096 particles, with ESS, degeneracy, repeated-seed, and stability checks.

For each future path sample the origin state from its filter, then simulate future volatility and responses recursively. Update observed states using $y_{o+1}$ only after issuing the forecast at $o$. Do not use future squared residuals or smoothed volatility from later observations. A fully reweighted sequential posterior would require parameter/architecture weight updates and is a separate experiment.

\newpage

# Independent validation requirements

Validation should falsify plausible errors rather than mirror the implementation. Use an independently written R reference before extending C++. A second implementation using the same internal helper is not independent evidence.

| Layer | Required independent check | Failure that must be caught |
|---|---|---|
| Normalization | Integrate one/two-dimensional priors; compare normalized multivariate densities | Missing scale factors or augmented-prior constants |
| Gaussian integral | Compare prior-whitened, $n$-space covariance, and direct quadrature on small cases | Missing intercept/calendar determinants or wrong variance convention |
| Coefficient draw | Empirical moments/linear contrasts versus exact conditional covariance | Cholesky orientation or coefficient transport error |
| RHS scales | Conditional quadrature and empirical CDFs for local/global/slab updates | Naive inverse-gamma update under the finite slab |
| Architecture/period | Exhaustive finite-state probabilities, ordered MH ratios, pairwise detailed balance | Missing proposal normalization, period mass, or dimension term |
| Product space | Change inactive embedding and compare marginal posteriors | Inactive-coordinate normalizers or index collisions |
| Partial collapse | Compare valid full-state and collapsed samplers on tiny targets | Stale coefficients after a model change |
| Volatility | Low-dimensional state integration and independent sampler | Incorrect stationary initialization or AR(1) determinant |
| Filtering | Particle filter versus grid/quadrature and particle-number limits | Lost initial-state uncertainty or filter weight errors |
| Forecasts | Future perturbation, prefix invariance, hand recursion, raw/scaled equality | Teacher forcing, future PCA/scaling, calendar shift, or variance leakage |
| R/C++ | Shared externally generated innovations plus independent target values | RNG/order masking an algebraic mismatch |
| Compatibility | Disabled options reproduce stored ridge/RHS results | An opt-in extension silently changes the default model |

Proposed deterministic tolerances: 1e-10 relative/absolute for well-conditioned log densities and Gaussian summaries, and 1e-8 for deliberately stressed cases, with condition-aware justification when tighter accuracy is impossible. For stochastic moments use independent-run Monte Carlo SE and predeclared simultaneous checks; do not require exact RNG agreement between unrelated algorithms.

Stress intercept-only cases, no seasonal block, constant/duplicate columns, rank-deficient designs with proper priors, large and small local scales, near-zero slab variance, highly persistent volatility, and periods whose phases repeat poorly in the training sample. Numerical failure must name its state and cause, not silently remove a model. Verify exact recovery of the homoscedastic target when volatility is disabled, separately from bitwise RNG compatibility of an unchanged code path.

\newpage

# Calibration tests and their limits

Run small-problem simulation-based calibration before long production fits [R7]. Proposed first batch: 200 prior-predictive replications with sufficiently accurate conditional/posterior samples. Use simultaneous rank envelopes and diagnose structured deviations; absence of rejection is not proof of correctness. Repeat targeted stress settings only as separately labeled recovery/reference tests, not as generic prior SBC.

For discrete architecture and period states, use randomized posterior-CDF ranks in a fixed declared ordering, indicator calibration, and predictive functionals. The ordering is a technical device and should be varied as a sensitivity check. Include the joint likelihood and other data-dependent test quantities, since marginal-parameter SBC alone can miss important computational defects [R8]. Handle serially correlated posterior samples through adequate ESS and independent-run checks rather than assume every retained draw is independent.

Two calibration experiments are distinct. **Fixed-design SBC** freezes all candidate matrices, draws the proper model/scales/coefficients, simulates responses from the stated conditional Gaussian model, and verifies its conditional sampler. This directly tests the Gaussian/RHS/architecture algebra.

**Recursive-model SBC** requires a generative causal feature map whose response/input transformations, projection matrices, and readout scalers are fixed independently of the responses being generated. An independent calibration prefix or independently generated calibration sequence can supply them. Then simulate and reconstruct all candidate paths using only each generated past. This checks the intended recursive model under that explicitly frozen map.

The production pipeline estimates transformations from the observed training sequence. Its frozen-bank posterior is a conditional analysis with data-adaptive preprocessing. Fixed-design SBC does not establish unconditional calibration of that whole workflow. Re-estimating transformations from each SBC response while pretending they were exogenous changes the generative target. Either model that preprocessing explicitly or keep the scope of the calibration claim limited and use independent-DGP predictive evaluation for the full production pipeline. This observation does not itself show future leakage: training-adaptive preprocessing can be causally valid for held-out forecasts.

A matched SV data generator can verify state inference. On a latent-volatility DGP, a true terminal latent state is not generally available from observed history. The principal oracle must filter/integrate that uncertainty using only observed information. A full-state oracle is a separate privileged diagnostic. The NHS1 GJR state, recoverable from observed history under the known DGP, has a different information status.

**Calibration exit:** independent reference identities pass; SBC shows no material explained or unexplained systematic defect at its available resolution; all failure patterns and finite Monte Carlo uncertainty are reported. Model adequacy still requires predictive checks and fresh forecasts.

\newpage

# Posterior qualification and budget ladders

Use at least four overdispersed chains for each new DESN target, including different architecture/period starts and scale regimes. Preserve existing normalized local/global interweaving and frozen full-support joint proposals where valid. Train proposals only on training pilots; discard pilot draws from production summaries. Do not alter the proposal from held-out performance.

Proposed homoscedastic retained budgets per chain are 32k, 128k, and 256k, with corresponding fresh-chain warmups of 8k, 32k, and 64k. These are an initial escalation policy, not evidence that any level will suffice. After the full-bank feasibility pilot, freeze a memory/wall-time cap and a continuation versus fresh-restart policy. Treat SV separately because its per-iteration cost differs substantially. Record every attempt and the cost of proposal training.

Proposed qualification thresholds, informed by modern rank diagnostics [R6], are rank-normalized split/folded R-hat at most 1.01; bulk and tail ESS at least 400 for monitored continuous functionals; and Monte Carlo SE small relative to each reported effect. Monitor noise/global/slab scales, group norms, conditional edf, fitted means at fixed training probes, predictive quantiles, architecture/period indicators, and grouped depth/lag/period masses. Coefficients from incompatible architectures are not the same estimand.

For categories with estimated mass at least 1%, target posterior-probability MCSE at most 0.01 and investigate chain-frequency discrepancies above 0.03. Use Rao-Blackwellized probabilities where available. A category unvisited in every chain is not demonstrated to have zero posterior mass. Require deliberately dispersed starts, full-support proposals, small-target exact references, and targeted mode checks in addition to occupancy diagnostics.

Two successive qualified budgets should agree within both reported Monte Carlo uncertainty and practical tolerances: training-probe means 0.01 response SD; predictive SDs 2%; and major architecture/period masses 0.02. If a tolerance is not estimable at a capped budget, label the quantity unresolved. Fixed chain counts and diagnostic thresholds cannot guarantee global convergence.

Predictive Monte Carlo sensitivity varies outer posterior draws and inner innovations separately: proposed outer counts 192/384/768 and inner paths 8/32/128. Start on a fixed training-validation panel of 12 origins, then select the smallest budget meeting an MCSE target before confirmation. Do not claim 384 outer draws suffice merely because they worked for an earlier target. If 768 is insufficient, expand according to a recorded computational rule without looking for a favorable test ranking.

Do not infer posterior convergence from unit tests, low acceptance alone, or stable RMSE on one series. Qualification must precede confirmatory forecasting.

\newpage

# Ordered development experiments

Each row changes one main mechanism. Development uses the original series and any newly designated development seeds, with training-only family decisions. Known-period rows remain labeled as privileged.

| ID | Mean/prior/inference change | Question |
|---|---|---|
| D0 | Exact original ridge, requested RHS, native GP references | Can the baseline be reconstructed? |
| D1 | F1 direct lags, flat RHS with requested controls | Does preserving raw lag information help? |
| D2 | F2 with unknown period, flat RHS | Is nonsinusoidal seasonal representation useful without oracle period input? |
| D2K | Known-period F2 ablation | How much does supplied calendar information explain? |
| D3 | Grouped normalized prior at fixed F2 | Does prior geometry improve over a common shrinkage block? |
| D4 | Ridge at fixed selected augmented feature family | Is an apparent gain specific to RHS? |
| G1 | Native GP target, larger SMC budget | Was budget alone the limiting factor? |
| G2 | Native GP target, valid targeted proposals | Is remaining failure proposal-related? |
| G3 | Separately named raw-time period prior sensitivity | How much do prior assumptions matter? |
| V1 | Qualified augmented RHS plus nonseasonal SV | Does dynamic variance improve calibration and proper scores? |
| V2 | V1 plus seasonal volatility | Is there additional predictable variance seasonality? |

Only after D1-D3 fail to reduce a meaningful mean gap despite adequate inference should a bounded reservoir expansion be considered. Define new width/leak/memory settings from training diagnostics, reuse paired seeds where possible, and balance architecture-family prior mass so adding more seeds or grid cells does not manufacture posterior preference. Preserve the old bank as a separate target. Do not call random reservoir seeds independent DGP replications.

Do not expand every axis by a large Cartesian grid. A wider/deeper bank is a second-stage ablation, not the default repair. A GP on lagged inputs would similarly be a different nonlinear autoregressive model, not a small tuning change to native time-indexed AutoGP. Hold it as a contingency if the repaired native grammar remains inadequate.

Freeze the promoted feature/prior family using the declared validation rule. Model failure is itself reportable; if F1 helps but F2 is computationally unresolved, an F1 release can be qualified without implying unknown-period discovery has been solved. Do not replace unresolved Bayesian averaging with the best diagnostic point fit.

\newpage

# Independent confirmation and simulation design

Structure simulation reporting by aims, DGPs, estimands, methods, and performance measures [R10]. The existing NHS1 series cannot become confirmatory again. Avoid selecting an attractive replacement seed or presenting overlapping rolling pairs as independent replications.

**Confirmation A:** reserve 30 independent NHS1 realizations, proposed DGP seeds $2766020+r$, $r=1,\ldots,30$. Freeze the methods and computational policies before generating/unblinding their held-out segments. Compare original requested RHS, promoted automatic augmented RHS, original native AutoGP, and repaired native AutoGP. Include augmented ridge and a generic train-selected direct-lag reference as additional comparators. Keep the original temporal protocol within every realization.

The primary comparisons are augmented versus original RHS for mean improvement, and repaired versus original AutoGP for exploration improvement. The repaired same-prior GP is the main computational contrast; a changed-prior GP must have a separate row. Known-calendar models form a separate information track, not a hidden advantage in the automatic primary comparison.

**Confirmation B:** reserve another 30 independent realizations for the selected augmented mean model with versus without the qualified volatility component. Freeze this design before seeing these new held-out outcomes. Distinct seeds are necessary if mean-confirmation results influence the volatility design. If all targets are frozen before either study is unblinded, a common predeclared replication block can instead support paired contrasts, with its multiple comparisons and shared data explicitly stated.

**Stress studies:** propose 10 independent replications per cell: the same nonlinear mean with constant noise; matched latent SV; and the NHS1-style mechanism at periods 42 and 84. For changed periods, explicitly replace the seasonal phase, seasonal lag $P$, and sub-seasonal lag by $\operatorname{round}(P/5)$, with the full generator checked and recorded. Choose simulation burn-in as a sufficiently long declared multiple of the period, with distributional sensitivity checked on development simulations. Verify bounds/stability after each generator change. These are new custom DGPs, not published benchmark reproductions.

For reproducibility, the proposed constant-noise variance is $0.45^2$. The matched-volatility stress cell uses $\sigma^2=0.45^2$, $\phi=0.95$, $\omega=0.5$, and no seasonal variance term, with the unchanged nonlinear mean; only its variance mechanism is matched to SV. For changed periods, define the short seasonal block through fractional phase $\{5(t-1)/P\}<1/3$, rather than an unrelated rounded-integer block period. This preserves a $P$-periodic calendar and recovers the original block at $P=60$. Give each stress cell a disjoint seed namespace, proposed seeds $3766020+1000c+r$ for cell $c=1,\ldots,4$ and replication $r=1,\ldots,10$; reserve $3266020+r$ for Confirmation B. None of these proposed series is generated during planning.

The 30/10 counts are pragmatic proposed budgets, not universal power guarantees. Compute paired-score uncertainty from development pilots and assess feasibility before committing. If fixed confirmation is imprecise, report inconclusiveness. Do not keep adding replications until significance appears; register a separate extension with fresh seeds. If resources cannot support the proposed blocks, preserve the smaller executed study and explicitly restrict its claims.

Model truth, oracle outputs, DGP coefficients, and latent innovations never select parameters or posterior states. All methods receive identical observed prefixes and the declared information track. Independent oracle simulations assess conditional risk without becoming extra DGP replications.

\newpage

# Scoring, uncertainty, and scientific promotion

Report RMSE and MAE by horizon and pooled, CRPS, NLL, 50%/90% coverage and widths, interval scores, and residual/PIT diagnostics. Preserve historical MAE-of-predictive-mean for comparability; additionally label median-based MAE if the absolute-loss optimal forecast is evaluated. Separate one-step conditional-mean fits from multi-step forecasts and from training-location GP smoothing.

Use the same origin/horizon weighting for all models. Primary horizon summaries are pooled, H1, H7, H14, and H30; all 30 horizons remain available. Marginal predictive scores do not establish a coherent multivariate trajectory law. If path dependence is claimed, add a separately specified joint/path diagnostic.

For density evaluation use final-step conditional Gaussian mixtures with stable log-sum-exp, integrating the simulated preceding path. This Rao-Blackwellization avoids kernel-density estimation of simulated terminal responses. Apply the response-scale Jacobian: if $y=a+sz$, then $\operatorname{NLL}_y=\operatorname{NLL}_z+\log s$. Predictive quantiles must come from the actual mixture/paths, not a fitted moment Gaussian. Proper scoring rules assess sharpness jointly with calibration [R9].

For CRPS, account for shared outer posterior draws and nested inner paths. A naive iid U-statistic over all nested paths need not have its claimed unbiasedness. Use cross-outer-group pairs or the explicitly defined empirical-mixture score, and measure remaining autocorrelation/finite-sample bias through independent computational replicates. NLL has finite-Monte-Carlo log bias; budget stability is required rather than an unsupported unbiasedness claim.

On simulated data also report average conditional mean squared error against an information-matched oracle, the average conditional variance, and their expected-risk sum. Correct estimated squared oracle-mean discrepancies for oracle MC variance when appropriate; retain untruncated estimates for inference, allowing clipping only for an explicitly labeled square-root display. A realized error sample does not obey the conditional-risk decomposition exactly.

Aggregate each score within each DGP realization first. Compare paired realization-level differences and report their mean, SD, MCSE, and 95% interval; use paired bootstrap sensitivity. Never use 14,130 as the independent sample size. Treat horizon comparisons as a family and avoid unadjusted horizon-by-horizon significance claims.

Proposed practical targets to freeze in G0: at least 5% relative mean MSE reduction for the augmented mean model, at least 2% CRPS reduction for a volatility extension, and reduced low/high-volatility coverage imbalance without winning by indiscriminate interval widening. These are scientific goals, not mathematical correctness gates. If intervals are wide or improvements smaller, report that result. A non-improving model can still be correctly implemented; it must not be promoted as a performance solution.

\newpage

# Resource feasibility and performance engineering

The observed environment has an 8 GiB memory limit, project-local R/Julia, and restricted parallelism. Do not promise a completion date from iteration counts. Recover actual original runtimes and measure the changed per-iteration costs on training-only pilots. New SV weighted regressions and per-parameter state filters can dominate costs even when reservoir construction is unchanged.

Use a bounded feasibility ladder: small exact-reference problems; 2,000-row representative single models; then the full declared bank and one full training-validation forecast panel. Measure median and tail step costs, weighted factorization counts, ESS per second, filter initialization cost, per-origin state updates, and peak process/process-tree RSS. Label unmeasured memory and noisy process-level peaks honestly.

Forecast storage should stream summaries, reproducible innovations/seeds, selected raw-path snapshots, and resumable posterior/state checkpoints. A 471 by 30 by 768 by 128 double array is about 10.35 GiB before copies, so the highest predictive sensitivity cannot be materialized globally in this environment. Stream origins and outer groups. Keep prediction seeds, draw indices, model/period assignments, and cache keys sufficient for exact replay.

Suggested implementation order is readable R reference, profiling, then C++ only for measured bottlenecks: weighted cross-products/Cholesky, batched reservoir recursion, repeated scoring, or AR(1) path generation. Avoid first implementing every extension twice. Preserve independent reference checks after optimization. Numerical agreement is not a full-study speedup claim.

Use BLAS thread limits and sequential large jobs unless measured headroom supports parallelism. Parallelize independent small integrity checks rather than duplicate large banks. Report shared reservoir construction once; then feature/period block preparation, proposal training, all failed and successful inference attempts, state-filter initialization, per-origin state updates, forecast simulation/scoring, compilation, I/O, and peak memory as separate scopes.

For a replication count $R$, estimate total compute from measured shared costs plus $R$ times scenario-specific costs, including unsuccessful qualification attempts and MC sensitivity. Compare both accuracy-qualified models and predeclared compute caps. If memory or runtime makes a gate infeasible, stop that branch, preserve its evidence, and explain the limitation. Do not alter priors, drop architectures, reduce confirmation counts after inspecting scores, or claim a job is running without an observed process.

Optimize exact computation before approximating the posterior. Any alternative using sparsity, a low-rank representation, or an approximate likelihood needs a separate target label, approximation-error study, and predictive comparison.

\newpage

# Software map, API, and delivery sequence

The following are proposed touch points, not edits already made. Keep defaults unchanged and version fit objects/checkpoints when new state is introduced.

| Area | Current code | Proposed responsibility |
|---|---|---|
| Feature bank and public fit | `R/autodesn.R` | Opt-in readout blocks, period state, model identity and forecast dispatch |
| Scaling and coefficient transport | `R/autodesn_scaling.R` | Common/architecture-specific semantic blocks and exact raw-coordinate mapping |
| Normalized RHS | `R/autodesn_rhs.R` | Group controls, fixed-space indexing, normalized scale updates |
| Frozen joint proposals | `R/autodesn_rhs_joint.R` | Dimension-general derivation and valid group/period proposals |
| Gaussian reference | `R/autodesn_gaussian.R` | Weighted conditional/evidence reference without changing legacy path |
| Optimized operations | `src/autodesn_rhs.cpp` | Only bottlenecks established by profiling |
| Diagnostics | `R/autodesn_diagnostics.R` | Function-space, grouped-scale, period and volatility diagnostics |
| Native GP integration | Existing pinned driver plus explicit patch/vendor record | Same-target search experiments, native trace tests and budgets |
| Experiments | A new versioned validation directory | Development, confirmation, protected truth, scoring and checkpoint registry |

Proposed API concepts are `readout_control`, `seasonal_control`, and `variance_control` with explicit named lists, validation, and no silent unknown arguments. A user must be able to select legacy reservoir-only behavior, add direct lags, specify known versus inferred period, choose flat versus grouped shrinkage, and select constant versus SV variance. These are interface requirements, not a promise of final argument names. Do not overload `normalize_features` to mean standardization, grouping, or whitening.

Every fit should expose its likelihood, prior family, feature basis, information track, period policy, variance policy, architecture prior, posterior qualification status, executed source hashes, and forecast-conditioning policy. New feature/variance options disabled must preserve the old regression fixtures and public return structures.

Deliver as independently reviewable changes: P0, specification/provenance; P1, readout blocks and exact Gaussian references; P2, grouped/period inference; P3, native GP search repair; P4, weighted SV sampler and filtering; P5, frozen experiment protocol; P6, completed results/report. Each change needs its own mathematical notes and validation evidence. Keep draft PRs unmerged until review; do not mix an unqualified SV experiment into the qualified homoscedastic release.

Archive sources, exact configs, environment locks, failure logs, seeds, numeric scores, posterior/state diagnostics, and a final report with checksum-verified restoration. Mark status as planned, implemented, validated, qualified, forecast-complete, or blocked. Preparing a launcher is not execution.

\newpage

# Adversarial review and stop rules

Before implementation is approved, an independent reviewer should be able to answer all of the following from the specification alone. These are proposed review questions; no separate reviewer has been invoked for this planning task.

1. Can the reviewer write the normalized joint density for every declared model and identify every data-derived transformation?
2. Are coefficient priors independent of observation variance, and is the intercept proper?
3. Do variable dimensions, Gaussian normalizers, period-support masses, inactive coordinates, and transformed scale priors all appear in architecture ratios?
4. Does a coefficient redraw immediately follow a collapsed model move?
5. Are equivalent GP syntax trees only grouped for diagnostics, with native prior multiplicity preserved in inference?
6. Are targeted GP proposals correctly weighted, and are optimized states prevented from becoming unweighted pseudo-posterior particles?
7. Does volatility preserve the claimed Gaussian conditional, or has residual dependence invalidated it?
8. Is the initial volatility state uncertain, with a causal filter rather than future smoothing or cloning a single state?
9. Is frozen-parameter state conditioning distinguished from full sequential Bayesian updating?
10. Are preprocessing, PCA, admission, hyperparameter decisions, and proposal training inside the relevant training boundary?
11. Are known period, DGP-specific lags, oracle means, and latent states explicitly labeled wherever used?
12. Are numerical correctness, sampler qualification, model adequacy, and independent confirmation assessed separately?
13. Does SBC target the actual stated conditional/generative model, with meaningful data-dependent quantities and discrete-state handling?
14. Are dependent rolling pairs and computational paths excluded from the independent replication count?
15. Do proper scores and conditional calibration prevent a nominal coverage improvement obtained only by widening intervals?
16. Are exact reference identities, failed budgets, computational costs, source hashes, and archive replay independently inspectable?

Stop and correct the specification if any answer is ambiguous. Stop a numerical branch if its reference target disagrees. Do not issue confirmatory forecasts from an unqualified posterior. Stop target-changing development before confirmation unblinding; subsequent redesign requires new confirmatory data. At a resource cap, report the unresolved objective rather than waive its gate.

The completion report must distinguish resolved mean representation, resolved GP exploration to the measured resolution, qualified conditional variance, and independent predictive confirmation. It must identify any objective still blocked. No claim of universal superiority or complete posterior convergence is permitted. The irreducible oracle gap remains part of the expected outcome even after a successful repair.

\newpage

# Sources and evidence trail

**Local primary evidence.** Starting revision `4916600928337f1ef179fda6100f54c20723bd9a`; original `RESULTS.md`, `DGP.md`, executed provenance, and `audit/README.md`; original and audit checksum manifests. Relevant R/C++ and pinned native Julia files were inspected for this plan. Draft PR: <https://github.com/AntonioAPDL/exdqlm/pull/4>. The evidence establishes the baseline and conditional-model conventions; it does not validate future extensions.

**[R1] Piironen and Vehtari (2017).** Sparsity information and regularization in the horseshoe and other shrinkage priors. Electronic Journal of Statistics 11(2), 5018-5051. <https://arxiv.org/abs/1707.01694>. Supports the finite-slab regularized horseshoe and the separation of sparsity from large-coefficient regularization. Grouping and architecture/volatility extensions here are proposed derivations, not results established by that paper.

**[R2] McDermott and Wikle (2019; preprint 2018).** Deep echo state networks with uncertainty quantification for spatio-temporal forecasting. Environmetrics. <https://arxiv.org/abs/1806.10728>. Background for deep reservoir constructions and uncertainty; it does not guarantee capacity or calibration for this finite bank.

**[R3] Del Moral, Doucet, and Jasra (2006).** Sequential Monte Carlo samplers. JRSS B 68(3), 411-436. <https://doi.org/10.1111/j.1467-9868.2006.00553.x>. Reference for weighted population samplers and invariant transitions; implementation-specific guarantees require the actual proposal/weight derivation.

**[R4] Murray, Adams, and MacKay (2010).** Elliptical slice sampling. AISTATS, PMLR 9, 541-548. <https://proceedings.mlr.press/v9/murray10a.html>. Reference for Gaussian-prior latent-vector transitions used as a proposed exact SV update.

**[R5] Kastner and Frühwirth-Schnatter (2014).** Ancillarity-sufficiency interweaving strategy for boosting MCMC estimation of stochastic volatility models. Computational Statistics & Data Analysis 76, 408-423. <https://arxiv.org/abs/1706.05280>. Motivates testing parameterization/interweaving efficiency; no speedup is assumed for this new sampler.

**[R6] Vehtari et al. (2021).** Rank-normalization, folding, and localization: an improved R-hat for assessing convergence of MCMC. Bayesian Analysis 16(2), 667-718. <https://arxiv.org/abs/1903.08008>. Basis for rank/folded diagnostics and local efficiency measures; thresholds are operational, not proofs of convergence.

**[R7] Talts et al. (2018/2020).** Validating Bayesian inference algorithms with simulation-based calibration. <https://arxiv.org/abs/1804.06788>. Supports prior-predictive calibration of computation and its distinction from model adequacy.

**[R8] Modrák et al. (2025).** Simulation-based calibration checking for Bayesian computation: the choice of test quantities shapes sensitivity. Bayesian Analysis 20(2). <https://doi.org/10.1214/23-BA1404>. Supports inclusion of data-dependent test quantities, particularly likelihood-based checks.

**[R9] Gneiting and Raftery (2007).** Strictly proper scoring rules, prediction, and estimation. JASA 102(477), 359-378. <https://doi.org/10.1198/016214506000001437>. Supports evaluating probabilistic forecasts using proper scores, with calibration and sharpness considered jointly.

**[R10] Morris, White, and Crowther (2019).** Using simulation studies to evaluate statistical methods. Statistics in Medicine 38, 2074-2102. <https://doi.org/10.1002/sim.8086>. Supports explicit aims/DGPs/estimands/methods/performance measures and Monte Carlo uncertainty reporting.

**[R11] Gelman et al. (2020).** Bayesian workflow. <https://arxiv.org/abs/2011.01808>. Supports iterative model construction, computational checking, and predictive assessment as distinct tasks.

**[R12] AutoGP authors' implementation.** <https://github.com/probsys/AutoGP.jl>, pinned source `2ad372db2b8bea176e3b32a769bfb5d6cff80866`. The plan used local `Model.jl`, native SMC/rejuvenation code, and the executed driver. Public documentation access was intermittent; pinned executed code takes precedence for this task.

All references were checked during planning on 23 October 2026 (America/Los_Angeles). They motivate methods and limitations. Numerical audit claims come from the project's executed evidence, and the proposed model/acceptance criteria are the author's planning decisions.
