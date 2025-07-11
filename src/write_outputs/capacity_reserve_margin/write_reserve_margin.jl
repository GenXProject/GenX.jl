function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar = dual.(EP[:cCapacityResMargin])
    if setup["ParameterScale"] == 1
        temp_ResMar = temp_ResMar * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end
    if setup["CapacityReserveMargin"] == 1
        dfResMar = DataFrame(temp_ResMar, :auto)
    elseif setup["CapacityReserveMargin"] == 2
        dfResMar = DataFrame(Value = temp_ResMar)
    end
    CSV.write(joinpath(path, "ReserveMargin.csv"), dfResMar)
    return nothing
end
