using FileUtils
using Printf
using ExtractMkp


include("CalcStats.jl")

include("C:/incart_dev/ExtractMkp.jl/src/dict.jl")

filepath = "C:/incart_dev/Myproject/data/AlgResult (3).xml"

res = readxml_rhythms_arrs(filepath)

arr_pairs = res[1]    # Rhythms in xml-file
arr_tuples = res[2]   # Arrhythmias in xml-file
meta = res[3]     # timestart, fs, point_count
sleep_info = res[4]   # SleepFragments

sums = [sum(bitvec) for (key, bitvec) in arr_pairs]

lens = [t.len for t in arr_tuples]
starts = [t.starts for t in arr_tuples]
titles = [t.title for t in arr_tuples]

sleep_frag = []
for (_, slp) in sleep_info
    push!(sleep_frag, (slp["ECGStartPoints"][1], slp["ECGStartPoints"][1] + slp["ECGDurationPoints"][1]))
end
sleep_frag

pqrst = readxml_pqrst_anz(filepath)
form_stats = calc_qrs_stats(pqrst[1])

function find_nodes(data, input_arr_tuples, input_arr_pairs, forms, path=[], form_context=nothing)
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
            if isa(custom_value, String)
                for pair in input_arr_pairs
                    rhytm = pair.first
                    if occursin(build_regex_pattern_v2(rhytm_value), rhytm)
                        # Сохраняем весь кортеж
                        push!(results, (path, rhytm_value, pair))
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
            child_results = find_nodes(value, input_arr_tuples, input_arr_pairs, forms, child_path, current_form)
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_nodes(item, input_arr_tuples, input_arr_pairs, forms, [path..., i], form_context)
            append!(results, child_results)
        end
    end

    return results
end


# ================================================================================

using YAML
using DataFrames

include("FindNodes.jl")


input_tree = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
output_tree = "C:/incart_dev/Myproject/result/output_datatree.yaml"

data = YAML.load(open(input_tree, "r"))

new_input_tree = "C:/incart_dev/Myproject/data/new_datatree.yaml"
new_data = YAML.load(open(input_tree, "r"))

codes = [t.code for t in arr_tuples]
formes = [String(f) for f in form_stats.form]

# result = find_all_nodes(data, codes, formes)
# result = find_all_nodes(data, arr_tuples, arr_pairs, formes)

result = find_nodes(data, arr_tuples, arr_pairs, formes)

function build_struct(results)
    root = Dict{String, Any}()

    for (path_parts, node_data, _) in results
        # Начинаем с корня
        current_level = root
        
        # Проходим по всем частям пути
        for i in 1:length(path_parts)
            key = path_parts[i]
            
            # Если это последний элемент пути, записываем оригинальные данные узла
            if i == length(path_parts)
                # Создаем копию оригинальных данных узла
                leaf_data = Dict{String, Any}()
                for (k, v) in node_data
                    leaf_data[k] = v
                end
                current_level[key] = leaf_data
            else
                # Создаем промежуточный узел, если нужно
                if !haskey(current_level, key)
                    current_level[key] = Dict{String, Any}()
                end
                # Переходим на следующий уровень
                current_level = current_level[key]
            end
        end
    end

    return root
end

if !isempty(result)
    result_data = build_structure(result)
    open(output_tree, "w") do f
        YAML.write(f, result_data)
    end
    println("Найдено $(length(result)) узлов. Результат сохранён в $output_tree")
else
    println("Ни один узел не найден")
end

result[1]
length(lens[1])
length(starts[1])

calc = calc_cmpx_stats(result, sleep_frag, meta.fs)

# stats_dicts = [item[2] for item in calc]

# df = DataFrame(stats_dicts)
# new_column_order = vcat(["Path"], setdiff(names(df), ["Path"]))
# select!(df, new_column_order)

# println(df)

calc1 = calc_episode_stats(result, sleep_frag, meta.fs, meta.point_count)
# stats_dicts1 = [item[2] for item in calc1]

# df1 = DataFrame(stats_dicts1)
# new_column_order1 = vcat(["Path"], setdiff(names(df1), ["Path"]))
# select!(df1, new_column_order1)

# println(df1)


output = complex_stats(result, sleep_frag, meta.fs, meta.point_count)

# ================================================================================

using BenchmarkTools


function find_nodes(data, codes, forms, path=[], form_context=nothing)
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
                for code in codes
                    if occursin(build_regex_pattern(custom_value), code)
                        # Сохраняем путь, custom_value и соответствующий код
                        push!(results, (path, custom_value, code))
                        # Если нужно найти все совпадения для данного custom_value, уберите break
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
            child_results = find_nodes(value, codes, forms, child_path, current_form)
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_nodes(item, codes, forms, [path..., i], form_context)
            append!(results, child_results)
        end
    end

    return results
end

