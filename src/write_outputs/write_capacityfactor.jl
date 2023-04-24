@doc raw"""
	write_capacityfactor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the capacity factor of different resources.
"""
function write_capacityfactor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    MUST_RUN = inputs["MUST_RUN"]

    dfCapacityfactor = DataFrame(Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone], AnnualSum=zeros(G), Capacity=zeros(G), CapacityFactor=zeros(G))
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    dfCapacityfactor.AnnualSum .= value.(EP[:vP]) * inputs["omega"] * scale_factor
    dfCapacityfactor.Capacity .= value.(EP[:eTotalCap]) * scale_factor
    # We only calcualte the resulted capacity factor with total capacity > 1MW and total generation > 1MWh
    EXISTING = intersect(findall(x -> x >= 1, dfCapacityfactor.AnnualSum), findall(x -> x >= 1, dfCapacityfactor.Capacity))
    # We calculate capacity factor for thermal, vre, hydro and must run. Not for storage and flexible demand
    CF_GEN = intersect(union(THERM_ALL, VRE, HYDRO_RES, MUST_RUN), EXISTING)
    dfCapacityfactor.CapacityFactor[CF_GEN] .= (dfCapacityfactor.AnnualSum[CF_GEN] ./ dfCapacityfactor.Capacity[CF_GEN]) / sum(inputs["omega"][t] for t in 1:T)

    CSV.write(joinpath(path, "capacityfactor.csv"), dfCapacityfactor)
    return dfCapacityfactor
end
