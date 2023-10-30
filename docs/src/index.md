# GenX Documentation
Welcome to the GenX documentation! 

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
Pages = ["workflow.md",
        "model_input.md",
        "TDR_input.md",
        "running_TDR.md",
        "multi_stage_input.md",
        "methodofmorris_input.md",
        "model_configuration.md",
        "solver_configuration.md",
        "running_model.md",
        "running_genx.md",
        "commercial_solvers.md",
        "generate_alternatives.md",
        "model_output.md",
        "model_introduction.md",
        "model_notation.md",
        "objective_function.md",
        "power_balance.md",
        "slack_variables_overview.md",
        "TDR_overview.md",
        "multi_stage_overview.md",
        "additional_third_party_extensions.md"]
Depth = 2
``` 

## Index

```@index
Pages = ["core.md",
        "curtailable_variable_renewable.md",
        "flexible_demand.md",
        "hydro_res.md",
        "hydro_inter_period_linkage.md",
        "must_run.md",
        "storage.md",
        "investment_charge.md",
        "investment_energy.md",
        "long_duration_storage.md",
        "storage_all.md",
        "storage_asymmetric.md",
        "storage_symmetric.md",
        "vre_stor.md",
        "thermal.md",
        "thermal_commit.md",
        "thermal_no_commit.md",
        "electrolyzers.md",
        "maintenance.md",
        "policies.md",
        "solver_configuration.md",
        "load_inputs.md",
        "TDR.md",
        "configure_multi_stage_inputs.md",
        "dual_dynamic_programming.md",
        "solve_model.md",
        "mga.md",
        "methodofmorris.md",
        "write_outputs.md"]
```

## License

GenX is released under the General Public License, GPL-2.0
