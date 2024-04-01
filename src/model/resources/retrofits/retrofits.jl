@doc raw"""
	retrofit(EP::Model, inputs::Dict)

This function defines the constraints for operation of retrofit technologies, including
		but not limited to carbon capture and thermal energy storage.
	
For retrofittable source technologies $y$ and retrofit technologies $r$ in the same region $z$ and retrofit cluster $id$,
(i.e. $y \in RS(id)$ and $r \in RO(id)$), the total retrofit capacity $\Omega_{r}$ that may be installed 
is constrained by the available retrofittable capacity $P_{y}$ as well as the efficiency ${ef}_{r}$ of the retrofit technology.

```math
\begin{aligned}
    \sum_{y \in RS(id)}P_{y} = \sum_{r \in RO(id)}\frac{\Omega_{r}}{{ef}_{r}} \quad \quad \quad \quad \forall id \in {RETROFIT},
\end{aligned}
```
where ${RETROFIT}$ represents the set of all retrofit IDs (clusters) in the model.

"""
function retrofit(EP::Model, inputs::Dict)
    println("Retrofit Resources Module")

    gen = inputs["RESOURCES"]

    COMMIT = inputs["COMMIT"]   # Set of all resources subject to unit commitment
    RETROFIT_CAP = inputs["RETROFIT_CAP"]  # Set of all resources being retrofitted
    RETROFIT_OPTIONS = inputs["RETROFIT_OPTIONS"] # Set of all resources being created
    RETROFIT_IDS = inputs["RETROFIT_IDS"] # Set of unique IDs for retrofit resources

    @expression(EP, eRetrofittedCapByRetroId[id in RETROFIT_IDS],
        sum(cap_size(gen[y]) * EP[:vRETROFITCAP][y] for y in intersect(RETROFIT_CAP,
                COMMIT,
                resources_in_retrofit_cluster_by_rid(gen, id));
            init = 0)
        +sum(EP[:vRETROFITCAP][y] for y in setdiff(intersect(RETROFIT_CAP,
                    resources_in_retrofit_cluster_by_rid(gen, id)),
                COMMIT);
            init = 0))

    @expression(EP, eRetrofitCapByRetroId[id in RETROFIT_IDS],
        sum(cap_size(gen[y]) * EP[:vCAP][y] * (1 / retrofit_efficiency(gen[y]))
            for y in intersect(RETROFIT_OPTIONS,
                COMMIT,
                resources_in_retrofit_cluster_by_rid(gen, id));
            init = 0)
        +sum(EP[:vCAP][y] * (1 / retrofit_efficiency(gen[y]))
             for y in setdiff(intersect(RETROFIT_OPTIONS,
                    resources_in_retrofit_cluster_by_rid(gen, id)),
                COMMIT);
            init = 0))

    @constraint(EP,
        cRetrofitCapacity[id in RETROFIT_IDS],
        eRetrofittedCapByRetroId[id]==eRetrofitCapByRetroId[id])

    return EP
end
