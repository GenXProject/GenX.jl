"""
    full_time_series_reconstruction(path::AbstractString, setup::Dict, DF::DataFrame)

Internal function for performing the reconstruction. This function returns a DataFrame with the full series reconstruction. 

# Arguments
- `path` (AbstractString): Path input to the results folder
- `setup` (Dict): Case setup
- `DF` (DataFrame): DataFrame to be reconstructed

# Returns
- `reconDF` (DataFrame): DataFrame with the full series reconstruction
"""
function full_time_series_reconstruction(
        path::AbstractString, setup::Dict, DF::DataFrame)
    if setup["MultiStage"] == 1
        dirs = splitpath(path)
        case = joinpath(dirs[.!occursin.("result", dirs)])  # Get the case folder without the "results" folder(s)
        cur_stage = setup["MultiStageSettingsDict"]["CurStage"]
        TDRpath = joinpath(case, "inputs", string("inputs_p", cur_stage),
            setup["TimeDomainReductionFolder"])
    else
        case = dirname(path)
        TDRpath = joinpath(case, setup["TimeDomainReductionFolder"])
    end
    # Read Period map file Period_map.csv
    Period_map = CSV.read(joinpath(TDRpath, "Period_map.csv"), DataFrame)

    # Read time domain reduction settings file time_domain_reduction_settings.yml
    myTDRsetup = YAML.load(open(joinpath(
        case, "settings/time_domain_reduction_settings.yml")))

    # Define Timesteps per Representative Period and Weight Total
    TimestepsPerRepPeriod = myTDRsetup["TimestepsPerRepPeriod"]
    WeightTotal = myTDRsetup["WeightTotal"]
    # Calculate the number of total periods the original time series was split into (will usually be 52)
    numPeriods = floor(Int, WeightTotal / TimestepsPerRepPeriod)

    # Get a matrix of the input DataFrame
    DFMatrix = Matrix(DF)
    total_timesteps = TimestepsPerRepPeriod * numPeriods

    # Find the index of the row with the first time step
    t1 = findfirst(x -> x == "t1", DF[!, 1])

    # Reconstruction of all hours of the year from TDR
    recon = Matrix{Any}(undef, total_timesteps, ncol(DF))
    recon[:, 1] = ["t$t" for t in 1:total_timesteps]
    for j in 2:ncol(DF)
        col = DFMatrix[t1:end, j]
        next_row = 1
        for i in 1:numPeriods
            index = Period_map[i, "Rep_Period_Index"]
            source_start = TimestepsPerRepPeriod * (index - 1) + 1
            source_end = TimestepsPerRepPeriod * index
            target_end = next_row + TimestepsPerRepPeriod - 1
            recon[next_row:target_end, j] = col[source_start:source_end]
            next_row = target_end + 1
        end
    end
    reconDF = DataFrame(recon, names(DF))

    # Insert rows that were above "t1" in the original DataFrame (e.g. "Zone" and "AnnualSum") if present
    if t1 > 1
        reconDF = vcat(DataFrame(DFMatrix[1:(t1 - 1), :], names(DF)), reconDF)
    end

    # Repeat the last rows of the year to fill in the gap (should be 24 hours for non-leap year)
    end_diff = WeightTotal - nrow(reconDF) + 1
    if end_diff > 0
        new_rows = copy(reconDF[(nrow(reconDF) - end_diff):nrow(reconDF), 1:end])
        new_rows[!, 1] = ["t$t" for t in (WeightTotal - end_diff):WeightTotal]
        append!(reconDF, new_rows)
    end
    return reconDF
end
