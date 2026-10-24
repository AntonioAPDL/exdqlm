# Native same-prior SMC with optional invariant period rejuvenation.
# Input is restricted to rows 501:2500; no confirmation or held-out scoring.
using AutoGP,Gen,CSV,DataFrames,Serialization,TOML,LinearAlgebra,Random,SHA
include("gp_moves.jl");using .RemediationGPMoves
BLAS.set_num_threads(1)
N=length(ARGS)>0 ? parse(Int,ARGS[1]) : 512
particles=length(ARGS)>1 ? parse(Int,ARGS[2]) : 16
seed=length(ARGS)>2 ? parse(Int,ARGS[3]) : 2266021
@assert N in [128,256,512,2000] && particles in [8,16,32,64]
native_root=dirname(dirname(pathof(AutoGP)))
@assert readchomp(`git -C $native_root rev-parse HEAD`)=="2ad372db2b8bea176e3b32a769bfb5d6cff80866"
root="validation/autodesn/remediation";dir=joinpath(root,"artifacts","gp_n$(N)_p$(particles)_s$(seed)");if isdir(dir)&&!isempty(readdir(dir));error("Use a fresh run directory; partial/complete evidence is never silently appended");end;mkpath(dir)
data=CSV.read("validation/autodesn/nonlinear_heteroscedastic/input/series.csv",DataFrame;limit=2500,ntasks=1)
times=collect(501:500+N);y=Float64.(data.y[times]);AutoGP.seed!(seed);Random.seed!(seed)
model=AutoGP.GPModel(times,y;n_particles=particles,config=AutoGP.GP.GPConfig(max_depth=4))
# Proposal uses fixed training-derived periodogram peaks. It is not a changed prior.
# Fresh runs must receive independently generated/frozen training peaks as input.
peaks=TOML.parsefile(joinpath(root,"artifacts/gp_training_proposal.toml"))["periods"]
centers=latent_centers(model,peaks)
base=[32,64,128,256,512,1000,1500,2000];schedule=filter(x->x<=N,base)
mc=[40,40,40,30,20,15,10,10][1:length(schedule)];hm=[4,4,4,3,3,2,2,2][1:length(schedule)]
hmc=Dict(:n_exit=>2,:L_param=>5,:L_noise=>5,:eps_param=>.02,:eps_noise=>.02)
source_identity=Dict(p=>bytes2hex(sha256(read(p))) for p in [@__FILE__,joinpath(root,"gp_moves.jl"),joinpath(root,"artifacts/gp_training_proposal.toml")])
started=time();updates=Ref(0);accepted=Ref(0)
fn=(;model,step,elapsed,rejuvenated,resampled,kw...)->begin
 for i in eachindex(model.pf_state.traces)
  tr=model.pf_state.traces[i]
  for j in 1:10
   tr,a,r=period_refresh(tr,centers);if isfinite(r);updates[]+=1;accepted[]+=a;end
  end
  model.pf_state.traces[i]=tr
 end
 row=DataFrame(step=step,elapsed=elapsed,ess=AutoGP.effective_sample_size(model),period_updates=updates[],period_acceptances=accepted[],max_log_joint=maximum(Gen.get_score.(model.pf_state.traces)))
 CSV.write(joinpath(dir,"progress.csv"),row;append=isfile(joinpath(dir,"progress.csv")))
 if step>0
  checkpoint=deepcopy(Dict(model));checkpoint["noises"] .-= AutoGP.Model.JITTER
  serialize(joinpath(dir,"checkpoint_step_$(step).jls"),checkpoint)
 end
 println(row);flush(stdout)
 next=filter(x->x>step,schedule)
 if !isempty(next);hmc[:eps_param]=.02*32/first(next);hmc[:eps_noise]=hmc[:eps_param];end
end
callback=AutoGP.Callbacks.make_smc_callback(fn,model)
AutoGP.fit_smc!(model;schedule=schedule,n_mcmc=mc,n_hmc=hm,biased=false,shuffle=true,adaptive_resampling=true,adaptive_rejuvenation=false,hmc_config=hmc,verbose=true,check=false,callback_fn=callback)
state=deepcopy(Dict(model));state["noises"] .-= AutoGP.Model.JITTER
@assert all(state["noises"].>0)
serialize(joinpath(dir,"posterior.jls.partial"),state)
restored=AutoGP.GPModel(deserialize(joinpath(dir,"posterior.jls.partial")))
@assert isapprox(AutoGP.particle_weights(model),AutoGP.particle_weights(restored);atol=1e-12)
@assert isapprox(AutoGP.observation_noise_variances(model),AutoGP.observation_noise_variances(restored);rtol=1e-10)
@assert isapprox(Gen.get_score.(model.pf_state.traces),Gen.get_score.(restored.pf_state.traces);rtol=1e-10,atol=1e-8)
mv(joinpath(dir,"posterior.jls.partial"),joinpath(dir,"posterior.jls");force=true)
CSV.write(joinpath(dir,"particles.csv"),DataFrame(weight=AutoGP.particle_weights(model),kernel=string.(AutoGP.covariance_kernels(model)),native_log_joint=Gen.get_score.(model.pf_state.traces)))
status=Dict("complete"=>true,"posterior_qualified"=>false,"training_rows"=>N,"particles"=>particles,"julia_threads"=>Threads.nthreads(),"seed"=>seed,"native_target_unchanged"=>true,"training_only"=>true,"elapsed_seconds"=>time()-started,"period_updates"=>updates[],"period_acceptances"=>accepted[],"forecast_issued"=>false,"subsample_feasibility_only"=>(N!=2000),"source_sha256"=>source_identity,"autogp_revision"=>"2ad372db2b8bea176e3b32a769bfb5d6cff80866")
open(joinpath(dir,"status.toml"),"w") do io;TOML.print(io,status);end
println(status)
