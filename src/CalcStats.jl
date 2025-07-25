using DataFrames


"""
Производит расчет статистики по формам QRS.
Возвращает объект типа `DataFrame` с колонками: [form, CmpxCount, CmpxCountPercent]
"""
function calc_qrs_stats(data)
    pqrst_df = filter(row -> !occursin(r"^[XZ]", string(row.form)), DataFrame(data))

    form_count_df = combine(groupby(pqrst_df, :form),
        nrow => :CmpxCount,
        :form => (f -> round((length(f) / nrow(pqrst_df)) * 100, digits=3)) => :CmpxCountPercent
    )
    return form_count_df
end

"""
Производит расчет статистик  `TotalDuration`, `TotalDurationPercent`
"""
function calc_duration()
end

"""
Производит расчет статистик     
    "CmpxCount" => 0,
P   "CmpxCountDay" => 0,
P   "CmpxCountNight" => 0,
    "CmpxPercent" => 0.0,
    "CmpxOccurence" => "",
P   "CmpxCount2s" => 0,
P   "CmpxCount3s" => 0,.
"""
function calc_cmpx_stats(data, sleep, fs)
    
    _total = []
    CmpxCount = 0
    CmpxCountDay = 0
    CmpxCountNight = 0
    CmpxPercent = 0.0
    CmpxOccurence = ""
    CmpxCount2s = 0
    CmpxCount3s = 0

    for item in data
        bitvec = item.bitvec
        CmpxCount = sum(bitvec)
        CmpxPercent = round((CmpxCount / length(bitvec)) * 100, digits=3)
        if CmpxPercent < 1.0
            CmpxOccurence = "Rare"
        elseif 1.0 <= CmpxPercent < 10.0
            CmpxOccurence = "Moderate"
        else
            CmpxOccurence = "Frequent"
        end

        if item[1][1] == "Pauses"
            lengths = [el / fs for el in item.len]
            CmpxCount2s = 0
            CmpxCount3s = 0
            for l in lengths
                if l >= 2.0
                    CmpxCount2s += 1
                end
                if l >= 3.0
                    CmpxCount3s += 1
                end
            end
        
        _start = item.starts
        _end = item.starts + item.len
        
        for (_st, _fin) in sleep
            if _start >= _st && _end <= _fin
                CmpxCountNight += 1
            end
        end
        CmpxCountDay = CmpxCount - CmpxCountNight
        end
    
    _item = [
        "$(item.code)",
        Dict(
            "CmpxCount" => CmpxCount,
            "CmpxCountDay" => CmpxCountDay,
            "CmpxCountNight" => CmpxCountNight,
            "CmpxPercent" => CmpxPercent,
            "CmpxOccurence" => CmpxOccurence,
            "CmpxCount2s" => CmpxCount2s,
            "CmpxCount3s" => CmpxCount3s
        )
    ]
    push!(_total, _item)
    end

    return _total
end

"""
Производит расчет статистики по формам QRS.
"""
function calc_episode_stats()
end

"""
Производит расчет статистики по формам QRS.
"""
function calc_rr_stats()
end

"""
Производит расчет статистики по формам QRS.
"""
function calc_hr()
end