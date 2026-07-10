module TestThreeZones

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 6960.20855
test_path = "three_zones"

# Define test inputs
genx_setup = Dict("NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "MinCapReq" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2)

# Run the case and get the objective value and tolerance
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value(EP)
optimal_tol_rel = get_attribute(EP, "ipm_optimality_tolerance")
optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

# Test the objective value
test_result = @test obj_test≈obj_true atol=optimal_tol

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

# ------------------------------------------------------------------------------------------------
# Integer generation builds
#
# Re-run the same three-zone system with IntegerInvestments = 1. The MA and CT natural gas combined
# cycle resources carry Integer_Build = 1 in Thermal.csv, so their vCAP (a count of 250 MW units,
# since they are unit-commitment resources) must be integral; the ME unit is left continuous.
# ------------------------------------------------------------------------------------------------

obj_true_int = 6960.595882

genx_setup_int = merge(copy(genx_setup), Dict("IntegerInvestments" => 1))

EP_int, inputs_int, _ = @warn_error_logger run_genx_case_testing(test_path, genx_setup_int)
obj_test_int = objective_value(EP_int)

# This is a MILP, so the interior-point tolerance does not bound the objective gap. Use a fixed
# relative tolerance comfortably above the solver's MIP gap (1e-6).
optimal_tol_int = 1.0e-3 * abs(obj_true_int)

test_result_int = @test obj_test_int≈obj_true_int atol=optimal_tol_int

@test termination_status(EP_int) == JuMP.MOI.OPTIMAL

# Only the two flagged thermal resources are integer-constrained.
@test inputs_int["NEW_CAP_INTEGER_BUILD"] == [1, 2]
@test is_integer(EP_int[:vCAP][1])
@test is_integer(EP_int[:vCAP][2])
@test !is_integer(EP_int[:vCAP][3])

# The integer path is only meaningful if those resources are actually built. Both should land on a
# strictly positive whole number of units.
for y in inputs_int["NEW_CAP_INTEGER_BUILD"]
    cap = value(EP_int[:vCAP][y])
    @test cap > 0.5
    @test isapprox(cap, round(cap), atol = 1.0e-4)
end

obj_test_int = round_from_tol!(obj_test_int, optimal_tol_int)
optimal_tol_int = round_from_tol!(optimal_tol_int, optimal_tol_int)
write_testlog(test_path, obj_test_int, optimal_tol_int, test_result_int)

end # module TestThreeZones
