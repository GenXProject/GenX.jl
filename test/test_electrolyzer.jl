module TestElectrolyzer

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 34275.8599
test_path = "electrolyzer"

# Define test inputs
genx_setup = Dict("Trans_Loss_Segments" => 1,
    "UCommit" => 2,
    "StorageLosses" => 1,
    "HourlyMatching" => 1,
    "HydrogenHourlyMatching" => 1,
    "HydrogenMinimumProduction" => 1
)
settings = GenX.default_settings()
merge!(settings, genx_setup)

# Read in generator/resource related inputs
inputs = @warn_error_logger GenX.load_inputs(settings, test_path)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

obj_test = objective_value(EP)
optimal_tol_rel = get_attribute(EP, "ipm_optimality_tolerance")
optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

# Test all the results
## Test loading functions and api for hourly matching constraint
@test GenX.qualified_supply.(inputs["RESOURCES"], tag = 1) == [0, 1, 0, 0, 1, 0]
@test inputs["QUALIFIED_SUPPLY"] == [2, 5]

## Test the objective value
test_result = @test obj_test≈obj_true atol=optimal_tol

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestElectrolyzer
