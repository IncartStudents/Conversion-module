include("struct.jl")

"""
Функция преобразования `CustomName` в регулярное выражение
"""
function build_regex_pattern_v2(custom_name)
    # Функция для экранирования спецсимволов в регулярных выражениях
    function regex_escape(s)
        replace(s, r"([-\\\{\}\(\)\*\+\?\.\^\$])" => s"\\\1")
    end

    # Функция построения шаблона для целого слова
    function build_word_pattern(part)
        if endswith(part, "*")
            base = regex_escape(part[1:end-1])
            return "(?:^|;)$base[^;]*(?:;|\$)"
        else
            escaped = regex_escape(part)
            return "(?:^|;)$escaped(?:;|\$)"
        end
    end

    # Обработка группы с операторами
    function process_group(group)
        variants = split(group, "|")
        variant_regexes = []
        for variant in variants
            if occursin("&", variant)
                subparts = split(variant, "&")
                sub_regex = join([process_part(subpart) for subpart in subparts], "")
                push!(variant_regexes, sub_regex)
            else
                push!(variant_regexes, process_part(variant))
            end
        end
        return "(?:" * join(variant_regexes, "|") * ")"
    end

    # Обработка отдельной части (элемент, отрицание или группа)
    function process_part(part)
        if startswith(part, "!")
            word_pattern = build_word_pattern(part[2:end])
            return "(?!.*$word_pattern)"
        elseif startswith(part, "(") && endswith(part, ")")
            return process_group(part[2:end-1])
        else
            word_pattern = build_word_pattern(part)
            return "(?=.*?$word_pattern)"
        end
    end

    parts = split(custom_name, ";")
    regex_components = [process_part(part) for part in parts]
    full_regex = "^" * join(regex_components) * ".*\$"
    return Regex(full_regex)
end

"""
Рекурсивно ищет все узлы, где `CustomName` соответствует коду из `input_arr_tuples` и `input_arr_pairs`.
Проверка `Form` идёт сверху вниз: если узел имеет `Form`, он должен быть в `forms`,
иначе он наследует контекст от родителя.
Возвращает список кортежей: [(path, custom_name, matched_arr_tuple), ...]
"""
function find_all_nodes_v2(data, input_arr_tuples, input_arr_pairs, forms, path=[], form_context=nothing)
    results = []

    if isa(data, Dict)
        current_form = form_context

        if haskey(data, "Form")
            form_value = data["Form"]
            if isa(form_value, String)
                form_ok = false
                for f in forms
                    if occursin(build_regex_pattern_v2(form_value), f)
                        form_ok = true
                        break
                    end
                end
                if form_ok
                    current_form = form_value
                else
                    # Форма не совпала — пропускаем этот узел
                    return results
                end
            else
                # Form не строка — пропускаем
                return results
            end
        end

        # Теперь проверяем CustomName, если форма подошла или её нет
        if haskey(data, "CustomName")
            custom_value = data["CustomName"]
            if isa(custom_value, String)
                for nt in input_arr_tuples
                    code = nt.code
                    if occursin(build_regex_pattern_v2(custom_value), code)
                        # Сохраняем весь кортеж
                        push!(results, (path, custom_value, nt))
                        break
                    end
                end
            end
        end

        # Теперь проверяем RhythmCode
        if haskey(data, "RhythmCode")
            rhytm_value = data["RhythmCode"]
            if isa(rhytm_value, String)
                for rhythm_nt in input_arr_pairs
                    rhytm = rhythm_nt.rhythm_code
                    if occursin(build_regex_pattern_v2(rhytm_value), rhytm)
                        # Сохраняем весь кортеж
                        push!(results, (path, rhytm_value, rhythm_nt))
                        break
                    end
                end
            end
        end

        # Рекурсивно обрабатываем дочерние элементы, кроме Form и CustomName
        for (key, value) in data
            if key in ["Form", "CustomName", "RhythmCode"]
                continue
            end
            child_path = [path..., key]
            child_results = find_all_nodes_v2(value, input_arr_tuples, input_arr_pairs, forms, child_path, current_form)
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_all_nodes_v2(item, input_arr_tuples, input_arr_pairs, forms, [path..., i], form_context)
            append!(results, child_results)
        end
    end

    return results
end

