module TestIncentivesSystem

using Test
using GenX

include(joinpath(@__DIR__, "utilities.jl"))

# Use a compact 3-zone system with incentives enabled
obj_true = nothing  # no golden value yet; we just check solve and non-negativity

test_path = "incentives"

# Define test inputs with incentives
genx_setup = Dict(
    "NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "CO2Cap" => 0,
    "StorageLosses" => 1,
    "MinCapReq" => 0,
    "InvestmentIncentive" => 1,
    "ProductionIncentive" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2,
)

EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

# Basic checks
@test haskey(EP.obj_dict, :eTotalInvIncentiveBenefit)
@test haskey(EP.obj_dict, :eTotalProdIncentiveBenefit)
@test haskey(EP.obj_dict, :eInvIncentiveBenefit)
@test haskey(EP.obj_dict, :eProdIncentiveBenefit)

inv_incentive_benefit = JuMP.value(EP[:eTotalInvIncentiveBenefit])
prod_incentive_benefit = JuMP.value(EP[:eTotalProdIncentiveBenefit])

@test inv_incentive_benefit >= 0
@test prod_incentive_benefit >= 0

# We at least assert the model solved to optimality
@test termination_status(EP) in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)

# Test ProdIncentive_Type validation and normalization
@testset "ProdIncentive_Type Validation" begin
    # Test that input types were normalized to lowercase
    @test all(t -> t in ["mwh", "tonne_co2"], inputs["ProdIncentive_Type"])
    
    # Test case-insensitive handling by checking we have 3 policies
    @test inputs["NumberOfProdIncentive"] == 3
    
    # Test that policies 1 and 2 are MWh type (normalized from "MWh" input)
    @test inputs["ProdIncentive_Type"][1] == "mwh"
    @test inputs["ProdIncentive_Type"][2] == "mwh"
    
    # Test that policy 3 is CO2 type (normalized from "Tonne_CO2" input)
    @test inputs["ProdIncentive_Type"][3] == "tonne_co2"
end

# Test production incentive benefits calculation
@testset "Production Incentive Benefits" begin
    # Each policy should have non-negative benefit
    for i in 1:inputs["NumberOfProdIncentive"]
        benefit = JuMP.value(EP[:eProdIncentiveBenefit][i])
        @test benefit >= 0
    end
    
    # Test CO2 capture incentive calculation (policy 3)
    # Calculate expected CO2 incentive from emissions captured
    CCS = inputs["CCS"]
    if !isempty(CCS) && haskey(EP.obj_dict, :eEmissionsCaptureByPlant)
        # Get resources eligible for policy 3
        gen = inputs["RESOURCES"]
        eligible_resources = GenX.ids_with_policy(gen, :prod_incentive, tag=3)
        ccs_eligible = intersect(eligible_resources, CCS)
        
        if !isempty(ccs_eligible)
            # Calculate expected CO2 incentive
            T = inputs["T"]
            expected_co2_incentive = sum(
                inputs["omega"][t] * 
                inputs["ProdIncentive_Rate"][3] * 
                JuMP.value(EP[:eEmissionsCaptureByPlant][y, t])
                for y in ccs_eligible, t in 1:T
            )
            
            # Compare with actual benefit from policy 3
            actual_co2_incentive = JuMP.value(EP[:eProdIncentiveBenefit][3])
            @test isapprox(actual_co2_incentive, expected_co2_incentive, rtol=1e-6)
        end
    end
end

# Test output file type normalization
@testset "Output Type Normalization" begin
    # Read the production_incentive output file if it exists
    output_path = joinpath(test_path, "results", "production_incentive.csv")
    if isfile(output_path)
        using CSV, DataFrames
        df = CSV.read(output_path, DataFrame)
        
        # Check that output types are normalized to display format
        # Should be "MWh" or "Tonne_CO2", not lowercase
        for type_val in df.ProdIncentive_Type
            if type_val != "Total" && type_val != "All"  # Skip total row
                @test type_val in ["MWh", "Tonne_CO2"]
            end
        end
    end
end

# Test invalid ProdIncentive_Type value
@testset "Invalid ProdIncentive_Type" begin
    using CSV, DataFrames
    
    # Create temporary test directory with invalid type
    temp_test_path = mktempdir()
    
    # Copy necessary files from incentives test
    mkpath(joinpath(temp_test_path, "policies"))
    mkpath(joinpath(temp_test_path, "system"))
    mkpath(joinpath(temp_test_path, "resources"))
    
    # Create Production_incentive.csv with invalid type
    invalid_df = DataFrame(
        ProdIncentive_Policy = [1],
        PolicyDescription = ["Invalid_Test"],
        ProdIncentive_Rate = [10.0],
        ProdIncentive_Type = ["invalid_type"]
    )
    CSV.write(joinpath(temp_test_path, "policies", "Production_incentive.csv"), invalid_df)
    
    # Test that loading invalid type raises an error
    @test_throws ErrorException begin
        setup_test = Dict("ProductionIncentive" => 1)
        inputs_test = Dict{String, Any}()
        GenX.load_production_incentive!(joinpath(temp_test_path, "policies"), inputs_test, setup_test)
    end
    
    # Clean up
    rm(temp_test_path, recursive=true)
end

@testset "Missing ProdIncentive_Type Column" begin
    using CSV, DataFrames

    # Create temporary test directory without ProdIncentive_Type column
    temp_missing_path = mktempdir()
    mkpath(joinpath(temp_missing_path, "policies"))

    # Minimal Production_incentive.csv missing the required column
    missing_df = DataFrame(
        ProdIncentive_Policy = [1],
        PolicyDescription = ["Missing_Type_Test"],
        ProdIncentive_Rate = [5.0],
    )
    CSV.write(joinpath(temp_missing_path, "policies", "Production_incentive.csv"), missing_df)

    # Expect an error due to missing ProdIncentive_Type column
    @test_throws ErrorException begin
        setup_missing = Dict("ProductionIncentive" => 1)
        inputs_missing = Dict{String, Any}()
        GenX.load_production_incentive!(joinpath(temp_missing_path, "policies"), inputs_missing, setup_missing)
    end

    rm(temp_missing_path, recursive=true)
end

end # module
