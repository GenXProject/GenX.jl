function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar = dual.(EP[:cCapacityResMargin])
    dfResMar = DataFrame(temp_ResMar, :auto)
    CSV.write(joinpath(path, "ReserveMargin.csv"), dfResMar)
    return nothing
end
