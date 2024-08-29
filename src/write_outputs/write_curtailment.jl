@doc raw"""
	write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources (both standalone and 
	co-located).
"""
function write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]  # Resources (objects)
    resources = inputs["RESOURCE_NAMES"] # Resource names
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    VRE = inputs["VRE"]
    VRE_STOR = inputs["VRE_STOR"]

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    curtailment = zeros(G, T)
    curtailment[VRE, :] = (value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .-
                           value.(EP[:vP][VRE, :]))

    if !isempty(VRE_STOR)
        SOLAR = setdiff(inputs["VS_SOLAR"], inputs["VS_WIND"])
        WIND = setdiff(inputs["VS_WIND"], inputs["VS_SOLAR"])
        SOLAR_WIND = intersect(inputs["VS_SOLAR"], inputs["VS_WIND"])
        if !isempty(SOLAR)
            curtailment[SOLAR, :] = (value.(EP[:eTotalCap_SOLAR][SOLAR]).data .*
                                    inputs["pP_Max_Solar"][SOLAR, :] .-
                                    value.(EP[:vP_SOLAR][SOLAR, :]).data) .*
                                    etainverter.(gen[SOLAR])
        end
        if !isempty(WIND)
            curtailment[WIND, :] = (value.(EP[:eTotalCap_WIND][WIND]).data .*
                                    inputs["pP_Max_Wind"][WIND, :] .-
                                    value.(EP[:vP_WIND][WIND, :]).data)
        end
        if !isempty(SOLAR_WIND)
            curtailment[SOLAR_WIND, :] = ((value.(EP[:eTotalCap_SOLAR])[SOLAR_WIND].data .*
                                           inputs["pP_Max_Solar"][SOLAR_WIND, :] .-
                                           value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data) .*
                                          etainverter.(gen[SOLAR_WIND])
                                          +
                                          (value.(EP[:eTotalCap_WIND][SOLAR_WIND]).data .*
                                           inputs["pP_Max_Wind"][SOLAR_WIND, :] .-
                                           value.(EP[:vP_WIND][SOLAR_WIND, :]).data))
        end
    end

    curtailment *= scale_factor

<<<<<<< HEAD
    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(G))
    df.AnnualSum = curtailment * weight

    write_temporal_data(df, curtailment, path, setup, setup["WriteResultsNamesDict"]["curtail"])
=======
    filename = joinpath(path, setup["WriteResultsNamesDict"]["curtail"])
    if setup["WriteOutputs"] == "annual"
        write_annual(filename, dfCurtailment, setup)
    else # setup["WriteOutputs"] == "full"
        df_Curtailment = write_fulltimeseries(filename, curtailment, dfCurtailment, setup)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, df_Curtailment, setup["WriteResultsNamesDict"]["curtail"])
            @info("Writing Full Time Series for Curtailment")
        end
    end
>>>>>>> 7b8d28340 (Code cleanup)
    return nothing
end
