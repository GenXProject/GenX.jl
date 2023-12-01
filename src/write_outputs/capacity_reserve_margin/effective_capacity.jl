@doc raw"""
	thermal_plant_effective_capacity(EP::Model,
	                                 inputs::Dict,
									 resources::Vector{Int},
									 capres_zone::Int,
									 timesteps::Vector{Int})::Matrix{Float64}

	Effective capacity in a capacity reserve margin zone for certain resources in the given timesteps.
"""
function thermal_plant_effective_capacity(
    EP,
    inputs,
    resources::Vector{Int},
    capres_zone::Int,
    timesteps::Vector{Int},
)::Matrix{Float64}
    eff_cap =
        thermal_plant_effective_capacity.(
            Ref(EP),
            Ref(inputs),
            resources,
            Ref(capres_zone),
            Ref(timesteps),
        )
    return reduce(hcat, eff_cap)
end

function thermal_plant_effective_capacity(EP::Model, inputs::Dict, y, capres_zone::Int)
    T = inputs["T"]
    timesteps = collect(1:T)
    return thermal_plant_effective_capacity(EP, inputs, y, capres_zone, timesteps)
end

function thermal_plant_effective_capacity(
    EP::Model,
    inputs::Dict,
    r_id::Int,
    capres_zone::Int,
    timesteps::Vector{Int},
)::Vector{Float64}
    y = r_id
    dfGen = inputs["dfGen"]
    capresfactor = dfGen[y, Symbol("CapRes_$capres_zone")]
    eTotalCap = value.(EP[:eTotalCap][y])

    effective_capacity = fill(capresfactor * eTotalCap, length(timesteps))

    if has_maintenance(inputs) && y in resources_with_maintenance(dfGen)
		adjustment = thermal_maintenance_capacity_reserve_margin_adjustment(EP, inputs, y, capres_zone, timesteps)
		effective_capacity = effective_capacity .+ value.(adjustment)
	end

	if has_fusion(inputs) && y in resources_with_fusion(dfGen)
		resource_component = dfGen[y, :Resource]
		adjustment = thermal_fusion_capacity_reserve_margin_adjustment(EP, inputs, resource_component, y, capres_zone, timesteps)
		effective_capacity = effective_capacity .+ value.(adjustment)
	end

    return effective_capacity
end
