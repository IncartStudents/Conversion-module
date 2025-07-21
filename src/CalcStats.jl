using DataFrames


function calc_qrs_stats(data)
    total_count = length(data)
    unique_forms = Set{Symbol}()

    for entry in data
        push!(unique_forms, entry.form)
    end

    counts = Dict{Symbol, Int}()
    for form in unique_forms
        counts[form] = 0
    end

    for entry in data
        counts[entry.form] += 1
    end

    result = Dict{String, Any}()
    result["CmpxCountTotal"] = total_count

    for form in unique_forms
        count = counts[form]
        percent = total_count > 0 ? (count / total_count) * 100 : 0.0
        result[string(form)] = Dict("CmpxCount" => count, "CmpxCountPercent" => percent)
    end

    return result
end


function calc_qrs_statsv2(data)
    pqrst_df = DataFrame(data)

    pqrst_gdf = groupby(pqrst_df, :form)

    form_count_df = combine(pqrst_gdf, nrow => :CmpxCount)

    filt_fc_df = filter(:form => f -> !occursin(r"^[XZ]", string(f)), form_count_df)

    total_count = sum(filt_fc_df.CmpxCount)

    cc_per = [round((cc / total_count) * 100, digits=3) for cc in filt_fc_df.CmpxCount]

    filt_fc_df[!, :CmpxCountPercent] = cc_per

    return filt_fc_df
end

"""
Производит расчет статистики по формам QRS.
Возвращает объект типа `DataFrame` с колонками: [form, CmpxCount, CmpxCountPercent]
"""
function calc_qrs_statsv3(data)
    pqrst_df = filter(row -> !occursin(r"^[XZ]", string(row.form)), DataFrame(data))

    form_count_df = combine(groupby(pqrst_df, :form),
        nrow => :CmpxCount,
        :form => (f -> round((length(f) / nrow(pqrst_df)) * 100, digits=3)) => :CmpxCountPercent
    )

    return form_count_df
end