@doc raw"""
	write_elec_power_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the values of energy consumption by electrolyzers in operation.
"""
function write_elec_power_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	ELECTROLYZERS = inputs["ELECTROLYZER"] 
	T = inputs["T"]     # Number of time steps (hours)

	# Power injected by each resource in each time step
	dfElec_Power = DataFrame(Resource = dfGen[ELECTROLYZERS,:Resource], Zone = dfGen[ELECTROLYZERS,:Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, length(ELECTROLYZERS)))
	elec_power = value.(EP[:vUSE].data)
	if setup["ParameterScale"] == 1
		elec_power *= ModelScalingFactor
	end
	dfElec_Power.AnnualSum .= elec_power * inputs["omega"]
	dfElec_Power = hcat(dfElec_Power, DataFrame(elec_power, :auto))

	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfElec_Power,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfElec_Power[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(elec_power, dims = 1)

	rename!(total,auxNew_Names)
	dfElec_Power = vcat(dfElec_Power, total)
	CSV.write(joinpath(path, "electrolyzer_power_consumption.csv"), dftranspose(dfElec_Power, false), writeheader=false)
	return dfElec_Power
end
