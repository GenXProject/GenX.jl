using Pkg

case = dirname(@__FILE__)

Pkg.activate(dirname(dirname(case)))
using Revise
using GenX,Gurobi

genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

settings_path = GenX.get_settings_path(case)

 ### Cluster time series inputs if necessary and if specified by the user
 if mysetup["TimeDomainReduction"] == 1
    TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])
    system_path = joinpath(case, mysetup["SystemFolder"])
    GenX.prevent_doubled_timedomainreduction(system_path)
    if !GenX.time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        GenX.cluster_inputs(case, settings_path, mysetup)
    else
        println("Time Series Data Already Clustered.")
    end
end

(@isdefined GRB_ENV) || (const GRB_ENV = Gurobi.Env())

myinputs = GenX.load_inputs(mysetup, case);

myinputs_decomp = GenX.separate_inputs_subperiods(myinputs);

OPTIMIZER = GenX.optimizer_with_attributes(()->Gurobi.Optimizer(GRB_ENV),"BarConvTol"=>1e-3,"Method"=>2,"Crossover"=>0)

PLANNING_OPTIMIZER = GenX.optimizer_with_attributes(()->Gurobi.Optimizer(GRB_ENV),"BarConvTol"=>1e-3,"Method"=>2,"MIPGap"=>1e-3,"Crossover"=>0)

SUBPROB_OPTIMIZER = GenX.optimizer_with_attributes(()->Gurobi.Optimizer(GRB_ENV),"BarConvTol"=>1e-3,"Method"=>2,"Crossover"=>1)

model = GenX.generate_model(mysetup,myinputs,OPTIMIZER);
model_old = GenX.generate_model_legacy(mysetup,myinputs,OPTIMIZER);
GenX.optimize!(model)
GenX.optimize!(model_old)
println(abs(GenX.objective_value(model) - GenX.objective_value(model_old)))

mysetup["Benders"] = 1;

planning_problem = GenX.generate_planning_problem(mysetup,myinputs,PLANNING_OPTIMIZER);

decomp_subproblems = Dict();
for w in keys(myinputs_decomp)
    decomp_subproblems[w] = GenX.generate_operation_subproblem(mysetup, myinputs_decomp[w], SUBPROB_OPTIMIZER);
end





