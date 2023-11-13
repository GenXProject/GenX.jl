using GenX
using Test
using Logging

include("utilities.jl")


@testset "Simple operation" begin
    include("simple_op_test.jl")
end

@testset "Resource validation" begin
    include("resource_test.jl")
end

@testset "Expression manipulation" begin
    include("expression_manipulation_test.jl")
end

# Test GenX modules
@testset verbose = true "GenX modules" begin
    @testset "Three zones" begin
        include("test_threezones.jl")
    end

    @testset "Time domain reduction" begin
        include("test_time_domain_reduction.jl")
    end

    @testset "PiecewiseFuel CO2" begin
        include("test_piecewisefuel_CO2.jl")
    end

    @testset "VRE and storage" begin
        include("test_VREStor.jl")
    end

    @testset "Electrolyzer" begin
        include("test_electrolyzer.jl")
    end

    @testset "Method of Morris" begin
        VERSION ≥ v"1.7" && include("test_methodofmorris.jl")
    end

    @testset "Multi Stage" begin
        include("test_multistage.jl")
    end
end
