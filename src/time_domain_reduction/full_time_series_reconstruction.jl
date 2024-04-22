@doc raw"""reconstruction(case::AbstractString,
                            DF::DataFrame)
Create a DataFrame with all 8,760 hours of the year from the reduced output.

case - folder for the case
DF - DataFrame to be reconstructed

This function uses Period_map.csv to create a new DataFrame with 8,760 time steps, as well as other pre-existing rows such as "Zone".
For each 52 weeks of the year, the corresponding representative week is taken from the input DataFrame and copied into the new DataFrame. Representative periods that 
represent more than one week will appear multiple times in the output. 

Note: Currently, TDR only gives the representative periods in Period_map for 52 weeks, when a (non-leap) year is 52 weeks + 24 hours. This function takes the last 24 hours of 
the time series and copies them to get up to all 8,760 hours in a year.

This function is called when output files with time series data (e.g. power.csv, emissions.csv) are created, if the setup key "OutputFullTimeSeries" is set to "1".

"""
function reconstruction(case::AbstractString,DF::DataFrame)
    settings_path = GenX.get_settings_path(case)
    
    # Read Period map file Period_map.csv
    Period_map = CSV.read(joinpath(case,"TDR_results/Period_map.csv"),DataFrame)
    
    # Read time domain reduction settings file time_domain_reduction_settings.yml
    myTDRsetup = YAML.load(open(joinpath(settings_path,
        "time_domain_reduction_settings.yml")))
    
    # Define Timesteps per Representative Period and Weight Total
    TimestepsPerRepPeriod = myTDRsetup["TimestepsPerRepPeriod"]
    WeightTotal = myTDRsetup["WeightTotal"]
    
    # Calculate the number of total periods the original time series was split into (will usually be 52)
    numPeriods = floor(Int,WeightTotal/TimestepsPerRepPeriod)
    
    # Get the names of the input DataFrame
    DFnames = names(DF)
    
    # Initialize an array to add the reconstructed data to
    recon = ["t$t" for t in 1:TimestepsPerRepPeriod*numPeriods]
    
    # Find the index of the row with the first time step
    t1 = findfirst(x -> x == "t1",DF[!,1])
    
    # Reconstruction of all hours of the year from TDR
    for j in range(2,ncol(DF))
        col = DF[t1:end,j]
        col_name = DFnames[j]
        recon_col = []
        for i in range(1,numPeriods)
            index = Period_map[i,"Rep_Period_Index"]
            recon_temp = col[(TimestepsPerRepPeriod*index-(TimestepsPerRepPeriod-1)):(TimestepsPerRepPeriod*index)]
            recon_col = [recon_col; recon_temp]
        end
        recon = [recon recon_col]
    end
    reconDF = DataFrame(recon, DFnames)
    
    # Insert rows that were above "t1" in the original DataFrame (e.g. "Zone" and "AnnualSum") if present
    for i in range(1,t1-1)
        insert!(reconDF,i,DF[i,1:end])
    end
    
    # Repeat the last rows of the year to fill in the gap (should be 24 hours for non-leap year)
    end_diff = WeightTotal - nrow(reconDF) + 1
    new_rows = reconDF[(nrow(reconDF)-end_diff):nrow(reconDF),2:end]
    new_rows[!,"Resource"] = ["t$t" for t in (WeightTotal-end_diff):WeightTotal] 
    
    reconDF = [reconDF; new_rows]
    
    return reconDF
end