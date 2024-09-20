module TestFusionNoPulse

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 300.5962608 # see fusion_pulse_every_hour/README.md
test_path = "fusion_pulse_every_hour"

# Define test inputs
genx_setup = Dict("UCommit" => 2,
    "ParameterScale" => 1,
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

## Test loading functions and api
@test GenX.ids_with(inputs["RESOURCES"], :fusion) == [1]

## Test the objective value
test_result = @test obj_test≈obj_true atol=optimal_tol

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

end
