function createemptyexpression!(EP::Model, exprname::Symbol, dim1::Int64)
    temp = Vector{AffExpr}(undef, dim1)
    for i=1:dim1::Int64
        temp[i] = AffExpr(0.0)
    end
    EP[exprname] = temp
end

function createemptyexpression!(EP::Model, exprname::Symbol, dim1::Int64, dim2::Int64)
    temp = Matrix{AffExpr}(undef, (dim1, dim2))
    for j=1:dim2
        for i=1:dim1
            temp[i,j] = AffExpr(0.0)
        end
    end
    EP[exprname] = temp
end

function createemptyexpression!(EP::Model, exprname::Symbol, dims::NTuple{N, Int64}) where N
    temp = Array{AffExpr}(undef, dims)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

function createemptyexpression!(EP::Model, exprname::Symbol, dims::Vector{Int64})
    # The version using tuples is slightly less memory
    temp = Array{AffExpr}(undef, dims...)
    fill_with_zeros!(temp)
    EP[exprname] = temp
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

function _add_similar_to_expression!(expr1::Array{C, dim1}, expr2::Array{T, dim2}) where {C,T,dim1,dim2}
    # This is defined for Arrays of different dimensions
    # despite the fact it will definitely throw an error
    # because the error will tell the user / developer
    # the dimensions of both arrays
    check_sizes_match(expr1, expr2)
    for i in eachindex(IndexLinear(), expr1)
        add_to_expression!(expr1[i], expr2[i])
    end
    return nothing
end

function add_similar_to_expression!(expr1::Array{GenericAffExpr{C,T}, dim1}, expr2::Array{GenericAffExpr{C,T}, dim2}) where {C,T,dim1,dim2}
    _add_similar_to_expression!(expr1, expr2)
end

function add_similar_to_expression!(expr1::Array{GenericAffExpr{C,T}, dim1}, expr2::Array{GenericVariableRef{C}, dim2}) where {C,T,dim1,dim2}
    _add_similar_to_expression!(expr1, expr2)
end

function add_similar_to_expression!(expr1::Array{GenericAffExpr{C,T}, dim1}, expr2::Array{AbstractJuMPScalar, dim2}) where {C,T,dim1,dim2}
    _add_similar_to_expression!(expr1, expr2)
end

function _add_term_to_expression!(expr1::Array{C, dims}, expr2::T) where {C,T,dims}
    for i in eachindex(IndexLinear(), expr1)
        add_to_expression!(expr1[i], expr2)
    end
    return nothing
end

function add_term_to_expression!(expr1::Array{AffExpr, dims}, expr2::Float64) where dims
    _add_term_to_expression!(expr1, expr2)
end

function add_term_to_expression!(expr1::Array{AffExpr, dims}, expr2::VariableRef) where dims
    _add_term_to_expression!(expr1, expr2)
end

function add_term_to_expression!(expr1::Array{GenericAffExpr{C,T}, dims}, expr2::GenericVariableRef{C}) where {C,T,dims}
    _add_term_to_expression!(expr1, expr2)
end

function add_term_to_expression!(expr1::Array{GenericAffExpr{C,T}, dims}, expr2::AbstractJuMPScalar) where {C,T,dims}
    _add_term_to_expression!(expr1, expr2)
end

# After testing, this appears to be just as fast as a method for Array{GenericAffExpr{C,T}, dims} or Array{AffExpr, dims}
function check_sizes_match(expr1::Array{C, dim1}, expr2::Array{T, dim2}) where {C,T,dim1, dim2}
    if size(expr1) != size(expr2)
        error("
            Both expressions must have the same dimensions
            Attempted to add each term of $(size(expr1))-sized expression to $(size(expr2))-sized expression")
    end
end