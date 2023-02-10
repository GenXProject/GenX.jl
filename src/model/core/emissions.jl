@doc raw"""
	emissions(EP::Model, inputs::Dict)

This function creates expression to add the CO2 emissions by plants in each zone, which is subsequently added to the total emissions
"""
function emissions!(EP::Model, inputs::Dict)

	println("Emissions Module (for CO2 Policy modularization")

	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	@expression(EP, eEmissionsByPlant[y=1:G,t=1:T],

		if y in inputs["COMMIT"]
			dfGen[y,:CO2_per_MWh]*EP[:vP][y,t]+dfGen[y,:CO2_per_Start]*EP[:vSTART][y,t]
		else
			dfGen[y,:CO2_per_MWh]*EP[:vP][y,t]
		end
	)
	@expression(EP, eEmissionsByZone[z=1:Z, t=1:T], sum(eEmissionsByPlant[y,t] for y in dfGen[(dfGen[!,:Zone].==z),:R_ID]))

end
