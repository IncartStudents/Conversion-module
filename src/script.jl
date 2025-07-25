using FileUtils
using Printf
using ExtractMkp


include("CalcStats.jl")

include("C:/incart_dev/ExtractMkp.jl/src/dict.jl")

filepath = "C:/incart_dev/Myproject/data/AlgResult.xml"


res = readxml_rhythms_arrs(filepath)

arr_pairs = res[1]    # Rhythms in xml-file
arr_tuples = res[2]   # Arrhythmias in xml-file
metadata = res[3]     # timestart, fs
sleep_info = res[4]   # SleepFragments

lens = [t.len for t in arr_tuples]
starts = [t.starts for t in arr_tuples]
titles = [t.title for t in arr_tuples]

sleep_frag = []
for (_, slp) in sleep_info
    push!(sleep_frag, (slp["ECGStartPoints"][1], slp["ECGStartPoints"][1] + slp["ECGDurationPoints"][1]))
end
sleep_frag

calc_cmpx_stats(arr_tuples, sleep_frag, metadata.fs)


pqrst = readxml_pqrst_anz(filepath)
form_stats = calc_qrs_stats(pqrst[1])


# ================================================================================

using YAML

include("FindNodes.jl")


input_tree = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
output_tree = "C:/incart_dev/Myproject/result/output_datatree.yaml"

data = YAML.load(open(input_tree, "r"))

codes = [t.code for t in arr_tuples]
formes = [String(f) for f in form_stats.form]

# result = find_all_nodes(data, codes, formes)
result = find_all_nodes(data, arr_tuples, formes)
if !isempty(result)
    result_data = build_structure(result)
    open(output_tree, "w") do f
        YAML.write(f, result_data)
    end
    println("Найдено $(length(result)) узлов. Результат сохранён в $output_tree")
else
    println("Ни один узел не найден")
end