function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar = dual.(EP[:cCapacityResMargin])
    if setup["ParameterScale"] == 1
        temp_ResMar = temp_ResMar * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end
    dfResMar = DataFrame(temp_ResMar, :auto)
    write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["reserve_margin"]),
            dftranspose(dfResMar,false),
            filetype = setup["ResultsFileType"],
            compression = setup["ResultsCompressionType"])
    return nothing
end
