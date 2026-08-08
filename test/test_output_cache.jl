using GenX, JuMP, HiGHS, CSV, DataFrames, Test

function make_test_model(G, T, Z)
    opt = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
    EP = Model(opt)

    @variable(EP, vP[1:G, 1:T] >= 0)
    @variable(EP, eTotalCap[1:G] >= 0)
    @variable(EP, vNSE[1:1, 1:T, 1:Z] >= 0)
    @variable(EP, eEmissionsByZone[1:Z, 1:T] >= 0)

    @constraint(EP, [i = 1:G, t = 1:T], vP[i, t] == Float64(i * t))
    @constraint(EP, [i = 1:G], eTotalCap[i] == Float64(i))
    @constraint(EP, [s = 1:1, t = 1:T, z = 1:Z], vNSE[s, t, z] == 0.0)
    @constraint(EP, [z = 1:Z, t = 1:T], eEmissionsByZone[z, t] == 0.0)

    optimize!(EP)
    return EP
end

function make_test_inputs(G, T)
    return Dict(
        "G" => G,
        "T" => T,
        "STOR_ALL" => Int[],
        "FLEX" => Int[],
        "ELECTROLYZER" => Int[],
        "VRE_STOR" => Int[],
        "ALLAM_CYCLE_LOX" => Int[],
        "HYDRO_RES" => Int[],
    )
end

function make_output_settings(overrides...)
    d = Dict{String, Any}(
        "WritePower" => false,
        "WriteCapacityFactor" => false,
        "WriteCurtailment" => false,
        "WriteCharge" => false,
        "WriteChargingCost" => false,
        "WriteNetRevenue" => false,
        "WriteStorage" => false,
        "WriteStorageDual" => false,
        "WriteEnergyRevenue" => false,
        "WritePrice" => false,
        "WriteNSE" => false,
        "WriteEmissions" => false,
    )
    for (key, value) in overrides
        d[key] = value
    end
    return d
end

function make_setup(output_settings_d)
    return Dict(
        "ParameterScale" => 0,
        "WriteShadowPrices" => 0,
        "WriteOutputsSettingsDict" => output_settings_d,
    )
end

