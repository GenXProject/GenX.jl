module TestWritingStatsMs

using Test
using CSV, DataFrames
using GenX

# create temporary directory for testing 
mkpath("writing_outputs/multi_stage_stats_tmp")
outpath = "writing_outputs/multi_stage_stats_tmp"
filename = GenX._get_multi_stage_stats_filename()

function test_header()
    # Note: if this test fails, it means that the header in the function _get_multi_stage_stats_header() has been changed.
    # Make sure to check that the code is consistent with the new header, and update the test accordingly.
    header = GenX._get_multi_stage_stats_header()
    @test header ==
          ["Iteration_Number", "Seconds", "Upper_Bound", "Lower_Bound", "Relative_Gap"]
end

function test_skip_existing_file()
    touch(joinpath(outpath, filename))
    # If the file already exists, don't overwrite it
    write_multi_stage_stats = GenX.write_multi_stage_stats(outpath, Dict())
    @test isnothing(write_multi_stage_stats)
    rm(joinpath(outpath, filename))
end

function test_write_multi_stage_stats(iter::Int64 = 10)
    # test writing stats to file for `iter` number of iterations
    times_a, upper_bounds_a, lower_bounds_a = rand(iter), rand(iter), rand(iter)
    stats_d = Dict("TIMES" => times_a, "UPPER_BOUNDS" => upper_bounds_a,
        "LOWER_BOUNDS" => lower_bounds_a)

    @test isnothing(GenX.write_multi_stage_stats(outpath, stats_d))
    df_stats = CSV.read(joinpath(outpath, filename), DataFrame)
    header = GenX._get_multi_stage_stats_header()
    @test size(df_stats) == (iter, length(header))
    for i in 1:iter
        test_stats_d(df_stats, i, times_a[i], upper_bounds_a[i], lower_bounds_a[i],
            (upper_bounds_a[i] - lower_bounds_a[i]) / lower_bounds_a[i])
    end
    rm(joinpath(outpath, filename))
end

function test_create_multi_stage_stats_file()
    GenX.create_multi_stage_stats_file(outpath)
    df_stats = CSV.read(joinpath(outpath, filename), DataFrame)
    @test size(df_stats, 1) == 0
    @test size(df_stats, 2) == 5
    @test names(df_stats) == GenX._get_multi_stage_stats_header()
    rm(joinpath(outpath, filename))
end

function test_update_multi_stage_stats_file(iter::Int64 = 10)
    # test updating the stats file with new values
    header = GenX._get_multi_stage_stats_header()
    GenX.create_multi_stage_stats_file(outpath)
    lower_bound = rand()
    iteration_time = rand()
    for i in 1:iter
        # upper bound is updated
        upper_bound = rand()
        GenX.update_multi_stage_stats_file(
            outpath, i, upper_bound, lower_bound, iteration_time, new_row = true)
        df_stats = CSV.read(joinpath(outpath, filename), DataFrame)
        test_stats_d(df_stats, i, iteration_time, upper_bound, lower_bound,
            (upper_bound - lower_bound) / lower_bound)
        # lower bound is updated
        lower_bound = rand()
        GenX.update_multi_stage_stats_file(
            outpath, i, upper_bound, lower_bound, iteration_time)
        df_stats = CSV.read(joinpath(outpath, filename), DataFrame)
        test_stats_d(df_stats, i, iteration_time, upper_bound, lower_bound,
            (upper_bound - lower_bound) / lower_bound)
        # iteration time is updated
        iteration_time = rand()
        GenX.update_multi_stage_stats_file(
            outpath, i, upper_bound, lower_bound, iteration_time)
        df_stats = CSV.read(joinpath(outpath, filename), DataFrame)
        test_stats_d(df_stats, i, iteration_time, upper_bound, lower_bound,
            (upper_bound - lower_bound) / lower_bound)
        # test size 
        @test size(df_stats) == (i, length(header))
    end
    rm(joinpath(outpath, filename))
end

function test_stats_d(df_stats, i, iteration_time, upper_bound, lower_bound, relative_gap)
    header = GenX._get_multi_stage_stats_header()
    @test df_stats[i, header[1]] == i
    @test df_stats[i, header[2]] == iteration_time
    @test df_stats[i, header[3]] == upper_bound
    @test df_stats[i, header[4]] == lower_bound
    @test df_stats[i, header[5]] == relative_gap
end

@testset "Test writing multi-stage stats" begin
    test_header()
    test_skip_existing_file()
    test_write_multi_stage_stats()
    test_create_multi_stage_stats_file()
    test_update_multi_stage_stats_file()
end

rm(outpath)

end # module TestWritingStatsMs
