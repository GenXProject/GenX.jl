@doc raw"""
    simple_operation(num1::Float64, num2::Float64)

This is just a simple function for adding two numbers intended to start off the unit testing. This function 
isn't used in GenX and will be replaced by the ones that are used as we develop the fully-grown unit testing.
"""
function simple_operation(num1::Float64, num2::Float64)
    num3 = num1 + num2
    return num3
end
