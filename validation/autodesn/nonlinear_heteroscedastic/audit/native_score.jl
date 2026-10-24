using AutoGP,Gen,CSV,DataFrames,Serialization,TOML,LinearAlgebra
BLAS.set_num_threads(1)
const ROOT="validation/autodesn/nonlinear_heteroscedastic"
params=TOML.parsefile(joinpath(ROOT,"audit/artifacts/gp_candidate.toml"))
G=AutoGP.GP
raw=G.Plus(G.Periodic(params["calendar_lengthscale"],60.,params["calendar_variance"]),
 G.Times(G.Periodic(params["oscillatory_lengthscale"],params["period"],params["oscillatory_variance"]),G.GammaExponential(params["coherence_length"],1.,1.)))
function count_params(node)
 if node isa G.BinaryOpNode
  return count_params(node.left)+count_params(node.right)
 end
 length(fieldnames(typeof(node)))
end
rows=DataFrame(run=Int[],component=Int[],kind=String[],latent_dimension=Int[],native_log_joint=Float64[])
for run in [1,2]
 model=AutoGP.GPModel(deserialize(joinpath(ROOT,"artifacts/gp/run_$(run)/posterior.jls")))
 for (i,tr) in enumerate(model.pf_state.traces)
  push!(rows,(run,i,"original_particle",count_params(tr[])+1,Gen.get_score(tr)))
 end
 internal=G.rescale(G.reparameterize(raw,AutoGP.Transforms.invert(model.ds_transform)),model.y_transform)
 ts=Float64.(AutoGP.Transforms.apply(model.ds_transform,model.ds));ys=AutoGP.Transforms.apply(model.y_transform,model.y)
 noise=params["noise_variance"]*model.y_transform.slope^2-AutoGP.Model.JITTER
 @assert noise>0
 tr=AutoGP.Inference.node_to_trace(internal,model.config,ts,ys,noise)
 @assert isfinite(Gen.get_score(tr))
 push!(rows,(run,0,"training_fitted_candidate",count_params(tr[])+1,Gen.get_score(tr)))
end
CSV.write(joinpath(ROOT,"audit/artifacts/native_log_joint_check.csv"),rows)
println(rows)
