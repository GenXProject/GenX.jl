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
	G = inputs["G"]
	T = inputs["T"] 
	RSV = inputs["RSV"]
	REG = inputs["REG"]
	dfOpResRevenue = DataFrame(Region = dfGen[RSV, :region], Resource = dfGen[RSV, :Resource], Zone = dfGen[RSV, :Zone], Cluster = dfGen[RSV, :cluster], AnnualSum = Array{Float64}(undef, length(RSV)),)
	dfOpRegRevenue = DataFrame(Region = dfGen[REG, :region], Resource = dfGen[REG, :Resource], Zone = dfGen[REG, :Zone], Cluster = dfGen[REG, :cluster], AnnualSum = Array{Float64}(undef, length(REG)),)
	#resrevenue = zeros(G, T)
	#regrevenue = zeros(G, T)
	weighted_reg_price = operating_regulation_price(EP, inputs, setup)
	weighted_rsv_price = operating_reserve_price(EP, inputs, setup)
	resrevenue = value.(EP[:vRSV][RSV, :].data).* transpose(weighted_rsv_price)

	regrevenue = value.(EP[:vREG][REG, :].data) .* transpose(weighted_reg_price)

	if setup["ParameterScale"] == 1
		resrevenue *= scale_factor
		regrevenue *= scale_factor
	end

	dfOpResRevenue.AnnualSum .= resrevenue * inputs["omega"]
	dfOpRegRevenue.AnnualSum .= regrevenue * inputs["omega"]
	write_simple_csv(joinpath(path, "OperatingReserveRevenue.csv"), dfOpResRevenue)
	write_simple_csv(joinpath(path, "OperatingRegulationRevenue.csv"), dfOpRegRevenue)
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
