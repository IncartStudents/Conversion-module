using FileUtils
using Printf
using ExtractMkp


include("CalcStats.jl")

include("C:/incart_dev/ExtractMkp.jl/src/dict.jl")

filepath = "C:/incart_dev/Myproject/data/AlgResult.xml"


res = readxml_rhythms_arrs(filepath)

arr_pairs = res[1]    # Rhythms in xml-file
arr_tuples = res[2]   # Arrhythmias in xml-file
metadata = res[3]


arrhythmias = Vector{Vector{Enum}}()

for nt in arr_tuples
    codes = split(nt.code, ';')
    for code in codes
        for mod in keys(DICT)
            val = get(DICT[mod], code, nothing)
            if val !== nothing
                push!(arrhythmias, val)
            end
        end
    end
end

println(arrhythmias)

pqrst = readxml_pqrst_anz(filepath)
calc_qrs_stats(pqrst[1])
calc_qrs_statsv3(pqrst[1])


# ================================================================================

using YAML

include("FindNodes.jl")


input_tree = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
output_tree = "C:/incart_dev/Myproject/result/output_datatree.yaml"

data = YAML.load(open(input_tree, "r"))

# для одной строки кода
input_code = "rFA"
found = find_node(data, input_code)

if !isempty(found)
    result_data = build_structure(found)
    open(output_tree, "w") do f
        YAML.write(f, result_data)
    end
    println("Результат сохранён в $output_tree")
else
    println("Узел не найден")
end

# для массива строк кодов
input_codes = ["rFA", "rCU"]
found_nodes = find_all_nodes(data, input_codes)

if !isempty(found_nodes)
    result_data = build_structure(found_nodes)
    open(output_tree, "w") do f
        YAML.write(f, result_data)
    end
    println("Найдено $(length(found_nodes)) узлов. Результат сохранён в $output_tree")
else
    println("Ни один узел не найден")
end