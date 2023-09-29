module NightlyTests

using Test, GenX

# base directory of GenX examples
const basedir = "Example_Systems"

function test_examples()
    # SmallNewEngland
    example_dir = "SmallNewEngland"
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "OneZone")))
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "OneZone_3VREBin")))
    @test isnothing(
        GenX.run_genx_case!(joinpath(basedir, example_dir, "OneZone_MultiStage")),
    )
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "ThreeZones")))
    @test isnothing(
        GenX.run_genx_case!(joinpath(basedir, example_dir, "ThreeZones_MultiStage")),
    )
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "Simple_Test_Case")))
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "Test_Up_Time")))
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "Test_Down_Time")))
    @test isnothing(
        GenX.run_genx_case!(joinpath(basedir, example_dir, "ThreeZones_Slack_Variables")),
    )

    # Retrofit
    example_dir = "Retrofit"
    @test isnothing(
        GenX.run_genx_case!(joinpath(basedir, example_dir, "Retrofit_MultiStage")),
    )

    #  RealSystem
    example_dir = "RealSystem"
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "ISONE_Singlezone")))
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "ISONE_Trizone")))
    @test isnothing(
        GenX.run_genx_case!(joinpath(basedir, example_dir, "ISONE_Trizone_FullTimeseries")),
    )
    @test isnothing(
        GenX.run_genx_case!(joinpath(basedir, example_dir, "ISONE_Trizone_MultiStage")),
    )
    @test isnothing(
        GenX.run_genx_case!(
            joinpath(basedir, example_dir, "MGA_ISONE_Trizone_FullTimeseries"),
        ),
    )

    # PiecewiseFuel_CO2
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, "PiecewiseFuel_CO2")))

    # VREStor
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, "VREStor")))

    # Electrolyzer
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, "Electrolyzer")))

    # MethodofMorris
    example_dir = "MethodofMorris"
    @test isnothing(GenX.run_genx_case!(joinpath(basedir, example_dir, "OneZone")))

    return
end

end # module NightlyTests
