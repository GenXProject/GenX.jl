@doc raw"""
    load_co2_cap!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to CO$_2$ emissions cap constraints
"""
function load_co2_cap!(setup::Dict, path::AbstractString, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "CO2_cap_slack.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        inputs["dfCO2Cap_slack"] = df
        inputs["dfCO2Cap_slack"][!, :PriceCap] ./= scale_factor # Million $/kton if scaled, $/ton if not scaled
    end

    filename = "CO2_cap.csv"
    df = load_dataframe(joinpath(path, filename))

    inputs["dfCO2Cap"] = df
    mat = extract_matrix_from_dataframe(df, "CO_2_Cap_Zone")
    inputs["dfCO2CapZones"] = mat
    inputs["NCO2Cap"] = size(mat, 2)

    # Emission limits
    if setup["CO2Cap"] == 1
        #  CO2 emissions cap in mass
        # note the default inputs is in million tons
        # when scaled, the constraint unit is kton
        # when not scaled, the constraint unit is ton
        mat = extract_matrix_from_dataframe(df, "CO_2_Max_Mtons")
        inputs["dfMaxCO2"] = mat * 1e6 / scale_factor

    elseif setup["CO2Cap"] == 2 || setup["CO2Cap"] == 3
        #  CO2 emissions rate applied per MWh
        mat = extract_matrix_from_dataframe(df, "CO_2_Max_tons_MWh")
        # no scale_factor is needed since this is a ratio
        inputs["dfMaxCO2Rate"] = mat
    end

    println(filename * " Successfully Read!")
end
