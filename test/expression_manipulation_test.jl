using GenX
using Test

let 
    EP = Model(Gurobi.Optimizer)

    # Test fill_with_zeros!
    small_zeros_expr = Array{AffExpr,2}(undef,(2,3))
    fill_with_zeros!(small_zeros_expr)
    @test small_zeros_expr == AffExpr.([0.0 0.0 0.0; 0.0 0.0 0.0])

    # Test fill_with_const!
    small_const_expr = Array{AffExpr,2}(undef,(3,2))
    fill_with_const!(small_const_expr, 6.0)
    @test small_const_expr == AffExpr.([6.0 6.0; 6.0 6.0; 6.0 6.0])

    # Test createemptyexpression! with fill_with_const!
    large_dims = (2,10,20)
    createemptyexpression!(EP, :large_expr, large_dims)
    @test all(EP[:large_expr] .== 0.0)

    # Test createemptyexpression! with fill_with_const!
    large_dims_vector = collect(large_dims)
    createemptyexpression!(EP, :large_const_expr, large_dims)
    fill_with_const!(EP[:large_const_expr], 6.0)
    @test all(EP[:large_const_expr] .== 6.0)

    # Test add_similar_to_expression! only adds each term once
    add_similar_to_expression!(EP[:large_expr], EP[:large_const_expr])
    @test all(EP[:large_expr][:] .== 6.0)
    add_similar_to_expression!(EP[:large_expr], EP[:large_const_expr])
    add_similar_to_expression!(EP[:large_expr], EP[:large_const_expr])
    @test all(EP[:large_expr][:] .== 18.0)

    # Test add_similar_to_expression! returns an error if the dimensions don't match
    createemptyexpression!(EP, :small_expr, (2,3))
    @test_throws ErrorException add_similar_to_expression!(EP[:large_expr], EP[:small_expr])

    # Test we can add variables to an expression using add_similar_to_expression!
    @variable(EP, test_var[1:large_dims[1], 1:large_dims[2], 1:large_dims[3]] >= 0)
    add_similar_to_expression!(EP[:large_expr], test_var)
    @test EP[:large_expr][100] == test_var[100] + 18.0

    # Test add_term_to_expression! for a Float64
    add_term_to_expression!(EP[:large_expr], 1.0)
    @test EP[:large_expr][100] == test_var[100] + 19.0

    # Test add_term_to_expression! for an expression
    add_term_to_expression!(EP[:large_expr], AffExpr(3.0))
    @test EP[:large_expr][100] == test_var[100] + 22.0

    # Test add_term_to_expression! for variable
    @variable(EP, single_var >= 0)
    add_term_to_expression!(EP[:large_expr], single_var)
    @test EP[:large_expr][100] == test_var[100] + 22.0 + single_var
end

 ###### ###### ###### ###### ###### ###### ###### 
 ###### ###### ###### ###### ###### ###### ###### 
    # Performance tests we can perhaps add later
    # These require the BenchmarkTests.jl package
 ###### ###### ###### ###### ###### ###### ###### 
 ###### ###### ###### ###### ###### ###### ###### 

# function test_performance(expr_dims)
#     EP = Model(Gurobi.Optimizer)
#     createemptyexpression!(EP, :e, expr_dims)
#     createemptyexpression!(EP, :r, expr_dims)
#     fill_with_const!(EP[:r], 6.0)
#     @code_warntype _add_similar_to_expression!(EP[:e], EP[:r])
#     @code_warntype add_similar_to_expression!(EP[:e], EP[:r])
#     benchmark_results = @benchmark add_similar_to_expression!(EP[:e], EP[:r])
#     return benchmark_results
# end

# small_benchmark = test_performance((2,3))
# medium_benchmark = test_performance((2,10,20))
# large_benchmark = test_performance((2,20,40))

