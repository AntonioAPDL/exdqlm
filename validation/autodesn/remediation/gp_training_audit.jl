# Deterministic training-only postprocessing of native serialized SMC output.
# No GPModel reconstruction, resampling, refitting or held-out observations.
using AutoGP, Serialization, CSV, DataFrames, TOML, LinearAlgebra, SHA, Statistics
BLAS.set_num_threads(1)
root="validation/autodesn/remediation"
out=joinpath(root,"artifacts/gp_training_audit16")
@assert !ispath(out) "Use a fresh audit output directory"
mkpath(out)
native_root=dirname(dirname(pathof(AutoGP)))
@assert readchomp(`git -C $native_root rev-parse HEAD`)=="2ad372db2b8bea176e3b32a769bfb5d6cff80866"
summaries=Dict[]
for seed in 7366021:7366024
    input=joinpath(root,"artifacts/remote_gp_runs/40146404171/s$(seed)",root,"artifacts/gp_n2000_p16_s$(seed)_native")
    st=TOML.parsefile(joinpath(input,"status.toml"))
    @assert st["complete"] && st["training_rows"]==2000 && st["particles"]==16
    file=joinpath(input,"posterior.jls"); state=deserialize(file)
    @assert state["ds"]==collect(501:2500)
    rows=CSV.read(joinpath(input,"training_input.csv"),DataFrame)
    @assert rows.time==state["ds"] && rows.y==state["y"]
    probes=CSV.read(joinpath(input,"training_probes.csv"),DataFrame)
    particle=CSV.read(joinpath(input,"particles.csv"),DataFrame)
    lw=state["pf_state"]["log_weights"]
    weights=exp.(lw.-maximum(lw));weights./=sum(weights)
    @assert maximum(abs.(weights.-particle.weight))<1e-12
    ts=AutoGP.Transforms.apply(state["ds_transform"],Float64.(state["ds"]))
    z=AutoGP.Transforms.apply(state["y_transform"],state["y"])
    slope=state["y_transform"].slope
    means=zeros(length(z));second=zeros(length(z));noise_mean=0.
    errors=zeros(3)
    for i in eachindex(weights)
        noise=state["noises"][i]+AutoGP.Model.JITTER
        K=AutoGP.GP.compute_cov_matrix_vectorized(state["kernels"][i],0.,ts)
        @assert isapprox(K,K';atol=1e-12,rtol=1e-10)
        C=cholesky(Symmetric((K+K')/2+noise*I))
        mu=AutoGP.Transforms.unapply(state["y_transform"],z.-noise.*(C\z))
        inverse_lower=C.L\Matrix{Float64}(I,length(z),length(z))
        v=noise.-noise^2 .* vec(sum(abs2,inverse_lower;dims=1))
        @assert minimum(v)>-1e-9
        v=max.(0.,v)./slope^2
        for p in eachrow(probes[probes.component.==i,:])
            j=p.time-500
            errors=max.(errors,abs.([mu[j]-p.mean,sqrt(v[j])-p.latent_sd,sqrt(v[j]+noise/slope^2)-p.predictive_sd]))
        end
        means.+=weights[i].*mu
        second.+=weights[i].*(v.+mu.^2)
        noise_mean+=weights[i]*noise/slope^2
        println("AUDIT seed=$(seed) component=$(i) native_probe_errors=$(errors)");flush(stdout)
    end
    @assert maximum(errors)<1e-7 "Independent streamed algebra must reproduce native probes"
    latent_var=max.(0.,second.-means.^2)
    CSV.write(joinpath(out,"training_s$(seed).csv"),DataFrame(time=state["ds"],observed=state["y"],mean=means,latent_sd=sqrt.(latent_var),predictive_sd=sqrt.(latent_var.+noise_mean)))
    push!(summaries,Dict("seed"=>seed,"posterior_sha256"=>bytes2hex(sha256(read(file))),"log_marginal_likelihood_estimate"=>state["pf_state"]["log_ml_est"],"particle_ess"=>1/sum(abs2,weights),"maximum_particle_weight"=>maximum(weights),"native_probe_max_errors"=>errors,"training_observed_rmse"=>sqrt(mean(abs2,state["y"].-means)),"rows"=>2000,"particles"=>16,"source_status_sha256"=>bytes2hex(sha256(read(joinpath(input,"status.toml"))))))
end
open(joinpath(out,"status.toml"),"w") do io
    TOML.print(io,Dict("complete"=>true,"native_revision"=>"2ad372db2b8bea176e3b32a769bfb5d6cff80866","source_sha256"=>bytes2hex(sha256(read(@__FILE__))),"replicates"=>summaries,"heldout_used"=>false,"posterior_qualified"=>false,"pooled"=>false,"scope"=>"Per-run exact training Gaussian-mixture first two moments. SDs are not quantile intervals. SMC normalizer and mode/budget qualification remain separate."))
end
