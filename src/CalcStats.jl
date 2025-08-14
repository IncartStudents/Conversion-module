using DataFrames
using Statistics
using Printf
using Dates


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
Вычисляет длительности эпизодов в секундах и количество дневных и ночных эпизодов.
- `segs`: Вектор сегментов
- `pqrst_vector`: Данные PQRST
- `fs`: Частота дискретизации
- `sleep`: Вектор периодов сна в формате [(start1, end1), (start2, end2)]

Возращает кортеж с данными.
"""
function compute_episode_stats(segs, pqrst_vector, fs, sleep_frag)
    n = length(segs)
    starts = Vector{Int}(undef, n)
    lens = Vector{Int}(undef, n)
    durations_sec = Vector{Float64}(undef, n)
    night_count = 0
    day_count = 0

    total_dur = 0.0
    max_dur = -Inf
    min_dur = Inf

    for (i, seg) in enumerate(segs)
        start_idx = first(seg)
        end_idx = last(seg)
        
        # Вычисление длительности эпизода
        start_time = pqrst_vector[start_idx].timeQ
        end_time = pqrst_vector[end_idx].timeS
        dur_sec = (end_time - start_time) / fs
        durations_sec[i] = dur_sec
        starts[i] = start_idx
        lens[i] = length(seg)
        
        # Обновление общей длительности, максимума и минимума
        total_dur += dur_sec
        max_dur = max(max_dur, dur_sec)
        min_dur = min(min_dur, dur_sec)
        
        # Проверка на ночной/дневной эпизод
        is_night = false
        for (sleep_start, sleep_end) in sleep_frag
            if max(start_time, sleep_start) < min(end_time, sleep_end)
                is_night = true
                break
            end
        end
        is_night ? (night_count += 1) : (day_count += 1)
    end

    avg_dur = n > 0 ? total_dur / n : 0.0

    return (
        starts = starts,
        len = lens,
        segm = segs,
        len_segm = n,
        dur = durations_sec,
        total_dur_s = total_dur,
        max_dur_s = max_dur,
        min_dur_s = min_dur,
        dur_avg_s = avg_dur,
        is_night = night_count,
        is_day = day_count
    )
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
function calculate_motion_statistics(motion_trend, sleep_frag, fs, point_count, pqrst_data, hr_trend)
    motion_interval_sec = motion_trend["MeasureInterval"][1]
    motion_string = motion_trend["Trend"]
    total_intervals = length(motion_string)
    
    # Создаем искусственный "узел" для движений
    motion_bitvec = BitVector([c == '1' for c in motion_string])
    segs = bitvec2seg(motion_bitvec)
    
    # Используем существующую функцию для расчета эпизодов
    episode_stats = compute_episode_stats(segs, pqrst_data[1], fs, sleep_frag)
    
    # Расчет базовых статистик комплексов
    CmpxCount = sum(motion_bitvec)
    CmpxPercent = total_intervals > 0 ? round((CmpxCount / total_intervals) * 100, digits=3) : 0.0
    
    CmpxOccurence = if CmpxPercent < 1.0
        "Rare"
    elseif 1.0 <= CmpxPercent < 10.0
        "Moderate"
    else
        "Frequent"
    end
    
    # Расчет ЧСС для движений (с проверками)
    hr_avg_bpm = 0.0
    hr_max_bpm = 0.0
    hr_min_bpm = 0.0
    
    if !isempty(hr_trend["Trend"]) && !isempty(segs) && haskey(hr_trend, "MeasureInterval")
        hr_values_in_motion = Float64[]
        measure_interval = hr_trend["MeasureInterval"][1]
        
        # Находим значения ЧСС для периодов движений
        for seg in segs
            start_time_sec = (first(seg) - 1) * motion_interval_sec
            end_time_sec = last(seg) * motion_interval_sec
            
            # Преобразуем временные границы в индексы HR тренда
            start_hr_idx = ceil(Int, start_time_sec / measure_interval)
            end_hr_idx = floor(Int, end_time_sec / measure_interval)
            
            # Ограничиваем диапазон и проверяем корректность
            start_hr_idx = max(1, min(start_hr_idx, length(hr_trend["Trend"])))
            end_hr_idx = max(1, min(end_hr_idx, length(hr_trend["Trend"])))
            
            if start_hr_idx <= end_hr_idx && end_hr_idx <= length(hr_trend["Trend"])
                # Фильтруем некорректные значения ЧСС (только отрицательные)
                values = hr_trend["Trend"][start_hr_idx:end_hr_idx]
                valid_values = filter(x -> x >= 0, values)  # Только неотрицательные значения
                append!(hr_values_in_motion, valid_values)
            end
        end
        
        # Проверяем, что есть валидные значения перед расчетом статистик
        if !isempty(hr_values_in_motion)
            hr_avg_bpm = round(mean(hr_values_in_motion), digits=3)
            hr_max_bpm = round(maximum(hr_values_in_motion), digits=3)
            hr_min_bpm = round(maximum([minimum(hr_values_in_motion), 0.0]), digits=3)  # Минимум не меньше 0
        end
    end
    
    # Формируем результат, используя те же ключи, что и в других функциях
    return Dict{String, Any}(
        "CustomName" => "Motion",
        "CmpxCount" => CmpxCount,
        "CmpxPercent" => CmpxPercent,
        "CmpxOccurence" => CmpxOccurence,
        "EpisodeCount" => episode_stats.len_segm,
        "EpisodeCountDay" => episode_stats.is_day,
        "EpisodeCountNight" => episode_stats.is_night,
        "TotalDuration" => dur_s_to_hhmmss(episode_stats.total_dur_s),
        "TotalDurationPercent" => point_count > 0 ? round((episode_stats.total_dur_s / (point_count / fs)) * 100, digits=3) : 0.0,
        "EpisodeDurationAvg" => dur_s_to_hhmmss(episode_stats.dur_avg_s),
        "EpisodeDurationMax" => dur_s_to_hhmmss(episode_stats.max_dur_s),
        "EpisodeDurationMin" => dur_s_to_hhmmss(episode_stats.min_dur_s),
        "EpisodeHRAvg" => hr_avg_bpm,
        "EpisodeHRMax" => hr_max_bpm,
        "EpisodeHRMin" => hr_min_bpm,
        "HRIntervalSec" => hr_trend["MeasureInterval"][1]
    )
end


"""
Объединяет результаты расчета статистик для комплексов, эпизодов и ЧСС
"""
function complex_stats(found_nodes_result, sleep, fs, point_count, pqrst_data, hr_trend, motion_trend)
    # Рассчитываем базовые статистики для всех узлов
    cmpx_results = calc_cmpx_stats(found_nodes_result, sleep, fs)
    episode_results = calc_episode_stats(found_nodes_result, fs, point_count)
    hr_results = calc_hr(found_nodes_result, hr_trend, pqrst_data)
    
    # Рассчитываем статистики движений
    motion_stats = calculate_motion_statistics(motion_trend, sleep, fs, point_count, pqrst_data, hr_trend)
    
    # Строим битовые векторы для родительских узлов
    parent_bitvecs = build_parent_bitvectors(found_nodes_result)
    
    _total = []
    
    # Обрабатываем все узлы
    for i in 1:length(found_nodes_result)
        (path, orig_codes, matched_tuple) = found_nodes_result[i]
        path_key = join(path, "/")
        
        # Получаем рассчитанные статистики
        cmpx_data = cmpx_results[i][5]
        episode_data = episode_results[i][2]
        hr_data = hr_results[i][2]
        
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
            parent_cmpx_stats = calc_cmpx_for_bitvec(
                parent_bitvecs[path_key],
                path,
                sleep,
                fs,
                get(matched_tuple, :starts, Int[]),
                get(matched_tuple, :len, Int[])
            )
            
            parent_episode_stats = calc_episode_for_bitvec(
                parent_bitvecs[path_key],
                fs,
                point_count,
                pqrst_data[1]
            )
            
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
    
    # Добавляем движения как отдельный элемент
    motion_path = ["Motion"]
    push!(_total, (
        motion_path,
        "Движения", 
        "", 
        "Артефакты движений", 
        motion_stats
    ))
    
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
    
    # Объединяем близкие эпизоды
    # merged_segs = merge_episodes(segs, 0)
    
    # Рассчитываем длительности
    durations = Float64[]
    if !isempty(segs) && !isempty(pqrst_vector)
        episode_stats = compute_episode_stats(segs, pqrst_vector, fs, Tuple{Int, Int}[])
    end
    
    TotalDuration = episode_stats.total_dur_s
    EpisodeDurationAvg = episode_stats.dur_avg_s
    EpisodeDurationMax = episode_stats.max_dur_s
    EpisodeDurationMin = episode_stats.min_dur_s
    EpisodeCount = episode_stats.len_segm

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


"""
Определяет пороговые значения для тахикардии и брадикардии
"""
function determine_hr_thresholds(hr_data)
    valid_values = filter(x -> x > 0 && x < 300, hr_data)
    
    if isempty(valid_values)
        return 110, 55  # значения по умолчанию
    end
    
    mean_hr = mean(valid_values)
    std_hr = std(valid_values)
    
    # Тахикардия: среднее + 2 стандартных отклонения
    tachy_cutoff = min(round(Int, mean_hr + 2 * std_hr), 150)
    
    # Брадикардия: среднее - 2 стандартных отклонения
    brady_cutoff = max(round(Int, mean_hr - 2 * std_hr), 40)
    
    # Убеждаемся, что пороги находятся в разумных пределах
    tachy_cutoff = max(100, min(tachy_cutoff, 150))
    brady_cutoff = max(40, min(brady_cutoff, 70))
    
    return tachy_cutoff, brady_cutoff
end

"""
Производит расчет статистик по Heart Rate
"""
function calculate_hr_statistics(hr_trend, sleep_frag, fs, timestart)
    stats = Dict{String, Any}()
    
    if isempty(hr_trend["Trend"]) || !haskey(hr_trend, "MeasureInterval")
        return stats
    end
    
    hr_data = hr_trend["Trend"]
    measure_interval = hr_trend["MeasureInterval"][1]
    
    # Определяем пороговые значения
    tachy_cutoff, brady_cutoff = determine_hr_thresholds(hr_data)
    
    # Базовая информация
    stats["IntervalSec"] = measure_interval
    stats["TachyCutoff"] = tachy_cutoff
    stats["BradyCutoff"] = brady_cutoff
    
    # Фильтруем валидные значения ЧСС
    valid_indices = findall(x -> x > 0 && x < 300, hr_data)
    valid_hr_values = hr_data[valid_indices]
    
    if isempty(valid_hr_values)
        return stats
    end
    
    # Разделяем дневные и ночные значения
    day_values = Float64[]
    night_values = Float64[]
    day_times = Int[]
    night_times = Int[]
    
    for i in valid_indices
        time_sec = (i - 1) * measure_interval
        
        is_night = false
        for (sleep_start, sleep_end) in sleep_frag
            sleep_start_sec = sleep_start / fs
            sleep_end_sec = sleep_end / fs
            if sleep_start_sec <= time_sec <= sleep_end_sec
                is_night = true
                break
            end
        end
        
        if is_night
            push!(night_values, hr_data[i])
            push!(night_times, time_sec)
        else
            push!(day_values, hr_data[i])
            push!(day_times, time_sec)
        end
    end
    
    # Общая статистика
    stats["AvgDaily"] = round(mean(valid_hr_values))
    
    # Дневная статистика
    if !isempty(day_values)
        stats["AvgDay"] = round(mean(day_values))
        stats["MaxDay"] = round(maximum(day_values))
        stats["MinDay"] = round(minimum(day_values))
        
        # Время максимума и минимума днем
        max_day_idx = argmax(day_values)
        min_day_idx = argmin(day_values)
        if !isempty(day_times) && length(day_times) == length(day_values)
            max_day_time = timestart + Dates.Second(day_times[max_day_idx])
            min_day_time = timestart + Dates.Second(day_times[min_day_idx])
            stats["MaxDayTime"] = Dates.format(max_day_time, "yyyy-mm-ddTHH:MM:SS")
            stats["MinDayTime"] = Dates.format(min_day_time, "yyyy-mm-ddTHH:MM:SS")
        end
    end
    
    # Ночная статистика
    if !isempty(night_values)
        stats["AvgNight"] = round(mean(night_values))
        stats["MaxNight"] = round(maximum(night_values))
        stats["MinNight"] = round(minimum(night_values))
        
        # Время максимума и минимума ночью
        max_night_idx = argmax(night_values)
        min_night_idx = argmin(night_values)
        if !isempty(night_times) && length(night_times) == length(night_values)
            max_night_time = timestart + Dates.Second(night_times[max_night_idx])
            min_night_time = timestart + Dates.Second(night_times[min_night_idx])
            stats["MaxNightTime"] = Dates.format(max_night_time, "yyyy-mm-ddTHH:MM:SS")
            stats["MinNightTime"] = Dates.format(min_night_time, "yyyy-mm-ddTHH:MM:SS")
        end
    end
    
    # Общие максимумы и минимумы
    # stats["MaxInFL"] = round(maximum(valid_hr_values))
    # stats["MaxOutFL"] = round(maximum(valid_hr_values))
    
    # Расчет длительности тахикардии
    tachy_indices = findall(x -> x >= tachy_cutoff, valid_hr_values)
    tachy_duration = length(tachy_indices) * measure_interval
    
    tachy_day_duration = 0
    tachy_night_duration = 0
    
    # Разделяем тахикардию на дневную и ночную
    for i in tachy_indices
        original_index = valid_indices[i]
        time_sec = (original_index - 1) * measure_interval
        
        is_night = false
        for (sleep_start, sleep_end) in sleep_frag
            sleep_start_sec = sleep_start / fs
            sleep_end_sec = sleep_end / fs
            if sleep_start_sec <= time_sec <= sleep_end_sec
                is_night = true
                break
            end
        end
        
        if is_night
            tachy_night_duration += measure_interval
        else
            tachy_day_duration += measure_interval
        end
    end
    
    stats["TachyTotalDuration"] = dur_s_to_hhmmss(Float64(tachy_duration))
    stats["TachyDayDuration"] = dur_s_to_hhmmss(Float64(tachy_day_duration))
    stats["TachyNightDuration"] = dur_s_to_hhmmss(Float64(tachy_night_duration))
    
    # Расчет длительности брадикардии
    brady_indices = findall(x -> x <= brady_cutoff, valid_hr_values)
    brady_duration = length(brady_indices) * measure_interval
    
    brady_day_duration = 0
    brady_night_duration = 0
    
    # Разделяем брадикардию на дневную и ночную
    for i in brady_indices
        original_index = valid_indices[i]
        time_sec = (original_index - 1) * measure_interval
        
        is_night = false
        for (sleep_start, sleep_end) in sleep_frag
            sleep_start_sec = sleep_start / fs
            sleep_end_sec = sleep_end / fs
            if sleep_start_sec <= time_sec <= sleep_end_sec
                is_night = true
                break
            end
        end
        
        if is_night
            brady_night_duration += measure_interval
        else
            brady_day_duration += measure_interval
        end
    end
    
    stats["BradyTotalDuration"] = dur_s_to_hhmmss(Float64(brady_duration))
    stats["BradyDayDuration"] = dur_s_to_hhmmss(Float64(brady_day_duration))
    stats["BradyNightDuration"] = dur_s_to_hhmmss(Float64(brady_night_duration))
    
    # Коэффициент изменчивости (CI)
    # if length(valid_hr_values) > 1
    #     mean_hr = mean(valid_hr_values)
    #     std_hr = std(valid_hr_values)
    #     if mean_hr > 0
    #         stats["CI"] = round(std_hr / mean_hr, digits=6)
    #     end
    # end
    
    return stats
end


"""
Подготавливает дополнительные статистики для записи в результат
"""
function prepare_additional_stats(form_stats, hr_trend, sleep_frag, fs, timestart)
    stats = Dict{String, Any}()
    
    # Добавляем статистику по QRS
    qrs_stats = Dict{String, Any}()
    qrs_stats["CmpxCountTotal"] = sum(form_stats.CmpxCount)
    
    for row in eachrow(form_stats)
        form_name = string(row.form)
        qrs_stats[form_name] = Dict{String, Any}(
            "CmpxCount" => row.CmpxCount,
            "CmpxCountPercent" => row.CmpxCountPercent
        )
    end
    stats["QRS"] = qrs_stats

    # Добавляем статистику по Heart Rate
    hr_stats = calculate_hr_statistics(hr_trend, sleep_frag, fs, timestart)
    if !isempty(hr_stats)
        stats["HR"] = hr_stats
    end

    # можно добавить любые другие статистики
    
    return stats
end