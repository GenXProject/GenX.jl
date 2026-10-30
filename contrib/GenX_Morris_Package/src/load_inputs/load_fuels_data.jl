# ------------------------------------------------------------------
# Change History:
# 2026-10 — Shane Menezes
#
# Extended fuel input handling to support Morris fuel-price sensitivity
# analysis:
#
# - Added configurable fuel-price multiplier handling.
# - Added FUELS metadata for fuel-level screening.
# - Added fuel-price screening eligibility controls.
# - Marked "None" fuel placeholders as ineligible for fuel-price
#   sensitivity analysis when present.
#
# Research reference:
# Menezes, S., & Patankar, N. (2026). "Zonal Global Sensitivity Analysis
# for Policy-Constrained Capacity Expansion Planning in New York."
# 11th North American International Conference on Industrial Engineering
# and Operations Management. https://doi.org/10.46254/NA11.20260328
# ------------------------------------------------------------------
@doc raw"""
    load_fuels_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to fuel costs and CO$_2$ content of fuels
"""
function load_fuels_data!(setup::Dict, path::AbstractString, inputs::Dict)

    # Fuel related inputs - read in different files depending on if time domain reduction is activated or not
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Fuels_data.csv"
    fuels_in = load_dataframe(joinpath(my_dir, filename))

    for nonfuel in ("None",)
        ensure_column!(fuels_in, nonfuel, 0.0)
    end

    # Fuel costs & CO2 emissions rate for each fuel type
    fuels = names(fuels_in)[2:end]
    costs = Matrix(fuels_in[2:end, 2:end])
    CO2_content = fuels_in[1, 2:end] # tons CO2/MMBtu
    fuel_costs = Dict{AbstractString, Array{Float64}}()
    fuel_CO2 = Dict{AbstractString, Float64}()

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    for i in 1:length(fuels)
    # fuel cost is in $/MMBTU w/o scaling, $/Billon BTU w/ scaling
        # fuel_costs[fuels[i]] = costs[:, i] / scale_factor
        # Added fuel_price_multiplier to scale costs to $/Billon BTU 
        fuel_name = String(fuels[i])
        fuel_cost_vec = (costs[:, i] / scale_factor) .* setup["fuel_price_multiplier"]
        fuel_co2_val = CO2_content[i]

        fuel_costs[fuel_name] = fuel_cost_vec
        fuel_CO2[fuel_name] = fuel_co2_val

        # Add aliases only for Hydrogen to tolerate case mismatches in multiplier inputs.
        if lowercase(fuel_name) == "hydrogen"
            fuel_costs["hydrogen"] = fuel_cost_vec
            fuel_costs["Hydrogen"] = fuel_cost_vec
            fuel_CO2["hydrogen"] = fuel_co2_val
            fuel_CO2["Hydrogen"] = fuel_co2_val
        end
        # No need to scale fuel_CO2, fuel_CO2 is ton/MMBTU or kton/Billion BTU 
    end

    inputs["fuels"] = fuels
    inputs["fuel_costs"] = fuel_costs
    inputs["fuel_CO2"] = fuel_CO2
    # Build FUELS metadata table used to track fuel price multiplier eligibility.
    fuel_param_df = DataFrame(
        fuel = String.(fuels),
        zone = fill("", length(fuels)),
        fuel_price_multiplier = fill(setup["fuel_price_multiplier"], length(fuels)),
        fuel_price_multiplier_eligible = trues(length(fuels)),
    )
    if "None" in fuel_param_df.fuel
        fuel_param_df[fuel_param_df.fuel .== "None", :fuel_price_multiplier_eligible] .= false
        fuel_param_df[fuel_param_df.fuel .== "None", :fuel_price_multiplier] .= 1.0
    end
    inputs["FUELS"] = fuel_param_df

    println(filename * " Successfully Read!")

    return fuel_costs, fuel_CO2
end

function ensure_column!(df::DataFrame, col::AbstractString, fill_element)
    if col ∉ names(df)
        df[!, col] = fill(fill_element, nrow(df))
    end
end
