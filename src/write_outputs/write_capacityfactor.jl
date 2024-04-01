@doc raw"""
	write_capacityfactor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the capacity factor of different resources. For co-located VRE-storage resources, this
    value is calculated if the site has either or both a solar PV or wind resource.
"""
function write_capacityfactor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    MUST_RUN = inputs["MUST_RUN"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]

    dfCapacityfactor = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        Zone = zone_id.(gen),
        AnnualSum = zeros(G),
        Capacity = zeros(G),
        CapacityFactor = zeros(G))
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    dfCapacityfactor.AnnualSum .= value.(EP[:vP]) * inputs["omega"] * scale_factor
    dfCapacityfactor.Capacity .= value.(EP[:eTotalCap]) * scale_factor

    if !isempty(VRE_STOR)
        SOLAR = setdiff(inputs["VS_SOLAR"], inputs["VS_WIND"])
        WIND = setdiff(inputs["VS_WIND"], inputs["VS_SOLAR"])
        SOLAR_WIND = intersect(inputs["VS_SOLAR"], inputs["VS_WIND"])
        gen_VRE_STOR = gen.VreStorage
        if !isempty(SOLAR)
            dfCapacityfactor.AnnualSum[SOLAR] .= value.(EP[:vP_SOLAR][SOLAR, :]).data *
                                                 inputs["omega"] * scale_factor
            dfCapacityfactor.Capacity[SOLAR] .= value.(EP[:eTotalCap_SOLAR][SOLAR]).data *
                                                scale_factor
        end
        if !isempty(WIND)
            dfCapacityfactor.AnnualSum[WIND] .= value.(EP[:vP_WIND][WIND, :]).data *
                                                inputs["omega"] * scale_factor
            dfCapacityfactor.Capacity[WIND] .= value.(EP[:eTotalCap_WIND][WIND]).data *
                                               scale_factor
        end
        if !isempty(SOLAR_WIND)
            dfCapacityfactor.AnnualSum[SOLAR_WIND] .= (value.(EP[:vP_WIND][SOLAR_WIND,
                                                          :]).data
                                                       +
                                                       value.(EP[:vP_SOLAR][SOLAR_WIND,
                                                          :]).data .*
                                                       etainverter.(gen_VRE_STOR[(gen_VRE_STOR.wind .!= 0) .& (gen_VRE_STOR.solar .!= 0)])) *
                                                      inputs["omega"] * scale_factor
            dfCapacityfactor.Capacity[SOLAR_WIND] .= (value.(EP[:eTotalCap_WIND][SOLAR_WIND]).data +
                                                      value.(EP[:eTotalCap_SOLAR][SOLAR_WIND]).data .*
                                                      etainverter.(gen_VRE_STOR[(gen_VRE_STOR.wind .!= 0) .& (gen_VRE_STOR.solar .!= 0)])) *
                                                     scale_factor
        end
    end

    # We only calcualte the resulted capacity factor with total capacity > 1MW and total generation > 1MWh
    EXISTING = intersect(findall(x -> x >= 1, dfCapacityfactor.AnnualSum),
        findall(x -> x >= 1, dfCapacityfactor.Capacity))
    # We calculate capacity factor for thermal, vre, hydro and must run. Not for storage and flexible demand
    CF_GEN = intersect(union(THERM_ALL, VRE, HYDRO_RES, MUST_RUN, VRE_STOR), EXISTING)
    dfCapacityfactor.CapacityFactor[CF_GEN] .= (dfCapacityfactor.AnnualSum[CF_GEN] ./
                                                dfCapacityfactor.Capacity[CF_GEN]) /
                                               sum(inputs["omega"][t] for t in 1:T)
    # Capacity factor for electrolyzers is based on vUSE variable not vP
    if (!isempty(ELECTROLYZER))
        dfCapacityfactor.AnnualSum[ELECTROLYZER] .= value.(EP[:vUSE][ELECTROLYZER,
                                                        :]).data * inputs["omega"] * scale_factor
        dfCapacityfactor.CapacityFactor[ELECTROLYZER] .= (dfCapacityfactor.AnnualSum[ELECTROLYZER] ./
                                                          dfCapacityfactor.Capacity[ELECTROLYZER]) /
                                                         sum(inputs["omega"][t] for t in 1:T)
    end

    CSV.write(joinpath(path, "capacityfactor.csv"), dfCapacityfactor)
    return nothing
end
