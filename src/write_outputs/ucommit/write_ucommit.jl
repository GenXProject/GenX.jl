function write_start(path, inputs, setup, EP)
    _write_ucommit_var(path, inputs, setup, EP, :vSTART, "Start")
end

function write_commit(path, inputs, setup, EP)
    _write_ucommit_var(path, inputs, setup, EP, :vCOMMIT, "Commit")
end

function write_shutdown(path, inputs, setup, EP)
    _write_ucommit_var(path, inputs, setup, EP, :vSHUT, "Shutdown")
end

function _write_ucommit_var(path, inputs, setup, EP, var, filename)
    COMMIT, data = _eval_ucommit_var(inputs, EP, var)
    df_annual = _create_annualsum_df(inputs, COMMIT, data)
    write_temporal_data(df_annual, data, path, setup, filename)
end

function _eval_ucommit_var(inputs::Dict, EP::Model, var::Symbol)
    COMMIT = inputs["COMMIT"]
    data = value.(EP[var][COMMIT, :].data)
    return COMMIT, data
end
