module TestVREStor

using Test
include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 92081.91504
test_path = "VREStor"

# Define test inputs
genx_setup = Dict(
    "NetworkExpansion" => 1,
    "TimeDomainReduction" => 0,
    "TimeDomainReductionFolder" => "TDR_Results",
    "MultiStage" => 0,
    "UCommit" => 2,
    "CapacityReserveMargin" => 1,
    "Reserves" => 0,
    "MinCapReq" => 1,
    "MaxCapReq" => 1,
    "EnergyShareRequirement" => 0,
    "CO2Cap" => 1,
    "StorageLosses" => 1,
    "PrintModel" => 0,
    "ModelingToGenerateAlternativeIterations" => 3,
    "ParameterScale" => 1,
    "Trans_Loss_Segments" => 1,
    "CapacityReserveMargin" => 1,
    "ModelingtoGenerateAlternativeSlack: 0" =>1,
    "Solver" => "HiGHS",
    "ModelingToGenerateAlternatives" => 0,
    "WriteShadowPrices" => 1,
    "EnableJuMPStringNames" => false,
    "IncludeLossesInESR" => 0,
)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

obj_test = objective_value(EP)
optimal_tol = get_attribute(EP, "dual_feasibility_tolerance")

# Round the objective value to the same number of digits as the tolerance
obj_test = round_objfromtol!(obj_test, optimal_tol)

# Test the objective value
test_result = @test obj_test ≈ obj_true atol=optimal_tol

# Add the results to the test log
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestVREStor

