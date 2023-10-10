module TestVREStor

using Test
include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 9.2081915042e+04
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
obj_test, optimal_tol = redirect_stdout(devnull) do
    solve_genx_model_testing(genx_setup, test_path)
end

# Test the objective value
test_result = @test obj_test ≈ obj_true atol=optimal_tol

# Add the results to the test log
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestVREStor

