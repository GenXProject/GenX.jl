# GenX Documentation

```@meta
CurrentModule = GenX
```

## Overview

GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape.

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by [Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by [a team of contributors](https://energy.mit.edu/genx/#team) at the MIT Energy Initiative (led by [Dharik Mallapragada](https://mallapragada.mit.edu)) and the Princeton University ZERO Lab (led by Jenkins).

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning. Depending on the planning problem or question to be studied, GenX can be configured with varying levels of model resolution and scope, with regards to: (1) temporal resolution of time series data such as electricity demand and renewable energy availability; (2) power system operational detail and unit commitment constraints; and (3) geospatial resolution and transmission network representation. The model is also capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

## Multi-stage investment planning

In addition to the standard **single-stage planning** mode, in which the produces a single snapshot of the minimum-cost generation capacity mix to meet demand at least cost under some pre-specified future conditions, recent improvements in the GenX source code (part of v0.3 release) enable its use for studying long-term evolution of the power system across multiple investment stages. More information of this feature can be found in the section on `Multi-stage` under the `Model function reference` tab. In brief, GenX can be used to study multi-stage power system planning in the following two ways: 
- The user can formulate and solve a deterministic **multi-stage planning problem with perfect foresight** i.e. demand, cost, and policy assumptions about all stages are known and exploited to determine the least-cost investment trajectory for the entire period. The solution of this multi-stage problem relies on exploiting the decomposable nature of the multi-stage problem via the implementation of the dual dynamic programming algorithm, described in [Lara et al. 2018 here](https://www.sciencedirect.com/science/article/abs/pii/S0377221718304466). 
- The user can formulate a **sequential, myopic multi-stage planning problem**, where the model solves a sequence of single-stage investment planning problems wherein investment decisions in each stage are individually optimized to meet demand given assumptions for the current planning stage and with investment decisions from previous stages treated as inputs for the current stage. We refer to this as "myopic" (or shortsighted) mode since the solution does not account for information about future stages in determining investments for a given stage. This version is generally more computationally efficient than the deterministic multi-stage expansion with perfect foresight mode.

## How to cite GenX

We recommend users of GenX to cite it in their academic publications and patent filings. Here's the text to put up as the citation for GenX:
`MIT Energy Initiative and Princeton University ZERO lab. [GenX](https://github.com/GenXProject/GenX): a configurable power system capacity expansion model for studying low-carbon energy futures n.d. https://github.com/GenXProject/GenX

