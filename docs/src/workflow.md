# User Guide

## Introduction
GenX is a constrained **linear** or **mixed integer linear optimization model** that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

Depending on the planning problem or question to be studied, GenX can be configured with varying levels of model resolution and scope, with regards to: 
1. Temporal resolution of time series data such as **electricity demand** and **renewable energy availability**; 
2. Power system **operational detail** and unit **commitment constraints**; 
3. **Geospatial resolution** and **transmission network** representation. 

The model is also capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

## Workflow
The flexibility of GenX is achieved through a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The software workflow includes two main steps: 

1. **Model configuration** and **building**: this step involves the specification of the planning problem to be studied, including time dependent data like electricity demand, renewable energy availability and fuel prices, number and type of resources included in the model, graph representation of the transmission network, and the set of constraints and objectives to be imposed.

2. **Model execution**: once the model is configured, a solver is called to find the optimal solution to the planning problem. The solution is then post-processed to generate a set of output files that can be used for further analysis.

The next sections in this guide provide more details on how to perform all the steps in the workflow: 
1. [Model settings parameters](@ref): `genx_settings.yml`
2. [Solver Configuration](@ref): `[solver_name]_settings.yml`
3. [GenX Inputs](@ref)
4. [Time-domain reduction](@ref): `time_domain_reduction.yml` (optional)
5. [Multi-stage setup](@ref): `multi_stage_settings.yml` (optional)
6. [Running the model](@ref)
7. [GenX Outputs](@ref)

## Single and Multi-stage investment planning

In addition to the standard single-stage planning mode, in which the produces a single snapshot of the minimum-cost generation capacity mix to meet demand at least cost under some pre-specified future conditions, recent improvements in the GenX source code (part of v0.3 release) enable its use for studying **long-term evolution** of the power system across multiple investment stages. GenX can be used to study multi-stage power system planning in the following two ways:

- The user can formulate and solve a deterministic multi-stage planning problem with perfect foresight i.e. demand, cost, and policy assumptions about all stages are known and exploited to determine the least-cost investment trajectory for the entire period. The solution relies on exploiting the decomposable nature of the multi-stage problem via the implementation of the dual dynamic programming algorithm, described in [Lara et al. 2018 here](https://www.sciencedirect.com/science/article/abs/pii/S0377221718304466).

- The user can formulate a sequential, myopic multi-stage planning problem, where the model solves a sequence of single-stage investment planning problems wherein investment decisions in each stage are individually optimized to meet demand given assumptions for the current planning stage and with investment decisions from previous stages treated as inputs for the current stage. We refer to this as "myopic" (or shortsighted) mode since the solution does not account for information about future stages in determining investments for a given stage. This version is generally more computationally efficient than the deterministic multi-stage expansion with perfect foresight mode.

