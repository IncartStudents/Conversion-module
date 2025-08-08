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

        code = ""
        if hasproperty(matched_tuple, :code)
            code = matched_tuple.code
        elseif hasproperty(matched_tuple, :rhythm_code)
            code = matched_tuple.rhythm_code
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

        push!(_total, (path, custom_name, code, matched_tuple.title,result_dict))
    end

    return _total
end


"""
Вычисляет длительности эпизодов в секундах.
- `segs`: Вектор сегментов (диапазонов индексов)
- `pqrst_vector`: Данные PQRST
- `fs`: Частота дискретизации

Возвращает вектор длительностей в секундах для каждого сегмента.
"""
function calc_episode_durations(segs, pqrst_vector, fs)
    durations = Float64[]
    for seg in segs
        start_idx = first(seg)
        end_idx = last(seg)
        start_time = pqrst_vector[start_idx].timeQ
        end_time = pqrst_vector[end_idx].timeS
        duration_sec = (end_time - start_time) / fs
        push!(durations, duration_sec)
    end
    return durations
end


"""
Подсчитывает количество дневных и ночных эпизодов.
- `segs`: Вектор сегментов
- `pqrst_vector`: Данные PQRST
- `sleep`: Вектор периодов сна в формате [(start1, end1), (start2, end2)]

Возвращает кортеж (количество_ночных_эпизодов, количество_дневных_эпизодов)
"""
function calc_episode_night(segs, pqrst_vector, sleep)
    is_night = 0
    is_day = 0
    for seg in segs
        start_idx = first(seg)
        end_idx = last(seg)

        start_time = pqrst_vector[start_idx].timeQ
        end_time = pqrst_vector[end_idx].timeS

        is_night_flag = false
        for (sleep_start, sleep_end) in sleep
            if start_time < sleep_end && end_time > sleep_start
                is_night_flag = true
                break
            end
        end

        if is_night_flag
            is_night += 1
        else
            is_day += 1
        end
    end
    return is_night, is_day
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
- `hr_trend`: Словарь с полями `MeasureInterval` и `Trend`, Dict{String, Any}.
- `pqrst_data`: Данные PQRST из `readxml_pqrst_anz`, (Vector{NamedTuple}, NamedTuple{timestart, fs}).

