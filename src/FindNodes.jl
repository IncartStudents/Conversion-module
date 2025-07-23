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

"""
Рекурсивно ищет все узлы, где `CustomName` соответствует коду из `input_codes`.
Проверка `Form` идёт сверху вниз: если узел имеет `Form`, он должен быть в `forms`,
иначе он наследует контекст от родителя.
Возвращает список кортежей: [(path, node), ...]
"""
function find_all_nodes(data, input_codes, forms, path=[], form_context_ok=true)
    results = []

    if isa(data, Dict)
        current_form_ok = form_context_ok # по умолчанию наследуем от родителя
        if haskey(data, "Form")
            form_value = data["Form"]
            if isa(form_value, String)
                current_form_ok = form_value in forms
            else
                current_form_ok = false # некорректная форма
            end
        end

        if current_form_ok && haskey(data, "CustomName")
            custom_value = data["CustomName"]
            if isa(custom_value, String)
                for code in input_codes
                    if occursin(build_regex_pattern(custom_value), code)
                        push!(results, (path, data))
                        break # совпадение по коду, выходим
                    end
                end
            end
        end

        # Рекурсивно обрабатываем дочерние узлы
        for (key, value) in data
            child_results = find_all_nodes(value, input_codes, forms, [path..., key], current_form_ok)
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_all_nodes(item, input_codes, forms, [path..., i], form_context_ok)
            append!(results, child_results)
        end
    end

    return results
end


"""
Объединяет все найденные узлы в единую структуру с сохранением их путей.
"""
function build_structure(results)
    merged = Dict()
    # Если передан один узел, то оборачиваем в массив
    results = isa(results, Tuple) ? [results] : results

    for (path, node) in results
        current = merged
        for key in path[1:end-1]
            if !haskey(current, key)
                current[key] = Dict()
            end
            current = current[key]
        end
        current[path[end]] = node
    end

    return merged
end