# QDESN Tau050 Post-Recovery Next Steps

Date: `2026-04-21`  
Status: recommended forward path after full failed-run recovery closeout

## Current State

The tau050 failed-run recovery is complete:

- original hard crash surface: `23`
- recovered now: `23`
- unresolved hard crashes: `0`

That means there is no remaining tau050 failed-run rerun to launch.

The right next move is not more repair compute. It is to freeze the lessons into the workflow and make future runs cheaper to recover.

## Recommended Next Steps

### 1. Freeze `ladder_v2` as the standard precision rescue

This should now be the default response for future runs that show the same precision-Cholesky failure family.

Recommended rule:

| Failure family | First response | Escalation |
|---|---|---|
| latent-`v` invalid-draw failures | existing run-specific latent-state recovery baseline | additional targeted rescue only if needed |
| beta-precision / Cholesky failures | `precision_beta = "ladder_v2"` | `precision_beta = "eigen_v1"` |

Practical interpretation:

- `ladder_v2` is now the normal precision rescue
- `eigen_v1` stays available, but should be treated as escalation, not default
- `ladder_v1` should not be reused

### 2. Keep the run-specific recovery philosophy

The strongest lesson from the whole program is still:

- classify failures by mechanism first
- relaunch by cluster
- do not assume one global spec will recover all failed runs efficiently

That philosophy should stay in place for future campaigns.

### 3. Do not broaden precision rescue blindly

Even though `ladder_v2` won, the evidence comes from the hardest precision pair. So the right promotion style is:

- use it proactively for surfaces that look like the same failure family
- do not automatically rewrite every MCMC job in the repo to use precision rescue unless that is a deliberate product decision later

The current evidence supports:

- default rescue for future similar precision failures
- not necessarily a universal always-on global change

### 4. Use the closeout package as the new reproducible template

For future hard residual pair repairs, the model we now have is good:

1. narrow the unresolved surface
2. do a small matrix to choose a winner
3. productize the winner
4. run a tiny canonical closeout rerun
5. keep the stronger fallback prepared only

That sequence gave a clean engineering and scientific story, and it kept wasted compute low.

### 5. Keep the healthcheck improvement

The dynamic healthcheck now tolerates empty/placeholder campaign tables instead of crashing after a successful completed run.

That should remain, because it makes closeout-state monitoring more trustworthy and reduces confusion at the end of a campaign.

## Suggested Immediate Follow-Up Work

These are the best next tasks now that the failed-run recovery is done.

### Option A: Recovery playbook consolidation

Create one concise internal playbook that maps:

- failure family
- diagnostic signature
- default intervention
- fallback intervention

This would make future recovery work faster and less ad hoc.

### Option B: Broader prophylactic evaluation

Run a small non-urgent screen to see whether `precision_beta = "ladder_v2"` should be turned on proactively for a broader high-risk class, for example:

- long-window ridge MCMC fits
- high-`tau`, high-stress laplace surfaces

This would not be a recovery task. It would be a preventive hardening task.

### Option C: General campaign finalization

If the next goal is beyond tau050 recovery itself, the natural move is to shift from repair engineering back to:

- broader campaign interpretation
- result comparison
- final analysis/reporting

## What I Recommend Now

The best immediate next move is:

1. stop launching more repair waves for tau050
2. freeze `ladder_v2` as the recommended precision rescue
3. keep `eigen_v1` as the fallback
4. write or maintain a small recovery playbook so the same logic is easy to reuse

If we want one concrete follow-on task after this, I would choose:

- **build the reusable recovery playbook**

That gives the most value per unit of effort now that the actual failed-run recovery is complete.
