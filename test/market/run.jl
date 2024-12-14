using GenX

genx_setup = Dict(
    "Market" => 1
)

settings = GenX.default_settings()
merge!(settings, genx_setup)

scenarios_path = joinpath(@__DIR__, "market_price_scenarios")
market_data_path = joinpath(@__DIR__, "system", "Market_data.csv")

price_csvs = [
    joinpath(scenarios_path, "one_tier_30.csv")
]

for price_csv in price_csvs
    cp(price_csv, market_data_path)
    
    run_genx_case!(".")
  
    rm(market_data_path)
end