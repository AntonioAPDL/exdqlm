using AutoGP, CSV, DataFrames, LinearAlgebra
BLAS.set_num_threads(2)
struct PilotComplete <: Exception end
x=CSV.read("validation/autodesn/c1_comparison/input/C1.csv",DataFrame)
AutoGP.seed!(1166020)
model=AutoGP.GPModel(collect(501:2500),Float64.(x.y[501:2500]);n_particles=8,config=AutoGP.GP.GPConfig(max_depth=4))
hmc=Dict(:n_exit=>2,:L_param=>5,:L_noise=>5,:eps_param=>.02,:eps_noise=>.02)
schedule=[32,64,128,256,512,1000,1500,2000]
fn=(;model,step,elapsed,kw...)->begin
 println("PILOT STEP ",step," elapsed ",elapsed);flush(stdout)
 step==512 && throw(PilotComplete())
 next=first(filter(n->n>step,schedule));hmc[:eps_param]=.02*32/next;hmc[:eps_noise]=hmc[:eps_param]
 println("NEXT HMC EPS ",hmc[:eps_param]);flush(stdout)
end
try
 AutoGP.fit_smc!(model;schedule=schedule,n_mcmc=[40,40,40,30,20,15,10,10],n_hmc=[4,4,4,3,3,2,2,2],hmc_config=hmc,callback_fn=AutoGP.Callbacks.make_smc_callback(fn,model),verbose=true)
catch e
 if e isa PilotComplete
  println("TRAINING-ONLY HMC PILOT COMPLETE")
 else
  rethrow(e)
 end
end
