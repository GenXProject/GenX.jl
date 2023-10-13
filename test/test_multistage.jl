module TestMultiStage

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = [79734.80032, 41630.03494, 27855.20632]
test_path = "MultiStage"

# Define test inputs
multistage_setup = Dict(
    "NumStages" => 3 ,
    "StageLengths" => [10,10,10],
    "WACC" => 0.045,
    "ConvergenceTolerance" => 0.01,
    "Myopic" => 0,
)

genx_setup = Dict(
    "OverwriteResults" => 0,
    "PrintModel" => 0,
    "NetworkExpansion" => 0,
    "Trans_Loss_Segments" => 1,
    "Reserves" => 1,
    "EnergyShareRequirement" => 0,
    "CapacityReserveMargin" => 0,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 0,
    "MaxCapReq" => 0,
    "Solver" => "HiGHS",
    "ParameterScale" => 1,
    "WriteShadowPrices" => 1,
    "UCommit" => 2,
    "TimeDomainReductionFolder" => "TDR_Results",
    "TimeDomainReduction" => 0,
    "ModelingToGenerateAlternatives" => 0,
    "ModelingtoGenerateAlternativeSlack" => 0.1,
    "ModelingToGenerateAlternativeIterations" => 3,
    "EnableJuMPStringNames" => false,
    "IncludeLossesInESR" => 0,
    "MultiStage" => 1,
    "MultiStageSettingsDict" => multistage_setup,
)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

obj_test = objective_value.([EP[i] for i in 1:3])
optimal_tol = get_attribute.([EP[i] for i in 1:3], "dual_feasibility_tolerance")

# Round the objective value to the same number of digits as the tolerance
obj_test = round_objfromtol!.(obj_test, optimal_tol)

# Test the objective value
test_result = @test all(obj_true .- optimal_tol .<= obj_test .<= obj_true .+ optimal_tol)

# Add the results to the test log
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestMultiStage
