function scale_constraints!(EP::Model, max_coeff::Float64=1e6, min_coeff::Float64=1e-3)
    con_list = all_constraints(EP; include_variable_in_set_constraints=false)
    scale_constraints!(con_list, max_coeff, min_coeff)
end
    
function scale_constraints!(constraint_list::Vector{ConstraintRef}, max_coeff::Float64=1e6, min_coeff::Float64=1e-3)
    action_count = 0
    for con_ref in constraint_list
        con_obj = constraint_object(con_ref)
        coefficients = abs.(append!(con_obj.func.terms.vals, normalized_rhs(con_ref)))
        # coefficients[coefficients .< min_coeff / 100] .= 0 # Set any coefficients less than min_coeff / 100 to zero
        coefficients = coefficients[coefficients .> 0] # Ignore constraints which equal zero
        if length(coefficients) == 0
            continue
        end
        max_ratio = maximum(coefficients) / max_coeff
        min_ratio = min_coeff / minimum(coefficients)
        if max_ratio > 1 && min_ratio < 1
            if min_ratio / max_ratio < 1
                for (key, val) in con_obj.func.terms
                    set_normalized_coefficient(con_ref, key, val / max_ratio)
                end
                set_normalized_rhs(con_ref, normalized_rhs(con_ref) / max_ratio)
                action_count += 1
            end
        elseif min_ratio > 1 && max_ratio < 1
            if max_ratio * min_ratio < 1
                for (key, val) in con_obj.func.terms
                    set_normalized_coefficient(con_ref, key, val * min_ratio)
                end
                set_normalized_rhs(con_ref, normalized_rhs(con_ref) * min_ratio)
                action_count += 1
            end
        end
    end
    return action_count
end