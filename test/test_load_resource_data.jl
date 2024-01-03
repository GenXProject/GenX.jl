module TestLoadResourceData

using Test
using GenX
using JLD2


setup = Dict(
    "ParameterScale" => 1,
    "Reserves" => 1,
    "UCommit" => 2,
    "MultiStage" => 1,
    "ResourcePath" => "resources",
    "PolicyPath" => "policies",
)

test_path = "LoadResourceData"

function prepare_inputs_true()
    dfGen = GenX.load_dataframe(joinpath(test_path, "_generators_data.csv"))
    scale_factor = setup["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1
    GenX.rename!(dfGen, lowercase.(names(dfGen)))
    GenX.scale_resources_data!(dfGen, scale_factor)
    dfGen[!,:r_id] = 1:size(dfGen,1)
    inputs_true = load(joinpath(test_path, "inputs_after_loadgen.jld2"))
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
    @test GenX.resource_type.(gen) == dfGen.resource_type
    @test GenX.zone_id.(gen) == dfGen.zone

    @test GenX.max_capacity_mw.(gen) == dfGen.max_cap_mw
    @test GenX.min_capacity_mw.(gen) == dfGen.min_cap_mw
    @test GenX.min_capacity_mwh.(gen) == dfGen.min_cap_mwh

    @test GenX.existing_capacity_mw.(gen) == dfGen.existing_cap_mw
    @test GenX.existing_capacity_mwh.(gen) == dfGen.existing_cap_mwh

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
    @test GenX.ccs_disposal_cost_per_metric_ton.(gen) == dfGen.ccs_disposal_cost_per_metric_ton
    @test GenX.biomass.(gen) == dfGen.biomass

    @test GenX.has_mga_on(gen) == dfGen[dfGen.mga .== 1, :r_id]

    @test GenX.region.(gen) == dfGen.region
    @test GenX.cluster.(gen) == dfGen.cluster
end

function test_add_policies_to_resources(gen, dfGen)
    @test GenX.esr.(gen, tag=1) == dfGen.esr_1
    @test GenX.esr.(gen, tag=2) == dfGen.esr_2
    @test GenX.min_cap.(gen, tag=1) == dfGen.mincaptag_1
    @test GenX.min_cap.(gen, tag=2) == dfGen.mincaptag_2
    @test GenX.min_cap.(gen, tag=3) == dfGen.mincaptag_3
    @test GenX.derated_capacity.(gen, tag=1) == dfGen.capres_1
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
    @test inputs["Z"] == inputs_true["Z"]
    @test inputs["T"] == inputs_true["T"]
    @test inputs["L"] == inputs_true["L"]
    @test inputs["H"] == inputs_true["H"]

    @test inputs["VRE"] == inputs_true["VRE"]
    @test inputs["HYDRO_RES"] == inputs_true["HYDRO_RES"]
    @test inputs["HYDRO_RES_KNOWN_CAP"] == inputs_true["HYDRO_RES_KNOWN_CAP"]
    @test inputs["THERM_ALL"] == inputs_true["THERM_ALL"]
    @test inputs["THERM_COMMIT"] == inputs_true["THERM_COMMIT"]
    @test inputs["THERM_NO_COMMIT"] == inputs_true["THERM_NO_COMMIT"]
    @test inputs["FLEX"] == inputs_true["FLEX"]
    @test inputs["VRE_STOR"] == inputs_true["VRE_STOR"]
    @test inputs["COMMIT"] == inputs_true["COMMIT"]
    @test inputs["C_Start"] == inputs_true["C_Start"]
    @test inputs["STOR_ALL"] == inputs_true["STOR_ALL"]
    @test inputs["STOR_SYMMETRIC"] == inputs_true["STOR_SYMMETRIC"]
    @test inputs["STOR_ASYMMETRIC"] == inputs_true["STOR_ASYMMETRIC"]
    @test inputs["STOR_SHORT_DURATION"] == inputs_true["STOR_SHORT_DURATION"]
    @test inputs["STOR_LONG_DURATION"] == inputs_true["STOR_LONG_DURATION"]
    @test inputs["STOR_HYDRO_LONG_DURATION"] == inputs_true["STOR_HYDRO_LONG_DURATION"]
    @test Set(inputs["RET_CAP"]) == inputs_true["RET_CAP"]
    @test Set(inputs["RET_CAP_CHARGE"]) == inputs_true["RET_CAP_CHARGE"]
    @test Set(inputs["RET_CAP_ENERGY"]) == inputs_true["RET_CAP_ENERGY"]
    @test Set(inputs["NEW_CAP"]) == inputs_true["NEW_CAP"]
    @test Set(inputs["NEW_CAP_ENERGY"]) == inputs_true["NEW_CAP_ENERGY"]
    @test Set(inputs["NEW_CAP_CHARGE"]) == inputs_true["NEW_CAP_CHARGE"]
    @test inputs["RETRO"] == inputs_true["RETRO"]
    @test inputs["ELECTROLYZER"] == inputs_true["ELECTROLYZER"]
    # @test inputs["dfVRE_STOR"] == inputs_true["dfVRE_STOR"]
    @test inputs["MUST_RUN"] == inputs_true["MUST_RUN"]
    @test inputs["REG"] == inputs_true["REG"]
    @test inputs["RSV"] == inputs_true["RSV"]
    
    @test inputs["pNet_Map"] == inputs_true["pNet_Map"]
    @test inputs["pTrans_Max_Possible"] == inputs_true["pTrans_Max_Possible"]
    @test inputs["pTrans_Max"] == inputs_true["pTrans_Max"]
    @test inputs["pC_Line_Reinforcement"] == inputs_true["pC_Line_Reinforcement"]
    @test inputs["pTrans_Loss_Coef"] == inputs_true["pTrans_Loss_Coef"]
    @test inputs["pMax_Line_Reinforcement"] == inputs_true["pMax_Line_Reinforcement"]
    @test inputs["pC_D_Curtail"] == inputs_true["pC_D_Curtail"]
    @test inputs["LOSS_LINES"] == inputs_true["LOSS_LINES"]
    @test inputs["EXPANSION_LINES"] == inputs_true["EXPANSION_LINES"]
    @test inputs["TRANS_LOSS_SEGS"] == inputs_true["TRANS_LOSS_SEGS"]
    
    @test inputs["pD"] == inputs_true["pD"]
    @test inputs["SEG"] == inputs_true["SEG"]
    @test inputs["Voll"] == inputs_true["Voll"]
    @test inputs["omega"] == inputs_true["omega"]
    @test inputs["Weights"] == inputs_true["Weights"]
    @test inputs["REP_PERIOD"] == inputs_true["REP_PERIOD"]
    @test inputs["hours_per_subperiod"] == inputs_true["hours_per_subperiod"]
    @test inputs["START_SUBPERIODS"] == inputs_true["START_SUBPERIODS"]
    @test inputs["INTERIOR_SUBPERIODS"] == inputs_true["INTERIOR_SUBPERIODS"]
    @test inputs["NO_EXPANSION_LINES"] == inputs_true["NO_EXPANSION_LINES"]

    @test inputs["pMax_D_Curtail"] == inputs_true["pMax_D_Curtail"]
    @test inputs["slope_cols"] == inputs_true["slope_cols"]
    @test inputs["intercept_cols"] == inputs_true["intercept_cols"]
    @test inputs["PWFU_data"] == inputs_true["PWFU_data"]
    @test inputs["PWFU_Num_Segments"] == inputs_true["PWFU_Num_Segments"]
    @test inputs["THERM_COMMIT_PWFU"] == inputs_true["THERM_COMMIT_PWFU"]

    @test inputs["fuels"] == inputs_true["fuels"]
    @test inputs["fuel_CO2"] == inputs_true["fuel_CO2"]
    @test inputs["fuel_costs"] == inputs_true["fuel_costs"]
    @test inputs["pPercent_Loss"] == inputs_true["pPercent_Loss"]
    @test inputs["HAS_FUEL"] == inputs_true["HAS_FUEL"]
    
    @test inputs["R_ZONES"] == inputs_true["R_ZONES"]
    @test inputs["RESOURCE_ZONES"] == inputs_true["RESOURCE_ZONES"]
    @test inputs["RESOURCE_NAMES"] == inputs_true["RESOURCES"]
end

function test_resource_specific_attributes(gen, dfGen, inputs)
    # @test GenX.has_retrofit(gen) == dfGen[dfGen.retro .== 1, :r_id]   #TODO: fix this when retrofit is implemented
    @test GenX.is_buildable(gen) == dfGen[dfGen.new_build .== 1, :r_id]
    @test GenX.is_retirable(gen) == dfGen[dfGen.can_retire .== 1, :r_id]
    
    rs = GenX.has_positive_max_capacity_mwh(gen)
    @test rs == dfGen[dfGen.max_cap_mwh .> 0, :r_id]
    @test GenX.max_capacity_mwh.(rs) == dfGen[dfGen.max_cap_mwh .> 0, :r_id]
    rs = GenX.has_positive_max_charge_capacity_mw(gen)
    @test rs == dfGen[dfGen.max_charge_cap_mw .> 0, :r_id]
    @test GenX.max_charge_capacity_mw.(rs) == dfGen[dfGen.max_charge_cap_mw .> 0, :r_id]
    rs = GenX.has_unit_commitment(gen)
    @test rs == dfGen[dfGen.therm .== 1, :r_id]
    @test GenX.cap_size.(gen[rs]) == dfGen[dfGen.therm.==1,:cap_size]
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
    @test GenX.ramp_up_percentage.(gen[rs]) == dfGen[rs, :ramp_up_percentage]
    @test GenX.ramp_down_percentage.(gen[rs]) == dfGen[rs, :ramp_dn_percentage]
    rs = inputs["STOR_ASYMMETRIC"]
    @test GenX.max_charge_capacity_mw.(gen[rs]) == dfGen[rs, :max_charge_cap_mw]
    @test GenX.min_charge_capacity_mw.(gen[rs]) == dfGen[rs, :min_charge_cap_mw]
    @test GenX.existing_charge_capacity_mw.(gen[rs]) == dfGen[rs, :existing_charge_cap_mw]
    @test GenX.inv_cost_charge_per_mwyr.(gen[rs]) == dfGen[rs, :inv_cost_charge_per_mwyr]
    @test GenX.fixed_om_cost_charge_per_mwyr.(gen[rs]) == dfGen[rs, :fixed_om_cost_charge_per_mwyr]
    rs = union(inputs["HYDRO_RES_KNOWN_CAP"], inputs["STOR_HYDRO_LONG_DURATION"])
    @test GenX.hydro_energy_to_power_ratio.(gen[rs]) == dfGen[rs, :hydro_energy_to_power_ratio]
end

function test_load_resources_data()
    # load dfGen and inputs_true to compare against
    dfGen, inputs_true = prepare_inputs_true()

    # Test resource data is loaded correctly
    gen = GenX.load_scaled_resources_data(setup, test_path)
    @testset "Default fields" begin
        test_load_scaled_resources_data(gen, dfGen)
    end

    # Test policy fields are correctly added to the resource structs
    GenX.add_policies_to_resources!(setup, test_path, gen)
    @testset "Policy attributes" begin
        test_add_policies_to_resources(gen, dfGen)
    end

    # Test modules are correctly added to the resource structs
    GenX.add_modules_to_resources!(setup, test_path, gen)
    @testset "Module attributes" begin
        test_add_modules_to_resources(gen, dfGen)
    end

    # Test that the inputs keys are correctly setß
    inputs = load(joinpath(test_path, "inputs_before_loadgen.jld2"))
    GenX.add_resources_to_input_data!(setup, test_path, inputs, gen)
    @testset "Inputs keys" begin
        test_inputs_keys(inputs, inputs_true)
    end

    # Test that the resource-specific attributes are correctly set
    @testset "Resource-specific attributes" begin
        test_resource_specific_attributes(gen, dfGen, inputs)
    end
end

test_load_resources_data()

end # module TestLoadResourceData