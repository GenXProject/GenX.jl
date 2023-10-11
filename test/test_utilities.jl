module TestUtilities

using Test

include(joinpath(@__DIR__, "utilities.jl"))

@testset "get_exponent_sciform" begin
    @test get_exponent_sciform(0) == 0
    @test get_exponent_sciform(0.005) == -3
    @test get_exponent_sciform(0.0531) == -2
    @test get_exponent_sciform(1) == 0
    @test get_exponent_sciform(1.0000) == 0
    @test get_exponent_sciform(1.0005) == 0
    @test get_exponent_sciform(64.000) == 1
    @test get_exponent_sciform(64.03) == 1
    @test get_exponent_sciform(100) == 2
end

@testset "round_objfromtol" begin
    @test round_objfromtol!(0, 0) == 0
    @test round_objfromtol!(0.005, 1) == 0
    @test round_objfromtol!(0.005, 0.1) == 0.0
    @test round_objfromtol!(0.005, 0.01) == 0.0
    @test round_objfromtol!(0.005, 0.001) == 0.005
    @test round_objfromtol!(0.005, 0.0001) == 0.005
    @test round_objfromtol!(1.005, 1) == 1
    @test round_objfromtol!(1.005, 0.1) == 1.0
    @test round_objfromtol!(1.005, 0.01) == 1.0
    @test round_objfromtol!(1.005, 0.001) == 1.005
    @test round_objfromtol!(2.006, 0.01) == 2.01
    @test round_objfromtol!(10.65, 10) == 10
    @test round_objfromtol!(10.65, 1) == 11
    @test round_objfromtol!(10.65, 0.1) == 10.6
    @test round_objfromtol!(10.65, 0.01) == 10.65
    @test round_objfromtol!(10.65, 0.001) == 10.65
end


end # module TestUtilities