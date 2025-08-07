using DataFrames
using Statistics
using Printf

include("struct.jl")

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
второй - словарь со статистиками комплексов.
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

        push!(_total, (path, custom_name, matched_tuple.code, matched_tuple.title,result_dict))
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

- `pqrst_vector`: StructArray, который является первым элементом результата функции `readxml_pqrst_anz`
- `point_count`: общее количество точек экзамена, которое берется из metadata, Int

Возвращает вектор кортежей: Vector{Tuple{String, Dict{String, Any}}}, где первый элемент - путь,
второй - словарь со статистиками эпизодов.
"""
function calc_episode_stats(found_nodes_result, fs, point_count)
    _total = []

    for (path, custom_name, matched_tuple) in found_nodes_result
        
        len_array = matched_tuple.len_segm
        starts_array = matched_tuple.starts

        EpisodeCount = len_array
        EpisodeCountDay = matched_tuple.is_day
        EpisodeCountNight = matched_tuple.is_night
        

        TotalDuration = sum(matched_tuple.dur)
        EpisodeDurationMax = matched_tuple.max_dur_s
        EpisodeDurationMin = matched_tuple.min_dur_s
        EpisodeDurationAvg = matched_tuple.dur_avg_s
   
        _time = point_count / fs
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
        push!(_total, (path, result_dict))
    end

    return _total
end


"""
Производит расчет статистик
    "HRIntervalSec" => 0,
    "EpisodeHRAvg" => 0,
    "EpisodeHRMax" => 0,
    "EpisodeHRMin" => 0,
    "EpisodeHRMaxTime" => "",
    "EpisodeHRMinTime" => "",
P   "RRMinMs" => 0.0,
P   "RRMaxMs" => 0.0

- `found_nodes_result`: Результат функции `find_all_nodes`, Vector{Tuple{Vector{Any}, String, NamedTuple}}.
- `pqrst_data`: Данные PQRST из `readxml_pqrst_anz`, (Vector{NamedTuple}, NamedTuple{timestart, fs}).

