using AutoGP, Gen, Serialization, CSV, DataFrames, TOML, SHA
include(joinpath(@__DIR__,"gp_evidence.jl"))
root="validation/autodesn/remediation";rows=DataFrame()
for seed in 7366021:7366024
    p=joinpath(root,"artifacts/remote_gp_runs/40146404171/s$(seed)",root,"artifacts/gp_n2000_p16_s$(seed)_native/posterior.jls")
    s=deserialize(p);v=serialized_smc_log_evidence(s)
    # Algebraic reference is Gen's public API on an actual ParticleFilterState.
    # A one-particle empty fixture supplies only the state container; weights and
    # accumulator below are the complete serialized run, with no GP refitting.
    f=Gen.initialize_particle_filter(AutoGP.Model.model,(Float64[],s["config"]),Gen.choicemap(),length(s["kernels"]))
    f.log_weights=copy(s["pf_state"]["log_weights"]);f.log_ml_est=s["pf_state"]["log_ml_est"]
    @assert isapprox(v.log_evidence,Gen.log_ml_estimate(f);atol=1e-10,rtol=1e-12)
    push!(rows,(seed=seed,log_evidence=v.log_evidence,pre_resampling_accumulator=v.pre_resampling_accumulator,terminal_log_mean_weight=v.terminal_log_mean_weight,log_evidence_original_y_units=v.log_evidence+length(s["y"])*log(abs(s["y_transform"].slope)),posterior_sha256=bytes2hex(sha256(read(p)))))
end
@assert !ispath(joinpath(root,"evidence/gp16_evidence_audit.csv"))
CSV.write(joinpath(root,"evidence/gp16_evidence_audit.csv"),rows)
println(rows)
