using JuMP
using HiGHS

let 
    EP = Model(HiGHS.Optimizer)

    # Test fill_with_zeros!
    small_zeros_expr = Array{AffExpr,2}(undef,(2,3))
    GenX.fill_with_zeros!(small_zeros_expr)
    @test small_zeros_expr == AffExpr.([0.0 0.0 0.0; 0.0 0.0 0.0])

    # Test fill_with_const!
    small_const_expr = Array{AffExpr,2}(undef,(3,2))
    GenX.fill_with_const!(small_const_expr, 6.0)
    @test small_const_expr == AffExpr.([6.0 6.0; 6.0 6.0; 6.0 6.0])

    # Test create_empty_expression! with fill_with_const!
    large_dims = (2,10,20)
    GenX.create_empty_expression!(EP, :large_expr, large_dims)
    @test all(EP[:large_expr] .== 0.0)

    # Test create_empty_expression! with fill_with_const!
    large_dims_vector = collect(large_dims)
    GenX.create_empty_expression!(EP, :large_const_expr, large_dims)
    GenX.fill_with_const!(EP[:large_const_expr], 6.0)
    @test all(EP[:large_const_expr] .== 6.0)

    # Test add_similar_to_expression! only adds each term once
    GenX.add_similar_to_expression!(EP[:large_expr], EP[:large_const_expr])
    @test all(EP[:large_expr][:] .== 6.0)
    GenX.add_similar_to_expression!(EP[:large_expr], EP[:large_const_expr])
    GenX.add_similar_to_expression!(EP[:large_expr], EP[:large_const_expr])
    @test all(EP[:large_expr][:] .== 18.0)

    # Test add_similar_to_expression! returns an error if the dimensions don't match
    GenX.create_empty_expression!(EP, :small_expr, (2,3))
    @test_throws ErrorException GenX.add_similar_to_expression!(EP[:large_expr], EP[:small_expr])

    # Test we can add variables to an expression using add_similar_to_expression!
    @variable(EP, test_var[1:large_dims[1], 1:large_dims[2], 1:large_dims[3]] >= 0)
    GenX.add_similar_to_expression!(EP[:large_expr], test_var)
    @test EP[:large_expr][100] == test_var[100] + 18.0

    # Test add_term_to_expression! for a Float64
    GenX.add_term_to_expression!(EP[:large_expr], 1.0)
    @test EP[:large_expr][100] == test_var[100] + 19.0

    # Test add_term_to_expression! for an expression
    GenX.add_term_to_expression!(EP[:large_expr], AffExpr(3.0))
    @test EP[:large_expr][100] == test_var[100] + 22.0

    # Test add_term_to_expression! for variable
    @variable(EP, single_var >= 0)
    GenX.add_term_to_expression!(EP[:large_expr], single_var)
    @test EP[:large_expr][100] == test_var[100] + 22.0 + single_var

    # Test extracting some rows from a 2D matrix variable
    columns = 10
    @variable(EP, var_matrix[row in 1:4, col in 1:columns])
    rows_to_extract = [3, 4]
    expr = GenX.extract_time_series_to_expression(var_matrix, rows_to_extract)
    @test size(expr) == (length(rows_to_extract), columns)
    @test expr isa JuMP.Containers.DenseAxisArray
    @test eltype(expr.data) isa AffExpr
    @test expr.axes[1] == rows_to_extract
    @test expr.axes[2] == 1:columns
    unregister(EP, :var_matrix)

    # Test extracting some rows from a 2D dense axis array variable
    @variable(EP, var_denseaxisarray[row in [1, 3, 5, 11], col in 1:columns])
    rows_to_extract = [3, 5]
    expr = GenX.extract_time_series_to_expression(var_denseaxisarray, rows_to_extract)
    @test size(expr) == (length(rows_to_extract), columns)
    @test expr isa JuMP.Containers.DenseAxisArray
    @test expr.axes[1] == rows_to_extract
    @test expr.axes[2] == 1:columns
    unregister(EP, :var_denseaxisarray)
end

 ###### ###### ###### ###### ###### ###### ###### 
 ###### ###### ###### ###### ###### ###### ###### 
    # Performance tests we can perhaps add later
    # These require the BenchmarkTests.jl package
 ###### ###### ###### ###### ###### ###### ###### 
 ###### ###### ###### ###### ###### ###### ###### 

# function test_performance(expr_dims)
#     EP = Model(HiGHS.Optimizer)
#     GenX.create_empty_expression!(EP, :e, expr_dims)
#     GenX.create_empty_expression!(EP, :r, expr_dims)
#     GenX.fill_with_const!(EP[:r], 6.0)
#     @code_warntype GenX._add_similar_to_expression!(EP[:e], EP[:r])
#     @code_warntype GenX.add_similar_to_expression!(EP[:e], EP[:r])
#     benchmark_results = @benchmark GenX.add_similar_to_expression!(EP[:e], EP[:r])
#     return benchmark_results
# end

# small_benchmark = test_performance((2,3))
# medium_benchmark = test_performance((2,10,20))
# large_benchmark = test_performance((2,20,40))

