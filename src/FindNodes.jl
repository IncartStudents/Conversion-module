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
                    if occursin(Regex(form_value), f)
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
                    if occursin(build_regex_pattern(custom_value), code)
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
function build_structure(results)
    if isempty(results)
        return Dict()
    end
    if isa(results, Tuple)
        results = [results]
    end
    merged = Dict{Any, Any}()

    for (path, custom_name, matched_tuple) in results
        current_level = merged
        for i in 1:length(path)-1
            key = path[i]
            if !haskey(current_level, key)
                current_level[key] = Dict{Any, Any}()
            elseif !isa(current_level[key], Dict)
                current_level[key] = Dict{Any, Any}()
            end
            current_level = current_level[key]
        end

        if length(path) > 0
            last_key = path[end]
            node_info = Dict{String, Any}(
                "CustomName" => custom_name,
                "code" => get(matched_tuple, :code, nothing)
                # "MatchedData" => Dict{String, Any}(
                #     "rhythm_code" => getproperty(matched_tuple, :rhythm_code, nothing),
                #     "code" => getproperty(matched_tuple, :code, nothing),
                #     # "bitvec" => getproperty(matched_tuple, :bitvec, nothing), # Исключено
                #     "len" => getproperty(matched_tuple, :len, nothing),
                #     "starts" => getproperty(matched_tuple, :starts, nothing),
                #     "title" => getproperty(matched_tuple, :title, nothing)
                # )
            )
            current_level[last_key] = node_info
        end
    end
    return merged
end