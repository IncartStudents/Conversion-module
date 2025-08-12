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
Строит битовые векторы для родительских узлов на основе дочерних узлов.
Возвращает словарь: Dict{String, BitVector} (ключ - путь, значение - битовый вектор)
"""
function build_parent_bitvectors(found_nodes_result)
    # Собираем все битовые векторы
    all_bitvecs = Dict{String, BitVector}()
    for (path, _, matched_tuple) in found_nodes_result
        path_key = join(path, "/")
        all_bitvecs[path_key] = matched_tuple.bitvec
    end

    all_paths = Set{String}()
    for (path, _, _) in found_nodes_result
        path_str = ""
        for part in path
            path_str = isempty(path_str) ? part : path_str * "/" * part
            push!(all_paths, path_str)
        end
    end

    parent_bitvecs = Dict{String, BitVector}()
    
    sorted_paths = sort(collect(all_paths), by=p->length(split(p, "/")), rev=true)
    
    for path in sorted_paths
        if path == "Rhythms" || path == "Pauses"
            continue
        end
        # Собираем всех потомков
        children_bitvecs = []
        for (child_path_key, child_bitvec) in all_bitvecs
            if startswith(child_path_key, path * "/")
                push!(children_bitvecs, child_bitvec)
            end
        end
        
        for (parent_path, parent_bitvec) in parent_bitvecs
            if startswith(parent_path, path * "/")
                push!(children_bitvecs, parent_bitvec)
            end
        end
        
        if !isempty(children_bitvecs)
            combined_bitvec = reduce(.|, children_bitvecs)
            parent_bitvecs[path] = combined_bitvec
        end
    end

    return parent_bitvecs
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
                    # break
                end
            end

            for ind in indx
                is_night = false
                for (start_p, end_p) in sleep
                    if start_p <= ind <= end_p
                        is_night = true
                        break
                    end
                end
                is_night ? (CmpxCountNight += 1) : (CmpxCountDay += 1)
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
            if max(start_time, sleep_start) < min(end_time, sleep_end)
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
Производит расчет статистик:
    "TotalMotionArtfCount": Общее количество интервалов с движениями
    "TotalMotionArtfPercent": Процент интервалов с движениями от общего количества интервалов (округлено до 3 знаков)
    "DayMotionArtfCount": Количество интервалов с движениями в дневное время (вне периодов сна)
    "NightMotionArtfCount": Количество интервалов с движениями в ночное время (в периоды сна)

Возвращает словарь Duct со статистиками.
"""
function calculate_motion_statistics(motion_trend, sleep_frag, fs)
    motion_interval_sec = motion_trend["MeasureInterval"][1]  # 10 seconds
    motion_string = motion_trend["Trend"]
    total_intervals = length(motion_string)
    
    motion_count = 0
    day_motion_count = 0
    night_motion_count = 0
    
    for i in 1:total_intervals
        if motion_string[i] == '1'
            motion_count += 1
            
            # Вычисляем временные границы интервала
            start_time_sec = (i-1) * motion_interval_sec
            end_time_sec = i * motion_interval_sec
            
            # Проверяем, попадает ли интервал в период сна
            is_night = false
            # перевести sleep_start и в sleep_end в секунды а не в отсчеты
            for (sleep_start, sleep_end) in sleep_frag
                if max(start_time_sec, sleep_start / fs) < min(end_time_sec, sleep_end / fs)
                    is_night = true
                    break
                end
            end
            
            if is_night
                night_motion_count += 1
            else
                day_motion_count += 1
            end
        end
    end
    
    motion_percent = (motion_count / total_intervals) * 100
    
    return Dict(
        "TotalMotionArtfCount" => motion_count,
        "TotalMotionArtfPercent" => round(motion_percent, digits=3),
        "DayMotionArtfCount" => day_motion_count,
        "NightMotionArtfCount" => night_motion_count
    )
end


