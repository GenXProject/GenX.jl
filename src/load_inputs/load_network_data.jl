@doc raw"""
    load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict)

Function for reading input parameters related to the electricity transmission network
"""
function load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Network.csv"
    network_var = load_dataframe(joinpath(path, filename))

    as_vector(col::Symbol) = collect(skipmissing(network_var[!, col]))
    to_floats(col::Symbol) = convert(Array{Float64}, as_vector(col))

    # Number of zones in the network
    Z = length(as_vector(:Network_zones))
    inputs_nw["Z"] = Z
    L = length(as_vector(:Network_Lines))
    inputs_nw["L"] = L
    L_asym  = 0 # Default number of asymmetrical lines
    if setup["asymmetrical_trans_flow_limit"] == 1
        L_asym = length(filtered_vector(network_var, :Asymmetrical, :Network_Lines)) #Number of asymmetrical lines
    end
    #println("Number of asymmetric lines: $L_asym")
    inputs_nw["L_asym"] = L_asym
    # Number of symmetric lines in the network
    L_sym = L - L_asym
    inputs_nw["L_sym"] = L_sym

    # Topology of the network source-sink matrix
    inputs_nw["pNet_Map"] = load_network_map(network_var, Z, L)

    if setup["asymmetrical_trans_flow_limit"] == 1
        # Topology of the network source-sink matrix with asymmetric bidirectional flow lines
        inputs_nw["pNet_Map_asym"] = load_network_map(network_var, Z, L_asym)
    end

    # Transmission capacity of the network (in MW) & Maximum possible flow after reinforcement for use in linear segments of piecewise approximation
    if setup["asymmetrical_trans_flow_limit"] == 1
        inputs_nw["pTrans_Max_Possible"] = inputs_nw["pTrans_Max"] = convert(Array{Float64}, filtered_vector_sym(network_var, :Asymmetrical, :Line_Max_Flow_MW)) / scale_factor
        # Transmission capacity of the network for asymmetrical lines; onward direction (in MW)
        inputs_nw["pTrans_Max_Possible_Pos"] = inputs_nw["pTrans_Max_Pos"] = convert(Array{Float64}, filtered_vector(network_var, :Asymmetrical, :Line_Max_Flow_MW))/ scale_factor  # convert to GW

        # Transmission capacity of the network for asymmetrical lines; return direction(in MW)
        inputs_nw["pTrans_Max_Possible_Neg"] = inputs_nw["pTrans_Max_Neg"] = convert(Array{Float64}, filtered_vector(network_var, :Asymmetrical, :Line_Max_Flow_MW_Neg)) / scale_factor  # convert to GW
    else
        inputs_nw["pTrans_Max_Possible"] = inputs_nw["pTrans_Max"] = to_floats(:Line_Max_Flow_MW) / scale_factor  # convert to GW
    end

    # Transmission line (between zone) loss coefficient (resistance/voltage^2)
    inputs_nw["pTrans_Loss_Coef"] = zeros(Float64, L)
    if setup["Trans_Loss_Segments"] == 1
        # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
        if setup["asymmetrical_trans_flow_limit"] == 1
            inputs_nw["pTrans_Loss_Coef"] = inputs_nw["pPercent_Loss"] = convert(Array{Float64}, filtered_vector_sym(network_var, :Asymmetrical, :Line_Loss_Percentage))
            # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
            inputs_nw["pTrans_Loss_Coef_Pos"] = inputs_nw["pPercent_Loss_Pos"] = convert(Array{Float64}, filtered_vector(network_var, :Asymmetrical, :Line_Loss_Percentage))
            # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
            inputs_nw["pTrans_Loss_Coef_Neg"] = inputs_nw["pPercent_Loss_Neg"] = convert(Array{Float64}, filtered_vector(network_var, :Asymmetrical, :Line_Loss_Percentage_Neg))
        else
            inputs_nw["pTrans_Loss_Coef"] = inputs_nw["pPercent_Loss"] = to_floats(:Line_Loss_Percentage)
        end
    elseif setup["Trans_Loss_Segments"] >= 2
        # Transmission line voltage (in kV)
        inputs_nw["kV"] = to_floats(:Line_Voltage_kV)
        # Transmission line resistance (in Ohms) - Used when modeling quadratic transmission losses
        inputs_nw["Ohms"] = to_floats(:Line_Resistance_Ohms)
        # If zones are connected, loss coefficient is R/V^2 where R is resistance in Ohms and V is voltage in Volts
        inputs_nw["pTrans_Loss_Coef"] = (inputs_nw["Ohms"] / 10^6) ./
                                        (inputs_nw["kV"] / 10^3)^2 * scale_factor # 1/GW ***
    end

    ## Inputs for the DC-OPF 
    if setup["DC_OPF"] == 1
        if setup["NetworkExpansion"] == 1
            @warn("Because the DC_OPF flag is active, GenX will not allow any transmission capacity expansion. Set the DC_OPF flag to 0 if you want to optimize tranmission capacity expansion.")
            setup["NetworkExpansion"] = 0
        end
        println("Reading DC-OPF values...")
        # Transmission line voltage (in kV)
        line_voltage_kV = to_floats(:Line_Voltage_kV)
        # Transmission line reactance (in Ohms)
        line_reactance_Ohms = to_floats(:Line_Reactance_Ohms)
        # Line angle limit (in radians)
        inputs_nw["Line_Angle_Limit"] = to_floats(:Angle_Limit_Rad)
        # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
        # MW = (kV)^2/Ohms 
        inputs_nw["pDC_OPF_coeff"] = ((line_voltage_kV .^ 2) ./ line_reactance_Ohms) /
                                     scale_factor
    end

    if setup["NetworkExpansion"] == 1
        if setup["asymmetrical_trans_flow_limit"] == 1
           # Maximum reinforcement allowed in MW
           # Read between zone network reinforcement costs per peak MW of capacity added
           inputs_nw["pC_Line_Reinforcement"] = to_floats(:Line_Reinforcement_Cost_per_MWyr) /
           scale_factor # convert to million $/GW/yr with objective function in millions
           # Maximum reinforcement allowed in MW
           #NOTE: values <0 indicate no expansion possible
           inputs_nw["pMax_Line_Reinforcement"] = map(x -> max(0, x),
           convert(Array{Float64}, filtered_vector_sym(network_var, :Asymmetrical, :Line_Max_Reinforcement_MW))) / scale_factor # convert to GW
           inputs_nw["pTrans_Max_Possible"] += inputs_nw["pMax_Line_Reinforcement"]
           #NOTE: values <0 indicate no expansion possible
           inputs_nw["pMax_Line_Reinforcement_Pos"] = map(x -> max(0, x),
           convert(Array{Float64}, filtered_vector(network_var, :Asymmetrical, :Line_Max_Reinforcement_MW))) / scale_factor # convert to GW
           inputs_nw["pTrans_Max_Possible_Pos"] += inputs_nw["pMax_Line_Reinforcement_Pos"]

           # Maximum reinforcement allowed in MW
           #NOTE: values <0 indicate no expansion possible
           inputs_nw["pMax_Line_Reinforcement_Neg"] = map(x -> max(0, x),
           convert(Array{Float64}, filtered_vector(network_var, :Asymmetrical, :Line_Max_Reinforcement_MW_Neg))) / scale_factor # convert to GW
           inputs_nw["pTrans_Max_Possible_Neg"] += inputs_nw["pMax_Line_Reinforcement_Neg"]
        else
            # Read between zone network reinforcement costs per peak MW of capacity added
            inputs_nw["pC_Line_Reinforcement"] = to_floats(:Line_Reinforcement_Cost_per_MWyr) /
            scale_factor # convert to million $/GW/yr with objective function in millions
            # Maximum reinforcement allowed in MW
            #NOTE: values <0 indicate no expansion possible
            inputs_nw["pMax_Line_Reinforcement"] = map(x -> max(0, x),
                to_floats(:Line_Max_Reinforcement_MW)) / scale_factor # convert to GW
            inputs_nw["pTrans_Max_Possible"] += inputs_nw["pMax_Line_Reinforcement"]
        end
    end

    # Multi-Stage
    if setup["MultiStage"] == 1
        # Weighted Average Cost of Capital for Transmission Expansion
        if setup["NetworkExpansion"] >= 1
            inputs_nw["transmission_WACC"] = to_floats(:WACC)
            inputs_nw["Capital_Recovery_Period_Trans"] = to_floats(:Capital_Recovery_Period)
        end

        # Max Flow Possible on Each Line
        if setup["asymmetrical_trans_flow_limit"] == 1
            inputs_nw["pLine_Max_Flow_Possible_MW_Pos"] = to_floats(:Line_Max_Flow_Possible_MW_Pos) /
                                                                                                scale_factor # Convert to GW
            inputs_nw["pLine_Max_Flow_Possible_MW_Neg"] = to_floats(:Line_Max_Flow_Possible_MW_Neg) /
                                                                                                scale_factor # Convert to GW
        else
            inputs_nw["pLine_Max_Flow_Possible_MW"] = to_floats(:Line_Max_Flow_Possible_MW) /
                                                  scale_factor # Convert to GW
        end
    end

    ## Sets and indices for transmission losses and expansion
    inputs_nw["TRANS_LOSS_SEGS"] = setup["Trans_Loss_Segments"] # Number of segments used in piecewise linear approximations quadratic loss functions
    if setup["asymmetrical_trans_flow_limit"] == 1
        inputs_nw["LOSS_LINES_SYM"] = findall(inputs_nw["pTrans_Loss_Coef"] .!= 0) # Lines for which loss coefficients apply (are non-zero);
        inputs_nw["LOSS_LINES_ASYM"] = findall((inputs_nw["pTrans_Loss_Coef_Pos"] .!= 0) .| (inputs_nw["pTrans_Loss_Coef_Neg"] .!= 0)) # Lines for which loss coefficients apply (are non-zero);
    else
        inputs_nw["LOSS_LINES"] = findall(inputs_nw["pTrans_Loss_Coef"] .!= 0) # Lines for which loss coefficients apply (are non-zero);
    end

    if setup["NetworkExpansion"] == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        if setup["asymmetrical_trans_flow_limit"] == 1
            inputs_nw["EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"] .>= 0)
            inputs_nw["EXPANSION_LINES_ASYM"] = findall((inputs_nw["pMax_Line_Reinforcement_Pos"] .> 0) .| (inputs_nw["pMax_Line_Reinforcement_Neg"] .> 0))
            inputs_nw["NO_EXPANSION_LINES_ASYM"] = findall((inputs_nw["pMax_Line_Reinforcement_Pos"] .<= 0) .& (inputs_nw["pMax_Line_Reinforcement_Neg"] .<= 0))
        else
            inputs_nw["EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"] .>= 0)
            inputs_nw["NO_EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"] .< 0)
        end
    end

    println(filename * " Successfully Read!")

    return network_var
