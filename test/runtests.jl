using GenX
using Test
using Logging

include("utilities.jl")

@testset "Expr manipulation" begin
    include("expression_manipulation_test.jl")
end

if VERSION ≥ v"1.7"
    @testset "Resource loading" begin
        include("test_load_resource_data.jl")
    end
end

# Test GenX modules
@testset verbose=true "GenX modules" begin
    @testset "Three zones" begin
        include("test_threezones.jl")
    end

    @testset "TDR" begin
        include("test_time_domain_reduction.jl")
    end

    @testset "Piecewise Fuel" begin
        include("test_piecewisefuel.jl")
    end

    @testset "VRE_STOR" begin
        include("test_VRE_storage.jl")
    end

    @testset "Electrolyzer" begin
        include("test_electrolyzer.jl")
    end

    @testset "Multi Stage" begin
        include("test_multistage.jl")
    end

    @testset "DCOPF" begin
        include("test_DCOPF.jl")
    end

    @testset "Multi Fuels" begin
        include("test_multifuels.jl")
    end

    @testset "Compute Conflicts" begin
        include("test_compute_conflicts.jl")
    end

    @testset "Retrofit" begin
        include("test_retrofit.jl")
    end
end
