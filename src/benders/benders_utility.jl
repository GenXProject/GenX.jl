
function separate_inputs_subperiods(inputs::Dict)

    inputs_all=Dict();
    number_periods = inputs["REP_PERIOD"];
    hours_per_subperiod = inputs["hours_per_subperiod"];
    
    ####### entries_to_be_changed = ["omega","REP_PERIOD",","INTERIOR_SUBPERIODS","START_SUBPERIODS","pP_Max","T","fuel_costs","Weights","pD","C_Start"];

    for w in 1:number_periods
        inputs_all[w] = deepcopy(inputs);
        Tw = (w-1)*hours_per_subperiod+1:w*hours_per_subperiod;
        if haskey(inputs, "omega")
            inputs_all[w]["omega"] = inputs["omega"][Tw];
        end
        inputs_all[w]["REP_PERIOD"]=1;
        STARTS = 1:hours_per_subperiod:hours_per_subperiod;
        INTERIORS = setdiff(1:hours_per_subperiod,STARTS);   
        inputs_all[w]["INTERIOR_SUBPERIODS"] = INTERIORS;
        inputs_all[w]["START_SUBPERIODS"] = STARTS;
        if haskey(inputs, "pP_Max")
            inputs_all[w]["pP_Max"] = inputs["pP_Max"][:,Tw];
        end
        inputs_all[w]["T"] = hours_per_subperiod;
        for ks in keys(inputs["fuel_costs"])
            inputs_all[w]["fuel_costs"][ks] = inputs["fuel_costs"][ks][Tw];
        end
        if haskey(inputs, "Weights")
            inputs_all[w]["Weights"] = [inputs["Weights"][w]];
        end
        if haskey(inputs, "pD")
            inputs_all[w]["pD"] = inputs["pD"][Tw,:];
        end
        if haskey(inputs, "C_start")
            inputs_all[w]["C_Start"] = inputs["C_Start"][:,Tw]; 
        end
        inputs_all[w]["SubPeriod"] = w;
		if haskey(inputs,"Period_Map")
			inputs_all[w]["SubPeriod_Index"] = inputs["Period_Map"].Rep_Period[findfirst(inputs["Period_Map"].Rep_Period_Index.==w)];
		end
        if haskey(inputs, "node_to_timeseries")
            for k in keys(inputs["node_to_timeseries"])
                inputs_all[w]["node_to_timeseries"][k] = inputs["node_to_timeseries"][k][Tw]
            end
        end
    end

    return inputs_all

end


function generate_benders_inputs(setup::Dict,inputs::Dict,inputs_decomp::Dict)

    planning_problem, planning_variables = init_planning_problem(setup,inputs);

    subproblems_dist,planning_variables_sub = init_dist_subproblems(setup,inputs_decomp,planning_variables);

    benders_inputs = Dict();
	benders_inputs["planning_problem"] = planning_problem;
	benders_inputs["planning_variables"] = planning_variables;

    benders_inputs["subproblems"] = subproblems_dist;
	benders_inputs["planning_variables_sub"] = planning_variables_sub;

    return benders_inputs


end

function check_negative_capacities(EP::Model)

	neg_cap_bool = false;
	tol = -1e-8;
	if any(value.(EP[:eTotalCap]).< tol) 
			neg_cap_bool = true;
	elseif haskey(EP,:eTotalCapEnergy)
		if any(value.(EP[:eTotalCapEnergy]).< tol)
			neg_cap_bool = true;
		end
	elseif haskey(EP,:eTotalCapCharge)
		if any(value.(EP[:eTotalCapCharge]).< tol)
			neg_cap_bool = true;
		end
	elseif haskey(EP,:eAvail_Trans_Cap)
		if any(value.(EP[:eAvail_Trans_Cap]).< tol)
			neg_cap_bool = true;
		end
	end
	return neg_cap_bool
end

function reset_subproblem_vector_to_bilinear(subproblems::Vector{Dict{Any,Any}}, inputs)
    for m in subproblems
        EP = m["Model"]
        reset_subproblem_to_bilinear(EP, inputs)
    end
end