Возвращает вектор кортежей: Vector{Tuple{String, Dict{String, Any}}}, где первый элемент - путь,
второй - словарь со статистиками ЧСС.
"""
function calc_hr(found_nodes_result, hr_trend, pqrst_data)
    results = []
    pqrst_vector = pqrst_data[1] 
    metadata = pqrst_data[2]
    fs = metadata.fs
    measure_interval = hr_trend["MeasureInterval"][1]

    for (path_vec, custom_name, matched_tuple) in found_nodes_result
        hr_ind = Dict("start_hr" => [], "end_hr" => [])
        rr_ms = Float64[]

        for seg in matched_tuple.segm
            start_idx = first(seg)
            end_idx = last(seg)
            start_ = pqrst_vector[start_idx].timeQ
            end_ = pqrst_vector[end_idx].timeS

            # Сбор RR интервалов для текущего сегмента
            for n in start_idx:end_idx
                rr_value = pqrst_vector[n].RR_ms
                if rr_value > 0
                    push!(rr_ms, rr_value)
                end
            end

            # Определение индексов в HR тренде
            start_hr_index = -1
            end_hr_index = -1
            
            for i in 1:length(hr_trend["Trend"])
                trend_time_points = i * measure_interval * fs
                if start_hr_index == -1 && trend_time_points >= start_
                    start_hr_index = i - 1
                end
                if trend_time_points <= end_
                    end_hr_index = i - 1
                end
            end
            
            if start_hr_index != -1
                push!(hr_ind["start_hr"], start_hr_index)
            end
            if end_hr_index != -1
                push!(hr_ind["end_hr"], end_hr_index)
            end
        end

        hr_avg_bpm = 0.0
        hr_max_bpm = 0.0
        hr_min_bpm = 0.0
        episode_hr_max_time = ""
        episode_hr_min_time = ""
        rr_min_ms = 0.0
        rr_max_ms = 0.0

        hr_values_bpm = Float64[]
        hr_indices = Int[]

        # Собираем все значения ЧСС для найденных индексов
        for i in 1:min(length(hr_ind["start_hr"]), length(hr_ind["end_hr"]))
            start_idx_0 = hr_ind["start_hr"][i]
            end_idx_0 = hr_ind["end_hr"][i]
            
            start_idx_1 = start_idx_0 + 1
            end_idx_1 = end_idx_0 + 1
            
            if 1 <= start_idx_1 <= end_idx_1 <= length(hr_trend["Trend"])
                append!(hr_values_bpm, hr_trend["Trend"][start_idx_1:end_idx_1])
                append!(hr_indices, start_idx_1:end_idx_1)
            end
        end

        if !isempty(hr_values_bpm)
            hr_avg_bpm = round(mean(hr_values_bpm), digits=3)
            hr_max_bpm, max_hr_idx = findmax(hr_values_bpm)
            hr_min_bpm, min_hr_idx = findmin(hr_values_bpm)
            
            # Вычисляем временные метки для максимума и минимума
            if 1 <= max_hr_idx <= length(hr_indices)
                max_index_in_trend = hr_indices[max_hr_idx]
                # Время в секундах от начала записи
                time_in_seconds = (max_index_in_trend - 1) * measure_interval
                episode_hr_max_time = dur_s_to_hhmmss(Float64(time_in_seconds))
            end
            
            if 1 <= min_hr_idx <= length(hr_indices)
                min_index_in_trend = hr_indices[min_hr_idx]
                # Время в секундах от начала записи
                time_in_seconds = (min_index_in_trend - 1) * measure_interval
                episode_hr_min_time = dur_s_to_hhmmss(Float64(time_in_seconds))
            end
        end

        # Расчет RRMinMs и RRMaxMs
        if !isempty(rr_ms)
            rr_min_ms = minimum(rr_ms)
            rr_max_ms = maximum(rr_ms)
        end

        code = ""
        if hasproperty(matched_tuple, :code)
            code = matched_tuple.code
        elseif hasproperty(matched_tuple, :rhythm_code)
            code = matched_tuple.rhythm_code
        end

        # Формирование результата
        path_key = join(path_vec, "/")
        result_dict = Dict{String, Any}(
            "Path" => path_key,
            "CustomName" => custom_name,
            "Code" => code,
            "Title" => matched_tuple.title,
            "HRIntervalSec" => measure_interval,
            "EpisodeHRAvg" => hr_avg_bpm,
            "EpisodeHRMax" => hr_max_bpm,
            "EpisodeHRMin" => hr_min_bpm,
            "EpisodeHRMaxTime" => episode_hr_max_time,
            "EpisodeHRMinTime" => episode_hr_min_time,
            "RRMinMs" => rr_min_ms,
            "RRMaxMs" => rr_max_ms
        )
        push!(results, (path_vec, result_dict))
    end
    return results
end


"""
Объединяет результаты расчета статистик для комплексов, эпизодов и ЧСС вызовом функций
"""
function complex_stats(found_nodes_result, sleep, fs, point_count, pqrst_data, hr_trend)
    cmpx_results = calc_cmpx_stats(found_nodes_result, sleep, fs)
    episode_results = calc_episode_stats(found_nodes_result, fs, point_count)
    hr_results = calc_hr(found_nodes_result, hr_trend, pqrst_data)
    
    _total = []
    
    # Собираем результаты по каждому пути
    for i in 1:length(found_nodes_result)
        (path, custom_name, matched_tuple) = found_nodes_result[i]
        
        cmpx_dict = cmpx_results[i][5]
        episode_dict = episode_results[i][2]
        hr_dict = hr_results[i][2]
        
        merged_dict = Dict{String, Any}()
        
        # Добавляем данные из cmpx_dict (исключая "Path")
        for (k, v) in cmpx_dict
            k != "Path" && (merged_dict[k] = v)
        end
        
        # Добавляем данные из episode_dict (исключая "Path")
        for (k, v) in episode_dict
            k != "Path" && (merged_dict[k] = v)
        end
        
        # Добавляем данные из hr_dict (включая специальные поля)
        for (k, v) in hr_dict
            if k == "CustomName" || k == "Code" || k == "Title"
                merged_dict[k] = v
            elseif k != "Path"
                merged_dict[k] = v
            end
        end
        
        merged_dict["Path"] = hr_dict["Path"]
        
        push!(_total, (
            path, 
            custom_name, 
            hr_dict["Code"], 
            hr_dict["Title"], 
            merged_dict
        ))
    end
    
    return _total
end