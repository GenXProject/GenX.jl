using GenX
using HiGHS


optimizer = HiGHS.Optimizer

# case = "Example_Systems/Electrolyzer_Example"
case = "test/Inputfiles"

genx_settings = GenX.get_settings_path(case, "genx_settings.yml") 
setup = configure_settings(genx_settings)

settings_path = GenX.get_settings_path(case)

TDRpath = joinpath(case, setup["TimeDomainReductionFolder"])

if setup["TimeDomainReduction"] == 1
    prevent_doubled_timedomainreduction(case)
    if !time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        cluster_inputs(case, settings_path, setup)
    else
        println("Time Series Data Already Clustered.")
    end
end

println("Configuring Solver")
OPTIMIZER = configure_solver(settings_path, optimizer)

println("Loading Inputs")
input_data = load_inputs(setup, case)

rs = input_data["RESOURCES"];

# println("Generating the Optimization Model")
time_elapsed = @elapsed EP = generate_model(setup, input_data, OPTIMIZER)
println("Time elapsed for model building is")
println(time_elapsed)