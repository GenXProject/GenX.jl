@Base.kwdef mutable struct ScalingSettings
    coeff_lb::Float64 = 1e-3
    coeff_ub::Float64 = 1e6
    min_coeff::Float64 = 1e-9
    rhs_lb::Float64 = 1e-3
    rhs_ub::Float64 = 1e6
    allow_recursion::Bool = true
    count_actions::Bool = false
    proxy_var_ratio_ub::Float64 = 10.0  
    proxy_var_map::Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}} = Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}}()
end

function get_scaling_settings(settings::Dict)
    scaling_settings = Dict{String, Any}()
    for scaling_setting in [String(x) for x in fieldnames(ScalingSettings)]
        if haskey(settings, scaling_setting)
            scaling_settings[scaling_setting] = settings[scaling_setting]
        end
    end
    return ScalingSettings(; scaling_settings...)
end

function scale_constraints!(EP::Model, scaling_settings::ScalingSettings=ScalingSettings())
    con_list = all_constraints(EP; include_variable_in_set_constraints=false)
    action_count = scale_constraint!.(con_list, Ref(scaling_settings));
    if scaling_settings.count_actions
        return sum(action_count)
    else
        return nothing
    end
end

function scale_constraints!(constraint_list::Vector{ConstraintRef}, scaling_settings::ScalingSettings=ScalingSettings())
    action_count = 0
    for con_ref in constraint_list
        action_count += scale_constraint!(con_ref, scaling_settings)
    end
    if scaling_settings.count_actions
        return action_count
    else
        return nothing
    end
end

function scale_constraint!(con_ref::ConstraintRef, scaling_settings::ScalingSettings)
    action_count = 0

    coeff_lb = scaling_settings.coeff_lb
    coeff_ub = scaling_settings.coeff_ub

    con_obj = constraint_object(con_ref)
    coefficients = abs.(append!(con_obj.func.terms.vals, normalized_rhs(con_ref)))
    coefficients = coefficients[coefficients .> 0] # Ignore coefficients which equal zero

    if length(coefficients) == 0
        return action_count
    end

    # If all the coefficients are within the bounds, we don't need to do anything
    if all(coeff_lb .<= coefficients .<= coeff_ub)
        return action_count
    end

    # Find the ratio of the maximum and minimum coefficients to the bounds
    # A value > 1 for either indicates that the coefficients are too large or too small
    max_ratio = maximum(coefficients) / coeff_ub
    min_ratio = coeff_lb / minimum(coefficients)

    # If some coefficients are too large, and none too small
    # and dividing by max_ratio will not make any coefficients less than coeff_lb
    if max_ratio > 1 && min_ratio < 1 && min_ratio * max_ratio < 1
        for (key, val) in con_obj.func.terms
            set_normalized_coefficient(con_ref, key, val / max_ratio)
        end
        set_normalized_rhs(con_ref, normalized_rhs(con_ref) / max_ratio)
        action_count += 1
    # Else-if some coefficients are too small, and none too large
    # and multiplying by min_ratio will not make any coefficients greater than coeff_ub
    elseif min_ratio > 1 && max_ratio < 1 && max_ratio * min_ratio < 1
        for (key, val) in con_obj.func.terms
            set_normalized_coefficient(con_ref, key, val * min_ratio)
        end
        set_normalized_rhs(con_ref, normalized_rhs(con_ref) * min_ratio)
        action_count += 1
    # Else we'll recreate the constraint with proxy variables to scale the coefficients one-by-one
    else
        scale_and_remake_constraint(con_ref, scaling_settings)
        action_count += 1
    end
    return action_count
end

function scale_and_remake_constraint(con_ref::ConstraintRef, scaling_settings::ScalingSettings)
    var_coeff_pairs = constraint_object(con_ref).func.terms
    new_var_coeff_pairs = OrderedDict{VariableRef, Float64}()

    # First we want to check if we need to scale the RHS constant
    # We'd like to do this without making it impossible to scale some coefficients with proxy variables
    rhs_multiplier = calc_rhs_multiplier(con_ref, scaling_settings.rhs_lb, scaling_settings.rhs_ub, scaling_settings.coeff_lb, scaling_settings.coeff_ub)

    for (var, coeff) in var_coeff_pairs
        if coeff == 0.0 || (scaling_settings.coeff_lb <= (abs(coeff) * rhs_multiplier) <= scaling_settings.coeff_ub)
            new_var_coeff_pairs[var] = coeff * rhs_multiplier
            continue
        end
        (updated_var, updated_coeff) = update_var_coeff_pair(var, coeff * rhs_multiplier, scaling_settings)
        new_var_coeff_pairs[updated_var] = updated_coeff
    end
    replace_constraint!(con_ref, new_var_coeff_pairs, rhs_multiplier)
end

function update_var_coeff_pair(var::VariableRef, coeff::Real, scaling_settings::ScalingSettings)
    multiplier = calc_coeff_multiplier(coeff, scaling_settings.coeff_lb, scaling_settings.coeff_ub)
    new_coeff = coeff * multiplier
    if abs(new_coeff) < scaling_settings.min_coeff
        return (var, 0.0)
    end
    # Get a new or cached proxy variable, and new or cached multiplier
    (proxy_var, multiplier) = get_proxy_var(var, multiplier, scaling_settings.proxy_var_map, scaling_settings.proxy_var_ratio_ub)
    new_coeff = coeff * multiplier
    # Tidy up near-unity coefficients, in case that allows a speedup
    (new_coeff, multiplier) = prune_coefficients(new_coeff, coeff, multiplier)
    # If the new coefficient is within bounds, we're done
    if scaling_settings.coeff_lb <= abs(new_coeff) <= scaling_settings.coeff_ub
        return (proxy_var, new_coeff)
    end
    # Else, the new coefficient is too large or too small
    # If recursion is allowed, we repeate the process with the new coefficient
    if scaling_settings.allow_recursion
        return update_var_coeff_pair(proxy_var, new_coeff, scaling_settings)
    # Else, we return the current proxy variable and coefficient
    # as the best we can do given the user's coefficient range.
    # In the future we could try to balance this better with
    # the RHS scaling
    else
        return (proxy_var, new_coeff)
    end
