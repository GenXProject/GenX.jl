module TestPiecewiseFuelCO2

using Test
include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 2341.82308
test_path = "PiecewiseFuel_CO2"

# Define test inputs
genx_setup = Dict(
    "Trans_Loss_Segments" => 1,
    "UCommit" => 2,
    "CO2Cap" => 1,
    "ParameterScale" => 1,
    "WriteShadowPrices" => 1,
    "Solver" => "HiGHS",
    "TimeDomainReduction" => 0,
    "TimeDomainReductionFolder" => "TDR_Results",
    "Reserves" => 0,
    "CapacityReserveMargin" => 0,
    "MinCapReq" => 0,
    "MaxCapReq" => 0,
    "EnergyShareRequirement" => 0,
    "EnableJuMPStringNames" => false,
    "MultiStage" => 0,
    "PrintModel" => 0,
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

end # module TestPiecewiseFuelCO2

