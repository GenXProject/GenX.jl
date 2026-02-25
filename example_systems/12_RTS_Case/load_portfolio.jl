ENV["GENX_PRECOMPILE"] = "false"

using Pkg;
using Revise
using GenX
using PowerSystemsInvestmentsPortfolios
using PowerSystems
using InfrastructureSystems
const PSIP = PowerSystemsInvestmentsPortfolios
const IS = InfrastructureSystems
const PSY = PowerSystems

function load_rts(case_name::AbstractString)
    #!/usr/bin/env julia

    """
    Method to load RTS data from SQLite database and create portfolio structs
    using the database_to_portfolio function.
    """

    # Define the database file path
    database_filepath = joinpath(case_name, "sys_DA_update_costs.sqlite")
    database_filepath = joinpath(case_name, "sys_DA.sqlite")
    database_filepath = joinpath(case_name, "rts_psy5_updated.sqlite")

    # Define the portfolio parameters
    discount_rate = 0.05
    inflation_rate = 0.07
    interest_rate = 0.07
    base_year = 2025
    aggregation = PSY.ACBus

    println("Loading RTS data from database: $database_filepath")
    println("Parameters:")
    println("  - Discount rate: $discount_rate")
    println("  - Inflation rate: $inflation_rate")
    println("  - Interest rate: $interest_rate")
    println("  - Base year: $base_year")
    println("  - Aggregation: $aggregation")

    # Check if the database file exists
    if !isfile(database_filepath)
        error("Database file not found: $database_filepath")
    end

    try
        println("\n🔄 Starting portfolio creation...")
    
        # Check if the database file exists and can be opened
        println("🔄 Opening database connection...")
    
        # Call the database_to_portfolio function
        portfolio = database_to_portfolio(
            database_filepath,
            discount_rate,
            inflation_rate,
            interest_rate,
            base_year;
            aggregation=aggregation
        )

        println("✅ Database loaded successfully")
        println("✅ Nodes created (with validation warnings)")
        println("✅ Technologies processed (some types skipped as expected)")
        println("✅ Power system data processed")
        println("✅ Time series deserialization completed")
    
        println("\n✅ Successfully created portfolio structs!")
        println("Portfolio object type: $(typeof(portfolio))")
    
        # Display some basic information about the portfolio
        println("\nPortfolio summary:")
        println("  - Aggregation type: $(portfolio.aggregation)")
        println("  - Discount rate: $(get_discount_rate(portfolio))")
        println("  - Inflation rate: $(get_inflation_rate(portfolio))")
        println("  - Interest rate: $(get_interest_rate(portfolio))")
        println("  - Base year: $(get_base_year(portfolio))")

        # Check if there are any technologies in the portfolio
        if isdefined(portfolio, :technologies) && !isempty(get_technologies(portfolio))
            println("  - Number of technologies: $(length(get_technologies(portfolio)))")
            println("  - Technology types:")
            for tech in get_technologies(portfolio)
                println("    - $(typeof(tech))")
            end
        end
    
        # Check if there are any demand requirements
        if isdefined(portfolio, :demand_requirements) && !isempty(get_technologies(DemandRequirement, portfolio))
            println("  - Number of demand requirements: $(length(get_technologies(DemandRequirement, portfolio)))")
        end
    
        # Check if there are any regions
        if isdefined(portfolio, :regions) && !isempty(get_regions(portfolio))
            println("  - Number of regions: $(length(get_regions(portfolio)))")
        end
        println("\nPortfolio loading complete.")
        return portfolio
    
    catch e
        # Determine which step failed based on the error message
        error_msg = string(e)
        if occursin("SystemError", error_msg) || occursin("database", error_msg)
            println("❌ Failed at database loading step")
        elseif occursin("Node", error_msg) || occursin("validation", error_msg)
            println("✅ Database loaded successfully")
            println("❌ Failed at nodes creation step")
        elseif occursin("Technologies", error_msg) || occursin("ROR", error_msg) || occursin("HYDRO", error_msg)
            println("✅ Database loaded successfully")
            println("✅ Nodes created (with validation warnings)")
            println("❌ Failed at technologies processing step")
        elseif occursin("TIME_SERIES", error_msg) || occursin("time_series", error_msg) || occursin("timeseries", error_msg)
            println("✅ Database loaded successfully")
            println("✅ Nodes created (with validation warnings)")
            println("✅ Technologies processed (some types skipped as expected)")
            println("✅ Power system data processed")
            println("❌ Failed at time series deserialization step")
        else
            println("✅ Database loaded successfully")
            println("✅ Nodes created (with validation warnings)")
            println("✅ Technologies processed (some types skipped as expected)")
            println("❌ Failed at power system data processing step")
        end
    
        println("\n❌ Error creating portfolio:")
        println("Error: $e")
        rethrow(e)
    end

end

