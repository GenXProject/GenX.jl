function load_generators_data_multi_period(setup::Dict, path::AbstractString, sep::AbstractString, inputs::Dict)
    # Generator related multi-period inputs
	gen_mp_in = DataFrame(CSV.File(string(path,sep,"Generators_data_multi_period.csv"), header=true), copycols=true)

    num_periods = setup["MultiPeriodSettingsDict"]["NumPeriods"]

    # Store DataFrame of generators/resources multi-period input data for use in model
	inputs["dfGenMultiPeriod"] = gen_mp_in

	if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values 

        # Overnight capacity investment cost of a generation technology
        #inputs["dfGenMultiPeriod"][!,:Inv_Cost_per_MW] = gen_mp_in[!,:Inv_Cost_per_MW]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
        # Overnight investment cost of the energy capacity for a storage technology with STOR = 1 or STOR = 2
        #inputs["dfGenMultiPeriod"][!,:Inv_Cost_per_MWh] = gen_mp_in[!,:Inv_Cost_per_MWh]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions
        # Overnight capacity investment cost for the charging portion of a storage technology with STOR = 2
        #inputs["dfGenMultiPeriod"][!,:Inv_Cost_Charge_per_MW] = gen_mp_in[!,:Inv_Cost_Charge_per_MW]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions

		for p in 1:num_periods
			inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p$p")] = gen_mp_in[!,Symbol("Min_Retired_Cap_MW_p$p")]/ModelScalingFactor # Convert to GW
			inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p$p")] = gen_mp_in[!,Symbol("Min_Retired_Charge_Cap_MW_p$p")]/ModelScalingFactor # Convert to GW
			inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p$p")] = gen_mp_in[!,Symbol("Min_Retired_Energy_Cap_MW_p$p")]/ModelScalingFactor # Convert to GW
		end
    end

    println("Generators_data_multi_period.csv Successfully Read!")

    return inputs
end