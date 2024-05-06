@doc raw"""
	write_emissions(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting time-dependent CO$_2$ emissions by zone.

"""
function write_emissions(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    if (setup["WriteShadowPrices"] == 1 || setup["UCommit"] == 0 ||
        (setup["UCommit"] == 2 && (setup["OperationalReserves"] == 0 ||
          (setup["OperationalReserves"] > 0 && inputs["pDynamic_Contingency"] == 0)))) # fully linear model
        # CO2 emissions by zone

        if setup["CO2Cap"] >= 1
            # Dual variable of CO2 constraint = shadow price of CO2
            tempCO2Price = zeros(Z, inputs["NCO2Cap"])
            if has_duals(EP) == 1
                for cap in 1:inputs["NCO2Cap"]
                    for z in findall(x -> x == 1, inputs["dfCO2CapZones"][:, cap])
                        tempCO2Price[z, cap] = (-1) *
                                               dual.(EP[:cCO2Emissions_systemwide])[cap]
                        # when scaled, The objective function is in unit of Million US$/kton, thus k$/ton, to get $/ton, multiply 1000
                        tempCO2Price[z, cap] *= scale_factor
                    end
                end
            end
            dfEmissions = hcat(DataFrame(Zone = 1:Z),
                DataFrame(tempCO2Price, :auto),
                DataFrame(AnnualSum = Array{Float64}(undef, Z)))
            auxNew_Names = [Symbol("Zone");
                            [Symbol("CO2_Price_$cap") for cap in 1:inputs["NCO2Cap"]];
                            Symbol("AnnualSum")]
            rename!(dfEmissions, auxNew_Names)
        else
            dfEmissions = DataFrame(Zone = 1:Z, AnnualSum = Array{Float64}(undef, Z))
        end

        emissions_by_zone = value.(EP[:eEmissionsByZone])
        for i in 1:Z
            dfEmissions[i, :AnnualSum] = sum(inputs["omega"] .* emissions_by_zone[i, :]) *
                                         scale_factor
        end

        if setup["WriteOutputs"] == "annual"
            total = DataFrame(["Total" sum(dfEmissions.AnnualSum)], [:Zone; :AnnualSum])
            if setup["CO2Cap"] >= 1
                total = DataFrame(
                    ["Total" zeros(1, inputs["NCO2Cap"]) sum(dfEmissions.AnnualSum)],
                    [:Zone;
                     [Symbol("CO2_Price_$cap") for cap in 1:inputs["NCO2Cap"]];
                     :AnnualSum])
            end
            dfEmissions = vcat(dfEmissions, total)
            CSV.write(joinpath(path, "emissions.csv"), dfEmissions)
        else# setup["WriteOutputs"] == "full"
            dfEmissions = hcat(dfEmissions,
                DataFrame(emissions_by_zone * scale_factor, :auto))
            if setup["CO2Cap"] >= 1
                auxNew_Names = [Symbol("Zone");
                                [Symbol("CO2_Price_$cap") for cap in 1:inputs["NCO2Cap"]];
                                Symbol("AnnualSum");
                                [Symbol("t$t") for t in 1:T]]
                rename!(dfEmissions, auxNew_Names)
                total = DataFrame(
                    ["Total" zeros(1, inputs["NCO2Cap"]) sum(dfEmissions[!,
                        :AnnualSum]) fill(0.0, (1, T))],
                    :auto)
                for t in 1:T
                    total[:, t + inputs["NCO2Cap"] + 2] .= sum(dfEmissions[:,
                        Symbol("t$t")][1:Z])
                end
            else
                auxNew_Names = [Symbol("Zone");
                                Symbol("AnnualSum");
                                [Symbol("t$t") for t in 1:T]]
                rename!(dfEmissions, auxNew_Names)
                total = DataFrame(
                    ["Total" sum(dfEmissions[!, :AnnualSum]) fill(0.0,
                        (1, T))],
                    :auto)
                for t in 1:T
                    total[:, t + 2] .= sum(dfEmissions[:, Symbol("t$t")][1:Z])
                end
            end
            rename!(total, auxNew_Names)
            dfEmissions = vcat(dfEmissions, total)
            CSV.write(joinpath(path, "emissions.csv"),
                dftranspose(dfEmissions, false),
                writeheader = false)
        end
        ## Aaron - Combined elseif setup["Dual_MIP"]==1 block with the first block since they were identical. Why do we have this third case? What is different about it?
    else
        # CO2 emissions by zone
        emissions_by_zone = value.(EP[:eEmissionsByZone])
        dfEmissions = hcat(DataFrame(Zone = 1:Z),
            DataFrame(AnnualSum = Array{Float64}(undef, Z)))
        for i in 1:Z
            dfEmissions[i, :AnnualSum] = sum(inputs["omega"] .* emissions_by_zone[i, :]) *
                                         scale_factor
        end

        if setup["WriteOutputs"] == "annual"
            total = DataFrame(["Total" sum(dfEmissions.AnnualSum)], [:Zone; :AnnualSum])
            dfEmissions = vcat(dfEmissions, total)
            CSV.write(joinpath(path, "emissions.csv"), dfEmissions)
        else# setup["WriteOutputs"] == "full"
            dfEmissions = hcat(dfEmissions,
                DataFrame(emissions_by_zone * scale_factor, :auto))
            auxNew_Names = [Symbol("Zone");
                            Symbol("AnnualSum");
                            [Symbol("t$t") for t in 1:T]]
            rename!(dfEmissions, auxNew_Names)
            total = DataFrame(["Total" sum(dfEmissions[!, :AnnualSum]) fill(0.0, (1, T))],
                :auto)
            for t in 1:T
                total[:, t + 2] .= sum(dfEmissions[:, Symbol("t$t")][1:Z])
            end
            rename!(total, auxNew_Names)
            dfEmissions = vcat(dfEmissions, total)
            CSV.write(joinpath(path, "emissions.csv"),
                dftranspose(dfEmissions, false),
                writeheader = false)
        end
    end
    return nothing
end
