using GenX
using Test

@testset "Simple operation" begin
    include("simple_op_test.jl")
end

@testset "Resource validation" begin
    include("resource_test.jl")
end
