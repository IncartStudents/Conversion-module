
"""
Рекурсивно ищет узел, содержащий `CustomName`, который начинается с `input_code`.
Возвращает путь (в виде массива ключей) и сам узел.
"""
function find_node(data, input_code, path=[])
    if isa(data, Dict)
        if haskey(data, "CustomName")
            custom_value = data["CustomName"]
            if isa(custom_value, String) && startswith(custom_value, input_code)
                return (path, data)
            end
        end
        for (key, value) in data
            result = find_node(value, input_code, [path..., key])
            if result !== nothing
                return result
            end
        end
    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            result = find_node(item, input_code, [path..., i])
            if result !== nothing
                return result
            end
        end
    end
    return nothing
end


"""  
Рекурсивно ищет все узлы, где `CustomName` начинается с любого из `input_codes`.
Возвращает список кортежей: [(path, node), ...]
"""
function find_all_nodes(data, input_codes, path=[])
    results = []

    if isa(data, Dict)
        if haskey(data, "CustomName")
            custom_value = data["CustomName"]
            for code in input_codes
                if isa(custom_value, String) && startswith(custom_value, code)
                    push!(results, (path, data))
                    break
                end
            end
        end

        for (key, value) in data
            child_results = find_all_nodes(value, input_codes, [path..., key])
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_all_nodes(item, input_codes, [path..., i])
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