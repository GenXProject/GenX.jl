module TestRTESModel

using Test
using GenX
using JuMP
using HiGHS
using CSV
using DataFrames
import MathOptInterface as MOI

struct MockRTESResource <: GenX.AbstractResource
    data::Dict{Symbol, Any}
end

Base.parent(r::MockRTESResource) = getfield(r, :data)

# -----------------------------------------------------------------------
# Shared physical parameters
# Q = 10 MW,  T_dc_out = 50°C,  T_HX12 = 40°C,  c_sl = 2 MJ/(kg·°C)
# m_sl = Q / (c_sl * ΔT) = 10 / (2*10) = 0.5 kg/s
#
# eThermalPower_UTES_Reservoir (mocked as fixed constants):
#   t=1: +2 MW (charging)
#   t=2:  0 MW (neutral)
#   t=3: -2 MW (discharging)
# -----------------------------------------------------------------------
const Q_VAL    = 10.0
const T_DC_OUT = 50.0
const T_HX12   = 40.0
const C_SL     = 2.0
const M_SL     = Q_VAL / (C_SL * (T_DC_OUT - T_HX12))

function make_resource()
    MockRTESResource(Dict{Symbol, Any}(
        :id  => 1,
        :zone => 1,
        :self_disch => 0.0,
        :hours_storage => 3.0,
        :thermal_capacity_tertiary_loop => 0.004184,
        :temp_hot_thermal_storage => 45.0,
        :temp_cold_thermal_storage => 35.0,
        :pump_total_pressure_drop_bar => 10.0,
        :efficiency_rtes_pump => 0.8,
        :temp_data_center_out_c => T_DC_OUT,
        :temp_max_data_center_in_c => T_HX12,
        :thermal_capacity_second_loop => C_SL,
    ))
end

# reservoir_vals = [+2.0, 0.0, -2.0] MW
const RESERVOIR_VALS = let
    vTemp_Chiller_vals = [38.0, 40.0, 42.0]
    [C_SL * M_SL * (T_HX12 - vt) for vt in vTemp_Chiller_vals]
end

function build_rtes_model(; max_charge_power = nothing)
    T, Z = 3, 1
    UTES_Indices = [1]

    inputs = Dict(
        "T"                        => T,
        "Z"                        => Z,
        "UTES"                     => UTES_Indices,
        "RESOURCES"                => [make_resource()],
        "pD_Computing"             => fill(Q_VAL, T, Z),
        "pAmbientTemp"             => fill(20.0, Z, T),
        "hours_per_subperiod"      => T,
        "REP_PERIOD"               => 1,
        "START_SUBPERIODS"         => [1],
        "INTERIOR_SUBPERIODS"      => [2, 3],
        "STOR_UTES_SHORT_DURATION" => UTES_Indices,
        "STOR_UTES_LONG_DURATION"  => Int[],
        "utes_dict"                => Dict{Any, Any}(),
        "MaxChargePower"           => max_charge_power,
    )
    setup = Dict("CapacityReserveMargin" => 0, "HourlyMatching" => 0)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @expression(model, eThermalPower_UTES_Reservoir[y in UTES_Indices, t = 1:T],
        RESERVOIR_VALS[t])
    @expression(model, eMassFlow_Sec_Loop[y in UTES_Indices, t = 1:T], M_SL)
    @expression(model, eThermalPower_DC_Data_Center[y in UTES_Indices, t = 1:T], Q_VAL)
    @expression(model, eThermalPower_Chiller_Data_Center[y in UTES_Indices, t = 1:T], 0.0)
    @variable(model, eTotalCap_UTES[y in UTES_Indices, c = 1:4] >= 0)
    for c in 1:4; fix(eTotalCap_UTES[1, c], 15.0; force=true); end
    @expression(model, ePowerBalance[t = 1:T, z = 1:Z], 0.0)

    GenX.rtes!(model, inputs, setup)
    @objective(model, Min, sum(model[:vSOC_RTES]))
    optimize!(model)
    return model
end

# ------------------------------------------------------------------
@testset "RTES SOC dynamics (no MaxChargePower)" begin
    model = build_rtes_model()

    @test termination_status(model) == MOI.OPTIMAL
    @test !haskey(model, :cRTES_MaxChargePower)

    # SOC trajectory: charge +2 at t=1, neutral at t=2, discharge -2 at t=3.
    # Periodic + SOC>=0 gives SOC = [2, 2, 0] when minimising total SOC.
    vSOC = model[:vSOC_RTES]
    @test value(vSOC[1, 1]) ≈ 2.0 atol=1e-6
    @test value(vSOC[1, 2]) ≈ 2.0 atol=1e-6
    @test value(vSOC[1, 3]) ≈ 0.0 atol=1e-6
end

# ------------------------------------------------------------------
@testset "RTES cRTES_MaxChargePower — non-binding cap" begin
    # cap = 3.0 > RESERVOIR_VALS[1] = 2.0 -> constraint is not binding
    model = build_rtes_model(max_charge_power = Dict(1 => fill(3.0, 3)))

    @test termination_status(model) == MOI.OPTIMAL
    @test haskey(model, :cRTES_MaxChargePower)

    vSOC = model[:vSOC_RTES]
    @test value(vSOC[1, 1]) ≈ 2.0 atol=1e-6
    @test value(vSOC[1, 3]) ≈ 0.0 atol=1e-6
end

@testset "RTES cRTES_MaxChargePower — binding cap makes model infeasible" begin
    # cap = 1.5 < RESERVOIR_VALS[1] = 2.0.
    # eThermalPower_UTES_Reservoir is mocked as a fixed constant (+2.0 at t=1),
    # so the constraint 2.0 <= 1.5 is directly infeasible.
    model = build_rtes_model(max_charge_power = Dict(1 => fill(1.5, 3)))

    @test termination_status(model) == MOI.INFEASIBLE
end

# ------------------------------------------------------------------
@testset "load_utes_charge_capacity! — file absent" begin
    tmp    = mktempdir()
    inputs = Dict("UTES" => [1], "RESOURCES" => [make_resource()],
                  "T" => 2, "pAmbientTemp" => fill(15.0, 1, 2))
    GenX.load_utes_charge_capacity!(Dict("CoolingDemand" => 1), tmp, inputs)
    @test inputs["MaxChargePower"] === nothing
    rm(tmp, recursive=true)
end

@testset "load_utes_charge_capacity! — missing column" begin
    tmp = mktempdir()
    CSV.write(joinpath(tmp, "UTES_charge_capacity.csv"),
              DataFrame(Resource=["A"], Deg_Celsius=[0.0]))   # no MWth column
    inputs = Dict("UTES" => [1], "RESOURCES" => [make_resource()],
                  "T" => 1, "pAmbientTemp" => fill(15.0, 1, 1))
    @test_throws ErrorException GenX.load_utes_charge_capacity!(
        Dict("CoolingDemand" => 1), tmp, inputs)
    rm(tmp, recursive=true)
end

@testset "load_utes_charge_capacity! — negative MWth" begin
    tmp = mktempdir()
    CSV.write(joinpath(tmp, "UTES_charge_capacity.csv"),
              DataFrame(Resource=["VA_UTES"], Deg_Celsius=[10.0], MWth=[-5.0]))
    inputs = Dict("UTES" => [1], "RESOURCES" => [make_resource()],
                  "T" => 1, "pAmbientTemp" => fill(10.0, 1, 1))
    @test_throws ErrorException GenX.load_utes_charge_capacity!(
        Dict("CoolingDemand" => 1), tmp, inputs)
    rm(tmp, recursive=true)
end

end  # module
