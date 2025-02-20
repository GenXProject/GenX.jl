module TestZoneNoResources

using Test
using DataFrames

include(joinpath(@__DIR__, "../utilities.jl"))

function prepare_costs_test(test_path, inputs, genx_setup, EP)
    settings = GenX.default_settings()
    merge!(settings, genx_setup)
    GenX.write_costs(test_path, inputs, settings, EP)
    costs_path = joinpath(test_path, "costs.csv")
    costs_test = CSV.read(costs_path, DataFrame)
    costs_test[!, :Zone1] = tryparse.(Float64, replace(costs_test[!, :Zone1], "-" => "0.0"))
    costs_test[!, :Zone2] = tryparse.(Float64, replace(costs_test[!, :Zone2], "-" => "0.0"))
    costs_test[!, :Zone2] = replace(costs_test[!, :Zone2], nothing => 0.0)
    return costs_test
end

function prepare_costs_true()
    df = DataFrame(
        ["cTotal" 5.177363815260002e12 4.027191550200002e12 1.1501722650599993e12;
         "cFix" 0.0 0.0 0.0;
         "cVar" 5.849292224195126e-8 0.0 5.849292224195126e-8;
         "cFuel" 0.0 0.0 0.0;
         "cNSE" 5.177363815260002e12 4.027191550200002e12 1.1501722650599993e12;
         "cStart" 0.0 0.0 0.0;
         "cUnmetRsv" 0.0 0.0 0.0;
         "cNetworkExp" 0.0 0.0 0.0;
         "cUnmetPolicyPenalty" 0.0 0.0 0.0;
         "cCO2" 0.0 0.0 0.0],
        [:Costs, :Total, :Zone1, :Zone2])

    df[!, :Costs] = convert(Vector{String}, df[!, :Costs])
    df[!, :Total] = convert(Vector{Float64}, df[!, :Total])
    df[!, :Zone1] = convert(Vector{Float64}, df[!, :Zone1])
    df[!, :Zone2] = convert(Vector{Float64}, df[!, :Zone2])
    return df
end

function test_case()
    test_path = joinpath(@__DIR__, "zone_no_resources")
    obj_true = 5.1773638153e12
    costs_true = prepare_costs_true()

    # Define test setup
    genx_setup = Dict("NetworkExpansion" => 1,
        "Trans_Loss_Segments" => 1,
        "UCommit" => 2,
        "CO2Cap" => 2,
        "StorageLosses" => 1,
        "WriteShadowPrices" => 1)

    # Run the case and get the objective value and tolerance
    EP, inputs, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end
    obj_test = objective_value(EP)
    optimal_tol_rel = get_attribute(EP, "dual_feasibility_tolerance")
    optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

    # Test the objective value
    test_result = @test obj_test≈obj_true atol=optimal_tol

    # Test the costs
    costs_test = prepare_costs_test(test_path, inputs, genx_setup, EP)
    test_result = @test costs_test[!, Not(:Costs)] ≈ costs_true[!, Not(:Costs)]

    # Remove the costs file
    rm(joinpath(test_path, "costs.csv"))

    return nothing
end

test_case()

end # module TestZoneNoResources
