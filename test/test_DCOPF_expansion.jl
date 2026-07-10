module TestDCOPFExpansion

using Test

include(joinpath(@__DIR__, "utilities.jl"))

# Reduced (24-hour) IEEE 9-bus DC-OPF case with integer transmission expansion.
# Reference objective captured from a HiGHS solve at mip_rel_gap = 1e-6.
obj_true = 554906.257731
test_path = joinpath(@__DIR__, "DCOPF_expansion")

# Define test inputs: DC-OPF + network expansion + discrete (integer) line builds.
genx_setup = Dict("DC_OPF" => 1,
    "NetworkExpansion" => 1,
    "IntegerInvestments" => 1,
    "Trans_Loss_Segments" => 0,
    "StorageLosses" => 0)

# Run the case
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value(EP)

# This is a MILP (binary transmission builds), so the solver's interior-point tolerance does not
# bound the objective gap. Use a fixed relative tolerance comfortably above the MIP gap (1e-6).
optimal_tol = 1.0e-3 * abs(obj_true)

# Test the objective value
test_result = @test obj_test≈obj_true atol=optimal_tol

# Confirm the integer network-expansion path was actually exercised: the model solved to optimality
# and at least one discrete candidate line was built (with a non-zero expansion cost).
@test termination_status(EP) == JuMP.MOI.OPTIMAL
@test sum(round.(Int, value.(EP[:vNEW_TRANS_LINES]))) >= 1
@test value(EP[:eTotalCNetworkExp]) > 0

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

end # module TestDCOPFExpansion
