# Complete native depth-one grammar, all continuous parameters and noise learned.
# Native prior-independence MH: Gen.generate supplies the normalized proposal,
# and its returned observed-data weight supplies the exact likelihood ratio.
using AutoGP,Gen,CSV,DataFrames,Distributions,LinearAlgebra,Random,TOML,SHA
BLAS.set_num_threads(1)
root="validation/autodesn/remediation";out=joinpath(root,"artifacts/gp_leaf_reference");mkpath(out)
native_root=dirname(dirname(pathof(AutoGP)))
@assert readchomp(`git -C $native_root rev-parse HEAD`)=="2ad372db2b8bea176e3b32a769bfb5d6cff80866"
ts=[0.,.19,.47,1.];y=[.13,-.24,.12,.07];config=AutoGP.GP.GPConfig(max_depth=1)
@assert config.node_dist_leaf == [0.,1/3,0.,1/3,1/3]
@assert config.prior[:wildcard] == Dict(:mu=>-1.5,:sigma=>1.)
@assert config.prior[:period] == Dict(:mu=>-1.5,:sigma=>1.)
@assert config.prior[:gamma] == Dict(:mu=>0.,:sigma=>1.,:scale=>2.)
observed=Gen.choicemap((:xs,y));retained=32000;warmup=8000
for chain in 1:4
 Random.seed!(7466020+chain)
 path=joinpath(out,"trace_$(chain).csv");@assert !isfile(path)
 trace,ll=Gen.generate(AutoGP.Model.model,(ts,config),observed)
 rows=DataFrame();accepted=0;max_density_error=0.
 for it in 1:(warmup+retained)
  proposal,proposed_ll=Gen.generate(AutoGP.Model.model,(ts,config),observed)
  if log(rand())<proposed_ll-ll
   trace=proposal;ll=proposed_ll;accepted+=1
  end
  if it>warmup
   node=trace[];kind=trace[:tree=>(1,:node_type)];fields=fieldnames(typeof(node))
   z=[trace[:noise];[trace[:tree=>(1,f)] for f in fields]]
   @assert length(z)==4
   prior=-log(3.)+sum(Distributions.logpdf.(Normal(),z))
   max_density_error=max(max_density_error,abs(Gen.get_score(trace)-prior-ll))
   noise=AutoGP.Model.transform_param(:noise,z[1],config)+AutoGP.Model.JITTER
   K=AutoGP.GP.compute_cov_matrix_vectorized(node,0.,ts)
   C=Symmetric(K+noise*I);a=C\y;mu=dot(K[3,:],a)
   variance=K[3,3]-dot(K[3,:],C\K[:,3])
   @assert variance >= -1e-10
   push!(rows,(iteration=it-warmup,linear_probability=Float64(kind==2),gamma_probability=Float64(kind==4),periodic_probability=Float64(kind==5),noise_variance=noise,log_noise_latent=z[1],amplitude=node.amplitude,log_likelihood=ll,fitted_mean_3=mu,latent_second_moment_3=mu^2+variance);cols=:union)
  end
 end
 @assert max_density_error<1e-9
 CSV.write(path*".partial",rows);mv(path*".partial",path)
 open(joinpath(out,"chain_$(chain)_status.toml"),"w") do io
  TOML.print(io,Dict("complete"=>true,"chain"=>chain,"retained"=>retained,"warmup"=>warmup,"accepted"=>accepted,"maximum_native_density_constant_error"=>max_density_error,"trace_sha256"=>bytes2hex(sha256(read(path)))))
 end
 println("Native leaf-grammar reference chain ",chain," complete");flush(stdout)
end
open(joinpath(out,"status.toml"),"w") do io
 TOML.print(io,Dict("complete"=>true,"chains"=>4,"retained"=>retained,"warmup"=>warmup,"source_sha256"=>bytes2hex(sha256(read(@__FILE__))),"native_revision"=>"2ad372db2b8bea176e3b32a769bfb5d6cff80866","scope"=>"Complete native depth-one leaf grammar and parameters; not depth-four SMC convergence","production_qualified"=>false))
end
