using Documenter
using GenX
import DataStructures: OrderedDict

DocMeta.setdocmeta!(GenX, :DocTestSetup, :(using GenX); recursive = true)

pages = OrderedDict(
    "Welcome Page" => [
        "GenX: Introduction" => "index.md",
        "Installation Guide" => "installation.md",
        "Limitation of GenX" => "limitations_genx.md",
        "Third Party Extensions" => "third_party_genx.md"
    ],
    "Getting Started" => [
        "Running GenX" => "Getting_Started/examples_casestudies.md",
        "Commertial solvers" => "Getting_Started/commercial_solvers.md"
    ],
    "Tutorials" => [
        "Tutorials Overview" => "Tutorials/Tutorials_intro.md",
        "Tutorial 1: Configuring Settings" => "Tutorials/Tutorial_1_configuring_settings.md",
        "Tutorial 2: Network Visualization" => "Tutorials/Tutorial_2_network_visualization.md",
        "Tutorial 3: K-Means and Time Domain Reduction" => "Tutorials/Tutorial_3_K-means_time_domain_reduction.md",
        "Tutorial 4: Model Generation" => "Tutorials/Tutorial_4_model_generation.md",
        "Tutorial 5: Solving the Model" => "Tutorials/Tutorial_5_solve_model.md",
        "Tutorial 6: Solver Settings" => "Tutorials/Tutorial_6_solver_settings.md",
        "Tutorial 7: Policy Constraints" => "Tutorials/Tutorial_7_setup.md",
        "Tutorial 8: Outputs" => "Tutorials/Tutorial_8_outputs.md"
    ],
    "User Guide" => [
        "Overall workflow" => "User_Guide/workflow.md",
        "Model Configuration" => "User_Guide/model_configuration.md",
        "Solver Configuration" => "User_Guide/solver_configuration.md",
        "Model Inputs" => "User_Guide/model_input.md",
        "Time-domain Reduction Inputs" => "User_Guide/TDR_input.md",
        "Running the Time-domain Reduction" => "User_Guide/running_TDR.md",
        "MGA package" => "User_Guide/generate_alternatives.md",
        "Multi-stage Model" => "User_Guide/multi_stage_input.md",
        "Slack Variables for Policies" => "User_Guide/slack_variables_overview.md",
        "Method of Morris Inputs" => "User_Guide/methodofmorris_input.md",
        "Running the Model" => "User_Guide/running_model.md",
        "Model Outputs" => "User_Guide/model_output.md"
    ],
    "Model Concept and Overview" => [
        "Model Introduction" => "Model_Concept_Overview/model_introduction.md",
        "Notation" => "Model_Concept_Overview/model_notation.md",
        "Objective Function" => "Model_Concept_Overview/objective_function.md",
        "Power Balance" => "Model_Concept_Overview/power_balance.md"
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
            "Retrofit" => "Model_Reference/Resources/retrofit.md",
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
            "Scheduled maintenance for various resources" => "Model_Reference/Resources/maintenance.md",
            "Resource types" => "Model_Reference/Resources/resource.md"
        ],
        "Maintenance" => "Model_Reference/maintenance_overview.md",
        "Policies" => "Model_Reference/policies.md",
        "Solver Configurations" => "Model_Reference/solver_configuration_api.md",
        "Inputs Functions" => "Model_Reference/load_inputs.md",
        "Generate the Model" => "Model_Reference/generate_model.md",
        "Solving the Model" => "Model_Reference/solve_model.md",
        "Time-domain Reduction" => "Model_Reference/TDR.md",
        "Outputs Functions" => "Model_Reference/write_outputs.md",
        "Modeling to Generate Alternatives" => "Model_Reference/mga.md",
        "Multi-stage" => [
            "Multi-Stage Modeling Introduction" => "Model_Reference/Multi_Stage/multi_stage_overview.md",
            "Configure multi-stage inputs" => "Model_Reference/Multi_Stage/configure_multi_stage_inputs.md",
            "Model multi stage: Dual Dynamic Programming Algorithm" => "Model_Reference/Multi_Stage/dual_dynamic_programming.md",
            "Endogenous Retirement" => "Model_Reference/Multi_Stage/endogenous_retirement.md"
        ],
        "Method of Morris" => "Model_Reference/methodofmorris.md",
        "Utility Functions" => "Model_Reference/utility_functions.md"
    ],
    "Public API Reference" => [
        "Public API" => "Public_API/public_api.md"],
    "Third Party Extensions" => "additional_third_party_extensions.md",
    "Developer Docs" => "developer_guide.md"
)

# Build documentation.
# ====================

makedocs(;
    modules = [GenX],
    authors = "Jesse Jenkins, Nestor Sepulveda, Dharik Mallapragada, Aaron Schwartz, Neha Patankar, Qingyu Xu, Jack Morris, Sambuddha Chakrabarti",
    sitename = "GenX.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://genxproject.github.io/GenX.jl/stable",
        assets = ["assets/genx_style.css"],
        sidebar_sitename = false,
        collapselevel = 1
    ),
    pages = [p for p in pages]
)

# Deploy built documentation.
# ===========================

deploydocs(;
    repo = "github.com/GenXProject/GenX.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "develop",
    devurl = "dev",
    push_preview = true,
    versions = ["stable" => "v^", "v#.#.#", "dev" => "dev"],
    forcepush = false
)
