function write_start(path, inputs, setup, EP)
    _write_ucommit_var(path, inputs, setup, EP, :vSTART, "start")
end

function write_commit(path, inputs, setup, EP)
    _write_ucommit_var(path, inputs, setup, EP, :vCOMMIT, "commit")
end

function write_shutdown(path, inputs, setup, EP)
    _write_ucommit_var(path, inputs, setup, EP, :vSHUT, "shutdown")
end

function _write_ucommit_var(path, inputs, setup, EP, var, filename)
    df_annual, data = _prepare_ucommit_var(inputs, EP, var)
    _write_ucommit_var(df_annual, data, path, setup, filename)
end

function _prepare_ucommit_var(inputs::Dict, EP::Model, var::Symbol)
    COMMIT = inputs["COMMIT"]
    resources = inputs["RESOURCE_NAMES"][COMMIT]
    zones = inputs["R_ZONES"][COMMIT]

    df_annual= DataFrame(Resource = resources, Zone = zones)
    data = value.(EP[var][COMMIT, :].data)
    df_annual.AnnualSum = data * inputs["omega"]
    return df_annual, data
end

function _write_ucommit_var(df_annual, data, path, setup::Dict, filename::AbstractString)
    filepath = joinpath(path, filename*".csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, df_annual)
    else # setup["WriteOutputs"] == "full"	
        df_full= write_fulltimeseries(filepath, data, df_annual)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, df_full, filename)
            @info("Writing Full Time Series for " *filename)
        end
    end
    return nothing
end


