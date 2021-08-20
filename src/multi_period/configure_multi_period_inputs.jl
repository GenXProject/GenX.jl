function compute_overnight_capital_cost(settings_d::Dict,inv_costs_yr::Array,crp::Array)

	cur_period = settings_d["CurPeriod"] # Current DDP Time Period
	num_periods = settings_d["NumPeriods"] # Total number of DDP time periods
	period_len = settings_d["PeriodLength"] # Length (in years) of each period
	wacc = settings_d["WACC"] # Interest Rate and also the discount rate unless specified other wise

	# 1) For each technology, find the minimum of the capital recovery period and the end of the planning horizon
	# KEY ASSUMPTION: Investment costs after the planning horizon are fully recoverable, so we don't need to include these costs
	total_yrs_remaining = period_len * num_periods - period_len * (cur_period-1) # Total time between the end of the final period and the start of the current period
	gen_yrs_remaining = min.(crp, total_yrs_remaining) # Use capital recovery period or end of planning horizon, whichever comes first

	println("AIC: ", inv_costs_yr)
	println("Years Remaining: ", gen_yrs_remaining)
	# 2) Compute the present value of investment associated with capital recovery period within the model horizon - discounting to year 1 and not year 0
	### Factor to adjust discounting to year 0 for capital cost is included in the discounting coefficient applied to all terms in the objective function value.
	### See GenX_DDP_notes_2021_02_25.docx for further details
	overnight_capital_cost = zeros(length(inv_costs_yr))
	for i in 1:length(overnight_capital_cost)
		overnight_capital_cost[i] = sum(inv_costs_yr[i]/(1+wacc) .^ (p) for p=1:gen_yrs_remaining[i])
	end

	# 4) Return the overnight capital cost (discounted sum of annual investment costs incured within the model horizon)
	println("OCC: ", overnight_capital_cost)
	return overnight_capital_cost
end

function configure_multi_period_inputs(inputs::Dict, settings_d::Dict, NetworkExpansion::Int64)

    dfGen = inputs["dfGen"]
	dfGenMultiPeriod = inputs["dfGenMultiPeriod"]

	# Parameter inputs when multi-year discounting is activated
	period_len = settings_d["PeriodLength"] # Length (in years) of each period
	cur_period = settings_d["CurPeriod"]
	wacc = settings_d["WACC"] # Interest Rate  and also the discount rate unless specified other wise

	# 1. Convert annualized investment costs incured within the model horizon into overnight capital costs
	# NOTE: Although the "yr" suffix is still in use in these parameter names, they no longer represent annualized costs
	inputs["dfGen"][!,:Inv_Cost_per_MWyr] = compute_overnight_capital_cost(settings_d,dfGen[!,:Inv_Cost_per_MWyr],dfGenMultiPeriod[!,:Capital_Recovery_Period])
	inputs["dfGen"][!,:Inv_Cost_per_MWhyr] = compute_overnight_capital_cost(settings_d,dfGen[!,:Inv_Cost_per_MWhyr],dfGenMultiPeriod[!,:Capital_Recovery_Period])
	inputs["dfGen"][!,:Inv_Cost_Charge_per_MWyr] = compute_overnight_capital_cost(settings_d,dfGen[!,:Inv_Cost_Charge_per_MWyr],dfGenMultiPeriod[!,:Capital_Recovery_Period])

	# 2. Update fixed O&M costs to account for the possibility of more than 1 year between two model time periods
	OPEXDF = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_len)]) # OPEX multiplier to count multiple years between two model time periods

	# Update fixed O&M costs
	# NOTE: Although the "yr" suffix is still in use in these parameter names, they now represent total costs incured in each period, which may be multiple years
	inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] = OPEXDF.*inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr]
	inputs["dfGen"][!,:Fixed_OM_Cost_per_MWhyr] = OPEXDF.*inputs["dfGen"][!,:Fixed_OM_Cost_per_MWhyr]
	inputs["dfGen"][!,:Fixed_OM_Cost_charge_per_MWyr] = OPEXDF.*inputs["dfGen"][!,:Fixed_OM_Cost_Charge_per_MWyr]

    # Set of all resources eligible for capacity retirements
	inputs["RET_CAP"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID])
	# Set of all storage resources eligible for energy capacity retirements
	inputs["RET_CAP_ENERGY"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], inputs["STOR_ALL"])
	# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
	inputs["RET_CAP_CHARGE"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], inputs["STOR_ASYMMETRIC"])

	# Transmission
	if NetworkExpansion == 1 && inputs["Z"] > 1

		dfNetworkMultiPeriod = inputs["dfNetworkMultiPeriod"]

		# 1. Convert annualized tramsmission investment costs incured within the model horizon into overnight capital costs
		inputs["pC_Line_Reinforcement"] = compute_overnight_capital_cost(settings_d,inputs["pC_Line_Reinforcement"],dfNetworkMultiPeriod[!,:Capital_Recovery_Period])

		# Scale max_allowed_reinforcement to allow for possibility of deploying maximum reinforcement in each investment period
		inputs["pTrans_Max_Possible"] = inputs["pLine_Max_Flow_Possible_MW_p$cur_period"]

        # Network lines and zones that are expandable have greater maximum possible line flow than that of the previous period
		if cur_period > 1
			inputs["EXPANSION_LINES"] = findall(inputs["pLine_Max_Flow_Possible_MW_p$cur_period"] .> inputs["pLine_Max_Flow_Possible_MW_p$(cur_period-1)"])
        	inputs["NO_EXPANSION_LINES"] = findall(inputs["pLine_Max_Flow_Possible_MW_p$cur_period"] .<= inputs["pLine_Max_Flow_Possible_MW_p$(cur_period-1)"])
		else
			inputs["EXPANSION_LINES"] = findall(inputs["pLine_Max_Flow_Possible_MW_p$cur_period"] .> inputs["pTrans_Max"])
			inputs["NO_EXPANSION_LINES"] = findall(inputs["pLine_Max_Flow_Possible_MW_p$cur_period"] .<= inputs["pTrans_Max"])
		end

		#To-Do: Error handling (Line Flow must be monotonically increasing, in first period must be negative or greater than pTrans_Max)
    end

    return inputs
end