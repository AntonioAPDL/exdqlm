\name{qdesn_residual_ablation}
\alias{qdesn_residual_ablation_candidates}
\alias{qdesn_residual_ablation_protocol}
\alias{qdesn_run_residual_ablation}
\title{Focused single-origin residual Q-DESN ablation}
\description{
Runs a paired comparison of the current Q-DESN and an inter-layer residual
Q-DESN on a simulated series of length 1100. Only reservoir depth, common
width, output-lag count, leak, and spectral radius are selected.
}
\usage{
qdesn_residual_ablation_candidates()

qdesn_residual_ablation_protocol()

qdesn_run_residual_ablation(
  y, output_dir,
  candidates = qdesn_residual_ablation_candidates(),
  tau0 = 0.1, p_vec = c(0.5, 0.75, 0.95),
  screening_seeds = c(1101L, 1102L),
  confirmation_seeds = c(1201L, 1202L, 1203L, 1204L),
  final_seeds = 1301:1310,
  nd_screen = 400L, nd_confirm = 1000L, nd_final = 2000L,
  skip_scale = 1, vb_control = list(),
  confirmation_top_per_architecture = 2L,
  near_tie_fraction = 0.01,
  residual_retuned_min_validation_gain = 0.01,
  minimum_median_improvement_percent = 2,
  minimum_seed_wins = 7L,
  maximum_quantile_degradation_percent = 5,
  forgetting_tolerance = 1e-6,
  workers = 1L, resume = TRUE, quick = FALSE
)
}
\arguments{
  \item{y}{Finite numeric series containing at least 1100 observations.}
  \item{output_dir}{Directory for checkpoints, tables, figures, and results.}
  \item{candidates}{Pre-specified candidate table.}
  \item{tau0}{Fixed RHS-NS global scale. The authoritative default is 0.1.}
  \item{p_vec}{Target quantiles; fixed to 0.50, 0.75, and 0.95.}
  \item{screening_seeds, confirmation_seeds, final_seeds}{Disjoint paired
  reservoir-seed sets.}
  \item{nd_screen, nd_confirm, nd_final}{Posterior-predictive path counts.}
  \item{skip_scale}{Fixed residual-path multiplier.}
  \item{vb_control}{Optional overrides for the existing VB implementation.}
  \item{confirmation_top_per_architecture}{Number of screening candidates per
  architecture carried to confirmation.}
  \item{near_tie_fraction}{Relative score tolerance used for the deterministic
  simplicity tie-break.}
  \item{residual_retuned_min_validation_gain}{Minimum validation gain required
  to include the optional residual-specific final arm.}
  \item{minimum_median_improvement_percent}{Minimum median paired final
  improvement required to retain the residual architecture.}
  \item{minimum_seed_wins}{Minimum number of paired final reservoir seeds won
  by the residual architecture.}
  \item{maximum_quantile_degradation_percent}{Maximum allowed median
  degradation at any individual quantile.}
  \item{forgetting_tolerance}{Maximum accepted final two-initial-condition
  state discrepancy.}
  \item{workers}{Number of independent candidate-seed jobs evaluated in
  parallel on Unix-like systems.}
  \item{resume}{Whether completed cell-level RDS checkpoints are reused.}
  \item{quick}{Whether to run a reduced software smoke evaluation.}
}
\details{
The single validation origin is time 900, with targets 901--1000. After
selection, both architectures are refitted through time 1000 and evaluated
from the single final origin at time 1000 on targets 1001--1100. Observations
1--500 are reservoir washout in both stages. The likelihood is asymmetric
Laplace with shape fixed at zero, inference is variational Bayes, and the
regularized-horseshoe prior is held fixed at \code{tau0 = 0.1}.
}
\value{
The candidate and protocol functions return their fixed specifications. The
runner returns rankings, selected configurations, final paired scores, and a
pre-specified residual-retention decision; the same objects are written below
\code{output_dir}.
}
