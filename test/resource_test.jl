let
    Resource = GenX.GenXResource
    check_resource = GenX.check_resource

    therm = Resource(:Resource => "my_therm",
                     :THERM => 1,
                     :FLEX => 0,
                     :HYDRO => 0,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 0,
                     :LDS => 0)

    stor_lds = Resource(:Resource => "stor_lds",
                        :THERM => 0,
                     :FLEX => 0,
                     :HYDRO => 0,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 1,
                     :LDS => 1)

    hydro_lds = Resource(:Resource => "hydro_lds",
                         :THERM => 0,
                     :FLEX => 0,
                     :HYDRO => 1,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 0,
                     :LDS => 1)

    bad_lds = Resource(:Resource => "bad lds combo",
                       :THERM => 0,
                     :FLEX => 1,
                     :HYDRO => 0,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 0,
                     :LDS => 1)

    bad_none = Resource(:Resource => "none",
                            :THERM => 0,
                     :FLEX => 0,
                     :HYDRO => 0,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 0,
                     :LDS => 0)

    bad_twotypes = Resource(:Resource => "too many",
                            :THERM => 1,
                     :FLEX => 1,
                     :HYDRO => 0,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 0,
                     :LDS => 0)

    bad_multiple = Resource(:Resource => "multiple_bad",
                            :THERM => 1,
                     :FLEX => 1,
                     :HYDRO => 0,
                     :VRE => 0,
                     :MUST_RUN => 0,
                     :STOR => 0,
                     :LDS => 1)

    function check_okay(resource)
        e = check_resource(resource)
        @test length(e) == 0
    end

    function check_bad(resource)
        e = check_resource(resource)
        @test length(e) > 0
    end

    check_okay(therm)
    check_okay(stor_lds)
    check_okay(hydro_lds)

    check_bad(bad_lds)
    check_bad(bad_none)
    check_bad(bad_twotypes)

    multiple_resources = [therm, stor_lds, hydro_lds]
    check_okay(multiple_resources)

    multiple_bad_resources = [bad_lds, bad_twotypes, bad_multiple]
    e = check_resource(multiple_bad_resources)
    @test length(e) > 3

    function test_validate_bad(resources)
        with_logger(NullLogger()) do
            @test_throws ErrorException GenX.validate_resources(resources)
        end
    end

    test_validate_bad(multiple_bad_resources)


end
