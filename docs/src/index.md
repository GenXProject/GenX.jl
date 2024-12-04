```@raw html
<img class="light-style-only" width="600" src="assets/logo.svg" style="padding-left: 50px; padding-top: 20px; "/>
<img class="dark-style-only" width="600" src="assets/logo-dark.svg" style="padding-left: 50px; padding-top: 20px; "/>
```

### Welcome to the GenX documentation! 

## What is GenX?

GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape.

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by [Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by [a team of contributors](https://energy.mit.edu/genx/#team) at the Princeton University ZERO Lab (led by Jenkins), MIT (led by [Ruaridh MacDonald](https://energy.mit.edu/profile/ruaridh-macdonald/)), NYU (led by [Dharik Mallapragada](https://engineering.nyu.edu/faculty/dharik-mallapragada)), and Binghamton University (led by [Neha Patankar](https://www.binghamton.edu/ssie/people/profile.html?id=npatankar)). 

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning. See the **User Guide** for more information on how to use GenX and the **Developer Guide** for more information on how to contribute to GenX.

## Uses

From a centralized planning perspective, the GenX model can help to determine the investments needed to supply future electricity demand at minimum cost, as is common in least-cost utility planning or integrated resource planning processes. In the context of liberalized markets, the model can be used by regulators and policy makers for indicative energy planning or policy analysis in order to establish a long-term vision of efficient market and policy outcomes. The model can also be used for techno-economic assessment of emerging electricity generation, storage, and demand-side resources and to enumerate the effect of parametric uncertainty (e.g., technology costs, fuel costs, demand, policy decisions) on the system-wide value or role of different resources.

## Roadmap of the Documentation: A Guide for the Users and Developers

This section provides a quick guidance as to how to navigate through the different parts of the documentation pages; what the different sections contain, and how to relate it to the different parts of the GenX code-base. 

This page serves as a gentle introduction to what GenX is meant for and what it does. 

The next subsection, [Installation Guide](@ref) goes over how to download and install GenX and also how to download and install the Julia programming language (in which GenX is written) and the different open-source non-commercial freely available solvers, as well as the commercial solvers and the respective JuMP interfaces. This subsection also goes over installing the environment dependencies and instantiating a virtual environment.

We also mention the shortcomings of GenX and some third party extentions in the next couple subsections

The next section is **Getting Started** goes over [Running GenX](@ref) and has two subsections. The first subsection, [Example cases](@ref), gives a walkthrough through some predefined example systems and how to run GenX for those and interpret the results. It also tells how to run GenX for a user-defined case. The subsection [Using commercial solvers: Gurobi or CPLEX](@ref) talks specifically about how to run GenX with commercial solvers like Gurobi and CPLEX that are absolutely indispensable for solving large cases. 

The third section, **Tutorial** starts with [GenX Tutorials](@ref) and gives a comprehensive tour of the different steps that are involved when a GenX capacity expansion simulation is run. It consists of 6 tutorial sections, each of which highlights the different important aspects of model construction and run of GenX. The different sections are configuring the GenX settings, visualizing the network, time domain reduction, generating the model, solving the model, and adjusting the different solver settings.

The **User Guide**, which the fourth section ([User Guide](@ref)) goes into the depths and details of the different steps and the settings and input parameters from the previous Tutorial section. The sections starts off with an overview of the workflow in GenX, briefing about the different steps (some of which we encountered in the Tutorials) of running GenX model. It then explains the different parameters of settings, policy, time-domain reduction, model structure, and output. Following this, the next subsection explains the different solver settings parameters of the different solvers. The next subsection goes over the different input CSV files and the different fields that are used there. The following two subsections are devoted to Time Domain Reduction (TDR). The first one walks through and explains the different settings parameters for TDR and the second one explains the couple different ways to run TDR for GenX and what exactly happens when we run TDR. The next four subsections, respectively, explains the different parameters, inputs, and outputs, and what happens when Modeling to Generate Alternatives (MGA), Multi-stage model, slack variables for policies (when we want to satisfy policy constraints in a soft manner by adding penalty of violation in the objective function), and Method of Morris. Finally, the last two sections are about the different steps involved while solving the model and the explanation of different output fields for both the default settings and user-specific settings. 

The **Model Concept and Overview** section first introduces the GenX model in [GenX Model Introduction](@ref) and talks about its scope. It also introduces the notations, the objective function, and the power balance constraints. This is the first section which delves into the theoretical and mathematical details of the model, which is the most important one for model developers.

The **Model Reference**, which is the sixth section delves deep into the GenX model and introduces the mathematical formulation, while discussing the physical interpretations of all the different parts of the GenX model. This section starts off with discussing the [Core](@ref) of the model, which models the Discharge, Non-Served Energy, Operational Reserves, Transmission, Unit Commitment, CO2, and Fuel. The different parts of the model consists of the different tyoe of generating resources (thermal, hydro, VRE, storage etc.), transmission network (modeling of flows as well as losses), demand modeling, operating reserves, unit commitment, different policies (such as CO2 constraint, capacity reserve margin, energy share requirement, min and max cap requirement etc.). This section also mentions about the different Julia functions (or methods) used for loading the input files, building the model, solving it, and generating the output files. Also, this is the section that explains the internal details of the Julia functions used for TDR, MGA, Method of Morris, Multi-stage modeling, and the several utility functions used throughout the GenX code-base. 

The seventh section, **Public API Reference** [Public Documentation](@ref) is for describing the functions that are directly accessible to an external program from GenX (like loading inputs, generating output, running TDR script etc.) and how an external "client" code can access the GenX features, if the user desires to run his/her own code instead of the Run.jl provided by us.

The eighth section, **Third Party Extension** [Additional Third Party Extensions to GenX](@ref) mentions about Pygenx, a Python interface for GenX, that was built by Daniel Olsen and GenX case runner for automated batch running, built by Jacob Schwartz.

Finally, the ninth and last section, **Developer Docs** [How to contribute to GenX](@ref) talks about the resource organization in GenX, how to add a new user-defined resource, and also several JuMP functions that are used as utility throughout the GenX code-base. 





## How to cite GenX

We recommend users of GenX to cite it in their academic publications and patent filings. Here's the text to put up as the citation for GenX:
`MIT Energy Initiative and Princeton University ZERO lab. [GenX](https://github.com/GenXProject/GenX): a configurable power system capacity expansion model for studying low-carbon energy futures n.d. https://github.com/GenXProject/GenX`.

## Acknowledgement
The GenX team expresses deep gratitude to [Maya Mutic](https://github.com/mmutic) for developing the tutorials along with Filippo Pecci and Luca Bonaldo. 
The Julia-themed GenX logo was designed by Laura Zwanziger and Jacob Schwartz.

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