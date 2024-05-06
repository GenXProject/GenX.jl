module TestLoadResourceData

using Test
using GenX
using JLD2
using Logging, LoggingExtras
import DataFrames: rename!

struct InputsTrue
    gen_filename::AbstractString
    inputs_filename::AbstractString
end

function test_macro_interface(attr::Symbol, gen, dfGen)
    f = getfield(GenX, attr)
    @test f.(gen) == dfGen[!, attr]
end

function test_ids_with(attr::Symbol, gen, dfGen)
    @test GenX.ids_with(gen, attr) == dfGen[dfGen[!, attr] .!= 0, :r_id]
end

function test_ids_with_nonneg(attr::Symbol, gen, dfGen)
    @test GenX.ids_with_nonneg(gen, attr) == dfGen[dfGen[!, attr] .>= 0, :r_id]
end

function test_ids_with_positive(attr::Symbol, gen, dfGen)
    @test GenX.ids_with_positive(gen, attr) == dfGen[dfGen[!, attr] .> 0, :r_id]
end

function prepare_inputs_true(test_path::AbstractString,
        in_filenames::InputsTrue,
        setup::Dict)
    gen_filename = in_filenames.gen_filename
    inputs_filename = in_filenames.inputs_filename
    dfGen = GenX.load_dataframe(joinpath(test_path, gen_filename))
    scale_factor = setup["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1.0
    GenX.rename!(dfGen, lowercase.(names(dfGen)))
    GenX.scale_resources_data!(dfGen, scale_factor)
    dfGen[!, :r_id] = 1:size(dfGen, 1)
    inputs_true = load(joinpath(test_path, inputs_filename))
    return dfGen, inputs_true
end

function test_load_scaled_resources_data(gen, dfGen)

    ## Test that the data loaded correctly
    # Test resource types
    @test GenX.storage(gen) == dfGen[dfGen.stor .== 1, :r_id]
    @test GenX.thermal(gen) == dfGen[dfGen.therm .== 1, :r_id]
    @test GenX.vre(gen) == dfGen[dfGen.vre .== 1, :r_id]
    @test GenX.hydro(gen) == dfGen[dfGen.hydro .== 1, :r_id]
    @test GenX.flex_demand(gen) == dfGen[dfGen.flex .== 1, :r_id]
    @test GenX.electrolyzer(gen) == dfGen[dfGen.electrolyzer .== 1, :r_id]
    @test GenX.must_run(gen) == dfGen[dfGen.must_run .== 1, :r_id]

    @test GenX.is_LDS(gen) == dfGen[dfGen.lds .== 1, :r_id]
    @test GenX.is_SDS(gen) == dfGen[dfGen.lds .== 0, :r_id]

    # Test resource attributes
    @test GenX.resource_name.(gen) == dfGen.resource
    @test GenX.resource_id.(gen) == dfGen.r_id
    @test GenX.resource_type_mga.(gen) == dfGen.resource_type
    @test GenX.zone_id.(gen) == dfGen.zone

    @test GenX.max_cap_mw.(gen) == dfGen.max_cap_mw
    @test GenX.min_cap_mw.(gen) == dfGen.min_cap_mw
    @test GenX.min_cap_mwh.(gen) == dfGen.min_cap_mwh

    @test GenX.existing_cap_mw.(gen) == dfGen.existing_cap_mw
    @test GenX.existing_cap_mwh.(gen) == dfGen.existing_cap_mwh

    @test GenX.num_vre_bins.(gen) == dfGen.num_vre_bins

    @test GenX.qualified_hydrogen_supply.(gen) == dfGen.qualified_hydrogen_supply

    @test GenX.reg_cost.(gen) == dfGen.reg_cost
    @test GenX.reg_max.(gen) == dfGen.reg_max
    @test GenX.rsv_cost.(gen) == dfGen.rsv_cost
    @test GenX.rsv_max.(gen) == dfGen.rsv_max

    @test GenX.inv_cost_per_mwyr.(gen) == dfGen.inv_cost_per_mwyr
    @test GenX.fixed_om_cost_per_mwyr.(gen) == dfGen.fixed_om_cost_per_mwyr
    @test GenX.var_om_cost_per_mwh.(gen) == dfGen.var_om_cost_per_mwh
    @test GenX.inv_cost_per_mwhyr.(gen) == dfGen.inv_cost_per_mwhyr
    @test GenX.fixed_om_cost_per_mwhyr.(gen) == dfGen.fixed_om_cost_per_mwhyr
    @test GenX.start_cost_per_mw.(gen) == dfGen.start_cost_per_mw

    @test GenX.fuel.(gen) == dfGen.fuel
    @test GenX.co2_capture_fraction.(gen) == dfGen.co2_capture_fraction
    @test GenX.co2_capture_fraction_startup.(gen) == dfGen.co2_capture_fraction_startup
    @test GenX.ccs_disposal_cost_per_metric_ton.(gen) ==
          dfGen.ccs_disposal_cost_per_metric_ton
    @test GenX.biomass.(gen) == dfGen.biomass
    ## multi-fuel flags
    @test GenX.ids_with_fuel(gen) == dfGen[(dfGen[!, :fuel] .!= "None"), :r_id]
    @test GenX.ids_with_positive(gen, GenX.co2_capture_fraction) ==
          dfGen[dfGen.co2_capture_fraction .> 0, :r_id]
    @test GenX.ids_with_singlefuel(gen) == dfGen[dfGen.multi_fuels .!= 1, :r_id]
    @test GenX.ids_with_multifuels(gen) == dfGen[dfGen.multi_fuels .== 1, :r_id]
    if !isempty(GenX.ids_with_multifuels(gen))
        MULTI_FUELS = GenX.ids_with_multifuels(gen)
        max_fuels = maximum(GenX.num_fuels.(gen))
        for i in 1:max_fuels
            @test findall(g -> GenX.max_cofire_cols(g, tag = i) < 1, gen[MULTI_FUELS]) ==
                  dfGen[dfGen[!, Symbol(string("fuel", i, "_max_cofire_level"))] .< 1, :][
                !,
                :r_id]
            @test findall(g -> GenX.max_cofire_start_cols(g, tag = i) < 1,
                gen[MULTI_FUELS]) == dfGen[
                dfGen[!, Symbol(string("fuel", i, "_max_cofire_level_start"))] .< 1,
                :][!,
                :r_id]
            @test findall(g -> GenX.min_cofire_cols(g, tag = i) > 0, gen[MULTI_FUELS]) ==
                  dfGen[dfGen[!, Symbol(string("fuel", i, "_min_cofire_level"))] .> 0, :][
                !,
                :r_id]
            @test findall(g -> GenX.min_cofire_start_cols(g, tag = i) > 0,
                gen[MULTI_FUELS]) == dfGen[
                dfGen[!, Symbol(string("fuel", i, "_min_cofire_level_start"))] .> 0,
                :][!,
                :r_id]
            @test GenX.fuel_cols.(gen, tag = i) == dfGen[!, Symbol(string("fuel", i))]
            @test GenX.heat_rate_cols.(gen, tag = i) ==
                  dfGen[!, Symbol(string("heat_rate", i, "_mmbtu_per_mwh"))]
            @test GenX.max_cofire_cols.(gen, tag = i) ==
                  dfGen[!, Symbol(string("fuel", i, "_max_cofire_level"))]
            @test GenX.min_cofire_cols.(gen, tag = i) ==
                  dfGen[!, Symbol(string("fuel", i, "_min_cofire_level"))]
            @test GenX.max_cofire_start_cols.(gen, tag = i) ==
                  dfGen[!, Symbol(string("fuel", i, "_max_cofire_level_start"))]
            @test GenX.min_cofire_start_cols.(gen, tag = i) ==
                  dfGen[!, Symbol(string("fuel", i, "_min_cofire_level_start"))]
        end
    end
    @test GenX.ids_with_mga(gen) == dfGen[dfGen.mga .== 1, :r_id]

    @test GenX.region.(gen) == dfGen.region
    @test GenX.cluster.(gen) == dfGen.cluster
end

function test_add_policies_to_resources(gen, dfGen)
    @test GenX.esr.(gen, tag = 1) == dfGen.esr_1
    @test GenX.esr.(gen, tag = 2) == dfGen.esr_2
    @test GenX.min_cap.(gen, tag = 1) == dfGen.mincaptag_1
    @test GenX.min_cap.(gen, tag = 2) == dfGen.mincaptag_2
    @test GenX.min_cap.(gen, tag = 3) == dfGen.mincaptag_3
    @test GenX.derating_factor.(gen, tag = 1) == dfGen.capres_1
end

function test_add_modules_to_resources(gen, dfGen)
    @test GenX.tech_wacc.(gen) == dfGen.wacc
    @test GenX.capital_recovery_period.(gen) == dfGen.capital_recovery_period
    @test GenX.lifetime.(gen) == dfGen.lifetime
    @test GenX.min_retired_cap_mw.(gen) == dfGen.min_retired_cap_mw
    @test GenX.min_retired_energy_cap_mw.(gen) == dfGen.min_retired_energy_cap_mw
    @test GenX.min_retired_charge_cap_mw.(gen) == dfGen.min_retired_charge_cap_mw
end

function test_inputs_keys(inputs, inputs_true)
    @test inputs["G"] == inputs_true["G"]

    @test inputs["HYDRO_RES"] == inputs_true["HYDRO_RES"]
    @test inputs["HYDRO_RES_KNOWN_CAP"] == inputs_true["HYDRO_RES_KNOWN_CAP"]
    @test inputs["STOR_ALL"] == inputs_true["STOR_ALL"]
    @test inputs["STOR_SYMMETRIC"] == inputs_true["STOR_SYMMETRIC"]
    @test inputs["STOR_ASYMMETRIC"] == inputs_true["STOR_ASYMMETRIC"]
    @test inputs["STOR_SHORT_DURATION"] == inputs_true["STOR_SHORT_DURATION"]
    @test inputs["STOR_LONG_DURATION"] == inputs_true["STOR_LONG_DURATION"]
    @test inputs["STOR_HYDRO_LONG_DURATION"] == inputs_true["STOR_HYDRO_LONG_DURATION"]
    @test inputs["VRE"] == inputs_true["VRE"]
    @test inputs["FLEX"] == inputs_true["FLEX"]
    @test inputs["MUST_RUN"] == inputs_true["MUST_RUN"]
    @test inputs["ELECTROLYZER"] == inputs_true["ELECTROLYZER"]
    @test inputs["RETROFIT_OPTIONS"] == inputs_true["RETRO"]
    @test inputs["REG"] == inputs_true["REG"]
    @test inputs["RSV"] == inputs_true["RSV"]
    @test inputs["THERM_ALL"] == inputs_true["THERM_ALL"]
    @test inputs["THERM_COMMIT"] == inputs_true["THERM_COMMIT"]
    @test inputs["THERM_NO_COMMIT"] == inputs_true["THERM_NO_COMMIT"]
    @test inputs["COMMIT"] == inputs_true["COMMIT"]
    @test inputs["C_Start"] == inputs_true["C_Start"]

    @test Set(inputs["RET_CAP"]) == inputs_true["RET_CAP"]
    @test Set(inputs["RET_CAP_CHARGE"]) == inputs_true["RET_CAP_CHARGE"]
    @test Set(inputs["RET_CAP_ENERGY"]) == inputs_true["RET_CAP_ENERGY"]
    @test Set(inputs["NEW_CAP"]) == inputs_true["NEW_CAP"]
    @test Set(inputs["NEW_CAP_ENERGY"]) == inputs_true["NEW_CAP_ENERGY"]
    @test Set(inputs["NEW_CAP_CHARGE"]) == inputs_true["NEW_CAP_CHARGE"]

    if isempty(inputs["MULTI_FUELS"])
        @test string.(inputs["slope_cols"]) ==
              lowercase.(string.(inputs_true["slope_cols"]))
        @test string.(inputs["intercept_cols"]) ==
              lowercase.(string.(inputs_true["intercept_cols"]))
        @test inputs["PWFU_data"] ==
              rename!(inputs_true["PWFU_data"], lowercase.(names(inputs_true["PWFU_data"])))
        @test inputs["PWFU_Num_Segments"] == inputs_true["PWFU_Num_Segments"]
        @test inputs["THERM_COMMIT_PWFU"] == inputs_true["THERM_COMMIT_PWFU"]
    end

    @test inputs["R_ZONES"] == inputs_true["R_ZONES"]
    @test inputs["RESOURCE_ZONES"] == inputs_true["RESOURCE_ZONES"]
    @test inputs["RESOURCE_NAMES"] == inputs_true["RESOURCES"]
end

function test_resource_specific_attributes(gen, dfGen, inputs)
    @test GenX.is_buildable(gen) == dfGen[dfGen.new_build .== 1, :r_id]
    @test GenX.is_retirable(gen) == dfGen[dfGen.can_retire .== 1, :r_id]

    rs = GenX.ids_with_positive(gen, GenX.max_cap_mwh)
    @test rs == dfGen[dfGen.max_cap_mwh .> 0, :r_id]
    @test GenX.max_cap_mwh.(rs) == dfGen[dfGen.max_cap_mwh .> 0, :r_id]
    rs = GenX.ids_with_positive(gen, GenX.max_charge_cap_mw)
    @test rs == dfGen[dfGen.max_charge_cap_mw .> 0, :r_id]
    @test GenX.max_charge_cap_mw.(rs) == dfGen[dfGen.max_charge_cap_mw .> 0, :r_id]
    rs = GenX.ids_with_unit_commitment(gen)
    @test rs == dfGen[dfGen.therm .== 1, :r_id]
    @test GenX.cap_size.(gen[rs]) == dfGen[dfGen.therm .== 1, :cap_size]
    rs = setdiff(inputs["HAS_FUEL"], inputs["THERM_COMMIT"])
    @test GenX.heat_rate_mmbtu_per_mwh.(gen[rs]) == dfGen[rs, :heat_rate_mmbtu_per_mwh]
    rs = setdiff(inputs["THERM_COMMIT"], inputs["THERM_COMMIT_PWFU"])
    @test GenX.heat_rate_mmbtu_per_mwh.(gen[rs]) == dfGen[rs, :heat_rate_mmbtu_per_mwh]
    rs = inputs["THERM_COMMIT"]
    @test GenX.start_fuel_mmbtu_per_mw.(gen[rs]) == dfGen[rs, :start_fuel_mmbtu_per_mw]
    rs = union(inputs["STOR_ALL"], inputs["HYDRO_RES"])
    @test GenX.efficiency_up.(gen[rs]) == dfGen[rs, :eff_up]
    @test GenX.efficiency_down.(gen[rs]) == dfGen[rs, :eff_down]
    rs = union(inputs["THERM_ALL"], inputs["HYDRO_RES"], inputs["ELECTROLYZER"])
    @test GenX.min_power.(gen[rs]) == dfGen[rs, :min_power]
    @test GenX.ramp_up_fraction.(gen[rs]) == dfGen[rs, :ramp_up_percentage]
    @test GenX.ramp_down_fraction.(gen[rs]) == dfGen[rs, :ramp_dn_percentage]
    rs = inputs["STOR_ASYMMETRIC"]
    @test GenX.max_charge_cap_mw.(gen[rs]) == dfGen[rs, :max_charge_cap_mw]
    @test GenX.min_charge_cap_mw.(gen[rs]) == dfGen[rs, :min_charge_cap_mw]
    @test GenX.existing_charge_cap_mw.(gen[rs]) == dfGen[rs, :existing_charge_cap_mw]
    @test GenX.inv_cost_charge_per_mwyr.(gen[rs]) == dfGen[rs, :inv_cost_charge_per_mwyr]
    @test GenX.fixed_om_cost_charge_per_mwyr.(gen[rs]) ==
          dfGen[rs, :fixed_om_cost_charge_per_mwyr]
    rs = union(inputs["HYDRO_RES_KNOWN_CAP"], inputs["STOR_HYDRO_LONG_DURATION"])
    @test GenX.hydro_energy_to_power_ratio.(gen[rs]) ==
          dfGen[rs, :hydro_energy_to_power_ratio]
end

function test_load_resources_data()
    setup = Dict("ParameterScale" => 0,
        "OperationalReserves" => 1,
        "UCommit" => 2,
        "MultiStage" => 1)

    # Merge the setup with the default settings
    settings = GenX.default_settings()
    merge!(settings, setup)

    test_path = joinpath("load_resources", "test_gen_non_colocated")

    # load dfGen and inputs_true to compare against
    input_true_filenames = InputsTrue("generators_data.csv", "inputs_after_loadgen.jld2")
    dfGen, inputs_true = prepare_inputs_true(test_path, input_true_filenames, settings)

    # Test resource data is loaded correctly
    resources_path = joinpath(test_path, settings["ResourcesFolder"])
    gen = GenX.create_resource_array(settings, resources_path)
    @testset "Default fields" begin
        test_load_scaled_resources_data(gen, dfGen)
    end

    # Test policy fields are correctly added to the resource structs
    resource_policies_path = joinpath(resources_path, settings["ResourcePoliciesFolder"])
    GenX.validate_policy_files(resource_policies_path, settings)
    GenX.add_policies_to_resources!(gen, resource_policies_path)
    @testset "Policy attributes" begin
        test_add_policies_to_resources(gen, dfGen)
    end

    # Test modules are correctly added to the resource structs
    GenX.add_modules_to_resources!(gen, settings, resources_path)
    @testset "Module attributes" begin
        test_add_modules_to_resources(gen, dfGen)
    end

    # Test that the inputs keys are correctly set
    inputs = load(joinpath(test_path, "inputs_before_loadgen.jld2"))
    GenX.add_resources_to_input_data!(inputs, settings, test_path, gen)
    @testset "Inputs keys" begin
        test_inputs_keys(inputs, inputs_true)
    end

    # Test that the resource-specific attributes are correctly set
    @testset "resource-specific attributes" begin
        test_resource_specific_attributes(gen, dfGen, inputs)
    end
end

function test_load_VRE_STOR_data()
    setup = Dict("ParameterScale" => 0,
        "OperationalReserves" => 1,
        "UCommit" => 2,
        "MultiStage" => 0)

    # Merge the setup with the default settings
    settings = GenX.default_settings()
    merge!(settings, setup)

    test_path = joinpath("load_resources", "test_gen_vre_stor")
    input_true_filenames = InputsTrue("generators_data.csv", "inputs_after_loadgen.jld2")
    dfGen, inputs_true = prepare_inputs_true(test_path, input_true_filenames, settings)

    dfVRE_STOR = GenX.load_dataframe(joinpath(test_path, "Vre_and_stor_data.csv"))
    dfVRE_STOR = GenX.rename!(dfVRE_STOR, lowercase.(names(dfVRE_STOR)))
    scale_factor = settings["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1.0
    GenX.scale_vre_stor_data!(dfVRE_STOR, scale_factor)

    resources_path = joinpath(test_path, settings["ResourcesFolder"])
    gen = GenX.create_resource_array(settings, resources_path)
    resource_policies_path = joinpath(resources_path, settings["ResourcePoliciesFolder"])
    GenX.validate_policy_files(resource_policies_path, settings)
    GenX.add_policies_to_resources!(gen, resource_policies_path)
    inputs = load(joinpath(test_path, "inputs_before_loadgen.jld2"))
    GenX.add_resources_to_input_data!(inputs, settings, test_path, gen)

    @test GenX.vre_stor(gen) == dfGen[dfGen.vre_stor .== 1, :r_id]
    sort!(dfVRE_STOR, :resource)

    rs = inputs["VRE_STOR"]
    @test GenX.solar(gen) == dfVRE_STOR[dfVRE_STOR.solar .== 1, :r_id]
    @test GenX.wind(gen) == dfVRE_STOR[dfVRE_STOR.wind .== 1, :r_id]
    @test GenX.storage_dc_discharge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .>= 1, :r_id]
    @test GenX.storage_sym_dc_discharge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .== 1, :r_id]
    @test GenX.storage_asym_dc_discharge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .== 2, :r_id]

    @test GenX.storage_dc_charge(gen) == dfVRE_STOR[dfVRE_STOR.stor_dc_charge .>= 1, :r_id]
    @test GenX.storage_sym_dc_charge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_charge .== 1, :r_id]
    @test GenX.storage_asym_dc_charge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_charge .== 2, :r_id]

    @test GenX.storage_ac_discharge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_discharge .>= 1, :r_id]
    @test GenX.storage_sym_ac_discharge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_discharge .== 1, :r_id]
    @test GenX.storage_asym_ac_discharge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_discharge .== 2, :r_id]

    @test GenX.storage_ac_charge(gen) == dfVRE_STOR[dfVRE_STOR.stor_ac_charge .>= 1, :r_id]
    @test GenX.storage_sym_ac_charge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_charge .== 1, :r_id]
    @test GenX.storage_asym_ac_charge(gen) ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_charge .== 2, :r_id]

    @test GenX.technology.(gen[rs]) == dfVRE_STOR.technology
    @test GenX.is_LDS_VRE_STOR(gen) == dfVRE_STOR[dfVRE_STOR.lds_vre_stor .!= 0, :r_id]

    for attr in (:existing_cap_solar_mw,
        :existing_cap_wind_mw,
        :existing_cap_inverter_mw,
        :existing_cap_charge_dc_mw,
        :existing_cap_charge_ac_mw,
        :existing_cap_discharge_dc_mw,
        :existing_cap_discharge_ac_mw)
        test_macro_interface(attr, gen[rs], dfVRE_STOR)
        test_ids_with_nonneg(attr, gen[rs], dfVRE_STOR)
    end

    for attr in (:max_cap_solar_mw,
        :max_cap_wind_mw,
        :max_cap_inverter_mw,
        :max_cap_charge_dc_mw,
        :max_cap_charge_ac_mw,
        :max_cap_discharge_dc_mw,
        :max_cap_discharge_ac_mw)
        test_macro_interface(attr, gen[rs], dfVRE_STOR)
        test_ids_with_nonneg(attr, gen[rs], dfVRE_STOR)
        test_ids_with(attr, gen[rs], dfVRE_STOR)
    end

    for attr in (:min_cap_solar_mw,
        :min_cap_wind_mw,
        :min_cap_inverter_mw,
        :min_cap_charge_dc_mw,
        :min_cap_charge_ac_mw,
        :min_cap_discharge_dc_mw,
        :min_cap_discharge_ac_mw,
        :inverter_ratio_solar,
        :inverter_ratio_wind)
        test_macro_interface(attr, gen[rs], dfVRE_STOR)
        test_ids_with_positive(attr, gen[rs], dfVRE_STOR)
    end

    for attr in (:etainverter,
        :inv_cost_inverter_per_mwyr,
        :inv_cost_solar_per_mwyr,
        :inv_cost_wind_per_mwyr,
        :inv_cost_discharge_dc_per_mwyr,
        :inv_cost_charge_dc_per_mwyr,
        :inv_cost_discharge_ac_per_mwyr,
        :inv_cost_charge_ac_per_mwyr,
        :fixed_om_inverter_cost_per_mwyr,
        :fixed_om_solar_cost_per_mwyr,
        :fixed_om_wind_cost_per_mwyr,
        :fixed_om_cost_discharge_dc_per_mwyr,
        :fixed_om_cost_charge_dc_per_mwyr,
        :fixed_om_cost_discharge_ac_per_mwyr,
        :fixed_om_cost_charge_ac_per_mwyr,
        :var_om_cost_per_mwh_solar,
        :var_om_cost_per_mwh_wind,
        :var_om_cost_per_mwh_charge_dc,
        :var_om_cost_per_mwh_discharge_dc,
        :var_om_cost_per_mwh_charge_ac,
        :var_om_cost_per_mwh_discharge_ac,
        :eff_up_ac,
        :eff_down_ac,
        :eff_up_dc,
        :eff_down_dc,
        :power_to_energy_ac,
        :power_to_energy_dc)
        test_macro_interface(attr, gen[rs], dfVRE_STOR)
    end

    # policies
    @test GenX.esr_vrestor.(gen[rs], tag = 1) == dfVRE_STOR.esr_vrestor_1
    @test GenX.esr_vrestor.(gen[rs], tag = 2) == dfVRE_STOR.esr_vrestor_2
    @test GenX.min_cap_stor.(gen[rs], tag = 1) == dfVRE_STOR.mincaptagstor_1
    @test GenX.min_cap_stor.(gen[rs], tag = 2) == dfVRE_STOR.mincaptagstor_2
    @test GenX.derating_factor.(gen[rs], tag = 1) == dfVRE_STOR.capresvrestor_1
    @test GenX.derating_factor.(gen[rs], tag = 2) == dfVRE_STOR.capresvrestor_2
    @test GenX.max_cap_stor.(gen[rs], tag = 1) == dfVRE_STOR.maxcaptagstor_1
    @test GenX.max_cap_stor.(gen[rs], tag = 2) == dfVRE_STOR.maxcaptagstor_2
    @test GenX.min_cap_solar.(gen[rs], tag = 1) == dfVRE_STOR.mincaptagsolar_1
    @test GenX.max_cap_solar.(gen[rs], tag = 1) == dfVRE_STOR.maxcaptagsolar_1
    @test GenX.min_cap_wind.(gen[rs], tag = 1) == dfVRE_STOR.mincaptagwind_1
    @test GenX.max_cap_wind.(gen[rs], tag = 1) == dfVRE_STOR.maxcaptagwind_1

    @test GenX.ids_with_policy(gen, GenX.min_cap_solar, tag = 1) ==
          dfVRE_STOR[dfVRE_STOR.mincaptagsolar_1 .== 1, :r_id]
    @test GenX.ids_with_policy(gen, GenX.min_cap_wind, tag = 1) ==
          dfVRE_STOR[dfVRE_STOR.mincaptagwind_1 .== 1, :r_id]
    @test GenX.ids_with_policy(gen, GenX.min_cap_stor, tag = 1) ==
          dfVRE_STOR[dfVRE_STOR.mincaptagstor_1 .== 1, :r_id]
    @test GenX.ids_with_policy(gen, GenX.max_cap_solar, tag = 1) ==
          dfVRE_STOR[dfVRE_STOR.maxcaptagsolar_1 .== 1, :r_id]
    @test GenX.ids_with_policy(gen, GenX.max_cap_wind, tag = 1) ==
          dfVRE_STOR[dfVRE_STOR.maxcaptagwind_1 .== 1, :r_id]
    @test GenX.ids_with_policy(gen, GenX.max_cap_stor, tag = 1) ==
          dfVRE_STOR[dfVRE_STOR.maxcaptagstor_1 .== 1, :r_id]

    # inputs keys
    @test inputs["VRE_STOR"] == dfGen[dfGen.vre_stor .== 1, :r_id]
    @test inputs["VS_SOLAR"] == dfVRE_STOR[(dfVRE_STOR.solar .!= 0), :r_id]
    @test inputs["VS_WIND"] == dfVRE_STOR[(dfVRE_STOR.wind .!= 0), :r_id]
    @test inputs["VS_DC"] == union(dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .>= 1, :r_id],
        dfVRE_STOR[dfVRE_STOR.stor_dc_charge .>= 1, :r_id],
        dfVRE_STOR[dfVRE_STOR.solar .!= 0, :r_id])

    @test inputs["VS_STOR"] == union(dfVRE_STOR[dfVRE_STOR.stor_dc_charge .>= 1, :r_id],
        dfVRE_STOR[dfVRE_STOR.stor_ac_charge .>= 1, :r_id],
        dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .>= 1, :r_id],
        dfVRE_STOR[dfVRE_STOR.stor_ac_discharge .>= 1, :r_id])
    STOR = inputs["VS_STOR"]
    @test inputs["VS_STOR_DC_DISCHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_dc_discharge .>= 1), :r_id]
    @test inputs["VS_SYM_DC_DISCHARGE"] ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .== 1, :r_id]
    @test inputs["VS_ASYM_DC_DISCHARGE"] ==
          dfVRE_STOR[dfVRE_STOR.stor_dc_discharge .== 2, :r_id]
    @test inputs["VS_STOR_DC_CHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_dc_charge .>= 1), :r_id]
    @test inputs["VS_SYM_DC_CHARGE"] == dfVRE_STOR[dfVRE_STOR.stor_dc_charge .== 1, :r_id]
    @test inputs["VS_ASYM_DC_CHARGE"] == dfVRE_STOR[dfVRE_STOR.stor_dc_charge .== 2, :r_id]
    @test inputs["VS_STOR_AC_DISCHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_ac_discharge .>= 1), :r_id]
    @test inputs["VS_SYM_AC_DISCHARGE"] ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_discharge .== 1, :r_id]
    @test inputs["VS_ASYM_AC_DISCHARGE"] ==
          dfVRE_STOR[dfVRE_STOR.stor_ac_discharge .== 2, :r_id]
    @test inputs["VS_STOR_AC_CHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_ac_charge .>= 1), :r_id]
    @test inputs["VS_SYM_AC_CHARGE"] == dfVRE_STOR[dfVRE_STOR.stor_ac_charge .== 1, :r_id]
    @test inputs["VS_ASYM_AC_CHARGE"] == dfVRE_STOR[dfVRE_STOR.stor_ac_charge .== 2, :r_id]
    @test inputs["VS_LDS"] == dfVRE_STOR[(dfVRE_STOR.lds_vre_stor .!= 0), :r_id]
    @test inputs["VS_nonLDS"] == setdiff(STOR, inputs["VS_LDS"])
    @test inputs["VS_ASYM"] == union(inputs["VS_ASYM_DC_CHARGE"],
        inputs["VS_ASYM_DC_DISCHARGE"],
        inputs["VS_ASYM_AC_DISCHARGE"],
        inputs["VS_ASYM_AC_CHARGE"])
    @test inputs["VS_SYM_DC"] ==
          intersect(inputs["VS_SYM_DC_CHARGE"], inputs["VS_SYM_DC_DISCHARGE"])
    @test inputs["VS_SYM_AC"] ==
          intersect(inputs["VS_SYM_AC_CHARGE"], inputs["VS_SYM_AC_DISCHARGE"])

    buildable = dfGen[dfGen.new_build .== 1, :r_id]
    retirable = dfGen[dfGen.can_retire .== 1, :r_id]
    @test inputs["NEW_CAP_SOLAR"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.solar .!= 0, :r_id],
        dfVRE_STOR[dfVRE_STOR.max_cap_solar_mw .!= 0, :r_id])
    @test inputs["RET_CAP_SOLAR"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.solar .!= 0, :r_id],
        dfVRE_STOR[dfVRE_STOR.existing_cap_solar_mw .>= 0, :r_id])
    @test inputs["NEW_CAP_WIND"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.wind .!= 0, :r_id],
        dfVRE_STOR[dfVRE_STOR.max_cap_wind_mw .!= 0, :r_id])
    @test inputs["RET_CAP_WIND"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.wind .!= 0, :r_id],
        dfVRE_STOR[dfVRE_STOR.existing_cap_wind_mw .>= 0, :r_id])
    @test inputs["NEW_CAP_DC"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.max_cap_inverter_mw .!= 0, :r_id],
        inputs["VS_DC"])
    @test inputs["RET_CAP_DC"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.existing_cap_inverter_mw .>= 0, :r_id],
        inputs["VS_DC"])
    @test inputs["NEW_CAP_STOR"] ==
          intersect(buildable, dfGen[dfGen.max_cap_mwh .!= 0, :r_id], inputs["VS_STOR"])
    @test inputs["RET_CAP_STOR"] == intersect(retirable,
        dfGen[dfGen.existing_cap_mwh .>= 0, :r_id],
        inputs["VS_STOR"])
    @test inputs["NEW_CAP_CHARGE_DC"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.max_cap_charge_dc_mw .!= 0, :r_id],
        inputs["VS_ASYM_DC_CHARGE"])
    @test inputs["RET_CAP_CHARGE_DC"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.existing_cap_charge_dc_mw .>= 0, :r_id],
        inputs["VS_ASYM_DC_CHARGE"])
    @test inputs["NEW_CAP_DISCHARGE_DC"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.max_cap_discharge_dc_mw .!= 0, :r_id],
        inputs["VS_ASYM_DC_DISCHARGE"])
    @test inputs["RET_CAP_DISCHARGE_DC"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.existing_cap_discharge_dc_mw .>= 0, :r_id],
        inputs["VS_ASYM_DC_DISCHARGE"])
    @test inputs["NEW_CAP_CHARGE_AC"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.max_cap_charge_ac_mw .!= 0, :r_id],
        inputs["VS_ASYM_AC_CHARGE"])
    @test inputs["RET_CAP_CHARGE_AC"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.existing_cap_charge_ac_mw .>= 0, :r_id],
        inputs["VS_ASYM_AC_CHARGE"])
    @test inputs["NEW_CAP_DISCHARGE_AC"] == intersect(buildable,
        dfVRE_STOR[dfVRE_STOR.max_cap_discharge_ac_mw .!= 0, :r_id],
        inputs["VS_ASYM_AC_DISCHARGE"])
    @test inputs["RET_CAP_DISCHARGE_AC"] == intersect(retirable,
        dfVRE_STOR[dfVRE_STOR.existing_cap_discharge_ac_mw .>= 0, :r_id],
        inputs["VS_ASYM_AC_DISCHARGE"])
    @test inputs["RESOURCE_NAMES_VRE_STOR"] ==
          collect(skipmissing(dfVRE_STOR[!, :resource][1:size(inputs["VRE_STOR"])[1]]))
    @test inputs["RESOURCE_NAMES_SOLAR"] == dfVRE_STOR[(dfVRE_STOR.solar .!= 0), :resource]
    @test inputs["RESOURCE_NAMES_WIND"] == dfVRE_STOR[(dfVRE_STOR.wind .!= 0), :resource]
    @test inputs["RESOURCE_NAMES_DC_DISCHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_dc_discharge .!= 0), :resource]
    @test inputs["RESOURCE_NAMES_AC_DISCHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_ac_discharge .!= 0), :resource]
    @test inputs["RESOURCE_NAMES_DC_CHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_dc_charge .!= 0), :resource]
    @test inputs["RESOURCE_NAMES_AC_CHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_ac_charge .!= 0), :resource]
    @test inputs["ZONES_SOLAR"] == dfVRE_STOR[(dfVRE_STOR.solar .!= 0), :zone]
    @test inputs["ZONES_WIND"] == dfVRE_STOR[(dfVRE_STOR.wind .!= 0), :zone]
    @test inputs["ZONES_DC_DISCHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_dc_discharge .!= 0), :zone]
    @test inputs["ZONES_AC_DISCHARGE"] ==
          dfVRE_STOR[(dfVRE_STOR.stor_ac_discharge .!= 0), :zone]
    @test inputs["ZONES_DC_CHARGE"] == dfVRE_STOR[(dfVRE_STOR.stor_dc_charge .!= 0), :zone]
    @test inputs["ZONES_AC_CHARGE"] == dfVRE_STOR[(dfVRE_STOR.stor_ac_charge .!= 0), :zone]
end

with_logger(ConsoleLogger(stderr, Logging.Warn)) do
    test_load_resources_data()
    test_load_VRE_STOR_data()
end

end # module TestLoadResourceData
