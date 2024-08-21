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
    weight = inputs["omega"]

    df = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        Zone = zone_id.(gen),
        AnnualSum = zeros(G),
        Capacity = zeros(G),
        CapacityFactor = zeros(G))
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    df.AnnualSum .= value.(EP[:vP]) * weight * scale_factor
    df.Capacity .= value.(EP[:eTotalCap]) * scale_factor

    # The .data only works on DenseAxisArray variables or expressions
    # In contract vP and eTotalCap are whole vectors / matrices
    energy_sum(sym, set) = value.(EP[sym][set, :]).data * weight * scale_factor
    capacity(sym, set) = value.(EP[sym][set]).data * scale_factor

    if !isempty(VRE_STOR)
        VS_SOLAR = inputs["VS_SOLAR"]
        VS_WIND = inputs["VS_WIND"]
        SOLAR = setdiff(VS_SOLAR, VS_WIND)
        WIND = setdiff(VS_WIND, VS_SOLAR)
        SOLAR_WIND = intersect(VS_SOLAR, VS_WIND)
        gen_VRE_STOR = gen.VreStorage
        if !isempty(SOLAR)
            df.AnnualSum[SOLAR] .= energy_sum(:vP_SOLAR, SOLAR)
            df.Capacity[SOLAR] .= capacity(:eTotalCap_SOLAR, SOLAR)
        end
        if !isempty(WIND)
            df.AnnualSum[WIND] .= energy_sum(:vP_WIND, WIND)
            df.Capacity[WIND] .= capacity(:eTotalCap_WIND, WIND)
        end
        if !isempty(SOLAR_WIND)
            inverter_efficiency = etainverter.(gen[SOLAR_WIND])
            df.AnnualSum[SOLAR_WIND] .= energy_sum(:vP_WIND, SOLAR_WIND) +
                                        energy_sum(:vP_SOLAR, SOLAR_WIND) .*
                                        inverter_efficiency

            df.Capacity[SOLAR_WIND] .= capacity(:eTotalCap_WIND, SOLAR_WIND) +
                                       capacity(
                :eTotalCap_SOLAR, SOLAR_WIND) .* inverter_efficiency
        end
    end

    # We only calculate the resulting capacity factor with total capacity > 1MW and total generation > 1MWh
    produces_power = findall(x -> x >= 1, df.AnnualSum)
    has_capacity = findall(x -> x >= 1, df.Capacity)
    EXISTING = intersect(produces_power, has_capacity)
    # We calculate capacity factor for thermal, vre, hydro and must run. Not for storage and flexible demand
    CF_GEN = intersect(union(THERM_ALL, VRE, HYDRO_RES, MUST_RUN, VRE_STOR), EXISTING)
    df.CapacityFactor[CF_GEN] .= (df.AnnualSum[CF_GEN] ./
                                  df.Capacity[CF_GEN]) /
                                 sum(weight)
    # Capacity factor for electrolyzers is based on vUSE variable not vP
    if !isempty(ELECTROLYZER)
        df.AnnualSum[ELECTROLYZER] .= energy_sum(:vUSE, ELECTROLYZER)
        df.CapacityFactor[ELECTROLYZER] .= (df.AnnualSum[ELECTROLYZER] ./
                                            df.Capacity[ELECTROLYZER]) /
                                           sum(weight)
    end

    CSV.write(joinpath(path, "capacityfactor.csv"), df)
    return nothing
end
