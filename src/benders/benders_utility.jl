
@doc raw"""
	separate_inputs_subperiods(inputs)

Decompose the full-year `inputs` dictionary into per-representative-period sub-dictionaries.

Returns a `Dict` keyed by subperiod index `w = 1:REP_PERIOD`, where each entry is a deep
copy of `inputs` with time-indexed arrays (demand `pD`, capacity factors `pP_Max`,
fuel costs, start costs, time weights `omega`, etc.) sliced to the hours belonging to
subperiod `w`.  Each sub-dictionary also carries `REP_PERIOD = 1` and a `SubPeriod` field
with its index, making it self-contained for building a single operational subproblem.
"""
function separate_inputs_subperiods(inputs::Dict)

    inputs_all=Dict();
    number_periods = inputs["REP_PERIOD"];
    hours_per_subperiod = inputs["hours_per_subperiod"];
    

    for w in 1:number_periods
        inputs_all[w] = Dict()
        Tw = (w-1)*hours_per_subperiod+1:w*hours_per_subperiod;
        inputs_all[w]["omega"] = inputs["omega"][Tw];
        inputs_all[w]["REP_PERIOD"]=1;
        STARTS = 1:hours_per_subperiod:hours_per_subperiod;
        INTERIORS = setdiff(1:hours_per_subperiod,STARTS);   
        inputs_all[w]["INTERIOR_SUBPERIODS"] = INTERIORS;
        inputs_all[w]["START_SUBPERIODS"] = STARTS;
        inputs_all[w]["pP_Max"] = inputs["pP_Max"][:,Tw];
        inputs_all[w]["T"] = hours_per_subperiod;
        inputs_all[w]["fuel_costs"] = Dict();
        for ks in keys(inputs["fuel_costs"])
            inputs_all[w]["fuel_costs"][ks] = inputs["fuel_costs"][ks][Tw];
        end
        if haskey(inputs, "pP_Max_Wind")
            inputs_all[w]["pP_Max_Wind"] = inputs["pP_Max_Wind"][:,Tw];
        end
        if haskey(inputs, "pP_Max_Solar")
            inputs_all[w]["pP_Max_Solar"] = inputs["pP_Max_Solar"][:,Tw];
        end
        inputs_all[w]["Weights"] = [inputs["Weights"][w]];
        inputs_all[w]["pD"] = inputs["pD"][Tw,:];
        if haskey(inputs, "C_Start")
            inputs_all[w]["C_Start"] = inputs["C_Start"][:,Tw]; 
        end
        inputs_all[w]["SubPeriod"] = w;
		if haskey(inputs,"Period_Map")
			inputs_all[w]["SubPeriod_Index"] = inputs["Period_Map"].Rep_Period[findfirst(inputs["Period_Map"].Rep_Period_Index.==w)];
		end
        if haskey(inputs, "dfHM_absolute")
            inputs_all[w]["dfHM_absolute"] = inputs["dfHM_absolute"][Tw,:];
        end
        for k in keys(inputs)
            if !haskey(inputs_all[w],k)
                inputs_all[w][k] = inputs[k];
            end
        end
    end

    return inputs_all

end

@doc raw"""
	generate_benders_inputs(setup, inputs, inputs_decomp, optimizer)

Build and return the complete set of Benders decomposition inputs as a `Dict`.

Initializes the planning (master) problem and all operational subproblems, then assembles
them into a single `benders_inputs` dictionary with fields:
- `"planning_problem"`: the master JuMP model
- `"planning_variables"`: names of first-stage decision variables
- `"subproblems"`: operational subproblem dicts — a `Vector{Dict}` when running with a
  single Julia process (`nworkers() == 1`), or a `DArray` across multiple workers otherwise
- `"planning_variables_sub"`: per-subperiod mapping of linking variable names

The "subproblems" entry of the dictionary uses a `Vector{Dict}` when only one process is 
available to avoid routing every subproblem solve through Julia's distributed message-passing
infrastructure (`@fetchfrom 1 / @spawnat 1`), which can deadlock when the solver (e.g. HiGHS IPM) 
spawns OpenMP threads that interfere with Julia's cooperative task scheduler on the single OS thread. 
"""
function generate_benders_inputs(setup::Dict, inputs::Dict, inputs_decomp::Dict, optimizer::Any)

    planning_problem, planning_variables = init_planning_problem(setup, inputs, optimizer);

    if nworkers() == 1
        subproblems, planning_variables_sub = init_sequential_subproblems(setup, inputs_decomp, planning_variables, optimizer)
    else
        subproblems, planning_variables_sub = init_dist_subproblems(setup, inputs_decomp, planning_variables, optimizer)
    end

    benders_inputs = Dict();
	benders_inputs["planning_problem"] = planning_problem;
	benders_inputs["planning_variables"] = planning_variables;

    benders_inputs["subproblems"] = subproblems;
	benders_inputs["planning_variables_sub"] = planning_variables_sub;

    return benders_inputs
end
