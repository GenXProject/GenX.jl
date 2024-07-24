module TestVREStor

using Test
include(joinpath(@__DIR__, "utilities.jl"))

function test_case(test_path, obj_true, genx_setup)
    # Run the case and get the objective value and tolerance
    EP, _, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end
    obj_test = objective_value(EP)
    optimal_tol_rel = get_attribute(EP, "dual_feasibility_tolerance")
    optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

    # Test the objective value
    test_result = @test obj_test≈obj_true atol=optimal_tol

    # Round objective value and tolerance. Write to test log.
    obj_test = round_from_tol!(obj_test, optimal_tol)
    optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
    write_testlog(test_path, obj_test, optimal_tol, test_result)

    return nothing
end

# Test cases (format: (test_path, obj_true))
test_cases = [("VRE_storage/solar_wind", 92376.060123),
    ("VRE_storage/solar", 106798.88706),
    ("VRE_storage/wind", 92376.275543)]

# Define test setup
genx_setup = Dict("NetworkExpansion" => 1,
    "UCommit" => 2,
    "CapacityReserveMargin" => 1,
    "MinCapReq" => 1,
    "MaxCapReq" => 1,
    "CO2Cap" => 1,
    "StorageLosses" => 1,
    "VirtualChargeDischargeCost" => 1,
    "ParameterScale" => 1)

# Run test cases
for (test_path, obj_true) in test_cases
    test_case(test_path, obj_true, genx_setup)
end

end # module TestVREStor