@testset "Output cache and transpose" begin
    @testset "transpose_output_dataframe" begin
        @testset "basic correctness and shape" begin
            df = DataFrame(A = [1, 2, 3], B = [4, 5, 6], C = [7, 8, 9])
            result = GenX.transpose_output_dataframe(df)

            @test nrow(result) == ncol(df)
            @test ncol(result) == nrow(df) + 1
            @test result[!, :Row] == names(df)
            @test result[1, :x1] == 1
            @test result[2, :x1] == 4
            @test result[3, :x1] == 7
            @test result[1, :x2] == 2
            @test result[1, :x3] == 3
        end

        @testset "withhead=true uses first column values as column names" begin
            df = DataFrame(label = ["alpha", "beta", "gamma"], v1 = [10, 20, 30], v2 = [100, 200, 300])
            result = GenX.transpose_output_dataframe(df; withhead = true)

            @test collect(propertynames(result)) == [:Row, :alpha, :beta, :gamma]
            @test result[1, :alpha] == "alpha"
            @test result[2, :alpha] == 10
            @test result[3, :alpha] == 100
        end

        @testset "input DataFrame is not mutated" begin
            df = DataFrame(X = [1, 2], Y = [3, 4])
            original_nrow = nrow(df)
            original_ncol = ncol(df)
            original_values = copy(Matrix(df))

            GenX.transpose_output_dataframe(df)

            @test nrow(df) == original_nrow
            @test ncol(df) == original_ncol
            @test Matrix(df) == original_values
        end

        @testset "single-row DataFrame transposes correctly" begin
            df = DataFrame(p = [42], q = [99], r = [7])
            result = GenX.transpose_output_dataframe(df)

            @test nrow(result) == 3
            @test ncol(result) == 2
            @test result[!, :Row] == ["p", "q", "r"]
            @test result[1, :x1] == 42
            @test result[2, :x1] == 99
            @test result[3, :x1] == 7
        end
    end

    @testset "write_transposed_csv" begin
        @testset "round-trip file shape and first column" begin
            df = DataFrame(A = [1, 2, 3], B = [4, 5, 6])

            mktempdir() do dir
                path = joinpath(dir, "out.csv")
                GenX.write_transposed_csv(path, df, writeheader = false)

                on_disk = CSV.read(path, DataFrame; header = false)

                @test nrow(on_disk) == ncol(df)
                @test ncol(on_disk) == nrow(df) + 1
                @test on_disk[!, 1] == string.(names(df))
            end
        end
    end

    @testset "build_output_cache" begin
        G, T, Z = 4, 3, 2
        EP = make_test_model(G, T, Z)

        @testset "non-selective (backward compat)" begin
            output_settings_d = make_output_settings()
            setup = make_setup(output_settings_d)
            inputs = make_test_inputs(G, T)

            cache = GenX.build_output_cache(EP, inputs, setup, output_settings_d; selective = false)

            @test size(cache.vP) == (G, T)
            @test cache.vP[2, 3] ≈ 6.0
            @test length(cache.eTotalCap) == G
            @test cache.eTotalCap[3] ≈ 3.0
            @test isnothing(cache.vNSE)
            @test isnothing(cache.eEmissionsByZone)
        end

        @testset "selective - all flags false" begin
            output_settings_d = make_output_settings()
            setup = make_setup(output_settings_d)
            inputs = make_test_inputs(G, T)

            cache = GenX.build_output_cache(EP, inputs, setup, output_settings_d; selective = true)

            @test size(cache.vP) == (0, 0)
            @test length(cache.eTotalCap) == 0
            @test size(cache.resource_time_scratch) == (0, 0)
            @test isnothing(cache.vNSE)
            @test isnothing(cache.eEmissionsByZone)
            @test isnothing(cache.vCHARGE)
            @test isnothing(cache.vS)
        end

        @testset "selective - only WritePower=true" begin
            output_settings_d = make_output_settings("WritePower" => true)
            setup = make_setup(output_settings_d)
            inputs = make_test_inputs(G, T)

            cache = GenX.build_output_cache(EP, inputs, setup, output_settings_d; selective = true)

            @test size(cache.vP) == (G, T)
            @test cache.vP[1, 1] ≈ 1.0
            @test length(cache.eTotalCap) == 0
            @test isnothing(cache.vNSE)
            @test isnothing(cache.eEmissionsByZone)
        end

        @testset "selective - only WriteNSE=true" begin
            output_settings_d = make_output_settings("WriteNSE" => true)
            setup = make_setup(output_settings_d)
            inputs = make_test_inputs(G, T)

            cache = GenX.build_output_cache(EP, inputs, setup, output_settings_d; selective = true)

            @test !isnothing(cache.vNSE)
            @test size(cache.vNSE) == (1, T, Z)
            @test all(==(0.0), cache.vNSE)
            @test size(cache.vP) == (0, 0)
        end

        @testset "selective - only WriteEmissions=true" begin
            output_settings_d = make_output_settings("WriteEmissions" => true)
            setup = make_setup(output_settings_d)
            inputs = make_test_inputs(G, T)

            cache = GenX.build_output_cache(EP, inputs, setup, output_settings_d; selective = true)

            @test !isnothing(cache.eEmissionsByZone)
            @test size(cache.eEmissionsByZone) == (Z, T)
            @test all(==(0.0), cache.eEmissionsByZone)
            @test size(cache.vP) == (0, 0)
        end

        @testset "selective - WriteCapacityFactor=true pulls both vP and eTotalCap" begin
            output_settings_d = make_output_settings("WriteCapacityFactor" => true)
            setup = make_setup(output_settings_d)
            inputs = make_test_inputs(G, T)

            cache = GenX.build_output_cache(EP, inputs, setup, output_settings_d; selective = true)

            @test size(cache.vP) == (G, T)
            @test length(cache.eTotalCap) == G
            @test cache.eTotalCap[4] ≈ 4.0
        end
    end

    @testset "resource_time_scratch! and scaled_resource_time_matrix!" begin
        function make_cache(scale_factor, scratch_val = 0.0)
            scratch = fill(scratch_val, 4, 3)
            return GenX.OutputCache(
                scale_factor,
                scratch,
                nothing,
                zeros(Float64, 4, 3),
                zeros(Float64, 4),
                nothing, nothing, nothing,
                nothing, nothing,
                nothing, nothing, nothing,
                nothing,
                nothing,
                nothing,
            )
        end

        @testset "resource_time_scratch! zeroes the scratch matrix" begin
            cache = make_cache(1.0, 99.0)
            result = GenX.resource_time_scratch!(cache)
            @test all(==(0.0), result)
            @test result === cache.resource_time_scratch
        end

        @testset "scaled_resource_time_matrix! with scale_factor == 1 returns identity" begin
            cache = make_cache(1.0)
            data = rand(Float64, 4, 3)
            result = GenX.scaled_resource_time_matrix!(cache, data)
            @test result === data
        end

        @testset "scaled_resource_time_matrix! with scale_factor == 2.0 scales correctly" begin
            cache = make_cache(2.0)
            data = ones(Float64, 4, 3)
            result = GenX.scaled_resource_time_matrix!(cache, data)
            @test all(==(2.0), result)
            @test result !== data
        end
    end
end
