module TestExamples

using Test
using GenX

include(joinpath(@__DIR__, "utilities.jl"))

# Test that the examples in the example_systems directory run without error
function test_examples()
    base_path = Base.dirname(Base.dirname(pathof(GenX)))
    examples_path = joinpath(base_path, "example_systems")

    examples_dir = readdir(examples_path, join = true)
    for example_dir in examples_dir
        if isdir(example_dir) && isfile(joinpath(example_dir, "Run.jl"))
            @info "Running example in $example_dir"
            result = @warn_error_logger run_genx_case!(example_dir)
            @test isnothing(result)
        end
    end
end

@testset "Test examples" begin
    test_examples()
end

end # module
