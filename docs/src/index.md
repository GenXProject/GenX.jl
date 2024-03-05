```@raw html
<img class="display-light-only" width="600" src="assets/title.svg" style="padding-left: 50px; padding-top: 20px; display: block; border: none;"/>
<img class="display-dark-only" width="600" src="assets/title_white_text.svg" style="padding-left: 50px; padding-top: 20px; display: block; border: none;"/>
```

### Welcome to the GenX documentation! 

## What is GenX?

GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape.

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by [Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by [a team of contributors](https://energy.mit.edu/genx/#team) at the MIT Energy Initiative (led by [Dharik Mallapragada](https://mallapragada.mit.edu)) and the Princeton University ZERO Lab (led by Jenkins).

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning. See the **User Guide** for more information on how to use GenX.
```@meta
# and the **Developer Guide** for more information on how to contribute to GenX.
```

## Uses

From a centralized planning perspective, the GenX model can help to determine the investments needed to supply future electricity demand at minimum cost, as is common in least-cost utility planning or integrated resource planning processes. In the context of liberalized markets, the model can be used by regulators and policy makers for indicative energy planning or policy analysis in order to establish a long-term vision of efficient market and policy outcomes. The model can also be used for techno-economic assessment of emerging electricity generation, storage, and demand-side resources and to enumerate the effect of parametric uncertainty (e.g., technology costs, fuel costs, demand, policy decisions) on the system-wide value or role of different resources.

## How to cite GenX

We recommend users of GenX to cite it in their academic publications and patent filings. Here's the text to put up as the citation for GenX:
`MIT Energy Initiative and Princeton University ZERO lab. [GenX](https://github.com/GenXProject/GenX): a configurable power system capacity expansion model for studying low-carbon energy futures n.d. https://github.com/GenXProject/GenX.

## Package Manual

```@contents
Pages = ["User_Guide/workflow.md",
        "User_Guide/model_input.md",
        "User_Guide/TDR_input.md",
        "User_Guide/running_TDR.md",
        "User_Guide/multi_stage_input.md",
        "User_Guide/methodofmorris_input.md",
        "User_Guide/model_configuration.md",
        "User_Guide/solver_configuration.md",
        "User_Guide/running_model.md",
        "Getting_Started/commercial_solvers.md",
        "User_Guide/generate_alternatives.md",
        "User_Guide/model_output.md",
        "Model_Concept_Overview/model_introduction.md",
        "Model_Concept_Overview/model_notation.md",
        "Model_Concept_Overview/objective_function.md",
        "Model_Concept_Overview/power_balance.md",
        "Model_Concept_Overview/slack_variables_overview.md",
        "Model_Concept_Overview/TDR_overview.md",
        "Model_Concept_Overview/multi_stage_overview.md",
        "additional_third_party_extensions.md"]
Depth = 2
``` 

## License

GenX is released under the General Public License, GPL-2.0

## Index

```@index
Pages = ["Model_Reference/core.md",
        "Model_Reference/Resources/curtailable_variable_renewable.md",
        "Model_Reference/Resources/flexible_demand.md",
        "Model_Reference/Resources/hydro_res.md",
        "Model_Reference/Resources/hydro_inter_period_linkage.md",
        "Model_Reference/Resources/must_run.md",
        "Model_Reference/Resources/storage.md",
        "Model_Reference/Resources/investment_charge.md",
        "Model_Reference/Resources/investment_energy.md",
        "Model_Reference/Resources/long_duration_storage.md",
        "Model_Reference/Resources/storage_all.md",
        "Model_Reference/Resources/storage_asymmetric.md",
        "Model_Reference/Resources/storage_symmetric.md",
        "Model_Reference/Resources/vre_stor.md",
        "Model_Reference/Resources/thermal.md",
        "Model_Reference/Resources/thermal_commit.md",
        "Model_Reference/Resources/thermal_no_commit.md",
        "Model_Reference/Resources/electrolyzers.md",
        "Model_Reference/Resources/maintenance.md",
        "Model_Reference/policies.md",
        "User_Guide/solver_configuration.md",
        "Model_Reference/load_inputs.md",
        "Model_Reference/TDR.md",
        "Model_Reference/Multi_Stage/configure_multi_stage_inputs.md",
        "Model_Reference/Multi_Stage/dual_dynamic_programming.md",
        "Public_API/solve_model.md",
        "Public_API/mga.md",
        "Public_API/methodofmorris.md",
        "Public_API/write_outputs.md"]
```