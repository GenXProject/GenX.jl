<div align="center"> <img src="docs/src/assets/logo_readme.svg"  height ="200"width="1000" alt="GenX.jl"></img></div>

|  **Documentation** | **DOI** |
|:-------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://genxproject.github.io/GenX.jl/stable/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://genxproject.github.io/GenX.jl/dev) | [![DOI](https://zenodo.org/badge/368957308.svg)](https://zenodo.org/doi/10.5281/zenodo.10846069) 

[![CI](https://github.com/GenXProject/GenX/actions/workflows/ci.yml/badge.svg)](https://github.com/GenXProject/GenX/actions/workflows/ci.yml) [![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle) [![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

## Overview
GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model 
that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape. 

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by 
[Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and 
[Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by 
[a team of contributors](https://github.com/GenXProject/GenX#genx-team) at the Princeton University ZERO Lab (led by Jenkins), MIT (led by [Ruaridh MacDonald](https://energy.mit.edu/profile/ruaridh-macdonald/)), NYU (led by [Dharik Mallapragada](https://engineering.nyu.edu/faculty/dharik-mallapragada)), and Binghamton University (led by [Neha Patankar](https://www.binghamton.edu/ssie/people/profile.html?id=npatankar)).

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, 
storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost,
while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/).
The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning.
Depending on the planning problem or question to be studied,
GenX can be configured with varying levels of model resolution and scope, with regards to:
(1) temporal resolution of time series data such as electricity demand and renewable energy availability;
(2) power system operational detail and unit commitment constraints;
and (3) geospatial resolution and transmission network representation.
The model is also capable of representing a full range of conventional and novel electricity resources,
including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators,
energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

The 'main' branch is the current master branch of GenX. The various subdirectories are described below:

1. `src/` Contains the core GenX model code for reading inputs, model generation, solving and writing model outputs.

2. `example_systems/` Contains fully specified examples that users can use to test GenX and get familiar with its various features. 

3. `docs/` Contains source files for documentation pertaining to the model.

## Requirements

GenX (v0.4.1) runs on Julia v1.6 through v1.9, with a minimum version of the package JuMP v1.1.1. Julia v1.10 is also supported. However, we recently noticed a decline in performance with Julia v1.10, which is currently under investigation. Therefore, **we recommend using Julia v1.9**, particularly for very large cases.
We recommend the users to either stick to a particular version of Julia to run GenX. If however, the users decide to switch between versions, it's very important to delete the old `Manifest.toml` file and do a fresh build of GenX when switching between Julia versions.

There is also an older version of GenX, which is also currently maintained and runs on Julia 1.3.x and 1.4.x series.
For those users who has previously cloned GenX, and has been running it successfully so far,
and therefore might be unwilling to run it on the latest version of Julia:
please look into the GitHub branch, [old_version](https://github.com/GenXProject/GenX/tree/old_version).
It is currently setup to use one of the following open-source freely available solvers:
- the default solver: [HiGHS](https://github.com/jump-dev/HiGHS.jl) for linear programming and MILP,
- [Clp](https://github.com/jump-dev/Clp.jl) for linear programming (LP) problems,
- [Cbc](https://github.com/jump-dev/Cbc.jl) for mixed integer linear programming (MILP) problems
We also provide the option to use one of these two commercial solvers: 
- [Gurobi](https://www.gurobi.com), or 
- [CPLEX](https://www.ibm.com/docs/en/icos/22.1.1?topic=documentation-orientation-guide).
Note that using Gurobi and CPLEX requires a valid license on the host machine.
There are two ways to run GenX with either type of solver options (open-source free or, licensed commercial) as detailed in the section, `Getting Started`.


## Documentation

Detailed documentation for GenX can be found [here](https://genxproject.github.io/GenX.jl/dev).
It includes details of each of GenX's methods, required and optional input files, and outputs.
Interested users may also want to browse through [prior publications](https://energy.mit.edu/genx/#publications) that have used GenX to understand the various features of the tool.


## How to cite GenX

We request that users of GenX to cite it in their academic publications and patent filings.

```
MIT Energy Initiative and Princeton University ZERO lab. GenX: a configurable power system capacity expansion model for studying low-carbon energy futures n.d. https://github.com/GenXProject/GenX
```

## Bug and feature requests and contact info
If you would like to report a bug in the code or request a feature, please use our [Issue Tracker](https://github.com/GenXProject/GenX/issues).
If you're unsure or have questions on how to use GenX that are not addressed by the above documentation, please reach out to Sambuddha Chakrabarti (sc87@princeton.edu), Jesse Jenkins (jdj2@princeton.edu) or Dharik Mallapragada (dharik@mit.edu).

## GenX Team
GenX has been developed jointly by researchers at the [MIT Energy Initiative](https://energy.mit.edu/) and the ZERO lab at Princeton University.
Key contributors include [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/),
[Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins),
[Dharik S. Mallapragada](https://energy.mit.edu/profile/dharik-mallapragada/),
[Aaron M. Schwartz](https://idss.mit.edu/staff/aaron-schwartz/),
[Neha S. Patankar](https://www.linkedin.com/in/nehapatankar),
[Qingyu Xu](https://www.linkedin.com/in/qingyu-xu-61b3567b),
[Jack Morris](https://www.linkedin.com/in/jack-morris-024b37121),
[Luca Bonaldo](https://www.linkedin.com/in/luca-bonaldo-56391719b/)
[Sambuddha Chakrabarti](https://www.linkedin.com/in/sambuddha-chakrabarti-ph-d-84157318).

## Acknowledgement
The GenX team expresses deep gratitude to [Maya Mutic](https://github.com/mmutic) for developing the tutorials along with Filippo Pecci and Luca Bonaldo. 
The Julia-themed GenX logo was designed by Laura Zwanziger and Jacob Schwartz.