Возвращает вектор кортежей: Vector{Tuple{String, Dict{String, Any}}}, где первый элемент - путь,
второй - словарь со статистиками ЧСС.
"""
function calc_hr(found_nodes_result, pqrst_data)
    results = []
    pqrst_vector = pqrst_data[1] 
    metadata = pqrst_data[2]
    fs = metadata.fs

    for (path_vec, custom_name, matched_tuple) in found_nodes_result
        len_array = matched_tuple.len_segm
        starts_array = matched_tuple.starts
        
        # Инициализация результатов по умолчанию
        hr_interval_sec = 0.0
        episode_hr_avg_bpm = 0.0
        episode_hr_max_bpm = 0.0
        episode_hr_min_bpm = 0.0
        episode_hr_max_time_str = ""
        episode_hr_min_time_str = ""
        
        if !isempty(len_array) && !isempty(starts_array) && fs > 0 && !isempty(pqrst_vector)
            rr_ms_values = Float64[]
            rr_times = Float64[]
            
            # Сбор RR-интервалов в эпизодах
            for i in eachindex(len_array)
                start_point = starts_array[i]
                end_point = start_point + len_array[i]
                
                for qrs in pqrst_vector
                    qrs_time = qrs.timeQ
                    if start_point <= qrs_time < end_point
                        rr = qrs.RR_ms
                        if rr > 0
                            push!(rr_ms_values, rr)
                            push!(rr_times, qrs_time / fs)
                        end
                    end
                end
            end
            
            # Расчет статистик при наличии данных
            if !isempty(rr_ms_values)
                rr_sec = rr_ms_values ./ 1000.0
                hr_interval = mean(rr_sec)
                hr_interval_sec = round(hr_interval, digits=3)
                
                if hr_interval > 0
                    episode_hr_avg_bpm = round(60.0 / hr_interval, digits=3)
                end
                
                # Мин макс значения ЧСС
                min_rr, min_idx = findmin(rr_sec)
                max_rr, max_idx = findmax(rr_sec)
                
                if min_rr > 0
                    episode_hr_max_bpm = round(60.0 / min_rr, digits=3)
                    episode_hr_max_time_str = dur_s_to_hhmmss(rr_times[min_idx])
                end
                
                if max_rr > 0
                    episode_hr_min_bpm = round(60.0 / max_rr, digits=3)
                    episode_hr_min_time_str = dur_s_to_hhmmss(rr_times[max_idx])
                end
            end
        end
        
        if hasproperty(matched_tuple, :code)
            code = matched_tuple.code
        elseif hasproperty(matched_tuple, :rhythm_code)
            code = matched_tuple.rhythm_code
        else
            code = ""
        end

        rr_min_ms = 0.0
        rr_max_ms = 0.0

        is_pause = !isempty(path_vec) && string(path_vec[1]) == "Pauses"
        if is_pause && !isempty(len_array) && !isempty(starts_array) && !isempty(pqrst_vector)
            rr_values_in_pause = Float64[]
            for i in eachindex(len_array)
                start_point = starts_array[i]
                end_point = start_point + len_array[i]
                # Проходим по всем QRS комплексам
                for qrs in pqrst_vector
                    qrs_time = qrs.timeQ
                    # Проверяем, попал ли QRS внутрь текущего эпизода паузы
                    if start_point <= qrs_time < end_point
                        rr = qrs.RR_ms
                        if rr > 0
                            push!(rr_values_in_pause, rr)
                        end
                    end
                end
            end

            # Если нашлись RR-интервалы внутри паузы, считаем минимум и максимум
            if !isempty(rr_values_in_pause)
                rr_min_ms = minimum(rr_values_in_pause)
                rr_max_ms = maximum(rr_values_in_pause)
            end
        end

        # Формирование результата
        path_key = join(path_vec, "/")
        result_dict = Dict{String, Any}(
            "Path" => path_key,
            "CustomName" => custom_name,
            "Code" => code,
            "Title" => matched_tuple.title,
            "HRIntervalSec" => hr_interval_sec,
            "EpisodeHRAvg" => episode_hr_avg_bpm,
            "EpisodeHRMax" => episode_hr_max_bpm,
            "EpisodeHRMin" => episode_hr_min_bpm,
            "EpisodeHRMaxTime" => episode_hr_max_time_str,
            "EpisodeHRMinTime" => episode_hr_min_time_str,
            "RRMinMs" => rr_min_ms,
            "RRMaxMs" => rr_max_ms
        )
        
        push!(results, (path_vec, result_dict))
    end
    
    return results
end


"""
Объединяет результаты расчета статистик для комплексов, эпизодов и ЧСС в лоб
"""
function complex_stats(found_nodes_result, sleep, fs, point_count, pqrst_data)
    _total = []
    pqrst_vector = pqrst_data[1] 
    metadata = pqrst_data[2]
    
    for (path, custom_name, matched_tuple) in found_nodes_result
        bitvec = matched_tuple.bitvec
        len_array = matched_tuple.len_segm
        starts_array = matched_tuple.starts

        # Расчёт статистик комплексов и эпизодов (существующая логика)
        CmpxCount = sum(bitvec)
        CmpxPercent = round((CmpxCount / length(bitvec)) * 100, digits=3)
        CmpxOccurence = CmpxPercent < 1.0 ? "Rare" :
                        1.0 <= CmpxPercent < 10.0 ? "Moderate" : "Frequent"

        is_pause = !isempty(path) && path[1] == "Pauses"
        CmpxCount2s = 0
        CmpxCount3s = 0
        
        if is_pause && !isempty(len_array)
            durations_sec = len_array / fs
            CmpxCount2s = sum(durations_sec .>= 2.0)
            CmpxCount3s = sum(durations_sec .>= 3.0)
        end

        CmpxCountDay = 0
        CmpxCountNight = 0
        if is_pause
            night_count = 0
            for (sleep_start, sleep_end) in sleep
                # Индексы комплексов в паузах
                indices = findall(bitvec .== 1)
                night_count += sum(idx -> sleep_start <= idx <= sleep_end, indices)
            end
            CmpxCountNight = night_count
            CmpxCountDay = CmpxCount - night_count
        end

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

        durations = Float64[]
        for seg in matched_tuple.segm
            start_idx = first(seg)
            end_idx = last(seg)
            start_time = pqrst_vector[start_idx].timeQ
            end_time = pqrst_vector[end_idx].timeS
            duration_sec = (end_time - start_time) / fs
            push!(durations, duration_sec)
        end

        TotalDuration = sum(durations)
        EpisodeDurationMax = maximum(durations)
        EpisodeDurationMin = minimum(durations)
        EpisodeDurationAvg = mean(durations)
   
        _time = point_count / fs
        TotalDurationPercent = round((TotalDuration / _time) * 100, digits=3)
        
        # Расчёт статистик ЧСС (логика из calc_hr)
        hr_interval_sec = 0.0
        episode_hr_avg_bpm = 0.0
        episode_hr_max_bpm = 0.0
        episode_hr_min_bpm = 0.0
        episode_hr_max_time_str = ""
        episode_hr_min_time_str = ""
        rr_min_ms = 0.0
        rr_max_ms = 0.0

        if !isempty(len_array) && !isempty(starts_array) && fs > 0 && !isempty(pqrst_vector)
            rr_ms_values = Float64[]
            rr_times = Float64[]
            
            # Сбор RR-интервалов в эпизодах
            for i in eachindex(len_array)
                start_point = starts_array[i]
                end_point = start_point + len_array[i]
                for qrs in pqrst_vector
                    qrs_time = qrs.timeQ
                    if start_point <= qrs_time < end_point
                        rr = qrs.RR_ms
                        if rr > 0
                            push!(rr_ms_values, rr)
                            push!(rr_times, qrs_time / fs)
                        end
                    end
                end
            end
            
            # Расчёт статистик ЧСС
            if !isempty(rr_ms_values)
                rr_sec = rr_ms_values ./ 1000.0
                hr_interval = mean(rr_sec)
                hr_interval_sec = round(hr_interval, digits=3)
                
                if hr_interval > 0
                    episode_hr_avg_bpm = round(60.0 / hr_interval, digits=3)
                end
                
                min_rr, min_idx = findmin(rr_sec)
                max_rr, max_idx = findmax(rr_sec)
                
                if min_rr > 0
                    episode_hr_max_bpm = round(60.0 / min_rr, digits=3)
                    episode_hr_max_time_str = dur_s_to_hhmmss(rr_times[min_idx])
                end
                
                if max_rr > 0
                    episode_hr_min_bpm = round(60.0 / max_rr, digits=3)
                    episode_hr_min_time_str = dur_s_to_hhmmss(rr_times[max_idx])
                end
            end
            
            # Расчёт RRMinMs/RRMaxMs для пауз
            if is_pause
                rr_values_in_pause = Float64[]
                for i in eachindex(len_array)
                    start_point = starts_array[i]
                    end_point = start_point + len_array[i]
                    for qrs in pqrst_vector
                        qrs_time = qrs.timeQ
                        if start_point <= qrs_time < end_point
                            rr = qrs.RR_ms
                            rr > 0 && push!(rr_values_in_pause, rr)
                        end
                    end
                end
                
                if !isempty(rr_values_in_pause)
                    rr_min_ms = minimum(rr_values_in_pause)
                    rr_max_ms = maximum(rr_values_in_pause)
                end
            end
        end
        
        # Формирование итогового словаря
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
            "EpisodeCount" => EpisodeCount,
            "EpisodeCountDay" => EpisodeCountDay,
            "EpisodeCountNight" => EpisodeCountNight,
            "EpisodeDurationAvg" => dur_s_to_hhmmss(EpisodeDurationAvg),
            "EpisodeDurationMax" => dur_s_to_hhmmss(EpisodeDurationMax),
            "EpisodeDurationMin" => dur_s_to_hhmmss(EpisodeDurationMin),
            "TotalDuration" => dur_s_to_hhmmss(TotalDuration),
            "TotalDurationPercent" => TotalDurationPercent,
            "HRIntervalSec" => hr_interval_sec,
            "EpisodeHRAvg" => episode_hr_avg_bpm,
            "EpisodeHRMax" => episode_hr_max_bpm,
            "EpisodeHRMin" => episode_hr_min_bpm,
            "EpisodeHRMaxTime" => episode_hr_max_time_str,
            "EpisodeHRMinTime" => episode_hr_min_time_str,
            "RRMinMs" => rr_min_ms,
            "RRMaxMs" => rr_max_ms
        )
        
        # Определение кода аритмии
        code = hasproperty(matched_tuple, :code) ? matched_tuple.code :
               hasproperty(matched_tuple, :rhythm_code) ? matched_tuple.rhythm_code : ""
        
        push!(_total, (path, custom_name, code, matched_tuple.title, result_dict))
    end

    return _total   
end