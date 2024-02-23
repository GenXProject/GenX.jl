@doc raw"""

Read input parameters related to electricity load (demand)
"""
function load_retrofit_data!(path::AbstractString, inputs::Dict)

	# Load related inputs
	filename = "Retrofit.csv"
	dfRetrofit = load_dataframe(joinpath(path, filename))
	rename!(dfRetrofit, lowercase.(names(dfRetrofit)))

	# cols that are required
	required_cols = ["retrofit_pool_id"]
	# check that all required columns are present
	validate_df_cols(dfRetrofit, "Retrofit", required_cols)

    as_vector(col::Symbol) = collect(skipmissing(dfRetrofit[!, col]))

    inputs["C"] = length(as_vector(:retrofit_pool_id))

	if "retrofit_efficiency" ∉ names(dfRetrofit)
		dfRetrofit[!, :retrofit_efficiency] .= 1.0
	end
	inputs["dfRetrofit"] = dfRetrofit

	println(filename * " Successfully Read!")
end
