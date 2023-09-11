# GenX Documentation

```@meta
CurrentModule = GenX
```

## Overview

GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape.

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by [Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by [a team of contributors](https://energy.mit.edu/genx/#team) at the MIT Energy Initiative (led by [Dharik Mallapragada](https://mallapragada.mit.edu)) and the Princeton University ZERO Lab (led by Jenkins).

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning. Depending on the planning problem or question to be studied, GenX can be configured with varying levels of model resolution and scope, with regards to: (1) temporal resolution of time series data such as electricity demand and renewable energy availability; (2) power system operational detail and unit commitment constraints; and (3) geospatial resolution and transmission network representation. The model is also capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

## How to cite GenX

We recommend users of GenX to cite it in their academic publications and patent filings. Here's the text to put up as the citation for GenX:
`MIT Energy Initiative and Princeton University ZERO lab. [GenX](https://github.com/GenXProject/GenX): a configurable power system capacity expansion model for studying low-carbon energy futures n.d. https://github.com/GenXProject/GenX

