@doc raw"""
	write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources (both standalone and 
	co-located).
"""
function write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    VRE = inputs["VRE"]
    dfCurtailment = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        Zone = zone_id.(gen),
        AnnualSum = zeros(G))
    curtailment = zeros(G, T)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    curtailment[VRE, :] = scale_factor *
                          (value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .-
                           value.(EP[:vP][VRE, :]))

    VRE_STOR = inputs["VRE_STOR"]
    if !isempty(VRE_STOR)
        SOLAR = setdiff(inputs["VS_SOLAR"], inputs["VS_WIND"])
        WIND = setdiff(inputs["VS_WIND"], inputs["VS_SOLAR"])
        SOLAR_WIND = intersect(inputs["VS_SOLAR"], inputs["VS_WIND"])
        gen_VRE_STOR = gen.VreStorage
        if !isempty(SOLAR)
            curtailment[SOLAR, :] = scale_factor *
                                    (value.(EP[:eTotalCap_SOLAR][SOLAR]).data .*
                                     inputs["pP_Max_Solar"][SOLAR, :] .-
                                     value.(EP[:vP_SOLAR][SOLAR, :]).data) .*
                                    etainverter.(gen_VRE_STOR[(gen_VRE_STOR.solar .!= 0)])
        end
        if !isempty(WIND)
            curtailment[WIND, :] = scale_factor * (value.(EP[:eTotalCap_WIND][WIND]).data .*
                                    inputs["pP_Max_Wind"][WIND, :] .-
                                    value.(EP[:vP_WIND][WIND, :]).data)
        end
        if !isempty(SOLAR_WIND)
            curtailment[SOLAR_WIND, :] = scale_factor *
                                         ((value.(EP[:eTotalCap_SOLAR])[SOLAR_WIND].data
                                           .*
                                           inputs["pP_Max_Solar"][SOLAR_WIND, :] .-
                                           value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data)
                                          .*
                                          etainverter.(gen_VRE_STOR[((gen_VRE_STOR.wind .!= 0) .& (gen_VRE_STOR.solar .!= 0))])
                                          +
                                          (value.(EP[:eTotalCap_WIND][SOLAR_WIND]).data .*
                                           inputs["pP_Max_Wind"][SOLAR_WIND, :] .-
                                           value.(EP[:vP_WIND][SOLAR_WIND, :]).data))
        end
    end

    dfCurtailment.AnnualSum = curtailment * inputs["omega"]

    filename = joinpath(path, "curtail.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filename, dfCurtailment)
    else # setup["WriteOutputs"] == "full"
        df_Curtailment = write_fulltimeseries(filename, curtailment, dfCurtailment)
        if setup["OutputFullTimeSeries"] == 1 & setup["TimeDomainReduction"] == 1
            DFMatrix = Matrix(dftranspose(df_Curtailment, true))
            DFnames = DFMatrix[1,:]
            FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
            output_path = joinpath(path, FullTimeSeriesFolder)
            dfOut_full = full_time_series_reconstruction(
                path, setup, dftranspose(df_Curtailment, false), DFnames)
            CSV.write(joinpath(output_path, "curtail.csv"), dfOut_full, writeheader = false)
            println("Writing Full Time Series for Curtailment")
        end
    end
    return nothing
end
