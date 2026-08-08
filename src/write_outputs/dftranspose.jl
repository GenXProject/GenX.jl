################################################################################
## helpers for writing transposed output tables
################################################################################
@doc raw"""
    transpose_output_dataframe(df::DataFrame; withhead::Bool=false)

Return a transposed copy of an output DataFrame without collecting each row into
an intermediate vector.
"""
function transpose_output_dataframe(df::DataFrame; withhead::Bool = false)
    row_count, col_count = size(df)
    colnames = withhead ? Symbol[:Row; Symbol.(df[!, 1])] :
               Symbol[:Row; Symbol.("x", 1:row_count)]
    transposed = Matrix{Any}(undef, col_count, row_count + 1)
    headers = names(df)

    for col in 1:col_count
        transposed[col, 1] = headers[col]
    end

    for row in 1:row_count
        for col in 1:col_count
            transposed[col, row + 1] = df[row, col]
        end
    end

    return DataFrame(transposed, colnames)
end

function write_transposed_csv(filename::AbstractString, df::DataFrame; kwargs...)
    options = Dict{Symbol, Any}(pairs(kwargs))
    if haskey(options, :writeheader) && !haskey(options, :header)
        options[:header] = options[:writeheader]
        delete!(options, :writeheader)
    end
    return CSV.write(filename, transpose_output_dataframe(df); options...)
end
