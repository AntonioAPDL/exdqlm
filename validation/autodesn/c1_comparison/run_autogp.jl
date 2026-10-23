# Authors' AutoGP SMC; pinned source revision is checked by the launcher/CI.
using AutoGP, CSV, DataFrames, Distributions, LinearAlgebra, Serialization, Printf
using TOML, Test
const ROOT = "validation/autodesn/c1_comparison"
BLAS.set_num_threads(2)

function checkpoint_dict(model)
    d = deepcopy(Dict(model))
    # AutoGP 0.1.19 Dict exports total observation noise, whereas GPModel(Dict)
    # expects noise before adding Model.JITTER. Correct the transport only.
    d["noises"] .-= AutoGP.Model.JITTER
    @assert all(d["noises"] .> 0)
    d
end
function save_model(model,path)
    serialize(path*".partial",checkpoint_dict(model))
    restored = AutoGP.GPModel(deserialize(path*".partial"))
    @assert isapprox(AutoGP.observation_noise_variances(model),AutoGP.observation_noise_variances(restored),rtol=1e-10,atol=1e-12)
    @assert isapprox(AutoGP.particle_weights(model),AutoGP.particle_weights(restored),rtol=1e-12)
    mv(path*".partial",path,force=true)
end
function direct_conditional(mu,C,y,n)
    n==0 && return copy(mu),copy(C)
    b=n+1:length(mu);a=1:n
    L=cholesky(Symmetric(C[a,a]))
    mu[b]+C[b,a]*(L\(y[a]-mu[a])),C[b,b]-C[b,a]*(L\C[a,b])
end
function contracts()
    AutoGP.seed!(81)
    model=AutoGP.GPModel(collect(1:20),sin.(collect(1:20)./4);n_particles=2,config=AutoGP.GP.GPConfig(max_depth=2))
    path=tempname();save_model(model,path)
    restored=AutoGP.GPModel(deserialize(path));rm(path)
    a=AutoGP.predict_mvn(model,collect(21:26));b=AutoGP.predict_mvn(restored,collect(21:26))
    for(p,q) in zip(components(a),components(b))
        @test isapprox(mean(p),mean(q),atol=1e-9,rtol=1e-9)
        @test isapprox(cov(p),cov(q),atol=1e-9,rtol=1e-9)
    end
    # Frozen-weight Gaussian conditioning must equal the native state update.
    y=cos.(collect(21:26)./3);fresh=AutoGP.GPModel(checkpoint_dict(model));w=copy(fresh.pf_state.log_weights)
    AutoGP.add_data!(fresh,collect(21:23),y[1:3]);fresh.pf_state.log_weights=w
    b=AutoGP.predict_mvn(fresh,collect(24:26))
    for(p,q) in zip(components(a),components(b))
        m,C=direct_conditional(mean(p),cov(p),y,3)
        @test isapprox(m,mean(q),atol=1e-7,rtol=1e-7)
        @test isapprox(C,cov(q),atol=1e-7,rtol=1e-7)
    end
    println("C1 AUTOGP NATIVE CONTRACTS PASSED");flush(stdout)
end
contracts()
"--test-only" in ARGS && exit()
cfg=TOML.parsefile(joinpath(ROOT,"configuration.toml"))
@assert Threads.nthreads()==cfg["autogp_seeded_threads"]
data=CSV.read(joinpath(ROOT,"input/C1.csv"),DataFrame)
@assert data.time==collect(1:3000)
y=Float64.(data.y);times=collect(cfg["fit_start"]:cfg["fit_end"])
future=collect(cfg["test_start"]:cfg["test_end"])
out=joinpath(ROOT,"artifacts/gp");mkpath(out)
open(joinpath(out,"runtime.txt"),"w") do io
    println(io,"Julia ",VERSION,"; AutoGP ",pkgversion(AutoGP),"; revision ",cfg["autogp_revision"])
    println(io,"Julia threads ",Threads.nthreads(),"; BLAS threads ",BLAS.get_num_threads())
    println(io,"Native default grammar and priors, max_depth=",cfg["autogp_depth"])
