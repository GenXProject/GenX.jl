@doc raw"""
    load_fuels_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to fuel costs and CO$_2$ content of fuels
"""
function load_fuels_data!(setup::Dict, path::AbstractString, inputs::Dict)

    # Fuel related inputs - read in different files depending on if time domain reduction is activated or not
    data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1  && time_domain_reduced_files_exist(data_directory)
        my_dir = data_directory
    else
        my_dir = path
    end
    filename = "Fuels_data.csv"
    fuels_in = load_dataframe(joinpath(my_dir, filename))

    existing_fuels = names(fuels_in)
    for nonfuel in ("None",)
        if nonfuel ∉ existing_fuels
            ensure_column!(fuels_in, nonfuel, 0.0)
        end
    end

    # Fuel costs & CO2 emissions rate for each fuel type
    fuels = names(fuels_in)[2:end]
    costs = Matrix(fuels_in[2:end, 2:end])
    CO2_content = fuels_in[1, 2:end] # tons CO2/MMBtu
    fuel_costs = Dict{AbstractString, Array{Float64}}()
    fuel_CO2 = Dict{AbstractString, Float64}()

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    for i = 1:length(fuels)
            fuel_costs[fuels[i]] = costs[:,i] / scale_factor

            # No reason to scale CO2_content beacuse fuel_CO2 is in tons/MMBTU=kton/BillionBTU. In fact:
            # without scaling: CO2 is in tons, fuel in MMBTU, and fuel_Co2 is in tons/MMBTU; 
            # with scaling: CO2 is in ktons, fuel in BillionBTU and fuel_CO2 is in tons/MMBTU = ktons/BillionBTU
            fuel_CO2[fuels[i]] = CO2_content[i] 
    end

    inputs["fuels"] = fuels
    inputs["fuel_costs"] = fuel_costs
    inputs["fuel_CO2"] = fuel_CO2

    println(filename * " Successfully Read!")

    return fuel_costs, fuel_CO2
end

function ensure_column!(df::DataFrame, col::AbstractString, fill_element)
    if col ∉ names(df)
        df[!, col] = fill(fill_element, nrow(df))
    end
end
