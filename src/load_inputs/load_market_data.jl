function load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)
    system_dir = joinpath(path, setup["SystemFolder"])

    filename = "Market_data.csv"
    df = load_dataframe(joinpath(system_dir, filename))

    # TODO fill in inputs
    println(filename * " Successfully Read!")
end