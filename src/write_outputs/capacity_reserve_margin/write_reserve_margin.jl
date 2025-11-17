function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar_Price = dual.(EP[:cCapacityResMargin])
    if setup["ParameterScale"] == 1
        temp_ResMar_Price = temp_ResMar_Price * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end
    dfResMarPrice = DataFrame(temp_ResMar_Price, :auto)
    CSV.write(joinpath(path, "ReserveMarginPrice.csv"), dfResMarPrice)
    return nothing
end
