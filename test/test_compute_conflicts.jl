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

m = genxoutput[1]

# This case is constructed to be infeasible, so the model should NOT have a
# primal solution. Exercise the branches of solve_model():
#   - if the model has values, that is wrong for an infeasible case -> fail.
#   - otherwise, re-run conflict computation: solvers that do not support it
#     throw a JuMP.ArgumentError (solve_model returns 2 outputs), while solvers
#     that do support it return the conflicting-constraint vector (3 outputs).
if has_values(m)
    @warn "compute_conflicts: model returned a primal solution but was " *
          "expected to be infeasible."
    test_result = @test !has_values(m)
    write_testlog(test_path,
        "Expected an infeasible point, but the model has values",
        test_result)
else
    try
        compute_conflict!(m)
        # Conflict computation supported -> solve_model returns (EP, time, conflicts)
        test_result = @test length(genxoutput) == 3
        write_testlog(test_path,
            "Infeasible model handled; conflicts computed (3 outputs)",
            test_result)
    catch e
        if isa(e, JuMP.ArgumentError)
            # Conflict computation unsupported -> solve_model returns (EP, time)
            test_result = @test length(genxoutput) == 2
            write_testlog(test_path,
                "Infeasible model handled; conflicts unsupported (2 outputs)",
                test_result)
        else
            rethrow(e)
        end
    end
end

end
