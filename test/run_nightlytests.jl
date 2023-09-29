#
# Nightly tests on develop. Check also test_examples.jl. 
#
# List of examples to run as nightly tests:
# - SmallNewEngland
#     * OneZone
#     * OneZone_3VREBin
#     * OneZone_MultiStage
#     * ThreeZones
#     * ThreeZones_MultiStage
#     * Simple_Test_Case
#     * Test_Up_Time
#     * Test_Down_Time
#     * ThreeZones_Slack_Variables
# - RetrofitExample
#     * RetrofitMultiStage
# - RealSystemExample
#     * ISONE_Singlezone
#     * ISONE_Trizone
#     * ISONE_Trizone_FullTimeseries
#     * ISONE_Trizone_MultiStage
#     * MGA_ISONE_Trizone_FullTimeseries
# - PiecewiseFuel_CO2
# - VREStor
# - Electrolyzer
# - MethodofMorris
#     * OneZone
#

include("test_examples.jl")

import Test

# run all the examples in test_examples.jl
function run_tests()
    Test.@testset "Test Examples" begin
        NightlyTests.test_examples()
    end
    return
end

run_tests()
