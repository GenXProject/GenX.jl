module TestConflicts

using Test

include(joinpath(@__DIR__, "utilities.jl"))
test_path = joinpath(@__DIR__, "compute_conflicts")

# Define test inputs
genx_setup = Dict{Any, Any}("Trans_Loss_Segments" => 1,
    "CO2Cap" => 1,
    "StorageLosses" => 1,
    "MaxCapReq" => 1,
    "ComputeConflicts" => 1)

genxoutput = redirect_stdout(devnull) do
    run_genx_case_conflict_testing(test_path, genx_setup)
end

test_result = @test length(genxoutput) == 2
write_testlog(test_path,
    "Testing that the infeasible model is correctly handled",
    test_result)

end
