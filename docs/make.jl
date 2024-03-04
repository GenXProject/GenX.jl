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
        "GenX: Introduction" => "index.md",
        "Installation Guide" => "installation.md",
        "Limitation of GenX" => "limitations_genx.md",
        "Third Party Extensions" => "third_party_genx.md"
    ],
    "Getting Started" => [
        "Running GenX" => "examples_casestudies.md",
        "Commertial solvers" => "commercial_solvers.md",
    ],
    "User Guide" => [
        "Overall workflow" => "workflow.md",
        "Model Configuration" => "model_configuration.md",
        "Solver Configuration" => "solver_configuration.md",
        "Model Inputs" => "model_input.md",
        "TDR Inputs" => "TDR_input.md",
        "Running the TDR" => "running_TDR.md",
        "MGA package" => "generate_alternatives.md",
        "Multi-stage Model" => "multi_stage_input.md",
        "Method of Morris Inputs" => "methodofmorris_input.md",
        "Running the Model" => "running_model.md",
        "Model Outputs" => "model_output.md",
    ],
    "Model Concept and Overview" => [
        "Model Introduction" => "model_introduction.md",
        "Notation" => "model_notation.md",
        "Objective Function" => "objective_function.md",
        "Power Balance" => "power_balance.md",
        "Slack Variables for Policies" => "slack_variables_overview.md",
        "Maintenance" => "maintenance_overview.md",
        "Time Domain Reduction" => "TDR_overview.md",
        "Multi-Stage Modeling" => "multi_stage_overview.md",
    ],
    "Model Reference" => [
        "Core" => "core.md",
        "Resources" => [
            "Curtailable Variable Renewable" => "curtailable_variable_renewable.md",
            "Flexible Demand" => "flexible_demand.md",
            "Hydro" => [
                "Hydro Reservoir" => "hydro_res.md",
                "Long Duration Hydro" => "hydro_inter_period_linkage.md"
            ],
            "Must Run" => "must_run.md",
            "Storage" => [
                "Storage" => "storage.md",
                "Investment Charge" => "investment_charge.md",
                "Investment Energy" => "investment_energy.md",
                "Long Duration Storage" => "long_duration_storage.md",
                "Storage All" => "storage_all.md",
                "Storage Asymmetric" => "storage_asymmetric.md",
                "Storage Symmetric" => "storage_symmetric.md"
            ],
            "Co-located VRE and Storage" => "vre_stor.md",
            "Thermal" => [
                "Thermal" => "thermal.md",
                "Thermal Commit" => "thermal_commit.md",
                "Thermal No Commit" => "thermal_no_commit.md"
            ],
            "Hydrogen Electrolyzers" => "electrolyzers.md",
            "Retrofit" => "retrofit.md",
            "Resources API" => "resources.md",
            "Scheduled maintenance for various resources" => "maintenance.md",
            "Resource types" => "resource.md"
        ],
        "Policies" => "policies.md",
        "Solver Configurations" => "solver_configuration_api.md",
        "Inputs Functions" => "load_inputs.md",
        "Utility Functions" => "utility_functions.md",
        "TDR" => "TDR.md",
        "Multi-stage" => [
            "Configure multi-stage inputs" => "configure_multi_stage_inputs.md",
            "Model multi stage: Dual Dynamic Programming Algorithm" => "dual_dynamic_programming.md",
            "Endogenous Retirement" => "endogenous_retirement.md"
        ],
    ],
    "Public API Reference" => [
        "Public API" => "public_api.md",
        "Solving the Model" => "solve_model.md",
        "Outputs Functions" => "write_outputs.md",
        "Modeling to Generate Alternatives" => "mga.md",
        "Method of Morris" => "methodofmorris.md",
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
