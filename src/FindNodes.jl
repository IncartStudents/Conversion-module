"""
Функция преобразования `CustomName` в регулярное выражение
"""
function build_regex_pattern(custom_name)
    parts = split(custom_name, ";")
    regex_components = []

    for part in parts       
        if startswith(part, "!")
            neg_pattern = part[2:end]
            push!(regex_components, "(?!.*$(neg_pattern))")
        elseif startswith(part, "(") && endswith(part, ")")
            inner = part[2:end-1]            
            push!(regex_components, "(?=.*(?:$(inner)))")
        else # остальные части без символов + символ `*`
            part_final = replace(part, "*" => ".*")
            push!(regex_components, "(?=.*$(part_final))")
        end
    end

    full_regex = "^" * join(regex_components, "") * ".*\$"   
    return Regex(full_regex)
end

"""
Рекурсивно ищет все узлы, где `CustomName` соответствует коду из `input_codes` 
и `Form` (если есть) входит в список `forms`.
Возвращает список кортежей: [(path, node), ...]
"""
function find_all_nodes(data, input_codes, forms, path=[])
    results = []

    if isa(data, Dict)
        if haskey(data, "CustomName")
            custom_value = data["CustomName"]
            if isa(custom_value, String)
                for code in input_codes
                    if occursin(build_regex_pattern(custom_value), code)
                        # Проверка поля Form
                        form_ok = true
                        if haskey(data, "Form")
                            form_value = data["Form"]
                            if isa(form_value, String)
                                form_ok = form_value in forms
                            else
                                form_ok = false
                            end
                        end
                        if form_ok
                            push!(results, (path, data))
                            break
                        end
                    end
                end
            end
        end

        for (key, value) in data
            child_results = find_all_nodes(value, input_codes, forms, [path..., key])
            append!(results, child_results)
        end
    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_all_nodes(item, input_codes, forms, [path..., i])
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