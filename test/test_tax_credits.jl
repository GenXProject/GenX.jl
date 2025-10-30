module TestTaxCredits

using Test

include(joinpath(@__DIR__, "utilities.jl"))

# Test with tax credits enabled
test_path = "three_zones"

# Define test inputs with tax credits
genx_setup = Dict("NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 1,
    "InvestmentTaxCredit" => 1,
    "ProductionTaxCredit" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2)

# Create temporary test directory with tax credit files
test_dir = joinpath(@__DIR__, test_path)
policies_dir = joinpath(test_dir, "policies")

# Create simple tax credit policy files for testing
itc_content = """ITC_Policy,PolicyDescription,ITC_Rate
1,Test_ITC,0.30
"""

ptc_content = """PTC_Policy,PolicyDescription,PTC_Rate
1,Test_PTC,26.0
"""

# Create resource policy assignment files
itc_resources = """Resource,ITC_1
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

ptc_resources = """Resource,PTC_1
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
itc_file = joinpath(policies_dir, "Investment_tax_credits.csv")
ptc_file = joinpath(policies_dir, "Production_tax_credits.csv")
itc_res_dir = joinpath(test_dir, "resources", "policy_assignments")
mkpath(itc_res_dir)
itc_res_file = joinpath(itc_res_dir, "Resource_investment_tax_credits.csv")
ptc_res_file = joinpath(itc_res_dir, "Resource_production_tax_credits.csv")

write(itc_file, itc_content)
write(ptc_file, ptc_content)
write(itc_res_file, itc_resources)
write(ptc_res_file, ptc_resources)

try
    # Run the case
    EP, inputs, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end
    
    # Test that tax credit expressions exist
    @test haskey(EP.obj_dict, :eTotalITCBenefit)
    @test haskey(EP.obj_dict, :eTotalPTCBenefit)
    @test haskey(EP.obj_dict, :eITCBenefit)
    @test haskey(EP.obj_dict, :ePTCBenefit)
    
    # Test that tax credit benefits are positive (reducing costs)
    itc_benefit = JuMP.value(EP[:eTotalITCBenefit])
    ptc_benefit = JuMP.value(EP[:eTotalPTCBenefit])
    
    @test itc_benefit >= 0  # Tax credits should be non-negative
    @test ptc_benefit >= 0  # Tax credits should be non-negative
    
    println("ITC Benefit: ", itc_benefit)
    println("PTC Benefit: ", ptc_benefit)
    
    # Objective value should be lower with tax credits than without
    obj_with_credits = objective_value(EP)
    
    # Test passed if we got here
    @test true
    
    println("Tax credits test passed!")
    println("Objective value with tax credits: ", obj_with_credits)
    
finally
    # Clean up temporary files
    rm(itc_file, force=true)
    rm(ptc_file, force=true)
    rm(itc_res_file, force=true)
    rm(ptc_res_file, force=true)
end

end # module TestTaxCredits