end

@doc raw"""
    load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)

Loads the network map from a list-style interface
```
..., Network_Lines, Start_Zone, End_Zone, ...
                 1,           1,       2,
                 2,           1,       3,
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
starting zone of the line and the zone with entry -1 is the ending zone of the line.
"""
function load_network_map_from_matrix(network_var::DataFrame, Z, L)
    # Topology of the network source-sink matrix
    network_map_matrix_format_deprecation_warning()
    col = findall(s -> s == "z1", names(network_var))[1]
    mat = Matrix{Float64}(network_var[1:L, col:(col + Z - 1)])
end

function load_network_map(network_var::DataFrame, Z, L)
    columns = names(network_var)

    list_columns = ["Start_Zone", "End_Zone"]
    has_network_list = all([c in columns for c in list_columns])

    zones_as_strings = ["z" * string(i) for i in 1:Z]
    has_network_matrix = all([c in columns for c in zones_as_strings])

    instructions = """The transmission network should be specified in the form of a matrix
           (with columns z1, z2, ... zN) or in the form of lists (with Start_Zone, End_Zone),
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

function network_map_matrix_format_deprecation_warning()
    @warn """Specifying the network map as a matrix is deprecated as of v0.4
  and will be removed in v0.5. Instead, use the more compact list-style format.

  ..., Network_Lines, Start_Zone, End_Zone, ...
                   1,          1,        2,
                   2,          1,        3,
                   3,          2,        3,
  """ maxlog=1
end

function filtered_vector(df::DataFrame, condition_col::Symbol, data_col::Symbol)
    filtered_df = df[df[!,condition_col] .== 1, :]
    return collect(skipmissing(filtered_df[!, data_col]))
end

function filtered_vector_sym(df::DataFrame, condition_col::Symbol, data_col::Symbol)
    filtered_df = df[df[!,condition_col] .== 0, :]
    return collect(skipmissing(filtered_df[!, data_col]))
end