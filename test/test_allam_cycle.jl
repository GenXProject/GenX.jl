module TestAllamCycle

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 1.223930169687326e10
test_path = "allam_cycle_lox"

# Define test inputs
genx_setup = Dict("Trans_Loss_Segments" => 1,
    "UCommit" => 2,
    "StorageLosses" => 1,
    "CO2Cap" => 1
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
## Test the objective value
test_result = @test obj_test≈obj_true atol=optimal_tol

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestAllamCycle
