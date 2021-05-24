#include(joinpath(pwd(), "package_activate.jl")) #Run this line to activate the Julia virtual environment for GenX; skip it, if the appropriate package versions are installed

### Set relevant directory paths
working_path = pwd()
genx_path = joinpath(pwd(), "src") # GenX path
settings_path = joinpath(working_path, "GenX_settings.yml") #Settings YAML file path

### Set inputs path
inpath="$working_path/Example_Systems/SmallNewEngland/ThreeZones"

### Load GenX
println("Loading packages")
push!(LOAD_PATH, genx_path)

using GenX
using YAML

mysetup = configure_settings(settings_path)
TDRpath = joinpath(inpath, mysetup["TimeDomainReductionFolder"])

### Cluster timeseries inputs if necessary and if specified by the user
if mysetup["TimeDomainReduction"] == 1
    if (!isfile(TDRpath*"/Load_data.csv")) || (!isfile(TDRpath*"/Generators_variability.csv")) || (!isfile(TDRpath*"/Fuels_data.csv"))
        println("Clustering Timeseries Data...")
        cluster_inputs(inpath, mysetup)
    else
        println("Timeseries Data Already Clustered.")
    end
end

### Configure solver
println("Configuring Solver")
solver_settings_path = pwd()
OPTIMIZER = configure_solver(mysetup["Solver"], solver_settings_path)

#### Running a case
for uc = [1]
    for r = [0,1]

    mysetup["UCommit"] = uc
    mysetup["Reserves"] = r

    ### Load inputs
    println("Loading Inputs")
    myinputs = Dict() # myinputs dictionary will store read-in data and computed parameters
    myinputs = load_inputs(mysetup, inpath)

    ### Generate model
    println("Generating the Optimization Model")
    EP = generate_model(mysetup, myinputs, OPTIMIZER)

    ### Solve model
    println("Solving Model")
    EP, solve_time = solve_model(EP, mysetup)
    myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

    ### Write output
    # Run MGA if the MGA flag is set to 1 else only save the least cost solution
    println("Writing Output")
    outpath = "$working_path/output_data/Results"*"UC_"*string(uc)*"_Res_"*string(r)
    write_outputs(EP, outpath, mysetup, myinputs)
    end
end
#if mysetup["ModelingToGenerateAlternatives"] == 1
#    print("Starting Model to Generate Alternatives (MGA) Iterations")
#    mga(EP,inpath,mysetup,myinputs,outpath)
#end
