using Pkg
Pkg.activate(".")
using GenX
using HiGHS


optimizer = HiGHS.Optimizer

# case = "Example_Systems/Electrolyzer_Example"
case = "test/Inputfiles"
# case = "/Users/lb9239/Documents/ZERO_lab/GenX/GenX/Example_Systems/RealSystemExample/ISONE_Trizone"
genx_settings = GenX.get_settings_path(case, "genx_settings.yml") 
mysetup = GenX.configure_settings(genx_settings)

settings_path = GenX.get_settings_path(case)

TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])

if mysetup["TimeDomainReduction"] == 1
    GenX.prevent_doubled_timedomainreduction(case)
    if !GenX.time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        GenX.cluster_inputs(case, settings_path, mysetup)
    else
        println("Time Series Data Already Clustered.")
    end
end

println("Configuring Solver")
OPTIMIZER = GenX.configure_solver(settings_path, optimizer)

println("Loading Inputs")
input_data = GenX.load_inputs(mysetup, case)

rs = input_data["RESOURCES"]

# println("Generating the Optimization Model")
# time_elapsed = @elapsed EP = GenX.generate_model(mysetup, myinputs, OPTIMIZER)
# println("Time elapsed for model building is")
# println(time_elapsed)