end
for (run,seed) in enumerate(cfg["autogp_seeds"])
    dir=joinpath(out,"run_$(run)");mkpath(dir);started=time();path=joinpath(dir,"posterior.jls")
    AutoGP.seed!(seed)
    if isfile(path)
        model=AutoGP.GPModel(deserialize(path))
    else
        model=AutoGP.GPModel(times,y[times];n_particles=cfg["autogp_particles_per_run"],
            config=AutoGP.GP.GPConfig(max_depth=cfg["autogp_depth"]))
        hmc=Dict(:n_exit=>cfg["autogp_hmc_exit"],:L_param=>cfg["autogp_leapfrog"],
            :L_noise=>cfg["autogp_leapfrog"],:eps_param=>cfg["autogp_hmc_base_step"],
            :eps_noise=>cfg["autogp_hmc_base_step"])
        fn=(;model,step,elapsed,rejuvenated,resampled,kw...)->begin
            weights=AutoGP.particle_weights(model)
            row=DataFrame(step=step,elapsed=elapsed,ess=AutoGP.effective_sample_size(model),
                unique_kernel_states=length(unique(string.(AutoGP.covariance_kernels(model)))),
                max_weight=maximum(weights),resampled=resampled,rejuvenated=rejuvenated,
                hmc_step=hmc[:eps_param])
            CSV.write(joinpath(dir,"smc_progress.csv"),row;append=isfile(joinpath(dir,"smc_progress.csv")))
            println("AutoGP run ",run," training rows ",step," ESS ",row.ess[1]);flush(stdout)
            println(stderr,"AutoGP run ",run," training rows ",step," ESS ",row.ess[1]);flush(stderr)
            next=filter(n->n>step,cfg["autogp_schedule"])
            if !isempty(next)
                hmc[:eps_param]=cfg["autogp_hmc_base_step"]*cfg["autogp_hmc_reference_n"]/first(next)
                hmc[:eps_noise]=hmc[:eps_param]
            end
        end
        callback=AutoGP.Callbacks.make_smc_callback(fn,model)
        open(joinpath(dir,"native_smc.log"),"w") do io
            redirect_stdout(io) do
                AutoGP.fit_smc!(model;schedule=cfg["autogp_schedule"],n_mcmc=cfg["autogp_mcmc"],
                    n_hmc=cfg["autogp_hmc"],biased=false,shuffle=true,adaptive_resampling=true,
                    adaptive_rejuvenation=false,hmc_config=hmc,verbose=true,check=false,callback_fn=callback)
            end
        end
        save_model(model,path)
    end
    dist=AutoGP.predict_mvn(model,future);parts=components(dist);weights=probs(dist)
    means=hcat(mean.(parts)...);covs=cat(cov.(parts)...;dims=3)
    @assert all(isfinite,means) && all(isfinite,covs)
    CSV.write(joinpath(dir,"means.csv"),DataFrame(means,:auto))
    open(joinpath(dir,"covariances.bin"),"w") do io;write(io,covs);end
    CSV.write(joinpath(dir,"particles.csv"),DataFrame(component=collect(1:length(weights)),weight=weights,
        noise_variance=AutoGP.observation_noise_variances(model),kernel=string.(AutoGP.covariance_kernels(model))))
    checks=DataFrame(origin=Int[],component=Int[],mean_max_error=Float64[],covariance_max_error=Float64[])
    for origin in (2500,2735,2970)
        native=AutoGP.GPModel(checkpoint_dict(model));w=copy(native.pf_state.log_weights)
        n=origin-cfg["fit_end"]
        if n>0
            AutoGP.add_data!(native,collect(2501:origin),y[2501:origin]);native.pf_state.log_weights=w
        end
        result=AutoGP.predict_mvn(native,collect(origin+1:origin+30))
        for j in eachindex(parts)
            m,C=direct_conditional(means[:,j],covs[:,:,j],y[future],n)
            e1=maximum(abs.(m[1:30]-mean(components(result)[j])))
            e2=maximum(abs.(C[1:30,1:30]-cov(components(result)[j])))
            push!(checks,(origin,j,e1,e2));@assert e1<1e-5 && e2<1e-5
        end
    end
    CSV.write(joinpath(dir,"native_checks.csv"),checks)
    open(joinpath(dir,"status.toml"),"w") do io
        TOML.print(io,Dict("complete"=>true,"seed"=>seed,"fit_rows"=>2000,"n_future"=>500,
            "n_particles"=>length(weights),"ess"=>AutoGP.effective_sample_size(model),
            "elapsed_seconds"=>time()-started,"fixed_weights"=>true))
    end
    println("AutoGP run ",run," complete");flush(stdout);GC.gc()
end