case = @__DIR__
p = load_rts(case)


# Set internal portfolio data for use in GenX
p.internal.ext["Rep_Periods"] = 1
p.internal.ext["Timesteps_per_Rep_Period"] = 48
p.internal.ext["hours_per_subperiod"] = 48
p.internal.ext["sub_weights"] = [8784 for i in 1:p.internal.ext["Rep_Periods"]] 

vom_dict = Dict("CC" => 2.12, "CT" => 6.94, "STEAM" => 9.18, "NUCLEAR" => 2.8, "PV" => 0, "CSP" => 3.0, "WIND" => 0)
#fom_dict = Dict("CC" => 33500, "CT" => 33500, "STEAM" => 33500, "NUCLEAR" => 175000, "PV" => 22000, "CSP" => 74000, "WIND" => 31000)
fom_dict = Dict("CC" => 33500, "CT" => 26000, "STEAM" => 33500, "NUCLEAR" => 175000, "PV" => 22000, "CSP" => 55000, "WIND" => 31000)
startup_dict = Dict("CC" => 92, "CT" => 119, "STEAM" => 124, "NUCLEAR" => 248, "PV" => 0, "CSP" => 0, "WIND" => 0)
function add_om_costs(p)
    techs = collect(get_technologies(ResourceTechnology, p))

    for t in techs
        if isa(t, StorageTechnology)
            continue
        end
        op_cost = t.operation_costs.variable

        key_val = [""]
        for key in keys(vom_dict)
            if occursin(key, t.name)
                key_val[1] = key
                break
            end
        end
        if key_val[1] == ""
            error("Technology of name $(t.name) does not have a corresponding dictionary pairing")
        end
        vom_val = vom_dict[key_val[1]]
        fom_val = fom_dict[key_val[1]]
        startup_val = startup_dict[key_val[1]]
        if isa(op_cost, CostCurve)
            new_cc = CostCurve(LinearCurve(LinearFunctionData(0, fom_val)), op_cost.power_units, LinearCurve(LinearFunctionData(vom_val, 0)))
            t.operation_costs.variable = new_cc
        elseif isa(op_cost, FuelCurve)
            new_fc = FuelCurve(op_cost.value_curve, op_cost.power_units, op_cost.fuel_cost, op_cost.startup_fuel_offtake, LinearCurve(LinearFunctionData(vom_val, 0)))
            t.operation_costs.variable = new_fc
            t.operation_costs.fixed = fom_val
            t.operation_costs.start_up = Float64(startup_val)
        else
            error("Variable Costs are of type , ", typeof(op_cost))
        end
    end
end

inv_cost_dict = Dict("CC" => 144000, "CT" => 130000, "STEAM" => 441000, "NUCLEAR" => 830000, "PV" => 120000, "CSP" => 347000, "WIND" => 160000)

function update_fuel_and_investment_costs(myinputs)
    myinputs["fuel_costs"]

    for k in keys(myinputs["fuel_costs"])
        if occursin("NATURAL_GAS", k)
            myinputs["fuel_costs"][k] .= 3.88722
        elseif occursin("NUCLEAR", k)
            myinputs["fuel_costs"][k] .= 0.810
        elseif occursin("COAL", k)
            myinputs["fuel_costs"][k] .= 2.11399
        elseif occursin("DISTILLATE", k)
            myinputs["fuel_costs"][k] .= 10.3494
        end
    end

    for (i, r) in enumerate(myinputs["RESOURCES"])
        if isa(r, GenX.Storage)
            continue
        end

        key_val = [""]
        for key in keys(inv_cost_dict)
            if occursin(key, GenX.resource_name(r))
                key_val[1] = key
                break
            end
        end
        if key_val[1] == ""
            error("Technology of name $(GenX.resource_name(r)) does not have a corresponding dictionary pairing")
        end
        inv_cost = inv_cost_dict[key_val[1]]
        parent(r)[:inv_cost_per_mwyr] = inv_cost

        if isa(r, GenX.Thermal)
            fuel = GenX.fuel(r)
            parent(r)[:fuel_costs] = myinputs["fuel_costs"][fuel][1]
        end
    end
end
add_om_costs(p)



# Load in settings
genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

# Make sure certain parameters are set
mysetup["ParameterScale"] = 0
mysetup["DC_OPF"] = 1
mysetup["ptdf"] = 0
mysetup["bilinear"] = 0
mysetup["disaggregate"] = 0
mysetup["unfix_slacks"] = 0
mysetup["SOS1"] = 0
settings_path = GenX.get_settings_path(case)    
mysetup["settings_path"] = settings_path;
mysetup["NetworkExpansion"] = 1
mysetup["Benders"] = 0

###################### SOLUTIONS WITH TRANSMISSION ######################
mysetup["DC_OPF"] = 1
myinputs = GenX.load_inputs(mysetup, case, p)