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
    COMMIT, data = _prepare_ucommit_var(inputs, EP, var)
    df_annual = _prepare_annualsum_df(inputs, COMMIT, data)
    _write_timeseries_or_annual_file(df_annual, data, path, setup, filename)
end

function _prepare_ucommit_var(inputs::Dict, EP::Model, var::Symbol)
    COMMIT = inputs["COMMIT"]
    data = value.(EP[var][COMMIT, :].data)
    return COMMIT, data
end
