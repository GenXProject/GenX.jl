function write_reserve_margin_w(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    #dfResMar dataframe with weights included for calculations
    dfResMar_w = DataFrame(Constraint = [Symbol("t$t") for t in 1:T])
    temp_ResMar_w = transpose(dual.(EP[:cCapacityResMargin])) ./ inputs["omega"]
    if setup["ParameterScale"] == 1
        temp_ResMar_w = temp_ResMar_w * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end
    dfResMar_w = hcat(dfResMar_w, DataFrame(temp_ResMar_w, :auto))
    auxNew_Names_res = [Symbol("Constraint");
        [Symbol("CapRes_$i") for i in 1:inputs["NCapacityReserveMargin"]]]
    rename!(dfResMar_w, auxNew_Names_res)
    CSV.write(joinpath(path, "ReserveMargin_w.csv"), dfResMar_w)
end
