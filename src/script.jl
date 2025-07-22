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
form_stats = calc_qrs_statsv3(pqrst[1])


# ================================================================================

using YAML

include("FindNodes.jl")


input_tree = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
output_tree = "C:/incart_dev/Myproject/result/output_datatree.yaml"

data = YAML.load(open(input_tree, "r"))

codes = [t.code for t in arr_tuples]
formes = [String(f) for f in form_stats.form]

res = find_all_nodes(data, codes, formes)
if !isempty(res)
    result_data = build_structure(res)
    open(output_tree, "w") do f
        YAML.write(f, result_data)
    end
    println("Найдено $(length(found_nodes)) узлов. Результат сохранён в $output_tree")
else
    println("Ни один узел не найден")
end