new_codes = [
    # Простые префиксы (20 элементов)
    "rN", "rC", "rCD", "rCA", "rCV", "rCU", "rF", "rFA", "rFN", "rSA",
    "rSI", "rSM", "rSP", "rSN", "rSR", "rS", "rM", "rV", "rVM", "rVP",
    
    # Префиксы + 1 параметр (200 элементов)
    "rN;nS", "rN;nD", "rN;nG", "rN;nP", "rN;pP*", "rN;pE*", "rN;!pP*", "rN;!pE*", "rN;vA*", "rN;vV",
    "rC;nS", "rC;nD", "rC;nG", "rC;nP", "rC;pP*", "rC;pE*", "rC;!pP*", "rC;!pE*", "rC;vA*", "rC;vV",
    "rCD;nS", "rCD;nD", "rCD;nG", "rCD;nP", "rCD;pP*", "rCD;pE*", "rCD;!pP*", "rCD;!pE*", "rCD;vA*", "rCD;vV",
    "rCA;nS", "rCA;nD", "rCA;nG", "rCA;nP", "rCA;pP*", "rCA;pE*", "rCA;!pP*", "rCA;!pE*", "rCA;vA*", "rCA;vV",
    "rCV;nS", "rCV;nD", "rCV;nG", "rCV;nP", "rCV;pP*", "rCV;pE*", "rCV;!pP*", "rCV;!pE*", "rCV;vA*", "rCV;vV",
    "rCU;nS", "rCU;nD", "rCU;nG", "rCU;nP", "rCU;pP*", "rCU;pE*", "rCU;!pP*", "rCU;!pE*", "rCU;vA*", "rCU;vV",
    "rF;nS", "rF;nD", "rF;nG", "rF;nP", "rF;pP*", "rF;pE*", "rF;!pP*", "rF;!pE*", "rF;vA*", "rF;vV",
    "rFA;nS", "rFA;nD", "rFA;nG", "rFA;nP", "rFA;pP*", "rFA;pE*", "rFA;!pP*", "rFA;!pE*", "rFA;vA*", "rFA;vV",
    "rFN;nS", "rFN;nD", "rFN;nG", "rFN;nP", "rFN;pP*", "rFN;pE*", "rFN;!pP*", "rFN;!pE*", "rFN;vA*", "rFN;vV",
    "rSA;nS", "rSA;nD", "rSA;nG", "rSA;nP", "rSA;pP*", "rSA;pE*", "rSA;!pP*", "rSA;!pE*", "rSA;vA*", "rSA;vV",
    "rSI;nS", "rSI;nD", "rSI;nG", "rSI;nP", "rSI;pP*", "rSI;pE*", "rSI;!pP*", "rSI;!pE*", "rSI;vA*", "rSI;vV",
    "rSM;nS", "rSM;nD", "rSM;nG", "rSM;nP", "rSM;pP*", "rSM;pE*", "rSM;!pP*", "rSM;!pE*", "rSM;vA*", "rSM;vV",
    "rSP;nS", "rSP;nD", "rSP;nG", "rSP;nP", "rSP;pP*", "rSP;pE*", "rSP;!pP*", "rSP;!pE*", "rSP;vA*", "rSP;vV",
    "rSN;nS", "rSN;nD", "rSN;nG", "rSN;nP", "rSN;pP*", "rSN;pE*", "rSN;!pP*", "rSN;!pE*", "rSN;vA*", "rSN;vV",
    "rSR;nS", "rSR;nD", "rSR;nG", "rSR;nP", "rSR;pP*", "rSR;pE*", "rSR;!pP*", "rSR;!pE*", "rSR;vA*", "rSR;vV",
    "rS;nS", "rS;nD", "rS;nG", "rS;nP", "rS;pP*", "rS;pE*", "rS;!pP*", "rS;!pE*", "rS;vA*", "rS;vV",
    "rM;nS", "rM;nD", "rM;nG", "rM;nP", "rM;pP*", "rM;pE*", "rM;!pP*", "rM;!pE*", "rM;vA*", "rM;vV",
    "rV;nS", "rV;nD", "rV;nG", "rV;nP", "rV;pP*", "rV;pE*", "rV;!pP*", "rV;!pE*", "rV;vA*", "rV;vV",
    "rVM;nS", "rVM;nD", "rVM;nG", "rVM;nP", "rVM;pP*", "rVM;pE*", "rVM;!pP*", "rVM;!pE*", "rVM;vA*", "rVM;vV",
    "rVP;nS", "rVP;nD", "rVP;nG", "rVP;nP", "rVP;pP*", "rVP;pE*", "rVP;!pP*", "rVP;!pE*", "rVP;vA*", "rVP;vV",
    
    # Префиксы + 2 параметра (400 элементов)
    "rN;nS;pP*", "rN;nS;pE*", "rN;nS;!pP*", "rN;nS;!pE*", "rN;nS;vA*", "rN;nS;vV", "rN;nS;vF", "rN;nS;!vF", "rN;nS;gB", "rN;nS;gT",
    "rN;nD;pP*", "rN;nD;pE*", "rN;nD;!pP*", "rN;nD;!pE*", "rN;nD;vA*", "rN;nD;vV", "rN;nD;vF", "rN;nD;!vF", "rN;nD;gB", "rN;nD;gT",
    "rN;nG;pP*", "rN;nG;pE*", "rN;nG;!pP*", "rN;nG;!pE*", "rN;nG;vA*", "rN;nG;vV", "rN;nG;vF", "rN;nG;!vF", "rN;nG;gB", "rN;nG;gT",
    "rN;nP;pP*", "rN;nP;pE*", "rN;nP;!pP*", "rN;nP;!pE*", "rN;nP;vA*", "rN;nP;vV", "rN;nP;vF", "rN;nP;!vF", "rN;nP;gB", "rN;nP;gT",
    "rN;pP*;nS", "rN;pP*;nD", "rN;pP*;nG", "rN;pP*;nP", "rN;pP*;vA*", "rN;pP*;vV", "rN;pP*;vF", "rN;pP*;!vF", "rN;pP*;gB", "rN;pP*;gT",
    "rN;pE*;nS", "rN;pE*;nD", "rN;pE*;nG", "rN;pE*;nP", "rN;pE*;vA*", "rN;pE*;vV", "rN;pE*;vF", "rN;pE*;!vF", "rN;pE*;gB", "rN;pE*;gT",
    "rN;!pP*;nS", "rN;!pP*;nD", "rN;!pP*;nG", "rN;!pP*;nP", "rN;!pP*;vA*", "rN;!pP*;vV", "rN;!pP*;vF", "rN;!pP*;!vF", "rN;!pP*;gB", "rN;!pP*;gT",
    "rN;!pE*;nS", "rN;!pE*;nD", "rN;!pE*;nG", "rN;!pE*;nP", "rN;!pE*;vA*", "rN;!pE*;vV", "rN;!pE*;vF", "rN;!pE*;!vF", "rN;!pE*;gB", "rN;!pE*;gT",
    "rN;vA*;nS", "rN;vA*;nD", "rN;vA*;nG", "rN;vA*;nP", "rN;vA*;pP*", "rN;vA*;pE*", "rN;vA*;!pP*", "rN;vA*;!pE*", "rN;vA*;gB", "rN;vA*;gT",
    "rN;vV;nS", "rN;vV;nD", "rN;vV;nG", "rN;vV;nP", "rN;vV;pP*", "rN;vV;pE*", "rN;vV;!pP*", "rN;vV;!pE*", "rN;vV;gB", "rN;vV;gT",
    
    "rC;nS;pP*", "rC;nS;pE*", "rC;nS;!pP*", "rC;nS;!pE*", "rC;nS;vA*", "rC;nS;vV", "rC;nS;vF", "rC;nS;!vF", "rC;nS;gB", "rC;nS;gT",
    "rC;nD;pP*", "rC;nD;pE*", "rC;nD;!pP*", "rC;nD;!pE*", "rC;nD;vA*", "rC;nD;vV", "rC;nD;vF", "rC;nD;!vF", "rC;nD;gB", "rC;nD;gT",
    "rC;nG;pP*", "rC;nG;pE*", "rC;nG;!pP*", "rC;nG;!pE*", "rC;nG;vA*", "rC;nG;vV", "rC;nG;vF", "rC;nG;!vF", "rC;nG;gB", "rC;nG;gT",
    "rC;nP;pP*", "rC;nP;pE*", "rC;nP;!pP*", "rC;nP;!pE*", "rC;nP;vA*", "rC;nP;vV", "rC;nP;vF", "rC;nP;!vF", "rC;nP;gB", "rC;nP;gT",
    "rC;pP*;nS", "rC;pP*;nD", "rC;pP*;nG", "rC;pP*;nP", "rC;pP*;vA*", "rC;pP*;vV", "rC;pP*;vF", "rC;pP*;!vF", "rC;pP*;gB", "rC;pP*;gT",
    "rC;pE*;nS", "rC;pE*;nD", "rC;pE*;nG", "rC;pE*;nP", "rC;pE*;vA*", "rC;pE*;vV", "rC;pE*;vF", "rC;pE*;!vF", "rC;pE*;gB", "rC;pE*;gT",
    "rC;!pP*;nS", "rC;!pP*;nD", "rC;!pP*;nG", "rC;!pP*;nP", "rC;!pP*;vA*", "rC;!pP*;vV", "rC;!pP*;vF", "rC;!pP*;!vF", "rC;!pP*;gB", "rC;!pP*;gT",
    "rC;!pE*;nS", "rC;!pE*;nD", "rC;!pE*;nG", "rC;!pE*;nP", "rC;!pE*;vA*", "rC;!pE*;vV", "rC;!pE*;vF", "rC;!pE*;!vF", "rC;!pE*;gB", "rC;!pE*;gT",
    "rC;vA*;nS", "rC;vA*;nD", "rC;vA*;nG", "rC;vA*;nP", "rC;vA*;pP*", "rC;vA*;pE*", "rC;vA*;!pP*", "rC;vA*;!pE*", "rC;vA*;gB", "rC;vA*;gT",
    "rC;vV;nS", "rC;vV;nD", "rC;vV;nG", "rC;vV;nP", "rC;vV;pP*", "rC;vV;pE*", "rC;vV;!pP*", "rC;vV;!pE*", "rC;vV;gB", "rC;vV;gT",
    
    "rCD;nS;pP*", "rCD;nS;pE*", "rCD;nS;!pP*", "rCD;nS;!pE*", "rCD;nS;vA*", "rCD;nS;vV", "rCD;nS;vF", "rCD;nS;!vF", "rCD;nS;gB", "rCD;nS;gT",
    "rCD;nD;pP*", "rCD;nD;pE*", "rCD;nD;!pP*", "rCD;nD;!pE*", "rCD;nD;vA*", "rCD;nD;vV", "rCD;nD;vF", "rCD;nD;!vF", "rCD;nD;gB", "rCD;nD;gT",
    "rCD;nG;pP*", "rCD;nG;pE*", "rCD;nG;!pP*", "rCD;nG;!pE*", "rCD;nG;vA*", "rCD;nG;vV", "rCD;nG;vF", "rCD;nG;!vF", "rCD;nG;gB", "rCD;nG;gT",
    "rCD;nP;pP*", "rCD;nP;pE*", "rCD;nP;!pP*", "rCD;nP;!pE*", "rCD;nP;vA*", "rCD;nP;vV", "rCD;nP;vF", "rCD;nP;!vF", "rCD;nP;gB", "rCD;nP;gT",
    "rCD;pP*;nS", "rCD;pP*;nD", "rCD;pP*;nG", "rCD;pP*;nP", "rCD;pP*;vA*", "rCD;pP*;vV", "rCD;pP*;vF", "rCD;pP*;!vF", "rCD;pP*;gB", "rCD;pP*;gT",
    "rCD;pE*;nS", "rCD;pE*;nD", "rCD;pE*;nG", "rCD;pE*;nP", "rCD;pE*;vA*", "rCD;pE*;vV", "rCD;pE*;vF", "rCD;pE*;!vF", "rCD;pE*;gB", "rCD;pE*;gT",
    "rCD;!pP*;nS", "rCD;!pP*;nD", "rCD;!pP*;nG", "rCD;!pP*;nP", "rCD;!pP*;vA*", "rCD;!pP*;vV", "rCD;!pP*;vF", "rCD;!pP*;!vF", "rCD;!pP*;gB", "rCD;!pP*;gT",
    "rCD;!pE*;nS", "rCD;!pE*;nD", "rCD;!pE*;nG", "rCD;!pE*;nP", "rCD;!pE*;vA*", "rCD;!pE*;vV", "rCD;!pE*;vF", "rCD;!pE*;!vF", "rCD;!pE*;gB", "rCD;!pE*;gT",
    "rCD;vA*;nS", "rCD;vA*;nD", "rCD;vA*;nG", "rCD;vA*;nP", "rCD;vA*;pP*", "rCD;vA*;pE*", "rCD;vA*;!pP*", "rCD;vA*;!pE*", "rCD;vA*;gB", "rCD;vA*;gT",
    "rCD;vV;nS", "rCD;vV;nD", "rCD;vV;nG", "rCD;vV;nP", "rCD;vV;pP*", "rCD;vV;pE*", "rCD;vV;!pP*", "rCD;vV;!pE*", "rCD;vV;gB", "rCD;vV;gT",
    
    "rCA;nS;pP*", "rCA;nS;pE*", "rCA;nS;!pP*", "rCA;nS;!pE*", "rCA;nS;vA*", "rCA;nS;vV", "rCA;nS;vF", "rCA;nS;!vF", "rCA;nS;gB", "rCA;nS;gT",
    "rCA;nD;pP*", "rCA;nD;pE*", "rCA;nD;!pP*", "rCA;nD;!pE*", "rCA;nD;vA*", "rCA;nD;vV", "rCA;nD;vF", "rCA;nD;!vF", "rCA;nD;gB", "rCA;nD;gT",
    "rCA;nG;pP*", "rCA;nG;pE*", "rCA;nG;!pP*", "rCA;nG;!pE*", "rCA;nG;vA*", "rCA;nG;vV", "rCA;nG;vF", "rCA;nG;!vF", "rCA;nG;gB", "rCA;nG;gT",
    "rCA;nP;pP*", "rCA;nP;pE*", "rCA;nP;!pP*", "rCA;nP;!pE*", "rCA;nP;vA*", "rCA;nP;vV", "rCA;nP;vF", "rCA;nP;!vF", "rCA;nP;gB", "rCA;nP;gT",
    "rCA;pP*;nS", "rCA;pP*;nD", "rCA;pP*;nG", "rCA;pP*;nP", "rCA;pP*;vA*", "rCA;pP*;vV", "rCA;pP*;vF", "rCA;pP*;!vF", "rCA;pP*;gB", "rCA;pP*;gT",
    "rCA;pE*;nS", "rCA;pE*;nD", "rCA;pE*;nG", "rCA;pE*;nP", "rCA;pE*;vA*", "rCA;pE*;vV", "rCA;pE*;vF", "rCA;pE*;!vF", "rCA;pE*;gB", "rCA;pE*;gT",
    "rCA;!pP*;nS", "rCA;!pP*;nD", "rCA;!pP*;nG", "rCA;!pP*;nP", "rCA;!pP*;vA*", "rCA;!pP*;vV", "rCA;!pP*;vF", "rCA;!pP*;!vF", "rCA;!pP*;gB", "rCA;!pP*;gT",
    "rCA;!pE*;nS", "rCA;!pE*;nD", "rCA;!pE*;nG", "rCA;!pE*;nP", "rCA;!pE*;vA*", "rCA;!pE*;vV", "rCA;!pE*;vF", "rCA;!pE*;!vF", "rCA;!pE*;gB", "rCA;!pE*;gT",
    "rCA;vA*;nS", "rCA;vA*;nD", "rCA;vA*;nG", "rCA;vA*;nP", "rCA;vA*;pP*", "rCA;vA*;pE*", "rCA;vA*;!pP*", "rCA;vA*;!pE*", "rCA;vA*;gB", "rCA;vA*;gT",
    "rCA;vV;nS", "rCA;vV;nD", "rCA;vV;nG", "rCA;vV;nP", "rCA;vV;pP*", "rCA;vV;pE*", "rCA;vV;!pP*", "rCA;vV;!pE*", "rCA;vV;gB", "rCA;vV;gT",
    
    "rCV;nS;pP*", "rCV;nS;pE*", "rCV;nS;!pP*", "rCV;nS;!pE*", "rCV;nS;vA*", "rCV;nS;vV", "rCV;nS;vF", "rCV;nS;!vF", "rCV;nS;gB", "rCV;nS;gT",
    "rCV;nD;pP*", "rCV;nD;pE*", "rCV;nD;!pP*", "rCV;nD;!pE*", "rCV;nD;vA*", "rCV;nD;vV", "rCV;nD;vF", "rCV;nD;!vF", "rCV;nD;gB", "rCV;nD;gT",
    "rCV;nG;pP*", "rCV;nG;pE*", "rCV;nG;!pP*", "rCV;nG;!pE*", "rCV;nG;vA*", "rCV;nG;vV", "rCV;nG;vF", "rCV;nG;!vF", "rCV;nG;gB", "rCV;nG;gT",
    "rCV;nP;pP*", "rCV;nP;pE*", "rCV;nP;!pP*", "rCV;nP;!pE*", "rCV;nP;vA*", "rCV;nP;vV", "rCV;nP;vF", "rCV;nP;!vF", "rCV;nP;gB", "rCV;nP;gT",
    
    # Префиксы + 3 параметра (300 элементов)
    "rN;nS;pP*;vA*", "rN;nS;pP*;vV", "rN;nS;pP*;vF", "rN;nS;pP*;!vF", "rN;nS;pP*;gB", "rN;nS;pP*;gT", "rN;nS;pP*;fR", "rN;nS;pP*;!fR", "rN;nS;pP*;!fT", "rN;nS;pP*;bB",
    "rN;nS;pE*;vA*", "rN;nS;pE*;vV", "rN;nS;pE*;vF", "rN;nS;pE*;!vF", "rN;nS;pE*;gB", "rN;nS;pE*;gT", "rN;nS;pE*;fR", "rN;nS;pE*;!fR", "rN;nS;pE*;!fT", "rN;nS;pE*;bB",
    "rN;nS;!pP*;vA*", "rN;nS;!pP*;vV", "rN;nS;!pP*;vF", "rN;nS;!pP*;!vF", "rN;nS;!pP*;gB", "rN;nS;!pP*;gT", "rN;nS;!pP*;fR", "rN;nS;!pP*;!fR", "rN;nS;!pP*;!fT", "rN;nS;!pP*;bB",
    "rN;nS;!pE*;vA*", "rN;nS;!pE*;vV", "rN;nS;!pE*;vF", "rN;nS;!pE*;!vF", "rN;nS;!pE*;gB", "rN;nS;!pE*;gT", "rN;nS;!pE*;fR", "rN;nS;!pE*;!fR", "rN;nS;!pE*;!fT", "rN;nS;!pE*;bB",
    "rN;nS;vA*;gB", "rN;nS;vA*;gT", "rN;nS;vA*;fR", "rN;nS;vA*;!fR", "rN;nS;vA*;!fT", "rN;nS;vA*;bB", "rN;nS;vA*;bV1", "rN;nS;vA*;bV2", "rN;nS;vA*;bVP", "rN;nS;vA*;bVS",
    "rN;nS;vV;gB", "rN;nS;vV;gT", "rN;nS;vV;fR", "rN;nS;vV;!fR", "rN;nS;vV;!fT", "rN;nS;vV;bB", "rN;nS;vV;bV1", "rN;nS;vV;bV2", "rN;nS;vV;bVP", "rN;nS;vV;bVS",
    "rN;nS;vF;gB", "rN;nS;vF;gT", "rN;nS;vF;fR", "rN;nS;vF;!fR", "rN;nS;vF;!fT", "rN;nS;vF;bB", "rN;nS;vF;bV1", "rN;nS;vF;bV2", "rN;nS;vF;bVP", "rN;nS;vF;bVS",
    "rN;nS;!vF;gB", "rN;nS;!vF;gT", "rN;nS;!vF;fR", "rN;nS;!vF;!fR", "rN;nS;!vF;!fT", "rN;nS;!vF;bB", "rN;nS;!vF;bV1", "rN;nS;!vF;bV2", "rN;nS;!vF;bVP", "rN;nS;!vF;bVS",
    
    "rC;nS;pP*;vA*", "rC;nS;pP*;vV", "rC;nS;pP*;vF", "rC;nS;pP*;!vF", "rC;nS;pP*;gB", "rC;nS;pP*;gT", "rC;nS;pP*;fR", "rC;nS;pP*;!fR", "rC;nS;pP*;!fT", "rC;nS;pP*;bB",
    "rC;nS;pE*;vA*", "rC;nS;pE*;vV", "rC;nS;pE*;vF", "rC;nS;pE*;!vF", "rC;nS;pE*;gB", "rC;nS;pE*;gT", "rC;nS;pE*;fR", "rC;nS;pE*;!fR", "rC;nS;pE*;!fT", "rC;nS;pE*;bB",
    "rC;nS;!pP*;vA*", "rC;nS;!pP*;vV", "rC;nS;!pP*;vF", "rC;nS;!pP*;!vF", "rC;nS;!pP*;gB", "rC;nS;!pP*;gT", "rC;nS;!pP*;fR", "rC;nS;!pP*;!fR", "rC;nS;!pP*;!fT", "rC;nS;!pP*;bB",
    "rC;nS;!pE*;vA*", "rC;nS;!pE*;vV", "rC;nS;!pE*;vF", "rC;nS;!pE*;!vF", "rC;nS;!pE*;gB", "rC;nS;!pE*;gT", "rC;nS;!pE*;fR", "rC;nS;!pE*;!fR", "rC;nS;!pE*;!fT", "rC;nS;!pE*;bB",
    "rC;nS;vA*;gB", "rC;nS;vA*;gT", "rC;nS;vA*;fR", "rC;nS;vA*;!fR", "rC;nS;vA*;!fT", "rC;nS;vA*;bB", "rC;nS;vA*;bV1", "rC;nS;vA*;bV2", "rC;nS;vA*;bVP", "rC;nS;vA*;bVS",
    "rC;nS;vV;gB", "rC;nS;vV;gT", "rC;nS;vV;fR", "rC;nS;vV;!fR", "rC;nS;vV;!fT", "rC;nS;vV;bB", "rC;nS;vV;bV1", "rC;nS;vV;bV2", "rC;nS;vV;bVP", "rC;nS;vV;bVS",
    "rC;nS;vF;gB", "rC;nS;vF;gT", "rC;nS;vF;fR", "rC;nS;vF;!fR", "rC;nS;vF;!fT", "rC;nS;vF;bB", "rC;nS;vF;bV1", "rC;nS;vF;bV2", "rC;nS;vF;bVP", "rC;nS;vF;bVS",
    "rC;nS;!vF;gB", "rC;nS;!vF;gT", "rC;nS;!vF;fR", "rC;nS;!vF;!fR", "rC;nS;!vF;!fT", "rC;nS;!vF;bB", "rC;nS;!vF;bV1", "rC;nS;!vF;bV2", "rC;nS;!vF;bVP", "rC;nS;!vF;bVS",
    
    "rCD;nS;pP*;vA*", "rCD;nS;pP*;vV", "rCD;nS;pP*;vF", "rCD;nS;pP*;!vF", "rCD;nS;pP*;gB", "rCD;nS;pP*;gT", "rCD;nS;pP*;fR", "rCD;nS;pP*;!fR", "rCD;nS;pP*;!fT", "rCD;nS;pP*;bB",
    "rCD;nS;pE*;vA*", "rCD;nS;pE*;vV", "rCD;nS;pE*;vF", "rCD;nS;pE*;!vF", "rCD;nS;pE*;gB", "rCD;nS;pE*;gT", "rCD;nS;pE*;fR", "rCD;nS;pE*;!fR", "rCD;nS;pE*;!fT", "rCD;nS;pE*;bB",
    "rCD;nS;!pP*;vA*", "rCD;nS;!pP*;vV", "rCD;nS;!pP*;vF", "rCD;nS;!pP*;!vF", "rCD;nS;!pP*;gB", "rCD;nS;!pP*;gT", "rCD;nS;!pP*;fR", "rCD;nS;!pP*;!fR", "rCD;nS;!pP*;!fT", "rCD;nS;!pP*;bB",
    "rCD;nS;!pE*;vA*", "rCD;nS;!pE*;vV", "rCD;nS;!pE*;vF", "rCD;nS;!pE*;!vF", "rCD;nS;!pE*;gB", "rCD;nS;!pE*;gT", "rCD;nS;!pE*;fR", "rCD;nS;!pE*;!fR", "rCD;nS;!pE*;!fT", "rCD;nS;!pE*;bB",
    "rCD;nS;vA*;gB", "rCD;nS;vA*;gT", "rCD;nS;vA*;fR", "rCD;nS;vA*;!fR", "rCD;nS;vA*;!fT", "rCD;nS;vA*;bB", "rCD;nS;vA*;bV1", "rCD;nS;vA*;bV2", "rCD;nS;vA*;bVP", "rCD;nS;vA*;bVS",
    "rCD;nS;vV;gB", "rCD;nS;vV;gT", "rCD;nS;vV;fR", "rCD;nS;vV;!fR", "rCD;nS;vV;!fT", "rCD;nS;vV;bB", "rCD;nS;vV;bV1", "rCD;nS;vV;bV2", "rCD;nS;vV;bVP", "rCD;nS;vV;bVS",
    "rCD;nS;vF;gB", "rCD;nS;vF;gT", "rCD;nS;vF;fR", "rCD;nS;vF;!fR", "rCD;nS;vF;!fT", "rCD;nS;vF;bB", "rCD;nS;vF;bV1", "rCD;nS;vF;bV2", "rCD;nS;vF;bVP", "rCD;nS;vF;bVS",
    "rCD;nS;!vF;gB", "rCD;nS;!vF;gT", "rCD;nS;!vF;fR", "rCD;nS;!vF;!fR", "rCD;nS;!vF;!fT", "rCD;nS;!vF;bB", "rCD;nS;!vF;bV1", "rCD;nS;!vF;bV2", "rCD;nS;!vF;bVP", "rCD;nS;!vF;bVS",
    
    "rCA;nS;pP*;vA*", "rCA;nS;pP*;vV", "rCA;nS;pP*;vF", "rCA;nS;pP*;!vF", "rCA;nS;pP*;gB", "rCA;nS;pP*;gT", "rCA;nS;pP*;fR", "rCA;nS;pP*;!fR", "rCA;nS;pP*;!fT", "rCA;nS;pP*;bB",
    "rCA;nS;pE*;vA*", "rCA;nS;pE*;vV", "rCA;nS;pE*;vF", "rCA;nS;pE*;!vF", "rCA;nS;pE*;gB", "rCA;nS;pE*;gT", "rCA;nS;pE*;fR", "rCA;nS;pE*;!fR", "rCA;nS;pE*;!fT", "rCA;nS;pE*;bB",
    "rCA;nS;!pP*;vA*", "rCA;nS;!pP*;vV", "rCA;nS;!pP*;vF", "rCA;nS;!pP*;!vF", "rCA;nS;!pP*;gB", "rCA;nS;!pP*;gT", "rCA;nS;!pP*;fR", "rCA;nS;!pP*;!fR", "rCA;nS;!pP*;!fT", "rCA;nS;!pP*;bB",
    "rCA;nS;!pE*;vA*", "rCA;nS;!pE*;vV", "rCA;nS;!pE*;vF", "rCA;nS;!pE*;!vF", "rCA;nS;!pE*;gB", "rCA;nS;!pE*;gT", "rCA;nS;!pE*;fR", "rCA;nS;!pE*;!fR", "rCA;nS;!pE*;!fT", "rCA;nS;!pE*;bB",
    "rCA;nS;vA*;gB", "rCA;nS;vA*;gT", "rCA;nS;vA*;fR", "rCA;nS;vA*;!fR", "rCA;nS;vA*;!fT", "rCA;nS;vA*;bB", "rCA;nS;vA*;bV1", "rCA;nS;vA*;bV2", "rCA;nS;vA*;bVP", "rCA;nS;vA*;bVS",
    "rCA;nS;vV;gB", "rCA;nS;vV;gT", "rCA;nS;vV;fR", "rCA;nS;vV;!fR", "rCA;nS;vV;!fT", "rCA;nS;vV;bB", "rCA;nS;vV;bV1", "rCA;nS;vV;bV2", "rCA;nS;vV;bVP", "rCA;nS;vV;bVS",
    "rCA;nS;vF;gB", "rCA;nS;vF;gT", "rCA;nS;vF;fR", "rCA;nS;vF;!fR", "rCA;nS;vF;!fT", "rCA;nS;vF;bB", "rCA;nS;vF;bV1", "rCA;nS;vF;bV2", "rCA;nS;vF;bVP", "rCA;nS;vF;bVS",
    "rCA;nS;!vF;gB", "rCA;nS;!vF;gT", "rCA;nS;!vF;fR", "rCA;nS;!vF;!fR", "rCA;nS;!vF;!fT", "rCA;nS;!vF;bB", "rCA;nS;!vF;bV1", "rCA;nS;!vF;bV2", "rCA;nS;!vF;bVP", "rCA;nS;!vF;bVS",
    
    "rCV;nS;pP*;vA*", "rCV;nS;pP*;vV", "rCV;nS;pP*;vF", "rCV;nS;pP*;!vF", "rCV;nS;pP*;gB", "rCV;nS;pP*;gT", "rCV;nS;pP*;fR", "rCV;nS;pP*;!fR", "rCV;nS;pP*;!fT", "rCV;nS;pP*;bB",
    "rCV;nS;pE*;vA*", "rCV;nS;pE*;vV", "rCV;nS;pE*;vF", "rCV;nS;pE*;!vF", "rCV;nS;pE*;gB", "rCV;nS;pE*;gT", "rCV;nS;pE*;fR", "rCV;nS;pE*;!fR", "rCV;nS;pE*;!fT", "rCV;nS;pE*;bB",
    "rCV;nS;!pP*;vA*", "rCV;nS;!pP*;vV", "rCV;nS;!pP*;vF", "rCV;nS;!pP*;!vF", "rCV;nS;!pP*;gB", "rCV;nS;!pP*;gT", "rCV;nS;!pP*;fR", "rCV;nS;!pP*;!fR", "rCV;nS;!pP*;!fT", "rCV;nS;!pP*;bB",
    "rCV;nS;!pE*;vA*", "rCV;nS;!pE*;vV", "rCV;nS;!pE*;vF", "rCV;nS;!pE*;!vF", "rCV;nS;!pE*;gB", "rCV;nS;!pE*;gT", "rCV;nS;!pE*;fR", "rCV;nS;!pE*;!fR", "rCV;nS;!pE*;!fT", "rCV;nS;!pE*;bB",
    
    # Префиксы + 4 параметра (80 элементов)
    "rN;nS;pP*;vA*;gB", "rN;nS;pP*;vA*;gT", "rN;nS;pP*;vA*;fR", "rN;nS;pP*;vA*;!fR", "rN;nS;pP*;vA*;!fT", "rN;nS;pP*;vA*;bB", "rN;nS;pP*;vA*;bV1", "rN;nS;pP*;vA*;bV2",
    "rN;nS;pP*;vV;gB", "rN;nS;pP*;vV;gT", "rN;nS;pP*;vV;fR", "rN;nS;pP*;vV;!fR", "rN;nS;pP*;vV;!fT", "rN;nS;pP*;vV;bB", "rN;nS;pP*;vV;bV1", "rN;nS;pP*;vV;bV2",
    "rN;nS;pP*;vF;gB", "rN;nS;pP*;vF;gT", "rN;nS;pP*;vF;fR", "rN;nS;pP*;vF;!fR", "rN;nS;pP*;vF;!fT", "rN;nS;pP*;vF;bB", "rN;nS;pP*;vF;bV1", "rN;nS;pP*;vF;bV2",
    "rN;nS;pP*;!vF;gB", "rN;nS;pP*;!vF;gT", "rN;nS;pP*;!vF;fR", "rN;nS;pP*;!vF;!fR", "rN;nS;pP*;!vF;!fT", "rN;nS;pP*;!vF;bB", "rN;nS;pP*;!vF;bV1", "rN;nS;pP*;!vF;bV2",
    
    "rC;nS;pP*;vA*;gB", "rC;nS;pP*;vA*;gT", "rC;nS;pP*;vA*;fR", "rC;nS;pP*;vA*;!fR", "rC;nS;pP*;vA*;!fT", "rC;nS;pP*;vA*;bB", "rC;nS;pP*;vA*;bV1", "rC;nS;pP*;vA*;bV2",
    "rC;nS;pP*;vV;gB", "rC;nS;pP*;vV;gT", "rC;nS;pP*;vV;fR", "rC;nS;pP*;vV;!fR", "rC;nS;pP*;vV;!fT", "rC;nS;pP*;vV;bB", "rC;nS;pP*;vV;bV1", "rC;nS;pP*;vV;bV2",
    "rC;nS;pP*;vF;gB", "rC;nS;pP*;vF;gT", "rC;nS;pP*;vF;fR", "rC;nS;pP*;vF;!fR", "rC;nS;pP*;vF;!fT", "rC;nS;pP*;vF;bB", "rC;nS;pP*;vF;bV1", "rC;nS;pP*;vF;bV2",
    "rC;nS;pP*;!vF;gB", "rC;nS;pP*;!vF;gT", "rC;nS;pP*;!vF;fR", "rC;nS;pP*;!vF;!fR", "rC;nS;pP*;!vF;!fT", "rC;nS;pP*;!vF;bB", "rC;nS;pP*;!vF;bV1", "rC;nS;pP*;!vF;bV2",
    
    "rCD;nS;pP*;vA*;gB", "rCD;nS;pP*;vA*;gT", "rCD;nS;pP*;vA*;fR", "rCD;nS;pP*;vA*;!fR", "rCD;nS;pP*;vA*;!fT", "rCD;nS;pP*;vA*;bB", "rCD;nS;pP*;vA*;bV1", "rCD;nS;pP*;vA*;bV2",
    "rCD;nS;pP*;vV;gB", "rCD;nS;pP*;vV;gT", "rCD;nS;pP*;vV;fR", "rCD;nS;pP*;vV;!fR", "rCD;nS;pP*;vV;!fT", "rCD;nS;pP*;vV;bB", "rCD;nS;pP*;vV;bV1", "rCD;nS;pP*;vV;bV2",
    "rCD;nS;pP*;vF;gB", "rCD;nS;pP*;vF;gT", "rCD;nS;pP*;vF;fR", "rCD;nS;pP*;vF;!fR", "rCD;nS;pP*;vF;!fT", "rCD;nS;pP*;vF;bB", "rCD;nS;pP*;vF;bV1", "rCD;nS;pP*;vF;bV2",
    "rCD;nS;pP*;!vF;gB", "rCD;nS;pP*;!vF;gT", "rCD;nS;pP*;!vF;fR", "rCD;nS;pP*;!vF;!fR", "rCD;nS;pP*;!vF;!fT", "rCD;nS;pP*;!vF;bB", "rCD;nS;pP*;!vF;bV1", "rCD;nS;pP*;!vF;bV2",
    
    "rCA;nS;pP*;vA*;gB", "rCA;nS;pP*;vA*;gT", "rCA;nS;pP*;vA*;fR", "rCA;nS;pP*;vA*;!fR", "rCA;nS;pP*;vA*;!fT", "rCA;nS;pP*;vA*;bB", "rCA;nS;pP*;vA*;bV1", "rCA;nS;pP*;vA*;bV2",
    "rCA;nS;pP*;vV;gB", "rCA;nS;pP*;vV;gT", "rCA;nS;pP*;vV;fR", "rCA;nS;pP*;vV;!fR", "rCA;nS;pP*;vV;!fT", "rCA;nS;pP*;vV;bB", "rCA;nS;pP*;vV;bV1", "rCA;nS;pP*;vV;bV2",
    "rCA;nS;pP*;vF;gB", "rCA;nS;pP*;vF;gT", "rCA;nS;pP*;vF;fR", "rCA;nS;pP*;vF;!fR", "rCA;nS;pP*;vF;!fT", "rCA;nS;pP*;vF;bB", "rCA;nS;pP*;vF;bV1", "rCA;nS;pP*;vF;bV2",
    "rCA;nS;pP*;!vF;gB", "rCA;nS;pP*;!vF;gT", "rCA;nS;pP*;!vF;fR", "rCA;nS;pP*;!vF;!fR", "rCA;nS;pP*;!vF;!fT", "rCA;nS;pP*;!vF;bB", "rCA;nS;pP*;!vF;bV1", "rCA;nS;pP*;!vF;bV2"
]

