function write_simple_csv(filename::AbstractString, df::DataFrame)
    CSV.write(filename, df)
end

function write_simple_csv(filename::AbstractString, header::Vector, matrix)
    df = DataFrame(matrix, header)
    write_simple_csv(filename, df)
end

# function to extract data from DenseAxisArray OR matrix
extract_data(var::JuMP.Containers.DenseAxisArray)::AbstractArray = var.data
extract_data(var::AbstractArray)::AbstractArray = var

function prepare_timeseries_variables(EP, inputs, syms::Set{Symbol}, prefix::AbstractString)
    v = collect(syms)
    var_resource_names = string.(strip_common_prefix(v, prefix))

    # put in same order as regular resources
    gen = inputs["RESOURCES"]
    r_id = resource_id.(resource_by_name.(Ref(gen), var_resource_names))
    sort_order = sortperm(r_id)

    r_id = r_id[sort_order]
    v = v[sort_order]

    extract(var) = value.(extract_data(EP[var]))

    mat = Matrix(reduce(hcat, extract.(v))') # matrix of size length(syms) x T
    return r_id, mat
end

function strip_common_prefix(v::Vector{Symbol}, prefix::AbstractString)
    s = string.(v)
    return Symbol.(chopprefix.(s, prefix))
end

function prepare_maintenance_downvars_matrix(EP::Model, inputs::Dict)
    downvars = maintenance_down_variables(inputs)
    return prepare_timeseries_variables(EP, inputs, downvars, "vMDOWN_")
end

function write_maintenance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    set, data = prepare_maintenance_downvars_matrix(EP, inputs)
    df = _create_annualsum_df(inputs, set, data)
    write_temporal_data(df, data, path, setup, "maint_down")
end
