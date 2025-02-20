###### ###### ###### ###### ###### ######
# Create dense arrays of expressions filled with zeros to be added to later
###### ###### ###### ###### ###### ######

# Single element version
function create_empty_expression!(EP::Model, exprname::Symbol)
    EP[exprname] = AffExpr(0.0)
    return nothing
end

# Vector version, to avoid needing to wrap the dimension in a tuple or array
function create_empty_expression!(EP::Model, exprname::Symbol, dim1::Int64)
    temp = Array{AffExpr}(undef, dim1)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

@doc raw"""
    create_empty_expression!(EP::Model, exprname::Symbol, dims::NTuple{N, Int64}) where N

Create an dense array filled with zeros which can be altered later.
Other approaches to creating zero-filled arrays will often return an array of floats, not expressions.
This can lead to errors later if a method can only operate on expressions.
    
We don't currently have a method to do this with non-contiguous indexing.
"""
function create_empty_expression!(EP::Model,
        exprname::Symbol,
        dims::NTuple{N, Int64}) where {N}
    temp = Array{AffExpr}(undef, dims)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

# Version with the dimensions wrapped in an array. This requires slightly more memory than using tuples
function create_empty_expression!(EP::Model, exprname::Symbol, dims::Vector{Int64})
    temp = Array{AffExpr}(undef, dims...)
    fill_with_zeros!(temp)
    EP[exprname] = temp
    return nothing
end

###### ###### ###### ###### ###### ######
# Fill dense arrays of expressions with zeros or a constant
###### ###### ###### ###### ###### ######

@doc raw"""
    fill_with_zeros!(arr::AbstractArray{GenericAffExpr{C,T}, dims}) where {C,T,dims}

Fill an array of expressions with zeros in-place.
"""
function fill_with_zeros!(arr::AbstractArray{GenericAffExpr{C, T}, dims}) where {C, T, dims}
    for i::Int64 in eachindex(IndexLinear(), arr)::Base.OneTo{Int64}
        arr[i] = AffExpr(0.0)
    end
    return nothing
end

@doc raw"""
    fill_with_const!(arr::AbstractArray{GenericAffExpr{C,T}, dims}, con::Real) where {C,T,dims}

Fill an array of expressions with the specified constant, in-place.

In the future we could expand this to non AffExpr, using GenericAffExpr
e.g. if we wanted to use Float32 instead of Float64
"""
function fill_with_const!(arr::AbstractArray{GenericAffExpr{C, T}, dims},
        con::Real) where {C, T, dims}
    for i in eachindex(arr)
        arr[i] = AffExpr(con)
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Create an expression from some first-dimension indices of a 2D variable array,
# where all of the 2nd-dimension indices are kept
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

function extract_time_series_to_expression(
        var::JuMP.Containers.DenseAxisArray{
            VariableRef,
            2,
            Tuple{X, Base.OneTo{Int64}},
            Y
        },
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

# Version for single element
function add_similar_to_expression!(expr1::GenericAffExpr{C, T}, expr2::V) where {C, T, V}
    add_to_expression!(expr1, expr2)
    return nothing
end

@doc raw"""
    add_similar_to_expression!(expr1::AbstractArray{GenericAffExpr{C,T}, dim1}, expr2::AbstractArray{V, dim2}) where {C,T,V,dim1,dim2}

Add an array of some type `V` to an array of expressions, in-place. 
This will work on JuMP DenseContainers which do not have linear indexing from 1:length(arr).
However, the accessed parts of both arrays must have the same dimensions.
"""
function add_similar_to_expression!(expr1::AbstractArray{GenericAffExpr{C, T}, dim1},
        expr2::AbstractArray{V, dim2}) where {C, T, V, dim1, dim2}
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

# If the expressions are vectors of numbers, use the += operator
function add_similar_to_expression!(arr1::AbstractArray{T, dims},
        arr2::AbstractArray{T, dims}) where {T <: Number, dims}
    for i in eachindex(arr1)
        arr1[i] += arr2[i]
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Element-wise addition of one term into an expression
# Both arrays must have the same dimensions
###### ###### ###### ###### ###### ######

# Version for single element
function add_term_to_expression!(expr1::GenericAffExpr{C, T}, expr2::V) where {C, T, V}
    add_to_expression!(expr1, expr2)
    return nothing
end

@doc raw"""
    add_term_to_expression!(expr1::AbstractArray{GenericAffExpr{C,T}, dims}, expr2::V) where {C,T,V,dims}

Add an entry of type `V` to an array of expressions, in-place. 
This will work on JuMP DenseContainers which do not have linear indexing from 1:length(arr).
"""
function add_term_to_expression!(expr1::AbstractArray{GenericAffExpr{C, T}, dims},
        expr2::V) where {C, T, V, dims}
    for i in eachindex(expr1)
        add_to_expression!(expr1[i], expr2)
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Check that two arrays have the same dimensions
###### ###### ###### ###### ###### ######

@doc raw"""
    check_sizes_match(expr1::AbstractArray{C, dim1}, expr2::AbstractArray{T, dim2}) where {C,T,dim1, dim2}

Check that two arrays have the same dimensions. 
If not, return an error message which includes the dimensions of both arrays.
"""
function check_sizes_match(expr1::AbstractArray{C, dim1},
        expr2::AbstractArray{T, dim2}) where {C, T, dim1, dim2}
    # After testing, this appears to be just as fast as a method for Array{GenericAffExpr{C,T}, dims} or Array{AffExpr, dims}
    if size(expr1) != size(expr2)
        error("
            Both expressions must have the same dimensions
            Attempted to add each term of $(size(expr1))-sized expression to $(size(expr2))-sized expression")
    end
end

@doc raw"""
    check_addable_to_expr(C::DataType, T::DataType)

Check that two datatype can be added using add_to_expression!(). Raises an error if not.

This needs some work to make it more flexible. Right now it's challenging to use with GenericAffExpr{C,T}
as the method only works on the constituent types making up the GenericAffExpr, not the resulting expression type.
Also, the default MethodError from add_to_expression! is sometime more informative than the error message here.
"""
function check_addable_to_expr(C::DataType, T::DataType)
    if !(hasmethod(add_to_expression!, (C, T)))
        error("No method found for add_to_expression! with types $(C) and $(T)")
    end
end

###### ###### ###### ###### ###### ######
# Sum an array of expressions into a single expression
###### ###### ###### ###### ###### ######

@doc raw"""
    sum_expression(expr::AbstractArray{C, dims}) where {C,dims} :: C

Sum an array of expressions into a single expression and return the result.
We're using errors from add_to_expression!() to check that the types are compatible.
"""
function sum_expression(expr::AbstractArray{C, dims})::AffExpr where {C, dims}
    # check_addable_to_expr(C,C)
    total = AffExpr(0.0)
    for i in eachindex(expr)
        add_to_expression!(total, expr[i])
    end
    return total
end