end

function prune_coefficients(new_coeff::Real, coeff::Real, multiplier::Real)
    if new_coeff ≈ 1.0
        return (1.0, new_coeff / coeff)
    elseif new_coeff ≈ -1.0
        return (-1.0, new_coeff / coeff)
    end
    return (new_coeff, multiplier)
end

function calc_rhs_multiplier(con_ref::ConstraintRef, rhs_lb::Real, rhs_ub::Real, coeff_lb::Real, coeff_ub::Real)
    rhs = normalized_rhs(con_ref)
    abs_rhs = abs(rhs)
    if rhs_lb < abs_rhs < rhs_ub
        return 1.0
    end
    coeff_and_rhs = abs.(append!(constraint_object(con_ref).func.terms.vals, rhs))
    coeff_and_rhs = coeff_and_rhs[coeff_and_rhs .> 0] # Ignore coefficients which equal zero
    if abs_rhs > rhs_ub
        return maximum([1.0 / abs_rhs, coeff_lb / coeff_ub / minimum(coeff_and_rhs)])
    end
    if abs_rhs < rhs_lb
        return minimum([1.0 / abs_rhs, coeff_ub / coeff_lb / maximum(coeff_and_rhs)])
    end
end

function calc_coeff_multiplier(coeff::Real, coeff_lb::Real, coeff_ub::Real)
    abs_coeff = abs(coeff)
    if abs_coeff < coeff_lb
        return minimum([coeff_ub, 1.0 / abs_coeff]) # We could shift the target value (i.e. 1.0 here)
    end
    if abs_coeff > coeff_ub
        return maximum([coeff_lb, 1.0 / abs_coeff])
    end
end

function get_proxy_var(var::VariableRef, multiplier::Real, proxy_var_map::Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}}, proxy_var_ratio_ub::Real)
    cached_result = existing_proxy_var(var, multiplier, proxy_var_map, proxy_var_ratio_ub)
    if !isnothing(cached_result)
        return cached_result
    end
    proxy_var = make_proxy_var(var, multiplier)
    if !haskey(proxy_var_map, var)
        proxy_var_map[var] = Vector{Tuple{VariableRef, Float64}}()
    end
    push!(proxy_var_map[var], (proxy_var, multiplier))
    return proxy_var, multiplier
end

function existing_proxy_var(var::VariableRef, multiplier::Real, proxy_var_map::Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}}, proxy_var_ratio_ub::Real)
    if !haskey(proxy_var_map, var)
        return nothing
    end
    for (proxy_var, cached_multiplier) in proxy_var_map[var]
        if 1 / proxy_var_ratio_ub < multiplier / cached_multiplier < proxy_var_ratio_ub
            return proxy_var, cached_multiplier
        end
    end
    return nothing
end

function make_proxy_var(var::VariableRef, multiplier::Real)
    model = var.model
    proxy_var = @variable(model)
    if has_lower_bound(var)
        set_lower_bound(proxy_var, lower_bound(var) * multiplier)
    end
    if has_upper_bound(var)
        set_upper_bound(proxy_var, upper_bound(var) * multiplier)
    end
    @constraint(model, var == proxy_var * multiplier)
    return proxy_var
end

function replace_constraint!(con_ref::ConstraintRef, var_coeff_pairs=nothing, rhs_multiplier::Real=1.0)
    con_obj = constraint_object(con_ref)
    con_name = name(con_ref)
    model = con_ref.model
    delete(model, con_ref)
    unregister(model, Symbol(con_name))
    if isnothing(var_coeff_pairs)
        _ = make_constraint(model, con_obj.func.terms, con_obj.set, con_name, rhs_multiplier)
    else
        _ = make_constraint(model, var_coeff_pairs, con_obj.set, con_name, rhs_multiplier)
    end
    return nothing
end

function make_constraint(EP::Model, var_coeff_pairs::AbstractDict{VariableRef, Float64}, rhs::MOI.AbstractScalarSet, con_name::AbstractString, rhs_multiplier::Real=1.0)
    expr = AffExpr()
    for (var, coeff) in var_coeff_pairs
        add_to_expression!(expr, var, coeff)
    end
    new_con = @constraint(EP, expr in rhs; base_name=con_name)
    if rhs_multiplier != 1.0
        set_normalized_rhs(new_con, normalized_rhs(new_con) * rhs_multiplier)
    end
    name, indices = parse_constraint_name(con_name)
    if indices === nothing
        EP[Symbol(name)] = new_con
    else
        EP[Symbol(name)][indices...] = new_con
    end
    return new_con
end

function parse_constraint_name(input::AbstractString)
    # Find the position of the opening bracket '['
    open_bracket_pos = findfirst(isequal('['), input)
    if open_bracket_pos === nothing
        # No brackets found, return the whole string as the name
        return input, nothing
    end
    # Extract the name part
    name = input[1:open_bracket_pos-1]
    # Extract the indexes part
    indexes_part = input[open_bracket_pos+1:end-1]  # Remove the closing bracket ']'
    # Split the indexes part by comma
    indexes = split(indexes_part, ',')
    # Parse the indexes as integers
    parsed_indexes = [parse(Int, index) for index in indexes]
    return name, parsed_indexes
end