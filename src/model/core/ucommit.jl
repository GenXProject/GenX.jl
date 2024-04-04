@doc raw"""
	ucommit!(EP::Model, inputs::Dict, setup::Dict)

This function creates decision variables and cost expressions associated with thermal plant unit commitment or start-up and shut-down decisions (cycling on/off)

**Unit commitment decision variables:**

This function defines the following decision variables:

$\nu_{y,t,z}$ designates the commitment state of generator cluster $y$ in zone $z$ at time $t$;
$\chi_{y,t,z}$ represents number of startup decisions in cluster $y$ in zone $z$ at time $t$;
$\zeta_{y,t,z}$ represents number of shutdown decisions in cluster $y$ in zone $z$ at time $t$.

**Cost expressions:**

The total cost of start-ups across all generators subject to unit commitment ($y \in UC$) and all time periods, t is expressed as:
```math
\begin{aligned}
	C^{start} = \sum_{y \in UC, t \in T} \omega_t \times start\_cost_{y,t} \times \chi_{y,t}
\end{aligned}
```

The sum of start-up costs is added to the objective function.
"""
function ucommit!(EP::Model, inputs::Dict, setup::Dict)
    println("Unit Commitment Module")

    T = inputs["T"]     # Number of time steps (hours)
    COMMIT = inputs["COMMIT"] # For not, thermal resources are the only ones eligible for Unit Committment

    ### Variables ###

    ## Decision variables for unit commitment
    # commitment state variable
    @variable(EP, vCOMMIT[y in COMMIT, t = 1:T]>=0)
    # startup event variable
    @variable(EP, vSTART[y in COMMIT, t = 1:T]>=0)
    # shutdown event variable
    @variable(EP, vSHUT[y in COMMIT, t = 1:T]>=0)

    ### Expressions ###

    ## Objective Function Expressions ##

    # Startup costs of "generation" for resource "y" during hour "t"
    @expression(EP,
        eCStart[y in COMMIT, t = 1:T],
        (inputs["omega"][t]*inputs["C_Start"][y, t]*vSTART[y, t]))

    # Julia is fastest when summing over one row one column at a time
    @expression(EP, eTotalCStartT[t = 1:T], sum(eCStart[y, t] for y in COMMIT))
    @expression(EP, eTotalCStart, sum(eTotalCStartT[t] for t in 1:T))

    add_to_expression!(EP[:eObj], eTotalCStart)

    ### Constratints ###
    ## Declaration of integer/binary variables
    if setup["UCommit"] == 1 # Integer UC constraints
        for y in COMMIT
            set_integer.(vCOMMIT[y, :])
            set_integer.(vSTART[y, :])
            set_integer.(vSHUT[y, :])
            if y in inputs["RET_CAP"]
                set_integer(EP[:vRETCAP][y])
            end
            if y in inputs["NEW_CAP"]
                set_integer(EP[:vCAP][y])
            end
            if y in inputs["RETROFIT_CAP"]
                set_integer(EP[:vRETROFITCAP][y])
            end
        end
    end #END unit commitment configuration
    return EP
end
