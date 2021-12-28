# TEST get_reitrement_period() function

function get_retirement_period_old(cur_period::Int, period_len::Int, lifetime::Int)
	years_from_start = cur_period * period_len # Years from start from the END of the current period
	ret_years = years_from_start - lifetime # Difference between end of current period and technology lifetime
	ret_period = floor(ret_years / period_len) # Compute the period before which all newly built capacity must be retired by the end of the current period
    if ret_period < 0
        return 0
	end
    return Int(ret_period)
end
function get_retirement_period(cur_period::Int, lifetime::Int, multi_period_settings::Dict)
	period_lens = multi_period_settings["PeriodLengths"]
	### years_from_start = cur_period * period_len # Years from start from the END of the current period # Pre-VSL
	years_from_start = sum(period_lens[1:cur_period])
	ret_years = years_from_start - lifetime # Difference between end of current period and technology lifetime
	### ret_period = floor(ret_years / period_len) # Compute the period before which all newly built capacity must be retired by the end of the current period # Pre-VSL
	ret_period = 0
	#println(ret_period, " - ", ret_years)
	while (ret_years - period_lens[ret_period+1] >= 0) & (ret_period < cur_period)
		ret_period += 1
		ret_years -= period_lens[ret_period]
		#println(ret_period, " - ", ret_years)
	end
    return Int(ret_period)
end

settings = Dict()
settings["PeriodLengths"] = zeros(Int64,0)

stages = [1, 2, 3, 4, 5]
stage_lengths = [5, 10, 15, 20]
lifetimes = [10, 15, 20, 25, 30]

for lifetime in lifetimes
	for stage_length in stage_lengths
		settings["PeriodLengths"] = zeros(Int64,0)
		for stage in stages
			append!(settings["PeriodLengths"], stage_length)
			println("Stage: ", stage, "  |  ", stage_length, "-year Stages  |  ", lifetime, " Year Lifetime")
			println("  Old: ", get_retirement_period_old(stage, stage_length, lifetime))
			println("  New: ", get_retirement_period(stage, lifetime, settings))
			println()
		end
	end
end
