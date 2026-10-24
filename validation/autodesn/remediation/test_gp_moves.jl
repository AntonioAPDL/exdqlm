using AutoGP,Gen,LinearAlgebra,Random,TOML,Distributions
include("gp_moves.jl");using .RemediationGPMoves
BLAS.set_num_threads(1);Random.seed!(2266021)
G=AutoGP.GP;config=G.GPConfig(max_depth=4);ts=collect(range(0,1,length=12));ys=.2sin.(12ts)
node=G.Plus(G.Periodic(.5,.08,.2),G.GammaExponential(.1,1.,.3))
tr=AutoGP.Inference.node_to_trace(node,config,ts,ys,.1)
centers=[-2.,0.,1.];moves=100;accepted=0
for i in 1:moves
 global tr,accepted
 tr,a,r=period_refresh(tr,centers);accepted+=a
 @assert isfinite(r)
end
# Direct pairwise balance under two normal-coordinate states with native scores.
original=tr;address=first([a for (a,v) in Gen.get_values_shallow(Gen.get_submap(Gen.get_choices(tr),:tree)) if a[2]==:period]);x=tr[:tree=>address];z=x+.8
cm=Gen.choicemap();cm[:tree=>address]=z
candidate,w,_,_=Gen.update(tr,Gen.get_args(tr),Tuple(Gen.NoChange() for a in Gen.get_args(tr)),cm)
a=Gen.get_score(tr);b=Gen.get_score(candidate);qx=log_proposal(x,centers);qz=log_proposal(z,centers)
r=b-a+qx-qz
left=a+qz+min(0.,r);right=b+qx+min(0.,-r)
@assert abs(left-right)<1e-10
@assert abs(w-(b-a))<1e-10
out=Dict("complete"=>true,"native_target_unchanged"=>true,"trace_updates"=>moves,"accepted"=>accepted,"detailed_balance_error"=>abs(left-right),"update_weight_error"=>abs(w-(b-a)),"posterior_qualified"=>false)
open("validation/autodesn/remediation/evidence/gp_moves_tests.toml","w") do io;TOML.print(io,out);end
println(out)
