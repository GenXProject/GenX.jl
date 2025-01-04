module TestCapacityReserveMargin2

using Test
include(joinpath(@__DIR__, "utilities.jl"))


test_path = joinpath(@__DIR__,  "three_zones_capacity_reserve")

genx_setup = Dict(
    "CapacityReserveMargin" => 2
)
  
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

max_demand_by_zone = maximum(inputs["pD"], dims=1)

min_cap_reserve = sum(d * (1+c) for (d,c) in zip(max_demand_by_zone, inputs["dfCapRes"]))

@test value.(EP[:eCapResMarBalance])[1] >= min_cap_reserve

end
