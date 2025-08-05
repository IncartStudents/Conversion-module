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
Объединяет все найденные узлы в единую структуру с сохранением их путей.
"""
function build_structure(data::Vector{Any})
    result = Dict{String, Any}()
    for el in data
        path_arr = el[1]
        orig_codes = el[2]
        in_code = el[3]
        title = el[4]
        stats = el[5]

        current = result
        for key in path_arr
            if !haskey(current, key)
                current[key] = Dict{String, Any}()
            end
            current = current[key]
        end

        # Добавляем поля из stats (включая Path)
        for (k, v) in stats
            current[k] = v
        end

        # Добавляем дополнительные поля
        current["InputCode"] = in_code
        current["OriginalArrTitle"] = title
        current["OriginalArrCodes"] = orig_codes
    end
    return result
end