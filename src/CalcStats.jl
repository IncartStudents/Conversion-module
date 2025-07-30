using DataFrames
using Statistics
using Printf


"""
Функция для преобразования секунд в строку формата HH:MM:SS.sssssss
"""
function dur_s_to_hhmmss(seconds::Float64)::String 
    total_seconds = seconds
    hours = floor(Int, total_seconds / 3600)
    minutes = floor(Int, (total_seconds - hours * 3600) / 60)
    secs = total_seconds - hours * 3600 - minutes * 60  

    secs_int = floor(Int, secs)
    secs_frac = secs - secs_int

    frac_part_padded = @sprintf("%07d", round(Int, secs_frac * 10_000_000))
    return @sprintf("%02d:%02d:%02d.%s", hours, minutes, secs_int, frac_part_padded)
end


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
Производит расчет статистик     
    "CmpxCount" => 0,
P   "CmpxCountDay" => 0,
P   "CmpxCountNight" => 0,
    "CmpxPercent" => 0.0,
    "CmpxOccurence" => "",
P   "CmpxCount2s" => 0,
P   "CmpxCount3s" => 0.

- `found_nodes_result`: Результат функции `find_all_nodes`, Vector{Tuple{Vector{Any}, String, NamedTuple}}
- `sleep`: Вектор пар (начало, конец) периодов сна, Vector{Tuple{Int, Int}}
- `fs`: Частота дискретизации, Int

Возвращает вектор кортежей: Vector{Tuple{String, Dict{String, Any}}}, где первый элемент - путь,
второй - словарь со статистиками эпизодов.
"""
function calc_cmpx_stats(found_nodes_result, sleep, fs)
    
    _total = []

    for (path, custom_name, matched_tuple) in found_nodes_result

        bitvec = matched_tuple.bitvec
        len_array = matched_tuple.len
        starts_array = matched_tuple.starts

        CmpxCount = sum(bitvec)
        CmpxPercent = round((CmpxCount / length(bitvec)) * 100, digits=3)
        CmpxOccurence = ""
        if CmpxPercent < 1.0
            CmpxOccurence = "Rare"
        elseif 1.0 <= CmpxPercent < 10.0
            CmpxOccurence = "Moderate"
        else
            CmpxOccurence = "Frequent"
        end

        is_pause = !isempty(path) && string(path[1]) == "Pauses"
        CmpxCount2s = 0
        CmpxCount3s = 0
        
        if is_pause && !isempty(len_array)
            durations_sec = len_array / fs
            CmpxCount2s = sum(durations_sec .>= 2.0)
            CmpxCount3s = sum(durations_sec .>= 3.0)
        end

        CmpxCountDay = 0
        CmpxCountNight = 0
        indx = []
        if is_pause
            for i in 1:length(bitvec)
                if bitvec[i] == 1
                    push!(indx, i)
                    break
                end
            end

            for (start_p, end_p) in sleep
                for ind in indx
                    if ind >= start_p && ind <= end_p
                        CmpxCountNight += 1
                    else
                        CmpxCountDay += 1
                    end

                end
            end
        end

        
        path_key = join(path, "/")
        result_dict = Dict{String, Any}(
            "Path" => path_key,
            "CmpxCount" => CmpxCount,
            "CmpxCountDay" => CmpxCountDay,
            "CmpxCountNight" => CmpxCountNight,
            "CmpxPercent" => CmpxPercent,
            "CmpxOccurence" => CmpxOccurence,
            "CmpxCount2s" => CmpxCount2s,
            "CmpxCount3s" => CmpxCount3s,
        )

        push!(_total, (path_key, result_dict))
    end

    return _total
end

"""
Производит расчет статистик
    "EpisodeCount" => 0,
    "EpisodeCountDay" => 0,
    "EpisodeCountNight" => 0,
    "EpisodeDurationAvg" => "",
    "EpisodeDurationMax" => "",
    "EpisodeDurationMin" => "",
    "TotalDuration" => "",
    "TotalDurationPercent" => 0.0.

- `point_count`: общее количество точек экзамена, которое берется из metadata, Int
"""
function calc_episode_stats(found_nodes_result, sleep, fs, point_count=meta.point_count)
    _total = []

    for (path, custom_name, matched_tuple) in found_nodes_result
        
        len_array = matched_tuple.len
        starts_array = matched_tuple.starts

        EpisodeCount = length(len_array)
        EpisodeCountDay = 0
        EpisodeCountNight = 0

        for i in 1:length(len_array)
                start_point = starts_array[i]
                end_point = starts_array[i] + len_array[i]

                is_night = false
                for (sleep_start, sleep_end) in sleep
                    if start_point < sleep_end && end_point > sleep_start
                         is_night = true
                         break
                    end
                end

                if is_night
                    EpisodeCountNight += 1
                else
                    EpisodeCountDay += 1
                end
        
        end

        durations_sec = len_array / fs

        EpisodeDurationAvg = mean(durations_sec)
        EpisodeDurationMax = maximum(durations_sec)
        EpisodeDurationMin = minimum(durations_sec)
        
        _time = point_count / fs
        TotalDuration = EpisodeCount * EpisodeDurationAvg
        TotalDurationPercent = round((TotalDuration / _time) * 100, digits=3)
        
        path_key = join(path, "/")
        result_dict = Dict{String, Any}(
            "Path" => path_key,
            "EpisodeCount" => EpisodeCount,
            "EpisodeCountDay" => EpisodeCountDay,
            "EpisodeCountNight" => EpisodeCountNight,
            "EpisodeDurationAvg" => dur_s_to_hhmmss(EpisodeDurationAvg),
            "EpisodeDurationMax" => dur_s_to_hhmmss(EpisodeDurationMax),
            "EpisodeDurationMin" => dur_s_to_hhmmss(EpisodeDurationMin),
            "TotalDuration" => dur_s_to_hhmmss(TotalDuration),
            "TotalDurationPercent" => TotalDurationPercent
        )
        push!(_total, (path_key, result_dict))
    end

    return _total
end


# Функция calc_rr_stats не нужна, так как RRMin и RRMax берем их xml -> пересчет во время
# Эти поля есть только для пауз
"""
Производит расчет статистик
    "RRMinMs" => 0.0,
    "RRMaxMs" => 0.0
"""
function calc_rr_stats()
end

"""
Производит расчет статистик
    "HRIntervalSec" => 0,
    "EpisodeHRAvg" => 0,
    "EpisodeHRMax" => 0,
    "EpisodeHRMin" => 0,
    "EpisodeHRMaxTime" => "",
    "EpisodeHRMinTime" => ""
"""
function calc_hr()
end