# Original288 Dynamic TT5000 Post-Fix Repair Plan

## Objective

Repair the unresolved dynamic `TT5000` comparison hole under the corrected
package state, without rerunning the entire validation study.

## Why This Is The Right Next Step

- static comparison work is already complete
- the unresolved pocket is only the dynamic `TT5000` block
- the old narrow repair lane was scientifically negative before the package
  root-cause fixes landed
- the validation checkout now carries those package fixes and a smoke-gated
  rerun stack

## Deliverables

1. isolated post-fix smoke over representative dynamic `TT5000` rows
2. fresh, separately tagged narrow repair rerun
3. refreshed repaired selection and comparison outputs after the rerun

## Guardrails

- no broad `288`-row relaunch
- no generic config replacement
- preserve exact row-level specs first
- preserve historical row-local repair controls second
- keep documentation current as soon as the rerun is launched and again when it
  finishes