@btime find_nodes($data, $new_codes, $formes)


input_file = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
output_file = "C:/incart_dev/Myproject/data/new_datatree.yaml"


function find_nodes_v2(data, codes, forms, path=[], form_context=nothing)
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
                    return results
                end
            else
                return results
            end
        end

        if haskey(data, "CustomName")
            custom_value_pattern = data["CustomName"]
            regex_pattern = if isa(custom_value_pattern, Regex)
                custom_value_pattern
            elseif isa(custom_value_pattern, AbstractString)
                Regex(custom_value_pattern)
            end
            
            for code in codes
                if occursin(regex_pattern, code)
                    pattern_str = isa(custom_value_pattern, Regex) ? custom_value_pattern.pattern : custom_value_pattern
                    push!(results, (path, pattern_str, code))
                    break
                end
            end
        end

        for (key, value) in data
            if key in ["Form", "CustomName"]
                continue
            end
            child_path = [path..., key]
            child_results = find_nodes_v2(value, codes, forms, child_path, current_form)
            append!(results, child_results)
        end

    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            child_results = find_nodes_v2(item, codes, forms, [path..., i], form_context)
            append!(results, child_results)
        end
    end

    return results
end

function transform_custom_names_to_regex(data)
    if isa(data, Dict)
        new_data = Dict{Any, Any}() 
        for (key, value) in data
            if key == "CustomName" && isa(value, String)
                new_data[key] = build_regex_pattern(value)
            else
                new_data[key] = transform_custom_names_to_regex(value)
            end
        end
        return new_data
    elseif isa(data, Vector)
        return [transform_custom_names_to_regex(item) for item in data]
    else
        return data
    end
end

transformed_data = transform_custom_names_to_regex(data)

trans_d = transform_custom_names_to_regex(data)

@btime find_nodes_v2($transformed_data, $new_codes, $formes)

open(output_file, "w") do f
        YAML.write(f, trans_d)
end
