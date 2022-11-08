@doc raw"""
    load_co2_cap!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to CO$_2$ emissions cap constraints
"""
function load_co2_cap!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "CO2_cap.csv"
    inputs["dfCO2Cap"] = load_dataframe(joinpath(path, filename))
    columns = names(inputs["dfCO2Cap"])

    function column_range(heading::AbstractString)
        f = s -> startswith(s, heading)
        findfirst(f, columns):findlast(f, columns)
    end

    my_range = column_range("CO_2_Cap_Zone")

    inputs["dfCO2CapZones"] = Matrix{Float64}(inputs["dfCO2Cap"][:, my_range])
    inputs["NCO2Cap"] = length(my_range)

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Emission limits
    if setup["CO2Cap"] == 1
        #  CO2 emissions cap in mass
        my_range = column_range("CO_2_Max_Mtons")
        # note the default inputs is in million tons
        # when scaled, the constraint unit is kton
        # when not scaled, the constraint unit is ton
        inputs["dfMaxCO2"] = Matrix{Float64}(inputs["dfCO2Cap"][:, my_range]) * 1e6 / scale_factor

    elseif setup["CO2Cap"] == 2 || setup["CO2Cap"] == 3
        #  CO2 emissions rate applied per MWh
        my_range = column_range("CO_2_Max_tons_MWh")
        # no scale_factor is needed since this is a ratio
        inputs["dfMaxCO2Rate"] = Matrix{Float64}(inputs["dfCO2Cap"][:, my_range])
    end

    println(filename * " Successfully Read!")
end
