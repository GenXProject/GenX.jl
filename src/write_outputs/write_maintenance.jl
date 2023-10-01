function write_simple_csv(filename::AbstractString, df::DataFrame)
    CSV.write(filename, df)
end

function write_simple_csv(filename::AbstractString,
                          header::Vector,
                          matrix)
    df = DataFrame(matrix, header)
    write_simple_csv(filename, df)
end

function prepare_timeseries_variables(EP::Model, set::Set{Symbol})
    # function to extract data from DenseAxisArray
    data(var) = value.(EP[var]).data

    return DataFrame(set .=> data.(set))
end

function write_timeseries_variables(EP, set::Set{Symbol}, filename::AbstractString)
    df = prepare_timeseries_variables(EP, set)
    write_simple_csv(filename, df)
end

@doc raw"""
    write_maintenance(path::AbstractString, inputs::Dict, EP::Model)
"""
function write_maintenance(path::AbstractString, inputs::Dict, EP::Model)
    downvars = get_maintenance_down_variables(inputs)
    write_timeseries_variables(EP, downvars, joinpath(path, "maint_down.csv"))
end
