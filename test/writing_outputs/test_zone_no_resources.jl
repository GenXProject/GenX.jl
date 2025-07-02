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
        ["cTotal" 1.463768296693398e12 1.4588919221877012e12 4.840797505702658e9;
        "cFix" 4.727103377348504e9 0.0 4.727103377348504e9;
        "cVar" 2.3347293240589075e7 0.0 2.3347293240589064e7;
        "cFuel" 4.4718223470249504e7 0.0 4.4718223470249504e7;
        "cNSE" 1.4588919221877012e12 1.4588919221877012e12 0.0;
        "cStart" 4.5628611643315025e7 0.0 4.5628611643315025e7;
        "cUnmetRsv" 0.0 0.0 0.0;
        "cNetworkExp" 3.5577e7 0.0 0.0;
        "cUnmetPolicyPenalty" 0.0 0.0 0.0;
        "cCO2" 0.0 0.0 0.0;
        "cInv" 3.4603915632743273e9 0.0 3.4603915632743273e9;
        "cFom" 1.266711814074177e9 0.0 1.266711814074177e9],
        [:Costs, :Total, :Zone1, :Zone2])

    df[!, :Costs] = convert(Vector{String}, df[!, :Costs])
    df[!, :Total] = convert(Vector{Float64}, df[!, :Total])
    df[!, :Zone1] = convert(Vector{Float64}, df[!, :Zone1])
    df[!, :Zone2] = convert(Vector{Float64}, df[!, :Zone2])
    return df
end

function test_case()
    test_path = joinpath(@__DIR__, "zone_no_resources")
    obj_true = 1.463768296693398e12
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
    @test obj_test≈obj_true atol=optimal_tol

    # Test the costs
    costs_test = prepare_costs_test(test_path, inputs, genx_setup, EP)
    @test costs_test[!, Not(:Costs)] ≈ costs_true[!, Not(:Costs)]
    @test Vector(costs_test[2, 2:end]) ≈ (Vector(costs_true[end-1, 2:end]) + Vector(costs_true[end, 2:end]))

    # Remove the costs file
    rm(joinpath(test_path, "costs.csv"))

    return nothing
end

test_case()

end # module TestZoneNoResources
