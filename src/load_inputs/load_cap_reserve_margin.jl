@doc raw"""
	load_cap_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to planning reserve margin constraints
"""
function load_cap_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Capacity_reserve_margin.csv"
    df = load_dataframe(joinpath(path, filename))

    # Identifying # of planning reserve margin constraints for the system
    columns = names(df)
    f = s -> startswith(s, "CapRes")
    res = count(f, columns)
    first_col = findfirst(f, columns)
    last_col = findlast(f, columns)

    inputs["dfCapRes"] = Matrix{Float64}(df[:,first_col:last_col])
    inputs["NCapacityReserveMargin"] = res

    println(filename * " Successfully Read!")
end

@doc raw"""
	load_cap_reserve_margin_trans!(setup::Dict, inputs::Dict, network_var::DataFrame)

Read input parameters related to participation of transmission imports/exports in capacity reserve margin constraint.
"""
function load_cap_reserve_margin_trans!(setup::Dict, inputs::Dict, network_var::DataFrame)
    columns = names(network_var)
    f = s -> startswith(s, "DerateCapRes")
    my_range = findfirst(f, columns):findlast(f, columns)
    dfDerateTransCapRes = network_var[:, my_range]
    inputs["dfDerateTransCapRes"] = Matrix{Float64}(dfDerateTransCapRes[completecases(dfDerateTransCapRes),:])

    f = s -> startswith(s, "CapRes_Excl")
    my_range = findfirst(f, columns):findlast(f, columns)
    dfTransCapRes_excl = network_var[:, my_range]
    inputs["dfTransCapRes_excl"] = Matrix{Float64}(dfTransCapRes_excl[completecases(dfTransCapRes_excl),:])
end
