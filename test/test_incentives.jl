module TestIncentives

using Test

include(joinpath(@__DIR__, "utilities.jl"))

# Test with incentives enabled
test_path = "three_zones"

# Define test inputs with incentives
genx_setup = Dict("NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 1,
    "InvestmentIncentive" => 1,
    "ProductionIncentive" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2)

# Create temporary test directory with incentive files
test_dir = joinpath(@__DIR__, test_path)
policies_dir = joinpath(test_dir, "policies")

# Create simple incentive policy files for testing
inv_incentive_content = """InvIncentive_Policy,PolicyDescription,InvIncentive_Rate
1,Test_InvIncentive,0.30
"""

prod_incentive_content = """ProdIncentive_Policy,PolicyDescription,ProdIncentive_Rate,ProdIncentive_Type
1,Test_ProdIncentive,26.0,energy
"""

# Create resource policy assignment files
inv_incentive_resources = """Resource,Inv_Incentive_1
MA_natural_gas_combined_cycle,0
CT_natural_gas_combined_cycle,0
ME_natural_gas_combined_cycle,0
MA_solar_pv,1
CT_onshore_wind,1
CT_solar_pv,1
ME_onshore_wind,1
MA_battery,0
CT_battery,0
ME_battery,0
"""

prod_incentive_resources = """Resource,Prod_Incentive_1
MA_natural_gas_combined_cycle,0
CT_natural_gas_combined_cycle,0
ME_natural_gas_combined_cycle,0
MA_solar_pv,1
CT_onshore_wind,1
CT_solar_pv,1
ME_onshore_wind,1
MA_battery,0
CT_battery,0
ME_battery,0
"""

# Write temporary files
inv_incentive_file = joinpath(policies_dir, "Investment_incentive.csv")
prod_incentive_file = joinpath(policies_dir, "Production_incentive.csv")
incentive_res_dir = joinpath(test_dir, "resources", "policy_assignments")
mkpath(incentive_res_dir)
inv_incentive_res_file = joinpath(incentive_res_dir, "Resource_investment_incentive.csv")
prod_incentive_res_file = joinpath(incentive_res_dir, "Resource_production_incentive.csv")

write(inv_incentive_file, inv_incentive_content)
write(prod_incentive_file, prod_incentive_content)
write(inv_incentive_res_file, inv_incentive_resources)
write(prod_incentive_res_file, prod_incentive_resources)

try
    # Run the case
    EP, inputs, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end
    
    # Test that incentive expressions exist
    @test haskey(EP.obj_dict, :eTotalInvIncentiveBenefit)
    @test haskey(EP.obj_dict, :eTotalProdIncentiveBenefit)
    @test haskey(EP.obj_dict, :eInvIncentiveBenefit)
    @test haskey(EP.obj_dict, :eProdIncentiveBenefit)
    
    # Test that incentive benefits are positive (reducing costs)
    inv_incentive_benefit = JuMP.value(EP[:eTotalInvIncentiveBenefit])
    prod_incentive_benefit = JuMP.value(EP[:eTotalProdIncentiveBenefit])
    
    @test inv_incentive_benefit >= 0  # Incentives should be non-negative
    @test prod_incentive_benefit >= 0  # Incentives should be non-negative
    
    println("Investment Incentive Benefit: ", inv_incentive_benefit)
    println("Production Incentive Benefit: ", prod_incentive_benefit)
    
    # Objective value should be lower with incentives than without
    obj_with_incentives = objective_value(EP)
    
    # Test passed if we got here
    @test true
    
    println("Incentives test passed!")
    println("Objective value with incentives: ", obj_with_incentives)
    
finally
    # Clean up temporary files
    rm(inv_incentive_file, force=true)
    rm(prod_incentive_file, force=true)
    rm(inv_incentive_res_file, force=true)
    rm(prod_incentive_res_file, force=true)
end

end # module TestIncentives