function reset_subproblem_to_bilinear(EP::Model, inputs::Dict)
    #syms_to_delete = [:slack_vFLOW, :slackup_vFLOW, :slackdown_vFLOW, :slackup_vCANDFLOW, :slackdown_vCANDFLOW, :cPOWER_FLOW_OPF_NONRETIRE, :cPOWER_FLOW_OPF_RETIRE_FORWARD, :cPOWER_FLOW_OPF_RETIRE_REVERSE, :cPOWER_FLOW_OPF_EXPANSION_FORWARD, :cPOWER_FLOW_OPF_EXPANSION_REVERSE, :cCAN_RETIRE_UPPER_LIMIT, :cCAN_RETIRE_LOWER_LIMIT]
    syms_to_delete = [
        :cPOWER_FLOW_OPF_NONRETIRE, 
        :cPOWER_FLOW_OPF_RETIRE_FORWARD, 
        :cPOWER_FLOW_OPF_RETIRE_REVERSE, 
        :cPOWER_FLOW_OPF_EXPANSION_FORWARD, 
        :cPOWER_FLOW_OPF_EXPANSION_REVERSE, 
        :cCAN_RETIRE_UPPER_LIMIT, 
        :cCAN_RETIRE_LOWER_LIMIT
    ]
    for sym in syms_to_delete
        println("DELETING $sym")
        JuMP.delete.(EP, EP[sym])
        JuMP.unregister(EP, sym)
    end

    CANNOT_RETIRE_LINES = inputs["CANNOT_RETIRE_LINES"]
    CAN_RETIRE_LINES = inputs["CAN_RETIRE_LINES"]
    CANDIDATE_LINES = inputs["CANDIDATE_LINES"]
    existing_to_cand_map = inputs["existing_to_cand_map"]
    T = inputs["H"]
    Z = inputs["Z"]
    L = inputs["L"]

    println("ADDING CONSTRAINTS")
    @constraint(EP,
            cPOWER_FLOW_OPF_NONRETIRE_BILINEAR[l in CANNOT_RETIRE_LINES, t = 1:T],
            EP[:vFLOW][l,t]
            ==inputs["pDC_OPF_coeff"][l] *
                    sum(inputs["pNet_Map"][l, z] * EP[:vANGLE][z, t] for z in 1:Z)
    )
    println("ADDED NONRETIRE CONSTRAINT")

    @constraint(EP,
        cPOWER_FLOW_OPF_RETIRE_BILINEAR[l in CAN_RETIRE_LINES, t = 1:T],
        EP[:vFLOW][l,
            t]==inputs["pDC_OPF_coeff"][l] *
                sum(inputs["pNet_Map"][l, z] * EP[:vANGLE][z, t] for z in 1:Z) * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
    )
    println("ADDED RETIRE CONSTRAINT")

    @constraint(EP,
        cCANDFLOW_BILINEAR[l in CANDIDATE_LINES, t = 1:T],
        EP[:vCANDFLOW][l, t] == inputs["pDC_OPF_coeff"][l] *
                    sum(inputs["pNet_Map"][l, z] * EP[:vANGLE][z, t] for z in 1:Z) * EP[:vNEW_TRANS_CAP_DECISION_INT][l]
    )
    println("ADDED CANDFLOW CONSTRAINT")
end

function reset_subproblem_vector_to_linear(subproblems::Vector{Dict{Any,Any}}, inputs)
    for m in subproblems
        EP = m["Model"]
        reset_subproblem_to_linear(EP, inputs)
    end
end

function reset_subproblem_to_linear(EP::Model, inputs::Dict)
    #syms_to_delete = [:slack_vFLOW, :slackup_vFLOW, :slackdown_vFLOW, :slackup_vCANDFLOW, :slackdown_vCANDFLOW, :cPOWER_FLOW_OPF_NONRETIRE, :cPOWER_FLOW_OPF_RETIRE_FORWARD, :cPOWER_FLOW_OPF_RETIRE_REVERSE, :cPOWER_FLOW_OPF_EXPANSION_FORWARD, :cPOWER_FLOW_OPF_EXPANSION_REVERSE, :cCAN_RETIRE_UPPER_LIMIT, :cCAN_RETIRE_LOWER_LIMIT]
    
    for var in EP[:slack_vFLOW]
        fix(var, 0, force = true)
    end
    for var in EP[:slackup_vFLOW]
        fix(var, 0, force = true)
    end
    for var in EP[:slackdown_vFLOW]
        fix(var, 0, force = true)
    end
    for var in EP[:slackup_vCANDFLOW]
        fix(var, 0, force = true)
    end
    for var in EP[:slackdown_vCANDFLOW]
        fix(var, 0, force = true)
    end
end