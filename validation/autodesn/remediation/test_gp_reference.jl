# Small conditional native-period posterior, checked against independent dense
# Gaussian covariance integration. This does not qualify full-tree SMC.
using AutoGP,Gen,Distributions,LinearAlgebra,Random,TOML,CSV,DataFrames
include("gp_moves.jl");using .RemediationGPMoves
BLAS.set_num_threads(1);Random.seed!(7366100)
G=AutoGP.GP;config=G.GPConfig(max_depth=4);ts=collect(range(0,1,length=9));y=.25sin.(12ts);lengthscale=.9;amplitude=.3;noise=.1
node=G.Periodic(lengthscale,.4,amplitude);initial=AutoGP.Inference.node_to_trace(node,config,ts,y,noise)
address=first([a for (a,v) in Gen.get_values_shallow(Gen.get_submap(Gen.get_choices(initial),:tree)) if a[2]==:period]);prior=config.prior[:period]
function independent(z)
 P=exp(prior[:mu]+prior[:sigma]*z)
 C=[amplitude*exp(-2*sin(pi*(a-b)/P)^2/lengthscale^2)+(i==j ? noise+AutoGP.Model.JITTER : 0) for (i,a) in enumerate(ts),(j,b) in enumerate(ts)]
 L=cholesky(Symmetric(C));-.5*(length(y)*log(2pi)+2sum(log.(diag(L.U)))+dot(y,L\y))+Distributions.logpdf(Normal(),z)
end
function candidate(z)
 cm=Gen.choicemap();cm[:tree=>address]=z
 tr,w,_,_=Gen.update(initial,Gen.get_args(initial),Tuple(Gen.NoChange() for a in Gen.get_args(initial)),cm);tr
end
constant=Gen.get_score(initial)-independent(initial[:tree=>address]);maximum_error=maximum(abs(Gen.get_score(candidate(z))-independent(z)-constant) for z in range(-3,3,length=31));@assert maximum_error<1e-9
function reference(step)
 grid=collect(-7:step:7);logw=independent.(grid);shift=maximum(logw);w=exp.(logw.-shift);w[[1,end]].*=.5
 norm=step*sum(w)*exp(shift);means=[sum(w.*grid)/sum(w),sum(w.*grid.^2)/sum(w),sum(w.*(grid.<0))/sum(w)]
 norm,means
end
n1,e1=reference(.002);n2,expected=reference(.001);@assert maximum(abs.(e1.-expected))<.001
# Normal-prior tail bound times the maximal N(y|0,C) density from C>=noise*I.
tail_bound=2cdf(Normal(),-7)*(2pi*(noise+AutoGP.Model.JITTER))^(-length(y)/2)/n2;@assert tail_bound<1e-8
centers=[-2.,0.,1.];trace=initial;sample=zeros(24000);accepted=0
for k in 1:26000
 global trace,accepted
 trace,a,r=period_refresh(trace,centers);accepted+=a
 if k>2000;sample[k-2000]=trace[:tree=>address];end
end
function mcse(x)
 batches=reshape(x,200,:);std(vec(sum(batches,dims=1)./200))/sqrt(size(batches,2))
end
values=[sample,sample.^2,Float64.(sample.<0)];rows=DataFrame(quantity=["latent_period_mean","latent_period_second_moment","latent_period_negative_probability"],reference=expected,estimate=mean.(values),mcse=mcse.(values))
@assert all(abs.(rows.estimate.-rows.reference).<7rows.mcse.+.001)
CSV.write("validation/autodesn/remediation/evidence/gp_conditional_reference.csv",rows)
result=Dict("complete"=>true,"checks"=>36,"native_dense_score_constant_error"=>maximum_error,"grid_refinement_max_difference"=>maximum(abs.(e1.-expected)),"posterior_truncation_bound"=>tail_bound,"mcmc_updates"=>26000,"accepted"=>accepted,"posterior_qualified"=>false,"scope"=>"Single native periodic-leaf conditional with other parameters/tree fixed; not exhaustive full grammar and not full-size SMC convergence")
open("validation/autodesn/remediation/evidence/gp_conditional_reference.toml","w") do io;TOML.print(io,result);end
println(rows);println(result)
