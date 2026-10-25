# Deterministic serialized-state audit, without reconstructing/fitting GPModels.
using AutoGP, Gen, Serialization, CSV, DataFrames, TOML, SHA, Statistics
include(joinpath(@__DIR__,"gp_evidence.jl"))
@assert length(ARGS)==5
run,particle_arg,seed_arg,policy_arg,output=ARGS
n=parse(Int,particle_arg);seeds=parse.(Int,split(seed_arg,','));policy=parse(Int,policy_arg)
@assert length(seeds)==4 && length(unique(seeds))==4 && policy in (0,10)
@assert !ispath(output);mkpath(output)
root="validation/autodesn/remediation";rows=DataFrame();inputs=Dict{String,String}();cohort_identity=Ref{Any}(nothing)
native_root=dirname(dirname(pathof(AutoGP)))
@assert readchomp(`git -C $native_root rev-parse HEAD`)=="2ad372db2b8bea176e3b32a769bfb5d6cff80866"
for seed in seeds
    suffix=policy==0 ? "_native" : ""
    path=joinpath(root,"artifacts/remote_gp_runs/$run/s$seed",root,"artifacts/gp_n2000_p$(n)_s$(seed)$suffix")
    st=TOML.parsefile(joinpath(path,"status.toml"))
    @assert st["complete"] && st["training_rows"]==2000 && st["particles"]==n
    @assert st["period_moves_per_particle_per_stage"]==policy
    id=(st["training_input_sha256"],st["source_sha256"],st["autogp_revision"])
    if isnothing(cohort_identity[]);cohort_identity[]=id;else;@assert cohort_identity[]==id;end
    file=joinpath(path,"posterior.jls");s=deserialize(file)
    @assert s["ds"]==collect(501:2500) && length(s["kernels"])==n
    v=serialized_smc_log_evidence(s)
    f=Gen.initialize_particle_filter(AutoGP.Model.model,(Float64[],s["config"]),Gen.choicemap(),n)
    f.log_weights=copy(s["pf_state"]["log_weights"]);f.log_ml_est=s["pf_state"]["log_ml_est"]
    @assert isapprox(v.log_evidence,Gen.log_ml_estimate(f);atol=1e-10,rtol=1e-12)
    # Old exports label the partial native API field; new exports explicitly
    # mark full Gen evidence. Neither is silently interpreted as the other.
    expected=get(st,"evidence_includes_terminal_particle_weights",false) ? v.log_evidence : v.pre_resampling_accumulator
    @assert isapprox(st["log_marginal_likelihood_estimate"],expected;atol=1e-10,rtol=1e-12)
    lw=s["pf_state"]["log_weights"];w=exp.(lw.-maximum(lw));w./=sum(w)
    particles=CSV.read(joinpath(path,"particles.csv"),DataFrame)
    @assert maximum(abs.(particles.weight.-w))<1e-12
    inputs[file]=bytes2hex(sha256(read(file)))
    push!(rows,(seed=seed,particles=n,period_moves=policy,log_evidence=v.log_evidence,
      pre_resampling_accumulator=v.pre_resampling_accumulator,terminal_log_mean_weight=v.terminal_log_mean_weight,
      original_units_log_evidence=v.log_evidence+length(s["y"])*log(abs(s["y_transform"].slope)),
      particle_ess=1/sum(abs2,w),maximum_particle_weight=maximum(w),posterior_sha256=inputs[file]))
end
CSV.write(joinpath(output,"evidence.csv"),rows)
w=exp.(rows.log_evidence.-maximum(rows.log_evidence));w./=sum(w)
open(joinpath(output,"status.toml"),"w") do io
 TOML.print(io,Dict("complete"=>true,"particles"=>n,"period_moves"=>policy,"seeds"=>seeds,
  "log_evidence_range"=>maximum(rows.log_evidence)-minimum(rows.log_evidence),
  "replica_weights"=>w,"effective_evidence_replicas"=>1/sum(abs2,w),
  "inputs"=>inputs,"source_sha256"=>bytes2hex(sha256(read(@__FILE__))),
  "normalizer_helper_sha256"=>bytes2hex(sha256(read(joinpath(@__DIR__,"gp_evidence.jl")))),
  "posterior_qualified"=>false,"forecasts_issued"=>false,"heldout_read"=>false,
  "scope"=>"All four registered same-budget/same-policy replicas, full Gen evidence and exact serialized weights. Computational qualification still requires mode and successive-budget stability."))
end
println(rows);println("GP_COHORT_EVIDENCE_COMPLETE")
