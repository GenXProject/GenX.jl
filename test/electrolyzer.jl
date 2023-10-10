module TestElectrolyzer

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 6.9469819126e+03
test_path = "Electrolyzer"

# Define test inputs
genx_setup = Dict(
    "Trans_Loss_Segments" => 1,
    "UCommit" => 2,
    "EnergyShareRequirement" => 0,
    "StorageLosses" => 1,
    "HydrogenHourlyMatching" => 1,
    "ParameterScale" => 1,
    "MultiStage" => 0,
    "TimeDomainReduction" => 0,
    "TimeDomainReductionFolder" => "TDR_Results",
    "WriteShadowPrices" => 1,
    "Solver" => "HiGHS",
    "EnableJuMPStringNames" => false,
    "Reserves" => 0,
    "CapacityReserveMargin" => 0,
    "MinCapReq" => 0,
    "MaxCapReq" => 0,
    "CO2Cap" => 0,
    "IncludeLossesInESR" => 0,
    "PrintModel" => 0,
)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

obj_test = objective_value(EP)
optimal_tol = get_attribute(EP, "dual_feasibility_tolerance")

# Test the objective value
test_result = @test obj_test ≈ obj_true atol=optimal_tol

# Add the results to the test log
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestElectrolyzer
