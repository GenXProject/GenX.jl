###### ###### ###### ###### ###### ######
# Create dense arrays of expressions filled with zeros to be added to later
###### ###### ###### ###### ###### ######

function create_empty_expression!(EP::Model, exprname::Symbol)
    EP[exprname] = AffExpr(0.0)
    return nothing
end

function create_empty_expression!(EP::Model, exprname::Symbol, dim1::Int64)
    temp = Array{AffExpr}(undef, dim1)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

function create_empty_expression!(EP::Model, exprname::Symbol, dims::NTuple{N, Int64}) where N
    temp = Array{AffExpr}(undef, dims)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

function create_empty_expression!(EP::Model, exprname::Symbol, dims::Vector{Int64})
    # The version using tuples is slightly less memory
    temp = Array{AffExpr}(undef, dims...)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

###### ###### ###### ###### ###### ######
# Fill dense arrays of expressions with zeros or a constant
###### ###### ###### ###### ###### ######

function fill_with_zeros!(arr::Array{GenericAffExpr{C,T}, dims}) where {C,T,dims}
    for i::Int64 in eachindex(IndexLinear(), arr)::Base.OneTo{Int64}
        arr[i] = AffExpr(0.0)
    end
    return nothing
end

function fill_with_const!(arr::Array{GenericAffExpr{C,T}, dims}, con::Real) where {C,T,dims}
    for i::Int64 in eachindex(IndexLinear(), arr)::Base.OneTo{Int64}
        arr[i] = AffExpr(con)
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Create an expression from some indices of a 2D variable array
###### ###### ###### ###### ###### ######
#
function extract_time_series_to_expression(var::Matrix{VariableRef},
                                           set::AbstractVector{Int})
    TIME_DIM = 2
    time_range = 1:size(var)[TIME_DIM]

    aff_exprs_data = AffExpr.(0, var[set, :] .=> 1)
    new_axes = (set, time_range)
    expr = JuMP.Containers.DenseAxisArray(aff_exprs_data, new_axes...)
    return expr
end

function extract_time_series_to_expression(var::JuMP.Containers.DenseAxisArray{VariableRef, 2, Tuple{X, Base.OneTo{Int64}}, Y},
                                           set::AbstractVector{Int}) where {X, Y}
    TIME_DIM = 2
    time_range = var.axes[TIME_DIM]

    aff_exprs = AffExpr.(0, var[set, :] .=> 1)
    new_axes = (set, time_range)
    expr = JuMP.Containers.DenseAxisArray(aff_exprs.data, new_axes...)
    return expr
end

###### ###### ###### ###### ###### ######
# Element-wise addition of one expression into another
# Both arrays must have the same dimensions
###### ###### ###### ###### ###### ######

function add_similar_to_expression!(expr1::GenericAffExpr{C,T}, expr2::V) where {C,T,V}
    add_to_expression!(expr1, expr2)
    return nothing
end

function add_similar_to_expression!(expr1::Array{GenericAffExpr{C,T}, dim1}, expr2::Array{V, dim2}) where {C,T,V,dim1,dim2}
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

function add_similar_to_expression!(expr1::AbstractArray{GenericAffExpr{C,T}, dim1}, expr2::AbstractArray{V, dim2}) where {C,T,V,dim1,dim2}
    # This is defined for Arrays of different dimensions
    # despite the fact it will definitely throw an error
    # because the error will tell the user / developer
    # the dimensions of both arrays
    check_sizes_match(expr1, expr2)
    for i in eachindex(expr1)
        add_to_expression!(expr1[i], expr2[i])
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Element-wise addition of one term into an expression
# Both arrays must have the same dimensions
###### ###### ###### ###### ###### ######

function add_term_to_expression!(expr1::GenericAffExpr{C,T}, expr2::V) where {C,T,V}
    add_to_expression!(expr1, expr2)
    return nothing
end

function add_term_to_expression!(expr1::Array{GenericAffExpr{C,T}, dims}, expr2::V) where {C,T,V,dims}
    for i in eachindex(IndexLinear(), expr1)
        add_to_expression!(expr1[i], expr2)
    end
    return nothing
end

function add_term_to_expression!(expr1::AbstractArray{GenericAffExpr{C,T}, dims}, expr2::V) where {C,T,V,dims}
    for i in eachindex(expr1)
        add_to_expression!(expr1[i], expr2)
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Check that two arrays have the same dimensions
###### ###### ###### ###### ###### ######

function check_sizes_match(expr1::AbstractArray{C, dim1}, expr2::AbstractArray{T, dim2}) where {C,T,dim1, dim2}
    # After testing, this appears to be just as fast as a method for Array{GenericAffExpr{C,T}, dims} or Array{AffExpr, dims}
    if size(expr1) != size(expr2)
        error("
            Both expressions must have the same dimensions
            Attempted to add each term of $(size(expr1))-sized expression to $(size(expr2))-sized expression")
    end
end

###### ###### ###### ###### ###### ######
# Sum an array of expressions into a single expression
###### ###### ###### ###### ###### ######

function sum_expression(expr::AbstractArray{C, dims}) where {C,dims}
    # This appears to work just as well as a separate method for Array{AffExpr, dims}
    total = AffExpr(0.0)
    for i in eachindex(expr)
        add_to_expression!(total, expr[i])
    end
    return total
end

function sum_expression(expr::AbstractArray{GenericAffExpr{C,T}, dims}) where {C,T,dims}
    return _sum_expression(expr)
end

function sum_expression(expr::AbstractArray{GenericVariableRef{C}, dims}) where {C,dims}
    return _sum_expression(expr)
end

function sum_expression(expr::AbstractArray{AbstractJuMPScalar, dims}) where {dims}
    return _sum_expression(expr)
end
