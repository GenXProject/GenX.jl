module TestTDRUTESIntegration

using Test
using GenX
using CSV
using DataFrames
using Logging

@testset "TDR + UTES Integration" begin
    base_path = Base.dirname(Base.dirname(pathof(GenX)))
    case_path = joinpath(base_path, "example_systems", "12_three_zones_thermal_storage")
    settings_path = joinpath(case_path, "settings")

    setup = GenX.configure_settings(
        joinpath(settings_path, "genx_settings.yml"),
        joinpath(settings_path, "output_settings.yml"),
    )

    # Build reduced time-series inputs used by UTES/cooling-demand pipelines.
    with_logger(ConsoleLogger(stderr, Logging.Warn)) do
        GenX.cluster_inputs(case_path, settings_path, setup, random = false)
    end

    tdr_path = joinpath(case_path, setup["TimeDomainReductionFolder"])

    computing_path = joinpath(tdr_path, "Computing_demand_data.csv")
    ambient_path = joinpath(tdr_path, "Ambient_temperature_data.csv")
    period_map_path = joinpath(tdr_path, "Period_map.csv")

    @test isfile(computing_path)
    @test isfile(ambient_path)
    @test isfile(period_map_path)

    computing_df = CSV.read(computing_path, DataFrame)
    ambient_df = CSV.read(ambient_path, DataFrame)

    @test nrow(computing_df) > 0
    @test nrow(ambient_df) > 0
    @test !isempty(collect(skipmissing(computing_df[!, :Voll])))
    @test names(ambient_df)[1] == "Time_Index"
    @test all(string(n) in ["z1", "z2", "z3"] for n in names(ambient_df)[2:end])

    inputs = GenX.load_inputs(setup, case_path)

    @test size(inputs["pD_Computing"], 1) == inputs["T"]
    @test size(inputs["pD_Computing"], 2) == inputs["Z"]
    @test size(inputs["pAmbientTemp"], 1) == inputs["Z"]
    @test size(inputs["pAmbientTemp"], 2) == inputs["T"]

    @test haskey(inputs, "COP_DC")
    @test haskey(inputs, "COP_Chiller")
    @test haskey(inputs, "MaxChargePower")
end

end # module