"""
Объединяет битовые векторы ритмов с битовыми векторами аритмий для корректного отображения 
в иерархической структуре.
Возвращает список кортежей: [(path, custom_name, matched_arr_tuple), ...]
"""
function combine_rhythm_arr_bitvecs(result::Vector)
    # Группируем по (path, matched_string)
    groups = Dict{Tuple{Vector{String}, String}, Vector{Any}}()
    
    for item in result
        path, matched_str, data = item
        key = (path, matched_str)
        if haskey(groups, key)
            push!(groups[key], data)
        else
            groups[key] = [data]
        end
    end

    new_result = []
    for (key, data_list) in groups
        path, matched_str = key

        # Разделяем на аритмии и ритмы
        arrs = filter(x -> x isa NamedTuple && hasproperty(x, :code), data_list)
        pure_rhythms = filter(x -> x isa NamedTuple && hasproperty(x, :rhythm_code) && !hasproperty(x, :code), data_list)

        if !isempty(arrs) && !isempty(pure_rhythms)
            # Объединяем все битовые векторы чистых ритмов через ИЛИ
            combined_rhythm_bitvec = reduce(
                (acc, r) -> acc .| r.bitvec,
                pure_rhythms,
                init = falses(length(first(pure_rhythms).bitvec))
            )
            
            # Берем первый ритм и обновляем его битовый вектор
            first_rhythm = first(pure_rhythms)
            updated_rhythm = (; first_rhythm..., bitvec = combined_rhythm_bitvec)
            push!(new_result, (path, matched_str, updated_rhythm))
            
        elseif isempty(arrs) && !isempty(pure_rhythms)
            # сохраняем ритмы без изменений
            for rhythm in pure_rhythms
                push!(new_result, (path, matched_str, rhythm))
            end
        elseif !isempty(arrs) && isempty(pure_rhythms)
            # сохраняем аритмии без изменений
            for arr in arrs
                push!(new_result, (path, matched_str, arr))
            end
        end
    end

    return new_result
end

"""
Объединяет близко расположенные сегменты `UnitRange` в один сегмент, 
если расстояние между ними не превышает порога, определяемого правилами:
    1) Желудочковые 1-2 комплекса НЕ разбивают эпизод наджелудочкового ритма, а 3 и более разбивают и формируют свой эпизод ритма.
    2) Наджелудочковые 1-4 комплекса НЕ разбивают эпизод синусового ритма, а 5 и более разбивают и формируют свой эпизод ритма.

Возвращает новый вектор диапазонов `Vector{UnitRange{Int}}`
"""
function merge_episodes_v2(segments::Vector{UnitRange{Int64}}, form_pairs::Vector{Pair{Int, String}})
    isempty(segments) && return segments
    
    # Создаем словарь для быстрого доступа к форме по индексу
    form_dict = Dict(form_pairs)
    
    # Функция для классификации комплексов
    function classify_complex(form::String)
        if startswith(form, 'S') || startswith(form, 'B') || 
           startswith(form, 'A') || startswith(form, 'W')
            return :ventricular
        elseif startswith(form, 'V') || form == "F"
            return :supraventricular
        else
            return :invalid  # X, Z*
        end
    end

    merged = [segments[1]]
    for i in 2:length(segments)
        prev_end = last(merged[end])
        curr_beg = first(segments[i])
        gap_start = prev_end + 1
        gap_end = curr_beg - 1
        
        should_merge = true
        
        if gap_start <= gap_end
            vent_count = 0
            supravent_count = 0
            
            for idx in gap_start:gap_end
                # Получаем форму из словаря
                form = get(form_dict, idx, "")
                class = classify_complex(form)
                
                if class == :ventricular
                    vent_count += 1
                elseif class == :supraventricular
                    supravent_count += 1
                end
            end
            
            # Применяем правила объединения
            if vent_count >= 3 || supravent_count >= 5
                should_merge = false
            end
        end
        
        if should_merge
            # Объединяем сегменты
            merged[end] = first(merged[end]):last(segments[i])
        else
            push!(merged, segments[i])
        end
    end
    
    return merged
end

"""
Объединяет все найденные узлы в единую структуру Dict с сохранением их путей.
"""
function build_structure(data::Vector{Any})
    result = Dict{String, Any}()
    
    # Группируем данные по путям
    path_mapping = Dict{String, Vector{Any}}()
    
    for el in data
        path_key = join(el[1], "/")
        if !haskey(path_mapping, path_key)
            path_mapping[path_key] = []
        end
        push!(path_mapping[path_key], el)
    end
    
    # Обрабатываем каждый уникальный путь
    for (path_key, elements) in path_mapping
        path_arr = elements[1][1]  # Путь (одинаковый для всех элементов)
        
        # Создаем структуру
        current = result
        for key in path_arr
            if !haskey(current, key)
                current[key] = Dict{String, Any}()
            end
            current = current[key]
        end
        
        # Используем данные первого элемента для основной информации
        first_el = elements[1]
        orig_codes = first_el[2]
        in_code = first_el[3]
        title = first_el[4]
        
        current["OriginalArrTitle"] = title
        
        # Если есть несколько элементов, объединяем их статистики
        if length(elements) > 1
            # Создаем список всех элементов
            current["items"] = []
            for el in elements
                stats = el[5]
                template = get_stats_template(path_key)
                merged_stats = merge(template, stats)
                
                item = Dict{String, Any}()
                item["OriginalArrTitle"] = el[4]
                for (k, v) in merged_stats
                    item[k] = v
                end
                push!(current["items"], item)
            end
        else
            # Один элемент - просто добавляем его статистику
            stats = first_el[5]
            template = get_stats_template(path_key)
            merged_stats = merge(template, stats)
            
            for (k, v) in merged_stats
                current[k] = v
            end
        end
    end
    
    return result
end