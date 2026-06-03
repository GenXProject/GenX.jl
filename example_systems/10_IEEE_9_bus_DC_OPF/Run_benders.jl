###############################################################################
# Run Example 10 (IEEE 9-bus DC OPF) using Benders decomposition with Gurobi.
###############################################################################

using Revise
using Gurobi
using GenX

const _CASE = dirname(@__FILE__)
const _SETTINGS_DIR = joinpath(_CASE, "settings")
const _MAIN_SETTINGS = joinpath(_SETTINGS_DIR, "genx_settings.yml")
const _BENDERS_SETTINGS = joinpath(_SETTINGS_DIR, "genx_benders_settings.yml")
const _BACKUP = _MAIN_SETTINGS * ".bak"

cp(_MAIN_SETTINGS, _BACKUP; force = true)
cp(_BENDERS_SETTINGS, _MAIN_SETTINGS; force = true)

try
	run_genx_case!(_CASE, Gurobi.Optimizer)
catch e
	@error "Error running GenX case" exception = e
	rethrow()
finally
	cp(_BACKUP, _MAIN_SETTINGS; force = true)
	rm(_BACKUP; force = true)
end
