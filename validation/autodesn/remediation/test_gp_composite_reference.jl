# Independent covariance/density and finite-product-space architecture reference.
# This checks all30 default depth-two syntactic trees, including change points;
# it does not qualify the production depth-four SMC algorithm.
using AutoGP,Gen,CSV,DataFrames,Distributions,LinearAlgebra,Test,TOML,SHA
BLAS.set_num_threads(1)
root="validation/autodesn/remediation";out=joinpath(root,"artifacts/gp_composite_reference");mkpath(out)
native=dirname(dirname(pathof(AutoGP)))
@assert readchomp(`git -C $native rev-parse HEAD`)=="2ad372db2b8bea176e3b32a769bfb5d6cff80866"
config=AutoGP.GP.GPConfig(max_depth=2)
ts=[0.,.19,.47,1.];y=[.13,-.24,.12,.07];distance=abs.(ts.-ts')
fields=Dict(2=>(:intercept,:bias,:amplitude),4=>(:lengthscale,:gamma,:amplitude),5=>(:lengthscale,:period,:amplitude))
function leaf_cov(kind,z)
 p=exp.(-1.5 .+ z)
 if kind==2
  a=ts.-p[1];return p[2].+p[3].*(a*a')
 elseif kind==4
  return p[3].*exp.(-(distance./p[1]).^(2/(1+exp(-z[2]))))
 else
  return p[3].*exp.(-2 .*sin.(pi.*distance./p[2]).^2 ./p[1]^2)
 end
end
function leaf_choices!(cm,index,kind,z)
 @assert fieldnames(config.index_to_node[kind])==fields[kind]
 cm[:tree=>(index,:node_type)]=kind
 for (field,value) in zip(fields[kind],z);cm[:tree=>(index,field)]=value;end
end
function normal_ll(K,noise)
 L=cholesky(Symmetric(K+noise*I)).L
 return -.5*(length(y)*log(2*pi)+2*sum(log,diag(L))+sum(abs2,L\y))
end
trees=[(op=m,left=0,right=0,prior=6/28) for m in [2,4,5]]
append!(trees,[(op=op,left=l,right=r,prior=(op==8 ? 2 : 4)/28/9) for op in [6,7,8] for l in [2,4,5] for r in [2,4,5]])
rows=DataFrame();maximum_covariance_error=0.;maximum_score_error=0.;maximum_probability_error=0.
@testset "Complete default depth-two native grammar" begin
 @test config.changepoints
 @test config.node_dist_cp≈[0.,6,0,6,6,4,4,2]./28
 @test config.node_dist_leaf==[0.,1/3,0.,1/3,1/3]
 @test length(trees)==30
 @test sum(t.prior for t in trees)≈1.
 for fixture in 1:5
  left=fixture==1 ? [-.7,.2,.5] : [-1.4+.31*fixture,.13*fixture,-.8+.27*fixture]
  right=fixture==1 ? copy(left) : [.9-.17*fixture,-.2*fixture,.6-.23*fixture]
  location=fixture==2 ? log(ts[2])+1.5 : fixture==3 ? log(ts[3])+1.5 : -.9+.4*fixture
  noise_z=-.6+.19*fixture;noise=exp(-1.5+noise_z)+1e-5
  manual=Float64[];native_expanded=Float64[]
  for (index,t) in enumerate(trees)
   cm=Gen.choicemap((:xs,y),(:noise,noise_z));active=[noise_z]
   if t.op in [2,4,5]
    leaf_choices!(cm,1,t.op,left);append!(active,left);K=leaf_cov(t.op,left)
   else
    cm[:tree=>(1,:node_type)]=t.op
    leaf_choices!(cm,2,t.left,left);leaf_choices!(cm,3,t.right,right)
    append!(active,left);append!(active,right)
    A=leaf_cov(t.left,left);B=leaf_cov(t.right,right)
    if t.op==6;K=A+B
    elseif t.op==7;K=A.*B
    else
     cm[:tree=>(1,:location)]=location;push!(active,location)
     g=.5 .* (1 .+ tanh.((exp(-1.5+location) .- ts) ./ .001))
     K=(g*g').*A+((1 .-g)*(1 .-g)').*B
    end
   end
   trace,weight=Gen.generate(AutoGP.Model.model,(ts,config),cm)
   nativeK=AutoGP.GP.compute_cov_matrix_vectorized(trace[],0.,ts)
   ll=normal_ll(K,noise);prior=sum(Distributions.logpdf.(Normal(),active));score=Gen.get_score(trace)
   ce=maximum(abs.(nativeK-K));se=abs(score-(log(t.prior)+prior+ll))
   global maximum_covariance_error=max(maximum_covariance_error,ce)
   global maximum_score_error=max(maximum_score_error,se)
   @test isapprox(nativeK,K;atol=1e-11,rtol=1e-11)
   @test isapprox(score,log(t.prior)+prior+ll;atol=1e-9,rtol=1e-11)
   @test isapprox(weight,score;atol=1e-10,rtol=1e-11)
   # Add the independent inactive normalized priors in a common8-slot space.
   # They integrate to one. All8 latent Normal factors cancel in p(tree|z,y).
   push!(manual,log(t.prior)+ll);push!(native_expanded,score-prior)
   push!(rows,(fixture=fixture,tree=index,op=t.op,left=t.left,right=t.right,tree_prior=t.prior,log_likelihood=ll,covariance_error=ce,score_error=se);cols=:union)
  end
  p=exp.(manual.-maximum(manual));p./=sum(p)
  q=exp.(native_expanded.-maximum(native_expanded));q./=sum(q)
  @test sum(p)≈1.
  @test isapprox(p,q;atol=1e-11,rtol=1e-11)
  global maximum_probability_error=max(maximum_probability_error,maximum(abs.(p-q)))
  if fixture==1
   for op in [6,7],l in [2,4,5],r in [2,4,5]
    a=findfirst(t->t.op==op&&t.left==l&&t.right==r,trees)
    b=findfirst(t->t.op==op&&t.left==r&&t.right==l,trees)
    @test p[a]≈p[b] # Equal covariance does not delete a syntactic tree's mass.
   end
  end
 end
end
CSV.write(joinpath(out,"checks.csv"),rows)
open(joinpath(root,"evidence/gp_composite_reference.toml"),"w") do io
 TOML.print(io,Dict("complete"=>true,"passed"=>true,"syntactic_trees"=>30,"latent_fixtures"=>5,"covariance_density_cases"=>nrow(rows),"maximum_covariance_error"=>maximum_covariance_error,"maximum_score_error"=>maximum_score_error,"maximum_probability_error"=>maximum_probability_error,"native_revision"=>"2ad372db2b8bea176e3b32a769bfb5d6cff80866","source_sha256"=>bytes2hex(sha256(read(@__FILE__))),"production_qualified"=>false,"scope"=>"All30 default depth-two syntactic trees, including nine change-point and ordered sum/product pairs: independent covariance, normalized latent-score constants and common-product-space conditional architecture probabilities. Not integrated full-parameter evidence, deep-grammar exploration or SMC qualification."))
end
