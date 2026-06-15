module TestBendersOutputParity

using Test

# Check whether the Gurobi package is loadable in this environment.
const _GUROBI_AVAILABLE = !isnothing(Base.find_package("Gurobi"))

if _GUROBI_AVAILABLE
    using Gurobi
    include(joinpath(@__DIR__, "..", "scripts", "benders_output_parity_example2.jl"))

    using .BendersOutputParityExample2: run_example2_parity_validation

    @testset "Benders Output Parity (Example 2)" begin
        report = redirect_stdout(devnull) do
            run_example2_parity_validation(
                optimizer = Gurobi.Optimizer,
                benders_conv_tol = 1.0e-5,
                benders_max_cpu_time = 1800.0,
                objective_rtol = 1.0e-4,
                csv_rtol = 1.0e-4,
                csv_atol = 1.0e-3,
                keep_case_copy = false,
            )
        end

        @test report.benders_gap_ok
        @test report.objective_ok
        @test report.csvs_ok
        @test report.passed
    end
else
    @testset "Benders Output Parity (Example 2)" begin
        @test_skip "Gurobi not available - skipping Benders output parity test"
    end
end

end # module TestBendersOutputParity
