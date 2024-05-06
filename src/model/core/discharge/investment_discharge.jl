@doc raw"""
	investment_discharge!(EP::Model, inputs::Dict, setup::Dict)
This function defines the expressions and constraints keeping track of total available power generation/discharge capacity across all resources as well as constraints on capacity retirements.
The total capacity of each resource is defined as the sum of the existing capacity plus the newly invested capacity minus any retired capacity. Note for storage and co-located resources, additional energy and charge power capacity decisions and constraints are defined in the storage and co-located VRE and storage module respectively.
```math
\begin{aligned}
& \Delta^{total}_{y,z} =(\overline{\Delta_{y,z}}+\Omega_{y,z}-\Delta_{y,z}) \forall y \in \mathcal{G}, z \in \mathcal{Z}
\end{aligned}
```
One cannot retire more capacity than existing capacity.
```math
\begin{aligned}
&\Delta_{y,z} \leq \overline{\Delta_{y,z}}
	\hspace{4 cm}  \forall y \in \mathcal{G}, z \in \mathcal{Z}
\end{aligned}
```
For resources where $\overline{\Omega_{y,z}}$ and $\underline{\Omega_{y,z}}$ is defined, then we impose constraints on minimum and maximum power capacity.
```math
\begin{aligned}
& \Delta^{total}_{y,z} \leq \overline{\Omega}_{y,z}
	\hspace{4 cm}  \forall y \in \mathcal{G}, z \in \mathcal{Z} \\
& \Delta^{total}_{y,z}  \geq \underline{\Omega}_{y,z}
	\hspace{4 cm}  \forall y \in \mathcal{G}, z \in \mathcal{Z}
\end{aligned}
```
In addition, this function adds investment and fixed O\&M related costs related to discharge/generation capacity to the objective function:
```math
\begin{aligned}
& 	\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z}}
	\left( (\pi^{INVEST}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Omega_{y,z})
	+ (\pi^{FOM}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Delta^{total}_{y,z})\right)
\end{aligned}
```
"""
function investment_discharge!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Discharge Module")
    MultiStage = setup["MultiStage"]

    gen = inputs["RESOURCES"]

    G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

    NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
    RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
    COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment
    RETROFIT_CAP = inputs["RETROFIT_CAP"]  # Set of all resources being retrofitted

    ### Variables ###

    # Retired capacity of resource "y" from existing capacity
    @variable(EP, vRETCAP[y in RET_CAP]>=0)

    # New installed capacity of resource "y"
    @variable(EP, vCAP[y in NEW_CAP]>=0)

    if MultiStage == 1
        @variable(EP, vEXISTINGCAP[y = 1:G]>=0)
    end

    # Being retrofitted capacity of resource y 
    @variable(EP, vRETROFITCAP[y in RETROFIT_CAP]>=0)

    ### Expressions ###

    if MultiStage == 1
        @expression(EP, eExistingCap[y in 1:G], vEXISTINGCAP[y])
    else
        @expression(EP, eExistingCap[y in 1:G], existing_cap_mw(gen[y]))
    end

    @expression(EP, eTotalCap[y in 1:G],
        if y in intersect(NEW_CAP, RET_CAP, RETROFIT_CAP) # Resources eligible for new capacity, retirements and being retrofitted
            if y in COMMIT
                eExistingCap[y] +
                cap_size(gen[y]) * (EP[:vCAP][y] - EP[:vRETCAP][y] - EP[:vRETROFITCAP][y])
            else
                eExistingCap[y] + EP[:vCAP][y] - EP[:vRETCAP][y] - EP[:vRETROFITCAP][y]
            end
        elseif y in intersect(setdiff(RET_CAP, NEW_CAP), setdiff(RET_CAP, RETROFIT_CAP)) # Resources eligible for only capacity retirements
            if y in COMMIT
                eExistingCap[y] - cap_size(gen[y]) * EP[:vRETCAP][y]
            else
                eExistingCap[y] - EP[:vRETCAP][y]
            end
        elseif y in setdiff(intersect(RET_CAP, NEW_CAP), RETROFIT_CAP) # Resources eligible for retirement and new capacity
            if y in COMMIT
                eExistingCap[y] + cap_size(gen[y]) * (EP[:vCAP][y] - EP[:vRETCAP][y])
            else
                eExistingCap[y] + EP[:vCAP][y] - EP[:vRETCAP][y]
            end
        elseif y in setdiff(intersect(RET_CAP, RETROFIT_CAP), NEW_CAP) # Resources eligible for retirement and retrofitting
            if y in COMMIT
                eExistingCap[y] -
                cap_size(gen[y]) * (EP[:vRETROFITCAP][y] + EP[:vRETCAP][y])
            else
                eExistingCap[y] - (EP[:vRETROFITCAP][y] + EP[:vRETCAP][y])
            end
        elseif y in intersect(setdiff(NEW_CAP, RET_CAP), setdiff(NEW_CAP, RETROFIT_CAP))  # Resources eligible for only new capacity
            if y in COMMIT
                eExistingCap[y] + cap_size(gen[y]) * EP[:vCAP][y]
            else
                eExistingCap[y] + EP[:vCAP][y]
            end
        else # Resources not eligible for new capacity or retirement
            eExistingCap[y] + EP[:vZERO]
        end)

    ### Need editting ##
    @expression(EP, eCFix[y in 1:G],
        if y in NEW_CAP # Resources eligible for new capacity (Non-Retrofit)
            if y in COMMIT
                inv_cost_per_mwyr(gen[y]) * cap_size(gen[y]) * vCAP[y] +
                fixed_om_cost_per_mwyr(gen[y]) * eTotalCap[y]
            else
                inv_cost_per_mwyr(gen[y]) * vCAP[y] +
                fixed_om_cost_per_mwyr(gen[y]) * eTotalCap[y]
            end
        else
            fixed_om_cost_per_mwyr(gen[y]) * eTotalCap[y]
        end)
    # Sum individual resource contributions to fixed costs to get total fixed costs
    @expression(EP, eTotalCFix, sum(EP[:eCFix][y] for y in 1:G))

    # Add term to objective function expression
    if MultiStage == 1
        # OPEX multiplier scales fixed costs to account for multiple years between two model stages
        # We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
        # and we have already accounted for multiple years between stages for fixed costs.
        add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFix)
    else
        add_to_expression!(EP[:eObj], eTotalCFix)
    end

    ### Constratints ###

    if MultiStage == 1
        # Existing capacity variable is equal to existing capacity specified in the input file
        @constraint(EP,
            cExistingCap[y in 1:G],
            EP[:vEXISTINGCAP][y]==existing_cap_mw(gen[y]))
    end

    ## Constraints on retirements and capacity additions
    # Cannot retire more capacity than existing capacity
    @constraint(EP,
        cMaxRetNoCommit[y in setdiff(RET_CAP, COMMIT)],
        vRETCAP[y]<=eExistingCap[y])
    @constraint(EP,
        cMaxRetCommit[y in intersect(RET_CAP, COMMIT)],
        cap_size(gen[y]) * vRETCAP[y]<=eExistingCap[y])
    @constraint(EP,
        cMaxRetroNoCommit[y in setdiff(RETROFIT_CAP, COMMIT)],
        vRETROFITCAP[y] + vRETCAP[y]<=eExistingCap[y])
    @constraint(EP,
        cMaxRetroCommit[y in intersect(RETROFIT_CAP, COMMIT)],
        cap_size(gen[y]) * (vRETROFITCAP[y] + vRETCAP[y])<=eExistingCap[y])

    ## Constraints on new built capacity
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    MAX_CAP = ids_with_positive(gen, max_cap_mw)
    @constraint(EP, cMaxCap[y in MAX_CAP], eTotalCap[y]<=max_cap_mw(gen[y]))

    # Constraint on minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    MIN_CAP = ids_with_positive(gen, min_cap_mw)
    @constraint(EP, cMinCap[y in MIN_CAP], eTotalCap[y]>=min_cap_mw(gen[y]))

    if setup["MinCapReq"] == 1
        @expression(EP,
            eMinCapResInvest[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum(EP[:eTotalCap][y] for y in ids_with_policy(gen, min_cap, tag = mincap)))
        add_similar_to_expression!(EP[:eMinCapRes], eMinCapResInvest)
    end

    if setup["MaxCapReq"] == 1
        @expression(EP,
            eMaxCapResInvest[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(EP[:eTotalCap][y] for y in ids_with_policy(gen, max_cap, tag = maxcap)))
        add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResInvest)
    end
end
