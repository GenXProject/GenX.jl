function createemptyexpression!(EP::Model, exprname::Symbol, dim1::Int64)
	EP[exprname] = Vector{AffExpr}(undef, dim1)
	for i=1:dim1
		EP[exprname][i] = AffExpr(0.0)
	end
end

function createemptyexpression!(EP::Model, exprname::Symbol, dim1::Int64, dim2::Int64)
	EP[exprname] = Matrix{AffExpr}(undef, (dim1, dim2))
	for j=1:dim2
		for i=1:dim1
			EP[exprname][i,j] = AffExpr(0.0)
		end
	end
end

function createemptyexpression!(EP::Model, exprname::Symbol, dims::NTuple{N, Int64}) where N
	EP[exprname] = Array{AffExpr}(undef, dims)
    fill_with_zeros!(EP[exprname])
    return nothing
end

function createemptyexpression!(EP::Model, exprname::Symbol, dims::Vector{Int64})
	# The version using tuples is slightly less memory
    EP[exprname] = Array{AffExpr}(undef, dims...)
    fill_with_zeros!(EP[exprname])
    return nothing
end

function fill_with_zeros!(arr::Array{AffExpr, dims}) where dims
	for i::Int64 in eachindex(IndexLinear(), arr)::Base.OneTo{Int64}
		arr[i] = AffExpr(0.0)
	end
    return nothing
end

function fill_with_const!(arr::Array{AffExpr, dims}, con::Float64) where dims
	for i::Int64 in eachindex(IndexLinear(), arr)::Base.OneTo{Int64}
		arr[i] = AffExpr(con)
	end
    return nothing
end

function add_similar_to_expression!(expr1::Array{AffExpr, dims}, expr2::Array{AffExpr, dims}) where dims
    # Check that both expr1 and expr2 have the same dimensions
    if size(expr1) != size(expr2)
        error("Both expressions must have the same dimensions")
    end
    for i::Int64 in eachindex(IndexLinear(), expr1)::Base.OneTo{Int64}
        add_to_expression!(expr1[i], expr2[i])
    end
    return nothing
end