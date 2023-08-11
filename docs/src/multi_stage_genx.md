## Multi-stage investment planning
_Added in 0.3_

GenX can be used to study the long-term evolution of the power system across multiple investment stages, in the following two ways:

* The user can formulate and solve a deterministic **multi-stage planning problem with perfect foresight** i.e. demand, cost, and policy assumptions about all stages are known and exploited to determine the least-cost investment trajectory for the entire period.
  The solution of this multi-stage problem relies on exploiting the decomposable nature of the multi-stage problem via the implementation of the dual dynamic programming algorithm, described in [Lara et al. 2018 here](https://www.sciencedirect.com/science/article/abs/pii/S0377221718304466).
* The user can formulate a **sequential, myopic multi-stage planning problem**, where the model solves a sequence of single-stage investment planning problems wherein investment decisions in each stage are individually optimized to meet demand given assumptions for the current planning stage and with investment decisions from previous stages treated as inputs for the current stage.
  We refer to this as "myopic" (or shortsighted) mode since the solution does not account for information about future stages in determining investments for a given stage.
  This version is generally more computationally efficient than the deterministic multi-stage expansion with perfect foresight mode.

More information on this feature can be found in the section on `Multi-stage` under the `Model function reference` tab.
