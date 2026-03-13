module TestDryCoolerModel

using Test
using GenX
using JuMP
using HiGHS
import MathOptInterface as MOI

struct MockUTESResource <: GenX.AbstractResource
    data::Dict{Symbol, Any}
end

Base.parent(r::MockUTESResource) = r.data

@testset "Dry Cooler Branch COP Logic" begin
    T = 2
    Z = 1
    UTES_Indices = [1]

    r_data = Dict{Symbol, Any}(
        :id => 1,
        :zone => 1,
        :thermal_capacity_second_loop => 2.0,
        :temp_max_data_center_in_c => 40.0,
        :temp_data_center_out_c => 50.0,
        :max_working_fluid_temp_second_loop => 85.0,
        :min_working_fluid_temp_second_loop => 5.0
    )

    gen = [MockUTESResource(r_data)]

    inputs = Dict(
        "T" => T,
        "Z" => Z,
        "UTES" => UTES_Indices,
        "RESOURCES" => gen,
        "pD_Computing" => fill(20.0, T, Z),
        "pAmbientTemp" => fill(25.0, Z, T),
        "COP_DC" => Dict(1 => fill(4.0, T)),
        "COP_DC_Data_Center" => Dict(1 => fill(4.0, T)),
        "COP_DC_Reservoir" => Dict(1 => fill(4.0, T)),
        "COP_Chiller" => Dict(1 => fill(2.0, T)),
    )

    setup = Dict(
        "CapacityReserveMargin" => 0,
        "HourlyMatching" => 0,
    )

    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, vTemp_DC[y in UTES_Indices, t=1:T])
    @variable(model, vTemp_Chiller[y in UTES_Indices, t=1:T])
    @variable(model, eTotalCap_UTES[y in UTES_Indices, c=1:4] >= 0)
    @expression(model, ePowerBalance[t=1:T, z=1:Z], 0.0)

    for t in 1:T
        fix(vTemp_DC[1, t], 45.0; force=true)
        fix(vTemp_Chiller[1, t], 45.0; force=true)
        for c in 1:4
            fix(eTotalCap_UTES[1, c], 100.0; force=true)
        end
    end

    GenX.dry_cooler!(model, inputs, setup)

    @objective(model, Min, 0)
    optimize!(model)

    @test termination_status(model) == MOI.OPTIMAL

    eThermalTotal = model[:eThermalPower_DC_Total]
    eThermalReservoir = model[:eThermalPower_DC_Reservoir]
    eThermalDirect = model[:eThermalPower_DC_Data_Center]
    eElecTotal = model[:eElec_DC]
    eElecDirect = model[:eElec_DC_Data_Center]
    eElecReservoir = model[:eElec_DC_Reservoir]

    for t in 1:T
        @test value(eThermalTotal[1, t]) ≈ 10.0 atol=1e-8
        @test value(eThermalReservoir[1, t]) ≈ -10.0 atol=1e-8
        @test value(eThermalDirect[1, t]) ≈ 20.0 atol=1e-8
        @test value(eElecDirect[1, t]) ≈ 5.0 atol=1e-8
        @test value(eElecReservoir[1, t]) ≈ -2.5 atol=1e-8
        @test value(eElecTotal[1, t]) ≈ 2.5 atol=1e-8
    end
end

end