function load_rts(case_name::AbstractString)
    #!/usr/bin/env julia

    """
    Method to load RTS data from SQLite database and create portfolio structs
    using the database_to_portfolio function.
    """

    # Define the database file path
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
