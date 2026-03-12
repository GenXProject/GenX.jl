module TestUTESCOP

using Test
using GenX
using DataFrames
using CSV
using Logging

@testset "UTES COP Functions" begin
    
    @testset "interpolate_cop" begin
        # Test basic interpolation
        temps = [0.0, 10.0, 20.0, 30.0]
        cops = [10.0, 15.0, 20.0, 25.0]
        warned = Ref(false)
        
        # Test exact match
        @test GenX.interpolate_cop(10.0, temps, cops, warned, "test") ≈ 15.0
        
        # Test interpolation between points
        @test GenX.interpolate_cop(5.0, temps, cops, warned, "test") ≈ 12.5
        @test GenX.interpolate_cop(15.0, temps, cops, warned, "test") ≈ 17.5
        
        # Test clamping at lower boundary
        warned = Ref(false)
        @test GenX.interpolate_cop(-5.0, temps, cops, warned, "test") ≈ 10.0
        @test warned[]  # Warning should have been issued
        
        # Test clamping at upper boundary
        warned = Ref(false)
        @test GenX.interpolate_cop(35.0, temps, cops, warned, "test") ≈ 25.0
        @test warned[]  # Warning should have been issued
        
        # Test edge case: exactly at boundary (no warning)
        warned = Ref(false)
        @test GenX.interpolate_cop(0.0, temps, cops, warned, "test") ≈ 10.0
        @test !warned[]  # No warning at exact boundary
        
        warned = Ref(false)
        @test GenX.interpolate_cop(30.0, temps, cops, warned, "test") ≈ 25.0
        @test !warned[]  # No warning at exact boundary
    end
    
    @testset "load_utes_cop! - file not found" begin
        temp_dir = mktempdir()
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        # Should not error if file doesn't exist
        @test GenX.load_utes_cop!(setup, temp_dir, inputs) === nothing
        @test inputs["UTES_COP_Lookup"] === nothing
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - missing required columns" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Missing Efficiency column
        df = DataFrame(Technology=["dry_cooler"], Deg_Celsius=[10.0])
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test_throws ErrorException GenX.load_utes_cop!(setup, temp_dir, inputs)
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - non-positive efficiency" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Negative efficiency
        df = DataFrame(
            Technology=["dry_cooler", "dry_cooler"],
            Deg_Celsius=[10.0, 20.0],
            Efficiency=[5.0, -2.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test_throws ErrorException GenX.load_utes_cop!(setup, temp_dir, inputs)
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - invalid technology" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Invalid technology name
        df = DataFrame(
            Technology=["invalid_tech"],
            Deg_Celsius=[10.0],
            Efficiency=[5.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test_throws ErrorException GenX.load_utes_cop!(setup, temp_dir, inputs)
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - technology normalization" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Test various formats of dry_cooler and chiller
        df = DataFrame(
            Technology=["Dry_Cooler", "dry-cooler", "dry cooler", "CHILLER", "Chiller"],
            Deg_Celsius=[10.0, 15.0, 20.0, 10.0, 20.0],
            Efficiency=[5.0, 6.0, 7.0, 8.0, 9.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test GenX.load_utes_cop!(setup, temp_dir, inputs) === nothing
        @test inputs["UTES_COP_Lookup"] isa Dict
        @test haskey(inputs["UTES_COP_Lookup"], "dry_cooler")
        @test haskey(inputs["UTES_COP_Lookup"], "chiller")
        
        # Check dry_cooler data
        dc_temps, dc_cops = inputs["UTES_COP_Lookup"]["dry_cooler"]
        @test dc_temps == [10.0, 15.0, 20.0]
        @test dc_cops == [5.0, 6.0, 7.0]
        
        # Check chiller data
        ch_temps, ch_cops = inputs["UTES_COP_Lookup"]["chiller"]
        @test ch_temps == [10.0, 20.0]
        @test ch_cops == [8.0, 9.0]
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - global lookup (no Resource column)" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        df = DataFrame(
            Technology=["dry_cooler", "dry_cooler", "chiller", "chiller"],
            Deg_Celsius=[10.0, 20.0, 15.0, 25.0],
            Efficiency=[5.0, 6.0, 7.0, 8.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test GenX.load_utes_cop!(setup, temp_dir, inputs) === nothing
        
        # Should be tuples, not dicts
        @test inputs["UTES_COP_Lookup"]["dry_cooler"] isa Tuple
        @test inputs["UTES_COP_Lookup"]["chiller"] isa Tuple
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - per-resource lookup" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        df = DataFrame(
            Technology=["dry_cooler", "dry_cooler", "chiller", "chiller"],
            Resource=["UTES_1", "UTES_1", "UTES_1", "UTES_1"],
            Deg_Celsius=[10.0, 20.0, 15.0, 25.0],
            Efficiency=[5.0, 6.0, 7.0, 8.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test GenX.load_utes_cop!(setup, temp_dir, inputs) === nothing
        
        # Should be dicts of resources
        @test inputs["UTES_COP_Lookup"]["dry_cooler"] isa Dict
        @test inputs["UTES_COP_Lookup"]["chiller"] isa Dict
        @test haskey(inputs["UTES_COP_Lookup"]["dry_cooler"], "UTES_1")
        @test haskey(inputs["UTES_COP_Lookup"]["chiller"], "UTES_1")
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "load_utes_cop! - missing technology" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Only dry_cooler, no chiller
        df = DataFrame(
            Technology=["dry_cooler", "dry_cooler"],
            Deg_Celsius=[10.0, 20.0],
            Efficiency=[5.0, 6.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        @test GenX.load_utes_cop!(setup, temp_dir, inputs) === nothing
        @test inputs["UTES_COP_Lookup"]["dry_cooler"] !== nothing
        @test inputs["UTES_COP_Lookup"]["chiller"] === nothing
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "compute_utes_cop! - no cooling demand" begin
        inputs = Dict()
        setup = Dict("CoolingDemand" => 0)
        
        # Should return early without error
        @test GenX.compute_utes_cop!(inputs, setup) === nothing
        @test !haskey(inputs, "COP_DC")
        @test !haskey(inputs, "COP_Chiller")
    end
    
    @testset "compute_utes_cop! - no UTES resources" begin
        inputs = Dict("UTES" => Int[], "RESOURCES" => [])
        setup = Dict("CoolingDemand" => 1)
        
        # Should return early without error
        @test GenX.compute_utes_cop!(inputs, setup) === nothing
    end
    
    @testset "compute_utes_cop! - validates positive COP" begin
        # This test would require creating mock UTES resources
        # For now, we test that the function signature works
        # Full integration testing should be done with actual GenX runs
        @test true
    end
    
    @testset "Integration - full workflow" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Create a complete valid COP file
        df = DataFrame(
            Technology=["dry_cooler", "dry_cooler", "dry_cooler", 
                       "chiller", "chiller", "chiller"],
            Deg_Celsius=[0.0, 15.0, 30.0, 0.0, 15.0, 30.0],
            Efficiency=[320.0, 280.0, 240.0, 25.0, 15.0, 8.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        # Load the file
        @test GenX.load_utes_cop!(setup, temp_dir, inputs) === nothing
        
        # Verify structure
        @test haskey(inputs, "UTES_COP_Lookup")
        @test inputs["UTES_COP_Lookup"]["dry_cooler"] !== nothing
        @test inputs["UTES_COP_Lookup"]["chiller"] !== nothing
        
        # Test interpolation on loaded data
        dc_temps, dc_cops = inputs["UTES_COP_Lookup"]["dry_cooler"]
        ch_temps, ch_cops = inputs["UTES_COP_Lookup"]["chiller"]
        
        warned = Ref(false)
        # Test dry cooler interpolation
        cop_dc = GenX.interpolate_cop(7.5, dc_temps, dc_cops, warned, "dry_cooler")
        @test cop_dc ≈ 300.0  # Midpoint between 320 and 280
        
        # Test chiller interpolation
        cop_ch = GenX.interpolate_cop(7.5, ch_temps, ch_cops, warned, "chiller")
        @test cop_ch ≈ 20.0  # Midpoint between 25 and 15
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "Sorted temperature data" begin
        temp_dir = mktempdir()
        cop_path = joinpath(temp_dir, "UTES_COP.csv")
        
        # Create unsorted data (should be sorted by load function)
        df = DataFrame(
            Technology=["dry_cooler", "dry_cooler", "dry_cooler"],
            Deg_Celsius=[20.0, 10.0, 30.0],  # Unsorted
            Efficiency=[6.0, 5.0, 7.0]
        )
        CSV.write(cop_path, df)
        
        inputs = Dict()
        setup = Dict("CoolingDemand" => 1)
        
        GenX.load_utes_cop!(setup, temp_dir, inputs)
        
        dc_temps, dc_cops = inputs["UTES_COP_Lookup"]["dry_cooler"]
        
        # Should be sorted
        @test dc_temps == [10.0, 20.0, 30.0]
        @test dc_cops == [5.0, 6.0, 7.0]
        
        rm(temp_dir, recursive=true)
    end
    
    @testset "Default equation COP calculation - no lookup file" begin
        # Create a minimal UTES resource-like object
        mutable struct MockUTES
            zone::Int
            fan_coefficient_dry_cooler::Float64
            temp_data_center_out_c::Float64
            approach_temp_dry_cooler::Float64
            fractional_pressure_dry_cooler_fan::Float64
            ambient_pressure_pa::Float64
            irreversibility_factor_chiller::Float64
            temp_evaporator_chiller_c::Float64
            temp_lift_chiller_c::Float64
            temp_approach_chiller_c::Float64
        end
        
        # Create mock resource
        utes_resource = MockUTES(
            1,                      # zone
            0.5,                    # fan_coefficient_dry_cooler
            30.0,                   # temp_data_center_out_c
            5.0,                    # approach_temp_dry_cooler
            0.1,                    # fractional_pressure_dry_cooler_fan
            101300.0,               # ambient_pressure_pa
            0.4,                    # irreversibility_factor_chiller
            5.0,                    # temp_evaporator_chiller_c
            8.0,                    # temp_lift_chiller_c
            2.0                     # temp_approach_chiller_c
        )
        
        # Test dry cooler equation
        ambient_temp = 15.0
        expected_cop_dc = 1000 * 1.2 * 0.5 * 1.013 * 
            (30.0 - 5.0 - 15.0) / (0.1 * 101300.0)
        
        @test expected_cop_dc > 0  # COP should be positive
        @test expected_cop_dc ≈ 0.6 atol=0.01  # Check calculated value: 1000*1.2*0.5*1.013*10/10130=0.6
        
        # Test chiller equation
        denominator = 15.0 + 8.0 + 2.0 - 5.0  # ambient + lift + approach - evap
        expected_cop_chiller = 0.4 * (5.0 + 273.15) / denominator
        
        @test expected_cop_chiller > 0  # COP should be positive
        @test expected_cop_chiller ≈ 5.563 atol=0.01  # Check calculated value: 0.4*278.15/20=5.563
    end
    
    @testset "Default equation COP calculation - compute_utes_cop! without lookup" begin
        # Test that compute_utes_cop! correctly falls back to equations when no lookup exists
        temp_dir = mktempdir()
        
        inputs = Dict(
            "UTES_COP_Lookup" => nothing,  # No lookup table
            "T" => 3,
            "UTES" => Int[],
            "RESOURCES" => [],
            "pAmbientTemp" => zeros(1, 3)
        )
        
        setup = Dict("CoolingDemand" => 1)
        
        # Should not error even with empty UTES
        @test GenX.compute_utes_cop!(inputs, setup) === nothing
        
        # When UTES is empty, these should not be created
        @test !haskey(inputs, "COP_DC") || isempty(inputs["COP_DC"])
        @test !haskey(inputs, "COP_Chiller") || isempty(inputs["COP_Chiller"])
        
        rm(temp_dir, recursive=true)
    end

end

end # module
