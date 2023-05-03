using GenX
using Test
#These are just some dummy sample test; The full-grown unit testing module is under active development currently
@testset "GenX.jl" begin
    @test simple_operation(2.0, 3.0) == 5
    @test simple_operation(2.1, 3.1)==5.2
    @test simple_operation(21.0, 31.0)== 52.0
    @test simple_operation(73.0, 35.0)== 108.0
    #=
    @test isa(inputs_gen["THERM_COMMIT"], Int64)
    @test isa(inputs_gen["THERM_NO_COMMIT"], Int64)
    @test isa(inputs_gen["HYDRO_RES"], Int64)
    @test isa(inputs_gen["HYDRO_RES_KNOWN_CAP"], Int64)
    @test isa(inputs_gen["FLEX"], Int64)
    @test isa(inputs_gen["MUST_RUN"], Int64)
    @test isa(inputs_gen["VRE"], Int64)
    =#
end
