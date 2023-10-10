module TestThreeZones

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 6.9602085499e+03
test_path = "ThreeZones"

# Define test inputs
genx_setup = Dict(
    "OverwriteResults" => 0,
    "PrintModel" => 0,
    "NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "Reserves" => 0,
    "EnergyShareRequirement" => 0,
    "CapacityReserveMargin" => 0,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 1 ,
    "MaxCapReq" => 0 ,
    "Solver" => "HiGHS",
    "ParameterScale" => 1,
    "WriteShadowPrices" => 1,
    "UCommit" => 2,
    "TimeDomainReductionFolder" => "TDR_Results",
    "TimeDomainReduction" => 0,
    "ModelingToGenerateAlternatives" => 0,
    "ModelingtoGenerateAlternativeSlack" => 0.1,
    "ModelingToGenerateAlternativeIterations" => 3,
    "MultiStage" => 0,
    "MethodofMorris" => 0,
    "EnableJuMPStringNames" => false,
    "IncludeLossesInESR" => 0,
)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    solve_genx_model_testing(genx_setup, test_path)
end

obj_test = objective_value(EP)
optimal_tol = get_attribute(EP, "dual_feasibility_tolerance")

# Test the objective value
test_result = @test obj_test ≈ obj_true atol=optimal_tol

# Add the results to the test log
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestThreeZones
