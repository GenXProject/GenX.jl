@doc raw"""
	write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file, or if a generator is subject to a Minimum Capacity Requirement constraint. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)
    rid = resource_id.(gen)

    G = inputs["G"]

    dfSubRevenue = DataFrame(Region = regions,
        Resource = inputs["RESOURCE_NAMES"],
        Zone = zones,
        Cluster = clusters,
        R_ID = rid,
        SubsidyRevenue = zeros(G))
    MIN_CAP = ids_with_positive(gen, min_cap_mw)
    if !isempty(inputs["VRE_STOR"])
        MIN_CAP_SOLAR = ids_with_positive(gen.VreStorage, min_cap_solar_mw)
        MIN_CAP_WIND = ids_with_positive(gen.VreStorage, min_cap_wind_mw)
        MIN_CAP_STOR = ids_with_positive(gen, min_cap_mwh)
        if !isempty(MIN_CAP_SOLAR)
            dfSubRevenue.SubsidyRevenue[MIN_CAP_SOLAR] .+= (value.(EP[:eTotalCap_SOLAR])[MIN_CAP_SOLAR]) .*
                                                           (dual.(EP[:cMinCap_Solar][MIN_CAP_SOLAR])).data
        end
        if !isempty(MIN_CAP_WIND)
            dfSubRevenue.SubsidyRevenue[MIN_CAP_WIND] .+= (value.(EP[:eTotalCap_WIND])[MIN_CAP_WIND]) .*
                                                          (dual.(EP[:cMinCap_Wind][MIN_CAP_WIND])).data
        end
        if !isempty(MIN_CAP_STOR)
            dfSubRevenue.SubsidyRevenue[MIN_CAP_STOR] .+= (value.(EP[:eTotalCap_STOR])[MIN_CAP_STOR]) .*
                                                          (dual.(EP[:cMinCap_Stor][MIN_CAP_STOR])).data
        end
    end
    dfSubRevenue.SubsidyRevenue[MIN_CAP] .= (value.(EP[:eTotalCap])[MIN_CAP]) .*
                                            (dual.(EP[:cMinCap][MIN_CAP])).data
    ### calculating tech specific subsidy revenue
    dfRegSubRevenue = DataFrame(Region = regions,
        Resource = inputs["RESOURCE_NAMES"],
        Zone = zones,
        Cluster = clusters,
        R_ID = rid,
        SubsidyRevenue = zeros(G))
    if (setup["MinCapReq"] >= 1)
        for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
            MIN_CAP_GEN = ids_with_policy(gen, min_cap, tag = mincap)
            dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] .= dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] +
                                                           (value.(EP[:eTotalCap][MIN_CAP_GEN])) *
                                                           (dual.(EP[:cZoneMinCapReq][mincap]))
            if !isempty(inputs["VRE_STOR"])
                gen_VRE_STOR = gen.VreStorage
                HAS_MIN_CAP_STOR = ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap)
                MIN_CAP_GEN_SOLAR = ids_with_policy(gen_VRE_STOR,
                    min_cap_solar,
                    tag = mincap)
                MIN_CAP_GEN_WIND = ids_with_policy(gen_VRE_STOR, min_cap_wind, tag = mincap)
                MIN_CAP_GEN_ASYM_DC_DIS = intersect(inputs["VS_ASYM_DC_DISCHARGE"],
                    HAS_MIN_CAP_STOR)
                MIN_CAP_GEN_ASYM_AC_DIS = intersect(inputs["VS_ASYM_AC_DISCHARGE"],
                    HAS_MIN_CAP_STOR)
                MIN_CAP_GEN_SYM_DC = intersect(inputs["VS_SYM_DC"], HAS_MIN_CAP_STOR)
                MIN_CAP_GEN_SYM_AC = intersect(inputs["VS_SYM_AC"], HAS_MIN_CAP_STOR)
                if !isempty(MIN_CAP_GEN_SOLAR)
                    dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_SOLAR] .+= ((value.(EP[:eTotalCap_SOLAR][MIN_CAP_GEN_SOLAR]).data)
                                                                           .*
                                                                           etainverter.(gen[ids_with_policy(gen,
                        min_cap_solar,
                        tag = mincap)])
                                                                           *
                                                                           (dual.(EP[:cZoneMinCapReq][mincap])))
                end
                if !isempty(MIN_CAP_GEN_WIND)
                    dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_WIND] .+= ((value.(EP[:eTotalCap_WIND][MIN_CAP_GEN_WIND]).data)
                                                                          *
                                                                          (dual.(EP[:cZoneMinCapReq][mincap])))
                end
                if !isempty(MIN_CAP_GEN_ASYM_DC_DIS)
                    MIN_CAP_GEN_ASYM_DC_DIS = intersect(inputs["VS_ASYM_DC_DISCHARGE"],
                        HAS_MIN_CAP_STOR)
                    dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_ASYM_DC_DIS] .+= ((value.(EP[:eTotalCapDischarge_DC][MIN_CAP_GEN_ASYM_DC_DIS].data)
                                                                                  .*
                                                                                  etainverter.(gen_VRE_STOR[min_cap_stor.(gen_VRE_STOR, tag = mincap) .== 1 .& (gen_VRE_STOR.stor_dc_discharge .== 2)]))
                                                                                 *
                                                                                 (dual.(EP[:cZoneMinCapReq][mincap])))
                end
                if !isempty(MIN_CAP_GEN_ASYM_AC_DIS)
                    dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_ASYM_AC_DIS] .+= ((value.(EP[:eTotalCapDischarge_AC][MIN_CAP_GEN_ASYM_AC_DIS]).data)
                                                                                 *
                                                                                 (dual.(EP[:cZoneMinCapReq][mincap])))
                end
                if !isempty(MIN_CAP_GEN_SYM_DC)
                    dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_SYM_DC] .+= ((value.(EP[:eTotalCap_STOR][MIN_CAP_GEN_SYM_DC]).data
                                                                             .*
                                                                             power_to_energy_dc.(gen_VRE_STOR[(min_cap_stor.(gen_VRE_STOR, tag = mincap) .== 1 .& (gen_VRE_STOR.stor_dc_discharge .== 1))])
                                                                             .*
                                                                             etainverter.(gen_VRE_STOR[(min_cap_stor.(gen_VRE_STOR, tag = mincap) .== 1 .& (gen_VRE_STOR.stor_dc_discharge .== 1))]))
                                                                            *
                                                                            (dual.(EP[:cZoneMinCapReq][mincap])))
                end
                if !isempty(MIN_CAP_GEN_SYM_AC)
                    dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_SYM_AC] .+= ((value.(EP[:eTotalCap_STOR][MIN_CAP_GEN_SYM_AC]).data
                                                                             .*
                                                                             power_to_energy_ac.(gen_VRE_STOR[(min_cap_stor.(gen_VRE_STOR, tag = mincap) .== 1 .& (gen_VRE_STOR.stor_ac_discharge .== 1))]))
                                                                            *
                                                                            (dual.(EP[:cZoneMinCapReq][mincap])))
                end
            end
        end
    end

    if setup["ParameterScale"] == 1
        dfSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
        dfRegSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
    end

    CSV.write(joinpath(path, "SubsidyRevenue.csv"), dfSubRevenue)
    CSV.write(joinpath(path, "RegSubsidyRevenue.csv"), dfRegSubRevenue)
    return dfSubRevenue, dfRegSubRevenue
end
