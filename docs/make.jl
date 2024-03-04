push!(LOAD_PATH, "../src/")
import DataStructures: OrderedDict
using GenX
using Documenter
DocMeta.setdocmeta!(GenX, :DocTestSetup, :(using GenX); recursive=true)
println(pwd())
genx_docpath = joinpath(pwd(), "docs/src")
push!(LOAD_PATH, genx_docpath)
pages = OrderedDict(
    "Welcome Page" => [
        "GenX: Introduction" => "Welcome_Page/index.md",
        "Installation Guide" => "Welcome_Page/installation.md",
        "Limitation of GenX" => "Welcome_Page/limitations_genx.md",
        "Third Party Extensions" => "Welcome_Page/third_party_genx.md"
    ],
    "Getting Started" => [
        "Running GenX" => "Getting_Started/examples_casestudies.md",
        "Commertial solvers" => "Getting_Started/commercial_solvers.md",
    ],
    "User Guide" => [
        "Overall workflow" => "User_Guide/workflow.md",
        "Model Configuration" => "User_Guide/model_configuration.md",
        "Solver Configuration" => "User_Guide/solver_configuration.md",
        "Model Inputs" => "User_Guide/model_input.md",
        "TDR Inputs" => "User_Guide/TDR_input.md",
        "Running the TDR" => "User_Guide/running_TDR.md",
        "MGA package" => "User_Guide/generate_alternatives.md",
        "Multi-stage Model" => "User_Guide/multi_stage_input.md",
        "Method of Morris Inputs" => "User_Guide/methodofmorris_input.md",
        "Running the Model" => "User_Guide/running_model.md",
        "Model Outputs" => "User_Guide/model_output.md",
    ],
    "Model Concept and Overview" => [
        "Model Introduction" => "Model_Concept_Overview/model_introduction.md",
        "Notation" => "Model_Concept_Overview/model_notation.md",
        "Objective Function" => "Model_Concept_Overview/objective_function.md",
        "Power Balance" => "Model_Concept_Overview/power_balance.md",
        "Slack Variables for Policies" => "Model_Concept_Overview/slack_variables_overview.md",
        "Maintenance" => "Model_Concept_Overview/maintenance_overview.md",
        "Time Domain Reduction" => "Model_Concept_Overview/TDR_overview.md",
        "Multi-Stage Modeling" => "Model_Concept_Overview/multi_stage_overview.md",
    ],
    "Model Reference" => [
        "Core" => "Model_Reference/core.md",
        "Resources" => [
            "Curtailable Variable Renewable" => "Model_Reference/Resources/curtailable_variable_renewable.md",
            "Flexible Demand" => "Model_Reference/Resources/flexible_demand.md",
            "Hydro" => [
                "Hydro Reservoir" => "Model_Reference/Resources/hydro_res.md",
                "Long Duration Hydro" => "Model_Reference/Resources/hydro_inter_period_linkage.md"
            ],
            "Must Run" => "Model_Reference/Resources/must_run.md",
            "Storage" => [
                "Storage" => "Model_Reference/Resources/storage.md",
                "Investment Charge" => "Model_Reference/Resources/investment_charge.md",
                "Investment Energy" => "Model_Reference/Resources/investment_energy.md",
                "Long Duration Storage" => "Model_Reference/Resources/long_duration_storage.md",
                "Storage All" => "Model_Reference/Resources/storage_all.md",
                "Storage Asymmetric" => "Model_Reference/Resources/storage_asymmetric.md",
                "Storage Symmetric" => "Model_Reference/Resources/storage_symmetric.md"
            ],
            "Co-located VRE and Storage" => "Model_Reference/Resources/vre_stor.md",
            "Thermal" => [
                "Thermal" => "Model_Reference/Resources/thermal.md",
                "Thermal Commit" => "Model_Reference/Resources/thermal_commit.md",
                "Thermal No Commit" => "Model_Reference/Resources/thermal_no_commit.md"
            ],
            "Hydrogen Electrolyzers" => "Model_Reference/Resources/electrolyzers.md",
            "Retrofit" => "Model_Reference/Resources/retrofit.md",
            "Resources API" => "Model_Reference/Resources/resources.md",
            "Scheduled maintenance for various resources" => "Model_Reference/Resources/maintenance.md",
            "Resource types" => "Model_Reference/Resources/resource.md"
        ],
        "Policies" => "Model_Reference/policies.md",
        "Solver Configurations" => "Model_Reference/solver_configuration_api.md",
        "Inputs Functions" => "Model_Reference/load_inputs.md",
        "Utility Functions" => "Model_Reference/utility_functions.md",
        "TDR" => "Model_Reference/TDR.md",
        "Multi-stage" => [
            "Configure multi-stage inputs" => "Model_Reference/Multi_Stage/configure_multi_stage_inputs.md",
            "Model multi stage: Dual Dynamic Programming Algorithm" => "Model_Reference/Multi_Stage/dual_dynamic_programming.md",
            "Endogenous Retirement" => "Model_Reference/Multi_Stage/endogenous_retirement.md"
        ],
    ],
    "Public API Reference" => [
        "Public API" => "Public_API/public_api.md",
        "Solving the Model" => "Public_API/solve_model.md",
        "Outputs Functions" => "Public_API/write_outputs.md",
        "Modeling to Generate Alternatives" => "Public_API/mga.md",
        "Method of Morris" => "Public_API/methodofmorris.md",
    ],
    "Third Party Extensions" => "additional_third_party_extensions.md",
    "Developer Docs" => "developer_guide.md",
)
makedocs(;
    modules=[GenX],
    authors="Jesse Jenkins, Nestor Sepulveda, Dharik Mallapragada, Aaron Schwartz, Neha Patankar, Qingyu Xu, Jack Morris, Sambuddha Chakrabarti",
    sitename="GenX",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://github.com/lbonaldo/GenX/stable",
        assets=String[],
        collapselevel=1
    ),
    pages=[p for p in pages],
    warnonly=true
)

# deploydocs(;
#     repo="github.com/GenXProject/GenX.git",
#     target = "build",
#     branch = "gh-pages",
#     devbranch = "main",
#     devurl = "dev",
#     push_preview=true,
#     versions = ["stable" => "v^", "v#.#"],
#     forcepush = false,
# )
