# for testing just the market model with the ability to inspect results
using GenX
using Logging
using JuMP

# Set the log level to Debug
global_logger(ConsoleLogger(stderr, Logging.Debug))


scenarios_path = joinpath(@__DIR__, "market_price_scenarios")
market_data_path = joinpath(@__DIR__, "system", "Market_data.csv")

price_csvs = [
    joinpath(scenarios_path, "two_tier_30_100.csv")
]

for price_csv in price_csvs
    cp(price_csv, market_data_path; force=true)
    
    run_genx_case!(".")
  
    rm(market_data_path)
end