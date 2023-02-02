"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
    load_network_data(setup::Dict, path::AbstractString, inputs_nw::Dict)

Function for reading input parameters related to the electricity transmission network
"""
#DEV NOTE:  add DC power flow related parameter inputs in a subsequent commit
function load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict)

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Network.csv"
    network_var = DataFrame(CSV.File(joinpath(path, filename), header=true), copycols=true)

    as_vector(col::Symbol) = collect(skipmissing(network_var[!, col]))
    to_floats(col::Symbol) = convert(Array{Float64}, as_vector(col))

    # Number of zones in the network
    Z = length(as_vector(:Network_zones))
    inputs_nw["Z"] = Z
    # Number of lines in the network
    L = length(as_vector(:Network_Lines))
    inputs_nw["L"] = L

    # Topology of the network source-sink matrix
    inputs_nw["pNet_Map"] = load_network_map(network_var, Z, L)

    # Transmission capacity of the network (in MW)
    inputs_nw["pTrans_Max"] = to_floats(:Line_Max_Flow_MW) / scale_factor  # convert to GW

    if setup["Trans_Loss_Segments"] == 1
        # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
        inputs_nw["pPercent_Loss"] = to_floats(:Line_Loss_Percentage)
    elseif setup["Trans_Loss_Segments"] >= 2
        # Transmission line voltage (in kV)
        inputs_nw["kV"] = to_floats(:Line_Voltage_kV)
        # Transmission line resistance (in Ohms) - Used when modeling quadratic transmission losses
        inputs_nw["Ohms"] = to_floats(:Line_Resistance_ohms)
    end

    # Maximum possible flow after reinforcement for use in linear segments of piecewise approximation
    inputs_nw["pTrans_Max_Possible"] = inputs_nw["pTrans_Max"]

    if setup["NetworkExpansion"]==1
        # Read between zone network reinforcement costs per peak MW of capacity added
        inputs_nw["pC_Line_Reinforcement"] = to_floats(:Line_Reinforcement_Cost_per_MWyr) / scale_factor # convert to million $/GW/yr with objective function in millions
        # Maximum reinforcement allowed in MW
        #NOTE: values <0 indicate no expansion possible
        inputs_nw["pMax_Line_Reinforcement"] = map(x->max(0, x), to_floats(:Line_Max_Reinforcement_MW)) / scale_factor # convert to GW
        inputs_nw["pTrans_Max_Possible"] += inputs_nw["pMax_Line_Reinforcement"]
    end

    # Multi-Stage
    if setup["MultiStage"] == 1
        # Weighted Average Cost of Capital for Transmission Expansion
        if setup["NetworkExpansion"]>=1
            inputs_nw["transmission_WACC"]= to_floats(:WACC)
            inputs_nw["Capital_Recovery_Period_Trans"]= to_floats(:Capital_Recovery_Period)
        end

        # Max Flow Possible on Each Line
        inputs_nw["pLine_Max_Flow_Possible_MW"] = to_floats(:Line_Max_Flow_Possible_MW) / scale_factor # Convert to GW
    end

    # Transmission line (between zone) loss coefficient (resistance/voltage^2)
    inputs_nw["pTrans_Loss_Coef"] = zeros(Float64, L)
    if setup["Trans_Loss_Segments"] == 1
        inputs_nw["pTrans_Loss_Coef"] = inputs_nw["pPercent_Loss"]
    elseif setup["Trans_Loss_Segments"] >= 2
        # If zones are connected, loss coefficient is R/V^2 where R is resistance in Ohms and V is voltage in Volts
        inputs_nw["pTrans_Loss_Coef"] = (inputs_nw["Ohms"]/10^6)/(inputs_nw["kV"]/10^3)^2 * scale_factor # 1/GW ***
    end

    ## Sets and indices for transmission losses and expansion
    inputs_nw["TRANS_LOSS_SEGS"] = setup["Trans_Loss_Segments"] # Number of segments used in piecewise linear approximations quadratic loss functions
    inputs_nw["LOSS_LINES"] = findall(inputs_nw["pTrans_Loss_Coef"].!=0) # Lines for which loss coefficients apply (are non-zero);

    if setup["NetworkExpansion"] == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        inputs_nw["EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"].>=0)
        inputs_nw["NO_EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"].<0)
    end

    println(filename * " Successfully Read!")

    return network_var
end

@doc raw"""
    load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)

Loads the network map from a list-style interface
```
..., Network_Lines, Origin_Zone, Destination_Zone, ...
                 1,           1,                2,
                 2,           1,                3,
```
"""
function load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)
    start_col, end_col = list_columns
    mat = zeros(L, Z)
    start_zones = collect(skipmissing(network_var[!, start_col]))
    end_zones = collect(skipmissing(network_var[!, end_col]))
    for l in 1:L
        mat[l, start_zones[l]] = 1
        mat[l, end_zones[l]] = -1
    end
    mat
end

@doc raw"""
    load_network_map_from_matrix(network_var::DataFrame, Z, L)

Loads the network map from a matrix-style interface
```
..., Network_Lines, z1, z2, z3, ...
                 1,  1, -1,  0,
                 2,  1,  0, -1,
```
This is equivalent to the list-style interface where the zone zN with entry +1 is the
starting node of the line and the zone with entry -1 is the ending node of the line.
"""
function load_network_map_from_matrix(network_var::DataFrame, Z, L)
    # Topology of the network source-sink matrix
    col = findall(s -> s == "z1", names(network_var))[1]
    mat = Matrix{Float64}(network_var[1:L, col:col+Z-1])
end

function load_network_map(network_var::DataFrame, Z, L)
    columns = names(network_var)

    list_columns = ["Origin_Zone", "Destination_Zone"]
    has_network_list = all([c in columns for c in list_columns])

    zones_as_strings = ["z" * string(i) for i in 1:Z]
    has_network_matrix =  all([c in columns for c in zones_as_strings])

    instructions = """The transmission network should be specified in the form of a matrix
           (with columns z1, z2, ... zN) or in the form of lists (with Start_Node, End_Node),
           but not both. See the documentation for examples."""

    if has_network_list && has_network_matrix
        error("two types of transmission network map were provided.\n" * instructions)
    elseif !(has_network_list || has_network_matrix)
        error("no transmission network map was detected.\n" * instructions)
    elseif has_network_list
        load_network_map_from_list(network_var, Z, L, list_columns)
    elseif has_network_matrix
        load_network_map_from_matrix(network_var, Z, L)
    end
end