"""
Объединяет результаты расчета статистик для комплексов, эпизодов и ЧСС
"""
function complex_stats(found_nodes_result, sleep, fs, point_count, pqrst_data, hr_trend)
    # Рассчитываем базовые статистики для всех узлов
    cmpx_results = calc_cmpx_stats(found_nodes_result, sleep, fs)
    episode_results = calc_episode_stats(found_nodes_result, fs, point_count)
    hr_results = calc_hr(found_nodes_result, hr_trend, pqrst_data)
    
    # Строим битовые векторы для родительских узлов
    parent_bitvecs = build_parent_bitvectors(found_nodes_result)
    
    _total = []
    
    # Обрабатываем все узлы
    for i in 1:length(found_nodes_result)
        (path, orig_codes, matched_tuple) = found_nodes_result[i]
        path_key = join(path, "/")
        
        # Получаем рассчитанные статистики
        cmpx_data = cmpx_results[i][5]  # 5-й элемент содержит словарь статистик
        episode_data = episode_results[i][2]  # 2-й элемент содержит словарь статистик
        hr_data = hr_results[i][2]  # 2-й элемент содержит словарь статистик
        
        # Создаем объединенный словарь статистик
        merged_stats = Dict{String, Any}()
        
        # Добавляем все статистики
        for (k, v) in cmpx_data
            merged_stats[k] = v
        end
        for (k, v) in episode_data
            merged_stats[k] = v
        end
        for (k, v) in hr_data
            # Некоторые поля могут дублироваться, поэтому сохраняем важные
            if k in ["CustomName", "Code", "Title", "Path", "HRIntervalSec", 
                     "EpisodeHRAvg", "EpisodeHRMax", "EpisodeHRMin", 
                     "EpisodeHRMaxTime", "EpisodeHRMinTime", "RRMinMs", "RRMaxMs"]
                merged_stats[k] = v
            elseif !haskey(merged_stats, k)
                merged_stats[k] = v
            end
        end
        
        # Если это родительский узел, пересчитываем статистики
        if haskey(parent_bitvecs, path_key)
            
            # Пересчитываем статистики комплексов для родительского узла
            parent_cmpx_stats = calc_cmpx_for_bitvec(
                parent_bitvecs[path_key],
                path,
                sleep,
                fs,
                get(matched_tuple, :starts, Int[]),
                get(matched_tuple, :len, Int[])
            )
            
            # Пересчитываем статистики эпизодов для родительского узла
            parent_episode_stats = calc_episode_for_bitvec(
                parent_bitvecs[path_key],
                fs,
                point_count,
                pqrst_data[1]
            )
            
            # Обновляем статистики
            for (k, v) in parent_cmpx_stats
                merged_stats[k] = v
            end
            for (k, v) in parent_episode_stats
                merged_stats[k] = v
            end
        end
        
        code = ""
        if hasproperty(matched_tuple, :code)
            code = matched_tuple.code
        elseif hasproperty(matched_tuple, :rhythm_code)
            code = matched_tuple.rhythm_code
        end

        push!(_total, (
            path, 
            orig_codes, 
            code, 
            matched_tuple.title, 
            merged_stats
        ))
    end
    
    return _total
end

"""
Пересчитывает статистики комплексов для родительского узла
"""
function calc_cmpx_for_bitvec(bitvec, path, sleep, fs, starts_array, len_array)
    CmpxCount = sum(bitvec)
    CmpxPercent = round((CmpxCount / length(bitvec)) * 100, digits=3)
    
    # Определение частоты встречаемости
    CmpxOccurence = if CmpxPercent < 1.0
        "Rare"
    elseif 1.0 <= CmpxPercent < 10.0
        "Moderate"
    else
        "Frequent"
    end

    # Для пауз считаем дополнительные статистики
    is_pause = !isempty(path) && string(path[1]) == "Pauses"
    CmpxCount2s = 0
    CmpxCount3s = 0
    
    if is_pause && !isempty(len_array)
        durations_sec = len_array ./ fs
        CmpxCount2s = sum(durations_sec .>= 2.0)
        CmpxCount3s = sum(durations_sec .>= 3.0)
    end

    # Считаем дневные/ночные статистики
    CmpxCountDay = 0
    CmpxCountNight = 0
    if is_pause && !isempty(sleep)
        for idx in findall(bitvec)
            is_night = false
            for (start_p, end_p) in sleep
                if start_p <= idx <= end_p
                    is_night = true
                    break
                end
            end
            is_night ? (CmpxCountNight += 1) : (CmpxCountDay += 1)
        end
    end

    return Dict{String, Any}(
        "CmpxCount" => CmpxCount,
        "CmpxCountDay" => CmpxCountDay,
        "CmpxCountNight" => CmpxCountNight,
        "CmpxPercent" => CmpxPercent,
        "CmpxOccurence" => CmpxOccurence,
        "CmpxCount2s" => CmpxCount2s,
        "CmpxCount3s" => CmpxCount3s,
    )
end

"""
Пересчитывает статистики эпизодов для родительского узла
"""
function calc_episode_for_bitvec(bitvec, fs, point_count, pqrst_vector)
    # Преобразуем битовый вектор в сегменты
    segs = bitvec2seg(bitvec)
    
    # Объединяем близкие эпизоды (если функция merge_episodes доступна)
    # merged_segs = merge_episodes(segs, 0)  # Предполагая, что эта функция существует
    
    EpisodeCount = length(segs)
    
    # Рассчитываем длительности
    durations = Float64[]
    if !isempty(segs) && !isempty(pqrst_vector)
        durations = calc_episode_durations(segs, pqrst_vector, fs)
    end
    
    TotalDuration = sum(durations)
    EpisodeDurationAvg = isempty(durations) ? 0.0 : mean(durations)
    EpisodeDurationMax = isempty(durations) ? 0.0 : maximum(durations)
    EpisodeDurationMin = isempty(durations) ? 0.0 : minimum(durations)
    
    TotalDurationPercent = point_count > 0 ? round((TotalDuration / (point_count / fs)) * 100, digits=3) : 0.0

    return Dict{String, Any}(
        "EpisodeCount" => EpisodeCount,
        "TotalDuration" => dur_s_to_hhmmss(TotalDuration),
        "TotalDurationPercent" => TotalDurationPercent,
        "EpisodeDurationAvg" => dur_s_to_hhmmss(EpisodeDurationAvg),
        "EpisodeDurationMax" => dur_s_to_hhmmss(EpisodeDurationMax),
        "EpisodeDurationMin" => dur_s_to_hhmmss(EpisodeDurationMin)
    )
end