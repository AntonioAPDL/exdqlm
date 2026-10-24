# Native same-prior SMC with optional invariant period rejuvenation.
# Input is restricted to rows 501:2500; no confirmation or held-out scoring.
using AutoGP,Gen,CSV,DataFrames,Serialization,TOML,LinearAlgebra,Random,SHA,Distributions,Statistics
include(joinpath(@__DIR__,"gp_moves.jl"));using .RemediationGPMoves
BLAS.set_num_threads(1)
N=length(ARGS)>0 ? parse(Int,ARGS[1]) : 512
particles=length(ARGS)>1 ? parse(Int,ARGS[2]) : 16
seed=length(ARGS)>2 ? parse(Int,ARGS[3]) : 2266021
period_moves=length(ARGS)>3 ? parse(Int,ARGS[4]) : 10
@assert N in [128,256,512,2000] && particles in [8,16,32,64] && period_moves in [0,10]
native_root=dirname(dirname(pathof(AutoGP)))
@assert readchomp(`git -C $native_root rev-parse HEAD`)=="2ad372db2b8bea176e3b32a769bfb5d6cff80866"
root="validation/autodesn/remediation";label=period_moves==0 ? "_native" : "";dir=joinpath(root,"artifacts","gp_n$(N)_p$(particles)_s$(seed)$(label)");if isdir(dir)&&!isempty(readdir(dir));error("Use a fresh run directory; partial/complete evidence is never silently appended");end;mkpath(dir)
data=CSV.read("validation/autodesn/nonlinear_heteroscedastic/input/series.csv",DataFrame;limit=2500,ntasks=1)
times=collect(501:500+N);y=Float64.(data.y[times]);AutoGP.seed!(seed);Random.seed!(seed)
initialization_started=time()
model=AutoGP.GPModel(times,y;n_particles=particles,config=AutoGP.GP.GPConfig(max_depth=4))
initialization_seconds=time()-initialization_started
CSV.write(joinpath(dir,"training_input.csv"),DataFrame(time=times,y=y))
training_sha256=bytes2hex(sha256(read(joinpath(dir,"training_input.csv"))))
# Proposal uses fixed training-derived periodogram peaks. It is not a changed prior.
# Fresh runs must receive independently generated/frozen training peaks as input.
proposal_path=get(ENV,"AUTOGP_FROZEN_PROPOSAL",joinpath(root,"artifacts/gp_training_proposal.toml"))
peaks=TOML.parsefile(proposal_path)["periods"]
centers=latent_centers(model,peaks)
base=[32,64,128,256,512,1000,1500,2000];schedule=filter(x->x<=N,base)
mc=[40,40,40,30,20,15,10,10][1:length(schedule)];hm=[4,4,4,3,3,2,2,2][1:length(schedule)]
hmc=Dict(:n_exit=>2,:L_param=>5,:L_noise=>5,:eps_param=>.02,:eps_noise=>.02)
source_identity=Dict(p=>bytes2hex(sha256(read(p))) for p in [@__FILE__,joinpath(@__DIR__,"gp_moves.jl"),proposal_path,joinpath(native_root,"Project.toml"),joinpath(native_root,"Manifest.toml")])
open(joinpath(dir,"configuration.toml"),"w") do io
 TOML.print(io,Dict("source_sha256"=>source_identity,"training_rows"=>N,"training_input_sha256"=>training_sha256,"particles"=>particles,"seed"=>seed,"period_moves_per_particle_per_stage"=>period_moves,"max_depth"=>4,"schedule"=>schedule,"n_mcmc"=>mc,"n_hmc"=>hm,"native_target_unchanged"=>true,"heldout_data_read"=>false))
end
started=time();updates=Ref(0);accepted=Ref(0)
fn=(;model,step,elapsed,rejuvenated,resampled,kw...)->begin
 for i in eachindex(model.pf_state.traces)
  tr=model.pf_state.traces[i]
  for j in 1:period_moves
   tr,a,r=period_refresh(tr,centers);if isfinite(r);updates[]+=1;accepted[]+=a;end
  end
  model.pf_state.traces[i]=tr
 end
 row=DataFrame(step=step,elapsed=elapsed,ess=AutoGP.effective_sample_size(model),period_updates=updates[],period_acceptances=accepted[],max_log_joint=maximum(Gen.get_score.(model.pf_state.traces)))
 CSV.write(joinpath(dir,"progress.csv"),row;append=isfile(joinpath(dir,"progress.csv")))
 CSV.write(joinpath(dir,"particles_step_$(step).csv"),DataFrame(component=collect(eachindex(model.pf_state.traces)),weight=AutoGP.particle_weights(model),noise_variance=AutoGP.observation_noise_variances(model),kernel=string.(AutoGP.covariance_kernels(model)),native_log_joint=Gen.get_score.(model.pf_state.traces)))
 if step>0
  checkpoint=deepcopy(Dict(model));checkpoint["noises"] .-= AutoGP.Model.JITTER
  serialize(joinpath(dir,"checkpoint_step_$(step).jls"),checkpoint)
 end
 println(row);flush(stdout)
 next=filter(x->x>step,schedule)
 if !isempty(next);hmc[:eps_param]=.02*32/first(next);hmc[:eps_noise]=hmc[:eps_param];end
