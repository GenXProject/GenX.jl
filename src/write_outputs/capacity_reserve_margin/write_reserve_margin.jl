function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar_Prices = dual.(EP[:cCapacityResMargin])
    if setup["ParameterScale"] == 1
        temp_ResMar_Prices = temp_ResMar_Prices * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end
    dfResMarPricec = DataFrame(temp_ResMar_Pricec, :auto)
    CSV.write(joinpath(path, "ReserveMarginPricec.csv"), dfResMarPricec)
    return nothing
end
