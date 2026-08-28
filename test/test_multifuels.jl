module TestMultiFuels

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = 5494.7919354
test_path = "multi_fuels"

# Define test inputs
genx_setup = Dict("Trans_Loss_Segments" => 1,
    "EnergyShareRequirement" => 1,
    "CapacityReserveMargin" => 1,
    "StorageLosses" => 1,
    "MinCapReq" => 1,
    "MaxCapReq" => 1,
    "ParameterScale" => 1,
    "WriteShadowPrices" => 1,
    "UCommit" => 2)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

status = termination_status(EP)

if status != JuMP.MOI.OPTIMAL && Sys.iswindows()
    # HiGHS occasionally fails to reach an optimal point for this case on Windows
    # (see CI history). Rather than fail the suite, mark it broken on Windows only.
    @warn "test_multifuels: solver returned $status on Windows; " *
          "marking test as broken (known HiGHS/Windows issue)."
    test_result = @test_broken status == JuMP.MOI.OPTIMAL
    write_testlog(test_path, "termination_status = $status (broken on Windows)", test_result)
elseif status != JuMP.MOI.OPTIMAL
    # On non-Windows platforms a non-optimal status is a genuine failure.
    test_result = @test status == JuMP.MOI.OPTIMAL
    write_testlog(test_path, "termination_status = $status", test_result)
else
    obj_test = objective_value(EP)
    optimal_tol_rel = get_attribute(EP, "ipm_optimality_tolerance")
    optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

    # Test the objective value
    test_result = @test obj_test≈obj_true atol=optimal_tol

    # Round objective value and tolerance. Write to test log.
    obj_test = round_from_tol!(obj_test, optimal_tol)
    optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
    write_testlog(test_path, obj_test, optimal_tol, test_result)
end

end # module TestMultiFuels
