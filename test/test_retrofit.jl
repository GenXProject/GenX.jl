module TestRetrofit

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 3179.6244
test_path = "retrofit"

# Define test inputs
genx_setup = Dict(
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 1,
    "MaxCapReq" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2,
    "EnergyShareRequirement" => 1,
    "CapacityReserveMargin" => 1,
    "MultiStage" => 0,
)

# Run the case and get the objective value and tolerance
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value(EP)
optimal_tol_rel = get_attribute(EP, "ipm_optimality_tolerance")
optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

# Test the objective value
test_result = @test obj_test ≈ obj_true atol = optimal_tol

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

# Test the outputs
outputs_path = joinpath(test_path, "results")
# Remove result folder if it exists
isdir(outputs_path) && rm(outputs_path, recursive = true)
# Write outputs
!(isdir(outputs_path)) && mkpath(outputs_path)
GenX.write_capacity(outputs_path, inputs, genx_setup, EP)

@test cmp_csv(joinpath(outputs_path, "capacity.csv"), joinpath(test_path, "results_true","capacity.csv"))

end # module TestRetrofit
