@doc raw"""
	write_operating_reserve_regulation_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the operating reserve and regulation revenue earned by generators listed in the input file.
    GenX will print this file only when operating reserve and regulation are modeled and the shadow price can be obtained from the solver.
    The revenues are calculated as the operating reserve and regulation contributions in each time step multiplied by the corresponding shadow price, and then the sum is taken over all modeled time steps.
    The last column is the total revenue received from all operating reserve and regulation constraints.
    As a reminder, GenX models the operating reserve and regulation at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_operating_reserve_regulation_revenue(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    gen = inputs["RESOURCES"]
    RSV = inputs["RSV"]
    REG = inputs["REG"]

    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)
    names = inputs["RESOURCE_NAMES"]

    dfOpRsvRevenue = DataFrame(Region = regions[RSV],
        Resource = names[RSV],
        Zone = zones[RSV],
        Cluster = clusters[RSV],
        AnnualSum = Array{Float64}(undef, length(RSV)))
    dfOpRegRevenue = DataFrame(Region = regions[REG],
        Resource = names[REG],
        Zone = zones[REG],
        Cluster = clusters[REG],
        AnnualSum = Array{Float64}(undef, length(REG)))

    weighted_reg_price = operating_regulation_price(EP, inputs, setup)
    weighted_rsv_price = operating_reserve_price(EP, inputs, setup)

    rsvrevenue = value.(EP[:vRSV][RSV, :].data) .* transpose(weighted_rsv_price)
    regrevenue = value.(EP[:vREG][REG, :].data) .* transpose(weighted_reg_price)

    rsvrevenue *= scale_factor
    regrevenue *= scale_factor

    dfOpRsvRevenue.AnnualSum .= rsvrevenue * inputs["omega"]
    dfOpRegRevenue.AnnualSum .= regrevenue * inputs["omega"]

    write_simple_csv(joinpath(path, "OperatingReserveRevenue.csv"), dfOpRsvRevenue)
    write_simple_csv(joinpath(path, "OperatingRegulationRevenue.csv"), dfOpRegRevenue)
    return dfOpRegRevenue, dfOpRsvRevenue
end

@doc raw"""
    operating_regulation_price(EP::Model,
                                  inputs::Dict,
                                  setup::Dict)::Vector{Float64}

Operating regulation price for each time step.
This is equal to the dual variable of the regulation requirement constraint.

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
