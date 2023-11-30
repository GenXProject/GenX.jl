@doc raw"""
	thermal_plant_effective_capacity(EP::Model,
	                                 inputs::Dict,
									 resources::Vector{Int},
									 capres_zone::Int,
									 timesteps::Vector{Int})::Matrix{Float64}

	Effective capacity in a capacity reserve margin zone for certain resources in the given timesteps.
"""
function thermal_plant_effective_capacity(EP, inputs, resources::Vector{Int}, capres_zone::Int, timesteps::Vector{Int})::Matrix{Float64}
    eff_cap = thermal_plant_effective_capacity.(Ref(EP), Ref(inputs), resources, Ref(capres_zone), Ref(timesteps))
	return reduce(hcat, eff_cap)
end

function thermal_plant_effective_capacity(EP::Model, inputs::Dict, y, capres_zone::Int)
	T = inputs["T"]
    timesteps = collect(1:T)
	return thermal_plant_effective_capacity(EP, inputs, y, capres_zone, timesteps)
end

function thermal_plant_effective_capacity(EP::Model, inputs::Dict, r_id::Int, capres_zone::Int, timesteps::Vector{Int})::Vector{Float64}
	y = r_id
	dfGen = inputs["dfGen"]
    capresfactor(y, capres) = dfGen[y, Symbol("CapRes_$capres")]
	eTotalCap = value.(EP[:eTotalCap][y])

	effective_capacity = capresfactor(y, capres_zone) * eTotalCap * one.(timesteps)

	if has_maintenance(inputs) && y in resources_with_maintenance(dfGen)
		resource_component = dfGen[y, :Resource]
		cap_size = dfGen[y, :Cap_Size]
		down_var = EP[Symbol(maintenance_down_name(resource_component))]
		vDOWN = value.(down_var[timesteps])
		effective_capacity = effective_capacity .- capresfactor(y, capres_zone) * vDOWN * cap_size
	end

	return effective_capacity
end
