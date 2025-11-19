module TestIncentivesSystem

using Test
using GenX
using Logging, LoggingExtras
using CSV, DataFrames

include(joinpath(@__DIR__, "utilities.jl"))

"""
    _run_incentives_case()
Internal helper to set up and solve the incentives test case.
Returns (EP, inputs, test_path).
"""
function _run_incentives_case()
    test_path = "incentives"
    genx_setup = Dict(
        "NetworkExpansion" => 1,
        "Trans_Loss_Segments" => 1,
        "CO2Cap" => 0,
        "StorageLosses" => 1,
        "MinCapReq" => 0,
        "InvestmentIncentive" => 1,
        "ProductionIncentive" => 1,
        "ParameterScale" => 1,
        "UCommit" => 2
    )
    EP, inputs, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end
    return EP, inputs, test_path
end

function test_basic_incentive_objects(EP)
    @test haskey(EP.obj_dict, :eTotalInvIncentiveBenefit)
    @test haskey(EP.obj_dict, :eTotalProdIncentiveBenefit)
    @test haskey(EP.obj_dict, :eInvIncentiveBenefit)
    @test haskey(EP.obj_dict, :eProdIncentiveBenefit)
end

function test_basic_incentive_values(EP)
    inv_incentive_benefit = JuMP.value(EP[:eTotalInvIncentiveBenefit])
    prod_incentive_benefit = JuMP.value(EP[:eTotalProdIncentiveBenefit])
    @test inv_incentive_benefit >= 0
    @test prod_incentive_benefit >= 0
    @test termination_status(EP) in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)
end

function test_prod_incentive_type_validation(inputs)
    @testset "ProdIncentive_Type Validation" begin
        @test all(t -> t in ["mwh", "tonne_co2"], inputs["ProdIncentive_Type"])
        @test inputs["NumberOfProdIncentive"] == 3
        @test inputs["ProdIncentive_Type"][1] == "mwh"
        @test inputs["ProdIncentive_Type"][2] == "mwh"
        @test inputs["ProdIncentive_Type"][3] == "tonne_co2"
    end
end

function test_production_incentive_benefits(EP, inputs)
    @testset "Production Incentive Benefits" begin
        for i in 1:inputs["NumberOfProdIncentive"]
            benefit = JuMP.value(EP[:eProdIncentiveBenefit][i])
            @test benefit >= 0
        end
        CCS = inputs["CCS"]
        if !isempty(CCS) && haskey(EP.obj_dict, :eEmissionsCaptureByPlant)
            gen = inputs["RESOURCES"]
            eligible_resources = GenX.ids_with_policy(gen, :prod_incentive, tag = 3)
            ccs_eligible = intersect(eligible_resources, CCS)
            if !isempty(ccs_eligible)
                T = inputs["T"]
                expected_co2_incentive = sum(
                    inputs["omega"][t] *
                    inputs["ProdIncentive_Rate"][3] *
                    JuMP.value(EP[:eEmissionsCaptureByPlant][y, t])
                for y in ccs_eligible, t in 1:T
                )
                actual_co2_incentive = JuMP.value(EP[:eProdIncentiveBenefit][3])
                @test isapprox(actual_co2_incentive, expected_co2_incentive, rtol = 1e-6)
            end
        end
    end
end

function test_output_type_normalization(test_path)
    @testset "Output Type Normalization" begin
        output_path = joinpath(test_path, "results", "production_incentive.csv")
        if isfile(output_path)
            df = CSV.read(output_path, DataFrame)
            for type_val in df.ProdIncentive_Type
                if type_val != "Total" && type_val != "All"
                    @test type_val in ["MWh", "Tonne_CO2"]
                end
            end
        end
    end
end

function test_invalid_prod_incentive_type()
    @testset "Invalid ProdIncentive_Type" begin
        temp_test_path = mktempdir()
        mkpath(joinpath(temp_test_path, "policies"))
        mkpath(joinpath(temp_test_path, "system"))
        mkpath(joinpath(temp_test_path, "resources"))
        invalid_df = DataFrame(
            ProdIncentive_Policy = [1],
            PolicyDescription = ["Invalid_Test"],
            ProdIncentive_Rate = [10.0],
            ProdIncentive_Type = ["invalid_type"]
        )
        CSV.write(joinpath(temp_test_path, "policies", "Production_incentive.csv"), invalid_df)
        @test_throws ErrorException begin
            setup_test = Dict("ProductionIncentive" => 1)
            inputs_test = Dict{String, Any}()
            GenX.load_production_incentive!(joinpath(temp_test_path, "policies"), inputs_test, setup_test)
        end
        rm(temp_test_path, recursive = true)
    end
end

function test_missing_prod_incentive_type_column()
    @testset "Missing ProdIncentive_Type Column" begin
        temp_missing_path = mktempdir()
        mkpath(joinpath(temp_missing_path, "policies"))
        missing_df = DataFrame(
            ProdIncentive_Policy = [1],
            PolicyDescription = ["Missing_Type_Test"],
            ProdIncentive_Rate = [5.0]
        )
        CSV.write(joinpath(temp_missing_path, "policies", "Production_incentive.csv"), missing_df)
        @test_throws ErrorException begin
            setup_missing = Dict("ProductionIncentive" => 1)
            inputs_missing = Dict{String, Any}()
            GenX.load_production_incentive!(
                joinpath(temp_missing_path, "policies"), inputs_missing, setup_missing)
        end
        rm(temp_missing_path, recursive = true)
    end
end

function test_incentives_system()
    EP, inputs, test_path = _run_incentives_case()
    test_basic_incentive_objects(EP)
    test_basic_incentive_values(EP)
    test_prod_incentive_type_validation(inputs)
    test_production_incentive_benefits(EP, inputs)
    test_output_type_normalization(test_path)
    test_invalid_prod_incentive_type()
    test_missing_prod_incentive_type_column()
end

with_logger(ConsoleLogger(stderr, Logging.Warn)) do
    test_incentives_system()
end

end # module
