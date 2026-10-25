# Small complete-leaf target: independent replica normalizer/measure validation.
using AutoGP, Gen, CSV, DataFrames, LinearAlgebra, Random
include(joinpath(@__DIR__,"gp_evidence.jl"))
BLAS.set_num_threads(1)
times=[0.,.19,.47,1.];y=[.13,-.24,.12,.07]
config=AutoGP.GP.GPConfig(max_depth=1)
rows=DataFrame()
for rejuvenation in (false,true), replica in 1:64
    seed=7466500+replica+(rejuvenation ? 1000 : 0)
    AutoGP.seed!(seed);Random.seed!(seed)
    state=AutoGP.Inference.run_smc_anneal_data(times,y;config=config,n_particles=128,schedule=[1,2,4],n_mcmc=rejuvenation ? 2 : 0,n_hmc=rejuvenation ? 1 : 0,biased=false,adaptive_resampling=true,adaptive_rejuvenation=false,hmc_config=Dict(:n_exit=>1,:L_param=>5,:L_noise=>5,:eps_param=>.02,:eps_noise=>.02))
    s=Dict("pf_state"=>Dict("log_weights"=>state.log_weights,"log_ml_est"=>state.log_ml_est))
    evidence=serialized_smc_log_evidence(s)
    @assert isapprox(evidence.log_evidence,Gen.log_ml_estimate(state);atol=1e-12)
    weights=exp.(state.log_weights.-maximum(state.log_weights));weights./=sum(weights)
    p=zeros(3);noise=0.
    for (w,tr) in zip(weights,state.traces)
        k=tr[];index=k isa AutoGP.GP.Linear ? 1 : k isa AutoGP.GP.GammaExponential ? 2 : k isa AutoGP.GP.Periodic ? 3 : error("Unexpected prior leaf")
        p[index]+=w
        noise+=w*(AutoGP.Model.transform_param(:noise,tr[:noise],config)+AutoGP.Model.JITTER)
    end
    push!(rows,(rejuvenation=rejuvenation,replica=replica,seed=seed,log_evidence=evidence.log_evidence,partial=evidence.pre_resampling_accumulator,terminal=evidence.terminal_log_mean_weight,linear_probability=p[1],gamma_probability=p[2],periodic_probability=p[3],noise_variance=noise))
end
path="validation/autodesn/remediation/evidence/gp_smc_normalizer_replicas.csv"
@assert !ispath(path);CSV.write(path,rows);println("NORMALIZER_REPLICAS_COMPLETE")
