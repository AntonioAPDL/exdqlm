# Exact additional period-parameter MH updates for the pinned native target.
# Native grammar, priors, transforms and observation model are unchanged.
module RemediationGPMoves
using AutoGP,Gen,Distributions,Random
export period_refresh,log_proposal,latent_centers
function latent_centers(model,raw_periods)
 [AutoGP.Model.untransform_param(:period,p*abs(model.ds_transform.slope),model.config) for p in raw_periods]
end
function log_proposal(z,centers;sd=.2,wide_weight=.2)
 isempty(centers)&&error("Need a nonempty training-only period proposal")
 values=vcat(log(wide_weight)+Distributions.logpdf(Normal(),z),[log1p(-wide_weight)-log(length(centers))+Distributions.logpdf(Normal(c,sd),z) for c in centers])
 hi=maximum(values);hi+log(sum(exp.(values.-hi)))
end
function period_refresh(trace,centers;sd=.2,wide_weight=.2)
 0<wide_weight<1 || error("Period mixture must have full support")
 sd>0 || error("Invalid proposal scale")
 choices=Gen.get_submap(Gen.get_choices(trace),:tree)
 addresses=[a for (a,v) in Gen.get_values_shallow(choices) if a[2]==:period]
 isempty(addresses)&&return trace,false,NaN
 address=rand(addresses);old=trace[:tree=>address]
 new=rand()<wide_weight ? randn() : rand(Normal(rand(centers),sd))
 cm=Gen.choicemap();cm[:tree=>address]=new
 args=Gen.get_args(trace);diffs=Tuple(Gen.NoChange() for a in args)
 candidate,weight,_,discard=Gen.update(trace,args,diffs,cm)
 delta=Gen.get_score(candidate)-Gen.get_score(trace)
 isapprox(weight,delta;atol=1e-8,rtol=1e-10)||error("Unexpected native trace update weight; refuse the move")
 ratio=delta+log_proposal(old,centers;sd=sd,wide_weight=wide_weight)-log_proposal(new,centers;sd=sd,wide_weight=wide_weight)
 accepted=log(rand())<min(0.,ratio)
 accepted ? (candidate,true,ratio) : (trace,false,ratio)
end
end
