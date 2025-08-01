"""
Функция преобразования `CustomName` в регулярное выражение
"""
function build_regex_pattern(custom_name)
    parts = split(custom_name, ";")
    regex_components = []

    for part in parts
        # Обработка отрицания       
        if startswith(part, "!")
            neg_pattern = replace(part[2:end], "*" => ".*")
            push!(regex_components, "(?!.*$(neg_pattern))")
        
        # Обработка ИЛИ / И
        elseif occursin("|", part) || occursin("&", part)
            # Обработка ИЛИ
            if startswith(part, "(") && endswith(part, ")")      
                disj = split(part[2:end-1] , "|")       
            else
                disj = split(part, "|")  
            end

            disj_reg = []

            for d in disj
                conj = split(d, "&")
                conj = [strip(String(c), ['(', ')']) for c in conj]
                conj_reg = []

                # Обработка И
                for c in conj
                    if startswith(c, "!")
                        c_f = replace(c[2:end], "*" => ".*")
                        push!(conj_reg, "(?!.*$(c_f))") 
                    else
                        c_f = replace(c, "*" => ".*")
                        push!(conj_reg, "(?=.*$(c_f))")
                    end    
                end
                push!(disj_reg, join(conj_reg, ""))
            end
            

            if length(disj_reg) > 1
                comb = "(?:" * join(disj_reg, "|") * ")"
                push!(regex_components, comb)
            else
                push!(regex_components, disj_reg[1])
            end 
        
        else # остальные части без символов + символ `*`
            part_final = replace(part, "*" => ".*")
            push!(regex_components, "(?=.*$(part_final))")
        end
    end

    full_regex = "^" * join(regex_components, "") * ".*\$"   
    return Regex(full_regex)
end

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
function find_all_nodes(data, input_arr_tuples, forms, path=[], form_context=nothing)
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

        # Рекурсивно обрабатываем дочерние элементы, кроме Form и CustomName
        for (key, value) in data
            if key in ["Form", "CustomName"]
                continue
            end
            child_path = [path..., key]
            child_results = find_all_nodes(value, input_arr_tuples, forms, child_path, current_form)
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_all_nodes(item, input_arr_tuples, forms, [path..., i], form_context)
            append!(results, child_results)
        end
    end

    return results
end

"""
Объединяет все найденные узлы в единую структуру с сохранением их путей.
"""
function build_structure(data::Vector{Any})
    root = Dict{String, Any}()
    
    for item in data
        path = item[1]       # Вектор строк пути
        pattern = item[2]    # Строка шаблона
        tags = item[3]       # Строка входного кода
        description = item[4] # Описание
        metrics = item[5]    # Словарь с метриками
        
        # Создаем объединенный словарь для узла
        node_data = Dict{String, Any}()
        node_data["OriginalArrCodes"] = pattern
        node_data["InputCode"] = tags
        node_data["OriginalArrTitle"] = description
        
        # Добавляем все метрики в основной словарь
        for (k, v) in metrics
            node_data[k] = v
        end
        
        # Построение иерархии в словаре
        current_level = root
        for i in 1:length(path)
            key = path[i]
            
            # Если достигнут конечный элемент пути
            if i == length(path)
                current_level[key] = node_data
            else
                # Создаем подуровень если нужно
                if !haskey(current_level, key) || !(current_level[key] isa Dict)
                    current_level[key] = Dict{String, Any}()
                end
                current_level = current_level[key]
            end
        end
    end
    
    return root
end
