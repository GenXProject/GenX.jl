module TestChillerModel

using Test
using GenX
using JuMP
using DataFrames
using HiGHS
import MathOptInterface as MOI

# Subtype AbstractResource to play nice with GenX internals
struct MockUTESResource <: GenX.AbstractResource
    data::Dict{Symbol, Any}
end

# Implement Base.parent so GenX.AbstractResource getproperty works
Base.parent(r::MockUTESResource) = getfield(r, :data)

@testset "Chiller External COP Logic" begin
    # Defines
    T = 3
    Z = 1
    UTES_Indices = [1]
    
    # Mock resources
    # We use a Dict to back the resource, matching GenX internal structure expectations
    # And we need to make sure :id and :zone keys are present for resource_id and zone_id checks.
    r_data = Dict{Symbol, Any}(
        :id => 1,
        :zone => 1,
        :chiller_pump_load_mw => 0.5,
        :fractional_pressure_chiller_fan => 0.1,
        :ambient_pressure_pa => 101325.0,
        :temp_lift_chiller_c => 10.0,
        :fan_coefficient_chiller => 0.05,
        :thermal_capacity_second_loop => 1.0,
        :max_working_fluid_temp_second_loop => 85.0,
        :min_working_fluid_temp_second_loop => 5.0
    )
    
    r = MockUTESResource(r_data)
    gen = [r]
    
    # Inputs
    inputs = Dict()
    inputs["T"] = T
    inputs["Z"] = Z
    inputs["UTES"] = UTES_Indices
    inputs["RESOURCES"] = gen
    
    # Mock dD_computing (Q)
    inputs["pD_Computing"] = fill(10.0, T, Z)
    inputs["pAmbientTemp"] = rand(T) .+ 20.0
    
    # Mock COPs
    copter = [5.0, 5.0, 5.0] 
    dc_cop = [2.0, 2.0, 2.0] 
    
    inputs["COP_Chiller"] = Dict(1 => copter)
    inputs["COP_Chiller_Data_Center"] = Dict(1 => copter)
    inputs["COP_Chiller_Reservoir"] = Dict(1 => copter)
    inputs["COP_DC"] = Dict(1 => dc_cop)
    
    # CRITICAL: External COP Setup
    # Presence of this key triggers the logic
    # The code checks `cop_lookup["chiller"] !== nothing`.
    inputs["UTES_COP_Lookup"] = Dict("chiller" => Dict(1 => [10.0, 10.0, 10.0])) 
    
    # Setup dict
    setup = Dict()
    setup["CapacityReserveMargin"] = 0
    setup["HourlyMatching"] = 0
    setup["MultiStage"] = 0 
    
    # Model Setup
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    
    # Mock variables/expressions required by chiller!
    @variable(model, vTemp_Chiller[y in UTES_Indices, t=1:T])
    @variable(model, vTemp_DC[y in UTES_Indices, t=1:T])
    
    @expression(model, eMassFlow_Sec_Loop[y in UTES_Indices, t=1:T], 10.0)
    @expression(model, eThermalPower_UTES_Reservoir[y in UTES_Indices, t=1:T], 1.5)
    @variable(model, eTotalCap_UTES[y in UTES_Indices, c=1:4] >= 0)
    
    # ePowerBalance
    @expression(model, ePowerBalance[t=1:T, z=1:Z], 0.0)

    for t in 1:T
        fix(vTemp_DC[1, t], 20.0; force=true)
        fix(vTemp_Chiller[1, t], 18.85; force=true)
        for c in 1:4
            fix(eTotalCap_UTES[1, c], 100.0; force=true)
        end
    end
    
    # Call the function being tested
    GenX.chiller!(model, inputs, setup)

    @objective(model, Min, 0)
    optimize!(model)

    @test termination_status(model) == MOI.OPTIMAL
    
    # Verify logic
    
    eCOP = model[:eCOP_Chiller]
    eCOP_plus = model[:eCOP_Chiller_plus_Pump]
    eCOP_plus_data_center = model[:eCOP_Chiller_plus_Pump_Data_Center]
    eCOP_plus_reservoir = model[:eCOP_Chiller_plus_Pump_Reservoir]
    eFan = model[:eElec_Chiller_Fan]
    eThermalTotal = model[:eThermalPower_Chiller_Total]
    eThermalDirect = model[:eThermalPower_Chiller_Data_Center]
    eThermalReservoir = model[:eThermalPower_Chiller_Reservoir]
    eElec_data_center = model[:eElec_Chiller_Data_Center]
    eElec_reservoir = model[:eElec_Chiller_Reservoir]
    
    for t in 1:T
        idx = (1, t)
        
        cop_val = inputs["COP_Chiller"][1][t]
        
        # Check if values match
        @test eCOP[idx...] == cop_val
        @test eCOP_plus[idx...] == cop_val
        @test eCOP_plus_data_center[idx...] == cop_val
        @test eCOP_plus_reservoir[idx...] == cop_val
        @test eFan[idx...] == 0
        @test value(eThermalTotal[idx...]) ≈ 11.5 atol=1e-8
        @test value(eThermalDirect[idx...]) ≈ 10.0 atol=1e-8
        @test value(eThermalReservoir[idx...]) ≈ 1.5 atol=1e-8
        @test value(eElec_data_center[idx...]) ≈ 2.0 atol=1e-8
        @test value(eElec_reservoir[idx...]) ≈ 0.3 atol=1e-8
    end
end

end