end
callback=AutoGP.Callbacks.make_smc_callback(fn,model)
inference_started=time()
AutoGP.fit_smc!(model;schedule=schedule,n_mcmc=mc,n_hmc=hm,biased=false,shuffle=true,adaptive_resampling=true,adaptive_rejuvenation=false,hmc_config=hmc,verbose=true,check=false,callback_fn=callback)
inference_seconds=time()-inference_started;transport_started=time()
state=deepcopy(Dict(model));state["noises"] .-= AutoGP.Model.JITTER
@assert all(state["noises"].>0)
serialize(joinpath(dir,"posterior.jls.partial"),state)
expected_weights=copy(AutoGP.particle_weights(model));expected_noise=AutoGP.observation_noise_variances(model);expected_score=Gen.get_score.(model.pf_state.traces)
# Avoid retaining two full trace collections while validating transport.
model=nothing;callback=nothing;state=nothing;GC.gc()
model=AutoGP.GPModel(deserialize(joinpath(dir,"posterior.jls.partial")))
@assert isapprox(expected_weights,AutoGP.particle_weights(model);atol=1e-12)
@assert isapprox(expected_noise,AutoGP.observation_noise_variances(model);rtol=1e-10)
@assert isapprox(expected_score,Gen.get_score.(model.pf_state.traces);rtol=1e-10,atol=1e-8)
mv(joinpath(dir,"posterior.jls.partial"),joinpath(dir,"posterior.jls");force=true)
CSV.write(joinpath(dir,"particles.csv"),DataFrame(weight=AutoGP.particle_weights(model),kernel=string.(AutoGP.covariance_kernels(model)),native_log_joint=Gen.get_score.(model.pf_state.traces)))
transport_seconds=time()-transport_started;probe_started=time()
probes=unique(round.(Int,range(first(times),last(times),length=12)))
predictive=components(AutoGP.predict_mvn(model,probes))
probe_rows=DataFrame(component=Int[],time=Int[],weight=Float64[],mean=Float64[],latent_sd=Float64[],predictive_sd=Float64[])
for i in eachindex(predictive)
 # Native constant/linear kernels can have singular latent covariance. Recover
 # its marginal variance from the proper noisy conditional instead of asking
 # MvNormal to factor a rank-deficient noiseless joint covariance. Native code
 # adds exactly the component observation variance to its predictive diagonal.
 v=diag(cov(predictive[i]));latent_v=v.-expected_noise[i]
 @assert all(latent_v .>= -1e-10.*max.(1.,v,expected_noise[i]))
 for j in eachindex(probes)
  push!(probe_rows,(i,probes[j],expected_weights[i],mean(predictive[i])[j],sqrt(max(0.,latent_v[j])),sqrt(v[j])))
 end
end
CSV.write(joinpath(dir,"training_probes.csv"),probe_rows)
probe_seconds=time()-probe_started
status=Dict("complete"=>true,"posterior_qualified"=>false,"training_rows"=>N,"training_input_sha256"=>training_sha256,"particles"=>particles,"julia_threads"=>Threads.nthreads(),"seed"=>seed,"native_target_unchanged"=>true,"training_only"=>true,"elapsed_seconds"=>time()-started,"initialization_seconds"=>initialization_seconds,"inference_seconds_including_stage_checkpoints"=>inference_seconds,"checkpoint_transport_seconds"=>transport_seconds,"training_probe_seconds"=>probe_seconds,"period_updates"=>updates[],"period_acceptances"=>accepted[],"period_moves_per_particle_per_stage"=>period_moves,"forecast_issued"=>false,"subsample_feasibility_only"=>(N!=2000),"source_sha256"=>source_identity,"autogp_revision"=>"2ad372db2b8bea176e3b32a769bfb5d6cff80866")
open(joinpath(dir,"status.toml"),"w") do io;TOML.print(io,status);end
println(status)
