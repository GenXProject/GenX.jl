@doc raw"""

Read input parameters related to electricity load (demand)
"""
function load_cluster!(setup::Dict, path::AbstractString, inputs::Dict)

	# Load related inputs
	filename = "Cluster.csv"
	cluster_in = DataFrame(CSV.File(joinpath(path, filename), header=true), copycols=true)

    as_vector(col::Symbol) = collect(skipmissing(cluster_in[!, col]))

    C = length(as_vector(:cluster))
    inputs["C"] = C

	println(filename * " Successfully Read!")
end
