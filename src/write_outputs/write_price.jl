@doc raw"""
    write_price(path::AbstractString, inputs::Dict, setup::Dict, EP::Model,
        cache::OutputCache = build_output_cache(EP, inputs, setup))

Function for reporting marginal electricity price for each model zone and time step. Marginal electricity price is equal to the dual variable of the power balance constraint. If GenX is configured as a mixed integer linear program, then this output is only generated if `WriteShadowPrices` flag is activated. If configured as a linear program (i.e. linearized unit commitment or economic dispatch) then output automatically available.
The optional `cache` argument allows callers to reuse extracted model outputs across
multiple write functions to reduce memory allocations.
"""
function write_price(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model,
    cache::OutputCache = build_output_cache(EP, inputs, setup))
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    ## Extract dual variables of constraints
    # Electricity price: Dual variable of hourly power balance constraint = hourly price
    dfPrice = DataFrame(Zone = 1:Z) # The unit is $/MWh
    # Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
        price = isnothing(cache.price) ? locational_marginal_price(EP, inputs, setup) :
            cache.price
    dfPrice = hcat(dfPrice, DataFrame(transpose(price), :auto))

    auxNew_Names = [Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfPrice, auxNew_Names)

    ## Linear configuration final output
    write_transposed_csv(joinpath(path, "prices.csv"), dfPrice, writeheader = false)

    if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
        write_full_time_series_reconstruction(path, setup, dfPrice, "prices")
        @info("Writing Full Time Series for Price")
    end
    return nothing
end

@doc raw"""
	locational_marginal_price(EP::Model, inputs::Dict, setup::Dict)

Marginal electricity price for each model zone and time step.
This is equal to the dual variable of the power balance constraint.
When solving a linear program (i.e. linearized unit commitment or economic dispatch)
this output is always available; when solving a mixed integer linear program, this can
be calculated only if `WriteShadowPrices` is activated.

    Returns a matrix of size (T, Z).
    Values have units of USD/MWh
"""
function locational_marginal_price(EP::Model, inputs::Dict, setup::Dict)::Matrix{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cPowerBalance]) ./ ω * scale_factor
end
