function load_multistage_dataframe(filepath::AbstractString, scale_factor::Float64)
    if !isfile(filepath)
        error("Multistage data file not found at $filepath")
    end

    multistage_in = load_dataframe(filepath)
    # rename columns lowercase for internal consistency
    rename!(multistage_in, lowercase.(names(multistage_in)))
    scale_multistage_data!(multistage_in, scale_factor)

    validate_multistage_data!(multistage_in)

    return multistage_in
end

function validate_multistage_data!(multistage_df::DataFrame)
    # cols that the user must provide
    required_cols = ("lifetime", "capital_recovery_period")
    # check that all required columns are present
    for col in required_cols
        if col ∉ names(multistage_df)
            error("Multistage data file is missing column $col")
        end
    end
end

function scale_multistage_data!(multistage_in::DataFrame, scale_factor::Float64)
    columns_to_scale = [:min_retired_cap_mw,            # to GW
        :min_retired_charge_cap_mw,     # to GW
        :min_retired_energy_cap_mw,     # to GW
        :min_retired_cap_inverter_mw,
        :min_retired_cap_solar_mw,
        :min_retired_cap_wind_mw,
        :min_retired_cap_charge_dc_mw,
        :min_retired_cap_charge_ac_mw,
        :min_retired_cap_discharge_dc_mw,
        :min_retired_cap_discharge_ac_mw,
    ]
    scale_columns!(multistage_in, columns_to_scale, scale_factor)
    return nothing
end
