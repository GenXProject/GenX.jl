@doc raw"""
	write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []

    # Power withdrawn to charge each resource in each time step
    dfCharge = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        Zone = zones,
        AnnualSum = Array{Union{Missing, Float64}}(undef, G))
    charge = zeros(G, T)

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    if !isempty(STOR_ALL)
        charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :]) * scale_factor
    end
    if !isempty(FLEX)
        charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]) * scale_factor
    end
    if !isempty(ELECTROLYZER)
        charge[ELECTROLYZER, :] = value.(EP[:vUSE][ELECTROLYZER, :]) * scale_factor
    end
    if !isempty(VS_STOR)
        charge[VS_STOR, :] = value.(EP[:vCHARGE_VRE_STOR][VS_STOR, :]) * scale_factor
    end

    dfCharge.AnnualSum .= charge * inputs["omega"]

    filepath = joinpath(path, "charge.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfCharge)
    else # setup["WriteOutputs"] == "full"
        write_fulltimeseries(filepath, charge, dfCharge)
        if setup["OutputFullTimeSeries"] == 1 & setup["TimeDomainReduction"] == 1

        # full path, dataout, dfout
       
            T = size(charge, 2)
            dfCharge = hcat(dfCharge, DataFrame(charge, :auto))
            auxNew_Names = [Symbol("Resource");
                            Symbol("Zone");
                            Symbol("AnnualSum");
                            [Symbol("t$t") for t in 1:T]]
            rename!(dfCharge, auxNew_Names)
            total = DataFrame(["Total" 0 sum(dfCharge[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
            total[!, 4:(T + 3)] .= sum(charge, dims = 1)
            df_Charge = vcat(dfCharge, total)
            DFMatrix = Matrix(dftranspose(df_Charge, true))
            DFnames = DFMatrix[1,:]
            
            FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
            output_path = joinpath(path, FullTimeSeriesFolder)
            dfOut_full = full_time_series_reconstruction(
                path, setup,  dftranspose(df_Charge, false), DFnames)
            CSV.write(joinpath(output_path, "charge.csv"), dfOut_full, writeheader = false)
            println("Writing Full Time Series for Charge")
        end
    end

    return nothing
end
