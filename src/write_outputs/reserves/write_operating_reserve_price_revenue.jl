@doc raw"""
	write_operating_reserve_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the operating reserve prices and revenue earned by generators listed in the input file.
    GenX will print this file only when operating reserve is modeled and the shadow price can be obtained form the solver.
    The revenue is calculated as the operating reserve contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps.
    The last column is the total revenue received from all operating reserve constraints.
    As a reminder, GenX models the operating reserve at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_operating_reserve_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
  	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	dfOpResRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster)
	dfOpRegRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster)
	#annual_sum = zeros(G)
	weighted_reg_price = operating_regulation_price(EP, inputs, setup) .* inputs["omega"]
	weighted_rsv_price = operating_reserve_price(EP, inputs, setup) .* inputs["omega"]
	#regsym = Symbol("Reg_Max")
	#rsvsym = Symbol("Rsv_Max")
	tempregrev = weighted_reg_price#zeros(G)
	tempresrev = weighted_rsv_price#zeros(G)
	tempregrev *= scale_factor
	tempresrev *= scale_factor
	#annual_reg_sum .+= tempregrev
	#annual_res_sum .+= tempresrev
	#print(DataFrame([tempregrev], :auto))
	#print(DataFrame([tempresrev], :auto))
	dfOpRegRevenue = DataFrame([tempregrev], :auto)#, [sym]))
	dfOpResRevenue = DataFrame([tempresrev], :auto)#, [sym]))

	dfOpRegRevenue.AnnualSum = tempregrev#annual_reg_sum
	dfOpResRevenue.AnnualSum = tempresrev#annual_res_sum
	CSV.write(joinpath(path, "OperatingRegulationRevenue.csv"), dfOpRegRevenue)
	CSV.write(joinpath(path, "OperatingReserveRevenue.csv"), dfOpResRevenue)
	return dfOpRegRevenue, dfOpResRevenue
end

@doc raw"""
    operating_regulation_price(EP::Model,
                                  inputs::Dict,
                                  setup::Dict)::Vector{Float64}

Operating regulation price for each time step.
This is equal to the dual variable of the regulatin requirement constraint.

    Returns a vector, with units of $/MW
"""

function operating_regulation_price(EP::Model, inputs::Dict, setup::Dict)::Vector{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cReg]) ./ ω * scale_factor
end

@doc raw"""
    operating_reserve_price(EP::Model,
                                  inputs::Dict,
                                  setup::Dict)::Vector{Float64}

Operating reserve price for each time step.
This is equal to the dual variable of the reserve requirement constraint.

    Returns a vector, with units of $/MW
"""

function operating_reserve_price(EP::Model, inputs::Dict, setup::Dict)::Vector{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cRsvReq]) ./ ω * scale_factor
end
